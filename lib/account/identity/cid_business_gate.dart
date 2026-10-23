import 'current_user_context.dart';
import 'finalized_identity_resolver.dart';
import 'package:flutter/foundation.dart';

/// 公民服务业务入口的唯一前置结果；此阶段绝不读取或创建 MLS 身份。
enum CidBusinessStatus { ready, unregistered, noWallet, unavailable }

final class CidBusinessDecision {
  const CidBusinessDecision(this.status, {this.cidNumber});

  final CidBusinessStatus status;
  final String? cidNumber;
}

/// 先用当前钱包身份判断公民号。只有本机身份未知时才核对链事实并同步公开绑定。
/// 链故障、账户切换和同步失败均为未知状态，不能冒充未注册。
interface class CidBusinessGate {
  CidBusinessGate({
    required CurrentUserContext currentUserContext,
    required FinalizedIdentityResolver identityResolver,
    required Future<void> Function(FinalizedIdentity) synchronizeIdentity,
    required this.revision,
  }) : _currentUser = currentUserContext,
       _resolver = identityResolver,
       _synchronize = synchronizeIdentity;

  final CurrentUserContext _currentUser;
  final FinalizedIdentityResolver _resolver;
  final Future<void> Function(FinalizedIdentity) _synchronize;
  final ValueListenable<int> revision;
  final Map<(String, int), Future<CidBusinessDecision>> _inflight = {};

  Future<CidBusinessDecision> resolve() async {
    late final Future<CidBusinessDecision> pending;
    try {
      final current = await _currentUser.resolve();
      if (current == null) {
        return const CidBusinessDecision(CidBusinessStatus.noWallet);
      }
      final key = (current.accountId, revision.value);
      final existing = _inflight[key];
      if (existing != null) {
        pending = existing;
      } else {
        late final Future<CidBusinessDecision> task;
        task = _resolve(current, key.$2).whenComplete(() {
          if (identical(_inflight[key], task)) {
            _inflight.remove(key);
          }
        });
        _inflight[key] = task;
        pending = task;
      }
    } on Object {
      return const CidBusinessDecision(CidBusinessStatus.unavailable);
    }
    // 在 try 外交付原 Future，保留去重任务既有的异步异常传播范围。
    return pending;
  }

  Future<CidBusinessDecision> _resolve(CurrentUser current, int expectedRevision) async {
    try {
      if (current.isUnregistered) {
        return const CidBusinessDecision(CidBusinessStatus.unregistered);
      }
      final local = current.binding;
      if (local != null && local.accountId == current.accountId) {
        return CidBusinessDecision(
          CidBusinessStatus.ready,
          cidNumber: local.cidNumber,
        );
      }

      final verified = await _resolver.resolve();
      if (verified == null) {
        return const CidBusinessDecision(CidBusinessStatus.noWallet);
      }
      // 链读取期间默认账户可能变化；未注册结论也必须绑定仍然有效的账户。
      final latest = await _currentUser.resolve();
      if (verified.accountId != current.accountId ||
          latest?.accountId != current.accountId ||
          latest?.binding != null ||
          revision.value != expectedRevision) {
        return const CidBusinessDecision(CidBusinessStatus.unavailable);
      }
      final snapshot = verified.snapshot;
      if (snapshot == null) {
        await _synchronize(verified);
        _currentUser.invalidate();
        return const CidBusinessDecision(CidBusinessStatus.unregistered);
      }

      // 只同步已验证的公开绑定；原有单源负责通知会话和聊天身份变更。
      await _synchronize(verified);
      _currentUser.invalidate();
      final restored = await _currentUser.resolve();
      final binding = restored?.binding;
      if (restored?.accountId != verified.accountId ||
          binding?.cidNumber != snapshot.cidNumber ||
          binding?.bindingRevision != snapshot.bindingRevision ||
          binding?.accountId != verified.accountId) {
        return const CidBusinessDecision(CidBusinessStatus.unavailable);
      }
      return CidBusinessDecision(
        CidBusinessStatus.ready,
        cidNumber: binding!.cidNumber,
      );
    } on Object {
      return const CidBusinessDecision(CidBusinessStatus.unavailable);
    }
  }
}
