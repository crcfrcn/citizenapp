import 'dart:async';
import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:citizen_sdk/account_codec.dart' show citizenSs58FromAccountId;
import 'package:citizen_system/security/system_protected_storage.dart';
import 'package:citizen_storage/isar_core_bootstrap.dart';

part 'user_isar.g.dart';

/// 行政区字典实体。
///
/// 行政区属于全 App 通用目录，不是用户、广场、聊天或区块链事实。
@Name('region')
@collection
class Region {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('province_code')
  @Index(
    composite: [CompositeIndex('cityCode'), CompositeIndex('townCode')],
    unique: true,
    replace: true,
  )
  late String provinceCode;
  @Name('city_code')
  String cityCode = '';
  @Name('town_code')
  String townCode = '';
  @Name('region_name')
  late String regionName;
}

/// 公权机构公开目录的本机缓存。
///
/// 公开目录、关注关系与机构多签业务记录归统一 UserIsar，按各集合自然键隔离。
@Name('entity')
@collection
class Entity {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('cid_number')
  @Index(unique: true, replace: true)
  late String cidNumber;

  @Name('full_name')
  late String fullName;
  @Name('short_name')
  String? shortName;
  @Name('cid_state')
  late String cidState;

  @Name('province_code')
  @Index()
  late String provinceCode;

  @Name('city_code')
  @Index()
  late String cityCode;

  @Name('town_code')
  String townCode = '';

  @Name('org_code')
  @Index()
  late String orgCode;

  @Name('parent_cid')
  String? parentCid;
  @Name('is_legal')
  bool? isLegal;
  @Name('family_name')
  String? familyName;
  @Name('given_name')
  String? givenName;
  @Name('legal_cid')
  String? legalCid;
  @Name('legal_account')
  String? legalAccount;
  @Name('account_count')
  late int accountCount;
  @Name('account_names')
  List<String> accountNames = const [];
}

/// 通用静态数据版本状态。
@Name('sync')
@collection
class Version {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('data_kind')
  @Index(unique: true, replace: true)
  late String dataKind;

  @Name('global_version')
  String? globalVersion;
  @Name('province_data')
  String? provinceData;
}

/// 公权机构目录的省级顺序。
@Name('catalog')
@collection
class Catalog {
  @Name('id')
  Id rowId = 0;

  @Name('province_codes')
  List<String> provinceCodes = const [];
}

/// 单省公权机构目录同步版本。
@Name('province')
@collection
class Province {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('province_code')
  @Index(unique: true, replace: true)
  late String provinceCode;

  @Name('data_version')
  late String dataVersion;
}

/// 资料修改的跨进程恢复记录，完整字节与请求同事务保存，不保存会话凭据。
@Name('edit')
@collection
class Edit {
  @Name('id')
  Id rowId = Isar.autoIncrement;
  @Name('cid_number')
  @Index(unique: true)
  late String cidNumber;
  @Name('state')
  late String jobState;
  @Name('request')
  late String requestData;
  @Name('response')
  String? responseData;
  @Name('content_hash')
  late String contentHash;
  @Name('avatar_bytes')
  late List<byte> avatarBytes;
  @Name('banner_bytes')
  late List<byte> bannerBytes;
}

/// 按永久 CID 保存的公开资料；持久记录不按时间或数量淘汰。
@Name('profile')
@collection
class Profile {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('cid_number')
  @Index(unique: true, replace: true)
  late String cidNumber;

  @Name('data')
  late String profileData;
}

/// 资料图片本体，与广场媒体分库；CID、用途及准确资料版本共同隔离。
/// 头像和背景上限分别为512KiB和1536KiB，可在一条记录内原子保存完整字节。
@Name('media')
@collection
class ProfileMedia {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('cid_number')
  @Index(
    composite: [CompositeIndex('mediaRole'), CompositeIndex('profileAt')],
    unique: true,
  )
  late String cidNumber;

  @Name('media_role')
  late String mediaRole;
  @Name('object_key')
  late String objectKey;
  @Name('profile_at')
  late int profileAt;
  @Name('body_hash')
  late String bodyHash;
  @Name('media_bytes')
  late List<byte> mediaBytes;
}

/// 身份展示唯一快照；CID 供徽章读取，账户用于恢复完整身份及已验证未注册状态。
///
/// 本行只服务离线展示，不能作为发布、投票或其它授权判断依据。
@Name('identity')
@collection
class Identity {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('cid_number')
  @Index()
  late String cidNumber;

  /// 尚未完整验真的既有徽章没有账户归属，不能作为当前账户的完整身份。
  @Name('account_id')
  @Index()
  String? accountId;

  /// 无账户时只保存徽章级别；完整身份保存原布局，JSON null表示已验真未注册。
  @Name('data')
  String? identityData;

  @Name('updated_at')
  late int updatedAt;
}

/// 通讯录系统保护记录；只保存待同步操作、同步状态和含删除墓碑的联系人记录。
/// CID与状态种类构成自然唯一索引，不保存派生状态键。
@Name('contact')
@collection
class Contact {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('cid_number')
  @Index(composite: [CompositeIndex('stateKind')], unique: true, replace: true)
  late String cidNumber;

