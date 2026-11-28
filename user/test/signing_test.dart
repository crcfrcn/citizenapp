// 验证跨功能签名域、通用SCALE编码及黄金向量。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/sdk.dart';

void main() {
  group('binary_prefix_domain_golden_test', suite111);
  group('scale_codec_golden_test', suite115);
  group('signing_golden_test', suite116);
}

// 原二进制前缀及载荷金标仍逐字节比较；实际编码只调用SDK Core。

const _fixturePath = 'user/test/signing/binary_prefix_domain_vectors.json';

void suite111() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestCitizenSdkHarness();
  final file = File(_fixturePath);
  if (!file.existsSync()) {
    throw StateError('缺少原金标$_fixturePath');
  }

  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final vectors = (root['vectors'] as List).cast<Map<String, dynamic>>();
  final byName = {for (final v in vectors) v['name'] as String: v};

  group('二进制前缀域金标(链端 node ↔ 冷钱包 ↔ citizenapp 逐字节对齐)', () {
    test('fixture 域常量为 GMB,与 Dart kGmbSignDomain 一致', () async {
      expect(root['domain'], 'GMB');
      expect(kGmbSignDomain, equals(const [0x47, 0x4D, 0x42]));
      expect(kBinaryPrefixLen, 4);
    });

    test('binaryDomainPrefix(0x18) == ACTIVATE_ADMIN fixture prefix', () async {
      final v = byName['ACTIVATE_ADMIN']!;
      expect(kOpSignRoleAccess, 0x18);
      expect(
        _hexLower(
          (await CitizenSdk.encodePayload(
            CitizenSigningPayload.binaryPrefix(kOpSignRoleAccess),
          )),
        ),
        (v['prefix_hex'] as String).toLowerCase(),
      );
    });

    test('binaryDomainPrefix(0x19) == DECRYPT fixture prefix', () async {
      final v = byName['DECRYPT']!;
      expect(kOpSignClearingDecrypt, 0x19);
      expect(
        _hexLower(
          (await CitizenSdk.encodePayload(
            CitizenSigningPayload.binaryPrefix(kOpSignClearingDecrypt),
          )),
        ),
        (v['prefix_hex'] as String).toLowerCase(),
      );
    });

    test('ACTIVATE_ADMIN payload 逐字节 == fixture == Rust', () async {
      final v = byName['ACTIVATE_ADMIN']!;
      final inputs = v['sample_inputs'] as Map<String, dynamic>;
      final payload = (await CitizenSdk.encodePayload(
        CitizenSigningPayload.roleAccess(
          cidNumber: inputs['cid_number'] as String,
          institutionCode: _hexToBytes(
            inputs['institution_code_hex'] as String,
          ),
          kind: inputs['kind'] as int,
          signerPublicKey: _hexToBytes(
            inputs['signer_public_key_hex'] as String,
          ),
          timestamp: BigInt.from(inputs['timestamp'] as int),
          nonce: _hexToBytes(inputs['nonce_hex'] as String),
        ),
      ));
      expect(payload.length, v['total_len'] as int);
      expect(_hexLower(payload), (v['payload_hex'] as String).toLowerCase());
    });

    test('DECRYPT challenge 逐字节 == fixture == Rust', () async {
      final v = byName['DECRYPT']!;
      final inputs = v['sample_inputs'] as Map<String, dynamic>;
      final payload = (await CitizenSdk.encodePayload(
        CitizenSigningPayload.clearingDecrypt(
          cidNumber: inputs['cid_number'] as String,
          signerPublicKey: _hexToBytes(
            inputs['signer_public_key_hex'] as String,
          ),
          timestamp: BigInt.from(inputs['timestamp'] as int),
          nonce: _hexToBytes(inputs['nonce_hex'] as String),
        ),
      ));
      expect(payload.length, v['total_len'] as int);
      expect(_hexLower(payload), (v['payload_hex'] as String).toLowerCase());
    });
  });
}

