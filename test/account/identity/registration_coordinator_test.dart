import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/account/identity/registration_api.dart';
import 'package:citizenapp/account/identity/registration_models.dart';
import 'package:citizenapp/account/identity/registration_store.dart';
import 'package:citizenapp/account/identity/registration_coordinator.dart';
import 'package:citizenapp/account/identity/identity_binding.dart';

import 'registration_api_test.dart'
    show registrationContext, registrationResponse;

class MemoryStore extends RegistrationStore {
  RegistrationRecord? value;
  bool fail = false;
  final List<String> events;
  MemoryStore(this.events);
  @override
  Future<RegistrationRecord?> read(RegistrationContext c) async => value;
  @override
  Future<void> save(
    RegistrationRecord? previous,
    RegistrationRecord next,
  ) async {
    if (fail || !identical(value, previous)) throw StateError('CAS refused');
    events.add('save:${next.phase.name}:${next.response.jobState.name}');
    value = next;
  }
}

class Api extends RegistrationApi {
  final List<String> events;
  String jobState = 'prepared';
  int pages = 0;
  bool failStatus = false;
  bool acceptVerification = true;
  Api(this.events);
  RegistrationResponse response(
    RegistrationContext c, {
    bool initial = false,
  }) => RegistrationResponse.parse(
    registrationResponse(c, jobState: jobState, initial: initial),
    c,
    initial: initial,
  );
  @override
  Future<RegistrationResponse> prepare(RegistrationContext c) async {
    events.add('prepare');
    return response(c, initial: true);
  }

  @override
  Future<RegistrationResponse> verify(
    RegistrationContext c,
    RegistrationCapabilities cap, {
    required String checkId,
    required String token,
  }) async {
    events.add('verify');
    jobState = acceptVerification ? 'human_verified' : 'prepared';
    return response(c);
  }

  @override
  Future<RegistrationResponse> status(
    RegistrationContext c,
    RegistrationCapabilities cap, {
    String operation = 'read',
  }) async {
    events.add('status:$operation');
    if (failStatus) throw StateError('offline');
    if (operation == 'refresh_verification') pages++;
    return response(c);
  }
}

