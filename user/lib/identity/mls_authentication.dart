import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:citizen_network/mls_authentication.dart' as mls;
import 'package:citizen_system/security/system_protected_storage.dart';

typedef MlsAccountBinding = ({String cidNumber, String accountId, int bindRev});

class MlsAuthenticationException implements Exception {
  const MlsAuthenticationException(
    this.message, {
    this.code = 'invalid_mls_proof',
  });
  final String message;
  final String code;
  @override
  String toString() => message;
}

/// 公开身份快照，仅含CID、当前绑定与同一MLS公钥。
class MlsAuthenticationIdentity {
  const MlsAuthenticationIdentity({
    required this.cidNumber,
    required this.accountId,
    required this.bindRev,
    required this.deviceId,
    required this.publicKey,
  });
  final String cidNumber;
  final String accountId;
  final int bindRev;
  final String deviceId;
  final String publicKey;

  String get cacheKey => jsonEncode([cidNumber, accountId, bindRev, deviceId]);
  void validate() {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$').hasMatch(cidNumber) ||
        !isCitizenAccountId(accountId) ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(publicKey) ||
        deviceId != publicKey.substring(2) ||
        bindRev <= 0 ||
        bindRev > mls.MlsAuthenticationRequest.maxJsonInteger) {
      throw const MlsAuthenticationException('MLS公开身份与当前绑定无效');
    }
  }
}

/// 测试只替换这个受限边界；生产没有任意字节签名回调。
abstract interface class MlsAuthenticationSource {
  Future<MlsAuthenticationIdentity> readIdentity();
  Future<void> requireCurrent(MlsAuthenticationIdentity identity);
  Future<mls.MlsAuthenticationProof> createProof({
    required MlsAuthenticationIdentity identity,
    required mls.MlsAuthenticationRequest request,
  });
}

/// 设备认证只使用当前绑定和受保护的签名存储。
class MlsAuthentication implements MlsAuthenticationSource {
  MlsAuthentication({
    required Future<mls.DeviceIdentity> Function() readLocalIdentity,
    required Future<mls.MlsAuthenticationProof> Function(
      mls.MlsAuthenticationRequest request,
    )
    createProof,
    required Future<MlsAccountBinding> Function() currentBinding,
  }) : _readLocalIdentity = readLocalIdentity,
       _createProof = createProof,
       _currentBinding = currentBinding;
  factory MlsAuthentication.native({
    required Future<MlsAccountBinding> Function() currentBinding,
  }) {
    return MlsAuthentication(
      currentBinding: currentBinding,
      readLocalIdentity: () async {
        final binding = await currentBinding();
        final response = await _DeviceStore.call(binding.cidNumber, 'prepare');
        return mls.DeviceIdentity(
          userId: response['user_id'] as String,
          deviceId: response['device_id'] as String,
          publicKey: response['public_key'] as String,
        );
      },
      createProof: (request) async {
        request.validate();
        final binding = await currentBinding();
        final response =
            await _DeviceStore.call(binding.cidNumber, 'sign_authentication', {
              'account_id': binding.accountId,
              'bind_rev': binding.bindRev,
              'request': request.toJson(),
            });
        return mls.MlsAuthenticationProof.fromJson(
          response.cast<String, Object>(),
        );
      },
    );
  }

  final Future<mls.DeviceIdentity> Function() _readLocalIdentity;
  final Future<mls.MlsAuthenticationProof> Function(
    mls.MlsAuthenticationRequest request,
  )
  _createProof;
  final Future<MlsAccountBinding> Function() _currentBinding;
  static bool _deviceAccessBlocked = false;

  /// 全量擦除进程禁止再生成或交付设备认证。
  static void blockDeviceAccess() => _deviceAccessBlocked = true;

  static final _deviceGenerations = <String, int>{};
  static final _retiring = <String>{};

