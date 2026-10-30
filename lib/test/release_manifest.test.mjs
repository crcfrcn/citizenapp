import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawn, spawnSync} from 'node:child_process';
import {chmodSync, copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, lstatSync, rmSync, symlinkSync, writeFileSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {assembleProject,selectSDKRelease,existingFlutter,build} from '../../scripts/build.mjs';
import {describeAction} from '../../scripts/config.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const pubspec = readFileSync(join(root, 'pubspec.yaml'), 'utf8');
const pubLock = readFileSync(join(root, 'pubspec.lock'), 'utf8');
const podLock = readFileSync(join(root, 'ios/Podfile.lock'), 'utf8');

// 合成工具只记录编译调用和生成占位字节，不下载、不调用Flutter或真实签名。
function fixture(t, platform = 'android') {
    const base = join(root, 'target/test');
    mkdirSync(base, {recursive: true});
    const directory = mkdtempSync(join(base, 'compile-'));
    t.after(() => rmSync(directory, {recursive: true, force: true}));
    for (const path of ['scripts', 'bin', 'target/build/21-1/project']) {
        mkdirSync(join(directory, path), {recursive: true});
    }
    copyFileSync(join(root, 'scripts/build.mjs'), join(directory, 'scripts/build.mjs'));
    const executable = (name, code) => {
        const path = join(directory, 'bin', name);
        writeFileSync(path, '#!' + process.execPath + '\n' + code);
        chmodSync(path, 0o700);
    };
    executable('git', 'console.log("a".repeat(40));');
    executable('flutter', `
        const fs = require('node:fs'), path = require('node:path');
        fs.appendFileSync(process.env.CALLS, JSON.stringify(process.argv.slice(2)) + '\\n');
        if (process.env.HOLD) setInterval(() => {}, 1000);
        else {
            const format = process.argv[3];
            const file = format === 'apk' ? 'build/app/outputs/flutter-apk/app-release.apk' :
                format === 'appbundle' ? 'build/app/outputs/bundle/release/app-release.aab' :
                'build/ios/ipa/citizenapp.ipa';
            fs.mkdirSync(path.dirname(file), {recursive: true});
            fs.writeFileSync(file, 'fixture-' + format);
        }
    `);
    const env = {
        ...process.env, PATH: join(directory, 'bin') + ':' + process.env.PATH,
        GITHUB_ACTIONS: 'true', GITHUB_REPOSITORY: 'crcfrcn/citizenapp',
        GITHUB_REF: 'refs/heads/main', GITHUB_EVENT_NAME: 'workflow_dispatch',
        GITHUB_WORKFLOW_REF: 'crcfrcn/citizenapp/.github/workflows/' + platform + '.yml@refs/heads/main',
        GITHUB_RUN_ID: '21', GITHUB_RUN_ATTEMPT: '1', GITHUB_RUN_NUMBER: '9',
        GITHUB_SHA: 'a'.repeat(40), CITIZENAPP_VERSION: '1.2.3',
        WORK: join(directory, 'target/build/21-1'),
        FLUTTER_ROOT: directory, CALLS: join(directory, 'calls.jsonl'),
        GH_TOKEN: '', GITHUB_TOKEN: ''
    };
    return {directory, env, script: join(directory, 'scripts/build.mjs')};
}

test('编译入口直接调用Flutter并保留工具实际失败', t => {
    const value = fixture(t);
    writeFileSync(join(value.directory, 'bin/flutter'), '#!' + process.execPath + '\nconsole.error("Flutter合成错误");process.exit(17);\n');
    const result = spawnSync(process.execPath, [value.script, 'android'], {
        env:{...value.env,GITHUB_REPOSITORY:'other/product'},encoding:'utf8',
    });
    assert.notEqual(result.status,0);
    assert.match(result.stderr,/Flutter合成错误/);
    assert.doesNotMatch(result.stderr,/只能在本平台|自动化源码提交不一致/);
});

for (const platform of ['android', 'ios']) {
    test(platform + '只通过Flutter官方Release命令生成准确本轮文件', t => {
        const value = fixture(t, platform);
        const result = spawnSync(process.execPath, [value.script, platform], {env: value.env, encoding: 'utf8'});
        assert.equal(result.status, 0, result.stderr);
        const calls = readFileSync(value.env.CALLS, 'utf8').trim().split('\n').map(JSON.parse);
        assert.deepEqual(calls.map(args => args.slice(0, 2)), platform === 'android' ?
            [['build', 'apk'], ['build', 'appbundle']] : [['build', 'ipa']]);
        for (const args of calls) {
            assert.ok(args.includes('--release'));
            assert.equal(args[args.indexOf('--build-name') + 1], '1.2.3');
            assert.equal(args[args.indexOf('--build-number') + 1], '9');
            assert.equal(args.includes('--no-pub'), false);
        }
        const title = '公民·' + (platform === 'ios' ? 'iOS' : 'Android') + '·v1.2.3';
        const output = join(value.directory, 'target/build/21-1/artifact', title);
        for (const suffix of platform === 'ios' ? ['ipa'] : ['apk', 'aab']) {
            assert.ok(existsSync(output + '.' + suffix));
        }
        assert.equal(existsSync(join(value.directory, 'target/build/21-1/build-active.json')), false);
    });
}

test('准确任务现场被占用时拒绝第二次编译', t => {
    const value = fixture(t);
    const marker = join(value.directory, 'target/build/21-1/build-active.json');
    writeFileSync(marker, '{"pid":42,"groups":[]}');
    const result = spawnSync(process.execPath, [value.script, 'android'], {env: value.env, encoding: 'utf8'});
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /占用/);
    assert.equal(readFileSync(marker, 'utf8'), '{"pid":42,"groups":[]}');
    assert.equal(existsSync(value.env.CALLS), false);
});

