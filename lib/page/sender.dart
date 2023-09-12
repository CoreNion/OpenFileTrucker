import 'package:flutter/material.dart';
import 'package:responsive_grid/responsive_grid.dart';

import '../helper/incoming.dart';
import '../helper/service.dart';

class SenderConfigPage extends StatefulWidget {
  const SenderConfigPage({Key? key}) : super(key: key);

  @override
  State<SenderConfigPage> createState() => _SenderConfigPageState();
}

class _SenderConfigPageState extends State<SenderConfigPage> {
  final List<String> _readyDevices = [];

  @override
  void initState() {
    super.initState();

    startDetectService(ServiceType.send, (service, status) async {
      setState(() {
        _readyDevices.add(service.host!);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          child: Text(
            "送信するデバイス",
            style: TextStyle(fontSize: 20, color: colorScheme.primary),
          ),
        ),
        Expanded(
          child: ResponsiveGridList(
              desiredItemWidth: 150,
              children: _readyDevices.map((e) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () async {
                        final res = await sendRequest(e, "MacBook Air");
                        if (!res) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("リクエストが拒否されました"),
                            ),
                          );
                        }
                      },
                      padding: const EdgeInsets.all(10),
                      icon: const Icon(
                        Icons.computer,
                        size: 90,
                      ),
                    ),
                    Text(
                      e,
                      textAlign: TextAlign.center,
                    )
                  ],
                );
              }).toList()),
        ),
      ],
    );
  }
}
