import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:polkadart/polkadart.dart' show Hasher;
import 'package:polkadart_scale_codec/polkadart_scale_codec.dart' as scale;

import '../history/citizenchain_transaction_event_decoder.dart';
import 'citizenchain_runtime_codec.dart';

/// 只读结果始终携带准确 finalized 锚点；gas 是资源计数，不能转换成 GMB 费用。
final class CitizenChainContractRead {
  CitizenChainContractRead({
    required this.block,
    required Uint8List? data,
    this.gasConsumed,
    this.reverted = false,
    this.failureDescription,
  }) : data = data == null
           ? null
           : Uint8List.fromList(data).asUnmodifiableView();
  final CitizenBlockRef block;
  final Uint8List? data;
  final BigInt? gasConsumed;
  final bool reverted;
  final String? failureDescription;
}

/// 从已验证正文和事件重建原生执行记录；交易序号属于 Substrate 正文。
final class CitizenChainContractExecution {
  CitizenChainContractExecution({
    required this.block,
    required this.extrinsicIndex,
    required this.transactionHash,
    required this.outcome,
    required this.fee,
    required List<CitizenChainContractLog> logs,
  }) : logs = List.unmodifiable(logs);
  final CitizenBlockRef block;
  final int extrinsicIndex;
  final String transactionHash;
  final CitizenChainExtrinsicOutcome outcome;
  final CitizenChainFeePaidEvent? fee;
  final List<CitizenChainContractLog> logs;
}

/// 合约参数和输出解释属于 App；全部读取复用 SDK 的同一个已验证轻节点。
/// 没有节点 RPC、签名、提交、map_account 或余额修改入口。
final class CitizenChainContractReadService {
  CitizenChainContractReadService(this.chain);
  final CitizenChain chain;
  static const maxInputBytes = 4096;
  static const maxOutputBytes = 1024 * 1024;

  Future<(CitizenBlockRef, CitizenChainRuntimeCodec)> _context() async {
    final block = await chain.getFinalizedHead();
    _finalized(block);
    final context = await chain.getRuntimeContext(block);
    _same(block, context.block);
    var codec = CitizenChainRuntimeCodec(context.metadata);
    if (codec.runtime.apis.isEmpty) {
      // V14 不含 Runtime API 类型表；在同一已验证块读取官方 V15 metadata，
      // 不替换 SDK 的交易 metadata 或引入节点元数据缓存。
      final raw = await chain.callRuntimeApi(
        block,
        'Metadata_metadata_at_version',
        Uint8List.fromList([15, 0, 0, 0]),
      );
      _size(raw);
      final input = scale.ByteInput(raw);
      final option = const scale.OptionCodec(
        scale.SequenceCodec(scale.U8Codec.codec),
      );
      final value = option.decode(input);
      input.assertEndOfDataReached();
      final canonical = option.encode(value);
      if (value == null ||
          canonical.length != raw.length ||
          List.generate(
            raw.length,
            (i) => i,
          ).any((i) => canonical[i] != raw[i])) {
        throw const FormatException('准确区块未提供规范 V15 metadata');
      }
      codec = CitizenChainRuntimeCodec(Uint8List.fromList(value));
      if (codec.runtime.runtimeMetadataVersion() != 15) {
        throw const FormatException('准确区块 metadata 版本不一致');
      }
    }
    return (block, codec);
  }

  Future<CitizenChainContractRead> getStorage({
    required String contract,
    required String key,
  }) async {
    final address = bytes(contract, 20);
    final storageKey = bytes(key, 32);
    final (block, codec) = await _context();
    final method = codec.method('ReviveApi', 'get_storage');
    final raw = await chain.callRuntimeApi(
      block,
      'ReviveApi_get_storage',
      codec.arguments(method, {'address': address, 'key': storageKey}),
    );
    _size(raw);
    final result = _map(codec.result(method, raw));
    if (result.containsKey('Err') && result.length == 1) {
      return CitizenChainContractRead(
        block: block,
        data: null,
        failureDescription: '合约存储查询失败：${result['Err']}',
      );
    }
    final option = _map(_only(result, 'Ok'));
    if (option.containsKey('None') && option.length == 1) {
      return CitizenChainContractRead(block: block, data: null);
    }
    return CitizenChainContractRead(
      block: block,
      data: _bytes(_only(option, 'Some')),
    );
  }

