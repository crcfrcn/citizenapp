import 'dart:typed_data';

import 'package:polkadart/polkadart.dart' show Hasher;
import 'package:substrate_metadata/substrate_metadata.dart' as metadata;

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_onchain/onchain_payment_models.dart';
import 'package:citizen_onchain/onchain_payment_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';

const _cid = 'CN220-CTZN2-100000001-2026';

class _Reader extends CitizenIdentityChainReader {
  _Reader(this.binding) : super();
  final CitizenBindingChainSnapshot? binding;
  int reads = 0;
  @override
  Future<CitizenBindingChainSnapshot?> readBindingByCidNumber(
    String cid, {CitizenBlockRef? at}
  ) async {
    expect(cid, _cid);
    reads++;
    return binding;
  }
}

void main() {
  test('备注上限读取请求块中的 Runtime 常量，缺失时拒绝', () async {
    final service = _ethereumService(metadataBytes: _mappingMetadata(remarkLimit: 6));
    expect(await service.readRemarkLimit(_block), 6);
    await expectLater(_ethereumService().readRemarkLimit(_block), throwsA(isA<CitizenSdkException>()));
  });

  OnchainPaymentService service(_Reader reader) => (() {
    final reads0 = TestWalletReads();
    final reads1 = TestTransactionCalls();
    return OnchainPaymentService(
      getWalletState: reads0.getWalletState,
      prepareTransaction: reads1.prepareTransaction,
      cancelPreparedTransaction: reads1.cancelPreparedTransaction,
      bindingReader: reader,
    );
  })();
  test('Ethereum已有映射优先使用同块32字节账户', () async {
    final mapped = Uint8List.fromList(List.filled(32, 0xbb));
    final recipient = await _ethereumService(mapped: mapped)
        .resolveRecipient(address: _ethereum);
    expect(recipient.address, citizenSs58FromAccountIdBytes(mapped));
    expect(recipient.blockHash, _block.hash);
  });
  test('无映射时补EE，0x与对应SS58生成完全相同的原交易调用', () async {
    final expected = Uint8List.fromList([
      ..._ethereumBytes,
      ...List.filled(12, 0xee),
    ]);
    final ss58 = citizenSs58FromAccountIdBytes(expected);
    for (final address in [
      _ethereum,
      _ethereum.toLowerCase(),
      '0x${_ethereum.substring(2).toUpperCase()}',
    ]) {
      final recipient = await _ethereumService().resolveRecipient(
        address: ' $address ',
      );
      expect(recipient.address, ss58);
      final native = await OnchainPaymentService().resolveRecipient(
        address: ss58,
      );
      Future<Uint8List> encode(String address) async {
        late Uint8List captured;
        await _transferService(onCall: (call) => captured = call)
            .prepareTransfer(_draft(address, remark: '测试'));
        return captured;
      }
      expect(await encode(recipient.address), await encode(native.address));
    }
  });

  test('转账调用保持原账户、u128 分和 UTF-8 备注的 SCALE 金标', () async {
    late Uint8List call;
    final destination = Uint8List.fromList(List<int>.filled(32, 0x11));
    await _transferService(onCall: (value) => call = value).prepareTransfer(
      _draft(citizenSs58FromAccountIdBytes(destination), remark: 'ab'),
    );
    expect(call, [4, 0, ...destination, 0x34, 0x12, ...List.filled(14, 0), 8, 0x61, 0x62]);
  });

  test('非法金额、地址和超长 UTF-8 备注在 SDK 准备前拒绝', () async {
    final valid = citizenSs58FromAccountId('0x${'11' * 32}');
    final service = _transferService(onCall: (_) => fail('非法草稿不得准备'));
    for (final draft in [
      _draft(valid, amount: BigInt.zero),
      _draft('invalid'),
      _draft(valid, remark: '测' * 34),
    ]) {
      await expectLater(service.prepareTransfer(draft), throwsA(isA<OnchainPaymentException>()));
    }
  });

  test('SDK 准备回执的 Runtime 版本变化时释放句柄', () async {
    final released = <String>[];
    final service = _transferService(
      preparedSpec: 2,
      onCancel: (id) async { released.add(id); },
    );
    await expectLater(
      service.prepareTransfer(_draft(citizenSs58FromAccountId('0x${'11' * 32}'))),
      throwsA(isA<OnchainPaymentException>()),
    );
    expect(released, ['prepared']);
  });

  test('交易失败文案只使用真实步骤和一次原因', () {
    for (final (step, code, message) in [
      (OnchainPaymentStep.preparation, CitizenSdkErrorCode.decode, '交易准备失败：链上数据解析异常'),
      (OnchainPaymentStep.execution, CitizenSdkErrorCode.network, '交易执行失败：区块链暂不可用'),
      (OnchainPaymentStep.externalSignature, CitizenSdkErrorCode.cancelled, '交易签名失败：操作已取消'),
      (OnchainPaymentStep.preparation, CitizenSdkErrorCode.internal, '交易准备失败：请稍后重试'),
    ]) {
      expect(onchainPaymentFailureText(step, code), message);
    }
  });
  test('无效0x、错误大小写校验和及32字节hex在读链前拒绝', () async {
    for (final address in [
      '0x',
      '0x1234',
      '0x${'aa' * 32}',
      '0x6D66a0cB155051055F3FB3Cc73d9230D3Fb4D5BZ',
      '0x6d66a0cB155051055F3FB3Cc73d9230D3Fb4D5B5',
    ]) {
      await expectLater(
        OnchainPaymentService().resolveRecipient(address: address),
        throwsFormatException,
      );
    }
  });
  test('SS58校验前缀、校验和和账户长度，无需读取链', () async {
    final account = Uint8List.fromList(List.filled(32, 0xbb));
    for (final address in [
      '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY',
      'invalid',
      '${citizenSs58FromAccountIdBytes(account)}1',
    ]) {
      await expectLater(
        OnchainPaymentService().resolveRecipient(address: address),
        throwsFormatException,
      );
    }
  });
  test('映射读取失败原样抛出，坏长度不降级补EE', () async {
    final failure = StateError('链读取失败');
    await expectLater(
      _ethereumService(readError: failure).resolveRecipient(address: _ethereum),
      throwsA(same(failure)),
    );
    for (final length in [0, 20, 31, 33]) {
      await expectLater(
        _ethereumService(mapped: Uint8List(length))
            .resolveRecipient(address: _ethereum),
        throwsFormatException,
      );
    }
  });
  test('旧Runtime、缺映射或错误hasher均在读映射前停止', () async {
    var reads = 0;
    for (final bytes in [
      _mappingMetadata(revive: false),
      _mappingMetadata(mapping: false),
      _mappingMetadata(hasher: metadata.StorageHasher.blake2_128Concat),
    ]) {
      await expectLater(
        _ethereumService(
          metadataBytes: bytes,
          onStorage: () => reads++,
        ).resolveRecipient(address: _ethereum),
        throwsStateError,
      );
    }
    expect(reads, 0);
  });
  test('元数据坏编码或不同块不允许解析，禁止混读状态', () async {
    var reads = 0;
    final other = CitizenBlockRef(
      hash: '0x${'22' * 32}',
      number: _block.number,
      finality: _block.finality,
    );
    await expectLater(
      _ethereumService(
        metadataBlock: other,
        onStorage: () => reads++,
      ).resolveRecipient(address: _ethereum),
      throwsStateError,
    );
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([..._mappingMetadata(), 0]),
    ]) {
      await expectLater(
        _ethereumService(
          metadataBytes: bytes,
          onStorage: () => reads++,
        ).resolveRecipient(address: _ethereum),
        throwsA(anything),
      );
    }
    expect(reads, 0);
  });
  test('CID签名前只解析一次，采用换绑后当前账户，不沿用联系人旧地址', () async {
    final binding = CitizenBindingChainSnapshot(
      cidNumber: _cid,
      accountId: Uint8List.fromList(List.filled(32, 0xaa)),
      bindRev: 2,
      block: CitizenBlockRef(
        hash: '0x${'11' * 32}',
        number: BigInt.from(9),
        finality: CitizenBlockFinality.finalized,
      ),
    );
    final reader = _Reader(binding);
    final target = await service(reader).resolveRecipient(
      address: citizenSs58FromAccountId('0x${'bb' * 32}'),
      cidNumber: _cid,
    );
    expect(reader.reads, 1);
    expect(target.address, citizenSs58FromAccountId(binding.accountIdText));
    expect(target.cidNumber, _cid);
    expect(target.bindRev, 2);
    expect(target.blockHash, binding.block!.hash);
  });
  test('无有效绑定时拒绝，禁止回退联系人缓存地址', () async {
    final reader = _Reader(null);
    await expectLater(
      service(reader).resolveRecipient(
        address: citizenSs58FromAccountId('0x${'bb' * 32}'),
        cidNumber: _cid,
      ),
      throwsStateError,
    );
    expect(reader.reads, 1);
  });
  test('直接账户转账不解析CID', () async {
    final reader = _Reader(null);
    final address = citizenSs58FromAccountId('0x${'bb' * 32}');
    expect(
      (await service(reader).resolveRecipient(address: address)).address,
      address,
    );
    expect(reader.reads, 0);
  });
  test('确认账户与待签草稿不一致时，在钱包读取和交易准备前拒绝', () async {
    final reader = _Reader(null);
    await expectLater(
      service(reader).prepareTransfer(
        OnchainPaymentDraft(
          sourceAccountId: '0x${'aa' * 32}',
          toAddress: 'changed',
          amountFen: BigInt.from(100),
          symbol: 'GMB',
          remark: '',
          recipient: const OnchainRecipient(
            address: 'confirmed',
            cidNumber: _cid,
          ),
        ),
      ),
      throwsA(isA<OnchainPaymentException>()),
    );
    expect(reader.reads, 0);
  });
}

