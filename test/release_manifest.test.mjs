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

// 回归直接执行对应Workflow正文；外部命令由合成端口返回，不访问真实GitHub。
function workflowBody(platform, name) {
    const text = readFileSync(join(root, '.github/workflows/' + platform + '.yml'), 'utf8');
    const step = text.split('      - name: ' + name + '\n')[1];
    assert.ok(step, '真实Workflow步骤必须存在：' + name);
    const block = step.split("node --input-type=module <<'JS'\n")[1].split('\n          JS')[0];
    return block.split('\n').map(line => line.slice(10)).filter(line => !line.startsWith('import ')).join('\n');
}

function remoteRun(id, platform, extra = {}) {
    return {
        id, head_sha: 'a'.repeat(40), head_branch: 'main', event: 'workflow_dispatch',
        path: '.github/workflows/' + platform + '.yml', repository: {full_name: 'crcfrcn/citizenapp'},
        created_at: '2026-10-19T00:00:00Z', display_title: '公民·' + (platform === 'ios' ? 'iOS' : 'Android') + '·v1.2.3',
        status: 'completed', conclusion: 'success', ...extra
    };
}

function executeBody(body, exec, extra = {}) {
    return new Function('execFileSync', 'process', 'console', body)(exec, {env: {
        GITHUB_REPOSITORY: 'crcfrcn/citizenapp', GITHUB_SHA: 'a'.repeat(40),
        ORIGINAL_CONTROLLER: '20', ORIGINAL_RUN: '42', CITIZENAPP_VERSION: '1.2.3',
        ...extra
    }}, {log() {}});
}

function serverFailure(status = 500) {
    return Object.assign(Error('合成GitHub读取失败'), {stderr: Buffer.from('HTTP ' + status)});
}

