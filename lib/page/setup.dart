import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/main_provider.dart';
import '../provider/service_provider.dart';
import '../widget/permission.dart';
import '../widget/send_settings.dart';

class SetupPage extends ConsumerWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = ref.watch(colorSchemeProvider);

    return Container(
        height: 650 + MediaQuery.of(context).viewInsets.bottom,
        decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.all(Radius.circular(20))),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: const Text(
                "Welcome to FileTrucker!",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Expanded(
                child: SingleChildScrollView(
                    child: Column(
              children: [
                Text(
                  "FileTruckerを使い始める前に、必要な権限を許可してください。",
                  style: TextStyle(fontSize: 20),
                ),
                SizedBox(height: 10),
                CheckPermissionWidget(),
                SizedBox(height: 10),
                Divider(),
                SizedBox(height: 10),
                Text(
                  "相手に表示される端末名を設定",
                  style: TextStyle(fontSize: 18),
                ),
                SettingDeviceName(),
              ],
            ))),
            const SizedBox(height: 10),
            const Text("＊一部機能(デバイス検知や暗号化)は、環境によっては利用できない場合があります。\nご了承ください。",
                textAlign: TextAlign.center, style: TextStyle(fontSize: 15)),
            const SizedBox(height: 10),
            FilledButton(
                onPressed: () {
                  // スキャン経由の受信用のサービスを登録
                  initIncomingProcess(ref);
                  // デバイスのスキャン開始
                  Future(() => ref.watch(scanDeviceProvider));

                  ref.read(prefsProvider).setBool("firstRun", true);
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text(
                  "使い始める",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                )),
          ],
        ));
  }
}
