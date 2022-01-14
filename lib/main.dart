import 'package:flutter/material.dart';
import 'package:open_file_trucker/ReceivePage.dart';
import 'package:open_file_trucker/sendPage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open File Trucker',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            bottom: const TabBar(
              tabs: [
                Tab(text: "Send", icon: Icon(Icons.send)),
                Tab(text: "Receive", icon: Icon(Icons.download)),
              ],
            ),
            title: const Text('Open File Trucker'),
          ),
          body: const TabBarView(
            children: [
              SendPage(),
              ReceivePage(),
            ],
          ),
        ),
      ),
    );
  }
}
