class QRCodeData {
  // IPアドレス
  final String ip;
  // 暗号化キー
  final String key;

  QRCodeData({required this.ip, required this.key});

  QRCodeData.fromJson(Map<String, dynamic> json)
      : ip = json["ip"],
        key = json["key"];

  Map<String, dynamic> toJson() {
    return {'ip': ip, 'key': key};
  }
}
