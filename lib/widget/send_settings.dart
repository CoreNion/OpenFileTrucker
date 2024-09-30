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
          const SettingDeviceName(),
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

class SettingDeviceName extends ConsumerWidget {
  const SettingDeviceName({super.key});

  static final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
        margin: const EdgeInsets.all(10),
        child: Form(
          key: _formKey,
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: '相手に表示される端末名',
              prefixIcon: Icon(Icons.title),
            ),
            initialValue: ref.watch(nameProvider),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'デバイス名を入力してください。';
              }
              return null;
            },
            onFieldSubmitted: (value) {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
              }
            },
            onTapOutside: (event) {
              FocusManager.instance.primaryFocus?.unfocus();
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
              }
            },
            onSaved: (newValue) {
              ref.read(nameProvider.notifier).state = newValue!;
            },
          ),
        ));
  }
}