Uint8List _hexToBytes(String hex) {
  final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _hexLower(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

// 通过真实Core核对冻结SCALE字符串和u64边界。

// 保留原SCALE金标输入及边界，公开Dart调用最终由真实SDK Core计算。
// 测试桥只搬运C ABI字节，不恢复App编码器；只读原向量，不修改其所有者。

String _bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void suite115() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestCitizenSdkHarness();
  // 工具根与源码根不同；只读准确主仓金标，不在中央目录复制 Runtime 数据。
  final root = Platform.environment['CITIZENCHAIN_ROOT'];
  if (root == null || !root.startsWith('/')) {
    throw StateError('SCALE 金标检查缺少准确 CITIZENCHAIN_ROOT');
  }
  final file = File(
    '$root/runtime/primitives/tests/fixtures/scale_codec_vectors.json',
  );
  final canonical = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final compactVectors = (canonical['compact_u32'] as List)
      .cast<Map<String, dynamic>>();
  final stringVectors = (canonical['scale_string'] as List)
      .cast<Map<String, dynamic>>();
  final u64Vectors = (canonical['u64_le'] as List).cast<Map<String, dynamic>>();

  group('SCALE 编码原语与链端一致(直读 citizenchain 真源)', () {
    test('真源三组向量均可读且非空', () async {
      // 读成空数组时下面的循环一条用例都不生成而整体显示通过,这条挡住金标静默失效。
      expect(
        file.existsSync(),
        isTrue,
        reason: '真源不可达,cwd=${Directory.current.path}',
      );
      expect(compactVectors, isNotEmpty);
      expect(stringVectors, isNotEmpty);
      expect(u64Vectors, isNotEmpty);
    });

    for (final vector in stringVectors) {
      final value = vector['value'] as String;
      final label = value.length > 24 ? '${value.substring(0, 24)}…' : value;
      test(
        'scaleString(${jsonEncode(label)}) 共 ${vector['utf8_len']} 字节',
        () async {
          expect(
            _bytesToHex(
              (await CitizenSdk.encodePayload(
                CitizenSigningPayload.scaleString(value),
              )),
            ),
            vector['hex'],
          );
        },
      );
    }

    for (final vector in u64Vectors) {
      test('u64Le(${vector['value']})', () async {
        expect(
          _bytesToHex(
            (await CitizenSdk.encodePayload(
              CitizenSigningPayload.u64Le(BigInt.from(vector['value'] as int)),
            )),
          ),
          vector['hex'],
        );
      });
    }
  });

  group('compact 长度前缀覆盖全部三档', () {
    // 通过SDK公开scaleString入口检查真实Core的compact(len) ++ utf8结果，
    // 用长度恰为向量取值的 ASCII 串反推前缀,即可把三档分支(< 2^6 / < 2^14 / < 2^30)
    // 的边界全部锁住。把 `<` 写成 `<=` 会让 63/64、16383/16384 中的一对编错字节数。
    for (final vector in compactVectors) {
      final length = vector['value'] as int;
      final expectedPrefix = vector['hex'] as String;
      // 4 字节档的上界是 2^30-1,构造那么长的字符串不现实;只覆盖可构造的长度。
      if (length > 65535) {
        continue;
      }
      test('长度 $length 的字符串前缀为 $expectedPrefix', () async {
        final encoded = (await CitizenSdk.encodePayload(
          CitizenSigningPayload.scaleString('x' * length),
        ));
        expect(
          _bytesToHex(encoded).substring(0, expectedPrefix.length),
          expectedPrefix,
        );
        // 前缀之后必须是原始字节,长度与前缀声明一致。
        expect(encoded.length, expectedPrefix.length ~/ 2 + length);
      });
    }
  });

  group('SCALE 编码原语的 fail-closed 边界', () {
    // 真源向量只覆盖合法取值。非法输入必须抛错而不是产出错误字节 ——
    // 静默产出会让一笔语义错误的交易被签名。
    test('u64Le 拒绝负数', () async {
      await expectLater(
        CitizenSdk.encodePayload(CitizenSigningPayload.u64Le(BigInt.from(-1))),
        throwsA(
          isA<CitizenSdkException>().having(
            (error) => error.code,
            'code',
            CitizenSdkErrorCode.invalidArgument,
          ),
        ),
      );
    });

    // 本App回归只构造65535字节以内的字符串，不把未执行的1GB边界宣称为通过。
  });
}

// 原签名域金标逐字节比较SDK Core真实结果；不保留App哈希镜像或预填答案。

const _goldenFixturePath = 'user/test/signing/signing_domain_vectors.json';

void suite116() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestCitizenSdkHarness();
  final file = File(_goldenFixturePath);
  if (!file.existsSync()) {
    throw StateError('缺少原金标$_goldenFixturePath');
  }

  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final vectors = (root['vectors'] as List).cast<Map<String, dynamic>>();

  group('签名消息金标向量(链端 primitives::sign ↔ Dart 逐字节对齐)', () {
    test('fixture 域常量为 GMB,与 Dart kGmbSignDomain 一致', () async {
      expect(root['domain'], 'GMB');
      expect(kGmbSignDomain, equals(const [0x47, 0x4D, 0x42]));
    });

    for (final v in vectors) {
      final name = v['name'] as String;
      final opTag = int.parse((v['op_tag'] as String).substring(2), radix: 16);
      final scalePayload = _goldenHexBytes(v['scale_payload_hex'] as String);
      final expectedHex = (v['message_hex'] as String).toLowerCase();

      test(
        '$name (op_tag=0x${opTag.toRadixString(16)}) → $expectedHex',
        () async {
          final actual = (await CitizenSdk.encodePayload(
            CitizenSigningPayload.message(
              opTag: opTag,
              scalePayload: scalePayload,
            ),
          ));
          expect(_goldenHexLower(actual), expectedHex);
        },
      );
    }
  });
}

Uint8List _goldenHexBytes(String hex) {
  final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _goldenHexLower(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
