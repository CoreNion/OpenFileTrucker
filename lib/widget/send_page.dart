import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_sizes/file_sizes.dart';
import 'package:flutter/material.dart';
import 'package:open_file_trucker/widget/dialog.dart';
import 'package:open_file_trucker/send.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';

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
    // ファイル数が多かったら詳細を省略する
    bool abbreviation = selectedFiles.length > 5;

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
      fileInfo += "${selectedFiles.length}個のファイル ";
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
      child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              flex: 7,
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
                            // 過去のファイル情報を消去
                            selectedFiles.clear();

                            if (Platform.isAndroid || Platform.isIOS) {
                              // ファイルの種類選択ダイアログを表示
                              await showDialog(
                                  context: context,
                                  builder: (_) => _selectFileType());
                            } else {
                              SendFiles.pickFiles(context).then(_setFiles);
                            }
                          },
                        ),
                      ),
                    ),
                  )),
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
                        final ip = await SendFiles.selectNetwork(context);
                        if (!(ip == null)) {
                          final qr =
                              await SendFiles.serverStart(ip, selectedFiles);
                          serverListen = true;
                          qrCode = qr;
                          ipText = "IP: $ip";
                          stopServerButton = FloatingActionButton(
                            onPressed: _stopShareProcess,
                            tooltip: '共有を停止する',
                            child: const Icon(Icons.pause),
                          );
                          if (isSmallUI) {
                            nav.push(MaterialPageRoute(
                              builder: (context) =>
                                  _pushQRPageForSmallScreen(context),
                            ));
                          } else {
                            setState(() {});
                          }
                        } else {
                          showDialog(
                              context: context,
                              builder: (context) => EasyDialog.showSmallInfo(
                                  Navigator.of(context),
                                  "エラー",
                                  "ネットワークに接続してください。"));
                        }
                      } on Exception catch (e) {
                        EasyDialog.showErrorDialog(e, Navigator.of(context));
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

  void _stopShareProcess() {
    SendFiles.serverClose();
    serverListen = false;
    setState(() {
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
                      SendFiles.pickFiles(context).then(_setFiles);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.file_copy, size: 70)),
                const Text("ファイル")
              ],
            ),
            Column(
              children: [
                IconButton(
                    onPressed: () {
                      ImagePicker().pickMultiImage().then(_setFiles);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.image, size: 70)),
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
      // ファイルが何も選択されていない場合はボタン内の文章を初期化
      setState(() {
        selectFileButtonText = firstFileButtonText;
      });
      return;
    } else if (val is List<File>) {
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

    _setFileInfo();
  }
}
