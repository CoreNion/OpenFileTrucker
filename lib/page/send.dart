import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file_trucker/page/setup.dart';
import 'package:share_handler/share_handler.dart';

import '../provider/main_provider.dart';
import '../provider/send_provider.dart';
import '../widget/send_select.dart';
import 'sender.dart';

class SendPage extends ConsumerStatefulWidget {
  const SendPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SendPageState();
}

class _SendPageState extends ConsumerState<SendPage> {
  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid || Platform.isIOS) {
      // ファイル共有APIからの処理のInit
      initShareHandlerPlatformState();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 初回起動の場合はセットアップページを表示
      if (!(ref.read(prefsProvider).getBool('firstRun') ?? false)) {
        if (MediaQuery.of(context).size.width < 800) {
          showModalBottomSheet(
              isDismissible: false,
              context: context,
              isScrollControlled: true,
              enableDrag: false,
              backgroundColor: Colors.transparent,
              useSafeArea: true,
              builder: (builder) => const PopScope(
                  canPop: false,
                  child: SizedBox(height: 650, child: SetupPage())));
        } else {
          showDialog(
              barrierDismissible: false,
              context: context,
              builder: (builder) {
                return const PopScope(
                    canPop: false,
                    child: Dialog(
                      child: SizedBox(
                        height: 600,
                        width: 700,
                        child: SetupPage(),
                      ),
                    ));
              });
        }
      }
    });
  }

  /// ファイル共有API関連の処理
  Future<void> initShareHandlerPlatformState() async {
    final handler = ShareHandlerPlatform.instance;
    final media = await handler.getInitialSharedMedia();
    List<XFile> files = [];

    void setShareFiles(SharedMedia? sharedMedia) {
      if (sharedMedia != null && sharedMedia.attachments != null) {
        // 各ファイルをXFileにして、ファイル設定を行う
        for (var i = 0; i < sharedMedia.attachments!.length; i++) {
          files.add(XFile(sharedMedia.attachments![i]!.path));
        }
        ref.read(selectedFilesProvider.notifier).state = files;
      }
    }

    // 起動時に来た共有ファイルを処理する
    setShareFiles(media);

    // アプリ実行中に来た時用
    handler.sharedMediaStream.listen((SharedMedia media) {
      setShareFiles(media);
    });
  }

  @override
  Widget build(BuildContext context) {
    return !(ref.watch(isSmallUIProvider))
        // サイズごとにUIを変える
        ? Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                  flex: 6,
                  child: Container(
                      decoration: const BoxDecoration(
                          border:
                              Border(right: BorderSide(color: Colors.grey))),
                      child: const SelectFiles())),
              const Expanded(flex: 4, child: SenderConfigPage())
            ],
          )
        : const SelectFiles();
  }
}
