import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:polkadart_scale_codec/polkadart_scale_codec.dart' as scale;
import 'package:polkadart/polkadart.dart' show Hasher;
import 'package:substrate_metadata/substrate_metadata.dart' as metadata;
import 'package:citizenapp/transaction/contract/citizenchain_contract_read_service.dart';
import 'package:citizenapp/transaction/contract/citizenchain_runtime_codec.dart';
import 'package:citizenapp/transaction/contract/citizenchain_contract_page.dart';

import '../../support/fake_citizen_sdk.dart';

const _account =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _contract = '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _key =
    '0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

Uint8List _metadata() => CitizenChainContractReadService.bytes(
  File(
    'test/transaction/contract/citizenchain-revive-v15-metadata.hex',
  ).readAsStringSync().trim(),
);

// 仅模拟旧版元数据传输的 V14 包装；API 类型和全部只读输出仍来自真实 V15 金标。
Uint8List _metadataWithoutApis() {
  final current = CitizenChainRuntimeCodec(_metadata()).runtime;
  final older = metadata.RuntimeMetadataV14(
    types: current.types,
    pallets: [],
    extrinsic: metadata.ExtrinsicMetadataV14(
      type: current.types.first.id,
      version: 4,
      signedExtensions: [],
      addressType: 0,
      callType: 0,
      signatureType: 0,
      extraType: 0,
    ),
    runtimeTypeId: current.runtimeTypeId,
    outerEnums: current.outerEnums,
  );
  return Uint8List.fromList([
    0x6d,
    0x65,
    0x74,
    0x61,
    14,
    ...metadata.RuntimeMetadataV14.codec.encode(older),
  ]);
}

class _Chain extends TestCitizenChain {
  final calls = <String>[];
  late Uint8List metadataBytes = _metadata();
  final block = CitizenBlockRef(
    hash: '0x${'11' * 32}',
    number: BigInt.one,
    finality: CitizenBlockFinality.finalized,
  );
  CitizenBlockRef? contextBlock;
  bool trailing = false;
  bool absent = false;
  bool apiTableFallback = false;
  int flags = 0;
  bool executionError = false;
  BigInt deposit = BigInt.zero;
  CitizenBlockRef? bodyBlock;
  final extrinsic = Uint8List.fromList([4, 0, 0]);
  Uint8List? eventBytes;

  @override
  Future<CitizenBlockRef> getFinalizedHead() async => block;
  @override
  Future<CitizenRuntimeContext> getRuntimeContext(
    CitizenBlockRef block,
  ) async => CitizenRuntimeContext(
    block: contextBlock ?? block,
    metadata: apiTableFallback ? _metadataWithoutApis() : metadataBytes,
    specVersion: 0,
    transactionVersion: 0,
  );
  @override
  Future<CitizenBlockRef> getFinalizedBlockAt(BigInt number) async => block;
  @override
  Future<CitizenBlockBody> getBlockBody(CitizenBlockRef block) async =>
      CitizenBlockBody(block: bodyBlock ?? block, extrinsics: [extrinsic]);
  @override
  Future<Uint8List?> getSystemEvents(CitizenBlockRef block) async => eventBytes;
  @override
  Future<Uint8List> callRuntimeApi(
    CitizenBlockRef block,
    String method,
    Uint8List arguments,
  ) async {
    expect(block.hash, this.block.hash);
    calls.add(method);
    if (method == 'Metadata_metadata_at_version') {
      expect(arguments, [15, 0, 0, 0]);
      return Uint8List.fromList(
        const scale.OptionCodec(
          scale.SequenceCodec(scale.U8Codec.codec),
        ).encode(metadataBytes),
      );
    }
    final codec = CitizenChainRuntimeCodec(metadataBytes);
    if (method == 'ReviveApi_call') {
      expect(arguments, [
        ...List.filled(32, 0xaa),
        ...List.filled(20, 0xbb),
        ...List.filled(16, 0),
        0,
        1,
        ...List.filled(16, 0),
        8,
        1,
        2,
      ]);
      return codec.types.codec(codec.method('ReviveApi', 'call').output).encode(
        {
          'weight_consumed': {
            'ref_time': BigInt.one,
            'proof_size': BigInt.zero,
          },
          'weight_required': {
            'ref_time': BigInt.one,
            'proof_size': BigInt.zero,
          },
          'storage_deposit': MapEntry('Charge', deposit),
          'max_storage_deposit': MapEntry('Charge', deposit),
          'gas_consumed': BigInt.from(123),
          'result': executionError
              ? const MapEntry('Err', MapEntry('Other', null))
              : MapEntry('Ok', {
                  'flags': {'bits': flags},
                  'data': [4, 5],
                }),
        },
      );
    }
    if (method != 'ReviveApi_get_storage') throw StateError('未配置 API');
    expect(arguments, [...List.filled(20, 0xbb), ...List.filled(32, 0xcc)]);
    final methodType = codec.method('ReviveApi', 'get_storage');
    final result = codec.types
        .codec(methodType.output)
        .encode(
          MapEntry(
            'Ok',
            absent
                ? const MapEntry('None', null)
                : const MapEntry('Some', [1, 2, 3]),
          ),
        );
    return Uint8List.fromList([...result, if (trailing) 0]);
  }
}

