part of '../chat.dart';

typedef GroupChatOpener =
    Future<void> Function(
      BuildContext context, {
      required String groupId,
      required String title,
    });

/// 聊天搜索页：一个输入框，三段结果 —— 会话 / 联系人 / 聊天记录。
///
/// - 会话与联系人在内存里过滤（进页时一次性载入，数据量小）。
/// - 聊天记录走 [ChatStore.searchMessages] 跨会话检索本机已解密消息。
/// - 点任一结果都复用既有打开收口：群聊 [openGroupChat]、单聊 [openDirectChat]，
///   不在本页复刻 ChatConversationPage 装配。
/// - 聊天记录命中当前**只打开所在会话**，不定位到具体消息（消息级锚点需
///   ChatConversationPage 支持滚动定位，单列后续任务）。
class ChatSearchPage extends StatefulWidget {
  const ChatSearchPage({
    super.key,
    this.store,
    this.contactService,
    this.cidNumber,
    this.accountId,
    this.directChatOpener,
    this.groupChatOpener,
  });

  final ChatStore? store;
  final UserContactService? contactService;

  /// 当前永久身份主键；不传则页面只读本地当前用户快照。
  final String? cidNumber;

  /// 当前身份账户（CID 绑定账户）；不传则页面自行读取。
  final String? accountId;
  final DirectChatOpener? directChatOpener;
  final GroupChatOpener? groupChatOpener;

  @override
  State<ChatSearchPage> createState() => _ChatSearchPageState();
}

class _ChatSearchPageState extends State<ChatSearchPage> {
  late ChatStore _store = widget.store ?? ChatStore();
  CurrentUserContext? _currentUserContext;
  AccountSecurityService? _security;
  int _loadGeneration = 0;
  UserContactService? _contactService;
  bool _dependenciesReady = false;
  final TextEditingController _controller = TextEditingController();

  String _accountId = '';
  String _cidNumber = '';
  List<ChatConversationPreview> _conversations =
      const <ChatConversationPreview>[];
  List<UserContact> _contacts = const <UserContact>[];
  List<ChatStoredMessage> _messageHits = const <ChatStoredMessage>[];
  String _query = '';
  bool _loading = true;
  bool _searching = false;
  String? _error;

