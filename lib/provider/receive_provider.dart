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

  // 全ファイルの受信の終了時の処理(異常終了関係なし)
  void endProcess() {
    // 画面ロック防止を解除
    WakelockPlus.disable();

    BotToast.showSimpleNotification(
        title: "ファイルの受信が完了しました！", backgroundColor: colorScheme.onPrimary);
    sendDevices[index].progress = 1;
    sendDevices[index].status = TruckerStatus.received;
    ref.read(tSendDevicesProvider.notifier).state = [...sendDevices];
  }

  // 各ファイルを受信する
  final controller =
      await ReceiveFile.receiveAllFiles(device.host, fileInfos, dirPath);

  // 進捗を適宜更新する
  final stream = controller.stream;
  stream.listen((newProgress) {
    sendDevices[index].progress = newProgress.totalProgress;
    ref.read(tSendDevicesProvider.notifier).state = [...sendDevices];
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
