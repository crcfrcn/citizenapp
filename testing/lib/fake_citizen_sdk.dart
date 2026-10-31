import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';
import 'package:flutter_test/flutter_test.dart';

/// 每例使用真实Core；只有明确选择的钱包、系统金库、显示和摄像资源才启用。
/// 原生测试库由本轮正式SDK构建交付，不接受业务结果处理器或旧协议。
class TestCitizenSdkHarness {
  TestCitizenSdkHarness({
    int modules = CitizenSdkModules.qr,
    int vaultMode = 0,
    bool physicalUi = false,
    Future<void> Function(CitizenSdk sdk)? initialize,
  }) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUp(() async {
      fixture = CitizenSdkTestFixture()..install();
      fixture.physicalUi = physicalUi;
      sdk = await CitizenSdk.open(modules: modules);
      if ((modules & (CitizenSdkModules.wallet | CitizenSdkModules.signing)) !=
          0) {
        expect(fixture.vault(fixture.handles.values.single, vaultMode), 0);
      }
      await initialize?.call(sdk);
    });
    tearDown(() async {
      try {
        await sdk.close();
      } finally {
        await fixture.dispose();
      }
    });
  }
  late CitizenSdkTestFixture fixture;
  late CitizenSdk sdk;
}

/// 单个用例内打开明确模块的真实会话；测试结束等待SDK实际关闭，再交还物理通道。
Future<({CitizenSdk sdk, CitizenSdkTestFixture fixture})> openTestSdk({
  int modules = CitizenSdkModules.qr,
  int vaultMode = 0,
  bool physicalUi = false,
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = CitizenSdkTestFixture()..install();
  fixture.physicalUi = physicalUi;
  final sdk = await CitizenSdk.open(modules: modules);
  if ((modules & (CitizenSdkModules.wallet | CitizenSdkModules.signing)) != 0) {
    expect(fixture.vault(fixture.handles.values.single, vaultMode), 0);
  }
  addTearDown(() async {
    try {
      await sdk.close();
    } finally {
      await fixture.dispose();
    }
  });
  return (sdk: sdk, fixture: fixture);
}

/// 业务函数输入夹具，不实现或冒充SDK；未配置读取立即失败。
class TestChainReads {
  const TestChainReads();
  @override
  dynamic noSuchMethod(Invocation call) =>
      throw UnimplementedError('未配置业务函数${call.memberName}');
  Future<CitizenCapabilitySnapshot> getCapabilities() =>
      noSuchMethod(Invocation.method(#getCapabilities, []))
          as Future<CitizenCapabilitySnapshot>;
  Future<String> getGenesisHash() =>
      noSuchMethod(Invocation.method(#getGenesisHash, [])) as Future<String>;
  Future<CitizenBlockRef> getFinalizedHead() =>
      noSuchMethod(Invocation.method(#getFinalizedHead, []))
          as Future<CitizenBlockRef>;
  Future<CitizenBlockRef> getBestHead() =>
      noSuchMethod(Invocation.method(#getBestHead, []))
          as Future<CitizenBlockRef>;
  Future<CitizenBlockRef> getFinalizedBlockAt(BigInt number) =>
      noSuchMethod(Invocation.method(#getFinalizedBlockAt, [number]))
          as Future<CitizenBlockRef>;
  Future<CitizenBlockRef> resolveFinalizedBlock(String hash, BigInt number) =>
      noSuchMethod(Invocation.method(#resolveFinalizedBlock, [hash, number]))
          as Future<CitizenBlockRef>;
  Future<CitizenChainSyncStatus> getSyncStatus() =>
      noSuchMethod(Invocation.method(#getSyncStatus, []))
          as Future<CitizenChainSyncStatus>;
  Future<CitizenBlockHeader> getBlockHeader(CitizenBlockRef block) =>
      noSuchMethod(Invocation.method(#getBlockHeader, [block]))
          as Future<CitizenBlockHeader>;
  Future<CitizenBlockBody> getBlockBody(CitizenBlockRef block) =>
      noSuchMethod(Invocation.method(#getBlockBody, [block]))
          as Future<CitizenBlockBody>;
  Future<CitizenRuntimeContext> getRuntimeContext(CitizenBlockRef block) =>
      noSuchMethod(Invocation.method(#getRuntimeContext, [block]))
          as Future<CitizenRuntimeContext>;
  Future<Uint8List?> getStorage(CitizenBlockRef block, Uint8List key) =>
      noSuchMethod(Invocation.method(#getStorage, [block, key]))
          as Future<Uint8List?>;
  Future<List<Uint8List?>> getStorageBatch(
    CitizenBlockRef block,
    List<Uint8List> keys,
  ) =>
      noSuchMethod(Invocation.method(#getStorageBatch, [block, keys]))
          as Future<List<Uint8List?>>;
  Future<List<Uint8List>> getStorageKeysPaged(
    CitizenBlockRef block,
    Uint8List prefix, {
    Uint8List? startKey,
    int limit = 1000,
  }) => noSuchMethod(
    Invocation.method(
      #getStorageKeysPaged,
      [block, prefix],
      {#startKey: startKey, #limit: limit},
    ),
  ) as Future<List<Uint8List>>;
  Future<Uint8List> callRuntimeApi(
    CitizenBlockRef block,
    String method,
    Uint8List arguments,
  ) => noSuchMethod(
    Invocation.method(#callRuntimeApi, [block, method, arguments]),
  ) as Future<Uint8List>;
  Future<Uint8List?> getSystemEvents(CitizenBlockRef block) =>
      noSuchMethod(Invocation.method(#getSystemEvents, [block]))
          as Future<Uint8List?>;
  Future<CitizenChainState> exportState() =>
      noSuchMethod(Invocation.method(#exportState, []))
          as Future<CitizenChainState>;
  Future<void> importState(CitizenChainState state) =>
      noSuchMethod(Invocation.method(#importState, [state])) as Future<void>;
  Future<CitizenAccountBalance> getAccountBalance(String accountId) =>
      noSuchMethod(Invocation.method(#getAccountBalance, [accountId]))
          as Future<CitizenAccountBalance>;
  Future<List<CitizenAccountBalance>> getAccountBalances(
    List<String> accountIds,
  ) =>
      noSuchMethod(Invocation.method(#getAccountBalances, [accountIds]))
          as Future<List<CitizenAccountBalance>>;
  Future<CitizenAccountNonce> getAccountNonce(String accountId) =>
      noSuchMethod(Invocation.method(#getAccountNonce, [accountId]))
          as Future<CitizenAccountNonce>;
  Future<CitizenFeeSnapshot> getFeeSnapshot() =>
      noSuchMethod(Invocation.method(#getFeeSnapshot, []))
          as Future<CitizenFeeSnapshot>;
}

/// 业务函数输入夹具，不实现或冒充SDK；未配置读取立即失败。
class TestTransactionCalls {
  const TestTransactionCalls();
  @override
  dynamic noSuchMethod(Invocation call) =>
      throw UnimplementedError('未配置业务函数${call.memberName}');
  Future<CitizenPreparedTransaction> prepareTransaction(
    Uint8List sourceAccountId,
    Uint8List callData,
  ) => noSuchMethod(
    Invocation.method(#prepareTransaction, [sourceAccountId, callData]),
  ) as Future<CitizenPreparedTransaction>;
  Future<void> cancelPreparedTransaction(String preparationId) => noSuchMethod(
    Invocation.method(#cancelPreparedTransaction, [preparationId]),
  ) as Future<void>;
  Future<CitizenTransactionExecution> executePreparedTransaction(
    String preparationId,
  ) => noSuchMethod(
    Invocation.method(#executePreparedTransaction, [preparationId]),
  ) as Future<CitizenTransactionExecution>;
  Future<CitizenTransactionExecutionCompleted>
  consumePreparedTransactionQrResponse(String executionId, String response) =>
      noSuchMethod(
        Invocation.method(#consumePreparedTransactionQrResponse, [
          executionId,
          response,
        ]),
      ) as Future<CitizenTransactionExecutionCompleted>;
  Future<void> cancelPreparedTransactionExecution(String executionId) =>
      noSuchMethod(
        Invocation.method(#cancelPreparedTransactionExecution, [executionId]),
      ) as Future<void>;
}

/// 业务函数输入夹具，不实现或冒充SDK；未配置读取立即失败。
class TestHistoryReads {
  const TestHistoryReads();
  @override
  dynamic noSuchMethod(Invocation call) =>
      throw UnimplementedError('未配置业务函数${call.memberName}');
  Future<CitizenTransactionHistoryPage> getTransactionHistory({
    String? beforeExecutionId,
    int limit = 100,
  }) => noSuchMethod(
    Invocation.method(#getTransactionHistory, [], {
      #beforeExecutionId: beforeExecutionId,
      #limit: limit,
    }),
  ) as Future<CitizenTransactionHistoryPage>;
  Future<CitizenTransactionHistoryPage> syncTransactionHistory() =>
      noSuchMethod(Invocation.method(#syncTransactionHistory, []))
          as Future<CitizenTransactionHistoryPage>;
}

/// 业务函数输入夹具，不实现或冒充SDK；未配置读取立即失败。
class TestWalletReads {
  const TestWalletReads();
  @override
  dynamic noSuchMethod(Invocation call) =>
      throw UnimplementedError('未配置业务函数${call.memberName}');
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      noSuchMethod(Invocation.method(#getWalletState, []))
          as CitizenSdkOperation<CitizenWalletState>;
}

/// 合成公开资料，不对应真实钱包；UI用例显式选择此夹具，绝不访问设备金库。
String get testCitizenAccountId => '0x${List.filled(32, '01').join()}';
CitizenWalletProfile testCitizenWalletProfile() => CitizenWalletProfile(
  walletIndex: 0,
  walletName: '钱包0',
  masterAccountId: testCitizenAccountId,
  origin: CitizenWalletOrigin.created,
  createdAtMillis: BigInt.one,
  activeAccountId: testCitizenAccountId,
  accounts: [
    CitizenAccount(
      index: 0,
      accountId: testCitizenAccountId,
      ss58Address: citizenSs58FromAccountId(testCitizenAccountId),
      name: '钱包0',
      createdAtMillis: BigInt.one,
      isActive: true,
    ),
  ],
);
CitizenWalletState testCitizenWalletState() => CitizenWalletState(
  revision: BigInt.one,
  activeWalletIndex: 0,
  hotProfile: testCitizenWalletProfile(),
  accounts: [
    CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: 0,
      accountId: testCitizenAccountId,
      ss58Address: citizenSs58FromAccountId(testCitizenAccountId),
      name: '钱包0',
      createdAtMillis: BigInt.one,
      isDefault: true,
    ),
  ],
  initializationState: CitizenWalletInitializationState.ready,
  cleanupPending: false,
);

/// 立即交付合成结果的测试操作；不模拟原生排空或声称测试取消能力。
/// 取消/迟到等场景须由对应测试显式提供可控的CitizenSdkOperation。
CitizenSdkOperation<T> testCitizenOperation<T>(FutureOr<T> Function() result) =>
    CitizenSdkOperation<T>(
      operationId: (++_testOperationId).toString(),
      result: Future<T>.sync(result),
      cancel: () async => false,
    );
int _testOperationId = 0;

class TestCitizenTransactionFlow extends TestTransactionCalls {
  Future<CitizenPreparedTransaction> Function(Uint8List, Uint8List)? prepare;
  Future<CitizenTransactionExecution> Function(String)? execute;
  Future<CitizenTransactionExecutionCompleted> Function(String, String)?
  consume;
  Future<void> Function(String)? cancel;
  int prepareCount = 0, executeCount = 0, consumeCount = 0, cancelCount = 0;
  Uint8List? callData;
  @override
  Future<CitizenPreparedTransaction> prepareTransaction(
    Uint8List sourceAccountId,
    Uint8List callData,
  ) async {
    prepareCount++;
    this.callData = Uint8List.fromList(callData);
    if (prepare == null) throw UnimplementedError('未配置prepareTransaction');
    return prepare!(sourceAccountId, callData);
  }

  @override
  Future<CitizenTransactionExecution> executePreparedTransaction(
    String preparationId,
  ) async {
    executeCount++;
    if (execute == null) {
      throw UnimplementedError('未配置executePreparedTransaction');
    }
    return execute!(preparationId);
  }

  @override
  Future<CitizenTransactionExecutionCompleted>
  consumePreparedTransactionQrResponse(
    String executionId,
    String response,
  ) async {
    consumeCount++;
    if (consume == null) {
      throw UnimplementedError('未配置consumePreparedTransactionQrResponse');
    }
    return consume!(executionId, response);
  }

  @override
  Future<void> cancelPreparedTransactionExecution(String executionId) async {
    cancelCount++;
    if (cancel == null) {
      throw UnimplementedError('未配置cancelPreparedTransactionExecution');
    }
    await cancel!(executionId);
  }
}
