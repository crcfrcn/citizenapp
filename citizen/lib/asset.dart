// 链上资产常量、提案模型及查询。

import 'package:citizen_citizen/data.dart' show PalletRegistry;
import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';

// 声明尚未开放代币业务的固定调用索引和动作编号。

class OnchainAssetActions {
  OnchainAssetActions._();

  // ---------- pallet_index / call_index(与链端 + citizenwallet PalletRegistry 同步) ----------

  /// OnchainIssue pallet_index(单源 PalletRegistry,对齐 construct_runtime)。
  static const int onchainIssuePalletIndex =
      PalletRegistry.onchainIssuePallet;

  /// pallet_assets 内核 pallet_index(原生 extrinsic 全部被 RuntimeCallFilter reject)。
  static const int assetsPalletIndex = PalletRegistry.assetsPallet;

  // 业务 propose_X(call_index 0..=4)
  static const int callProposeIssue = PalletRegistry.proposeIssueCall;
  static const int callProposeMint = PalletRegistry.proposeMintCall;
  static const int callProposeBurn = PalletRegistry.proposeBurnCall;
  static const int callProposeClose = PalletRegistry.proposeCloseAssetCall;
  static const int callProposeTransfer =
      PalletRegistry.proposeAssetTransferCall;

  // 监管 propose_monitor_X(call_index 10..=14)
  static const int callProposeMonitorFreeze =
      PalletRegistry.proposeMonitorFreezeCall;
  static const int callProposeMonitorUnfreeze =
      PalletRegistry.proposeMonitorUnfreezeCall;
  static const int callProposeMonitorConfiscate =
      PalletRegistry.proposeMonitorConfiscateCall;
  static const int callProposeMonitorForceTransfer =
      PalletRegistry.proposeMonitorForceTransferCall;
  static const int callProposeMonitorForceClose =
      PalletRegistry.proposeMonitorForceCloseCall;

  // ---------- ACTION 字符串常量(VotingEngine ProposalData 业务标签) ----------

  // 业务 ACTION(InternalVote)
  static const String actionIssue = 'OAIS';
  static const String actionMint = 'OAMT';
  static const String actionBurn = 'OABN';
  static const String actionClose = 'OACL';
  static const String actionTransfer = 'OATR';

  // 监管 ACTION(JointVote)
  static const String actionMonitorFreeze = 'OMFZ';
  static const String actionMonitorUnfreeze = 'OMUF';
  static const String actionMonitorConfiscate = 'OMCF';
  static const String actionMonitorForceTransfer = 'OMFT';
  static const String actionMonitorForceClose = 'OMFC';

  /// VotingEngine ProposalData 业务标签前缀(与链端 MODULE_TAG 一致)。
  static const String moduleTag = 'onc-iss';

  /// decimals合法区间，对齐链端onchainissue::validation。
  static const int minDecimals = 0;
  static const int maxDecimals = 18;
}

// 定义尚未接入数据库的资产提案候选记录模型。

class OnchainAssetProposalEntity {
  OnchainAssetProposalEntity({
    required this.proposalId,
    required this.action,
    required this.assetId,
    required this.proposerSs58,
    required this.createdAtBlock,
    required this.createdAtMs,
    this.amount,
    this.counterpartySs58,
    this.reasonHashHex,
    this.status = 'Voting',
  });

  /// VotingEngine分配的全局u128提案ID；年份/序号属于独立展示元数据，不拆分此主键。
  final BigInt proposalId;

  /// 4 字符 ACTION 常量(OAIS / OAMT / OABN / ... / OMFC)。
  final String action;

  /// 资产编号；发行提案尚无编号时为空，不能由本地候选记录推定已分配。
  int? assetId;

  final String proposerSs58;
  final int createdAtBlock;
  final int createdAtMs;

  /// mint / burn / transfer / confiscate / forceTransfer 时的金额(raw,含 decimals)。
  BigInt? amount;

  /// transfer / forceTransfer 的对方 SS58。
  String? counterpartySs58;

  /// 监管 5 动作的 reason_hash(链下文书 sha256)hex 字符串。
  String? reasonHashHex;

  /// 尚未接线的本地状态文本，不能替代链上提案或资产状态。
  String status;
}

// 定义资产元数据及发行结果模型，并严格解码其SCALE布局。

/// 链端SCALE枚举；pegged仅为保留协议位，能解码不表示允许发行。
enum OnchainAssetClass { plain, pegged }

enum OnchainAssetStateKind { active, closed, forceClosed }

class OnchainAssetState {
  const OnchainAssetState._({required this.kind, this.closeBlock});

  const OnchainAssetState.active() : this._(kind: OnchainAssetStateKind.active);

  const OnchainAssetState.closed() : this._(kind: OnchainAssetStateKind.closed);

  const OnchainAssetState.forceClosed({required int closeBlock})
    : this._(kind: OnchainAssetStateKind.forceClosed, closeBlock: closeBlock);

  final OnchainAssetStateKind kind;

  /// 仅 ForceClosed 携带，对齐 runtime `ForceClosed { close_block: u32 }`。
  final int? closeBlock;
}

class OnchainAssetMeta {
  OnchainAssetMeta({
    required this.assetId,
    required this.actorCidNumber,
    required Uint8List executionAccountId,
    required this.assetClass,
    required this.decimals,
    required this.state,
  }) : executionAccountId = Uint8List.fromList(executionAccountId);

  /// storage key `OnchainIssue.AssetMetas[asset_id]`，不是 OnchainAssetMeta value 的内嵌字段。
  final int assetId;

