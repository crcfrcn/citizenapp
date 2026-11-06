import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import 'mls_boundary.dart';
import 'mls_group_boundary.dart';
import 'mls_state_store.dart';

/// 通过现有 native 库调用 Rust OpenMLS。
///
/// 该类只负责跨 FFI 边界，密码学实现全部在 Rust OpenMLS 中完成。
class OpenMlsCrypto implements MlsGroupCrypto, MlsPersistentCrypto {
  OpenMlsCrypto({
    OpenMlsBindings? bindings,
    ChatDevice? identity,
    MlsStateStore? stateStore,
  }) : _bindings = bindings ?? OpenMlsBindings.load(),
       _identity = identity,
       _stateStore = stateStore;

  final OpenMlsBindings _bindings;
  final ChatDevice? _identity;
  final MlsStateStore? _stateStore;

  static final Object _messageZoneKey = Object();
  String get _messageId {
    final id = Zone.current[_messageZoneKey] as String?;
    if (id == null || id.isEmpty) throw StateError('MLS状态变更必须提供现有message_id');
    return id;
  }

  @override
  Future<T> withMessage<T>(String messageId, Future<T> Function() operation) =>
      runZoned(operation, zoneValues: {_messageZoneKey: messageId});
  @override
  Future<void> acknowledgeMessage(String messageId) =>
      _requireStateStore().acknowledge(messageId);
  @override
  Future<List<Map<String, dynamic>>> pendingMessageResults(String? messageId) =>
      _requireStateStore().pendingResults(messageId);

  /// 上下文释放不删除持久化MLS身份。
  void dispose() {
    _stateStore?.dispose();
  }

  @override
  Future<MlsKeyPackage> createKeyPackage(
    ChatDevice identity, {
    bool lastResort = true,
  }) async {
    final error = identity.validate();
    if (error != null) {
      throw ArgumentError(error);
    }

    final response = _bindings.callJson(_bindings.createKeyPackage, {
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'state_store_dir': _requireStateStore().path,
      'message_id':
          'key-package:${identity.deviceId}:$lastResort:${DateTime.now().millisecondsSinceEpoch ~/ 86400000}',
      'last_resort': lastResort,
    });
    return MlsKeyPackage(
      userId: identity.userId,
      deviceId: identity.deviceId,
      keyPackageRef: _requireField(
        response,
        'key_package_ref',
        operation: OpenMlsOperation.keyPackage,
      ),
      keyPackageBytes: _hexToBytes(
        _requireField(
          response,
          'key_package_hex',
          operation: OpenMlsOperation.keyPackage,
        ),
      ),
      cipherSuite: (response['cipher_suite'] ?? '').toString(),
      notBeforeMillis: (response['not_before_millis'] as num?)?.toInt() ?? 0,
      notAfterMillis: (response['not_after_millis'] as num?)?.toInt() ?? 0,
      lastResort: response['last_resort'] == true,
    );
  }

  // 私聊和群聊统一调用同一套 OpenMLS 群接口。

