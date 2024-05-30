import 'dart:convert';
import 'dart:io';

import 'service.dart';

import '../class/trucker_device.dart';

ServerSocket? _serverSocket;
Socket? _socket;

/// ファイルの送信リクエストを受け付けるサーバーを起動
Future<void> startIncomingServer(Future<bool> Function(String name) incoming,
    Future<void> Function(String remote) onAccept) async {
  // 受信用のmDNSサービスを登録
  await registerNsd(ServiceType.receive, Platform.localHostname);

  _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 4783);
  _serverSocket!.listen((socket) {
    socket.listen((event) async {
      final data = utf8.decode(event);
      final remote = socket.remoteAddress.address;
      if (data.startsWith("request: ")) {
        final name = data.substring(9);

        // リクエストを受け付けるかどうかを確認
        final res = await incoming(name);
        if (res) {
          socket.add(utf8.encode("accept"));
          await socket.close();

          // 認可時の処理
          onAccept(remote);
        } else {
          socket.add(utf8.encode("reject"));
          await socket.close();
        }
      }
    });
  });
}

/// リクエストサーバーを停止
Future<void> stopIncomingServer() async {
  if (_serverSocket == null) return;
  await _serverSocket!.close();
}

/// サービス経由で通信しているデバイスのリスト
final Map<String, TruckerDevice> viaServiceDevice = {};

/// ファイルの送信リクエストを送信
Future<bool> sendRequest(String host, String name) async {
  _socket = await Socket.connect(host, 4783);
  _socket!.add(utf8.encode("request: $name"));

  bool res = false;
  await _socket!.listen((event) async {
    final data = utf8.decode(event);
    if (data == "accept") {
      res = true;
    } else {
      res = false;
    }

    await _socket!.close();
  }).asFuture();

  return res;
}
