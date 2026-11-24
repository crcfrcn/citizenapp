// 展示运行时升级详情，并按机构岗位资格提供联合投票。

import 'package:citizen_system/security/account_security_exception.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:flutter/services.dart';

import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_citizen/institution/governance_registry.dart';
import 'package:citizen_citizen/proposal/proposal_context.dart';
import 'package:citizen_citizen/proposal/proposal_detail_local_store.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';
import 'package:citizen_citizen/runtime/runtime_upgrade_service.dart';
import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_citizen/proposal/proposal_vote_widgets.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 协议升级提案详情页。
///
/// 从全链提案页进入时为只读模式；
/// 从机构详情页进入时，当前机构岗位有效选民可直接提交联合投票。
class RuntimeUpgradeDetailPage extends StatefulWidget {
  const RuntimeUpgradeDetailPage({
    super.key,
    required this.proposalId,
    required this.proposalContext,
    this.resolveVoteContext,
  });

  final BigInt proposalId;

  /// 统一的提案上下文（包含机构信息和管理员钱包）。
  final ProposalContext proposalContext;
  final Future<ProposalContext> Function()? resolveVoteContext;

  /// 便捷访问。
  InstitutionInfo? get institution => proposalContext.institution;
  List<CitizenWalletStateAccount> get adminWallets =>
      proposalContext.adminWallets;

  @override
  State<RuntimeUpgradeDetailPage> createState() =>
      _RuntimeUpgradeDetailPageState();
}

class _RuntimeUpgradeDetailPageState extends State<RuntimeUpgradeDetailPage> {
  late final RuntimeUpgradeService _service;
  late final ProposalQueryService _proposalQueryService;
  bool _dependenciesReady = false;
  ProposalContext? _verifiedVoteContext;
  ProposalContext get _proposalContext =>
      _verifiedVoteContext ?? widget.proposalContext;
  List<CitizenWalletStateAccount> get _voteWallets =>
      _proposalContext.adminWallets;
  StreamSubscription<Set<BigInt>>? _localUpdates;
  bool _preparingVote = false;

  Future<void> _readLocalDetail() async {
    final snapshot = await _applyLocalSnapshot();
    if (!mounted || snapshot != null) return;
    setState(() {
      _loading = false;
      _error = '该提案的本机记录已不可用';
    });
  }

  final ProposalDetailLocalStore _detailStore =
      ProposalDetailLocalStore.instance;

  bool _loading = true;
  bool _submitting = false;
  bool _ticketsReady = false;
  String? _error;

  RuntimeUpgradeProposalInfo? _proposalInfo;
  ProposalMeta? _meta;
  ({int yes, int no}) _jointTally = (yes: 0, no: 0);
  ({int yes, int no}) _referendumTally = (yes: 0, no: 0);
  bool _reasonExpanded = false;

