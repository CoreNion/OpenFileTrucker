import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_sizes/file_sizes.dart';
import 'package:flutter/material.dart';
import 'package:open_file_trucker/widget/dialog.dart';
import 'package:open_file_trucker/send.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:path/path.dart' as p;
import 'package:share_handler/share_handler.dart';
import 'package:sodium_libs/sodium_libs.dart';
import 'package:wakelock/wakelock.dart';

class SendPage extends StatefulWidget {
  const SendPage({Key? key}) : super(key: key);

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late bool isSmallUI;
  List<XFile> selectedFiles = <XFile>[];
  static String firstFileButtonText =
      Platform.isIOS ? "タップしてファイルを選択" : "タップしてファイルを選択\nまたはドラック&ドロップ";
  String selectFileButtonText = firstFileButtonText;
  String ipText = "";
  String keyText = "";
  Widget qrCode = Container();
  Widget stopServerButton = Container();
  bool serverListen = false;
  bool checkFileHash = false;

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
    String fileInfo = "";
    int totalSize = 0;
    // ファイル数が多い場合/画面が小さい場合、詳細を省略する
    bool abbreviation = selectedFiles.length > 5 || isSmallUI;

    // ファイル名とサイズを取得
    for (XFile file in selectedFiles) {
      int fileLength = await file.length();
      totalSize += fileLength;
      if (!abbreviation) {
        fileInfo +=
            "${p.basename(file.path)} ${FileSize.getSize(fileLength)}\n";
      }
    }

    if (abbreviation) {
      fileInfo += "${selectedFiles.length}個のファイル\n";
    }
    fileInfo += "合計: ${FileSize.getSize(totalSize)}";

    setState(() {
      selectFileButtonText = "選択されたファイル:\n$fileInfo";
    });
  }

  /// ファイルを選択する部分のUI
  Container selectFileArea() {
    return Container(
      margin: const EdgeInsets.all(10),
      child:
          Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <
              Widget>[
        Expanded(
          flex: 8,
          child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              child: DropTarget(
                onDragDone: (detail) {
                  // 過去のファイル情報を消去
                  selectedFiles.clear();

                  // ドロップされたファイルの情報を記録
                  final file = detail.files;
                  for (var i = 0; i < file.length; i++) {
                    selectedFiles.add(XFile(file[i].path));
                  }
                  _setFileInfo();
                },
                child: DottedBorder(
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 3,
                  dashPattern: const [30, 5],
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.transparent,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: Text(
                        selectFileButtonText,
                        style: TextStyle(
                            fontSize: 25,
                            color: Theme.of(context).colorScheme.primary),
                        textAlign: TextAlign.center,
                      ),
                      onPressed: () async {
                        if (Platform.isIOS) {
                          // ファイルの種類選択ダイアログを表示
                          await showDialog(
                              context: context,
                              builder: (_) => _selectFileType());
                        } else {
                          SendFiles.pickFiles(context: context)
                              .then(_setFiles)
                              .catchError((e, stackTrace) =>
                                  EasyDialog.showErrorDialog(
                                      e, Navigator.of(context)));
                        }
                      },
                    ),
                  ),
                ),
              )),
        ),
        SwitchListTile(
          value: checkFileHash,
          title: const Text('受信時にファイルの整合性を確認する'),
          subtitle: const Text("一部端末では利用できない場合があります。"),
          onChanged: (bool value) => setState(() {
            checkFileHash = value;
          }),
        ),
        Expanded(
          flex: 1,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                    final networks = await SendFiles.getAvailableNetworks();
                    late String ip;

                    // 利用可能なネットワークが無い場合は終了
                    if (networks == null) {
                      showDialog(
                          context: context,
                          builder: (context) => EasyDialog.showSmallInfo(
                              Navigator.of(context),
                              "エラー",
                              "WiFiやイーサーネットなどの、ローカルネットワークに接続してください。"));
                      return;
                    }

                    // ネットワークが2つ以上ある場合はユーザーにネットワークを選択させる
                    if (networks.length > 1) {
                      // 選択肢のDialogOptionに追加する
                      List<SimpleDialogOption> dialogOptions = [];
                      for (var network in networks) {
                        dialogOptions.add(SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, network.ip),
                          child: Text("${network.interfaceName} ${network.ip}"),
                        ));
                      }

                      ip = (await showDialog<String>(
                        context: context,
                        builder: (BuildContext context) {
                          return WillPopScope(
                              // 戻る無効化
                              onWillPop: () => Future.value(false),
                              child: SimpleDialog(
                                title: const Text("利用するネットワークを選択してください。"),
                                children: dialogOptions,
                              ));
                        },
                      ))!;
                    } else {
                      ip = networks[0].ip;
                    }

                    // スリープ無効化
                    Wakelock.enable();

                    List<Uint8List>? hashs = [];
                    if (checkFileHash) {
                      // SnackBarで通知
                      ScaffoldMessenger.of(nav.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              "ファイルのハッシュを取得中です...\nファイルの大きさなどによっては、時間がかかる場合があります。"),
                          duration: Duration(days: 100),
                        ),
                      );

                      final sodium = await SodiumInit.init();
                      // 各ファイルのハッシュを計算
                      for (var file in selectedFiles) {
                        hashs.add(await sodium.crypto.genericHash
                            .stream(messages: file.openRead()));
                      }

                      // SnackBarで通知
                      ScaffoldMessenger.of(nav.context).removeCurrentSnackBar();
                    } else {
                      hashs = null;
                    }

                    // サーバーの開始
                    final qr =
                        await SendFiles.serverStart(ip, selectedFiles, hashs);
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
                    EasyDialog.showErrorDialog(e, Navigator.of(context));

                    ScaffoldMessenger.of(nav.context).removeCurrentSnackBar();
                  }
                } else {
                  showDialog(
                      context: context,
                      builder: (context) => EasyDialog.showSmallInfo(
                          Navigator.of(context), "エラー", "ファイルを選択してください。"));
                }
              },
            ),
          ),
        ),
      ]),
    );
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
  void _stopShareProcess() {
    SendFiles.serverClose();
    serverListen = false;
    selectedFiles.clear();

    setState(() {
      selectFileButtonText = firstFileButtonText;
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
                      SendFiles.pickFiles(context: context)
                          .then(_setFiles)
                          .catchError((e, stackTrace) =>
                              EasyDialog.showErrorDialog(
                                  e, Navigator.of(context)));
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
                        SendFiles.pickFiles(
                                context: context, type: FileType.media)
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
