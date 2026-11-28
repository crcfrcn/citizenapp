// 审阅身份授权载荷并核验、准备签名响应。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:citizen_scanner/sign.dart';
import 'dart:typed_data';
import 'dart:convert';

// 完整解码公民身份授权，核对请求、载荷和本机账户后准备签名。

class CitizenIdentitySignException implements Exception {
  const CitizenIdentitySignException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 公民身份签名的已校验待签态；三个扫码入口共用，避免页面各自实现协议。
class CitizenIdentitySignPrep {
  const CitizenIdentitySignPrep({
    required this.request,
    required this.actionLabel,
    required this.decoded,
    required this.account,
  });

  final CitizenQrDocument request;
  final String actionLabel;
  final VotingIdentityConsentPayload decoded;
  final CitizenWalletStateAccount account;
}

/// 公民签名统一服务：完整解码、请求/载荷/本机钱包三方公钥一致后才允许签名。
class CitizenIdentitySignService {
  CitizenIdentitySignService({required CitizenSdk qr}) : _qr = qr;
  final CitizenSdk _qr;

  Future<CitizenIdentitySignPrep> prepare(
    CitizenQrDocument request,
    CitizenSdk? wallet, {
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
    CitizenWalletStateAccount? requiredAccount,
  }) async {
    final payload = request.reviewPayload;
    final signer = request.signerAccountId;
    if (request.kind != CitizenQrKind.signRequest ||
        request.action != CitizenQrActions.citizenIdentity ||
        payload == null ||
        signer == null) {
      throw const CitizenIdentitySignException('该二维码不是公民签名确认请求');
    }
    // 原确认页文案归App所有；协议与期限只由SDK验证。
    const actionLabel = '公民签名确认';
    final decoded = VotingIdentityConsentPayload.decode(payload);
    if (decoded == null) {
      throw const CitizenIdentitySignException('签名内容无法完整中文展示，已拒绝签名');
    }
    if (decoded.accountId != signer) {
      throw const CitizenIdentitySignException('身份载荷钱包与签名请求不一致');
    }
    final account =
        requiredAccount ??
        _findAccount(
          await (getWalletState ?? wallet!.getWalletState)().result,
          signer,
        );
    if (account == null || account.accountId != signer) {
      throw const CitizenIdentitySignException('此签名请求的账户不在本机');
    }
    return CitizenIdentitySignPrep(
      request: request,
      actionLabel: actionLabel,
      decoded: decoded,
      account: account,
    );
  }

  Future<String> sign(
    CitizenIdentitySignPrep prep,
    CitizenSdk? signing,
    BuildContext? context, {
    PayloadSigner? payloadSigner,
  }) async {
    final bytes = await CitizenSdk.encodePayload(
      CitizenSigningPayload.message(
        opTag: kOpSignCitizenIdentity,
        scalePayload: prep.request.reviewPayload!,
      ),
    );
    if (context != null && !context.mounted) {
      throw const CitizenIdentitySignException('当前签名页面已经关闭');
    }
    final signature =
        await (payloadSigner ??
            ((id, payload, action, ctx) => signCitizenPayload(
              signing: signing!,
              context: ctx,
              accountId: id,
              payload: payload,
              action: action,
            )))(prep.account.accountId, bytes, prep.request.action!, context);
    return (await _qr.encodeDocument(
      CitizenQrContent.signResponse(
        requestId: prep.request.requestId!,
        expiresAt: BigInt.from(prep.request.expiresAt!),
        signerAccountId: prep.account.accountId,
        signature: signature,
      ),
    )).canonicalText;
  }

  static CitizenWalletStateAccount? _findAccount(
    CitizenWalletState state,
    String accountId,
  ) {
    for (final account in state.accounts) {
      if (account.accountId == accountId) {
        return account;
      }
    }
    return null;
  }
}

// 核验注册局占号或换绑授权模板，按用户选择的账户准备回签。

class CitizenOccupySignException implements Exception {
  const CitizenOccupySignException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 注册局代办占号/换绑的已校验待签态。请求 b.u 留空,绑定账户由用户自选。
class CitizenOccupySignPrep {
  const CitizenOccupySignPrep({
    required this.request,
    required this.actionLabel,
    required this.cidNumber,
    required this.isOccupy,
    required this.genesisHash,
    required this.currentAccountId,
    required this.expectedBindingRevision,
    required this.expiresAt,
    required this.account,
    required this.materializedPayload,
    this.currentAccount,
  });

  final CitizenQrDocument request;
  final String actionLabel;
  final String cidNumber;
  final bool isOccupy;
  final String genesisHash;

