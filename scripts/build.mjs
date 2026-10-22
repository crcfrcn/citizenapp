#!/usr/bin/env node
// 本产品唯一编译与自动化实现；本机签名、安装统一由控制台安装器负责。
import {spawn, execFileSync} from 'node:child_process';
import {appendFileSync, chmodSync, copyFileSync, cpSync, existsSync, mkdirSync, mkdtempSync,
    readFileSync, readdirSync, realpathSync, renameSync, rmSync, writeFileSync} from 'node:fs';
import {join, resolve, dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const controller = new AbortController();
const groups = new Set();
let activeMarker;

// 取消后确认本轮整个进程组退出；无法确认时留下标记，禁止后续清场。
async function run(command, args, cwd, capture = false, environment = process.env, operation = '编译') {
    controller.signal.throwIfAborted();
    return new Promise((accept, reject) => {
        const child = spawn(command, args, {cwd, env: environment, detached: true,
            stdio: ['ignore', capture ? 'pipe' : 'inherit', 'inherit']});
        let output = '', failure, timer;
        if (child.pid) groups.add(child.pid);
        const stop = () => {
            if (timer) return;
            try {
                process.kill(-child.pid, 'SIGTERM');
            } catch {}
            timer = setTimeout(() => {
                try {
                    process.kill(-child.pid, 'SIGKILL');
                } catch {}
            }, 30000);
        };
        controller.signal.addEventListener('abort', stop, {once: true});
        child.stdout?.on('data', bytes => { output += bytes; });
        child.once('error', error => { failure = error; });
        child.once('close', async code => {
            controller.signal.removeEventListener('abort', stop);
            for (let retry = 0; retry < 350 && child.pid; retry++) {
                try {
                    process.kill(-child.pid, 0);
                } catch (error) {
                    if (error.code === 'ESRCH') {
                        groups.delete(child.pid);
                        break;
                    }
                }
                if (retry === 0) {
                    failure ||= Error(operation + '主进程退出后仍有后代活动');
                    stop();
                }
                await new Promise(done => setTimeout(done, 100));
            }
            clearTimeout(timer);
            if (groups.size) return reject(Error(operation + '进程组退出未确认，保留本轮现场'));
            if (failure || code !== 0 || controller.signal.aborted) return reject(failure || Error(operation + '失败或已取消'));
            accept(output.trim());
        });
    });
}

export async function build(platform, phase = 'app', options={}) {
    const environment=options.environment||process.env;
    const work = options.work || environment.WORK ||
        join(root, 'target/build', `${environment.GITHUB_RUN_ID}-${environment.GITHUB_RUN_ATTEMPT}`);
    const project = join(work, 'project');
    activeMarker = join(work, 'build-active.json');
    if (existsSync(activeMarker)) throw Error('本轮编译现场仍被占用');
    writeFileSync(activeMarker, JSON.stringify({pid: process.pid}), {flag: 'wx', mode: 0o600});
    try {
        if (phase === 'dependencies') {
            // 自动化已经消费正式SDK中的原生组件，不重复编译SDK。
            if (!options.local) return;
            const source=join(work,'sources/tatachat_sdk');
            for(const target of [platform]){
                const dependencyEnvironment={...environment};delete dependencyEnvironment.GH_TOKEN;delete dependencyEnvironment.GITHUB_TOKEN;
                const result=await run(process.execPath,[join(source,'scripts/build.mjs'),'native',target],source,true,dependencyEnvironment);
                const output=JSON.parse(result).output;
                const packagePath=target==='android'?'android/src/main/jniLibs':target==='ios'?'ios/TataChatSDK.xcframework':'native';
                cpSync(target==='ios'?join(output,'TataChatSDK.xcframework'):output,join(work,'packages/tatachat_sdk',packagePath),{recursive:true});
            }
            return;
        }
        const flutter = join(environment.FLUTTER_ROOT, 'bin/flutter');
        const version = ['--build-name', environment.CITIZENAPP_VERSION, '--build-number', environment.CITIZENAPP_BUILD_NUMBER||environment.GITHUB_RUN_NUMBER];
        const output = join(work, 'artifact');
        mkdirSync(output);
        const title = `公民·${platform === 'ios' ? 'iOS' : 'Android'}·v${environment.CITIZENAPP_VERSION}`;
        if (platform === 'android') {
            for (const [format, source] of (options.local?[['apk','flutter-apk/app-release.apk']]:[['apk', 'flutter-apk/app-release.apk'], ['appbundle', 'bundle/release/app-release.aab']])) {
                await run(flutter, ['build', format, '--release', '--target-platform', 'android-arm64', ...version], project,false,environment);
                copyFileSync(join(project, 'build/app/outputs', source), join(output, `${title}.${format === 'apk' ? 'apk' : 'aab'}`));
            }
        } else if(options.local){
            await run(flutter,['build','ios','--release','--no-codesign',...version],project,false,environment);
            cpSync(join(project,'build/ios/iphoneos/Runner.app'),join(output,'Runner.app'),{recursive:true});
        } else {
            await run(flutter, ['build', 'ipa', '--release', '--export-options-plist', join(work, 'signing/export.plist'), ...version], project,false,environment);
            const directory = join(project, 'build/ios/ipa');
            const files = readdirSync(directory).filter(name => name.endsWith('.ipa'));
            copyFileSync(join(directory, files[0]), join(output, `${title}.ipa`));
        }
    } finally {
        // 成败不决定现场占用；只有编译进程组全部退出后才释放标记。
        if (!groups.size) rmSync(activeMarker);
    }
}

// 为保留现有自动化功能暂留必要接口；配置文件仅同名导出，不扩展职责。
export async function describeAction({flow, platform}) {
    const labels = {ios: 'iOS', android: 'Android'};
    // 版本按本平台最新成功Run递增，只派发一次并返回原Run编号。
    return {repository: 'crcfrcn/citizenapp', launch: async ({read, dispatch}) => {
        const rows = [];
        for (let page = 1; ; page++) {
            const data = await read('actions/workflows/' + platform + '.yml/runs?' +
                'branch=main&event=workflow_dispatch&per_page=100&page=' + page);
            rows.push(...data.workflow_runs);
            if (data.workflow_runs.length < 100) break;
        }
        const latest = rows.filter(row => row.status === 'completed' && row.conclusion === 'success')
            .sort((a, b) => Date.parse(b.updated_at) - Date.parse(a.updated_at) || b.id - a.id)[0];
        let version;
        if (latest) {
            const prefix = '公民·' + labels[platform] + '·v';
            const parts = latest.display_title.slice(prefix.length).split('.');
            parts[2] = String(BigInt(parts[2]) + 1n);
            version = parts.join('.');
        } else {
            version = /^version:\s*(\S+)/mu.exec(readFileSync(join(root, 'pubspec.yaml'), 'utf8'))[1].split('+')[0];
        }
        const receipt = await dispatch({workflow: platform + '.yml', ref: 'main', inputs: {version}});
        return {runID: receipt.workflow_run_id};
    }};
}

// 只在本轮选择一次正式版本；不用GitHub的latest标记或手填Run代替真实成功来源。
export async function selectSDKRelease(product, read) {
    const releases = [];
    for (let page = 1; ; page++) {
        const rows = await read('releases?per_page=100&page=' + page);
        releases.push(...rows);
        if (rows.length < 100) break;
    }
    const candidates = releases.flatMap(release => {
        if (release.draft || release.prerelease || !release.published_at) return [];
        let proof;
        try { proof = JSON.parse(release.body); } catch { return []; }
        if (proof.product_id !== product || proof.platform !== 'sdk') return [];
        return [{release, proof}];
    }).sort((a, b) => {
        const left = a.proof.software_version.split('.').map(BigInt);
        const right = b.proof.software_version.split('.').map(BigInt);
        for (let i = 0; i < 3; i++) if (left[i] !== right[i]) return left[i] > right[i] ? -1 : 1;
        return b.release.id - a.release.id;
    });
    const selected = candidates[0];
    if (!selected) throw Error(product + '没有可用的正式SDK版本');
    const run = await read('actions/runs/' + selected.proof.producer_run_id);
    if (run.status !== 'completed' || run.conclusion !== 'success') {
        throw Error(product + '最新正式SDK的来源自动化未成功');
    }
    return selected;
}

// 两个平台及本机共用产品自己的工程装配，公开IO注入仅供既有合成回归。
export async function assembleProject(environment,io={}){
 const process={env:environment,pid:globalThis.process.pid};
 const execute=io.execFileSync||execFileSync;
const root = environment.GITHUB_WORKSPACE, work = environment.WORK;
const project = join(work, 'project');
mkdirSync(project);
for (const entry of readdirSync(root)) {
    if (['target', '.git', '.dart_tool', 'build', '.gradle'].includes(entry)) continue;
    cpSync(join(root, entry), join(project, entry), {recursive: true});
}
let declaration = readFileSync(join(project, 'pubspec.yaml'), 'utf8');
let lock = readFileSync(join(project, 'pubspec.lock'), 'utf8');
for (const name of ['citizen_sdk', 'tatachat_sdk']) {
    const record = lock.split('\n  ' + name + ':\n')[1]?.split(/\n  \S/)[0];
    const url = /url: "?(https:\/\/github.com\/[^"\s]+\.git)"?/.exec(record || '')?.[1];
    const repository = url.slice('https://github.com/'.length, -4);
    const product = repository.split('/')[1];
    const local = resolve(root, '..', product);
    const read = path => JSON.parse(execute('gh', ['api', 'repos/' + repository + '/' + path],
        {encoding: 'utf8', env: environment}));
    const selected = environment.GITHUB_ACTIONS === 'true' ? await selectSDKRelease(product, read) : null;
    const ref = selected ? selected.proof.git_commit_sha :
        execute('git', ['-C', local, 'rev-parse', 'refs/heads/main'], {encoding: 'utf8'}).trim();
    const source = join(work, 'sources', name), output = join(work, 'packages', name);
    mkdirSync(source, {recursive: true});
    execute('git', ['init', source]);
    execute('git', ['-C', source, 'fetch', '--depth=1', selected ? url : local, ref]);
    execute('git', ['-C', source, 'checkout', '--detach', 'FETCH_HEAD']);
    mkdirSync(dirname(output), {recursive: true});
    const sdk = await import(pathToFileURL(join(source, 'scripts/build.mjs')));
    console.log(product + '：' + (selected ? selected.release.tag_name : 'main') + ' ' + ref);
    if (selected) {
        const directory = join(work, 'downloads', product);
        mkdirSync(directory, {recursive: true});
        for (const extension of ['zip', 'json', 'sha256']) {
            const label = selected.release.tag_name + '.' + extension;
            const asset = selected.release.assets.find(asset => asset.label === label && asset.state === 'uploaded');
            await run('gh', ['release', 'download', selected.release.tag_name, '--repo', repository,
                '--pattern', asset.name, '--output', join(directory, label)], root, false, environment);
        }
        if (name === 'citizen_sdk') {
            await sdk.consume({directory, sourceSha: ref, sourceRun: selected.proof.producer_run_id,
                sourceAttempt: selected.proof.producer_run_attempt, output, signal: controller.signal});
        } else {
            const expanded = join(directory, 'expanded');
            await run('unzip', ['-q', join(directory, selected.release.tag_name + '.zip'), '-d', expanded], root, false, environment);
            sdk.createFlutterSourceView(join(expanded, 'project'), output);
        }
    } else {
        sdk.createFlutterSourceView(source, output);
        if (name === 'citizen_sdk') {
            const settings = await import(pathToFileURL(join(source, 'scripts/config.mjs')));
            const tools = settings.tools;
            const nativeEnvironment = {...environment,
                ANDROID_NDK_HOME: join(environment.ANDROID_HOME, 'ndk', tools.ndk)};
            nativeEnvironment.PATH = join(environment.ANDROID_HOME, 'cmake', tools.cmake, 'bin') + ':' + environment.PATH;
            if (environment.PLATFORM === 'android') {
                // 复用Gradle官方wrapper已安装版本，不下载第二份工具。
                const distributions = join(environment.HOME, '.gradle/wrapper/dists');
                const candidates = environment.GRADLE_HOME ? [environment.GRADLE_HOME] :
                    readdirSync(distributions).filter(name => name.startsWith('gradle-' + tools.gradle + '-'))
                        .flatMap(name => readdirSync(join(distributions, name))
                            .map(id => join(distributions, name, id, 'gradle-' + tools.gradle)));
                const gradle = candidates.find(path => existsSync(join(path, 'bin/gradle')));
                if (gradle) nativeEnvironment.PATH = join(gradle, 'bin') + ':' + nativeEnvironment.PATH;
            }
            const result = JSON.parse(await run(globalThis.process.execPath,
                [join(source, 'scripts/build.mjs'), 'native', environment.PLATFORM === 'ios' ? 'Apple' : 'Android'],
                source, true, nativeEnvironment));
            cpSync(result.output, output, {recursive: true});
        }
    }
    declaration = declaration.replace(new RegExp('  ' + name + ':\\n(?:    .*\\n)+'), '  ' + name + ':\n    path: ' + output + '\n');
    lock = lock.replace(new RegExp('  ' + name + ':\\n(?:    .*\\n)+'), entry => {
        const version = '    version: ' + JSON.stringify(/^version: (\S+)$/m.exec(readFileSync(join(output,'pubspec.yaml'),'utf8'))[1]);
        return '  ' + name + ':\n    dependency: "direct main"\n    description:\n      path: "' + output +
            '"\n      relative: false\n    source: path\n' + version + '\n';
    });
}
writeFileSync(join(project, 'pubspec.yaml'), declaration);
// Flutter官方模板只写本轮工程；保留既有业务源码和平台工程原件。
const flutter = join(process.env.FLUTTER_ROOT, 'bin/flutter');
execute(flutter, ['create', '--no-pub', '--platforms=android,ios', '--org=com.crcfrcn', '--project-name=citizenapp', project], {stdio: 'inherit'});
// create即使不执行Pub也会重写锁；完成后写回只映射SDK路径的完整原锁。
writeFileSync(join(project, 'pubspec.lock'), lock);
// 只排除模板新增的示例；产品原有同名测试必须保留。
if (!readdirSync(join(root, 'test')).includes('widget_test.dart')) rmSync(join(project, 'test/widget_test.dart'), {force: true});
const write = (path, text) => {
    mkdirSync(dirname(join(project, path)), {recursive: true});
    writeFileSync(join(project, path), text);
};
const copy = (source, destination) => {
    mkdirSync(dirname(join(project, destination)), {recursive: true});
    copyFileSync(join(root, source), join(project, destination));
};
// 移除模板入口，唯一原生入口来自本产品已提交源码。
rmSync(join(project, 'android/app/src/main/kotlin'), {recursive: true, force: true});
for (const name of ['MainActivity', 'SquareMediaChannel', 'SquareMp4FastStart', 'SquareVideoTranscoder']) {
    const source = name === 'MainActivity' ? 'app' : 'square';
    copy('android/' + source + '/' + name + '.kt', 'android/app/src/main/' + name + '.kt');
}
copy('android/app/AndroidManifest.xml', 'android/app/src/main/AndroidManifest.xml');
copy('android/app/InstrumentedTests.kt', 'android/app/src/androidTest/InstrumentedTests.kt');
copy('ios/project/Runner.pbxproj', 'ios/Runner.xcodeproj/project.pbxproj');
copy('ios/project/Runner.xcscheme', 'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme');
for (const name of ['AppDelegate.swift', 'SystemProtectedDataChannel.swift', 'Info.plist', 'InfoPlist.xcstrings']) {
    copy('ios/source/' + name, 'ios/Runner/' + name);
}
for (const name of ['SquareMediaChannel', 'SquareVideoTranscoder']) copy('ios/square/' + name + '.swift', 'ios/Runner/' + name + '.swift');
for (const name of ['RunnerTests', 'RunnerUITests']) copy('ios/tests/' + name + '.swift', 'ios/' + name + '.swift');
// 以下仅为本轮平台工具直接消费的必要配置，不生成常驻模块。
// 使用Flutter生成的标准工程，只应用本产品编译需要的插件和版本差异。
const gradleRoot = join(project, 'android/build.gradle.kts');
write('android/build.gradle.kts', readFileSync(gradleRoot, 'utf8') + `
subprojects {
    plugins.withId("com.android.library") {
        if (project.name == "citizen_sdk") { pluginManager.apply("org.jetbrains.kotlin.android") }
        if (project.name == "camera_android_camerax") {
            dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
        }
    }
}
`);
const settings = join(project, 'android/settings.gradle.kts');
write('android/settings.gradle.kts', readFileSync(settings, 'utf8')
    .replace(/id\("com.android.application"\) version "[^"]+"/, 'id("com.android.application") version "9.0.1"')
    .replace(/id\("org.jetbrains.kotlin.android"\) version "[^"]+"/, 'id("org.jetbrains.kotlin.android") version "2.2.20"')
    .replace('id("dev.flutter.flutter-plugin-loader") version "1.0.0"',
        'id("dev.flutter.flutter-plugin-loader") version "1.0.0"\n    id("com.android.library") version "9.0.1" apply false'));
