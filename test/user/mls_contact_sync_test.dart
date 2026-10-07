import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizenapp/8964/profile/services/square_session_provider.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/citizen/shared/account_derivation.dart';
import 'package:citizenapp/my/myid/current_user_context.dart';
import 'package:citizenapp/my/myid/citizen_identity_chain_reader.dart';
import 'package:citizenapp/my/user/contact_service.dart';
import 'package:citizenapp/security/account_security_service.dart';
import 'package:citizenapp/security/identity_binding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

import '../support/fake_citizen_sdk.dart';
import '../support/isar_test_env.dart';

const _owner = 'CID-A';
const _account =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _binding = IdentityBinding(
  genesisHash:
      '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  cidNumber: _owner,
  bindingRevision: 1,
  accountId: _account,
);

class _Security implements AccountSecurityService {
  @override
  Future<IdentityBinding?> readIdentityBindingForCid(String cid) async =>
      _binding;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Current implements CurrentUserContext {
  bool changed = false;
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: 0,
      accountId: _account,
      ss58Address: ss58FromAccountIdText(_account),
      name: 'owner',
      createdAtMillis: BigInt.one,
      isDefault: true,
    ),
    binding: changed ? null : _binding,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Host implements ChatRuntimeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Runtime extends ChatSdk {
  _Runtime() : super(host: _Host());
  final incoming = <List<int>>[];
  final sent = <List<int>>[];
  Future<void> Function()? beforeApply;
  @override
  Future<List<List<int>>> synchronizeContacts({
    required ContactMlsExchange exchange,
    required Future<List<List<int>>> Function() snapshots,
    required ContactMlsApply apply,
  }) async {
    for (final payload in incoming) {
      await beforeApply?.call();
      await apply(payload);
    }
    sent.addAll(await snapshots());
    return List<List<int>>.from(sent);
  }
}

class _Sessions implements SquareSessionProvider {
  _Sessions(this.runtime);
  final _Runtime runtime;
  Object? failure;
  @override
  ChatSdk get mlsRuntime => runtime;
  @override
  Future<SquareSession?> ensureSession() async {
    if (failure != null) throw failure!;
    return SquareSession(
      deviceId: '11' * 32,
      sessionToken: 'token',
      cidNumber: _owner,
      bindingRevision: 1,
      accountId: _account,
      expiresAt: 4102444800000,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  useIsolatedIsar();
  // 同样的失败在有无待发记录时都必须保持真实类别；失败不能消费待同步操作。
  for (final withPending in [false, true]) {
    for (final failure in <Object>[
      const SocketException('合成断网'),
      TimeoutException('合成超时'),
      const SquareApiException(
        '不应保存的合成服务正文',
        statusCode: 404,
        stage: SquareApiStage.challenge,
      ),
      const SquareApiException(
        '合成认证拒绝',
        statusCode: 401,
        errorCode: 'invalid_mls_signature',
        stage: SquareApiStage.session,
      ),
    ]) {
      test('同步${failure.runtimeType}待发=$withPending分类准确并保留记录', () async {
        final sessions = _Sessions(_Runtime());
        sessions.failure = failure;
        final service = UserContactService(
          accountSecurity: _Security(),
          currentUserContext: _Current(),
          sessionProvider: sessions,
          chainReader: CitizenIdentityChainReader(chain: TestCitizenChain()),
          autoSync: false,
        );
        if (withPending) {
          await service.addContact(
            cidNumber: 'CID-B',
            ss58Address: ss58FromAccountIdText('0x${'22' * 32}'),
            contactRemark: '合成备注',
          );
        }
        final before = await service.getContacts();
        final after = await service.sync();
        expect(after.length, before.length);
        final state = await service.readSyncState();
        final network =
            failure is SocketException || failure is TimeoutException;
        expect(
          state.phase,
          network ? ContactSyncPhase.offline : ContactSyncPhase.failed,
        );
        expect(state.message, isNot(contains('合成服务正文')));
        if (failure is SquareApiException) {
          expect(state.statusCode, failure.statusCode);
          expect(state.stage, failure.stage);
        }
        sessions.failure = null;
        await service.sync();
        expect((await service.readSyncState()).phase, ContactSyncPhase.synced);
        final snapshot = jsonDecode(
          utf8.decode(sessions.runtime.sent.single),
        ) as Map<String, dynamic>;
        expect(snapshot['records'], hasLength(withPending ? 1 : 0));
        await sessions.runtime.close();
      });
    }
  }
  test('本地删除保存墓碑，MLS快照重放不复活联系人', () async {
    final runtime = _Runtime(), current = _Current();
    final service = UserContactService(
      accountSecurity: _Security(),
      currentUserContext: current,
      sessionProvider: _Sessions(runtime),
      chainReader: CitizenIdentityChainReader(chain: TestCitizenChain()),
      autoSync: false,
    );
    final contact = await service.addContact(
      cidNumber: 'CID-B',
      ss58Address: ss58FromAccountIdText('0x${'22' * 32}'),
      contactRemark: '备注',
    );
    final old = utf8.encode(
      jsonEncode({
        'type': 'contacts',
        'owner_cid_number': _owner,
        'records': [
          {
            'cid_number': 'CID-B',
            'updated_at': contact.contact.updatedAt,
            'contact': contact.contact.toJson(),
          },
        ],
      }),
    );
    await service.deleteContact('CID-B');
    runtime.incoming.add(old);
    expect(await service.sync(), isEmpty);
    final snapshot =
        jsonDecode(utf8.decode(runtime.sent.single)) as Map<String, dynamic>;
    expect((snapshot['records'] as List).single['contact'], isNull);
    expect((await service.readSyncState()).phase, ContactSyncPhase.synced);
    await runtime.close();
  });
  test('接收期间当前CID变化，不能把晚回结果写入其他身份', () async {
    final runtime = _Runtime(), current = _Current();
    final service = UserContactService(
      accountSecurity: _Security(),
      currentUserContext: current,
      sessionProvider: _Sessions(runtime),
      chainReader: CitizenIdentityChainReader(chain: TestCitizenChain()),
      autoSync: false,
    );
    runtime.incoming.add(
      utf8.encode(
        jsonEncode({
          'type': 'contacts',
          'owner_cid_number': _owner,
          'records': [],
        }),
      ),
    );
    runtime.beforeApply = () async {
      current.changed = true;
    };
    await expectLater(service.sync(), throwsA(isA<AccountSecurityException>()));
    expect(runtime.sent, isEmpty);
    await runtime.close();
  });
}
