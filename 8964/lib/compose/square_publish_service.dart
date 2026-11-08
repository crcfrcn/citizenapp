import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_storage/social_isar.dart' as social_store show Publish;

import 'package:citizen_square/draft/compose_draft_store.dart';
import 'package:citizen_square/post/square_local_post_presenter.dart';

import 'package:citizen_user/identity/finalized_identity_resolver.dart';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_system/app_log.dart';

import 'package:citizen_square/compose/square_chain_service.dart';
import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_user/identity/square_identity_state.dart';
import 'package:citizen_square/post/square_post_deletion_coordinator.dart';
import 'package:citizen_square/post/square_post_store.dart';
import 'package:citizen_square/media/square_upload_service.dart';

class SquarePublishException implements Exception {
  const SquarePublishException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SquarePublishResult {
  const SquarePublishResult({
    required this.post,
    required this.txHash,
    required this.blockHash,
    this.completionWarning,
  });

  final SquarePost post;
  final String txHash;
  final String blockHash;

  /// 远端已发布、本地收尾或原帖删除仍待显式恢复时的成功告警。
  final String? completionWarning;
}

abstract class SquarePublishBalanceReader {
  Future<BigInt> fetchFreshFinalizedBalanceFen(String accountId);

  /// 自付一笔最低链上交易所需的余额门槛(分),取自链上常量,App 侧无副本。
  Future<BigInt> fetchMinSelfPayBalanceFen();
}

class SquareChainBalanceReader implements SquarePublishBalanceReader {
  const SquareChainBalanceReader(this._chain);

  final CitizenSdk? _chain;

  @override
  Future<BigInt> fetchFreshFinalizedBalanceFen(String accountId) async {
    final balance = await _chain!.getAccountBalance(
      accountId,
      forceRefresh: true,
    );
    return balance.freeFen;
  }

  @override
  Future<BigInt> fetchMinSelfPayBalanceFen() async {
    final fees = await _chain!.getFeeSnapshot();
    return fees.minimumSelfPayFen;
  }
}

class SquarePublishService {
  SquarePublishService({
    required SquareContentUploader uploadService,
    required FinalizedIdentityResolver identityResolver,
    CitizenSdk? chain,
    CitizenSdk? transactions,
    SquarePostChainPublisher? chainService,
    SquarePublicationConfirmer? publicationConfirmer,
    SquarePostDeleteCoordinator? postDeletionCoordinator,
    SquarePublishBalanceReader? balanceReader,
    SquareLocalPostWriter? localPostWriter,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
    Future<CitizenPreparedTransaction> Function(
      Uint8List sourceAccountId,
      Uint8List callData,
    )?
    prepareTransaction,
    Future<CitizenTransactionExecution> Function(String preparationId)?
    executePreparedTransaction,
    Future<void> Function(String executionId)?
    cancelPreparedTransactionExecution,
    Future<CitizenTransactionExecutionCompleted> Function(
      String executionId,
      String response,
    )?
    consumePreparedTransactionQrResponse,
  }) : _identityResolver = identityResolver,
       _uploadService = uploadService,
       _chainService =
           chainService ??
           SquareChainService(
             chain: chain,
             transactions: transactions,
             getFinalizedHead: getFinalizedHead,
             getStorage: getStorage,
             getStorageBatch: getStorageBatch,
             prepareTransaction: prepareTransaction,
             executePreparedTransaction: executePreparedTransaction,
             cancelPreparedTransactionExecution:
                 cancelPreparedTransactionExecution,
             consumePreparedTransactionQrResponse:
                 consumePreparedTransactionQrResponse,
           ),
       _publicationConfirmer = publicationConfirmer ?? SquareApiClient(),
       _postDeletionCoordinator =
           postDeletionCoordinator ?? SquarePostDeletionCoordinator(),
       _balanceReader = balanceReader ?? SquareChainBalanceReader(chain),
       _localPostWriter = localPostWriter ?? const SquarePostStore();

  final FinalizedIdentityResolver _identityResolver;
  final SquareContentUploader _uploadService;
  final SquarePostChainPublisher _chainService;
  final SquarePublicationConfirmer _publicationConfirmer;
  final SquarePostDeleteCoordinator _postDeletionCoordinator;
  final SquarePublishBalanceReader _balanceReader;
  final SquareLocalPostWriter _localPostWriter;
  static const _postStore = SquarePostStore();

