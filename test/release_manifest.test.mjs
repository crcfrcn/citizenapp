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

// 执行所属Workflow的真实准备正文，替换外部I/O；不另造版本算法。
function prepareWorkflow({active = false, missing = false, lost = false} = {}) {
    const workflow = readFileSync(join(root, '.github/workflows/android.yml'), 'utf8');
    const block = workflow.split("node --input-type=module <<'JS'\n")[1].split('\n          JS')[0];
    const body = block.split('\n').map(line => line.slice(10)).filter(line => !line.startsWith('import ')).join('\n');
    const run = {
        id: 10, status: 'completed', conclusion: 'success',
        path: '.github/workflows/android.yml', head_sha: 'a'.repeat(40),
        display_title: '公民·Android·v1.0.1'
    };
    const rows = [run, {...run, id: 11, conclusion: 'failure', display_title: '公民·Android·v1.0.2'}];
    if (active) rows.push({...run, id: 12, status: 'queued'});
    const release = {
        tag_name: run.display_title, target_commitish: run.head_sha, draft: false, prerelease: false,
        body: JSON.stringify({product_id: 'citizenapp', platform: 'android', version: '1.0.1',
            run_id: 10, run_attempt: 1, source_sha: run.head_sha})
    };
    const dispatches = [];
    const exec = (command, args) => {
        assert.equal(command, 'gh');
        const endpoint = args.at(-1);
        if (args.includes('inputs[operation]=build')) {
            dispatches.push(args);
            if (lost) throw Error('派发响应丢失');
            return JSON.stringify({workflow_run_id: 15, html_url: 'https://github.com/crcfrcn/citizenapp/actions/runs/15'});
        }
        if (endpoint.includes('/workflows/')) return JSON.stringify([{workflow_runs: rows}]);
        if (endpoint.includes('/releases?')) return JSON.stringify([missing ? [] : [release]]);
        if (endpoint.includes('/attempts/')) return JSON.stringify(run);
        if (endpoint.includes('/jobs?')) return JSON.stringify([{jobs: []}]);
        if (endpoint.includes('/git/ref/')) return JSON.stringify({object: {type: 'commit', sha: run.head_sha}});
        throw Error('未声明的外部调用');
    };
    const evaluate = new Function('execFileSync', 'readFileSync', 'appendFileSync', 'process', 'console', body);
    return {dispatches, run: () => evaluate(exec, () => 'version: 1.0.0+1\n', () => {}, {env: {
        GITHUB_REPOSITORY: 'crcfrcn/citizenapp', WORKFLOW: 'android.yml', PLATFORM: 'android',
        GITHUB_RUN_ID: '20', GITHUB_OUTPUT: 'fixture'
    }}, {log() {}})};
}

test('失败候选不递增，准备流程只派发准确后继版本一次', () => {
    const value = prepareWorkflow();
    value.run();
    assert.equal(value.dispatches.length, 1);
    assert.ok(value.dispatches[0].includes('inputs[version]=1.0.2'));
});

test('活动Run、缺失正式证明和回执丢失均禁止再次派发', () => {
    for (const input of [{active: true}, {missing: true}, {lost: true}]) {
        const value = prepareWorkflow(input);
        assert.throws(value.run);
        assert.equal(value.dispatches.length, input.lost ? 1 : 0);
    }
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
