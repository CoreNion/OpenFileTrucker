import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_sizes/file_sizes.dart';
import 'package:flutter/material.dart';
import 'package:open_file_trucker/send.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dotted_border/dotted_border.dart';

class SendPage extends StatefulWidget {
  const SendPage({Key? key}) : super(key: key);

  @override
  _SendPageState createState() => _SendPageState();
}

class _SendPageState extends State<SendPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late bool isSmallUI;
  late FilePickerResult? selectedFile;
  static Text firstFileButtonText = const Text(
    "ファイルを選択\nまたはドラック&ドロップ",
    style: TextStyle(fontSize: 30, color: Colors.blue),
  );
  Text selectFileButtonText = firstFileButtonText;
  late String fileName;
  String serverStatus = "";
  String ipText = "";
  String keyText = "";
  Widget qrCode = Container();
  Widget stopServerButton = Container();

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // サイズごとにUIを変える
        final pageWidth = constraints.maxWidth;
        if (pageWidth >= 800) {
          isSmallUI = false;
          return largeUI();
        } else {
          isSmallUI = true;
          /* if (qrCode is QrImage) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (builder) => _pushQRPageForSmallScreen(context)));
          } */
          return smallUI();
        }
      },
    );
  }

  /// 大きな画面やウィンドウに最適化された送信ページのUI
  Scaffold largeUI() {
    return Scaffold(
        body: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 5, child: selectFileArea()),
            Expanded(
                flex: 5,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                        left: BorderSide(
                      color: Colors.grey,
                    )),
                  ),
                  child: senderInfoArea(),
                ))
          ],
        ),
        floatingActionButton: stopServerButton);
  }

  /// 小さな画面やウィンドウに最適化された送信ページのUI
  Scaffold smallUI() {
    return Scaffold(
        body: selectFileArea(), floatingActionButton: stopServerButton);
  }

  /// ファイルを選択する部分のUI
  Container selectFileArea() {
    return Container(
      margin: const EdgeInsets.all(10),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              // TO DO ドラック&ドロップの実装
              flex: 7,
              child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  child: DottedBorder(
                    color: Colors.blueAccent,
                    strokeWidth: 3,
                    dashPattern: const [30, 5],
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            primary: Colors.transparent,
                            elevation: 0,
                            shadowColor: Colors.black38),
                        child: selectFileButtonText,
                        onPressed: () async {
                          var _selectedFile =
                              await FilePicker.platform.pickFiles();
                          if (!(_selectedFile == null)) {
                            selectedFile = _selectedFile;
                            fileName = _selectedFile.names[0]!;
                            setState(() {
                              selectFileButtonText = Text(
                                "選択されたファイル:\n" +
                                    fileName +
                                    " " +
                                    FileSize.getSize(
                                        _selectedFile.files[0].size),
                                style: const TextStyle(
                                    color: Colors.blue, fontSize: 20),
                              );
                            });
                          } else {
                            setState(() {
                              selectFileButtonText = firstFileButtonText;
                              selectedFile = null;
                            });
                          }
                        },
                      ),
                    ),
                  )),
            ),
            Expanded(
              flex: 1,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blueGrey,
                    onPrimary: Colors.white,
                  ),
                  child: const Text("Send"),
                  onPressed: () {
                    // ファイル選択時のみ実行
                    if (selectedFile != null) {
                      SendFiles.selectNetwork(context).then((ip) {
                        if (!(ip == null)) {
                          var file = File(selectedFile!.files.single.path!);
                          SendFiles.serverStart(ip, "no", file).then((qr) {
                            qrCode = qr;
                            serverStatus = "受信待機中です。";
                            ipText = "ip: " + ip;
                            stopServerButton = FloatingActionButton(
                              onPressed: _stopShareProcess,
                              tooltip: '共有を停止する',
                              child: const Icon(Icons.stop),
                            );
                            if (isSmallUI) {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) =>
                                    _pushQRPageForSmallScreen(context),
                              ));
                            } else {
                              setState(() {});
                            }
                          });
                        } else {
                          showDialog(
                              context: context,
                              builder: (context) =>
                                  _showSmallInfo(context, "ネットワークに接続してください。"));
                        }
                      });
                    } else {
                      showDialog(
                          context: context,
                          builder: (context) =>
                              _showSmallInfo(context, "ファイルを選択してください。"));
                    }
                  },
                ),
              ),
            ),
          ]),
    );
  }

  /// QRコードやIPアドレスが書かれる部分のUI
  Widget senderInfoArea() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            serverStatus,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.red, fontSize: 20),
          ),
          qrCode,
          Text(
            ipText,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 30),
          ),
          Text(
            keyText,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  void _stopShareProcess() {
    SendFiles.serverClose();
    setState(() {
      qrCode = Container();
      serverStatus = "";
      ipText = "";
      stopServerButton = Container();
    });
  }

  Widget _showSmallInfo(BuildContext context, String text) {
    return AlertDialog(
      title: Text(text),
      actions: <Widget>[
        TextButton(
          child: const Text("OK"),
          onPressed: () => Navigator.pop(context),
        )
      ],
    );
  }

  LayoutBuilder _pushQRPageForSmallScreen(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
            appBar: AppBar(
              title: RichText(
                textAlign: TextAlign.start,
                text: TextSpan(
                    text: "受信待機中です",
                    style: const TextStyle(fontSize: 22),
                    children: <TextSpan>[
                      TextSpan(
                        text: '\n' + fileName,
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ]),
              ),
              leading: IconButton(
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (_) {
                          return AlertDialog(
                            title: const Text("確認"),
                            content: const Text("共有を停止してもよろしいですか？"),
                            actions: <Widget>[
                              TextButton(
                                child: const Text("はい"),
                                onPressed: () {
                                  _stopShareProcess();
                                  // AlertDialogの分のcontextもあるので二回前の階層に戻る
                                  Navigator.of(context)
                                    ..pop()
                                    ..pop();
                                },
                              ),
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("いいえ"))
                            ],
                          );
                        });
                  },
                  icon: const Icon(Icons.stop)),
            ),
            body: senderInfoArea());
      },
    );
  }
}
