// 归并聊天原有回归，保留各来源用例、断言及独立生命周期。

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:chat/mls/native.dart';
import 'package:chat/mls/protocol.dart';
import 'package:chat/mls/store.dart';
import 'package:citizen_testing/chat/native.dart';
import 'package:flutter_test/flutter_test.dart';

// 验证MLS发送和接收中断后从原生持久状态恢复相同结果。

void _registerNativeSession() {
  requireMlsTestLibrary();
  test('MLS发送和接收在宿主落库前中断，重建后仍恢复相同结果', () async {
    final root = await Directory.systemTemp.createTemp('chat_native_session_');
    addTearDown(() => root.delete(recursive: true));
    Future<MlsStateStore> fixture(String user) async {
      final directory = await Directory('${root.path}/$user').create();
      final store = MlsStateStore(
        Directory(await directory.resolveSymbolicLinks()),
        ownerUserId: user,
      );
      await store.prepareIdentity();
      return store;
    }

    final aStore = await fixture('alice'), bStore = await fixture('bob');
    final aId = await aStore.readIdentity(), bId = await bStore.readIdentity();
    final a = MlsCrypto(identity: aId, stateStore: aStore),
        b = MlsCrypto(identity: bId, stateStore: bStore);
    final package = await b.createKeyPackage(bId, lastResort: true);
    await a.withMessage('create', () => a.createGroup('group'));
    final added = await a.withMessage(
      'add',
      () => a.addMembers('group', [package]),
    );
    await a.finishCommit('add', accepted: true);
    await b.withMessage('welcome', () => b.groupProcess(added.welcome!));
    // 群已建立后签认证证明，快照逐字不变；随后继续真实MLS发送和重启恢复。
    final snapshot = File('${aStore.path}/state.bin');
    final beforeAuthentication = await snapshot.readAsBytes();
    final authentication = await aStore.signAuthentication(
      accountId: '0x${List.filled(32, '11').join()}',
      bindingRevision: 1,
      request: MlsAuthenticationRequest(
        tokenPurpose: 'device',
        serviceOrigin: 'https://api.example.test',
        nonceId: '0x${List.filled(32, '22').join()}',
        expiresAt: DateTime.now().millisecondsSinceEpoch + 120000,
        httpMethod: 'POST',
        requestTarget: '/auth/session',
        bodyBytes: utf8.encode('synthetic request'),
      ),
    );
    expect(authentication.toJson()['device_id'], aId.deviceId);
    expect(await snapshot.readAsBytes(), beforeAuthentication);
    final first = await a.withMessage(
      'message-a',
      () => a.groupCreateMessage('group', utf8.encode('合成消息')),
    );
    final restarted = MlsCrypto(
      identity: await aStore.readIdentity(),
      stateStore: aStore,
    );
    final retry = await restarted.withMessage(
      'message-a',
      () => restarted.groupCreateMessage('group', utf8.encode('合成消息')),
    );
    expect(retry.wireHex, first.wireHex);
    final result = await b.withMessage(
      'message-b',
      () => b.groupProcess(first),
    );
    expect(utf8.decode(result.plaintext!), '合成消息');
    expect(result.senderMemberIdentity, 'alice:${aId.deviceId}');
    final restartedReceiver = MlsCrypto(
      identity: await bStore.readIdentity(),
      stateStore: bStore,
    );
    final recovered = await restartedReceiver.withMessage(
      'message-b',
      () => restartedReceiver.groupProcess(first),
    );
    expect(recovered.plaintext, result.plaintext);
    expect(recovered.senderMemberIdentity, result.senderMemberIdentity);
    await restartedReceiver.acknowledgeMessage('message-b');
    final duplicate = await restartedReceiver.withMessage(
      'message-b',
      () => restartedReceiver.groupProcess(first),
    );
    expect(duplicate.status, GroupProcessStatus.stale);
    expect(duplicate.committed, isTrue);
    expect(duplicate.plaintext, isNull);
    await expectLater(a.groupCreateMessage('group', [1]), throwsStateError);
    await expectLater(
      restarted.withMessage(
        'message-a',
        () => restarted.groupCreateMessage('group', [2]),
      ),
      throwsA(isA<MlsException>()),
    );
  });
}

// 通过真实FFI验证MLS身份复用、认证证明及损坏状态拒绝。

MlsAuthenticationRequest _authenticationRequest() => MlsAuthenticationRequest(
  tokenPurpose: 'device',
  serviceOrigin: 'https://api.example.test',
  nonceId: '0x${List.filled(32, '22').join()}',
  expiresAt: DateTime.now().millisecondsSinceEpoch + 120000,
  httpMethod: 'POST',
  requestTarget: '/auth/session?scope=chat',
  bodyBytes: [1, 2, 3],
);

