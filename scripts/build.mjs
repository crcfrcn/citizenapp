#!/usr/bin/env node
// 本产品流程唯一实现：自动化编译、启动所属Workflow，以及下载正式包安装到手机。
import {spawn, execFileSync} from 'node:child_process';
import {copyFileSync, cpSync, createReadStream, createWriteStream, existsSync, mkdirSync,
    readFileSync, readdirSync, realpathSync, renameSync, rmSync, writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {homedir} from 'node:os';
import {join, resolve} from 'node:path';
import {Readable} from 'node:stream';
import {pipeline} from 'node:stream/promises';
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
        child.stdout?.on('data', bytes => {
            output += bytes;
            if (output.length > 4 * 1024 * 1024) {
                failure = Error(operation + '工具回执超限');
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

export async function build(platform, phase = 'app') {
    const work = requireAutomationBuild(platform);
    if (!['dependencies', 'app'].includes(phase)) throw Error('未知编译阶段');
    const project = join(work, 'project');
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
        // 成败不决定现场占用；只有编译进程组全部退出后才释放标记。
        if (!groups.size) rmSync(activeMarker);
    }
}

// 沿用控制台现有公开接口；配置文件仅同名导出，流程正文只有本文件这一份。
export async function describeAction({flow, platform}) {
    const labels = {ios: 'iOS', android: 'Android'};
    if (!['ios', 'android'].includes(platform) || !['build', 'release'].includes(flow)) {
        throw Error('本产品尚未声明该流程入口：' + flow + '·' + platform);
    }
    if (flow === 'build') {
        return {command: process.execPath,
            args: [fileURLToPath(import.meta.url), 'install', platform], cwd: root,
            env: {PATH: '/usr/bin:/bin', HOME: homedir()}};
    }
    // 自动化原有版本与单Run派发规则整体移出配置文件，不改变调用协议。
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
            if (!latest.display_title.startsWith(prefix)) throw Error('本产品最新成功Run没有准确版本');
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

// 固定缓存只保留每端一个正式包；以GitHub官方附件摘要判断是否需要下载。
async function checksum(file) {
    const hash = createHash('sha256');
    for await (const bytes of createReadStream(file, {signal: controller.signal})) hash.update(bytes);
    return 'sha256:' + hash.digest('hex');
}

export async function install(platform) {
    if (!['ios', 'android'].includes(platform)) throw Error('未知安装平台');
    const label = {ios: 'iOS', android: 'Android'}[platform];
    const cache = join(root, 'target'), work = join(cache, 'install-' + platform);
    const extension = platform === 'ios' ? 'ipa' : 'apk', file = join(cache, platform + '.' + extension);
    mkdirSync(cache, {recursive: true});
    if (realpathSync(cache) !== cache) throw Error('安装缓存必须位于本产品真实target目录');
    // 同平台互斥，双端现场独立；已有现场不擅自清理或抢占。
    mkdirSync(work);
    const tool = (command, args, capture = false) => run(command, args, root, capture, process.env, '安装');
    try {
        const cached = existsSync(file) && realpathSync(file) === file ? await checksum(file) : null;
        const releases = [];
        for (let page = 1; ; page++) {
            const response = await fetch('https://api.github.com/repos/crcfrcn/citizenapp/releases?' +
                'per_page=100&page=' + page, {signal: controller.signal});
            if (!response.ok) throw Error('读取GitHub正式版失败：HTTP ' + response.status);
            const rows = await response.json();
            releases.push(...rows);
            if (rows.length < 100) break;
        }
        const prefix = '公民·' + label + '·v';
        const latest = releases.filter(row => !row.draft && !row.prerelease && row.published_at &&
            row.tag_name.startsWith(prefix) && /^\d+\.\d+\.\d+$/.test(row.tag_name.slice(prefix.length)))
            .sort((a, b) => Date.parse(b.published_at) - Date.parse(a.published_at) || b.id - a.id)[0];
        if (!latest) throw Error('GitHub没有本平台正式版');
        const name = label + '.v' + latest.tag_name.slice(prefix.length) + '.' + extension;
        const assets = latest.assets.filter(asset => asset.name === name && asset.state === 'uploaded');
        if (assets.length !== 1 || !/^sha256:[a-f0-9]{64}$/.test(assets[0].digest || '')) {
            throw Error('正式安装附件不唯一或缺少GitHub官方SHA-256');
        }
        const asset = assets[0];
        if (!asset.browser_download_url.startsWith('https://github.com/crcfrcn/citizenapp/releases/download/')) {
            throw Error('正式附件下载地址不是本产品GitHub HTTPS地址');
        }
        if (cached !== asset.digest) {
            console.log('下载最新正式包：' + name);
            const response = await fetch(asset.browser_download_url, {signal: controller.signal});
            if (!response.ok) throw Error('下载安装包失败：HTTP ' + response.status);
            const pending = join(work, 'download');
            await pipeline(Readable.fromWeb(response.body), createWriteStream(pending), {signal: controller.signal});
            if (await checksum(pending) !== asset.digest) throw Error('下载包与GitHub正式附件不一致');
            renameSync(pending, file);
        } else {
            console.log('本地包与最新正式版一致，直接安装：' + name);
        }
        if (platform === 'android') {
            const adb = join(homedir(), 'Library/Android/sdk/platform-tools/adb');
            await tool(adb, ['-d', 'install', '-r', file]);
        } else {
            const listing = JSON.parse(await tool('/usr/bin/xcrun',
                ['devicectl', 'list', 'devices', '--json-output', '-', '--omit-deprecated-fields-in-json'], true));
            const devices = listing.result.devices.filter(device => device.properties.hardware.platform === 'iOS' &&
                device.properties.hardware.reality === 'physical' && device.properties.connection.pairingState === 'paired' &&
                device.properties.connection.transportType === 'wired' &&
                device.properties.connection.state !== 'unavailable');
            if (devices.length !== 1) throw Error('请连接并信任唯一一台要安装的iPhone');
            await tool('/usr/bin/unzip', ['-q', file, '-d', work]);
            const apps = readdirSync(join(work, 'Payload')).filter(name => name.endsWith('.app'));
            if (apps.length !== 1) throw Error('IPA内应用缺失或不唯一');
            await tool('/usr/bin/xcrun', ['devicectl', 'device', 'install', 'app',
                '--device', devices[0].identifier, join(work, 'Payload', apps[0])]);
        }
        console.log('已安装：' + name);
    } finally {
        // 安装结束保留正式包，临时下载和IPA解包只在工具进程组确认退出后清理。
        if (!groups.size) rmSync(work, {recursive: true, force: true});
    }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => controller.abort());
    try {
        if (process.argv[2] === 'install') await install(process.argv[3]);
        else await build(process.argv[2], process.argv[3]);
    } catch (error) {
        console.error(error.message);
        process.exitCode = 1;
    }
}
