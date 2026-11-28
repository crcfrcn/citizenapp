// 定义当前用户快照、公开绑定及跨功能导航接口。

import 'package:citizen_system/security/access.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/security.dart' show AccountSecurityService;
import 'package:citizen_user/identity/state.dart' show IdentityBadgeSnapshot, IdentityBadgeSnapshotStore;
import 'dart:convert';
import 'package:flutter/widgets.dart';

// 提供聊天、通讯录及主页共用的本机当前用户绑定快照。

/// 普通业务的当前用户快照；账户直接使用 CitizenSDK 公开模型。
final class CurrentUser {
  const CurrentUser({
    required this.account,
    required this.binding,
    this.verifiedUnregistered = false,
  });

  final CitizenWalletStateAccount account;
  final IdentityBinding? binding;

  /// 仅完整验真得到空身份才成立；本机缺绑定仍是未知。
  final bool verifiedUnregistered;

  String get accountId => account.accountId;
  String get accountAddress => account.ss58Address;
  String get cidNumber => binding?.cidNumber ?? '';
  int get bindRev => binding?.bindRev ?? 0;
  bool get isRegistered => binding != null;
  bool get isUnregistered => binding == null && verifiedUnregistered;
}

typedef CurrentUserBindingReader = Future<IdentityBinding?> Function(
  String accountId,
);

/// Chat、通讯录、主页和动态共用的本机当前用户入口。
///
/// 默认账户来自 CitizenSDK 全局顺序第一项；绑定是 CitizenApp 自己的 finalized 业务缓存。
interface class CurrentUserContext {
  CurrentUserContext({
    CitizenSdk? wallet,
    required AccountSecurityService accountSecurity,
    CurrentUserBindingReader? bindingReader,
    Future<IdentityBadgeSnapshot?> Function(String)? identityReader,
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
  }) : _accountSecurity = accountSecurity,
       _bindingReader = bindingReader,
       _identityReader = identityReader,
       _getWalletState =
           getWalletState ??
           wallet?.getWalletState ??
           (() => throw StateError('未配置getWalletState'));
  final CitizenSdkOperation<CitizenWalletState> Function() _getWalletState;

  final AccountSecurityService _accountSecurity;
  final CurrentUserBindingReader? _bindingReader;
  final Future<IdentityBadgeSnapshot?> Function(String)? _identityReader;

  CurrentUser? _cached;
  int _cachedRevision = -1;
  Future<CurrentUser?>? _inflight;
  int _generation = 0;

  Future<CurrentUser?> resolve() async {
    final revision = _accountSecurity.revision.value;
    final cached = _cached;
    if (cached != null && _cachedRevision == revision) return cached;
    final inflight = _inflight;
    if (inflight != null) return inflight;
    final generation = _generation;
    final future = _resolveFresh(revision, generation);
    _inflight = future;
    try {
      return await future;
    } finally {
      if (identical(_inflight, future)) _inflight = null;
    }
  }

  Future<String?> accountId() async => (await resolve())?.accountId;

  Future<IdentityBinding?> binding() async => (await resolve())?.binding;

  Future<CurrentUser?> _resolveFresh(int revision, int generation) async {
    final account = (await _getWalletState().result).defaultAccount;
    if (account == null) return null;
    var binding =
        await (_bindingReader?.call(account.accountId) ??
            _accountSecurity.readIdentityBindingForAccountId(
              account.accountId,
            ));
    IdentityBadgeSnapshot? saved;
    try {
      saved =
          await (_identityReader?.call(account.accountId) ??
              IdentityBadgeSnapshotStore().readForAccountId(account.accountId));
    } on Object {
      // 展示库不可读不能触发查链，也不能把缓存缺失认作未注册。
    }
    final unregistered = saved?.verified == true && saved?.identity == null;
    if (unregistered) binding = null;
    final current = CurrentUser(
      account: account,
      binding: binding,
      verifiedUnregistered: unregistered,
    );
    if (_generation == generation &&
        _accountSecurity.revision.value == revision) {
      _cached = current;
      _cachedRevision = revision;
      return current;
    }
    // 迟到快照不能展示或授权；这是重试异常，不能把已有钱包误判为未注册。
    throw const AccountSecurityException(
      '当前用户已变化，请重试',
      code: 'identityChanged',
    );
  }

  void invalidate() {
    _generation += 1;
    _cached = null;
    _cachedRevision = -1;
    _inflight = null;
  }
}

// 表示链上已确认的公开CID与账户绑定。

/// 链上已确认的公开身份绑定；不含任何钱包或数据秘密。
final class IdentityBinding {
  const IdentityBinding({
    required this.genesisHash,
    required this.cidNumber,
    required this.bindRev,
    required this.accountId,
  });
  final String genesisHash;
  final String cidNumber;
  final int bindRev;
  final String accountId;
  static final _hash = RegExp(r'^0x[0-9a-f]{64}$');
  void validate() {
    if (!_hash.hasMatch(genesisHash) ||
        !isCitizenAccountId(accountId) ||
        !RegExp(r'^[\x21-\x39\x3b-\x7e]{1,32}$').hasMatch(cidNumber) ||
        bindRev <= 0 ||
        bindRev > 9007199254740991) {
      throw const FormatException('公开身份绑定格式无效');
    }
  }

  Map<String, Object> toJson() => {
    'genesis_hash': genesisHash,
    'cid_number': cidNumber,
    'bind_rev': bindRev,
    'account_id': accountId,
  };
  static IdentityBinding? fromJson(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> ||
          value.length != 4 ||
          value['genesis_hash'] is! String ||
          value['cid_number'] is! String ||
          value['bind_rev'] is! int ||
          value['account_id'] is! String) {
        return null;
      }
      final binding = IdentityBinding(
        genesisHash: value['genesis_hash'] as String,
        cidNumber: value['cid_number'] as String,
        bindRev: value['bind_rev'] as int,
        accountId: value['account_id'] as String,
      );
      binding.validate();
      return binding;
    } on FormatException {
      return null;
    }
  }
}

// 声明用户模块的聊天、支付、主页和联系人选择导航意图。

typedef DirectChatOpener =
    Future<void> Function(
      BuildContext context, {
      required String peerUserId,
      required String title,
    });

// 用户模块只描述用户动作，具体聊天和支付页面由根App装配。
final class UserNavigation {
  const UserNavigation({
    required this.openDirectChat,
    required this.openTransfer,
  });
  final DirectChatOpener openDirectChat;
  final Future<void> Function(BuildContext context, {required String cidNumber})
  openTransfer;
}

/// 通讯录页使用模式。
enum ContactPickMode {
  /// 常规浏览:点联系人进主页,卡片带「转账/私信/改名/删除」操作菜单。
  browse,

  /// 选收款人(交易页发起):点联系人即返回公民号，由调用方选择收款人。
  pickForTransfer,

  /// 发起聊天内嵌多选列表；只交付选中联系人，不负责打开聊天。
  pickForChat,
}
