import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock/wakelock.dart';
import 'dart:io';

class ReceiveFile {
  static void receiveFile(
      String ip, TextEditingController log, BuildContext context) async {
    late String fileName;
    late double fileSize;
    late File receivedFile;
    late Socket socket;

    //スリープ無効化
    Wakelock.enable();

    // 最初の接続
    try {
      socket = await Socket.connect(ip, 4782);
      socket.add(utf8.encode("first"));
    } on SocketException catch (e) {
      Wakelock.disable();
      return _showErrorDialog(e, context);
    }

    socket.listen((event) {
      Map<String, dynamic> fileInfo = json.decode(String.fromCharCodes(event));
      fileName = fileInfo["name"];
      fileSize = fileInfo["length"].toDouble();
    })
      // ファイルの情報を取得したら一旦通信終了される
      ..onDone(() {
        // ファイルの保存場所を取得(聞く)
        _getSavePath(fileName).then((path) async {
          if (path != null) {
            receivedFile = File(path);
            double progress = 0;
            late Function dialogSetState;

            // 2回目の通信でファイルを受信
            try {
              socket = await Socket.connect(ip, 4782);
              // サーバーに準備が出来たことを伝える
              socket.add(utf8.encode("ready"));
            } on SocketException catch (e) {
              Wakelock.disable();
              return _showErrorDialog(e, context);
            }

            // 進行を定期的に更新する
            Timer timer =
                Timer.periodic(const Duration(milliseconds: 300), (timer) {
              dialogSetState(() =>
                  progress = (receivedFile.lengthSync() / fileSize).toDouble());
            });
            // "ready"を送信するとデータが送られてくるので、そのStreamをIOSinkで書き込み
            // Listen上ではSocketのStreamを扱えないので二回通信する必要がある
            IOSink receieveSink =
                receivedFile.openWrite(mode: FileMode.writeOnly);
            // 終了時の処理(異常終了関係なし)
            void endProcess() {
              Wakelock.disable();
              socket.destroy();
              Navigator.of(context).pop();
              timer.cancel();
            }

            // 流れてきたデータをファイルに書き込む
            receieveSink.addStream(socket)
              ..then((_) async {
                try {
                  await receieveSink.flush();
                  await receieveSink.close();
                } on Exception catch (e) {
                  endProcess();
                  return _showErrorDialog(e, context);
                }
                endProcess();
                log.text += "Done.\n";
              })
              ..catchError((e) {
                endProcess();
                return _showErrorDialog(e, context);
              });

            // ファイル受信の進行状況を表示するダイアログを表示
            showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
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
                                  LinearProgressIndicator(
                                    value: progress,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    actions: <Widget>[
                      // TO DO キャンセルボタンの実装
                      TextButton(child: const Text("中止"), onPressed: () => null)
                    ],
                  );
                });
          } else {
            log.text += "filePath is null. exit....\n";
          }
        });
      })
      ..onError((e) {
        return _showErrorDialog(e, context);
      });
  }

  /// エラーのダイアログを表示する
  static Future<void> _showErrorDialog(Exception e, BuildContext context) {
    late String errorTitle;
    late String errorMessage;

    if (e is SocketException) {
      errorTitle = "通信エラー";
      errorMessage = "通信エラーが発生しました。\n入力された値が正しいか、ネットワークに問題が無いか確認してください。";
    } else if (e is IOException) {
      errorTitle = "I/Oエラー";
      errorMessage = "ファイルの読み書き中にエラーが発生しました。";
    } else {
      errorTitle = "不明なエラー";
      errorMessage = "エラーが発生しました。";
    }

    return showDialog(
        context: context,
        builder: (builder) {
          return AlertDialog(
            title: Text(errorTitle),
            content: Text(errorMessage + "\n詳細:\n" + e.toString()),
            actions: <Widget>[
              TextButton(
                child: const Text("閉じる"),
                onPressed: () => Navigator.pop(context),
              )
            ],
          );
        });
  }

  /// ファイルの保存場所をユーザーなどから取得
  static Future<String?> _getSavePath(String fileName) async {
    // Desktopはファイル保存のダイアログ経由
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      var savePicker = await FilePicker.platform
          .saveFile(dialogTitle: "ファイルの保存場所を選択...", fileName: fileName);
      return savePicker;
    } else if (Platform.isAndroid) {
      // 仮
      /* TO DO: ACTION_CREATE_DOCUMENT経由でユーザーが選択した場所に保存する */
      Directory? directory = await getExternalStorageDirectory();
      if (directory != null) {
        return directory.path + "/" + fileName;
      } else {
        return null;
      }
    } else if (Platform.isIOS) {
      // iOSはgetApplicationDocumentsDirectoryでもファイルアプリに表示可
      final directory = await getApplicationDocumentsDirectory();
      return directory.path + "/" + fileName;
    } else {
      return null;
    }
  }
}
