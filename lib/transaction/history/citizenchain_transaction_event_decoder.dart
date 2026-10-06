import 'dart:convert';
import 'dart:typed_data';

import 'package:polkadart_scale_codec/polkadart_scale_codec.dart' as scale;
import 'package:substrate_metadata/substrate_metadata.dart' as metadata;

import '../contract/citizenchain_runtime_codec.dart';

/// 本文件按准确区块的 Runtime metadata 投影 System 执行终态和 CitizenApp 业务转账事件；
/// 它不维护轻节点、扫描游标或 CitizenSDK 自有 execution history。
/// 按准确区块 metadata 解码的一次业务转账。
final class CitizenChainTransferEvent {
  const CitizenChainTransferEvent({
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountFen,
    required this.eventRecordIndex,
    required this.extrinsicIndex,
    required this.sourcePallet,
    this.remark,
  });

  final String fromAccountId;
  final String toAccountId;
  final String amountFen;
  final int eventRecordIndex;
  final int? extrinsicIndex;
  final String sourcePallet;
  final String? remark;
}

/// 事件向量中同一 extrinsic 的准确 System 执行结果。
final class CitizenChainExtrinsicOutcome {
  const CitizenChainExtrinsicOutcome({
    required this.extrinsicIndex,
    required this.succeeded,
    this.failureDescription,
  });

  final int extrinsicIndex;
  final bool succeeded;
  final String? failureDescription;
}

/// 一份准确原生费用事实；不会把 gas 或最低余额转换成手续费。
final class CitizenChainFeePaidEvent {
  const CitizenChainFeePaidEvent({
    required this.accountId,
    required this.feeFen,
    required this.eventRecordIndex,
    required this.extrinsicIndex,
  });
  final String accountId;
  final String feeFen;
  final int eventRecordIndex;
  final int extrinsicIndex;
}

/// 已验证 Runtime 事件中的合约日志，主题不是应用猜测的 ABI 字段。
final class CitizenChainContractLog {
  CitizenChainContractLog({
    required this.contract,
    required Uint8List data,
    required List<String> topics,
    required this.eventRecordIndex,
    required this.extrinsicIndex,
  }) : data = Uint8List.fromList(data).asUnmodifiableView(),
       topics = List.unmodifiable(topics);
  final String contract;
  final Uint8List data;
  final List<String> topics;
  final int eventRecordIndex;
  final int extrinsicIndex;
}

final class CitizenChainTransactionBlockEvents {
  CitizenChainTransactionBlockEvents({
    required List<CitizenChainTransferEvent> transfers,
    required Map<int, CitizenChainExtrinsicOutcome> outcomes,
    required Map<int, CitizenChainFeePaidEvent> fees,
    required List<CitizenChainContractLog> contractLogs,
  }) : transfers = List<CitizenChainTransferEvent>.unmodifiable(transfers),
       outcomes = Map<int, CitizenChainExtrinsicOutcome>.unmodifiable(outcomes),
       fees = Map<int, CitizenChainFeePaidEvent>.unmodifiable(fees),
       contractLogs = List<CitizenChainContractLog>.unmodifiable(contractLogs);

  final List<CitizenChainTransferEvent> transfers;
  final Map<int, CitizenChainExtrinsicOutcome> outcomes;
  final Map<int, CitizenChainFeePaidEvent> fees;
  final List<CitizenChainContractLog> contractLogs;
}

/// 全块按准确 metadata 解码；任一错误必须使整块投影失败，进度不得推进。
/// 同一转账的 Balances.Transfer 与 TransferWithRemark 按事件顺序一对一合并，
/// 保持 Balances 事件索引为记录身份，禁止把同金额的独立转账合为一条。
final class CitizenChainTransactionEventDecoder {
  const CitizenChainTransactionEventDecoder();

