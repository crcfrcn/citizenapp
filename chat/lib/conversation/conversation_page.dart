part of '../chat.dart';

typedef ChatPickMediaCallback = Future<ChatMediaDraft?> Function();
typedef ChatDeleteConversationCallback = Future<void> Function();

/// 聊天包的完整会话页。
///
/// 文本、表情、贴纸、媒体选择、录音、下载、删除和消息渲染均在此收口；
/// App只注入产品资料、发送资格与产品专属动作。
class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    super.key,
    required this.runtime,
    required this.conversationId,
    required this.currentUserId,
    required this.accountId,
    required this.peerUserId,
    required this.title,
    this.initialProfile,
    this.initialProfileMedia,
    this.profileApi,
    this.profileCache,
    this.profileMediaCache,
    this.sessionProvider,
    this.isGroup = false,
    this.pickMedia,
    this.onDeleteConversation,
  });

  /// 页面直接持有唯一 ChatRuntime；App不得再拼装发送、补拉、ACK 或实时连接回调。
  final ChatRuntime runtime;
  final String conversationId;
  final String currentUserId;
  final String accountId;
  final String peerUserId;
  final String title;
  final bool isGroup;
  final CitizenProfile? initialProfile;
  final CitizenProfileMediaSnapshot? initialProfileMedia;
  final CitizenProfileApi? profileApi;
  final CitizenProfileCache? profileCache;
  final CitizenProfileMediaCache? profileMediaCache;
  final SquareSessionProvider? sessionProvider;
  final ChatPickMediaCallback? pickMedia;
  final ChatDeleteConversationCallback? onDeleteConversation;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  String _attachmentTooLargeMessage(ChatMessageKind kind) =>
      '文件超出当前会员单个附件上限（${SubscriptionService.currentChatFileSizeLabel}）';
  String _attachmentTooLongMessage(ChatMessageKind kind) => '语音、视频消息每条最长 3 分钟';
  Future<void> _openTransfer(BuildContext context, String targetUserId) async {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OnchainPaymentPage(
          initialRecipientCid: targetUserId,
        ),
      ),
    );
  }

  Widget? _actionIcon(
    BuildContext context,
    ChatComposerAction action,
    Color color,
    double size,
  ) {
    if (action != ChatComposerAction.transfer) return null;
    return Image.asset(
      'packages/citizen_assets/logo/mark256.png',
      key: const ValueKey('chat-action-transfer-gmb-mark'),
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.high,
    );
  }

  late final ChatConversationController _conversationController;
  late final VoiceRecorder _voiceRecorder;
  late final MediaCompressor _mediaCompressor;
  final MediaPicker _mediaPicker = MediaPicker();
  final MediaProbe _mediaProbe = MediaProbe();
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  ChatComposerPanel _openPanel = ChatComposerPanel.none;
  ChatExpressionTab _expressionTab = ChatExpressionTab.emoji;
  ChatInputMode _inputMode = ChatInputMode.keyboard;
  VoiceRecordingState _voiceState = VoiceRecordingState.idle;
  Future<void>? _voiceStartInFlight;
  bool _deleting = false;
  String? _pageError;
  late final bool Function() _attachmentContextCurrent;

  @override
  void initState() {
    super.initState();
    final origin = (
      widget.currentUserId,
      widget.accountId,
      widget.conversationId,
      widget.runtime,
    );
    _attachmentContextCurrent = () =>
        mounted &&
        origin ==
            (
              widget.currentUserId,
              widget.accountId,
              widget.conversationId,
              widget.runtime,
            );
    _voiceRecorder = VoiceRecorder(onMaximumReached: _sendVoiceResult);
    _voiceRecorder.state.addListener(_onVoiceStateChanged);
    _mediaCompressor = MediaCompressor(
      limitForKind: widget.runtime.mediaLimits.limitForKind,
    );
    _conversationController = ChatConversationController(
      conversationId: widget.conversationId,
      currentUserId: widget.currentUserId,
      loadSnapshot: () async {
        final batch = await widget.runtime.store.readMessagesForDisplay(
          ownerUserId: widget.currentUserId,
          currentAccountId: widget.accountId,
          conversationId: widget.conversationId,
        );
        return (
          messages: batch.messages,
          integrityFailureCount: batch.integrityFailureCount,
        );
      },
      onSendText: (text) async {
        if (widget.isGroup) {
          await widget.runtime.sendGroupText(
            groupId: widget.conversationId,
            text: text,
          );
        } else {
          await widget.runtime.sendText(
            peerUserId: widget.peerUserId,
            conversationId: widget.conversationId,
            text: text,
          );
        }
      },
      onSendMedia: (media, {onLocalCommitted}) async {
        if (widget.isGroup) {
          await widget.runtime.sendGroupAttachment(
            groupId: widget.conversationId,
            media: media,
            onLocalCommitted: onLocalCommitted,
          );
        } else {
          await widget.runtime.sendMedia(
            peerUserId: widget.peerUserId,
            conversationId: widget.conversationId,
            media: media,
            onLocalCommitted: onLocalCommitted,
          );
        }
      },
      onSendSticker: (packId, stickerId) async {
        if (widget.isGroup) {
          await widget.runtime.sendGroupSticker(
            groupId: widget.conversationId,
            packId: packId,
            stickerId: stickerId,
          );
        } else {
          await widget.runtime.sendSticker(
            peerUserId: widget.peerUserId,
            conversationId: widget.conversationId,
            packId: packId,
            stickerId: stickerId,
          );
        }
      },
      onSync: () => widget.runtime.retryOutgoing(
        conversationId: widget.conversationId,
        recipientUserId: widget.isGroup ? null : widget.peerUserId,
      ),
      onStartRealtime: ({required onNotice, onDisconnected}) =>
          widget.runtime.startRealtimeSync(
            onNotice: onNotice,
            onDisconnected: onDisconnected,
            retryOutgoingOnConnect: false,
          ),
      onDownloadAttachment: (controlPlaintext) =>
          widget.runtime.downloadAttachment(
            conversationId: widget.conversationId,
            controlPlaintext: controlPlaintext,
          ),
      onResolveMediaPaths: (contents) => widget.runtime.resolveCachedMediaPaths(
        conversationId: widget.conversationId,
        contents: contents,
      ),
      onMarkRead: (readThroughMillis) => widget.runtime.markConversationRead(
        conversationId: widget.conversationId,
        readThroughMillis: readThroughMillis,
      ),
      isVisible: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false),
      onPause: _cancelVoiceRecording,
      mediaLimits: widget.runtime.mediaLimits,
      errorMessage: chatUserErrorMessage,
    );
    _conversationController.addListener(_refresh);
    _conversationController.start();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onVoiceStateChanged() {
    if (mounted) setState(() => _voiceState = _voiceRecorder.state.value);
  }

  @override
  void dispose() {
    _conversationController.removeListener(_refresh);
    _conversationController.dispose();
    _composerController.dispose();
    _composerFocusNode.dispose();
    _voiceRecorder.state.removeListener(_onVoiceStateChanged);
    unawaited(_voiceRecorder.dispose());
    super.dispose();
  }

  bool _requireSendPermission() {
    if (widget.runtime.canSendCached(widget.currentUserId)) return true;
    if (mounted) {
      setState(() {
        _pageError = '当前公民身份或会话尚未就绪，请稍后重试';
      });
    }
    return false;
  }

  Future<void> _sendText(String text) async {
    if (_requireSendPermission()) await _conversationController.sendText(text);
  }

  Future<void> _sendSticker(String packId, String stickerId) async {
    if (_requireSendPermission()) {
      await _conversationController.sendSticker(packId, stickerId);
    }
  }

  Future<bool> _prepareAttachment() async {
    if (!_attachmentContextCurrent()) return false;
    await widget.runtime.prepareAttachmentForUser(
      userId: widget.currentUserId,
      accountId: widget.accountId,
    );
    // 整个附件动作归本页初始会话；选取/录音期间换账户也不能交给新会话。
    return _attachmentContextCurrent() && _requireSendPermission();
  }

  Future<void> _sendMediaDrafts(Iterable<ChatMediaDraft> drafts) async {
    if (_conversationController.attachmentBusy || !_requireSendPermission()) {
      return;
    }
    if (!await _prepareAttachment() || _conversationController.attachmentBusy) {
      return;
    }
    final prepared = drafts.toList(growable: false);
    for (final draft in prepared) {
      if (widget.runtime.mediaLimits.exceedsForKind(
        draft.kind,
        draft.byteSize,
      )) {
        setState(() {
          _pageError = _attachmentTooLargeMessage(draft.kind);
        });
        return;
      }
      final durationMs = draft.durationMs;
      if (durationMs != null &&
          durationMs > chatMessageMaximumDuration.inMilliseconds) {
        setState(() {
          _pageError = _attachmentTooLongMessage(draft.kind);
        });
        return;
      }
    }
    await _conversationController.sendMediaDrafts(prepared);
  }

  Future<void> _pickGallery() async {
    if (widget.pickMedia != null) {
      final draft = await widget.pickMedia!.call();
      if (draft != null) await _sendMediaDrafts([draft]);
      return;
    }
    final picked = await _mediaPicker.gallery(context);
    if (picked.isEmpty) return;
    final drafts = <ChatMediaDraft>[];
    for (final item in picked) {
      drafts.add(await _buildMediaDraft(item));
    }
    await _sendMediaDrafts(drafts);
  }

  Future<void> _capture() async {
    final picked = await openChatCameraCapture(context);
    if (picked == null || !mounted) return;
    ChatMediaDraft? draft;
    try {
      draft = await _buildMediaDraft(picked);
      await _sendMediaDrafts([draft]);
    } finally {
      final paths = <String>{picked.path, if (draft != null) draft.sourcePath};
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
  }

  Future<void> _pickFile() async {
    final file = await const ChatAttachmentPlatform().pickFile(
      maxBytes: widget.runtime.mediaLimits.limitForKind(ChatMessageKind.file),
    );
    if (file == null) return;
    ChatMediaDraft? draft;
    try {
      final mime = file.mime == 'application/octet-stream'
          ? mimeFromFileName(file.fileName)
          : file.mime;
      draft = await _buildMediaDraft(
        PickedMediaFile(
          path: file.path,
          fileName: file.fileName,
          mime: mime,
          kind: mediaKindFromMime(mime),
        ),
      );
      await _sendMediaDrafts([draft]);
    } finally {
      final paths = <String>{file.path, if (draft != null) draft.sourcePath};
      for (final path in paths) {
        final temporary = File(path);
        if (await temporary.exists()) await temporary.delete();
      }
    }
  }

  Future<ChatMediaDraft> _buildMediaDraft(PickedMediaFile picked) async {
    if (!await _prepareAttachment()) throw StateError('聊天会话已变化');
    final path = await _mediaCompressor.ensureWithinLimit(
      path: picked.path,
      kind: picked.kind,
    );
    final probe = await _mediaProbe.probe(path: path, kind: picked.kind);
    final durationMs = probe.durationMs;
    if (durationMs != null &&
        durationMs > chatMessageMaximumDuration.inMilliseconds) {
      throw ChatMediaTooLongException(
        kind: picked.kind,
        durationMs: durationMs,
      );
    }
    return ChatMediaDraft(
      kind: picked.kind,
      fileName: picked.fileName,
      contentType: picked.mime,
      sourcePath: path,
      byteSize: await File(path).length(),
      width: probe.width,
      height: probe.height,
      durationMs: durationMs,
      blurhash: probe.blurhash,
    );
  }

  Future<void> _handleAction(ChatComposerAction action) async {
    if (!_requireSendPermission()) return;
    _togglePanel(ChatComposerPanel.none);
    try {
      if ((action == ChatComposerAction.gallery ||
              action == ChatComposerAction.capture ||
              action == ChatComposerAction.file) &&
          !await _prepareAttachment()) {
        return;
      }
      if (!mounted) return;
      switch (action) {
        case ChatComposerAction.gallery:
          await _pickGallery();
        case ChatComposerAction.capture:
          await _capture();
        case ChatComposerAction.file:
          await _pickFile();
        case ChatComposerAction.transfer:
          final action = _openTransfer;
          if (!widget.isGroup) {
            await action(context, widget.peerUserId);
          }
        case ChatComposerAction.location:
          final action = null;
          if (action != null) await action(context, widget.peerUserId);
        case ChatComposerAction.voiceCall:
        case ChatComposerAction.videoCall:
          return;
      }
    } on ChatMediaTooLargeException {
      if (mounted) {
        setState(() {
          _pageError = _attachmentTooLargeMessage(ChatMessageKind.file);
        });
      }
    } on ChatMediaTooLongException catch (error) {
      if (mounted) {
        setState(() {
          _pageError = _attachmentTooLongMessage(error.kind);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _pageError = chatUserErrorMessage(error));
    }
  }

  void _togglePanel(ChatComposerPanel panel) {
    final close = _openPanel == panel;
    setState(() {
      _openPanel = close ? ChatComposerPanel.none : panel;
    });
    if (_openPanel == ChatComposerPanel.none) {
      _requestKeyboard();
    } else {
      _composerFocusNode.unfocus();
    }
  }

  void _handleTextInputTap() {
    if (_openPanel == ChatComposerPanel.none) return;
    setState(() => _openPanel = ChatComposerPanel.none);
    _requestKeyboard();
  }

  void _requestKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _inputMode == ChatInputMode.keyboard) {
        _composerFocusNode.requestFocus();
      }
    });
  }

  void _toggleInputMode() {
    unawaited(_cancelVoiceRecording());
    setState(() {
      _inputMode = _inputMode == ChatInputMode.keyboard
          ? ChatInputMode.voice
          : ChatInputMode.keyboard;
      _openPanel = ChatComposerPanel.none;
    });
    if (_inputMode == ChatInputMode.voice) {
      _composerFocusNode.unfocus();
    } else {
      _composerFocusNode.requestFocus();
    }
  }

  Future<void> _startVoiceRecording() async {
    if (!_requireSendPermission() ||
        _voiceStartInFlight != null ||
        _voiceState.recording) {
      return;
    }
    late final Future<void> pending;
    pending = () async {
      if (await _prepareAttachment()) await _voiceRecorder.start();
    }();
    _voiceStartInFlight = pending;
    try {
      await pending;
    } catch (error) {
      if (mounted) setState(() => _pageError = chatUserErrorMessage(error));
    } finally {
      if (identical(_voiceStartInFlight, pending)) _voiceStartInFlight = null;
    }
  }

  Future<void> _finishVoiceRecording(bool cancel) async {
    try {
      final starting = _voiceStartInFlight;
      if (starting != null) await starting;
      final result = await _voiceRecorder.stop(cancel: cancel);
      if (result == null) return;
      if (result.duration < const Duration(milliseconds: 800)) {
        await File(result.path).delete();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('说话时间太短')));
        }
        return;
      }
      await _sendVoiceResult(result);
    } catch (error) {
      if (mounted) setState(() => _pageError = chatUserErrorMessage(error));
    }
  }

  Future<void> _cancelVoiceRecording() async {
    try {
      final starting = _voiceStartInFlight;
      if (starting != null) await starting;
      await _voiceRecorder.cancel();
    } catch (_) {
      // 页面退出时只收口录音资源，不向已销毁页面写入异步错误。
    }
  }

  Future<void> _sendVoiceResult(VoiceRecordingResult result) async {
    final file = File(result.path);
    try {
      if (!await _prepareAttachment()) return;
      await _sendMediaDrafts([
        ChatMediaDraft(
          kind: ChatMessageKind.audio,
          fileName: result.path.split(Platform.pathSeparator).last,
          contentType: 'audio/mp4',
          sourcePath: result.path,
          byteSize: await file.length(),
          durationMs: result.duration.inMilliseconds.clamp(
            1,
            chatMessageMaximumDuration.inMilliseconds,
          ),
        ),
      ]);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _downloadMedia(String controlPlaintext) async {
    final downloaded = await _conversationController.downloadAttachment(
      controlPlaintext,
    );
    if (!mounted || downloaded == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已保存：${downloaded.fileName}')));
  }

  Future<void> _deleteConversation() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除聊天记录'),
            content: const Text('确定删除这台设备上的聊天记录？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final deleter = widget.onDeleteConversation;
    if (deleter == null) {
      setState(() => _pageError = '当前会话不能删除');
      return;
    }
    setState(() => _deleting = true);
    _conversationController.pause();
    final deletion = deleter();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      unawaited(deletion.catchError((Object _) {}));
      return;
    }
    await deletion;
    await _conversationController.chatController.setMessages(
      const [],
      animated: false,
    );
    if (mounted) setState(() => _deleting = false);
  }

  Widget _buildComposer(BuildContext context) {
    if (!widget.runtime.canSendCached(widget.currentUserId)) {
      return Container(
        key: const ValueKey('chat-membership-required'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: AppTheme.surfaceCard,
        child: Text(
          '当前公民身份或会话尚未就绪，请稍后重试',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    final panel = switch (_openPanel) {
      ChatComposerPanel.none => null,
      ChatComposerPanel.expression => ChatExpressionPanel(
        controller: _composerController,
        selectedTab: _expressionTab,
        onTabChanged: (tab) => setState(() => _expressionTab = tab),
        onStickerPick: (packId, stickerId) =>
            unawaited(_sendSticker(packId, stickerId)),
        onSendText: (text) => unawaited(_sendText(text)),
      ),
      ChatComposerPanel.actions => ComposerActionPanel(
        isGroup: widget.isGroup,
        callsEnabled: false,
        onAction: (action) => unawaited(_handleAction(action)),
        iconBuilder: _actionIcon,
      ),
    };
    return ComposerBar(
      controller: _composerController,
      focusNode: _composerFocusNode,
      inputMode: _inputMode,
      expressionOpen: _openPanel == ChatComposerPanel.expression,
      actionsOpen: _openPanel == ChatComposerPanel.actions,
      recording: _voiceState.recording,
      recordingDuration: _voiceState.duration,
      onToggleInputMode: _toggleInputMode,
      onToggleExpression: () => _togglePanel(ChatComposerPanel.expression),
      onToggleActions: () => _togglePanel(ChatComposerPanel.actions),
      onTextInputTap: _handleTextInputTap,
      onSendText: (text) => unawaited(_sendText(text)),
      onVoicePressStart: () => unawaited(_startVoiceRecording()),
      onVoicePressEnd: (cancel) => unawaited(_finishVoiceRecording(cancel)),
      panel: panel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        titleSpacing: 0,
        title: _CitizenChatHeader(
          peerUserId: widget.peerUserId,
          title: widget.title,
          isGroup: widget.isGroup,
          initialProfile: widget.initialProfile,
          initialProfileMedia: widget.initialProfileMedia,
          profileApi: widget.profileApi,
          profileCache: widget.profileCache,
          profileMediaCache: widget.profileMediaCache,
          sessionProvider: widget.sessionProvider,
        ),
        actions: [
          PopupMenuButton<_ChatMenuAction>(
            tooltip: '更多',
            icon: const Icon(Icons.more_vert_rounded),
            enabled: !_deleting,
            onSelected: (_) => unawaited(_deleteConversation()),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ChatMenuAction.deleteConversation,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('删除聊天记录'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ChatMessageListView(
        currentUserId: widget.currentUserId,
        chatController: _conversationController.chatController,
        onMessageSend: _sendText,
        resolveUser: (id) => Future.value(
          User(
            id: id,
            name: id == widget.currentUserId
                ? '我'
                : ProfilePresentation.forIdentityKey(id).resolveDisplayName(
                    publicName: !widget.isGroup && id == widget.peerUserId
                        ? widget.title
                        : null,
                  ),
          ),
        ),
        composerBuilder: _buildComposer,
        onDownloadAttachment: _downloadMedia,
        onMessagesChanged: _conversationController.reloadMessages,
        isGroup: widget.isGroup,
        loading: _conversationController.loading,
        error: _pageError ?? _conversationController.error,
        groupSenderBuilder: widget.isGroup
            ? (context, userId) => Username(
                userId: userId,
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 11),
                  color: AppTheme.textSecondary,
                ),
              )
            : null,
      ),
    );
  }
}

enum _ChatMenuAction { deleteConversation }