  @override
  Future<GroupCreated> createGroup(String groupId) async {
    final identity = _requireIdentity();
    final stateStore = _requireStateStore();
    await stateStore.ensureReady();
    final response = _bindings.callJson(_bindings.groupCreate, {
      'state_store_dir': stateStore.path,
      'message_id': _messageId,
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'group_id': groupId,
    });
    return GroupCreated(
      groupId: (response['group_id'] ?? groupId).toString(),
      epoch: (response['epoch'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<GroupCommitBundle> addMembers(
    String groupId,
    List<MlsKeyPackage> keyPackages,
  ) async {
    final identity = _requireIdentity();
    final stateStore = _requireStateStore();
    await stateStore.ensureReady();
    final response = _bindings.callJson(_bindings.groupAddMembers, {
      'state_store_dir': stateStore.path,
      'message_id': _messageId,
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'group_id': groupId,
      'expected_member_identities': keyPackages
          .map((package) => '${package.userId}:${package.deviceId}')
          .toList(),
      'key_packages_hex': keyPackages
          .map((keyPackage) => keyPackage.keyPackageHex)
          .toList(),
    });
    final welcomeHex = (response['welcome_wire_hex'] ?? '').toString();
    return GroupCommitBundle(
      groupId: (response['group_id'] ?? groupId).toString(),
      epoch: (response['epoch'] as num?)?.toInt() ?? 0,
      commit: _groupWire(
        groupId,
        (response['commit_wire_hex'] ?? '').toString(),
        MlsMessageKind.commit,
      ),
      priorMemberIdentities: (response['prior_member_identities'] as List)
          .cast<String>(),
      createdAtMillis: (response['created_at_millis'] as num).toInt(),
      welcome: welcomeHex.isEmpty
          ? null
          : _groupWire(groupId, welcomeHex, MlsMessageKind.welcome),
    );
  }

  @override
  Future<GroupCommitBundle> removeMembers(
    String groupId,
    List<String> memberIdentities,
  ) async {
    final identity = _requireIdentity();
    final stateStore = _requireStateStore();
    await stateStore.ensureReady();
    final response = _bindings.callJson(_bindings.groupRemoveMembers, {
      'state_store_dir': stateStore.path,
      'message_id': _messageId,
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'group_id': groupId,
      'member_identities': memberIdentities,
    });
    final removed =
        (response['removed_member_identities'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];
    return GroupCommitBundle(
      groupId: (response['group_id'] ?? groupId).toString(),
      epoch: (response['epoch'] as num?)?.toInt() ?? 0,
      commit: _groupWire(
        groupId,
        (response['commit_wire_hex'] ?? '').toString(),
        MlsMessageKind.commit,
      ),
      removedMemberIdentities: removed,
      priorMemberIdentities: (response['prior_member_identities'] as List)
          .cast<String>(),
      createdAtMillis: (response['created_at_millis'] as num).toInt(),
    );
  }

  @override
  Future<MlsWireMessage> groupCreateMessage(
    String groupId,
    List<int> plaintext,
  ) async {
    final identity = _requireIdentity();
    final stateStore = _requireStateStore();
    await stateStore.ensureReady();
    final response = _bindings.callJson(_bindings.groupCreateMessage, {
      'state_store_dir': stateStore.path,
      'message_id': _messageId,
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'group_id': groupId,
      'plaintext_hex': _bytesToHex(plaintext),
    });
    return _groupWire(
      groupId,
      (response['application_wire_hex'] ?? '').toString(),
      MlsMessageKind.application,
    );
  }

  @override
  Future<GroupInbound> groupProcess(MlsWireMessage wire) async {
    final identity = _requireIdentity();
    final stateStore = _requireStateStore();
    await stateStore.ensureReady();
    final response = _bindings.callJson(_bindings.groupProcess, {
      'state_store_dir': stateStore.path,
      'message_id': _messageId,
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'group_id': wire.conversationId,
      'wire_message_hex': wire.wireHex,
    });
    final plaintextHex = response['plaintext_hex']?.toString();
    final members = (response['member_identities'] as List?)
        ?.map((item) => item.toString())
        .toList();
    final sender = response['sender_member_identity'] as String?;
    if (response['status'] == 'applied' &&
        response['message_kind'] != 'unknown') {
      if (sender == null || !RegExp(r'^[^:]+:[0-9a-f]{64}$').hasMatch(sender)) {
        throw StateError('OpenMLS实际发送者缺失或无效');
      }
    }
    return GroupInbound(
      groupId: (response['group_id'] ?? wire.conversationId).toString(),
      kind: GroupInboundKind.fromWireName(
        (response['message_kind'] ?? '').toString(),
      ),
      status: GroupProcessStatus.fromWireName(
        (response['status'] ?? '').toString(),
      ),
      messageEpoch: (response['message_epoch'] as num?)?.toInt() ?? 0,
      groupEpoch: (response['group_epoch'] as num?)?.toInt() ?? 0,
      selfRemoved: response['self_removed'] == true,
      plaintext: plaintextHex == null || plaintextHex.isEmpty
          ? null
          : _hexToBytes(plaintextHex),
      memberIdentities: members,
      senderMemberIdentity: sender,
      committed: response['committed'] == true,
    );
  }

  @override
  Future<GroupState> groupState(String groupId) async {
    final identity = _requireIdentity();
    final stateStore = _requireStateStore();
    await stateStore.ensureReady();
    final response = _bindings.callJson(_bindings.groupState, {
      'state_store_dir': stateStore.path,
      'user_id': identity.userId,
      'device_id': identity.deviceId,
      'group_id': groupId,
    });
    final members =
        (response['member_identities'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];
    return GroupState(
      groupId: (response['group_id'] ?? groupId).toString(),
      epoch: (response['epoch'] as num?)?.toInt() ?? 0,
      memberIdentities: members,
    );
  }

  MlsWireMessage _groupWire(
    String groupId,
    String wireHex,
    MlsMessageKind kind,
  ) {
    return MlsWireMessage(
      wireBytes: _hexToBytes(wireHex),
      conversationId: groupId,
      messageKind: kind,
    );
  }

  ChatDevice _requireIdentity() {
    final identity = _identity;
    if (identity == null) {
      throw StateError('OpenMlsCrypto 需要 Chat 设备身份才能执行会话加解密');
    }
    final error = identity.validate();
    if (error != null) {
      throw ArgumentError(error);
    }
    return identity;
  }

  MlsStateStore _requireStateStore() {
    final store = _stateStore;
    if (store == null) {
      throw StateError('OpenMlsCrypto 需要 MLS stateStore 才能持久化会话');
    }
    return store;
  }
}

typedef MlsJsonNative =
    Pointer<Utf8> Function(
      Pointer<Utf8> requestJson,
      Pointer<Pointer<Utf8>> errorOut,
    );
typedef MlsJsonDart =
    Pointer<Utf8> Function(
      Pointer<Utf8> requestJson,
      Pointer<Pointer<Utf8>> errorOut,
    );
typedef MlsFreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef MlsFreeStringDart = void Function(Pointer<Utf8> ptr);

/// Chat MLS native bindings。
class OpenMlsBindings {
  OpenMlsBindings._({
    required this.createKeyPackage,
    required this.identity,
    required this.store,
    required this.groupCreate,
    required this.groupAddMembers,
    required this.groupRemoveMembers,
    required this.groupCreateMessage,
    required this.groupProcess,
    required this.groupState,
    required MlsFreeStringDart freeString,
  }) : _freeString = freeString;

  final MlsJsonDart createKeyPackage;
  final MlsJsonDart identity;
  final MlsJsonDart store;
  final MlsJsonDart groupCreate;
  final MlsJsonDart groupAddMembers;
  final MlsJsonDart groupRemoveMembers;
  final MlsJsonDart groupCreateMessage;
  final MlsJsonDart groupProcess;
  final MlsJsonDart groupState;
  final MlsFreeStringDart _freeString;

  static OpenMlsBindings load() {
    final library = _loadOpenMlsLibrary();
    return OpenMlsBindings._(
      createKeyPackage: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'chat_openmls_create_key_package_json',
      ),
      identity: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'chat_openmls_identity_json',
      ),
      store: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'chat_openmls_store_json',
      ),
      groupCreate: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'chat_openmls_group_create_json',
      ),
      groupAddMembers: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'chat_openmls_group_add_members_json',
      ),
      groupRemoveMembers: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'chat_openmls_group_remove_members_json',
      ),
      groupCreateMessage: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'chat_openmls_group_create_message_json',
      ),
      groupProcess: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'chat_openmls_group_process_json',
      ),
      groupState: library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'chat_openmls_group_state_json',
      ),
      freeString: library
          .lookupFunction<MlsFreeStringNative, MlsFreeStringDart>(
            'chat_openmls_free_string',
          ),
    );
  }

  Map<String, dynamic> callJson(
    MlsJsonDart function,
    Map<String, Object?> request,
  ) {
    final operation = _operationFor(function);
    final requestPtr = jsonEncode(request).toNativeUtf8();
    final errorOut = calloc<Pointer<Utf8>>();
    Pointer<Utf8> resultPtr = nullptr;
    try {
      resultPtr = function(requestPtr, errorOut);
      if (resultPtr == nullptr) {
        final errorPtr = errorOut.value;
        final message = errorPtr == nullptr
            ? 'OpenMLS native 调用失败'
            : errorPtr.toDartString();
        if (errorPtr != nullptr) {
          _freeString(errorPtr);
        }
        throw OpenMlsException.fromTechnicalMessage(
          message,
          operation: operation,
        );
      }
      try {
        final json = jsonDecode(resultPtr.toDartString());
        if (json is! Map<String, dynamic>) throw const FormatException();
        return json;
      } on FormatException {
        throw OpenMlsException(
          OpenMlsErrorCode.invalidResponse,
          'OpenMLS native响应JSON结构无效',
          operation: operation,
        );
      }
    } finally {
      calloc.free(requestPtr);
      calloc.free(errorOut);
      if (resultPtr != nullptr) {
        _freeString(resultPtr);
      }
    }
  }

  // 操作名只取本绑定持有的函数槽位，不读取或记录调用参数。
  OpenMlsOperation _operationFor(MlsJsonDart function) {
    for (final entry in <MlsJsonDart, OpenMlsOperation>{
      createKeyPackage: OpenMlsOperation.keyPackage,
      identity: OpenMlsOperation.identity,
      store: OpenMlsOperation.store,
      groupCreate: OpenMlsOperation.groupCreate,
      groupAddMembers: OpenMlsOperation.groupAdd,
      groupRemoveMembers: OpenMlsOperation.groupRemove,
      groupCreateMessage: OpenMlsOperation.groupMessage,
      groupProcess: OpenMlsOperation.groupProcess,
      groupState: OpenMlsOperation.groupState,
    }.entries) {
      if (identical(function, entry.key)) return entry.value;
    }
    return OpenMlsOperation.unknown;
  }
}

