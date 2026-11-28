// 归并广场原有回归，保留各来源用例、断言及独立生命周期。

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_network/auth.dart' show bytesToHex, hexToBytes;
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_square/post/store.dart';
import 'package:citizen_testing/chat/authentication.dart';
import 'package:citizen_testing/chat/runtime.dart';
import 'package:citizen_testing/sdk.dart';
import 'package:citizen_user/api.dart'
    show
        SquareAccountDeletionPendingException,
        SquareActionSigner,
        SquareApiClient,
        SquareApiException;
import 'package:citizen_user/context.dart' show IdentityBinding;
import 'package:citizen_user/identity/session.dart'
    show MlsAuthenticationException;
import 'package:citizen_user/profile/data.dart'
    show CitizenProfileCache, CitizenProfileMediaCache;
import 'package:citizen_user/profile/data.dart'
    show SquareAccountDeletionService, SquareAccountLocalCleanupException;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// 验证账户动作签名范围及无会话只读恢复，拒绝错误完成回执。

const _accountId =
    '0x625e25364c7b68e0a83065ccb40afed43f8fe933e669b24f3d69a57eddb3b715';
const _cidNumber = 'CN220-CTZN2-198805200-2026';
const _binding = IdentityBinding(
  genesisHash:
      '0x3333333333333333333333333333333333333333333333333333333333333333',
  cidNumber: _cidNumber,
  bindRev: 1,
  accountId: _accountId,
);
const _nonce =
    '1111111111111111111111111111111111111111111111111111111111111111';

// 独立夹具按公开合同构造SCALE字节，不调用产品私有payload方法。
Map<String, dynamic> challenge(String purpose) {
  final expiry = DateTime.now().millisecondsSinceEpoch + 240000;
  final out = BytesBuilder();
  void string(String value) {
    final raw = utf8.encode(value);
    out.addByte(raw.length << 2);
    out.add(raw);
  }

  void u64(int value) {
    final d = ByteData(8)..setUint64(0, value, Endian.little);
    out.add(d.buffer.asUint8List());
  }

  string('citizenserve.account_deletion');
  string('https://square.test');
  out.add(hexToBytes(_binding.genesisHash));
  string(_cidNumber);
  out.add(hexToBytes(_accountId));
  u64(1);
  out.addByte(purpose == 'delete' ? 0 : 1);
  out.add(hexToBytes(_nonce));
  u64(expiry);
  return {
    'is_ok': true,
    'token_purpose': purpose,
    'nonce_id': _nonce,
    'cid_number': _cidNumber,
    'account_id': _accountId,
    'bind_rev': 1,
    'chain_scope': _binding.genesisHash,
    'service_origin': 'https://square.test',
    'expires_at': expiry,
    'sign_hex': '0x${bytesToHex(out.takeBytes())}',
  };
}

Map<String, Object?> receipt(String state) => {
  'is_ok': true,
  'cid_number': _cidNumber,
  'account_id': _accountId,
  'bind_rev': 1,
  'deletion_id': state == 'absent' ? null : _nonce,
  'state': state,
};
http.Response json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
SquareApiClient client(Future<http.Response> Function(http.Request) business) =>
    SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/user/sessions') {
          return json(
            fakeMlsSession(
              cidNumber: _cidNumber,
              accountId: _accountId,
              token: 'sqs_test',
            ),
          );
        }
        return business(request);
      }),
    );
Future<void> login(SquareApiClient api) => api
    .ensureSession(
      accountId: _accountId,
      authentication: FakeMlsAuthentication(
        cidNumber: _cidNumber,
        accountId: _accountId,
      ),
    )
    .then((_) {});

