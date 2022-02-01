import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ReceiveFile {
  static void receiveFile(String ip, TextEditingController log) async {
    late String fileName;
    // ローカルの保存するファイル
    late File receivedFile;

    Socket socket = await Socket.connect(ip, 4782);

    // 最初の通信であることを送信
    socket.add(utf8.encode("first"));
    socket.listen((event) {
      // ファイルの情報が送られてくる
      fileName = String.fromCharCodes(event).substring(5);
    })
      // ファイルの情報を取得したら一旦通信終了される
      ..onDone(() {
        // ファイルの保存場所を取得(聞く)
        _getSavePath(fileName).then((path) async {
          if (path != null) {
            receivedFile = File(path);

            // 2回目の通信でファイルを受信
            socket = await Socket.connect(ip, 4782);
            // サーバーに準備が出来たことを伝える
            socket.add(utf8.encode("ready"));
            // "ready"を送信するとデータが送られてくるので、そのStreamをIOSinkで書き込み
            // Listen上ではSocketのStreamを扱えないので二回通信する必要がある
            IOSink receieveSink =
                receivedFile.openWrite(mode: FileMode.writeOnly);
            receieveSink.addStream(socket).whenComplete(() async {
              await receieveSink.flush();
              await receieveSink.close();
              log.text += "Done.\n";
            });
          } else {
            log.text += "filePath is null. exit....\n";
          }
        });
      })
      ..onError((e) => log.text += "Err: " + e.toString());
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
      getExternalStorageDirectory().then((directory) {
        if (directory != null) {
          return directory.path + "/" + fileName;
        } else {
          return null;
        }
      });
    } else if (Platform.isIOS) {
      // iOSはgetApplicationDocumentsDirectoryでもファイルアプリに表示可
      final directory = await getApplicationDocumentsDirectory();
      return directory.path + "/" + fileName;
    } else {
      return null;
    }
  }
}
