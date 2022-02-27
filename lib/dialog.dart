import 'dart:io';

import 'package:flutter/material.dart';

class EasyDialog {
  /// 小規模なダイアログを表示する
  static Widget showSmallInfo(
      BuildContext context, String title, String content) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: <Widget>[
        TextButton(
          child: const Text("OK"),
          onPressed: () => Navigator.pop(context),
        )
      ],
    );
  }

  /// エラーのダイアログを表示する
  static Future<void> showErrorDialog(Exception e, BuildContext context) {
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
        exceptionMessage = "詳細:\n" + e.toString();
      }
    } else if (e is IOException) {
      errorTitle = "I/Oエラー";
      errorMessage = "ファイルの読み書き中にエラーが発生しました。\n";
      exceptionMessage = "詳細:\n" + e.toString();
    } else {
      errorTitle = "不明なエラー";
      errorMessage = "エラーが発生しました。\n";
      exceptionMessage = "詳細:\n" + e.toString();
    }

    return showDialog(
        context: context,
        builder: (builder) {
          return AlertDialog(
            title: Text(errorTitle),
            content: Text(errorMessage + exceptionMessage),
            actions: <Widget>[
              TextButton(
                child: const Text("閉じる"),
                onPressed: () => Navigator.pop(context),
              )
            ],
          );
        });
  }
}
