import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'class/file_info.dart';
import 'class/qr_data.dart';

class SendFiles {
  /// FileTruckerで利用可能なネットワーク一覧を取得
  static Future<List<TruckerNetworkInfo>?> getAvailableNetworks() async {
    List<TruckerNetworkInfo> addressList = [];

    // NetworkInterfaceから情報を取得
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

      // 条件に合う場合のみlistに追加
      if (strAddr.isNotEmpty) {
        void addList() {
          late String userInterfaceName;

          // 既知のインターフェースの名前を分かりやすくする
          if (interfaceName.contains(RegExp("wlan|wl|wlp|ath"))) {
            userInterfaceName = "無線LAN ($interfaceName)";
          } else if (interfaceName.contains(RegExp("eth|en"))) {
            userInterfaceName = "ネットワーク ($interfaceName)";
          } else if (interfaceName.contains(RegExp("bridge|ap"))) {
            userInterfaceName = "テザリング(アクセスポイント)/インターネット共有 ($interfaceName)";
          } else {
            userInterfaceName = interfaceName;
          }

          addressList.add(TruckerNetworkInfo(
              interfaceName: userInterfaceName, ip: strAddr));
        }

        // Androidではwlan/eth系、iOSではen/ap/bridge系のみ追加(それ以外は基本的に意味が無いため)
        if (Platform.isAndroid || Platform.isIOS) {
          if (interfaceName
              .contains(RegExp("wlan|wl|wlp|ath|eth|en|ap|bridge"))) {
            addList();
          }
        } else {
          addList();
        }
      }
    }

    if (addressList.isEmpty) {
      return null;
    } else {
      return addressList;
    }
  }

  /// ファイルを選択する関数
  static Future<List<File>?> pickFiles({FileType type = FileType.any}) async {
    List<File> files = <File>[];

    if (Platform.isAndroid && await Permission.storage.request().isDenied) {
      return null;
    }

    var res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        dialogTitle: "送信するファイルを選択",
        type: type,
        allowCompression: false);
    if (!(res == null)) {
      // 選択されたファイルの情報をFile形式で記録
      for (var i = 0; i < res.files.length; i++) {
        files.add(File(res.files[i].path!));
      }
      return files;
    } else {
      return null;
    }
  }

  static ServerSocket? _server;
  static late RawDatagramSocket _datagramSocket;
  static late Timer _broadcastTask;

  /// ファイル送信用のサーバーとブロードキャストを立ち上げる
  static Future<QrImage> serverStart(String ip,
      /* String key, */ List<XFile> files, List<Uint8List>? hashs) async {
    _server = await ServerSocket.bind(ip, 4782);
    _server?.listen((event) => _serverListen(event, files, hashs));

    // 1秒ごとに送信側の情報をブロードキャストする
    _datagramSocket = await RawDatagramSocket.bind(ip, 4783);
    _datagramSocket.broadcastEnabled = true;
    _broadcastTask = Timer.periodic(const Duration(seconds: 1), (timer) {
      _datagramSocket.send(utf8.encode('FROM_FILE_TRUCKER'),
          InternetAddress("255.255.255.255"), 4783);
    });

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
        // クライアント側にファイル情報を送信
        List<String> names = <String>[];
        List<int> sizes = <int>[];
        for (var i = 0; i < files.length; i++) {
          names.add(basename(files[i].path));
          sizes.add(await files[i].length());
        }

        socket.add(utf8.encode(json.encode(
            FileInfo(names: names, sizes: sizes, hashs: hashs).toMap())));

        socket.destroy();
      } else {
        // n番目のファイルを送信
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

  /// ファイル送信サーバーとブロードキャストを閉じる
  static void serverClose() {
    _server?.close();

    _broadcastTask.cancel();
    _datagramSocket.close();
  }
}

/// 簡易的なネットワーク情報
class TruckerNetworkInfo {
  final String interfaceName;

  final String ip;

  TruckerNetworkInfo({required this.interfaceName, required this.ip});
}