  @Name('kind')
  late String stateKind;

  @Name('data')
  late String bodyData;
}

/// 当前CID的通知展示缓存；不承载会话凭据，不作为会员执行许可。
@Name('notice')
@collection
class Notice {
  @Name('id')
  Id rowId = Isar.autoIncrement;
  @Name('cid_number')
  @Index(unique: true, replace: true)
  late String cidNumber;
  @Name('data')
  late String stateData;
  @Name('pending')
  String? pendingData;
}

/// 通用用户设置和 App 展示状态。
///
/// 钱包排序、活动钱包、设备锁和安全失败计数不属于本行。
@Name('setting')
@collection
class Setting {
  @Name('id')
  Id rowId = 0;

  @Name('guide_seen')
  bool guideSeen = false;
  @Name('chat_home')
  bool chatHome = false;
  @Name('council_order')
  List<String> councilOrder = const [];
  @Name('bank_order')
  List<String> bankOrder = const [];
  @Name('square_tab_order')
  List<String> squareTabOrder = const [];
}

/// 按订阅者永久 CID 隔离的公权机构关注关系。
@Name('follow')
@collection
class Follow {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('cid_number')
  @Index(composite: [CompositeIndex('peerCid')], unique: true)
  late String cidNumber;
  @Name('peer_cid')
  late String peerCid;
}

/// 账户余额展示快照；链上交易授权不得使用本行作为真源。
@Name('balance')
@collection
class Balance {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('account_id')
  @Index(unique: true, replace: true)
  late String accountId;

  @Name('data')
  late String bodyData;
}

/// 个人多签账户的本机生命周期与详情快照。
@Name('group')
@collection
class Group {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('account_id')
  @Index(unique: true, replace: true)
  late String accountId;

  @Name('state')
  String? groupState;
  @Name('synced_at')
  int? syncedAt;
  @Name('data')
  String? detailData;
}

/// 当前钱包执行个人多签反向发现的边界快照。
@Name('scan')
@collection
class Scan {
  @Name('id')
  Id rowId = 0;

  @Name('wallet_hash')
  late String walletHash;
}

/// 链上治理提案列表的展示摘要。
@Name('summary')
@collection
class Summary {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('proposal_id')
  @Index(unique: true, replace: true)
  late int proposalId;

  @Name('data')
  late String bodyData;
}

/// 按机构 CID 保存的链上治理提案索引。
@Name('list')
@collection
class ProposalList {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('cid_number')
  @Index(unique: true, replace: true)
  late String cidNumber;

  @Name('proposal_ids')
  List<int> proposalIds = [];
  @Name('synced_at')
  late int syncedAt;
}

/// 链上提案详情展示快照。
@Name('proposal')
@collection
class Proposal {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('kind')
  @Index(composite: [CompositeIndex('proposalId')], unique: true, replace: true)
  late String proposalKind;
  @Name('proposal_id')
  late int proposalId;

  @Name('data')
  late String bodyData;
}

/// 宪法与立法链状态的原始快照。
@Name('law')
@collection
class LawSnapshot {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('state_key')
  @Index(unique: true, replace: true)
  late String stateKey;

  @Name('state_hex')
  late String stateHex;
}

/// 当前设备已激活的链上机构管理员身份集合。
@Name('admin')
@collection
class Admin {
  @Name('id')
  Id rowId = 0;

  @Name('data')
  late String bodyData;
}

/// 不可变交易证明只保存一份；pending_kind只表示尚待镜像的业务，不复制证明数组。
@Name('member')
@collection
class Member {
  @Name('id')
  Id rowId = Isar.autoIncrement;
  @Name('cid_number')
  @Index(composite: [CompositeIndex('stateKind')], unique: true, replace: true)
  late String cidNumber;
  @Name('kind')
  late String stateKind;
  @Name('data')
  late String bodyData;

  static Future<String?> readState(String cidNumber, String stateKind) =>
      UserIsar.instance.read(
        (db) async => (await db.members.getByCidNumberStateKind(
          cidNumber,
          stateKind,
        ))?.bodyData,
      );

  static Future<void> writeState(
    Member row, {
    bool Function()? isCurrent,
    Object? staleError,
  }) => UserIsar.instance.writeTxn((db) async {
    if (isCurrent != null && !isCurrent()) return;
    await db.members.putByCidNumberStateKind(row);
    if (isCurrent != null && !isCurrent()) {
      throw staleError ?? StateError('会员上下文已变化');
    }
  });

  static List<Map<String, dynamic>> _proofs(String? raw) {
    if (raw == null) return [];
    final value = jsonDecode(raw);
    if (value is! List ||
        value.any(
          (row) =>
              row is! Map<String, dynamic> ||
              row['tx_hash'] is! String ||
              (row['tx_hash'] as String).isEmpty,
        )) {
      throw const FormatException('交易证明记录无效');
    }
    return value.cast<Map<String, dynamic>>().toList(growable: true);
  }