void _registerSquareAccountAction() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestCitizenSdkHarness();
  setUp(() async {
    SquareApiClient.activateFinalizedBinding(
      cidNumber: _cidNumber,
      bindRev: 1,
      accountId: _accountId,
    );
  });

  test('submit requires MLS, returns pending, then wallet-only status recovers completion', () async {
    final submitted = <String>[];
    final signed = <Uint8List>[];
    final payloads = <String>[];
    final api = client((request) async {
      submitted.add(request.url.path);
      if (request.url.path == '/api/user/deletion/challenges') {
        expect(request.headers['authorization'], 'Bearer sqs_test');
        expect(request.headers['x-mls-proof'], isNotNull);
        expect(jsonDecode(request.body), {});
        final c = challenge('delete');
        payloads.add(c['sign_hex'] as String);
        return json(c);
      }
      if (request.url.path == '/api/user/deletion') {
        expect(request.headers['x-mls-proof'], isNotNull);
        expect(jsonDecode(request.body), {
          'nonce_id': _nonce,
          'signature': '0xSIG',
        });
        return json(receipt('pending'), 202);
      }
      if (request.url.path == '/api/user/deletion/status/challenges') {
        expect(request.headers['authorization'], isNull);
        expect(request.headers['x-mls-proof'], isNull);
        expect(jsonDecode(request.body), {
          'cid_number': _cidNumber,
          'account_id': _accountId,
        });
        final c = challenge('status');
        payloads.add(c['sign_hex'] as String);
        return json(c);
      }
      if (request.url.path == '/api/user/deletion/status') {
        expect(request.headers['authorization'], isNull);
        return json(receipt('complete'));
      }
      return http.Response('not found', 404);
    });
    await login(api);
    Future<String> signer(Uint8List message) async {
      signed.add(message);
      return '0xSIG';
    }

    await expectLater(
      api.deleteAccount(binding: _binding, signAction: signer),
      throwsA(isA<SquareAccountDeletionPendingException>()),
    );
    await api.deleteAccount(binding: _binding, signAction: signer);
    expect(submitted, [
      '/api/user/deletion/challenges',
      '/api/user/deletion',
      '/api/user/deletion/status/challenges',
      '/api/user/deletion/status',
    ]);
    for (var i = 0; i < signed.length; i++) {
      final expected = await CitizenSdk.encodePayload(
        CitizenSigningPayload.message(
          opTag: kOpSignSquareAction,
          scalePayload: hexToBytes(payloads[i]),
        ),
      );
      expect(bytesToHex(signed[i]), bytesToHex(expected));
    }
    expect(bytesToHex(signed[0]), isNot(bytesToHex(signed[1])));
  });

  test('a new client recovers pending without a session and never creates a deletion', () async {
    final paths = <String>[];
    final api = client((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/challenges')) {
        return json(challenge('status'));
      }
      return json(receipt('pending'));
    });
    await expectLater(
      api.deleteAccount(binding: _binding, signAction: (_) async => '0xSIG'),
      throwsA(isA<SquareAccountDeletionPendingException>()),
    );
    expect(paths, [
      '/api/user/deletion/status/challenges',
      '/api/user/deletion/status',
    ]);
  });

  test('lost acceptance with a stale session switches only to read-only wallet recovery', () async {
    final paths = <String>[];
    final api = client((request) async {
      paths.add(request.url.path);
      if (request.url.path == '/api/user/deletion/challenges') {
        return json({'error_code': 'invalid_session'}, 401);
      }
      if (request.url.path == '/api/user/deletion/status/challenges') {
        return json(challenge('status'));
      }
      return json(receipt('complete'));
    });
    await login(api);
    await api.deleteAccount(
      binding: _binding,
      signAction: (_) async => '0xSIG',
    );
    expect(paths, [
      '/api/user/deletion/challenges',
      '/api/user/deletion/status/challenges',
      '/api/user/deletion/status',
    ]);
  });

  test('foreign binding, scope, purpose, expiry and opaque payload are rejected before signing', () async {
    final changes = <Map<String, Object?>>[
      {'cid_number': 'OTHER-CID'},
      {'account_id': '0x${List.filled(32, '22').join()}'},
      {'bind_rev': 2},
      {'chain_scope': '0x${List.filled(32, '44').join()}'},
      {'service_origin': 'https://other.test'},
      {'token_purpose': 'delete'},
      {'expires_at': 1},
      {'sign_hex': '0x00'},
      {'op_tag': 0x99},
      {'nonce_id': '../other'},
    ];
    for (final change in changes) {
      var signed = false;
      final api = client(
        (_) async => json({...challenge('status'), ...change}),
      );
      await expectLater(
        api.deleteAccount(
          binding: _binding,
          signAction: (_) async {
            signed = true;
            return '0xSIG';
          },
        ),
        throwsA(isA<SquareApiException>()),
      );
      expect(signed, isFalse);
    }
  });

  test(
    'binding changed during wallet signing prevents submitting the old intent',
    () async {
      var submits = 0;
      final api = client((request) async {
        if (request.url.path.endsWith('/challenges')) {
          return json(challenge('status'));
        }
        submits++;
        return json(receipt('complete'));
      });
      await expectLater(
        api.deleteAccount(
          binding: _binding,
          signAction: (_) async {
            SquareApiClient.activateFinalizedBinding(
              cidNumber: _cidNumber,
              bindRev: 2,
              accountId: _accountId,
            );
            return '0xSIG';
          },
        ),
        throwsA(isA<SquareApiException>()),
      );
      expect(submits, 0);
    },
  );

  test('wrong completion receipt never permits local cleanup; absent is not complete', () async {
    for (final result in [
      receipt('complete')..['cid_number'] = 'OTHER-CID',
      receipt('complete')..['deletion_id'] = 'bad',
      receipt('absent'),
    ]) {
      final api = client(
        (request) async => json(
          request.url.path.endsWith('/challenges')
              ? challenge('status')
              : result,
        ),
      );
      await expectLater(
        api.deleteAccount(binding: _binding, signAction: (_) async => '0xSIG'),
        throwsA(isA<SquareApiException>()),
      );
    }
  });
  test('finalized 换绑立即清除旧会话，并拒绝换绑后才返回的旧握手', () async {
    const newAccountId =
        '0x2222222222222222222222222222222222222222222222222222222222222222';
    SquareApiClient.activateFinalizedBinding(
      cidNumber: _cidNumber,
      bindRev: 1,
      accountId: _accountId,
    );
    final cachedClient = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(
            fakeMlsSession(
              cidNumber: _cidNumber,
              accountId: _accountId,
              token: 'cached-token',
            ),
          ),
          200,
        );
      }),
    );
    await cachedClient.ensureSession(
      accountId: _accountId,
      authentication: FakeMlsAuthentication(
        cidNumber: _cidNumber,
        accountId: _accountId,
      ),
    );

    final sessionRequested = Completer<void>();
    final sessionResponse = Completer<http.Response>();
    final lateClient = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        sessionRequested.complete();
        return sessionResponse.future;
      }),
    );
    final late = lateClient.ensureSession(
      accountId: _accountId,
      authentication: FakeMlsAuthentication(
        cidNumber: _cidNumber,
        accountId: _accountId,
      ),
    );
    final rejectedLate = expectLater(
      late,
      throwsA(isA<MlsAuthenticationException>()),
    );
    await sessionRequested.future;

    SquareApiClient.activateFinalizedBinding(
      cidNumber: _cidNumber,
      bindRev: 2,
      accountId: newAccountId,
    );
    sessionResponse.complete(
      http.Response(
        jsonEncode(
          fakeMlsSession(
            cidNumber: _cidNumber,
            accountId: _accountId,
            token: 'late-token',
          ),
        ),
        200,
      ),
    );

    await expectLater(
      cachedClient.deleteAccount(
        binding: _binding,
        signAction: (_) async => '0xSIG',
      ),
      throwsA(isA<SquareApiException>()),
    );
    await rejectedLate;
  });
}

