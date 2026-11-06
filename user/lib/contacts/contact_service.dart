import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:citizen_sdk/account_codec.dart';
import 'package:citizen_storage/user_isar.dart' as store;
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_system/security/account_security_exception.dart';
import 'contact_sort.dart';

/// 联系人及云端备份备注的展示模型；SS58仅由账户ID计算。
class UserContact {
  const UserContact({
    required this.cidNumber,
    required this.accountId,
    required this.contactRemark,
    required this.updatedAt,
  });
  final String cidNumber;
  final String accountId;
  final String contactRemark;
  final int updatedAt;
  String get ss58Address => citizenSs58FromAccountId(accountId);
  UserContact copyWith({
    String? accountId,
    String? contactRemark,
    int? updatedAt,
  }) => UserContact(
    cidNumber: cidNumber,
    accountId: accountId ?? this.accountId,
    contactRemark: contactRemark ?? this.contactRemark,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  factory UserContact.fromCloudJson(Map<String, dynamic> value) {
    if (value.length != 4 ||
        value['cid_number'] is! String ||
        value['account_id'] is! String ||
        value['contact_remark'] is! String ||
        value['updated_at'] is! int ||
        (value['updated_at'] as int) <= 0) {
      throw const FormatException('云端联系人字段无效');
    }
    return UserContact(
      cidNumber: UserContactService.requireCidNumber(
        value['cid_number'] as String,
      ),
      accountId: UserContactService.requireAccountId(
        value['account_id'] as String,
      ),
      contactRemark: validateContactRemark(value['contact_remark'] as String),
      updatedAt: value['updated_at'] as int,
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
    this.message,
    this.errorCode,
    this.statusCode,
    this.stage,
  });
  final ContactSyncPhase phase;
  final String? message, errorCode;
  final int? statusCode;
  final SquareApiStage? stage;
  String get label => switch (phase) {
    ContactSyncPhase.syncing => '正在同步',
    ContactSyncPhase.synced => '云端已同步',
    ContactSyncPhase.pending => '待同步',
    ContactSyncPhase.offline => '离线，显示本地通讯录',
    ContactSyncPhase.failed =>
      message?.isNotEmpty == true ? message! : '同步失败，点击重试',
    ContactSyncPhase.idle => '本地通讯录',
  };
}

/// 列表只读本机；自动备份只发送待同步条目，全量读取仅由 sync 发起。
class UserContactService {
  UserContactService({
    required AccountSecurityService accountSecurity,
    required CurrentUserContext currentUserContext,
    required SquareSessionProvider sessionProvider,
    SquareApiClient? apiClient,
    bool autoSync = true,
  }) : _security = accountSecurity,
       _current = currentUserContext,
       _sessions = sessionProvider,
       _api = apiClient ?? SquareApiClient(),
       _autoSync = autoSync;
  final AccountSecurityService _security;
  final CurrentUserContext _current;
  final SquareSessionProvider _sessions;
  final SquareApiClient _api;
  final bool _autoSync;
  bool _disposed = false;
  void invalidate() {
    _state(ContactSyncPhase.idle);
  }

  void dispose() {
    _disposed = true;
    syncState.dispose();
  }

  final syncState = ValueNotifier<ContactSyncState>(
    const ContactSyncState(phase: ContactSyncPhase.idle),
  );
  static final _tails = <(AccountSecurityService, String), Future<void>>{};
  Future<void>? _backupFlight;
  _Owner? _backupOwner;
  Future<List<UserContact>>? _syncFlight;
  _Owner? _syncOwner;

  Future<T> _serial<T>(_Owner owner, Future<T> Function() work) async {
    final key = (_security, owner.cidNumber);
    final previous = _tails[key] ?? Future<void>.value();
    final task = previous.then((_) async {
      await _assertOwner(owner);
      return work();
    });
    final tail = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _tails[key] = tail;
    try {
      return await task;
    } finally {
      if (identical(_tails[key], tail)) _tails.remove(key);
    }
  }

