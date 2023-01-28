import 'dart:typed_data';

class FileInfo {
  final List<String> names;

  final List<int> sizes;

  final List<Uint8List>? hashs;

  FileInfo({required this.names, required this.sizes, this.hashs});

  Map<String, dynamic> toMap() {
    return {'nameList': names, 'lengthList': sizes, 'hashList': hashs};
  }

  static FileInfo mapToInfo(Map<String, dynamic> map) {
    late List<String> names;
    late List<int> sizes;
    late List<Uint8List>? hashs;

    names = map["nameList"].cast<String>();
    sizes = map["lengthList"].cast<int>();

    // cast<List<Uint8List>>が効かないのでmapを介す
    final List<dynamic>? dynamics = map["hashList"] as List<dynamic>?;
    if (dynamics != null) {
      hashs = dynamics
          .map((subList) =>
              Uint8List.fromList((subList as List<dynamic>).cast<int>()))
          .toList();
    } else {
      hashs = null;
    }

    return FileInfo(names: names, sizes: sizes, hashs: hashs);
  }
}
