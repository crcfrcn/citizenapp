// 管理联系人、私有备注、排序、扫码添加及同步。

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_storage/user.dart' as store;
import 'package:citizen_user/security.dart' show AccountSecurityService;
import 'package:citizen_user/context.dart' show CurrentUserContext;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider, SquareSessionResolution, SquareSessionStatus;
import 'package:citizen_user/api.dart' show SquareApiClient, SquareApiException, SquareApiStage, SquareSession;
import 'package:citizen_system/security/access.dart';
import 'package:lpinyin/lpinyin.dart';

// 按CID管理联系人与私有备注，协调增量备份、合并和身份隔离。

/// 按公民号保存的联系人及其私有备注。
class UserContact {
  const UserContact({
    required this.cidNumber,
    required this.contactRemark,
    required this.changeVersion,
    this.deleted = false,
  });

  final String cidNumber;
  final String contactRemark;
  final int changeVersion;
  final bool deleted;

  factory UserContact.fromCloudJson(Map<String, dynamic> value) {
    if (value.length != 4 ||
        value['cid_number'] is! String ||
        value['contact_remark'] is! String ||
        value['change_version'] is! int ||
        (value['change_version'] as int) <= 0 ||
        (value['change_version'] as int) >= 9007199254740991 ||
        value['deleted'] is! bool ||
        value['deleted'] == true && value['contact_remark'] != '') {
      throw const FormatException('云端联系人字段无效');
    }
    return UserContact(
      cidNumber: UserContactService.requireCidNumber(
        value['cid_number'] as String,
      ),
      contactRemark: validateContactRemark(value['contact_remark'] as String),
      changeVersion: value['change_version'] as int,
      deleted: value['deleted'] as bool,
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
    this.retryByPull = false,
  });
  final ContactSyncPhase phase;
  final String? message, errorCode;
  final int? statusCode;
  final SquareApiStage? stage;
  final bool retryByPull;
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
  final _retryTimers = <String, Timer>{};
  int _retryAttempt = 0;
  bool _deleting = false;
  static const deleteAction = CitizenQrActions.contactsDelete;
  static const deleteScope = 'citizenapp.contacts.delete.v1';
  static const _retryDelays = [5, 15, 60];
  void setForeground(bool foreground) {
    _foreground = foreground;
  }

  bool _foreground = true;
  void invalidate() {
    // 保留已有等待窗口，身份广播不能绕过同一CID的限流。
    _retryAttempt = 0;
    _state(ContactSyncPhase.idle, resetPull: true);
  }

  void dispose() {
    _disposed = true;
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    syncState.dispose();
  }