Uint8List _executionEvents({bool failed = false, bool logs = true}) {
  final codec = CitizenChainRuntimeCodec(_metadata());
  final entry = codec.runtime.pallets
      .singleWhere((p) => p.name == 'System')
      .storage!
      .entries
      .singleWhere((e) => e.name == 'Events');
  final dispatchInfo = {
    // Runtime 事件使用 DispatchEventInfo，字段是合并后的 weight。
    'weight': {'ref_time': BigInt.zero, 'proof_size': BigInt.zero},
    'class': const MapEntry('Normal', null),
    'pays_fee': const MapEntry('Yes', null),
  };
  Map<String, Object?> record(String pallet, String event, Object? value) => {
    'phase': const MapEntry('ApplyExtrinsic', 0),
    'event': MapEntry(pallet, MapEntry(event, value)),
    'topics': <Object?>[],
  };
  return codec.types.codec(entry.type.value).encode([
    record('OnchainTransaction', 'FeePaid', {
      'account_id': List.filled(32, 0xaa),
      'fee': BigInt.from(10),
    }),
    if (logs)
      record('Revive', 'ContractEmitted', {
        'contract': List.filled(20, 0xbb),
        'data': [1, 2, 3],
        'topics': [List.filled(32, 0xcc)],
      }),
    record(
      'System',
      failed ? 'ExtrinsicFailed' : 'ExtrinsicSuccess',
      failed
          ? {
              'dispatch_error': const MapEntry('Other', null),
              'dispatch_info': dispatchInfo,
            }
          : {'dispatch_info': dispatchInfo},
    ),
  ]);
}