  /// 只取消尚未上传的本地媒体处理；链上或云端阶段不接受客户端取消。
  Future<void> cancelMediaProcessing() async {
    final uploader = _uploadService;
    if (uploader is SquareMediaProcessingController) {
      await (uploader as SquareMediaProcessingController)
          .cancelMediaProcessing();
    }
  }

  Future<SquarePublishResult> publish({
    required SquareIdentityState identity,
    required String draftId,
    required SquarePostType postType,
    required String text,
    required List<SquareLocalMediaDraft> mediaDrafts,
    required SquareSessionResolver sessionForAccount,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
    String? title,
    List<Map<String, Object?>>? contentSections,
    String? replaceId,
    void Function(SquarePublishStage stage)? onStage,
  }) async {
    final trimmedText = text.trim();
    if (!identity.hasWallet || identity.accountAddress == null) {
      throw const SquarePublishException('请先创建或选择钱包');
    }
    if (trimmedText.isEmpty && mediaDrafts.isEmpty) {
      throw const SquarePublishException('发布内容不能为空');
    }

    final cid = identity.cidNumber;
    final pending = cid == null
        ? null
        : await _postStore.readPublication(cid, draftId);
    if (pending?.jobState == 'confirmed') {
      // 远端成功事实已在本机：仅恢复本地事务，不再验真、上传或发起交易。
      final local = SquarePostStore.confirmedPublication(pending!);
      final warning = await _finishLocal(pending);
      return SquarePublishResult(
        post: const SquareLocalPostPresenter().present(local).post,
        txHash: pending.txHash!,
        blockHash: pending.blockHash!,
        completionWarning:
            warning ?? (pending.replaceId == null ? null : '本地副本已恢复，请检查原帖删除状态'),
      );
    }

    // 点击发布才验真一次；后续上传与签名只复用此结果和本机版本校验。
    final verified = await _identityResolver.resolve();
    if (verified == null || verified.snapshot == null) {
      throw const SquarePublishException('请先注册公民号');
    }
    if (verified.accountId != identity.accountId ||
        (identity.cidNumber?.isNotEmpty == true &&
            identity.cidNumber != verified.snapshot!.cidNumber)) {
      throw const SquarePublishException('身份已变化，请重新进入发布');
    }
    final snapshot = verified.snapshot!;
    identity = SquareIdentityState(
      accountId: verified.accountId,
      cidNumber: snapshot.cidNumber,
      accountAddress: verified.accountAddress,
      displayName: identity.displayName,
      walletIndex: identity.walletIndex,
      signMode: identity.signMode,
      cidLevel: snapshot.votingIdentity == null
          ? 'visitor'
          : snapshot.candidateIdentity == null
          ? 'voting'
          : 'candidate',
    );
    await _identityResolver.assertCurrent(verified);

    if (pending != null) {
      final session = await _uploadService.resumeSession(
        identity.accountId,
        sessionForAccount,
      );
      if (session.cidNumber != pending.cidNumber ||
          session.accountId != pending.accountId) {
        throw const SquarePublishException('发布恢复会话与原发布归属不一致');
      }
      final evidence = pending.blockHash == null
          ? await _chainService.recoverPost(
              accountId: pending.accountId,
              postId: pending.postId,
              postType: SquarePostType.values.byName(pending.postType),
              contentHash: pending.contentHash,
              receiptId: pending.receiptId,
            )
          : SquareChainPublishedResult(
              txHash: pending.txHash!,
              blockHash: pending.blockHash!,
            );
      final tx = pending.txHash ?? evidence?.txHash;
      if (tx == null || (evidence != null && evidence.txHash != tx)) {
        throw const SquarePublishException('正在核对原发布交易，请稍后继续');
      }
      if (evidence != null &&
          (pending.jobState == 'finalized' || evidence.failed)) {
        pending.txHash = tx;
        return _confirm(pending, session, evidence, onStage);
      }
      pending.txHash = tx;
      await _postStore.savePublication(pending);
      final prepared = await _uploadService.resumePreparedContent(
        session,
        pending.postId,
        pending.contentHash,
        Uint8List.fromList(pending.manifestBytes),
      );
      await _uploadService.uploadPreparedContent(
        prepared,
        txHash: tx,
        onStage: onStage,
      );
      if (evidence == null || evidence.blockHash.isEmpty) {
        throw const SquarePublishException('上传已完成，等待原交易最终确认');
      }
      return _confirm(pending, session, evidence, onStage);
    }

    final prepared = await _uploadService.preparePostContent(
      accountId: identity.accountId,
      postType: postType,
      text: trimmedText,
      mediaDrafts: mediaDrafts,
      sessionForAccount: sessionForAccount,
      title: title,
      contentSections: contentSections,
      onStage: onStage,
    );
    social_store.Publish? publication;
    try {
      if (prepared.session.accountId != verified.accountId ||
          prepared.session.cidNumber != snapshot.cidNumber ||
          prepared.session.bindRev != snapshot.bindRev) {
        throw const SquarePublishException('发布会话与已验证身份不一致，请重新操作');
      }
      onStage?.call(SquarePublishStage.checkingBalance);
      await _ensurePublishBalance(identity.accountId);
      await _identityResolver.assertCurrent(verified);
      final row = social_store.Publish()
        ..cidNumber = prepared.session.cidNumber
        ..draftId = draftId
        ..accountId = identity.accountId
        ..postId = prepared.postId
        ..postType = postType.workerValue
        ..contentHash = prepared.contentHash
        ..receiptId = prepared.receiptId
        ..uploadId = prepared.postId
        ..manifestBytes = prepared.manifestBytes
        ..jobState = 'submitting'
        ..replaceId = replaceId;
      await _postStore.savePublication(
        row,
        references: prepared.mediaReferences,
      );
      publication = row;

      final signed = Completer<String>();
      void observe(String hash) {
        if (!signed.isCompleted) signed.complete(hash);
      }

      final upload = signed.future.then((hash) async {
        row.txHash = hash;
        await _postStore.savePublication(row);
        return _uploadService.uploadPreparedContent(
          prepared,
          txHash: hash,
          onStage: onStage,
        );
      });
      onStage?.call(SquarePublishStage.submittingChain);
      SquareChainPublishedResult? finalized;
      final chain =
          Future.sync(
            () => _chainService.publishPost(
              signerPublicKey: citizenAccountIdBytes(identity.accountId),
              postId: prepared.postId,
              postType: postType,
              contentHashHex: prepared.contentHash,
              receiptId: prepared.receiptId,
              externalSigning: externalSigning,
              onSigned: observe,
            ),
          ).then(
            (result) {
              observe(result.txHash);
              finalized = result;
              return result;
            },
            onError: (Object e, StackTrace stack) {
              if (!signed.isCompleted) signed.completeError(e, stack);
              Error.throwWithStackTrace(e, stack);
            },
          );
      // 等在途上传退出。最终失败可先核验并清理，成功仍须完整上传。
      try {
        await Future.wait<Object>([chain, upload]);
      } on Object {
        final evidence = finalized;
        if (evidence == null) rethrow;
        if (evidence.failed) {
          return await _confirm(row, prepared.session, evidence, onStage);
        }
        row.blockHash = evidence.blockHash;
        await _postStore.savePublication(row);
        rethrow;
      }
      return await _confirm(row, prepared.session, finalized!, onStage);
    } catch (e) {
      if (publication != null &&
          publication.txHash == null &&
          e is SquareChainPublishException &&
          e.canAbortUpload) {
        await _postStore.discardPublication(
          publication.cidNumber,
          draftId,
          publication.postId,
          definitiveFailure: true,
        );
      }
      throw SquarePublishException(_messageOf(e));
    } finally {
      await prepared.deleteTemporaryMedia();
    }
  }

