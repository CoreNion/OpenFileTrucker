import 'dart:convert';
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file_trucker/widget/dialog.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:open_file_trucker/qr_data.dart';
import 'package:wakelock/wakelock.dart';

class SendFiles {
  /// 利用するネットワークを選択する関数
  static Future<String?> selectNetwork(BuildContext context) async {
    // ネットワーク一覧のDialogOptionのList
    List<SimpleDialogOption> dialogOptions = [];

    // スリープ無効化
    Wakelock.enable();

    // NetworkInterfaceからIPアドレスを取得
    List<String> addressList = [];
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
      if (strAddr.isNotEmpty) {
        void addOption() {
          addressList.add(strAddr);
          late String userInterfaceName;

          // インターフェースの名前を分かりやすくする(Unix系のみ)
          if (interfaceName.contains(RegExp("wlan|wl|wlp|ath"))) {
            userInterfaceName = "無線LAN ($interfaceName)";
          } else if (interfaceName.contains(RegExp("eth|en"))) {
            userInterfaceName = "ネットワーク ($interfaceName)";
          } else if (interfaceName.contains(RegExp("bridge|ap"))) {
            userInterfaceName = "テザリング(アクセスポイント)/インターネット共有 ($interfaceName)";
          } else {
            userInterfaceName = interfaceName;
          }

          dialogOptions.add(SimpleDialogOption(
            onPressed: () => Navigator.pop(context, strAddr),
            child: Text("$userInterfaceName $strAddr"),
          ));
        }

        // Androidではwlan/eth系、iOSではen/ap/bridge系のみのみ表示
        if (Platform.isAndroid || Platform.isIOS) {
          if (interfaceName
              .contains(RegExp("wlan|wl|wlp|ath|eth|en|ap|bridge"))) {
            addOption();
          }
        } else {
          addOption();
        }
      }
    }

    if (dialogOptions.isEmpty) {
      return null;
    } else if (addressList.length == 1) {
      return addressList[0];
    } else {
      return showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return WillPopScope(
              // 戻る無効化
              onWillPop: () => Future.value(false),
              child: SimpleDialog(
                title: const Text("利用するネットワークを選択してください。"),
                children: dialogOptions,
              ));
        },
      );
    }
  }

  /// ファイルを選択する関数
  static Future<List<File>?> pickFiles(
      {required BuildContext context, FileType type = FileType.any}) async {
    List<File> files = <File>[];

    if (Platform.isAndroid && await Permission.storage.request().isDenied) {
      EasyDialog.showPermissionAlert(
          "ファイルを参照するには、ストレージへのアクセス権限が必要です。", Navigator.of(context));
      return null;
    }

    var res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        dialogTitle: "送信するファイルを選択",
        type: type,
        allowCompression: false);
    if (!(res == null)) {
      // 選択されたファイルの情報を記録
      for (var i = 0; i < res.files.length; i++) {
        files.add(File(res.files[i].path!));
      }
      return files;
    } else {
      return null;
    }
  }

  static ServerSocket? _server;

  static Future<QrImage> serverStart(String ip,
      /* String key, */ List<XFile> files, List<Uint8List>? hashs) async {
    _server = await ServerSocket.bind(ip, 4782);
    _server?.listen((event) => _serverListen(event, files, hashs));

    return QrImage(
      data: json.encode(QRCodeData(
        ip: ip, /* key: key */
      ).toJson()),
      size: 300,
      backgroundColor: Colors.white,
    );
  }

  static void _serverListen(
      Socket socket, List<XFile> files, List<Uint8List>? hashs) {
    socket.listen((event) async {
      String mesg = utf8.decode(event);
      if (mesg == "first") {
        // 1回目の場合、ファイルの各情報を送って一旦close(受信の処理の都合で1回の通信では送らない)
        List<String> nameList = <String>[];
        List<int> lengthList = <int>[];
        for (var i = 0; i < files.length; i++) {
          nameList.add(basename(files[i].path));
          lengthList.add(await files[i].length());
        }
        if (!(hashs == null)) {
          socket.add(utf8.encode(json.encode({
            "nameList": nameList,
            "lengthList": lengthList,
            "hashList": hashs
          })));
        } else {
          socket.add(utf8.encode(
              json.encode({"nameList": nameList, "lengthList": lengthList})));
        }
        socket.destroy();
      } else {
        int? fileNumber = int.tryParse(mesg);
        if (fileNumber != null) {
          await socket.addStream(files[fileNumber].openRead());
          socket.destroy();
        } else {
          socket.destroy();
        }
      }
    });
  }

  static void serverClose() {
    _server?.close();

    if (Platform.isIOS || Platform.isAndroid) {
      // キャッシュ削除
      FilePicker.platform.clearTemporaryFiles();
    }
    // スリープ有効化
    Wakelock.disable();
  }
}
