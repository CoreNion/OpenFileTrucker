import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:file_sizes/file_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file_trucker/widget/dialog.dart';
import 'package:open_file_trucker/receive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file_trucker/widget/receive_qr.dart';
import 'package:wakelock/wakelock.dart';

import '../class/file_info.dart';
import '../class/qr_data.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({Key? key}) : super(key: key);

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Widget> sucsessWidght = Platform.isAndroid
      ? <Widget>[
          const Text(
            "Androidでは、選択が可能なフォルダーでもファイルを保存できない場合があります。\n特に指定が無い場合、「ダウンロード」フォルダーにFileTrucker用のフォルダーを作成し、そこにファイルを保存することがおすすめです。",
            textAlign: TextAlign.center,
          )
        ]
      : <Widget>[];

  bool bypassAdressCheck = false;

  TextEditingController textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final formKey = GlobalKey<FormState>();
    String ip = "";

    // String key = "";

    late Widget? qrButton;
    if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
      qrButton = FloatingActionButton(
        onPressed: () async {
          final nav = Navigator.of(context);

          // QR読み取り画面に移管する
          void popQRScreen() {
            Navigator.of(context)
                .push(MaterialPageRoute(
                    builder: (builder) => const ScanQRCodePage()))
                .then((result) {
              if (result is QRCodeData) {
                // 読み取りが終了したら受信開始
                _startReceive(result.ip);
              } else {
                Wakelock.disable();
              }
            });
          }

          // 権限の確認
          if (Platform.isIOS || Platform.isAndroid) {
            if (await Permission.camera.request().isGranted) {
              popQRScreen();
            } else {
              EasyDialog.showPermissionAlert(
                  "QRコードを読み取るためには、カメラへのアクセスの許可が必要です。", nav);
            }
          } else if (Platform.isMacOS) {
            // 権限の取得などに独自実装が必要なOS
            const platform =
                MethodChannel('com.corenion.filetrucker/permission');
            final request =
                await platform.invokeMethod("requestCameraPermission");

            if (request == null) {
              EasyDialog.showErrorDialog("権限の要求中にエラーが発生しました。", nav);
            } else if (request) {
              popQRScreen();
            } else {
              EasyDialog.showSmallInfo(
                  nav, "権限が必要です", "QRコードを読み取るためには、カメラへのアクセスの許可が必要です。");
            }
          }
        },
        tooltip: "QRコードを利用する",
        child: const Icon(Icons.qr_code),
      );
    } else {
      // 非対応端末では表示しない
      qrButton = null;
    }

    return SafeArea(
        child: Scaffold(
            body: Container(
              margin: const EdgeInsets.all(10),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'IP Address',
                        hintText: 'IPアドレスを入力',
                        icon: Icon(Icons.connect_without_contact),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '値を入力してください';
                        } else if (!bypassAdressCheck &&
                            !RegExp(r"(^(127(?:\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}$)|(10(?:\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}$)|(192\.168(?:\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}$)|(172\.(?:1[6-9]|2\d|3[0-1])(?:\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){2}$))")
                                .hasMatch(value)) {
                          return "正しいIPアドレスを入力してください。(IPv4 / プライベートIPアドレスのみ入力可能)";
                        }
                        return null;
                      },
                      onSaved: (newValue) => ip = newValue!,
                      controller: textEditingController,
                    ),
                    /* 
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Key (任意)',
                          hintText: 'Keyを入力(設定している場合のみ)',
                          icon: Icon(Icons.vpn_key)),
                      obscureText: true,
                      onSaved: (newValue) => key = newValue!,
                    ), */
                    SwitchListTile(
                      value: bypassAdressCheck,
                      title: const Text('IPアドレスの確認を行わない'),
                      subtitle: const Text("正しいIPアドレスを入力しても正しくない判定になる場合に利用"),
                      onChanged: (bool value) => setState(() {
                        bypassAdressCheck = value;
                      }),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 30),
                      height: 40,
                      width: double.infinity,
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                          child: const Text("ファイルを受信"),
                          onPressed: () async {
                            // 値のチェック
                            if (formKey.currentState != null) {
                              if (formKey.currentState!.validate()) {
                                formKey.currentState!.save();
                                _startReceive(ip);
                              }
                            }
                          }),
                    ),
                    Column(children: sucsessWidght),
                  ],
                ),
              ),
            ),
            floatingActionButton: qrButton));
  }

  Future<void> _startReceive(String ip /*, String key  */) async {
    int currentIndex = 0;
    late FileInfo fileInfo;
    late StreamController<ReceiveProgress> controller;

    // スリープ無効化
    Wakelock.enable();

    // ダイアログ関連の変数
    bool receiveReady = false;
    final setStateCompleter = Completer<Function>();
    ReceiveProgress progress = ReceiveProgress(
        currentFileIndex: 0,
        totalProgress: 0,
        singleProgress: 0,
        receiveSpeed: 0,
        currentFileSize: 0,
        currentTotalSize: 0);

    showDialog(
        context: context,
        builder: (context) {
          return WillPopScope(
            // 戻る無効化
            onWillPop: (() => Future.value(false)),
            child: StatefulBuilder(builder: (stContext, dialogSetState) {
              // Progressの更新のためのSetStateを外でも使えるようにする
              // setState読み込みより先にdialogSetStateが呼び出されることがあるのでCompleterを利用して対策
              if (!setStateCompleter.isCompleted) {
                setStateCompleter.complete(dialogSetState);
              }

              return AlertDialog(
                scrollable: true,
                title: Text(receiveReady ? "ファイルを受信しています..." : "端末に接続しています..."),
                actions: receiveReady
                    ? <Widget>[
                        TextButton(
                            child: const Text("キャンセル"),
                            onPressed: () {
                              controller.close();

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("ファイルの受信はキャンセルされました。"),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            })
                      ]
                    : null,
                content: Column(
                  children: [
                    Text(
                      receiveReady
                          ? "${progress.currentFileIndex! + 1}個目のファイルを受信中 ${(progress.totalProgress! * 100).toStringAsFixed(1)}%完了"
                          : "",
                      textAlign: TextAlign.center,
                    ),
                    LinearProgressIndicator(
                      value: receiveReady ? progress.totalProgress : null,
                    ),
                    Text(
                      receiveReady
                          ? "${fileInfo.names[progress.currentFileIndex!]} ${(progress.singleProgress * 100).toStringAsFixed(1)}%完了"
                          : "",
                      textAlign: TextAlign.center,
                    ),
                    LinearProgressIndicator(
                      value: progress.singleProgress,
                    ),
                    Text(
                      receiveReady
                          ? "速度: ${FileSize.getSize(progress.receiveSpeed)}/s"
                          : "",
                      textAlign: TextAlign.right,
                    )
                  ],
                ),
              );
            }),
          );
        });

    try {
      // ファイル情報を取得
      fileInfo = await ReceiveFile.getServerFileInfo(ip);
    } catch (e) {
      Navigator.pop(context);
      EasyDialog.showErrorDialog(e, Navigator.of(context));
      return;
    }

    // 保存場所を取得 (何も入力されない場合は終了)
    final dirPath = await ReceiveFile.getSavePath();
    if (dirPath == null) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    // ダイアログ更新
    final dialogSetState = await setStateCompleter.future;
    dialogSetState(() {
      receiveReady = true;
    });

    // 全ファイルの受信の終了時の処理(異常終了関係なし)
    void endProcess() {
      // 画面ロック防止を解除
      Wakelock.disable();
      // キャッシュ削除
      if (Platform.isIOS || Platform.isAndroid) {
        FilePicker.platform.clearTemporaryFiles();
      }

      Navigator.pop(context);
    }

    // 各ファイルを受信する
    controller = await ReceiveFile.receiveAllFiles(ip, fileInfo, dirPath);
    // 進捗を適宜更新する
    final stream = controller.stream;
    stream.listen((newProgress) {
      dialogSetState(() {
        progress = newProgress;
      });
    }, onError: (e) {
      endProcess();

      EasyDialog.showErrorDialog(e, Navigator.of(context));
      return;
    });
    await controller.done;

    /* ファイルの受信完了時の処理 */

    // iOSで画像/動画のみかを確認する
    final iosAndOnlyMedia =
        Platform.isIOS ? ReceiveFile.checkMediaOnly(fileInfo) : false;

    if (fileInfo.hashs != null) {
      // ハッシュ値のチェック
      showDialog(
          context: context,
          builder: (_) {
            return WillPopScope(
              // 戻る無効化
              onWillPop: () => Future.value(false),
              child: const AlertDialog(
                title: Text(
                  "整合性を確認しています...",
                  textAlign: TextAlign.center,
                ),
                content: Text("ファイルの大きさなどによっては、時間がかかる場合があります。"),
              ),
            );
          });

      try {
        if (!(await ReceiveFile.checkFileHash(dirPath, fileInfo))) {
          await EasyDialog.showErrorDialog(
              const FileSystemException(
                  "ファイルはダウンロードされましたが、整合性が確認できませんでした。\n安定した環境でファイルの共有を行ってください。"),
              Navigator.of(context));
        }
      } catch (e) {
        await EasyDialog.showErrorDialog(e, Navigator.of(context));
      }

      Navigator.pop(context);
    }

    if (iosAndOnlyMedia) {
      final savePhotoLibrary = await showDialog(
          context: context,
          builder: ((context) {
            return AlertDialog(
              title: const Text("写真/動画の保存場所の確認"),
              content:
                  const Text("写真ライブラリにも画像や動画を保存しますか？\n(アプリ内のフォルダーには保存済みです。)"),
              actions: <Widget>[
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("はい")),
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("いいえ")),
              ],
            );
          }));

      if (savePhotoLibrary) {
        try {
          final res = await ReceiveFile.savePhotoLibrary(dirPath, fileInfo);
          if (!res) {
            EasyDialog.showPermissionAlert(
                "写真ライブラリに画像を保存するには、ライブラリへの権限が必要です。", Navigator.of(context));
          }
        } catch (e) {
          EasyDialog.showErrorDialog(e, Navigator.of(context));
        }
      }
    }

    // 終了処理
    endProcess();
    // 結果のメッセージを削除し、新しいメッセージを表示
    setState(() {
      sucsessWidght.clear();
      sucsessWidght.add(const Text("ファイルの受信が完了しました",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 25, color: Colors.red, fontWeight: FontWeight.bold)));
      if (Platform.isIOS) {
        sucsessWidght.add(const Text(
            '\niOSではファイルは、アプリ用のフォルダーに格納されています。\n内蔵の「ファイル」アプリなどから閲覧/操作したり、他のアプリでのファイル選択時にこのアプリのフォルダーを閲覧することによって、利用可能です。',
            textAlign: TextAlign.start));
      }
    });
  }
}
