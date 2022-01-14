import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class SendPage extends StatefulWidget {
  const SendPage({Key? key}) : super(key: key);

  @override
  _SendPageState createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  var fileDataText = "<Result>";

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
                  var file = await FilePicker.platform.pickFiles();
                  setState(() {
                    fileDataText = file.toString();
                  });
                },
              ),
            ),
            Text(
              fileDataText,
              style: const TextStyle(),
            ),
          ],
        ),
      ),
    );
  }
}
