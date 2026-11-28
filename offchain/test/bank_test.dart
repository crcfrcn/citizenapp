// 验证绑定缓存与清算行设置。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen_offchain/bank.dart' show ClearingBankBindingSnapshot, ClearingBankPrefs;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';
import 'package:citizen_offchain/chain.dart' show OnchainClearingBankChain;
import 'package:citizen_offchain/settings.dart' show BindClearingBankPage;
import 'package:citizen_offchain/balance.dart' show DepositPage;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:citizen_offchain/settings.dart' show ClearingBankSettingsPage;
import 'package:citizen_offchain/bank.dart' show ClearingBankBinding, ClearingBankCandidate, ClearingBankDirectory, ClearingBankNodeEndpoint;
import 'package:citizen_testing/sdk.dart';

void main() {
  group('clearing_bank_prefs_test', _registerPrefs);
  group('clearing_bank_settings_page_test', _registerSettings);
}

// 验证清算快照账户隔离、WSS端点及写入和删除失败回读。

const _accountA =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _accountB =
    '0x2222222222222222222222222222222222222222222222222222222222222222';
const _mainAccountId =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _feeAccountId =
    '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

ClearingBankBindingSnapshot _snapshot({
  required String cidNumber,
  String mainAccountId = _mainAccountId,
  String feeAccountId = _feeAccountId,
  String rpcDomain = '127.0.0.1',
}) {
  return ClearingBankBindingSnapshot(
    cidNumber: cidNumber,
    fullName: '测试清算行',
    shortName: '测试清算行',
    mainAccountId: mainAccountId,
    feeAccountId: feeAccountId,
    peerId: '12D3KooWTest',
    rpcDomain: rpcDomain,
    rpcPort: 9944,
    boundAtMs: 1,
    lastVerifiedAtMs: 2,
  );
}

