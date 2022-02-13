import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:wakelock/wakelock.dart';
import 'package:open_file_trucker/qr_data.dart';

class ScanQRCodePage extends StatefulWidget {
  const ScanQRCodePage({Key? key}) : super(key: key);

  @override
  _ScanQRCodePageState createState() => _ScanQRCodePageState();
}

class _ScanQRCodePageState extends State<ScanQRCodePage> {
  final key = GlobalKey(debugLabel: "qrView");

  @override
  Widget build(BuildContext context) {
    Wakelock.enable();

    return Scaffold(
      appBar: AppBar(
        title: const Text("QRコードを読み取る"),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 10,
            child: QRView(
                key: key,
                onQRViewCreated: (qVC) => _onQRViewCreated(qVC, context)),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(
      QRViewController qrViewController, BuildContext context) {
    qrViewController.scannedDataStream.listen((scanData) {
      final QRCodeData senderData;
      try {
        senderData = QRCodeData.fromJson(json.decode(scanData.code!));
      } catch (e) {
        setState(() {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text("対応していない形式のQRコードです。\nバージョンを確認するか、正しいQRコードを読み取ってください。"),
              duration: Duration(seconds: 6),
            ),
          );
        });
        return;
      }
      qrViewController.dispose();
      // 元のページにデータを送る
      Navigator.of(context).pop(senderData);
    });
  }
}
