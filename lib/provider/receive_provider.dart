import 'dart:async';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../class/file_info.dart';
import '../class/trucker_device.dart';

import '../helper/service.dart';
import '../receive.dart';
import 'main_provider.dart';
import 'service_provider.dart';

/// 指定されたIPアドレスからファイルを受信する
Future<void> startManualReceive(String ip, WidgetRef ref) async {
  final sendDevices = ref.watch(tSendDevicesProvider);
  final device = TruckerDevice(ip, ip, null, TruckerStatus.sendReady, uuid);

  // 受信リストに追加
  ref.read(tSendDevicesProvider.notifier).state = [...sendDevices, device];
  startReceive(device, ref);
}

/// 指定されたデバイスからファイルを受信する
Future<void> startReceive(TruckerDevice device, WidgetRef ref) async {
  final colorScheme = ref.watch(colorSchemeProvider);
  final sendDevices = ref.watch(tSendDevicesProvider);
  final index = sendDevices.indexOf(device);

  // ファイル情報を取得
  List<FileInfo> fileInfos;
  try {
    fileInfos = await ReceiveFile.getServerFileInfo(device.host);
  } catch (e) {
    BotToast.showSimpleNotification(
        title: "送信元に接続できませんでした。",
        subTitle: e.toString(),
        backgroundColor: colorScheme.onError);

    // エラー扱いにする
    sendDevices[index].progress = 1;
    sendDevices[index].status = TruckerStatus.failed;
    ref.read(tSendDevicesProvider.notifier).state = [...sendDevices];
    return;
  }

  // 保存場所を取得 (何も入力されない場合は終了)
  final dirPath = await ReceiveFile.getSavePath();
  if (dirPath == null) {
    sendDevices[index].progress = 0;
    sendDevices[index].status = TruckerStatus.sendReady;

    ref.read(tSendDevicesProvider.notifier).state = [...sendDevices];
    return;
  }

  // iOSで画像/動画ファイルが含まれている場合は、写真ライブラリに保存するか尋ねる
  bool saveMediaFile = false;
  if (Platform.isIOS &&
      fileInfos.any((e) =>
          lookupMimeType(e.name)?.contains(RegExp(r"image|video")) ?? false)) {
    final resultCompleter = Completer<bool>();
    BotToast.showWidget(toastBuilder: (cancelFunc) {
      return AlertDialog(
        title: const Text("写真ライブラリに保存しますか？"),
        content: const Text("受信した画像/動画ファイルを、写真ライブラリに保存しますか？"),
        actions: [
          TextButton(
              onPressed: () {
                cancelFunc();
                resultCompleter.complete(false);
              },
              child: const Text("保存しない (フォルダーに保存)")),
          TextButton(
              onPressed: () async {
                cancelFunc();
                if (await Permission.photosAddOnly.request().isDenied) {
                  BotToast.showSimpleNotification(
                      title: "写真ライブラリにアクセスできません",
                      subTitle: "今回はファイルとして保存します。ライブラリに保存するには、設定から権限を変更してください。",
                      duration: const Duration(seconds: 10),
                      backgroundColor: colorScheme.onError);
                  resultCompleter.complete(false);
                  return;
                }
                resultCompleter.complete(true);
              },
              child: const Text("保存する")),
        ],
      );
    });
    saveMediaFile = await resultCompleter.future;
  }

  // 全ファイルの受信の終了時の処理(異常終了関係なし)
  void endProcess(bool sucess) {
    // 画面ロック防止を解除
    WakelockPlus.disable();

    sendDevices[index].progress = 1;
    sendDevices[index].status = TruckerStatus.received;
    ref.read(tSendDevicesProvider.notifier).state = [...sendDevices];

    if (!sucess) {
      return;
    }
    BotToast.showNotification(
      leading: (_) => SizedBox.fromSize(
          size: const Size(40, 40),
          child: const Icon(Icons.check, color: Colors.green)),
      title: (_) => const Text("ファイルの受信が完了しました！"),
      subtitle: (_) => const Text("ディレクトリを開くには、ここをタップしてください。"),
      trailing: (_) => const Icon(Icons.folder_open),
      duration: const Duration(seconds: 10),
      backgroundColor: colorScheme.onPrimary,
      onTap: () {
        if (Platform.isWindows) {
          Process.run("explorer", [dirPath]);
        } else if (Platform.isMacOS) {
          Process.run("open", [dirPath]);
        } else if (Platform.isLinux) {
          Process.run("xdg-open", [dirPath]);
        } else if (Platform.isIOS) {
          if (saveMediaFile) {
            launchUrlString("photos-redirect://");
          } else {
            launchUrlString("shareddocuments://$dirPath");
          }
        } else if (Platform.isAndroid) {
          launchUrlString("file://$dirPath");
        }
      },
    );
  }

  // 各ファイルを受信する
  final controller = await ReceiveFile.receiveAllFiles(
      device.host, fileInfos, dirPath, saveMediaFile);

  // 進捗を適宜更新する
  final stream = controller.stream;
  stream.listen((newProgress) {
    sendDevices[index].progress = newProgress.totalProgress;
    ref.read(tSendDevicesProvider.notifier).state = [...sendDevices];
  }, onError: (e) {
    endProcess(false);

    BotToast.showSimpleNotification(
        title: "ファイルの受信に失敗しました",
        subTitle: e,
        backgroundColor: colorScheme.onError);
  });

  controller.done.then((_) {
    endProcess(true);
  });
}