  /// 消息检索是异步的：用递增序号丢弃过期结果，
  /// 避免快速输入时旧关键词的结果覆盖新关键词的结果。
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    _contactService =
        widget.contactService ?? _contactServiceFromContextOrNull(context);
    _currentUserContext = context.read<CurrentUserContext?>();
    _security = context.read<AccountSecurityService?>();
    if (_currentUserContext != null) {
      _security?.revision.addListener(_identityChanged);
    }
    _dependenciesReady = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    if (_currentUserContext != null) {
      _security?.revision.removeListener(_identityChanged);
    }
    _loadGeneration++;
    _searchSeq++;
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cidNumber != widget.cidNumber ||
        oldWidget.accountId != widget.accountId ||
        oldWidget.store != widget.store ||
        oldWidget.contactService != widget.contactService) {
      _store = widget.store ?? _store;
      _contactService =
          widget.contactService ?? _contactServiceFromContextOrNull(context);
      unawaited(_load());
    }
  }

  void _identityChanged() {
    if (mounted) unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration,
        store = _store,
        contactsService = _contactService;
    _searchSeq++;
    setState(() {
      _accountId = '';
      _cidNumber = '';
      _conversations = const [];
      _contacts = const [];
      _messageHits = const [];
      _loading = true;
      _searching = false;
      _error = null;
    });
    try {
      final source = _currentUserContext;
      final identity = source != null ? await source.resolve() : null;
      final account = source != null ? identity?.accountId : widget.accountId;
      final cid = source != null ? identity?.cidNumber : widget.cidNumber;
      if (account == null || account.isEmpty || cid == null || cid.isEmpty) {
        throw StateError('本机身份不可用');
      }
      if (!mounted || generation != _loadGeneration) return;
      final conversations = await store.readConversationPreviews(
        ownerUserId: cid,
        currentAccountId: account,
      );
      if (!mounted || generation != _loadGeneration) return;
      List<UserContact> contacts;
      try {
        contacts = await contactsService?.getContacts() ?? const [];
      } on Object {
        contacts = const [];
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _accountId = account;
        _cidNumber = cid;
        _conversations = conversations;
        _contacts = contacts;
        _loading = false;
      });
      if (_query.isNotEmpty) unawaited(_onQueryChanged(_query));
    } on Object {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _error = '本地聊天数据读取失败';
        });
      }
    }
  }

  Future<void> _onQueryChanged(String value) async {
    final query = value.trim();
    if (query.isEmpty || _loading || _cidNumber.isEmpty) {
      ++_searchSeq;
      setState(() {
        _query = query;
        _messageHits = const <ChatStoredMessage>[];
        _searching = false;
        _error = null;
      });
      return;
    }
    final seq = ++_searchSeq, generation = _loadGeneration;
    final cid = _cidNumber, account = _accountId, store = _store;
    setState(() {
      _query = query;
      _searching = true;
      _error = null;
    });
    try {
      final hits = await store.searchMessages(
        ownerUserId: cid,
        currentAccountId: account,
        keyword: query,
      );
      if (!mounted ||
          seq != _searchSeq ||
          generation != _loadGeneration ||
          cid != _cidNumber ||
          account != _accountId) {
        return;
      }
      setState(() {
        _messageHits = hits;
        _searching = false;
      });
    } on Exception {
      if (!mounted ||
          seq != _searchSeq ||
          generation != _loadGeneration ||
          cid != _cidNumber ||
          account != _accountId) {
        return;
      }
      setState(() {
        _messageHits = const <ChatStoredMessage>[];
        _searching = false;
        _error = '聊天记录搜索失败';
      });
    }
  }

  List<ChatConversationPreview> get _conversationHits {
    if (_query.isEmpty) return const <ChatConversationPreview>[];
    final needle = _query.toLowerCase();
    return _conversations
        .where(
          (item) =>
              item.title.toLowerCase().contains(needle) ||
              item.lastMessage.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  List<UserContact> get _contactHits {
    if (_query.isEmpty) return const <UserContact>[];
    final needle = _query.toLowerCase();
    // 只匹配私人备注、CID 与账户：公开昵称要联网拉取，搜索页不引入网络依赖。
    return _contacts
        .where(
          (item) =>
              item.contactRemark.toLowerCase().contains(needle) ||
              item.cidNumber.toLowerCase().contains(needle) ||
              item.accountId.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  Future<void> _openConversation(ChatConversationPreview preview) async {
    if (preview.isGroup) {
      final opener = widget.groupChatOpener ?? openGroupChat;
      await opener(
        context,
        groupId: preview.conversationId,
        title: preview.title,
      );
      return;
    }
    final opener = widget.directChatOpener ?? openDirectChat;
    await opener(context, peerUserId: preview.peerUserId, title: preview.title);
  }

  Future<void> _openContact(UserContact contact) async {
    final opener = widget.directChatOpener ?? openDirectChat;
    final title = contact.contactRemark.isEmpty
        ? ProfilePresentation.forIdentityKey(contact.cidNumber).fallbackName
        : contact.contactRemark;
    await opener(context, peerUserId: contact.cidNumber, title: title);
  }

  /// 聊天记录命中：只打开消息所在会话，不定位到具体消息。
  Future<void> _openMessageHit(ChatStoredMessage message) async {
    ChatConversationPreview? preview;
    for (final item in _conversations) {
      if (item.conversationId == message.conversationId) {
        preview = item;
        break;
      }
    }
    if (preview == null) return;
    await _openConversation(preview);
  }

  @override
  Widget build(BuildContext context) {
    return ChatSearchView(
      controller: _controller,
      query: _query,
      onQueryChanged: (value) => unawaited(_onQueryChanged(value)),
      onClear: () {
        _controller.clear();
        unawaited(_onQueryChanged(''));
      },
      loading: _loading,
      searching: _searching,
      error: _error,
      sections: [
        ChatSearchSection(
          title: '会话',
          items: [
            for (final item in _conversationHits)
              ChatSearchItem(
                key: ValueKey('search-conversation-${item.conversationId}'),
                leading: Icon(
                  item.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                  color: AppTheme.textSecondary,
                ),
                title: item.title,
                subtitle: item.lastMessage,
                onTap: () => unawaited(_openConversation(item)),
              ),
          ],
        ),
        ChatSearchSection(
          title: '联系人',
          items: [
            for (final item in _contactHits)
              ChatSearchItem(
                key: ValueKey('search-contact-${item.cidNumber}'),
                leading: const Icon(
                  Icons.account_circle_rounded,
                  color: AppTheme.textSecondary,
                ),
                title: item.contactRemark.isEmpty
                    ? ProfilePresentation.forIdentityKey(
                        item.cidNumber,
                      ).fallbackName
                    : item.contactRemark,
                subtitle: item.cidNumber,
                onTap: () => unawaited(_openContact(item)),
              ),
          ],
        ),
        ChatSearchSection(
          title: '聊天记录',
          items: [
            for (final item in _messageHits)
              ChatSearchItem(
                key: ValueKey('search-message-${item.messageId}'),
                leading: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppTheme.textSecondary,
                ),
                title: ChatPayloadCodec.decode(item.plaintext ?? '').summary,
                onTap: () => unawaited(_openMessageHit(item)),
              ),
          ],
        ),
      ],
    );
  }
}

/// 建群页:输群名 + 从通讯录多选成员 → `createGroup`(创建者自动为 admin)。
