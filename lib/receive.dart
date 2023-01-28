import 'dart:async';
import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_sizes/file_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:sodium_libs/sodium_libs.dart';
import 'package:wakelock/wakelock.dart';
import 'package:open_file_trucker/widget/dialog.dart';
import 'package:mime/mime.dart';
import 'dart:io';

import 'class/file_info.dart';

class ReceiveFile {
  /// ファイルの受信の処理をする関数
  static Future<bool> receiveFile(String ip, FileInfo fileInfo, String path,
      bool onlyImage, BuildContext context) async {
    final nav = Navigator.of(context);
    late ConnectionTask<Socket> connectionTask;
    late Socket socket;

    final fileName = fileInfo.names;
    final fileSize = fileInfo.sizes;

    late int currentNum;
    double singleFileProgress = 0;
    double totalProgress = 0;
    late Function dialogSetState;
    final int totalFileLength = fileSize.reduce((a, b) => a + b);
    int receieveSpeed = 0;
    int completedLength = 0;
    late Timer timer;
    bool pushCancelButton = false;

    // 全ファイルの受信の終了時の処理(異常終了関係なし)
    void endProcess() {
      Wakelock.disable();

      // キャッシュ削除
      if (Platform.isIOS || Platform.isAndroid) {
        FilePicker.platform.clearTemporaryFiles();
      }

      Navigator.of(context).pop();
    }

    // ファイル受信の進行状況を表示するダイアログを表示
    showDialog(
        context: context,
        builder: (context) {
          return WillPopScope(
            // 戻る無効化
            onWillPop: (() => Future.value(false)),
            child: AlertDialog(
              title: const Text("ファイルを受信しています..."),
              content: StatefulBuilder(
                builder: (context, setState) {
                  // Progressの更新にはStateの更新が必要
                  dialogSetState = setState;
                  return SingleChildScrollView(
                    child: ListBody(
                      children: <Widget>[
                        Column(
                          children: [
                            Text(
                              "${currentNum + 1}個目のファイルを受信中 ${(totalProgress * 100).toStringAsFixed(1)}%完了",
                              textAlign: TextAlign.center,
                            ),
                            LinearProgressIndicator(
                              value: totalProgress,
                            ),
                            Text(
                              "${fileName[currentNum]} ${(singleFileProgress * 100).toStringAsFixed(1)}%完了",
                              textAlign: TextAlign.center,
                            ),
                            LinearProgressIndicator(
                              value: singleFileProgress,
                            ),
                            Text(
                              "速度: ${FileSize.getSize(receieveSpeed * 10)}/s",
                              textAlign: TextAlign.right,
                            )
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              actions: <Widget>[
                TextButton(
                    child: const Text("キャンセル"),
                    onPressed: () {
                      pushCancelButton = true;
                      socket.destroy();
                    })
              ],
            ),
          );
        });

    // "ready"を送信するとデータが送られてくるので、そのStreamをIOSinkで書き込み
    // Listen上ではSocketのStreamを扱えないので二回通信する必要がある
    for (currentNum = 0; currentNum < fileName.length; currentNum++) {
      // キャンセルボタンによって前回の通信が終了した場合はbreak
      if (pushCancelButton) {
        break;
      }

      // 2回目以降の通信でファイルを受信
      try {
        connectionTask = await Socket.startConnect(ip, 4782);
        socket = await connectionTask.socket;
      } on SocketException catch (e) {
        Wakelock.disable();
        EasyDialog.showErrorDialog(e, nav);
        return false;
      }
      // サーバーi個目のファイルをファイルを要求
      socket.add(utf8.encode(currentNum.toString()));

      // 受信ディレクトリにファイルを作成
      late File receieveFile;
      if (fileName.length < 2) {
        receieveFile = File(path);
      } else {
        receieveFile = File(p.join(path, fileName[currentNum]));
      }

      // 進捗を定期的に更新する
      int latestCompletedFileLen = 0;
      timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        final currentFileLength = receieveFile.lengthSync();
        dialogSetState(() {
          // 1つのファイルの進捗
          singleFileProgress =
              (currentFileLength / fileSize[currentNum]).toDouble();
          // この100msで取得した容量 (現在の容量 - 最後に取得した時の容量)
          receieveSpeed = currentFileLength - latestCompletedFileLen;
          // 現在までに受信した容量 = (現在の容量 - 最後に取得した時の容量) + いままでの容量
          completedLength = receieveSpeed + completedLength;
          // トータルの進捗
          totalProgress = (completedLength / totalFileLength).toDouble();
        });
        // 最後に取得した時の容量を更新
        latestCompletedFileLen = currentFileLength;
      });

      // 流れてきたデータをファイルに書き込む
      final IOSink receieveSink =
          receieveFile.openWrite(mode: FileMode.writeOnly);
      await receieveSink.addStream(socket);

      // 進捗更新の停止
      timer.cancel();
      // ファイルの最終処理
      await receieveSink.flush();
      await receieveSink.close();

      // 通信の終了
      socket.destroy();
    }

    // 共通の終了処理
    endProcess();

    // キャンセルボタンが押されて終了した場合は作成したファイルを削除
    if (pushCancelButton) {
      if (fileName.length < 2) {
        File(path).deleteSync();
      } else {
        for (var name in fileName) {
          final file = File(p.join(path + name));
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      }
      showDialog(
          context: context,
          builder: (context) =>
              EasyDialog.showSmallInfo(nav, "情報", "ファイルの受信はキャンセルされました。"));
      return false;
    } else {
      return true;
    }
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

  /// ファイルの保存場所をユーザーなどから取得
  static Future<String?> getSavePath(List<String> fileNames) async {
    // Desktopはファイル保存のダイアログ経由
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      if (fileNames.length < 2) {
        // ファイルが一つだけの場合はファイルの保存のダイアログを開く
        return await FilePicker.platform.saveFile(
            dialogTitle: "ファイルの保存場所を選択...", fileName: fileNames.first);
      } else {
        return await FilePicker.platform
            .getDirectoryPath(dialogTitle: "ファイルを保存するフォルダーを選択...");
      }
    } else if (Platform.isAndroid) {
      // なぜかiOSでは動作しない...
      String? path = await FilePicker.platform
          .getDirectoryPath(dialogTitle: "ファイルを保存するフォルダーを選択...");
      if (path != null) {
        if (fileNames.length < 2) {
          return p.join(path, fileNames.first);
        } else {
          return path;
        }
      } else {
        return null;
      }
    } else if (Platform.isIOS) {
      // iOSはgetApplicationDocumentsDirectoryでもファイルアプリに表示可
      final directory = await getApplicationDocumentsDirectory();
      if (fileNames.length < 2) {
        return p.join(directory.path, fileNames.first);
      } else {
        return directory.path;
      }
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
