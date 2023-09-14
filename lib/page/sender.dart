import 'dart:io';

import 'package:flutter/material.dart';
import 'package:responsive_grid/responsive_grid.dart';
import 'package:bot_toast/bot_toast.dart';

import '../class/receiver.dart';
import '../helper/incoming.dart';
import '../helper/service.dart';

class SenderConfigPage extends StatefulWidget {
  const SenderConfigPage({Key? key}) : super(key: key);

  @override
  State<SenderConfigPage> createState() => _SenderConfigPageState();
}

class _SenderConfigPageState extends State<SenderConfigPage> {
  final List<ReceiveReadyDevice> _readyDevices = [];

  @override
  void initState() {
    super.initState();

    startDetectService(ServiceType.receive, (service, status) async {
      setState(() {
        _readyDevices.add(ReceiveReadyDevice(
            service.name!, service.host!, 0, ReceiverStatus.ready));
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
                children: _readyDevices.asMap().entries.map(
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
                                  _readyDevices[index].progress = null;
                                });
                                final res = await sendRequest(
                                    _readyDevices[index].host,
                                    Platform.localHostname);
                                if (!res && mounted) {
                                  setState(() {
                                    _readyDevices[index].progress = 1;
                                    _readyDevices[index].status =
                                        ReceiverStatus.rejected;
                                  });
                                  BotToast.showSimpleNotification(
                                      title: "リクエストが拒否されました",
                                      subTitle:
                                          "拒否された端末: ${_readyDevices[index].name}",
                                      backgroundColor: colorScheme.onError);
                                  return;
                                }

                                setState(() {
                                  _readyDevices[index].progress = 1;
                                  _readyDevices[index].status =
                                      ReceiverStatus.received;
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
                                        value: _readyDevices[index].progress,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          _readyDevices[index].status ==
                                                  ReceiverStatus.ready
                                              ? colorScheme.primary
                                              : _readyDevices[index].status ==
                                                      ReceiverStatus.rejected
                                                  ? colorScheme.error
                                                  : colorScheme.secondary,
                                        ),
                                        strokeWidth: 2.0))),
                          ],
                        ),
                        Text(
                          _readyDevices[index].name,
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
