import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_sizes/file_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path/path.dart' as p;

import '../class/file_info.dart';
import '../class/send_settings.dart';
import '../send.dart';
import 'main_provider.dart';

/// 選択されたファイルのリスト
final selectedFilesProvider = StateProvider<List<XFile>>((ref) => []);

/// ファイルが増減した時に、バックのファイルリストも更新する
class SelectedFilesListener extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) async {
    if (provider == selectedFilesProvider &&
        !container.read(isSmallUIProvider)) {
      final newList = newValue as List<XFile>;

      // ファイル情報を更新
      SendFiles.files = newList;
      SendFiles.fileInfo = await Future.wait(SendFiles.files.map((e) async {
        return FileInfo(
            name: p.basename(e.path), size: await e.length(), hash: null);
      }));

      // ファイルが0ならサーバーを停止
      if (newList.isEmpty) {
        container.read(serverStateProvider.notifier).state = false;
      } else {
        // ファイルが1以上ならサーバーを起動
        container.read(serverStateProvider.notifier).state = true;
      }
    }
  }
}

/// 選択されたファイルの合計サイズ
final totalSizeProvider = FutureProvider<String>((ref) async {
  final files = ref.watch(selectedFilesProvider);

  int totalSize = 0;
  // サイズを取得
  for (XFile file in files) {
    int fileLength = await file.length();
    totalSize += fileLength;
  }

  return FileSize.getSize(totalSize);
});

/// 送信設定
final sendSettingsProvider =
    StateProvider<SendSettings>((ref) => SendSettings());

/// サーバーの起動状態
final serverStateProvider = StateProvider<bool>((ref) => false);

/// サーバーの起動状態を変更する
class ServerStateListener extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) async {
    if (provider == serverStateProvider) {
      // サーバーを起動
      if (newValue == true) {
        WakelockPlus.enable();
        await SendFiles.serverStart(container.read(sendSettingsProvider));
      } else {
        SendFiles.serverClose();

        // キャッシュ削除
        if (Platform.isIOS || Platform.isAndroid) {
          await FilePicker.platform.clearTemporaryFiles();
        }

        WakelockPlus.disable();
      }
    }
  }
}

/// サーバー停止ボタン
final actionButtonProvider = Provider<FloatingActionButton?>((ref) {
  final serverState = ref.watch(serverStateProvider);

  if (serverState && !ref.watch(isSmallUIProvider)) {
    return FloatingActionButton(
      onPressed: () {
        ref.read(serverStateProvider.notifier).state = false;
      },
      tooltip: '共有を停止する',
      child: const Icon(Icons.pause),
    );
  } else {
    return null;
  }
});