  Future<SquarePublishResult> _confirm(
    social_store.Publish row,
    SquareSession session,
    SquareChainPublishedResult evidence,
    void Function(SquarePublishStage)? onStage,
  ) async {
    if (row.txHash != evidence.txHash || evidence.blockHash.isEmpty) {
      throw const SquarePublishException('原发布交易最终证明不完整');
    }
    row
      ..blockHash = evidence.blockHash
      ..jobState = 'finalized';
    await _postStore.savePublication(row);
    onStage?.call(SquarePublishStage.confirmingPost);
    late final SquarePost post;
    try {
      post = await _publicationConfirmer.confirmPublishedPost(
        session: session,
        postId: row.postId,
        blockHash: evidence.blockHash,
        txHash: evidence.txHash,
      );
    } on SquareApiException catch (e) {
      if (e.errorCode == 'post_chain_failed') {
        await _postStore.discardPublication(
          row.cidNumber,
          row.draftId,
          row.postId,
          definitiveFailure: true,
        );
      }
      rethrow;
    }
    _recordConfirmation(row, post);
    String? warning;
    try {
      await _postStore.savePublication(row);
      warning = await _finishLocal(row);
    } catch (e) {
      AppLog.d('[SquarePublishService] local copy pending: $e');
      warning = '内容已发布，本地收尾尚未完成';
    }
    final cleanup = await _deleteReplacedPostAfterSuccess(
      session: session,
      newPostId: row.postId,
      replaceId: row.replaceId,
    );
    final warnings = <String>[?warning, ?cleanup].join('\n');
    onStage?.call(SquarePublishStage.completed);
    return SquarePublishResult(
      post: post,
      txHash: evidence.txHash,
      blockHash: evidence.blockHash,
      completionWarning: warnings.isEmpty ? null : warnings,
    );
  }