void _registerPrefs() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ClearingBankPrefs.debugRemoveForTest = null;
    ClearingBankPrefs.debugSetForTest = null;
  });

  tearDown(() {
    ClearingBankPrefs.debugRemoveForTest = null;
    ClearingBankPrefs.debugSetForTest = null;
  });

  group('ClearingBankPrefs', () {
    test('loadSnapshot returns null when key absent', () async {
      expect(await ClearingBankPrefs.loadSnapshot(_accountA), isNull);
    });

    test('完整快照按 account_id 隔离', () async {
      await ClearingBankPrefs.saveSnapshot(
        _accountA,
        _snapshot(cidNumber: 'GD001-SCB05-000000001-2026'),
      );
      await ClearingBankPrefs.saveSnapshot(
        _accountB,
        _snapshot(cidNumber: 'BJ001-SCB0U-000000002-2026'),
      );
      expect(
        (await ClearingBankPrefs.loadSnapshot(_accountA))?.cidNumber,
        'GD001-SCB05-000000001-2026',
      );
      expect(
        (await ClearingBankPrefs.loadSnapshot(_accountB))?.cidNumber,
        'BJ001-SCB0U-000000002-2026',
      );
    });

    test('写入返回 false 时抛错，不得伪装缓存已更新', () async {
      ClearingBankPrefs.debugSetForTest = (_, _, _) async => false;
      await expectLater(
        ClearingBankPrefs.saveSnapshot(_accountA, _snapshot(cidNumber: 'AAA')),
        throwsStateError,
      );
      expect(await ClearingBankPrefs.loadSnapshot(_accountA), isNull);
    });

    test('clear removes only the specified account_id', () async {
      await ClearingBankPrefs.saveSnapshot(
        _accountA,
        _snapshot(cidNumber: 'AAA'),
      );
      await ClearingBankPrefs.saveSnapshot(
        _accountB,
        _snapshot(cidNumber: 'BBB'),
      );
      await ClearingBankPrefs.clear(_accountA);
      expect(await ClearingBankPrefs.loadSnapshot(_accountA), isNull);
      expect(
        (await ClearingBankPrefs.loadSnapshot(_accountB))?.cidNumber,
        'BBB',
      );
    });

    test('clear 在 remove=false 时抛错，不得伪装已删除', () async {
      await ClearingBankPrefs.saveSnapshot(
        _accountA,
        _snapshot(cidNumber: 'REMOVE-FALSE'),
      );
      ClearingBankPrefs.debugRemoveForTest = (_, _) async => false;

      await expectLater(
        ClearingBankPrefs.clear(_accountA),
        throwsA(isA<StateError>()),
      );
      expect(await ClearingBankPrefs.loadSnapshot(_accountA), isNotNull);
    });

    test('clear 回读前并发重建键时抛错，上层不得 ack', () async {
      await ClearingBankPrefs.saveSnapshot(
        _accountA,
        _snapshot(cidNumber: 'BEFORE-REAPPEAR'),
      );
      ClearingBankPrefs.debugRemoveForTest = (prefs, key) async {
        final removed = await prefs.remove(key);
        await prefs.setString(key, '{"cid_number":"REAPPEARED"}');
        return removed;
      };

      await expectLater(
        ClearingBankPrefs.clear(_accountA),
        throwsA(isA<StateError>()),
      );
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'clearing_bank_binding_$_accountA',
        ),
        isTrue,
      );
    });

    test('saveSnapshot overwrites previous value (切换清算行)', () async {
      await ClearingBankPrefs.saveSnapshot(
        _accountA,
        _snapshot(cidNumber: 'OLD'),
      );
      await ClearingBankPrefs.saveSnapshot(
        _accountA,
        _snapshot(cidNumber: 'NEW'),
      );
      expect(
        (await ClearingBankPrefs.loadSnapshot(_accountA))?.cidNumber,
        'NEW',
      );
    });

    test('saveSnapshot stores endpoint data', () async {
      await ClearingBankPrefs.saveSnapshot(
        _accountA,
        _snapshot(cidNumber: 'GD001-SCB05-000000001-2026'),
      );

      final snapshot = await ClearingBankPrefs.loadSnapshot(_accountA);
      expect(snapshot, isNotNull);
      expect(snapshot!.cidNumber, 'GD001-SCB05-000000001-2026');
      expect(snapshot.wssUrl, 'wss://127.0.0.1:9944');
      expect(snapshot.mainAccountId, _mainAccountId);
      expect(snapshot.feeAccountId, _feeAccountId);
    });

    // 端点经过持久化再读取仍须保持WSS，本机和局域网不提供明文例外。
    for (final domain in [
      '127.0.0.1',
      'localhost',
      '192.168.1.10',
      'clearing.test',
    ]) {
      test('清算行快照读回 $domain 端点仍使用WSS', () async {
        await ClearingBankPrefs.saveSnapshot(
          _accountA,
          _snapshot(cidNumber: 'TEST-CLEARING', rpcDomain: domain),
        );
        final snapshot = await ClearingBankPrefs.loadSnapshot(_accountA);
        expect(snapshot, isNotNull);
        expect(snapshot!.wssUrl, 'wss://$domain:9944');
        final endpoint = ClearingBankNodeEndpoint(
          cidNumber: 'TEST-CLEARING',
          peerId: '12D3KooWTest',
          rpcDomain: domain,
          rpcPort: 9944,
          registeredAt: 1,
          registeredBy: _mainAccountId,
        );
        expect(endpoint.wssUrl, snapshot.wssUrl);
      });
    }

    test('缺少费用账户的旧快照必须拒绝', () async {
      SharedPreferences.setMockInitialValues({
        'clearing_bank_binding_$_accountA':
            '{"cid_number":"GD001-SCB05-000000001-2026",'
            '"main_account_id":"$_mainAccountId",'
            '"rpc_domain":"127.0.0.1","rpc_port":9944}',
      });
      expect(await ClearingBankPrefs.loadSnapshot(_accountA), isNull);
    });
  });
}

// 验证清算目录、同块绑定和节点读取及Runtime调用编码。

const _bankA = 'GD001-SCB01-000000001-2026';
const _bankB = 'GD001-SCB01-000000002-2026';

