import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webcrypto/webcrypto.dart';

class EasyDialog {
  /// 小規模なダイアログを表示する
  static Widget showSmallInfo(
      NavigatorState nav, String title, String content) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: <Widget>[
        TextButton(
          child: const Text("OK"),
          onPressed: () => nav.pop(),
        )
      ],
    );
  }

  /// エラーのダイアログを表示する
  static Future<void> showErrorDialog(e, NavigatorState nav) {
    late String errorTitle;
    late String errorMessage;
    String exceptionMessage = "";

    if (e is SocketException) {
      if (e.message.contains("cancel")) {
        errorTitle = "情報";
        errorMessage = "操作はキャンセルされました。";
      } else {
        errorTitle = "通信エラー";
        errorMessage = "通信エラーが発生しました。\n入力された値が正しいか、ネットワークに問題が無いか確認してください。\n";
        exceptionMessage = "詳細:\n$e";
      }
    } else if (e is IOException) {
      errorTitle = "I/Oエラー";
      errorMessage = "ファイルの読み書き中にエラーが発生しました。\n";
      exceptionMessage = "詳細:\n$e";
    } else if (e is OperationError) {
      errorTitle = "Sodiumエラー";
      errorMessage =
          "webcryptでの処理中にエラーが発生しました。\nこの端末では、整合性確認機能などは利用できない可能性があります。\n";
      exceptionMessage = "詳細:\n$e";
    } else {
      errorTitle = "不明なエラー";
      errorMessage = "エラーが発生しました。\n";
      exceptionMessage = "詳細:\n$e";
    }

    return showDialog(
        context: nav.context,
        builder: (builder) {
          return AlertDialog(
            title: Text(errorTitle),
            content: Text(errorMessage + exceptionMessage),
            actions: <Widget>[
              TextButton(
                child: const Text("閉じる"),
                onPressed: () => nav.pop(),
              )
            ],
          );
        });
  }

  /// 権限が必要であることを伝えるダイアログを表示する
  static Future<void> showPermissionAlert(String reason, NavigatorState nav) {
    return showDialog(
        context: nav.context,
        builder: (_) {
          return AlertDialog(
            title: const Text("権限が必要です"),
            content: Text(reason),
            actions: <Widget>[
              TextButton(
                child: const Text("設定を開く"),
                onPressed: () => openAppSettings(),
              ),
              TextButton(
                child: const Text("閉じる"),
                onPressed: () => nav.pop(),
              )
            ],
          );
        });
  }
}
