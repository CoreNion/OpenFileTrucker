import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wakelock/wakelock.dart';

import '../class/qr_data.dart';

class ScanQRCodePage extends StatefulWidget {
  const ScanQRCodePage({Key? key}) : super(key: key);

  @override
  State<ScanQRCodePage> createState() => _ScanQRCodePageState();
}

class _ScanQRCodePageState extends State<ScanQRCodePage> {
  final key = GlobalKey(debugLabel: "qrView");

  MobileScannerController cameraController = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    Wakelock.enable();

    return Scaffold(
      appBar: AppBar(title: const Text("QRコードを読み取る"), actions: <Widget>[
        IconButton(
            icon: const Icon(Icons.switch_camera_rounded),
            onPressed: () => cameraController.switchCamera()),
        IconButton(
            icon: const Icon(Icons.lightbulb),
            onPressed: () => cameraController.toggleTorch())
      ]),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 10,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (barcodes) => _onQRDetect(barcodes, context),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRDetect(BarcodeCapture barcodes, BuildContext context) async {
    late QRCodeData data;
    try {
      data =
          QRCodeData.fromJson(json.decode(barcodes.barcodes.first.rawValue!));
    } catch (e) {
      setState(() {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "対応していない形式のQRコードです。\n両方の端末のバージョンが合っているか確認するか、正しいQRコードを読み取ってください。"),
            duration: Duration(seconds: 6),
          ),
        );
      });
      return;
    }
    // 元のページにデータを送る
    Navigator.of(context).pop(data);
  }
}
