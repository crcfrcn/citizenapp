#!/usr/bin/env node
// CitizenApp 本机Build的源码外只读工程视图。只建目录骨架与源文件链接，
// 平台固定布局仅在工程视图装配；Wrapper 按原字节复制，源码目录不承载生成物。
import { execFileSync } from 'node:child_process';
import {
  chmodSync, copyFileSync, existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, realpathSync, rmSync,
  symlinkSync, writeFileSync,
} from 'node:fs';
import { dirname, isAbsolute, join, parse, relative, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

// 第一方依赖只来自宿主声明和锁中的准确公开Git提交；不读取邻仓、不接受override。
// Git检出和标准Flutter消费视图均属于本次工作根，宿主源码声明和锁保持原字节。
const firstPartyRepositories = Object.freeze({
  citizen_sdk: 'https://github.com/crcfrcn/citizensdk.git',
  tatachat_sdk: 'https://github.com/tuyutata/tatachatsdk.git',
});
function dependencyBlock(text, name) {
  const matches = [...text.matchAll(new RegExp('^  ' + name + ':\\n(?:[ \\t]{4,}[^\\n]*\\n)+', 'gm'))];
  if (matches.length !== 1) fail('第一方依赖块不唯一：' + name);
  return matches[0][0];
}
function dependencyField(block, key) {
  const matches = [...block.matchAll(new RegExp('^[ \\t]+' + key + ':\\s*(.*?)\\s*$', 'gm'))];
  if (matches.length !== 1) fail('第一方依赖字段不唯一：' + key);
  const value = matches[0][1];
  return value.startsWith('"') && value.endsWith('"') ? JSON.parse(value)
    : value.startsWith("'") && value.endsWith("'") ? value.slice(1, -1) : value;
}
// Git只由调用方受控PATH交付；缺失直接失败，不回退系统目录。
function sourceGit(root, args) {
  return execFileSync('git', ['-c', 'credential.helper=', '-c', 'core.hooksPath=/dev/null',
    '-c', 'protocol.file.allow=never', '-c', 'gc.auto=0', '-C', root, ...args], {
    encoding: 'utf8', timeout: 180000, maxBuffer: 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
    env: { HOME: process.env.HOME, PATH: process.env.PATH, LANG: 'C',
      GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null', GIT_TERMINAL_PROMPT: '0' },
  }).trim();
}
function verifyGitDirectory(root) {
  if (!isAbsolute(root) || resolve(root) !== root || root === parse(root).root) fail('Git来源根无效');
  let at = parse(root).root;
  for (const part of relative(at, root).split(sep)) {
    at = join(at, part);
    const info = lstatSync(at, { throwIfNoEntry: false });
    if (!info?.isDirectory() || info.isSymbolicLink()) fail('Git来源根缺失或经过链接');
  }
}
export function resolveFirstPartyDependencies(source, work) {
  verifyGitDirectory(source); verifyGitDirectory(work);
  if (existsSync(join(source, 'pubspec_overrides.yaml'))) fail('第一方依赖禁止override');
  const manifest = readFileSync(join(source, 'pubspec.yaml'), 'utf8');
  const lock = readFileSync(join(source, 'pubspec.lock'), 'utf8');
  const result = {};
  for (const [name, url] of Object.entries(firstPartyRepositories)) {
    if (!new RegExp('^  ' + name + ':$', 'm').test(manifest)) continue;
    const declared = dependencyBlock(manifest, name), locked = dependencyBlock(lock, name);
    const sha = dependencyField(declared, 'ref');
    if (!/^    git:\s*$/m.test(declared) || !/^[0-9a-f]{40}$/.test(sha)
      || dependencyField(declared, 'url') !== url || dependencyField(declared, 'path') !== '.'
      || dependencyField(locked, 'source') !== 'git' || dependencyField(locked, 'url') !== url
      || dependencyField(locked, 'path') !== '.' || dependencyField(locked, 'ref') !== sha
      || dependencyField(locked, 'resolved-ref') !== sha
      || dependencyField(locked, 'version') !== '1.0.0') fail('第一方声明、锁和唯一Git来源不一致：' + name);
    const parent = join(work, 'git-sources'); mkdirSync(parent, { recursive: true, mode: 0o700 });
    verifyGitDirectory(parent);
    const root = join(parent, name);
    if (!existsSync(root)) {
      mkdirSync(root, { mode: 0o700 });
      const owned = lstatSync(root);
      try {
        sourceGit(root, ['init', '--quiet']);
        sourceGit(root, ['remote', 'add', 'origin', url]);
        sourceGit(root, ['fetch', '--no-tags', '--depth=1', 'origin', sha]);
        sourceGit(root, ['checkout', '--quiet', '--detach', sha]);
      } catch {
        const now = lstatSync(root, { throwIfNoEntry: false });
        if (now?.isDirectory() && !now.isSymbolicLink() && now.dev === owned.dev && now.ino === owned.ino) rmSync(root, { recursive: true });
        fail('第一方固定Git提交取得失败；未使用邻仓或重试：' + name);
      }
    }
    verifyGitDirectory(root); verifyGitDirectory(join(root, '.git'));
    if (resolve(sourceGit(root, ['rev-parse', '--show-toplevel'])) !== root
      || resolve(sourceGit(root, ['rev-parse', '--absolute-git-dir'])) !== join(root, '.git')
      || resolve(root, sourceGit(root, ['rev-parse', '--git-common-dir'])) !== join(root, '.git')
      || sourceGit(root, ['rev-parse', '--abbrev-ref', 'HEAD']) !== 'HEAD'
      || sourceGit(root, ['rev-parse', 'HEAD']) !== sha || sourceGit(root, ['remote', 'get-url', 'origin']) !== url
      || sourceGit(root, ['status', '--porcelain=v1', '--untracked-files=all']) !== ''
      || !new RegExp('^name:\\s*' + name + '\\s*$', 'm').test(readFileSync(join(root, 'pubspec.yaml'), 'utf8'))) {
      fail('第一方Git检出身份或源码已变：' + name);
    }
    result[name] = { root, url, sha };
  }
  if (!result.citizen_sdk) fail('宿主缺少唯一CitizenSDK直接依赖');
  return result;
}
function projectedPubMetadata(source, dependencies, views) {
  let manifest = readFileSync(join(source, 'pubspec.yaml'), 'utf8');
  let lock = readFileSync(join(source, 'pubspec.lock'), 'utf8');
  for (const [name] of Object.entries(dependencies)) {
    const target = views[name];
    if (typeof target !== 'string' || !isAbsolute(target) || target !== resolve(target)) fail('SDK视图路径无效');
    manifest = manifest.replace(dependencyBlock(manifest, name), '  ' + name + ':\n    path: ' + JSON.stringify(target) + '\n');
    lock = lock.replace(dependencyBlock(lock, name), '  ' + name + ':\n    dependency: "direct main"\n    description:\n      path: '
      + JSON.stringify(target) + '\n      relative: false\n    source: path\n    version: "1.0.0"\n');
  }
  return { 'pubspec.yaml': manifest, 'pubspec.lock': lock };
}

function fail(message) {
  throw new Error(`CitizenApp工程视图失败：${message}`);
}

function argumentsFor(command, values) {
  const allowed = (['create', 'create-android', 'verify', 'dependencies'].includes(command))
    ? new Set(['source-root', 'work-root'])
    : command === 'project-framework'
      ? new Set(['source-root', 'project-root', 'work-root', 'package-root', 'package-subpath', 'framework'])
      : fail(`未知命令：${command || '<empty>'}`);
  const result = {};
  for (let index = 0; index < values.length; index += 2) {
    const key = values[index]?.replace(/^--/u, '');
    const value = values[index + 1];
    if (!key || !allowed.has(key) || result[key] !== undefined || value === undefined || value === '') {
      fail('参数不完整、重复或越界');
    }
    result[key] = value;
  }
  if (Object.keys(result).length !== allowed.size) fail('参数闭集不完整');
  return result;
}

function absolutePath(value, label) {
  if (typeof value !== 'string' || !isAbsolute(value) || value !== resolve(value)
    || value === parse(value).root || value.endsWith(sep) || value.includes(`${sep}.${sep}`)
    || value.includes(`${sep}..${sep}`)) fail(`${label}必须是规范绝对路径`);
  return value;
}

function inside(root, candidate) {
  const part = relative(root, candidate);
  return part === '' || (part !== '..' && !part.startsWith(`..${sep}`) && !isAbsolute(part));
}

function ordinaryDirectory(directory, label) {
  const info = lstatSync(directory, { throwIfNoEntry: false });
  if (!info?.isDirectory() || info.isSymbolicLink() || realpathSync(directory) !== directory) {
    fail(`${label}必须是无链接普通目录`);
  }
}

function existingAncestors(path, label) {
  const root = parse(path).root;
  let current = root;
  for (const part of path.slice(root.length).split(sep).filter(Boolean)) {
    current = join(current, part);
    const info = lstatSync(current, { throwIfNoEntry: false });
    if (!info) break;
    if (!info.isDirectory() || info.isSymbolicLink() || realpathSync(current) !== current) {
      fail(`${label}包含链接或非目录祖先：${current}`);
    }
  }
}

const generatedDirectories = new Set([
  '.dart_tool', '.git', '.gradle', '.pub-cache', '.symlinks', 'Pods', 'build', 'ephemeral',
  'node_modules', 'target',
]);
const generatedFiles = new Set([
  '.flutter-plugins', '.flutter-plugins-dependencies', '.packages',
  'Generated.xcconfig', 'flutter_export_environment.sh', 'local.properties',
  'generated_config.cmake', 'generated_plugin_registrant.cc',
  'generated_plugin_registrant.h', 'generated_plugin_registrant.dart',
  'GeneratedPluginRegistrant.h', 'GeneratedPluginRegistrant.m',
  'GeneratedPluginRegistrant.swift', 'GeneratedPluginRegistrant.java', 'generated_plugins.cmake',
]);
const excludedFiles = new Set(['settings.gradle', 'settings.gradle.kts']);

// Wrapper 属于已选 Flutter 工具；只有直接调用 Wrapper 的 Android 工程才需要复制。
// 本机使用显式 Gradle，iOS 与 Dart 测试均不向工程引入 Android 工具副本。
function wrapperInputs() {
  const flutterRoot = absolutePath(process.env.FLUTTER_ROOT, 'Flutter工具根');
  ordinaryDirectory(flutterRoot, 'Flutter工具根');
  const root = join(flutterRoot, 'bin/cache/artifacts/gradle_wrapper');
  return ['gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar'].map(name => {
    const input = join(root, name);
    existingAncestors(dirname(input), 'Wrapper工具来源');
    const info = lstatSync(input, { throwIfNoEntry: false });
    if (!info?.isFile() || info.isSymbolicLink() || !info.size) fail('Flutter Wrapper原件缺失：' + name);
    return { input, name };
  });
}

// 只对已声明的本地聊天包调用其公开装配接口，宿主不复制插件包路径。
async function chatSourceViewApi(packageRoot) {
  const manifest = readFileSync(join(packageRoot, 'pubspec.yaml'), 'utf8');
  if (!/^name: tatachat_sdk\r?$/mu.test(manifest)) return null;
  const entry = join(packageRoot, 'scripts/release.mjs');
  if (!lstatSync(entry).isFile() || lstatSync(entry).isSymbolicLink()) fail('聊天SDK装配入口必须是普通文件');
  return import(pathToFileURL(entry).href);
}

async function createView(sourceInput, workInput, android = false) {
  const wrappers = android ? wrapperInputs() : [];
  const sourceRoot = absolutePath(sourceInput, '产品源码根');
  const workRoot = absolutePath(workInput, '产品工作根');
  ordinaryDirectory(sourceRoot, '产品源码根');
  existingAncestors(workRoot, '产品工作根');
  if (inside(sourceRoot, workRoot) || inside(workRoot, sourceRoot)) fail('产品工作根与源码根必须分离');
  mkdirSync(workRoot, { recursive: true, mode: 0o700 });
  ordinaryDirectory(workRoot, '产品工作根');
  const viewRoot = join(workRoot, 'source-view');
  const prior = lstatSync(viewRoot, { throwIfNoEntry: false });
  if (prior) {
    if (!prior.isDirectory() || prior.isSymbolicLink() || !inside(workRoot, viewRoot)) {
      fail('旧工程视图归属无效');
    }
    rmSync(viewRoot, { recursive: true });
  }
  mkdirSync(viewRoot, { recursive: true, mode: 0o700 });
  const visited = new Set();
  const mappedPath = source => join(viewRoot, source.replace(/^\/+/, ''));

  async function materialize(packageRoot, allowPackageLink = false) {
    packageRoot = resolve(packageRoot);
    if (visited.has(packageRoot)) return;
    const packageInfo = lstatSync(packageRoot, { throwIfNoEntry: false });
    let sourceDirectory = packageRoot;
    if (packageInfo?.isSymbolicLink()) {
      if (!allowPackageLink) fail('产品源码根不得是链接');
      existingAncestors(parse(packageRoot).dir, '本地path依赖父目录');
      sourceDirectory = realpathSync(packageRoot);
    }
    ordinaryDirectory(sourceDirectory, '本地path依赖真实根');
    if ((!inside(join(workRoot, 'git-sources'), packageRoot) && inside(packageRoot, workRoot))
      || inside(sourceDirectory, viewRoot) || inside(viewRoot, sourceDirectory)) {
      fail('工程视图与path依赖必须分离');
    }
    visited.add(packageRoot);
    const destinationRoot = mappedPath(packageRoot);
    if (/^name: citizen_sdk\r?$/mu.test(readFileSync(join(sourceDirectory, "pubspec.yaml"), "utf8"))) {
      // SDK独自拥有Flutter入口布局；宿主不复制包名/路径映射合同。
      const api = await import(pathToFileURL(join(sourceDirectory, "scripts/release.mjs")).href);
      api.createFlutterSourceView(sourceDirectory, destinationRoot);
      return;
    }
    const chat = await chatSourceViewApi(sourceDirectory);
    if (chat) {
      await chat.createFlutterSourceView(sourceDirectory, destinationRoot);
      return;
    }
    mkdirSync(destinationRoot, { recursive: true, mode: 0o700 });

    function visit(source, destination) {
      for (const name of readdirSync(source).sort()) {
        const input = join(source, name);
        const output = join(destination, name);
        const info = lstatSync(input);
        // 远端Flutter直接启动Gradle：settings保留原字节的普通文件，防止Gradle把
        // 跨根链接解析成源码工程。其它源文件仍只读链接；本机原生入口保持原方式。
        if (android && sourceDirectory === sourceRoot && input === join(sourceRoot, 'android/settings.gradle.kts')) {
          if (!info.isFile() || info.isSymbolicLink()) fail('Android settings来源必须是普通文件');
          copyFileSync(input, output);
          continue;
        }
        if (sourceDirectory === sourceRoot && ['android/gradlew', 'android/gradlew.bat',
          'android/gradle'].includes(relative(sourceRoot, input).split(sep).join('/'))) {
          fail('产品源码残留Wrapper副本：' + input);
        }
        if (info.isDirectory() && name === 'swiftpm') continue;
        if (generatedDirectories.has(name) || generatedFiles.has(name) || excludedFiles.has(name)
          || input.endsWith(`${sep}.idea${sep}workspace.xml`)) continue;
        if (info.isDirectory() && !info.isSymbolicLink()) {
          mkdirSync(output, { recursive: true, mode: 0o700 });
          visit(input, output);
        } else if (info.isFile() || info.isSymbolicLink()) {
          symlinkSync(input, output);
        } else fail(`源码视图遇到不支持的条目：${input}`);
      }
    }

    visit(sourceDirectory, destinationRoot);
    if (sourceDirectory === sourceRoot) {
      // Xcode/Gradle 固定入口只在源码外生成；每个入口绑定一个已核对的源文件。
      const mappings = [
        ['ios/Runner.xcscheme', 'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme'],
        ['ios/RunnerUITests.xcscheme', 'ios/Runner.xcodeproj/xcshareddata/xcschemes/RunnerUITests.xcscheme'],
        ['android/gradle-wrapper.properties', 'android/gradle/wrapper/gradle-wrapper.properties'],
      ];
      for (const [sourcePath, targetPath] of mappings) {
        const input = join(sourceRoot, sourcePath), output = join(destinationRoot, targetPath);
        const info = lstatSync(input, { throwIfNoEntry: false });
        if (!info?.isFile() || info.isSymbolicLink()) fail(`平台输入缺少普通文件：${sourcePath}`);
        existingAncestors(dirname(output), '平台输出');
        if (lstatSync(output, { throwIfNoEntry: false })) fail(`平台入口重复：${targetPath}`);
        mkdirSync(dirname(output), { recursive: true, mode: 0o700 });
        symlinkSync(input, output);
      }
      for (const { input, name } of wrappers) {
        const output = join(destinationRoot, 'android', name);
        existingAncestors(dirname(output), 'Wrapper目标');
        if (lstatSync(output, { throwIfNoEntry: false })) fail('Wrapper目标重复：' + name);
        mkdirSync(dirname(output), { recursive: true, mode: 0o700 });
        copyFileSync(input, output);
        if (name === 'gradlew') chmodSync(output, 0o755);
      }
    }
  }

  const dependencies = resolveFirstPartyDependencies(sourceRoot, workRoot);
  await materialize(sourceRoot);
  const views = {};
  for (const [name, item] of Object.entries(dependencies)) {
    await materialize(item.root);
    views[name] = mappedPath(item.root);
  }
  for (const [name, value] of Object.entries(projectedPubMetadata(sourceRoot, dependencies, views))) {
    const path = join(mappedPath(sourceRoot), name);
    if (lstatSync(path, { throwIfNoEntry: false })?.isSymbolicLink()) rmSync(path);
    writeFileSync(path, value);
  }
  return mappedPath(sourceRoot);
}

// CI预先解析Pub后复用同一视图；不接受另一工作根、源码副本或漂移的SDK依赖。
async function verifyView(sourceInput, workInput) {
  const sourceRoot = absolutePath(sourceInput, '产品源码根');
  const workRoot = absolutePath(workInput, '产品工作根');
  ordinaryDirectory(sourceRoot, '产品源码根');
  ordinaryDirectory(workRoot, '产品工作根');
  existingAncestors(workRoot, '产品工作根');
  if (inside(sourceRoot, workRoot) || inside(workRoot, sourceRoot)) fail('产品工作根与源码根必须分离');
  const viewRoot = join(workRoot, 'source-view');
  const projectRoot = join(viewRoot, sourceRoot.replace(/^\/+/, ''));
  ordinaryDirectory(projectRoot, '产品视图根');
  const dependencies = resolveFirstPartyDependencies(sourceRoot, workRoot), views = {};
  for (const [name, item] of Object.entries(dependencies)) {
    const view = join(viewRoot, item.root.replace(/^\/+/, ''));
    const api = await import(pathToFileURL(join(item.root, 'scripts/release.mjs')).href);
    await api.assertFlutterSourceView(item.root, view);
    views[name] = view;
  }
  for (const [name, expected] of Object.entries(projectedPubMetadata(sourceRoot, dependencies, views))) {
    const path = join(projectRoot, name), info = lstatSync(path, { throwIfNoEntry: false });
    if (!info?.isFile() || info.isSymbolicLink() || readFileSync(path, 'utf8') !== expected) fail('本轮Pub声明或锁漂移');
  }
  const expectedPackages = Object.entries(views);
  const configPath = join(projectRoot, '.dart_tool/package_config.json');
  if (existsSync(configPath)) {
    const config = JSON.parse(readFileSync(configPath, 'utf8'));
    for (const [name, view] of expectedPackages) {
      const dependencies = config.packages?.filter(item => item.name === name) ?? [];
      if (dependencies.length !== 1
          || fileURLToPath(new URL(dependencies[0].rootUri, pathToFileURL(configPath))).replace(/[\/]$/u, '') !== view) {
        fail('Pub实际SDK依赖未绑定本轮消费视图');
      }
    }
  }
  return projectRoot;
}

async function projectFramework(values) {
  const sourceRoot = absolutePath(values['source-root'], '产品源码根');
  const projectRoot = absolutePath(values['project-root'], '产品视图根');
  const workRoot = absolutePath(values['work-root'], '产品工作根');
  const packageRoot = absolutePath(values['package-root'], 'SDK源码根');
  const framework = absolutePath(values.framework, 'Framework目录');
  const packageSubpath = values['package-subpath'];
  if (packageSubpath.startsWith('/') || packageSubpath.includes('\\')
    || packageSubpath.split('/').some(part => !part || part === '.' || part === '..')
    || !packageSubpath.endsWith('.xcframework')) fail('Framework投影子路径无效');
  ordinaryDirectory(sourceRoot, '产品源码根');
  ordinaryDirectory(packageRoot, 'SDK源码根');
  ordinaryDirectory(projectRoot, '产品视图根');
  ordinaryDirectory(workRoot, '产品工作根');
  ordinaryDirectory(framework, 'Framework目录');
  if (!inside(workRoot, projectRoot) || !inside(workRoot, framework)) {
    fail('工程视图与Framework必须归属同一产品工作根');
  }
  const suffix = sourceRoot.replace(/^\/+/, '');
  if (!projectRoot.endsWith(`${sep}${suffix}`)) fail('产品视图没有保留源绝对路径映射');
  const viewRoot = projectRoot.slice(0, -(suffix.length + 1));
  if (!inside(workRoot, viewRoot)) fail('工程视图映射根越界');
  const packageView = join(viewRoot, packageRoot.replace(/^\/+/, ''));
  ordinaryDirectory(packageView, 'SDK视图根');
  const manifest = join(packageView, 'pubspec.yaml');
  const manifestInfo = lstatSync(manifest, { throwIfNoEntry: false });
  if (/^name: citizen_sdk\r?$/mu.test(readFileSync(join(packageRoot, "pubspec.yaml"), "utf8"))) {
    const api = await import(pathToFileURL(join(packageRoot, "scripts/release.mjs")).href);
    api.assertFlutterSourceView(packageRoot, packageView);
  } else {
    const chat = await chatSourceViewApi(packageRoot);
    if (chat) await chat.assertFlutterSourceView(packageRoot, packageView);
    else if (!manifestInfo?.isSymbolicLink() || realpathSync(manifest) !== join(packageRoot, 'pubspec.yaml')) {
      fail('SDK视图与源码根绑定无效');
    }
  }
  const destination = join(packageView, ...packageSubpath.split('/'));
  const parent = parse(destination).dir;
  ordinaryDirectory(parent, 'Framework投影父目录');
  const existing = lstatSync(destination, { throwIfNoEntry: false });
  if (existing) {
    if (!existing.isSymbolicLink() || realpathSync(destination) !== framework) {
      fail('Framework投影目标被其它条目占用');
    }
    return destination;
  }
  symlinkSync(framework, destination, 'dir');
  if (!lstatSync(destination).isSymbolicLink() || realpathSync(destination) !== framework) {
    fail('Framework投影回读验真失败');
  }
  return destination;
}

try {
  const [command, ...values] = process.argv.slice(2);
  const parsed = argumentsFor(command, values);
  const result = command === 'dependencies'
    ? JSON.stringify(resolveFirstPartyDependencies(parsed['source-root'], parsed['work-root']))
    : (command === 'create' || command === 'create-android')
    ? await createView(parsed['source-root'], parsed['work-root'], command === 'create-android')
    : command === 'verify'
      ? await verifyView(parsed['source-root'], parsed['work-root'])
      : await projectFramework(parsed);
  process.stdout.write(`${result}\n`);
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
}