void _registerNative() {
  requireMlsTestLibrary();
  test('原生诊断只公开固定码和操作，私密技术文本不进入用户提示', () {
    for (final entry in {
      'CHAT_MLS_REQUEST_CONFLICT:合成私密文本': MlsErrorCode.requestConflict,
      'CHAT_MLS_PENDING_FULL:合成私密文本': MlsErrorCode.pendingFull,
      '生成 OpenMLS KeyPackage 失败:合成私密文本': MlsErrorCode.keyPackageFailed,
      '未知合成私密文本': MlsErrorCode.operationFailed,
    }.entries) {
      final error = MlsException.fromTechnicalMessage(
        entry.key,
        operation: MlsOperation.keyPackage,
      );
      expect(error.code, entry.value);
      expect(error.diagnosticOperation, 'key_package');
      expect(error.diagnosticCode, isNot(contains('私密文本')));
      expect(error.userMessage, isNot(contains('私密文本')));
    }
  });
  test('真实FFI坏请求带精确操作名和固定分类', () {
    final bindings = MlsBindings.load();
    expect(
      () => bindings.callJson(bindings.createKeyPackage, {'unexpected': true}),
      throwsA(
        isA<MlsException>()
            .having((e) => e.code, 'code', MlsErrorCode.invalidRequest)
            .having((e) => e.operation, 'operation', MlsOperation.keyPackage),
      ),
    );
    expect(
      () => bindings.callJson(bindings.identity, {'unexpected': true}),
      throwsA(
        isA<MlsException>().having(
          (e) => e.operation,
          'operation',
          MlsOperation.identity,
        ),
      ),
    );
  });
  test('存储重开复用同一身份和同一KeyPackage', () async {
    final created = await Directory.systemTemp.createTemp('chat_persistence_');
    final root = Directory(await created.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    final directory = await Directory('${root.path}/before').create();
    final before = MlsStateStore(directory, ownerUserId: 'user-a');
    final identity = await before.prepareIdentity();
    final crypto = MlsCrypto(identity: identity, stateStore: before);
    final first = await crypto.createKeyPackage(identity, lastResort: true);
    before.dispose();
    final after = MlsStateStore(directory, ownerUserId: 'user-a');
    addTearDown(after.dispose);
    final restored = await after.readIdentity();
    expect(restored.deviceId, identity.deviceId);
    expect(restored.publicKey, identity.publicKey);
    final reopened = MlsCrypto(identity: restored, stateStore: after);
    final replay = await reopened.createKeyPackage(restored, lastResort: true);
    expect(replay.keyPackageRef, first.keyPackageRef);
    expect(replay.keyPackageHex, first.keyPackageHex);
    expect(replay.notBeforeMillis, first.notBeforeMillis);
    expect(replay.notAfterMillis, first.notAfterMillis);
  });
  test('KeyPackage只在已持久化的同一MLS身份上生成', () async {
    final root = await Directory.systemTemp.createTemp('chat_native_identity_');
    addTearDown(() => root.delete(recursive: true));
    final store = MlsStateStore(
      Directory(await root.resolveSymbolicLinks()),
      ownerUserId: 'user-a',
    );
    final identity = await store.prepareIdentity();
    final crypto = MlsCrypto(identity: identity, stateStore: store);
    final package = await crypto.createKeyPackage(identity, lastResort: true);
    final again = await crypto.createKeyPackage(
      await store.readIdentity(),
      lastResort: true,
    );
    expect(package.keyPackageHex, again.keyPackageHex);
    expect(package.lastResort, isTrue);
    expect(
      package.notAfterMillis - package.notBeforeMillis,
      (84 * 24 + 1) * 60 * 60 * 1000,
    );
    expect(identity.publicKey, matches(RegExp(r'^0x[0-9a-f]{64}$')));
    expect((await store.readIdentity()).deviceId, identity.deviceId);
    expect((await store.prepareIdentity()).deviceId, identity.deviceId);
    final wrongOwner = MlsStateStore(store.directory, ownerUserId: 'other');
    await expectLater(wrongOwner.readIdentity(), throwsA(isA<MlsException>()));
  });

  test('真实FFI认证复用MLS身份，重建后签名一致且不改快照', () async {
    final root = await Directory.systemTemp.createTemp('chat_native_auth_');
    addTearDown(() => root.delete(recursive: true));
    final directory = Directory(await root.resolveSymbolicLinks());
    final store = MlsStateStore(directory, ownerUserId: 'user-a');
    final identity = await store.prepareIdentity();
    final request = _authenticationRequest();
    final account = '0x${List.filled(32, '11').join()}';
    final snapshot = File('${directory.path}/state.bin');
    final before = await snapshot.readAsBytes();
    final proof = await store.signAuthentication(
      accountId: account,
      bindingRevision: 1,
      request: request,
    );
    store.dispose();
    final restarted = MlsStateStore(directory, ownerUserId: 'user-a');
    final again = await restarted.signAuthentication(
      accountId: account,
      bindingRevision: 1,
      request: request,
    );
    expect(again.toJson(), proof.toJson());
    expect(proof.toJson()['user_id'], identity.userId);
    expect(proof.toJson()['device_id'], identity.deviceId);
    expect(proof.toJson()['public_key'], identity.publicKey);
    expect(
      proof.toJson().keys,
      unorderedEquals([
        'user_id',
        'device_id',
        'public_key',
        'account_id',
        'bind_rev',
        'token_purpose',
        'service_origin',
        'nonce_id',
        'expires_at',
        'http_method',
        'request_target',
        'body_hash',
        'signature',
      ]),
    );
    expect(proof.toJson()['signature'], matches(RegExp(r'^0x[0-9a-f]{128}$')));
    expect(await snapshot.readAsBytes(), before);
    final wrongOwner = MlsStateStore(directory, ownerUserId: 'other');
    await expectLater(
      wrongOwner.signAuthentication(
        accountId: account,
        bindingRevision: 1,
        request: request,
      ),
      throwsA(isA<MlsException>()),
    );
  });

  test('认证缺状态或损坏时失败，禁止补身份或清空恢复', () async {
    final root = await Directory.systemTemp.createTemp('chat_native_auth_bad_');
    addTearDown(() => root.delete(recursive: true));
    final directory = Directory(await root.resolveSymbolicLinks());
    final store = MlsStateStore(directory, ownerUserId: 'user-a');
    await store.prepareIdentity();
    final snapshot = File('${directory.path}/state.bin');
    final request = _authenticationRequest();
    Future<MlsAuthenticationProof> sign() => store.signAuthentication(
      accountId: '0x${List.filled(32, '11').join()}',
      bindingRevision: 1,
      request: request,
    );
    await snapshot.writeAsString('synthetic corrupt state');
    await expectLater(sign(), throwsA(isA<MlsException>()));
    await expectLater(store.prepareIdentity(), throwsA(isA<MlsException>()));
    expect(await snapshot.readAsString(), 'synthetic corrupt state');
    await snapshot.delete();
    await expectLater(sign(), throwsA(isA<MlsException>()));
    await expectLater(store.prepareIdentity(), throwsA(isA<MlsException>()));
    expect(await snapshot.exists(), isFalse);
  });
  test('真实FFI拒绝错误属主后释放锁，主动重试继续使用原MLS身份和快照', () async {
    final temporary = await Directory.systemTemp.createTemp('chat_lock_retry_');
    final root = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    final store = MlsStateStore(root, ownerUserId: 'original-user');
    final identity = await store.prepareIdentity();
    final snapshot = File('${root.path}/state.bin');
    final before = await snapshot.readAsBytes();
    final wrong = MlsStateStore(root, ownerUserId: 'other-user');
    await expectLater(wrong.readIdentity(), throwsA(isA<MlsException>()));
    expect((await store.readIdentity()).deviceId, identity.deviceId);
    final proof = await store.signAuthentication(
      accountId: '0x${List.filled(32, '11').join()}',
      bindingRevision: 1,
      request: _authenticationRequest(),
    );
    expect(proof.toJson()['device_id'], identity.deviceId);
    expect(await snapshot.readAsBytes(), before);
  });
  test('空锁目录严格读取不生成身份，随后自动准备正常完成', () async {
    final temporary = await Directory.systemTemp.createTemp('chat_lock_empty_');
    final root = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/state.lock').writeAsBytes([]);
    final store = MlsStateStore(root, ownerUserId: 'existing-user');
    await expectLater(store.readIdentity(), throwsA(isA<MlsException>()));
    await expectLater(store.readIdentity(), throwsA(isA<MlsException>()));
    expect(await File('${root.path}/state.bin').exists(), isFalse);
    final identity = await store.prepareIdentity();
    expect((await store.readIdentity()).deviceId, identity.deviceId);
  });
  test('既有空目录自动准备、回执中断复用、已交付缺失不换钥', () async {
    final temp = await Directory.systemTemp.createTemp('chat_phase_');
    final root = Directory(await temp.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    final store = MlsStateStore(root, ownerUserId: 'phase-user');
    final first = await store.prepareIdentity();
    final before = await File('${root.path}/state.bin').readAsBytes();
    await File('${root.path}/state.lock')
        .writeAsString('initializing\n', flush: true);
    expect((await store.prepareIdentity()).deviceId, first.deviceId);
    expect(await File('${root.path}/state.bin').readAsBytes(), before);
    await File('${root.path}/state.bin').delete();
    await expectLater(
      store.prepareIdentity(),
      throwsA(
        isA<MlsException>().having(
          (e) => e.code,
          'code',
          MlsErrorCode.stateMissing,
        ),
      ),
    );
    expect(await File('${root.path}/state.bin').exists(), isFalse);
  });
  test('同CID三设备移除只影响指定叶子，伪造KeyPackage登记身份拒绝', () async {
    final temporary = await Directory.systemTemp.createTemp('mls_leaf_');
    final root = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    final devices = <ChatDevice>[], cryptos = <MlsCrypto>[];
    for (var index = 0; index < 3; index++) {
      final directory = await Directory('${root.path}/$index').create();
      final store = MlsStateStore(directory, ownerUserId: 'CID-A');
      final identity = await store.prepareIdentity();
      devices.add(identity);
      cryptos.add(MlsCrypto(identity: identity, stateStore: store));
    }
    final b = await cryptos[1].createKeyPackage(devices[1], lastResort: true);
    final c = await cryptos[2].createKeyPackage(devices[2], lastResort: true);
    await cryptos[0].withMessage(
      'create',
      () => cryptos[0].createGroup('exact-leaves'),
    );
    final forged = MlsKeyPackage(
      userId: 'CID-A',
      deviceId: devices[1].deviceId,
      keyPackageRef: c.keyPackageRef,
      keyPackageBytes: c.keyPackageBytes,
      cipherSuite: c.cipherSuite,
      notBeforeMillis: c.notBeforeMillis,
      notAfterMillis: c.notAfterMillis,
      lastResort: true,
    );
    await expectLater(
      cryptos[0].withMessage(
        'forged',
        () => cryptos[0].addMembers('exact-leaves', [forged]),
      ),
      throwsA(isA<MlsException>()),
    );
    expect((await cryptos[0].groupState('exact-leaves')).memberCount, 1);
    final added = await cryptos[0].withMessage(
      'add',
      () => cryptos[0].addMembers('exact-leaves', [b, c]),
    );
    await cryptos[0].finishCommit('add', accepted: true);
    for (var index = 1; index < 3; index++) {
      await cryptos[index].withMessage(
        'welcome',
        () => cryptos[index].groupProcess(added.welcome!),
      );
    }
    final target = 'CID-A:${devices[1].deviceId}';
    await expectLater(
      cryptos[0].withMessage(
        'duplicate-remove',
        () => cryptos[0].removeMembers('exact-leaves', [target, target]),
      ),
      throwsA(isA<MlsException>()),
    );
    await expectLater(
      cryptos[0].withMessage(
        'unknown-remove',
        () => cryptos[0].removeMembers('exact-leaves', [
          target,
          'CID-A:${'00' * 32}',
        ]),
      ),
      throwsA(isA<MlsException>()),
    );
    expect((await cryptos[0].groupState('exact-leaves')).memberCount, 3);
    final removed = await cryptos[0].withMessage(
      'remove',
      () => cryptos[0].removeMembers('exact-leaves', [target]),
    );
    await cryptos[0].finishCommit('remove', accepted: true);
    expect(removed.removedMemberIdentities, [target]);
    final accepted = await cryptos[2].withMessage(
      'commit',
      () => cryptos[2].groupProcess(removed.commit),
    );
    expect(accepted.selfRemoved, false);
    expect(accepted.senderMemberIdentity, 'CID-A:${devices[0].deviceId}');
    expect(
      (await cryptos[2].groupState('exact-leaves')).memberIdentities,
      unorderedEquals(
        [
          devices[0],
          devices[2],
        ].map((identity) => 'CID-A:${identity.deviceId}'),
      ),
    );
  });
}

// 核对本轮真实动态库导出全部声明聊天C接口。

void _registerSymbol() {
  test('本轮独立动态库真实导出头文件中的全部聊天FFI接口', () {
    final file = Platform.environment['MLS_TEST_LIBRARY'];
    expect(file, isNotNull, reason: '必须由本产品测试入口交付本轮真实原生库');
    final library = DynamicLibrary.open(file!);
    final header = File('chat/mls/mls.h').readAsStringSync();
    final names = RegExp(r'\b(mls_[a-z_]+)\s*\(')
        .allMatches(header)
        .map((value) => value.group(1)!)
        .toSet();
    expect(names.length, 10);
    for (final name in names) {
      expect(
        library.lookup<NativeFunction<Void Function()>>(name).address,
        isNot(0),
        reason: name,
      );
    }
    for (final name in [
      'mls_rekey_state_json',
      'mls_two_party_smoke_json',
      'mls_device_identity_json',
      'mls_encrypt_json',
      'mls_decrypt_json',
    ]) {
      expect(
        () => library.lookup<NativeFunction<Void Function()>>(name),
        throwsArgumentError,
        reason: '禁止重新导出退役接口$name',
      );
    }
  });
}

void main() {
  group("mls/native_session_test", _registerNativeSession);
  group("mls/native_test", _registerNative);
  group("mls/symbol_test", _registerSymbol);
}
