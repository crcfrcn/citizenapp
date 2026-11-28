// 验证身份授权审阅、载荷及拒绝边界。

import 'package:flutter/widgets.dart';
import 'package:citizen_testing/sdk.dart';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/identity/signing.dart' show CitizenIdentityConsentLevel, CitizenIdentitySignException, CitizenIdentitySignService, CitizenOccupySignException, CitizenOccupySignService, VotingIdentityConsentPayload;
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

void main() {
  group('citizen_identity_sign_service_test', suite112);
  group('citizen_occupy_sign_service_test', suite113);
  group('voting_identity_payload_test', suite94);
}

// 验证身份授权完整审阅、指定账户和动作拒绝。

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

Future<CitizenQrDocument> _request(
  CitizenSdk qr, {
  required int action,
  required List<int> payload,
}) async {
  final encoded = await qr.encodeDocument(
    CitizenQrContent.signRequest(
      requestId: 'citizen-request-000001',
      expiresAt: BigInt.from(1900000000),
      signerAccountId: '0x${'11' * 32}',
      action: action,
      reviewPayload: Uint8List.fromList(payload),
    ),
  );
  return (await qr.parseForPurpose(
    encoded.canonicalText,
    CitizenQrScanPurpose.signingRequest,
  )).document;
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

void suite112() {
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
    final request = await _request(
      encoding.sdk,
      action: CitizenQrActions.citizenIdentity,
      payload: _validAuthorizationBytes(),
    );
    final prep = await service.prepare(
      request,
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

// 验证占号换绑模板、当前账户和防重放字段及过期范围。

const _cid = 'CN220-CTZN2-198805200-2026';
const _expiresAt = 1900000000;

CitizenWalletStateAccount _account({int index = 0, int accountByte = 0xab}) =>
    CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: index,
      accountId: '0x${_hexByte(accountByte) * 32}',
      ss58Address: 'w5FhTestAddress',
      name: '账户$index',
      createdAtMillis: BigInt.zero,
      isDefault: index == 0,
    );

class _OccupyFakeWallet extends TestWalletReads {
  _OccupyFakeWallet({this.currentAccount});

  final CitizenWalletStateAccount? currentAccount;

  @override
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      testCitizenOperation(
        () async => CitizenWalletState(
          initializationState: currentAccount == null
              ? CitizenWalletInitializationState.empty
              : CitizenWalletInitializationState.ready,
          cleanupPending: false,
          revision: BigInt.one,
          hotProfile: null,
          accounts: currentAccount == null ? const [] : [currentAccount!],
        ),
      );
}

// 仅提供业务所假定的外部签名结果，协议编码与解析仍经真实Core。
class _OccupyFakeSigning {
  String? signedAccountId;
  Uint8List? signedPayload;
  final List<String> signedAccountIds = <String>[];
  final List<Uint8List> signedPayloads = <Uint8List>[];

  Future<Uint8List> sign(
    String accountId,
    Uint8List payload,
    int action,
    BuildContext? context,
  ) async {
    signedAccountId = accountId;
    signedPayload = Uint8List.fromList(payload);
    signedAccountIds.add(accountId);
    signedPayloads.add(Uint8List.fromList(payload));
    return Uint8List(64);
  }
}

String _hexByte(int value) => value.toRadixString(16).padLeft(2, '0');

List<int> _occupyU64Le(int value) =>
    List<int>.generate(8, (index) => (value >> (index * 8)) & 0xff);

List<int> _occupyTemplate({int revision = 0, int expiresAt = _expiresAt}) => [
  ...List<int>.filled(32, 0x44),
  _cid.length << 2,
  ..._cid.codeUnits,
  ...List<int>.filled(32, 0),
  ..._occupyU64Le(revision),
  ..._occupyU64Le(expiresAt),
];

List<int> _rebindTemplate({int revision = 7, int expiresAt = _expiresAt}) => [
  ...List<int>.filled(32, 0x44),
  _cid.length << 2,
  ..._cid.codeUnits,
  ...List<int>.filled(32, 0x55),
  ...List<int>.filled(32, 0),
  ..._occupyU64Le(revision),
  ..._occupyU64Le(expiresAt),
];

/// 合成授权模板交由真实SDK编码；测试不持有App协议实现。
Future<CitizenQrDocument> _occupyRequest(
  CitizenSdk qr, {
  int? action,
  List<int>? payload,
  int outerExpiresAt = _expiresAt,
}) async {
  final actualAction = action ?? CitizenQrActions.citizenOccupy;
  final authorization =
      payload ??
      (actualAction == CitizenQrActions.citizenOccupy
          ? _occupyTemplate()
          : _rebindTemplate());
  final encoded = await qr.encodeDocument(
    CitizenQrContent.signRequest(
      requestId: 'citizen-occupy-req-000001',
      expiresAt: BigInt.from(outerExpiresAt),
      action: actualAction,
      reviewPayload: Uint8List.fromList(authorization),
    ),
  );
  return (await qr.parseForPurpose(
    encoded.canonicalText,
    CitizenQrScanPurpose.signingRequest,
  )).document;
}

void suite113() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final encoding = TestCitizenSdkHarness();

  late CitizenOccupySignService service;
  setUp(() {
    service = CitizenOccupySignService(qr: encoding.sdk);
  });

  test('SDK占号与换绑公开动作保留原QR_V1数值', () {
    expect(CitizenQrActions.citizenOccupy, 10);
    expect(CitizenQrActions.citizenRebind, 11);
  });

  test('prepare 严格解出占号完整授权模板并展示全部防重放字段', () async {
    final prep = await service.prepare(
      await _occupyRequest(encoding.sdk),
      _account(),
    );
    expect(prep.cidNumber, _cid);
    expect(prep.isOccupy, isTrue);
    expect(prep.genesisHash, '0x${'44' * 32}');
    expect(prep.currentAccountId, isNull);
    expect(prep.expectedBindingRevision, BigInt.zero);
    expect(prep.expiresAt, BigInt.from(_expiresAt));
    expect(prep.account.accountId, '0x${'ab' * 32}');
  });

  test('prepare 严格解出换绑当前账户、非零 revision 与 expires', () async {
    final prep = await service.prepare(
      await _occupyRequest(encoding.sdk, action: CitizenQrActions.citizenRebind),
      _account(),
    );
    expect(prep.isOccupy, isFalse);
    expect(prep.cidNumber, _cid);
    expect(prep.genesisHash, '0x${'44' * 32}');
    expect(prep.currentAccountId, '0x${'55' * 32}');
    expect(prep.expectedBindingRevision, BigInt.from(7));
    expect(prep.expiresAt, BigInt.from(_expiresAt));
  });

  test('非占号/换绑动作即拒', () async {
    final encoded = await encoding.sdk.encodeDocument(
      CitizenQrContent.signRequest(
        requestId: 'citizen-identity-req-0001',
        signerAccountId: '0x${'11' * 32}',
        reviewPayload: Uint8List.fromList([1, 2, 3, 4]),
        action: CitizenQrActions.citizenIdentity,
        expiresAt: BigInt.from(_expiresAt),
      ),
    );
    final request = (await encoding.sdk.parseForPurpose(
      encoded.canonicalText,
      CitizenQrScanPurpose.signingRequest,
    )).document;
    await expectLater(
      service.prepare(request, _account()),
      throwsA(isA<CitizenOccupySignException>()),
    );
  });

  test('旧 CID-only 载荷即拒，不恢复末尾追加账户协议', () async {
    await expectLater(
      service.prepare(
        await _occupyRequest(
          encoding.sdk,
          payload: [_cid.length << 2, ..._cid.codeUnits],
        ),
        _account(),
      ),
      throwsA(isA<CitizenOccupySignException>()),
    );
  });

  test('外层 e 与内层 expires_at 不一致即拒', () async {
    await expectLater(
      service.prepare(
        await _occupyRequest(encoding.sdk, outerExpiresAt: _expiresAt + 1),
        _account(),
      ),
      throwsA(
        isA<CitizenOccupySignException>().having(
          (error) => error.message,
          'message',
          contains('过期时间'),
        ),
      ),
    );
  });

  test('零槽污染、尾字节与错误 revision 全部 fail-closed', () async {
    final nonZeroSlot = _occupyTemplate();
    nonZeroSlot[32 + 1 + _cid.length] = 1;
    final malformed = <List<int>>[
      nonZeroSlot,
      [..._occupyTemplate(), 0xff],
      _occupyTemplate(revision: 1),
      _rebindTemplate(revision: 0),
    ];
    for (var index = 0; index < malformed.length; index++) {
      await expectLater(
        service.prepare(
          await _occupyRequest(
            encoding.sdk,
            action: index == malformed.length - 1
                ? CitizenQrActions.citizenRebind
                : CitizenQrActions.citizenOccupy,
            payload: malformed[index],
          ),
          _account(),
        ),
        throwsA(isA<CitizenOccupySignException>()),
        reason: 'malformed template #$index must reject',
      );
    }
  });

  test('换绑选择账户与 current_account_id 相同即拒', () async {
    await expectLater(
      service.prepare(
        await _occupyRequest(encoding.sdk, action: CitizenQrActions.citizenRebind),
        _account(accountByte: 0x55),
      ),
      throwsA(
        isA<CitizenOccupySignException>().having(
          (error) => error.message,
          'message',
          contains('不得与当前绑定账户相同'),
        ),
      ),
    );
  });

  test('账户卡锁定的子账户原位填入占号零槽后签名', () async {
    final account = _account(index: 5);
    final signing = _OccupyFakeSigning();
    final prep = await service.prepare(await _occupyRequest(encoding.sdk), account);
    await service.sign(prep, null, null, payloadSigner: (signing).sign);
    expect(prep.account.accountIndex, 5);
    expect(signing.signedAccountId, account.accountId);
    final exactAuthorization = _occupyTemplate()
      ..setRange(
        32 + 1 + _cid.length,
        32 + 1 + _cid.length + 32,
        List<int>.filled(32, 0xab),
      );
    expect(
      signing.signedPayload,
      (await CitizenSdk.encodePayload(
        CitizenSigningPayload.message(
          opTag: kOpSignCidOccupy,
          scalePayload: Uint8List.fromList(exactAuthorization),
        ),
      )),
    );
  });

  test('注册局换绑在同一次扫码中收集当前与新账户对同一授权的双签名', () async {
    final newAccount = _account(accountByte: 0xab);
    final currentAccount = _account(accountByte: 0x55);
    final wallet = _OccupyFakeWallet(currentAccount: currentAccount);
    final signing = _OccupyFakeSigning();
    final prep = await service.prepare(
      await _occupyRequest(encoding.sdk, action: CitizenQrActions.citizenRebind),
      newAccount,
      null,
      (wallet).getWalletState,
    );

    expect(prep.currentAccount?.accountId, currentAccount.accountId);
    final raw = await service.sign(
      prep,
      null,
      null,
      payloadSigner: (signing).sign,
    );
    expect(signing.signedAccountIds, <String>[
      newAccount.accountId,
      currentAccount.accountId,
    ]);

    final exactAuthorization = _rebindTemplate()
      ..setRange(
        32 + 1 + _cid.length + 32,
        32 + 1 + _cid.length + 64,
        List<int>.filled(32, 0xab),
      );
    expect(
      signing.signedPayloads[0],
      (await CitizenSdk.encodePayload(
        CitizenSigningPayload.message(
          opTag: kOpSignCidAdminRebind,
          scalePayload: Uint8List.fromList(exactAuthorization),
        ),
      )),
    );
    expect(
      signing.signedPayloads[1],
      (await CitizenSdk.encodePayload(
        CitizenSigningPayload.message(
          opTag: kOpSignCidRebind,
          scalePayload: Uint8List.fromList(exactAuthorization),
        ),
      )),
    );

    final response = await encoding.sdk.parseQr(raw);
    expect(response.signerAccountId, newAccount.accountId);
    expect(response.currentAccountId, currentAccount.accountId);
    expect(response.currentAccountSignature, Uint8List(64));
  });

  test('当前钱包不在本机时注册局仍可强制换绑，但响应不伪造当前账户签名', () async {
    final wallet = _OccupyFakeWallet();
    final signing = _OccupyFakeSigning();
    final prep = await service.prepare(
      await _occupyRequest(encoding.sdk, action: CitizenQrActions.citizenRebind),
      _account(accountByte: 0xab),
      null,
      (wallet).getWalletState,
    );
    expect(prep.currentAccount, isNull);

    final response = await encoding.sdk.parseQr(
      await service.sign(prep, null, null, payloadSigner: (signing).sign),
    );
    expect(signing.signedAccountIds, <String>['0x${'ab' * 32}']);
    expect(response.currentAccountId, isNull);
    expect(response.currentAccountSignature, isNull);
  });
}

// 验证身份完整授权审阅、公开字段及状态日期边界。

/// 公民实际签名覆盖的完整授权字节(与链端 `CitizenIdentityAuthorization` 一致):
/// genesis_hash(32) || payload || expected_identity_version(u64le) ||
/// expires_at(u64le)。三者分别锁链身份、锁身份版本、锁授权时间窗。
Uint8List wrapAuthorization(
  List<int> payloadBytes, {
  int identityVersion = 3,
  int expiresAt = 1800000000,
}) {
  void pushU64Le(List<int> out, int value) {
    for (var i = 0; i < 8; i++) {
      out.add((value >> (i * 8)) & 0xff);
    }
  }

  final out = <int>[
    ...List.filled(32, 0x11), // genesis_hash
    ...payloadBytes,
  ];
  pushU64Le(out, identityVersion);
  pushU64Le(out, expiresAt);
  return Uint8List.fromList(out);
}

/// 按 onchina `build_voting_identity_payload` 的字节布局构造裸载荷:
/// compact(len)+cid || publicKey(32) || valid_from(u32le) ||
/// valid_until(u32le) || status(1) || compact+province || compact+city ||
/// compact+town。长度均 < 64,compact 恒为单字节 len<<2。
Uint8List buildVotingPayloadRaw({
  String cidNumber = 'BJ110198512345678',
  int? publicKeyByte,
  int validFrom = 20260101,
  int validUntil = 20360101,
  int status = 0,
  String province = '11',
  String city = '01',
  String town = '001',
}) {
  final out = <int>[];
  void pushVec(String text) {
    final bytes = utf8.encode(text);
    out.add(bytes.length << 2);
    out.addAll(bytes);
  }

  void pushU32Le(int value) {
    out.addAll([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ]);
  }

  pushVec(cidNumber);
  out.addAll(List.filled(32, publicKeyByte ?? 0xaa));
  pushU32Le(validFrom);
  pushU32Le(validUntil);
  out.add(status);
  pushVec(province);
  pushVec(city);
  pushVec(town);
  return Uint8List.fromList(out);
}

/// 解码入口收的是完整授权字节，故夹具默认返回已包壳的形态。
Uint8List buildPayload({
  String cidNumber = 'BJ110198512345678',
  int? publicKeyByte,
  int validFrom = 20260101,
  int validUntil = 20360101,
  int status = 0,
  String province = '11',
  String city = '01',
  String town = '001',
}) => wrapAuthorization(
  buildVotingPayloadRaw(
    cidNumber: cidNumber,
    publicKeyByte: publicKeyByte,
    validFrom: validFrom,
    validUntil: validUntil,
    status: status,
    province: province,
    city: city,
    town: town,
  ),
);

Uint8List buildCandidatePayload() {
  final out = <int>[...buildVotingPayloadRaw()];
  void pushVec(String text) {
    final bytes = utf8.encode(text);
    out.add(bytes.length << 2);
    out.addAll(bytes);
  }

  pushVec('11');
  pushVec('01');
  pushVec('002');
  pushVec('测');
  pushVec('试公民');
  out.add(1);
  // birth_date: u32 YYYYMMDD(LE),20000131。
  const birthDate = 20000131;
  out.addAll([
    birthDate & 0xff,
    (birthDate >> 8) & 0xff,
    (birthDate >> 16) & 0xff,
    (birthDate >> 24) & 0xff,
  ]);
  return wrapAuthorization(out);
}

void suite94() {
  group('VotingIdentityConsentPayload.decode', () {
    test('解码完整载荷并生成中文确认条目', () {
      final decoded = VotingIdentityConsentPayload.decode(buildPayload());

      expect(decoded, isNotNull);
      expect(decoded!.cidLevel, CitizenIdentityConsentLevel.voting);
      expect(decoded.cidNumber, 'BJ110198512345678');
      expect(decoded.accountId, '0x${'aa' * 32}');
      expect(
        decoded.accountAddress,
        citizenSs58FromAccountIdBytes(List.filled(32, 0xaa)),
      );
      expect(decoded.statusNormal, isTrue);
      expect(decoded.provinceCode, '11');
      expect(decoded.cityCode, '01');
      expect(decoded.townCode, '001');

      final entries = Map.fromEntries(
        decoded.reviewEntries.map((e) => MapEntry(e.$1, e.$2)),
      );
      expect(entries['护照有效期'], '2026-01-01 至 2036-01-01');
      expect(entries['身份状态'], '正常');
      expect(entries['居住地'], '11 / 01 / 001');
      // 中文标签必须全量存在,禁止英文 key 直出。
      expect(entries.keys, containsAll(['CID编号', '公民钱包账户']));
    });

    test('解码参选身份载荷并展示额外公开档案字段', () {
      final decoded = VotingIdentityConsentPayload.decode(
        buildCandidatePayload(),
      );

      expect(decoded, isNotNull);
      expect(decoded!.cidLevel, CitizenIdentityConsentLevel.candidate);
      expect(decoded.isCandidate, isTrue);
      expect(decoded.birthProvinceCode, '11');
      expect(decoded.birthCityCode, '01');
      expect(decoded.birthTownCode, '002');
      expect(decoded.familyName, '测');
      expect(decoded.givenName, '试公民');
      expect(decoded.citizenSexLabel, '女');
      expect(decoded.birthDate, 20000131);

      final entries = Map.fromEntries(
        decoded.reviewEntries.map((e) => MapEntry(e.$1, e.$2)),
      );
      expect(entries['身份类型'], '参选身份');
      expect(entries['出生地'], '11 / 01 / 002');
      expect(entries['出生日期'], '2000-01-31');
      expect(entries['公民姓名'], '测试公民');
      expect(entries['公民性别'], '女');
    });

    test('注销状态展示为注销', () {
      final decoded = VotingIdentityConsentPayload.decode(
        buildPayload(status: 1),
      );
      expect(decoded, isNotNull);
      expect(decoded!.statusNormal, isFalse);
    });

    test('拒绝未知状态值', () {
      expect(
        VotingIdentityConsentPayload.decode(buildPayload(status: 2)),
        isNull,
      );
    });

    test('拒绝有效期倒挂', () {
      expect(
        VotingIdentityConsentPayload.decode(
          buildPayload(validFrom: 20360101, validUntil: 20260101),
        ),
        isNull,
      );
    });

    test('拒绝非法日期', () {
      expect(
        VotingIdentityConsentPayload.decode(buildPayload(validFrom: 20261301)),
        isNull,
      );
    });

    test('拒绝截断载荷', () {
      final full = buildPayload();
      final truncated = Uint8List.sublistView(full, 0, full.length - 1);
      expect(VotingIdentityConsentPayload.decode(truncated), isNull);
    });

    test('拒绝尾部残留字节', () {
      final withTrailing = Uint8List.fromList([...buildPayload(), 0x00]);
      expect(VotingIdentityConsentPayload.decode(withTrailing), isNull);
    });

    test('拒绝空 CID', () {
      final bytes = buildPayload(cidNumber: '');
      expect(VotingIdentityConsentPayload.decode(bytes), isNull);
    });
  });
}
