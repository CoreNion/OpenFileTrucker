import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';
import 'package:nsd/nsd.dart';
import 'package:uuid/uuid.dart';

import '../class/trucker_device.dart';

enum ServiceType { send, receive }

bool discovery = false;

Registration? registration;
final uuid = const Uuid().v4();

void Function() refreshUserInfo = () {};

/// Truckerな端末をスキャンし、発見次第Streamで流す
Stream<TruckerDevice> scanTruckerService(ServiceType mode) async* {
  if (discovery) return;
  discovery = true;

  late String type;
  if (mode == ServiceType.send) {
    type = '_trucker-send._tcp';
  } else {
    type = '_trucker-receive._tcp';
  }

  // MDnsClientのインスタンスを生成
  final MDnsClient client = MDnsClient(rawDatagramSocketFactory:
      (dynamic host, int port,
          {bool? reuseAddress, bool? reusePort, int? ttl}) {
    // WindowsなどでreusePortをtrueにするとエラーが発生するため設定を変更
    // https://github.com/flutter/flutter/issues/106881
    return RawDatagramSocket.bind(host, port,
        reuseAddress: true,
        reusePort: Platform.isWindows || Platform.isAndroid ? false : true,
        ttl: ttl!);
  });

  // MDnsClientのスタート
  await client.start(
    // LinkLocalのアドレスによる不具合を回避
    // https://github.com/flutter/flutter/issues/106881
    interfacesFactory: (type) async {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: type,
        includeLoopback: false,
      );
      return interfaces;
    },
  );

  // TO DO: streamがキャンセルされた時に処理を止める
  while (discovery) {
    // サービスの検索
    await for (final PtrResourceRecord ptr in client
        .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(type))) {
      await for (final SrvResourceRecord srv
          in client.lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName))) {
        // ドメイン名を取得
        final domainName = ptr.domainName;

        // [UUID]:[端末名].[サービス名]から端末名を取得
        final regExp = RegExp(r'(?<=:)(.*?)(?=\.)');
        Match? match = regExp.firstMatch(domainName);

        yield TruckerDevice(
          match?.group(0) ?? 'デバイス名不明',
          srv.target,
          0,
          mode == ServiceType.send
              ? TruckerStatus.receiveReady
              : TruckerStatus.sendReady,
          domainName.substring(0, 36),
        );
      }
    }
  }
}

void stopDetectService() {
  discovery = false;
}

Future<String> registerNsd(ServiceType mode, String name) async {
  // 名前にUUIDを追加
  final mName = "$uuid:$name";

  late String type;
  if (mode == ServiceType.send) {
    type = '_trucker-send._tcp';
  } else {
    type = '_trucker-receive._tcp';
  }

  registration = await register(Service(
    name: mName,
    port: 4782,
    type: type,
  ));

  return uuid;
}

Future<void> unregisterNsd() async {
  if (registration == null) return;
  await unregister(registration!);
}
