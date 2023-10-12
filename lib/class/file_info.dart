import 'dart:typed_data';

/// 平文であることを示すヘッダー
const plainTextHeader = [128, 64, 128, 64, 128];

/// ファイル情報を表すクラス
class FileInfo {
  /// ファイル名
  final String name;

  /// ファイルサイズ
  final int size;

  /// ファイルのハッシュ値
  final Uint8List? hash;

  FileInfo({required this.name, required this.size, this.hash});

  Map<String, dynamic> toJson() {
    return {'name': name, 'size': size, 'hash': hash};
  }

  static FileInfo mapToInfo(Map<String, dynamic> map) {
    return FileInfo(
        name: map['name'],
        size: map['size'],
        hash: Uint8List.fromList(map['hash'].cast<int>()));
  }
}
