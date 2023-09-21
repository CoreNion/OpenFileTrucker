import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:responsive_grid/responsive_grid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:loading_indicator/loading_indicator.dart';

import '../class/file_info.dart';
import '../class/trucker_device.dart';
import '../helper/incoming.dart';
import '../helper/service.dart';
import '../receive.dart';

class TruckerDevicesList extends StatefulWidget {
  /// 送信側かどうか
  final bool isSender;

  const TruckerDevicesList({Key? key, required this.isSender})
      : super(key: key);

  @override
  State<TruckerDevicesList> createState() => _TruckerDevicesListState();
}

class _TruckerDevicesListState extends State<TruckerDevicesList> {
  /// FileTruckerデバイスのリスト
  List<TruckerDevice> _truckerDevices = [];

  ColorScheme _colorScheme = const ColorScheme.light();

  @override
  void initState() {
    super.initState();

    refreshUserInfo = () {
      if (viaServiceDevice.containsKey(_truckerDevices[0].uuid)) {
        final device = viaServiceDevice[_truckerDevices[0].uuid]!;
        viaServiceDevice.remove(_truckerDevices[0].uuid);

        setState(() {
          _truckerDevices = [
            ..._truckerDevices,
            TruckerDevice(
              device.name,
              device.host,
              device.progress,
              device.status,
              device.uuid,
            )
          ];
        });
      }
    };

    // 検知サービスを開始
    startDetectService(widget.isSender ? ServiceType.receive : ServiceType.send,
        (service, status) async {
      setState(() {
        _truckerDevices.add(TruckerDevice(
          service.name!.substring(37),
          service.host!,
          0,
          widget.isSender
              ? TruckerStatus.receiveReady
              : TruckerStatus.sendReady,
          service.name!.substring(0, 36),
        ));
      });
    });
  }

  @override
  void dispose() {
    super.dispose();

    // 検知サービスを停止
    stopDetectService();
  }

  @override
  Widget build(BuildContext context) {
    _colorScheme = Theme.of(context).colorScheme;

    return _truckerDevices.isNotEmpty
        ? ResponsiveGridList(
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
                          onPressed: () => _startConnection(index),
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
                              valueColor: _setLoadingColor(index),
                              strokeWidth: 3.0),
                        )),
                      ],
                    ),
                    Text(
                      _truckerDevices[index].name,
                      textAlign: TextAlign.center,
                    )
                  ],
                );
              },
            ).toList())
        : Container(
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
                      colors: [_colorScheme.primary.withOpacity(1.0)],
                    ))
              ],
            ));
  }

  /// リクエストが要求されたときの処理
  Future<void> _startConnection(int index) async {
    // progressをnullにして、ローディングをくるくるさせる
    setState(() {
      _truckerDevices[index].progress = null;
    });

    final remote = _truckerDevices[index].host;

    if (widget.isSender) {
      // サービス経由で通信しているデバイスリストに追加
      viaServiceDevice.addEntries(
          {MapEntry(_truckerDevices[index].uuid, _truckerDevices[index])});

      // サーバー側にリクエストを送信
      final res = await sendRequest(remote, Platform.localHostname);
      if (!res && mounted) {
        setState(() {
          _truckerDevices[index].progress = 1;
          _truckerDevices[index].status = TruckerStatus.rejected;
        });
        BotToast.showSimpleNotification(
            title: "リクエストが拒否されました",
            subTitle: "拒否された端末: ${_truckerDevices[index].name}",
            backgroundColor: _colorScheme.onError);
        return;
      }
    } else {
      // ファイル情報を取得
      FileInfo fileInfo;
      try {
        fileInfo = await ReceiveFile.getServerFileInfo(remote);
      } catch (e) {
        BotToast.showSimpleNotification(
            title: "送信元に接続できませんでした。",
            subTitle: e,
            backgroundColor: _colorScheme.onError);
        return;
      }

      // 保存場所を取得 (何も入力されない場合は終了)
      final dirPath = await ReceiveFile.getSavePath();
      if (dirPath == null) {
        setState(() {
          _truckerDevices[index].progress = 0;
          _truckerDevices[index].status = TruckerStatus.sendReady;
        });
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
            title: "ファイルの受信が完了しました！", backgroundColor: _colorScheme.onPrimary);
        setState(() {
          _truckerDevices[index].progress = 1;
          _truckerDevices[index].status = TruckerStatus.received;
        });
      }

      // 各ファイルを受信する
      final controller =
          await ReceiveFile.receiveAllFiles(remote, fileInfo, dirPath);

      // 進捗を適宜更新する
      final stream = controller.stream;
      stream.listen((newProgress) {
        setState(() {
          _truckerDevices[index].progress = newProgress.totalProgress;
        });
      }, onError: (e) {
        endProcess();

        BotToast.showSimpleNotification(
            title: "ファイルの受信に失敗しました",
            subTitle: e,
            backgroundColor: _colorScheme.onError);
      });

      controller.done.then((_) {
        endProcess();
      });
    }

    setState(() {
      _truckerDevices[index].status =
          widget.isSender ? TruckerStatus.receiving : TruckerStatus.sending;
    });
  }

  /// ローディングの色を設定
  Animation<Color> _setLoadingColor(int index) {
    switch (_truckerDevices[index].status) {
      case TruckerStatus.receiving:
      case TruckerStatus.sending:
        return AlwaysStoppedAnimation<Color>(_colorScheme.secondary);
      case TruckerStatus.rejected:
      case TruckerStatus.failed:
        return AlwaysStoppedAnimation<Color>(_colorScheme.error);
      default:
        return AlwaysStoppedAnimation<Color>(_colorScheme.primary);
    }
  }
}