test('本机编译使用本地构建号并保留Flutter的Release插件刷新', async t => {
    const value=fixture(t);
    await build('android','app',{local:true,work:value.env.WORK,
        environment:{...value.env,CITIZENAPP_BUILD_NUMBER:'40'}});
    const calls=readFileSync(value.env.CALLS,'utf8').trim().split('\n').map(JSON.parse);
    assert.equal(calls.length,1);
    assert.equal(calls[0][calls[0].indexOf('--build-number')+1],'40');
    assert.equal(calls[0].includes('--no-pub'),false);
    assert.equal(value.env.GITHUB_RUN_NUMBER,'9');
});

test('本机公开入口在GitHub完全不可用时仍先读取本地SDK', t => {
    const value=fixture(t);
    writeFileSync(join(value.directory,'pubspec.yaml'),pubspec);
    writeFileSync(join(value.directory,'pubspec.lock'),pubLock);
    // 合成git不创建SDK模块；到达本地模块加载后终止，禁止实际工具和网络。
    const code=`globalThis.fetch=()=>{throw Error('合成GitHub禁止调用')};
        const {compile}=await import(${JSON.stringify(pathToFileURL(value.script).href)});
        try{await compile('android')}catch(error){console.error(error.message);process.exitCode=17}`;
    const result=spawnSync(process.execPath,['--input-type=module','-e',code],{env:value.env,encoding:'utf8'});
    assert.equal(result.status,17);
    assert.match(result.stderr,/Cannot find module/);
    assert.doesNotMatch(result.stderr,/合成GitHub禁止调用|读取GitHub Run失败/);
    assert.equal(existsSync(value.env.CALLS),false);
});

for (const phase of ['app']) {
    test(phase + '取消等待真实合成工具退出后才释放本轮编译标记', {timeout: 15000}, async t => {
        const value = fixture(t);
        const child = spawn(process.execPath, [value.script, 'android', phase], {
            env: {...value.env, HOLD: '1'}, stdio: ['ignore', 'ignore', 'pipe']
        });
        t.after(() => { try { child.kill('SIGKILL'); } catch {} });
        const finished = new Promise(resolve => child.once('close', code => resolve(code)));
        for (let attempt = 0; attempt < 100 && !existsSync(value.env.CALLS); attempt++) {
            await new Promise(resolve => setTimeout(resolve, 30));
        }
        assert.ok(existsSync(value.env.CALLS));
        child.kill('SIGTERM');
        assert.notEqual(await finished, 0);
        assert.equal(existsSync(join(value.directory, 'target/build/21-1/build-active.json')), false);
    });
}

test('自动化复用正式SDK，依赖阶段不重新编译SDK', t => {
    const value = fixture(t);
    const result = spawnSync(process.execPath, [value.script, 'android', 'dependencies'], {env: value.env, encoding: 'utf8'});
    assert.equal(result.status, 0, result.stderr);
    assert.equal(existsSync(value.env.CALLS), false);
    assert.equal(existsSync(join(value.directory, 'target/build/21-1/build-active.json')), false);
});

test('宿主Core输入解析同轮Framework内部链接，真机组件不输出不存在的宿主库', t => {
    const base = join(root, 'target/test');
    mkdirSync(base, {recursive:true});
    const work = mkdtempSync(join(base, 'host-'));
    t.after(() => rmSync(work, {recursive:true, force:true}));
    const body = assembleProject.toString().split("const sdkRoot = join(work, 'packages/citizen_sdk');")[1].split('await preparePackages(')[0];
    assert.ok(body);
    const execute = new Function('join', 'work', 'existsSync', 'realpathSync', 'lstatSync', 'appendFileSync', 'environment',
        "const sdkRoot = join(work, 'packages/citizen_sdk');" + body + 'return values;');
    const environment = {CITIZENSDK_TEST_CORE_LIB_PATH:'/obsolete/Core', GITHUB_ENV:'/fixture/env'};
    let writes = [];
    const run = () => execute(join, work, existsSync, realpathSync, lstatSync, (file, value) => {
        assert.equal(file, '/fixture/env'); writes.push(value);
    }, environment);
    let values = run();
    assert.equal('CITIZENSDK_TEST_CORE_LIB_PATH' in values, false);
    assert.equal('CITIZENSDK_TEST_CORE_LIB_PATH' in environment, false);
    assert.ok(writes.every(value => !value.startsWith('CITIZENSDK_TEST_CORE_LIB_PATH=')));
    const framework = join(work, 'packages/citizen_sdk/darwin/CitizenSDK.xcframework/macos-arm64/CitizenSDK.framework');
    const core = join(framework, 'Versions/A/CitizenSDK');
    mkdirSync(dirname(core), {recursive:true});
    writeFileSync(core, 'same-run synthetic Core');
    symlinkSync('A', join(framework, 'Versions/Current'));
    symlinkSync('Versions/Current/CitizenSDK', join(framework, 'CitizenSDK'));
    writes = [];
    values = run();
    assert.equal(values.CITIZENSDK_TEST_CORE_LIB_PATH, realpathSync(core));
    assert.equal(environment.CITIZENSDK_TEST_CORE_LIB_PATH, realpathSync(core));
    assert.equal(lstatSync(values.CITIZENSDK_TEST_CORE_LIB_PATH).isSymbolicLink(), false);
    assert.ok(writes.includes('CITIZENSDK_TEST_CORE_LIB_PATH=' + realpathSync(core) + '\n'));
    rmSync(core);
    mkdirSync(core);
    assert.throws(run, /宿主测试Core不是普通文件/);
});

test('iOS在原锁版本核对后、工程装配前预缓存两种Apple引擎', () => {
    const workflow = readFileSync(join(root, '.github/workflows/ios.yml'), 'utf8');
    const version = workflow.indexOf('.frameworkVersion=="3.47.2"');
    const precache = workflow.indexOf('"$FLUTTER_ROOT/bin/flutter" precache --ios --macos');
    const compile = workflow.indexOf('await assembleProject(process.env)');
    assert.ok(version >= 0 && precache > version && compile > precache);
});