  CitizenChainTransactionBlockEvents decode({
    required Uint8List eventsBytes,
    required Uint8List metadataBytes,
  }) {
    final input = scale.ByteInput(metadataBytes);
    final runtime = metadata.RuntimeMetadataPrefixed.codec
        .decode(input)
        .metadata;
    input.assertEndOfDataReached();
    final systemStorage = runtime.pallets
        .singleWhere((p) => p.name == 'System')
        .storage;
    final entry = systemStorage?.entries.singleWhere((e) => e.name == 'Events');
    if (entry == null ||
        entry.type.key != null ||
        entry.type.hashers.isNotEmpty) {
      throw const FormatException('metadata 缺少 System.Events 普通存储');
    }
    final codec = CitizenChainPortableCodecs(runtime).codec(entry.type.value);
    final eventInput = scale.ByteInput(eventsBytes);
    final decoded = codec.decode(eventInput);
    eventInput.assertEndOfDataReached();
    final raw = _normalize(decoded);
    if (raw is! List) throw const FormatException('System.Events 必须是事件向量');

    final transfers = <CitizenChainTransferEvent>[];
    final outcomes = <int, CitizenChainExtrinsicOutcome>{};
    final fees = <int, CitizenChainFeePaidEvent>{};
    final contractLogs = <CitizenChainContractLog>[];
    for (var index = 0; index < raw.length; index++) {
      final record = raw[index] as Map;
      final extrinsicIndex = _extrinsicIndex(
        Map<String, dynamic>.from(record['phase'] as Map),
      );
      final event = record['event'] as Map;

      final system = event['System'];
      if (system is Map && extrinsicIndex != null) {
        CitizenChainExtrinsicOutcome? outcome;
        if (system.containsKey('ExtrinsicSuccess')) {
          outcome = CitizenChainExtrinsicOutcome(
            extrinsicIndex: extrinsicIndex,
            succeeded: true,
          );
        } else if (system.containsKey('ExtrinsicFailed')) {
          outcome = CitizenChainExtrinsicOutcome(
            extrinsicIndex: extrinsicIndex,
            succeeded: false,
            failureDescription: '链上执行失败',
          );
        }
        if (outcome != null) {
          if (outcomes.containsKey(extrinsicIndex)) {
            throw FormatException('extrinsic $extrinsicIndex 存在重复 System 执行终态');
          }
          outcomes[extrinsicIndex] = outcome;
        }
      }

      final onchain = event['OnchainTransaction'];
      if (onchain is Map && onchain.containsKey('FeePaid')) {
        if (extrinsicIndex == null || fees.containsKey(extrinsicIndex)) {
          throw const FormatException('FeePaid 缺少 extrinsic 或存在重复费用');
        }
        final fields = _namedFields(onchain['FeePaid'], const [
          'account_id',
          'fee',
        ], 'OnchainTransaction.FeePaid');
        fees[extrinsicIndex] = CitizenChainFeePaidEvent(
          accountId: _accountId(fields[0], 'account_id'),
          feeFen: _positiveAmount(fields[1]),
          eventRecordIndex: index,
          extrinsicIndex: extrinsicIndex,
        );
      }
      final revive = event['Revive'];
      if (revive is Map && revive.containsKey('ContractEmitted')) {
        if (extrinsicIndex == null) {
          throw const FormatException('合约日志缺少 extrinsic');
        }
        final fields = _namedFields(revive['ContractEmitted'], const [
          'contract',
          'data',
          'topics',
        ], 'Revive.ContractEmitted');
        final topics = fields[2];
        if (topics is! List || topics.length > 4) {
          throw const FormatException('合约日志主题超过 4 个或格式无效');
        }
        contractLogs.add(
          CitizenChainContractLog(
            contract: '0x${_hexEncode(_eventBytes(fields[0], 20))}',
            data: _eventBytes(fields[1]),
            topics: topics
                .map((topic) => '0x${_hexEncode(_eventBytes(topic, 32))}')
                .toList(),
            eventRecordIndex: index,
            extrinsicIndex: extrinsicIndex,
          ),
        );
      }
      if (onchain is Map && onchain.containsKey('TransferWithRemark')) {
        final fields = _namedFields(onchain['TransferWithRemark'], const [
          'from_account_id',
          'beneficiary_account_id',
          'amount',
          'remark',
        ], 'OnchainTransaction.TransferWithRemark');
        final from = _accountId(fields[0], 'from_account_id');
        final to = _accountId(fields[1], 'beneficiary_account_id');
        final amount = _positiveAmount(fields[2]);
        final matching = transfers.lastIndexWhere(
          (transfer) =>
              transfer.sourcePallet == 'Balances' &&
              transfer.extrinsicIndex == extrinsicIndex &&
              transfer.fromAccountId == from &&
              transfer.toAccountId == to &&
              transfer.amountFen == amount,
        );
        // Runtime 在 Currency::transfer 成功后才发备注事件，必须找到前序本金事件。
        if (matching < 0) {
          throw const FormatException('备注事件缺少同一执行中的前序转账事件');
        }
        transfers[matching] = CitizenChainTransferEvent(
          fromAccountId: from,
          toAccountId: to,
          amountFen: _positiveAmount(fields[2]),
          eventRecordIndex: transfers[matching].eventRecordIndex,
          extrinsicIndex: extrinsicIndex,
          sourcePallet: 'OnchainTransaction',
          remark: _remark(fields[3]),
        );
        continue;
      }

      final balances = event['Balances'];
      if (balances is Map && balances.containsKey('Transfer')) {
        final fields = _namedFields(balances['Transfer'], const [
          'from',
          'to',
          'amount',
        ], 'Balances.Transfer');
        transfers.add(
          CitizenChainTransferEvent(
            fromAccountId: _accountId(fields[0], 'from'),
            toAccountId: _accountId(fields[1], 'to'),
            amountFen: _positiveAmount(fields[2]),
            eventRecordIndex: index,
            extrinsicIndex: extrinsicIndex,
            sourcePallet: 'Balances',
          ),
        );
      }
    }
    for (final log in contractLogs) {
      if (outcomes[log.extrinsicIndex]?.succeeded == false) {
        throw const FormatException('失败执行不能保留合约日志');
      }
    }
    return CitizenChainTransactionBlockEvents(
      transfers: transfers,
      outcomes: outcomes,
      fees: fees,
      contractLogs: contractLogs,
    );
  }

