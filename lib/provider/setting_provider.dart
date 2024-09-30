import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helper/service.dart';
import '../main.dart';
import 'main_provider.dart';
import 'send_provider.dart';

enum _SettingsType {
  checkFileHash,
  encryptMode,
  deviceDetection,
  bindAdress,
  name
}

final checkFileHashProvider = StateProvider<bool>(
    (ref) => _prefProviderFn(_SettingsType.checkFileHash, false, ref));

final encryptModeProvider = StateProvider<bool>(
    (ref) => _prefProviderFn(_SettingsType.encryptMode, false, ref));

final deviceDetectionProvider = StateProvider<bool>(
    (ref) => _prefProviderFn(_SettingsType.deviceDetection, true, ref));

final bindAdressProvider = StateProvider<String>(
    (ref) => _prefProviderFn(_SettingsType.bindAdress, "0.0.0.0", ref));

final nameProvider = StateProvider<String>((ref) {
  // サービス名を更新
  ref.listenSelf(
    (prev, curr) async {
      if (prev == curr) return;

      // 初回ロード時は更新しない (初期化と重複する)
      if (prev != null) {
        if (ref.read(serverStateProvider) == true) {
          await unregisterNsd(ServiceType.send);
          await registerNsd(ServiceType.send, curr);
        }

        await unregisterNsd(ServiceType.receive);
        await registerNsd(ServiceType.receive, curr);
      }
    },
  );

  return _prefProviderFn(_SettingsType.name, userDeviceName, ref);
});

/// Providerと設定を同期する関数
dynamic _prefProviderFn(
  _SettingsType settingType,
  dynamic defalut,
  StateProviderRef ref,
) {
  // 設定を読み込み、既存の設定を返す
  final prefs = ref.watch(prefsProvider);
  final current = prefs.get(settingType.name) ?? defalut;

  // 設定の変更を監視し、保存する
  ref.listenSelf((prev, curr) {
    if (prev == curr) return;

    if (curr is bool) {
      prefs.setBool(settingType.name, curr);
    } else if (curr is String) {
      prefs.setString(settingType.name, curr);
    } else if (curr is int) {
      prefs.setInt(settingType.name, curr);
    } else if (curr is double) {
      prefs.setDouble(settingType.name, curr);
    }

    if (prev == null) return;

    // 送信設定を更新
    ref.read(sendSettingsProvider.notifier).update((state) => state.copyWith(
          checkFileHash:
              settingType == _SettingsType.checkFileHash ? curr : null,
          encryptMode: settingType == _SettingsType.encryptMode ? curr : null,
          deviceDetection:
              settingType == _SettingsType.deviceDetection ? curr : null,
          bindAdress: settingType == _SettingsType.bindAdress ? curr : null,
          name: settingType == _SettingsType.name ? curr : null,
        ));
  });

  return current;
}
