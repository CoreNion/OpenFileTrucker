import 'dart:async';

import 'package:nsd/nsd.dart';
import 'package:uuid/uuid.dart';

import '../class/trucker_device.dart';

enum ServiceType { send, receive }

Discovery? discovery;
Registration? registration;
final uuid = const Uuid().v4();

void Function() refreshUserInfo = () {};

/// Truckerな端末をスキャンし、発見次第Streamで流す
Stream<TruckerDevice> scanTruckerService(ServiceType mode) async* {
  late String type;
  if (mode == ServiceType.send) {
    type = '_trucker-send._tcp';
  } else {
    type = '_trucker-receive._tcp';
  }
  discovery = await startDiscovery(type, ipLookupType: IpLookupType.v4);

  final streamController = StreamController<TruckerDevice>();
  discovery!.addServiceListener((service, status) {
    if (status == ServiceStatus.found) {
      streamController.add(TruckerDevice(
        service.name!.substring(37),
        service.addresses!.first.address,
        0,
        mode == ServiceType.send
            ? TruckerStatus.receiveReady
            : TruckerStatus.sendReady,
        service.name!.substring(0, 36),
      ));
    }
  });

  yield* streamController.stream;
}

Future<void> stopDetectService() async {
  if (discovery == null) return;
  await stopDiscovery(discovery!);
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
