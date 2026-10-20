import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawn, spawnSync} from 'node:child_process';
import {chmodSync, copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {requireAutomationBuild} from '../scripts/build.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
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
        FLUTTER_ROOT: directory, CALLS: join(directory, 'calls.jsonl'),
        GH_TOKEN: '', GITHUB_TOKEN: ''
    };
    return {directory, env, script: join(directory, 'scripts/build.mjs')};
}

test('普通本机、错误工作流及非法版本在任何工程写入前拒绝', () => {
    for (const environment of [
        {}, {GITHUB_ACTIONS: 'true'},
        {GITHUB_ACTIONS: 'true', GITHUB_REPOSITORY: 'other/product'},
        {GITHUB_ACTIONS: 'true', CITIZENAPP_VERSION: '1.2.3\n'}
    ]) {
        assert.throws(() => requireAutomationBuild('android', environment), /只能/);
    }
    assert.throws(() => requireAutomationBuild('macos', {}), /只能/);
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

test('取消等待真实合成工具退出后才释放本轮编译标记', {timeout: 15000}, async t => {
    const value = fixture(t);
    const child = spawn(process.execPath, [value.script, 'android'], {
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

test('原生依赖入口失败阻止后续App编译', t => {
    const value = fixture(t);
    mkdirSync(join(value.directory, 'target/build/21-1/sources/citizen_sdk'), {recursive: true});
    const result = spawnSync(process.execPath, [value.script, 'android', 'dependencies'], {env: value.env, encoding: 'utf8'});
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /编译失败/);
    assert.equal(existsSync(value.env.CALLS), false);
    assert.ok(existsSync(join(value.directory, 'target/build/21-1/build-active.json')));
});

// 直接执行所属Workflow的真实正文，仅替换外部I/O；不复制版本或装配算法。
function workflowBody(platform, name) {
    const source = readFileSync(join(root, '.github/workflows/' + platform + '.yml'), 'utf8');
    const step = source.split('      - name: ' + name + '\n')[1];
    assert.ok(step, '缺少所属Workflow步骤：' + name);
    return step.split("node --input-type=module <<'JS'\n")[1].split('\n          JS')[0]
        .split('\n').map(line => line.slice(10)).filter(line => !line.startsWith('import ')).join('\n');
}
function checkCandidate(platform, rows, candidate, initial = '1.0.0') {
    const calls = [];
    const execute = new Function('execFileSync', 'readFileSync', 'process', workflowBody(platform, '核对候选版本及唯一原Run'));
    return {calls, run: () => execute((command, args) => {
        assert.equal(command, 'gh');
        calls.push(args);
        assert.equal(args.some(value => ['POST','DELETE','-f'].includes(value)), false);
        return JSON.stringify([{workflow_runs:rows}]);
    }, () => 'version: ' + initial + '+1\n', {env:{CITIZENAPP_VERSION:candidate,
        GITHUB_RUN_ID:'20', GITHUB_REPOSITORY:'crcfrcn/citizenapp', PLATFORM:platform}})};
}
for (const platform of ['ios', 'android']) {
    const label = platform === 'ios' ? 'iOS' : 'Android';
    const success = {id:10, status:'completed', conclusion:'success', display_title:'公民·' + label + '·v1.0.1'};
    test(platform + '单Run按成功记录校验候选，失败和当前Run不占号', () => {
        const value = checkCandidate(platform, [success,
            {...success,id:11,conclusion:'failure',display_title:'公民·' + label + '·v1.0.2'},
            {...success,id:20,status:'in_progress'}], '1.0.2');
        value.run();
        assert.equal(value.calls.length, 1);
        checkCandidate(platform, [], '1.0.0').run();
    });
    test(platform + '拒绝错误候选、更早活动Run和未知成功版本', () => {
        for (const [rows, candidate] of [
            [[success], '1.0.3'], [[{...success,status:'in_progress'}], '1.0.0'],
            [[{...success,display_title:'未知旧版本'}], '1.0.2'], [[], '01.0.0']
        ]) assert.throws(checkCandidate(platform, rows, candidate).run);
    });
    test(platform + '平台装配正文读取真实原件并生成必要标准配置', () => {
        const all = workflowBody(platform, '按本产品原锁装配普通工程');
        const body = all.slice(all.indexOf('// Flutter官方模板'), all.indexOf("const citizen = join(work, 'sources/citizen_sdk/scripts/build.mjs');"));
        for (const sourceHasWidgetTest of [false, true]) {
            const files = new Map(), copies = [], tools = [], removed = [];
            const project = '/fixture/project';
            const icon = project + '/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json';
            const fsRead = path => {
                if (files.has(path)) return files.get(path);
                if (path === icon) return JSON.stringify({images:[{size:'20x20',scale:'2x',filename:'Icon-App-20x20@2x.png'}]});
                throw Error('未声明读取：' + path);
            };
            new Function('execFileSync', 'readFileSync', 'writeFileSync', 'mkdirSync', 'copyFileSync', 'chmodSync', 'rmSync', 'readdirSync',
                'join', 'dirname', 'root', 'work', 'project', 'process', body)(
                (command,args) => {
                    assert.equal(command, '/fixture/flutter/bin/flutter', '装配不得调用未声明工具');
                    assert.equal(args[0], 'create');
                    tools.push([command,args]);
                }, fsRead, (path,text) => files.set(path,text), () => {},
                (source,destination) => copies.push([source,destination]), () => {}, path => removed.push(path),
                path => { assert.equal(path, '/fixture/source/test'); return sourceHasWidgetTest ? ['widget_test.dart'] : []; }, join, dirname,
                '/fixture/source','/fixture',project,{env:{FLUTTER_ROOT:'/fixture/flutter'}});
            assert.equal(tools.length, 1, '只允许本轮Flutter模板生成命令');
            assert.ok(tools[0][1].includes('--platforms=android,ios'));
            assert.equal(removed.includes(project + '/test/widget_test.dart'), !sourceHasWidgetTest);
            assert.ok(removed.every(path => path.startsWith(project + '/')), '不得删除产品源码');
            assert.ok(copies.some(([source,target]) => source.endsWith('ios/project/Runner.pbxproj') && target.endsWith('Runner.xcodeproj/project.pbxproj')));
            assert.ok(copies.some(([source,target]) => source.endsWith('android/square/SquareMediaChannel.kt') && target.endsWith('src/main/SquareMediaChannel.kt')));
            assert.ok(copies.some(([source,target]) => source.endsWith('assets/logo/icon40.png') && target.endsWith('Icon-App-20x20@2x.png')));
            assert.match(files.get(project+'/android/app/src/main/res/values/strings.xml'), /<string name="app_name">公民<\/string>/);
            assert.match(files.get(project+'/android/app/src/main/res/values-en/strings.xml'), />CitizenApp</);
            assert.match(files.get(project+'/android/app/src/main/res/xml/network_security_config.xml'), /cleartextTrafficPermitted="false"/);
            assert.match(files.get(project+'/ios/Runner/Runner.entitlements'), /\$\(APS_ENVIRONMENT\)/);
            assert.match(files.get(project+'/ios/Podfile'), /tatachat_sdk\.podspec/);
            assert.match(files.get(project+'/ios/Podfile'), /isar_community_flutter_libs\/libisar\.a/);
            assert.match(files.get(project+'/android/gradle.properties'), /android\.builtInKotlin=false/);
            assert.match(files.get(project+'/android/gradle/wrapper/gradle-wrapper.properties'), /gradle-9\.1\.0-bin\.zip/);
        }
    });
}

// 固定链金标仍归链源码；这里只检查产品依赖来源，真实ABI与业务回归由原命令执行。
test('两项SDK原始声明和锁的准确提交一致', () => {
    for (const name of ['citizen_sdk', 'tatachat_sdk']) {
        const declaration = pubspec.split('  ' + name + ':\n')[1]?.split(/\n  \S/)[0];
        const record = pubLock.split('\n  ' + name + ':\n')[1]?.split(/\n  \S/)[0];
        const ref = /resolved-ref: ([a-f0-9]{40})/.exec(record || '')?.[1];
        assert.ok(ref && declaration?.includes('ref: ' + ref));
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
    const preview = readFileSync(join(root, 'lib/scanner/scanner_view.dart'), 'utf8');
    const display = readFileSync(join(root, 'lib/scanner/qr_display_scaffold.dart'), 'utf8');
    assert.match(preview, /qr[.]openCapture\(purpose\)/u);
    assert.match(preview, /Texture\(textureId: capture[.]textureId\)/u);
    assert.match(display, /qr[.]encode\(widget[.]data, scale: 1\)/u);
    const caller = readFileSync(join(root, 'lib/scanner/scan_dispatch_flow.dart'), 'utf8');
    assert.ok(caller.includes("import 'package:citizen_sdk/citizen_sdk.dart';"));
    assert.equal(caller.includes('package:citizen_sdk/src/'), false);
});
