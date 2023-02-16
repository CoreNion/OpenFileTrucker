import 'dart:async';
import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:sodium_libs/sodium_libs.dart';
import 'package:mime/mime.dart';
import 'dart:io';

import 'class/file_info.dart';

class ReceiveFile {
  /// ファイルの受信の処理をする関数
  static Future<StreamController<ReceiveProgress>> receiveFile(
      String ip, int fileIndex, File saveFile, int size) async {
    StreamController<ReceiveProgress> controller = StreamController();

    // サーバーにi個目のファイルをファイルを要求
    final socket =
        await Socket.connect(ip, 4782, timeout: const Duration(seconds: 10));
    socket.add(utf8.encode(fileIndex.toString()));

    // ファイル受信が完了するまで、進捗を定期的にStreamで流す
    ReceiveProgress latestProg =
        ReceiveProgress(singleProgress: 0, receiveSpeed: 0, currentFileSize: 0);
    final timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final currentFileSize = saveFile.lengthSync();

      latestProg = _refreshProgress(latestProg, size, currentFileSize);
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
    receiveSink.addStream(socket)
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
  static Future<StreamController<ReceiveProgress>> receiveAllFiles(
      String ip, FileInfo fileInfo, String dirPath) async {
    StreamController<ReceiveProgress> controller = StreamController();
    late StreamController<ReceiveProgress> singleController;

    // 現在の全ファイルの受信進捗
    double totalProgress = 0;
    // 現在までに受信したサイズ (全ファイル)
    int currentTotalSize = 0;
    // 正常に終了したかのステータス
    bool receiveDone = false;

    // 全ファイルの合計のサイズを計算
    final totalFileSize =
        fileInfo.sizes.reduce((value, element) => value + element);

    // 受信タスクを非同期実行
    Future.sync(() async {
      // 各ファイルを受信
      for (var i = 0; i < fileInfo.names.length; i++) {
        singleController = await ReceiveFile.receiveFile(
            ip, i, File(p.join(dirPath, fileInfo.names[i])), fileInfo.sizes[i]);

        singleController.stream.listen((progress) {
          // 各値を最新の値に更新
          if (!(fileInfo.names.length == 1)) {
            currentTotalSize = currentTotalSize + progress.receiveSpeed;
            totalProgress = (currentTotalSize / totalFileSize).toDouble();
          } else {
            // 受信するファイルが一つだけなら現在の進捗をそのまま流す
            currentTotalSize = progress.currentFileSize;
            totalProgress = progress.singleProgress;
          }

          // 全体の進捗をstreamで送信
          final totalReceiveProgress = ReceiveProgress(
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
        for (String fileName in fileInfo.names) {
          final file = File(p.join(dirPath, fileName));
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
  static bool checkMediaOnly(FileInfo fileInfo) {
    return fileInfo.names.every((name) {
      final mine = lookupMimeType(name);
      if (mine != null) {
        return mine.contains(RegExp(r"image|video"));
      } else {
        return false;
      }
    });
  }

  /// サーバーにファイル情報を取得する関数
  static Future<FileInfo> getServerFileInfo(String ip) async {
    late FileInfo result;

    // サーバーに接続し、ファイル情報を要求する
    final socket =
        await Socket.connect(ip, 4782, timeout: const Duration(seconds: 10));
    socket.add(utf8.encode("first"));

    await socket.listen((event) {
      result = FileInfo.mapToInfo(json.decode(utf8.decode(event)));

      socket.destroy();
    }).asFuture<void>();

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
  static Future<bool> checkFileHash(String dirPath, FileInfo fileInfo) async {
    final sodium = await SodiumInit.init();

    // 各ファイルのハッシュ値を確認
    for (var i = 0; i < fileInfo.names.length; i++) {
      final Uint8List origHash = fileInfo.hashs![i];
      final XFile file = XFile(p.join(dirPath, fileInfo.names[i]));

      final receieHash =
          await sodium.crypto.genericHash.stream(messages: file.openRead());
      if (!(listEquals(origHash, receieHash))) {
        return false;
      }
    }

    return true;
  }

  /// 画像ライブラリに保存する関数
  static Future<bool> savePhotoLibrary(
      String dirPath, FileInfo fileInfo) async {
    if (await Permission.photosAddOnly.request().isDenied) {
      return false;
    }

    for (var i = 0; i < fileInfo.names.length; i++) {
      final XFile file = XFile(p.join(dirPath, fileInfo.names[i]));

      await ImageGallerySaver.saveFile(file.path);
    }

    return true;
  }
}

/// 受信の進捗情報のクラス
class ReceiveProgress {
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
      {this.totalProgress,
      required this.singleProgress,
      required this.receiveSpeed,
      required this.currentFileSize,
      this.currentTotalSize});
}
