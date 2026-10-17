import 'dart:typed_data';

/// 纯字节编码，不生成、保存或使用任何密钥。
String bytesToHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Uint8List hexToBytes(String value) {
  final text = value.startsWith('0x') ? value.substring(2) : value;
  if (text.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(text)) {
    throw const FormatException('十六进制字节格式无效');
  }
  return Uint8List.fromList(List<int>.generate(
    text.length ~/ 2, (index) => int.parse(text.substring(index * 2, index * 2 + 2), radix: 16),
  ));
}