  /// 换绑授权模板中的当前绑定账户；首次占号时为空。
  final String? currentAccountId;
  final BigInt expectedBindingRevision;
  final BigInt expiresAt;
  final CitizenWalletStateAccount account;

  /// 当前账户仅在本机存在可签名私钥时取得，不建立任何服务端恢复通道。
  final CitizenWalletStateAccount? currentAccount;

  /// 已填入新 account_id 的完整 SCALE 载荷，新旧账户对同一份换绑语义签名。
  final Uint8List materializedPayload;
}

/// 注册局占号/换绑签名服务。
///
/// 请求 `b.u` 留空；`d` 必须是包含创世哈希、CID、账户零槽、绑定 revision 和过期时间的
/// 完整 Runtime 授权模板。服务严格解码、核对外层 `e == 内层 expires_at`，再把用户选择
/// 的本机账户原位填入零槽签名；响应 `b.u` 用该账户带回。
class CitizenOccupySignService {
  CitizenOccupySignService({required CitizenSdk qr}) : _occupyQr = qr;
  final CitizenSdk _occupyQr;

  /// [selectedAccount] = 用户自选或账户卡扫码入口锁定的绑定账户(占即绑一账户)。
  Future<CitizenOccupySignPrep> prepare(
    CitizenQrDocument request,
    CitizenWalletStateAccount selectedAccount, [
    CitizenSdk? wallet,
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
  ]) async {
    final action = request.action;
    final payload = request.reviewPayload;
    if (request.kind != CitizenQrKind.signRequest ||
        action == null ||
        !CitizenQrActions.isSelfAccountDomainAction(action) ||
        payload == null) {
      throw const CitizenOccupySignException('该二维码不是注册局占号/换绑请求');
    }
    final actionLabel = action == CitizenQrActions.citizenOccupy
        ? '注册局占号绑定确认'
        : '注册局换绑账户确认';
    final authorization = await _occupyQr.prepareAccountAuthorization(
      action: action,
      payload: payload,
      accountId: selectedAccount.accountId,
    );
    switch (authorization.reason) {
      case CitizenQrAuthorizationReason.invalidTemplate:
        throw const CitizenOccupySignException('签名内容无法完整中文展示，已拒绝签名');
      case CitizenQrAuthorizationReason.invalidAccountId:
        throw const CitizenOccupySignException('所选账户 account_id 格式错误');
      case CitizenQrAuthorizationReason.sameAccount:
        throw const CitizenOccupySignException('换绑新账户不得与当前绑定账户相同');
      case CitizenQrAuthorizationReason.valid:
        break;
    }
    final outerExpiresAt = request.expiresAt;
    if (outerExpiresAt == null ||
        BigInt.from(outerExpiresAt) != authorization.expiresAt) {
      throw const CitizenOccupySignException('二维码过期时间与授权载荷不一致，已拒绝签名');
    }
    final materializedPayload = authorization.materializedPayload!;
    // 只有当前账户私钥在本机可用时才附加旧账户签名；缺失时不伪造、不回退。
    final currentAccount =
        authorization.currentAccountId == null ||
            (wallet == null && getWalletState == null)
        ? null
        : _occupyFindAccount(
            await (getWalletState ?? wallet!.getWalletState)().result,
            authorization.currentAccountId!,
          );
    return CitizenOccupySignPrep(
      request: request,
      actionLabel: actionLabel,
      cidNumber: authorization.cidNumber!,
      isOccupy: action == CitizenQrActions.citizenOccupy,
      genesisHash: authorization.genesisHash!,
      currentAccountId: authorization.currentAccountId,
      expectedBindingRevision: authorization.expectedBindingRevision!,
      expiresAt: authorization.expiresAt!,
      account: selectedAccount,
      currentAccount: currentAccount,
      materializedPayload: materializedPayload,
    );
  }

