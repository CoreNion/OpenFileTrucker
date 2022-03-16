import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_file_trucker/receieve_page.dart';
import 'package:open_file_trucker/send_page.dart';
import 'package:cool_alert/cool_alert.dart';

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
                  applicationIcon: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: SvgPicture.asset(
                        'original_media/FileTrucker.svg',
                        width: 80,
                        height: 80,
                      )),
                  applicationName: 'Open FileTrucker',
                  applicationVersion: 'Dev (Nightly Build)',
                  applicationLegalese: 'Copyright (c) 2022 CoreNion',
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        CoolAlert.show(
                          context: context,
                          type: CoolAlertType.error,
                          animType: CoolAlertAnimType.rotate,
                          title: "ﾊﾟｧｧｧｧ!!()",
                          text: "このアプリはまだ公開されていません！\nまだまだ開発中です！",
                        );
                      },
                      child: const Text('GitHub Repo'),
                      style: ElevatedButton.styleFrom(
                        primary: Colors.transparent,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        onPrimary: Colors.blue,
                      ),
                    ),
                  ]),
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
