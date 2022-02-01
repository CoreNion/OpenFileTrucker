import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:open_file_trucker/qr_data.dart';
import 'package:wakelock/wakelock.dart';

class SendFiles {
  static Future<String?> selectNetwork(BuildContext context) async {
    // ネットワーク一覧のDialogOptionのList
    List<SimpleDialogOption> dialogOptions = [];

    // スリープ無効化
    Wakelock.enable();

    // NetworkInterfaceからIPアドレスを取得
    for (NetworkInterface interface in await NetworkInterface.list()) {
      String strAddr = "";
      String interfaceName = interface.name;
      for (InternetAddress addr in interface.addresses) {
        // IPv4/プライベートIPのみ取得
        if (addr.type == InternetAddressType.IPv4 ||
            addr.toString().startsWith(RegExp("192|172|10"))) {
          strAddr = addr.address.toString();
        }
      }

      // 条件に合う場合のみdialogOptionsに追加
      // To Do: モバイル通信の検知
      if (strAddr.isNotEmpty) {
        dialogOptions.add(SimpleDialogOption(
          onPressed: () => Navigator.pop(context, strAddr),
          child: Text(interfaceName + " " + strAddr),
          // 表示例: "Wi-Fi 192.168.0.10"
        ));
      }
    }

    // To Do ネットワークが一つの時はダイアログを出さないようにする
    if (dialogOptions.isEmpty) {
      return null;
    } else {
      return showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text("利用するネットワークを選択してください。"),
            children: dialogOptions,
          );
        },
      );
    }
  }

  static ServerSocket? _server;

  static Future<QrImage> serverStart(String ip, String key, File file) async {
    _server = await ServerSocket.bind(ip, 4782);
    _server?.listen((event) => _serverListen(event, file));

    return QrImage(
      data: json.encode(QRCodeData(ip: ip, key: key).toJson()),
      size: 300,
    );
  }

  static void _serverListen(Socket socket, File file) {
    socket.listen((event) {
      String mesg = String.fromCharCodes(event);
      if (mesg == "first") {
        // 1回目の場合、ファイルの各情報を送って一旦close(受信の処理の都合で1回の通信では送らない)
        Map<String, dynamic> fileInfo = {
          "name": file.uri.pathSegments.last,
          "length": file.lengthSync()
        };
        socket.add(utf8.encode(json.encode(fileInfo)));
        socket.close();
      }
      if (mesg == "ready") {
        // 受信側の準備が出来たら2回目の通信でファイルを送信
        socket.addStream(file.openRead()).then((e) => socket.close());
      }
    });
  }

  static void serverClose() {
    _server?.close();
    // スリープ有効化
    Wakelock.disable();
  }
}
