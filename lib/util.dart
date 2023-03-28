import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

/// ユーザーが設定した端末の名前を取得
Future<String?> getUserDeviceName() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    const platform = MethodChannel('com.corenion.filetrucker/info');
    late String res;

    try {
      res = await platform.invokeMethod('getUserDeviceName');
    } on PlatformException {
      res = (await deviceInfo.androidInfo).model;
    }
    return res;
  } else if (Platform.isIOS) {
    return (await deviceInfo.iosInfo).name;
  } else if (Platform.isWindows) {
    return (await deviceInfo.windowsInfo).computerName;
  } else if (Platform.isMacOS) {
    return (await deviceInfo.macOsInfo).computerName;
  } else if (Platform.isLinux) {
    return "${(await deviceInfo.linuxInfo).prettyName} [${Platform.localHostname}]";
  } else {
    return null;
  }
}
