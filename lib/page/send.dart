import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_sizes/file_sizes.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_handler/share_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webcrypto/webcrypto.dart';

import '../class/send_settings.dart';
import '../widget/send_settings.dart';
import '../widget/dialog.dart';
import '../send.dart';

class SendPage extends StatefulWidget {
  const SendPage({Key? key}) : super(key: key);

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late ColorScheme colorScheme;

  late bool isSmallUI;
  List<XFile> selectedFiles = <XFile>[];
  String selectFileButtonText = "";
  SendSettings settings = SendSettings();

  String ipText = "";
  String keyText = "";
  Widget qrCode = Container();
  Widget stopServerButton = Container();
  bool serverListen = false;

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid || Platform.isIOS) {
      // ファイル共有APIからの処理のInit
      initShareHandlerPlatformState();
    }
  }

  /// ファイル共有API関連の処理
  Future<void> initShareHandlerPlatformState() async {
    final handler = ShareHandlerPlatform.instance;
    final media = await handler.getInitialSharedMedia();
    List<XFile> files = [];

    void setShareFiles(SharedMedia? sharedMedia) {
      if (sharedMedia != null && sharedMedia.attachments != null) {
        // 各ファイルをXFileにして、ファイル設定を行う
        for (var i = 0; i < sharedMedia.attachments!.length; i++) {
          files.add(XFile(sharedMedia.attachments![i]!.path));
        }
        _setFiles(files);
      }
    }

    // 起動時に来た共有ファイルを処理する
    setShareFiles(media);

    // アプリ実行中に来た時用
    handler.sharedMediaStream.listen((SharedMedia media) {
      setShareFiles(media);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    colorScheme = Theme.of(context).colorScheme;

    return SafeArea(child: LayoutBuilder(
      builder: (context, constraints) {
        // サイズごとにUIを変える
        final pageWidth = constraints.maxWidth;
        if (pageWidth >= 800) {
          isSmallUI = false;
          return largeUI();
        } else {
          isSmallUI = true;
          return smallUI();
        }
      },
    ));
  }

  /// 大きな画面やウィンドウに最適化された送信ページのUI
  Scaffold largeUI() {
    return Scaffold(
        body: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 5, child: selectFileArea()),
            Expanded(
                flex: 5,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                        left: BorderSide(
                      color: Colors.grey,
                    )),
                  ),
                  child: senderInfoArea(),
                ))
          ],
        ),
        floatingActionButton: stopServerButton);
  }

  /// 小さな画面やウィンドウに最適化された送信ページのUI
  Scaffold smallUI() {
    return Scaffold(
        body: selectFileArea(), floatingActionButton: stopServerButton);
  }

  /// selectedFilesからファイル選択ボタンに書かれる文章を設定
  Future<void> _setFileInfo() async {
    int totalSize = 0;
    // サイズを取得
    for (XFile file in selectedFiles) {
      int fileLength = await file.length();
      totalSize += fileLength;
    }

    setState(() {
      selectFileButtonText = FileSize.getSize(totalSize);
    });
  }

  /// ファイルを選択する部分のUI
  Widget selectFileArea() {
    return Column(children: <Widget>[
      Container(
        color: colorScheme.background,
        padding: const EdgeInsets.only(left: 15, right: 15, top: 5, bottom: 5),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton.filled(
              onPressed: () async {
                await showDialog(
                    context: context, builder: (context) => _selectFileType());
                await _setFileInfo();
              },
              icon: const Icon(Icons.add)),
          Text(
            "${selectedFiles.length}個のファイル   合計: $selectFileButtonText",
            style: const TextStyle(fontSize: 17),
          ),
        ]),
      ),
      Expanded(
        flex: 8,
        child: DropTarget(
            onDragDone: (detail) {
              // ドロップされたファイルの情報を記録
              final file = detail.files;
              for (var i = 0; i < file.length; i++) {
                if (selectedFiles.contains(file[i])) {
                  continue;
                }
                selectedFiles.add(XFile(file[i].path));
              }
              _setFileInfo();
            },
            child: selectedFiles.isEmpty
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      child: ElevatedButton(
                        onPressed: () async {
                          await showDialog(
                              context: context,
                              builder: (context) => _selectFileType());
                          await _setFileInfo();
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            )),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.file_open, size: 100),
                              Text(
                                "タップでファイルを追加\nまたはドラック＆ドロップ",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 20),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemBuilder: (context, index) {
                      return Dismissible(
                        key: Key(selectedFiles[index].path),
                        background: Container(
                          color: colorScheme.errorContainer,
                          alignment: Alignment.centerLeft,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                        ),
                        onDismissed: (direction) {
                          setState(() {
                            selectedFiles.removeAt(index);
                            _setFileInfo();
                          });
                        },
                        child: ListTile(
                            title: Text(p.basename(selectedFiles[index].path)),
                            leading: IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedFiles.removeAt(index);
                                    _setFileInfo();
                                  });
                                },
                                icon: const Icon(Icons.delete))),
                      );
                    },
                    itemCount: selectedFiles.length)),
      ),
      Expanded(
          flex: 1,
          child: Container(
            margin: const EdgeInsets.all(7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    flex: 8,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Text("送信する"),
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        if (serverListen) {
                          showDialog(
                              context: context,
                              builder: (context) => EasyDialog.showSmallInfo(
                                  nav, "エラー", "他のファイルの共有を停止してください。"));
                        } else if (selectedFiles.isNotEmpty) {
                          try {
                            final networks =
                                await SendFiles.getAvailableNetworks();
                            late String ip;

                            // 利用可能なネットワークが無い場合は終了
                            if (networks == null) {
                              showDialog(
                                  context: context,
                                  builder: (context) =>
                                      EasyDialog.showSmallInfo(
                                          Navigator.of(context),
                                          "エラー",
                                          "WiFiやイーサーネットなどに接続してください。"));
                              return;
                            }

                            // ネットワークが2つ以上ある場合はユーザーにネットワークを選択させる
                            if (networks.length > 1) {
                              // 選択肢のDialogOptionに追加する
                              List<SimpleDialogOption> dialogOptions = [];
                              for (var network in networks) {
                                dialogOptions.add(SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(context, network.ip),
                                  child: Text(
                                      "${network.interfaceName} ${network.ip}"),
                                ));
                              }

                              ip = (await showDialog<String>(
                                context: context,
                                builder: (BuildContext context) {
                                  return WillPopScope(
                                      // 戻る無効化
                                      onWillPop: () => Future.value(false),
                                      child: SimpleDialog(
                                        title:
                                            const Text("利用するネットワークを選択してください。"),
                                        children: dialogOptions,
                                      ));
                                },
                              ))!;
                            } else {
                              ip = networks[0].ip;
                            }

                            // スリープ無効化
                            WakelockPlus.enable();

                            List<Uint8List>? hashs = [];
                            if (settings.checkFileHash) {
                              // SnackBarで通知
                              ScaffoldMessenger.of(nav.context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "ファイルのハッシュを取得中です...\nファイルの大きさなどによっては、時間がかかる場合があります。"),
                                  duration: Duration(days: 100),
                                ),
                              );

                              // 各ファイルのハッシュを計算
                              for (var file in selectedFiles) {
                                hashs.add(await Hash.sha256
                                    .digestStream(file.openRead()));
                              }

                              // SnackBarで通知
                              ScaffoldMessenger.of(nav.context)
                                  .removeCurrentSnackBar();
                            } else {
                              hashs = null;
                            }

                            // サーバーの開始
                            final qr = await SendFiles.serverStart(
                                ip, selectedFiles, hashs);
                            serverListen = true;
                            qrCode = qr;
                            ipText = "IP: $ip";
                            stopServerButton = FloatingActionButton(
                              onPressed: _stopShareProcess,
                              tooltip: '共有を停止する',
                              child: const Icon(Icons.pause),
                            );

                            // 小画面デバイスの場合、別ページでqrを表示
                            if (isSmallUI) {
                              nav.push(MaterialPageRoute(
                                builder: (context) =>
                                    _pushQRPageForSmallScreen(context),
                              ));
                            } else {
                              setState(() {});
                            }
                          } catch (e) {
                            EasyDialog.showErrorDialog(
                                e, Navigator.of(context));

                            ScaffoldMessenger.of(nav.context)
                                .removeCurrentSnackBar();
                          }
                        } else {
                          showDialog(
                              context: context,
                              builder: (context) => EasyDialog.showSmallInfo(
                                  Navigator.of(context),
                                  "エラー",
                                  "ファイルを選択してください。"));
                        }
                      },
                    )),
                const SizedBox(width: 10),
                Expanded(
                    flex: 2,
                    child: IconButton.outlined(
                        onPressed: (() async {
                          final res = await showDialog(
                              context: context,
                              builder: (context) => SendSettingsDialog(
                                  currentSettings: settings));
                          if (res != null && mounted) {
                            setState(() {
                              settings = res;
                            });
                          }
                        }),
                        icon: const Icon(Icons.settings)))
              ],
            ),
          )),
    ]);
  }

  /// QRコードやIPアドレスが書かれる部分のUI
  Widget senderInfoArea() {
    if (serverListen) {
      return Container(
          margin: const EdgeInsets.only(left: 10, right: 10),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Column(
                children: const <Widget>[
                  Text(
                    "送信待機中です",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 30),
                  ),
                  Text("ファイルを受信するには、QRコード読み取るか、IPアドレスを入力してください。"),
                ],
              ),
              qrCode,
              Column(
                children: <Widget>[
                  Text(
                    ipText,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 35),
                  ),
                  /*
            Text(
              keyText,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blue),
            ), */
                ],
              )
            ],
          ));
    } else {
      return Container(
        margin: const EdgeInsets.only(left: 10, right: 10),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            Text(
              "現在、ファイルの送受信は行われていません。",
              style: TextStyle(fontSize: 20),
            ),
            Text("ファイルの送受信が行われる際には、ここに情報が表示されます。")
          ],
        ),
      );
    }
  }

  /// ファイル共有を停止し、初期状態に戻す関数
  void _stopShareProcess() async {
    SendFiles.serverClose();

    if (Platform.isIOS || Platform.isAndroid) {
      // キャッシュ削除
      await FilePicker.platform.clearTemporaryFiles();
    }

    // スリープ有効化
    WakelockPlus.disable();
    serverListen = false;
    selectedFiles.clear();

    setState(() {
      selectFileButtonText = "";
      qrCode = Container();
      ipText = "";
      stopServerButton = Container();
    });
  }

  Widget _pushQRPageForSmallScreen(BuildContext context) {
    return WillPopScope(onWillPop: (() async {
      await showDialog(context: context, builder: (_) => _stopServerDialog());
      return false;
    }), child: LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
            appBar: AppBar(
              title: RichText(
                textAlign: TextAlign.start,
                text: TextSpan(
                    text: "送信待機中です",
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyText1!.color,
                        fontSize: 22),
                    children: <TextSpan>[
                      TextSpan(
                        text: "\n${selectedFiles.length.toString()}個のファイル",
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ]),
              ),
              leading: IconButton(
                  onPressed: () {
                    showDialog(
                        context: context, builder: (_) => _stopServerDialog());
                  },
                  icon: const Icon(Icons.pause)),
            ),
            body: senderInfoArea());
      },
    ));
  }

  Widget _stopServerDialog() {
    return AlertDialog(
      title: const Text("確認"),
      content: const Text("共有を停止してもよろしいですか？"),
      actions: <Widget>[
        TextButton(
          child: const Text("はい"),
          onPressed: () {
            _stopShareProcess();
            // AlertDialogの分のcontextもあるので二回前の階層に戻る
            Navigator.of(context)
              ..pop()
              ..pop();
          },
        ),
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text("いいえ"))
      ],
    );
  }

  /// ファイルの種類を選択するダイアログ
  Widget _selectFileType() {
    return AlertDialog(
      title: const Text("データの種類を選択", textAlign: TextAlign.center),
      actions: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Column(
              children: <Widget>[
                IconButton(
                    onPressed: () {
                      SendFiles.pickFiles().then(_setFiles).catchError((e,
                              stackTrace) =>
                          EasyDialog.showErrorDialog(e, Navigator.of(context)));
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.file_copy, size: 70)),
                const Text("ファイル")
              ],
            ),
            Column(
              children: [
                IconButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      if (Platform.isIOS) {
                        SendFiles.pickFiles(type: FileType.media)
                            .then(_setFiles)
                            .catchError((e, stackTrace) =>
                                EasyDialog.showErrorDialog(
                                    e, Navigator.of(context)));
                      }
                    },
                    icon: const Icon(Icons.perm_media, size: 70)),
                const Text("写真/動画")
              ],
            )
          ],
        )
      ],
    );
  }

  /// 選択したファイルを設定し、文言を追加する (Listの型はFileかXFileのみ有効)
  ///
  /// File型を設定した場合、自動的にXFileに変換されます。
  void _setFiles(List<dynamic>? val) {
    if (val == null || val.isEmpty) {
      return;
    }

    // 過去のファイル情報を消去
    selectedFiles.clear();

    if (val is List<File>) {
      // XFileに変換
      List<XFile> xFiles = List.empty(growable: true);
      for (File file in val) {
        xFiles.add(XFile(file.path));
      }

      selectedFiles = xFiles;
    } else if (val is List<XFile>) {
      selectedFiles = val;
    } else {
      throw ArgumentError.value(val);
    }

    // 文章設定
    _setFileInfo();
  }
}
