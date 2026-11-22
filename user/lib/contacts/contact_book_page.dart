// 以本地优先通讯录展示联系人，提供主页、转账、私聊及备注和删除操作。

import 'package:citizen_system/identity_cid_display.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart'
    show signCitizenPayload;
import 'contact_scan.dart';
import 'package:provider/provider.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:citizen_user/profile/citizen_profile.dart';
import 'package:citizen_user/profile/profile_presentation.dart';
import 'package:citizen_user/profile/citizen_profile_api.dart';
import 'package:citizen_user/profile/citizen_profile_cache.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/profile/user_profile_page.dart';
import 'package:citizen_user/profile/profile_avatar.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_user/navigation.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/membership/membership_revision.dart';
import 'package:citizen_user/contacts/contact_service.dart';
import 'package:citizen_user/contacts/contact_sort.dart';
import 'package:citizen_scanner/qr_scan_page.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_user/identity/identity_register_guide.dart';
import 'package:citizen_user/identity/account_security_service.dart';

/// “我的通讯录”唯一页面。联系人关系本地优先、关系变更逐条云端同步；公开头像、昵称、
/// 签名与身份徽章复用统一用户资料，点击后进入现有 [UserProfilePage]。
class ContactBookPage extends StatefulWidget {
  const ContactBookPage({
    super.key,
    this.mode = ContactPickMode.browse,
    this.service,
    this.profileApi,
    this.profileCache,
    this.profileMediaCache,
    this.sessionProvider,
    this.initialProfiles = const <String, CitizenProfile>{},
    this.directChatOpener,
    this.transferOpener,
    this.currentUserContext,
    this.identityRevision,
    this.onSelectionChanged,
    this.selectionEnabled = true,
  });

  /// 页面模式:浏览 / 选收款人 / 聊天多选;不改变通讯录所属身份账户。
  final ContactPickMode mode;

  /// 聊天多选模式只嵌入原列表，公开资料、搜索和缓存仍由本页统一管理。
  final ValueChanged<List<UserContact>>? onSelectionChanged;
  final bool selectionEnabled;
  final UserContactService? service;
  final CitizenProfileApi? profileApi;
  final CitizenProfileCache? profileCache;
  final CitizenProfileMediaCache? profileMediaCache;
  final SquareSessionProvider? sessionProvider;
  final Map<String, CitizenProfile> initialProfiles;
  final DirectChatOpener? directChatOpener;
  final CurrentUserContext? currentUserContext;
  final Listenable? identityRevision;

  /// 测试可替换页面打开器；正式运行始终进入现有链上支付页面。
  final Future<void> Function(
    BuildContext context, {
    required String cidNumber,
  })?
  transferOpener;

  @override
  State<ContactBookPage> createState() => _ContactBookPageState();
}

class _ContactBookPageState extends State<ContactBookPage> {
  late final UserContactService _service;
  late final CitizenProfileApi _profileApi =
      widget.profileApi ?? CitizenProfileApi();
  late final CitizenProfileCache _profileCache =
      widget.profileCache ?? const CitizenProfileCache();
  late final CitizenProfileMediaCache _profileMediaCache =
      widget.profileMediaCache ?? CitizenProfileMediaCache();
  late final SquareSessionProvider _sessionProvider;
  late final CurrentUserContext _currentUserContext;
  Listenable? _identityRevision;
  bool _dependenciesReady = false;
  final TextEditingController _searchController = TextEditingController();

  List<UserContact> _contacts = const <UserContact>[];

  /// 公开资料按身份主键 身份CID号缓存（键 = cid_number，与资料接口寻址一致）。
  final Map<String, CitizenProfile> _profiles = <String, CitizenProfile>{};
  final Map<String, CitizenProfileMediaSnapshot> _profileMedia =
      <String, CitizenProfileMediaSnapshot>{};
  final Set<String> _resolvedProfileCidNumbers = <String>{};

  ContactSyncState _syncState = const ContactSyncState(
    phase: ContactSyncPhase.idle,
  );
  bool _loading = true;
  bool _retrying = false;
  Future<void>? _localRead;
  bool _localReadAgain = false;

