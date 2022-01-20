import 'dart:io';
import 'package:flutter/material.dart';

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

    return Scaffold(
      body: Center(
        child: ElevatedButton(
          child: const Text("Print socket Message"),
          onPressed: () async {
            Socket socket = await Socket.connect("192.168.0.40", 4782);
            socket.listen((event) {
              print(String.fromCharCodes(event));
            });
          },
        ),
      ),
    );
  }
}
