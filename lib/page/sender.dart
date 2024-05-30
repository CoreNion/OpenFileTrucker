import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file_trucker/provider/send_provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

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
          const Expanded(
              child: TruckerDevicesList(
            ServiceType.receive,
          )),
          ref.watch(sendQRData) != null
              ? SizedBox(
                  width: 200,
                  height: 200,
                  child: PrettyQrView.data(
                    data: json.encode(ref.watch(sendQRData)!.toJson()),
                    decoration: PrettyQrDecoration(
                      shape: PrettyQrRoundedSymbol(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ))
              : Container(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
