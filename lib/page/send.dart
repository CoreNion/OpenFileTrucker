import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late ColorScheme colorScheme;

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid || Platform.isIOS) {
      // ファイル共有APIからの処理のInit
      initShareHandlerPlatformState();
    }
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
    colorScheme = Theme.of(context).colorScheme;

    return !(ref.watch(isSmallUIProvider))
        // サイズごとにUIを変える
        ? Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              const Expanded(flex: 6, child: SelectFiles()),
              Expanded(
                  flex: 4,
                  child: Container(
                      decoration: const BoxDecoration(
                          border: Border(left: BorderSide(color: Colors.grey))),
                      child: const SenderConfigPage()))
            ],
          )
        : const SelectFiles();
  }
}
