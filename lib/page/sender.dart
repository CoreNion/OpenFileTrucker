import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helper/service.dart';
import '../widget/service.dart';

class SenderConfigPage extends ConsumerWidget {
  const SenderConfigPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: TruckerDevicesList(
              ServiceType.receive,
            ),
          ),
        ],
      ),
    );
  }
}