  /// 注销完成后只擦除该 CID 的设备身份，不打开钱包存储。
  static Future<void> eraseDeviceIdentity(String cidNumber) async {
    if (!_retiring.add(cidNumber)) {
      throw StateError('设备身份正在擦除');
    }
    _deviceGenerations.update(
      cidNumber,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    try {
      await SystemProtectedStorage.eraseDeviceStorage(cidNumber: cidNumber);
    } finally {
      _retiring.remove(cidNumber);
    }
  }

  bool _closed = false;

  /// SDK关闭与业务释放之前同步封住新认证和晚返回。
  void close() {
    _closed = true;
  }

  @override
  Future<MlsAuthenticationIdentity> readIdentity() async {
    if (_closed || _deviceAccessBlocked) {
      throw const MlsAuthenticationException(
        'MLS认证已关闭',
        code: 'identityChanged',
      );
    }
    final binding = await _currentBinding();
    // SDK在同一受保护锁内自动准备合法空存储或复用原身份；这里只读取公开结果。
    final local = await _readLocalIdentity();
    final publicKey = local.publicKey;
    if (publicKey == null) throw const MlsAuthenticationException('MLS公开身份缺失');
    final identity = MlsAuthenticationIdentity(
      cidNumber: binding.cidNumber,
      accountId: binding.accountId,
      bindRev: binding.bindRev,
      deviceId: local.deviceId,
      publicKey: publicKey,
    );
    identity.validate();
    if (local.userId != identity.cidNumber) {
      throw const MlsAuthenticationException('MLS身份所有者不一致');
    }
    await requireCurrent(identity);
    return identity;
  }

  @override
  Future<void> requireCurrent(MlsAuthenticationIdentity identity) async {
    identity.validate();
    final binding = await _currentBinding();
    if (_closed ||
        _deviceAccessBlocked ||
        binding.cidNumber != identity.cidNumber ||
        binding.accountId != identity.accountId ||
        binding.bindRev != identity.bindRev) {
      throw const MlsAuthenticationException(
        'MLS认证期间当前用户已变化',
        code: 'identityChanged',
      );
    }
  }

  @override
  Future<mls.MlsAuthenticationProof> createProof({
    required MlsAuthenticationIdentity identity,
    required mls.MlsAuthenticationRequest request,
  }) async {
    identity.validate();
    request.validate();
    await requireCurrent(identity);
    final proof = await _createProof(request);
    await requireCurrent(identity);
    validateMlsProofMatches(identity, request, proof);
    return proof;
  }
}

void validateMlsProofMatches(
  MlsAuthenticationIdentity identity,
  mls.MlsAuthenticationRequest request,
  mls.MlsAuthenticationProof proof,
) {
  identity.validate();
  request.validate();
  // 直接验证SDK原生字段集；宿主不再构造第二份证明或翻译字段名。
  final fields = proof.toJson();
  final expected = <String, Object>{
    'user_id': identity.cidNumber,
    'device_id': identity.deviceId,
    'public_key': identity.publicKey,
    'account_id': identity.accountId,
    'bind_rev': identity.bindRev,
    'service_origin': request.serviceOrigin,
    'token_purpose': request.tokenPurpose,
    if (request.sessionHash != null) 'session_hash': request.sessionHash!,
    'nonce_id': request.nonceId,
    'expires_at': request.expiresAt,
    'http_method': request.httpMethod,
    'request_target': request.requestTarget,
    'body_hash': '0x${sha256.convert(request.bodyBytes)}',
  };
  final signature = fields['signature'];
  if (fields.length != expected.length + 1 ||
      signature is! String ||
      !RegExp(r'^0x[0-9a-f]{128}$').hasMatch(signature) ||
      !expected.entries.every((entry) => fields[entry.key] == entry.value)) {
    throw const MlsAuthenticationException('MLS证明与准确请求不一致');
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

final class _DeviceStore {
  _DeviceStore(DynamicLibrary library)
    : _identity = library.lookupFunction<MlsJsonNative, MlsJsonDart>(
        'mls_identity_json',
      ),
      _freeString = library
          .lookupFunction<MlsFreeStringNative, MlsFreeStringDart>(
            'mls_free_string',
          );

  static const _channel = MethodChannel('citizenapp/system_protected_data');
  static final _DeviceStore _native = _DeviceStore(_loadMlsLibrary());

  final MlsJsonDart _identity;
  final MlsFreeStringDart _freeString;

  static Future<Map<String, dynamic>> call(
    String owner,
    String action, [
    Map<String, Object?> fields = const {},
  ]) async {
    final generation = MlsAuthentication._deviceGenerations[owner];
    if (MlsAuthentication._deviceAccessBlocked ||
        MlsAuthentication._retiring.contains(owner)) {
      throw const MlsAuthenticationException('设备签名已停止');
    }
    final storage = await _channel.invokeMethod<String>(
      'prepareDeviceStorage',
      {'user_id': owner},
    );
    if (storage == null || !path.isAbsolute(storage)) {
      throw const MlsAuthenticationException('设备签名存储不可用');
    }
    if (MlsAuthentication._deviceAccessBlocked ||
        MlsAuthentication._retiring.contains(owner) ||
        MlsAuthentication._deviceGenerations[owner] != generation) {
      throw const MlsAuthenticationException('设备签名已停止');
    }
    return _native.callJson({
      'state_store_dir': storage,
      'user_id': owner,
      'action': action,
      ...fields,
    });
  }

  Map<String, dynamic> callJson(Map<String, Object?> request) {
    const operation = mls.MlsOperation.identity;
    final requestPtr = jsonEncode(request).toNativeUtf8();
    final errorOut = calloc<Pointer<Utf8>>();
    Pointer<Utf8> resultPtr = nullptr;
    try {
      resultPtr = _identity(requestPtr, errorOut);
      if (resultPtr == nullptr) {
        final errorPtr = errorOut.value;
        final message = errorPtr == nullptr
            ? 'OpenMLS native 调用失败'
            : errorPtr.toDartString();
        if (errorPtr != nullptr) {
          _freeString(errorPtr);
        }
        throw mls.MlsException.fromTechnicalMessage(
          message,
          operation: operation,
        );
      }
      try {
        final json = jsonDecode(resultPtr.toDartString());
        if (json is! Map<String, dynamic>) throw const FormatException();
        return json;
      } on FormatException {
        throw mls.MlsException(
          mls.MlsErrorCode.invalidResponse,
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
}

DynamicLibrary _loadMlsLibrary() {
  // iOS由App直接嵌入MLS.framework，Dart读取同一进程的C接口。
  // 原生设备签名随 App 交付。
  if (Platform.isIOS) return DynamicLibrary.process();
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    final work = Platform.environment['CITIZENAPP_TEST_WORK_DIR'];
    final library = Platform.environment['MLS_TEST_LIBRARY'];
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
      throw mls.MlsException(
        mls.MlsErrorCode.libraryUnavailable,
        '测试MLS动态库必须显式属于本轮验证任务',
      );
    }
    return DynamicLibrary.open(library);
  }
  if (!Platform.isAndroid) throw UnsupportedError('设备签名仅支持Android与iOS');
  const library = 'libmls.so';
  try {
    return DynamicLibrary.open(library);
  } on Object {
    throw mls.MlsException(
      mls.MlsErrorCode.libraryUnavailable,
      '无法加载公民设备签名动态库',
    );
  }
}
