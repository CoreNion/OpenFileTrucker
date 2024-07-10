import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../helper/service.dart';
import '../provider/send_provider.dart';
import '../send.dart';
import '../widget/service.dart';

class SenderConfigPage extends ConsumerWidget {
  const SenderConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final qrIP = ref.watch(selectedNetworkProvider);
    final availableNetworks = ref.watch(availableNetworksProvider);

    return ListView(
      shrinkWrap: true,
      children: [
        const SizedBox(height: 15),
        const Text(
          "送信可能なデバイス...",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        TruckerDevicesList(
          ServiceType.receive,
        ),
        const Divider(),
        ref.watch(sendQRData) != null
            ? Column(
                children: [
                  const Text(
                    "QRコードでの接続",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: PrettyQrView.data(
                      data: json.encode(ref.watch(sendQRData)!.toJson()),
                      decoration: PrettyQrDecoration(
                        shape: PrettyQrRoundedSymbol(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: DropdownButton(
                          isExpanded: true,
                          value: qrIP,
                          items: availableNetworks.value!
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text("${e.interfaceName} ${e.ip}"),
                                  ))
                              .toList(),
                          onChanged: (TruckerNetworkInfo? value) {
                            ref.read(selectedNetworkProvider.notifier).state =
                                value!;
                          }),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              )
            : Container(),
      ],
    );
  }
}