const _ethereum = '0x6D66a0cB155051055F3FB3Cc73d9230D3Fb4D5B5';
final _best = CitizenBlockRef(
  hash: '0x${'22' * 32}', number: BigInt.one, finality: CitizenBlockFinality.best,
);

OnchainPaymentDraft _draft(String address, {BigInt? amount, String remark = ''}) =>
    OnchainPaymentDraft(
      sourceAccountId: testCitizenAccountId,
      toAddress: address,
      amountFen: amount ?? BigInt.from(0x1234),
      symbol: 'GMB',
      remark: remark,
    );

OnchainPaymentService _transferService({
  void Function(Uint8List)? onCall,
  Future<void> Function(String)? onCancel,
  int preparedSpec = 1,
}) => OnchainPaymentService(
  getBestHead: () async => _best,
  getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
  getWalletState: () => testCitizenOperation(testCitizenWalletState),
  prepareTransaction: (source, call) async {
    onCall?.call(call);
    return CitizenPreparedTransaction(
      preparationId: 'prepared', sourceAccountId: source,
      callDataHash: CitizenScale.blake2b256(call), bestBlock: _best,
      runtimeSpecNumber: preparedSpec, transactionFormatNumber: 4, nonce: BigInt.zero,
    );
  },
  cancelPreparedTransaction: onCancel,
);

