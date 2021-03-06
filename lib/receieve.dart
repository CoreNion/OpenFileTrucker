import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:wakelock/wakelock.dart';
import 'package:open_file_trucker/dialog.dart';
import 'dart:io';

class ReceiveFile {
  /// ファイルの受信の処理をする関数
  static Future<bool> receiveFile(
      String ip, /* String key */ BuildContext context) async {
    late ConnectionTask<Socket> connectionTask;
    late Socket socket;
    bool err = false;

    // ダイアログ表示
    showDialog(
        context: context,
        builder: (_) {
          return WillPopScope(
            // 戻る無効化
            onWillPop: () => Future.value(false),
            child: AlertDialog(
              title: const Text("接続しています..."),
              actions: <Widget>[
                TextButton(
                    onPressed: () => connectionTask.cancel(),
                    child: const Text("キャンセル")),
              ],
            ),
          );
        });

    //スリープ無効化
    Wakelock.enable();

    // 最初の接続を開始
    try {
      connectionTask = await Socket.startConnect(ip, 4782);
      socket = await connectionTask.socket;
      socket.add(utf8.encode("first"));
    } on SocketException catch (e) {
      Wakelock.disable();
      // 「接続しています」のダイアログを消す
      Navigator.pop(context);
      EasyDialog.showErrorDialog(e, context);
      return false;
    }

    // ファイルの情報を受信
    late List<String> fileName;
    late List<int> fileSize;
    // ファイルの情報を取得したら一旦通信終了される
    await socket
        .listen((event) {
          Map<String, dynamic> fileInfo = json.decode(utf8.decode(event));
          fileName = fileInfo["nameList"].cast<String>();
          fileSize = fileInfo["lengthList"].cast<int>();
        })
        .asFuture<void>()
        .catchError((e) {
          EasyDialog.showErrorDialog(e, context);
          err = true;
        });
    if (err) {
      return false;
    }

    // 終了次第「接続しています」のダイアログを消す
    Navigator.pop(context);
    // ファイルの保存場所を取得(聞く)
    String? path = await _getSavePath(fileName, context);
    if (path != null) {
      late int currentNum;
      double singleFileProgress = 0;
      double totalProgress = 0;
      late Function dialogSetState;
      final int totalFileLength = fileSize.reduce((a, b) => a + b);
      int completedLength = 0;
      late Timer timer;
      bool pushCancelButton = false;

      // 全ファイルの受信の終了時の処理(異常終了関係なし)
      void endProcess() {
        Wakelock.disable();
        socket.destroy();
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
          EasyDialog.showErrorDialog(e, context);
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
            // 現在までに受信した容量 = (現在の容量 - 最後に取得した時の容量) + いままでの容量
            completedLength =
                (currentFileLength - latestCompletedFileLen) + completedLength;
            // トータルの進捗
            totalProgress = (completedLength / totalFileLength).toDouble();
          });
          // 最後に取得した時の容量を更新
          latestCompletedFileLen = currentFileLength;
        });

        // 流れてきたデータをファイルに書き込む
        final IOSink receieveSink =
            receieveFile.openWrite(mode: FileMode.writeOnly);
        await receieveSink.addStream(socket).catchError((e) {
          timer.cancel();
          endProcess();
          return EasyDialog.showErrorDialog(e, context);
        });

        // 進捗更新の停止
        timer.cancel();
        // ファイルの最終処理
        try {
          await receieveSink.flush();
          await receieveSink.close();
        } on Exception catch (e) {
          endProcess();
          EasyDialog.showErrorDialog(e, context);
          return true;
        }
      }
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
                EasyDialog.showSmallInfo(context, "情報", "ファイルの受信はキャンセルされました。"));
        return false;
      } else {
        return true;
      }
    } else {
      return false;
    }
  }

  /// ファイルの保存場所をユーザーなどから取得
  static Future<String?> _getSavePath(
      List<String> fileName, BuildContext context) async {
    // Desktopはファイル保存のダイアログ経由
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      if (fileName.length < 2) {
        // ファイルが一つだけの場合はファイルの保存のダイアログを開く
        return await FilePicker.platform
            .saveFile(dialogTitle: "ファイルの保存場所を選択...", fileName: fileName.first);
      } else {
        return await FilePicker.platform
            .getDirectoryPath(dialogTitle: "ファイルを保存するフォルダーを選択...");
      }
    } else if (Platform.isAndroid) {
      // なぜかiOSでは動作しない...
      if (await Permission.storage.request().isGranted) {
        String? path = await FilePicker.platform
            .getDirectoryPath(dialogTitle: "ファイルを保存するフォルダーを選択...");
        if (path != null) {
          if (fileName.length < 2) {
            return p.join(path, fileName.first);
          } else {
            return path;
          }
        } else {
          return null;
        }
      } else {
        EasyDialog.showPermissionAlert(
            "ファイルを保存するには、ストレージへのアクセス権限が必要です。", context);
        return null;
      }
    } else if (Platform.isIOS) {
      // iOSはgetApplicationDocumentsDirectoryでもファイルアプリに表示可
      final directory = await getApplicationDocumentsDirectory();
      if (fileName.length < 2) {
        return p.join(directory.path, fileName.first);
      } else {
        return directory.path;
      }
    } else {
      return null;
    }
  }
}
