import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// prefsのProvider (起動時に初期化)
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

/// ダークモードの切り替え / 判定
final isDarkProvider = StateProvider<bool>((ref) {
  return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;
});

/// 現在のColorScheme
final colorSchemeProvider = StateProvider<ColorScheme>((ref) {
  return ref.watch(isDarkProvider)
      ? const ColorScheme.dark()
      : const ColorScheme.light();
});

/// 現在のページインデックス
final currentPageIndexProvider = StateProvider<int>((ref) => 0);

/// 小さい画面かどうか
final isSmallUIProvider = StateProvider<bool>((ref) {
  return PlatformDispatcher.instance.views.first.physicalSize.width < 800;
});
