// 资产编号的u32 SCALE编解码；不承载机构身份或治理权限。
// 发行机构唯一身份为actor_cid_number；execution_account_id仅承担资产执行。
// 元数据与AssetIssued事件的严格解码由同目录OnchainAssetScaleCodec唯一提供。

import 'dart:typed_data';

class OnchainAssetCodec {
  OnchainAssetCodec._();

  /// 将 asset_id 编码为 u32 little-endian 字节。
  static Uint8List encodeAssetId(int assetId) {
    if (assetId < 0 || assetId > 0xFFFFFFFF) {
      throw ArgumentError('assetId 必须在 u32 范围内,实际 $assetId');
    }
    final bytes = ByteData(4)..setUint32(0, assetId, Endian.little);
    return bytes.buffer.asUint8List();
  }

  /// 从 u32 little-endian 字节解析 asset_id。
  static int decodeAssetId(Uint8List bytes) {
    if (bytes.length != 4) {
      throw FormatException('asset_id 必须是 4 字节,实际 ${bytes.length}');
    }
    return ByteData.sublistView(bytes).getUint32(0, Endian.little);
  }
}
