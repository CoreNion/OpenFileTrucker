import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool?> checkLocalnetPermission() async {
  if (Platform.isWindows) {
    // Windowsの場合、ファイヤーウォールの設定を確認
    final res = await Process.run("powershell", [
      "netsh",
      "advfirewall",
      "firewall",
      "show",
      "rule",
      "name=FileTrucker"
    ]);
    return res.exitCode == 0;
  }

  // ダミーのサーバーを立てて接続を試みる
  try {
    final sendSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 4782);
    await sendSocket.close();
    return true;
  } catch (e) {
    return false;
  }
}

Future<bool?> requestLocalnetPermission() async {
  if (Platform.isIOS) {
    return openAppSettings();
  } else if (Platform.isMacOS) {
    // 権限の取得などに独自実装が必要なOS向け処理
    const platform = MethodChannel('dev.cnion.trucker/permission');
    final request = await platform.invokeMethod("requestLocalnetPermission");

    if (request == null) {
      return null;
    } else {
      return request;
    }
  } else if (Platform.isWindows) {
    // 管理者権限のcmdを立ち上げ、ファイヤーウォールのルールを追加
    const dirInCmd =
        "netsh advfirewall firewall add rule name=\"FileTrucker\" dir=in action=allow protocol=TCP localport=4782,4783";
    const dirOutCmd =
        "netsh advfirewall firewall add rule name=\"FileTrucker\" dir=out action=allow protocol=TCP localport=4782,4783";

    final res = await Process.run("powershell", [
      "Start-Process",
      "-Verb",
      "RunAs",
      "cmd",
      "-Args",
      "/c, '$dirInCmd & $dirOutCmd & pause'"
    ]);
    return res.exitCode == 0;
  } else {
    return true;
  }
}

Future<bool?> checkPhotosPermission() async {
  if (Platform.isIOS) {
    return Permission.photos.isGranted;
  } else {
    return true;
  }
}

Future<bool?> requestPhotosPermission() async {
  if (Platform.isIOS) {
    return Permission.photos.request().isGranted;
  } else {
    return true;
  }
}

Future<bool?> checkCamPermission() async {
  if (Platform.isIOS || Platform.isAndroid) {
    return Permission.camera.isGranted;
  } else if (Platform.isMacOS) {
    // 権限の取得などに独自実装が必要なOS向け処理
    const platform = MethodChannel('dev.cnion.trucker/permission');
    final status = await platform.invokeMethod("checkCameraPermission");

    if (status == null) {
      return null;
    } else {
      return status;
    }
  } else {
    return null;
  }
}

Future<bool?> requestCamPermission() async {
  if (Platform.isIOS || Platform.isAndroid) {
    return Permission.camera.request().isGranted;
  } else if (Platform.isMacOS) {
    // 権限の取得などに独自実装が必要なOS向け処理
    const platform = MethodChannel('dev.cnion.trucker/permission');
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
