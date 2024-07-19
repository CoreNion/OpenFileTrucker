import 'dart:async';

import 'package:async/async.dart';
import 'package:bonsoir/bonsoir.dart';

import '../class/trucker_device.dart';
import '../main.dart';

enum ServiceType { send, receive }

// Bonsoirの各種インスタンス
BonsoirBroadcast? sendBroadcast;
BonsoirDiscovery? sendDiscovery;
BonsoirBroadcast? receiveBroadcast;
BonsoirDiscovery? receiveDiscovery;

void Function() refreshUserInfo = () {};

// ホスト名リクエストのデータ保持
Map<String, Completer<String?>> _requestHostList = {};

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
        if (!(event.type == BonsoirDiscoveryEventType.discoveryServiceLost)) {
          // [UUID]:[端末名]から端末名を取得
          final serviceName = event.service!.name;
          final infos = serviceName.split(':');

          // 名前解決が検知されたら、リクエスト待ちのCompleterを完了させる
          String? host;
          if (event.type ==
              BonsoirDiscoveryEventType.discoveryServiceResolved) {
            host = (event.service! as ResolvedBonsoirService).host;
            if (_requestHostList.containsKey(infos[1])) {
              _requestHostList[infos[1]]!.complete(host);
            }
          }

          // 発見した端末をTruckerDeviceに変換
          final device = TruckerDevice(
            infos[1],
            host,
            event.service!,
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

/// ホスト名をリクエストする
Future<String?> requestHostName(
    BonsoirService service, ServiceType type) async {
  final hostUUID = service.name.split(":")[1];
  // リクエスト待ちのCompleterを作成
  _requestHostList[hostUUID] = Completer<String?>();

  // 名前解決をリクエスト
  await service.resolve(
      (type == ServiceType.send ? sendDiscovery! : receiveDiscovery!)
          .serviceResolver);
  // ブロードキャストが名前解決を検知するので、そこからホスト名を取得してcompleteする
  final host = await _requestHostList[hostUUID]!.future;

  _requestHostList.remove(hostUUID);
  return host;
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
  final mName = "$myUUID:$name";

  // 送信/受信のタイプを指定
  late String type;
  late int port;
  if (mode == ServiceType.send) {
    type = '_trucker-send._tcp';
    port = 4782;
  } else {
    type = '_trucker-receive._tcp';
    port = 4783;
  }

  // BonsoirServiceを作成
  // iOS17のデバイスで登録端末の検知率が低い問題を回避するため、pathのTXTレコードを追加
  // https://github.com/esp8266/Arduino/issues/9046
  BonsoirService service = BonsoirService(
      name: mName, port: port, type: type, attributes: {"path": "/"});

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

  return myUUID;
}

/// 名前解決サービスの登録を解除
Future<void> unregisterNsd(ServiceType mode) async {
  if (mode == ServiceType.send) {
    await sendBroadcast?.stop();
  } else {
    await receiveBroadcast?.stop();
  }
}
