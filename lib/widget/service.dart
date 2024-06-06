import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_indicator/loading_indicator.dart';

import '../class/trucker_device.dart';
import '../helper/incoming.dart';
import '../helper/service.dart';
import '../provider/receive_provider.dart';
import '../provider/send_provider.dart';
import '../provider/service_provider.dart';

class TruckerDevicesList extends ConsumerWidget {
  final ServiceType scanType;

  const TruckerDevicesList(this.scanType, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final scanDevices = ref.watch(scanDeviceProvider(scanType));
    final allDevices = ref.watch(truckerDevicesProvider);

    return scanDevices.when(loading: () {
      return Container(
          margin: const EdgeInsets.all(5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 170,
                child: LoadingIndicator(
                  indicatorType: Indicator.ballScale,
                  colors: [colorScheme.primary.withOpacity(1.0)],
                ),
              ),
              const Text(
                "デバイスを探しています...",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20),
              ),
            ],
          ));
    }, error: (e, s) {
      return Center(
        child: Text(
          "エラーが発生しました\n$e",
          textAlign: TextAlign.center,
        ),
      );
    }, data: (devices) {
      return scanType == ServiceType.receive
          ? SizedBox(
              height: 160,
              child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: allDevices.length,
                  itemBuilder: (BuildContext context, int index) =>
                      TruckerDeviceWidget(scanType, index)))
          : SingleChildScrollView(
              child: Wrap(
                  children: List.generate(allDevices.length,
                      (index) => TruckerDeviceWidget(scanType, index))));
    });
  }
}

class TruckerDeviceWidget extends ConsumerWidget {
  const TruckerDeviceWidget(this.scanType, this.index, {Key? key})
      : super(key: key);

  final ServiceType scanType;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final allDevices = ref.watch(truckerDevicesProvider);

    return Container(
      margin: const EdgeInsets.only(left: 10, right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () async {
                  if (scanType == ServiceType.receive &&
                      !ref.watch(serverStateProvider)) {
                    BotToast.showSimpleNotification(
                        title: "ファイルを選択してください",
                        backgroundColor: colorScheme.onError);
                    return;
                  }

                  // progressをnullにして、ローディングをくるくるさせる
                  allDevices[index].progress = null;
                  ref.read(truckerDevicesProvider.notifier).state = [
                    ...allDevices
                  ];

                  final remote = allDevices[index].host;

                  if (scanType == ServiceType.receive) {
                    // サービス経由で通信しているデバイスリストに追加
                    viaServiceDevice.addEntries(
                        {MapEntry(allDevices[index].uuid, allDevices[index])});

                    // サーバー側にリクエストを送信
                    final res =
                        await sendRequest(remote, Platform.localHostname);
                    if (!res) {
                      allDevices[index].progress = 1;
                      allDevices[index].status = TruckerStatus.rejected;
                      BotToast.showSimpleNotification(
                          title: "リクエストが拒否されました",
                          subTitle: "拒否された端末: ${allDevices[index].name}",
                          backgroundColor: colorScheme.onError);
                      return;
                    }

                    // プログレスが更新された時の動作
                    refreshUserInfo = () {
                      allDevices[index].progress =
                          viaServiceDevice[allDevices[index].uuid]?.progress;
                      ref.read(truckerDevicesProvider.notifier).state = [
                        ...allDevices
                      ];
                    };
                  } else {
                    startReceive(allDevices[index], ref);
                  }

                  allDevices[index].status = scanType == ServiceType.send
                      ? TruckerStatus.receiving
                      : TruckerStatus.sending;
                },
                padding: const EdgeInsets.all(5),
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
                    value: allDevices[index].progress,
                    valueColor: _setLoadingColor(allDevices[index].status,
                        Theme.of(context).colorScheme),
                    strokeWidth: 3.0),
              )),
            ],
          ),
          Text(
            allDevices[index].name,
            textAlign: TextAlign.center,
          )
        ],
      ),
    );
  }

  /// ローディングの色を設定
  Animation<Color> _setLoadingColor(
      TruckerStatus status, ColorScheme colorScheme) {
    switch (status) {
      case TruckerStatus.receiving:
      case TruckerStatus.sending:
        return AlwaysStoppedAnimation<Color>(colorScheme.secondary);
      case TruckerStatus.rejected:
      case TruckerStatus.failed:
        return AlwaysStoppedAnimation<Color>(colorScheme.error);
      default:
        return AlwaysStoppedAnimation<Color>(colorScheme.primary);
    }
  }
}