  Future<_Owner> _owner() async {
    final revision = _security.revision.value;
    final identity = await _current.resolve();
    if (revision != _security.revision.value) {
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
    return _Owner(
      requireCidNumber(identity.cidNumber),
      requireAccountId(identity.accountId),
      identity.bindRev,
      revision,
    );
  }

  Future<void> _assertOwner(_Owner owner) async {
    if (_disposed) throw const AccountSecurityException('通讯录已关闭');
    final current = await _current.resolve();
    final binding = await _security.readIdentityBindingForCid(owner.cidNumber);
    if (_security.revision.value != owner.accountRevision ||
        current?.cidNumber != owner.cidNumber ||
        current?.accountId != owner.accountId ||
        current?.bindRev != owner.bindRev ||
        current?.isRegistered != true ||
        binding?.accountId != owner.accountId ||
        binding?.bindRev != owner.bindRev) {
      throw const AccountSecurityException('通讯录当前身份已变化');
    }
  }

  Future<T> _write<T>(_Owner owner, Future<T> Function(Isar) action) async {
    await _assertOwner(owner);
    final result = await store.UserIsar.instance.writeTxn((db) async {
      if (_security.revision.value != owner.accountRevision) {
        throw const AccountSecurityException('通讯录当前身份已变化');
      }
      final value = await action(db);
      if (_security.revision.value != owner.accountRevision) {
        throw const AccountSecurityException('通讯录当前身份已变化');
      }
      return value;
    });
    await _assertOwner(owner);
    return result;
  }

  Future<SquareSession> _session(_Owner owner) async {
    await _assertOwner(owner);
    final value = await _sessions.ensureSession();
    await _assertOwner(owner);
    if (value == null ||
        value.cidNumber != owner.cidNumber ||
        value.accountId != owner.accountId ||
        value.bindRev != owner.bindRev) {
      throw const SquareApiException('通讯录会话不可用');
    }
    return value;
  }

  Future<List<store.Contact>> _rows(_Owner owner) async {
    await _assertOwner(owner);
    final rows = await store.UserIsar.instance.read(
      (db) => db
          .collection<store.Contact>()
          .filter()
          .ownerCidNumberEqualTo(owner.cidNumber)
          .findAll(),
    );
    await _assertOwner(owner);
    return rows;
  }

  UserContact _view(store.Contact row) => UserContact(
    cidNumber: row.cidNumber,
    accountId: row.accountId,
    contactRemark: row.contactRemark,
    updatedAt: row.updatedAt,
  );
  Future<List<UserContact>> _contacts(_Owner owner) async {
    final result = (await _rows(
      owner,
    )).where((r) => r.pendingAction != 'delete').map(_view).toList();
    result.sort(
      (a, b) => compareContactKeys(
        a.contactRemark,
        a.cidNumber,
        b.contactRemark,
        b.cidNumber,
      ),
    );
    return result;
  }

  void _state(ContactSyncPhase phase, {Object? error}) {
    if (_disposed) return;
    final failure = error == null
        ? null
        : SquareSessionResolution.fromError(error);
    syncState.value = ContactSyncState(
      phase: phase,
      message: failure?.message,
      errorCode: failure?.errorCode,
      statusCode: failure?.statusCode,
      stage: failure?.stage,
    );
  }

  Future<List<UserContact>> getContacts() async => _contacts(await _owner());
  Future<ContactSyncState> readSyncState() async {
    final rows = await _rows(await _owner());
    if (rows.any((r) => r.pendingAction.isNotEmpty)) {
      if ([
        ContactSyncPhase.syncing,
        ContactSyncPhase.offline,
        ContactSyncPhase.failed,
      ].contains(syncState.value.phase)) {
        return syncState.value;
      }
      return const ContactSyncState(phase: ContactSyncPhase.pending);
    }
    return ContactSyncState(
      phase: rows.isEmpty && syncState.value.phase == ContactSyncPhase.idle
          ? ContactSyncPhase.idle
          : ContactSyncPhase.synced,
    );
  }

  Future<void> _failed(_Owner owner, Object error) async {
    await _assertOwner(owner);
    final failure = SquareSessionResolution.fromError(error);
    _state(
      failure.status == SquareSessionStatus.networkUnavailable
          ? ContactSyncPhase.offline
          : ContactSyncPhase.failed,
      error: error,
    );
  }

  Future<void> _flush(_Owner owner) async {
    var pending = (await _rows(
      owner,
    )).where((r) => r.pendingAction.isNotEmpty).toList();
    if (pending.isEmpty) return;
    final session = await _session(owner);
    while (pending.isNotEmpty) {
      final sent = pending.first;
      _state(ContactSyncPhase.syncing);
      final deleting = sent.pendingAction == 'delete';
      final reply = deleting
          ? await _api.deleteUserContact(
              session: session,
              cidNumber: sent.cidNumber,
            )
          : await _api.saveUserContact(
              session: session,
              cidNumber: sent.cidNumber,
              accountId: sent.accountId,
              contactRemark: sent.contactRemark,
            );
      await _assertOwner(owner);
      UserContact? confirmed;
      if (reply['is_ok'] != true) throw const FormatException('联系人写入回执无效');
      if (deleting) {
        if (reply['deleted_cid_number'] != sent.cidNumber) {
          throw const FormatException('联系人删除回执不匹配');
        }
      } else {
        confirmed = UserContact.fromCloudJson(
          (reply['contact'] as Map).cast<String, dynamic>(),
        );
        if (confirmed.cidNumber != sent.cidNumber ||
            confirmed.accountId != sent.accountId ||
            confirmed.contactRemark != sent.contactRemark) {
          throw const FormatException('联系人写入回执不匹配');
        }
      }
      await _write(owner, (db) async {
        final rows = db.collection<store.Contact>();
        final saved = await rows.getByOwnerCidNumberCidNumber(
          owner.cidNumber,
          sent.cidNumber,
        );
        if (saved == null ||
            saved.rowId != sent.rowId ||
            saved.changeVersion != sent.changeVersion) {
          return;
        }
        if (deleting) {
          await rows.delete(saved.rowId);
        } else {
          saved.pendingAction = '';
          saved.updatedAt = confirmed!.updatedAt;
          await rows.put(saved);
        }
      });
      pending = (await _rows(
        owner,
      )).where((r) => r.pendingAction.isNotEmpty).toList();
    }
    _state(ContactSyncPhase.synced);
  }

  Future<void> flushPending() async {
    try {
      final owner = await _owner();
      if (_backupFlight != null && _backupOwner == owner) {
        return await _backupFlight!;
      }
      late final Future<void> task;
      task =
          _serial(owner, () async {
            try {
              await _flush(owner);
            } on Object catch (error) {
              await _failed(owner, error);
            }
          }).whenComplete(() {
            if (identical(_backupFlight, task)) {
              _backupFlight = null;
              _backupOwner = null;
            }
          });
      _backupOwner = owner;
      _backupFlight = task;
      await task;
    } on Object {
      // 身份尚未就绪或已切换时保留原属主待发条目。
    }
  }

  Future<void> _afterMutation(_Owner owner) async {
    _state(ContactSyncPhase.pending);
    if (!_autoSync) return;
    unawaited(
      _serial(owner, () async {
        try {
          await _flush(owner);
        } on Object catch (error) {
          await _failed(owner, error);
        }
      }).catchError((Object error) {
        // 已切换或关闭的身份不能接收迟到结果；待发动作仍留在原属主记录。
      }),
    );
  }

  Future<ContactImportResult> importContact({
    required String cidNumber,
    required String accountId,
  }) async {
    final owner = await _owner();
    final card = await _api.fetchUserCard(
      cidNumber: requireCidNumber(cidNumber),
      session: await _session(owner),
    );
    if (card.cidNumber != cidNumber ||
        card.accountId != requireAccountId(accountId)) {
      throw const FormatException('用户码与当前绑定不一致');
    }
    await _assertOwner(owner);
    return _addContact(
      owner,
      cidNumber: cidNumber,
      accountId: card.accountId,
      contactRemark: '',
    );
  }

  Future<ContactImportResult> addContact({
    required String cidNumber,
    required String accountId,
    required String contactRemark,
  }) async => _addContact(
    await _owner(),
    cidNumber: cidNumber,
    accountId: accountId,
    contactRemark: contactRemark,
  );
  Future<ContactImportResult> _addContact(
    _Owner owner, {
    required String cidNumber,
    required String accountId,
    required String contactRemark,
  }) async {
    final cid = requireCidNumber(cidNumber),
        account = requireAccountId(accountId),
        remark = normalizeContactRemark(contactRemark);
    if (cid == owner.cidNumber || account == owner.accountId) {
      throw const FormatException('不能把自己加入通讯录');
    }
    var created = false, changed = false;
    late UserContact result;
    await _write(owner, (db) async {
      final rows = db.collection<store.Contact>();
      final prior = await rows.getByOwnerCidNumberCidNumber(
        owner.cidNumber,
        cid,
      );
      created = prior == null || prior.pendingAction == 'delete';
      final row =
          prior ??
          (store.Contact()
            ..ownerCidNumber = owner.cidNumber
            ..cidNumber = cid);
      final nextRemark = remark.isEmpty && !created
          ? row.contactRemark
          : remark;
      changed =
          created ||
          row.accountId != account ||
          row.contactRemark != nextRemark;
      if (changed) {
        row.accountId = account;
        row.contactRemark = nextRemark;
        row.changeVersion++;
        row.pendingAction = 'put';
        row.updatedAt = DateTime.now().millisecondsSinceEpoch;
        await rows.put(row);
      }
      result = _view(row);
    });
    if (changed) await _afterMutation(owner);
    return ContactImportResult(contact: result, created: created);
  }

  Future<List<UserContact>> renameContact(
    String cidNumber,
    String contactRemark,
  ) async {
    final owner = await _owner(),
        cid = requireCidNumber(cidNumber),
        remark = normalizeContactRemark(contactRemark);
    var changed = false;
    await _write(owner, (db) async {
      final rows = db.collection<store.Contact>();
      final row = await rows.getByOwnerCidNumberCidNumber(owner.cidNumber, cid);
      if (row == null || row.pendingAction == 'delete') {
        throw StateError('未找到联系人');
      }
      if (row.contactRemark == remark) return;
      changed = true;
      row.contactRemark = remark;
      row.changeVersion++;
      row.pendingAction = 'put';
      row.updatedAt = DateTime.now().millisecondsSinceEpoch;
      await rows.put(row);
    });
    if (changed) await _afterMutation(owner);
    return _contacts(owner);
  }

  Future<List<UserContact>> deleteContact(String cidNumber) async {
    final owner = await _owner(), cid = requireCidNumber(cidNumber);
    var changed = false;
    await _write(owner, (db) async {
      final rows = db.collection<store.Contact>();
      final row = await rows.getByOwnerCidNumberCidNumber(owner.cidNumber, cid);
      if (row == null || row.pendingAction == 'delete') return;
      row.pendingAction = 'delete';
      row.changeVersion++;
      changed = true;
      await rows.put(row);
    });
    if (changed) await _afterMutation(owner);
    return _contacts(owner);
  }

  Future<void> _replace(_Owner owner, Map<String, UserContact> incoming) async {
    await _write(owner, (db) async {
      final collection = db.collection<store.Contact>();
      final old = await collection
          .filter()
          .ownerCidNumberEqualTo(owner.cidNumber)
          .findAll();
      final existing = {for (final row in old) row.cidNumber: row};
      for (final row in old) {
        if (row.pendingAction.isEmpty && !incoming.containsKey(row.cidNumber)) {
          await collection.delete(row.rowId);
        }
      }
      for (final contact in incoming.values) {
        final prior = existing[contact.cidNumber];
        if (prior != null && prior.pendingAction.isNotEmpty) continue;
        final row =
            prior ??
            (store.Contact()
              ..ownerCidNumber = owner.cidNumber
              ..cidNumber = contact.cidNumber);
        row.accountId = contact.accountId;
        row.contactRemark = contact.contactRemark;
        row.updatedAt = contact.updatedAt;
        await collection.put(row);
      }
    });
  }

  Future<List<UserContact>> sync() async {
    final owner = await _owner();
    if (_syncFlight != null && _syncOwner == owner) return _syncFlight!;
    late final Future<List<UserContact>> task;
    task =
        _serial(owner, () async {
          _state(ContactSyncPhase.syncing);
          try {
            await _flush(owner);
            final session = await _session(owner);
            final incoming = <String, UserContact>{}, cursors = <String>{};
            String? cursor;
            do {
              final page = await _api.fetchUserContacts(
                session: session,
                cursor: cursor,
              );
              await _assertOwner(owner);
              if (page['is_ok'] != true ||
                  page['contacts'] is! List ||
                  (page['next_cursor'] != null &&
                      page['next_cursor'] is! String)) {
                throw const FormatException('通讯录清单无效');
              }
              for (final raw in page['contacts'] as List) {
                final contact = UserContact.fromCloudJson(
                  (raw as Map).cast<String, dynamic>(),
                );
                if (contact.cidNumber == owner.cidNumber ||
                    contact.accountId == owner.accountId ||
                    incoming.containsKey(contact.cidNumber)) {
                  throw const FormatException('通讯录联系人无效或重复');
                }
                incoming[contact.cidNumber] = contact;
              }
              cursor = page['next_cursor'] as String?;
              if (cursor != null && (cursor.isEmpty || !cursors.add(cursor))) {
                throw const FormatException('通讯录分页游标重复');
              }
            } while (cursor != null);
            await _replace(owner, incoming);
            _state(
              (await _rows(owner)).any((r) => r.pendingAction.isNotEmpty)
                  ? ContactSyncPhase.pending
                  : ContactSyncPhase.synced,
            );
          } on Object catch (error) {
            await _failed(owner, error);
          }
          return _contacts(owner);
        }).whenComplete(() {
          if (identical(_syncFlight, task)) {
            _syncFlight = null;
            _syncOwner = null;
          }
        });
    _syncOwner = owner;
    _syncFlight = task;
    return task;
  }

  static String requireCidNumber(String value) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$').hasMatch(value)) {
      throw const FormatException('公民号无效');
    }
    return value;
  }

  static String requireAccountId(String value) {
    if (!isCitizenAccountId(value)) throw const FormatException('account_id无效');
    return value;
  }

  static String normalizeContactRemark(String value) =>
      validateContactRemark(value);
}

class _Owner {
  const _Owner(
    this.cidNumber,
    this.accountId,
    this.bindRev,
    this.accountRevision,
  );
  final String cidNumber, accountId;
  final int bindRev, accountRevision;
  @override
  bool operator ==(Object other) =>
      other is _Owner &&
      other.cidNumber == cidNumber &&
      other.accountId == accountId &&
      other.bindRev == bindRev &&
      other.accountRevision == accountRevision;
  @override
  int get hashCode =>
      Object.hash(cidNumber, accountId, bindRev, accountRevision);
}