  /// value 固定为零、存储押金上限固定为零，不构造任何可提交交易。
  /// Runtime API 模拟由 SDK 在准确块上执行，临时执行状态不写入已验证链。
  Future<CitizenChainContractRead> call({
    required String accountId,
    required String contract,
    required String inputData,
  }) async {
    final origin = bytes(accountId, 32);
    final dest = bytes(contract, 20);
    if (inputData.length > 2 + maxInputBytes * 2) {
      throw const FormatException('调用数据超过 4096 字节');
    }
    final input = bytes(inputData);
    final (block, codec) = await _context();
    final method = codec.method('ReviveApi', 'call');
    final raw = await chain.callRuntimeApi(
      block,
      'ReviveApi_call',
      codec.arguments(method, {
        'origin': origin,
        'dest': dest,
        'value': BigInt.zero,
        'gas_limit': const MapEntry('None', null),
        'storage_deposit_limit': MapEntry('Some', BigInt.zero),
        'input_data': input,
      }),
    );
    _size(raw);
    final result = _map(codec.result(method, raw));
    // 当前链的 Deposit=()，存储押金不是 ED，也不是原生手续费。
    for (final name in ['storage_deposit', 'max_storage_deposit']) {
      final deposit = _map(result[name]);
      if (deposit.length != 1 ||
          !['Charge', 'Refund'].contains(deposit.keys.single) ||
          integer(deposit.values.single) != BigInt.zero) {
        throw const FormatException('准确链的模拟存储押金合同不一致');
      }
    }
    final gas = integer(result['gas_consumed']);
    final execution = _map(result['result']);
    if (execution.containsKey('Err') && execution.length == 1) {
      return CitizenChainContractRead(
        block: block,
        data: null,
        gasConsumed: gas,
        failureDescription: '合约执行失败：${execution['Err']}',
      );
    }
    final returned = _map(_only(execution, 'Ok'));
    // 当前 V15 的 ReturnFlags 是具名 bits 包装，仍只解释成功/REVERT 两个值。
    final flagFields = _map(returned['flags']);
    final flags = integer(_only(flagFields, 'bits'));
    if (flags > BigInt.one) throw const FormatException('未知合约返回标记');
    return CitizenChainContractRead(
      block: block,
      data: _bytes(returned['data']),
      gasConsumed: gas,
      reverted: flags == BigInt.one,
    );
  }

  Future<CitizenChainContractExecution> execution({
    required BigInt blockNumber,
    required int extrinsicIndex,
  }) async {
    if (blockNumber < BigInt.zero || extrinsicIndex < 0) {
      throw const FormatException('区块和原生交易序号必须非负');
    }
    final block = await chain.getFinalizedBlockAt(blockNumber);
    _finalized(block);
    if (block.number != blockNumber) throw StateError('区块高度与请求不一致');
    final context = await chain.getRuntimeContext(block);
    _same(block, context.block);
    final body = await chain.getBlockBody(block);
    _same(block, body.block);
    if (extrinsicIndex >= body.extrinsics.length) {
      throw const FormatException('原生交易序号超出区块正文');
    }
    final events = await chain.getSystemEvents(block);
    if (events == null || events.isEmpty) {
      throw const FormatException('区块缺少执行事件');
    }
    final decoded = const CitizenChainTransactionEventDecoder().decode(
      eventsBytes: events,
      metadataBytes: context.metadata,
    );
    final outcome = decoded.outcomes[extrinsicIndex];
    if (outcome == null) throw const FormatException('原生交易缺少 System 执行结果');
    final logs = decoded.contractLogs
        .where((log) => log.extrinsicIndex == extrinsicIndex)
        .toList();
    if (!outcome.succeeded && logs.isNotEmpty) {
      throw const FormatException('失败执行不能保留合约日志');
    }
    return CitizenChainContractExecution(
      block: block,
      extrinsicIndex: extrinsicIndex,
      transactionHash: hex(
        Hasher.blake2b256.hash(body.extrinsics[extrinsicIndex]),
      ),
      outcome: outcome,
      fee: decoded.fees[extrinsicIndex],
      logs: logs,
    );
  }

  static void _finalized(CitizenBlockRef block) {
    if (block.finality != CitizenBlockFinality.finalized ||
        block.number < BigInt.zero) {
      throw StateError('合约查询要求准确 finalized 区块');
    }
  }

  static void _same(CitizenBlockRef expected, CitizenBlockRef actual) {
    if (expected.hash != actual.hash ||
        expected.number != actual.number ||
        expected.finality != actual.finality) {
      throw StateError('已验证区块锚点不一致');
    }
  }

  static Uint8List bytes(String value, [int? length]) {
    if (!RegExp(r'^0x(?:[0-9a-fA-F]{2})*$').hasMatch(value) ||
        (length != null && value.length != 2 + length * 2)) {
      throw const FormatException('请输入完整 0x 十六进制字节');
    }
    return Uint8List.fromList([
      for (var i = 2; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ]);
  }

  static String hex(List<int> value) =>
      '0x${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  static BigInt integer(Object? value) {
    final result = value is BigInt
        ? value
        : value is int
        ? BigInt.from(value)
        : null;
    if (result == null || result < BigInt.zero) {
      throw const FormatException('Runtime 整数无效');
    }
    return result;
  }

  static Map _map(Object? value) {
    if (value is! Map) throw const FormatException('Runtime 返回结构无效');
    return value;
  }

  static Object? _only(Map map, String name) {
    if (map.length != 1 || !map.containsKey(name)) {
      throw const FormatException('Runtime 枚举无效');
    }
    return map[name];
  }

  static Uint8List _bytes(Object? value) {
    if (value is! List || !value.every((b) => b is int && b >= 0 && b <= 255)) {
      throw const FormatException('Runtime 字节结构无效');
    }
    return Uint8List.fromList(value.cast<int>());
  }

  static void _size(Uint8List value) {
    if (value.length > maxOutputBytes) {
      throw const FormatException('合约返回数据超过 1 MiB');
    }
  }
}
