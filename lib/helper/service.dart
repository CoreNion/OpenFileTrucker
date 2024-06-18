import 'dart:async';

import 'package:async/async.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:uuid/uuid.dart';

import '../class/trucker_device.dart';

enum ServiceType { send, receive }

BonsoirBroadcast? sendBroadcast;
BonsoirDiscovery? sendDiscovery;
BonsoirBroadcast? receiveBroadcast;
BonsoirDiscovery? receiveDiscovery;

final uuid = const Uuid().v4();

void Function() refreshUserInfo = () {};

/// Truckerな端末をスキャンし、発見次第Streamで流す
Future<Stream<TruckerDevice>> scanTruckerService() async {
  // それぞれのBonsoirDiscoveryを作成
  sendDiscovery = BonsoirDiscovery(
    type: '_trucker-send._tcp',
  );
  receiveDiscovery = BonsoirDiscovery(
    type: '_trucker-receive._tcp',
  );

  // スキャン開始
  await sendDiscovery!.ready;
  await sendDiscovery!.start();
  await receiveDiscovery!.ready;
  await receiveDiscovery!.start();

  if (sendDiscovery!.eventStream == null ||
      receiveDiscovery!.eventStream == null) {
    throw Exception("Discovery Stream is null");
  }

  // 送信検知と受信検知のストリームををマージ
  final rsStream = StreamGroup.merge([
    sendDiscovery!.eventStream!,
    receiveDiscovery!.eventStream!,
  ]);

  // ストリームをTruckerDeviceに変換して返す
  return rsStream.transform(
    StreamTransformer.fromHandlers(
      handleData: (BonsoirDiscoveryEvent event, EventSink<TruckerDevice> sink) {
        if (event.service == null) return;
        // 送信か受信かを判定
        final type = event.service!.type == '_trucker-send._tcp'
            ? ServiceType.send
            : ServiceType.receive;
        // それぞれのDiscoveryを取得
        final discovery =
            type == ServiceType.send ? sendDiscovery! : receiveDiscovery!;

        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          // 名前解決
          event.service!.resolve(discovery.serviceResolver);
        } else if (event.type ==
            BonsoirDiscoveryEventType.discoveryServiceResolved) {
          // 解決済みサービスとみなす
          final service = event.service! as ResolvedBonsoirService;
          // 万が一ホスト名がnullの場合は無視
          if (service.host == null) return;

          // [UUID]:[端末名]から端末名を取得
          final serviceName = service.name;
          final infos = serviceName.split(':');

          // 発見した端末をTruckerDeviceに変換
          final device = TruckerDevice(
            infos[1],
            service.host!,
            0,
            type == ServiceType.send
                ? TruckerStatus.receiveReady
                : TruckerStatus.sendReady,
            infos[0],
          );

          // Streamに流す
          sink.add(device);
        }
      },
    ),
  );
}

void stopDetectService(ServiceType mode) {
  if (mode == ServiceType.send) {
    sendDiscovery?.stop();
  } else {
    receiveDiscovery?.stop();
  }
}

/// 名前解決サービスに登録する
/// [mode] 登録するサービスの種類
/// [name] 端末名
Future<String> registerNsd(ServiceType mode, String name) async {
  // 名前にUUIDを追加
  final mName = "$uuid:$name";

  // 送信/受信のタイプを指定
  late String type;
  if (mode == ServiceType.send) {
    type = '_trucker-send._tcp';
  } else {
    type = '_trucker-receive._tcp';
  }

  // BonsoirServiceを作成
  BonsoirService service = BonsoirService(
    name: mName,
    port: 4782,
    type: type,
  );

  // タイプに応じて、BonsoirBroadcastを作成
  if (mode == ServiceType.send) {
    sendBroadcast = BonsoirBroadcast(service: service);
    await sendBroadcast!.ready;
    await sendBroadcast!.start();
  } else {
    receiveBroadcast = BonsoirBroadcast(service: service);
    await receiveBroadcast!.ready;
    await receiveBroadcast!.start();
  }

  return uuid;
}

/// 名前解決サービスの登録を解除
Future<void> unregisterNsd(ServiceType mode) async {
  if (mode == ServiceType.send) {
    await sendBroadcast?.stop();
  } else {
    await receiveBroadcast?.stop();
  }
}