void _registerSettings() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => ClearingBankPrefs.debugSetForTest = null);

  const accountId =
      '0x0000000000000000000000000000000000000000000000000000000000000000';

  test('绑定和切换按 Runtime metadata 编码机构 CID', () async {
    final runtime = await CitizenSdkTestFixture.runtimeContext(
      _block(CitizenBlockFinality.best),
    );
    final stop = StateError('只验证交易准备前的字节');
    Uint8List? encoded;
    final chain = OnchainClearingBankChain(
      buildCall: (pallet, method, fields) async =>
          runtime.encodeCall(pallet, method, fields),
      prepareTransaction: (_, callData) async {
        encoded = callData;
        throw stop;
      },
    );
    for (final (submit, index) in [
      (chain.bindClearingBank, 30),
      (chain.switchBank, 33),
    ]) {
      for (final bankCid in [_bankA, 'A' * 32]) {
        final bytes = utf8.encode(bankCid);
        await expectLater(
          submit(
            signerPublicKey: Uint8List(32),
            bankCid: bankCid,
            externalSigning: (_) async => fail('本测试不签名'),
          ),
          throwsA(same(stop)),
        );
        expect(encoded, [19, index, bytes.length << 2, ...bytes]);
      }
      encoded = null;
      for (final bankCid in ['', '清' * 11, accountId]) {
        await expectLater(
          submit(
            signerPublicKey: Uint8List(32),
            bankCid: bankCid,
            externalSigning: (_) async => fail('无效 CID 不应签名'),
          ),
          throwsArgumentError,
        );
        expect(encoded, isNull);
      }
    }
  });

  test('从同一 finalized 块读取 CID，区分无绑定和损坏值', () async {
    final block = _block(CitizenBlockFinality.finalized);
    final runtime = await CitizenSdkTestFixture.runtimeContext(block);
    final key = runtime.storageKey('Offchain', 'UserBank', [
      citizenAccountIdBytes(accountId),
    ]);
    final other = citizenAccountIdFromBytes(Uint8List.fromList(List.filled(32, 1)));
    final otherKey = runtime.storageKey('Offchain', 'UserBank', [
      citizenAccountIdBytes(other),
    ]);
    var reads = 0;
    var heads = 0;
    final bytes = utf8.encode(_bankA);
    Uint8List? raw;
    final directory = ClearingBankDirectory(
      getFinalizedHead: () async {
        heads++;
        return block;
      },
      getRuntimeContext: (at) async {
        expect(at, same(block));
        return runtime;
      },
      getStorage: (at, actualKey) async {
        expect(at, same(block));
        reads++;
        if (listEquals(actualKey, otherKey)) return null;
        expect(actualKey, key);
        return raw;
      },
    );
    expect(await directory.fetchUserBankCid(accountId), isNull);
    raw = Uint8List.fromList([bytes.length << 2, ...bytes]);
    expect(await directory.fetchUserBankCid(accountId), _bankA);
    expect(await directory.fetchUserBankCid(other), isNull);
    expect(key, isNot(otherKey));
    final before = (heads, reads);
    await expectLater(directory.fetchUserBankCid('invalid'), throwsFormatException);
    expect((heads, reads), before);
    for (final malformed in [
      <int>[],
      [bytes.length << 2, ...bytes, 0],
      [4, 0xff],
    ]) {
      raw = Uint8List.fromList(malformed);
      await expectLater(
        directory.fetchUserBankCid(accountId),
        throwsFormatException,
      );
    }
  });

  test('当前绑定和节点同块读取，缺节点不得视为未绑定', () async {
    final block = _block(CitizenBlockFinality.finalized);
    final runtime = await CitizenSdkTestFixture.runtimeContext(block);
    final accountKey = runtime.storageKey('Offchain', 'UserBank', [
      citizenAccountIdBytes(accountId),
    ]);
    final nodeKey = runtime.storageKey('Offchain', 'ClearingBankNodes', [
      Uint8List.fromList(utf8.encode(_bankB)),
    ]);
    List<int> text(String value) => [utf8.encode(value).length << 2, ...utf8.encode(value)];
    var reads = 0;
    var heads = 0;
    var bound = true;
    Uint8List? node = Uint8List.fromList([
      ...text('peer'),
      ...text('new.example'),
      187, 1, 1, 0, 0, 0,
      ...List.filled(32, 3),
    ]);
    final directory = ClearingBankDirectory(
      getFinalizedHead: () async { heads++; return block; },
      getRuntimeContext: (at) async {
        expect(at, same(block));
        return runtime;
      },
      getStorage: (at, key) async {
        expect(at, same(block));
        reads++;
        if (listEquals(key, accountKey)) {
          return bound ? Uint8List.fromList(text(_bankB)) : null;
        }
        expect(key, nodeKey);
        return node;
      },
    );
    final verified = await directory.fetchUserBank(accountId);
    expect(verified?.endpoint.cidNumber, _bankB);
    expect(verified?.endpoint.wssUrl, 'wss://new.example:443');
    expect(verified?.title, _bankB);
    expect((heads, reads), (1, 2));
    for (final invalid in [null, Uint8List.fromList([4, 0xff])]) {
      node = invalid;
      await expectLater(directory.fetchUserBank(accountId), throwsStateError);
    }
    bound = false;
    final before = reads;
    expect(await directory.fetchUserBank(accountId), isNull);
    expect(reads, before + 1);
  });

  test('清算充值和提现由 Runtime 编码为普通 u128 分', () async {
    final block = CitizenBlockRef(
      hash: '0x${'ab' * 32}',
      number: BigInt.one,
      finality: CitizenBlockFinality.best,
    );
    final runtime = await CitizenSdkTestFixture.runtimeContext(block);
    final stop = StateError('只验证交易准备前的字节');
    late Uint8List encoded;
    final chain = OnchainClearingBankChain(
      buildCall: (pallet, method, fields) async =>
          runtime.encodeCall(pallet, method, fields),
      prepareTransaction: (_, callData) async {
        encoded = callData;
        throw stop;
      },
    );
    for (final (submit, index) in [(chain.deposit, 31), (chain.withdraw, 32)]) {
      await expectLater(
        submit(
          signerPublicKey: Uint8List(32),
          amountFen: BigInt.from(0x1234),
          externalSigning: (_) async => fail('本测试不签名'),
        ),
        throwsA(same(stop)),
      );
      expect(encoded, [19, index, 0x34, 0x12, ...List.filled(14, 0)]);
    }
  });

  testWidgets('renders AppBar title, search field and empty hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClearingBankSettingsPage(
          accountId: accountId,
          directory: (() {
            final reads0 = TestChainReads();
            return ClearingBankDirectory(
              getFinalizedHead: reads0.getFinalizedHead,
              getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
              getStorage: reads0.getStorage,
              getStorageKeysPaged: reads0.getStorageKeysPaged,
              getStorageBatch: reads0.getStorageBatch,
            );
          })(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置清算行'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('搜索清算行'), findsOneWidget);
    expect(find.text('暂无结果'), findsOneWidget);
  });

  testWidgets('清除本地快照后仍按链上绑定切换', (tester) async {
    final directory = _SettingsDirectory()..boundCid = _bankA;
    final bank = directory.banks.first;
    await ClearingBankPrefs.saveSnapshot(
      accountId,
      ClearingBankBindingSnapshot(
        cidNumber: bank.cidNumber,
        fullName: bank.fullName,
        shortName: '',
        mainAccountId: accountId.substring(2),
        feeAccountId: accountId.substring(2),
        peerId: bank.endpoint.peerId,
        rpcDomain: bank.endpoint.rpcDomain,
        rpcPort: bank.endpoint.rpcPort,
        boundAtMs: 1,
        lastVerifiedAtMs: 1,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ClearingBankSettingsPage(
          accountId: accountId,
          directory: directory,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除缓存'));
    await tester.pumpAndSettle();
    expect(await ClearingBankPrefs.loadSnapshot(accountId), isNull);
    expect(find.text('当前清算行'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.search));
    await tester.pumpAndSettle();
    final alreadyBound = find.widgetWithText(FilledButton, '已绑定');
    expect(tester.widget<FilledButton>(alreadyBound).onPressed, isNull);
    await tester.tap(find.widgetWithText(FilledButton, '切换'));
    await tester.pumpAndSettle();
    expect(find.text('确认切换'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == 'GD001-SCB01-000000002',
      ),
      findsOneWidget,
    );
  });

  testWidgets('链上无绑定时可绑定，确认前读取失败时停止', (tester) async {
    final directory = _SettingsDirectory();
    await tester.pumpWidget(
      MaterialApp(
        home: ClearingBankSettingsPage(
          accountId: accountId,
          directory: directory,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.search));
    await tester.pumpAndSettle();
    final bind = find.widgetWithText(FilledButton, '绑定');
    expect(bind, findsNWidgets(2));
    directory.failRead = true;
    await tester.tap(bind.first);
    await tester.pumpAndSettle();
    expect(find.textContaining('读取当前绑定失败'), findsOneWidget);
    expect(find.text('确认绑定'), findsNothing);
    expect(find.text('尚未绑定清算行'), findsNothing);
    directory.failRead = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    await tester.tap(bind.first);
    await tester.pumpAndSettle();
    expect(find.text('确认绑定'), findsOneWidget);
  });

  testWidgets('切换账户后忽略旧绑定读取，旧确认不进入新账户', (tester) async {
    final previous = Completer<String?>();
    final other = '0x${'01' * 32}';
    var readCount = 0;
    final directory = _SettingsDirectory()
      ..read = (id) async {
        if (id == other) return null;
        expect(id, accountId);
        return ++readCount == 1 ? _bankA : await previous.future;
      };
    Widget page(String id) => MaterialApp(
      home: ClearingBankSettingsPage(accountId: id, directory: directory),
    );
    await tester.pumpWidget(page(accountId));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.search));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '切换'));
    await tester.pump();
    expect(find.text('正在读取当前绑定'), findsOneWidget);
    await tester.pumpWidget(page(other));
    await tester.pumpAndSettle();
    expect(find.text('尚未绑定清算行'), findsOneWidget);
    previous.complete(_bankA);
    await tester.pumpAndSettle();
    expect(find.text('尚未绑定清算行'), findsOneWidget);
    expect(find.byType(BindClearingBankPage), findsNothing);
    expect(find.widgetWithText(FilledButton, '绑定'), findsNWidgets(2));
  });

  testWidgets('充值确认前发现目标变化，先更新展示且不请求签名', (tester) async {
    final directory = _SettingsDirectory()..boundCid = _bankB;
    final bank = directory.banks.first;
    await tester.pumpWidget(MaterialApp(home: DepositPage(
      accountId: accountId,
      directory: directory,
      bank: (endpoint: bank.endpoint, title: bank.displayTitle),
    )));
    await tester.enterText(find.byType(TextField), '1.00');
    await tester.tap(find.text('确认充值'));
    await tester.pumpAndSettle();
    expect(find.text('转入 清算行 $_bankB'), findsOneWidget);
    expect(find.text('清算行已变化，请重新确认'), findsOneWidget);
  });

  for (final (mode, account) in [(0, accountId), (1, '0x${'01' * 32}'), (2, accountId)]) {
    testWidgets('绑定确认分开处理交易和缓存结果 $mode', (tester) async {
      final bank = _SettingsDirectory().banks[mode == 0 ? 0 : 1];
      final signer = citizenAccountIdBytes(account);
      final block = _block(CitizenBlockFinality.finalized);
      final best = _block(CitizenBlockFinality.best);
      final runtime = await CitizenSdkTestFixture.runtimeContext(best);
      final txid = Uint8List.fromList(List.filled(32, 0xab));
      final chain = OnchainClearingBankChain(
        buildCall: (pallet, method, fields) async {
          expect(method, mode == 0 ? 'bind_clearing_bank' : 'switch_bank');
          return runtime.encodeCall(pallet, method, fields);
        },
        prepareTransaction: (source, callData) async {
          expect(source, signer);
          expect(callData.sublist(3), utf8.encode(bank.cidNumber));
          return CitizenPreparedTransaction(
            preparationId: 'test-prepared',
            sourceAccountId: source,
            callDataHash: Uint8List(32),
            bestBlock: best,
            runtimeSpecNumber: 1,
            transactionFormatNumber: 1,
            nonce: BigInt.zero,
          );
        },
        executePreparedTransaction: (_) async => CitizenTransactionExecutionCompleted(
          executionId: 'test-execution',
          sourceAccountId: signer,
          callDataHash: Uint8List(32),
          transactionHash: txid,
          resolution: CitizenTransactionResolution.finalizedSuccess,
          execution: CitizenExecution(
            status: CitizenExecutionStatus.success,
            block: block,
            extrinsicIndex: 2,
            dispatchVariant: null,
            palletIndex: null,
            errorIndex: null,
          ),
          poolRejectionReason: null,
          replacementHash: null,
        ),
      );
      var cacheWrites = 0;
      ClearingBankPrefs.debugSetForTest = (prefs, key, value) async {
        cacheWrites++;
        expect(key, 'clearing_bank_binding_$account');
        if (mode == 1) return false;
        if (mode == 2) throw StateError('本地写入失败');
        return prefs.setString(key, value);
      };
      bool? result;
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            result = await Navigator.push<bool>(context, MaterialPageRoute(
              builder: (_) => BindClearingBankPage(
                accountId: account,
                bank: bank,
                switchMode: mode != 0,
                chain: chain,
                readFees: () async => CitizenFeeSnapshot(
                  bestBlock: best, feeRateParts: 0, minimumFeeFen: BigInt.zero,
                  existentialDepositFen: BigInt.zero, FLAT_FEE: BigInt.zero,
                  feeFen: BigInt.zero, minimumSelfPayFen: BigInt.zero,
                ),
              ),
            ));
          },
          child: const Text('打开确认页'),
        )),
      )));
      await tester.tap(find.text('打开确认页'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(mode == 0 ? '确认绑定' : '确认切换'));
      await tester.pumpAndSettle();
      expect(cacheWrites, 1);
      expect(result, true);
      expect(find.textContaining('已确认，交易 0xababab'), findsOneWidget);
      expect(find.textContaining('本地缓存未更新'), mode == 0 ? findsNothing : findsOneWidget);
      expect(find.textContaining('失败'), findsNothing);
    });
  }

}

