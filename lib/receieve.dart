import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ReceiveFile {
  static void receiveFile(String ip, TextEditingController log) async {
    String fileName;
    bool ready = false;
    late File receivedFile;

    Socket socket = await Socket.connect(ip, 4782);
    socket.listen((event) {
      if (!ready && String.fromCharCodes(event).startsWith("name")) {
        // "name:"部を消去
        fileName = String.fromCharCodes(event).substring(5);
        // 保存場所を取得
        _getSavePath(fileName).then((path) {
          if (path != null) {
            receivedFile = File(path);
            // 準備が完了したことを送信
            ready = true;
            socket.add(utf8.encode("ready"));
          } else {
            socket.close();
            log.text = "filePath is null. exit....\n";
          }
        });
      } else {
        // 準備完了後にファイルが送られてくる
        /* TO DO: openWrite方式への変更 */
        receivedFile.writeAsBytesSync(event, mode: FileMode.writeOnlyAppend);
      }
    })
      ..onError((e) => log.text += "Err: " + e.toString())
      ..onDone(() => log.text += "Done.");
    /* TO DO: 受信中のUI作成 */
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