  Future<String> sign(
    CitizenOccupySignPrep prep,
    CitizenSdk? signing,
    BuildContext? context, {
    PayloadSigner? payloadSigner,
  }) async {
    final bytes = await CitizenSdk.encodePayload(
      CitizenSigningPayload.message(
        opTag: prep.isOccupy ? kOpSignCidOccupy : kOpSignCidAdminRebind,
        scalePayload: prep.materializedPayload,
      ),
    );
    if (context != null && !context.mounted) {
      throw const CitizenOccupySignException('当前签名页面已经关闭');
    }
    final signature =
        await (payloadSigner ??
            ((id, payload, action, ctx) => signCitizenPayload(
              signing: signing!,
              context: ctx,
              accountId: id,
              payload: payload,
              action: action,
            )))(prep.account.accountId, bytes, prep.request.action!, context);
    Uint8List? currentAccountSignature;
    final currentAccount = prep.currentAccount;
    if (!prep.isOccupy && currentAccount != null) {
      if (context != null && !context.mounted) {
        throw const CitizenOccupySignException('当前签名页面已经关闭');
      }
      // 同一次换绑扫码内，当前账户和新账户共同绑定同一份 materialized payload。
      final currentAccountDigest = await CitizenSdk.encodePayload(
        CitizenSigningPayload.message(
          opTag: kOpSignCidRebind,
          scalePayload: prep.materializedPayload,
        ),
      );
      if (context != null && !context.mounted) {
        throw const CitizenOccupySignException('当前签名页面已经关闭');
      }
      currentAccountSignature =
          await (payloadSigner ??
              ((id, payload, action, ctx) => signCitizenPayload(
                signing: signing!,
                context: ctx,
                accountId: id,
                payload: payload,
                action: action,
              )))(
            currentAccount.accountId,
            currentAccountDigest,
            kOpSignCidRebind,
            context,
          );
    }
    return (await _occupyQr.encodeDocument(
      CitizenQrContent.signResponse(
        requestId: prep.request.requestId!,
        expiresAt: BigInt.from(prep.request.expiresAt!),
        signerAccountId: prep.account.accountId,
        signature: signature,
        currentAccountId: currentAccountSignature == null
            ? null
            : currentAccount?.accountId,
        currentAccountSignature: currentAccountSignature,
      ),
    )).canonicalText;
  }

  static CitizenWalletStateAccount? _occupyFindAccount(
    CitizenWalletState state,
    String accountId,
  ) {
    for (final account in state.accounts) {
      if (account.accountId == accountId) return account;
    }
    return null;
  }
}

// 完整解码身份确认授权字节及版本和期限，供签名前独立审阅。

/// CitizenSdk SS58 前缀。

enum CitizenIdentityConsentLevel { voting, candidate }

class VotingIdentityConsentPayload {
  const VotingIdentityConsentPayload({
    required this.cidLevel,
    required this.cidNumber,
    required this.accountId,
    required this.accountAddress,
    required this.validFrom,
    required this.validUntil,
    required this.statusNormal,
    required this.provinceCode,
    required this.cityCode,
    required this.townCode,
    this.birthProvinceCode,
    this.birthCityCode,
    this.birthTownCode,
    this.familyName,
    this.givenName,
    this.citizenSexLabel,
    this.birthDate,
    this.genesisHashHex,
    this.expectedIdentityVersion,
    this.authorizationExpiresAt,
  });

  /// 附加授权字段；只有整段授权字节解码成功才会带上。
  VotingIdentityConsentPayload withAuthorization({
    required String genesisHashHex,
    required int expectedIdentityVersion,
    required int authorizationExpiresAt,
  }) {
    return VotingIdentityConsentPayload(
      cidLevel: cidLevel,
      cidNumber: cidNumber,
      accountId: accountId,
      accountAddress: accountAddress,
      validFrom: validFrom,
      validUntil: validUntil,
      statusNormal: statusNormal,
      provinceCode: provinceCode,
      cityCode: cityCode,
      townCode: townCode,
      birthProvinceCode: birthProvinceCode,
      birthCityCode: birthCityCode,
      birthTownCode: birthTownCode,
      familyName: familyName,
      givenName: givenName,
      citizenSexLabel: citizenSexLabel,
      birthDate: birthDate,
      genesisHashHex: genesisHashHex,
      expectedIdentityVersion: expectedIdentityVersion,
      authorizationExpiresAt: authorizationExpiresAt,
    );
  }

  /// 0x 小写 hex 创世哈希;锁定本次授权只对该链有效。
  final String? genesisHashHex;

  /// 授权声明的身份版本;须等于链上当前值。
  final int? expectedIdentityVersion;

  /// 授权失效时间(Unix 秒)。
  final int? authorizationExpiresAt;

  final CitizenIdentityConsentLevel cidLevel;
  final String cidNumber;

  /// 0x 小写 hex,32 字节公民钱包公钥。
  final String accountId;

  /// SS58(prefix 走 citizenSs58Prefix 单源)展示地址。
  final String accountAddress;

  /// YYYYMMDD 整数。
  final int validFrom;
  final int validUntil;

  /// true=NORMAL,false=REVOKED。
  final bool statusNormal;

  final String provinceCode;
  final String cityCode;
  final String townCode;
  final String? birthProvinceCode;
  final String? birthCityCode;
  final String? birthTownCode;
  final String? familyName;
  final String? givenName;
  final String? citizenSexLabel;

