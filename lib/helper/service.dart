import 'dart:async';

import 'package:nsd/nsd.dart';

enum ServiceType { send, receive }

Discovery? discovery;
Registration? registration;

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
    if (status == ServiceStatus.found && service.name == 'FileTrucker') {
      onDetect(service, status);
    }
  });
}

Future<void> stopDetectService() async {
  if (discovery == null) return;
  await stopDiscovery(discovery!);
}

Future<void> registerNsd(ServiceType mode) async {
  late String type;
  if (mode == ServiceType.send) {
    type = '_trucker-send._tcp';
  } else {
    type = '_trucker-receive._tcp';
  }

  registration = await register(Service(
    name: 'FileTrucker',
    port: 4782,
    type: type,
  ));
}

Future<void> unregisterNsd() async {
  if (registration == null) return;
  await unregister(registration!);
}
