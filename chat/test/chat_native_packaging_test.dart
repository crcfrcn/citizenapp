import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('普通本地chat包的真实包图不包含独立聊天插件或内部SDK包', () {
    final config =
        jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
            as Map<String, dynamic>;
    final packages = config['packages'] as List;
    expect(
      packages.where((entry) => (entry as Map)['name'] == 'chat'),
      hasLength(1),
    );
    expect(
      packages.where(
        (entry) => (entry as Map)['name'].toString().startsWith('tatachat_'),
      ),
      isEmpty,
    );
    final plugins =
        jsonDecode(File('.flutter-plugins-dependencies').readAsStringSync())
            as Map<String, dynamic>;
    final entries = (plugins['plugins'] as Map).values.expand(
      (value) => value as List,
    );
    expect(entries.where((entry) => (entry as Map)['name'] == 'chat'), isEmpty);
  });

  test('本轮移动端OpenMLS产物是真实ARM64库，完整导出唯一C接口', () async {
    final root = Platform.environment['CHAT_OPENMLS_COMPONENT_DIR'];
    final target = Platform.environment['PLATFORM'];
    expect(root, isNotNull, reason: '由App构建入口交付本轮组件目录');
    expect(['ios', 'android'], contains(target));
    final relative = target == 'ios'
        ? 'aarch64-apple-ios/ChatOpenMLS.framework/ChatOpenMLS'
        : 'android/arm64-v8a/libchat_openmls.so';
    final file = File('$root/$relative');
    final bytes = await file.readAsBytes();
    final header = ByteData.sublistView(bytes);
    if (target == 'ios') {
      expect(header.getUint32(0, Endian.little), 0xfeedfacf);
      expect(header.getUint32(4, Endian.little), 0x0100000c);
    } else {
      expect(bytes.take(5), [0x7f, 0x45, 0x4c, 0x46, 2]);
      expect(header.getUint16(18, Endian.little), 183);
    }
    final declaration = File('chat/openmls/chat.h').readAsStringSync();
    final names = RegExp(
      r'\b(chat_openmls_[a-z_]+)\s*\(',
    ).allMatches(declaration).map((match) => match.group(1)!).toSet();
    expect(names, hasLength(10));
    final sdk = Platform.environment['ANDROID_HOME'];
    final tool = target == 'ios'
        ? '/usr/bin/nm'
        : '$sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/${Platform.isMacOS ? 'darwin-x86_64' : 'linux-x86_64'}/bin/llvm-nm';
    final symbols = await Process.run(
      tool,
      target == 'android'
          ? ['-D', '--defined-only', file.path]
          : ['-g', file.path],
    );
    expect(symbols.exitCode, 0, reason: symbols.stderr.toString());
    for (final name in names) {
      expect(
        RegExp(
          '(?:^|\\s)_?$name(?:\\s|\$)',
          multiLine: true,
        ).hasMatch(symbols.stdout.toString()),
        isTrue,
        reason: name,
      );
    }
  });
}
