import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file_trucker/send.dart';

class SendPage extends StatefulWidget {
  const SendPage({Key? key}) : super(key: key);

  @override
  _SendPageState createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  late FilePickerResult selectedFile;
  String fileDataText = "";
  Widget qrCode = Container();

  @override
  Widget build(BuildContext context) {
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
                  setState(() {
                    if (!(fileDataText == "File not selected." ||
                        fileDataText == "")) {
                      SendFiles.serverStart()
                          .then((generatedCode) => qrCode = generatedCode);
                    }
                  });
                },
              ),
            ),
            qrCode
          ],
        ),
      ),
    );
  }
}
