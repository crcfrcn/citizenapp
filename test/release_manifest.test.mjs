import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawn, spawnSync} from 'node:child_process';
import {chmodSync, copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {assembleProject,selectSDKRelease,describeAction,existingFlutter} from '../scripts/build.mjs';

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
        const body = all.slice(all.indexOf('// Flutter官方模板'), all.indexOf("const sdkRoot = join(work, 'packages/citizen_sdk');"));
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
                'join', 'dirname', 'root', 'work', 'project', 'process', 'lock', body)(
                (command,args) => {
                    assert.equal(command, '/fixture/flutter/bin/flutter', '装配不得调用未声明工具');
                    assert.equal(args[0], 'create');
                    tools.push([command,args]);
                    // 对应原锁Flutter的create：--no-pub仍会用模板依赖重写工程锁。
                    files.set(project + '/pubspec.lock', '{"packages":{}}');
                }, fsRead, (path,text) => files.set(path,text), () => {},
                (source,destination) => copies.push([source,destination]), () => {}, path => removed.push(path),
                path => { assert.equal(path, '/fixture/source/test'); return sourceHasWidgetTest ? ['widget_test.dart'] : []; }, join, dirname,
                '/fixture/source','/fixture',project,{env:{FLUTTER_ROOT:'/fixture/flutter'}},pubLock);
            assert.equal(tools.length, 1, '只允许本轮Flutter模板生成命令');
            assert.ok(tools[0][1].includes('--platforms=android,ios'));
            assert.equal(files.get(project + '/pubspec.lock'), pubLock, '模板生成后必须完整恢复传入的锁，不重新解版本');
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
    const preview = readFileSync(join(root, 'lib/scanner/scanner_view.dart'), 'utf8');
    const display = readFileSync(join(root, 'lib/scanner/qr_display_scaffold.dart'), 'utf8');
    assert.match(preview, /qr[.]openCapture\(purpose\)/u);
    assert.match(preview, /Texture\(textureId: capture[.]textureId\)/u);
    assert.match(display, /qr[.]encode\(widget[.]data, scale: 1\)/u);
    const caller = readFileSync(join(root, 'lib/scanner/scan_dispatch_flow.dart'), 'utf8');
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
    const run = {status:'completed',conclusion:'success',head_sha:proof.git_commit_sha,run_attempt:1};
    const rows = [release,{...release,id:9,draft:true,body:JSON.stringify({...proof,software_version:'1.0.9'})}];
    const read = async path => path.startsWith('releases?') ? rows : run;
    assert.equal((await selectSDKRelease('citizensdk',read)).release.id,8);
    await assert.rejects(selectSDKRelease('citizensdk',async () => []),/没有可用/);
    await assert.rejects(selectSDKRelease('citizensdk',async path =>
        path.startsWith('releases?') ? rows : {...run,conclusion:'failure'}),/未成功/);
    const action = await describeAction({flow:'release',platform:'android'});
    let sent;
    await action.launch({read:async () => ({workflow_runs:[]}),dispatch:async value => {
        sent=value;return {workflow_run_id:12};
    }});
    assert.deepEqual(sent.inputs,{version:'1.0.0'});
    // 仅定位现有工具；版本、引擎或目录门禁不得重新进入编译入口。
    const value = fixture(t), tool = join(value.directory, 'flutter');
    mkdirSync(join(tool,'bin'),{recursive:true});writeFileSync(join(tool,'bin/flutter'),'fixture');
    assert.equal(existingFlutter('android',{},[tool]),tool);
    assert.equal(existingFlutter('ios',{},[tool]),tool);
    assert.doesNotMatch(builder,/requireAutomationBuild|sandbox-exec|CITIZENAPP_OFFLINE|CARGO_NET_OFFLINE|缺少SDK声明的现有ZXing/);

});
