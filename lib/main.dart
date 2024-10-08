import 'dart:async';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:uuid/uuid.dart';

import 'helper/service.dart';
import 'provider/main_provider.dart';
import 'page/receive.dart';
import 'page/send.dart';
import 'provider/send_provider.dart';
import 'provider/service_provider.dart';

/// この端末のUUID
late String myUUID;

/// ユーザー設定のデバイス名
late String userDeviceName;

void main() async {
  // スプラッシュスクリーンの設定
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb || Platform.isIOS || Platform.isAndroid) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  // ファイルのキャッシュ削除
  if (Platform.isIOS || Platform.isAndroid) {
    await FilePicker.platform.clearTemporaryFiles();
  }

  // パッケージ情報を取得 / 記録
  MyApp.packageInfo = await PackageInfo.fromPlatform();
  // 無いライセンスを登録
  final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
  LicenseRegistry.addLicense(() {
    return Stream<LicenseEntry>.fromIterable(<LicenseEntry>[
      LicenseEntryWithLineBreaks(<String>['Noto Sans JP'], ofl)
    ]);
  });

  // 設定の読み込み、prefeProviderを上書きする形で読み込む
  final prefs = await SharedPreferences.getInstance();

  // UUIDを設定
  myUUID = const Uuid().v4();

  // デバイス名を取得
  userDeviceName = await getUserDeviceName();

  runApp(ProviderScope(
    observers: [ServerStateListener(), SelectedFilesListener()],
    overrides: [
      prefsProvider.overrideWithValue(prefs),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  static late PackageInfo packageInfo;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();

    if (ref.read(prefsProvider).getBool('firstRun') ?? false) {
      // スキャン経由の受信用のサービスを登録
      initIncomingProcess(ref);

      // デバイスのスキャン開始
      Future(() => ref.watch(scanDeviceProvider));
    }

    if (kIsWeb || Platform.isIOS || Platform.isAndroid) {
      FlutterNativeSplash.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI更新時に画面サイズを判定
    Future(() => ref.read(isSmallUIProvider.notifier).state =
        MediaQuery.of(context).size.width < 800);

    return DynamicColorBuilder(builder: ((lightDynamic, darkDynamic) {
      ColorScheme lightColorScheme;
      ColorScheme darkColorScheme;
      Uri siteUri = Uri.https("cnion.dev", "/trucker/");

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

      Future(() => ref.watch(colorSchemeProvider.notifier).state =
          ref.watch(isDarkProvider) ? darkColorScheme : lightColorScheme);

      return MaterialApp(
        title: 'Open FileTrucker',
        builder: BotToastInit(),
        debugShowCheckedModeBanner: false,
        navigatorObservers: [BotToastNavigatorObserver()],
        theme: ThemeData(
          colorScheme: lightColorScheme,
          fontFamily: 'Noto Sans JP',
          appBarTheme: AppBarTheme.of(context).copyWith(
              backgroundColor: lightColorScheme.surfaceContainerHighest),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: darkColorScheme,
          fontFamily: 'Noto Sans JP',
          scaffoldBackgroundColor: Colors.black,
          useMaterial3: true,
        ),
        themeMode: ref.watch(isDarkProvider) ? ThemeMode.dark : ThemeMode.light,
        home: LayoutBuilder(
          builder: (context, constraints) {
            return Scaffold(
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
                            applicationVersion:
                                "Version:${MyApp.packageInfo.version}",
                            applicationLegalese:
                                'Copyright (c) 2024 CoreNion\n',
                            children: <Widget>[
                              if (await canLaunchUrl(siteUri)) ...{
                                TextButton(
                                  child: const Text('公式サイト'),
                                  onPressed: () async =>
                                      await launchUrl(siteUri),
                                ),
                                TextButton(
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.blue),
                                    onPressed: () async => await launchUrl(
                                        Uri.parse(
                                            "https://github.com/CoreNion/OpenFileTrucker/wiki")),
                                    child: const Text('使い方 / GitHub')),
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
              floatingActionButton: ref.watch(actionButtonProvider),
            );
          },
        ),
      );
    }));
  }
}
