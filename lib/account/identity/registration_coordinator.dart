import 'package:citizenapp/security/identity_binding.dart';

import 'registration_api.dart';
import 'registration_models.dart';
import 'registration_store.dart';

/// 唯一编排；服务器结果持久化在任何钱包动作之前。同一时刻只允许一个账户编排。
class RegistrationCoordinator {
  RegistrationCoordinator({RegistrationApi? api, RegistrationStore? store})
    : api = api ?? RegistrationApi(),
      store = store ?? RegistrationStore();
  final RegistrationApi api;
  final RegistrationStore store;
  Future<FinalizedRegistration>? _flight;
  String? _context;
  IdentityBinding? activeBinding;
  Future<void> Function()? _guard;
  Future<void> requireActiveCurrent() async => _guard?.call();
  Future<FinalizedRegistration> run({
    required RegistrationContext context,
    required Future<void> Function() requireCurrent,
    required Future<String?> Function(RegistrationVerification)
    showVerification,
    required Future<bool> Function() ensureAffordable,
    required Future<FinalizedRegistration?> Function() readFinalized,
    required Future<FinalizedRegistration> Function(
      Future<void> Function(Map<String, dynamic>),
    )
    registerCid,
    Future<bool> Function(Map<String, dynamic>?)? canRetryChain,
    required Future<String> Function(FinalizedRegistration) activate,
  }) {
    if (_flight != null) {
      if (_context == context.hash) return _flight!;
      throw const RegistrationException('另一个账户正在注册，请完成后再切换');
    }
    _context = context.hash;
    _guard = requireCurrent;
    late final Future<FinalizedRegistration> future;
    future =
        _run(
          context,
          requireCurrent,
          showVerification,
          ensureAffordable,
          readFinalized,
          registerCid,
          activate,
          canRetryChain,
        ).whenComplete(() {
          if (identical(_flight, future)) {
            _flight = null;
            _context = null;
            activeBinding = null;
            _guard = null;
          }
        });
    _flight = future;
    return future;
  }

  Future<FinalizedRegistration> _run(
    RegistrationContext context,
    Future<void> Function() guard,
    Future<String?> Function(RegistrationVerification) showPage,
    Future<bool> Function() affordable,
    Future<FinalizedRegistration?> Function() readChain,
    Future<FinalizedRegistration> Function(
      Future<void> Function(Map<String, dynamic>),
    )
    register,
    Future<String> Function(FinalizedRegistration) activate,
    Future<bool> Function(Map<String, dynamic>?)? canRetryChain,
  ) async {
    await guard();
    final previous = await store.read(context);
    final prepared = previous == null;
    var response = previous == null
        ? await api.prepare(context)
        : await api.status(context, previous.capabilities);
    await guard();
    var record = previous == null
        ? RegistrationRecord(
            context: context,
            capabilities: RegistrationCapabilities(
              response.enrollmentId,
              registrationText(response.json, 'recovery_token'),
            ),
            response: response,
          )
        : previous.next(response: response);
    await store.save(previous, record);
    if (response.state == RegistrationState.cancelled ||
        response.state == RegistrationState.expired) {
      final existing = await readChain();
      await guard();
      if (existing == null &&
          record.phase == RegistrationPhase.chainPending &&
          !(await canRetryChain?.call(record.checkpoint) ?? false)) {
        throw const RegistrationException('登记已过期，原交易结果尚未确认；不会重复上链');
      }
      response = await api.prepare(context);
      await guard();
      final renewed = RegistrationRecord(
        context: context,
        capabilities: RegistrationCapabilities(
          response.enrollmentId,
          registrationText(response.json, 'recovery_token'),
        ),
        response: response,
        phase: existing == null
            ? RegistrationPhase.verification
            : RegistrationPhase.finalized,
        finalized: existing,
        checkpoint: record.checkpoint,
      );
      await store.save(record, renewed);
      record = renewed;
    }
    if (response.state == RegistrationState.prepared) {
      if (!prepared) {
        response = await api.status(
          context,
          record.capabilities,
          operation: 'refresh_verification',
        );
        await guard();
        final next = record.next(response: response);
        await store.save(record, next);
        record = next;
      }
      final verification = response.verification!;
      if (verification.expiresAt <= DateTime.now().millisecondsSinceEpoch) {
        throw const RegistrationException('验证页面已过期，请重试');
      }
      final token = await showPage(verification);
      await guard();
      if (token == null) {
        throw const RegistrationException(
          '注册验证已取消',
          code: 'verification_cancelled',
        );
      }
      response = await api.verify(
        context,
        record.capabilities,
        verificationId: verification.id,
        token: token,
      );
      await guard();
      if (response.state != RegistrationState.humanVerified) {
        throw const RegistrationException('服务器未保存验证通过结果');
      }
      final next = record.next(
        response: response,
        phase: RegistrationPhase.verified,
      );
      await store.save(record, next);
      record = next;
    }
    // 恢复时先读真实finalized链事实；网络异常向上抛，绝不等同“未注册”。
    var finalized = await readChain();
    await guard();
    if (record.finalized != null &&
        (finalized == null ||
            finalized.binding.cidNumber !=
                record.finalized!.binding.cidNumber ||
            finalized.binding.bindingRevision !=
                record.finalized!.binding.bindingRevision)) {
      throw const RegistrationException('注册身份绑定已变化，请核实当前账户');
    }
    if (finalized == null) {
      if ((record.phase == RegistrationPhase.chainPending &&
              !(await canRetryChain?.call(record.checkpoint) ?? false)) ||
          record.finalized != null ||
          response.state == RegistrationState.activated) {
        throw const RegistrationException('链交易结果尚未确认，请稍后恢复；不会重复签名或上链');
      }
      if (!await affordable()) {
        throw const RegistrationException('余额不足，充值后可继续本次登记');
      }
      await guard();
      final pending = record.next(phase: RegistrationPhase.chainPending);
      await store.save(record, pending);
      record = pending;
      await guard();
      try {
        finalized = await register((checkpoint) async {
          await guard();
          final next = record.next(checkpoint: checkpoint);
          await store.save(record, next);
          record = next;
          await guard();
        });
      } on RegistrationBeforeBroadcastException {
        await guard();
        await store.save(
          record,
          record.next(phase: RegistrationPhase.verified),
        );
        rethrow;
      }
      await guard();
    }
    if (finalized.binding.accountId != context.accountId ||
        finalized.binding.genesisHash != context.chainScope) {
      throw const RegistrationException('finalized身份与所选账户或链不一致');
    }
    // 当前链绑定核验通过后保留原注册的finalized回执，不用新头覆盖原交易区块。
    finalized = record.finalized ?? finalized;
    final completed = record.next(
      phase: RegistrationPhase.finalized,
      finalized: finalized,
    );
    await store.save(record, completed);
    record = completed;
    activeBinding = finalized.binding;
    try {
      final deviceId = await activate(finalized);
      await guard();
      response = await api.status(context, record.capabilities);
      await guard();
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(deviceId) ||
          response.state != RegistrationState.activated ||
          response.json['activation']['device_id'] != deviceId ||
          response.json['activation']['cid_number'] !=
              finalized.binding.cidNumber ||
          response.json['activation']['binding_revision'] !=
              finalized.binding.bindingRevision) {
        throw const RegistrationException('服务器设备激活尚未完成');
      }
      await store.save(
        record,
        record.next(response: response, phase: RegistrationPhase.ready),
      );
      return finalized;
    } catch (_) {
      throw const RegistrationException(
        'CID已注册，设备激活待完成；请重试恢复，不会重复上链',
        code: 'activation_pending',
      );
    }
  }
}