  /// 发行机构 CID；机构身份和管理员权限只按此字段寻址。
  final String actorCidNumber;

  /// 资产执行账户 AccountId32；只承担资产执行，不表示机构身份。
  final Uint8List executionAccountId;

  final OnchainAssetClass assetClass;
  final int decimals;
  final OnchainAssetState state;
}

class OnchainAssetIssued {
  OnchainAssetIssued({
    required this.assetId,
    required this.actorCidNumber,
    required Uint8List executionAccountId,
  }) : executionAccountId = Uint8List.fromList(executionAccountId);

  final int assetId;
  final String actorCidNumber;
  final Uint8List executionAccountId;
}

/// runtime storage/event 的局部 SCALE 镜像。
///
/// 解码必须完整消费输入；未知枚举、超长 CID、畸形 UTF-8 或尾随字节一律拒绝，
/// 禁止把任何非当前布局误读为当前协议。
class OnchainAssetScaleCodec {
  OnchainAssetScaleCodec._();

  static const int _accountIdLength = 32;
  static const int _maxCidNumberLength = 32;

  static OnchainAssetMeta decodeMeta({
    required int assetId,
    required Uint8List scale,
  }) {
    _ensureAssetId(assetId);
    final reader = _ScaleReader(scale);
    final actorCidNumber = reader.readCidNumber();
    final executionAccountId = reader.readBytes(_accountIdLength);
    final assetClass = switch (reader.readU8()) {
      0 => OnchainAssetClass.plain,
      1 => OnchainAssetClass.pegged,
      final value => throw FormatException('未知 AssetClass 枚举: $value'),
    };
    final decimals = reader.readU8();
    if (decimals < OnchainAssetActions.minDecimals ||
        decimals > OnchainAssetActions.maxDecimals) {
      throw FormatException('OnchainAssetMeta.decimals 超出链端范围: $decimals');
    }
    final state = _decodeState(reader);
    reader.ensureFinished('OnchainAssetMeta');
    return OnchainAssetMeta(
      assetId: assetId,
      actorCidNumber: actorCidNumber,
      executionAccountId: executionAccountId,
      assetClass: assetClass,
      decimals: decimals,
      state: state,
    );
  }

  static OnchainAssetIssued decodeAssetIssued(Uint8List scale) {
    final reader = _ScaleReader(scale);
    final assetId = reader.readU32();
    final actorCidNumber = reader.readCidNumber();
    final executionAccountId = reader.readBytes(_accountIdLength);
    reader.ensureFinished('AssetIssued');
    return OnchainAssetIssued(
      assetId: assetId,
      actorCidNumber: actorCidNumber,
      executionAccountId: executionAccountId,
    );
  }

  static OnchainAssetState _decodeState(_ScaleReader reader) {
    return switch (reader.readU8()) {
      0 => const OnchainAssetState.active(),
      1 => const OnchainAssetState.closed(),
      2 => OnchainAssetState.forceClosed(closeBlock: reader.readU32()),
      final value => throw FormatException('未知 AssetState 枚举: $value'),
    };
  }

  static void _ensureAssetId(int assetId) {
    if (assetId < 0 || assetId > 0xFFFFFFFF) {
      throw ArgumentError.value(assetId, 'assetId', '必须在 u32 范围内');
    }
  }
}

class _ScaleReader {
  _ScaleReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  int readU8() {
    _ensureAvailable(1);
    return _bytes[_offset++];
  }

  int readU32() {
    final value = CitizenScale.readUnsigned(_bytes, _offset, 4).toInt();
    _offset += 4;
    return value;
  }

  Uint8List readBytes(int length) {
    if (length < 0) {
      throw const FormatException('SCALE 字节长度不能为负数');
    }
    _ensureAvailable(length);
    final value = Uint8List.fromList(_bytes.sublist(_offset, _offset + length));
    _offset += length;
    return value;
  }

  String readCidNumber() {
    final length = readCompactU32();
    if (length == 0 || length > OnchainAssetScaleCodec._maxCidNumberLength) {
      throw FormatException('actor_cid_number 长度非法: $length');
    }
    final value = readBytes(length);
    try {
      return utf8.decode(value);
    } on FormatException {
      throw const FormatException('actor_cid_number 不是合法 UTF-8');
    }
  }

  int readCompactU32() {
    final (value, width) = CitizenScale.readCompact(_bytes, _offset);
    if (width > 4) {
      throw const FormatException('SCALE Compact 大整数模式不适用于 CID 长度');
    }
    _offset += width;
    return value;
  }

  void ensureFinished(String typeName) {
    if (_offset != _bytes.length) {
      throw FormatException(
        '$typeName SCALE 存在尾随字节: ${_bytes.length - _offset}',
      );
    }
  }

  void _ensureAvailable(int length) {
    if (_offset + length > _bytes.length) {
      throw const FormatException('SCALE 数据被截断');
    }
  }
}

/// 资产查询接口声明；当前没有实现或页面接线，不返回合成资产或余额。
abstract class OnchainAssetQuery {
  /// 列出指定持币人(SS58)持有的所有资产与当前余额关联元数据。
  Future<List<OnchainAssetMeta>> listAssetsHeldBy(String ss58);

  /// 按 asset_id 读取并严格解码 OnchainIssue.AssetMetas元数据。
  Future<OnchainAssetMeta?> readAssetById(int assetId);

  /// 读取特定持币人在某资产下的 raw 余额。
  Future<BigInt> readBalance({required int assetId, required String ss58});
}