  static Future<List<Map<String, dynamic>>> readProofs(
    String cidNumber, {
    String? pendingKind,
  }) async {
    final rows = _proofs(await readState(cidNumber, 'proof'));
    final selected = pendingKind == null && rows.length > 50
        ? rows.skip(rows.length - 50)
        : rows;
    return selected
        .where(
          (row) => pendingKind == null || row['pending_kind'] == pendingKind,
        )
        .map((row) => Map<String, dynamic>.of(row)..remove('pending_kind'))
        .toList(growable: false);
  }

  static void _retainProofs(List<Map<String, dynamic>> rows) {
    final cutoff = rows.length - 50;
    var position = 0;
    rows.removeWhere(
      (row) => position++ < cutoff && row['pending_kind'] == null,
    );
  }

  /// 同一事务提交证明和待镜像状态；保留最近50条历史及所有未完成证明。
  static Future<void> storeProof(
    String cidNumber,
    Map<String, dynamic> proof, {
    String? pendingKind,
    bool replacePending = false,
  }) => UserIsar.instance.writeTxn((db) async {
    if (proof['tx_hash'] is! String ||
        (proof['tx_hash'] as String).isEmpty ||
        proof.containsKey('pending_kind')) {
      throw const FormatException('交易证明无效');
    }
    final row =
        await db.members.getByCidNumberStateKind(cidNumber, 'proof') ??
        (Member()
          ..cidNumber = cidNumber
          ..stateKind = 'proof'
          ..bodyData = '[]');
    final rows = _proofs(row.bodyData);
    if (replacePending) {
      for (final item in rows) {
        if (item['pending_kind'] == pendingKind) item.remove('pending_kind');
      }
    }
    rows.removeWhere((item) => item['tx_hash'] == proof['tx_hash']);
    rows.add({...proof, 'pending_kind': ?pendingKind});
    _retainProofs(rows);
    row.bodyData = jsonEncode(rows);
    await db.members.putByCidNumberStateKind(row);
  });

  static Future<void> finishProof(
    String cidNumber,
    String txHash,
    String pendingKind,
  ) => UserIsar.instance.writeTxn((db) async {
    final row = await db.members.getByCidNumberStateKind(cidNumber, 'proof');
    if (row == null) return;
    final rows = _proofs(row.bodyData);
    for (final proof in rows) {
      if (proof['tx_hash'] == txHash && proof['pending_kind'] == pendingKind) {
        proof.remove('pending_kind');
      }
    }
    _retainProofs(rows);
    row.bodyData = jsonEncode(rows);
    await db.members.put(row);
  });
}

/// 创作者展示快照；待确认计划直接引用member中的唯一交易证明。
@Name('creator')
@collection
class Creator {
  @Name('id')
  Id rowId = Isar.autoIncrement;
  @Name('cid_number')
  @Index(unique: true, replace: true)
  late String cidNumber;
  @Name('data')
  late String bodyData;
}

/// 用户创建的个人多签账户（本地持久化）。
@Name('account')
@collection
class Account {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  /// 个人多签规范 AccountId。
  @Name('account_id')
  @Index(unique: true, replace: true)
  late String accountId;

  /// 个人多签账户名称。
  @Name('account_name')
  late String accountName;

  /// 创建人账户 ID，小写 `0x` 加 64 位十六进制。
  @Name('creator_account')
  late String creatorAccount;

  /// 添加时间戳（毫秒）。
  @Name('added_at')
  @Index()
  late int addedAt;

  /// true = 通过反向索引发现的(钱包账户作为 admin 命中);false = 本机创建/手动添加。
  /// 反向校验只会删除 true 的 entity,false 的永不被自动清理。
  @Name('is_found')
  @Index()
  bool isFound = false;

  /// 本钱包持有的管理员 AccountId 列表(快照,UI 显示"我作为 N 位管理员之一参与")。
  /// 仅在 is_found=true 时填充;false 时空列表。
  @Name('admin_accounts')
  List<String> adminAccounts = const [];
}

/// 个人多签提案历史快照（本地持久化）。
///
/// 链上 votingengine 90 天后清理终态提案 (REJECTED/EXECUTED/EXECUTION_FAILED)，
/// citizenapp 端必须在本地永久保留历史，详情页提案列表才能在历史段始终可见。
///
/// 写入时机:
/// 1. 本机发起提案后(propose_create_personal / propose_transfer / propose_close)
/// 2. 详情页打开时同步链上活跃提案最新状态（upsert）
/// 3. 本机投票后刷新该提案的 status / yes_count / no_count
@Name('action')
@collection
class Action {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  /// 个人多签规范 AccountId；复合索引键之一。
  @Name('account_id')
  @Index(composite: [CompositeIndex('proposalId')], unique: true, replace: true)
  late String accountId;

  /// 链上提案 ID。
  @Name('proposal_id')
  late int proposalId;

  /// 提案动作:'create' / 'transfer' / 'close'。
  @Name('kind')
  @Index()
  late String actionKind;

