import 'package:citizen_user/identity/registration_api.dart';
import 'package:citizen_user/identity/registration_models.dart';
import 'package:citizen_user/identity/registration_store.dart';

/// 一次默认人验后执行原链注册，最终确认后只报告公开绑定。
class RegistrationCoordinator {
  RegistrationCoordinator({RegistrationApi? api, RegistrationStore? store})
    : api = api ?? RegistrationApi(),
      store = store ?? RegistrationStore();
  final RegistrationApi api;
  final RegistrationStore store;
  Future<FinalizedRegistration>? _flight;
  String? _context;
  bool get isRegistering => _flight != null;
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
  }) {
    if (_flight != null) {
      if (_context == context.recordKey) return _flight!;
      throw const RegistrationException('另一个账户正在注册，请完成后再切换');
    }
    _context = context.recordKey;
    late final Future<FinalizedRegistration> task;
    task =
        _run(
          context,
          requireCurrent,
          showVerification,
          requireAffordable,
          readFinalized,
          registerCid,
          canRetryChain,
          report,
        ).whenComplete(() {
          if (identical(_flight, task)) {
            _flight = null;
            _context = null;
          }
        });
    _flight = task;
    return task;
  }

  Future<FinalizedRegistration> _run(
    RegistrationContext context,
    Future<void> Function() guard,
    Future<RegistrationVerification?> Function() showPage,
    Future<void> Function() affordable,
    Future<FinalizedRegistration?> Function() readChain,
    Future<FinalizedRegistration> Function(
      Future<void> Function(Map<String, dynamic>),
    )
    register,
    Future<bool> Function(Map<String, dynamic>?)? canRetry,
    Future<void> Function(FinalizedRegistration) report,
  ) async {
    await guard();
    var finalized = await readChain();
    await guard();
    var record = await store.read(context);
    await guard();
    if (finalized == null) {
      if (record?.finalized != null) {
        throw const RegistrationException(
          '已确认的链绑定发生变化，请核实账户',
          code: 'identityChanged',
        );
      }
      final checkpoint = record?.checkpoint;
      if (checkpoint != null &&
          !{
            'prepared',
            'cancelled_before_broadcast',
          }.contains(checkpoint['state']) &&
          !(await canRetry?.call(checkpoint) ?? false)) {
        throw const RegistrationException(
          '链交易结果尚未确认，不会重复签名注册',
          code: 'chain_pending',
        );
      }
      final verification = await showPage();
      await guard();
      if (verification == null) {
        throw const RegistrationException(
          '真人验证已取消',
          code: 'verification_cancelled',
        );
      }
      await api.verify(context, verification);
      await guard();
      await affordable();
      await guard();
      finalized = await readChain();
      await guard();
      if (finalized == null) {
        finalized = await register((checkpoint) async {
          await guard();
          final next = RegistrationRecord(
            context: context,
            checkpoint: Map.unmodifiable(checkpoint),
          );
          await store.save(record, next);
          record = next;
          await guard();
        });
        await guard();
      }
    }
    final binding = finalized.binding;
    binding.validate();
    if (binding.accountId != context.accountId ||
        binding.genesisHash != context.chainScope) {
      throw const RegistrationException(
        '链注册结果与所选账户或链不一致',
        code: 'identityChanged',
      );
    }
    final saved = record?.finalized;
    if (saved != null &&
        (saved.binding.cidNumber != binding.cidNumber ||
            saved.binding.accountId != binding.accountId ||
            saved.binding.genesisHash != binding.genesisHash ||
            saved.binding.bindRev != binding.bindRev)) {
      throw const RegistrationException('已确认的链绑定发生变化', code: 'identityChanged');
    }
    finalized = saved ?? finalized;
    if (saved == null) {
      final next = (record ?? RegistrationRecord(context: context)).next(
        finalized: finalized,
      );
      await store.save(record, next);
      record = next;
      await guard();
    }
    try {
      await report(finalized);
      await guard();
    } on RegistrationException {
      rethrow;
    } on Object {
      throw const RegistrationException(
        '公民号已上链，服务同步失败，请主动重试',
        code: 'report_pending',
      );
    }
    return finalized;
  }
}