  bool _canSend(_Owner owner) =>
      !_disposed &&
      _foreground &&
      !(_retryTimers[owner.cidNumber]?.isActive ?? false);
  static const _conflict = SquareApiException(
    '同步失败，点击重试',
    errorCode: 'contact_version_conflict',
  );
  static const _legacy = SquareApiException(
    '同步失败，点击重试',
    errorCode: 'contact_legacy_confirmation_required',
  );
  static const _terminalDelete = {
    'contact_delete_signature_invalid',
    'contact_delete_batch_conflict',
    'invalid_contact_delete',
    'invalid_contact_delete_subset',
  };
  static bool _authorizedDelete(store.Contact row) =>
      row.pendingAction == 'delete' && row.deleteBatch.isNotEmpty;

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
      _requireOwnerAccountId(identity.accountId),
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
    final value = await _sessions.ensureContactSession();
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
          .where()
          .ownerCidNumberEqualToAnyCidNumber(owner.cidNumber)
          .findAll(),
    );
    await _assertOwner(owner);
    return rows;
  }

  Future<List<store.Contact>> _pending(_Owner owner) async {
    await _assertOwner(owner);
    final rows = await store.UserIsar.instance.read(
      (db) => db
          .collection<store.Contact>()
          .where()
          .ownerCidNumberEqualToAnyCidNumber(owner.cidNumber)
          .filter()
          .deletedIsNotNull()
          .group(
            (q) => q
                .pendingActionEqualTo('put')
                .or()
                .pendingActionEqualTo('delete'),
          )
          .findAll(),
    );
    await _assertOwner(owner);
    return rows;
  }

  UserContact _view(store.Contact row) => UserContact(
    cidNumber: row.cidNumber,
    contactRemark: row.contactRemark,
    changeVersion: row.changeVersion,
    deleted: row.deleted == true,
  );
  Future<List<UserContact>> _contacts(_Owner owner) async {
    final result = (await _rows(owner))
        .where((r) => !_authorizedDelete(r) && r.deleted != true)
        .map(_view)
        .toList();
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

  void _state(
    ContactSyncPhase phase, {
    Object? error,
    bool retryByPull = false,
    bool resetPull = false,
  }) {
    if (_disposed) return;
    final previous = syncState.value;
    final keepPull = !resetPull && previous.retryByPull;
    final pull = retryByPull || keepPull;
    final failure = error == null
        ? null
        : SquareSessionResolution.fromError(error);
    syncState.value = ContactSyncState(
      phase: phase == ContactSyncPhase.synced && pull
          ? ContactSyncPhase.failed
          : phase,
      message: failure?.message ?? (keepPull ? previous.message : null),
      errorCode: failure?.errorCode ?? (keepPull ? previous.errorCode : null),
      statusCode:
          failure?.statusCode ?? (keepPull ? previous.statusCode : null),
      stage: failure?.stage ?? (keepPull ? previous.stage : null),
      retryByPull: pull,
    );
  }

  Future<List<UserContact>> getContacts() async => _contacts(await _owner());
  Future<ContactSyncState> readSyncState() async {
    final rows = await _rows(await _owner());
    if (syncState.value.retryByPull ||
        syncState.value.errorCode == 'contact_version_conflict' ||
        syncState.value.errorCode == 'contact_legacy_confirmation_required' ||
        _terminalDelete.contains(syncState.value.errorCode)) {
      return syncState.value;
    }
    if (rows.any(
      (r) => r.deleted == null || r.pendingAction == 'unsigned_delete',
    )) {
      return const ContactSyncState(
        phase: ContactSyncPhase.failed,
        message: '同步失败，点击重试',
        errorCode: 'contact_legacy_confirmation_required',
      );
    }
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

  Future<void> _failed(
    _Owner owner,
    Object error, {
    bool retryByPull = false,
  }) async {
    await _assertOwner(owner);
    final failure = SquareSessionResolution.fromError(error);
    _state(
      failure.status == SquareSessionStatus.networkUnavailable
          ? ContactSyncPhase.offline
          : ContactSyncPhase.failed,
      error: error,
      retryByPull: retryByPull,
    );
    final transient =
        failure.status == SquareSessionStatus.networkUnavailable ||
        error is SquareApiException &&
            [408, 429, 500, 502, 503, 504].contains(error.statusCode);
    if (!transient || (_retryTimers[owner.cidNumber]?.isActive ?? false)) {
      return;
    }
    final automatic =
        !retryByPull && _autoSync && _retryAttempt < _retryDelays.length;
    var wait = automatic
        ? Duration(seconds: _retryDelays[_retryAttempt++])
        : Duration.zero;
    if (error is SquareApiException &&
        error.retryAfter != null &&
        error.retryAfter! > wait) {
      wait = error.retryAfter!;
    }
    if (wait <= Duration.zero) return;
    late final Timer timer;
    timer = Timer(wait, () async {
      if (identical(_retryTimers[owner.cidNumber], timer)) {
        _retryTimers.remove(owner.cidNumber);
      }
      if (!automatic || _disposed || !_foreground) return;
      try {
        if ((await _current.resolve())?.cidNumber == owner.cidNumber) {
          await flushPending();
        }
      } on Object {
        /* 旧身份等待结束不触发其它CID的补传。 */
      }
    });
    _retryTimers[owner.cidNumber] = timer;
  }

  static void _cloud(store.Contact row, UserContact contact) {
    row.changeVersion = contact.changeVersion;
    row.contactRemark = contact.contactRemark;
    row.deleted = contact.deleted;
    row.pendingAction = '';
    row.deleteBatch = '';
  }

  /// 成功回执可接续新编辑；冲突只采用高版本，不能借回执重发旧草稿。
  static void _receipt(
    store.Contact row,
    UserContact contact, {
    required bool conflict,
    required int expected,
    required bool unchanged,
  }) {
    if (row.changeVersion > contact.changeVersion ||
        row.changeVersion == contact.changeVersion &&
            row.changeVersion > expected) {
      return;
    }
    if (conflict) {
      if (contact.changeVersion > row.changeVersion) _cloud(row, contact);
      return;
    }
    row.changeVersion = contact.changeVersion;
    if (unchanged) _cloud(row, contact);
  }

  Future<void> _declineBatch(_Owner owner, store.ContactDeleteBatch batch) =>
      _write(owner, (db) async {
        final rows = await db
            .collection<store.Contact>()
            .where()
            .ownerCidNumberEqualToAnyCidNumber(owner.cidNumber)
            .filter()
            .deleteBatchEqualTo(batch.batchId)
            .findAll();
        for (final row in rows) {
          row.deleteBatch = '';
          if (row.pendingAction == 'delete') {
            row.pendingAction = '';
            row.deleted = false;
          }
          await db.collection<store.Contact>().put(row);
        }
        await db.collection<store.ContactDeleteBatch>().delete(batch.id);
      });
  Future<SquareApiException?> _flush(_Owner owner) async {
    SquareApiException? failure;
    var rows = await _pending(owner);
    if (rows.isEmpty) return null;
    final session = await _session(owner);
    final batches = await store.UserIsar.instance.read(
      (db) => db
          .collection<store.ContactDeleteBatch>()
          .where()
          .ownerCidEqualToAnyBatchId(owner.cidNumber)
          .findAll(),
    );
    for (final batch in batches) {
      final signed = (jsonDecode(batch.data) as Map).cast<String, dynamic>();
      final expected = <String, int>{
        for (final raw in (signed['intent'] as Map)['contacts'] as List)
          (raw as Map)['cid_number'] as String: raw['change_version'] as int,
      };
      final selected =
          (await _pending(owner))
              .where((r) => r.deleteBatch == batch.batchId)
              .map((r) => r.cidNumber)
              .toList()
            ..sort();
      if (selected.isEmpty) {
        await _write(
          owner,
          (db) => db.collection<store.ContactDeleteBatch>().delete(batch.id),
        );
        continue;
      }
      if (selected.any((cid) => !expected.containsKey(cid))) {
        throw const FormatException('联系人删除回执不匹配');
      }
      _state(ContactSyncPhase.syncing);
      Map<String, dynamic> reply;
      try {
        reply = await _api.deleteUserContacts(
          session: session,
          signed: signed,
          remainingCids: selected,
        );
      } on SquareApiException catch (error) {
        if (!_terminalDelete.contains(error.errorCode)) rethrow;
        await _declineBatch(owner, batch);
        failure ??= error;
        continue;
      }
      await _assertOwner(owner);
      if (reply['is_ok'] != true || reply['results'] is! List) {
        throw const FormatException('联系人删除回执无效');
      }
      final remaining = reply['remaining_cids'] ?? <String>[];
      if (remaining is! List || remaining.any((cid) => cid is! String)) {
        throw const FormatException('联系人删除回执无效');
      }
      final left = remaining.cast<String>().toSet();
      if (left.length != remaining.length ||
          left.any((cid) => !selected.contains(cid))) {
        throw const FormatException('联系人删除回执不匹配');
      }
      final results = <String, (UserContact, bool)>{};
      for (final raw in reply['results'] as List) {
        if (raw is! Map || raw['conflict'] is! bool || raw['contact'] is! Map) {
          throw const FormatException('联系人删除回执无效');
        }
        final contact = UserContact.fromCloudJson(
          (raw['contact'] as Map).cast<String, dynamic>(),
        );
        if (!selected.contains(contact.cidNumber) ||
            left.contains(contact.cidNumber) ||
            results.containsKey(contact.cidNumber) ||
            contact.changeVersion <= expected[contact.cidNumber]! ||
            raw['conflict'] == false && !contact.deleted) {
          throw const FormatException('联系人删除回执不匹配');
        }
        results[contact.cidNumber] = (contact, raw['conflict'] as bool);
        if (raw['conflict'] == true) failure ??= _conflict;
      }
      if (results.length + left.length != selected.length) {
        throw const FormatException('联系人删除回执不完整');
      }
      SquareApiException? partial;
      if (left.isNotEmpty) {
        if (reply['status_code'] is! int || reply['error_code'] is! String) {
          throw const FormatException('联系人删除回执无效');
        }
        partial = SquareApiException(
          '同步失败，点击重试',
          statusCode: reply['status_code'] as int,
          errorCode: reply['error_code'] as String,
        );
      }
      await _write(owner, (db) async {
        final collection = db.collection<store.Contact>();
        for (final entry in results.entries) {
          final row = await collection.getByOwnerCidNumberCidNumber(
            owner.cidNumber,
            entry.key,
          );
          if (row == null || row.deleteBatch != batch.batchId) continue;
          _receipt(
            row,
            entry.value.$1,
            conflict: entry.value.$2,
            expected: expected[entry.key]!,
            unchanged: row.pendingAction == 'delete',
          );
          row.deleteBatch = '';
          if (row.pendingAction == 'delete') row.pendingAction = '';
          await collection.put(row);
        }
        if (left.isEmpty) {
          await db.collection<store.ContactDeleteBatch>().delete(batch.id);
        }
      });
      if (partial != null) {
        if (!_terminalDelete.contains(partial.errorCode)) throw partial;
        await _declineBatch(owner, batch);
        failure ??= partial;
      }
    }
    rows = await _pending(owner);
    for (final sent in rows.where(
      (r) => r.pendingAction == 'put' && r.deleteBatch.isEmpty,
    )) {
      _state(ContactSyncPhase.syncing);
      final reply = await _api.saveUserContact(
        session: session,
        cidNumber: sent.cidNumber,
        contactRemark: sent.contactRemark,
        changeVersion: sent.changeVersion,
      );
      await _assertOwner(owner);
      if (reply['is_ok'] != true ||
          reply['conflict'] is! bool ||
          reply['contact'] is! Map) {
        throw const FormatException('联系人写入回执无效');
      }
      final conflict = reply['conflict'] as bool;
      final confirmed = UserContact.fromCloudJson(
        (reply['contact'] as Map).cast<String, dynamic>(),
      );
      if (confirmed.cidNumber != sent.cidNumber ||
          confirmed.changeVersion <= sent.changeVersion ||
          !conflict &&
              (confirmed.deleted ||
                  confirmed.contactRemark != sent.contactRemark)) {
        throw const FormatException('联系人写入回执不匹配');
      }
      if (conflict) failure ??= _conflict;
      await _write(owner, (db) async {
        final collection = db.collection<store.Contact>();
        final saved = await collection.getByOwnerCidNumberCidNumber(
          owner.cidNumber,
          sent.cidNumber,
        );
        if (saved == null || saved.rowId != sent.rowId) return;
        _receipt(
          saved,
          confirmed,
          conflict: conflict,
          expected: sent.changeVersion,
          unchanged:
              saved.pendingAction == sent.pendingAction &&
              saved.contactRemark == sent.contactRemark &&
              saved.deleted == sent.deleted,
        );
        await collection.put(saved);
      });
    }
    if ((await _pending(
      owner,
    )).any((r) => r.pendingAction == 'put' && r.deleteBatch.isEmpty)) {
      final more = await _flush(owner);
      failure ??= more;
    }
    _retryTimers.remove(owner.cidNumber)?.cancel();
    _retryAttempt = 0;
    return failure;
  }

  Future<void> _finish(
    _Owner owner,
    SquareApiException? failure, {
    bool restored = false,
  }) async {
    final rows = await _rows(owner);
    if (rows.any(
      (r) => r.deleted == null || r.pendingAction == 'unsigned_delete',
    )) {
      failure ??= _legacy;
    }
    _state(
      failure != null
          ? ContactSyncPhase.failed
          : rows.any((r) => r.pendingAction.isNotEmpty)
          ? ContactSyncPhase.pending
          : rows.isEmpty && syncState.value.phase == ContactSyncPhase.idle
          ? ContactSyncPhase.idle
          : ContactSyncPhase.synced,
      error: failure,
      resetPull: restored,
    );
  }

  Future<void> flushPending() async {
    try {
      final owner = await _owner();
      if (!_canSend(owner)) return;
      if ((await _rows(
        owner,
      )).any((r) => r.deleted == null && r.pendingAction != 'legacy_put')) {
        await sync();
        return;
      }
      if (_backupFlight != null && _backupOwner == owner) {
        return await _backupFlight!;
      }
      late final Future<void> task;
      task =
          _serial(owner, () async {
            if (!_canSend(owner)) return;
            try {
              await _finish(owner, await _flush(owner));
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
      () async {
        await _assertOwner(owner);
        await flushPending();
      }().catchError((Object _) {
        // 已切换身份的待发操作留在原 CID，不接收迟到结果。
      }),
    );
  }

  Future<ContactImportResult> addContact({
    required String cidNumber,
    String contactRemark = '',
  }) async {
    final owner = await _owner();
    final cid = requireCidNumber(cidNumber);
    final remark = normalizeContactRemark(contactRemark);
    if (cid == owner.cidNumber) {
      throw const FormatException('不能把自己加入通讯录');
    }
    final result = await _write(owner, (db) async {
      final rows = db.collection<store.Contact>();
      final prior = await rows.getByOwnerCidNumberCidNumber(
        owner.cidNumber,
        cid,
      );
      if (prior != null && !_authorizedDelete(prior) && prior.deleted != true) {
        return ContactImportResult(contact: _view(prior), created: false);
      }
      final row =
          prior ??
          (store.Contact()
            ..ownerCidNumber = owner.cidNumber
            ..cidNumber = cid);
      row.contactRemark = remark;
      row.pendingAction = 'put';
      row.deleted = false;
      await rows.put(row);
      return ContactImportResult(contact: _view(row), created: true);
    });
    if (result.created) await _afterMutation(owner);
    return result;
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
      if (row == null || _authorizedDelete(row) || row.deleted == true) {
        throw StateError('未找到联系人');
      }
      if (row.contactRemark == remark && row.pendingAction != 'legacy_put') {
        return;
      }
      changed = true;
      row.contactRemark = remark;
      if (row.deleted != null || row.pendingAction == 'legacy_put') {
        row.deleted = false;
      }
      row.pendingAction = 'put';
      await rows.put(row);
    });
    if (changed) await _afterMutation(owner);
    return _contacts(owner);
  }

  Future<List<UserContact>> deleteContact(
    String cidNumber, {
    required Future<Uint8List> Function(String, Uint8List) signer,
  }) => deleteContacts([cidNumber], signer: signer);

  Future<List<UserContact>> deleteContacts(
    List<String> cidNumbers, {
    required Future<Uint8List> Function(String, Uint8List) signer,
  }) async {
    if (_deleting) throw StateError('正在确认删除');
    _deleting = true;
    try {
      final owner = await _owner();
      await _tails[(_security, owner.cidNumber)];
      await _assertOwner(owner);
      final ids = cidNumbers.map(requireCidNumber).toSet().toList()..sort();
      if (ids.length > 128 || ids.contains(owner.cidNumber)) {
        throw const FormatException('删除名单无效');
      }
      var existing = {for (final r in await _rows(owner)) r.cidNumber: r};
      if (ids.any(
        (cid) =>
            existing[cid]?.deleted == null &&
            existing[cid] != null &&
            existing[cid]!.pendingAction != 'legacy_put',
      )) {
        await sync();
        existing = {for (final r in await _rows(owner)) r.cidNumber: r};
        if (ids.any(
          (cid) =>
              existing[cid] != null &&
              existing[cid]!.deleted == null &&
              existing[cid]!.pendingAction != 'legacy_put',
        )) {
          throw const AccountSecurityException('通讯录会话不可用');
        }
      }
      final targets = [
        for (final cid in ids)
          if (existing[cid] != null &&
              existing[cid]!.deleted != true &&
              !_authorizedDelete(existing[cid]!))
            existing[cid]!,
      ];
      if (targets.isEmpty) return await _contacts(owner);
      final random = Random.secure();
      final batchId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final intent = <String, dynamic>{
        'scope': deleteScope,
        'cid_number': owner.cidNumber,
        'account_id': owner.accountId,
        'bind_rev': owner.bindRev,
        'batch_id': batchId,
        'contacts': [
          for (final row in targets)
            {'cid_number': row.cidNumber, 'change_version': row.changeVersion},
        ],
      };
      final payload = Uint8List.fromList(utf8.encode(jsonEncode(intent)));
      final signature = await signer(owner.accountId, payload);
      if (!await CitizenSdk.verify(
        accountId: owner.accountId,
        signature: signature,
        payload: payload,
      )) {
        throw const AccountSecurityException('联系人删除签名无效');
      }
      await _assertOwner(owner);
      await _write(owner, (db) async {
        final collection = db.collection<store.Contact>();
        for (final sent in targets) {
          final current = await collection.getByOwnerCidNumberCidNumber(
            owner.cidNumber,
            sent.cidNumber,
          );
          if (current == null ||
              current.rowId != sent.rowId ||
              current.changeVersion != sent.changeVersion ||
              current.pendingAction != sent.pendingAction ||
              current.contactRemark != sent.contactRemark) {
            throw const AccountSecurityException('联系人已变化，请重新确认');
          }
        }
        final signed = {
          'intent': intent,
          'signature':
              '0x${signature.map((v) => v.toRadixString(16).padLeft(2, "0")).join()}',
        };
        await db.collection<store.ContactDeleteBatch>().put(
          store.ContactDeleteBatch()
            ..ownerCid = owner.cidNumber
            ..batchId = batchId
            ..data = jsonEncode(signed),
        );
        for (final row in targets) {
          row.pendingAction = 'delete';
          row.deleted = false;
          row.deleteBatch = batchId;
          await collection.put(row);
        }
      });
      await _afterMutation(owner);
      return await _contacts(owner);
    } finally {
      _deleting = false;
    }
  }

  Future<SquareApiException?> _replace(
    _Owner owner,
    Map<String, UserContact> incoming,
  ) => _write(owner, (db) async {
    SquareApiException? failure;
    final collection = db.collection<store.Contact>();
    final old = await collection
        .where()
        .ownerCidNumberEqualToAnyCidNumber(owner.cidNumber)
        .findAll();
    final existing = {for (final row in old) row.cidNumber: row};
    for (final row in old.where((r) => r.deleted == null)) {
      final cloud = incoming[row.cidNumber];
      if (row.pendingAction == 'delete' ||
          row.pendingAction == 'unsigned_delete') {
        if (cloud?.deleted == true) {
          _cloud(row, cloud!);
        } else {
          row.changeVersion = cloud?.changeVersion ?? 0;
          row.deleted = false;
          row.pendingAction = 'unsigned_delete';
          failure ??= _legacy;
        }
      } else if (cloud != null &&
          (row.pendingAction.isEmpty ||
              !cloud.deleted && row.contactRemark == cloud.contactRemark)) {
        _cloud(row, cloud);
      } else {
        row.changeVersion = cloud?.changeVersion ?? 0;
        row.pendingAction = 'legacy_put';
        // 保留旧库未备份内容；已有保存动作才能确认这条基线。
        failure ??= _legacy;
      }
      await collection.put(row);
    }
    for (final contact in incoming.values) {
      final prior = existing[contact.cidNumber];
      if (prior != null &&
          (prior.deleted == null ||
              contact.changeVersion <= prior.changeVersion)) {
        continue;
      }
      final row =
          prior ??
          (store.Contact()
            ..ownerCidNumber = owner.cidNumber
            ..cidNumber = contact.cidNumber);
      if (row.pendingAction.isNotEmpty) failure ??= _conflict;
      _cloud(row, contact);
      existing[contact.cidNumber] = row;
      await collection.put(row);
    }
    final batches = await db
        .collection<store.ContactDeleteBatch>()
        .where()
        .ownerCidEqualToAnyBatchId(owner.cidNumber)
        .findAll();
    final referenced = {
      for (final r in existing.values)
        if (r.deleteBatch.isNotEmpty) r.deleteBatch,
    };
    for (final batch in batches) {
      if (!referenced.contains(batch.batchId)) {
        await db.collection<store.ContactDeleteBatch>().delete(batch.id);
      }
    }
    return failure;
  });
  Future<Map<String, UserContact>> _download(_Owner owner) async {
    _state(ContactSyncPhase.syncing, resetPull: true);
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
          page['next_cursor'] != null && page['next_cursor'] is! String) {
        throw const FormatException('通讯录清单无效');
      }
      for (final raw in page['contacts'] as List) {
        final contact = UserContact.fromCloudJson(
          (raw as Map).cast<String, dynamic>(),
        );
        if (contact.cidNumber == owner.cidNumber ||
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
    return incoming;
  }

  Future<List<UserContact>> sync() async {
    final owner = await _owner();
    if (!_canSend(owner)) return _contacts(owner);
    if (_syncFlight != null && _syncOwner == owner) return _syncFlight!;
    late final Future<List<UserContact>> task;
    task =
        _serial(owner, () async {
          if (!_canSend(owner)) return _contacts(owner);
          var readingCloud = false;
          try {
            SquareApiException? failure;
            if ((await _rows(owner)).any((r) => r.deleted == null)) {
              readingCloud = true;
              final incoming = await _download(owner);
              failure = await _replace(owner, incoming);
              readingCloud = false;
              final sent = await _flush(owner);
              failure ??= sent;
            } else {
              failure = await _flush(owner);
              readingCloud = true;
              final merged = await _replace(owner, await _download(owner));
              failure ??= merged;
            }
            await _finish(owner, failure, restored: true);
          } on Object catch (error) {
            await _failed(owner, error, retryByPull: readingCloud);
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

  static String _requireOwnerAccountId(String value) {
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

// 从用户码取得CID并保存联系人，再交后台同步备份。

/// 用户码只提供联系人 CID；本机保存后才允许后台备份。
Future<ContactImportResult> addUserQrContact({
  required CitizenQrDocument body,
  required UserContactService contactService,
}) => contactService.addContact(cidNumber: body.cidNumber!);

String contactImportFailure(Object error) => switch (error) {
  FormatException(:final message) => message,
  AccountSecurityException() => '本机身份状态暂不可用，请稍后重试',
  SquareApiException() => SquareSessionResolution.fromError(error).message,
  _ => '联系人保存失败，请稍后重试',
};

// 校验联系人备注，并按汉字和字母生成稳定排序键。

/// 备注仅限汉字和英文字母；排序键不含时间或公开昵称。
String validateContactRemark(String value) {
  if (value.runes.length > 40 ||
      !RegExp(r'^[A-Za-z\p{Script=Han}]*$', unicode: true).hasMatch(value)) {
    throw const FormatException('备注只能输入中英文，最多40字，可留空');
  }
  return value;
}

String _phonetic(String value) => PinyinHelper.getPinyinE(
  value,
  separator: '',
  defPinyin: '#',
  format: PinyinFormat.WITHOUT_TONE,
).toUpperCase();

int compareContactKeys(
  String remarkA,
  String cidA,
  String remarkB,
  String cidB,
) {
  String key(String remark, String cid) {
    if (remark.isEmpty) {
      final first = RegExp(r'[0-9]').firstMatch(cid)?.group(0);
      return first == null ? '2$cid' : '0$first';
    }
    final pinyin = _phonetic(remark);
    return '1${pinyin.isEmpty ? '#' : pinyin.substring(0, 1)}';
  }

  var result = key(remarkA, cidA).compareTo(key(remarkB, cidB));
  if (result != 0) return result;
  result = _phonetic(remarkA).compareTo(_phonetic(remarkB));
  if (result != 0) return result;
  final nA = BigInt.tryParse(cidA), nB = BigInt.tryParse(cidB);
  return nA != null && nB != null ? nA.compareTo(nB) : cidA.compareTo(cidB);
}
