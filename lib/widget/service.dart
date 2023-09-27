import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_grid/responsive_grid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:loading_indicator/loading_indicator.dart';

import '../class/file_info.dart';
import '../class/trucker_device.dart';
import '../helper/incoming.dart';
import '../helper/service.dart';
import '../provider/service_provider.dart';
import '../receive.dart';

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
          margin: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                  flex: 3,
                  child: Text(
                    "デバイスを探しています...",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  )),
              Expanded(
                  flex: 7,
                  child: LoadingIndicator(
                    strokeWidth: 0.1,
                    indicatorType: Indicator.ballScale,
                    colors: [colorScheme.primary.withOpacity(1.0)],
                  ))
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
      return ResponsiveGridList(
          desiredItemWidth: 150,
          children: devices.asMap().entries.map(
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
                          // progressをnullにして、ローディングをくるくるさせる
                          allDevices[index].progress = null;
                          ref.read(truckerDevicesProvider.notifier).state = [
                            ...allDevices
                          ];

                          final remote = allDevices[index].host;

                          if (scanType == ServiceType.receive) {
                            // サービス経由で通信しているデバイスリストに追加
                            viaServiceDevice.addEntries({
                              MapEntry(
                                  allDevices[index].uuid, allDevices[index])
                            });

                            // サーバー側にリクエストを送信
                            final res = await sendRequest(
                                remote, Platform.localHostname);
                            if (!res) {
                              allDevices[index].progress = 1;
                              allDevices[index].status = TruckerStatus.rejected;
                              BotToast.showSimpleNotification(
                                  title: "リクエストが拒否されました",
                                  subTitle:
                                      "拒否された端末: ${allDevices[index].name}",
                                  backgroundColor: colorScheme.onError);
                              return;
                            }

                            // プログレスが更新された時の動作
                            refreshUserInfo = () {
                              allDevices[index].progress =
                                  viaServiceDevice[allDevices[index].uuid]
                                      ?.progress;
                              ref.read(truckerDevicesProvider.notifier).state =
                                  [...allDevices];
                            };
                          } else {
                            // ファイル情報を取得
                            FileInfo fileInfo;
                            try {
                              fileInfo =
                                  await ReceiveFile.getServerFileInfo(remote);
                            } catch (e) {
                              BotToast.showSimpleNotification(
                                  title: "送信元に接続できませんでした。",
                                  subTitle: e.toString(),
                                  backgroundColor: colorScheme.onError);

                              allDevices[index].progress = 1;
                              allDevices[index].status = TruckerStatus.failed;
                              ref.read(truckerDevicesProvider.notifier).state =
                                  [...allDevices];
                              return;
                            }

                            // 保存場所を取得 (何も入力されない場合は終了)
                            final dirPath = await ReceiveFile.getSavePath();
                            if (dirPath == null) {
                              allDevices[index].progress = 0;
                              allDevices[index].status =
                                  TruckerStatus.sendReady;

                              ref.read(truckerDevicesProvider.notifier).state =
                                  [...allDevices];
                              return;
                            }

                            // 全ファイルの受信の終了時の処理(異常終了関係なし)
                            void endProcess() {
                              // 画面ロック防止を解除
                              WakelockPlus.disable();
                              // キャッシュ削除
                              if (Platform.isIOS || Platform.isAndroid) {
                                FilePicker.platform.clearTemporaryFiles();
                              }

                              BotToast.showSimpleNotification(
                                  title: "ファイルの受信が完了しました！",
                                  backgroundColor: colorScheme.onPrimary);
                              allDevices[index].progress = 1;
                              allDevices[index].status = TruckerStatus.received;
                              ref.read(truckerDevicesProvider.notifier).state =
                                  [...allDevices];
                            }

                            // 各ファイルを受信する
                            final controller =
                                await ReceiveFile.receiveAllFiles(
                                    remote, fileInfo, dirPath);

                            // 進捗を適宜更新する
                            final stream = controller.stream;
                            stream.listen((newProgress) {
                              allDevices[index].progress =
                                  newProgress.totalProgress;
                              ref.read(truckerDevicesProvider.notifier).state =
                                  [...allDevices];
                            }, onError: (e) {
                              endProcess();

                              BotToast.showSimpleNotification(
                                  title: "ファイルの受信に失敗しました",
                                  subTitle: e,
                                  backgroundColor: colorScheme.onError);
                            });

                            controller.done.then((_) {
                              endProcess();
                            });
                          }

                          allDevices[index].status =
                              scanType == ServiceType.send
                                  ? TruckerStatus.receiving
                                  : TruckerStatus.sending;
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
                            value: allDevices[index].progress,
                            valueColor: _setLoadingColor(
                                allDevices[index].status,
                                Theme.of(context).colorScheme),
                            strokeWidth: 3.0),
                      )),
                    ],
                  ),
                  Text(
                    devices[index].name,
                    textAlign: TextAlign.center,
                  )
                ],
              );
            },
          ).toList());
    });
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
