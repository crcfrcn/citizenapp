import 'dart:typed_data';
import 'package:citizenapp/security/identity_binding.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:citizenapp/8964/profile/citizen_profile_cache.dart';
import 'package:citizenapp/8964/services/square_account_deletion_service.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/8964/services/square_post_store.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

const _owner =
    '0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d';
const _cidNumber = 'CN001-CTZN-000000001-2026';
const _binding=IdentityBinding(genesisHash:'0x3333333333333333333333333333333333333333333333333333333333333333',cidNumber:_cidNumber,bindingRevision:1,accountId:_owner);

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

class _FakeChatRuntime extends ChatSdk {
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

class _UnusedChatHost implements ChatRuntimeHost {
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

void main() {
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
      chatRuntime: chatRuntime,
      localPostStore: localPostStore,
    );

    await service.deleteAccount(
      binding: _binding,
      signAction: (_) async => '0xSIG',
    );

    expect(api.deleteCalled, isTrue);
    expect(api.signerInvoked, isTrue);
    expect(cache.clearedCidNumber, _cidNumber);
    expect(cache.clearedCidNumber, isNot(_owner));
    expect(mediaCache.clearedCidNumber, _cidNumber);
    expect(api.sessionCleared, isTrue);
    expect(chatRuntime.cleared, isTrue);
    expect(chatRuntime.eraseCalls, 1);
    expect(chatRuntime.erasedCid, _cidNumber);
    expect(chatRuntime.erasedAccount, _owner);
    expect(localPostStore.cleared, isTrue);
    expect(localPostStore.deletedCidNumber, _cidNumber);
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
      chatRuntime: chatRuntime,
      localPostStore: localPostStore,
    );

    await expectLater(
      service.deleteAccount(
        binding: _binding,
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
      chatRuntime: chatRuntime,
      localPostStore: localPostStore,
    );

    await expectLater(
      service.deleteAccount(
        binding: _binding,
        signAction: (_) async => '0xSIG',
      ),
      throwsA(isA<SquareAccountLocalCleanupException>()),
    );

    expect(localPostStore.cleared, isTrue);
    expect(cache.clearedCidNumber, _cidNumber);
    expect(mediaCache.clearedCidNumber, _cidNumber);
    expect(api.sessionCleared, isTrue);
    expect(chatRuntime.cleared, isTrue);
    expect(chatRuntime.eraseCalls, 1);
    expect(chatRuntime.erasedCid, _cidNumber);
    expect(chatRuntime.erasedAccount, _owner);
  });

  test('pending receipt keeps all local data and the chat runtime intact',()async{
    final api=_FakeApi(pending:true);final cache=_FakeCache();final media=_FakeMediaCache();
    final chat=_FakeChatRuntime();final posts=_FakeLocalPostStore();
    final service=SquareAccountDeletionService(apiClient:api,profileCache:cache,profileMediaCache:media,chatRuntime:chat,localPostStore:posts);
    await expectLater(service.deleteAccount(binding:_binding,signAction:(_)async=>'0xSIG'),throwsA(isA<SquareAccountDeletionPendingException>()));
    expect(cache.clearedCidNumber,isNull);expect(media.clearedCidNumber,isNull);
    expect(api.sessionCleared,isFalse);expect(chat.eraseCalls,0);expect(posts.cleared,isFalse);
  });
}
