import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:open_file_trucker/provider/setting_provider.dart';

import '../class/trucker_device.dart';
import '../helper/incoming.dart';
import '../helper/service.dart';
import '../provider/receive_provider.dart';
import '../provider/send_provider.dart';
import '../provider/service_provider.dart';

class TruckerDevicesList extends ConsumerWidget {
  final ServiceType scanType;

  TruckerDevicesList(this.scanType, {super.key});

  final scrollController = ScrollController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final list = scanType == ServiceType.send
        ? ref.watch(tSendDevicesProvider)
        : ref.watch(tReceiveDevicesProvider);

    return list.isEmpty
        ? Container(
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
            ))
        : scanType == ServiceType.receive
            ? SizedBox(
                height: 160,
                child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                        controller: scrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: list.length,
                        itemBuilder: (BuildContext context, int index) =>
                            TruckerDeviceWidget(scanType, index))))
            : SingleChildScrollView(
                child: Wrap(
                    children: List.generate(list.length,
                        (index) => TruckerDeviceWidget(scanType, index))));
  }
}

class TruckerDeviceWidget extends ConsumerWidget {
  const TruckerDeviceWidget(this.scanType, this.index, {super.key});

  final ServiceType scanType;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final list = scanType == ServiceType.send
        ? ref.watch(tSendDevicesProvider)
        : ref.watch(tReceiveDevicesProvider);

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
                  final listw = scanType == ServiceType.send
                      ? ref.watch(tSendDevicesProvider.notifier)
                      : ref.watch(tReceiveDevicesProvider.notifier);

                  if (scanType == ServiceType.receive &&
                      !ref.watch(serverStateProvider)) {
                    BotToast.showSimpleNotification(
                        title: "ファイルを選択してください",
                        backgroundColor: colorScheme.onError);
                    return;
                  }

                  // progressをnullにして、ローディングをくるくるさせる
                  list[index].progress = null;
                  listw.state = [...list];

                  if (list[index].host == null) {
                    // 名前解決
                    list[index].host = await requestHostName(
                        list[index].bonsoirService!, scanType);
                  }

                  final remote = list[index].host;

                  if (scanType == ServiceType.receive) {
                    // サービス経由で通信しているデバイスリストに追加
                    viaServiceDevice
                        .addEntries({MapEntry(list[index].uuid, list[index])});

                    // サーバー側にリクエストを送信
                    final res =
                        await sendRequest(remote!, ref.read(nameProvider));
                    if (!res) {
                      list[index].progress = 1;
                      list[index].status = TruckerStatus.rejected;
                      listw.state = [...list];

                      BotToast.showSimpleNotification(
                          title: "リクエストが拒否されました",
                          subTitle: "拒否された端末: ${list[index].name}",
                          backgroundColor: colorScheme.onError);
                      return;
                    }

                    // プログレスが更新された時の動作
                    refreshUserInfo = () {
                      list[index].progress =
                          viaServiceDevice[list[index].uuid]?.progress;
                      listw.state = [...list];
                    };
                  } else {
                    startReceive(list[index], ref);
                  }

                  list[index].status = scanType == ServiceType.send
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
                    value: list[index].progress,
                    valueColor: _setLoadingColor(
                        list[index].status, Theme.of(context).colorScheme),
                    strokeWidth: 3.0),
              )),
            ],
          ),
          Text(
            list[index].name,
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
