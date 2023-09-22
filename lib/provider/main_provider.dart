import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ダークモードの切り替え / 判定
final isDarkProvider = StateProvider<bool>((ref) {
  return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;
});

/// 現在のページインデックス
final currentPageIndexProvider = StateProvider<int>((ref) => 0);
