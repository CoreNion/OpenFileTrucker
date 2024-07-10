import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/setting_provider.dart';

class SendSettingsDialog extends ConsumerWidget {
  const SendSettingsDialog({super.key});

  static final _formKey = GlobalKey<FormState>();

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
            title: const Text('暗号化モードで送信する'),
            subtitle: const Text(
                "外部からは通信内容が全く分からないようにしますが、接続パフォーマンスは低くなります。\n公共無線LANなど、不特定多数が使用するネットワークに接続している場合はオンにすることを強く推奨します。"),
            onChanged: (bool value) =>
                ref.read(encryptModeProvider.notifier).state = value,
          ),
          SwitchListTile(
            value: ref.watch(deviceDetectionProvider),
            title: const Text('デバイス検知を有効化'),
            subtitle: const Text("他の端末に、この端末がファイルの送信待機状態であることを知らせます。"),
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
                  return Container(
                    margin: const EdgeInsets.all(10),
                    child: AlertDialog(
                      title: const Text("通信相手の端末に表示される名前を設定..."),
                      content: Form(
                        key: _formKey,
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
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("キャンセル"),
                        ),
                        TextButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();
                              Navigator.pop(context);
                            }
                          },
                          child: const Text("決定"),
                        ),
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
