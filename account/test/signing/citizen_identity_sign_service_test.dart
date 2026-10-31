import 'package:flutter/widgets.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_account/identity/citizen_identity_sign_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWallet extends TestWalletReads {
  _FakeWallet({this.account});

  final CitizenWalletStateAccount? account;

  @override
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      testCitizenOperation(
        () async => CitizenWalletState(
          initializationState: account == null
              ? CitizenWalletInitializationState.empty
              : CitizenWalletInitializationState.ready,
          cleanupPending: false,
          revision: BigInt.one,
          hotProfile: null,
          accounts: account == null ? const [] : [account!],
        ),
      );
}

// 仅提供业务所假定的外部签名结果，协议编码与解析仍经真实Core。
class _FakeSigning {
  String? signedAccountId;

  Future<Uint8List> sign(
    String accountId,
    Uint8List payload,
    int action,
    BuildContext? context,
  ) async {
    signedAccountId = accountId;
    return Uint8List(64);
  }
}

Future<String> _request(
  CitizenSdk qr, {
  required int action,
  required List<int> payload,
}) async {
  return (await qr.encodeDocument(
    CitizenQrContent.signRequest(
      requestId: 'citizen-request-000001',
      expiresAt: BigInt.from(1900000000),
      signerAccountId: '0x${'11' * 32}',
      action: action,
      reviewPayload: Uint8List.fromList(payload),
    ),
  )).canonicalText;
}

List<int> _u32Le(int value) => [
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

List<int> _u64Le(int value) => [
  for (var i = 0; i < 8; i++) (value >> (i * 8)) & 0xff,
];

List<int> _scaleText(String value) => [
  value.codeUnits.length << 2,
  ...value.codeUnits,
];

/// 内层 `VotingIdentityPayload` SCALE 字节，**不是**公民实际签名的内容。
List<int> _votingIdentityPayload() => [
  ..._scaleText('CN220-CTZN2-198805200-2026'),
  ...List<int>.filled(32, 0x11),
  ..._u32Le(20260728),
  ..._u32Le(20360728),
  0,
  ..._scaleText('CN22'),
  ..._scaleText('CN2201'),
  ..._scaleText('CN220101'),
];

const _genesisHashByte = 0xaa;
const _expectedIdentityVersion = 7;
const _authorizationExpiresAt = 1893456000;

/// 公民实际签名覆盖的**完整授权字节**，逐字节镜像唯一写入端
/// `onchina/src/domains/citizens/chain_identity.rs`
/// 的 `build_citizen_identity_authorization_bytes`：
/// `genesis_hash(32) ++ payload ++ expected_identity_version(8) ++ expires_at(8)`。
///
/// 本夹具曾只喂内层 payload，防重放三件套落地后长期红着 —— 夹具必须照写入端
/// 真实字节形态，否则「解码通过」证明不了任何跨端一致性。
Uint8List _validAuthorizationBytes() => Uint8List.fromList([
  ...List<int>.filled(32, _genesisHashByte),
  ..._votingIdentityPayload(),
  ..._u64Le(_expectedIdentityVersion),
  ..._u64Le(_authorizationExpiresAt),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final encoding = TestCitizenSdkHarness();

  late CitizenIdentitySignService service;
  setUp(() {
    service = CitizenIdentitySignService(qr: encoding.sdk);
  });

  test('公民身份确认文案由App保留，不由通用SDK提供', () async {
    final account = CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: 0,
      accountId: '0x${'11' * 32}',
      ss58Address: 'w5CitizenAccount',
      name: '账户0',
      createdAtMillis: BigInt.zero,
      isDefault: true,
    );
    final prep = await service.prepare(
      await _request(
        encoding.sdk,
        action: CitizenQrActions.citizenIdentity,
        payload: _validAuthorizationBytes(),
      ),
      null,
      getWalletState: (_FakeWallet(account: account)).getWalletState,
    );
    expect(prep.actionLabel, '公民签名确认');
  });

  test('非公民签名动作在读取钱包前即拒绝', () async {
    await expectLater(
      service.prepare(
        await _request(
          encoding.sdk,
          action: CitizenQrActions.login,
          payload: Uint8List(1),
        ),
        null,
        getWalletState: (_FakeWallet()).getWalletState,
      ),
      throwsA(isA<CitizenIdentitySignException>()),
    );
  });

  test('无法完整解码的公民身份载荷禁止签名', () async {
    await expectLater(
      service.prepare(
        await _request(
          encoding.sdk,
          action: CitizenQrActions.citizenIdentity,
          payload: Uint8List(1),
        ),
        null,
        getWalletState: (_FakeWallet()).getWalletState,
      ),
      throwsA(
        isA<CitizenIdentitySignException>().having(
          (error) => error.message,
          'message',
          contains('无法完整中文展示'),
        ),
      ),
    );
  });

  test('缺少防重放三件套的裸载荷禁止签名', () async {
    await expectLater(
      service.prepare(
        await _request(
          encoding.sdk,
          action: CitizenQrActions.citizenIdentity,
          payload: _votingIdentityPayload(),
        ),
        null,
        getWalletState: (_FakeWallet()).getWalletState,
      ),
      throwsA(
        isA<CitizenIdentitySignException>().having(
          (error) => error.message,
          'message',
          contains('无法完整中文展示'),
        ),
      ),
    );
  });

  test('卡片指定账户与请求一致时按该 account_id 签名', () async {
    final account = CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: 5,
      accountId: '0x${'11' * 32}',
      ss58Address: 'w5CitizenAccount',
      name: '账户5',
      createdAtMillis: BigInt.zero,
      isDefault: true,
    );
    final wallet = _FakeWallet(account: account);
    final signing = _FakeSigning();
    final raw = await _request(
      encoding.sdk,
      action: CitizenQrActions.citizenIdentity,
      payload: _validAuthorizationBytes(),
    );
    final prep = await service.prepare(
      raw,
      null,
      requiredAccount: account,
      getWalletState: (wallet).getWalletState,
    );
    await service.sign(prep, null, null, payloadSigner: (signing).sign);
    expect(prep.account.accountIndex, 5);
    expect(signing.signedAccountId, account.accountId);
    // 防重放三件套必须原样解出来并展示，不能只是"跳过了外层字节"。
    expect(prep.decoded.genesisHashHex, '0x${'aa' * 32}');
    expect(prep.decoded.expectedIdentityVersion, _expectedIdentityVersion);
    expect(prep.decoded.authorizationExpiresAt, _authorizationExpiresAt);
  });
}