// 直接执行所属Workflow的真实正文，仅替换外部I/O；不复制版本或装配算法。
function workflowBody(platform, name) {
    if(name==='按本产品原锁装配普通工程')return assembleProject.toString().replaceAll('execute(','execFileSync(');
    const source = readFileSync(join(root, '.github/workflows/' + platform + '.yml'), 'utf8');
    const marker = name === '计算本Run版本' ? '        name: ' : '      - name: ';
    const step = source.split(marker + name + '\n')[1];
    assert.ok(step, '缺少所属Workflow步骤：' + name);
    const body = /<<'(JS|NODE)'\n([\s\S]*?)\n\s+\1(?:\n|$)/u.exec(step);
    assert.ok(body, '缺少所属Workflow的Node正文：' + name);
    return body[2].split('\n').map(line => line.slice(10)).filter(line => !line.startsWith('import ')).join('\n');
}
// 运行当前版本计算正文；GitHub返回与文件读取只在内存替换，不访问网络。
function versionFor(platform, {previous, artifacts = [], initial = '1.0.0', failure} = {}) {
    const calls = [], output = [];
    const execute = new Function('execFileSync', 'readFileSync', 'process', 'console', workflowBody(platform, '计算本Run版本'));
    return {calls, run: () => {
        execute((command, args) => {
            assert.equal(command, 'gh');
            assert.deepEqual(args, ['api', 'repos/crcfrcn/citizenapp/actions/runs/' + previous.id + '/artifacts?per_page=100']);
            calls.push(args);
            if (failure) throw failure;
            return JSON.stringify({artifacts});
        }, path => {
            if (path === 'pubspec.yaml') return 'version: ' + initial + '+1\n';
            assert.equal(path, '/fixture/previous.json');
            return JSON.stringify({workflow_runs:previous ? [previous] : []});
        }, {env:{RUNNER_TEMP:'/fixture', GITHUB_REPOSITORY:'crcfrcn/citizenapp'}}, {log:value => output.push(value)});
        assert.equal(output.length, 1);
        return output[0];
    }};
}
for (const platform of ['ios', 'android']) {
    const label = platform === 'ios' ? 'iOS' : 'Android';
    test(platform + '首次使用本仓版本，只从成功Run完整Artifact递增', () => {
        const workflow = readFileSync(join(root, '.github/workflows/' + platform + '.yml'), 'utf8');
        assert.match(workflow, /runs\?branch=main&event=workflow_dispatch&status=success&per_page=1/u, '失败和当前活动Run不进入官方成功记录查询');
        const first = versionFor(platform, {initial:'1.2.3'});
        assert.equal(first.run(), 'version=1.2.3');
        assert.equal(first.calls.length, 0);
        const value = versionFor(platform, {previous:{id:10, display_title:'公民·' + label + '·10'}, artifacts:[
            {name:'其他产品·v9.9.9'}, {name:'公民·' + label + '·v1.0.99·内部'}, {name:'公民·' + label + '·v1.0.99'}
        ]});
        assert.equal(value.run(), 'version=1.0.100');
        assert.equal(value.calls.length, 1);
    });
    test(platform + '成功Artifact缺失或API失败时原样失败，不猜版本', () => {
        for (const artifacts of [[], [{name:'公民·' + label + '·10'}], [{name:'公民·' + label + '·v1.0.1·内部'}]]) {
            assert.throws(versionFor(platform, {previous:{id:10}, artifacts}).run, TypeError);
        }
        const failure = new Error('合成GitHub读取错误');
        assert.throws(versionFor(platform, {previous:{id:10}, failure}).run, error => error === failure);
    });
    test(platform + '平台装配正文读取真实原件并生成必要标准配置', () => {
        const all = workflowBody(platform, '按本产品原锁装配普通工程');
        const body = all.slice(all.indexOf('// Flutter官方模板'), all.indexOf("const sdkRoot = join(work, 'packages/citizen_sdk');"));
        {
            const files = new Map(), copies = [], tools = [], removed = [], prepared = [];
            const project = '/fixture/project';
            const icon = project + '/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json';
            const fsRead = path => {
                if (files.has(path)) return files.get(path);
                if (path === icon) return JSON.stringify({images:[{size:'20x20',scale:'2x',filename:'Icon-App-20x20@2x.png'}]});
                if (path === '/fixture/flutter/packages/flutter_tools/templates/cocoapods/Podfile-ios') {
                    return "# platform :ios, '15.0'\nflutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))\npost_install do |installer|\nflutter_additional_ios_build_settings(target)\nend\n";
                }
                throw Error('未声明读取：' + path);
            };
            new Function('execFileSync', 'readFileSync', 'writeFileSync', 'appendFileSync', 'mkdirSync', 'copyFileSync', 'chmodSync', 'rmSync', 'readdirSync',
                'join', 'dirname', 'root', 'work', 'project', 'process', 'lock', 'prepareTests', body)(
                (command,args) => {
                    assert.equal(command, '/fixture/flutter/bin/flutter', '装配不得调用未声明工具');
                    assert.equal(args[0], 'create');
                    tools.push([command,args]);
                    // 对应原锁Flutter的create：--no-pub仍会用模板依赖重写工程锁。
                    files.set(project + '/pubspec.lock', '{"packages":{}}');
                    files.set(project + '/android/build.gradle.kts', 'rootProject.layout.buildDirectory.dir("../../build")');
                    files.set(project + '/android/settings.gradle.kts', 'plugins { id("dev.flutter.flutter-plugin-loader") version "1.0.0"\nid("com.android.application") version "8.0.0" apply false\nid("org.jetbrains.kotlin.android") version "2.0.0" apply false }\ninclude(":app")');
                    files.set(project + '/android/gradle.properties', 'android.useAndroidX=true\n');
                    files.set(project + '/android/gradle/wrapper/gradle-wrapper.properties', 'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.0.0-bin.zip\n');
                    files.set(project + '/ios/Runner/Base.lproj/LaunchScreen.storyboard', '<image name="LaunchImage" width="168" height="185"/>');
                    files.set(project + '/android/app/src/main/res/values/styles.xml', 'Flutter官方主题');
                    files.set(project + '/ios/Runner/Runner-Bridging-Header.h', '#import "GeneratedPluginRegistrant.h"');
                }, fsRead, (path,text) => files.set(path,text),
                (path,text) => files.set(path,(files.get(path)||'')+text), () => {},
                (source,destination) => copies.push([source,destination]), () => {}, path => removed.push(path),
                path => { assert.equal(path,'/fixture/source/android/tests');return ['MlsTransportSecurityInstrumentedTest.kt','RegistrationRecordSecurityInstrumentedTest.kt','SquareMediaChannelInstrumentedTest.kt']; }, join, dirname,
                '/fixture/source','/fixture',project,{env:{FLUTTER_ROOT:'/fixture/flutter'}},pubLock, path=>prepared.push(path));
            assert.equal(tools.length, 1, '只允许本轮Flutter模板生成命令');
            assert.ok(tools[0][1].includes('--platforms=android,ios'));
            assert.equal(files.get(project + '/pubspec.lock'), pubLock, '模板生成后必须完整恢复传入的锁，不重新解版本');
            assert.ok(removed.includes(project + '/test'));
            assert.ok(!removed.includes(project + '/lib/test'));
            assert.deepEqual(prepared,[project]);
            assert.ok(removed.every(path => path.startsWith(project + '/')), '不得删除产品源码');
            assert.ok(copies.some(([source,target]) => source.endsWith('ios/project/Runner.pbxproj') && target.endsWith('Runner.xcodeproj/project.pbxproj')));
            assert.ok(copies.some(([source,target]) => source.endsWith('android/square/SquareMediaChannel.kt') && target.endsWith('src/main/SquareMediaChannel.kt')));
            assert.ok(copies.some(([source,target]) => source.endsWith('assets/logo/icon40.png') && target.endsWith('Icon-App-20x20@2x.png')));
            assert.match(files.get(project+'/android/app/src/main/res/values/strings.xml'), /<string name="app_name">公民<\/string>/);
            assert.match(files.get(project+'/android/app/src/main/res/values-en/strings.xml'), />CitizenApp</);
            assert.match(files.get(project+'/android/app/src/main/res/xml/network_security_config.xml'), /cleartextTrafficPermitted="false"/);
            assert.match(files.get(project+'/ios/Runner/Runner.entitlements'), /\$\(APS_ENVIRONMENT\)/);
            assert.match(files.get(project+'/ios/Podfile'), /flutter_install_all_ios_pods/);
            assert.match(files.get(project+'/ios/Podfile'), /isar_community_flutter_libs\/libisar\.a/);
            assert.equal(files.get(project+'/android/app/src/main/res/values/styles.xml'), 'Flutter官方主题');
            assert.equal(files.get(project+'/ios/Runner/Runner-Bridging-Header.h'), '#import "GeneratedPluginRegistrant.h"');
            assert.match(files.get(project+'/ios/Runner/Base.lproj/CitizenLaunchScreen.storyboard'), /name="CitizenLaunchLogo" width="160" height="160"/);
            assert.match(files.get(project+'/android/gradle.properties'), /android\.builtInKotlin=false/);
            assert.match(files.get(project+'/android/gradle/wrapper/gradle-wrapper.properties'), /gradle-9\.1\.0-bin\.zip/);
        }
    });
}

