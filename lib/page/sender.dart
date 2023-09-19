import 'dart:io';

import 'package:flutter/material.dart';
import 'package:responsive_grid/responsive_grid.dart';
import 'package:bot_toast/bot_toast.dart';

import '../class/trucker_device.dart';
import '../helper/incoming.dart';
import '../helper/service.dart';

class SenderConfigPage extends StatefulWidget {
  const SenderConfigPage({Key? key}) : super(key: key);

  @override
  State<SenderConfigPage> createState() => _SenderConfigPageState();
}

class _SenderConfigPageState extends State<SenderConfigPage> {
  /// FileTruckerデバイスのリスト
  final List<TruckerDevice> _truckerDevices = [];

  @override
  void initState() {
    super.initState();

    startDetectService(ServiceType.receive, (service, status) async {
      setState(() {
        _truckerDevices.add(TruckerDevice(
            service.name!, service.host!, 0, TruckerStatus.receiveReady));
      });
    });
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
            child: ResponsiveGridList(
                desiredItemWidth: 150,
                children: _truckerDevices.asMap().entries.map(
                  (e) {
                    final index = e.key;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              onPressed: () async {
                                setState(() {
                                  _truckerDevices[index].progress = null;
                                });
                                final res = await sendRequest(
                                    _truckerDevices[index].host,
                                    Platform.localHostname);
                                if (!res && mounted) {
                                  setState(() {
                                    _truckerDevices[index].progress = 1;
                                    _truckerDevices[index].status =
                                        TruckerStatus.rejected;
                                  });
                                  BotToast.showSimpleNotification(
                                      title: "リクエストが拒否されました",
                                      subTitle:
                                          "拒否された端末: ${_truckerDevices[index].name}",
                                      backgroundColor: colorScheme.onError);
                                  return;
                                }

                                setState(() {
                                  _truckerDevices[index].progress = 1;
                                  _truckerDevices[index].status =
                                      TruckerStatus.received;
                                });
                              },
                              padding: const EdgeInsets.all(10),
                              icon: const Icon(
                                Icons.computer,
                                size: 90,
                              ),
                            ),
                            IgnorePointer(
                                child: SizedBox(
                                    height: 120,
                                    width: 120,
                                    child: CircularProgressIndicator(
                                        value: _truckerDevices[index].progress,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          _truckerDevices[index].status ==
                                                  TruckerStatus.receiveReady
                                              ? colorScheme.primary
                                              : _truckerDevices[index].status ==
                                                      TruckerStatus.rejected
                                                  ? colorScheme.error
                                                  : colorScheme.secondary,
                                        ),
                                        strokeWidth: 2.0))),
                          ],
                        ),
                        Text(
                          _truckerDevices[index].name,
                          textAlign: TextAlign.center,
                        )
                      ],
                    );
                  },
                ).toList()),
          ),
        ],
      ),
    );
  }
}
