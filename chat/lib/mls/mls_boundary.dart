export 'package:citizen_network/mls_authentication.dart';
// 公民聊天 的 RFC 9420 MLS 边界模型。
//
// Dart 只传递身份、KeyPackage、MLS wire bytes和受限认证请求。签名唯一由
// Rust OpenMLS 完成，禁止另建原始 HPKE 直聊协议或应用层密钥编号。

export 'mls_session.dart';

/// OpenMLS 生成的 RFC 9420 KeyPackage。
class MlsKeyPackage {
  const MlsKeyPackage({
    required this.userId,
    required this.deviceId,
    required this.keyPackageRef,
    required this.keyPackageBytes,
    required this.cipherSuite,
    required this.notBeforeMillis,
    required this.notAfterMillis,
    required this.lastResort,
  });

  final String userId;
  final String deviceId;

  /// OpenMLS 根据标准 KeyPackage 计算的 KeyPackageRef 十六进制值。
  final String keyPackageRef;

  final List<int> keyPackageBytes;
  final String cipherSuite;
  final int notBeforeMillis;
  final int notAfterMillis;
  final bool lastResort;

  String get keyPackageHex => _bytesToHex(keyPackageBytes);
}

String _bytesToHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
