import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import {
  existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync,
  writeFileSync,
} from 'node:fs';
import { testRoot as tmpdir, BUILD_SHELL_SOURCES, SOURCE_VIEW_SOURCE } from '../scripts/build.mjs';
import { join } from 'node:path';
import { after, test } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';

const settings = readFileSync(new URL('../android/settings.gradle.kts', import.meta.url), 'utf8');
const root = readFileSync(new URL('../android/build.gradle.kts', import.meta.url), 'utf8');
const application = readFileSync(new URL('../android/app/build.gradle.kts', import.meta.url), 'utf8');
const properties = readFileSync(new URL('../android/gradle.properties', import.meta.url), 'utf8');
const wrapper = readFileSync(new URL('../android/gradle-wrapper.properties', import.meta.url), 'utf8');
const runner = BUILD_SHELL_SOURCES.run;
const iosUITestRunner = BUILD_SHELL_SOURCES['ui-test'];
const iosUITests = readFileSync(new URL('../ios/tests/RunnerUITests.swift', import.meta.url), 'utf8');
const viewScript = fileURLToPath(new URL('../scripts/build.mjs', import.meta.url));
const view = SOURCE_VIEW_SOURCE;
const podfile = readFileSync(new URL('../ios/Podfile', import.meta.url), 'utf8');
const testRunner = BUILD_SHELL_SOURCES.test;
const pubspec = readFileSync(new URL('../pubspec.yaml', import.meta.url), 'utf8');
const pubLock = readFileSync(new URL('../pubspec.lock', import.meta.url), 'utf8');
const podLock = readFileSync(new URL('../ios/Podfile.lock', import.meta.url), 'utf8');
// 跨SDK验收读取原始声明锁定的实际Git输入，产品独立检出也能执行，不依赖邻仓布局。
// 本轮调用方可交付已验真的固定Git输入；仍由原resolver回读，不借用邻仓或改写来源。
const suppliedDependencyWork = process.env.CITIZENAPP_TEST_WORK_DIR;
const dependencyWork = suppliedDependencyWork
  ? realpathSync(suppliedDependencyWork)
  : realpathSync(mkdtempSync(join(tmpdir(), 'citizenapp-release-inputs-')));
after(() => { if (!suppliedDependencyWork) rmSync(dependencyWork, { recursive: true, force: true }); });
const sourceRoot = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/u, '');
let dependencySources;
try {
  dependencySources = JSON.parse(execFileSync(process.execPath, [viewScript, 'view', 'dependencies',
    '--source-root', sourceRoot, '--work-root', dependencyWork], { encoding: 'utf8' }));
} catch (error) {
  if (!suppliedDependencyWork) rmSync(dependencyWork, { recursive: true, force: true });
  throw error;
}
const tataChatRoot = pathToFileURL(dependencySources.tatachat_sdk.root + '/');
const tataChatPubspec = readFileSync(new URL('pubspec.yaml', tataChatRoot), 'utf8');
const tataChatPubLock = readFileSync(new URL('pubspec.lock', tataChatRoot), 'utf8');
const tataChatAndroid = readFileSync(new URL('android/build.gradle.kts', tataChatRoot), 'utf8');
const tataChatAndroidPlugin = readFileSync(
  new URL('android/TataChatSdkPlugin.java', tataChatRoot), 'utf8');
const tataChatIOSPlugin = readFileSync(new URL('ios/TataChatSdkPlugin.swift', tataChatRoot), 'utf8');
const tataChatProbe = readFileSync(new URL('lib/attachment/probe.dart', tataChatRoot), 'utf8');
const tataChatAttachmentPlatform = readFileSync(
  new URL('lib/attachment/attachment_platform.dart', tataChatRoot), 'utf8');
const tataChatConversation = readFileSync(
  new URL('lib/ui/conversation/conversation_page.dart', tataChatRoot), 'utf8');

