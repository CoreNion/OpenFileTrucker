import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ReceiveFile {
  static void receiveFile(String ip, TextEditingController log) async {
    // アプリ内部のストレージのパス
    final internalPath = (await getApplicationDocumentsDirectory()).path;
    log.text += "path: " + internalPath + "\n";

    Socket socket = await Socket.connect(ip, 4782);
    socket.listen((event) {
      final receivedFile = File("$internalPath/receivedFile");
      receivedFile.writeAsBytesSync(event, mode: FileMode.writeOnlyAppend);
    })
      ..onError((e) => log.text += "Err: " + e.toString())
      ..onDone(() => log.text += "Done.");
  }
}
