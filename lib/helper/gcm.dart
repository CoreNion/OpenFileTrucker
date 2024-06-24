import 'dart:async';
import 'dart:typed_data';

import 'package:webcrypto/webcrypto.dart';

// 一度に暗号化するデータサイズ
const _payloadSize = 52428800;
// 暗号化後に付属されるのヘッダーサイズ
const _headerSize = 16;

Stream<Uint8List> encryptGcmStream(
    Stream<Uint8List> stream, AesGcmSecretKey key, Uint8List iv) async* {
  final buffer = <int>[];

  // データが壊れないように、一定のデータごとに暗号化する
  await for (final chunk in stream) {
    // 流れたデータを一旦バッファに追加
    buffer.addAll(chunk);

    while (buffer.length >= _payloadSize) {
      // サイズ分のデータ取得し、その分をバッファから削除
      final chunk = buffer.sublist(0, _payloadSize);
      buffer.removeRange(0, _payloadSize);

      // 暗号化
      final encrypted = await key.encryptBytes(chunk, iv);
      yield encrypted;
    }
  }

  // データサイズ未満になったら全て暗号化
  if (buffer.isNotEmpty) {
    yield await key.encryptBytes(buffer, iv);
  }
}

Stream<Uint8List> decryptGcmStream(
    Stream<Uint8List> stream, AesGcmSecretKey key, Uint8List iv) async* {
  // 一度に復号化するデータサイズ (元のデータサイズ + ヘッダーサイズ)
  const dataSize = _payloadSize + _headerSize;

  final buffer = <int>[];
  await for (final chunk in stream) {
    buffer.addAll(chunk);
    while (buffer.length >= dataSize) {
      final chunk = buffer.sublist(0, dataSize);
      buffer.removeRange(0, dataSize);

      final decrypted = await key.decryptBytes(chunk, iv);
      yield decrypted;
    }
  }

  if (buffer.isNotEmpty) {
    yield await key.decryptBytes(buffer, iv);
  }
}
