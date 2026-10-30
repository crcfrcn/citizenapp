import 'package:citizen_system/security/account_security_exception.dart';
import 'package:citizen_storage/user_isar.dart' as user_store show Contact;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:polkadart_keyring/polkadart_keyring.dart' show Keyring;

import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_citizen/account_derivation.dart';
import 'package:citizen_account/identity/current_user_context.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:citizen_account/identity/account_security_service.dart';

/// 通讯录唯一业务模型。
///
/// `cid_number` 是联系人关系的永久主键；`account_id` / `ss58_address` 是该 CID
/// 当前绑定的签名账户与展示地址，换绑后允许更新。公开昵称、头像和签名属于用户公开
/// 资料，不复制进通讯录；`contact_remark` 只保存当前用户自己的私人备注。
class UserContact {
  const UserContact({
    required this.cidNumber,
    required this.accountId,
    required this.accountAddress,
    required this.contactRemark,
    required this.createdAt,
    required this.updatedAt,
  });

  final String cidNumber;
  final String accountId;
  final String accountAddress;
  final String contactRemark;
  final int createdAt;
  final int updatedAt;

  UserContact copyWith({
    String? cidNumber,
    String? accountId,
    String? accountAddress,
    String? contactRemark,
    int? createdAt,
    int? updatedAt,
  }) {
    return UserContact(
      cidNumber: cidNumber ?? this.cidNumber,
      accountId: accountId ?? this.accountId,
      accountAddress: accountAddress ?? this.accountAddress,
      contactRemark: contactRemark ?? this.contactRemark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cid_number': cidNumber,
    'account_id': accountId,
    'ss58_address': accountAddress,
    'contact_remark': contactRemark,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory UserContact.fromJson(Map<String, dynamic> json) {
    if (json.length != 6 ||
        json['cid_number'] is! String ||
        json['account_id'] is! String ||
        json['ss58_address'] is! String ||
        json['created_at'] is! int ||
        json['updated_at'] is! int) {
      throw const FormatException('通讯录字段或类型无效');
    }
    final cidNumber = UserContactService.requireCidNumber(
      json['cid_number'] as String,
    );
    final accountId = json['account_id']?.toString() ?? '';
    final accountAddress = json['ss58_address']?.toString().trim() ?? '';
    final contactRemark = json['contact_remark'];
    if (!isAccountIdText(accountId) ||
        accountAddress.isEmpty ||
        contactRemark is! String) {
      throw const FormatException('通讯录 CID、账户、地址或私人备注不合法');
    }
    if (UserContactService.accountIdFromSs58(accountAddress) != accountId) {
      throw const FormatException('通讯录 account_id 与 ss58_address 不匹配');
    }
    final createdAt = json['created_at'] as int;
    final updatedAt = json['updated_at'] as int;
    if (createdAt <= 0 || updatedAt <= 0) {
      throw const FormatException('通讯录时间戳不合法');
    }
    final normalizedRemark = UserContactService.normalizeContactRemark(
      contactRemark,
    );
    return UserContact(
      cidNumber: cidNumber,
      accountId: accountId,
      accountAddress: UserContactService.normalizeSs58Address(accountAddress),
      contactRemark: normalizedRemark,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class ContactImportResult {
  const ContactImportResult({required this.contact, required this.created});

  final UserContact contact;
  final bool created;
}

enum ContactSyncPhase { idle, syncing, synced, pending, offline, failed }

class ContactSyncState {
  const ContactSyncState({
    required this.phase,
    this.updatedAt = 0,
    this.message,
    this.errorCode,
    this.statusCode,
    this.stage,
  });

  final ContactSyncPhase phase;
  final int updatedAt;
  final String? message;
  final String? errorCode;
  final int? statusCode;
  final SquareApiStage? stage;

  String get label => switch (phase) {
    ContactSyncPhase.syncing => '正在同步',
    ContactSyncPhase.synced => '云端已同步',
    ContactSyncPhase.pending => '待同步',
    ContactSyncPhase.offline => '离线，显示本地通讯录',
    ContactSyncPhase.failed => '同步失败，点击重试',
    ContactSyncPhase.idle => '本地通讯录',
  };
}

/// 本地优先通讯录；本地由系统保护，云端只传同 CID 的真实 MLS 消息。
class UserContactService {
  UserContactService({
    required AccountSecurityService accountSecurity,
    required CurrentUserContext currentUserContext,
    required SquareSessionProvider sessionProvider,
    SquareApiClient? apiClient,
    bool autoSync = true,
  }) : _accountSecurity = accountSecurity,
       _sessionProvider = sessionProvider,
       _apiClient = apiClient ?? SquareApiClient(),
       _currentUserContext = currentUserContext,
       _autoSync = autoSync;

  final AccountSecurityService _accountSecurity;
  final SquareSessionProvider _sessionProvider;
  final SquareApiClient _apiClient;
  final CurrentUserContext _currentUserContext;
  final bool _autoSync;
  static final _syncFlights = <String, Future<List<UserContact>>>{};

  /// 通讯录永久归属 CID；当前绑定账户只参与公开授权代次和云会话鉴权。
  CurrentUserContext get _currentUser => _currentUserContext;

  final ValueNotifier<ContactSyncState> syncState =
      ValueNotifier<ContactSyncState>(
        const ContactSyncState(phase: ContactSyncPhase.idle),
      );

  /// 通讯录只属于当前 CID 身份，调用方不得用交易付款钱包覆盖其身份账户。
  Future<List<UserContact>> getContacts() async {
    final owner = await _requireIdentityOwner();
    return _getContacts(owner);
  }

  Future<List<UserContact>> _getContacts(_ContactOwner owner) async {
    return await _readContacts(owner);
  }

  /// 扫码导入使用服务端身份投影核对名片；联系人浏览和同步没有链读取依赖。
  Future<ContactImportResult> importContact({
    required String cidNumber,
    required String accountId,
  }) async {
    final owner = await _requireIdentityOwner();
    final session = await _sessionProvider.ensureSession();
    if (session == null || session.cidNumber != owner.cidNumber) {
      throw StateError('通讯录会话不可用');
    }
    final profile = await _apiClient.fetchUserCard(
      cidNumber: requireCidNumber(cidNumber),
      session: session,
    );
    if (profile.cidNumber != cidNumber ||
        profile.accountId != requireAccountId(accountId)) {
      throw const FormatException('用户码与服务端当前绑定不一致');
    }
    return _addContact(
      owner,
      cidNumber: cidNumber,
      accountAddress: ss58FromAccountIdText(profile.accountId),
      contactRemark: '',
    );
  }

  /// 返回通讯录当前所属的身份账户，供扫码页做“不能添加自己”校验。
  Future<String> getAccountId() async =>
      (await _requireIdentityOwner()).accountId;

  Future<ContactImportResult> addContact({
    required String cidNumber,
    required String accountAddress,
    required String contactRemark,
  }) async {
    final owner = await _requireIdentityOwner();
    return _addContact(
      owner,
      cidNumber: cidNumber,
      accountAddress: accountAddress,
      contactRemark: contactRemark,
    );
  }

  /// 导入与手动添加共用同一属主；所有等待之后仍核对原账户修订。
  Future<ContactImportResult> _addContact(
    _ContactOwner owner, {
    required String cidNumber,
    required String accountAddress,
    required String contactRemark,
  }) async {
    await _assertOwner(owner);
    final normalizedCidNumber = requireCidNumber(cidNumber);
    final normalizedSs58Address = normalizeSs58Address(accountAddress);
    final contactAccountId = accountIdFromSs58(normalizedSs58Address);
    final normalizedRemark = normalizeContactRemark(contactRemark);
    if (normalizedCidNumber == owner.cidNumber ||
        contactAccountId == owner.accountId) {
      throw const FormatException('不能把自己加入通讯录');
    }

    final contacts = (await _readContacts(owner)).toList(growable: true);
    final index = contacts.indexWhere(
      (item) => item.cidNumber == normalizedCidNumber,
    );
    final created = index < 0;
    final now = _nextTimestamp(created ? 0 : contacts[index].updatedAt);
    final contact = created
        ? UserContact(
            cidNumber: normalizedCidNumber,
            accountId: contactAccountId,
            accountAddress: normalizedSs58Address,
            contactRemark: normalizedRemark,
            createdAt: now,
            updatedAt: now,
          )
        : contacts[index].copyWith(
            accountId: contactAccountId,
            accountAddress: normalizedSs58Address,
            // 扫码得到的空备注不得抹掉用户已经填写的私人备注。
            contactRemark: normalizedRemark.isEmpty
                ? contacts[index].contactRemark
                : normalizedRemark,
            updatedAt: now,
          );
    if (created) {
      contacts.add(contact);
    } else {
      contacts[index] = contact;
    }
    await _writeContactsAndPending(
      owner,
      contacts,
      _PendingContactOp.upsert(contact.cidNumber, contact.updatedAt),
    );
    if (_autoSync) {
      unawaited(_syncOwner(owner));
    }
    return ContactImportResult(contact: contact, created: created);
  }

  Future<List<UserContact>> renameContact(
    String contactCidNumber,
    String contactRemark,
  ) async {
    final owner = await _requireIdentityOwner();
    final normalizedContactCidNumber = requireCidNumber(contactCidNumber);
    final normalizedRemark = normalizeContactRemark(contactRemark);
    final contacts = (await _getContacts(owner)).toList(growable: true);
    final index = contacts.indexWhere(
      (item) => item.cidNumber == normalizedContactCidNumber,
    );
    if (index < 0) {
      throw Exception('未找到联系人');
    }
    contacts[index] = contacts[index].copyWith(
      contactRemark: normalizedRemark,
      updatedAt: _nextTimestamp(contacts[index].updatedAt),
    );
    await _writeContactsAndPending(
      owner,
      contacts,
      _PendingContactOp.upsert(
        contacts[index].cidNumber,
        contacts[index].updatedAt,
      ),
    );
    if (_autoSync) {
      unawaited(_syncOwner(owner));
    }
    return _sorted(contacts);
  }

  Future<List<UserContact>> deleteContact(String contactCidNumber) async {
    final owner = await _requireIdentityOwner();
    final normalizedContactCidNumber = requireCidNumber(contactCidNumber);
    final contacts = (await _getContacts(owner))
        .where((item) => item.cidNumber != normalizedContactCidNumber)
        .toList(growable: false);
    await _writeContactsAndPending(
      owner,
      contacts,
      _PendingContactOp.delete(normalizedContactCidNumber, _nextTimestamp()),
    );
    if (_autoSync) {
      unawaited(_syncOwner(owner));
    }
    return _sorted(contacts);
  }

  /// 使用当前 CID 的持久 MLS 身份同步；先应用组消息，再发送本机快照。
  /// 损坏记录、其他 CID 或失效绑定必须拒绝，待同步操作只在精确确认后删除。
  Future<List<UserContact>> sync() async {
    return _syncOwner(await _requireIdentityOwner());
  }

  Future<List<UserContact>> _syncOwner(_ContactOwner owner) async {
    if (_syncFlights.containsKey(owner.cidNumber)) {
      return _syncFlights[owner.cidNumber]!;
    }
    final task = _performSync(owner);
    _syncFlights[owner.cidNumber] = task;
    try {
      return await task;
    } finally {
      if (identical(_syncFlights[owner.cidNumber], task)) {
        _syncFlights.remove(owner.cidNumber);
      }
    }
  }

  Future<List<UserContact>> _performSync(_ContactOwner owner) async {
    await _setSyncState(owner, ContactSyncPhase.syncing);
    try {
      final session = await _sessionProvider.ensureSession();
      if (session == null ||
          session.accountId != owner.accountId ||
          session.cidNumber != owner.cidNumber ||
          session.bindRev != owner.bindRev) {
        throw const SquareApiException('通讯录同步需要当前 CID 的精确 MLS 会话');
      }
      final sent = await _sessionProvider.mlsRuntime.synchronizeContacts(
        exchange: (request) =>
            _apiClient.exchangeContactMls(session: session, request: request),
        snapshots: () => _contactSnapshots(owner),
        apply: (payload) => _applyContactSnapshot(owner, payload),
      );
      for (final payload in sent) {
        final records = _decodeRecords(owner, payload);
        for (final record in records) {
          final pending = await _readPending(owner);
          for (final operation in pending) {
            if (operation.cidNumber == record['cid_number'] &&
                operation.updatedAt == record['updated_at'] &&
                ((operation.action == _PendingAction.delete) ==
                    (record['contact'] == null))) {
              await _removePending(owner, operation);
            }
          }
        }
      }
      await _setSyncState(owner, ContactSyncPhase.synced);
      return await _readContacts(owner);
    } catch (error) {
      await _assertOwner(owner);
      final failure = SquareSessionResolution.fromError(error);
      await _setSyncState(
        owner,
        failure.status == SquareSessionStatus.networkUnavailable
            ? ContactSyncPhase.offline
            : ContactSyncPhase.failed,
        // 唯一会话入口自动准备MLS；目录/已提交状态故障沿固定分类显示，保留联系人及待发项。
        // 不自动换钥、不以重试清空记录，也不持久化原始异常正文。
        message: failure.message,
        errorCode: failure.errorCode,
        statusCode: failure.statusCode,
        stage: failure.stage,
      );
      return await _readContacts(owner);
    }
  }

  Future<void> _assertOwner(_ContactOwner owner) async {
    if (owner.accountRevision != _accountSecurity.revision.value) {
      throw const AccountSecurityException('通讯录账户修订已变化');
    }
    final current = await _currentUser.resolve();
    final binding = await _accountSecurity.readIdentityBindingForCid(
      owner.cidNumber,
    );
    if (owner.accountRevision != _accountSecurity.revision.value ||
        binding == null ||
        binding.bindRev != owner.bindRev ||
        binding.accountId != owner.accountId) {
      throw const AccountSecurityException('通讯录公开绑定已变化');
    }
    if (current == null ||
        !current.isRegistered ||
        current.cidNumber != owner.cidNumber ||
        current.accountId != owner.accountId ||
        current.bindRev != owner.bindRev) {
      throw const AccountSecurityException('通讯录当前身份已变化');
    }
  }

  Future<List<List<int>>> _contactSnapshots(_ContactOwner owner) async {
    await _assertOwner(owner);
    final raw = await _readState(owner, 'records');
    final records = _recordMap(raw).values.toList()
      ..sort(
        (a, b) =>
            (a['cid_number'] as String).compareTo(b['cid_number'] as String),
      );
    final payloads = <List<int>>[];
    for (
      var index = 0;
      index < records.length || (records.isEmpty && index == 0);
      index += 50
    ) {
      final payload = utf8.encode(
        jsonEncode({
          'type': 'contacts',
          'owner_cid_number': owner.cidNumber,
          'records': records.skip(index).take(50).toList(),
        }),
      );
      if (payload.length > 32 * 1024) throw const FormatException('通讯录同步批次超限');
      payloads.add(payload);
      if (records.isEmpty) break;
    }
    return payloads;
  }

  List<Map<String, dynamic>> _decodeRecords(
    _ContactOwner owner,
    List<int> payload,
  ) {
    final value = jsonDecode(utf8.decode(payload));
    if (value is! Map<String, dynamic> ||
        value.length != 3 ||
        value['type'] != 'contacts' ||
        value['owner_cid_number'] != owner.cidNumber ||
        value['records'] is! List ||
        (value['records'] as List).length > 50) {
      throw const FormatException('通讯录 MLS 载荷无效');
    }
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final item in value['records'] as List) {
      if (item is! Map<String, dynamic> ||
          item.length != 3 ||
          item['cid_number'] is! String ||
          item['updated_at'] is! int ||
          (item['updated_at'] as int) <= 0 ||
          !item.containsKey('contact')) {
        throw const FormatException('通讯录 MLS 记录无效');
      }
      final cid = requireCidNumber(item['cid_number'] as String);
      if (cid == owner.cidNumber || !seen.add(cid)) {
        throw const FormatException('通讯录 MLS 联系人重复或为自身');
      }
      final contact = item['contact'];
      if (contact != null) {
        if (contact is! Map<String, dynamic>) {
          throw const FormatException('通讯录 MLS 联系人无效');
        }
        final parsed = UserContact.fromJson(contact);
        if (parsed.cidNumber != cid || parsed.updatedAt != item['updated_at']) {
          throw const FormatException('通讯录 MLS 联系人标识不一致');
        }
      }
      result.add({
        'cid_number': cid,
        'updated_at': item['updated_at'],
        'contact': contact == null
            ? null
            : UserContact.fromJson(contact as Map<String, dynamic>).toJson(),
      });
    }
    return result;
  }

  Map<String, Map<String, dynamic>> _recordMap(String? raw) {
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded.length > 10000) {
      throw const FormatException('通讯录本地合并记录无效');
    }
    return decoded.map((cid, value) {
      requireCidNumber(cid);
      if (value is! Map<String, dynamic> ||
          value.length != 3 ||
          value['cid_number'] != cid ||
          value['updated_at'] is! int ||
          (value['updated_at'] as int) <= 0 ||
          !value.containsKey('contact')) {
        throw const FormatException('通讯录本地合并记录无效');
      }
      if (value['contact'] != null) {
        if (value['contact'] is! Map<String, dynamic>) {
          throw const FormatException('通讯录本地联系人无效');
        }
        final contact = UserContact.fromJson(
          value['contact'] as Map<String, dynamic>,
        );
        if (contact.cidNumber != cid ||
            contact.updatedAt != value['updated_at']) {
          throw const FormatException('通讯录本地联系人标识不一致');
        }
      }
      return MapEntry(cid, {
        'cid_number': cid,
        'updated_at': value['updated_at'],
        'contact': value['contact'] == null
            ? null
            : UserContact.fromJson(value['contact'] as Map<String, dynamic>)
                  .toJson(),
      });
    });
  }

  Future<void> _applyContactSnapshot(
    _ContactOwner owner,
    List<int> payload,
  ) async {
    final incoming = _decodeRecords(owner, payload);
    await _assertOwner(owner);
    await UserIsar.instance.writeTxn((isar) async {
      await _assertOwner(owner);
      final prior = await isar
          .collection<user_store.Contact>()
          .getByCidNumberStateKind(owner.cidNumber, 'records');
      final merged = _recordMap(prior?.bodyData);
      for (final record in incoming) {
        final cid = record['cid_number'] as String;
        final previous = merged[cid];
        // 同时间冲突采用规范 JSON 的稳定顺序；删除在同时间优先，防止复活。
        final timestamp = record['updated_at'] as int;
        final oldTimestamp = previous?['updated_at'] as int? ?? 0;
        if (timestamp > oldTimestamp ||
            (timestamp == oldTimestamp &&
                (record['contact'] == null ||
                    (previous?['contact'] != null &&
                        jsonEncode(record).compareTo(jsonEncode(previous)) >
                            0)))) {
          merged[cid] = record;
        }
      }
      if (merged.length > 10000) throw const FormatException('通讯录记录数量超限');
      await _putState(isar, owner, 'records', jsonEncode(merged));
    });
    await _assertOwner(owner);
  }

  Future<ContactSyncState> readSyncState() async {
    final owner = await _requireIdentityOwner();
    final raw = await _readState(owner, 'sync');
    if (raw == null) {
      return const ContactSyncState(phase: ContactSyncPhase.idle);
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) throw const FormatException();
      final phaseName = json['phase']?.toString();
      final phase = ContactSyncPhase.values.firstWhere(
        (item) => item.name == phaseName,
        orElse: () => ContactSyncPhase.idle,
      );
      return ContactSyncState(
        phase: phase,
        updatedAt: _asInt(json['updated_at']),
        message: json['message']?.toString(),
        errorCode: json['error_code'] is String
            ? json['error_code'] as String
            : null,
        statusCode: json['status_code'] is int
            ? json['status_code'] as int
            : null,
        stage: SquareApiStage.values
            .where((item) => item.name == json['stage'])
            .firstOrNull,
      );
    } on FormatException {
      return const ContactSyncState(phase: ContactSyncPhase.idle);
    }
  }

  /// 解析通讯录永久属主与当前授权账户；未注册 CID 必须失败关闭。
  Future<_ContactOwner> _requireIdentityOwner() async {
    final accountRevision = _accountSecurity.revision.value;
    final identity = await _currentUser.resolve();
    if (accountRevision != _accountSecurity.revision.value) {
      throw const AccountSecurityException('通讯录账户修订已变化');
    }
    if (identity == null || !identity.isRegistered) {
      throw SquareApiException(
        identity?.isUnregistered == true
            ? '当前账户尚未注册公民号'
            : '身份信息暂不可用，请在身份页刷新后重试',
        errorCode: identity?.isUnregistered == true
            ? 'identity_unregistered'
            : 'identity_local_missing',
        stage: SquareApiStage.identity,
      );
    }
    return _ContactOwner(
      accountRevision: accountRevision,
      cidNumber: requireCidNumber(identity.cidNumber),
      bindRev: identity.bindRev,
      accountId: requireAccountId(identity.accountId),
    );
  }

  Future<List<UserContact>> _readContacts(_ContactOwner owner) async {
    final raw = await _readState(owner, 'records');
    owner.recordsSnapshot = raw;
    return _sorted(
      _recordMap(raw).values
          .where((record) => record['contact'] != null)
          .map(
            (record) => UserContact.fromJson(
              (record['contact'] as Map).cast<String, dynamic>(),
            ),
          ),
    );
  }

  Future<List<_PendingContactOp>> _readPending(_ContactOwner owner) async {
    final raw = await _readState(owner, 'pending');
    owner.pendingSnapshot = raw;
    if (raw == null) return const <_PendingContactOp>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.length > 10000) {
        throw const FormatException('通讯录待同步记录无效');
      }
      return decoded
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('通讯录记录类型无效');
            }
            return item;
          })
          .map(_PendingContactOp.fromJson)
          .toList(growable: false);
    } on FormatException {
      rethrow;
    }
  }

  Future<void> _writeContactsAndPending(
    _ContactOwner owner,
    List<UserContact> contacts,
    _PendingContactOp next,
  ) async {
    final pending = (await _readPending(owner)).toList(growable: true)
      ..removeWhere((item) => item.cidNumber == next.cidNumber)
      ..add(next);
    await _writeSnapshot(owner, contacts, pending);
    await _setSyncState(owner, ContactSyncPhase.pending);
  }

  Future<void> _removePending(
    _ContactOwner owner,
    _PendingContactOp completed,
  ) async {
    final pending = (await _readPending(owner))
        .where(
          (item) =>
              item.cidNumber != completed.cidNumber ||
              item.updatedAt > completed.updatedAt,
        )
        .toList(growable: false);
    await _writePending(owner, pending);
  }

  Future<void> _writeSnapshot(
    _ContactOwner owner,
    List<UserContact> contacts,
    List<_PendingContactOp> pending,
  ) async {
    await _assertOwner(owner);
    await UserIsar.instance.writeTxn((isar) async {
      await _assertOwner(owner);
      final existing = await isar
          .collection<user_store.Contact>()
          .getByCidNumberStateKind(owner.cidNumber, 'records');
      final queued = await isar
          .collection<user_store.Contact>()
          .getByCidNumberStateKind(owner.cidNumber, 'pending');
      if (existing?.bodyData != owner.recordsSnapshot ||
          queued?.bodyData != owner.pendingSnapshot) {
        throw StateError('通讯录已被其他操作更新，请重试');
      }
      final records = _recordMap(existing?.bodyData);
      for (final contact in contacts) {
        records[contact.cidNumber] = {
          'cid_number': contact.cidNumber,
          'updated_at': contact.updatedAt,
          'contact': contact.toJson(),
        };
      }
      for (final operation in pending.where(
        (item) => item.action == _PendingAction.delete,
      )) {
        records[operation.cidNumber] = {
          'cid_number': operation.cidNumber,
          'updated_at': operation.updatedAt,
          'contact': null,
        };
      }
      if (records.length > 10000) throw const FormatException('通讯录记录数量超限');
      final queue = jsonEncode(pending.map((item) => item.toJson()).toList());
      await _putState(isar, owner, 'pending', queue);
      await _putState(isar, owner, 'records', jsonEncode(records));
      owner.recordsSnapshot = jsonEncode(records);
      owner.pendingSnapshot = queue;
    });
    await _assertOwner(owner);
  }

  Future<void> _writePending(
    _ContactOwner owner,
    List<_PendingContactOp> pending,
  ) => _writeState(
    owner,
    'pending',
    jsonEncode(pending.map((item) => item.toJson()).toList()),
  );

  Future<void> _setSyncState(
    _ContactOwner owner,
    ContactSyncPhase phase, {
    String? message,
    String? errorCode,
    int? statusCode,
    SquareApiStage? stage,
  }) async {
    final state = ContactSyncState(
      phase: phase,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      message: message,
      errorCode: errorCode,
      statusCode: statusCode,
      stage: stage,
    );
    syncState.value = state;
    await _writeState(
      owner,
      'sync',
      jsonEncode(<String, Object?>{
        'phase': phase.name,
        'updated_at': state.updatedAt,
        'message': ?message,
        'error_code': ?errorCode,
        'status_code': ?statusCode,
        'stage': ?stage?.name,
      }),
    );
  }

  /// 读取只能使用当前 CID 的系统保护记录，损坏数据直接失败。
  Future<String?> _readState(_ContactOwner owner, String stateKind) async {
    await _assertOwner(owner);
    final value = await UserIsar.instance.read(
      (isar) async =>
          (await isar.collection<user_store.Contact>().getByCidNumberStateKind(
            owner.cidNumber,
            stateKind,
          ))?.bodyData,
    );
    await _assertOwner(owner);
    return value;
  }

  Future<void> _writeState(
    _ContactOwner owner,
    String stateKind,
    String value,
  ) async {
    await _assertOwner(owner);
    await UserIsar.instance.writeTxn((isar) async {
      await _assertOwner(owner);
      if (stateKind == 'pending' &&
          (await isar.collection<user_store.Contact>().getByCidNumberStateKind(
                owner.cidNumber,
                stateKind,
              ))?.bodyData !=
              owner.pendingSnapshot) {
        throw StateError('通讯录待同步操作已变化，请重试');
      }
      await _putState(isar, owner, stateKind, value);
      if (stateKind == 'pending') {
        owner.pendingSnapshot = value;
      }
    });
    await _assertOwner(owner);
  }

  Future<void> _putState(
    Isar isar,
    _ContactOwner owner,
    String stateKind,
    String value,
  ) async {
    if (!{'pending', 'sync', 'records'}.contains(stateKind)) {
      throw const FormatException('通讯录状态种类无效');
    }
    final row =
        await isar.collection<user_store.Contact>().getByCidNumberStateKind(
          owner.cidNumber,
          stateKind,
        ) ??
        (user_store.Contact()
          ..cidNumber = owner.cidNumber
          ..stateKind = stateKind);
    row.bodyData = value;
    await isar.collection<user_store.Contact>().put(row);
  }

  static String normalizeSs58Address(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) throw const FormatException('地址为空');
    try {
      final bytes = Keyring().decodeAddress(trimmed);
      final normalized = Keyring().encodeAddress(bytes, kGmbSs58Prefix);
      if (normalized != trimmed) {
        throw const FormatException('联系人地址不是本链 SS58 地址');
      }
      return normalized;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('联系人地址格式无效');
    }
  }

  static String accountIdFromSs58(String accountAddress) {
    final normalized = normalizeSs58Address(accountAddress);
    final bytes = Keyring().decodeAddress(normalized);
    return '0x${_hex(bytes)}';
  }

  static String requireAccountId(String accountId) {
    if (!isAccountIdText(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }

  static String requireCidNumber(String cidNumber) {
    final normalized = cidNumber.trim();
    if (normalized.isEmpty || utf8.encode(normalized).length > 32) {
      throw const FormatException('cid_number 必须为 1 到 32 字节');
    }
    return normalized;
  }

  static String normalizeContactRemark(String contactRemark) {
    final normalized = contactRemark.trim();
    if (normalized.runes.length > 40) {
      throw const FormatException('联系人私人备注不能超过 40 个字符');
    }
    return normalized;
  }
}

/// 通讯录的永久属主与本次有效授权账户。
class _ContactOwner {
  _ContactOwner({
    required this.accountRevision,
    required this.cidNumber,
    required this.bindRev,
    required this.accountId,
  });

  final String cidNumber;
  final int bindRev;
  final String accountId;
  String? recordsSnapshot;
  String? pendingSnapshot;
  final int accountRevision;
}

enum _PendingAction { upsert, delete }

class _PendingContactOp {
  const _PendingContactOp({
    required this.action,
    required this.cidNumber,
    required this.updatedAt,
  });

  factory _PendingContactOp.upsert(String cidNumber, int updatedAt) =>
      _PendingContactOp(
        action: _PendingAction.upsert,
        cidNumber: cidNumber,
        updatedAt: updatedAt,
      );

  factory _PendingContactOp.delete(String cidNumber, int updatedAt) =>
      _PendingContactOp(
        action: _PendingAction.delete,
        cidNumber: cidNumber,
        updatedAt: updatedAt,
      );

  final _PendingAction action;
  final String cidNumber;
  final int updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'action': action.name,
    'cid_number': cidNumber,
    'updated_at': updatedAt,
  };

  factory _PendingContactOp.fromJson(Map<String, dynamic> json) {
    if (json.length != 3 ||
        !['delete', 'upsert'].contains(json['action']) ||
        json['cid_number'] is! String ||
        json['updated_at'] is! int ||
        (json['updated_at'] as int) <= 0) {
      throw const FormatException('通讯录待同步操作无效');
    }
    final action = json['action'] == 'delete'
        ? _PendingAction.delete
        : _PendingAction.upsert;
    return _PendingContactOp(
      action: action,
      cidNumber: UserContactService.requireCidNumber(
        json['cid_number']?.toString() ?? '',
      ),
      updatedAt: _asInt(json['updated_at']),
    );
  }
}

List<UserContact> _sorted(Iterable<UserContact> contacts) =>
    contacts.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// 联系人冲突时间戳必须为正且单设备单调递增，避免同一毫秒内连续修改被旧值覆盖。
int _nextTimestamp([int previous = 0]) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return now > previous ? now : previous + 1;
}

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