// 验证远端注销确认后完整本地清理，未知或失败时保留数据。

const _owner =
    '0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d';
const _deletionCidNumber = 'CN001-CTZN-000000001-2026';
const _deletionBinding = IdentityBinding(
  genesisHash:
      '0x3333333333333333333333333333333333333333333333333333333333333333',
  cidNumber: _deletionCidNumber,
  bindRev: 1,
  accountId: _owner,
);

class _FakeApi extends SquareApiClient {
  _FakeApi({this.fail = false, this.pending = false});
  final bool pending;
  final bool fail;
  bool deleteCalled = false;
  bool sessionCleared = false;
  bool signerInvoked = false;

  @override
  Future<void> deleteAccount({
    required IdentityBinding binding,
    Future<void> Function()? requireCurrent,
    required SquareActionSigner signAction,
  }) async {
    deleteCalled = true;
    await signAction(Uint8List(32)); // 触发一次签名器，模拟真实往返
    signerInvoked = true;
    if (fail) throw const SquareApiException('服务端删除失败');
    if (pending) throw const SquareAccountDeletionPendingException();
  }

  @override
  void clearSession(String accountId) {
    sessionCleared = true;
  }
}

class _FakeCache extends CitizenProfileCache {
  _FakeCache() : super();
  String? clearedCidNumber;
  @override
  Future<void> clear(String cidNumber) async {
    clearedCidNumber = cidNumber;
  }
}

class _FakeMediaCache extends CitizenProfileMediaCache {
  String? clearedCidNumber;

  @override
  Future<void> clearCid(String cidNumber) async {
    clearedCidNumber = cidNumber;
  }
}

class _FakeChatRuntime extends TestChatRuntime {
  _FakeChatRuntime() : super(host: _UnusedChatHost());

  bool cleared = false;
  String? erasedCid;
  String? erasedAccount;
  int eraseCalls = 0;
  @override
  Future<void> clearAllForUserId({
    required String userId,
    required String accountId,
  }) async {
    cleared = true;
    erasedCid = userId;
    erasedAccount = accountId;
    eraseCalls++;
  }
}

class _UnusedChatHost implements ChatRuntimeFixture {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocalPostStore implements SquareLocalPostBulkDeletionStore {
  _FakeLocalPostStore({this.fail = false});

  final bool fail;
  bool cleared = false;
  String? deletedCidNumber;