DynamicLibrary _loadOpenMlsLibrary() {
  // iOS由公民聊天自己的CocoaPods目标装载动态Framework，沿用正式插件合同。
  // 公民聊天 自己的 CocoaPods 目标不依赖其它产品原生库。
  if (Platform.isIOS) return DynamicLibrary.process();
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    final work = Platform.environment['CITIZENAPP_TEST_WORK_DIR'];
    final library = Platform.environment['CHAT_OPENMLS_TEST_LIBRARY'];
    if (work == null ||
        library == null ||
        !path.isAbsolute(work) ||
        !path.isAbsolute(library) ||
        path.normalize(work) != work ||
        path.normalize(library) != library ||
        FileSystemEntity.typeSync(work, followLinks: false) !=
            FileSystemEntityType.directory ||
        Directory(work).resolveSymbolicLinksSync() != work ||
        FileSystemEntity.typeSync(library, followLinks: false) !=
            FileSystemEntityType.file ||
        File(library).resolveSymbolicLinksSync() != library ||
        !path.isWithin(work, library)) {
      throw OpenMlsException(
        OpenMlsErrorCode.libraryUnavailable,
        '测试MLS动态库必须显式属于本轮验证任务',
      );
    }
    return DynamicLibrary.open(library);
  }
  if (!Platform.isAndroid) throw UnsupportedError('聊天生产运行仅支持Android与iOS');
  const library = 'libchat_openmls.so';
  try {
    return DynamicLibrary.open(library);
  } on Object {
    throw OpenMlsException(
      OpenMlsErrorCode.libraryUnavailable,
      '无法加载独立公民聊天动态库',
    );
  }
}

