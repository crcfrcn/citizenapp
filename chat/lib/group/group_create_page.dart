part of '../chat.dart';

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key, this.runtime, this.contactService});

  final ChatRuntime? runtime;
  final UserContactService? contactService;

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final TextEditingController _nameController = TextEditingController();
  late final UserContactService _contactService;
  ChatRuntime? _runtime;
  bool _dependenciesReady = false;

  List<UserContact> _contacts = const <UserContact>[];
  final Set<String> _selected = <String>{};
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    _contactService =
        widget.contactService ?? _contactServiceFromContext(context);
    _runtime = widget.runtime;
    _dependenciesReady = true;
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final contacts = await _contactService.getContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = chatUserErrorMessage(error, fallback: '加载通讯录失败，请稍后重试');
        _loading = false;
      });
    }
  }

  /// 发群聊最少 2 人(1 人应走「发私信」),群名非空方可创建。
  bool get _canCreate =>
      !_loading &&
      _nameController.text.trim().isNotEmpty &&
      _selected.length >= 2;

  Future<void> _create() async {
    if (!_canCreate || _creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final runtime = _runtime ??= context.read<ChatRuntime>();
      final group = await runtime.createGroup(
        name: _nameController.text.trim(),
        inviteeUserIds: _selected.toList(growable: false),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await openGroupChat(context, groupId: group.groupId, title: group.name);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = chatUserErrorMessage(error);
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChatGroupCreateView(
      nameController: _nameController,
      users: [
        for (final contact in _contacts)
          ChatSelectableUser(
            userId: contact.cidNumber,
            displayName: contact.contactRemark.isEmpty
                ? _shortCreateContact(contact.cidNumber)
                : contact.contactRemark,
            subtitle: _shortCreateContact(contact.cidNumber),
          ),
      ],
      selectedUserIds: _selected,
      onSelectionChanged: (userId, selected) => setState(() {
        if (selected) {
          _selected.add(userId);
        } else {
          _selected.remove(userId);
        }
      }),
      canCreate: _canCreate,
      onCreate: _create,
      loading: _loading,
      creating: _creating,
      error: _error,
      emptyMessage: '通讯录为空,先在「我的 → 通讯录」添加联系人',
    );
  }
}

String _shortCreateContact(String address) {
  if (address.length <= 14) return address;
  return '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
}

/// 成员管理页:名册 + 加/删(仅 admin)+ 改群名(仅 admin)+ 退群(任何人)。
