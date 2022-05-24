import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_sizes/file_sizes.dart';
import 'package:flutter/material.dart';
import 'package:open_file_trucker/dialog.dart';
import 'package:open_file_trucker/send.dart';
import 'package:dotted_border/dotted_border.dart';

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
  List<File> selectedFiles = <File>[];
  static String firstFileButtonText = "ファイルを選択\nまたはドラック&ドロップ";
  String selectFileButtonText = firstFileButtonText;
  List<String> fileName = <String>[];
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
          /* if (qrCode is QrImage) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (builder) => _pushQRPageForSmallScreen(context)));
          } */
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

  /// selectedFilesからファイル選択ボタンに書かれる文章を生成
  String _setFileInfoStr() {
    String fileInfo = "";
    int totalSize = 0;

    for (var i = 0; i < selectedFiles.length; i++) {
      int fileLength = selectedFiles[i].lengthSync();
      totalSize += fileLength;
      if (selectedFiles.length <= 5) {
        fileInfo += "${fileName[i]} ${FileSize.getSize(fileLength)}\n";
      }
    }
    if (fileInfo == "") {
      fileInfo =
          "${selectedFiles.length + 1}個のファイル ${FileSize.getSize(totalSize)}";
    } else {
      fileInfo += "合計: ${FileSize.getSize(totalSize)}";
    }

    return fileInfo;
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
                      fileName.clear();

                      // ドロップされたファイルの情報を記録
                      final file = detail.files;
                      for (var i = 0; i < file.length; i++) {
                        selectedFiles.add(File(file[i].path));
                        fileName.add(file[i].name);
                      }
                      setState(() {
                        selectFileButtonText =
                            "選択されたファイル:\n${_setFileInfoStr()}";
                      });
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
                            primary: Colors.transparent,
                            onPrimary: Colors.transparent,
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
                            fileName.clear();

                            // ピッカーを起動
                            var res = await FilePicker.platform.pickFiles(
                                allowMultiple: true,
                                dialogTitle: "送信するファイルを取得");
                            if (!(res == null)) {
                              // 選択されたファイルの情報を記録
                              for (var i = 0; i < res.files.length; i++) {
                                selectedFiles.add(File(res.files[i].path!));
                                fileName.add(res.files[i].name);
                              }
                              setState(() {
                                selectFileButtonText =
                                    "選択されたファイル:\n${_setFileInfoStr()}";
                              });
                            } else {
                              // ファイルが何も選択されていない場合はボタン内の文章を初期化
                              setState(() {
                                selectFileButtonText = firstFileButtonText;
                              });
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
                    onPrimary: Theme.of(context).colorScheme.onPrimary,
                    primary: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Text("送信する"),
                  onPressed: () async {
                    if (serverListen) {
                      showDialog(
                          context: context,
                          builder: (context) => EasyDialog.showSmallInfo(
                              context, "エラー", "他のファイルの共有を停止してください。"));
                    } else if (selectedFiles.isNotEmpty) {
                      try {
                        final ip = await SendFiles.selectNetwork(context);
                        if (!(ip == null)) {
                          final qr = await SendFiles.serverStart(
                              ip, selectedFiles, context);
                          serverListen = true;
                          qrCode = qr;
                          ipText = "IP: $ip";
                          stopServerButton = FloatingActionButton(
                            onPressed: _stopShareProcess,
                            tooltip: '共有を停止する',
                            child: const Icon(Icons.pause),
                          );
                          if (isSmallUI) {
                            Navigator.of(context).push(MaterialPageRoute(
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
                                  context, "エラー", "ネットワークに接続してください。"));
                        }
                      } on Exception catch (e) {
                        EasyDialog.showErrorDialog(e, context);
                      }
                    } else {
                      showDialog(
                          context: context,
                          builder: (context) => EasyDialog.showSmallInfo(
                              context, "エラー", "ファイルを選択してください。"));
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
                        text: "\n${fileName.length.toString()}個のファイル",
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
}
