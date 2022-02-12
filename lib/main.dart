import 'package:flutter/material.dart';
import 'package:open_file_trucker/receieve_page.dart';
import 'package:open_file_trucker/send_page.dart';

void main() {
  runApp(MaterialApp(
      title: 'Open FileTrucker',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.info),
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: 'Open FileTrucker',
                applicationVersion: '0.0.0',
                applicationLegalese: 'Copyright (c) 2022 CoreNion',
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Send", icon: Icon(Icons.send)),
              Tab(text: "Receive", icon: Icon(Icons.download)),
            ],
          ),
          title: const Text('Open FileTrucker'),
        ),
        body: const TabBarView(
          children: [
            SendPage(),
            ReceivePage(),
          ],
        ),
      ),
    );
  }
}
