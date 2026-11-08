import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:citizen_citizen/asset/onchain_asset_constants.dart';
import 'package:citizen_citizen/asset/onchain_asset_query.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
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
  for (final row in (vectors['id_vectors'] as List).cast<Map<String, dynamic>>()) {
    final id = BigInt.from(row['asset_id'] as int);
    final encoded = scaleBytes(row['scale_hex'] as String);
    test('资产编号保持 u32 金标：$id', () {
      expect(CitizenScale.unsigned(id, 4), encoded);
      expect(CitizenScale.readUnsigned(encoded, 0, 4), id);
    });
  }
  test('资产编号从非零偏移读取，不消费前后字段', () {
    final storage = Uint8List.fromList([255, 0, 1, 0, 0, 255]);
    expect(CitizenScale.readUnsigned(storage, 1, 4), BigInt.from(256));
  });
  final contract = vectors['contract'] as Map<String, dynamic>;
  test('资产调用编号、动作与精度沿固定链合同，留洞不复用', () {
    expect(
      OnchainAssetActions.onchainIssuancePalletIndex,
      contract['pallet_index'],
    );
    expect(
      OnchainAssetActions.assetsPalletIndex,
      contract['assets_pallet_index'],
    );
    expect(OnchainAssetActions.moduleTag, contract['module_tag']);
    expect(OnchainAssetActions.minDecimals, contract['min_decimals']);
    expect(OnchainAssetActions.maxDecimals, contract['max_decimals']);
    final actual = {
      OnchainAssetActions.actionIssue: OnchainAssetActions.callProposeIssue,
      OnchainAssetActions.actionMint: OnchainAssetActions.callProposeMint,
      OnchainAssetActions.actionBurn: OnchainAssetActions.callProposeBurn,
      OnchainAssetActions.actionClose: OnchainAssetActions.callProposeClose,
      OnchainAssetActions.actionTransfer:
          OnchainAssetActions.callProposeTransfer,
      OnchainAssetActions.actionMonitorFreeze:
          OnchainAssetActions.callProposeMonitorFreeze,
      OnchainAssetActions.actionMonitorUnfreeze:
          OnchainAssetActions.callProposeMonitorUnfreeze,
      OnchainAssetActions.actionMonitorConfiscate:
          OnchainAssetActions.callProposeMonitorConfiscate,
      OnchainAssetActions.actionMonitorForceTransfer:
          OnchainAssetActions.callProposeMonitorForceTransfer,
      OnchainAssetActions.actionMonitorForceClose:
          OnchainAssetActions.callProposeMonitorForceClose,
    };
    expect(actual, {
      for (final row in contract['calls'] as List)
        row['action']: row['call_index'],
    });
  });
  for (final row
      in (vectors['meta_vectors'] as List).cast<Map<String, dynamic>>()) {
    final bytes = scaleBytes(row['scale_hex'] as String);
    test('AssetMetas固定金标：${row['name']}', () {
      final meta = OnchainAssetScaleCodec.decodeMeta(
        assetId: row['asset_id'] as int,
        scale: bytes,
      );
      expect(meta.assetId, row['asset_id']);
      expect(meta.actorCidNumber, row['actor_cid_number']);
      expect(
        meta.executionAccountId,
        scaleBytes(row['execution_account_id'] as String),
      );
      expect(
        meta.assetClass,
        row['asset_class'] == 'plain'
            ? OnchainAssetClass.plain
            : OnchainAssetClass.pegged,
      );
      expect(meta.decimals, row['decimals']);
      expect(
        meta.state.kind,
        {
          'active': OnchainAssetStateKind.active,
          'closed': OnchainAssetStateKind.closed,
          'force_closed': OnchainAssetStateKind.forceClosed,
        }[row['state']],
      );
      expect(meta.state.closeBlock, row['close_block']);
    });
    test('AssetMetas所有截断及尾随字节拒绝：${row['name']}', () {
      for (var end = 0; end < bytes.length; end++) {
        expect(
          () => OnchainAssetScaleCodec.decodeMeta(
            assetId: 1,
            scale: Uint8List.sublistView(bytes, 0, end),
          ),
          throwsFormatException,
          reason: '截断位置$end',
        );
      }
      expect(
        () => OnchainAssetScaleCodec.decodeMeta(
          assetId: 1,
          scale: Uint8List.fromList([...bytes, 0]),
        ),
        throwsFormatException,
      );
    });
  }
  for (final row
      in (vectors['issued_vectors'] as List).cast<Map<String, dynamic>>()) {
    final bytes = scaleBytes(row['scale_hex'] as String);
    test('AssetIssued固定金标：${row['name']}', () {
      final issued = OnchainAssetScaleCodec.decodeAssetIssued(bytes);
      expect(issued.assetId, row['asset_id']);
      expect(issued.actorCidNumber, row['actor_cid_number']);
      expect(
        issued.executionAccountId,
        scaleBytes(row['execution_account_id'] as String),
      );
    });
    test('AssetIssued所有截断及尾随字节拒绝：${row['name']}', () {
      for (var end = 0; end < bytes.length; end++) {
        expect(
          () => OnchainAssetScaleCodec.decodeAssetIssued(
            Uint8List.sublistView(bytes, 0, end),
          ),
          throwsFormatException,
          reason: '截断位置$end',
        );
      }
      expect(
        () => OnchainAssetScaleCodec.decodeAssetIssued(
          Uint8List.fromList([...bytes, 255]),
        ),
        throwsFormatException,
      );
    });
  }
  for (final row
      in (vectors['invalid_vectors'] as List).cast<Map<String, dynamic>>()) {
    final bytes = scaleBytes(row['scale_hex'] as String);
    test('损坏协议拒绝：${row['name']}', () {
      if (row['target'] == 'meta') {
        expect(
          () => OnchainAssetScaleCodec.decodeMeta(assetId: 1, scale: bytes),
          throwsFormatException,
        );
      } else {
        expect(
          () => OnchainAssetScaleCodec.decodeAssetIssued(bytes),
          throwsFormatException,
        );
      }
    });
  }
  test('元数据外部资产ID同样限制u32，AccountId输入不会与返回对象共享字节', () {
    final row = (vectors['meta_vectors'] as List).first as Map;
    final bytes = scaleBytes(row['scale_hex'] as String);
    for (final id in [-1, 4294967296]) {
      expect(
        () => OnchainAssetScaleCodec.decodeMeta(assetId: id, scale: bytes),
        throwsArgumentError,
      );
    }
    final meta = OnchainAssetScaleCodec.decodeMeta(assetId: 1, scale: bytes);
    bytes.fillRange(0, bytes.length, 255);
    expect(
      meta.executionAccountId,
      scaleBytes(row['execution_account_id'] as String),
    );
  });
}
