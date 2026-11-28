// 验证资料账户动作载荷、审阅及签名边界。

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/sdk.dart';
import 'package:citizen_user/profile/action.dart' show SquareActionSignError, SquareActionSignException, SquareActionSignService, decodeSquareActionPayload;
import 'package:flutter/widgets.dart';

void main() {
  group('square_action_payload_test', suite117);
  group('square_action_sign_service_test', suite118);
}

// 验证会员动作载荷逐字节解码及未知、截断和尾随拒绝。

Future<String> _payloadHex({
  required String action,
  required String accountId,
  required String challengeId,
  String? level,
  required int expiresAt,
}) async {
  final bytes = <int>[
    ...(await CitizenSdk.encodePayload(
      CitizenSigningPayload.scaleString(action),
    )),
    ...(await CitizenSdk.encodePayload(
      CitizenSigningPayload.scaleString(accountId),
    )),
    ...(await CitizenSdk.encodePayload(
      CitizenSigningPayload.scaleString(challengeId),
    )),
    if (level != null)
      ...(await CitizenSdk.encodePayload(
        CitizenSigningPayload.scaleString(level),
      )),
    ...(await CitizenSdk.encodePayload(
      CitizenSigningPayload.u64Le(BigInt.from(expiresAt)),
    )),
  ];
  return Uint8List.fromList(bytes)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

void suite117() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestCitizenSdkHarness();

  const accountId =
      '0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d';

  test('decodes cancel_membership (no context) byte-for-byte', () async {
    final hex = await _payloadHex(
      action: 'cancel_membership',
      accountId: accountId,
      challengeId: 'sqa_abc',
      expiresAt: 1700000000000,
    );
    final decoded = decodeSquareActionPayload(hex);
    expect(decoded, isNotNull);
    expect(decoded!.action, 'cancel_membership');
    expect(decoded.accountId, accountId);
    expect(decoded.challengeId, 'sqa_abc');
    expect(decoded.context, isNull);
    expect(decoded.expiresAt, 1700000000000);
    expect(decoded.actionTypeLabel, '取消订阅');
    expect(
      decoded.reviewFields!.map((field) => field.label),
      containsAll(['操作类型', '账户', '挑战编号', '过期时间']),
    );
  });

  test('decodes subscribe_membership with level context', () async {
    final hex = await _payloadHex(
      action: 'subscribe_membership',
      accountId: accountId,
      challengeId: 'sqa_xyz',
      level: 'voting',
      expiresAt: 1700000000000,
    );
    final decoded = decodeSquareActionPayload(hex);
    expect(decoded, isNotNull);
    expect(decoded!.action, 'subscribe_membership');
    expect(decoded.context, 'voting');
    expect(decoded.actionTypeLabel, '订阅会员');
    expect(
      decoded.reviewFields!.map((field) => '${field.label}:${field.value}'),
      contains('会员等级:voting'),
    );
  });

  test('rejects unknown action → null (no blind sign)', () async {
    final hex = await _payloadHex(
      action: 'transfer_all_funds',
      accountId: accountId,
      challengeId: 'sqa_evil',
      expiresAt: 1,
    );
    expect(decodeSquareActionPayload(hex), isNull);
  });

  test('rejects trailing-byte / truncated payload → null', () async {
    final hex = await _payloadHex(
      action: 'cancel_membership',
      accountId: accountId,
      challengeId: 'sqa_abc',
      expiresAt: 1,
    );
    expect(decodeSquareActionPayload('${hex}ff'), isNull); // 多一字节
    expect(
      decodeSquareActionPayload(hex.substring(0, hex.length - 4)),
      isNull,
    ); // 缺尾
  });
}

// 验证账户动作按二维码定位本机钱包并构造绑定请求的签名响应。

const _accountId =
    '0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d';
const _signerSs58Address = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
final Uint8List _pubBytes = Uint8List.fromList(
  List.generate(32, (i) => (i + 7) & 0xff),
);
final String _pubHex = _pubBytes
    .map((b) => b.toRadixString(16).padLeft(2, '0'))
    .join();

Future<Uint8List> _payloadBytes() async => Uint8List.fromList(<int>[
  ...(await CitizenSdk.encodePayload(
    CitizenSigningPayload.scaleString('cancel_membership'),
  )),
  ...(await CitizenSdk.encodePayload(
    CitizenSigningPayload.scaleString(_accountId),
  )),
  ...(await CitizenSdk.encodePayload(
    CitizenSigningPayload.scaleString('sqa_1'),
  )),
  ...(await CitizenSdk.encodePayload(
    CitizenSigningPayload.u64Le(BigInt.from(1700000000000)),
  )),
]);

Future<CitizenQrDocument> _request(
  CitizenSdk qr, {
  int action = CitizenQrActions.squareAccountAction,
}) async {
  final encoded = await qr.encodeDocument(
    CitizenQrContent.signRequest(
      requestId: 'square-request-000001',
      expiresAt: BigInt.from(1900000000),
      signerAccountId: '0x$_pubHex',
      reviewPayload: await _payloadBytes(),
      action: action,
    ),
  );
  return (await qr.parseForPurpose(
    encoded.canonicalText,
    CitizenQrScanPurpose.signingRequest,
  )).document;
}

CitizenWalletStateAccount _account({required String accountId, int index = 3}) {
  return CitizenWalletStateAccount(
    signMode: CitizenWalletSignMode.hot,
    walletIndex: 0,
    accountIndex: index,
    ss58Address: _signerSs58Address,
    accountId: accountId,
    name: '账户$index',
    createdAtMillis: BigInt.zero,
    isDefault: true,
  );
}

