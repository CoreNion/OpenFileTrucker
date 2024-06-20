import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_provider.dart';

enum _SettingsType {
  checkFileHash,
  encryptMode,
  deviceDetection,
  bindAdress,
  name
}

final checkFileHashProvider = StateProvider<bool>(
    (ref) => _prefProviderFn(_SettingsType.checkFileHash, true, ref));

final encryptModeProvider = StateProvider<bool>(
    (ref) => _prefProviderFn(_SettingsType.encryptMode, true, ref));

final deviceDetectionProvider = StateProvider<bool>(
    (ref) => _prefProviderFn(_SettingsType.deviceDetection, true, ref));

final bindAdressProvider = StateProvider<String>(
    (ref) => _prefProviderFn(_SettingsType.bindAdress, "0.0.0.0", ref));

final nameProvider = StateProvider<String>(
    (ref) => _prefProviderFn(_SettingsType.name, Platform.localHostname, ref));

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

    // TO Do:送信設定を更新
  });

  return current;
}
