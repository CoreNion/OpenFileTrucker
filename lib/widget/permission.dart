import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../helper/permission.dart';

final _didLocalnetProvider = StateProvider<bool>((ref) => false);
final _checkLocalnetProvider = FutureProvider<void>((ref) async {
  ref.read(_didLocalnetProvider.notifier).state =
      await checkLocalnetPermission() ?? false;
});

final _checkPhotosProvider = FutureProvider<bool>((ref) async {
  return await checkPhotosPermission() ?? false;
});

final _checkCameraProvider = FutureProvider<bool>((ref) async {
  return await checkCamPermission();
});

class CheckPermissionWidget extends ConsumerWidget {
  const CheckPermissionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final localnetProvider = ref.watch(_checkLocalnetProvider);
    final photosProvider = ref.watch(_checkPhotosProvider);
    final cameraProvider = ref.watch(_checkCameraProvider);

    return SafeArea(
        child: Column(
      children: [
        ListTile(
          trailing: localnetProvider.when(
            data: (_) => ref.watch(_didLocalnetProvider)
                ? Icon(Icons.check, color: colorScheme.primary)
                : Icon(Icons.error, color: colorScheme.error),
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => const Icon(Icons.error),
          ),
          title: const Text('ローカルネットワークへのアクセス (必須)'),
          subtitle: const Text(
              "デバイス間でファイルを送受信するために必要です。\n4782番と4783番のポートでの送受信が許可されている必要があります。"),
          onTap: localnetProvider.hasValue && !(ref.watch(_didLocalnetProvider))
              ? () async {
                  if (!(await requestLocalnetPermission() ?? false)) {
                    BotToast.showSimpleNotification(
                        crossPage: true,
                        duration: const Duration(seconds: 6),
                        title: "設定に失敗した可能性があります。\n必要な権限が無い場合、管理者に相談してください。",
                        backgroundColor: colorScheme.onSecondary);
                  }
                  ref.invalidate(_checkLocalnetProvider);
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
                subtitle:
                    const Text("完全な状態の写真データを送信したり、写真を写真ライブラリに保存するために必要です。"),
                onTap: photosProvider.hasValue
                    ? () async {
                        if (!(await requestPhotosPermission())) {
                          await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                    title: const Text('権限が拒否されました'),
                                    content: const Text(
                                        '写真ライブラリへのアクセスが拒否されました。\n設定から写真ライブラリへのフルアクセスを許可してください。'),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('キャンセル')),
                                      TextButton(
                                        onPressed: () {
                                          openAppSettings();
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('設定'),
                                      ),
                                    ],
                                  ));
                        }
                        ref.invalidate(_checkPhotosProvider);
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
                        if (!(await requestCamPermission())) {
                          await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                    title: const Text('権限が拒否されました'),
                                    content: const Text(
                                        'カメラへのアクセスが拒否されました。\n設定からカメラへのアクセスを許可してください。'),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('キャンセル')),
                                      TextButton(
                                        onPressed: () {
                                          openAppSettings();
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('設定'),
                                      ),
                                    ],
                                  ));
                        }
                        ref.invalidate(_checkCameraProvider);
                      }
                    : null,
              )
            : const SizedBox(),
        const SizedBox(height: 10)
      ],
    ));
  }
}
