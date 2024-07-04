import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file_trucker/provider/send_provider.dart';
import 'package:path/path.dart' as p;

import '../class/file_info.dart';
import '../page/sender.dart';
import '../provider/main_provider.dart';
import '../send.dart';
import 'dialog.dart';
import 'send_settings.dart';

class SelectFiles extends ConsumerWidget {
  const SelectFiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallUi = ref.watch(isSmallUIProvider);

    final selectedFiles = ref.watch(selectedFilesProvider);
    final totalSize = ref.watch(totalSizeProvider);
    final serverListen = ref.watch(serverStateProvider);

    /// ファイル選択リストのUIを更新
    void refleshFilesList() {
      ref.read(selectedFilesProvider.notifier).state = [...selectedFiles];
    }

    return Column(children: <Widget>[
      Container(
        color: colorScheme.surface,
        padding: const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton.filled(
              onPressed: () async {
                final files = await selectViaDialog(context);
                if (files == null) return;
                selectedFiles.addAll(files);

                refleshFilesList();
              },
              icon: const Icon(Icons.add)),
          Row(
            children: [
              Text(
                "${selectedFiles.length}個のファイル   ${totalSize.hasValue ? totalSize.asData?.value : ''}",
                style: const TextStyle(fontSize: 17),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                  onPressed: (() async {
                    await showDialog(
                        context: context,
                        builder: (context) => const SendSettingsDialog());
                  }),
                  icon: const Icon(Icons.settings))
            ],
          ),
        ]),
      ),
      Expanded(
        flex: 8,
        child: DropTarget(
            onDragDone: (detail) {
              selectedFiles.addAll(detail.files);
              refleshFilesList();
            },
            child: selectedFiles.isEmpty
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      child: ElevatedButton(
                        onPressed: () async {
                          final files = await selectViaDialog(context);
                          if (files == null) return;
                          selectedFiles.addAll(files);

                          refleshFilesList();
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            )),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.file_open, size: 100),
                              Text(
                                "タップでファイルを追加\nまたはドラック＆ドロップ",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 20),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemBuilder: (context, index) {
                      return Dismissible(
                        key: Key(selectedFiles[index].path),
                        background: Container(
                          color: colorScheme.errorContainer,
                          alignment: Alignment.centerLeft,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                        ),
                        onDismissed: (direction) {
                          selectedFiles.removeAt(index);
                          refleshFilesList();
                        },
                        child: ListTile(
                            title: Text(p.basename(selectedFiles[index].path)),
                            leading: IconButton(
                                onPressed: () {
                                  selectedFiles.removeAt(index);
                                  refleshFilesList();
                                },
                                icon: const Icon(Icons.delete))),
                      );
                    },
                    itemCount: selectedFiles.length)),
      ),
      Container(
        height: 50,
        width: double.infinity,
        margin: const EdgeInsets.all(7),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          onPressed: !serverListen && selectedFiles.isNotEmpty
              ? () async {
                  if (serverListen) {
                    EasyDialog.showSmallToast(
                        ref, "エラー", "他のファイルの共有を停止してください。");
                  } else if (selectedFiles.isNotEmpty) {
                    try {
                      final networks = await SendFiles.getAvailableNetworks();

                      // 利用可能なネットワークが無い場合は終了
                      if (networks == null) {
                        BotToast.showSimpleNotification(
                            title: "利用可能なネットワークがありません",
                            subTitle: "WiFiやイーサーネットなどに接続してください。",
                            backgroundColor: colorScheme.onError,
                            duration: const Duration(seconds: 5));
                        return;
                      }

                      // サーバーの開始
                      SendFiles.fileInfo =
                          await Future.wait(selectedFiles.map((e) async {
                        return FileInfo(
                            name: p.basename(e.path),
                            size: await e.length(),
                            hash: null);
                      }));
                      SendFiles.files = selectedFiles;

                      ref.read(serverStateProvider.notifier).state = true;

                      // 小画面デバイスの場合、別ページで送信待機を表示
                      if (isSmallUi) {
                        if (!context.mounted) return;
                        await showModalBottomSheet(
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            useSafeArea: true,
                            context: context,
                            builder: (context) {
                              return Container(
                                padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.of(context).viewInsets.bottom,
                                ),
                                decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(25))),
                                child: SizedBox(
                                  height: 600,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AppBar(
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(25),
                                          ),
                                        ),
                                        title: const Text("送信待機中です"),
                                        automaticallyImplyLeading: false,
                                        leading: IconButton(
                                            onPressed: (() =>
                                                Navigator.of(context).pop()),
                                            icon:
                                                const Icon(Icons.expand_more)),
                                      ),
                                      const SenderConfigPage(),
                                    ],
                                  ),
                                ),
                              );
                            });

                        ref.watch(serverStateProvider.notifier).state = false;
                      }
                    } catch (e) {
                      EasyDialog.showErrorNoti(e, ref);

                      BotToast.cleanAll();
                    }
                  } else {
                    EasyDialog.showSmallToast(ref, "エラー", "ファイルを選択してください。");
                  }
                }
              : null,
          child: const Text("送信する"),
        ),
      )
    ]);
  }

  /// ファイル選択ダイアログ経由でのファイル選択を行う
  Future<Iterable<XFile>?> selectViaDialog(BuildContext context) async {
    late FileType? fileType;

    // iOSでは写真ライブラリからの選択かも確認する
    if (Platform.isIOS) {
      fileType = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("データの種類を選択", textAlign: TextAlign.center),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Column(children: <Widget>[
                  IconButton(
                      onPressed: () => Navigator.pop(context, FileType.any),
                      icon: const Icon(Icons.file_copy, size: 70)),
                  const Text("ファイル")
                ]),
                Column(children: [
                  IconButton(
                      onPressed: () => Navigator.pop(context, FileType.media),
                      icon: const Icon(Icons.perm_media, size: 70)),
                  const Text("写真/動画")
                ])
              ],
            ),
          ],
        ),
      );
      if (fileType == null) return null;
    } else {
      fileType = FileType.any;
    }
    final files = await SendFiles.pickFiles(type: fileType);
    if (files == null || files.isEmpty) return null;

    // XFileに変換
    return files.map((e) => XFile(e.path));
  }
}
