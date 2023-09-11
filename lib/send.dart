import 'dart:convert';
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webcrypto/webcrypto.dart';

import 'class/file_info.dart';
import 'helper/service.dart';

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
  static RsaOaepPublicKey? pubKey;
  static AesCbcSecretKey? _aesCbcSecretKey;

  /// ファイル送信用ののサーバーを立ち上げる
  static Future<void> serverStart(String ip,
      /* String key, */ List<XFile> files, List<Uint8List>? hashs) async {
    // AES-CBC暗号化用の鍵を生成
    _aesCbcSecretKey = await AesCbcSecretKey.generateKey(256);

    _server = await ServerSocket.bind(ip, 4782);
    _server?.listen((event) => _serverListen(event, files, hashs));

    await registerNsd();
  }

  static void _serverListen(
      Socket socket, List<XFile> files, List<Uint8List>? hashs) {
    socket.listen((event) async {
      if (listEquals(event.sublist(0, 5), plainTextHeader)) {
        // 公開鍵を記録
        final data = event.sublist(5);
        pubKey = await RsaOaepPublicKey.importSpkiKey(data, Hash.sha512);

        // AES-CBC暗号化用の鍵を公開鍵で暗号化し、送信
        socket.add(
            await pubKey!.encryptBytes(await _aesCbcSecretKey!.exportRawKey()));
      } else {
        // IVを作成/取得
        final sendIV = Uint8List(16);
        fillRandomBytes(sendIV);
        final recIV = event.sublist(0, 16);
        final data = event.sublist(16);

        final decryptMesg =
            utf8.decode(await _aesCbcSecretKey!.decryptBytes(data, recIV));
        if (decryptMesg == "second") {
          // クライアント側にファイル情報を送信
          List<String> names = <String>[];
          List<int> sizes = <int>[];
          for (var i = 0; i < files.length; i++) {
            names.add(basename(files[i].path));
            sizes.add(await files[i].length());
          }

          socket.add([
            ...sendIV,
            ...await _aesCbcSecretKey!.encryptBytes(
                utf8.encode(json.encode(
                    FileInfo(names: names, sizes: sizes, hashs: hashs)
                        .toMap())),
                sendIV)
          ]);
          socket.destroy();
        } else {
          // n番目のファイルを送信
          int? fileNumber = int.tryParse(decryptMesg);
          if (fileNumber != null) {
            await socket.addStream(_aesCbcSecretKey!
                .encryptStream(files[fileNumber].openRead(), recIV));
            socket.destroy();
          } else {
            socket.destroy();
          }
        }
      }
    });
  }

  /// ファイル送信サーバーを閉じる
  static void serverClose() {
    _server?.close();
    pubKey = null;
    _aesCbcSecretKey = null;

    unregisterNsd();
  }
}

/// 簡易的なネットワーク情報
class TruckerNetworkInfo {
  final String interfaceName;

  final String ip;

  TruckerNetworkInfo({required this.interfaceName, required this.ip});
}
