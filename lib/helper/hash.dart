import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:webcrypto/webcrypto.dart';

/// ファイルのハッシュ値を計算
Future<List<Uint8List>> calcFileHash(List<XFile> files) async {
  List<Uint8List> hashs = [];
  for (var file in files) {
    hashs.add(await Hash.sha256.digestStream(file.openRead()));
  }

  return hashs;
}