  /// 提案状态最新快照:'voting' / 'passed' / 'rejected' / 'executed' / 'execution_failed'。
  @Name('state')
  @Index()
  late String proposalState;

  /// 投票计数 yes(每次刷新链上状态时同步)。
  @Name('yes_count')
  late int yesCount;

  /// 投票计数 no。
  @Name('no_count')
  late int noCount;

  /// 提案首次记录时间(本机发起或首次发现)。
  @Name('created_at')
  @Index()
  late int createdAt;

  /// 终态时间:rejected / executed / execution_failed 时写入;voting 期间为 null。
  @Name('final_at')
  int? finalAt;

  /// 业务快照(JSON 字符串):转账金额 / 关闭 beneficiary / 创建账户名等,便于扩展。
  @Name('data')
  String? snapshotData;
}

/// 钱包业务流水进度；与该块的流水在同一事务内提交。
/// 账户导入时间和链身份共同隔离重导入、换链，不能复用另一代账户的进度。
@Name('cursor')
@collection
class WalletCursor {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  @Name('account_id')
  @Index(unique: true, replace: true)
  late String accountId;

  @Name('created_at')
  late int createdAt;
  @Name('genesis_hash')
  late String genesisHash;
  @Name('start_block')
  late int startBlock;

  /// 已完整处理的高度；初始化为 start_block - 1。
  @Name('cursor_block')
  late int cursorBlock;
}

/// 本地钱包余额变化流水（持久化存储，去中心化设计，不依赖 CID 服务器）。
@Name('entry')
@collection
class Entry {
  @Name('id')
  Id rowId = Isar.autoIncrement;

  /// 单条钱包流水唯一键。
  ///
  /// 提交记录以账户/交易哈希定位，事件以账户/区块哈希/事件序号定位。
  /// Isar的id只作本机主键；SDK execution与call hash仍独立约束状态推进。
  /// 所属链账户 ID（小写 `0x` 加 64 位十六进制）。
  @Name('account_id')
  @Index()
  late String accountId;

  /// 业务类型：transfer / fee / reward / interest / issuance / burn / multisig_transfer。
  @Name('kind')
  late String entryKind;

  /// 该钱包实际余额变化（分），带正负号；正数=增加，负数=减少。
  ///
  /// Dart int 在不同平台上不适合承载链上 u128，统一用十进制字符串保存。
  @Name('amount_delta')
  late String amountDelta;

  /// 转账本金（分），不带正负号。
  @Name('transfer_amount')
  String? transferAmount;

  /// 手续费（分），不带正负号；只有本钱包支付手续费时记录。
  @Name('fee_amount')
  String? feeAmount;

  /// 对方地址由真实收发双方和所属账户确定；净额含手续费，不能用正负号猜测。
  @ignore
  String? get peerAddress => fromAddress == citizenSs58FromAccountId(accountId)
      ? toAddress
      : fromAddress;

  @Name('from_address')
  String? fromAddress;
  @Name('to_address')
  String? toAddress;

  /// 转账备注，来自 OnchainTransaction::TransferWithRemark 事件或本机提交草稿。
  @Name('tx_note')
  String? txNote;

  /// 状态(ADR-017)：pending=已提交 / finalized=已确认 / failed=失败；
  /// inBlock 为交易提交 watch 的临时进度态(豁免区)，非 finalized 流水终态。
  @Name('state')
  late String entryState;

  /// 记录来源：local_submit / chain_event / resync。
  @Name('entry_source')
  late String entrySource;

  /// 链上交易哈希。
  @Name('tx_hash')
  String? txHash;

  /// CitizenSDK 为本机提交分配的唯一 execution 标识。
  /// 链上被动收入事件没有 SDK execution，因此为 null。
  @Name('execution_id')
  String? executionId;

  /// CitizenSDK 返回的 opaque RuntimeCall hash，只用于关联业务记录。
  @Name('call_hash')
  String? callHash;

  /// 链上区块号。
  @Name('block_number')
  int? blockNumber;

  /// 链上区块哈希。
  @Name('block_hash')
  String? blockHash;

  /// 区块内事件序号。
  @Name('event_index')
  int? eventIndex;

  /// 事件所属 extrinsic 序号（如果 phase 为 ApplyExtrinsic）。
  @Name('extrinsic_index')
  int? extrinsicIndex;

  /// 本地创建时间（毫秒时间戳）。
  @Name('created_at')
  @Index()
  late int createdAt;

  /// 最终确认时间（毫秒时间戳）。
  @Name('confirmed_at')
  int? confirmedAt;

  /// 失败原因。
  @Name('fail_reason')
  String? failReason;
}

enum _UserIsarLifecycle { active, closing, closed }

/// 数据库打开期间收到关闭请求时使用的内部终止信号。
class _UserOpeningCancelled implements Exception {
  const _UserOpeningCancelled([this.cleanupError]);

  final Object? cleanupError;
}