for (const platform of ['ios', 'android']) {
    test(platform + '从真实包根URI定位Isar，保留包名、版本及转义目录', () => {
        const execute = new Function('readFileSync', 'copyFileSync', 'appendFileSync', 'fileURLToPath', 'join', 'process',
            workflowBody(platform, '准备原生测试输入'));
        const cases = [
            ['file:///fixture/cache/isar_community_flutter_libs-3.3.2', '/fixture/cache'],
            ['../../cache/isar_community_flutter_libs-3.3.2', '/fixture/cache'],
            ['file:///fixture/cache%20pub/isar_community_flutter_libs-3.3.2', '/fixture/cache pub'],
            ['../../cache%20pub/isar_community_flutter_libs-3.3.2', '/fixture/cache pub']
        ];
        for (const [uri, parent] of cases) {
            for (const suffix of ['', '/']) {
                const copies = [], writes = [];
                execute(file => {
                    assert.equal(file.href, 'file:///fixture/project/.dart_tool/package_config.json');
                    return JSON.stringify({packages:[{name:'isar_community_flutter_libs',rootUri:uri + suffix}]});
                }, (...args) => copies.push(args), (...args) => writes.push(args), fileURLToPath, join,
                {cwd:() => '/fixture/project',env:{WORK:'/fixture/work',GITHUB_ENV:'/fixture/env'}});
                assert.deepEqual(copies, [[parent + '/isar_community_flutter_libs-3.3.2/macos/libisar.dylib', '/fixture/work/libisar.dylib']]);
                assert.deepEqual(writes, [
                    ['/fixture/env', 'ISAR_CORE_LIB_PATH=/fixture/work/libisar.dylib\n'],
                    ['/fixture/env', 'CITIZENAPP_TEST_WORK_DIR=/fixture/work\n']
                ]);
            }
        }
        for (const missing of ['package', 'library']) {
            const writes = [];
            assert.throws(() => execute(() => JSON.stringify({packages:missing === 'package' ? [] :
                [{name:'isar_community_flutter_libs',rootUri:cases[0][0]}]}),
            () => { throw Error('ENOENT'); }, (...args) => writes.push(args), fileURLToPath, join,
            {cwd:() => '/fixture/project',env:{WORK:'/fixture/work',GITHUB_ENV:'/fixture/env'}}),
            missing === 'package' ? /原锁缺少Isar/ : /ENOENT/);
            assert.deepEqual(writes, [], '缺包或缺库必须原样失败，不写入成功环境');
        }
    });
}