  Future<String?> _finishLocal(social_store.Publish row) async {
    try {
      await _localPostWriter.save(
        SquarePostStore.confirmedPublication(row),
        draftId: row.draftId,
      );
    } catch (_) {
      return '内容已发布，本地收尾尚未完成；请从草稿重试恢复，不会重复发布';
    }
    try {
      await SquareComposeDraftStore.instance.retryPendingFileCleanup(
        cidNumber: row.cidNumber,
      );
      return null;
    } catch (_) {
      return '内容已发布并保存在数据库，临时媒体文件仍待清理';
    }
  }

  static void _recordConfirmation(social_store.Publish row, SquarePost post) {
    if (post.postId != row.postId ||
        post.author.cidNumber != row.cidNumber ||
        post.author.accountId != row.accountId ||
        post.contentHash != row.contentHash ||
        post.receiptId != row.receiptId ||
        post.postType.workerValue != row.postType) {
      throw const SquarePublishException('远端确认与本机发布记录不一致');
    }
    row
      ..jobState = 'confirmed'
      ..postCategory = post.postCategory.workerValue
      ..chainBlock = post.chainBlock
      ..publishedAt = post.publishedAt.millisecondsSinceEpoch;
  }

  Future<String?> _deleteReplacedPostAfterSuccess({
    required SquareSession session,
    required String newPostId,
    required String? replaceId,
  }) async {
    final oldPostId = replaceId?.trim();
    if (oldPostId == null || oldPostId.isEmpty || oldPostId == newPostId) {
      return null;
    }
    try {
      // 修改视为重新发布：新帖成功后再清旧帖，避免发布失败导致原内容丢失。
      await _postDeletionCoordinator.delete(
        session: session,
        cidNumber: session.cidNumber,
        postId: oldPostId,
      );
      return null;
    } catch (error) {
      final message = '新内容已发布，但旧内容清理失败：${_messageOf(error)}';
      AppLog.d('[SquarePublishService] $message');
      return message;
    }
  }

  /// 发布前余额闸。发布是自签自付的链上交易，余额不够连入池预检都过不了。
  ///
  /// 门槛 = 链上 `OnchainMinFee + ExistentialDeposit`，两个数**现取自链上 metadata**：
  /// 交易费常量的真源恒为区块链常量库（`primitives::fee_policy`，经 runtime 转发），
  /// App 侧一律不留副本。链读失败不吞，上抛由发布流程按失败处理。
  Future<void> _ensurePublishBalance(String accountId) async {
    final requiredFen = await _balanceReader.fetchMinSelfPayBalanceFen();
    final balanceFen = await _balanceReader.fetchFreshFinalizedBalanceFen(
      accountId,
    );
    if (balanceFen < requiredFen) {
      throw SquarePublishException(
        '钱包余额不足，发布内容需至少 ${formatFen(requiredFen, group: false)} 元'
        '（含账户存在最低余额与链上最低交易费）',
      );
    }
  }

  static String _messageOf(Object error) {
    if (error is SquarePublishException) return error.message;
    if (error is SquareApiException) return error.message;
    return error.toString();
  }
}
