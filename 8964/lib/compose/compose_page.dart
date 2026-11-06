import 'package:citizen_user/identity/account_security_service.dart';
import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:citizen_square/article/article_compose_body.dart';
import 'package:citizen_square/compose/compose_payload.dart';
import 'package:citizen_square/compose/document_compose_body.dart';
import 'package:citizen_square/draft/compose_draft.dart';
import 'package:citizen_square/draft/compose_draft_media.dart';
import 'package:citizen_square/draft/compose_draft_store.dart';
import 'package:citizen_square/draft/drafts_page.dart';
import 'package:citizen_square/compose/video_compose_body.dart';
import 'package:citizen_square/compose/compose_media_widgets.dart';
import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_user/profile/citizen_profile_cache.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/profile/profile_avatar.dart';
import 'package:citizen_user/identity/square_identity_state.dart';
import 'package:citizen_square/compose/square_publish_service.dart';
import 'package:citizen_square/post/square_post_store.dart';
import 'package:citizen_square/media/square_upload_service.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 广场发布页公共外壳；[postType] 由广场圆弧入口决定，页面内不可切换。
class SquareComposePage extends StatefulWidget {
  const SquareComposePage({
    super.key,
    required this.postType,
    this.identityService,
    this.identityRevision,
    this.publishService,
    this.draftStore,
    this.profileCache,
    this.profileMediaCache,
    this.initialText,
    this.initialTitle,
    this.replaceId,
  });

  final SquareIdentityService? identityService;
  final Listenable? identityRevision;
  final SquarePublishService? publishService;
  final SquareComposeDraftRepository? draftStore;
  final CitizenProfileCache? profileCache;
  final CitizenProfileMediaCache? profileMediaCache;
  final SquarePostType postType;

  /// 编辑既有帖时预填正文/标题；媒体需重选（远端资源无法转回本地草稿）。
  final String? initialText;
  final String? initialTitle;
  final String? replaceId;

  @override
  State<SquareComposePage> createState() => _SquareComposePageState();
}

/// 一次本地编辑的归属；排队写入只消费此对象，不重读当前页面的CID、类型或仓库。
class _DraftEditor {
  _DraftEditor({
    required this.id,
    required this.type,
    required this.store,
    this.initialText,
    this.initialTitle,
    this.replaceId,
  });
  final String id;
  final SquarePostType type;
  final SquareComposeDraftRepository store;
  final String? initialText, initialTitle, replaceId;
  SquareIdentityState? identity;
  ComposeSnapshot? snapshot;
  bool saved = false,
      pendingIdentity = false,
      published = false,
      recovering = false,
      installing = false;
  String? get cid => identity?.cidNumber;
}

