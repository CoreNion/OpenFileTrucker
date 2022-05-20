import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_file_trucker/receieve_page.dart';
import 'package:open_file_trucker/send_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
          colorSchemeSeed: Colors.green,
          appBarTheme: AppBarTheme(backgroundColor: Colors.green.shade100),
          tabBarTheme: const TabBarTheme(labelColor: Colors.black),
          brightness: Brightness.light,
          fontFamily: 'Noto Sans JP',
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.green,
          brightness: Brightness.dark,
          fontFamily: 'Noto Sans JP',
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: AppBarTheme(backgroundColor: Colors.green.shade900),
          useMaterial3: true,
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
                        onPressed: () async {
                          final ofl = await rootBundle
                              .loadString("assets/fonts/OFL.txt");
                          LicenseRegistry.addLicense(() {
                            return Stream<LicenseEntry>.fromIterable(<
                                LicenseEntry>[
                              LicenseEntryWithLineBreaks(
                                  <String>['Noto Sans JP'], ofl)
                            ]);
                          });
                          PackageInfo packageInfo =
                              await PackageInfo.fromPlatform();

                          showAboutDialog(
                              context: context,
                              applicationIcon: ClipRRect(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(12)),
                                  child: SvgPicture.asset(
                                    'assets/FileTrucker.svg',
                                    width: 80,
                                    height: 80,
                                  )),
                              applicationName: 'Open FileTrucker',
                              applicationVersion:
                                  "Version: ${packageInfo.version}",
                              applicationLegalese:
                                  'Copyright (c) 2022 CoreNion\n',
                              children: <Widget>[
                                if (await canLaunch(
                                    "https://corenion.github.io/")) ...{
                                  TextButton(
                                    child: const Text('公式サイト'),
                                    onPressed: () async => await launch(
                                        "https://corenion.github.io/file_trucker/"),
                                  ),
                                  TextButton(
                                      child: const Text('GitHub'),
                                      style: TextButton.styleFrom(
                                          primary: Colors.blue),
                                      onPressed: () async => await launch(
                                          "https://github.com/CoreNion/OpenFileTrucker")),
                                }
                              ]);
                        }),
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
