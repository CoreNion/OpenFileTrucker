import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/send_provider.dart';
import '../send.dart';
import 'dialog.dart';

class SendSettingsDialog extends ConsumerWidget {
  const SendSettingsDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(sendSettingsProvider);

    return AlertDialog(
      title: const Text("送信設定"),
      content: SingleChildScrollView(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SwitchListTile(
            value: settings.checkFileHash,
            title: const Text('受信時にファイルの整合性を確認する'),
            subtitle: const Text("ファイルのハッシュ値を確認し、送信元と同じファイルを受信したかどうかを確認します。"),
            onChanged: (bool value) => ref
                .read(sendSettingsProvider.notifier)
                .state = settings.copyWith(checkFileHash: value),
          ),
          SwitchListTile(
            value: settings.encryptMode,
            title: const Text('暗号化モードで送信する (推奨)'),
            subtitle: const Text(
                "鍵は全て端末側で生成され、安全に共有されます。\n暗号化しない場合、通信内容が盗聴されたり改竄される可能性があります。"),
            onChanged: (bool value) => ref
                .read(sendSettingsProvider.notifier)
                .state = settings.copyWith(encryptMode: value),
          ),
          SwitchListTile(
            value: settings.deviceDetection,
            title: const Text('デバイス検知を有効化'),
            subtitle: const Text(
                "他の端末に、この端末がファイルの送信待機状態であることを知らせます。\n待機状態を隠したい場合は無効化してください。"),
            onChanged: (bool value) => ref
                .read(sendSettingsProvider.notifier)
                .state = settings.copyWith(deviceDetection: value),
          ),
          ListTile(
              title: const Text("Bindアドレス"),
              trailing: Text(settings.bindAdress,
                  style: const TextStyle(fontSize: 18)),
              onTap: () async {
                final nets = await SendFiles.getAvailableNetworks();
                if (nets == null || nets.isEmpty) {
                  EasyDialog.showSmallToast(
                      ref, "エラー", "WiFiやイーサーネットなどに接続してください。");
                  return;
                }

                // 選択肢のDialogOptionに追加する
                List<SimpleDialogOption> dialogOptions = [
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, "0.0.0.0"),
                    child: const Text("0.0.0.0"),
                  )
                ];
                for (var network in nets) {
                  dialogOptions.add(SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, network.ip),
                    child: Text("${network.interfaceName} ${network.ip}"),
                  ));
                }

                if (!context.mounted) return;
                final res = await showDialog<String>(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      title: const Text("利用するネットワークを選択してください。"),
                      children: dialogOptions,
                    );
                  },
                );

                if (res != null) {
                  ref.read(sendSettingsProvider.notifier).state =
                      settings.copyWith(bindAdress: res);
                }
              }),
          ListTile(
            title: const Text("デバイス名"),
            trailing: Text(settings.name, style: const TextStyle(fontSize: 18)),
            onTap: () async {
              late String name;
              final res = await showDialog(
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
                              initialValue: settings.name,
                              decoration: const InputDecoration(
                                labelText: 'デバイス名',
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'デバイス名を入力してください。';
                                }
                                name = value!;
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
                                  Navigator.pop(context, settings.name);
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

              if (res == null) return;
              ref.watch(sendSettingsProvider.notifier).state =
                  settings.copyWith(name: name);
            },
          )
        ],
      )),
      actions: <Widget>[
        TextButton(
          child: const Text("閉じる"),
          onPressed: () => Navigator.pop(context, settings),
        )
      ],
    );
  }
}
