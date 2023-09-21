import 'dart:async';

import 'package:nsd/nsd.dart';
import 'package:uuid/uuid.dart';

enum ServiceType { send, receive }

Discovery? discovery;
Registration? registration;
final uuid = const Uuid().v4();

void Function() refreshUserInfo = () {};

Future<void> startDetectService(ServiceType mode,
    FutureOr<void> Function(Service, ServiceStatus) onDetect) async {
  late String type;
  if (mode == ServiceType.send) {
    type = '_trucker-send._tcp';
  } else {
    type = '_trucker-receive._tcp';
  }
  discovery = await startDiscovery(type);

  discovery!.addServiceListener((service, status) {
    if (status == ServiceStatus.found) {
      onDetect(service, status);
    }
  });
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
