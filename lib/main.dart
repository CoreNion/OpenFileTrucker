import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'provider/main_provider.dart';
import 'page/receive.dart';
import 'page/send.dart';
import 'provider/send_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // パッケージ情報を取得 / 記録
  MyApp.packageInfo = await PackageInfo.fromPlatform();
  // 無いライセンスを登録
  final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
  LicenseRegistry.addLicense(() {
    return Stream<LicenseEntry>.fromIterable(<LicenseEntry>[
      LicenseEntryWithLineBreaks(<String>['Noto Sans JP'], ofl)
    ]);
  });

  runApp(ProviderScope(
    observers: [ServerStateListener()],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  static late PackageInfo packageInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DynamicColorBuilder(builder: ((lightDynamic, darkDynamic) {
      ColorScheme lightColorScheme;
      ColorScheme darkColorScheme;
      Uri siteUri = Uri.https("corenion.github.io", "/file_trucker/");

      // DynamicColorが設定されている場合、それを使う
      if (lightDynamic != null && darkDynamic != null) {
        lightColorScheme = lightDynamic.harmonized();
        darkColorScheme = darkDynamic.harmonized();
      } else {
        lightColorScheme = ColorScheme.fromSeed(
          seedColor: Colors.green,
        );
        darkColorScheme = ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        );
      }

      return MaterialApp(
        title: 'Open FileTrucker',
        builder: BotToastInit(),
        navigatorObservers: [BotToastNavigatorObserver()],
        theme: ThemeData(
          colorScheme: lightColorScheme,
          fontFamily: 'Noto Sans JP',
          appBarTheme: AppBarTheme.of(context)
              .copyWith(backgroundColor: lightColorScheme.surfaceVariant),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: darkColorScheme,
          fontFamily: 'Noto Sans JP',
          scaffoldBackgroundColor: Colors.black,
          useMaterial3: true,
        ),
        themeMode: ref.watch(isDarkProvider) ? ThemeMode.dark : ThemeMode.light,
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text("Open FileTrucker"),
              actions: <Widget>[
                IconButton(
                    icon: const Icon(Icons.brightness_6),
                    onPressed: () => ref.read(isDarkProvider.notifier).state =
                        !ref.watch(isDarkProvider)),
                IconButton(
                    icon: const Icon(Icons.info),
                    onPressed: () async {
                      showAboutDialog(
                          context: context,
                          applicationIcon: ClipRRect(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              child: SvgPicture.asset(
                                'assets/FileTrucker.svg',
                                width: 60,
                                height: 60,
                              )),
                          applicationName: 'Open FileTrucker',
                          applicationVersion: "Version:${packageInfo.version}",
                          applicationLegalese: 'Copyright (c) 2023 CoreNion\n',
                          children: <Widget>[
                            if (await canLaunchUrl(siteUri)) ...{
                              TextButton(
                                child: const Text('公式サイト'),
                                onPressed: () async => await launchUrl(siteUri),
                              ),
                              TextButton(
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue),
                                  onPressed: () async => await launchUrl(Uri.parse(
                                      "https://github.com/CoreNion/OpenFileTrucker")),
                                  child: const Text('GitHub')),
                            }
                          ]);
                    }),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              onDestinationSelected: (int index) {
                ref.read(currentPageIndexProvider.notifier).state = index;
              },
              selectedIndex: ref.watch(currentPageIndexProvider),
              destinations: const <Widget>[
                NavigationDestination(
                  icon: Icon(Icons.send_outlined),
                  selectedIcon: Icon(Icons.send),
                  label: '送信',
                ),
                NavigationDestination(
                  icon: Icon(Icons.download_outlined),
                  selectedIcon: Icon(Icons.download),
                  label: '受信',
                ),
              ],
            ),
            body: IndexedStack(
                index: ref.watch(currentPageIndexProvider),
                children: const <Widget>[
                  SendPage(),
                  ReceivePage(),
                ]),
          ),
        ),
      );
    }));
  }
}
