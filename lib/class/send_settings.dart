import 'dart:io';

/// 送信設定
class SendSettings {
  /// ファイルのハッシュ値をチェックするかどうか
  bool checkFileHash = true;

  /// 暗号化モードで送信するかどうか
  bool encryptMode = true;

  /// デバイス検知を行うかどうか
  bool deviceDetection = true;

  /// Bindアドレス
  String bindAdress = "0.0.0.0";

  /// デバイス名
  String name = Platform.localHostname;
}
