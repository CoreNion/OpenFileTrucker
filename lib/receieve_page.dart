import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file_trucker/qr_data.dart';
import 'package:open_file_trucker/receieve.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file_trucker/receieve_scan_qr_page.dart';
import 'package:wakelock/wakelock.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({Key? key}) : super(key: key);

  @override
  _ReceivePageState createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final formKey = GlobalKey<FormState>();
    String ip = "";
    String key = "";
    TextEditingController logController = TextEditingController();

    late Widget? qrButton;
    if (Platform.isIOS || Platform.isAndroid) {
      qrButton = FloatingActionButton(
        onPressed: () async {
          // 権限の確認
          if (await Permission.camera.request().isGranted) {
            Navigator.of(context)
                .push(MaterialPageRoute(
                    builder: (builder) => const ScanQRCodePage()))
                .then((result) {
              if (result is QRCodeData) {
                ReceiveFile.receiveFile(result.ip, logController, context);
              } else {
                Wakelock.disable();
              }
            });
          } else {
            showDialog(
                context: context,
                builder: (_) {
                  return AlertDialog(
                    title: const Text("カメラへのアクセスの権限が必要です"),
                    content: const Text("QRコードを読み取るためには、カメラへのアクセスの許可が必要です。"),
                    actions: <Widget>[
                      TextButton(
                        child: const Text("設定を開く"),
                        onPressed: () => openAppSettings(),
                      ),
                      TextButton(
                        child: const Text("閉じる"),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  );
                });
          }
        },
        tooltip: "QRコードを利用する",
        child: const Icon(Icons.qr_code),
      );
    } else {
      // 非対応端末では表示しない
      qrButton = null;
    }

    return Scaffold(
        body: Container(
          margin: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'IP Address',
                        hintText: 'IPアドレスを入力',
                        icon: Icon(Icons.connect_without_contact),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '値を入力してください';
                        } else if (!RegExp(
                                r"^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$")
                            .hasMatch(value)) {
                          return "IPアドレスを入力してください。";
                        }
                        return null;
                      },
                      onSaved: (newValue) => ip = newValue!,
                    ),
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Key (任意)',
                          hintText: 'Keyを入力(設定している場合のみ)',
                          icon: Icon(Icons.vpn_key)),
                      obscureText: true,
                      onSaved: (newValue) => key = newValue!,
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      height: 40,
                      width: double.infinity,
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            primary: Colors.blueGrey,
                            onPrimary: Colors.white,
                          ),
                          child: const Text("ファイルを受信"),
                          onPressed: () async {
                            if (formKey.currentState != null) {
                              // TO DO:値のチェック
                              if (formKey.currentState!.validate()) {
                                formKey.currentState!.save();
                                ReceiveFile.receiveFile(
                                    ip, logController, context);
                              }
                            }
                          }),
                    ),
                  ],
                ),
              ),
              // ログ出力
              TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  maxLines: null,
                  controller: logController),
            ],
          ),
        ),
        floatingActionButton: qrButton);
  }
}
