// 选择聊天联系人并返回确定目标，由原入口复核身份后创建会话。

part of '../chat.dart';

/// 只传回已确定的聊天目标；原导航入口负责身份复核及打开会话。
typedef ChatCreateResult = ({
  String targetId,
  String title,
  bool isGroup,
  ChatOwner owner,
});

class ChatCreatePage extends StatefulWidget {
  const ChatCreatePage({super.key, this.runtime, this.contactService});

  final ChatRuntime? runtime;
  final UserContactService? contactService;

  @override
  State<ChatCreatePage> createState() => _ChatCreatePageState();
}

class _ChatCreatePageState extends State<ChatCreatePage> {
  final TextEditingController _nameController = TextEditingController();
  List<UserContact> _selected = const [];
  ChatOwner? _owner;
  bool _ownerInitialized = false;
  bool _ownerLoading = false;
  bool _ownerInvalid = false;
  Listenable? _ownerRevision;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ownerInitialized) return;
    _ownerInitialized = true;
    _ownerRevision = context.read<AccountSecurityService?>()?.revision;
    _ownerRevision?.addListener(_invalidateOwner);
    unawaited(_captureOwner());
  }

  Future<void> _captureOwner() async {
    if (_ownerLoading || _ownerInvalid || !mounted) return;
    _ownerLoading = true;
    try {
      final owner = _chatOwner(
        await context.read<CurrentUserContext>().resolve(),
      );
      if (mounted && !_ownerInvalid) {
        setState(() {
          _owner = owner;
          _error = null;
        });
      }
    } on Object catch (error) {
      if (mounted && !_ownerInvalid) {
        setState(() => _error = chatUserErrorMessage(error));
      }
    } finally {
      _ownerLoading = false;
    }
  }

  void _invalidateOwner() {
    if (_ownerInvalid) return;
    _ownerInvalid = true;
    // 先同步禁用提交；移除旧选择页延到帧末，不能误弹出其上的其它页面。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    });
  }

  Future<bool> _sameOwner(ChatOwner owner) async {
    final current = _chatOwner(
      await context.read<CurrentUserContext>().resolve(),
    );
    return mounted && !_ownerInvalid && owner == current;
  }

  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ownerRevision?.removeListener(_invalidateOwner);
    _nameController.dispose();
    super.dispose();
  }

  /// 选择只由原通讯录页面交付；群名不作为发起条件。
  bool get _canCreate =>
      !_ownerInvalid && _owner != null && _selected.isNotEmpty;

  Future<void> _create() async {
    if (!_canCreate || _creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final owner = _owner!;
      final ownerMatches = await _sameOwner(owner);
      if (!mounted) {
        return;
      }
      if (!ownerMatches) {
        _invalidateOwner();
        return;
      }
      if (_selected.length == 1) {
        final contact = _selected.single;
        Navigator.of(context).pop<ChatCreateResult>((
          targetId: contact.cidNumber,
          title: contact.contactRemark.isEmpty
              ? _shortCreateContact(contact.cidNumber)
              : contact.contactRemark,
          isGroup: false,
          owner: owner,
        ));
        return;
      }
      final runtime = widget.runtime ?? context.read<ChatRuntime>();
      final group = await runtime.createGroup(
        name: _nameController.text.trim().isEmpty
            ? '群聊'
            : _nameController.text.trim(),
        inviteeUserIds: _selected
            .map((contact) => contact.cidNumber)
            .toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      final ownerStillMatches = await _sameOwner(owner);
      if (!mounted) {
        return;
      }
      if (!ownerStillMatches) {
        _invalidateOwner();
        return;
      }
      Navigator.of(context).pop<ChatCreateResult>((
        targetId: group.groupId,
        title: group.name,
        isGroup: true,
        owner: owner,
      ));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = chatUserErrorMessage(error);
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChatCreateView(
      nameController: _nameController,
      selectedCount: _selected.length,
      contacts: ContactBookPage(
        mode: ContactPickMode.pickForChat,
        service: widget.contactService ?? _contactServiceFromContext(context),
        currentUserContext: context.read<CurrentUserContext>(),
        sessionProvider: context.read<SquareSessionProvider>(),
        identityRevision: context.read<AccountSecurityService?>()?.revision,
        selectionEnabled: !_creating,
        onSelectionChanged: (contacts) {
          if (mounted && !_ownerInvalid) {
            setState(() => _selected = contacts);
            if (_owner == null) unawaited(_captureOwner());
          }
        },
      ),
      canCreate: _canCreate,
      onCreate: _create,
      creating: _creating,
      error: _error,
    );
  }
}

String _shortCreateContact(String address) {
  if (address.length <= 14) return address;
  return '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
}