/// 资源 Zone 内的数据库打开结果。
///
/// 物理打开必须脱离页面 fake-async Zone，但 Dart 不允许错误跨 error Zone 直接转交；
/// 因此资源任务只返回不会失败的结果对象，再由每个业务调用方在自己的 Zone 内重抛。
class _UserOpeningOutcome {
  const _UserOpeningOutcome._({
    required this.generation,
    required this.opened,
    required this.error,
    required this.stackTrace,
  });

  factory _UserOpeningOutcome.success({
    required int generation,
    required Isar opened,
  }) {
    return _UserOpeningOutcome._(
      generation: generation,
      opened: opened,
      error: null,
      stackTrace: null,
    );
  }

  factory _UserOpeningOutcome.failure({
    required int generation,
    required Object error,
    required StackTrace stackTrace,
  }) {
    return _UserOpeningOutcome._(
      generation: generation,
      opened: null,
      error: error,
      stackTrace: stackTrace,
    );
  }

  final int generation;
  final Isar? opened;
  final Object? error;
  final StackTrace? stackTrace;
}

/// 统一用户数据库外部消费者的生命周期凭证。
///
/// Isar watcher 不经过 [UserIsar] 的读写队列，却会持续持有数据库句柄。消费者
/// 必须在创建任何异步数据库工作前同步登记本凭证，并且只在真实取消完成后释放；这样
/// 应用锁擦除才能先等待 watcher 退出，再关闭和删除数据库。
class IsarConsumerLease {
  IsarConsumerLease._(this._owner, this._id);

  final UserIsar _owner;
  final int _id;
  bool _released = false;

  /// 仅在消费者的取消 Future 已成功完成后调用；重复释放是幂等操作。
  void release() {
    if (_released) return;
    _owner._releaseConsumerLease(this);
    _released = true;
  }
}

class _IsarConsumerRegistration {
  _IsarConsumerRegistration({required this.lease, required this.cancel});

  final IsarConsumerLease lease;
  final Future<void> Function() cancel;
  Future<void>? _cancelInFlight;

  /// 同一消费者的并发取消请求共用一次调用；失败后保留登记并允许下一次擦除重试。
  Future<void> cancelSingleFlight() {
    final inFlight = _cancelInFlight;
    if (inFlight != null) return inFlight;

    late final Future<void> task;
    task = Future<void>.sync(cancel).whenComplete(() {
      if (identical(_cancelInFlight, task)) {
        _cancelInFlight = null;
      }
    });
    _cancelInFlight = task;
    return task;
  }
}

/// App 的统一用户业务数据库。
///
/// 公共目录、资料、设置、关注、交易、多签和提案共用唯一文件、schema 与生命周期。
/// 事务内只做本库操作；网络、SDK、密码学和文件处理必须先在事务外完成。
/// Social 与 Chat 保持各自独立的数据库与生命周期。
class UserIsar {
  UserIsar._();

  static final UserIsar instance = UserIsar._();

  static final Object _operationZoneKey = Object();

  Isar? _isar;
  Future<_UserOpeningOutcome>? _opening;
  Future<bool>? _deleteInFlight;
  Future<void>? _closing;
  Future<void> _operationTail = Future<void>.value();
  bool _operationActive = false;
  _UserIsarLifecycle _lifecycle = _UserIsarLifecycle.active;
  int _generation = 0;
  int _nextConsumerLeaseId = 0;
  final Map<int, _IsarConsumerRegistration> _consumerRegistrations =
      <int, _IsarConsumerRegistration>{};

  static const Duration _gracefulDrainTimeout = Duration(milliseconds: 250);
  static const Duration _consumerDrainTimeout = Duration(seconds: 2);
  static const Duration _openingSettleTimeout = Duration(seconds: 2);
  static const Duration _forcedDeleteTimeout = Duration(seconds: 2);

  static const List<Duration> _busyRetryDelays = [
    Duration(milliseconds: 80),
    Duration(milliseconds: 160),
    Duration(milliseconds: 320),
    Duration(milliseconds: 640),
    Duration(milliseconds: 1200),
    Duration(milliseconds: 2400),
    Duration(milliseconds: 3600),
    Duration(milliseconds: 5000),
  ];

  /// 统一用户库的唯一 schema 清单；正常打开与终态擦除必须使用同一真源。
  static const List<CollectionSchema<dynamic>> _schemas =
      <CollectionSchema<dynamic>>[
        RegionSchema,
        EntitySchema,
        VersionSchema,
        CatalogSchema,
        ProvinceSchema,
        ProfileSchema,
        EditSchema,
        ProfileMediaSchema,
        IdentitySchema,
        ContactSchema,
        NoticeSchema,
        SettingSchema,
        FollowSchema,
        BalanceSchema,
        GroupSchema,
        ScanSchema,
        SummarySchema,
        ProposalListSchema,
        ProposalSchema,
        LawSnapshotSchema,
        AdminSchema,
        MemberSchema,
        CreatorSchema,
        AccountSchema,
        ActionSchema,
        EntrySchema,
        WalletCursorSchema,
      ];

