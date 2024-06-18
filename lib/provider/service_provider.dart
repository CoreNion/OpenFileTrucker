import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../class/trucker_device.dart';
import '../helper/service.dart';

final tSendDevicesProvider =
    StateProvider<List<TruckerDevice>>((ref) => const []);

final tReceiveDevicesProvider =
    StateProvider<List<TruckerDevice>>((ref) => const []);

/// 送受信待機中のデバイスをスキャンを開始するプロバイダー
final scanDeviceProvider = StreamProvider(
  (ref) async* {
    final tSendDevices = ref.read(tSendDevicesProvider.notifier);
    final tReceiveDevices = ref.read(tReceiveDevicesProvider.notifier);

    final scanStream = await scanTruckerService();

    await for (final device in scanStream) {
      if (device.status == TruckerStatus.receiveReady) {
        // 受信待機中のデバイスを見つけた場合、ダブってない場合送信可能リストに追加
        if (tSendDevices.state.map((e) => e.uuid).contains(device.uuid)) {
          continue;
        } else {
          tSendDevices.state = [
            ...tSendDevices.state,
            device,
          ];
        }
      } else if (device.status == TruckerStatus.sendReady) {
        // 送信待機中のデバイスを見つけた場合、ダブってない場合受信可能デバイスリストに追加
        if (tReceiveDevices.state.map((e) => e.uuid).contains(device.uuid)) {
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