// 固定链金标仍归链源码；这里只检查产品依赖来源，真实ABI与业务回归由原命令执行。
test('两项SDK声明main，仓库锁保留基线提交且无需人工追更', () => {
    for (const name of ['citizen_sdk', 'tatachat_sdk']) {
        const declaration = pubspec.split('  ' + name + ':\n')[1]?.split(/\n  \S/)[0];
        const record = pubLock.split('\n  ' + name + ':\n')[1]?.split(/\n  \S/)[0];
        const ref = /resolved-ref: ([a-f0-9]{40})/.exec(record || '')?.[1];
        assert.ok(ref && declaration?.includes('ref: main') && record.includes('ref: main'));
    }
    assert.ok(podLock.includes('PODS:'));
});

test('CitizenApp不重复声明SDK内部依赖或未使用的协议生成器', () => {
    assert.doesNotMatch(pubspec, /^  (?:cupertino_icons|protoc_plugin|build_runner|isar_community_generator|camera|record|just_audio|protobuf|fixnum|blurhash_dart):/mu);
    assert.match(pubspec, /dev_dependencies:[\s\S]*^  image: 4[.]9[.]1$/mu);
});

test('CitizenApp二维码非UI能力只由SDK提供', () => {
    for (const source of [pubspec, pubLock]) assert.doesNotMatch(source, /^  (?:qr|qr_flutter|mobile_scanner):/mu);
    assert.doesNotMatch(podLock, /mobile_scanner/u);
    const preview = readFileSync(join(root, 'scanner/lib/scanner_view.dart'), 'utf8');
    const display = readFileSync(join(root, 'scanner/lib/qr_display_scaffold.dart'), 'utf8');
    assert.match(preview, /qr[.]openCapture\(purpose\)/u);
    assert.match(preview, /Texture\(textureId: capture[.]textureId\)/u);
    assert.match(display, /qr[.]encode\(widget[.]data, scale: 1\)/u);
    const caller = readFileSync(join(root, 'lib/scan_dispatch_flow.dart'), 'utf8');
    assert.ok(caller.includes("import 'package:citizen_sdk/citizen_sdk.dart';"));
    assert.equal(caller.includes('package:citizen_sdk/src/'), false);
});

