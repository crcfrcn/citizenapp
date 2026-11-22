// 管理会话本地快照、乐观消息、通知刷新和前后台生命周期。

import '../message/message_view.dart';
import '../chat_error.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:chat/message/chat_content.dart';
import 'package:chat/message/chat_message.dart';
import 'package:chat/chat_media_limits.dart';
import 'package:chat/chat_models.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:chat/chat_runtime.dart';
import 'package:chat/message/direct_flow.dart';

typedef ChatMessageSnapshot = ({
  List<ChatStoredMessage> messages,
  int integrityFailureCount,
});
typedef ChatLoadMessageSnapshotCallback =
    Future<ChatMessageSnapshot> Function();
typedef ChatSendTextCallback = Future<void> Function(String text);
typedef ChatSendMediaCallback =
    Future<void> Function(
      ChatMediaDraft media, {
      ChatMediaLocalCommitNotifier? onLocalCommitted,
    });
typedef ChatSendStickerCallback =
    Future<void> Function(String packId, String stickerId);
typedef ChatSyncCallback = Future<int> Function();
typedef ChatStartRealtimeCallback =
    Future<Future<void> Function()?> Function({
      required Future<void> Function() onNotice,
      Future<void> Function(bool ready)? onConnectionChanged,
    });
typedef ChatDownloadAttachmentCallback =
    Future<ChatDownloadedAttachment> Function(String controlPlaintext);
typedef ChatResolveMediaPathsCallback =
    Future<Map<String, String>> Function(List<ChatContent> contents);
typedef ChatMarkReadCallback = Future<void> Function(int readThroughMillis);
typedef ChatControllerPauseCallback = Future<void> Function();