appendFileSync(join(project, 'android/gradle.properties'), '\nandroid.builtInKotlin=false\nandroid.newDsl=false\n');
const wrapper = join(project, 'android/gradle/wrapper/gradle-wrapper.properties');
write('android/gradle/wrapper/gradle-wrapper.properties', readFileSync(wrapper, 'utf8')
    .replace(/gradle-[^/]+-(?:bin|all)\.zip/, 'gradle-9.1.0-bin.zip')
    .replace(/^distributionSha256Sum=.*\n?/gm, '') +
    '\ndistributionSha256Sum=a17ddd85a26b6a7f5ddb71ff8b05fc5104c0202c6e64782429790c933686c806\n');
write("android/app/src/main/res/xml/network_security_config.xml", `<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- 生产全部走 HTTPS / WSS（TLS）：cid、square/chain-bootstrap Worker、
         GitHub 更新和 CitizenSDK 公民链节点。
         默认阻断一切明文流量，防中间人（iOS 侧由默认 ATS 同等阻断）。 -->
    <base-config cleartextTrafficPermitted="false" />
</network-security-config>
`);
write("android/app/src/main/res/xml/update_file_paths.xml", `<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <cache-path
        name="citizenapp_update_cache"
        path="." />
</paths>
`);
// Podfile和启动页正文沿用现有Flutter官方模板，不在脚本重复维护。
const podfile = join(process.env.FLUTTER_ROOT, 'packages/flutter_tools/templates/cocoapods/Podfile-ios');
write('ios/Podfile', readFileSync(podfile, 'utf8')
    .replace(/^# platform :ios.*$/m, "platform :ios, '16.0'")
    .replace('post_install do |installer|', `post_install do |installer|
  # 沿用Isar静态XCFramework实际输出，修正CocoaPods生成的输出列表。
  File.write(
    File.join(installer.sandbox.root.to_s, 'Target Support Files', 'isar_community_flutter_libs',
      'isar_community_flutter_libs-xcframeworks-output-files.xcfilelist'),
    "\${PODS_XCFRAMEWORKS_BUILD_DIR}/isar_community_flutter_libs/libisar.a\\n",
  )
`)
    .replace('flutter_additional_ios_build_settings(target)', `flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = ''
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end`));
write('ios/Runner/Base.lproj/CitizenLaunchScreen.storyboard',
    readFileSync(join(project, 'ios/Runner/Base.lproj/LaunchScreen.storyboard'), 'utf8')
        .replaceAll('LaunchImage', 'CitizenLaunchLogo')
        .replace('width="168" height="185"', 'width="160" height="160"'));
write("ios/Runner/Runner.entitlements", `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 这里只声明请求值；最终 APNs 环境以签名 provisioning profile 为唯一真源。 -->
    <key>aps-environment</key>
    <string>$(APS_ENVIRONMENT)</string>
</dict>
</plist>
`);
write("android/app/src/main/res/values/strings.xml", `<resources>
    <string name="app_name">公民</string>
</resources>
`);
write("android/app/src/main/res/values-en/strings.xml", `<resources>
    <string name="app_name">CitizenApp</string>
</resources>
`);
write("android/app/src/main/res/values/colors.xml", `<resources>
    <color name="ic_launcher_background">#18787D</color>
</resources>
`);
write("android/app/src/main/res/drawable/launch_background.xml", `<?xml version="1.0" encoding="utf-8"?>
<!-- Modify this file to customize your launch splash screen -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />

    <item>
        <bitmap
            android:gravity="center"
            android:src="@mipmap/launch_image" />
    </item>
</layer-list>
`);
write("android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml", `<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
`);
write("android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml", `<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
`);
// 保留Flutter生成的主题和桥接头，只生成产品图标所需的资源清单。
write('ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/Contents.json', JSON.stringify({
    images: [1, 2, 3].map(scale => ({
        filename: 'CitizenLaunchLogo' + (scale === 1 ? '' : '@' + scale + 'x') + '.png',
        idiom: 'universal', scale: scale + 'x',
    })),
    info: {version: 1, author: 'xcode'},
}, null, 2));
for (const [density, icon, foreground, launch] of [['mdpi',48,108,120], ['hdpi',72,162,180], ['xhdpi',96,216,240], ['xxhdpi',144,324,360], ['xxxhdpi',192,432,480]]) {
    const destination = 'android/app/src/main/res/mipmap-' + density + '/';
    for (const name of ['ic_launcher', 'ic_launcher_round']) copy('assets/logo/icon' + icon + '.png', destination + name + '.png');
    copy('assets/logo/foreground' + foreground + '.png', destination + 'ic_launcher_foreground.png');
    copy('assets/logo/launch' + launch + '.png', destination + 'launch_image.png');
}
write('android/app/src/main/res/drawable-v21/launch_background.xml', readFileSync(join(project, 'android/app/src/main/res/drawable/launch_background.xml'), 'utf8'));
const iconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/';
const icons = JSON.parse(readFileSync(join(project, iconSet, 'Contents.json')));
for (const image of icons.images) {
    if (!image.filename) continue;
    const size = Number(image.size.split('x')[0]) * Number(image.scale.replace('x', ''));
    copy('assets/logo/icon' + size + '.png', iconSet + image.filename);
}
for (const [scale, suffix] of [[1,''], [2,'@2x'], [3,'@3x']]) copy('assets/logo/launch' + 160 * scale + '.png', 'ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/CitizenLaunchLogo' + suffix + '.png');
writeFileSync(join(project, 'analysis_options.yaml'), 'include: package:flutter_lints/flutter.yaml\nanalyzer:\n  exclude:\n    - build/**\n    - android/**\n    - ios/**\n');
chmodSync(join(project, 'android/gradlew'), 0o755);
const sdkRoot = join(work, 'packages/citizen_sdk');
const values = {
    CITIZENSDK_SOURCE_DIR: sdkRoot,
    CITIZENSDK_ANDROID_BUILD_DIR: join(work,'citizen-android'),
    CITIZENSDK_TEST_CORE_LIB_PATH: join(sdkRoot,'darwin/CitizenSDK.xcframework/macos-arm64/CitizenSDK.framework/CitizenSDK'),
    TATACHATSDK_TEST_WORK_ROOT: work,
    TATACHATSDK_TEST_NATIVE_LIBRARY: join(work,'packages/tatachat_sdk/native/libtatachat_sdk.dylib')
};
Object.assign(environment,values);
if(environment.GITHUB_ENV)for (const [key, value] of Object.entries(values)) appendFileSync(environment.GITHUB_ENV, key + '=' + value + '\n');
return {project,values};
}