test('SDK自动选择最新成功正式版，本机与自动化使用独立消费路径', async t => {
    const builder = readFileSync(join(root, 'scripts/build.mjs'), 'utf8');
    for (const platform of ['ios', 'android']) {
        const workflow = readFileSync(join(root, '.github/workflows', platform + '.yml'), 'utf8');
        assert.doesNotMatch(workflow, /sdk_run|CITIZENSDK_PACKAGE|CITIZENSDK_ATTEMPT/u);
        assert.match(workflow, /await assembleProject\(process.env\)/u);
    }
    assert.match(builder, /rev-parse', 'refs\/heads\/main'/u);
    assert.match(builder, /sdk\.consume\(/u);
    assert.doesNotMatch(builder, /请指定已成功|缺少本产品原锁的完整SDK交付目录/u);
    const proof = {product_id:'citizensdk',platform:'sdk',software_version:'1.0.1',
        git_commit_sha:'a'.repeat(40),producer_run_id:8,producer_run_attempt:1};
    const release = {id:8,tag_name:'公民SDK·SDK·v1.0.1',draft:false,prerelease:false,
        published_at:'2026-10-22',body:JSON.stringify(proof)};
    const run = {id:8,status:'completed',conclusion:'success',head_sha:proof.git_commit_sha,run_attempt:1};
    const rows = [release,{...release,id:9,draft:true,body:JSON.stringify({...proof,software_version:'1.0.9'})}];
    const read = async path => path.startsWith('releases?') ? rows : run;
    assert.equal((await selectSDKRelease('citizensdk',read)).release.id,8);
    await assert.rejects(selectSDKRelease('citizensdk',async () => []),/没有可用/);
    await assert.rejects(selectSDKRelease('citizensdk',async path =>
        path.startsWith('releases?') ? rows : {...run,conclusion:'failure'}),/没有可用/);
    const action = await describeAction({flow:'release',platform:'android'});
    assert.deepEqual(action,{repository:'crcfrcn/citizenapp',workflow:'android.yml',ref:'main',inputs:{}});
    // 仅定位现有工具；不新增目录门禁，本机可使用标准工具的离线参数。
    const value = fixture(t), tool = join(value.directory, 'flutter');
    mkdirSync(join(tool,'bin'),{recursive:true});writeFileSync(join(tool,'bin/flutter'),'fixture');
    assert.equal(existingFlutter('android',{},[tool]),tool);
    assert.equal(existingFlutter('ios',{},[tool]),tool);
    assert.doesNotMatch(builder,/requireAutomationBuild|sandbox-exec|CITIZENAPP_OFFLINE|缺少SDK声明的现有ZXing/);

});

// 两种SDK共用相同正式回执；读取替身只返回GitHub公开记录，不访问网络或下载组件。
function sdkVersion(product, version, id, attempt = 1) {
    const proof = {product_id:product,platform:'sdk',software_version:version,
        git_commit_sha:id.toString(16).padStart(40,'0'),producer_run_id:id,producer_run_attempt:attempt};
    return {
        release:{id,tag_name:product + '-v' + version,draft:false,prerelease:false,
            published_at:'2026-10-28',body:JSON.stringify(proof)},
        run:{id,status:'completed',conclusion:'success',head_sha:proof.git_commit_sha,run_attempt:attempt}
    };
}
for (const product of ['citizensdk', 'tatachatsdk']) {
    test(product + '分页后按数值版本选择最新成功正式包，忽略不合格Release', async () => {
        const failed = sdkVersion(product,'2.0.0',30), latest = sdkVersion(product,'1.0.10',10,2);
        const older = sdkVersion(product,'1.0.2',200), calls = [];
        const invalid = sdkVersion(product,'9.0.0',40).release;
        const pages = [
            [failed.release,...Array.from({length:99},() => ({...invalid,body:'null'}))],
            [older.release, latest.release, {...invalid,draft:true}, {...invalid,prerelease:true},
                {...invalid,published_at:null}, {...invalid,body:'invalid JSON'},
                sdkVersion('other','9.0.0',41).release, sdkVersion(product,'invalid',42).release,
                {...invalid,body:JSON.stringify({product_id:product,platform:'sdk',software_version:'9.0.0'})}]
        ];
        const selected = await selectSDKRelease(product, async path => {
            calls.push(path);
            if (path === 'releases?per_page=100&page=1') return pages[0];
            if (path === 'releases?per_page=100&page=2') return pages[1];
            if (path === 'actions/runs/30/attempts/1') return {...failed.run,conclusion:'failure'};
            assert.equal(path,'actions/runs/10/attempts/2');
            return latest.run;
        });
        assert.equal(selected.release,latest.release);
        assert.equal(selected.proof.git_commit_sha,latest.run.head_sha);
        assert.deepEqual(calls,['releases?per_page=100&page=1','releases?per_page=100&page=2',
            'actions/runs/30/attempts/1','actions/runs/10/attempts/2']);
    });
    test(product + '只承认准确Run和attempt成功且源码一致的正式版本', async () => {
        const latest = sdkVersion(product,'1.0.2',20,2), older = sdkVersion(product,'1.0.1',10);
        for (const change of [
            {status:'in_progress',conclusion:null}, {conclusion:'failure'}, {conclusion:'cancelled'},
            {id:21}, {run_attempt:1}, {head_sha:'f'.repeat(40)}
        ]) {
            const selected = await selectSDKRelease(product, async path => {
                if (path.startsWith('releases?')) return [older.release,latest.release];
                if (path === 'actions/runs/20/attempts/2') return {...latest.run,...change};
                assert.equal(path,'actions/runs/10/attempts/1');
                return older.run;
            });
            assert.equal(selected.release,older.release);
        }
        assert.equal((await selectSDKRelease(product,async path => {
            if (path.startsWith('releases?')) return [latest.release];
            assert.equal(path,'actions/runs/20/attempts/2','不能读取整个Run的最新attempt冒充生产来源');
            return latest.run;
        })).release,latest.release);
    });
    test(product + '无成功正式版或真实读取失败就停止，不以旧包掩盖错误', async () => {
        const latest = sdkVersion(product,'1.0.2',20), older = sdkVersion(product,'1.0.1',10);
        await assert.rejects(selectSDKRelease(product,async () => []),/没有可用/);
        await assert.rejects(selectSDKRelease(product,async path =>
            path.startsWith('releases?') ? [latest.release] : {...latest.run,conclusion:'failure'}),/没有可用/);
        for (const stage of ['releases', 'attempt']) {
            const failure = new Error('合成GitHub读取失败'), calls = [];
            await assert.rejects(selectSDKRelease(product,async path => {
                calls.push(path);
                if (path.startsWith('releases?') && stage !== 'releases') return [older.release,latest.release];
                throw failure;
            }),error => error === failure);
            assert.equal(calls.includes('actions/runs/10/attempts/1'),false);
        }
    });
}

// 直接执行App装配函数中的真实资源正文，不另建功能构建入口或复制实现。
test('App普通装配生成随包资源，库或资源工具失败不得继续', async () => {
    const source = assembleProject.toString();
    const start = source.indexOf('// App随包资源随普通工程一起准备，不增加功能构建入口。');
    assert.ok(start >= 0);
    const body = source.slice(start, source.indexOf('return {project,values};', start));
    const execute = new Function('join', 'project', 'environment', 'run', 'return (async () => {' + body + '})();');
    for (const failure of [null, 'npm', '/fixture/esbuild']) {
        const calls = [], error = new Error('合成工具失败');
        const result = execute(join, '/fixture/project', {ESBUILD_BIN:'/fixture/esbuild'}, async (...args) => {
            calls.push(args);
            if (args[0] === failure) throw error;
        });
        if (failure) await assert.rejects(result, actual => actual === error);
        else await result;
        assert.equal(calls.length, failure === 'npm' ? 1 : 2);
        assert.deepEqual(calls[0].slice(0, 3), ['npm', ['ci', '--ignore-scripts', '--no-audit', '--no-fund'], '/fixture/project/transaction/web']);
        assert.equal(calls[0][4].npm_config_ignore_scripts, 'true');
        if (calls.length === 2) {
            assert.equal(calls[1][0], '/fixture/esbuild');
            assert.ok(calls[1][1].includes('--outfile=walletconnect.bundle.js'));
            assert.equal(calls[1][2], '/fixture/project/transaction/web');
        }
    }
    const declaration = JSON.parse(readFileSync(join(root, 'transaction/web/package.json')));
    for (const platform of ['ios', 'android']) {
        const workflow = readFileSync(join(root, '.github/workflows/' + platform + '.yml'), 'utf8');
        const tools = workflow.slice(workflow.indexOf('      - name: 准备官方工具和本轮目录'), workflow.indexOf('      - name: 按本产品原锁装配普通工程'));
        assert.match(tools, /citizenapp[.]tools[.]esbuild/);
        assert.match(tools, /ESBUILD_BIN/);
        assert.doesNotMatch(workflow, /name: 准备本轮充值构建工具/);
    }
    assert.equal(declaration.citizenapp.tools.esbuild, '0.28.1');
});

// 直接执行所属Workflow的清理正文；gh替身只操作本轮JSON现场，不访问网络。
function cleanupGithub() {
    const fs = require('node:fs');
    const path = process.env.CLEANUP_STATE;
    const state = JSON.parse(fs.readFileSync(path, 'utf8'));
    const args = process.argv.slice(2);
    fs.appendFileSync(process.env.CLEANUP_CALLS, JSON.stringify(args) + '\n');
    const missing = (status = 404) => {
        process.stdout.write('HTTP/2.0 ' + status + '\n');
        process.exit(status === 404 ? 4 : 7);
    };
    const save = () => fs.writeFileSync(path, JSON.stringify(state));
    if (args[0] === 'run' && args[1] === 'delete') {
        const id = Number(args[2]);
        state.runs = state.runs.filter(run => run.id !== id);
        if (!state.keepArtifacts) state.artifacts = state.artifacts.filter(a => a.workflow_run.id !== id);
        save();
        return;
    }
    if (args[0] !== 'api') process.exit(90);
    const request = args.at(-1).replace('repos/crcfrcn/citizenapp/', '').split('?')[0];
    const method = args.includes('--method') ? args[args.indexOf('--method') + 1] : 'GET';
    if (method === 'GET' && state.denied?.[request]) missing(state.denied[request]);
    let value;
    if (request.startsWith('actions/workflows/')) value = {workflow_runs: state.runs};
    else if (request === 'releases') value = state.releases;
    else if (request === 'actions/caches') value = {actions_caches: state.caches};
    else if (request === 'actions/artifacts') value = {artifacts: state.artifacts};
    else if (request.startsWith('git/matching-refs/tags/')) {
        const prefix = decodeURIComponent(request.slice('git/matching-refs/tags/'.length));
        value = Object.entries(state.tags).filter(([tag]) => tag.startsWith(prefix))
            .map(([tag, object]) => ({ref:'refs/tags/' + tag, object}));
    } else if (/^git\/refs?\/tags\//u.test(request)) {
        const tag = decodeURIComponent(request.replace(/^git\/refs?\/tags\//u, ''));
        if (!state.tags[tag]) missing();
        if (method === 'DELETE') delete state.tags[tag];
        else value = {object:state.tags[tag]};
    } else if (/^releases\/[0-9]+$/u.test(request)) {
        const id = Number(request.split('/')[1]);
        value = state.releases.find(release => release.id === id);
        if (!value) missing();
        if (method === 'DELETE' && state.undeletedRelease !== id) state.releases = state.releases.filter(r => r.id !== id);
    } else if (/^actions\/runs\/[0-9]+(?:\/logs)?$/u.test(request)) {
        const id = Number(request.split('/')[2]);
        value = [...state.runs, ...(state.foreignRuns ?? [])].find(run => run.id === id);
        if (!value) missing();
    } else if (/^actions\/caches\/[0-9]+$/u.test(request)) {
        const id = Number(request.split('/')[2]);
        if (method !== 'DELETE') process.exit(91);
        if (!state.keepCaches) state.caches = state.caches.filter(cache => cache.id !== id);
    } else process.exit(92);
    if (method === 'DELETE') { save(); return; }
    if (args.includes('--silent')) process.stdout.write('HTTP/2.0 200\n');
    else process.stdout.write(JSON.stringify(args.includes('--slurp') ? [value] : value));
}
function cleanupCase(t, platform) {
    const base = join(root, 'target/test');
    mkdirSync(base, {recursive:true});
    const directory = mkdtempSync(join(base, 'cleanup-'));
    t.after(() => rmSync(directory, {recursive:true, force:true}));
    mkdirSync(join(directory, 'bin'));
    writeFileSync(join(directory, 'bin/gh'), '#!' + process.execPath + '\n(' + cleanupGithub.toString() + ')();\n', {mode:0o700});
    const label = platform === 'ios' ? 'iOS' : 'Android';
    const sha = id => id.toString(16).padStart(2, '0').repeat(20);
    const run = (id, status, conclusion) => ({id,status,conclusion,run_number:id,head_sha:sha(id),run_attempt:1,
        display_title:'公民·' + label + '·' + id});
    const release = id => ({id:id + 100,tag_name:'公民·' + label + '·v1.0.' + id,target_commitish:sha(id),
        body:JSON.stringify({product_id:'citizenapp',platform,version:'1.0.' + id,source_sha:sha(id),run_id:id,run_attempt:1})});
    const state = {runs:[run(20,'in_progress',null),run(19,'in_progress',null),run(18,'completed','failure'),
        run(11,'completed','failure'),run(10,'completed','success')],
        releases:[20,19,18,11,10].map(release), tags:{},
        caches:[10,20].map(id => ({id,key:'citizenapp-' + platform + '-source-' + id + '-1',ref:'refs/heads/main'})),
        artifacts:[10,20].map(id => ({id,workflow_run:{id}}))};
    for (const value of state.releases) state.tags[value.tag_name] = {type:'commit',sha:value.target_commitish};
    state.releases.push({id:999,tag_name:'另一个产品·v1.0.0',body:'not-owned'});
    state.tags['另一个产品·v1.0.0'] = {type:'commit',sha:sha(99)};
    state.caches.push({id:99,key:'citizenapp-other-source-99-1',ref:'refs/heads/main'});
    const file = join(directory, 'state.json'), calls = join(directory, 'calls.jsonl');
    const workflow = readFileSync(join(root, '.github/workflows/' + platform + '.yml'), 'utf8');
    assert.equal(workflow.includes('删除本平台旧记录及附属数据并回查'), false);
    const section = workflow.slice(workflow.indexOf('  cleanup:\n'));
    const body = section.split('        run: |\n')[1].split('\n')
        .map(line => line.startsWith('          ') ? line.slice(10) : line).join('\n');
    return {state,release,sha,execute(result='success') {
        writeFileSync(file, JSON.stringify(state));
        writeFileSync(calls, '');
        const completed = spawnSync('/bin/bash', ['-euo','pipefail','-c',body], {cwd:directory,encoding:'utf8',
            env:{...process.env,PATH:join(directory,'bin') + ':/usr/bin:/bin',GH_TOKEN:'',GITHUB_TOKEN:'',
                GITHUB_REPOSITORY:'crcfrcn/citizenapp',GITHUB_RUN_ID:'20',PLATFORM:platform,RESULT:result,
                CLEANUP_STATE:file,CLEANUP_CALLS:calls}});
        return {...completed,state:JSON.parse(readFileSync(file,'utf8')),
            calls:readFileSync(calls,'utf8').trim().split('\n').filter(Boolean).map(JSON.parse)};
    }};
}
for (const platform of ['ios', 'android']) {
    test(platform + '清理按Run回执保护当前Release，编号显示名不作为Tag', t => {
        const f = cleanupCase(t,platform), r = f.execute();
        assert.equal(r.status,0,r.stderr);
        assert.deepEqual(r.state.runs.map(v => v.id),[20,19,18]);
        assert.deepEqual(r.state.releases.map(v => v.id),[120,119,118,999]);
        assert.deepEqual(r.state.caches.map(v => v.id),[20,99]);
        assert.deepEqual(r.state.artifacts.map(v => v.id),[20]);
        assert.ok(r.state.tags['另一个产品·v1.0.0']);
        Object.assign(f.state,r.state);
        const repeated = f.execute();
        assert.equal(repeated.status,0,repeated.stderr);
        assert.ok(repeated.calls.every(args => !args.includes('DELETE') && args[0] !== 'run'));
    });
    test(platform + '失败或取消保留上一成功、当前失败及活动Run', t => {
        const f = cleanupCase(t,platform), r = f.execute('failure');
        assert.equal(r.status,0,r.stderr);
        assert.deepEqual(r.state.runs.map(v => v.id),[20,19,10]);
        assert.deepEqual(r.state.releases.map(v => v.id),[120,119,110,999]);
    });
    test(platform + '最新终态按官方run_number选择，不依赖列表顺序或ID大小', t => {
        const f = cleanupCase(t,platform);
        f.state.runs.find(run => run.id === 11).run_number = 99;
        f.state.runs.reverse();
        const r = f.execute();
        assert.equal(r.status,0,r.stderr);
        assert.deepEqual(r.state.runs.map(v => v.id).sort((a,b) => a-b),[11,19,20]);
    });
    test(platform + 'Run已真实404的旧Release按原回执清理', t => {
        const f = cleanupCase(t,platform), release = f.release(6);
        f.state.releases.unshift(release);
        f.state.tags[release.tag_name] = {type:'commit',sha:f.sha(6)};
        const r = f.execute();
        assert.equal(r.status,0,r.stderr);
        assert.ok(!r.state.releases.some(v => v.id === release.id));
        assert.equal(r.state.tags[release.tag_name],undefined);
    });
    test(platform + '旧Release的Tag已404仍能清理且回查', t => {
        const f = cleanupCase(t,platform), release = f.release(6);
        f.state.releases.unshift(release);
        const r = f.execute();
        assert.equal(r.status,0,r.stderr);
        assert.ok(!r.state.releases.some(v => v.id === release.id));
    });
    for (const status of [403,500]) test(platform + '来源读取HTTP' + status + '不能冒充404', t => {
        const f = cleanupCase(t,platform), release = f.release(6);
        f.state.releases.unshift(release);
        f.state.tags[release.tag_name] = {type:'commit',sha:f.sha(6)};
        f.state.denied = {'actions/runs/6':status};
        const r = f.execute();
        assert.notEqual(r.status,0);
        assert.ok(r.state.releases.some(v => v.id === release.id));
        assert.ok(r.calls.every(args => !args.includes('DELETE') && args[0] !== 'run'));
    });
    test(platform + '仍存在但不属于当前Workflow的来源禁止认领', t => {
        const f = cleanupCase(t,platform), release = f.release(6);
        f.state.releases.unshift(release);
        f.state.foreignRuns = [{id:6}];
        const r = f.execute();
        assert.notEqual(r.status,0);
        assert.ok(r.state.releases.some(v => v.id === release.id));
    });
    for (const kind of ['receipt','source','tag']) test(platform + kind + '归属错误保留目标对象', t => {
        const f = cleanupCase(t,platform), release = f.state.releases[0];
        if (kind === 'receipt') release.body = '{}';
        if (kind === 'source') release.target_commitish = f.sha(99);
        if (kind === 'tag') {
            const old = f.state.releases.find(v => v.id === 110);
            f.state.tags[old.tag_name].sha = f.sha(99);
        }
        const r = f.execute();
        assert.notEqual(r.status,0);
        assert.ok(r.state.releases.some(v => v.id === (kind === 'tag' ? 110 : 120)));
    });
    test(platform + '无回执孤立Tag不按显示名猜归属', t => {
        const f = cleanupCase(t,platform), tag = f.release(6).tag_name;
        f.state.tags[tag] = {type:'commit',sha:f.sha(6)};
        const r = f.execute();
        assert.notEqual(r.status,0);
        assert.ok(r.state.tags[tag]);
        assert.ok(!r.calls.some(args => args.includes('DELETE') && args.at(-1).includes(encodeURIComponent(tag))));
    });
    for (const remaining of ['release','cache','artifact']) test(platform + remaining + '删除未实际完成必须失败', t => {
        const f = cleanupCase(t,platform);
        if (remaining === 'release') f.state.undeletedRelease = 111;
        if (remaining === 'cache') f.state.keepCaches = true;
        if (remaining === 'artifact') f.state.keepArtifacts = true;
        const r = f.execute();
        assert.notEqual(r.status,0);
    });
}
