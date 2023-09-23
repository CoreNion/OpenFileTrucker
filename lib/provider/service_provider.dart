import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../class/trucker_device.dart';
import '../helper/service.dart';

/// すべてのTruckerデバイスを管理するプロバイダー
final truckerDevicesProvider = StateProvider<List<TruckerDevice>>((ref) {
  return const [];
});

/// 送受信待機中のデバイスをスキャンするプロバイダー
final scanDeviceProvider =
    StreamProvider.family<List<TruckerDevice>, ServiceType>(
  (ref, serviceType) async* {
    final allDevices = ref.read(truckerDevicesProvider.notifier);

    await for (final device in scanTruckerService(serviceType)) {
      allDevices.state = [
        ...allDevices.state,
        device,
      ];
      yield allDevices.state;
    }
  },
);
