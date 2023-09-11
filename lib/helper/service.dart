import 'dart:async';

import 'package:nsd/nsd.dart';

Discovery? discovery;
Registration? registration;

Future<void> startDetectService(
    FutureOr<void> Function(Service, ServiceStatus) onDetect) async {
  discovery = await startDiscovery('_trucker._tcp');

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

Future<void> registerNsd() async {
  registration = await register(const Service(
    name: 'FileTrucker',
    port: 4782,
    type: '_trucker._tcp',
  ));
}

Future<void> unregisterNsd() async {
  if (registration == null) return;
  await unregister(registration!);
}
