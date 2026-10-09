import 'package:citizenapp/8964/profile/citizen_profile_cache.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/8964/services/square_post_store.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import 'package:citizenapp/security/identity_binding.dart';

/// 注销用户编排：签名提交或恢复查询 → 云端真实完成 → 逐项清理本地。
///
/// 顺序钉死：**先取得服务端完成回执**（op_tag 0x1D 主钥签名；失败即上抛、绝不清本地，
/// 保证「服务端没删就别动本地」的一致性），**成功后再清本地**（资料缓存 / 会话缓存 /
/// 本人广场副本与检查点 / SDK所属MLS身份与私信历史）。
/// 钱包与链上身份不受影响。
class SquareAccountLocalCleanupException implements Exception {
  const SquareAccountLocalCleanupException(this.failures);

  final List<String> failures;

  @override
  String toString() => '服务端已注销，但本机清理未完成：${failures.join('；')}';
}

class SquareAccountDeletionService {
  SquareAccountDeletionService({
    required ChatSdk chatRuntime,
    SquareApiClient? apiClient,
    CitizenProfileCache? profileCache,
    CitizenProfileMediaCache? profileMediaCache,
    SquareLocalPostBulkDeletionStore? localPostStore,
  }) : _api = apiClient ?? SquareApiClient(),
       _profileCache = profileCache ?? const CitizenProfileCache(),
       _profileMediaCache = profileMediaCache ?? CitizenProfileMediaCache(),
       _chatRuntime = chatRuntime,
       _localPostStore = localPostStore ?? const SquarePostStore();

  final SquareApiClient _api;
  final CitizenProfileCache _profileCache;
  final CitizenProfileMediaCache _profileMediaCache;
  final ChatSdk _chatRuntime;
  final SquareLocalPostBulkDeletionStore _localPostStore;

  /// [signAction] 对 signing_message(0x1D) 摘要用 sr25519 主钥签名（弹生物识别）。
  Future<void> deleteAccount({
    required IdentityBinding binding,
    Future<void> Function()? requireCurrent,
    required SquareActionSigner signAction,
  }) async {
    // 1. 服务端完成确认（失败或pending上抛 → 本地一律不动，UI/数据保持一致）。
    await _api.deleteAccount(binding: binding, signAction: signAction, requireCurrent: requireCurrent);
    final cidNumber = binding.cidNumber;
    final accountId = binding.accountId;
    // 2. 服务端确认后逐项清本地。单项失败不能阻断后续项，否则会制造更多残留。
    final failures = <String>[];
    Future<void> attempt(String label, Future<void> Function() action) async {
      try {
        await action();
      } on Object catch (error) {
        failures.add('$label：$error');
      }
    }

    await attempt('广场本人副本', () async {
      await _localPostStore.deleteAllByCid(cidNumber);
    });
    // 资料缓存的唯一键是 cid_number；account_id 只清理账户级会话与 Chat 数据。
    await attempt('资料缓存', () => _profileCache.clear(cidNumber));
    await attempt('资料图片缓存', () => _profileMediaCache.clearCid(cidNumber));
    await attempt('会话缓存', () async => _api.clearSession(accountId));
    await attempt(
      '私信历史',
      () => _chatRuntime.clearAllForUserId(
        userId: cidNumber,
        accountId: accountId,
      ),
    );

    if (failures.isNotEmpty) {
      throw SquareAccountLocalCleanupException(
        List<String>.unmodifiable(failures),
      );
    }
  }
}
