import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helper/permission.dart';

final didLocalnetProvider = StateProvider<bool>((ref) => false);
final checkLocalnetProvider = FutureProvider<void>((ref) async {
  ref.read(didLocalnetProvider.notifier).state =
      await checkLocalnetPermission() ?? false;
});

final checkPhotosProvider = FutureProvider<bool>((ref) async {
  return await checkPhotosPermission() ?? false;
});

final checkCameraProvider = FutureProvider<bool>((ref) async {
  return await checkCamPermission() ?? false;
});

class CheckPermissionWidget extends ConsumerWidget {
  const CheckPermissionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final localnetProvider = ref.watch(checkLocalnetProvider);
    final photosProvider = ref.watch(checkPhotosProvider);
    final cameraProvider = ref.watch(checkCameraProvider);

    return Column(
      children: [
        ListTile(
          trailing: localnetProvider.when(
            data: (_) => ref.watch(didLocalnetProvider)
                ? Icon(Icons.check, color: colorScheme.primary)
                : Icon(Icons.error, color: colorScheme.error),
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => const Icon(Icons.error),
          ),
          title: const Text('ローカルネットワークへのアクセス (必須)'),
          subtitle: const Text(
              "デバイス間でファイルを送受信するために必要です。\n4782番と4783番のポートでの送受信が許可されている必要があります。"),
          onTap: localnetProvider.hasValue && !(ref.watch(didLocalnetProvider))
              ? () async {
                  if (!(await requestLocalnetPermission() ?? false)) {
                    BotToast.showSimpleNotification(
                        crossPage: true,
                        duration: const Duration(seconds: 6),
                        title: "設定に失敗した可能性があります。\n必要な権限が無い場合、管理者に相談してください。",
                        backgroundColor: colorScheme.onSecondary);
                  }
                  ref.invalidate(checkLocalnetProvider);
                }
              : null,
        ),
        Platform.isIOS
            ? ListTile(
                trailing: photosProvider.when(
                  data: (value) => value
                      ? Icon(Icons.check, color: colorScheme.primary)
                      : Icon(Icons.error, color: colorScheme.error),
                  loading: () => const CircularProgressIndicator(),
                  error: (error, _) => const Icon(Icons.error),
                ),
                title: const Text('写真ライブラリへのアクセス'),
                subtitle: const Text("写真を写真ライブラリに保存するために必要です。"),
                onTap: photosProvider.hasValue
                    ? () async {
                        if (await requestPhotosPermission() ?? false) {
                          ref.invalidate(checkPhotosProvider);
                        }
                      }
                    : null,
              )
            : const SizedBox(),
        Platform.isIOS || Platform.isAndroid || Platform.isMacOS
            ? ListTile(
                trailing: cameraProvider.when(
                  data: (value) => value
                      ? Icon(Icons.check, color: colorScheme.primary)
                      : Icon(Icons.error, color: colorScheme.error),
                  loading: () => const CircularProgressIndicator(),
                  error: (error, _) => const Icon(Icons.error),
                ),
                title: const Text('カメラへのアクセス'),
                subtitle: const Text("QRコードをスキャンするために必要です。"),
                onTap: cameraProvider.hasValue
                    ? () async {
                        if (await requestCamPermission() ?? false) {
                          ref.invalidate(checkCameraProvider);
                        }
                      }
                    : null,
              )
            : const SizedBox(),
      ],
    );
  }
}
