import 'package:bonsoir/bonsoir.dart';

enum TruckerStatus {
  /// 受信待機中
  receiveReady,

  /// 受信中
  receiving,

  /// 受信完了
  received,

  /// 送信待機中
  sendReady,

  /// 送信中
  sending,

  /// 送信完了
  sent,

  /// 拒否
  rejected,

  /// 失敗
  failed,
}

/// 受信可能なデバイスの情報
class TruckerDevice {
  /// デバイス名
  final String name;

  /// UUID
  final String uuid;

  /// ホスト名
  String? host;

  /// mDNS / bonsoirサービス
  BonsoirService? bonsoirService;

  /// 進捗
  double? progress;

  /// 状態
  TruckerStatus status;

  TruckerDevice(this.name, this.host, this.bonsoirService, this.progress,
      this.status, this.uuid);

  @override
  String toString() {
    return 'ReceiveReadyDevice{name: $name, host: $host, bonsoir: $bonsoirService progress: $progress, status: $status}';
  }
}
