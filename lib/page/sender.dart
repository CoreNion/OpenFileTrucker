import 'package:flutter/material.dart';
import 'package:open_file_trucker/helper/service.dart';

import '../widget/service.dart';

class SenderConfigPage extends StatefulWidget {
  const SenderConfigPage({Key? key}) : super(key: key);

  @override
  State<SenderConfigPage> createState() => _SenderConfigPageState();
}

class _SenderConfigPageState extends State<SenderConfigPage> {
  GlobalKey _key = GlobalKey<State<TruckerDevicesList>>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            child: Text(
              "送信するデバイス",
              style: TextStyle(fontSize: 20, color: colorScheme.primary),
            ),
          ),
          Expanded(
            child: TruckerDevicesList(
              isSender: true,
              key: _key,
            ),
          ),
        ],
      ),
    );
  }
}
