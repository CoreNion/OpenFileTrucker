import 'dart:async';
import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'package:webcrypto/webcrypto.dart';
import 'dart:io';

import 'class/file_info.dart';
import 'helper/gcm.dart';
import 'main.dart';

class ReceiveFile {
  static KeyPair<RsaOaepPrivateKey, RsaOaepPublicKey>? _pubKeyPair;
  static bool _encrypt = true;
  static AesGcmSecretKey? _aesGcmSecretKey;

  /// ファイルの受信の処理をする関数
  static Future<StreamController<ReceiveProgress>> receiveFile(
      String ip,
      int fileIndex,
      File saveFile,
      FileInfo fileInfo,
      bool saveMediaFile) async {
    if (_encrypt && _aesGcmSecretKey == null) {
      throw Exception("AES暗号化用の鍵が設定されていません");
    }

    StreamController<ReceiveProgress> controller = StreamController();

    final sendIV = Uint8List(16);
    fillRandomBytes(sendIV);

    // 送信側に接続
    final socket =
        await Socket.connect(ip, 4782, timeout: const Duration(seconds: 10));
    // サーバーにUUIDを伝え, i個目のファイルをファイルを要求
    final mesg = utf8.encode("$myUUID${fileIndex.toString()}");
    final sendRawData = _encrypt
        ? [...sendIV, ...await _aesGcmSecretKey!.encryptBytes(mesg, sendIV)]
        : mesg;
    socket.add(sendRawData);

    // ファイル受信が完了するまで、進捗を定期的にStreamで流す
    ReceiveProgress latestProg =
        ReceiveProgress(singleProgress: 0, receiveSpeed: 0, currentFileSize: 0);
    final timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final currentFileSize = saveFile.lengthSync();

      latestProg = _refreshProgress(latestProg, fileInfo.size, currentFileSize);
      controller.sink.add(latestProg);
    });

    // Sinkを開く
    final IOSink receiveSink = saveFile.openWrite(mode: FileMode.writeOnly);

    // 正常に終了したかのステータス
    bool receiveDone = false;
    bool onCancel = false;

    // キャンセルボタンによって前回の通信が終了した場合はSocketなどを終了し、データ削除
    controller.onCancel = () async {
      // キャンセル時のみ実行 (closeでonCancelは実行されるため判別)
      if (!receiveDone) {
        onCancel = true;
        socket.destroy();
        // Socket放棄でreceiveSink.addStreamが終了される
      }
    };

    // 流れてきたデータをファイルに書き込む
    receiveSink.addStream(
        _encrypt ? decryptGcmStream(socket, _aesGcmSecretKey!, sendIV) : socket)
      ..then((v) async {
        /* 書き込み終了時の処理 (キャンセル関係なく実行) */
        timer.cancel();

        // 通信の終了
        socket.destroy();

        // 終了処理
        await receiveSink.flush();
        await receiveSink.close();

        if (!onCancel) {
          // 正常終了のステータスを付ける
          receiveDone = true;
        } else {
          // キャンセルの場合はファイルを削除
          if (saveFile.existsSync()) {
            saveFile.deleteSync();
          }
        }

        // MediaStore/写真ライブラリにファイル情報を保存 (Android/iOSのみ)
        if (saveMediaFile || Platform.isAndroid) {
          await _saveMediaStore(saveFile);
        }

        await controller.close();
      })
      ..catchError((error) {
        timer.cancel();
        socket.destroy();

        controller.addError(error);
      });

    return controller;
  }

  /// 更新された進捗を返す関数
  static ReceiveProgress _refreshProgress(
      ReceiveProgress oldProg, int allFileSize, int currentFileSize) {
    // ファイルの進捗(割合)
    final singleProgress = (oldProg.currentFileSize / allFileSize).toDouble();
    // 最後の更新から新たに取得した容量 (現在の容量 - 最後に取得した時の容量)
    final receiveSpeed = currentFileSize - oldProg.currentFileSize;

    return ReceiveProgress(
        singleProgress: singleProgress,
        receiveSpeed: receiveSpeed,
        currentFileSize: currentFileSize);
  }

  /// FileInfoにあるファイルを全て受信する関数
  static Future<StreamController<ReceiveProgress>> receiveAllFiles(String ip,
      List<FileInfo> fileInfos, String dirPath, bool saveMediaFile) async {
    StreamController<ReceiveProgress> controller = StreamController();
    late StreamController<ReceiveProgress> singleController;

    // 現在の全ファイルの受信進捗
    double totalProgress = 0;
    // 現在までに受信したサイズ (全ファイル)
    int currentTotalSize = 0;
    // 正常に終了したかのステータス
    bool receiveDone = false;

    // 全ファイルの合計のサイズを計算
    final totalFileSize = fileInfos.fold<int>(
        0, (previousValue, element) => previousValue + element.size);

    // 受信タスクを非同期実行
    Future.sync(() async {
      // 各ファイルを受信
      for (var i = 0; i < fileInfos.length; i++) {
        singleController = await ReceiveFile.receiveFile(
            ip,
            i,
            File(p.join(dirPath, fileInfos[i].name)),
            fileInfos[i],
            saveMediaFile);

        singleController.stream.listen((progress) {
          // 各値を最新の値に更新
          if (!(fileInfos.length == 1)) {
            currentTotalSize = currentTotalSize + progress.receiveSpeed;
            totalProgress = (currentTotalSize / totalFileSize).toDouble();
          } else {
            // 受信するファイルが一つだけなら現在の進捗をそのまま流す
            currentTotalSize = progress.currentFileSize;
            totalProgress = progress.singleProgress;
          }

          // 全体の進捗をstreamで送信
          final totalReceiveProgress = ReceiveProgress(
              currentFileIndex: i,
              totalProgress: totalProgress,
              singleProgress: progress.singleProgress,
              receiveSpeed: progress.receiveSpeed,
              currentFileSize: progress.currentFileSize,
              currentTotalSize: currentTotalSize);
          controller.sink.add(totalReceiveProgress);
        }, onError: (e) {
          controller.addError(e);
        });
        await singleController.done;
      }
    }).then((value) async {
      receiveDone = true;
      await controller.close();
    });

    // キャンセル時の動作を設定
    controller.onCancel = () async {
      if (!receiveDone) {
        // ファイル受信を停止
        await singleController.close();

        // ファイルが残っている場合は削除
        for (var i = 0; i < fileInfos.length; i++) {
          final file = File(p.join(dirPath, fileInfos[i].name));
          if (file.existsSync()) {
            file.deleteSync();
          }
        }

        await controller.close();
      }
    };
    return controller;
  }

  /// 画像/動画のみかを確認する関数
  static bool checkMediaOnly(List<FileInfo> fileInfos) {
    return fileInfos.every((f) {
      final mine = lookupMimeType(f.name);
      if (mine != null) {
        return mine.contains(RegExp(r"image|video"));
      } else {
        return false;
      }
    });
  }

  /// サーバーにファイル情報を取得する関数
  static Future<List<FileInfo>> getServerFileInfo(String ip) async {
    List<FileInfo> result = [];

    final iv = Uint8List(16);
    fillRandomBytes(iv);

    // RSAの鍵ペアを作成
    _pubKeyPair = await RsaOaepPrivateKey.generateKey(
        2048, BigInt.from(65537), Hash.sha512);

    // サーバーに1回目で接続し、公開鍵を要求する
    Socket socket =
        await Socket.connect(ip, 4782, timeout: const Duration(seconds: 10));
    socket.add(
        [...plainTextHeader, ...await _pubKeyPair!.publicKey.exportSpkiKey()]);

    // AES暗号化用の鍵を受信
    Completer completer = Completer();
    await socket.listen((event) async {
      // 暗号化モードが無効の場合は暗号化を無効にする
      if (listEquals(event, plainTextHeader)) {
        _encrypt = false;
      } else {
        _encrypt = true;
        _aesGcmSecretKey = await AesGcmSecretKey.importRawKey(
            await _pubKeyPair!.privateKey.decryptBytes(event));
      }

      completer.complete();
      socket.destroy();
    }).asFuture();
    await completer.future;

    // ファイル情報を要求する
    socket =
        await Socket.connect(ip, 4782, timeout: const Duration(seconds: 10));
    final mesg = utf8.encode("${myUUID}second");
    final sendRawData = _encrypt
        ? [...iv, ...await _aesGcmSecretKey!.encryptBytes(mesg, iv)]
        : mesg;
    socket.add(sendRawData);

    // ファイル情報を受信
    List<int> decData = [];
    await for (var data in _encrypt
        ? decryptGcmStream(socket, _aesGcmSecretKey!, iv)
        : socket) {
      decData.addAll(data);
    }

    // ファイル情報をJSONにデコード
    final js = json.decode(utf8.decode(decData)) as List<dynamic>;
    // ファイル情報をList<FileInfo>に変換
    for (var element in js) {
      final map = element as Map<String, dynamic>;
      result.add(FileInfo.mapToInfo(map));
    }
    return result;
  }

  /// ファイルの保存場所(ディレクトリ)のパスをユーザーなどから取得
  static Future<String?> getSavePath() async {
    // Desktopはファイル保存のダイアログ経由
    if (Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isAndroid) {
      return await FilePicker.platform
          .getDirectoryPath(dialogTitle: "ファイルを保存するフォルダーを選択...");
    } else if (Platform.isIOS) {
      // iOSはgetApplicationDocumentsDirectoryでもファイルアプリに表示可
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } else {
      return null;
    }
  }

  /// 各ファイルの整合性を確認する関数
  static Future<bool> checkFileHash(
      String dirPath, List<FileInfo> fileInfos) async {
    // 各ファイルのハッシュ値を確認
    for (var i = 0; i < fileInfos.length; i++) {
      final Uint8List origHash = fileInfos[i].hash!;
      final XFile file = XFile(p.join(dirPath, fileInfos[i].name));

      final receieHash = await Hash.sha256.digestStream(file.openRead());
      if (!(listEquals(origHash, receieHash))) {
        return false;
      }
    }

    return true;
  }

  /// (Android/iOSのみ) MediaStore/写真ライブラリにファイル情報を保存する関数
  static Future<void> _saveMediaStore(File file) async {
    if (Platform.isAndroid || Platform.isIOS) {
      const platform = MethodChannel('dev.cnion.filetrucker/mediastore');
      await platform.invokeMethod('registerMediaStore', {"path": file.path});
    }
  }
}

/// 受信の進捗情報のクラス
class ReceiveProgress {
  /// 現在受信しているファイルのIndex番号
  final int? currentFileIndex;

  /// 全体の進捗 (割合)
  final double? totalProgress;

  /// 現在のファイルの進捗 (割合)
  final double singleProgress;

  /// 受信スピード
  final int receiveSpeed;

  /// 現在までに受信したデータのサイズ
  final int currentFileSize;

  /// 現在までに受信したデータのサイズ
  final int? currentTotalSize;

  ReceiveProgress(
      {this.currentFileIndex,
      this.totalProgress,
      required this.singleProgress,
      required this.receiveSpeed,
      required this.currentFileSize,
      this.currentTotalSize});
}