  /// 给低优先级后台任务判断是否让路；前台读写仍应直接排队执行。
  bool get hasActiveOperation => _operationActive;

  /// 业务调度层用它识别 MDBX 短暂繁忙，并选择跳过低优先级后台任务。
  bool isBusyError(Object error) => _isBusyError(error);

  /// 同步登记一个会跨越普通读写调用、持续持有 统一用户数据库的消费者。
  ///
  /// 调用方必须先取得 lease，再开始 `db()`、创建 watcher 或其它异步工作。关闭意图
  /// 一旦生效，本方法和 [db] 会同时拒绝新工作。传入的取消函数必须是幂等且可等待的，
  /// 并且只能在底层资源真实释放后完成。
  IsarConsumerLease registerExternalConsumer(Future<void> Function() cancel) {
    _ensureActive();
    final lease = IsarConsumerLease._(this, _nextConsumerLeaseId++);
    _consumerRegistrations[lease._id] = _IsarConsumerRegistration(
      lease: lease,
      cancel: cancel,
    );
    return lease;
  }

  void _releaseConsumerLease(IsarConsumerLease lease) {
    final registration = _consumerRegistrations[lease._id];
    if (registration == null) return;
    if (!identical(registration.lease, lease)) {
      throw StateError('UserIsar 消费者 lease 归属不一致，拒绝释放。');
    }
    _consumerRegistrations.remove(lease._id);
  }

  /// 读取用户选择的 App 首页；缺省值固定为广场，不从其它存储推断。
  Future<bool> readOpenChatOnLaunch() {
    return read((isar) async {
      final settings = await isar.settings.get(0);
      return settings?.chatHome ?? false;
    });
  }

  /// 原子保存首页选择；本偏好只属于 UserIsar，不进入平台安全存储。
  Future<void> writeOpenChatOnLaunch(bool value) {
    return writeTxn((isar) async {
      final settings = await isar.settings.get(0) ?? Setting();
      settings
        ..rowId = 0
        ..chatHome = value;
      await isar.settings.put(settings);
    });
  }