// 仅定位现有Flutter命令，不复核版本、引擎或组件完整性，不下载工具。
export function existingFlutter(platform, environment = process.env, candidates) {
 const paths = candidates || (environment.FLUTTER_ROOT ? [environment.FLUTTER_ROOT] : [
  ...(environment.PATH || '').split(':').filter(Boolean).map(path => resolve(path, '..')),
  ...readdirSync(dirname(root), {withFileTypes:true})
   .filter(entry => entry.isDirectory() && join(dirname(root), entry.name) !== resolve(root))
   .map(entry => join(dirname(root), entry.name, 'target/cache/flutter'))]);
 return paths.find(path => existsSync(join(path, 'bin/flutter')));
}

export async function compile(platform){
 const flutterRoot=existingFlutter(platform);
 const parent=join(root,'target/build');mkdirSync(parent,{recursive:true});
 if(realpathSync(parent)!==parent)throw Error('本机编译现场经过链接');
 const work=mkdtempSync(join(parent,'local-'));let safe=true;
 const cache=join(root,'target/cache');mkdirSync(cache,{recursive:true});
 const version=/^version:\s*([^+\s]+)(?:\+(\d+))?/mu.exec(readFileSync(join(root,'pubspec.yaml'),'utf8'));
 const environment={...process.env,GITHUB_WORKSPACE:root,WORK:work,PLATFORM:platform,
  CITIZENAPP_VERSION:version[1],CITIZENAPP_BUILD_NUMBER:version[2]||'1',
  FLUTTER_ROOT:flutterRoot,PUB_CACHE:process.env.PUB_CACHE||join(cache,'pub'),GRADLE_USER_HOME:process.env.GRADLE_USER_HOME||join(cache,'gradle'),
  CARGO_TARGET_DIR:join(cache,'rust'),RUSTUP_TOOLCHAIN:'1.97.1',
  PATH:process.env.HOME+'/.cargo/bin:'+process.env.HOME+'/.nvm/versions/node/v25.2.1/bin:'+(process.env.PATH||'/usr/bin:/bin'),
  ANDROID_HOME:process.env.ANDROID_HOME||join(process.env.HOME,'Library/Android/sdk'),
  JAVA_HOME:process.env.JAVA_HOME||'/Applications/Android Studio.app/Contents/jbr/Contents/Home'};
 delete environment.GH_TOKEN;delete environment.GITHUB_TOKEN;delete environment.GITHUB_ENV;
 try{
  environment.PATH=join(environment.FLUTTER_ROOT,'bin')+':'+environment.PATH;
  await assembleProject(environment);
  await build(platform,'dependencies',{local:true,work,environment});
  await build(platform,'app',{local:true,work,environment});
  const output=join(work,'artifact'),files=readdirSync(output).filter(name=>name.endsWith(platform==='ios'?'.app':'.apk'));
  const sdk=environment.ANDROID_HOME;
  process.stdout.write('TATA_COMPILE '+JSON.stringify({schema:1,product_id:'citizenapp',platform,work,artifact:join(output,files[0]),
   tools:platform==='android'?{adb:join(sdk,'platform-tools/adb'),apksigner:join(sdk,'build-tools/36.0.0/apksigner'),apkanalyzer:join(sdk,'cmdline-tools/latest/bin/apkanalyzer')}:{},
   environment:platform==='android'?{JAVA_HOME:environment.JAVA_HOME,ANDROID_HOME:sdk}:{}})+'\n');
  for await(const part of process.stdin) {} // 消费结束后再释放本轮现场。
  controller.signal.throwIfAborted();
 }catch(error){safe=!groups.size&&!error.keepWork;throw error;}finally{if(safe)rmSync(work,{recursive:true,force:true});}
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => controller.abort());
    try {
        if (process.argv[2] === 'compile') await compile(process.argv[3]);
        else await build(process.argv[2], process.argv[3]);
    } catch (error) {
        console.error(error.message);
        process.exitCode = 1;
    }
}