for (const platform of ['ios', 'android']) {
    test(platform + '观察500后仍只读取原Run，远端成功才报告成功', () => {
        const calls = [];
        let reads = 0;
        const exec = (command, args) => {
            calls.push([command, args]);
            if (command === 'sleep') return '';
            assert.equal(command, 'gh');
            assert.ok(args.at(-1).endsWith('/actions/runs/42'));
            if (++reads === 1) throw serverFailure();
            return JSON.stringify(remoteRun(42, platform, {
                status: reads === 2 ? 'in_progress' : 'completed', conclusion: reads === 2 ? null : 'success'
            }));
        };
        executeBody(workflowBody(platform, '观察准确原编译Run'), exec);
        assert.equal(reads, 3);
        assert.deepEqual(calls.filter(row => row[0] === 'sleep').map(row => row[1]), [['1'], ['10']]);
        assert.ok(calls.every(row => !row[1].includes('-X') && !row[1].includes('cancel')));
    });

    test(platform + '只读500耗尽三次重试仍失败，不取消、不重派', () => {
        let reads = 0;
        const exec = (command, args) => {
            if (command === 'sleep') return '';
            assert.equal(command, 'gh');
            assert.equal(args.includes('-X'), false);
            reads++;
            throw serverFailure();
        };
        assert.throws(() => executeBody(workflowBody(platform, '观察准确原编译Run'), exec), /合成GitHub/);
        assert.equal(reads, 4);
    });

    test(platform + '远端明确失败时报告失败，不触发变更请求', () => {
        let calls = 0;
        const exec = (command, args) => {
            assert.equal(command, 'gh');
            assert.equal(args.includes('-X'), false);
            calls++;
            return JSON.stringify(remoteRun(42, platform, {conclusion: 'failure'}));
        };
        assert.throws(() => executeBody(workflowBody(platform, '观察准确原编译Run'), exec), /原编译Run失败/);
        assert.equal(calls, 1);
    });

    test(platform + '准备Run结束后仍核对身份和候选，明确取消及错源码拒绝', () => {
        const body = workflowBody(platform, '原准备Run·${{ inputs.controller }}');
        for (const extra of [{conclusion: 'failure'}, {conclusion: 'cancelled'}, {head_sha: 'b'.repeat(40)}]) {
            let jobs = 0;
            const exec = (command, args) => {
                if (command === 'sleep') return '';
                if (args.at(-1).endsWith('/actions/runs/20')) return JSON.stringify(remoteRun(20, platform, extra));
                assert.ok(args.at(-1).includes('/20/jobs?'));
                jobs++;
                return JSON.stringify([{jobs: [{steps: jobs < 3 ? [] : [{name: '候选版本·v1.2.3'}]}]}]);
            };
            if (extra.conclusion === 'failure') {
                executeBody(body, exec);
                assert.equal(jobs, 3);
            } else {
                assert.throws(() => executeBody(body, exec), /身份不符或已明确取消/);
                assert.equal(jobs, 0);
            }
        }
    });

    test(platform + '收尾使用准确Run ID，Job延迟出现后仍确认原关联', () => {
        const all = workflowBody(platform, '核对原Run、取消及真实清理');
        const body = all.slice(0, all.indexOf("if (process.env.OPERATION === 'cancel'")) + '\nreturn child;';
        for (const original of ['42', '']) {
            let jobs = 0, scans = 0;
            const exec = (command, args) => {
                if (command === 'sleep') return '';
                assert.equal(command, 'gh');
                assert.equal(args.includes('-X'), false);
                const endpoint = args.at(-1);
                if (endpoint.endsWith('/actions/runs/20')) return JSON.stringify(remoteRun(20, platform));
                if (endpoint.endsWith('/actions/runs/42')) return JSON.stringify(remoteRun(42, platform));
                if (endpoint.includes('/workflows/')) {
                    scans++;
                    return JSON.stringify([{workflow_runs: [remoteRun(42, platform)]}]);
                }
                assert.ok(endpoint.includes('/42/jobs?'));
                jobs++;
                return JSON.stringify([{jobs: [{steps: jobs < 3 ? [] : [{name: '原准备Run·20'}]}]}]);
            };
            const child = executeBody(body, exec, {ORIGINAL_RUN: original, WORKFLOW: platform + '.yml'});
            assert.equal(child.id, 42);
            assert.equal(jobs, 3);
            assert.equal(scans, original ? 0 : 3);
        }
    });

    test(platform + '收尾拒绝关联到其它准备Run的准确编号', () => {
        const all = workflowBody(platform, '核对原Run、取消及真实清理');
        const body = all.slice(0, all.indexOf("if (process.env.OPERATION === 'cancel'")) + '\nreturn child;';
        const exec = (command, args) => {
            assert.equal(command, 'gh');
            const endpoint = args.at(-1);
            if (endpoint.endsWith('/actions/runs/20')) return JSON.stringify(remoteRun(20, platform));
            if (endpoint.endsWith('/actions/runs/42')) return JSON.stringify(remoteRun(42, platform));
            return JSON.stringify([{jobs: [{steps: [{name: '原准备Run·99'}]}]}]);
        };
        assert.throws(() => executeBody(body, exec, {WORKFLOW: platform + '.yml'}), /关联不符/);
    });

    test(platform + 'Job始终不可见时有限等待后保留记录，不猜测或重派', () => {
        const all = workflowBody(platform, '核对原Run、取消及真实清理');
        const body = all.slice(0, all.indexOf("if (process.env.OPERATION === 'cancel'")) + '\nreturn child;';
        let jobs = 0;
        const exec = (command, args) => {
            if (command === 'sleep') return '';
            assert.equal(command, 'gh');
            assert.equal(args.includes('-X'), false);
            const endpoint = args.at(-1);
            if (endpoint.endsWith('/actions/runs/20')) return JSON.stringify(remoteRun(20, platform));
            if (endpoint.endsWith('/actions/runs/42')) return JSON.stringify(remoteRun(42, platform));
            assert.ok(endpoint.includes('/42/jobs?'));
            jobs++;
            return JSON.stringify([{jobs: []}]);
        };
        assert.throws(() => executeBody(body, exec, {WORKFLOW: platform + '.yml'}), /保留记录，禁止重新派发/);
        assert.equal(jobs, 60);
    });

    test(platform + '实际收尾Shell仅对明确取消请求cancel，并传准确Run ID', t => {
        const value = fixture(t, platform);
        const gh = join(value.directory, 'bin/gh');
        writeFileSync(gh, '#!' + process.execPath + '\n' +
            'require("node:fs").writeFileSync(process.env.CALLS, JSON.stringify(process.argv.slice(2)));\n');
        chmodSync(gh, 0o700);
        const workflow = readFileSync(join(root, '.github/workflows/' + platform + '.yml'), 'utf8');
        const source = workflow.split('      - name: 请求原Run收尾\n')[1]
            .split('        run: |\n')[1].split('\n  manage:')[0]
            .split('\n').map(line => line.slice(10)).join('\n');
        for (const status of ['success', 'failure', 'cancelled']) {
            const shell = source.replaceAll('${{ job.status }}', status);
            const result = spawnSync('bash', ['-c', shell], {
                env: {...value.env, ORIGINAL_RUN: '42'}, encoding: 'utf8'
            });
            assert.equal(result.status, 0, result.stderr);
            const args = JSON.parse(readFileSync(value.env.CALLS, 'utf8'));
            assert.ok(args.includes('inputs[operation]=' + (status === 'cancelled' ? 'cancel' : 'settle')));
            assert.ok(args.includes('inputs[run_id]=42'));
            assert.ok(args.includes('inputs[controller]=21'));
        }
    });
}

test('派发POST即使返回500也只执行一次', () => {
    const body = workflowBody('android', '核对版本并且只派发一次');
    const start = body.indexOf('const request =');
    const end = body.indexOf('\n};', start) + 3;
    let calls = 0;
    const request = new Function('execFileSync', 'console', body.slice(start, end) + '\nreturn request;')(() => {
        calls++;
        throw serverFailure();
    }, {log() {}});
    assert.throws(() => request('repos/crcfrcn/citizenapp/actions/workflows/android.yml/dispatches', ['-X', 'POST']), /合成GitHub/);
    assert.equal(calls, 1);
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