  /// 出生日期(YYYYMMDD 整数),仅竞选身份携带。
  final int? birthDate;

  bool get isCandidate => cidLevel == CitizenIdentityConsentLevel.candidate;

  /// 解码完整授权字节,必须恰好消费完全部字节。
  ///
  /// 任何字段越界、长度非法、日期非法、状态未知都返回 null,
  /// 由调用方按"无法独立验证"拒签。
  static VotingIdentityConsentPayload? decode(Uint8List bytes) {
    const genesisHashLen = 32;
    const trailerLen = 16; // version(8) + expires_at(8)
    if (bytes.length <= genesisHashLen + trailerLen) return null;

    final inner = Uint8List.sublistView(
      bytes,
      genesisHashLen,
      bytes.length - trailerLen,
    );
    final decoded = _decodeCandidate(inner) ?? _decodeVotingRoot(inner);
    if (decoded == null) return null;

    return decoded.withAuthorization(
      genesisHashHex: _bytesToLowerHex(
        Uint8List.sublistView(bytes, 0, genesisHashLen),
      ),
      expectedIdentityVersion: _readU64Le(bytes, bytes.length - trailerLen),
      authorizationExpiresAt: _readU64Le(bytes, bytes.length - 8),
    );
  }

  /// 确认页展示条目,字段中文名与 citizenwallet 确认页一致。
  List<(String, String)> get reviewEntries => [
    ('身份类型', isCandidate ? '参选身份' : '投票身份'),
    ('CID编号', cidNumber),
    ('公民钱包账户', accountAddress),
    ('护照有效期', '${_formatDateInt(validFrom)} 至 ${_formatDateInt(validUntil)}'),
    ('身份状态', statusNormal ? '正常' : '注销'),
    ('居住地', '$provinceCode / $cityCode / $townCode'),
    if (isCandidate) ...[
      ('出生地', '$birthProvinceCode / $birthCityCode / $birthTownCode'),
      ('出生日期', birthDate == null ? '' : _formatDateInt(birthDate!)),
      ('公民姓名', '${familyName ?? ''}${givenName ?? ''}'),
      ('公民性别', citizenSexLabel ?? ''),
    ],
    if (authorizationExpiresAt != null)
      ('授权有效期至', _formatUnixSeconds(authorizationExpiresAt!)),
  ];

  static VotingIdentityConsentPayload? _decodeVotingRoot(Uint8List bytes) {
    final decoded = _readVotingIdentityPayload(bytes, 0);
    if (decoded == null || decoded.next != bytes.length) return null;
    return decoded.payload;
  }

  static VotingIdentityConsentPayload? _decodeCandidate(Uint8List bytes) {
    final voting = _readVotingIdentityPayload(bytes, 0);
    if (voting == null) return null;
    var offset = voting.next;

    final (birthProvinceCode, afterBirthProvince) = _readUtf8Vec(
      bytes,
      offset,
      maxLen: 16,
    );
    if (birthProvinceCode == null) return null;
    offset = afterBirthProvince;
    final (birthCityCode, afterBirthCity) = _readUtf8Vec(
      bytes,
      offset,
      maxLen: 16,
    );
    if (birthCityCode == null) return null;
    offset = afterBirthCity;
    final (birthTownCode, afterBirthTown) = _readUtf8Vec(
      bytes,
      offset,
      maxLen: 16,
    );
    if (birthTownCode == null) return null;
    offset = afterBirthTown;
    final (familyName, afterFamilyName) = _readUtf8Vec(
      bytes,
      offset,
      maxLen: 128,
    );
    if (familyName == null) return null;
    offset = afterFamilyName;
    final (givenName, afterGivenName) = _readUtf8Vec(
      bytes,
      offset,
      maxLen: 128,
    );
    if (givenName == null) return null;
    offset = afterGivenName;
    if (offset >= bytes.length) return null;
    final sex = bytes[offset];
    offset += 1;
    final sexLabel = switch (sex) {
      0 => '男',
      1 => '女',
      _ => null,
    };
    if (sexLabel == null) return null;

    // birth_date: u32 YYYYMMDD(LE),CandidateIdentityPayload 末字段。
    if (offset + 4 > bytes.length) return null;
    final birthDate = _readU32Le(bytes, offset);
    offset += 4;
    if (!_isValidDateInt(birthDate) || offset != bytes.length) return null;

    final base = voting.payload;
    return VotingIdentityConsentPayload(
      cidLevel: CitizenIdentityConsentLevel.candidate,
      cidNumber: base.cidNumber,
      accountId: base.accountId,
      accountAddress: base.accountAddress,
      validFrom: base.validFrom,
      validUntil: base.validUntil,
      statusNormal: base.statusNormal,
      provinceCode: base.provinceCode,
      cityCode: base.cityCode,
      townCode: base.townCode,
      birthProvinceCode: birthProvinceCode,
      birthCityCode: birthCityCode,
      birthTownCode: birthTownCode,
      familyName: familyName,
      givenName: givenName,
      citizenSexLabel: sexLabel,
      birthDate: birthDate,
    );
  }

