import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../class/file_info.dart';
import '../class/trucker_device.dart';

import '../helper/service.dart';
import '../receive.dart';
import 'main_provider.dart';
import 'service_provider.dart';

/// 指定されたIPアドレスからファイルを受信する
Future<void> startManualReceive(String ip, WidgetRef ref) async {
  final allDevices = ref.watch(truckerDevicesProvider);
  final device = TruckerDevice(ip, ip, null, TruckerStatus.sendReady, uuid);

  // 受信リストに追加
  ref.read(truckerDevicesProvider.notifier).state = [...allDevices, device];
  startReceive(device, ref);
}

/// 指定されたデバイスからファイルを受信する
Future<void> startReceive(TruckerDevice device, WidgetRef ref) async {
  final colorScheme = ref.watch(colorSchemeProvider);
  final allDevices = ref.watch(truckerDevicesProvider);
  final index = allDevices.indexOf(device);

  // ファイル情報を取得
  FileInfo fileInfo;
  try {
    fileInfo = await ReceiveFile.getServerFileInfo(device.host);
  } catch (e) {
    BotToast.showSimpleNotification(
        title: "送信元に接続できませんでした。",
        subTitle: e.toString(),
        backgroundColor: colorScheme.onError);

    allDevices[index].progress = 1;
    allDevices[index].status = TruckerStatus.failed;
    ref.read(truckerDevicesProvider.notifier).state = [...allDevices];
    return;
  }

  // 保存場所を取得 (何も入力されない場合は終了)
  final dirPath = await ReceiveFile.getSavePath();
  if (dirPath == null) {
    allDevices[index].progress = 0;
    allDevices[index].status = TruckerStatus.sendReady;

    ref.read(truckerDevicesProvider.notifier).state = [...allDevices];
    return;
  }

  // 全ファイルの受信の終了時の処理(異常終了関係なし)
  void endProcess() {
    // 画面ロック防止を解除
    WakelockPlus.disable();
    // キャッシュ削除
    if (Platform.isIOS || Platform.isAndroid) {
      FilePicker.platform.clearTemporaryFiles();
    }

    BotToast.showSimpleNotification(
        title: "ファイルの受信が完了しました！", backgroundColor: colorScheme.onPrimary);
    allDevices[index].progress = 1;
    allDevices[index].status = TruckerStatus.received;
    ref.read(truckerDevicesProvider.notifier).state = [...allDevices];
  }

  // 各ファイルを受信する
  final controller =
      await ReceiveFile.receiveAllFiles(device.host, fileInfo, dirPath);

  // 進捗を適宜更新する
  final stream = controller.stream;
  stream.listen((newProgress) {
    allDevices[index].progress = newProgress.totalProgress;
    ref.read(truckerDevicesProvider.notifier).state = [...allDevices];
  }, onError: (e) {
    endProcess();

    BotToast.showSimpleNotification(
        title: "ファイルの受信に失敗しました",
        subTitle: e,
        backgroundColor: colorScheme.onError);
  });

  controller.done.then((_) {
    endProcess();
  });
}
