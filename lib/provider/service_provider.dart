import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../class/trucker_device.dart';
import '../helper/incoming.dart';
import '../helper/service.dart';
import '../main.dart';
import 'main_provider.dart';
import 'receive_provider.dart';
import 'setting_provider.dart';

final tSendDevicesProvider =
    StateProvider<List<TruckerDevice>>((ref) => const []);

final tReceiveDevicesProvider =
    StateProvider<List<TruckerDevice>>((ref) => const []);

/// 受信リクエスト関連の処理
void initIncomingProcess(WidgetRef ref) {
  startIncomingServer((name) async {
    final completer = Completer<bool>();

    HapticFeedback.vibrate();
    BotToast.showNotification(
      title: (_) => Text("$nameからの受信リクエスト"),
      subtitle: (_) => const Text("許諾するにはタップ"),
      leading: (_) => const Icon(Icons.file_download),
      duration: const Duration(days: 999),
      onTap: () {
        BotToast.cleanAll();
        completer.complete(true);
      },
      onClose: () => completer.complete(false),
    );
    return await completer.future;
  }, ((remote) async {
    // 受信ページに移動
    ref.read(currentPageIndexProvider.notifier).state = 1;
    // 受信リストに追加
    await startManualReceive(remote, ref);
  }), ref.read(nameProvider));
}

/// 送受信待機中のデバイスをスキャンを開始するプロバイダー
final scanDeviceProvider = StreamProvider(
  (ref) async* {
    final tSendDevices = ref.read(tSendDevicesProvider.notifier);
    final tReceiveDevices = ref.read(tReceiveDevicesProvider.notifier);

    final scanStream = await scanTruckerService();

    await for (final device in scanStream) {
      if (device.status == TruckerStatus.receiveReady) {
        // 受信待機中のデバイスを見つけた場合、ダブってない場合送信可能リストに追加
        final uuidIter = tSendDevices.state.map((e) => e.uuid).toList();
        if (uuidIter.contains(device.uuid) || device.uuid == myUUID) {
          continue;
        } else {
          tSendDevices.state = [
            ...tSendDevices.state,
            device,
          ];
        }
      } else if (device.status == TruckerStatus.sendReady) {
        // 送信待機中のデバイスを見つけた場合、ダブってない場合受信可能デバイスリストに追加
        final uuidIter = tReceiveDevices.state.map((e) => e.uuid).toList();
        if (uuidIter.contains(device.uuid) || device.uuid == myUUID) {
          continue;
        } else {
          tReceiveDevices.state = [
            ...tReceiveDevices.state,
            device,
          ];
        }
      }
    }
  },
);
