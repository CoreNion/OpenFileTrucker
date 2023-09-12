import 'package:flutter/material.dart';

import '../class/send_settings.dart';

class SendSettingsDialog extends StatefulWidget {
  final SendSettings? currentSettings;

  const SendSettingsDialog(
      {Key? key, SendSettings? sendSettings, this.currentSettings})
      : super(key: key);

  @override
  State<SendSettingsDialog> createState() => _SendSettingsDialogState();
}

class _SendSettingsDialogState extends State<SendSettingsDialog> {
  SendSettings settings = SendSettings();

  @override
  void initState() {
    super.initState();

    if (widget.currentSettings != null) settings = widget.currentSettings!;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("送信設定"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SwitchListTile(
            value: settings.checkFileHash,
            title: const Text('受信時にファイルの整合性を確認する'),
            subtitle: const Text("ファイルのハッシュ値を確認し、送信元と同じファイルを受信したかどうかを確認します。"),
            onChanged: (bool value) => setState(() {
              settings.checkFileHash = value;
            }),
          ),
          SwitchListTile(
            value: settings.encryptMode,
            title: const Text('暗号化モードで送信する (推奨)'),
            subtitle: const Text(
                "鍵は全て端末側で生成され、安全に共有されます。\n暗号化しない場合、通信内容が盗聴されたり改竄される可能性があります。"),
            onChanged: (bool value) => setState(() {
              settings.encryptMode = value;
            }),
          ),
          SwitchListTile(
            value: settings.deviceDetection,
            title: const Text('デバイス検知を有効化'),
            subtitle: const Text(
                "他の端末に、この端末がファイルの送信待機状態であることを知らせます。\n待機状態を隠したい場合は無効化してください。"),
            onChanged: (bool value) => setState(() {
              settings.deviceDetection = value;
            }),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: const Text("閉じる"),
          onPressed: () => Navigator.pop(context, settings),
        )
      ],
    );
  }
}
