import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool?> checkCamPermission() async {
  if (Platform.isIOS || Platform.isAndroid) {
    return Permission.camera.request().isGranted;
  } else if (Platform.isMacOS) {
    // 権限の取得などに独自実装が必要なOS向け処理
    const platform = MethodChannel('com.corenion.filetrucker/permission');
    final request = await platform.invokeMethod("requestCameraPermission");

    if (request == null) {
      return null;
    } else {
      return request;
    }
  } else {
    return null;
  }
}