class _FakeWallet extends TestWalletReads {
  _FakeWallet(this._accounts);
  final List<CitizenWalletStateAccount> _accounts;

  @override
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      testCitizenOperation(
        () async => CitizenWalletState(
          initializationState: _accounts.isEmpty
              ? CitizenWalletInitializationState.empty
              : CitizenWalletInitializationState.ready,
          cleanupPending: false,
          revision: BigInt.one,
          hotProfile: null,
          accounts: _accounts,
        ),
      );
}

// 仅提供业务所假定的外部签名结果，协议编码与解析仍经真实Core。
class _FakeSigning {
  Uint8List signature = Uint8List(64)..fillRange(0, 64, 0x5a);
  Uint8List? signedPayload;
  String? signedAccountId;

  Future<Uint8List> sign(
    String accountId,
    Uint8List payload,
    int action,
    BuildContext? context,
  ) async {
    signedAccountId = accountId;
    signedPayload = Uint8List.fromList(payload);
    return signature;
  }
}

void suite118() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final encoding = TestCitizenSdkHarness();

  late SquareActionSignService service;
  setUp(() {
    service = SquareActionSignService(qr: encoding.sdk);
  });

  test('prepare resolves accountId wallet by QR u signer public key + decodes action', () async {
    final wm = _FakeWallet([_account(accountId: '0x$_pubHex')]);
    final prep = await service.prepare(
      await _request(encoding.sdk),
      null,
      getWalletState: (wm).getWalletState,
    );
    expect(prep.account.accountIndex, 3);
    expect(prep.actionLabel, '广场账户动作签名');
    expect(prep.decoded.action, 'cancel_membership');
    expect(prep.decoded.actionTypeLabel, '取消订阅');
    expect(prep.decoded.reviewFields, isNotNull);
  });

  test('prepare rejects unknown non-App action before signing', () async {
    final wm = _FakeWallet([_account(accountId: '0x$_pubHex')]);
    await expectLater(
      service.prepare(
        await _request(encoding.sdk, action: 0x7fff),
        null,
        getWalletState: (wm).getWalletState,
      ),
      throwsA(
        isA<SquareActionSignException>()
            .having(
              (e) => e.error,
              'error',
              SquareActionSignError.invalidRequest,
            )
            .having(
              (e) => e.message,
              'message',
              contains('不属于 CitizenApp 业务二维码'),
            ),
      ),
    );
  });

  test('prepare rejects registered non-App action before signing', () async {
    final wm = _FakeWallet([_account(accountId: '0x$_pubHex')]);
    await expectLater(
      service.prepare(
        await _request(encoding.sdk, action: CitizenQrActions.login),
        null,
        getWalletState: (wm).getWalletState,
      ),
      throwsA(
        isA<SquareActionSignException>()
            .having(
              (e) => e.error,
              'error',
              SquareActionSignError.invalidRequest,
            )
            .having(
              (e) => e.message,
              'message',
              contains('不属于 CitizenApp 业务二维码'),
            ),
      ),
    );
  });

  test('prepare throws accountNotLocal when no wallet matches u', () async {
    final wm = _FakeWallet([_account(accountId: '0x${'aa' * 32}')]);
    await expectLater(
      service.prepare(
        await _request(encoding.sdk),
        null,
        getWalletState: (wm).getWalletState,
      ),
      throwsA(
        isA<SquareActionSignException>().having(
          (e) => e.error,
          'error',
          SquareActionSignError.accountNotLocal,
        ),
      ),
    );
  });

  test(
    'prepare rejects card-selected account when QR u is another account',
    () async {
      final wm = _FakeWallet([_account(accountId: '0x$_pubHex')]);
      await expectLater(
        service.prepare(
          await _request(encoding.sdk),
          null,
          requiredAccount: _account(accountId: '0x${'aa' * 32}'),
          getWalletState: (wm).getWalletState,
        ),
        throwsA(
          isA<SquareActionSignException>().having(
            (e) => e.error,
            'error',
            SquareActionSignError.accountNotLocal,
          ),
        ),
      );
    },
  );

  test('sign signs signing_message(0x1D) with accountId wallet and builds signResponse', () async {
    final wm = _FakeWallet([_account(accountId: '0x$_pubHex')]);
    final prep = await service.prepare(
      await _request(encoding.sdk),
      null,
      getWalletState: (wm).getWalletState,
    );
    final signing = _FakeSigning();

    final responseData = await service.sign(
      prep,
      null,
      null,
      payloadSigner: (signing).sign,
    );

    // 用 QR 指定的 account_id 对 signing_message(0x1D, payload) 签名。
    expect(signing.signedAccountId, '0x$_pubHex');
    final expected = await CitizenSdk.encodePayload(
      CitizenSigningPayload.message(
        opTag: kOpSignSquareAction,
        scalePayload: await _payloadBytes(),
      ),
    );
    expect(signing.signedPayload, expected);

    // 响应由同一SDK解码；保留签名、请求标识及有效期绑定断言。
    final response = await encoding.sdk.parseQr(responseData);
    expect(response.kind, CitizenQrKind.signResponse);
    expect(response.signature, hasLength(64));
    expect(response.signature, signing.signature);
    expect(response.requestId, prep.request.requestId);
    expect(response.expiresAt, prep.request.expiresAt);
  });
}
