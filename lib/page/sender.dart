import 'dart:io';

import 'package:flutter/material.dart';
import 'package:responsive_grid/responsive_grid.dart';
import 'package:bot_toast/bot_toast.dart';

import '../class/trucker_device.dart';
import '../helper/incoming.dart';
import '../widget/service.dart';

class SenderConfigPage extends StatefulWidget {
  const SenderConfigPage({Key? key}) : super(key: key);

  @override
  State<SenderConfigPage> createState() => _SenderConfigPageState();
}

class _SenderConfigPageState extends State<SenderConfigPage> {
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
          const Expanded(
            child: TruckerDevicesList(isSender: true),
          ),
        ],
      ),
    );
  }
}