  /// 当前钱包未注册 CID(合法状态,非故障)。置真时整页显示统一注册引导,
  /// 且**不读通讯录**——通讯录属主就是 CID,没有 CID 连读都不该读。
  bool _unregistered = false;
  String _query = '';
  final Set<String> _selected = {};
  String _ownerCid = '';
  int _loadGeneration = 0;
  Future<void> _profileRestore = Future<void>.value();
  Future<void> _cacheReads = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _profiles.addAll(widget.initialProfiles);
    _resolvedProfileCidNumbers.addAll(widget.initialProfiles.keys);
    MembershipRevision.instance.listenable.addListener(_onMembershipChanged);
    CitizenProfileCache.revision.addListener(_onProfileChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    final injectedService = widget.service;
    final injectedSession = widget.sessionProvider;
    final injectedCurrentUser = widget.currentUserContext;
    if (injectedService != null &&
        injectedSession != null &&
        injectedCurrentUser != null) {
      _service = injectedService;
      _sessionProvider = injectedSession;
      _currentUserContext = injectedCurrentUser;
      _service.syncState.addListener(_onSyncStateChanged);
      _identityRevision = widget.identityRevision;
      _identityRevision?.addListener(_onIdentityChanged);
      _dependenciesReady = true;
      unawaited(_load());
      return;
    }
    final accountSecurity = context.read<AccountSecurityService>();
    _sessionProvider =
        widget.sessionProvider ?? context.read<SquareSessionProvider>();
    _currentUserContext =
        widget.currentUserContext ?? context.read<CurrentUserContext>();
    _service =
        widget.service ??
        context.read<UserContactService?>() ??
        UserContactService(
          accountSecurity: accountSecurity,
          currentUserContext: _currentUserContext,
          sessionProvider: _sessionProvider,
        );
    _service.syncState.addListener(_onSyncStateChanged);
    _identityRevision = accountSecurity.revision;
    _identityRevision!.addListener(_onIdentityChanged);
    _dependenciesReady = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    _loadGeneration++;
    CitizenProfileCache.revision.removeListener(_onProfileChanged);
    _service.syncState.removeListener(_onSyncStateChanged);
    _identityRevision?.removeListener(_onIdentityChanged);
    MembershipRevision.instance.listenable.removeListener(_onMembershipChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSyncStateChanged() {
    if (!mounted) return;
    final state = _service.syncState.value;
    setState(() => _syncState = state);
    if (!_retrying &&
        [
          ContactSyncPhase.synced,
          ContactSyncPhase.failed,
          ContactSyncPhase.offline,
        ].contains(state.phase))
      unawaited(_reloadLocalContacts());
  }

  Future<void> _reloadLocalContacts() async {
    if (_localRead != null) {
      _localReadAgain = true;
      return _localRead;
    }
    late final Future<void> task;
    task =
        () async {
          do {
            _localReadAgain = false;
            final generation = ++_loadGeneration;
            try {
              final contacts = _filterContacts(await _service.getContacts());
              if (!mounted || generation != _loadGeneration) return;
              await _loadCachedProfiles(contacts, generation: generation);
              if (!mounted || generation != _loadGeneration) return;
              setState(() {
                _contacts = contacts;
                _loading = false;
              });
              _reconcileSelection();
            } on Object catch (error) {
              if (!mounted || generation != _loadGeneration) return;
              final failure = SquareSessionResolution.fromError(error);
              setState(() {
                _loading = false;
                _syncState = ContactSyncState(
                  phase: ContactSyncPhase.failed,
                  message: failure.message,
                  errorCode: failure.errorCode,
                  stage: failure.stage,
                );
              });
            }
          } while (_localReadAgain && mounted);
        }().whenComplete(() {
          if (identical(_localRead, task)) _localRead = null;
        });
    _localRead = task;
    await task;
  }

  /// CID finalized 后即使绑定账户没变也要退出“尚未注册”态；当前用户快照已在广播前
  /// 失效，此处重读即可得到新的 cid_number，不依赖当前注册引导的局部回调。
  void _onIdentityChanged() {
    if (mounted) {
      setState(() {
        _contacts = const [];
        _loading = true;
      });
      _clearSelection();
      unawaited(_load());
    }
  }

  void _notifySelection() {
    widget.onSelectionChanged?.call([
      for (final contact in _contacts)
        if (_selected.contains(contact.cidNumber)) contact,
    ]);
  }

  void _clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    // 身份广播可能发生于父级构建，延至帧末撤下父页的旧选择。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifySelection();
    });
  }

  void _toggleContact(UserContact contact) {
    if (!widget.selectionEnabled || _loading || contact.cidNumber == _ownerCid)
      return;
    setState(() {
      if (!_selected.add(contact.cidNumber))
        _selected.remove(contact.cidNumber);
    });
    _notifySelection();
  }

  List<UserContact> _filterContacts(List<UserContact> contacts) =>
      widget.mode == ContactPickMode.pickForChat
      ? contacts
            .where((contact) => contact.cidNumber != _ownerCid)
            .toList(growable: false)
      : contacts;

  void _reconcileSelection() {
    final available = _contacts.map((contact) => contact.cidNumber).toSet()
      ..remove(_ownerCid);
    _selected.removeWhere((cid) => !available.contains(cid));
    if (widget.mode == ContactPickMode.pickForChat) _notifySelection();
  }

  /// 只刷新通讯录中与事件 CID 匹配的公开资料，避免会员变化触发整本通讯录同步。
  void _onMembershipChanged() {
    final event = MembershipRevision.instance.listenable.value;
    if (!mounted || event == null) return;
    final matching = _contacts
        .where((contact) => contact.cidNumber == event.cidNumber)
        .toList(growable: false);
    if (matching.isEmpty) return;
    unawaited(_refreshMembershipProfiles(matching));
  }

  void _onProfileChanged() {
    final event = CitizenProfileCache.revision.value;
    if (!mounted || event == null) return;
    final matching = _contacts
        .where((c) => c.cidNumber == event.cidNumber)
        .toList();
    if (matching.isNotEmpty) unawaited(_refreshMembershipProfiles(matching));
  }

  // 恢复关系后后台补齐公开资料，跨页面复用十分钟限速；最多两个并发读取。
  // 批次顺序排队，旧身份任务退出后才启动新批次，不让切换账户扩大并发。
  void _restoreProfiles(
    List<UserContact> contacts,
    IdentityBinding binding,
    int generation,
  ) {
    bool current() => mounted && generation == _loadGeneration;
    _profileRestore = _profileRestore.then((_) async {
      var next = 0;
      Future<void> read() async {
        while (current() && next < contacts.length) {
          final cid = contacts[next++].cidNumber;
          try {
            final result = await _profileApi.refreshOnEntry(
              cid,
              binding: binding,
              sessions: _sessionProvider,
              cache: _profileCache,
              mediaCache: _profileMediaCache,
              isCurrentIdentity: current,
            );
            if (!current()) return;
            if (result != null) {
              _profiles[cid] = result.profile.profile;
              _resolvedProfileCidNumbers.add(cid);
              try {
                final media = await _profileMediaCache.read(
                  result.profile.profile,
                );
                if (!current()) return;
                _profileMedia[cid] = media;
              } on Object {
                /* 单个媒体失败仍显示已恢复的昵称。 */
              }
              if (current()) setState(() {});
            }
          } on Object {
            // 单个资料失败保留本地展示，其余联系人继续恢复。
          }
        }
      }

      await Future.wait([read(), read()]);
    });
  }

  Future<void> _refreshMembershipProfiles(List<UserContact> contacts) async {
    final generation = _loadGeneration;
    for (final contact in contacts) {
      _profiles.remove(contact.cidNumber);
      _profileMedia.remove(contact.cidNumber);
    }
    await _loadCachedProfiles(contacts, generation: generation);
    if (mounted && generation == _loadGeneration) setState(() {});
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      // 未注册 CID 必须在此短路:通讯录属主 = CID,`getContacts()` 第一步
      // 身份未知或未注册返回精确门禁错误，catch 后
      // `_contacts` 保持空,渲染会落到「空通讯录」——把"你没注册"显示成"你没有联系人",
      // 与广场当初把权限态伪装成"加载失败"是同一类错误。
      // 公开同步独立完成；页面只消费已核实状态，不借会话入口查链或登记设备。
      var identity = await _currentUserContext.resolve();
      if (!mounted || generation != _loadGeneration) return;
      if (identity == null) {
        setState(() {
          _unregistered = true;
          _contacts = const <UserContact>[];
          _loading = false;
        });
        return;
      }
      if (identity.isUnregistered) {
        setState(() {
          _unregistered = true;
          _contacts = const <UserContact>[];
          _loading = false;
        });
        return;
      }
      if (!identity.isRegistered) {
        throw const SquareApiException(
          '身份信息暂不可用，请在身份页刷新后重试',
          errorCode: 'identity_local_missing',
          stage: SquareApiStage.identity,
        );
      }
      _ownerCid = identity.cidNumber;
      if (_unregistered) setState(() => _unregistered = false);
      final contacts = _filterContacts(await _service.getContacts());
      final syncState = await _service.readSyncState();
      if (!mounted || generation != _loadGeneration) return;
      await _loadCachedProfiles(contacts, generation: generation);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _contacts = contacts;
        _syncState = syncState;
        _loading = false;
      });
      _reconcileSelection();
      _restoreProfiles(contacts, identity.binding!, generation);
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      final failure = SquareSessionResolution.fromError(error);
      setState(() {
        _loading = false;
        _syncState = ContactSyncState(
          phase: ContactSyncPhase.failed,
          message: failure.message,
          errorCode: failure.errorCode,
          stage: failure.stage,
        );
      });
    }
  }

  Future<void> _refreshContacts() async {
    if (_retrying) return;
    _retrying = true;
    final generation = ++_loadGeneration;
    try {
      final contacts = _filterContacts(await _service.sync());
      final syncState = await _service.readSyncState();
      if (!mounted || generation != _loadGeneration) return;
      await _loadCachedProfiles(contacts, generation: generation);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _contacts = contacts;
        _syncState = syncState;
      });
      _reconcileSelection();
      final identity = await _currentUserContext.resolve();
      if (mounted &&
          generation == _loadGeneration &&
          identity?.binding != null) {
        _restoreProfiles(contacts, identity!.binding!, generation);
      }
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      final failure = SquareSessionResolution.fromError(error);
      setState(() {
        _loading = false;
        _syncState = ContactSyncState(
          phase: ContactSyncPhase.failed,
          message: failure.message,
          errorCode: failure.errorCode,
          stage: failure.stage,
          retryByPull: true,
        );
      });
    } finally {
      _retrying = false;
    }
  }

  /// 联系人关系已强制携带永久 CID，公开资料无需再按 account_id 临时链读。
  CitizenProfile? _profileOf(UserContact contact) =>
      _profiles[contact.cidNumber];

  /// 联系人关系和公开资料缓存先在内存中完成同一首帧装配，再一次性显示列表；资料尚未
  /// 解析时保持中性占位，不能把“未知”误画成用户从未设置头像的内置照片。
  Future<void> _loadCachedProfiles(
    List<UserContact> contacts, {
    required int generation,
  }) {
    final flight = _cacheReads.then((_) async {
      var next = 0;
      Future<void> read() async {
        while (mounted &&
            generation == _loadGeneration &&
            next < contacts.length) {
          final contact = contacts[next++];
          final cidNumber = contact.cidNumber;
          try {
            final profile =
                _profiles[cidNumber] ?? await _profileCache.read(cidNumber);
            if (profile == null || !mounted || generation != _loadGeneration)
              continue;
            _profiles[cidNumber] = profile;
            _resolvedProfileCidNumbers.add(cidNumber);
            try {
              final media = await _profileMediaCache.read(profile);
              if (!mounted || generation != _loadGeneration) continue;
              _profileMedia[cidNumber] = media;
            } on Object {
              // 资料 JSON 已解析时仍可显示真实昵称和徽章；单个媒体文件故障不阻塞联系人。
            }
          } on Object {
            // 单个公开资料缓存故障保持中性占位，不能阻塞整本本地通讯录。
          }
        }
      }

      await Future.wait([read(), read()]);
    });
    _cacheReads = flight;
    return flight;
  }

  Future<void> _scanContactQr() async {
    // 复用统一「扫码加好友」收口(写库与提示在扫码页内完成),扫毕本地刷新。
    await scanAndAddContact(context, service: _service);
    if (!mounted) return;
    await _load();
  }

  Future<void> _rename(UserContact contact) async {
    final generation = _loadGeneration;
    final formKey = GlobalKey<FormState>();
    var draftRemark = contact.contactRemark;
    final remark = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改私人备注'),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: contact.contactRemark,
            autofocus: true,
            maxLength: 40,
            validator: (value) {
              try {
                UserContactService.normalizeContactRemark(value ?? '');
                return null;
              } on FormatException {
                return '备注只能输入中英文，可留空';
              }
            },
            decoration: const InputDecoration(hintText: '可留空'),
            onChanged: (value) => draftRemark = value,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.of(dialogContext).pop(draftRemark.trim());
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (remark == null || !mounted || generation != _loadGeneration) return;
    final contacts = await _service.renameContact(contact.cidNumber, remark);
    if (mounted && generation == _loadGeneration) {
      setState(() => _contacts = contacts);
    }
  }

  Future<void> _transfer(UserContact contact) async {
    if (widget.mode == ContactPickMode.pickForTransfer) {
      Navigator.of(context).pop(contact.cidNumber);
      return;
    }
    final openTransfer =
        widget.transferOpener ?? context.read<UserNavigation>().openTransfer;
    await openTransfer(context, cidNumber: contact.cidNumber);
  }

  Future<void> _message(UserContact contact) async {
    final profile = _profileOf(contact);
    final title = ProfilePresentation.forIdentityKey(
      contact.cidNumber,
    ).resolveDisplayName(publicName: profile?.displayName);
    final opener =
        widget.directChatOpener ??
        (context, {required peerUserId, required title}) => context
            .read<UserNavigation>()
            .openDirectChat(context, peerUserId: peerUserId, title: title);
    await opener(context, peerUserId: contact.cidNumber, title: title);
  }

  Future<void> _delete(UserContact contact) async {
    final generation = _loadGeneration;
    final selected = <String>{contact.cidNumber};
    final confirmed = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('删除联系人'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('确定从通讯录删除“${_contactDisplayName(contact)}”？'),
              if (_contacts.length > 1)
                SizedBox(
                  height: 240,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final item = _contacts[index];
                      return CheckboxListTile(
                        value: selected.contains(item.cidNumber),
                        title: Text(_contactDisplayName(item)),
                        subtitle: Text(formatIdentityCidText(item.cidNumber)),
                        onChanged: (value) => update(() {
                          if (value == true) {
                            selected.add(item.cidNumber);
                          } else {
                            selected.remove(item.cidNumber);
                          }
                        }),
                      );
                    },
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.of(
                      dialogContext,
                    ).pop(Set<String>.of(selected)),
              child: const Text('删除'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == null || !mounted || generation != _loadGeneration) return;
    try {
      final contacts = await _service.deleteContacts(
        confirmed.toList(),
        signer: (accountId, payload) => signCitizenPayload(
          signing: context.read<CitizenSdk>(),
          context: context,
          accountId: accountId,
          payload: payload,
          action: UserContactService.deleteAction,
        ),
      );
      if (mounted && generation == _loadGeneration)
        setState(() => _contacts = contacts);
    } catch (error) {
      if (mounted && generation == _loadGeneration)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SquareSessionResolution.fromError(error).message),
          ),
        );
    }
  }

  Future<void> _open(UserContact contact) async {
    switch (widget.mode) {
      case ContactPickMode.pickForTransfer:
        // 交易发起:把选中的联系人返回给收款栏。
        await _transfer(contact);
      case ContactPickMode.pickForChat:
        _toggleContact(contact);
      case ContactPickMode.browse:
        // 资料页按通讯录关系主键 cid_number 直接寻址。
        await _openProfile(contact);
    }
  }

  /// 打开联系人主页：通讯录只接受已经完成双向绑定解析的永久 CID。
  Future<void> _openProfile(UserContact contact) async {
    final cidNumber = contact.cidNumber;
    await UserProfilePage.open(
      context,
      UserProfilePage(
        cidNumber: cidNumber,
        isSelf: false,
        initialProfile: _profiles[cidNumber],
        initialProfileMedia: _profileMedia[cidNumber],
        api: _profileApi,
        cache: _profileCache,
        mediaCache: _profileMediaCache,
        sessionProvider: _sessionProvider,
      ),
    );
  }

  List<UserContact> get _visibleContacts {
    final query = _query.trim().toLowerCase();
    final visible =
        _contacts
            .where((contact) {
              if (query.isEmpty) return true;
              final profile = _profileOf(contact);
              final publicName =
                  ProfilePresentation.forIdentityKey(contact.cidNumber)
                      .resolveDisplayName(publicName: profile?.displayName)
                      .toLowerCase();
              return contact.contactRemark.toLowerCase().contains(query) ||
                  contact.cidNumber.toLowerCase().contains(query) ||
                  publicName.contains(query);
            })
            .toList(growable: false)
          ..sort(
            (a, b) => compareContactKeys(
              a.contactRemark,
              a.cidNumber,
              b.contactRemark,
              b.cidNumber,
            ),
          );
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleContacts;
    final body = _unregistered
        ? IdentityRegisterGuide(
            description: '注册后即可使用通讯录。',
            onRegistered: () => unawaited(_load()),
          )
        : _buildContactList(visible);
    if (widget.mode == ContactPickMode.pickForChat) return body;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('我的通讯录'),
        centerTitle: true,
        actions: [
          if (!_unregistered)
            IconButton(
              tooltip: '扫码添加联系人',
              onPressed: _scanContactQr,
              icon: SvgPicture.asset(
                'packages/citizen_assets/icons/scan-line.svg',
                width: AppLayout.scaled(context, 20),
                height: AppLayout.scaled(context, 20),
              ),
            ),
        ],
      ),
      // 未注册 = 合法状态,整页给统一注册引导(与广场/聊天/创作者同规),
      // 不显示搜索框和假的「空通讯录」。
      body: body,
    );
  }

  Widget _buildContactList(List<UserContact> visible) {
    return RefreshIndicator(
      onRefresh: _refreshContacts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          if (_loading) ...[
            LinearProgressIndicator(
              key: const ValueKey('contacts-local-load-progress'),
              minHeight: AppLayout.scaledValue(2),
            ),
            SizedBox(height: AppLayout.scaledValue(10)),
          ],
          _SyncBanner(state: _syncState, onRetry: _service.flushPending),
          SizedBox(height: AppLayout.scaledValue(10)),
          TextField(
            key: const ValueKey('contact-search'),
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: '搜索昵称、备注或身份CID号',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppTheme.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.scaledValue(14)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: AppLayout.scaledValue(12)),
          if (_loading && _contacts.isEmpty)
            const _ContactsLoadingNotice()
          else if (_contacts.isEmpty)
            const _EmptyContacts()
          else if (visible.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: AppLayout.scaledValue(56),
              ),
              child: const Center(child: Text('没有匹配的联系人')),
            )
          else
            for (final contact in visible) ...[
              _ContactCard(
                contact: contact,
                profile: _profileOf(contact),
                profileResolved: _resolvedProfileCidNumbers.contains(
                  contact.cidNumber,
                ),
                avatarPath: _profileMedia[contact.cidNumber]?.avatarPath,
                avatarUrl: _avatarUrl(_profileOf(contact)),

                showActions: widget.mode != ContactPickMode.pickForChat,
                selected: widget.mode == ContactPickMode.pickForChat
                    ? _selected.contains(contact.cidNumber)
                    : null,
                onTap:
                    widget.mode == ContactPickMode.pickForChat &&
                        !widget.selectionEnabled
                    ? null
                    : () => _open(contact),
                onTransfer: () => _transfer(contact),
                onMessage: () => _message(contact),
                onRename: () => _rename(contact),
                onDelete: () => _delete(contact),
              ),
              SizedBox(height: AppLayout.scaledValue(10)),
            ],
        ],
      ),
    );
  }

  String? _avatarUrl(CitizenProfile? profile) {
    final key = profile?.avatarKey;
    return key == null
        ? null
        : _profileApi.cardMediaUrl(key, updatedAt: profile?.profileAt);
  }

  String _contactDisplayName(UserContact contact) {
    final profile = _profileOf(contact);
    return ProfilePresentation.forIdentityKey(
      contact.cidNumber,
    ).resolveDisplayName(publicName: profile?.displayName);
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.profile,
    required this.profileResolved,
    required this.avatarPath,
    required this.avatarUrl,

    required this.showActions,
    required this.onTap,
    required this.onTransfer,
    required this.onMessage,
    required this.onRename,
    required this.onDelete,
    this.selected,
  });

  final UserContact contact;
  final CitizenProfile? profile;
  final bool profileResolved;
  final String? avatarPath;
  final String? avatarUrl;

  /// 是否显示逐项操作菜单(转账/私信/改名/删除);纯选人模式为 false。
  final bool showActions;
  final VoidCallback? onTap;
  final bool? selected;
  final VoidCallback onTransfer;
  final VoidCallback onMessage;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final publicName = ProfilePresentation.forIdentityKey(
      contact.cidNumber,
    ).resolveDisplayName(publicName: profile?.displayName);
    final remark = contact.contactRemark;
    return Material(
      key: ValueKey('contact-card-${contact.cidNumber}'),
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(AppLayout.scaledValue(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(16)),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: AppLayout.scaled(context, 88)),
          child: Padding(
            padding: EdgeInsets.all(AppLayout.scaled(context, 12)),
            child: Row(
              children: [
                if (selected != null) ...[
                  Checkbox(
                    value: selected,
                    shape: const CircleBorder(),
                    onChanged: onTap == null ? null : (_) => onTap!(),
                    semanticLabel:
                        '选择${contact.contactRemark.isEmpty ? publicName : contact.contactRemark}',
                  ),
                  SizedBox(width: AppLayout.scaled(context, 8)),
                ],
                ProfileAvatar(
                  seed: contact.cidNumber,
                  size: AppLayout.scaled(context, 52),
                  imagePath: avatarPath,
                  imageUrl: avatarUrl,

                  userImageSet: profileResolved
                      ? profile?.avatarKey?.trim().isNotEmpty == true
                      : true,
                  borderRadius: 14,
                ),
                SizedBox(width: AppLayout.scaled(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        publicName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: AppLayout.scaled(context, 16),
                          fontWeight: FontWeight.w700,
                          height: AppLayout.compactLineHeight,
                        ),
                      ),
                      if (remark.isNotEmpty) ...[
                        SizedBox(height: AppLayout.scaled(context, 3)),
                        Text(
                          '备注：$remark',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: AppLayout.scaled(context, 12),
                            height: AppLayout.subtitleLineHeight,
                          ),
                        ),
                      ],
                      SizedBox(height: AppLayout.scaled(context, 3)),
                      Text(
                        '身份CID号：${formatIdentityCidText(contact.cidNumber)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: AppLayout.scaled(context, 12),
                          height: AppLayout.subtitleLineHeight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showActions)
                  PopupMenuButton<_ContactMenuAction>(
                    tooltip: '联系人操作',
                    // 显式指定竖向三点，避免框架在 iOS 使用横向自适应图标。
                    icon: const Icon(
                      Icons.more_vert,
                      size: AppLayout.iconStandard,
                    ),
                    onSelected: (action) => switch (action) {
                      _ContactMenuAction.transfer => onTransfer(),
                      _ContactMenuAction.message => onMessage(),
                      _ContactMenuAction.rename => onRename(),
                      _ContactMenuAction.delete => onDelete(),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _ContactMenuAction.transfer,
                        child: Text('转账'),
                      ),
                      PopupMenuItem(
                        value: _ContactMenuAction.message,
                        child: Text('私信'),
                      ),
                      PopupMenuItem(
                        value: _ContactMenuAction.rename,
                        child: Text('修改备注'),
                      ),
                      PopupMenuItem(
                        value: _ContactMenuAction.delete,
                        child: Text(
                          '删除联系人',
                          style: TextStyle(color: AppTheme.danger),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ContactMenuAction { transfer, message, rename, delete }

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.state, required this.onRetry});

  final ContactSyncState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError =
        state.phase == ContactSyncPhase.failed ||
        state.phase == ContactSyncPhase.offline;
    final retryable = hasError && !state.retryByPull;
    return InkWell(
      onTap: retryable ? () => unawaited(onRetry()) : null,
      borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaled(context, 4),
          vertical: AppLayout.scaled(context, 5),
        ),
        child: Row(
          children: [
            Icon(
              state.phase == ContactSyncPhase.synced
                  ? Icons.cloud_done_outlined
                  : state.phase == ContactSyncPhase.syncing
                  ? Icons.sync_rounded
                  : Icons.cloud_outlined,
              size: AppLayout.scaled(context, 16),
              color: hasError ? AppTheme.warning : AppTheme.textTertiary,
            ),
            SizedBox(width: AppLayout.scaled(context, 6)),
            Text(
              state.retryByPull
                  ? '同步失败，请下拉重试'
                  : state.stage == SquareApiStage.identity ||
                        state.stage == SquareApiStage.registration ||
                        state.errorCode == 'device_not_registered' ||
                        state.errorCode?.startsWith('mls_') == true
                  ? state.message ?? state.label
                  : state.label,
              style: TextStyle(
                color: hasError ? AppTheme.warning : AppTheme.textTertiary,
                fontSize: AppLayout.scaled(context, 12),
                height: AppLayout.subtitleLineHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsLoadingNotice extends StatelessWidget {
  const _ContactsLoadingNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: AppLayout.scaled(context, 64),
        horizontal: AppLayout.scaled(context, 28),
      ),
      child: Column(
        children: [
          Icon(
            Icons.perm_contact_calendar_outlined,
            size: AppLayout.scaled(context, 52),
            color: AppTheme.primary,
          ),
          SizedBox(height: AppLayout.scaled(context, 16)),
          Text(
            '正在读取本地通讯录',
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 17),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: AppLayout.scaled(context, 64),
        horizontal: AppLayout.scaled(context, 28),
      ),
      child: Column(
        children: [
          Icon(
            Icons.perm_contact_calendar_outlined,
            size: AppLayout.scaled(context, 52),
            color: AppTheme.primary,
          ),
          SizedBox(height: AppLayout.scaled(context, 16)),
          Text(
            '通讯录还是空的',
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 19),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppLayout.scaled(context, 8)),
          const Text(
            '扫描其他用户的二维码添加联系人，云端同步后换设备也能恢复。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// 通讯录 / 聊天页共用的「扫码加好友」收口。
///
/// 打开 contact 模式扫码页,扫到用户名片码即写入本机并同步本人云端通讯录
/// (写库与「已加入/已在通讯录」提示均在扫码页内完成)。调用方返回后自行刷新列表。
Future<void> scanAndAddContact(
  BuildContext context, {
  UserContactService? service,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (scanContext) => QrScanPage(
        mode: QrScanMode.contact,
        importContact: (body) async {
          final contactService =
              service ?? scanContext.read<UserContactService>();
          return (await addUserQrContact(
            body: body,
            contactService: contactService,
          )).created;
        },
        contactErrorMessage: contactImportFailure,
      ),
    ),
  );
}