CitizenBlockRef _block(CitizenBlockFinality finality) => CitizenBlockRef(
  hash: '0x${'ab' * 32}',
  number: BigInt.one,
  finality: finality,
);

class _SettingsDirectory extends ClearingBankDirectory {
  String? boundCid;
  bool failRead = false;
  Future<String?> Function(String)? read;

  final banks = [
    for (final cid in [_bankA, _bankB])
      ClearingBankCandidate(
        cidNumber: cid,
        fullName: '清算行 $cid',
        shortName: null,
        areaPath: '',
        endpoint: ClearingBankNodeEndpoint(
          cidNumber: cid,
          peerId: 'peer',
          rpcDomain: cid == _bankA ? 'old.example' : 'new.example',
          rpcPort: 443,
          registeredAt: 1,
          registeredBy: '',
        ),
      ),
  ];

  @override
  Future<String?> fetchUserBankCid(String accountId) async {
    if (failRead) throw StateError('链读取失败');
    final reader = read;
    return reader == null ? boundCid : await reader(accountId);
  }

  @override
  Future<ClearingBankBinding?> fetchUserBank(String accountId) async {
    final cid = await fetchUserBankCid(accountId);
    if (cid == null) return null;
    final bank = banks.singleWhere((bank) => bank.cidNumber == cid);
    return (endpoint: bank.endpoint, title: bank.displayTitle);
  }

  @override
  Future<List<ClearingBankCandidate>> search(String query) async => banks;
}
