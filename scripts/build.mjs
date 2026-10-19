#!/usr/bin/env node
// 仅在所属GitHub自动化编译SDK依赖和App；不包含测试、版本管理或远端任务功能。
import {spawn, execFileSync} from 'node:child_process';
import {copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, realpathSync, rmSync, writeFileSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const controller = new AbortController();
const groups = new Set();
let activeMarker;

// 必须对应本仓main、准确工作流和本轮已装配工程；普通本机环境在写入前拒绝。
export function requireAutomationBuild(platform, environment = process.env) {
    const e = environment;
    if (!['ios', 'android'].includes(platform) || e.GITHUB_ACTIONS !== 'true' ||
        e.GITHUB_REPOSITORY !== 'crcfrcn/citizenapp' || e.GITHUB_REF !== 'refs/heads/main' ||
        e.GITHUB_EVENT_NAME !== 'workflow_dispatch' ||
        e.GITHUB_WORKFLOW_REF !== `crcfrcn/citizenapp/.github/workflows/${platform}.yml@refs/heads/main` ||
        !/^[1-9]\d*$/.test(e.GITHUB_RUN_ID || '') || !/^[1-9]\d*$/.test(e.GITHUB_RUN_ATTEMPT || '') ||
        !/^[1-9]\d*$/.test(e.GITHUB_RUN_NUMBER || '') || !/^[a-f0-9]{40}$/.test(e.GITHUB_SHA || '') ||
        e.GITHUB_SHA.length !== 40 || /\s/.test(e.CITIZENAPP_VERSION || '') || (e.CITIZENAPP_VERSION || '').length > 64 ||
        !/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(e.CITIZENAPP_VERSION || '')) {
        throw Error('公民App只能在本平台准确的塔塔自动化中编译');
    }
    const work = join(root, 'target/build', `${e.GITHUB_RUN_ID}-${e.GITHUB_RUN_ATTEMPT}`);
    if (realpathSync(work) !== work || realpathSync(join(work, 'project')) !== join(work, 'project')) {
        throw Error('自动化工程目录无效');
    }
    if (execFileSync('git', ['rev-parse', 'HEAD'], {cwd: root, encoding: 'utf8'}).trim() !== e.GITHUB_SHA) {
        throw Error('自动化源码提交不一致');
    }
    return work;
}

// 取消后确认本轮整个进程组退出；无法确认时留下标记，禁止后续清场。
async function run(command, args, cwd, capture = false, environment = process.env) {
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
        child.stdout?.on('data', bytes => {
            output += bytes;
            if (output.length > 4 * 1024 * 1024) {
                failure = Error('编译工具回执超限');
                stop();
            }
        });
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
                    failure ||= Error('编译主进程退出后仍有后代活动');
                    stop();
                }
                await new Promise(done => setTimeout(done, 100));
            }
            clearTimeout(timer);
            if (groups.size) return reject(Error('编译进程组退出未确认，保留本轮现场'));
            if (failure || code !== 0 || controller.signal.aborted) return reject(failure || Error('编译失败或已取消'));
            accept(output.trim());
        });
    });
}

export async function build(platform, phase = 'app') {
    const work = requireAutomationBuild(platform);
    if (!['dependencies', 'app'].includes(phase)) throw Error('未知编译阶段');
    const project = join(work, 'project');
    let dependencyComplete = phase !== 'dependencies';
    activeMarker = join(work, 'build-active.json');
    if (existsSync(activeMarker)) throw Error('本轮编译现场仍被占用');
    writeFileSync(activeMarker, JSON.stringify({pid: process.pid}), {flag: 'wx', mode: 0o600});
    try {
        if (phase === 'dependencies') {
            for (const name of ['citizen_sdk', 'tatachat_sdk']) {
                const source = join(work, 'sources', name);
                const script = join(source, 'scripts/build.mjs');
                const targets = name === 'citizen_sdk' ? ['abi-host', platform === 'ios' ? 'apple' : 'android'] : ['macos', platform];
                for (const target of targets) {
                    const environment = {...process.env};
                    delete environment.GH_TOKEN;
                    delete environment.GITHUB_TOKEN;
                    environment.CITIZENSDK_WORK_DIR = join(work, 'native-work', target);
                    const result = await run(process.execPath, [script, 'native', target], source, name === 'tatachat_sdk', environment);
                    if (name !== 'tatachat_sdk') continue;
                    const output = JSON.parse(result).output;
                    const packagePath = target === 'android' ? 'android/src/main/jniLibs' :
                        target === 'ios' ? 'ios/TataChatSDK.xcframework' : 'native';
                    const destination = join(work, 'packages/tatachat_sdk', packagePath);
                    cpSync(target === 'ios' ? join(output, 'TataChatSDK.xcframework') : output, destination, {recursive: true});
                }
            }
            dependencyComplete = true;
            return;
        }
        const flutter = join(process.env.FLUTTER_ROOT, 'bin/flutter');
        const version = ['--build-name', process.env.CITIZENAPP_VERSION, '--build-number', process.env.GITHUB_RUN_NUMBER];
        const output = join(work, 'artifact');
        mkdirSync(output);
        const title = `公民·${platform === 'ios' ? 'iOS' : 'Android'}·v${process.env.CITIZENAPP_VERSION}`;
        if (platform === 'android') {
            for (const [format, source] of [['apk', 'flutter-apk/app-release.apk'], ['appbundle', 'bundle/release/app-release.aab']]) {
                await run(flutter, ['build', format, '--release', '--target-platform', 'android-arm64', ...version], project);
                copyFileSync(join(project, 'build/app/outputs', source), join(output, `${title}.${format === 'apk' ? 'apk' : 'aab'}`));
            }
        } else {
            await run(flutter, ['build', 'ipa', '--release', '--export-options-plist', join(work, 'signing/export.plist'), ...version], project);
            const directory = join(project, 'build/ios/ipa');
            const files = readdirSync(directory).filter(name => name.endsWith('.ipa'));
            if (files.length !== 1) throw Error('正式IPA缺失或不唯一');
            copyFileSync(join(directory, files[0]), join(output, `${title}.ipa`));
        }
    } finally {
        if (dependencyComplete && !groups.size) rmSync(activeMarker);
    }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => controller.abort());
    try {
        await build(process.argv[2], process.argv[3]);
    } catch (error) {
        console.error(error.message);
        process.exitCode = 1;
    }
}
