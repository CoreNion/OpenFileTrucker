import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:webcrypto/webcrypto.dart';

import 'class/file_info.dart';
import 'class/send_settings.dart';
import 'class/trucker_device.dart';
import 'helper/gcm.dart';
import 'helper/incoming.dart';
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
            userInterfaceName = "インターネット共有 ($interfaceName)";
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

    // TODO: Live Photo(ディレクトリ)の対応
    var res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        dialogTitle: "送信するファイルを選択",
        type: type,
        allowCompression: true);
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
  static AesGcmSecretKey? _aesGcmSecretKey;

  static List<FileInfo>? fileInfo;
  static List<XFile> files = [];
  static int _totalSize = 0;

  /// ファイル送信用ののサーバーを立ち上げる
  static Future<void> serverStart(SendSettings settings) async {
    if (fileInfo == null || files.isEmpty) {
      throw Exception("ファイル情報がありません");
    }

    for (var element in fileInfo!) {
      _totalSize += element.size;
    }

    if (settings.encryptMode) {
      // AES-CBC暗号化用の鍵を生成
      _aesGcmSecretKey = await AesGcmSecretKey.generateKey(256);
    }

    _server = await ServerSocket.bind(settings.bindAdress, 4782);
    _server?.listen((event) => _serverListen(event, settings));

    if (settings.deviceDetection) {
      await registerNsd(ServiceType.send, settings.name);
    }
  }

  static int _byteCount = 0;

  static void _serverListen(Socket socket, SendSettings settings) async {
    final bool encrypt = settings.encryptMode;

    socket.listen((event) async {
      if (listEquals(event.sublist(0, 5), plainTextHeader)) {
        if (encrypt) {
          // 公開鍵を記録
          final data = event.sublist(5);
          pubKey = await RsaOaepPublicKey.importSpkiKey(data, Hash.sha512);

          // AES暗号化用の鍵を公開鍵で暗号化し、送信
          socket.add(await pubKey!
              .encryptBytes(await _aesGcmSecretKey!.exportRawKey()));
        } else {
          // 暗号化モードが無効であることを知らせる
          socket.add(plainTextHeader);
        }
      } else {
        late String strData;

        // IVを取得
        late Uint8List iv;
        if (encrypt) {
          iv = event.sublist(0, 16);
          final rawData = event.sublist(16);
          strData =
              utf8.decode(await _aesGcmSecretKey!.decryptBytes(rawData, iv));
        } else {
          strData = utf8.decode(event);
        }

        // UUIDを取得
        final uuid = strData.substring(0, 36);
        final mesg = strData.substring(36);

        if (mesg.contains("second")) {
          // クライアント側にファイル情報を送信
          final rawFileInfo = Stream.value(utf8.encode(json.encode(fileInfo)));
          await socket.addStream(encrypt
              ? encryptGcmStream(rawFileInfo, _aesGcmSecretKey!, iv)
              : rawFileInfo);
          socket.destroy();
        } else {
          // 指定されたn番目のファイルを送信
          int? fileNumber = int.tryParse(mesg);

          // リクエストからの場合は進捗を更新
          final byRequest = viaServiceDevice.keys.contains(uuid);
          final StreamTransformer<Uint8List, Uint8List> progTransformer =
              StreamTransformer.fromHandlers(handleData: (data, sink) {
            if (byRequest) {
              _byteCount += data.length;
              viaServiceDevice[uuid]?.progress = _byteCount / _totalSize;
              refreshUserInfo();
            }
            sink.add(data);
          });

          if (fileNumber != null) {
            // ファイル読み込みStream
            final readFileStream = files[fileNumber].openRead().transform(
                  progTransformer,
                );
            // 暗号化Streamまたは生Streamを送信
            await socket
                .addStream(encrypt
                    ? encryptGcmStream(readFileStream, _aesGcmSecretKey!, iv)
                    : readFileStream)
                .catchError((e) {
              if (byRequest) {
                viaServiceDevice[uuid]?.progress = 1;
                viaServiceDevice[uuid]?.status = TruckerStatus.failed;
                refreshUserInfo();
              }
            });
            socket.destroy();

            if (fileNumber == files.length - 1) {
              // 全ファイルの送信が完了した場合
              if (byRequest) {
                _byteCount = 0;
                
                viaServiceDevice[uuid]?.progress = 1;
                viaServiceDevice[uuid]?.status = TruckerStatus.sendReady;
                refreshUserInfo();
              }
            }
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
    _aesGcmSecretKey = null;

    unregisterNsd(ServiceType.send);
  }
}

/// 簡易的なネットワーク情報
class TruckerNetworkInfo {
  final String interfaceName;

  final String ip;

  TruckerNetworkInfo({required this.interfaceName, required this.ip});
}