void main() {
  test('准确 Runtime V15 的 Revive 索引和只读参数来自 metadata', () {
    final codec = CitizenChainRuntimeCodec(_metadata());
    expect(codec.runtime.runtimeMetadataVersion(), 15);
    expect(
      codec.runtime.pallets.singleWhere((p) => p.name == 'Revive').index,
      35,
    );
    final method = codec.method('ReviveApi', 'call');
    expect(method.inputs.map((i) => i.name), [
      'origin',
      'dest',
      'value',
      'gas_limit',
      'storage_deposit_limit',
      'input_data',
    ]);
    final encoded = codec.arguments(method, {
      'origin': List.filled(32, 0xaa),
      'dest': List.filled(20, 0xbb),
      'value': BigInt.zero,
      'gas_limit': const MapEntry('None', null),
      'storage_deposit_limit': MapEntry('Some', BigInt.zero),
      'input_data': [1, 2],
    });
    // 原生 u128 金额、None weight、Some(0) deposit、两字节 input 的独立字节金标。
    expect(encoded, [
      ...List.filled(32, 0xaa),
      ...List.filled(20, 0xbb),
      ...List.filled(16, 0),
      0,
      1,
      ...List.filled(16, 0),
      8,
      1,
      2,
    ]);
    expect(
      () => codec.arguments(method, {'origin': []}),
      throwsFormatException,
    );
  });

  test('合约存储只读取同一 finalized 块，区分不存在与读取值', () async {
    final chain = _Chain();
    final service = CitizenChainContractReadService(chain);
    final found = await service.getStorage(contract: _contract, key: _key);
    expect(found.block.hash, chain.block.hash);
    expect(found.data, [1, 2, 3]);
    chain.absent = true;
    final missing = await service.getStorage(contract: _contract, key: _key);
    expect(missing.data, isNull);
    expect(missing.failureDescription, isNull);
    expect(chain.calls, ['ReviveApi_get_storage', 'ReviveApi_get_storage']);
  });

  test('metadata 与块不匹配、输出尾字节、未知方法均拒绝', () async {
    final chain = _Chain()
      ..contextBlock = CitizenBlockRef(
        hash: '0x${'22' * 32}',
        number: BigInt.one,
        finality: CitizenBlockFinality.finalized,
      );
    final service = CitizenChainContractReadService(chain);
    await expectLater(
      service.getStorage(contract: _contract, key: _key),
      throwsStateError,
    );
    expect(chain.calls, isEmpty);
    chain.contextBlock = null;
    chain.trailing = true;
    await expectLater(
      service.getStorage(contract: _contract, key: _key),
      throwsA(isA<Exception>()),
    );
    expect(
      () =>
          CitizenChainRuntimeCodec(_metadata()).method('ReviveApi', 'missing'),
      throwsFormatException,
    );
  });

  test('错误地址、非完整字节和超限调用输入在链读取前拒绝', () async {
    final service = CitizenChainContractReadService(TestCitizenChain());
    for (final address in ['0x1', '0xgg', _account]) {
      await expectLater(
        service.getStorage(contract: address, key: _key),
        throwsFormatException,
      );
    }
    await expectLater(
      service.call(
        accountId: _account,
        contract: _contract,
        inputData: '0x${'00' * 4097}',
      ),
      throwsFormatException,
    );
  });

  test('零金额模拟分别显示成功、REVERT 和执行失败，非零押金拒绝', () async {
    final chain = _Chain();
    final service = CitizenChainContractReadService(chain);
    Future<CitizenChainContractRead> call() => service.call(
      accountId: _account,
      contract: _contract,
      inputData: '0x0102',
    );
    final success = await call();
    expect(success.data, [4, 5]);
    expect(success.gasConsumed, BigInt.from(123));
    expect(success.reverted, isFalse);
    expect(() => success.data![0] = 0, throwsUnsupportedError);
    chain.flags = 1;
    expect((await call()).reverted, isTrue);
    chain.executionError = true;
    expect((await call()).failureDescription, contains('执行失败'));
    chain.deposit = BigInt.one;
    await expectLater(call(), throwsFormatException);
    chain.deposit = BigInt.zero;
    chain.executionError = false;
    chain.flags = 2;
    await expectLater(call(), throwsFormatException);
  });

  test('V14 缺少 API 表时只在同一已验证块取得 V15，不替换 SDK 元数据', () async {
    final chain = _Chain()..apiTableFallback = true;
    final result = await CitizenChainContractReadService(
      chain,
    ).getStorage(contract: _contract, key: _key);
    expect(result.data, [1, 2, 3]);
    expect(chain.calls, [
      'Metadata_metadata_at_version',
      'ReviveApi_get_storage',
    ]);
    expect(chain.apiTableFallback, isTrue);
  });

  test('执行记录的原生哈希、真实费用和日志取自同一准确块', () async {
    final chain = _Chain()..eventBytes = _executionEvents();
    final service = CitizenChainContractReadService(chain);
    final result = await service.execution(
      blockNumber: BigInt.one,
      extrinsicIndex: 0,
    );
    expect(
      result.transactionHash,
      CitizenChainContractReadService.hex(
        Hasher.blake2b256.hash(chain.extrinsic),
      ),
    );
    expect(result.fee!.feeFen, '10');
    expect(result.logs.single.contract, _contract);
    expect(result.logs.single.data, [1, 2, 3]);
    expect(result.outcome.succeeded, isTrue);
    chain.bodyBlock = CitizenBlockRef(
      hash: '0x${'22' * 32}',
      number: BigInt.one,
      finality: CitizenBlockFinality.finalized,
    );
    await expectLater(
      service.execution(blockNumber: BigInt.one, extrinsicIndex: 0),
      throwsStateError,
    );
    chain.bodyBlock = null;
    await expectLater(
      service.execution(blockNumber: BigInt.one, extrinsicIndex: 1),
      throwsFormatException,
    );
    chain.eventBytes = _executionEvents(failed: true);
    await expectLater(
      service.execution(blockNumber: BigInt.one, extrinsicIndex: 0),
      throwsFormatException,
    );
    chain.eventBytes = _executionEvents(failed: true, logs: false);
    expect(
      (await service.execution(
        blockNumber: BigInt.one,
        extrinsicIndex: 0,
      )).outcome.succeeded,
      isFalse,
    );
  });

  testWidgets('真实 SDK 接线页面丢弃改参后迟到的只读结果', (tester) async {
    final chain = _Chain();
    final barrier = Completer<void>();
    final block = [chain.block.hash, '1', 'finalized'];
    final transport = TestCitizenSdkTransport({
      'getFinalizedHead': (_) async {
        await barrier.future;
        return [block];
      },
      'getRuntimeContext': (_) => [
        [block, 0, 0, _metadata()],
      ],
      'callRuntimeApi': (fields) async => [
        await chain.callRuntimeApi(
          chain.block,
          fields[1]! as String,
          fields[2]! as Uint8List,
        ),
      ],
    });
    final sdk = await transport.open();
    try {
      await tester.pumpWidget(
        Provider<CitizenSdk>.value(
          value: sdk,
          child: const MaterialApp(
            home: CitizenChainContractPage(accountId: _account),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), _contract);
      await tester.enterText(find.byType(TextField).at(1), _key);
      await tester.tap(find.text('查询'));
      await tester.pump();
      expect(find.text('查询中…'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '0x${'dd' * 20}');
      barrier.complete();
      await tester.pumpAndSettle();
      expect(find.text('查询成功'), findsNothing);
      expect(find.text(chain.block.hash), findsNothing);
      expect(find.text('查询状态'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    } finally {
      await sdk.close();
      await transport.dispose();
    }
  });

  testWidgets('只读页面展示同块存储值和零金额 REVERT，不提供提交动作', (tester) async {
    final chain = _Chain()..flags = 1;
    final block = [chain.block.hash, '1', 'finalized'];
    final transport = TestCitizenSdkTransport({
      'getFinalizedHead': (_) => [block],
      'getRuntimeContext': (_) => [
        [block, 0, 0, _metadata()],
      ],
      'callRuntimeApi': (fields) async => [
        await chain.callRuntimeApi(
          chain.block,
          fields[1]! as String,
          fields[2]! as Uint8List,
        ),
      ],
    });
    final sdk = await transport.open();
    try {
      await tester.pumpWidget(
        Provider<CitizenSdk>.value(
          value: sdk,
          child: const MaterialApp(
            home: CitizenChainContractPage(accountId: _account),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), _contract);
      await tester.enterText(find.byType(TextField).at(1), _key);
      await tester.tap(find.text('查询'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('查询成功'),
        160,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('0x010203'), findsOneWidget);
      expect(find.text(chain.block.hash), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('合约存储'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('只读模拟').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '0x0102');
      await tester.ensureVisible(find.text('查询'));
      await tester.tap(find.text('查询'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('0x0405'),
        160,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('0x0405'), findsOneWidget);
      expect(
        transport.calls.where(
          (method) => method.contains('prepare') || method.contains('execute'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    } finally {
      await sdk.close();
      await transport.dispose();
    }
  });
}
