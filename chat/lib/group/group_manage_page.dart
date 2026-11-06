part of '../chat.dart';

class GroupManagePage extends StatefulWidget {
  const GroupManagePage({
    super.key,
    required this.groupId,
    this.runtime,
    this.store,
    this.cidNumber,
  });

  final String groupId;
  final ChatRuntime? runtime;
  final ChatStore? store;
  final String? cidNumber;

  @override
  State<GroupManagePage> createState() => _GroupManagePageState();
}

class _GroupManagePageState extends State<GroupManagePage> {
  ChatRuntime? _runtime;
  late final ChatStore _store = widget.store ?? ChatStore();
  bool _dependenciesReady = false;

  ChatGroup? _group;
  String _myCidNumber = '';
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    _runtime = widget.runtime ?? context.read<ChatRuntime?>();
    _dependenciesReady = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final identity = widget.cidNumber != null
          ? null
          : await context.read<CurrentUserContext>().resolve();
      final ownerUserId = widget.cidNumber ?? identity?.cidNumber ?? '';
      final group = await _store.readGroup(ownerUserId, widget.groupId);
      if (!mounted) return;
      setState(() {
        _myCidNumber = ownerUserId;
        _group = group;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = chatUserErrorMessage(error);
        _loading = false;
      });
    }
  }

  bool get _isAdmin => _group?.adminSet.contains(_myCidNumber) ?? false;

  ChatRuntime get _activeRuntime => _runtime ?? (throw StateError('聊天运行实例不可用'));

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = chatUserErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename() async {
    final name = await showChatRenameGroupDialog(
      context,
      currentName: _group?.name ?? '',
    );
    if (name != null && name.isNotEmpty) {
      await _run(
        () => _activeRuntime.renameGroup(groupId: widget.groupId, name: name),
      );
    }
  }

  Future<void> _addMembers() async {
    final existing = _group?.memberUserIds.toSet() ?? <String>{};
    final selected = await _pickContacts(existing);
    if (selected != null && selected.isNotEmpty) {
      await _run(
        () => _activeRuntime.addGroupMembers(
          groupId: widget.groupId,
          inviteeUserIds: selected,
        ),
      );
    }
  }

  Future<void> _leave() async {
    if (await showChatLeaveGroupDialog(context)) {
      await _run(() => _activeRuntime.leaveGroup(widget.groupId));
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<List<String>?> _pickContacts(Set<String> exclude) async {
    List<UserContact> contacts;
    try {
      contacts = await _contactServiceFromContext(context).getContacts();
    } catch (_) {
      contacts = const <UserContact>[];
    }
    if (!mounted) return null;
    return showChatUserPickerDialog(
      context,
      users: [
        for (final contact in contacts)
          if (!exclude.contains(contact.cidNumber))
            ChatSelectableUser(
              userId: contact.cidNumber,
              displayName: contact.contactRemark.isEmpty
                  ? _shortManageContact(contact.cidNumber)
                  : contact.contactRemark,
              subtitle: _shortManageContact(contact.cidNumber),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    return ChatGroupManageView(
      title: group?.name ?? '群聊',
      members: [
        if (group != null)
          for (final member in group.roster)
            ChatGroupMemberItem(
              userId: member.userId,
              displayName: _shortManageContact(member.userId),
              isAdmin: member.isAdmin,
              canRemove:
                  _isAdmin &&
                  member.userId != _myCidNumber &&
                  member.userId != group.creatorUserId,
              onRemove: () => _run(
                () => _activeRuntime.removeGroupMembers(
                  groupId: widget.groupId,
                  targetUserIds: [member.userId],
                ),
              ),
            ),
      ],
      isAdmin: _isAdmin,
      onRename: _rename,
      onAddMembers: _addMembers,
      onLeave: _leave,
      loading: _loading,
      busy: _busy,
      groupAvailable: group != null,
      error: _error,
    );
  }
}

String _shortManageContact(String address) {
  if (address.length <= 14) return address;
  return '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
}

class ChatSelectableUser {
  const ChatSelectableUser({
    required this.userId,
    required this.displayName,
    this.subtitle,
  });

  final String userId;
  final String displayName;
  final String? subtitle;
}

/// 通用群创建表单；联系人和创建动作由App提供。
class ChatGroupCreateView extends StatelessWidget {
  const ChatGroupCreateView({
    super.key,
    required this.nameController,
    required this.users,
    required this.selectedUserIds,
    required this.onSelectionChanged,
    required this.canCreate,
    required this.onCreate,
    this.loading = false,
    this.creating = false,
    this.error,
    this.emptyMessage = '通讯录为空',
  });

  final TextEditingController nameController;
  final List<ChatSelectableUser> users;
  final Set<String> selectedUserIds;
  final void Function(String userId, bool selected) onSelectionChanged;
  final bool canCreate;
  final VoidCallback onCreate;
  final bool loading;
  final bool creating;
  final String? error;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新建群聊'),
        actions: [
          TextButton(
            onPressed: canCreate && !creating ? onCreate : null,
            child: creating
                ? SizedBox(
                    width: AppLayout.scaled(context, 18),
                    height: AppLayout.scaled(context, 18),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('创建'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (loading)
            LinearProgressIndicator(
              key: const ValueKey('group-create-load-progress'),
              minHeight: AppLayout.scaled(context, 2),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: nameController,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '群名称',
                counterText: '',
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.scaled(context, 16),
            ),
            child: Row(
              children: [
                Text('选择成员', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  selectedUserIds.length < 2
                      ? '已选 ${selectedUserIds.length}·至少 2 人'
                      : '已选 ${selectedUserIds.length}',
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
              child: Text(error!, style: TextStyle(color: AppTheme.danger)),
            ),
          Expanded(
            child: loading && users.isEmpty
                ? const Center(child: Text('正在读取本地通讯录'))
                : users.isEmpty
                ? Center(child: Text(emptyMessage))
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final selected = selectedUserIds.contains(user.userId);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (value) =>
                            onSelectionChanged(user.userId, value ?? false),
                        title: Text(user.displayName),
                        subtitle: user.subtitle == null
                            ? null
                            : Text(
                                user.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ChatGroupMemberItem {
  const ChatGroupMemberItem({
    required this.userId,
    required this.displayName,
    required this.isAdmin,
    required this.canRemove,
    this.onRemove,
  });

  final String userId;
  final String displayName;
  final bool isAdmin;
  final bool canRemove;
  final VoidCallback? onRemove;
}

/// 通用群成员列表及管理页面。
class ChatGroupManageView extends StatelessWidget {
  const ChatGroupManageView({
    super.key,
    required this.title,
    required this.members,
    required this.isAdmin,
    required this.onLeave,
    this.onRename,
    this.onAddMembers,
    this.loading = false,
    this.busy = false,
    this.groupAvailable = true,
    this.error,
    this.memberLimit = 1989,
  });

  final String title;
  final List<ChatGroupMemberItem> members;
  final bool isAdmin;
  final VoidCallback onLeave;
  final VoidCallback? onRename;
  final VoidCallback? onAddMembers;
  final bool loading;
  final bool busy;
  final bool groupAvailable;
  final String? error;
  final int memberLimit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: '改群名',
              icon: const Icon(Icons.edit_outlined),
              onPressed: busy ? null : onRename,
            ),
        ],
      ),
      body: Column(
        children: [
          if (loading)
            LinearProgressIndicator(
              key: const ValueKey('group-manage-load-progress'),
              minHeight: AppLayout.scaled(context, 2),
            ),
          if (error != null)
            Padding(
              padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
              child: Text(error!, style: TextStyle(color: AppTheme.danger)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  '成员 ${groupAvailable ? members.length : '--'} / $memberLimit',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: busy ? null : onAddMembers,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('添加'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: !groupAvailable
                ? Center(child: Text(loading ? '正在读取群聊信息' : '群不存在或已退出'))
                : ListView(
                    children: [
                      for (final member in members)
                        ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member.userId.isEmpty
                                  ? '?'
                                  : member.userId.substring(0, 1),
                            ),
                          ),
                          title: Text(member.displayName),
                          subtitle: member.isAdmin ? const Text('管理员') : null,
                          trailing: member.canRemove
                              ? IconButton(
                                  tooltip: '移除',
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: busy ? null : member.onRemove,
                                )
                              : null,
                        ),
                    ],
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
              child: OutlinedButton.icon(
                onPressed: loading || !groupAvailable || busy ? null : onLeave,
                icon: const Icon(Icons.exit_to_app),
                label: const Text('退出群聊'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> showChatRenameGroupDialog(
  BuildContext context, {
  required String currentName,
}) async {
  final controller = TextEditingController(text: currentName);
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改群名'),
        content: TextField(
          controller: controller,
          maxLength: 40,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

Future<bool> showChatLeaveGroupDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('退出群聊'),
          content: const Text('退群后将收不到后续消息。确定退出？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('退出'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<List<String>?> showChatUserPickerDialog(
  BuildContext context, {
  required List<ChatSelectableUser> users,
}) {
  final selected = <String>{};
  return showDialog<List<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: const Text('添加成员'),
        content: SizedBox(
          width: double.maxFinite,
          child: users.isEmpty
              ? const Text('没有可添加的联系人')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final user in users)
                      CheckboxListTile(
                        value: selected.contains(user.userId),
                        onChanged: (value) => setLocal(() {
                          if (value ?? false) {
                            selected.add(user.userId);
                          } else {
                            selected.remove(user.userId);
                          }
                        }),
                        title: Text(user.displayName),
                        subtitle: user.subtitle == null
                            ? null
                            : Text(user.subtitle!),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(selected.toList(growable: false)),
            child: const Text('添加'),
          ),
        ],
      ),
    ),
  );
}
