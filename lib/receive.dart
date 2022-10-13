import 'dart:async';
import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_sizes/file_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sodium_libs/sodium_libs.dart';
import 'package:wakelock/wakelock.dart';
import 'package:open_file_trucker/widget/dialog.dart';
import 'dart:io';

class ReceiveFile {
  /// ファイルの受信の処理をする関数
  static Future<bool> receiveFile(
      String ip, /* String key */ BuildContext context) async {
    final nav = Navigator.of(context);
    late ConnectionTask<Socket> connectionTask;
    late Socket socket;

    // ダイアログ表示
    showDialog(
        context: context,
        builder: (_) {
          return WillPopScope(
            // 戻る無効化
            onWillPop: () => Future.value(false),
            child: const AlertDialog(
              title: Text(
                "接続しています...",
                textAlign: TextAlign.center,
              ),
            ),
          );
        });

    //スリープ無効化
    Wakelock.enable();

    // 最初の接続を開始
    socket =
        await Socket.connect(ip, 4782, timeout: const Duration(seconds: 10));
    socket.add(utf8.encode("first"));

    // ファイルの情報を受信
    late List<String> fileName;
    late List<int> fileSize;
    late List<Uint8List>? hashs;
    // ファイルの情報を取得したら一旦通信終了される
    await socket.listen((event) {
      // 各情報を保存
      Map<String, dynamic> fileInfo = json.decode(utf8.decode(event));
      fileName = fileInfo["nameList"].cast<String>();
      fileSize = fileInfo["lengthList"].cast<int>();
      // cast<List<Uint8List>>が効かないのでmapを介す
      if (fileInfo.containsKey("hashList")) {
        hashs = (fileInfo["hashList"] as List<dynamic>)
            .map((subList) =>
                Uint8List.fromList((subList as List<dynamic>).cast<int>()))
            .toList();
      } else {
        hashs = null;
      }
    }).asFuture<void>();

    // 終了次第「接続しています」のダイアログを消す
    nav.pop();
    // ファイルの保存場所を取得(聞く)
    String? path = await _getSavePath(fileName, nav);
    if (path != null) {
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
        socket.destroy();

        // キャッシュ削除
        FilePicker.platform.clearTemporaryFiles();

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
      }

      // ハッシュ計算
      if (!(hashs == null) && !pushCancelButton) {
        // 進捗のダイアログを消す
        nav.pop();

        // ダイアログ表示
        showDialog(
            context: context,
            builder: (_) {
              return WillPopScope(
                // 戻る無効化
                onWillPop: () => Future.value(false),
                child: const AlertDialog(
                  title: Text(
                    "整合性を確認しています...",
                    textAlign: TextAlign.center,
                  ),
                  content: Text("ファイルの大きさなどによっては、時間がかかる場合があります。"),
                ),
              );
            });

        final sodium = await SodiumInit.init();
        late Uint8List receieHash;

        // 各ファイルのハッシュ値を確認
        for (var i = 0; i < fileName.length; i++) {
          final Uint8List origHash = hashs![i];
          final XFile file = fileName.length < 2
              ? XFile(path)
              : XFile(p.join(path, fileName[i]));

          receieHash =
              await sodium.crypto.genericHash.stream(messages: file.openRead());

          if (!(listEquals(origHash, receieHash))) {
            endProcess();

            throw FileSystemException(
                "ファイルはダウンロードされましたが、整合性が確認できませんでした。\n安定した環境でファイルの共有を行ってください。",
                file.path);
          }
        }
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
    } else {
      return false;
    }
  }

  /// ファイルの保存場所をユーザーなどから取得
  static Future<String?> _getSavePath(
      List<String> fileName, NavigatorState nav) async {
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
