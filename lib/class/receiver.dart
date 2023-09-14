enum ReceiverStatus {
  /// 受信待機中
  ready,

  /// 受信中
  receiving,

  /// 受信完了
  received,

  /// 受信拒否
  rejected,

  /// 受信失敗
  failed,
}

/// 受信可能なデバイスの情報
class ReceiveReadyDevice {
  /// デバイス名
  final String name;

  /// ホスト名
  final String host;

  /// 進捗
  double? progress = 0;

  /// 状態
  ReceiverStatus status = ReceiverStatus.ready;

  ReceiveReadyDevice(this.name, this.host, this.progress, this.status);

  @override
  String toString() {
    return 'ReceiveReadyDevice{name: $name, host: $host, progress: $progress, status: $status}';
  }
}
