import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:citizen_citizen/asset/onchain_asset_codec.dart';
import 'package:flutter_test/flutter_test.dart';

/// 固定金标唯一归本包；从Pub实际包配置定位，支持workspace及包目录运行。
Future<Map<String, dynamic>> readAssetVectors() async {
  var directory = Directory.current.absolute;
  while (!File('${directory.path}/.dart_tool/package_config.json')
      .existsSync()) {
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('资产测试需要产品Pub包配置');
    }
    directory = parent;
  }
  final config = File('${directory.path}/.dart_tool/package_config.json');
  final packages = jsonDecode(await config.readAsString())['packages'] as List;
  final owner =
      packages.singleWhere((row) => row['name'] == 'citizen_citizen') as Map;
  final root = config.uri.resolve(owner['rootUri'] as String);
  final fixture = Uri.directory(root.toFilePath())
      .resolve('test/asset/asset_vectors.json');
  return jsonDecode(await File.fromUri(fixture).readAsString())
      as Map<String, dynamic>;
}

Uint8List scaleBytes(String hex) => Uint8List.fromList([
  for (var offset = 0; offset < hex.length; offset += 2)
    int.parse(hex.substring(offset, offset + 2), radix: 16),
]);

Future<void> main() async {
  final vectors = await readAssetVectors();
  for (final row
      in (vectors['id_vectors'] as List).cast<Map<String, dynamic>>()) {
    final id = row['asset_id'] as int;
    final encoded = scaleBytes(row['scale_hex'] as String);
    test('资产ID固定u32金标：$id', () {
      expect(OnchainAssetCodec.encodeAssetId(id), encoded);
      expect(OnchainAssetCodec.decodeAssetId(encoded), id);
    });
  }
  for (final id in [-1, 4294967296]) {
    test('资产ID越界拒绝：$id', () {
      expect(() => OnchainAssetCodec.encodeAssetId(id), throwsArgumentError);
    });
  }
  for (final length in [0, 1, 3, 5, 8]) {
    test('资产ID字节数必须恰好为4：$length', () {
      expect(
        () => OnchainAssetCodec.decodeAssetId(Uint8List(length)),
        throwsFormatException,
      );
    });
  }
  test('资产ID从非零偏移视图读取，不消费前后字节', () {
    final storage = Uint8List.fromList([255, 0, 1, 0, 0, 255]);
    expect(
      OnchainAssetCodec.decodeAssetId(Uint8List.sublistView(storage, 1, 5)),
      256,
    );
  });
}