  List<Object?> _namedFields(Object? raw, List<String> names, String label) {
    if (raw is! Map) {
      throw FormatException('$label 必须由 metadata 解码为命名字段');
    }
    final values = <Object?>[];
    for (final name in names) {
      if (!raw.containsKey(name)) {
        throw FormatException('$label 缺少字段 $name');
      }
      values.add(raw[name]);
    }
    return values;
  }

  int? _extrinsicIndex(Map<String, dynamic> phase) {
    final raw = phase['ApplyExtrinsic'];
    if (raw == null) return null;
    if (raw is int && raw >= 0 && raw <= 0xffffffff) return raw;
    if (raw is BigInt && raw >= BigInt.zero && raw <= BigInt.from(0xffffffff)) {
      return raw.toInt();
    }
    if (raw is String) {
      final value = int.tryParse(raw);
      if (value != null && value >= 0 && value <= 0xffffffff) return value;
    }
    throw const FormatException('ApplyExtrinsic phase index 无效');
  }

  String _accountId(Object? raw, String field) {
    final bytes = raw is Uint8List
        ? raw
        : raw is List &&
              raw.every((value) => value is int && value >= 0 && value <= 255)
        ? Uint8List.fromList(raw.cast<int>())
        : null;
    if (bytes == null || bytes.length != 32) {
      throw FormatException('$field 必须是 32 字节 AccountId');
    }
    return '0x${_hexEncode(bytes)}';
  }

  String _positiveAmount(Object? raw) {
    final value = switch (raw) {
      BigInt value => value,
      int value => BigInt.from(value),
      String value => BigInt.tryParse(value),
      _ => null,
    };
    if (value == null || value <= BigInt.zero || value >= (BigInt.one << 128)) {
      throw const FormatException('transfer amount 必须是正 u128');
    }
    return value.toString();
  }

  Uint8List _eventBytes(Object? value, [int? length]) {
    if (value is! List ||
        (length != null && value.length != length) ||
        !value.every((byte) => byte is int && byte >= 0 && byte <= 255)) {
      throw const FormatException('合约事件字节长度或内容无效');
    }
    return Uint8List.fromList(value.cast<int>());
  }

  String? _remark(Object? raw) {
    final bytes = raw is Uint8List
        ? raw
        : raw is List &&
              raw.every((value) => value is int && value >= 0 && value <= 255)
        ? Uint8List.fromList(raw.cast<int>())
        : null;
    if (bytes == null || bytes.length > 99) {
      throw const FormatException('remark 必须是最多 99 字节的 Runtime bytes');
    }
    return bytes.isEmpty ? null : utf8.decode(bytes, allowMalformed: true);
  }

  String _hexEncode(Uint8List bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  /// 保留整数与字节，枚举只转换结构，不经 JSON 或类型名猜测字段。
  Object? _normalize(Object? value) {
    if (value is MapEntry) return {value.key: _normalize(value.value)};
    if (value is Map) {
      return value.map((key, item) => MapEntry(key, _normalize(item)));
    }
    if (value is List) return value.map(_normalize).toList();
    return value;
  }
}