final _block = CitizenBlockRef(
  hash: '0x${'11' * 32}',
  number: BigInt.from(9),
  finality: CitizenBlockFinality.finalized,
);

Uint8List _mappingMetadata({
  bool revive = true,
  bool mapping = true,
  metadata.StorageHasher hasher = metadata.StorageHasher.identity,
  int? remarkLimit,
}) {
  final runtime = metadata.RuntimeMetadataV15(
    types: [
      metadata.PortableType(
        id: 0,
        type: metadata.TypeMetadata(
          path: [],
          params: [],
          typeDef: const metadata.TypeDefTuple([]),
          docs: [],
        ),
      ),
      metadata.PortableType(
        id: 1,
        type: metadata.TypeMetadata(
          path: [], params: [], docs: [],
          typeDef: const metadata.TypeDefPrimitive(metadata.Primitive.U8),
        ),
      ),
      metadata.PortableType(
        id: 2,
        type: metadata.TypeMetadata(
          path: [], params: [], docs: [],
          typeDef: const metadata.TypeDefArray(length: 20, type: 1),
        ),
      ),
      metadata.PortableType(
        id: 3,
        type: metadata.TypeMetadata(
          path: [], params: [], docs: [],
          typeDef: const metadata.TypeDefPrimitive(metadata.Primitive.U32),
        ),
      ),
    ],
    pallets: [
      if (revive)
        metadata.PalletMetadata(
          name: 'Revive',
          index: 35,
          constants: [],
          docs: [],
          storage: metadata.PalletStorageMetadata(
            prefix: 'Revive',
            entries: [
              if (mapping)
                metadata.StorageEntryMetadata(
                  name: 'OriginalAccount',
                  modifier: metadata.StorageEntryModifier.optional,
                  type: metadata.StorageEntryType(
                    hashers: [hasher],
                    key: 2,
                    value: 0,
                  ),
                  defaultValue: [],
                  docs: [],
                ),
            ],
          ),
        ),
      if (remarkLimit != null)
        metadata.PalletMetadata(
          name: 'OnchainTransaction',
          index: 4,
          storage: null,
          docs: [],
          constants: [
            metadata.PalletConstantMetadata(
              name: 'MaxTransferRemarkLen',
              type: 3,
              value: (ByteData(4)..setUint32(0, remarkLimit, Endian.little))
                  .buffer.asUint8List(),
              docs: [],
            ),
          ],
        ),
    ],
    extrinsic: metadata.ExtrinsicMetadata(
      version: 4,
      signedExtensions: [],
      addressType: 0,
      callType: 0,
      signatureType: 0,
      extraType: 0,
    ),
    runtimeTypeId: 0,
    apis: [],
    custom: metadata.CustomMetadata(map: {}),
    outerEnums: metadata.OuterEnumMetadata(
      callType: 0,
      eventType: 0,
      errorType: 0,
    ),
  );
  return Uint8List.fromList([
    0x6d,
    0x65,
    0x74,
    0x61,
    15,
    ...metadata.RuntimeMetadataV15.codec.encode(runtime),
  ]);
}

OnchainPaymentService _ethereumService({
  Uint8List? mapped,
  Uint8List? metadataBytes,
  CitizenBlockRef? metadataBlock,
  Object? readError,
  void Function()? onStorage,
}) => OnchainPaymentService(
  getFinalizedHead: () async => _block,
  getRuntimeContext: (block) async {
    expect(identical(block, _block), isTrue);
    return CitizenRuntimeContext(
      block: metadataBlock ?? block,
      specVersion: 1,
      transactionVersion: 1,
      metadata: metadataBytes ?? _mappingMetadata(),
    );
  },
  getStorage: (block, key) async {
    onStorage?.call();
    expect(identical(block, _block), isTrue);
    // Identity键共52字节；不能插入Blake2_128Concat的额外哈希。
    expect(key.length, 52);
    expect(key.take(32), [
      ...Hasher.twoxx128.hashString('Revive'),
      ...Hasher.twoxx128.hashString('OriginalAccount'),
    ]);
    expect(key.skip(32), _ethereumBytes);
    if (readError != null) throw readError;
    return mapped;
  },
);
final _ethereumBytes = Uint8List.fromList([
  for (var i = 2; i < _ethereum.length; i += 2)
    int.parse(_ethereum.substring(i, i + 2), radix: 16),
]);
