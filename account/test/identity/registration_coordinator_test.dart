import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_account/identity/identity_binding.dart';
import 'package:citizen_account/identity/registration_api.dart';
import 'package:citizen_account/identity/registration_coordinator.dart';
import 'package:citizen_account/identity/registration_models.dart';
import 'package:citizen_account/identity/registration_store.dart';
import 'registration_api_test.dart' show registrationContext, verification;

class Api extends RegistrationApi {
  Api(this.events);
  final List<String> events;
  bool acceptVerification = true;
  @override
  Future<void> verify(RegistrationContext c, RegistrationVerification v) async {
    events.add('siteverify');
    if (!acceptVerification) {
      throw const RegistrationException('未通过', code: 'verification_failed');
    }
  }
}

class MemoryStore extends RegistrationStore {
  MemoryStore(this.events);
  final List<String> events;
  RegistrationRecord? value;
  bool failWrite = false;
  @override
  Future<RegistrationRecord?> read(RegistrationContext c) async => value;
  @override
  Future<void> save(
    RegistrationRecord? previous,
    RegistrationRecord next,
  ) async {
    if (failWrite) throw StateError('storage');
    if (value != previous) throw StateError('CAS');
    RegistrationRecord.decode(next.encode());
    value = next;
    events.add(next.finalized == null ? 'checkpoint' : 'finalized');
  }
}

/// Widget业务测试只替换人验页面交付，不跳过实际Siteverify编排。
class VerifiedCoordinator extends RegistrationCoordinator {
  VerifiedCoordinator({required super.api, required super.store});
  @override
  Future<FinalizedRegistration> run({
    required RegistrationContext context,
    required Future<void> Function() requireCurrent,
    required Future<RegistrationVerification?> Function() showVerification,
    required Future<void> Function() requireAffordable,
    required Future<FinalizedRegistration?> Function() readFinalized,
    required Future<FinalizedRegistration> Function(
      Future<void> Function(Map<String, dynamic>),
    )
    registerCid,
    Future<bool> Function(Map<String, dynamic>?)? canRetryChain,
    required Future<void> Function(FinalizedRegistration) report,
  }) => super.run(
    context: context,
    requireCurrent: requireCurrent,
    showVerification: () async => verification(),
    requireAffordable: requireAffordable,
    readFinalized: readFinalized,
    registerCid: registerCid,
    canRetryChain: canRetryChain,
    report: report,
  );
}

