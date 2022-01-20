import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file_trucker/send.dart';

class SendPage extends StatefulWidget {
  const SendPage({Key? key}) : super(key: key);

  @override
  _SendPageState createState() => _SendPageState();
}

class _SendPageState extends State<SendPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late FilePickerResult selectedFile;
  String fileDataText = "";
  String serverStatus = "";
  Widget qrCode = Container();
  Widget stopServerButton = Container();

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
        body: Container(
          margin: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              // ファイル選択ボタン
              SizedBox(
                // width最大化
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                  ),
                  child: const Text("Select file..."),
                  onPressed: () async {
                    var _selectedFile = await FilePicker.platform.pickFiles();
                    if (!(_selectedFile == null)) {
                      selectedFile = _selectedFile;
                      setState(() {
                        fileDataText = selectedFile.toString();
                      });
                    } else {
                      setState(() {
                        fileDataText = "File not selected.";
                      });
                    }
                  },
                ),
              ),
              Text(
                fileDataText,
                style: const TextStyle(),
              ),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blueGrey,
                    onPrimary: Colors.white,
                  ),
                  child: const Text("Send"),
                  onPressed: () {
                    // ファイル選択時のみ実行
                    if (!(fileDataText == "File not selected." ||
                        fileDataText == "")) {
                      SendFiles.selectNetwork(context).then((ip) {
                        if (!(ip == null)) {
                          SendFiles.serverStart(ip, "no")
                              .then((qr) => setState(() {
                                    qrCode = qr;
                                    serverStatus = "受信待機中です。";
                                    stopServerButton = FloatingActionButton(
                                      onPressed: () {
                                        SendFiles.serverClose();
                                        setState(() {
                                          qrCode = Container();
                                          serverStatus = "";
                                          stopServerButton = Container();
                                        });
                                      },
                                      tooltip: '共有を停止する',
                                      child: const Icon(Icons.stop),
                                    );
                                  }));
                        } else {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text("ネットワークに接続してください。"),
                                  actions: <Widget>[
                                    TextButton(
                                      child: const Text("OK"),
                                      onPressed: () => Navigator.pop(context),
                                    )
                                  ],
                                );
                              });
                        }
                      });
                    } else {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text("ファイルを選択してください。"),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text("OK"),
                                  onPressed: () => Navigator.pop(context),
                                )
                              ],
                            );
                          });
                    }
                  },
                ),
              ),
              qrCode,
              Text(
                serverStatus,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
        ),
        // 共有停止ボタン
        floatingActionButton: stopServerButton);
  }
}