  static ({VotingIdentityConsentPayload payload, int next})?
  _readVotingIdentityPayload(Uint8List bytes, int offset) {
    final (cidNumber, afterCid) = _readUtf8Vec(bytes, offset, maxLen: 32);
    if (cidNumber == null) return null;
    offset = afterCid;
    // 投票载荷不含年龄:account_id(32) + valid_from(4) + valid_until(4) + status(1)。
    if (offset + 32 + 4 + 4 + 1 > bytes.length) return null;

    final walletBytes = bytes.sublist(offset, offset + 32);
    offset += 32;

    final validFrom = _readU32Le(bytes, offset);
    offset += 4;
    final validUntil = _readU32Le(bytes, offset);
    offset += 4;
    if (!_isValidDateInt(validFrom) || !_isValidDateInt(validUntil)) {
      return null;
    }
    if (validUntil < validFrom) return null;

    final status = bytes[offset];
    offset += 1;
    if (status > 1) return null;

    final (provinceCode, afterProvince) = _readUtf8Vec(
      bytes,
      offset,
      maxLen: 16,
    );
    if (provinceCode == null) return null;
    offset = afterProvince;
    final (cityCode, afterCity) = _readUtf8Vec(bytes, offset, maxLen: 16);
    if (cityCode == null) return null;
    offset = afterCity;
    final (townCode, afterTown) = _readUtf8Vec(bytes, offset, maxLen: 16);
    if (townCode == null) return null;
    offset = afterTown;

    return (
      payload: VotingIdentityConsentPayload(
        cidLevel: CitizenIdentityConsentLevel.voting,
        cidNumber: cidNumber,
        accountId: citizenAccountIdFromBytes(walletBytes),
        accountAddress: citizenSs58FromAccountIdBytes(walletBytes),
        validFrom: validFrom,
        validUntil: validUntil,
        statusNormal: status == 0,
        provinceCode: provinceCode,
        cityCode: cityCode,
        townCode: townCode,
      ),
      next: offset,
    );
  }

  static (String?, int) _readUtf8Vec(
    Uint8List bytes,
    int offset, {
    required int maxLen,
  }) {
    if (offset >= bytes.length) return (null, offset);
    final (len, lenSize) = _decodeCompactU32(bytes, offset);
    if (lenSize == 0) return (null, offset);
    offset += lenSize;
    if (len <= 0 || len > maxLen || offset + len > bytes.length) {
      return (null, offset);
    }
    final text = utf8.decode(
      bytes.sublist(offset, offset + len),
      allowMalformed: false,
    );
    if (text.trim().isEmpty) return (null, offset);
    return (text, offset + len);
  }

  /// 解码 SCALE `Compact<u32>`,返回 (值, 消耗字节数);big-int 模式不会出现在
  /// 本载荷的长度前缀里,按非法处理。
  static (int, int) _decodeCompactU32(Uint8List bytes, int offset) {
    try {
      final decoded = CitizenScale.readCompact(bytes, offset);
      return decoded.$2 <= 4 ? decoded : (0, 0);
    } on FormatException {
      return (0, 0);
    }
  }

  static int _readU64Le(Uint8List bytes, int offset) =>
      CitizenScale.readUnsigned(bytes, offset, 8).toSigned(64).toInt();

  /// Unix 秒 → 本地时区 `YYYY-MM-DD HH:mm`。
  static String _formatUnixSeconds(int seconds) {
    final local = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static int _readU32Le(Uint8List bytes, int offset) =>
      CitizenScale.readUnsigned(bytes, offset, 4).toInt();

  static bool _isValidDateInt(int value) {
    final year = value ~/ 10000;
    final month = (value ~/ 100) % 100;
    final day = value % 100;
    return year >= 1900 &&
        year <= 9999 &&
        month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= 31;
  }

  static String _formatDateInt(int value) {
    final year = value ~/ 10000;
    final month = (value ~/ 100) % 100;
    final day = value % 100;
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  static String _bytesToLowerHex(Uint8List bytes) {
    return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}