FinalizedRegistration chainResult() => FinalizedRegistration(
  binding: IdentityBinding(
    genesisHash: registrationContext().chainScope,
    cidNumber: 'CN220-CTZN2-100000001-2026',
    bindRev: 1,
    accountId: registrationContext().accountId,
  ),
  blockHash: '0x${'aa' * 32}',
  txHash: '0x${'bb' * 32}',
);
void main() {
  late List<String> events;
  late Api api;
  late MemoryStore store;
  late RegistrationCoordinator coordinator;
  int wallets = 0, reports = 0, pages = 0;
  bool exists = false, failReport = false, cancel = false, guardOk = true;
  Future<FinalizedRegistration> run() => coordinator.run(
    context: registrationContext(),
    requireCurrent: () async {
      if (!guardOk) throw StateError('account changed');
    },
    showVerification: () async {
      pages++;
      events.add('page');
      return cancel ? null : verification();
    },
    requireAffordable: () async {
      events.add('balance');
    },
    readFinalized: () async {
      events.add('chain');
      return exists ? chainResult() : null;
    },
    registerCid: (save) async {
      final point = {
        'preparation_id': 'prepared-id',
        'account_id': registrationContext().accountId,
        'call_data_hash': '0x${'cc' * 32}',
        'state': 'prepared',
      };
      await save(point);
      await save({...point, 'state': 'executing'});
      wallets++;
      events.add('wallet');
      exists = true;
      return chainResult();
    },
    canRetryChain: (_) async => false,
    report: (_) async {
      reports++;
      events.add('report');
      if (failReport) throw StateError('offline');
    },
  );
  setUp(() {
    events = [];
    api = Api(events);
    store = MemoryStore(events);
    coordinator = RegistrationCoordinator(api: api, store: store);
    wallets = reports = pages = 0;
    exists = failReport = cancel = false;
    guardOk = true;
  });
  tearDown(() => api.close());
  test('一次人验通过后原交易，最终结果落盘后才报告，无登记状态', () async {
    final result = await run();
    expect(result.binding.cidNumber, chainResult().binding.cidNumber);
    expect(wallets, 1);
    expect(reports, 1);
    expect(pages, 1);
    expect(events.indexOf('siteverify'), lessThan(events.indexOf('balance')));
    expect(events.indexOf('balance'), lessThan(events.indexOf('wallet')));
    expect(events.indexOf('finalized'), lessThan(events.indexOf('report')));
    final encoded = store.value!.encode();
    for (final text in [
      'reg_id',
      'recovery_token',
      'human_verified',
      'turnstile_token',
      'context_hash',
      'job_state',
    ]) {
      expect(encoded, isNot(contains(text)));
    }
  });
  test('人验失败与取消均零链交易、零报告、零存储', () async {
    api.acceptVerification = false;
    await expectLater(run(), throwsA(isA<RegistrationException>()));
    expect(wallets, 0);
    expect(reports, 0);
    expect(store.value, isNull);
    api.acceptVerification = true;
    cancel = true;
    await expectLater(run(), throwsA(isA<RegistrationException>()));
    expect(events.where((e) => e == 'siteverify'), hasLength(1));
    expect(wallets, 0);
  });
  test('上报失败保留真实finalized，再试不重新人验或签名注册', () async {
    failReport = true;
    await expectLater(
      run(),
      throwsA(
        isA<RegistrationException>().having(
          (e) => e.code,
          '代码',
          'report_pending',
        ),
      ),
    );
    expect(store.value!.finalized, isNotNull);
    failReport = false;
    await run();
    expect(wallets, 1);
    expect(pages, 1);
    expect(reports, 2);
    expect(store.value!.finalized!.blockHash, chainResult().blockHash);
  });
  test('未知执行只恢复原交易，不再人验或签名', () async {
    store.value = RegistrationRecord(
      context: registrationContext(),
      checkpoint: {
        'preparation_id': 'p',
        'execution_id': 'e',
        'account_id': registrationContext().accountId,
        'call_data_hash': '0x${'cc' * 32}',
        'state': 'executing',
      },
    );
    await expectLater(
      run(),
      throwsA(
        isA<RegistrationException>().having(
          (e) => e.code,
          '代码',
          'chain_pending',
        ),
      ),
    );
    expect(pages, 0);
    expect(wallets, 0);
    expect(reports, 0);
  });
  test('链读取失败与本机检查点失败不进入钱包签名', () async {
    await expectLater(
      coordinator.run(
        context: registrationContext(),
        requireCurrent: () async {},
        showVerification: () async {
          pages++;
          return verification();
        },
        requireAffordable: () async {},
        readFinalized: () async => throw StateError('chain offline'),
        registerCid: (_) async {
          wallets++;
          return chainResult();
        },
        report: (_) async {
          reports++;
        },
      ),
      throwsStateError,
    );
    expect(pages, 0);
    store.failWrite = true;
    await expectLater(run(), throwsStateError);
    expect(wallets, 0);
    expect(reports, 0);
  });
  test('已有公民号只报告，账户变化停止后续动作', () async {
    exists = true;
    await run();
    expect(pages, 0);
    expect(wallets, 0);
    expect(reports, 1);
    guardOk = false;
    await expectLater(run(), throwsStateError);
    expect(reports, 1);
  });
  test('同一账户在途合并，结束后释放', () async {
    final gate = Completer<void>();
    var calls = 0;
    Future<FinalizedRegistration> call() => coordinator.run(
      context: registrationContext(),
      requireCurrent: () async {},
      showVerification: () async => verification(),
      requireAffordable: () async {},
      readFinalized: () async {
        await gate.future;
        return chainResult();
      },
      registerCid: (_) async => throw StateError('unexpected'),
      report: (_) async {
        calls++;
      },
    );
    final first = call(), second = call();
    expect(identical(first, second), true);
    expect(coordinator.isRegistering, true);
    gate.complete();
    await Future.wait([first, second]);
    expect(calls, 1);
    expect(coordinator.isRegistering, false);
  });
}