  @override
  Future<int> deleteAllByCid(String cidNumber) async {
    cleared = true;
    deletedCidNumber = cidNumber;
    if (fail) throw StateError('本地副本清理失败');
    return 2;
  }
}

void _registerSquareAccountDeletionService() {
  test('注销成功：服务端删后清齐所有本地数据', () async {
    final api = _FakeApi();
    final cache = _FakeCache();
    final mediaCache = _FakeMediaCache();
    final chatRuntime = _FakeChatRuntime();
    final localPostStore = _FakeLocalPostStore();
    final service = SquareAccountDeletionService(
      apiClient: api,
      profileCache: cache,
      profileMediaCache: mediaCache,
      localPostStore: localPostStore,
      clearChatHistory: (chatRuntime).clearAllForUserId,
    );

    await service.deleteAccount(
      binding: _deletionBinding,
      signAction: (_) async => '0xSIG',
    );

    expect(api.deleteCalled, isTrue);
    expect(api.signerInvoked, isTrue);
    expect(cache.clearedCidNumber, _deletionCidNumber);
    expect(cache.clearedCidNumber, isNot(_owner));
    expect(mediaCache.clearedCidNumber, _deletionCidNumber);
    expect(api.sessionCleared, isTrue);
    expect(chatRuntime.cleared, isTrue);
    expect(chatRuntime.eraseCalls, 1);
    expect(chatRuntime.erasedCid, _deletionCidNumber);
    expect(chatRuntime.erasedAccount, _owner);
    expect(localPostStore.cleared, isTrue);
    expect(localPostStore.deletedCidNumber, _deletionCidNumber);
  });

  test('服务端删除失败：本地一律不动（数据一致）', () async {
    final api = _FakeApi(fail: true);
    final cache = _FakeCache();
    final mediaCache = _FakeMediaCache();
    final chatRuntime = _FakeChatRuntime();
    final localPostStore = _FakeLocalPostStore();
    final service = SquareAccountDeletionService(
      apiClient: api,
      profileCache: cache,
      profileMediaCache: mediaCache,
      localPostStore: localPostStore,
      clearChatHistory: (chatRuntime).clearAllForUserId,
    );

    await expectLater(
      service.deleteAccount(
        binding: _deletionBinding,
        signAction: (_) async => '0xSIG',
      ),
      throwsA(isA<SquareApiException>()),
    );

    expect(cache.clearedCidNumber, isNull);
    expect(mediaCache.clearedCidNumber, isNull);
    expect(api.sessionCleared, isFalse);
    expect(chatRuntime.cleared, isFalse);
    expect(localPostStore.cleared, isFalse);
  });

  test('服务端删除成功后即使副本清理失败，其他本地清理仍全部尝试', () async {
    final api = _FakeApi();
    final cache = _FakeCache();
    final mediaCache = _FakeMediaCache();
    final chatRuntime = _FakeChatRuntime();
    final localPostStore = _FakeLocalPostStore(fail: true);
    final service = SquareAccountDeletionService(
      apiClient: api,
      profileCache: cache,
      profileMediaCache: mediaCache,
      localPostStore: localPostStore,
      clearChatHistory: (chatRuntime).clearAllForUserId,
    );

    await expectLater(
      service.deleteAccount(
        binding: _deletionBinding,
        signAction: (_) async => '0xSIG',
      ),
      throwsA(isA<SquareAccountLocalCleanupException>()),
    );

    expect(localPostStore.cleared, isTrue);
    expect(cache.clearedCidNumber, _deletionCidNumber);
    expect(mediaCache.clearedCidNumber, _deletionCidNumber);
    expect(api.sessionCleared, isTrue);
    expect(chatRuntime.cleared, isTrue);
    expect(chatRuntime.eraseCalls, 1);
    expect(chatRuntime.erasedCid, _deletionCidNumber);
    expect(chatRuntime.erasedAccount, _owner);
  });

  test(
    'pending receipt keeps all local data and the chat runtime intact',
    () async {
      final api = _FakeApi(pending: true);
      final cache = _FakeCache();
      final media = _FakeMediaCache();
      final chat = _FakeChatRuntime();
      final posts = _FakeLocalPostStore();
      final service = SquareAccountDeletionService(
        apiClient: api,
        profileCache: cache,
        profileMediaCache: media,
        localPostStore: posts,
        clearChatHistory: (chat).clearAllForUserId,
      );
      await expectLater(
        service.deleteAccount(
          binding: _deletionBinding,
          signAction: (_) async => '0xSIG',
        ),
        throwsA(isA<SquareAccountDeletionPendingException>()),
      );
      expect(cache.clearedCidNumber, isNull);
      expect(media.clearedCidNumber, isNull);
      expect(api.sessionCleared, isFalse);
      expect(chat.eraseCalls, 0);
      expect(posts.cleared, isFalse);
    },
  );
}

void main() {
  group("square_account_action_test", _registerSquareAccountAction);
  group(
    "square_account_deletion_service_test",
    _registerSquareAccountDeletionService,
  );
}
