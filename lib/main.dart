import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_file_trucker/receieve_page.dart';
import 'package:open_file_trucker/send_page.dart';
import 'package:cool_alert/cool_alert.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  // 起動時はplatformBrightnessでダークモード判定
  static bool isDark =
      SchedulerBinding.instance!.window.platformBrightness == Brightness.dark
          ? true
          : false;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Open FileTrucker',
        theme: ThemeData(
          primarySwatch: Colors.green,
        ),
        darkTheme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.lightGreen,
            brightness: Brightness.dark,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Colors.green, foregroundColor: Colors.white),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.green.shade800,
          ),
          scaffoldBackgroundColor: Colors.black,
        ),
        themeMode: MyApp.isDark ? ThemeMode.dark : ThemeMode.light,
        home: DefaultTabController(
            length: 2,
            child: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  actions: <Widget>[
                    IconButton(
                        icon: const Icon(Icons.brightness_6),
                        onPressed: () => MyApp.isDark
                            ? setState(() => MyApp.isDark = false)
                            : setState(() => MyApp.isDark = true)),
                    IconButton(
                      icon: const Icon(Icons.info),
                      onPressed: () => showAboutDialog(
                          context: context,
                          applicationIcon: ClipRRect(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
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
                      Tab(text: "送信", icon: Icon(Icons.send)),
                      Tab(text: "受信", icon: Icon(Icons.download)),
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
            )));
  }
}
