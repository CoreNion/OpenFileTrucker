import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file_trucker/dialog.dart';
import 'package:open_file_trucker/qr_data.dart';
import 'package:open_file_trucker/receieve.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file_trucker/receieve_scan_qr_page.dart';
import 'package:wakelock/wakelock.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({Key? key}) : super(key: key);

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Widget> sucsessWidght = <Widget>[];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final formKey = GlobalKey<FormState>();
    String ip = "";
    // String key = "";

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
                _startReceive(result.ip);
              } else {
                Wakelock.disable();
              }
            });
          } else {
            EasyDialog.showPermissionAlert(
                "QRコードを読み取るためには、カメラへのアクセスの許可が必要です。", Navigator.of(context));
          }
        },
        tooltip: "QRコードを利用する",
        child: const Icon(Icons.qr_code),
      );
    } else {
      // 非対応端末では表示しない
      qrButton = null;
    }

    return SafeArea(
        child: Scaffold(
            body: Container(
              margin: const EdgeInsets.all(10),
              child: Form(
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
                    /* 
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Key (任意)',
                          hintText: 'Keyを入力(設定している場合のみ)',
                          icon: Icon(Icons.vpn_key)),
                      obscureText: true,
                      onSaved: (newValue) => key = newValue!,
                    ), */
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 30),
                      height: 40,
                      width: double.infinity,
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                          child: const Text("ファイルを受信"),
                          onPressed: () async {
                            // 値のチェック
                            if (formKey.currentState != null) {
                              if (formKey.currentState!.validate()) {
                                formKey.currentState!.save();
                                _startReceive(ip);
                              }
                            }
                          }),
                    ),
                    Column(children: sucsessWidght),
                  ],
                ),
              ),
            ),
            floatingActionButton: qrButton));
  }

  Future<void> _startReceive(String ip /*, String key  */) async {
    // 結果のメッセージを削除
    sucsessWidght.clear();

    final result = await ReceiveFile.receiveFile(ip, /* key, */ context);
    // ファイルの受信に成功したらメッセージを表示
    if (result) {
      sucsessWidght.add(const Text("ファイルの受信が完了しました",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 25, color: Colors.red, fontWeight: FontWeight.bold)));
      if (Platform.isIOS) {
        sucsessWidght.add(const Text(
            '\niOSではファイルは、アプリ用の外から読み書きが可能なフォルダーに格納されています。\n内蔵の「ファイル」アプリなどから閲覧/操作したり、他のアプリでのファイル選択時にこのアプリのフォルダーを閲覧することによって、利用可能です。',
            textAlign: TextAlign.start));
      }
      setState(() {});
    }
  }
}