// 执行真实脚本片段，检查注释幂等、正文保留和任一输入异常时零写入。
test('CitizenApp Isar 注释规范化保留正文且重复执行一致', () => {
  const code = runner.match(/<<'NORMALIZE_ISAR_COMMENTS'\n([\s\S]*?)\nNORMALIZE_ISAR_COMMENTS/u)?.[1];
  assert.ok(code);
  const fixture = mkdtempSync(join(tmpdir(), 'citizenapp-isar-'));
  const directory = join(fixture, 'lib/storage');
  mkdirSync(directory, { recursive: true });
  const names = ['user_isar', 'wallet_isar'];
  const originals = names.map(name => `// GENERATED CODE - DO NOT MODIFY BY HAND\n\npart of '${name}.dart';\n\nconst sentinel = 1;\n`);
  const run = () => spawnSync(process.execPath, ['-', fixture], { input: code, encoding: 'utf8' });
  try {
    names.forEach((name, index) => writeFileSync(join(directory, `${name}.g.dart`), originals[index]));
    const other = join(directory, 'unrelated.g.dart');
    writeFileSync(other, '保持原样');
    assert.equal(run().status, 0);
    const first = names.map(name => readFileSync(join(directory, `${name}.g.dart`), 'utf8'));
    first.forEach((value, index) => {
      assert.match(value.split('\n')[1], /^\/\/ 由 .*生成/u);
      assert.equal(value.replace(/^\/\/ 由 .*\n/mu, ''), originals[index]);
    });
    assert.equal(run().status, 0);
    names.forEach((name, index) => assert.equal(readFileSync(join(directory, `${name}.g.dart`), 'utf8'), first[index]));
    assert.equal(readFileSync(other, 'utf8'), '保持原样');
    for (const invalid of ['无效生成头', originals[1].replace('wallet_isar.dart', 'other.dart')]) {
      writeFileSync(join(directory, 'user_isar.g.dart'), originals[0]);
      writeFileSync(join(directory, 'wallet_isar.g.dart'), invalid);
      assert.notEqual(run().status, 0);
      assert.equal(readFileSync(join(directory, 'user_isar.g.dart'), 'utf8'), originals[0]);
      assert.equal(readFileSync(join(directory, 'wallet_isar.g.dart'), 'utf8'), invalid);
    }
    rmSync(join(directory, 'wallet_isar.g.dart'));
    assert.notEqual(run().status, 0);
    symlinkSync(other, join(directory, 'wallet_isar.g.dart'));
    assert.notEqual(run().status, 0);
    assert.equal(readFileSync(other, 'utf8'), '保持原样');
    assert.equal(readFileSync(join(directory, 'user_isar.g.dart'), 'utf8'), originals[0]);
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
});

// 使用完整合并入口与真实迁移后的文件位置，避免旧目录夹具掩盖入口失效。
test('CitizenApp Isar 注释入口消费当前 storage 目录并拒绝旧目录', () => {
  const fixture = mkdtempSync(join(tmpdir(), 'citizenapp-storage-entry-'));
  const scripts = join(fixture, 'scripts');
  const directory = join(fixture, 'lib/storage');
  mkdirSync(scripts, { recursive: true });
  mkdirSync(directory, { recursive: true });
  writeFileSync(join(scripts, 'build.mjs'), readFileSync(viewScript));
  for(const name of ['target.mjs'])writeFileSync(join(scripts,name),readFileSync(new URL('../scripts/'+name,import.meta.url)));
  writeFileSync(join(scripts, 'flows.json'), readFileSync(new URL('../scripts/flows.json', import.meta.url)));
  const names = ['user_isar', 'wallet_isar'];
  const originals = names.map(name => readFileSync(new URL(`../lib/storage/${name}.g.dart`, import.meta.url), 'utf8'));
  const run = () => spawnSync(process.execPath, [join(scripts, 'build.mjs'), 'run', 'normalize-isar-comments'], {
    cwd: fixture, encoding: 'utf8', env: { ...process.env, NODE_TEST_CONTEXT: '' },
  });
  try {
    names.forEach((name, index) => writeFileSync(join(directory, `${name}.g.dart`), originals[index]));
    const result = run();
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stderr, /生成正文保持不变/u);
    const normalized = names.map((name, index) => {
      const value = readFileSync(join(directory, `${name}.g.dart`), 'utf8');
      assert.match(value.split('\n')[1], /^\/\/ 由 .*生成/u);
      assert.equal(value.replace(/^\/\/ 由 .*\n/mu, ''), originals[index].replace(/^\/\/ 由 .*\n/mu, ''));
      return value;
    });
    assert.equal(run().status, 0);
    names.forEach((name, index) => assert.equal(readFileSync(join(directory, `${name}.g.dart`), 'utf8'), normalized[index]));
    // 只有旧位置时必须失败，不能悄悄跳过或恢复旧目录兼容。
    const legacy = join(fixture, 'lib/isar');
    mkdirSync(legacy);
    names.forEach((name, index) => writeFileSync(join(legacy, `${name}.g.dart`), originals[index]));
    rmSync(directory, { recursive: true });
    assert.notEqual(run().status, 0);
    names.forEach((name, index) => assert.equal(readFileSync(join(legacy, `${name}.g.dart`), 'utf8'), originals[index]));
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
});

test('CitizenApp locks the shared Dart protocol generator exactly', () => {
  assert.match(pubspec, /^  protoc_plugin: 25[.]0[.]0$/mu);
  assert.doesNotMatch(pubspec, /^  protoc_plugin: [\^~><=]/mu);
});

// 只约束CitizenApp自己的扫码所有权；SDK原生功能由SDK测试与真实验收覆盖。
test('CitizenApp二维码非UI能力只由SDK提供', () => {
  assert.match(pubspec, /^  citizen_sdk:/mu);
  for (const source of [pubspec, pubLock]) {
    assert.doesNotMatch(source, /^  (?:qr|qr_flutter|mobile_scanner):/mu);
  }
  assert.doesNotMatch(podLock, /mobile_scanner/u);
  const preview = readFileSync(new URL('../lib/scanner/scanner_view.dart', import.meta.url), 'utf8');
  const display = readFileSync(new URL('../lib/scanner/qr_display_scaffold.dart', import.meta.url), 'utf8');
  assert.match(preview, /qr[.]openCapture\(purpose\)/u);
  assert.match(preview, /Texture\(textureId: capture[.]textureId\)/u);
  assert.match(display, /qr[.]encode\(widget[.]data, scale: 1\)/u);
  for (const path of [
    'lib/scanner/envelope.dart', 'lib/scanner/qr_protocols.dart',
    'lib/scanner/generated/qr_action_registry.g.dart', 'lib/scanner/generated/qr_bodies.g.dart',
    'lib/scanner/scanner/scanner_controller.dart', 'lib/scanner/scanner/scanner_backend.dart',
    'lib/scanner/scanner/mobile_scanner_backend.dart',
    'lib/signing/app_business_qr_codec.dart', 'lib/signing/signing.dart',
  ]) {
    assert.equal(existsSync(new URL('../' + path, import.meta.url)), false, path + '必须移除');
  }
});

test('CitizenApp与TataChatSDK只装配AGP9内置Kotlin兼容的移动插件闭包', () => {
  assert.match(pubspec, /^  saver_gallery: 5[.]1[.]0$/mu);
  assert.doesNotMatch(pubspec, /^  (?:file_picker|video_compress):/mu);
  assert.match(tataChatPubspec, /^  emoji_picker_flutter: 4[.]5[.]4$/mu);
  assert.match(tataChatPubspec, /^  saver_gallery: 5[.]1[.]0$/mu);
  assert.doesNotMatch(tataChatPubspec, /^  (?:file_picker|video_compress):/mu);
  assert.doesNotMatch(tataChatProbe, /package:video_compress|VideoCompress/u);

  for (const [name, version] of [
    ['emoji_picker_flutter', '4.5.4'],
    ['flutter_image_compress_common', '1.1.1'],
    ['quill_native_bridge', '11.2.0'],
    ['quill_native_bridge_android', '0.0.2'],
    ['saver_gallery', '5.1.0'],
    ['shared_preferences_android', '2.4.28'],
  ]) {
    assert.match(pubLock, new RegExp(`^  ${name}:\\n(?:    .*\\n)+?    version: "${version.replaceAll('.', '[.]')}"$`, 'mu'));
  }
  for (const source of [pubLock, tataChatPubLock]) {
    assert.doesNotMatch(source, /^  (?:android_file_picker|file_picker|file_picker_darwin|file_picker_linux|file_picker_platform_interface|file_picker_web|video_compress|windows_file_picker):/mu);
  }
  assert.doesNotMatch(podLock, /(?:^|\n)  - file_picker_darwin\b|file_picker_darwin:/u);

  assert.match(tataChatAndroid, /id\("com[.]android[.]library"\)/u);
  assert.doesNotMatch(tataChatAndroid, /kotlin-android|org[.]jetbrains[.]kotlin[.]android/u);
  assert.match(tataChatAndroidPlugin, /MediaMetadataRetriever/u);
  assert.match(tataChatAndroidPlugin, /getScaledFrameAtTime/u);
  assert.match(tataChatAndroidPlugin, /Build[.]VERSION[.]SDK_INT < Build[.]VERSION_CODES[.]O_MR1/u);
  assert.match(tataChatAndroidPlugin, /implements FlutterPlugin, ActivityAware/u);
  assert.match(tataChatAndroidPlugin, /Intent[.]ACTION_OPEN_DOCUMENT/u);
  assert.match(tataChatAndroidPlugin, /MAX_SELECTED_BYTES = 512L \* 1024L \* 1024L/u);
  assert.match(tataChatIOSPlugin, /AVAssetImageGenerator/u);
  assert.match(tataChatIOSPlugin, /maximumSize = CGSize\(width: 64, height: 64\)/u);
  assert.match(tataChatIOSPlugin, /UIDocumentPickerViewController/u);
  assert.match(tataChatAttachmentPlatform, /chat[.]tata[.]sdk\/attachment/u);
  assert.match(tataChatConversation, /ChatAttachmentPlatform\(\)[.]pickFile\(\)/u);
  assert.match(tataChatConversation, /finally \{[\s\S]*temporary[.]delete\(\)/u);
  assert.doesNotMatch(tataChatConversation, /FilePicker|package:file_picker/u);
  assert.doesNotMatch(`${tataChatAttachmentPlatform}\n${tataChatAndroidPlugin}\n${tataChatIOSPlugin}`, /media_probe/u);
});

test('Android从真实产品源码根启动Gradle并把可写状态放入外部工作目录', () => {
  assert.match(settings, /System\.getenv\("CITIZENAPP_PROJECT_ROOT"\)/u);
  assert.match(settings, /settingsDir\.parentFile/u);
  assert.match(settings, /resolve\("android\/local\.properties"\)/u);
  assert.match(settings, /\.flutter-plugins-dependencies/u);
  assert.doesNotMatch(settings, /dev\.flutter\.flutter-plugin-loader|System\.getProperty\("user\.dir"\)/u);
  assert.doesNotMatch(settings, /id\("com\.android\.(?:application|library)"\)\s+version/u);
  assert.match(root, /classpath\("com\.android\.tools\.build:gradle:9\.0\.1"\)/u);
  assert.match(root, /classpath\("org\.jetbrains\.kotlin:kotlin-gradle-plugin:2\.2\.20"\)/u);
  assert.doesNotMatch(root, /com\.android\.tools\.build:gradle:8\./u);
  assert.match(root, /System\.getenv\("CITIZENAPP_BUILD_DIR"\)/u);
  assert.match(root, /System\.getProperty\("java\.io\.tmpdir"\)/u);
  assert.match(application, /import java\.util\.Properties/u);
  assert.doesNotMatch(application, /java\.util\.Properties\(\)/u);
  assert.match(application, /compileSdk = 36/u);
  assert.match(application, /ndkVersion = "28\.2\.13676358"/u);
  assert.match(application, /minSdk = 24/u);
  assert.match(application, /targetSdk = 36/u);
  assert.doesNotMatch(application, /(?:compileSdk|ndkVersion|minSdk|targetSdk)\s*=.*\bflutter\./u);
  assert.deepEqual(properties.split('\n').filter((line) => /^android\.(?:builtInKotlin|newDsl)=/u.test(line)), [
    'android.builtInKotlin=true', 'android.newDsl=true',
  ]);
  const pluginBlock = application.slice(application.indexOf('plugins {'), application.indexOf('\n}'));
  assert.ok(pluginBlock.indexOf('id("com.android.application")')
    < pluginBlock.indexOf('id("dev.flutter.flutter-gradle-plugin")'));
  assert.doesNotMatch(pluginBlock, /org\.jetbrains\.kotlin\.android|kotlin-android/u);
  assert.match(application, /kotlin \{[\s\S]*compilerOptions[\s\S]*JvmTarget\.JVM_17/u);
  assert.match(wrapper, /distributionUrl=https\\:\/\/services\.gradle\.org\/distributions\/gradle-9\.1\.0-bin\.zip/u);
  assert.match(wrapper, /distributionSha256Sum=a17ddd85a26b6a7f5ddb71ff8b05fc5104c0202c6e64782429790c933686c806/u);
  assert.doesNotMatch(wrapper, /gradle-8\./u);
  assert.match(application, /System\.getenv\("CITIZENAPP_PROJECT_ROOT"\) \?: "\.\.\/\.\."/u);
  assert.match(runner, /cd "\$APP_ROOT\/android"/u);
  assert.match(runner, /--no-problems-report/u);
  assert.match(runner, /--init-script "\$CITIZENAPP_GRADLE_INIT_SCRIPT"/u);
  assert.match(runner, /retain_android_local_artifact\(\)/u);
  assert.match(runner, /android[.]apk[.]pending/u);
  assert.match(runner, /destination="\$ARTIFACT_ROOT\/android[.]apk"/u);
  assert.match(runner, /retain_android_local_artifact "\$ANDROID_APK"/u);
  assert.match(runner, /gradle\.beforeSettings \{ settings ->/u);
  assert.match(runner, /settings\.settingsDir\.canonicalPath == new File\(source\)\.canonicalPath/u);
  const includedBuildRepositories = runner.slice(
    runner.indexOf('settings.pluginManagement.repositories'),
    runner.indexOf("'gradle.beforeProject"),
  );
  assert.ok(includedBuildRepositories.indexOf('mavenCentral()')
    < includedBuildRepositories.indexOf('google()'));
  assert.ok(includedBuildRepositories.indexOf('google()')
    < includedBuildRepositories.indexOf('gradlePluginPortal()'));
  assert.doesNotMatch(includedBuildRepositories, new RegExp(['resolutionStrategy', 'force\\(', 'PUB_CACHE', ['TATA', '_CONSOLE'].join('')].join('|'), 'u'));
  assert.match(runner, /CITIZENAPP_FLUTTER_GRADLE_ROOT="\$flutter_sdk\/packages\/flutter_tools\/gradle"/u);
  assert.match(runner, /flutter_sdk="\$\{FLUTTER_ROOT:-\}"/u);
  assert.match(runner, /CitizenApp Flutter SDK根目录无效/u);
  assert.match(runner, /java_home="\$ANDROID_JAVA_HOME"/u);
  assert.match(runner, /ANDROID_JAVA_HOME="\$\{JAVA_HOME:-\/Applications\/Android Studio\.app\/Contents\/jbr\/Contents\/Home\}"/u);
  assert.match(runner, /ANDROID_SDK_HOME="\$\{ANDROID_HOME:-\$\{ANDROID_SDK_ROOT:-\$HOME\/Library\/Android\/sdk\}\}"/u);
  assert.match(runner, /ANDROID_HOME与ANDROID_SDK_ROOT必须一致/u);
  assert.match(runner, /ANDROID_SDK_HOME\/ndk\/28\.2\.13676358/u);
  assert.match(runner, /-x "\$ANDROID_JAVA_HOME\/bin\/java"/u);
  assert.match(runner, /ANDROID_HOME="\$android_sdk" ANDROID_SDK_ROOT="\$android_sdk" JAVA_HOME="\$java_home" PATH="\$java_home\/bin:\$PATH"/u);
  assert.match(runner, /GRADLE_EXECUTABLE="\$\{CITIZENAPP_GRADLE:-\$CITIZENAPP_PROJECT_ROOT\/android\/gradlew\}"/u);
  assert.match(runner, /Gradle执行器必须是绝对普通可执行文件/u);
  assert.match(runner, /"\$GRADLE_EXECUTABLE"[\s\S]*--project-cache-dir "\$BUILD_WORK_DIR\/gradle-project"/u);
  assert.match(runner, /-Pkotlin[.]project[.]persistent[.]dir="\$CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR\/kotlin-project"/u);
  assert.match(runner, /-Pflutter[.]sdk="\$flutter_sdk"/u);
  assert.match(runner, /CITIZENSDK_GRADLE="\$GRADLE_EXECUTABLE"[\s\S]*build-native\.sh" android/u);
  assert.match(runner, /CITIZENSDK_GRADLE="\$GRADLE_EXECUTABLE"[\s\S]*JAVA_HOME="\$ANDROID_JAVA_HOME" PATH="\$ANDROID_JAVA_HOME\/bin:\$PATH"/u);
  assert.doesNotMatch(runner, new RegExp([['TATA', '_CONSOLE'].join(''), ['tata', 'console'].join('')].join('|'), 'u'));
  assert.match(runner, /CITIZENAPP_GRADLE_OFFLINE="\$\{CITIZENAPP_GRADLE_OFFLINE:-\$\{CITIZENAPP_OFFLINE:-false\}\}"/u);
  assert.match(runner, /gradle_network_arg=''/u);
  assert.match(runner, /true\) gradle_network_arg='--offline'/u);
  assert.match(runner, /\$\{gradle_network_arg:\+"\$gradle_network_arg"\}/u);
  assert.doesNotMatch(runner, /GRADLE_NETWORK_ARGS/u);
  assert.match(runner, /CITIZENSDK_OFFLINE="\$CITIZENAPP_GRADLE_OFFLINE"/u);
  assert.match(runner, /ANDROID_HOME="\$ANDROID_SDK_HOME" ANDROID_SDK_ROOT="\$ANDROID_SDK_HOME"[\s\S]*build-native\.sh" android/u);
});

test('iOS Pod装配保留调用方工程路径且不把生成状态写回源码', () => {
  assert.match(podfile, /flutter_install_all_ios_pods File\.dirname\(File\.expand_path\(__FILE__\)\)/u);
  assert.doesNotMatch(podfile, /flutter_install_all_ios_pods File\.dirname\(File\.realpath\(__FILE__\)\)/u);
});

// 执行真实入口的工具检查段，验证平台隔离及 Android 执行器边界。
test('CitizenApp iOS不依赖Gradle且Android拒绝缺失或链接执行器', () => {
  const begin = runner.indexOf('  export GRADLE_USER_HOME=');
  const end = runner.indexOf('  export CP_HOME_DIR=', begin);
  assert.ok(begin >= 0 && end > begin);
  const code = runner.slice(begin, end);
  const work = realpathSync(mkdtempSync(join(tmpdir(), 'citizenapp-gradle-')));
  try {
    const executable = join(work, 'gradle');
    const linked = join(work, 'linked-gradle');
    writeFileSync(executable, '#!/bin/sh\nexit 0\n', { mode: 0o755 });
    symlinkSync(executable, linked);
    const run = (platform, gradle = '') => spawnSync('bash', ['-euc', code], {
      env: { ...process.env, PLATFORM: platform, CITIZENAPP_GRADLE: gradle,
        CITIZENAPP_PROJECT_ROOT: work, DEPENDENCY_WORK_DIR: work },
      encoding: 'utf8',
    });
    assert.equal(run('ios').status, 0);
    assert.equal(run('ios', linked).status, 0);
    for (const invalid of ['', 'relative-gradle', work, linked]) {
      const rejected = run('android', invalid);
      assert.notEqual(rejected.status, 0);
      assert.match(rejected.stderr, /Gradle执行器必须是绝对普通可执行文件/u);
    }
    assert.equal(run('android', executable).status, 0);
  } finally { rmSync(work, { recursive: true }); }
});

test('CitizenApp直接开发自建源码外视图并只投影当轮Framework', async () => {
  const fixture = realpathSync(mkdtempSync(join(tmpdir(), 'citizenapp-view-test-')));
  try {
    const workspace = join(fixture, 'workspace');
    const app = join(workspace, 'citizenapp');
    // 合成产品的消费工作根同归自身target，保持正式越界拒绝。
    const work = join(app, 'target/ios/test/work');
    const sdk = join(work, 'git-sources/citizen_sdk');
    const chat = join(work, 'git-sources/tatachat_sdk');
    const formalChatSource = join(workspace, 'packages', 'tatachatsdk');
    const formalChat = join(workspace, 'FORMAL', 'tatachatsdk');
    for (const directory of [join(app, 'lib'), join(app, '.dart_tool'), join(app, 'android'),
      formalChatSource, join(workspace, 'FORMAL'), join(work, 'git-sources')]) {
      mkdirSync(directory, { recursive: true });
    }
    symlinkSync(formalChatSource, formalChat, 'dir');
    const sdkManifest = [], sdkLock = ['packages:'];
    // 夹具保留真正固定提交、HTTPS origin及detached源码，视图/Framework仍按真实入口执行。
    for (const name of ['citizen_sdk', 'tatachat_sdk']) {
      const provider = dependencySources[name], destination = name === 'citizen_sdk' ? sdk : chat;
      const git = args => execFileSync('git', ['-c', 'core.hooksPath=/dev/null', ...args],
        { encoding: 'utf8', env: { ...process.env, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null' } }).trim();
      git(['-c', 'protocol.file.allow=always', 'clone', '--quiet', '--shared', '--no-checkout', '--', provider.root, destination]);
      git(['-C', destination, 'remote', 'set-url', 'origin', provider.url]);
      git(['-C', destination, 'checkout', '--quiet', '--detach', provider.sha]);
      sdkManifest.push('  '+name+':', '    git:', '      url: '+provider.url, '      ref: '+provider.sha, '      path: .');
      sdkLock.push('  '+name+':', '    dependency: "direct main"', '    description:', '      url: "'+provider.url+'"',
        '      ref: "'+provider.sha+'"', '      resolved-ref: "'+provider.sha+'"', '      path: "."',
        '    source: git', '    version: "1.0.0"');
    }
    writeFileSync(join(app, 'pubspec.yaml'), [
      'name: app', 'dependencies:', ...sdkManifest,
      '  formal_chat_sdk:', '    path: ../FORMAL/tatachatsdk', '',
    ].join('\n'));
    writeFileSync(join(app, 'pubspec.lock'), sdkLock.join('\n')+'\n');
    mkdirSync(join(app, 'ios/project'), {recursive:true});
    for (const scheme of ['Runner', 'RunnerUITests']) {
      writeFileSync(join(app, 'ios/project', `${scheme}.xcscheme`), `<Scheme name="${scheme}"/>`);
    }
    writeFileSync(join(app, 'android/gradle-wrapper.properties'), 'distributionUrl=https://example.invalid/gradle.zip\n');
    writeFileSync(join(app, 'lib/main.dart'), 'void main() {}\n');
    writeFileSync(join(app, '.dart_tool/forbidden'), 'generated\n');
    writeFileSync(join(app, 'android/settings.gradle'), 'generated by caller\n');
    writeFileSync(join(formalChatSource, 'pubspec.yaml'), 'name: formal_chat_sdk\n');
    const project = execFileSync(process.execPath, [viewScript, 'view', 'create',
      '--source-root', app, '--work-root', work], { encoding: 'utf8' }).trim();
    assert.equal(project, join(work, 'source-view', app.replace(/^\/+/, '')));
    assert.equal(lstatSync(join(project, 'lib/main.dart')).isSymbolicLink(), false);
    assert.deepEqual(readFileSync(join(project, 'lib/main.dart')), readFileSync(join(app, 'lib/main.dart')));
    for (const scheme of ['Runner', 'RunnerUITests']) {
      const copy = join(project, `ios/Runner.xcodeproj/xcshareddata/xcschemes/${scheme}.xcscheme`);
      assert.equal(lstatSync(copy).isSymbolicLink(), false);
      assert.equal(lstatSync(copy).nlink, 1);
      assert.deepEqual(readFileSync(copy), readFileSync(join(app, `ios/project/${scheme}.xcscheme`)));
    }
    // 普通本机工程不消费 Wrapper；只有 create-android 从 Flutter 工具原件装配。
    for (const name of ['gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar']) {
      assert.equal(existsSync(join(project, 'android', name)), false);
    }
    const wrapperCopy = join(project, 'android/gradle/wrapper/gradle-wrapper.properties');
    assert.equal(lstatSync(wrapperCopy).isSymbolicLink(), false);
    assert.deepEqual(readFileSync(wrapperCopy), readFileSync(join(app, 'android/gradle-wrapper.properties')));

    const sdkView = join(work, 'source-view', sdk.replace(/^\/+/, ''));
    const chatView = join(work, 'source-view', chat.replace(/^\/+/, ''));
    const sdkApi = await import(pathToFileURL(join(sdk, 'scripts/release.mjs')).href);
    const chatApi = await import(pathToFileURL(join(chat, 'scripts/release.mjs')).href);
    sdkApi.assertFlutterSourceView(sdk, sdkView);
    await chatApi.assertFlutterSourceView(chat, chatView);
    assert.equal(execFileSync('git', ['-C', sdk, 'status', '--porcelain'], { encoding: 'utf8' }), '');
    assert.equal(execFileSync('git', ['-C', chat, 'status', '--porcelain'], { encoding: 'utf8' }), '');
    const formalManifest = join(work, 'source-view', formalChatSource.replace(/^\/+/, ''),
      'pubspec.yaml');
    // 只投影已登记的固定 Git 产品输入，未知 FORMAL path 不能进入本轮视图。
    assert.equal(lstatSync(formalManifest, { throwIfNoEntry: false }), undefined);
    const aliasManifest = join(work, 'source-view', formalChat.replace(/^\/+/, ''), 'pubspec.yaml');
    assert.equal(lstatSync(aliasManifest, { throwIfNoEntry: false }), undefined);
    assert.equal(lstatSync(formalChat).isSymbolicLink(), true);
    assert.equal(readFileSync(join(formalChatSource, 'pubspec.yaml'), 'utf8'), 'name: formal_chat_sdk\n');
    assert.equal(lstatSync(join(project, '.dart_tool'), { throwIfNoEntry: false }), undefined);
    assert.equal(lstatSync(join(project, 'android/settings.gradle'), { throwIfNoEntry: false }), undefined);

    const citizenFramework = join(work, 'native/CitizenSDK.xcframework');
    const chatFramework = join(work, 'native/TataChatSDK.xcframework');
    mkdirSync(citizenFramework, { recursive: true });
    mkdirSync(chatFramework, { recursive: true });
    const projectFramework = (packageRoot, packageSubpath, framework) => execFileSync(
      process.execPath, [viewScript, 'view', 'project-framework', '--source-root', app,
        '--project-root', project, '--work-root', work, '--package-root', packageRoot,
        '--package-subpath', packageSubpath, '--framework', framework], { encoding: 'utf8' }).trim();
    const citizenProjection = projectFramework(sdk,
      'darwin/CitizenSDK.xcframework', citizenFramework);
    const chatProjection = projectFramework(chat,
      'ios/TataChatSDK.xcframework', chatFramework);
    assert.equal(lstatSync(citizenProjection).isSymbolicLink(), true);
    assert.equal(realpathSync(citizenProjection), citizenFramework);
    assert.equal(lstatSync(chatProjection).isSymbolicLink(), true);
    assert.equal(realpathSync(chatProjection), chatFramework);
    assert.equal(projectFramework(sdk, 'darwin/CitizenSDK.xcframework', citizenFramework),
      citizenProjection);

    const outside = join(fixture, 'outside/CitizenSDK.xcframework');
    mkdirSync(outside, { recursive: true });
    const rejected = spawnSync(process.execPath, [viewScript, 'view', 'project-framework',
      '--source-root', app, '--project-root', project, '--work-root', work,
      '--package-root', sdk, '--package-subpath', 'darwin/Outside.xcframework',
      '--framework', outside], { encoding: 'utf8' });
    assert.notEqual(rejected.status, 0);
    assert.match(rejected.stderr, /必须归属同一产品工作根/u);
    // 消费副本可被工具改写，正式输入字节保持；target外工作根在创建目录前拒绝。
    writeFileSync(join(project, 'lib/main.dart'), 'void changedInWork() {}\n');
    assert.equal(readFileSync(join(app, 'lib/main.dart'), 'utf8'), 'void main() {}\n');
    const foreignWork = join(fixture, 'foreign-work');
    const outsideRoot = spawnSync(process.execPath, [viewScript, 'view', 'create',
      '--source-root', app, '--work-root', foreignWork], { encoding: 'utf8' });
    assert.notEqual(outsideRoot.status, 0);
    assert.match(outsideRoot.stderr, /工作根必须在本仓target内/u);
    assert.equal(existsSync(foreignWork), false);
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
});

test('CitizenApp依赖准备默认联网且离线模式必须由调用方显式选择', () => {
  assert.match(runner, /PUB_GET_ARGS=\(--enforce-lockfile\)/u);
  assert.match(runner, /CITIZENAPP_OFFLINE:-false/u);
  assert.match(runner, /CITIZENAPP_GRADLE_OFFLINE只接受true或false/u);
  assert.match(runner, /flutter pub get "\$\{PUB_GET_ARGS\[@\]\}"/u);
});

test('CitizenApp测试只在源码外工程视图生成Flutter状态', () => {
  assert.match(testRunner, /node "\$VIEW_SCRIPT" view create/u);
  assert.match(testRunner, /--source-root "\$CITIZENAPP_DIR" --work-root "\$CITIZENAPP_TEST_WORK_DIR"/u);
  assert.match(testRunner, /FLUTTER_ROOT="\$\(node/u);
  assert.doesNotMatch(testRunner, /FLUTTER_ROOT="\$CITIZENAPP_DIR"/u);
  assert.match(testRunner, /cd "\$FLUTTER_ROOT"/u);
});

test('CitizenApp Apple Build只调用产品视图投影且不向podspec传外部路径', () => {
  assert.match(runner, /node "\$VIEW_SCRIPT" view create/u);
  assert.equal((runner.match(/node "\$VIEW_SCRIPT" view project-framework/gu) ?? []).length, 2);
  assert.match(runner, /darwin\/CitizenSDK[.]xcframework/u);
  assert.match(runner, /ios\/TataChatSDK[.]xcframework/u);
  assert.doesNotMatch(runner, /CITIZENSDK_APPLE_FRAMEWORK_DIR|TATACHATSDK_APPLE_FRAMEWORK_DIR/u);
  assert.match(view, /generatedDirectories/u);
  assert.match(view, /project-framework/u);
});

test('iOS Release黑盒UI验收使用主动真机探测且不改变正式App', () => {
  assert.match(iosUITestRunner, /DEVICECTL = \["\/usr\/bin\/xcrun", "devicectl"\]/u);
  assert.match(iosUITestRunner, /command_json\(\["list", "devices"\]/u);
  assert.match(iosUITestRunner, /"device", "info", "details", "--device", identifier/u);
  assert.match(iosUITestRunner, /hardware[.]get\("reality"\) == "physical"/u);
  assert.match(iosUITestRunner, /connection[.]get\("pairingState"\) == "paired"/u);
  assert.match(iosUITestRunner, /developer_mode_enabled\(state[.]get\("developerModeStatus"\)\)/u);
  assert.match(iosUITestRunner, /for attempt in range\(ATTEMPTS\)/u);
  assert.match(iosUITestRunner, /time[.]sleep\(2\)/u);
  assert.doesNotMatch(iosUITestRunner, /get\("connection", \{\}\)[.]get\("state"\) != "connected"/u);
  assert.match(iosUITestRunner, /bundleContainerPath/u);
  assert.match(iosUITestRunner, /dataContainerPath/u);
  assert.match(iosUITestRunner, /relative[.]endswith\("[.]isar"\)/u);
  assert.match(iosUITestRunner, /set\(before\) - set\(after\)/u);
  assert.doesNotMatch(iosUITestRunner, /CitizenApp Isar 数据库必须且只能有一个/u);
  assert.doesNotMatch(iosUITestRunner, /uninstall app[^\n]*\$TARGET_BUNDLE_ID/u);

  assert.match(iosUITests, /testTransactionTabPreservesLiveChainHeaderAndEmptyPaymentForm/u);
  assert.match(iosUITests, /最终区块 \[0-9\]\+/u);
  assert.match(iosUITests, /XCTAssertGreaterThanOrEqual\(secondHeight, firstHeight/u);
  assert.match(iosUITests, /testWalletPagePreservesPublicSurfaceAndAvailableSdkEntry/u);
  assert.match(iosUITests, /testWalletGateShowsOnboardingAndColdImportWithoutSecretInput/u);
  assert.match(iosUITests, /throw XCTSkip\("正常App尚无账户/u);
  assert.match(iosUITests, /不读写助记词或密码/u);
  const walletGateTest = iosUITests.match(/func testWalletGateShowsOnboardingAndColdImportWithoutSecretInput\(\) throws \{[\s\S]*?\n  \}/u)?.[0];
  assert.ok(walletGateTest);
  // 对齐现有引导与冷导入用例，保留数量选项、空地址拒绝、返回及不输入秘密的合同。
  assert.match(walletGateTest, /for count in \[12, 18, 24\]/u);
  assert.match(walletGateTest, /let cold = app[.]buttons\["导入冷钱包"\]/u);
  assert.match(walletGateTest, /XCTAssertTrue\(confirm[.]waitForExistence\(timeout: 5\), "空地址必须保留导入页"\)/u);
  assert.match(walletGateTest, /XCTAssertFalse\(chatTab\(in: app\)[.]exists, "空地址不得进入主导航"\)/u);
  assert.match(walletGateTest, /try XCTUnwrap\(back[.]first, "冷导入页缺少返回按钮"\)[.]tap\(\)/u);
  assert.match(walletGateTest, /XCTAssertTrue\(create[.]waitForExistence\(timeout: 10\)\)/u);
  assert.doesNotMatch(walletGateTest, /typeText\(/u);
});

// 防止 AGP 9 只登记 Java 源集而漏编 Kotlin：APK 可构建成功，但真机找不到 MainActivity。
test('Android入口及测试显式登记独立Kotlin源集', () => {
  assert.ok(application.includes('sourceSets.getByName("main").kotlin.directories.apply { clear(); add("src/main") }'));
  assert.ok(application.includes('sourceSets.getByName("androidTest").kotlin.directories.apply { clear(); add("src/androidTest") }'));
});

test('Android插件注册表来自本轮外部Flutter工程', () => {
  const javaSources = application.slice(application.indexOf('sourceSets.getByName("main").java.directories.apply'),
    application.indexOf('sourceSets.getByName("main").java.directories.apply') + 260);
  assert.ok(javaSources.includes('add(flutterProductRoot.resolve("android/app/src/main/java").absolutePath)'));
});

// 中文注释：原跨仓 Rust 宿主断言转由 App 本仓测试执行，SDK 输入仍来自固定公开 Git。
test('citizenapp_qr_uses_sdk_public_contract', () => {
  for (const relative of ['lib/scanner/generated/qr_action_registry.g.dart', 'lib/scanner/generated/qr_bodies.g.dart', 'lib/scanner/qr_protocols.dart']) {
    assert.equal(existsSync(join(sourceRoot, relative)), false, '公民不得恢复 QR 第二实现：' + relative);
  }
  const sdk = dependencySources.citizen_sdk.root;
  assert.ok(readFileSync(join(sdk, 'lib/citizen_sdk.dart'), 'utf8').includes("export 'src/api/citizen_qr.dart';"));
  const api = readFileSync(join(sdk, 'lib/src/api/citizen_qr.dart'), 'utf8');
  assert.ok(api.includes('class CitizenQrActions'));
  // 核验公开方法及准确参数类型，允许正式Dart格式化产生换行。
  assert.match(api, /Future<CitizenQrScanResult>\s+parseForPurpose\(\s*String text,\s*CitizenQrScanPurpose purpose,?\s*\)/u);
  const caller = readFileSync(join(sourceRoot, 'lib/scanner/scan_dispatch_flow.dart'), 'utf8');
  assert.ok(caller.includes("import 'package:citizen_sdk/citizen_sdk.dart';"));
  assert.ok(caller.includes('.qr.parseForPurpose('));
  assert.ok(caller.includes('CitizenQrActions.'));
  assert.equal(caller.includes('package:citizen_sdk/src/'), false);
});

// 读取正式锁定SDK原件，保证打包不会重新引入已停用的应用密码钥实现。
test('非钱包客户端依赖只保留MLS及系统保护存储', () => {
  for (const source of [pubspec, tataChatPubspec]) {
    assert.doesNotMatch(source, /^  (?:cryptography|flutter_secure_storage):/mu);
  }
  for (const source of [pubLock, tataChatPubLock]) {
    assert.doesNotMatch(source, /^  flutter_secure_storage(?:_\\w+)?:/mu);
  }
  assert.doesNotMatch(tataChatPubLock, /^  cryptography:/mu);
  // 钱包上游仍使用锁定密码学闭包；取消App直接声明不能删除这条依赖。
  assert.match(pubLock, /^  cryptography:\n    dependency: transitive\n/mu);
  assert.doesNotMatch(podLock, /flutter_secure_storage/u);
  // 新固定SDK仅消费当前目录；旧src包装层必须不存在，不能靠别名掩盖失败。
  assert.equal(existsSync(new URL('lib/src/', tataChatRoot)), false);
  for (const path of ['lib/storage/chat_crypto.dart']) {
    assert.equal(existsSync(new URL(path, tataChatRoot)), false, path);
  }
  const attachment = readFileSync(new URL('lib/mls/mls_attachment.dart', tataChatRoot), 'utf8');
  const media = readFileSync(new URL('lib/protocol/media_content.proto', tataChatRoot), 'utf8');
  assert.match(attachment, /groupCreateMessage/u);
  assert.match(media, /attachment_welcome/u);
  assert.doesNotMatch(media, /cipher_key/u);
});
