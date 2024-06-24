import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/setting_provider.dart';

class SendSettingsDialog extends ConsumerWidget {
  const SendSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text("送信設定"),
      content: SingleChildScrollView(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SwitchListTile(
            value: ref.watch(encryptModeProvider),
            title: const Text('暗号化モードで送信する (推奨)'),
            subtitle: const Text(
                "鍵は全て端末側で生成され、安全に共有されます。\n暗号化しない場合、通信内容が盗聴されたり改竄される可能性があります。"),
            onChanged: (bool value) =>
                ref.read(encryptModeProvider.notifier).state = value,
          ),
          SwitchListTile(
            value: ref.watch(deviceDetectionProvider),
            title: const Text('デバイス検知を有効化'),
            subtitle: const Text(
                "他の端末に、この端末がファイルの送信待機状態であることを知らせます。\n待機状態を隠したい場合は無効化してください。"),
            onChanged: (bool value) =>
                ref.read(deviceDetectionProvider.notifier).state = value,
          ),
          ListTile(
            title: const Text("デバイス名"),
            trailing: Text(ref.watch(nameProvider),
                style: const TextStyle(fontSize: 18)),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (context) {
                  final formKey = GlobalKey<FormState>();

                  return Container(
                    margin: const EdgeInsets.all(10),
                    child: SimpleDialog(
                      title: const Text("デバイス名を入力してください。"),
                      children: [
                        Form(
                          key: formKey,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextFormField(
                              initialValue: ref.watch(nameProvider),
                              decoration: const InputDecoration(
                                labelText: 'デバイス名',
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'デバイス名を入力してください。';
                                }
                                ref.read(nameProvider.notifier).state = value!;
                                return null;
                              },
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("キャンセル"),
                            ),
                            TextButton(
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  formKey.currentState!.save();
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text("決定"),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                },
              );
            },
          )
        ],
      )),
      actions: <Widget>[
        TextButton(
          child: const Text("閉じる"),
          onPressed: () => Navigator.pop(context),
        )
      ],
    );
  }
}