class _SquareComposePageState extends State<SquareComposePage>
    with WidgetsBindingObserver {
  var _documentKey = GlobalKey<SquareDocumentComposeBodyState>();
  var _articleKey = GlobalKey<SquareArticleComposeBodyState>();
  var _videoKey = GlobalKey<SquareVideoComposeBodyState>();

  SquarePublishService? _publishService;
  late SquareIdentityService _identityService;
  late CitizenProfileCache _profileCache;
  late CitizenProfileMediaCache _profileMediaCache;
  late Future<SquareIdentityState> _identityFuture;
  late _DraftEditor _draft;
  final _boxOwner = ValueNotifier<_DraftEditor?>(null);
  Listenable? _identityRevision;
  int _identityGeneration = 0;
  bool _changingIdentity = false;
  _DraftEditor? _publishingEditor;
  SquareIdentityState? get _identity => _draft.identity;
  bool get _publishing => identical(_publishingEditor, _draft);
  Timer? _autosaveTimer;
  Future<void> _saveChain = Future<void>.value();
  String? _avatarPath;
  bool _avatarSet = false;
  int _documentImageCount = 0;
  SquareLocalMediaDraft? _selectedVideo;

  SquarePublishStage _stage = SquarePublishStage.idle;
  bool _contentValid = false;
  bool _dependenciesReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draft = _newDraft(seed: true);
    _profileCache = widget.profileCache ?? const CitizenProfileCache();
    _profileMediaCache = widget.profileMediaCache ?? CitizenProfileMediaCache();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    final injectedIdentity = widget.identityService;
    if (injectedIdentity != null) {
      _identityService = injectedIdentity;
    } else {
      final sdk = context.read<CitizenSdk>();
      _identityService = SquareIdentityService(
        wallet: sdk,
        currentUserContext: context.read<CurrentUserContext>(),
      );
    }
    _publishService = widget.publishService;
    _identityRevision =
        widget.identityRevision ??
        context.read<AccountSecurityService?>()?.revision;
    _identityRevision?.addListener(_onIdentityChanged);
    _reloadIdentity();
    _dependenciesReady = true;
  }

  _DraftEditor _newDraft({bool seed = false}) => _DraftEditor(
    id: 'd${DateTime.now().microsecondsSinceEpoch}',
    type: widget.postType,
    store: widget.draftStore ?? SquareComposeDraftStore.instance,
    initialText: seed ? widget.initialText : null,
    initialTitle: seed ? widget.initialTitle : null,
    replaceId: seed ? widget.replaceId : null,
  );
  bool _current(_DraftEditor draft) => identical(draft, _draft);
  void _resetEditor({bool seed = false}) {
    _draft = _newDraft(seed: seed);
    _documentKey = GlobalKey<SquareDocumentComposeBodyState>();
    _articleKey = GlobalKey<SquareArticleComposeBodyState>();
    _videoKey = GlobalKey<SquareVideoComposeBodyState>();
    _avatarPath = null;
    _avatarSet = false;
    _documentImageCount = 0;
    _selectedVideo = null;
    _contentValid = false;
    _stage = SquarePublishStage.idle;
  }

  @override
  void didUpdateWidget(covariant SquareComposePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identityRevision != widget.identityRevision) {
      _identityRevision?.removeListener(_onIdentityChanged);
      _identityRevision =
          widget.identityRevision ??
          context.read<AccountSecurityService?>()?.revision;
      _identityRevision?.addListener(_onIdentityChanged);
    }
    if (oldWidget.postType != widget.postType ||
        oldWidget.draftStore != widget.draftStore ||
        oldWidget.identityService != widget.identityService ||
        oldWidget.identityRevision != widget.identityRevision) {
      _captureLatestSnapshot();
      _autosaveTimer?.cancel();
      _saveInBackground(_draft);
      if (oldWidget.postType != widget.postType ||
          oldWidget.draftStore != widget.draftStore) {
        _resetEditor(seed: true);
      } else if (_draft.identity == null) {
        _resetEditor();
      }
      if (widget.identityService != null) {
        _identityService = widget.identityService!;
      }
      _reloadIdentity(changing: true);
    }
  }

  void _onIdentityChanged() {
    if (!mounted) return;
    _captureLatestSnapshot();
    _autosaveTimer?.cancel();
    _saveInBackground(_draft);
    if (_draft.identity == null) _resetEditor();
    setState(() => _reloadIdentity(changing: true));
  }

  void _reloadIdentity({bool changing = false}) {
    final generation = ++_identityGeneration, original = _draft;
    _changingIdentity = changing;
    if (changing) {
      _avatarPath = null;
      _avatarSet = false;
      _boxOwner.value = null;
    }
    _identityFuture = _identityService.loadCurrent().then((identity) {
      if (generation != _identityGeneration || !_current(original)) {
        if (generation != _identityGeneration &&
            original.identity == null &&
            original.pendingIdentity) {
          unawaited(_saveRetiredIdentity(original, identity));
        }
        return identity;
      }
      final old = original.identity;
      final sameOwner =
          old == null ||
          (old.cidNumber?.isNotEmpty == true &&
              old.cidNumber == identity.cidNumber) ||
          (old.cidNumber?.isNotEmpty != true &&
              old.accountId == identity.accountId);
      if (!sameOwner) _resetEditor();
      final draft = _draft;
      draft.identity = identity;
      _changingIdentity = false;
      if (mounted) {
        _boxOwner.value = draft;
        unawaited(_loadAvatar(identity, generation));
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _refreshEditorState(draft),
        );
      }
      // 系统返回后本地身份才到达时，仍为退出时的编辑保存，不读取已销毁子组件。
      if (draft.pendingIdentity) _saveInBackground(draft);
      return identity;
    });
  }

  Future<void> _saveRetiredIdentity(
    _DraftEditor draft,
    SquareIdentityState identity,
  ) async {
    final cid = identity.cidNumber;
    if (cid == null || cid.isEmpty) return;
    try {
      // 迟到的本地读取只补全原编辑对象；当前编辑对象和页面不采用此结果。
      draft.identity = identity;
      await _flushDraft(draft);
    } on Object {
      /* 原仓库失败不能改写当前草稿归属。 */
    }
  }

  /// 发布页只读当前 CID 的公开资料与已验证媒体缓存，不额外联网，也不建立本机头像
  /// 第二真源。用户已设置但缓存暂缺时显示中性占位，不能回退内置随机头像。
  Future<void> _loadAvatar(SquareIdentityState identity, int generation) async {
    final cidNumber = identity.cidNumber?.trim() ?? '';
    if (cidNumber.isEmpty) return;
    try {
      final profile = await _profileCache.read(cidNumber);
      if (profile == null) return;
      final media = await _profileMediaCache.read(profile);
      if (mounted &&
          generation == _identityGeneration &&
          _identity?.cidNumber == identity.cidNumber) {
        setState(() {
          _avatarPath = media.avatarPath;
          _avatarSet = profile.avatarKey?.trim().isNotEmpty == true;
        });
      }
    } on Exception {
      // 头像缓存读取失败不阻塞发布编辑。
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _identityRevision?.removeListener(_onIdentityChanged);
    _boxOwner.dispose();
    _autosaveTimer?.cancel();
    // 路由被系统手势直接移除时，使用已缓存快照继续排队保存；不再读取已销毁子组件。
    _saveInBackground(_draft);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _autosaveTimer?.cancel();
      _refreshEditorState();
      _saveInBackground(_draft);
    }
  }

  ComposeBodyCollector? get _activeBody => switch (_draft.type) {
    SquarePostType.document =>
      _documentKey.currentState as ComposeBodyCollector?,
    SquarePostType.article => _articleKey.currentState as ComposeBodyCollector?,
    SquarePostType.video => _videoKey.currentState as ComposeBodyCollector?,
  };

  Future<SquareLocalMediaDraft> _persistMedia(
    _DraftEditor draft,
    SquareLocalMediaDraft media,
  ) async {
    if (!_current(draft) || _changingIdentity) return media;
    if (draft.cid?.isNotEmpty != true) await _identityFuture;
    if (!_current(draft) ||
        _changingIdentity ||
        draft.cid?.isNotEmpty != true) {
      return media;
    }
    return ComposeDraftMedia.persist(draft.cid!, draft.id, media);
  }

  /// 内容变化同时更新发布按钮和最新快照，再防抖 800ms 持久化草稿。
  void _handleBodyChanged(_DraftEditor draft) {
    if (!_current(draft) || _changingIdentity || draft.installing) return;
    // 文本监听器触发时先同步缓存，保证同一帧立刻发生系统返回也能取得最后一个字符；
    // 发布按钮的 setState 延到下一帧，避免在子组件构建阶段重建父组件。
    _captureLatestSnapshot();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshEditorState(draft),
    );
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(milliseconds: 800),
      () => _saveInBackground(draft),
    );
  }

  void _refreshEditorState([_DraftEditor? owner]) {
    if (!mounted || _changingIdentity || (owner != null && !_current(owner))) {
      return;
    }
    final valid = _captureLatestSnapshot();
    if (valid == null) return;
    // 即使合法性未变化也重建顶部媒体入口，使首图缩略图等子编辑器状态即时同步。
    setState(() => _contentValid = valid);
  }

  /// 只同步读取子编辑器，不触发布局；用于输入事件与退出事件之间的零帧窗口。
  bool? _captureLatestSnapshot() {
    final collector = _activeBody;
    if (collector == null) return null;
    _draft.snapshot = collector.snapshot();
    final valid = collector.isContentValid;
    return valid;
  }

  /// 快照当前内容存草稿；空内容不存（已存过则删除）。
  Future<void> _saveDraft() async {
    _refreshEditorState();
    await _flushLatestSnapshot();
  }

  void _saveInBackground(_DraftEditor draft) {
    unawaited(
      _flushDraft(draft).catchError((Object _) {
        if (mounted && _current(draft) && !_changingIdentity) {
          _showError('草稿保存失败，请重试');
        }
      }),
    );
  }

  Future<void> _flushLatestSnapshot() => _flushDraft(_draft);

  /// 每份快照固定发起时的CID、草稿、类型及仓库；保存链只负责顺序，不改变归属。
  Future<void> _flushDraft(_DraftEditor draft) async {
    if (identical(_publishingEditor, draft) ||
        draft.published ||
        draft.recovering ||
        draft.installing) {
      return;
    }
    final cid = draft.cid, snapshot = draft.snapshot;
    if (cid == null || cid.isEmpty) {
      draft.pendingIdentity = snapshot != null && !snapshot.isEmpty;
      return;
    }
    if (snapshot == null) return;
    draft.pendingIdentity = false;
    _saveChain = _saveChain
        .catchError((_) {})
        .then((_) => _writeSnapshot(draft, cid, snapshot));
    await _saveChain;
  }

  Future<void> _writeSnapshot(
    _DraftEditor draft,
    String cid,
    ComposeSnapshot snapshot,
  ) async {
    if (snapshot.isEmpty) {
      if (draft.saved) {
        await draft.store.delete(cid, draft.id);
        draft.saved = false;
      }
      return;
    }
    await draft.store.save(
      SquareComposeDraft(
        draftId: draft.id,
        cidNumber: cid,
        postType: draft.type,
        title: snapshot.title,
        text: snapshot.text,
        media: snapshot.media,
        contentSections: snapshot.contentSections,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    draft.saved = true;
  }

  /// 退出/取消前把待保存的草稿立即落盘。
  Future<void> _flushAndPop() async {
    final draft = _draft;
    _autosaveTimer?.cancel();
    try {
      await _saveDraft();
      if (mounted && _current(draft)) Navigator.of(context).maybePop();
    } on Object {
      if (mounted && _current(draft)) _showError('草稿保存失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveInBackground(_draft);
      },
      child: Scaffold(
        body: SafeArea(
          child: FutureBuilder<SquareIdentityState>(
            future: _identityFuture,
            builder: (context, snapshot) {
              final identity = snapshot.connectionState == ConnectionState.done
                  ? (snapshot.data ?? const SquareIdentityState(accountId: ''))
                  : const SquareIdentityState(accountId: '');
              return Column(
                children: [
                  _TopBar(
                    title: '发${widget.postType.label}',
                    publishing: _publishing,
                    recovering: _draft.recovering,
                    canCancel:
                        !_publishing ||
                        _stage == SquarePublishStage.processingMedia,
                    stageLabel: _stage.label,
                    onCancel:
                        _publishing &&
                            _stage == SquarePublishStage.processingMedia
                        ? _cancelMediaProcessing
                        : _flushAndPop,
                    onDrafts: _openDrafts,
                    onPublish:
                        identity.hasWallet &&
                            identity.signMode != null &&
                            identity.cidNumber?.isNotEmpty == true &&
                            _contentValid &&
                            _publishingEditor == null &&
                            !_changingIdentity
                        ? () => _publish(identity)
                        : null,
                  ),
                  _IdentityBar(
                    identity: identity,
                    avatarPath: _avatarPath,
                    avatarSet: _avatarSet,
                    mediaAction:
                        _publishing || _draft.recovering || _changingIdentity
                        ? null
                        : _buildMediaAction(),
                  ),
                  Expanded(
                    child: Visibility(
                      visible: !_changingIdentity,
                      maintainState: true,
                      replacement: Center(
                        child: Text(
                          snapshot.hasError ? '本机身份读取失败，请返回重试' : '正在读取本机身份',
                        ),
                      ),
                      child: IgnorePointer(
                        ignoring: _publishing || _draft.recovering,
                        child: _buildBody(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final draft = _draft;
    return switch (draft.type) {
      SquarePostType.document => SquareDocumentComposeBody(
        key: _documentKey,
        initialText: draft.initialText,
        onChanged: () => _handleBodyChanged(draft),
        persistMedia: (media) => _persistMedia(draft, media),
        onMediaCountChanged: (count) {
          if (mounted && _current(draft) && count != _documentImageCount) {
            setState(() => _documentImageCount = count);
          }
        },
      ),
      SquarePostType.article => SquareArticleComposeBody(
        key: _articleKey,
        initialTitle: draft.initialTitle,
        initialText: draft.initialText,
        onChanged: () => _handleBodyChanged(draft),
        persistMedia: (media) => _persistMedia(draft, media),
      ),
      SquarePostType.video => SquareVideoComposeBody(
        key: _videoKey,
        initialText: draft.initialText,
        onChanged: () => _handleBodyChanged(draft),
        persistMedia: (media) => _persistMedia(draft, media),
        onVideoChanged: (video) {
          if (mounted && _current(draft) && video != _selectedVideo) {
            setState(() => _selectedVideo = video);
          }
        },
      ),
    };
  }

  /// 原类型胶囊位置只承载当前编辑器的媒体入口，不重复显示内容类型。
  Widget? _buildMediaAction() => switch (_draft.type) {
    SquarePostType.document => ComposeMediaAddButton(
      key: const ValueKey('document-add-images'),
      icon: Icons.add_photo_alternate_outlined,
      tooltip: _documentImageCount >= documentMaxImages
          ? '最多选择 $documentMaxImages 张图片'
          : '添加图片',
      onPressed: _documentImageCount >= documentMaxImages
          ? null
          : () => _documentKey.currentState?.pickImages(),
    ),
    SquarePostType.video =>
      _selectedVideo == null
          ? ComposeMediaAddButton(
              key: const ValueKey('video-picker'),
              icon: Icons.video_library_outlined,
              tooltip: '选择视频',
              onPressed: () => _videoKey.currentState?.pickVideo(),
            )
          : ComposeVideoThumbnailButton(
              key: const ValueKey('video-picker-thumbnail'),
              path: _selectedVideo!.path,
              onPressed: () => _videoKey.currentState?.pickVideo(),
            ),
    SquarePostType.article => ComposeMediaAddButton(
      key: const ValueKey('article-add-section'),
      icon: Icons.post_add_outlined,
      iconSize: 25,
      tooltip: '添加图文框',
      onPressed: () => _articleKey.currentState?.addTextSection(),
    ),
  };

  Future<void> _openDrafts() async {
    final original = _draft;
    if (_changingIdentity || original.cid?.isNotEmpty != true || _publishing) {
      return;
    }
    _autosaveTimer?.cancel();
    try {
      await _saveDraft();
    } on Object {
      if (mounted && _current(original)) _showError('草稿保存失败，请重试');
      return;
    }
    if (!mounted || !_current(original) || _changingIdentity) return;
    final selected = await Navigator.of(context).push<SquareComposeDraft>(
      MaterialPageRoute(
        builder: (_) => ValueListenableBuilder<_DraftEditor?>(
          valueListenable: _boxOwner,
          builder: (context, draft, _) {
            final cid = draft?.cid;
            if (cid == null || cid.isEmpty) {
              return Scaffold(
                appBar: AppBar(title: const Text('草稿箱')),
                body: const Center(child: Text('本机身份信息暂不可用')),
              );
            }
            return DraftsPage(
              cidNumber: cid,
              postType: draft!.type,
              store: draft.store,
            );
          },
        ),
      ),
    );
    if (selected == null || !mounted || _changingIdentity) return;
    final owner = _draft;
    if (selected.cidNumber != owner.cid || selected.postType != owner.type) {
      _showError('草稿身份或类型已变化，请重新选择');
      return;
    }
    var restored = selected;
    try {
      final store = owner.store;
      if (store is SquareComposeDraftStore) {
        restored = await store.restore(selected);
      }
    } on Object {
      if (mounted && _current(owner)) _showError('草稿媒体读取失败，原数据已保留');
      return;
    }
    if (!mounted || !_current(owner) || _changingIdentity) return;
    final pending = await const SquarePostStore().readPublication(
      selected.cidNumber,
      restored.draftId,
    );
    if (!mounted || !_current(owner) || _changingIdentity) return;
    final draft =
        _DraftEditor(id: restored.draftId, type: owner.type, store: owner.store)
          ..identity = owner.identity
          ..saved = true
          ..recovering = pending != null
          ..installing = true;
    _autosaveTimer?.cancel();
    setState(() => _draft = draft);
    _boxOwner.value = draft;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_current(draft) || _changingIdentity) return;
      switch (draft.type) {
        case SquarePostType.document:
          _documentKey.currentState?.restore(restored);
        case SquarePostType.article:
          _articleKey.currentState?.restore(restored);
        case SquarePostType.video:
          _videoKey.currentState?.restore(restored);
      }
      draft.installing = false;
      _refreshEditorState(draft);
    });
  }

  SquarePublishService _requirePublishService() {
    final existing = _publishService;
    if (existing != null) return existing;
    final sdk = context.read<CitizenSdk>();
    final created = SquarePublishService(
      identityResolver: context.read<FinalizedIdentityResolver>(),
      chain: sdk,
      transactions: sdk,
      uploadService: SquareUploadService(
        subscriptionService: SubscriptionService(
          wallet: sdk,
          chain: sdk,
          transactions: sdk,
          identityResolver: context.read<FinalizedIdentityResolver>(),
          sessionProvider: context.read<SquareSessionProvider>(),
        ),
      ),
    );
    _publishService = created;
    return created;
  }

  Future<void> _publish(SquareIdentityState identity) async {
    if (_publishingEditor != null || _changingIdentity) return;
    final draft = _draft;
    final collector = _activeBody;
    if (collector == null) return;
    final payload = collector.collect();
    if (!payload.isValid) {
      _showError(payload.error!);
      return;
    }
    final service = _requirePublishService();
    _captureLatestSnapshot();
    _autosaveTimer?.cancel();
    setState(() {
      _publishingEditor = draft;
      _stage = SquarePublishStage.signingIn;
    });
    final sessions = context.read<SquareSessionProvider>();
    try {
      await _saveChain;
      if (!_current(draft) ||
          _changingIdentity ||
          draft.identity?.accountId != identity.accountId) {
        throw StateError('发布身份已变化');
      }
      final cid = identity.cidNumber;
      if (cid == null) throw StateError('保存发布草稿前必须取得 CID');
      final pending = await const SquarePostStore().readPublication(
        cid,
        draft.id,
      );
      if (pending == null && draft.snapshot != null) {
        await _writeSnapshot(draft, cid, draft.snapshot!);
      }
      if (!_current(draft) ||
          _changingIdentity ||
          draft.identity?.accountId != identity.accountId) {
        throw StateError('发布身份已变化');
      }
      final result = await service.publish(
        draftId: draft.id,
        identity: identity,
        postType: draft.type,
        text: payload.text,
        title: payload.title,
        contentSections: payload.contentSections,
        mediaDrafts: payload.mediaDrafts,
        sessionForAccount: (accountId) async =>
            await sessions.ensureSessionForAccountId(accountId) ??
            (throw StateError('MLS会话不可用')),
        externalSigning: (pending) {
          if (!mounted || !_current(draft) || _changingIdentity) {
            throw StateError('发布身份已变化');
          }
          return showCitizenSdkQrResponse(
            context,
            request: pending.qrRequest,
            expiresAt: BigInt.from(
              pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
            ),
          );
        },
        replaceId: draft.replaceId,
        onStage: (stage) {
          if (mounted && _current(draft)) setState(() => _stage = stage);
        },
      );
      // 帖子、媒体引用和草稿删除已由服务端结果驱动的本地事务处理。
      // 关闭快照，避免 dispose/生物识别生命周期回调把已发布草稿重新写回。
      draft.published = true;
      draft.snapshot = null;
      draft.saved = false;
      if (!mounted || !_current(draft)) return;
      _autosaveTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.completionWarning ?? '已发布'),
          backgroundColor: AppTheme.primaryDark,
        ),
      );
      Navigator.of(context).pop(result.post);
    } catch (e) {
      // 失败保留已提交草稿；存在发布恢复行时重试只继续确认/收尾，禁止重发。
      final cid = identity.cidNumber;
      if (cid != null) {
        final pending = await const SquarePostStore().readPublication(
          cid,
          draft.id,
        );
        draft.recovering = pending != null;
        if (mounted && _current(draft)) setState(() {});
      }
      if (mounted && _current(draft)) _showError('发布未完成：$e');
    } finally {
      _publishingEditor = null;
      if (mounted) setState(() => _stage = SquarePublishStage.idle);
    }
  }

  Future<void> _cancelMediaProcessing() async {
    await _requirePublishService().cancelMediaProcessing();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.publishing,
    required this.recovering,
    required this.canCancel,
    required this.stageLabel,
    required this.onCancel,
    required this.onDrafts,
    required this.onPublish,
  });

  final String title;
  final bool publishing;
  final bool recovering;
  final bool canCancel;
  final String stageLabel;
  final VoidCallback onCancel;
  final VoidCallback onDrafts;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 标题以整屏宽度的几何中心定位，不受左右操作区宽度影响。
          Transform.translate(
            offset: Offset(0, -AppLayout.scaled(context, 4)),
            child: Center(
              child: Text(
                title,
                key: const ValueKey('compose-centered-title'),
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 18),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: AppLayout.scaled(context, 8)),
              child: TextButton(
                onPressed: canCancel ? onCancel : null,
                child: Text(publishing ? '停止' : '取消'),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: AppLayout.scaled(context, 12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: publishing ? null : onDrafts,
                    child: const Text('草稿'),
                  ),
                  SizedBox(width: AppLayout.scaled(context, 2)),
                  Tooltip(
                    message: publishing
                        ? stageLabel
                        : recovering
                        ? '恢复上次发布'
                        : '发布',
                    child: FilledButton(
                      key: const ValueKey('compose-publish-button'),
                      onPressed: onPublish,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        disabledForegroundColor: Colors.white,
                        minimumSize: const Size(56, 32),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        visualDensity: VisualDensity.standard,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(
                        publishing
                            ? '发布中'
                            : recovering
                            ? '恢复'
                            : '发布',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityBar extends StatelessWidget {
  const _IdentityBar({
    required this.identity,
    required this.avatarPath,
    required this.avatarSet,
    required this.mediaAction,
  });

  final SquareIdentityState identity;
  final String? avatarPath;
  final bool avatarSet;
  final Widget? mediaAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('compose-fixed-identity-bar'),
      height: AppLayout.scaled(context, 50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ProfileAvatar(
              key: const ValueKey('compose-user-avatar'),
              imagePath: avatarPath,
              userImageSet: avatarSet,
              size: 34,
              seed: identity.cidNumber ?? identity.accountId,
              borderRadius: 17,
              showBadge: false,
            ),
            if (mediaAction != null) ...[const Spacer(), mediaAction!],
          ],
        ),
      ),
    );
  }
}