  Future<Isar> db() async {
    _ensureActive();

    final current = _isar;
    if (current != null && current.isOpen) {
      return current;
    }

    final opening = _opening;
    if (opening != null) {
      return _resolveOpening(opening);
    }

    final generation = _generation;
    // 数据库句柄是进程级资源，物理打开/取消清理不能依附页面的 fake-async 或
    // 临时 Zone；否则页面已销毁时 close 看到 `_opening`，却永远等不到该 Zone 恢复。
    // 这里只把资源生命周期任务放到 root，业务 read/write 回调仍留在调用方 Zone，
    // 因而不改变业务异常传播与 UserIsar 串行队列语义。
    final task = Zone.root.run(() async {
      try {
        return _UserOpeningOutcome.success(
          generation: generation,
          opened: await _openForGeneration(generation),
        );
      } catch (error, stackTrace) {
        // 在资源所属 root Zone 内消费错误，禁止旧代取消成为 root unhandled；
        // 业务调用仍会由 [_resolveOpening] 在原调用 Zone 收到同一错误与堆栈。
        return _UserOpeningOutcome.failure(
          generation: generation,
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
    _opening = task;
    try {
      return await _resolveOpening(task);
    } finally {
      if (identical(_opening, task)) {
        _opening = null;
      }
    }
  }

  Future<Isar> _resolveOpening(Future<_UserOpeningOutcome> task) async {
    final outcome = await task;
    final error = outcome.error;
    if (error != null) {
      Error.throwWithStackTrace(error, outcome.stackTrace!);
    }
    if (_lifecycle != _UserIsarLifecycle.active ||
        outcome.generation != _generation) {
      throw const _UserOpeningCancelled();
    }

    final opened = outcome.opened!;
    _isar = opened;
    return opened;
  }

  /// 低端 Android 的 MDBX 在读写窗口重叠时可能短暂返回 EAGAIN。
  /// 对这类 busy 错误做小间隔重试，避免交易流水同步或余额刷新把瞬时竞争暴露给 UI。
  Future<T> runWithBusyRetry<T>(Future<T> Function() action) async {
    for (var attempt = 0; attempt <= _busyRetryDelays.length; attempt++) {
      try {
        return await action();
      } catch (error) {
        if (!_isBusyError(error) || attempt == _busyRetryDelays.length) {
          rethrow;
        }
        await Future<void>.delayed(_busyRetryDelays[attempt]);
      }
    }
    throw StateError('unreachable');
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    if (identical(Zone.current[_operationZoneKey], this)) {
      throw StateError('禁止在 UserIsar 操作回调内再次进入 UserIsar；请先返回快照，再执行后续工作。');
    }

    _ensureActive();

    final generation = _generation;
    final previous = _operationTail;
    final completer = Completer<T>();
    _operationTail = completer.future.then<void>((_) {}, onError: (_) {});

    () async {
      try {
        await previous.catchError((_) {});
        if (_lifecycle != _UserIsarLifecycle.active ||
            generation != _generation) {
          throw StateError('UserIsar 已关闭，禁止继续执行或重新打开数据库。');
        }
        _operationActive = true;
        final result = await runZoned(
          () => runWithBusyRetry(action),
          zoneValues: <Object?, Object?>{_operationZoneKey: this},
        );
        if (_lifecycle != _UserIsarLifecycle.active ||
            generation != _generation) {
          throw StateError('UserIsar 已关闭，旧操作结果已取消。');
        }
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        if (generation == _generation) {
          _operationActive = false;
        }
      }
    }();

    return completer.future;
  }

  Future<T> read<T>(Future<T> Function(Isar isar) action) {
    return _enqueue(() async {
      final isar = await db();
      if (!IsarCoreBootstrap.isFlutterTest) {
        await SystemProtectedStorage.protectUserDatabase(
          await IsarCoreBootstrap.resolveDirectory(),
        );
      }
      return action(isar);
    });
  }

  bool _isBusyError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('mdbxerror (11)') ||
        raw.contains('try again') ||
        raw.contains('active transaction');
  }

  void _ensureActive() {
    if (_lifecycle != _UserIsarLifecycle.active) {
      throw StateError('UserIsar 已关闭，禁止继续执行或重新打开数据库。');
    }
  }

  Future<Isar> _openForGeneration(int generation) async {
    final opened = await _openDatabase();
    if (_lifecycle == _UserIsarLifecycle.active && generation == _generation) {
      return opened;
    }

    try {
      final deleted = await _deleteInstance(opened)
          .timeout(_forcedDeleteTimeout);
      if (!deleted) {
        throw StateError('统一用户数据库仍被其它实例持有，未实际关闭并删除。');
      }
      throw const _UserOpeningCancelled();
    } catch (error) {
      if (error is _UserOpeningCancelled) rethrow;
      throw _UserOpeningCancelled(error);
    }
  }

  Future<bool> _deleteInstance(Isar isar) {
    final deleting = _deleteInFlight;
    if (deleting != null) return deleting;
    if (!isar.isOpen) return Future<bool>.value(true);

    final task = isar.close(deleteFromDisk: true);
    _deleteInFlight = task;
    task.then<void>(
      (_) {
        if (identical(_deleteInFlight, task)) _deleteInFlight = null;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_deleteInFlight, task)) _deleteInFlight = null;
      },
    );
    return task;
  }

  /// UserIsar 所属集合共用的域内写事务入口。
  ///
  /// Android 低端机上交易流水同步、余额刷新、多签扫描和钱包导入可能同时读写库，
  /// MDBX 会返回 `MdbxError(11): Try again`。本数据库所属业务统一排队到这里；
  /// Chat 使用独立 ChatIsar，禁止接入本队列。
  Future<T> writeTxn<T>(Future<T> Function(Isar isar) action) {
    return _enqueue(() async {
      final isar = await db();
      final directory = await IsarCoreBootstrap.resolveDirectory();
      if (!IsarCoreBootstrap.isFlutterTest) {
        await SystemProtectedStorage.protectUserDatabase(directory);
      }
      final result = await isar.writeTxn<T>(() => action(isar));
      if (!IsarCoreBootstrap.isFlutterTest) {
        await SystemProtectedStorage.protectUserDatabase(directory);
      }
      return result;
    });
  }

  Future<Isar> _openDatabase() async {
    await IsarCoreBootstrap.ensureTestCoreInitialized();

    // 同名实例已经打开时直接复用；目标 schema 不做运行时兼容或业务 KV 扫描。
    final existing = Isar.getInstance('citizenapp_user');
    if (existing != null && existing.isOpen) {
      return _prepareOpened(existing);
    }

    return _openDatabaseFile();
  }

  /// 只打开 统一用户数据库文件。
  ///
  /// 全量擦除时即使本进程从未打开过钱包库，也必须取得磁盘句柄并验证真实删除；禁止
  /// 因“没有内存实例”就把仍存在的上一进程数据库误报为已清空。
  Future<Isar> _openDatabaseFile() async {
    await IsarCoreBootstrap.ensureTestCoreInitialized();
    final directory = await IsarCoreBootstrap.resolveDirectory();
    if (!IsarCoreBootstrap.isFlutterTest) {
      await SystemProtectedStorage.protectUserDatabase(directory);
    }
    final opened = Isar.openSync(
      _schemas,
      name: 'citizenapp_user',
      directory: directory,
      relaxedDurability: false,
    );
    try {
      return await _prepareOpened(opened);
    } catch (_) {
      await opened.close();
      rethrow;
    }
  }

  Future<Isar> _prepareOpened(Isar isar) async {
    if (!IsarCoreBootstrap.isFlutterTest) {
      await SystemProtectedStorage.protectUserDatabase(
        await IsarCoreBootstrap.resolveDirectory(),
      );
    }
    return isar;
  }

  Future<void> resetForTest() async {
    if (!IsarCoreBootstrap.isFlutterTest) {
      return;
    }

    // 必须先完成同一套有界关闭；失败时保持终态，禁止带着晚到的打开任务复活测试库。
    await closeAndDeleteFromDisk();
    if (_consumerRegistrations.isNotEmpty) {
      throw StateError('UserIsar 测试复位时仍有未释放的外部消费者。');
    }
    _isar = null;
    _opening = null;
    _deleteInFlight = null;
    _closing = null;
    _operationTail = Future<void>.value();
    _operationActive = false;
    _generation += 1;
    _lifecycle = _UserIsarLifecycle.active;
  }

  /// 应用锁触发清空数据时使用。
  ///
  /// 关闭意图在本方法返回 Future 前同步生效；此前已排队但尚未开始的操作会拒绝执行。
  /// 活动操作只获得短暂排空窗口，之后直接关闭数据库，避免永久挂起阻塞全 App 擦除。
  Future<void> closeAndDeleteFromDisk() {
    final inFlight = _closing;
    if (_lifecycle == _UserIsarLifecycle.closing && inFlight != null) {
      return inFlight;
    }

    _lifecycle = _UserIsarLifecycle.closing;
    _generation += 1;
    late final Future<void> task;
    task = _closeAndDeleteInternal().whenComplete(() {
      _lifecycle = _UserIsarLifecycle.closed;
      if (identical(_closing, task)) _closing = null;
    });
    _closing = task;
    return task;
  }

  Future<void> _closeAndDeleteInternal() async {
    final failures = <String>[];
    await _drainExternalConsumers(failures);

    final tailAtClose = _operationTail;
    var deleteWasAttempted = false;

    try {
      await tailAtClose.timeout(_gracefulDrainTimeout);
    } on TimeoutException {
      // 活动回调可能永久等待外部资源；超时后继续强制关闭本数据库。
    } catch (error) {
      failures.add('等待 用户库操作队列失败：$error');
    }

    final openingAtClose = _opening;
    if (openingAtClose != null) {
      try {
        final outcome = await openingAtClose.timeout(_openingSettleTimeout);
        final error = outcome.error;
        if (error is _UserOpeningCancelled) {
          if (error.cleanupError != null) {
            failures.add('取消 统一用户数据库打开后的删除失败：${error.cleanupError}');
          }
        } else if (error != null) {
          failures.add('等待 统一用户数据库打开任务失败：$error');
        }
      } catch (error) {
        failures.add('等待 统一用户数据库打开任务失败：$error');
      }
    }

    final candidates = <Isar>[];
    final tracked = _isar;
    final registered = Isar.getInstance('citizenapp_user');
    if (tracked != null) candidates.add(tracked);
    if (registered != null && !identical(registered, tracked)) {
      candidates.add(registered);
    }
    for (final candidate in candidates) {
      if (!candidate.isOpen) continue;
      deleteWasAttempted = true;
      try {
        final deleted = await _deleteInstance(candidate)
            .timeout(_forcedDeleteTimeout);
        if (!deleted) {
          failures.add('统一用户数据库仍被其它实例持有，未实际关闭并删除。');
        }
      } catch (error) {
        failures.add('强制删除 统一用户数据库失败：$error');
      }
    }

    final deleting = _deleteInFlight;
    if (deleting != null) {
      deleteWasAttempted = true;
      try {
        final deleted = await deleting.timeout(_forcedDeleteTimeout);
        if (!deleted) {
          failures.add('统一用户数据库仍被其它实例持有，删除没有落盘。');
        }
      } catch (error) {
        failures.add('等待 统一用户数据库删除落盘失败：$error');
      }
    }

    if (!deleteWasAttempted) {
      try {
        // 上一进程留下的冷库在本进程没有注册实例；仍须真实打开后删除。
        final coldDatabase = await _openDatabaseFile().timeout(
          _openingSettleTimeout,
        );
        final deleted = await coldDatabase
            .close(deleteFromDisk: true)
            .timeout(_forcedDeleteTimeout);
        if (!deleted) {
          failures.add('用户冷数据库仍被其它实例持有，删除没有落盘。');
        }
      } catch (error) {
        failures.add('打开并删除 用户冷数据库失败：$error');
      }
    }

    if ((_isar?.isOpen ?? false) == false) _isar = null;
    if (failures.isNotEmpty) {
      throw StateError(failures.join('\n'));
    }
  }

  Future<void> _drainExternalConsumers(List<String> failures) async {
    final registrations = _consumerRegistrations.values.toList(growable: false);
    await Future.wait<void>(
      registrations.map((registration) async {
        try {
          await registration.cancelSingleFlight().timeout(
            _consumerDrainTimeout,
          );
        } on TimeoutException {
          failures.add('等待 用户库外部消费者取消超时：lease=${registration.lease._id}');
        } catch (error) {
          failures.add('取消 用户库外部消费者失败：lease=${registration.lease._id}，$error');
        }
      }),
    );

    if (_consumerRegistrations.isNotEmpty) {
      final remainingIds = _consumerRegistrations.keys.toList()..sort();
      failures.add('用户库外部消费者尚未真实释放：lease=$remainingIds');
    }
  }
}