/// 单个会话的通用 UI 运行控制器。
///
/// 控制器只管理本地消息快照、乐观气泡、WSS 通知、数据刷新和前后台生命周期。
/// 完整会话页从同一 ChatRuntime 生成这些运行回调；产品App只提供展示、发送资格和产品动作。
class ChatConversationController extends ChangeNotifier
    with WidgetsBindingObserver {
  ChatConversationController({
    required this.conversationId,
    required this.currentUserId,
    required this.loadSnapshot,
    required this.onSendText,
    required this.onSendMedia,
    required this.onSendSticker,
    required this.onSync,
    required this.onStartRealtime,
    required this.onDownloadAttachment,
    required this.onResolveMediaPaths,
    required this.onMarkRead,
    required this.isVisible,
    this.onPause,
    this.mediaLimits = const ChatMediaLimits(),
  });

  final String conversationId;
  final String currentUserId;
  final ChatLoadMessageSnapshotCallback loadSnapshot;
  final ChatSendTextCallback? onSendText;
  final ChatSendMediaCallback? onSendMedia;
  final ChatSendStickerCallback? onSendSticker;
  final ChatSyncCallback? onSync;
  final ChatStartRealtimeCallback? onStartRealtime;
  final ChatDownloadAttachmentCallback? onDownloadAttachment;
  final ChatResolveMediaPathsCallback? onResolveMediaPaths;
  final ChatMarkReadCallback? onMarkRead;
  final bool Function() isVisible;
  final ChatControllerPauseCallback? onPause;
  final ChatMediaLimits mediaLimits;

  final InMemoryChatController chatController = InMemoryChatController();
  final Map<String, String> _resolvedMediaPaths = <String, String>{};
  final Map<String, Message> _optimisticMessages = <String, Message>{};
  Future<void> Function()? _stopRealtime;
  Future<void>? _openCoordinatorInFlight;
  bool _started = false;
  bool _disposed = false;
  bool _appResumed = false;
  bool _realtimeConnecting = false;
  bool _realtimeConnected = false;
  bool _loading = true;
  bool _attachmentBusy = false;
  int _messageReloadGeneration = 0;
  int? _renderedMessageFingerprint;
  int _optimisticMessageSequence = 0;

  bool get loading => _loading;
  bool get attachmentBusy => _attachmentBusy;
  int get optimisticMessageCount => _optimisticMessages.length;

  /// 启动一次控制器。重复调用不会重复注册生命周期或建立实时订阅。
  void start() {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _requestOpenCoordinate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _appResumed = true;
      _requestOpenCoordinate();
      return;
    }
    _appResumed = false;
    if (onPause != null) {
      unawaited(onPause!());
    }
    _pauseSync();
  }

  void _recordFailure(Object error) {
    debugPrint(
      '[ChatTrace] direction=ui stage=conversation code=${chatDiagnosticCode(error)}',
    );
  }

  /// 主动暂停实时订阅；再次进入前台时由生命周期统一恢复。
  void pause() {
    if (_disposed) {
      return;
    }
    if (onPause != null) {
      unawaited(onPause!());
    }
    _pauseSync();
  }

  void _requestOpenCoordinate() {
    if (_disposed || !_appResumed || _openCoordinatorInFlight != null) {
      return;
    }
    late final Future<void> created;
    created = _syncOnOpen().whenComplete(() {
      if (identical(_openCoordinatorInFlight, created)) {
        _openCoordinatorInFlight = null;
      }
    });
    _openCoordinatorInFlight = created;
    unawaited(created.catchError((_) {}));
  }

  /// 读取本地真值并原位刷新消息。网络通知只负责触发此方法。
  Future<void> reloadMessages() async {
    if (_disposed) {
      return;
    }
    final generation = ++_messageReloadGeneration;
    try {
      final batch = await loadSnapshot();
      if (_disposed || generation != _messageReloadGeneration) {
        return;
      }
      final messages = batch.messages;
      final fingerprint = Object.hashAll(
        messages.map(
          (message) => Object.hash(
            message.messageId,
            message.direction,
            message.messageKind,
            message.deliveryState,
            message.createdAtMillis,
            message.plaintext,
          ),
        ),
      );
      if (_renderedMessageFingerprint != fingerprint) {
        await chatController.setMessages(
          _visibleMessages(messages),
          animated: false,
        );
        if (_disposed || generation != _messageReloadGeneration) {
          return;
        }
        _renderedMessageFingerprint = fingerprint;
      }
      unawaited(_resolveAndApplyMediaPaths(messages, generation));
      _commitReloadState(generation);
      unawaited(_markRead(messages, generation));
    } catch (error) {
      _recordFailure(error);
      _commitReloadState(generation);
    }
  }

  Future<void> _markRead(
    List<ChatStoredMessage> messages,
    int generation,
  ) async {
    final callback = onMarkRead;
    if (callback == null || messages.isEmpty || !_appResumed || !isVisible()) {
      return;
    }
    final readThroughMillis = messages
        .map((message) => message.createdAtMillis)
        .reduce((left, right) => left > right ? left : right);
    try {
      await callback(readThroughMillis);
    } catch (_) {
      // 已读写入失败时保留未读数；下次当前页快照刷新会自然重试。
    }
    if (_disposed || generation != _messageReloadGeneration) {
      return;
    }
  }

  void _commitReloadState(int generation) {
    if (_disposed || generation != _messageReloadGeneration) {
      return;
    }
    if (!_loading) {
      return;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _resolveAndApplyMediaPaths(
    List<ChatStoredMessage> messages,
    int generation,
  ) async {
    final resolver = onResolveMediaPaths;
    if (resolver == null) {
      return;
    }
    try {
      final contents = <ChatContent>[];
      for (final message in messages) {
        final content = ChatPayloadCodec.decode(message.plaintext ?? '');
        final attachmentId = content.attachmentId ?? '';
        if (!content.isMedia || attachmentId.isEmpty) {
          continue;
        }
        if (mediaLimits.exceedsForKind(content.kind, content.byteSize ?? 0)) {
          continue;
        }
        if (!_resolvedMediaPaths.containsKey(attachmentId)) {
          contents.add(content);
        }
      }
      if (contents.isEmpty) {
        return;
      }
      final paths = await resolver(contents);
      if (_disposed ||
          generation != _messageReloadGeneration ||
          paths.isEmpty) {
        return;
      }
      _resolvedMediaPaths.addAll(paths);
      await chatController.setMessages(
        _visibleMessages(messages),
        animated: false,
      );
    } catch (_) {
      // 媒体尚未到达时保留占位，不把附件缓存状态误报为正文读取失败。
    }
  }

  Future<void> _syncOnOpen() async {
    await reloadMessages();
    if (!_disposed) {
      await _startRealtime();
    }
  }

  Future<bool> _startRealtime() async {
    final starter = onStartRealtime;
    if (!_appResumed || starter == null || _disposed) {
      return false;
    }
    if (_stopRealtime != null || _realtimeConnecting) {
      return _realtimeConnected;
    }
    _realtimeConnecting = true;
    try {
      final stop = await starter(
        onNotice: reloadMessages,
        onConnectionChanged: (ready) async {
          if (_disposed || !_appResumed) {
            return;
          }
          _realtimeConnected = ready;
        },
      );
      if (_disposed || !_appResumed) {
        await stop?.call();
        return false;
      }
      _stopRealtime = stop;
      return stop != null;
    } catch (_) {
      // 实时连接由Runtime静默恢复；连接状态只在聊天列表展示。
      return false;
    } finally {
      _realtimeConnecting = false;
    }
  }

  /// 用户重试复用原会话发送入口；网络恢复仍由账户Hub单飞处理。
  Future<void> retry() async {
    await _syncAndReload(silent: false);
  }

  Future<bool> _syncAndReload({required bool silent}) async {
    final ok = await _syncOnly(silent: silent);
    if (!ok) {
      return false;
    }
    await reloadMessages();
    return true;
  }

  Future<bool> _syncOnly({required bool silent}) async {
    final sync = onSync;
    if (sync == null) {
      if (!silent) {}
      return false;
    }
    try {
      await sync();
      return true;
    } catch (error) {
      if (!silent) {
        _recordFailure(error);
      }
      return false;
    }
  }

  void _pauseSync() {
    final stop = _stopRealtime;
    _stopRealtime = null;
    if (stop != null) {
      unawaited(stop());
    }
  }

  List<Message> _visibleMessages(List<ChatStoredMessage> storedMessages) {
    final messages = <Message>[
      ...storedMessagesToChatMessages(
        storedMessages,
        currentUserId: currentUserId,
        mediaLimits: mediaLimits,
        resolveLocalMediaPath: (content) =>
            _resolvedMediaPaths[content.attachmentId],
      ),
      ..._optimisticMessages.values,
    ];
    messages.sort((left, right) {
      final leftAt = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightAt = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return leftAt.compareTo(rightAt);
    });
    return messages;
  }

  String _nextOptimisticMessageId() {
    _optimisticMessageSequence += 1;
    return 'local:$conversationId:'
        '${DateTime.now().microsecondsSinceEpoch}:$_optimisticMessageSequence';
  }

  Map<String, dynamic> _optimisticMetadata(ChatMessageKind kind) =>
      <String, dynamic>{
        'conversation_id': conversationId,
        'direction': 'outgoing',
        'is_mine': true,
        'message_kind': kind.name,
        'optimistic': true,
      };

  Message _optimisticTextMessage(String text) => Message.text(
    id: _nextOptimisticMessageId(),
    authorId: currentUserId,
    createdAt: DateTime.now().toUtc(),
    text: text,
    metadata: _optimisticMetadata(ChatMessageKind.text),
  );

  Message _optimisticStickerMessage(String packId, String stickerId) =>
      Message.custom(
        id: _nextOptimisticMessageId(),
        authorId: currentUserId,
        createdAt: DateTime.now().toUtc(),
        metadata: <String, dynamic>{
          ..._optimisticMetadata(ChatMessageKind.sticker),
          'pack_id': packId,
          'sticker_id': stickerId,
        },
      );

  Message _optimisticMediaMessage(ChatMediaDraft draft) {
    final id = _nextOptimisticMessageId();
    final createdAt = DateTime.now().toUtc();
    final metadata = <String, dynamic>{
      ..._optimisticMetadata(draft.kind),
      'attachment_id': id,
      'file_name': draft.fileName,
    };
    return switch (draft.kind) {
      ChatMessageKind.image => Message.image(
        id: id,
        authorId: currentUserId,
        createdAt: createdAt,
        source: draft.sourcePath,
        width: draft.width?.toDouble(),
        height: draft.height?.toDouble(),
        size: draft.byteSize,
        metadata: metadata,
      ),
      ChatMessageKind.video => Message.video(
        id: id,
        authorId: currentUserId,
        createdAt: createdAt,
        source: draft.sourcePath,
        name: draft.fileName,
        width: draft.width?.toDouble(),
        height: draft.height?.toDouble(),
        size: draft.byteSize,
        metadata: metadata,
      ),
      ChatMessageKind.audio => Message.audio(
        id: id,
        authorId: currentUserId,
        createdAt: createdAt,
        source: draft.sourcePath,
        duration: Duration(milliseconds: draft.durationMs ?? 0),
        size: draft.byteSize,
        metadata: metadata,
      ),
      ChatMessageKind.file => Message.file(
        id: id,
        authorId: currentUserId,
        createdAt: createdAt,
        source: draft.sourcePath,
        name: draft.fileName,
        size: draft.byteSize,
        mimeType: draft.contentType,
        metadata: metadata,
      ),
      ChatMessageKind.text ||
      ChatMessageKind.sticker => throw StateError('文字和贴纸不能进入媒体乐观气泡'),
    };
  }

  Future<void> _insertOptimisticMessage(Message message) async {
    _optimisticMessages[message.id] = message;
    await chatController.insertMessage(message, animated: false);
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _discardOptimisticMessages(Iterable<String> messageIds) async {
    var removed = false;
    for (final messageId in messageIds) {
      removed = _optimisticMessages.remove(messageId) != null || removed;
    }
    if (removed && !_disposed) {
      await reloadMessages();
    }
  }

  Future<void> sendText(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty || _disposed) {
      return;
    }
    final sender = onSendText;
    if (sender == null) {
      return;
    }
    final optimistic = _optimisticTextMessage(normalized);
    await _insertOptimisticMessage(optimistic);
    try {
      await sender(normalized);
      await _discardOptimisticMessages(<String>[optimistic.id]);
    } catch (error) {
      await _discardOptimisticMessages(<String>[optimistic.id]);
      _recordFailure(error);
    }
  }

  Future<void> sendMediaDrafts(Iterable<ChatMediaDraft> drafts) async {
    if (_attachmentBusy || _disposed) {
      return;
    }
    final sender = onSendMedia;
    if (sender == null) {
      return;
    }
    final prepared = drafts.toList(growable: false);
    _attachmentBusy = true;
    notifyListeners();
    final pending = <({ChatMediaDraft draft, Message message})>[];
    for (final draft in prepared) {
      final message = _optimisticMediaMessage(draft);
      pending.add((draft: draft, message: message));
      await _insertOptimisticMessage(message);
    }
    try {
      for (final item in pending) {
        var reconciled = false;
        await sender(
          item.draft,
          onLocalCommitted: () async {
            if (reconciled) {
              return;
            }
            reconciled = true;
            await _discardOptimisticMessages(<String>[item.message.id]);
          },
        );
        if (!reconciled) {
          await _discardOptimisticMessages(<String>[item.message.id]);
        }
      }
    } catch (error) {
      await _discardOptimisticMessages(pending.map((item) => item.message.id));
      _recordFailure(error);
    } finally {
      if (!_disposed) {
        _attachmentBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> sendSticker(String packId, String stickerId) async {
    if (_disposed) {
      return;
    }
    final sender = onSendSticker;
    if (sender == null) {
      return;
    }
    final optimistic = _optimisticStickerMessage(packId, stickerId);
    await _insertOptimisticMessage(optimistic);
    try {
      await sender(packId, stickerId);
      await _discardOptimisticMessages(<String>[optimistic.id]);
    } catch (error) {
      await _discardOptimisticMessages(<String>[optimistic.id]);
      _recordFailure(error);
    }
  }

  Future<ChatDownloadedAttachment?> downloadAttachment(
    String controlPlaintext,
  ) async {
    final downloader = onDownloadAttachment;
    if (downloader == null) {
      return null;
    }
    try {
      final downloaded = await downloader(controlPlaintext);
      await reloadMessages();
      return downloaded;
    } catch (error) {
      _recordFailure(error);
      return null;
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _messageReloadGeneration += 1;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _pauseSync();
    chatController.dispose();
    super.dispose();
  }
}

typedef ChatConversationListCoordinateCallback = Future<void> Function();
typedef ChatConversationListRefreshCallback =
    Future<bool> Function(String scope);

/// 会话列表只协调生命周期、WSS订阅和本地刷新；恢复与补发由Runtime唯一处理。
///
/// 控制器直接持有同一 ChatRuntime；产品列表只提供业务数据刷新，不接触具体实时连接入口。
class ChatConversationListController extends ChangeNotifier
    with WidgetsBindingObserver {
  ChatConversationListController({
    required ChatRuntime runtime,
    required this.onCoordinate,
    required this.onRefresh,
  }) : _runtime = runtime;

  final ChatRuntime _runtime;
  final ChatConversationListCoordinateCallback onCoordinate;
  final ChatConversationListRefreshCallback onRefresh;
  Future<void> Function()? _stopRealtime;
  Future<void>? _coordinatorInFlight;
  String? _scope;
  bool _started = false;
  bool _disposed = false;
  bool _visible = false;
  bool _appResumed = false;
  bool _realtimeConnecting = false;
  bool _realtimeConnected = false;
  int _realtimeGeneration = 0;
  bool _realtimeFailed = false;

  /// 初次握手和正常重连静默；实际尝试失败后只交付列表顶部的中性状态文字。
  String? get connectionLabel =>
      isActive && _scope != null && _realtimeFailed ? '连接中' : null;

  bool get isActive => !_disposed && _visible && _appResumed;

  void start({required bool visible}) {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    _visible = visible;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void setVisible(bool visible) {
    if (_disposed || _visible == visible) {
      return;
    }
    _visible = visible;
    if (isActive) {
      requestCoordinate();
    } else {
      _stopSync(clearScope: false);
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) {
      return;
    }
    _appResumed = state == AppLifecycleState.resumed;
    if (isActive) {
      requestCoordinate();
    } else {
      _stopSync(clearScope: false);
    }
    notifyListeners();
  }

  void requestCoordinate() {
    if (!isActive || _coordinatorInFlight != null) {
      return;
    }
    late final Future<void> created;
    created = onCoordinate().whenComplete(() {
      if (identical(_coordinatorInFlight, created)) {
        _coordinatorInFlight = null;
      }
    });
    _coordinatorInFlight = created;
    unawaited(created.catchError((_) {}));
  }

  void configureScope(String scope) {
    final normalized = scope.trim();
    if (!isActive || normalized.isEmpty) {
      pause();
      return;
    }
    if (_scope != normalized) {
      _stopSync(clearScope: true);
      _scope = normalized;
    }
    unawaited(_startRealtime(normalized));
  }

  void synchronizeScope(String scope) {
    configureScope(scope);
    if (isActive && _scope == scope.trim()) {
      unawaited(_refresh(scope.trim()));
    }
  }

  void pause() => _stopSync(clearScope: true);

  Future<bool> _startRealtime(String scope) async {
    if (!isActive || scope != _scope) {
      return false;
    }
    if (_stopRealtime != null || _realtimeConnecting) {
      return _realtimeConnected;
    }
    _realtimeConnecting = true;
    final generation = _realtimeGeneration;
    bool current() =>
        isActive && _scope == scope && generation == _realtimeGeneration;
    try {
      final stop = await _runtime.startRealtimeSync(
        onNotice: () async {
          await _refresh(scope);
        },
        onConnectionChanged: (ready) async {
          if (!current()) {
            return;
          }
          _realtimeConnected = ready;
          _realtimeFailed = !ready;
          notifyListeners();
        },
      );
      if (!current()) {
        await stop?.call();
        return false;
      }
      _stopRealtime = stop;
      return _realtimeConnected;
    } catch (_) {
      if (current()) {
        _realtimeConnected = false;
        _realtimeFailed = true;
      }
      return false;
    } finally {
      if (current()) {
        _realtimeConnecting = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _refresh(String scope) async {
    if (!isActive || _scope != scope) {
      return false;
    }
    try {
      return await onRefresh(scope);
    } catch (_) {
      return false;
    }
  }

  void _stopSync({required bool clearScope}) {
    _realtimeGeneration++;
    _realtimeConnecting = false;
    _realtimeConnected = false;
    _realtimeFailed = false;
    final stop = _stopRealtime;
    _stopRealtime = null;
    if (clearScope) {
      _scope = null;
    }
    if (stop != null) {
      unawaited(stop());
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _stopSync(clearScope: true);
    super.dispose();
  }
}