void main() {
  late List<String> events;
  late MemoryStore store;
  late Api api;
  late RegistrationCoordinator coordinator;
  late FinalizedRegistration finalized;
  FinalizedRegistration? chain;
  bool cancel = false, activateFail = false, changed = false;
  int wallets = 0, pages = 0;
  var activatedDevice = "33" * 32;
  setUp(() {
    events = [];
    store = MemoryStore(events);
    api = Api(events);
    coordinator = RegistrationCoordinator(api: api, store: store);
    finalized = FinalizedRegistration(
      binding: IdentityBinding(
        genesisHash: registrationContext().chainScope,
        cidNumber: 'CN220-CTZN2-100000001-2026',
        bindRev: 1,
        accountId: registrationContext().accountId,
      ),
      chainHash: '0x${'aa' * 32}',
    );
    chain = null;
    cancel = false;
    activateFail = false;
    changed = false;
    activatedDevice = "33" * 32;
    wallets = 0;
    pages = 0;
  });
  Future<FinalizedRegistration> run() => coordinator.run(
    context: registrationContext(),
    requireCurrent: () async {
      if (changed) throw StateError('account changed');
    },
    showVerification: (_) async {
      expect(coordinator.isRegistering, true);
      expect(coordinator.activeBinding, isNull);
      pages++;
      events.add('page');
      return cancel ? null : 'valid-ephemeral-token';
    },
    requireAffordable: () async {
      events.add('balance');
    },
    readFinalized: () async => chain,
    registerCid: (save) async {
      wallets++;
      events.add('wallet');
      await save({
        'state': 'executing',
        'account_id': registrationContext().accountId,
        'call_data_hash': '0x${'55' * 32}',
      });
      chain = finalized;
      return finalized;
    },
    activate: (result) async {
      events.add('activate');
      expect(coordinator.activeBinding, result.binding);
      if (activateFail) throw StateError('timeout');
      api.jobState = 'activated';
      return activatedDevice;
    },
  );
  test('已有公民号零登记API、零真人验证、零费用及占号', () async {
    chain = finalized;
    api.failStatus = true;
    expect(await run(), finalized);
    expect(events, ['activate']);
    expect(pages, 0);
    expect(wallets, 0);
    expect(store.value, isNull);
  });
  test('服务器通过和两次保护保存先于余额/原钱包；成功只弹一次', () async {
    await run();
    expect(pages, 1);
    expect(wallets, 1);
    expect(coordinator.isRegistering, false);
    expect(coordinator.activeBinding, isNull);
    expect(store.value?.phase, RegistrationPhase.ready);
    expect(
      events.indexOf('save:verification:prepared'),
      lessThan(events.indexOf('page')),
    );
    expect(
      events.indexOf('save:verified:humanVerified'),
      lessThan(events.indexOf('balance')),
    );
    expect(events.indexOf('balance'), lessThan(events.indexOf('wallet')));
    expect(
      events.indexOf('save:finalized:humanVerified'),
      lessThan(events.indexOf('activate')),
    );
  });
  test('激活回执必须对应实际普通会话的同一MLS设备', () async {
    activatedDevice = '44' * 32;
    await expectLater(
      run(),
      throwsA(
        isA<RegistrationException>().having(
          (e) => e.code,
          'code',
          'activation_pending',
        ),
      ),
    );
    expect(store.value?.phase, RegistrationPhase.finalized);
    expect(wallets, 1);
  });
  test('链读取异常不准备登记、不弹真人验证或占号', () async {
    await expectLater(
      coordinator.run(
        context: registrationContext(),
        requireCurrent: () async {},
        showVerification: (_) async {
          pages++;
          return 'token';
        },
        requireAffordable: () async {
          events.add('balance');
        },
        readFinalized: () async =>
            throw StateError('synthetic network failure'),
        registerCid: (_) async {
          wallets++;
          return finalized;
        },
        activate: (_) async => '33' * 32,
      ),
      throwsStateError,
    );
    expect(events, isEmpty);
    expect(pages, 0);
    expect(wallets, 0);
  });
  test('finalized恢复不依赖过期或故障的登记服务', () async {
    activateFail = true;
    await expectLater(run(), throwsA(isA<RegistrationException>()));
    activateFail = false;
    events.clear();
    api.failStatus = true;
    await run();
    expect(
      events.where(
        (e) =>
            e.startsWith('status') ||
            e == 'prepare' ||
            e == 'page' ||
            e == 'wallet',
      ),
      isEmpty,
    );
    expect(
      store.value!.response.jobState,
      RegistrationState.humanVerified,
      reason: '只更新本机阶段，不能伪造服务器activated',
    );
    expect(store.value!.phase, RegistrationPhase.ready);
  });
  test('Turnstile未被服务器确认通过，零余额读取和链交易', () async {
    api.acceptVerification = false;
    await expectLater(run(), throwsA(isA<RegistrationException>()));
    expect(pages, 1);
    expect(events, isNot(contains('balance')));
    expect(wallets, 0);
    expect(store.value!.phase, RegistrationPhase.verification);
  });
  test('取消和保存失败：钱包/余额均为零', () async {
    cancel = true;
    await expectLater(run(), throwsA(isA<RegistrationException>()));
    expect(wallets, 0);
    expect(events, isNot(contains('balance')));
    store.fail = true;
    cancel = false;
    await expectLater(run(), throwsStateError);
    expect(wallets, 0);
  });
  test('finalized后激活失败：重启读服务器和链；不重新验证/注册', () async {
    activateFail = true;
    await expectLater(
      run(),
      throwsA(
        isA<RegistrationException>().having(
          (e) => e.code,
          'code',
          'activation_pending',
        ),
      ),
    );
    activateFail = false;
    coordinator = RegistrationCoordinator(api: api, store: store);
    await run();
    expect(pages, 1);
    expect(wallets, 1);
    expect(store.value?.phase, RegistrationPhase.ready);
  });
  test('明确未进入SDKexecute的失败可恢复同一验证，未知异常保持pending', () async {
    await expectLater(
      coordinator.run(
        context: registrationContext(),
        requireCurrent: () async {},
        showVerification: (_) async => 'ephemeral-token',
        requireAffordable: () async {},
        readFinalized: () async => null,
        registerCid: (_) async =>
            throw const RegistrationBeforeBroadcastException(),
        activate: (_) async => '33' * 32,
      ),
      throwsA(isA<RegistrationBeforeBroadcastException>()),
    );
    expect(store.value?.phase, RegistrationPhase.verified);
    await run();
    expect(pages, 0);
    expect(wallets, 1);
  });
  test('恢复保留原交易区块；新finalized头不能覆盖已保存回执', () async {
    activateFail = true;
    await expectLater(run(), throwsA(isA<RegistrationException>()));
    chain = FinalizedRegistration(
      binding: finalized.binding,
      chainHash: '0x${'99' * 32}',
    );
    activateFail = false;
    await run();
    expect(store.value?.finalized?.chainHash, finalized.chainHash);
    expect(wallets, 1);
  });
  test('未知广播和网络未知都禁止重发', () async {
    cancel = true;
    await expectLater(run(), throwsA(isA<RegistrationException>()));
    cancel = false;
    api.jobState = 'human_verified';
    store.value = store.value!.next(
      response: api.response(registrationContext()),
      phase: RegistrationPhase.chainPending,
    );
    await expectLater(run(), throwsA(isA<RegistrationException>()));
    expect(wallets, 0);
    api.failStatus = true;
    await expectLater(run(), throwsStateError);
    expect(wallets, 0);
  });
  test('同上下文在途合并；账户变化后不签名', () async {
    final gate = Completer<void>();
    final first = coordinator.run(
      context: registrationContext(),
      requireCurrent: () async {
        await gate.future;
        if (changed) throw StateError('changed');
      },
      showVerification: (_) async => null,
      requireAffordable: () async {},
      readFinalized: () async => null,
      registerCid: (_) async {
        wallets++;
        return finalized;
      },
      activate: (_) async => '33' * 32,
    );
    final same = run();
    expect(identical(first, same), true);
    changed = true;
    gate.complete();
    await expectLater(first, throwsStateError);
    expect(wallets, 0);
  });
}