/// OpenMLS FFI 的结构化错误类别。
///
/// 技术信息仅供日志和测试定位；页面必须通过 [userMessage] 展示固定中文文案，禁止把
/// native 路径、Dart `Bad state` 前缀或不可控底层文本直接交给用户。
/// 读 Rust 侧**必填**响应字段;缺字段或空值一律抛错,绝不静默退化成空串。
///
/// FFI 两侧字段名没有编译期约束，任何拼写漂移都会让错误远离根因；因此必须在
/// OpenMLS 边界立即失败，禁止把空串继续传入群状态或 KeyPackage 流程。
///
/// 只用于**恒非空**的字段;可为空的响应字段(如无新会话时的
/// `welcome_wire_message_hex`、Welcome 消息的 `plaintext_hex`)照旧走 `?? ''`。
String _requireField(
  Map<String, dynamic> response,
  String key, {
  OpenMlsOperation operation = OpenMlsOperation.unknown,
}) {
  final value = (response[key] ?? '').toString();
  if (value.isEmpty) {
    throw OpenMlsException(
      OpenMlsErrorCode.invalidResponse,
      'OpenMLS native 响应缺少必填字段 $key;请核对 Rust 侧 FFI 键名',
      operation: operation,
    );
  }
  return value;
}

List<int> _hexToBytes(String value) {
  final normalized = value.startsWith('0x') ? value.substring(2) : value;
  if (normalized.length.isOdd) {
    throw const FormatException('OpenMLS hex 长度必须为偶数');
  }
  if (normalized.isNotEmpty &&
      !RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized)) {
    throw const FormatException('OpenMLS hex 必须合法');
  }
  final bytes = <int>[];
  for (var i = 0; i < normalized.length; i += 2) {
    bytes.add(int.parse(normalized.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

String _bytesToHex(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
