import 'package:citizen_account/identity/identity_binding.dart';

import 'package:citizen_account/identity/registration_api.dart';
import 'package:citizen_account/identity/registration_models.dart';
import 'package:citizen_account/identity/registration_store.dart';

/// 唯一编排；服务器结果持久化在任何钱包动作之前。同一时刻只允许一个账户编排。
class RegistrationCoordinator {
  RegistrationCoordinator({RegistrationApi? api, RegistrationStore? store})
    : api = api ?? RegistrationApi(),
      store = store ?? RegistrationStore();
  final RegistrationApi api;
  final RegistrationStore store;
  Future<FinalizedRegistration>? _flight;
  String? _context;
  bool get isRegistering => _flight != null;
  IdentityBinding? activeBinding;
  Future<void> Function()? _guard;
  Future<void> requireActiveCurrent() async => _guard?.call();
  Future<FinalizedRegistration> run({
    required RegistrationContext context,
    required Future<void> Function() requireCurrent,
    required Future<String?> Function(RegistrationVerification)
    showVerification,
    required Future<void> Function() requireAffordable,
    required Future<FinalizedRegistration?> Function() readFinalized,
    required Future<FinalizedRegistration> Function(
      Future<void> Function(Map<String, dynamic>),
    )
    registerCid,
    Future<bool> Function(Map<String, dynamic>?)? canRetryChain,
    required Future<String> Function(FinalizedRegistration) activate,
  }) {
    if (_flight != null) {
      if (_context == context.contextHash) return _flight!;
      throw const RegistrationException('另一个账户正在注册，请完成后再切换');
    }
    _context = context.contextHash;
    _guard = requireCurrent;
    late final Future<FinalizedRegistration> future;
    future =
        _run(
          context,
          requireCurrent,
          showVerification,
          requireAffordable,
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
    Future<void> Function() affordable,
    Future<FinalizedRegistration?> Function() readChain,
    Future<FinalizedRegistration> Function(
      Future<void> Function(Map<String, dynamic>),
    )
    register,
    Future<String> Function(FinalizedRegistration) activate,
    Future<bool> Function(Map<String, dynamic>?)? canRetryChain,
  ) async {
    await guard();
    // 先核对真实finalized事实；失败直接抛出，不创建登记、不打开真人验证。
    final existing = await readChain();
    await guard();
    final previous = await store.read(context);
    if (existing != null) {
      return _completeExisting(context, previous, existing, guard, activate);
    }
    final prepared = previous == null;
    var response = previous == null
        ? await api.prepare(context)
        : await api.status(context, previous.capabilities);
    await guard();
    var record = previous == null
        ? RegistrationRecord(
            context: context,
            capabilities: RegistrationCapabilities(
              response.regId,
              registrationText(response.json, 'recovery_token'),
            ),
            response: response,
          )
        : previous.next(response: response);
    await store.save(previous, record);
    if (response.jobState == RegistrationState.cancelled ||
        response.jobState == RegistrationState.expired) {
      final existing = await readChain();
      await guard();
      if (existing != null) {
        return _completeExisting(context, record, existing, guard, activate);
      }
      if (record.phase == RegistrationPhase.chainPending &&
          !(await canRetryChain?.call(record.checkpoint) ?? false)) {
        throw const RegistrationException('登记已过期，原交易结果尚未确认；不会重复上链');
      }
      response = await api.prepare(context);
      await guard();
      final renewed = RegistrationRecord(
        context: context,
        capabilities: RegistrationCapabilities(
          response.regId,
          registrationText(response.json, 'recovery_token'),
        ),
        response: response,
        phase: RegistrationPhase.verification,
        checkpoint: record.checkpoint,
      );
      await store.save(record, renewed);
      record = renewed;
    }
    if (response.jobState == RegistrationState.prepared) {
      final existing = await readChain();
      await guard();
      if (existing != null) {
        return _completeExisting(context, record, existing, guard, activate);
      }
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
      if (verification.pageExpiresAt <= DateTime.now().millisecondsSinceEpoch) {
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
        checkId: verification.checkId,
        token: token,
      );
      await guard();
      if (response.jobState != RegistrationState.humanVerified) {
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
    if (finalized != null) {
      return _completeExisting(context, record, finalized, guard, activate);
    }
    if (record.finalized != null) {
      throw const RegistrationException('注册身份绑定已变化，请核实当前账户');
    }
    if (finalized == null) {
      if (response.jobState != RegistrationState.humanVerified &&
          response.jobState != RegistrationState.activated) {
        throw const RegistrationException('新注册必须先通过真人验证');
      }
      if ((record.phase == RegistrationPhase.chainPending &&
              !(await canRetryChain?.call(record.checkpoint) ?? false)) ||
          record.finalized != null ||
          response.jobState == RegistrationState.activated) {
        throw const RegistrationException('链交易结果尚未确认，请稍后恢复；不会重复签名或上链');
      }
      // 费用读取失败与确认余额不足由调用方分别抛出带代码的结果，不再用 bool
      // 把所有失败误报成钱包余额不足。
      await affordable();
      await guard();
      finalized = await readChain();
      await guard();
      if (finalized != null) {
        return _completeExisting(context, record, finalized, guard, activate);
      }
      if (finalized == null) {
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
          response.jobState != RegistrationState.activated ||
          response.json['activation']['device_id'] != deviceId ||
          response.json['activation']['cid_number'] !=
              finalized.binding.cidNumber ||
          response.json['activation']['bind_rev'] !=
              finalized.binding.bindRev) {
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

  Future<FinalizedRegistration> _completeExisting(
    RegistrationContext context,
    RegistrationRecord? previous,
    FinalizedRegistration existing,
    Future<void> Function() guard,
    Future<String> Function(FinalizedRegistration) activate,
  ) async {
    final saved = previous?.finalized?.binding;
    final binding = existing.binding;
    if (binding.accountId != context.accountId ||
        binding.genesisHash != context.chainScope ||
        (saved != null &&
            (saved.cidNumber != binding.cidNumber ||
                saved.accountId != binding.accountId ||
                saved.genesisHash != binding.genesisHash ||
                saved.bindRev != binding.bindRev))) {
      throw const RegistrationException('finalized身份与当前账户或链不一致');
    }
    final finalized = previous?.finalized ?? existing;
    activeBinding = finalized.binding;
    try {
      final deviceId = await activate(finalized);
      await guard();
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(deviceId)) {
        throw const RegistrationException('普通会话设备校验失败');
      }
      // 仅推进本机阶段，保留真实服务响应，不伪造activated或真人验证。
      if (previous != null) {
        await store.save(
          previous,
          previous.next(phase: RegistrationPhase.ready, finalized: finalized),
        );
      }
      return finalized;
    } on Object {
      throw const RegistrationException(
        '公民号已存在，服务准备未完成，请重试',
        code: 'activation_pending',
      );
    }
  }
}
