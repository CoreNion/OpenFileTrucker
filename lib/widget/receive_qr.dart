import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../class/qr_data.dart';

class ScanQRCodePage extends StatefulWidget {
  const ScanQRCodePage({super.key});

  @override
  State<ScanQRCodePage> createState() => _ScanQRCodePageState();
}

class _ScanQRCodePageState extends State<ScanQRCodePage> {
  final key = GlobalKey(debugLabel: "qrView");

  MobileScannerController cameraController = MobileScannerController();

  @override
  void initState() {
    super.initState();

    WakelockPlus.enable();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(25))),
      child: SizedBox(
        height: 600,
        child: Column(
          children: [
            AppBar(title: const Text("QRコードを読み取る"), actions: <Widget>[
              IconButton(
                  icon: const Icon(Icons.switch_camera_rounded),
                  onPressed: () => cameraController.switchCamera()),
              IconButton(
                  icon: const Icon(Icons.lightbulb),
                  onPressed: () => cameraController.toggleTorch())
            ]),
            Expanded(
              child: MobileScanner(
                controller: cameraController,
                onDetect: (barcodes) => _onQRDetect(barcodes, context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// QRコードを読み取ったときの処理
  void _onQRDetect(BarcodeCapture barcodes, BuildContext context) async {
    // 読み取りを一時停止 (重複防止)
    await cameraController.stop();

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
      await cameraController.start();
      return;
    }

    // 元のページにデータを送る
    Navigator.pop(context, data);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    cameraController.dispose();

    super.dispose();
  }
}
