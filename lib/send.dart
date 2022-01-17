import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:open_file_trucker/qr_data.dart';

class SendFiles {
  static Future<QrImage> serverStart() async {
    // To Do:ネットワークに接続されていないときの処理を追加

    final localIP = await NetworkInfo().getWifiIP() ?? "Unknwon";
    return QrImage(
      data: json.encode(QRCodeData(ip: localIP, key: "no").toJson()),
      size: 300,
    );
  }
}
