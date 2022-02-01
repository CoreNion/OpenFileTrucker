import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file_trucker/receieve.dart';

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
    );
  }
}