  bool? _institutionVote;
  List<EligibleVoterTicket> _voterTickets = const [];
  ({int yes, int no}) _institutionAdminTally = (yes: 0, no: 0);
  Map<String, bool?> _ticketVotes = const {};
  List<CitizenWalletStateAccount> _votableWallets = const [];
  CitizenWalletStateAccount? _selectedVoteWallet;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    final sdk = context.read<CitizenSdk>();
    _service = RuntimeUpgradeService(chain: sdk, transactions: sdk);
    _proposalQueryService = ProposalQueryService(chain: sdk);
    _dependenciesReady = true;
    if (widget.resolveVoteContext == null) {
      _load();
    } else {
      _localUpdates = _detailStore.changes.listen((ids) {
        if (ids.contains(widget.proposalId) &&
            mounted &&
            !_submitting &&
            !_preparingVote) {
          _verifiedVoteContext = null;
          unawaited(_readLocalDetail());
        }
      });
      unawaited(_readLocalDetail());
    }
  }

  @override
  void dispose() {
    unawaited(_localUpdates?.cancel());
    super.dispose();
  }

  bool get _isAdmin => _proposalContext.isAdmin;

  int get _requiredAdminThreshold => widget.institution?.internalThreshold ?? 0;

  String get _voterRoleCode => widget.institution?.orgType == OrgType.prb
      ? 'DIRECTOR'
      : 'COMMITTEE_MEMBER';

  bool get _jointVoteOpen =>
      (_meta?.status == 0) && (_meta?.stage == 1) && _resolvedStatusCode() == 0;

  bool get _canSubmitVote =>
      _ticketsReady &&
      _isAdmin &&
      _jointVoteOpen &&
      _institutionVote == null &&
      _selectedVoteWallet != null &&
      !_submitting;

  bool get _allImportedVotersVoted {
    if (!_isAdmin) return false;
    final imported = _voterTickets
        .where(
          (ticket) => _voteWallets.any(
            (wallet) => ticket.voterAccountId == wallet.accountId,
          ),
        )
        .toList();
    return imported.isNotEmpty &&
        imported.every((ticket) => _ticketVotes[ticket.ticketKey] != null);
  }

  List<CitizenWalletStateAccount> _matchingWallets(
    List<EligibleVoterTicket> tickets,
    Map<String, bool?> votes,
  ) =>
      _voteWallets
          .where(
            (wallet) => tickets.any(
              (ticket) =>
                  ticket.voterAccountId == wallet.accountId &&
                  votes[ticket.ticketKey] == null,
            ),
          )
          .toList()
        ..sort((a, b) => a.walletIndex.compareTo(b.walletIndex));

  String? get _voteDisabledReason {
    if (!_isAdmin) return null;
    if (!_jointVoteOpen) return '当前提案不在联合投票阶段';
    if (_institutionVote != null) return '本机构已形成最终投票结果';
    if (_votableWallets.isEmpty && _allImportedVotersVoted) {
      return '已导入的岗位选民钱包都已完成投票';
    }
    if (_votableWallets.isEmpty) return '当前没有可用的岗位选民钱包';
    if (_selectedVoteWallet == null) return '请选择用于投票的岗位选民钱包';
    return null;
  }

  Future<void> _load({bool showSpinner = true}) async {
    _ticketsReady = false;
    ProposalDetailSnapshot? localSnapshot;
    if (showSpinner) {
      localSnapshot = await _applyLocalSnapshot();
    }
    if (showSpinner &&
        localSnapshot?.isFresh(ProposalDetailLocalStore.activeTtl) == true) {
      return;
    }

    if (showSpinner && localSnapshot == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _error = null);
    }

    if (!mounted) {
      return;
    }
    try {
      final sdk = context.read<CitizenSdk>();
      final block = widget.resolveVoteContext == null
          ? null
          : await sdk.getFinalizedHead();
      if (!mounted) {
        return;
      }
      final reads = block == null
          ? _service
          : RuntimeUpgradeService(
              chain: sdk,
              getFinalizedHead: () async => block,
            );
      final query = block == null
          ? _proposalQueryService
          : ProposalQueryService(chain: sdk, block: block);
      final futures = <Future<dynamic>>[
        reads.fetchProposalMeta(widget.proposalId),
        widget.resolveVoteContext == null
            ? reads.fetchRuntimeUpgradeProposal(widget.proposalId)
            : Future.value(_proposalInfo),
        reads.fetchJointTally(widget.proposalId),
        reads.fetchReferendumTally(widget.proposalId),
      ];

      final institution = widget.institution;
      if (institution != null) {
        futures.add(
          query.fetchEligibleVoterTickets(widget.proposalId, institution),
        );
        futures.add(
          reads.fetchJointVoteByInstitution(
            widget.proposalId,
            institution.cidNumber,
          ),
        );
        futures.add(
          reads.fetchJointInstitutionTally(
            widget.proposalId,
            institution.cidNumber,
          ),
        );
      }

      final results = await Future.wait(futures);
      final meta = results[0] as ProposalMeta?;
      final proposalInfo = results[1] as RuntimeUpgradeProposalInfo?;
      final jointTally = results[2] as ({int yes, int no});
      final referendumTally = results[3] as ({int yes, int no});

      List<EligibleVoterTicket> tickets = const [];
      bool? institutionVote;
      ({int yes, int no}) institutionAdminTally = (yes: 0, no: 0);
      Map<String, bool?> adminVotes = const {};
      List<CitizenWalletStateAccount> votableWallets = const [];
      CitizenWalletStateAccount? selectedVoteWallet = _selectedVoteWallet;
      if (institution != null) {
        tickets = (results[4] as List<EligibleVoterTicket>)
            .where((ticket) => ticket.voterRoleCode == _voterRoleCode)
            .toList();
        institutionVote = results[5] as bool?;
        institutionAdminTally = results[6] as ({int yes, int no});
        final votes = await reads.fetchJointTicketVotesBatch(
          widget.proposalId,
          institution.cidNumber,
          _voterRoleCode,
          tickets.map((ticket) => ticket.personCid!),
        );
        adminVotes = {
          for (final ticket in tickets)
            ticket.ticketKey: votes[ticket.personCid],
        };
        votableWallets = _matchingWallets(tickets, adminVotes);

        if (selectedVoteWallet == null ||
            !votableWallets.any(
              (wallet) => wallet.walletIndex == selectedVoteWallet!.walletIndex,
            )) {
          selectedVoteWallet = votableWallets.isNotEmpty
              ? votableWallets.first
              : null;
        }
      }

      if (!mounted) {
        return;
      }
      if (widget.resolveVoteContext == null) {
        try {
          await _detailStore.put(
            _snapshotFromChain(
              meta: meta,
              proposalInfo: proposalInfo,
              jointTally: jointTally,
              referendumTally: referendumTally,
              tickets: tickets,
              adminVotes: adminVotes,
              institutionVote: institutionVote,
              institutionAdminTally: institutionAdminTally,
            ),
          );
        } catch (_) {
          // 详情快照写入失败不能影响链上最新结果展示。
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _meta = meta;
        _proposalInfo = proposalInfo;
        _jointTally = jointTally;
        _referendumTally = referendumTally;
        _voterTickets = tickets;
        _institutionVote = institutionVote;
        _institutionAdminTally = institutionAdminTally;
        _ticketVotes = adminVotes;
        _votableWallets = votableWallets;
        _selectedVoteWallet = selectedVoteWallet;
        _loading = false;
        _ticketsReady = true;
      });
    } catch (e) {
      _ticketsReady = false;
      if (!mounted) {
        return;
      }
      if (widget.resolveVoteContext != null) rethrow;
      if (localSnapshot != null) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = '协议升级链状态暂时不可用';
        _loading = false;
      });
    }
  }

  Future<ProposalDetailSnapshot?> _applyLocalSnapshot() async {
    try {
      final snapshot = await _detailStore.read(
        'runtime_upgrade',
        widget.proposalId,
      );
      if (snapshot == null || !mounted) return snapshot;
      final tickets = snapshot.voterTickets;
      if (widget.institution != null &&
          (tickets.isEmpty ||
              tickets.any(
                (ticket) =>
                    ticket.cidNumber != widget.institution!.cidNumber ||
                    ticket.voterRoleCode != _voterRoleCode ||
                    ticket.personCid == null,
              ))) {
        return null;
      }
      final votableWallets = _matchingWallets(tickets, snapshot.adminVotes);

      setState(() {
        _ticketsReady = false;
        _meta = _metaFromSnapshot(snapshot);
        _proposalInfo = _proposalInfoFromSnapshot(snapshot);
        _jointTally = (
          yes: _toInt(snapshot.extra['joint_yes']) ?? snapshot.yesCount,
          no: _toInt(snapshot.extra['joint_no']) ?? snapshot.noCount,
        );
        _referendumTally = (
          yes: _toInt(snapshot.extra['referendum_yes']) ?? 0,
          no: _toInt(snapshot.extra['referendum_no']) ?? 0,
        );
        _voterTickets = tickets;
        _institutionVote = _toBool(snapshot.extra['institution_vote']);
        _institutionAdminTally = (
          yes: _toInt(snapshot.extra['institution_yes']) ?? 0,
          no: _toInt(snapshot.extra['institution_no']) ?? 0,
        );
        _ticketVotes = snapshot.adminVotes;
        _votableWallets = votableWallets;
        _selectedVoteWallet = votableWallets.isNotEmpty
            ? votableWallets.first
            : null;
        _loading = false;
        _error = null;
      });
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  ProposalDetailSnapshot _snapshotFromChain({
    required ProposalMeta? meta,
    required RuntimeUpgradeProposalInfo? proposalInfo,
    required ({int yes, int no}) jointTally,
    required ({int yes, int no}) referendumTally,
    required List<EligibleVoterTicket> tickets,
    required Map<String, bool?> adminVotes,
    required bool? institutionVote,
    required ({int yes, int no}) institutionAdminTally,
  }) {
    return ProposalDetailSnapshot(
      proposalId: widget.proposalId,
      proposalKind: 'runtime_upgrade',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      status: meta?.status,
      yesCount: jointTally.yes,
      noCount: jointTally.no,
      threshold: _requiredAdminThreshold,
      admins: tickets
          .map((ticket) => ticket.voterAccountId)
          .whereType<String>()
          .toSet()
          .toList(),
      adminVotes: Map.of(adminVotes),
      pendingPublicKeys: const [],
      detail: _proposalInfoToJson(proposalInfo),
      extra: {
        'voter_tickets': ProposalDetailSnapshot.encodeTickets(tickets),
        'meta_kind': meta?.kind,
        'meta_stage': meta?.stage,
        'meta_status': meta?.status,
        'meta_internal_code': meta?.internalCode,
        'meta_subject_cid_numbers': meta?.subjectCidNumbers,
        'meta_actor_cid_number': meta?.actorCidNumber,
        'meta_execution_account_id': meta?.executionAccountId == null
            ? null
            : citizenAccountIdFromBytes(meta!.executionAccountId!),
        'joint_yes': jointTally.yes,
        'joint_no': jointTally.no,
        'referendum_yes': referendumTally.yes,
        'referendum_no': referendumTally.no,
        'institution_vote': institutionVote,
        'institution_yes': institutionAdminTally.yes,
        'institution_no': institutionAdminTally.no,
      },
    );
  }

  Map<String, Object?> _proposalInfoToJson(RuntimeUpgradeProposalInfo? info) {
    if (info == null) return const {};
    return {
      'actor_cid_number': info.actorCidNumber,
      'proposer': info.proposer,
      'reason': info.reason,
      'code_hash_hex': info.codeHashHex,
      'expected_pow_params_hash_hex': info.expectedPowParamsHashHex,
      'params_version': info.paramsVersion,
      'algorithm_version': info.algorithmVersion,
      'target_block_time_ms': info.targetBlockTimeMs,
      'adjustment_interval': info.adjustmentInterval,
      'max_adjust_up_factor': info.maxAdjustUpFactor,
      'max_adjust_down_divisor': info.maxAdjustDownDivisor,
    };
  }

  RuntimeUpgradeProposalInfo? _proposalInfoFromSnapshot(
    ProposalDetailSnapshot snapshot,
  ) {
    final detail = snapshot.detail;
    final actorCidNumber = detail['actor_cid_number']?.toString();
    final codeHash = detail['code_hash_hex']?.toString();
    final paramsHash = detail['expected_pow_params_hash_hex']?.toString();
    final paramsVersion = _toInt(detail['params_version']);
    final algorithmVersion = _toInt(detail['algorithm_version']);
    final targetBlockTimeMs = _toInt(detail['target_block_time_ms']);
    final adjustmentInterval = _toInt(detail['adjustment_interval']);
    final maxAdjustUpFactor = _toInt(detail['max_adjust_up_factor']);
    final maxAdjustDownDivisor = _toInt(detail['max_adjust_down_divisor']);
    if (actorCidNumber == null ||
        actorCidNumber.isEmpty ||
        codeHash == null ||
        codeHash.isEmpty ||
        paramsHash == null ||
        paramsVersion == null ||
        algorithmVersion == null ||
        targetBlockTimeMs == null ||
        adjustmentInterval == null ||
        maxAdjustUpFactor == null ||
        maxAdjustDownDivisor == null) {
      return null;
    }
    return RuntimeUpgradeProposalInfo(
      proposalId: snapshot.proposalId,
      actorCidNumber: actorCidNumber,
      proposer: detail['proposer']?.toString() ?? '',
      reason: detail['reason']?.toString() ?? '',
      codeHashHex: codeHash,
      expectedPowParamsHashHex: paramsHash,
      paramsVersion: paramsVersion,
      algorithmVersion: algorithmVersion,
      targetBlockTimeMs: targetBlockTimeMs,
      adjustmentInterval: adjustmentInterval,
      maxAdjustUpFactor: maxAdjustUpFactor,
      maxAdjustDownDivisor: maxAdjustDownDivisor,
    );
  }

  ProposalMeta? _metaFromSnapshot(ProposalDetailSnapshot snapshot) {
    final kind = _toInt(snapshot.extra['meta_kind']);
    final stage = _toInt(snapshot.extra['meta_stage']);
    final status = _toInt(snapshot.extra['meta_status']);
    if (kind == null || stage == null || status == null) return null;
    final executionAccountId = snapshot.extra['meta_execution_account_id']
        ?.toString();
    return ProposalMeta(
      proposalId: snapshot.proposalId,
      kind: kind,
      stage: stage,
      status: status,
      internalCode: snapshot.extra['meta_internal_code']?.toString(),
      actorCidNumber: snapshot.extra['meta_actor_cid_number']?.toString(),
      subjectCidNumbers: _toStringList(
        snapshot.extra['meta_subject_cid_numbers'],
      ),
      executionAccountId:
          executionAccountId == null || executionAccountId.isEmpty
          ? null
          : citizenAccountIdBytes(executionAccountId),
    );
  }

  int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  List<String> _toStringList(Object? value) {
    if (value is Iterable) {
      return value.map((v) => v.toString()).toList(growable: false);
    }
    return const [];
  }

  bool? _toBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value.toString() == 'true') return true;
    if (value.toString() == 'false') return false;
    return null;
  }

  String _requireAccountId(String accountId) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }

  String _truncateAddress(String address) {
    if (address.length <= 14) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  String _truncateWalletAddress(String address) {
    if (address.length <= 18) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }

  Future<void> _submitJointVote(bool approve) async {
    final institution = widget.institution;
    final voteWallet = _selectedVoteWallet;
    if (institution == null || voteWallet == null) return;

    setState(() => _submitting = true);

    try {
      final result = await _service.submitJointVote(
        proposalId: widget.proposalId,
        actorCidNumber: institution.cidNumber,
        voterRoleCode: _voterRoleCode,
        approve: approve,
        signerPublicKey: citizenAccountIdBytes(voteWallet.accountId),
        externalSigning: (pending) => showCitizenSdkQrResponse(
          context,
          request: pending.qrRequest,
          expiresAt: BigInt.from(
            pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
          ),
        ),
      );

      final accountId = _requireAccountId(voteWallet.accountId);
      final ticket = _voterTickets.singleWhere(
        (ticket) => ticket.voterAccountId == accountId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ticketVotes = {..._ticketVotes, ticket.ticketKey: approve};
        _institutionAdminTally = (
          yes: _institutionAdminTally.yes + (approve ? 1 : 0),
          no: _institutionAdminTally.no + (approve ? 0 : 1),
        );
        _votableWallets = _votableWallets
            .where((w) => _requireAccountId(w.accountId) != accountId)
            .toList(growable: false);
        _selectedVoteWallet = _votableWallets.isNotEmpty
            ? _votableWallets.first
            : null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('联合投票已由 runtime 确认：${_truncateAddress(result.txHash)}'),
          backgroundColor: AppTheme.primaryDark,
        ),
      );
      if (widget.resolveVoteContext == null) {
        unawaited(_load(showSpinner: false));
      }
    } on AccountSecurityException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投票失败：$e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _confirmVote(bool approve) async {
    final resolve = widget.resolveVoteContext;
    if (_preparingVote || _submitting) return;
    if (resolve != null) setState(() => _preparingVote = true);
    try {
      if (resolve != null) {
        final verified = await resolve();
        if (!mounted) {
          return;
        }
        if (!verified.isAdmin) throw StateError('当前钱包没有投票资格');
        _verifiedVoteContext = verified;
      }
      // 缓存和入口上下文只用于展示；每次确认前重新核对冻结人员与当前绑定。
      await _load(showSpinner: false);
      if (!mounted) return;
      if (_error != null || !_canSubmitVote) {
        throw StateError(_error ?? '提案已停止投票或当前钱包没有未使用的投票票据');
      }
      if (resolve != null && ModalRoute.of(context)?.isCurrent != true) return;
      final label = approve ? '赞成' : '反对';
      final choices = resolve != null && _votableWallets.length > 1
          ? _votableWallets
          : const <CitizenWalletStateAccount>[];
      var selected = _selectedVoteWallet;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, updateDialog) {
            return AlertDialog(
              title: Text('确认提交$label票'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('将使用所选岗位选民钱包直接提交$label票。投票后不可修改。'),
                  if (choices.isNotEmpty)
                    DropdownButton<int>(
                      isExpanded: true,
                      value: selected?.walletIndex,
                      items: [
                        for (final wallet in choices)
                          DropdownMenuItem(
                            value: wallet.walletIndex,
                            child: Text(
                              wallet.ss58Address,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (index) => updateDialog(() {
                        selected = choices.firstWhere(
                          (wallet) => wallet.walletIndex == index,
                        );
                      }),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(label),
                ),
              ],
            );
          },
        ),
      );
      if (!mounted || confirmed != true) return;
      if (resolve != null && ModalRoute.of(context)?.isCurrent != true) return;
      _selectedVoteWallet = selected;
      await _submitJointVote(approve);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('投票校验未通过：$error')));
      }
    } finally {
      if (resolve != null && mounted) {
        _verifiedVoteContext = null;
        await _readLocalDetail();
        if (mounted) setState(() => _preparingVote = false);
      }
    }
  }

  int? _resolvedStatusCode() {
    // 协议升级真实状态只以投票引擎元数据为准。
    return _meta?.status;
  }

  String _institutionVoteLabel() {
    if (_institutionVote == null) return '待形成机构结果';
    return _institutionVote! ? '机构已赞成' : '机构已反对';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '协议升级详情',
          style: TextStyle(
            fontSize: AppLayout.scaled(context, 17),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _buildContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaledValue(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: AppLayout.scaledValue(48),
              color: AppTheme.danger,
            ),
            SizedBox(height: AppLayout.scaledValue(12)),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(16),
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(6)),
            Text(
              _error!,
              style: TextStyle(
                fontSize: AppLayout.scaledValue(12),
                color: AppTheme.textTertiary,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: AppLayout.scaledValue(16)),
            OutlinedButton(
              onPressed: widget.resolveVoteContext == null
                  ? _load
                  : _readLocalDetail,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: () async {
        if (widget.resolveVoteContext == null) {
          await _load();
        } else {
          await _readLocalDetail();
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ProposalStatusBadge(
            status: _meta?.status,
            proposalId: widget.proposalId,
          ),
          SizedBox(height: AppLayout.scaledValue(16)),
          _buildProposalInfoCard(),
          SizedBox(height: AppLayout.scaledValue(16)),
          _buildJointVotingProgress(),
          if (_isAdmin) ...[
            SizedBox(height: AppLayout.scaledValue(16)),
            _buildInstitutionVoteCard(),
          ],
          if (_meta?.stage == 2) ...[
            SizedBox(height: AppLayout.scaledValue(16)),
            _buildJointReferendumProgress(),
          ],
        ],
      ),
    );
  }

  Widget _buildProposalInfoCard() {
    final info = _proposalInfo;
    final reason = info?.reason ?? '';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaledValue(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '提案信息',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(16),
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(12)),
            _buildInfoRow('提案 ID', formatProposalId(_meta?.displayMeta)),
            if (widget.institution != null) ...[
              Divider(height: AppLayout.scaledValue(20)),
              _buildInfoRow('当前机构简称', widget.institution!.shortName),
            ],
            if (info != null) ...[
              Divider(height: AppLayout.scaledValue(20)),
              _buildInfoRow(
                '发起人',
                _truncateAddress(info.proposer),
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: info.proposer));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('地址已复制'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              Divider(height: AppLayout.scaledValue(20)),
              _buildInfoRow(
                'Code Hash',
                _truncateAddress(info.codeHashHex),
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: info.codeHashHex));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Code Hash 已复制'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              _buildRemarkRow('升级理由', reason),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRemarkRow(String label, String text) {
    if (text.isEmpty) {
      return _buildInfoRow(label, '无');
    }
    final isLong = text.length > 30;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppLayout.scaledValue(80),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(13),
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(13),
              color: AppTheme.textPrimary,
            ),
            maxLines: _reasonExpanded ? null : 1,
            overflow: _reasonExpanded ? null : TextOverflow.ellipsis,
          ),
        ),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _reasonExpanded = !_reasonExpanded),
            child: Icon(
              _reasonExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: AppLayout.scaledValue(20),
              color: AppTheme.textTertiary,
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {VoidCallback? onCopy}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppLayout.scaledValue(80),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(13),
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(13),
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        if (onCopy != null)
          GestureDetector(
            onTap: onCopy,
            child: Icon(
              Icons.copy,
              size: AppLayout.scaledValue(16),
              color: AppTheme.textTertiary,
            ),
          ),
      ],
    );
  }

  Widget _buildJointVotingProgress() {
    final progress = jointVotePassThreshold > 0
        ? (_jointTally.yes / jointVotePassThreshold).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaledValue(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '联合投票进度',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(16),
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(12)),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppLayout.scaledValue(6)),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: AppLayout.scaledValue(10),
                backgroundColor: AppTheme.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryDark,
                ),
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(8)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '赞成 ${_jointTally.yes} 票 / 通过阈值 $jointVotePassThreshold',
                  style: TextStyle(
                    fontSize: AppLayout.scaledValue(14),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryDark,
                  ),
                ),
                Text(
                  '反对 ${_jointTally.no} 票',
                  style: TextStyle(
                    fontSize: AppLayout.scaledValue(13),
                    color: AppTheme.danger,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppLayout.scaledValue(6)),
            Text(
              '联合投票总权重 $jointVoteTotal，国家储委会权重 19，省储委会/省储行各权重 1',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(12),
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionVoteCard() {
    final institution = widget.institution!;
    final progress = _requiredAdminThreshold > 0
        ? (_institutionAdminTally.yes / _requiredAdminThreshold).clamp(0.0, 1.0)
        : 0.0;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaledValue(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本机构投票',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(16),
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(12)),
            _buildInfoRow('机构简称', institution.shortName),
            Divider(height: AppLayout.scaledValue(20)),
            _buildInfoRow('投票状态', _institutionVoteLabel()),
            Divider(height: AppLayout.scaledValue(20)),
            Text(
              '岗位选民赞成 ${_institutionAdminTally.yes} 票 / $_requiredAdminThreshold',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(14),
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppLayout.scaledValue(6)),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: AppLayout.scaledValue(8),
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _institutionVote == true
                      ? AppTheme.primaryDark
                      : AppTheme.warning,
                ),
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '岗位选民反对 ${_institutionAdminTally.no} 票',
                  style: TextStyle(
                    fontSize: AppLayout.scaledValue(13),
                    color: AppTheme.danger,
                  ),
                ),
                Text(
                  '提案岗位快照 ${_voterTickets.length} 人',
                  style: TextStyle(
                    fontSize: AppLayout.scaledValue(12),
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
            Divider(height: AppLayout.scaledValue(20)),
            _buildVoteWalletSelector(),
            if (_voterTickets.isNotEmpty) ...[
              SizedBox(height: AppLayout.scaledValue(8)),
              Text(
                '本机构仅提案创建时冻结的岗位有效选民可直接上链投票；赞成达到机构阈值会形成机构赞成结果，剩余选民已不足以达到阈值时会形成机构反对结果。',
                style: TextStyle(
                  fontSize: AppLayout.scaledValue(12),
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoteWalletSelector() {
    if (!_isAdmin) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppLayout.scaledValue(12)),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
        ),
        child: Text(
          '当前未导入属于本机构岗位快照的选民钱包',
          style: TextStyle(
            fontSize: AppLayout.scaledValue(13),
            color: AppTheme.warning,
          ),
        ),
      );
    }

    if (_votableWallets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppLayout.scaledValue(12)),
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
        ),
        child: Text(
          _allImportedVotersVoted ? '已导入岗位选民钱包均已完成投票' : '当前没有可用的岗位选民钱包',
          style: TextStyle(
            fontSize: AppLayout.scaledValue(13),
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    if (_votableWallets.length == 1) {
      final wallet = _votableWallets.first;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          _truncateWalletAddress(wallet.ss58Address),
          style: TextStyle(fontSize: AppLayout.scaledValue(13)),
        ),
        subtitle: Text(
          citizenSs58FromAccountId(wallet.accountId),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppLayout.scaledValue(11),
            color: AppTheme.textTertiary,
          ),
        ),
        trailing: Icon(
          Icons.shield_outlined,
          size: AppLayout.scaledValue(18),
          color: AppTheme.warning,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppLayout.scaledValue(12)),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedVoteWallet?.walletIndex,
          isExpanded: true,
          items: _votableWallets.map((wallet) {
            return DropdownMenuItem<int>(
              value: wallet.walletIndex,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _truncateWalletAddress(wallet.ss58Address),
                      style: TextStyle(fontSize: AppLayout.scaledValue(13)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: AppLayout.scaledValue(8)),
                  Icon(
                    Icons.shield_outlined,
                    size: AppLayout.scaledValue(18),
                    color: AppTheme.warning,
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (walletIndex) {
            if (walletIndex == null) return;
            setState(() {
              _selectedVoteWallet = _votableWallets.firstWhere(
                (wallet) => wallet.walletIndex == walletIndex,
              );
            });
          },
        ),
      ),
    );
  }

  Widget _buildJointReferendumProgress() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaledValue(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '联合公投进度',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(16),
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '赞成 ${_referendumTally.yes} 票',
                  style: TextStyle(
                    fontSize: AppLayout.scaledValue(14),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryDark,
                  ),
                ),
                Text(
                  '反对 ${_referendumTally.no} 票',
                  style: TextStyle(
                    fontSize: AppLayout.scaledValue(13),
                    color: AppTheme.danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 联合公投阶段判断
  bool get _jointReferendumOpen =>
      (_meta?.status == 0) && (_meta?.stage == 2) && _resolvedStatusCode() == 0;

  Widget? _buildBottomBar() {
    if (_loading || _error != null) return null;
    if (_jointVoteOpen &&
        (_isAdmin ||
            (widget.resolveVoteContext != null &&
                widget.institution != null))) {
      return _buildVoteButtons();
    }
    // 联合公投阶段：所有用户显示投票按钮（链上公民身份校验后续完善）
    if (_jointReferendumOpen) {
      return _buildJointReferendumButtons();
    }
    // 非投票阶段但存在机构签名钱包上下文：显示禁用状态的投票按钮。
    if (_isAdmin) {
      return _buildVoteButtons();
    }
    return null;
  }

  Widget _buildJointReferendumButtons() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.06),
            blurRadius: AppLayout.scaledValue(8),
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '联合公投',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(13),
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () => _confirmJointReferendumVote(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.danger.withValues(
                      alpha: 0.25,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: AppLayout.scaledValue(14),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(10),
                      ),
                    ),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: AppLayout.scaledValue(18),
                          height: AppLayout.scaledValue(18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('反对'),
                ),
              ),
              SizedBox(width: AppLayout.scaledValue(12)),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () => _confirmJointReferendumVote(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.success.withValues(
                      alpha: 0.25,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: AppLayout.scaledValue(14),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(10),
                      ),
                    ),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: AppLayout.scaledValue(18),
                          height: AppLayout.scaledValue(18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('赞成'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmJointReferendumVote(bool approve) {
    final label = approve ? '赞成' : '反对';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('确认联合公投$label'),
        content: Text('将对此协议升级提案投"$label"票。投票后不可修改。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _submitJointReferendumVote(approve);
            },
            child: Text(label),
          ),
        ],
      ),
    );
  }

  Future<void> _submitJointReferendumVote(bool approve) async {
    // 联合公投提交依赖链上 cast_referendum extrinsic，入口未开放前只提示状态。
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('联合公投功能开发中'),
        backgroundColor: AppTheme.warning,
      ),
    );
  }

  Widget _buildVoteButtons() {
    final canVote =
        !_preparingVote &&
        !_submitting &&
        (widget.resolveVoteContext != null ? _jointVoteOpen : _canSubmitVote);
    final disabledReason = widget.resolveVoteContext == null
        ? _voteDisabledReason
        : null;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.06),
            blurRadius: AppLayout.scaledValue(8),
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (disabledReason != null)
            Padding(
              padding: EdgeInsets.only(bottom: AppLayout.scaledValue(10)),
              child: Text(
                disabledReason,
                style: TextStyle(
                  fontSize: AppLayout.scaledValue(13),
                  color: AppTheme.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: canVote ? () => _confirmVote(false) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.danger.withValues(
                      alpha: 0.25,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: AppLayout.scaledValue(14),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(10),
                      ),
                    ),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: AppLayout.scaledValue(18),
                          height: AppLayout.scaledValue(18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('反对'),
                ),
              ),
              SizedBox(width: AppLayout.scaledValue(12)),
              Expanded(
                child: ElevatedButton(
                  onPressed: canVote ? () => _confirmVote(true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.success.withValues(
                      alpha: 0.25,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: AppLayout.scaledValue(14),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(10),
                      ),
                    ),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: AppLayout.scaledValue(18),
                          height: AppLayout.scaledValue(18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('赞成'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
