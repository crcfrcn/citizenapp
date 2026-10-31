// 本脚本消费产品声明的工具和原锁依赖，只负责普通工程装配、编译构建和必要注释。
// config.mjs：只负责配置声明；build.mjs：只负责编译构建实现和必要注释；*.yml：负责全部GitHub流程，包括版本、作业编排、发布及历史清理。
import {spawn, execFileSync} from 'node:child_process';
import {appendFileSync, chmodSync, copyFileSync, cpSync, existsSync, mkdirSync, mkdtempSync,
    lstatSync, readFileSync, readdirSync, realpathSync, renameSync, rmSync, writeFileSync} from 'node:fs';
import {join, resolve, dirname, relative, sep} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const controller = new AbortController();
// Apple嵌套代码及权限由本产品交付，不让安装器猜测产品结构。
export function appleSigning(app, entitlements = null) {
 const targets=[];
 const visit=directory=>{for(const name of readdirSync(directory).sort()){
  const file=join(directory,name),info=lstatSync(file);
  if(info.isSymbolicLink())continue;
  if(info.isDirectory())visit(file);
  if(name.endsWith('.framework')||name.endsWith('.dylib')||name.endsWith('.appex'))targets.push({path:relative(app,file).split(sep).join('/'),entitlements:null});
 }};
 visit(app);return [...targets,{path:'.',entitlements}];
}

const groups = new Set();
let activeMarker;

// 取消后确认本轮整个进程组退出；无法确认时留下标记，禁止后续清场。
async function run(command, args, cwd, capture = false, environment = process.env, operation = '编译') {
    controller.signal.throwIfAborted();
    return new Promise((accept, reject) => {
        const child = spawn(command, args, {cwd, env: environment, detached: true,
            // 本机诊断逐行交给安装器日志，避免stderr缓冲上限吞掉最终错误。
            stdio: ['ignore', capture ? 'pipe' : 'inherit', environment.GITHUB_ACTIONS === 'true' ? 'inherit' : 1]});
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

// 最终R8产物必须保留JNI空结果回调需要的精确类和单例字段。
export async function verifyAndroidRuntime(apk, environment, execute = run) {
    if (!environment.ANDROID_HOME) throw Error('Android SDK工具根目录未提供');
    const analyzer = join(environment.ANDROID_HOME, 'cmdline-tools/latest/bin/apkanalyzer');
    const code = await execute(analyzer, ['dex', 'code', '--class', 'kotlin.Unit', apk],
        dirname(apk), true, environment, 'Android JNI产物核验');
    if (!/^\.class[^\n]* Lkotlin\/Unit;$/m.test(code) ||
        !/^\.field[^\n]*\bstatic\b[^\n]* INSTANCE:Lkotlin\/Unit;$/m.test(code)) {
        throw Error('Release APK缺少JNI需要的kotlin.Unit.INSTANCE');
    }
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
            // SDK原生组件已由统一工程装配准备，依赖阶段不重复编译。
            return;
        }
        const flutter = join(environment.FLUTTER_ROOT, 'bin/flutter');
        const version = ['--build-name', environment.CITIZENAPP_VERSION, '--build-number',
            options.local ? environment.CITIZENAPP_BUILD_NUMBER : environment.GITHUB_RUN_NUMBER];
        const output = join(work, 'artifact');
        mkdirSync(output);
        const title = `公民·${platform === 'ios' ? 'iOS' : 'Android'}·v${environment.CITIZENAPP_VERSION}`;
        if (platform === 'android') {
            for (const [format, source] of (options.local?[['apk','flutter-apk/app-release.apk']]:[['apk', 'flutter-apk/app-release.apk'], ['appbundle', 'bundle/release/app-release.aab']])) {
                await run(flutter, ['build', format, '--release', '--target-platform', 'android-arm64', ...version], project,false,environment);
                if (format === 'apk') await verifyAndroidRuntime(join(project, 'build/app/outputs', source), environment);
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


// 聊天SDK沿用其正式Release交付。
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
        if (proof?.product_id !== product || proof.platform !== 'sdk'
            || !/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/u.test(proof.software_version)
            || !/^[a-f0-9]{40}$/u.test(proof.git_commit_sha)
            || ![proof.producer_run_id, proof.producer_run_attempt].every(value => Number.isSafeInteger(value) && value > 0)) return [];
        return [{release, proof}];
    }).sort((a, b) => {
        const left = a.proof.software_version.split('.').map(BigInt);
        const right = b.proof.software_version.split('.').map(BigInt);
        for (let i = 0; i < 3; i++) if (left[i] !== right[i]) return left[i] > right[i] ? -1 : 1;
        return b.release.id - a.release.id;
    });
    const selected = candidates[0];
    if (selected) {
        const proof = selected.proof;
        const run = await read('actions/runs/' + proof.producer_run_id + '/attempts/' + proof.producer_run_attempt);
        if (run.status === 'completed' && run.conclusion === 'success'
            && run.id === proof.producer_run_id && run.run_attempt === proof.producer_run_attempt
            && run.head_sha === proof.git_commit_sha) return selected;
    }
    throw Error(product + '没有可用的成功正式SDK版本');
}

// 公民SDK唯一工作流只保留最新成功Run；完整Artifact直接交给SDK自己的consume。
export async function selectSDKArtifact(read) {
    const {workflow_runs: runs} = await read('actions/workflows/sdk.yml/runs?branch=main&status=success&per_page=100');
    const run = runs.find(row => row.status === 'completed' && row.conclusion === 'success'
        && row.head_branch === 'main' && /^[a-f0-9]{40}$/u.test(row.head_sha)
        && [row.id, row.run_attempt].every(value => Number.isSafeInteger(value) && value > 0));
    if (!run) throw Error('citizensdk没有可用的成功自动化');
    const {artifacts} = await read('actions/runs/' + run.id + '/artifacts?per_page=100');
    const artifact = artifacts.find(row => !row.expired
        && /^公民SDK·SDK·v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/u.test(row.name));
    if (!artifact) throw Error('citizensdk成功自动化缺少完整Artifact');
    return {run, artifact};
}

// 编译与测试都从产品唯一workspace声明取得包路径，不另建包清单。
export function packageRoots(root){
 const text=readFileSync(join(root,'pubspec.yaml'),'utf8');
 const block=/^workspace:\n((?:  - .*\n)+)/m.exec(text)?.[1];
 if(!block)throw Error('产品workspace声明缺失');
 const members=block.trimEnd().split('\n').map(line=>line.slice(4).trim().replace(/^(['"])(.*)\1$/,'$2'));
 if(new Set(members).size!==members.length||members.some(path=>!path||path.includes('/')||path==='..'))throw Error('workspace包目录无效或重复');
 return [root,...members.map(path=>join(root,path))];
}

// 同一SDK在所有成员声明中映射到本轮同一源码视图，避免Git与path形成双来源。
export function mapSdkSource(root,name,output){
 let changed=0;
 for(const member of packageRoots(root)){
  const file=join(member,'pubspec.yaml'),source=readFileSync(file,'utf8');
  const mapped=source.replace(new RegExp('  '+name+':\\n(?:    .*\\n)+'), '  '+name+':\n    path: '+output+'\n');
  if(mapped!==source){writeFileSync(file,mapped);changed++;}
 }
 if(!changed)throw Error('workspace没有声明SDK：'+name);
 return changed;
}

// 仅在普通工程离线解析冻结SDK的新内部包；原有锁记录不变，不手写SDK包清单。
// 新包必须由官方Pub配置指向本轮SDK源码，第三方新增、漂移或缺件直接失败。
export async function preparePackages(project,{sources,environment=process.env,execute=run}){
 if(realpathSync(project)===realpathSync(root))throw Error('依赖装配禁止修改正式源码锁');
 const file=join(project,'pubspec.lock');
 const records=text=>new Map([...text.matchAll(/^  ([a-z][a-z0-9_]*):\n((?:    .*\n|\n)+)/gm)]
  .map(([,name,body])=>[name,body.split('\n').filter(line=>line.trim()).join('\n')]));
 const before=records(readFileSync(file,'utf8'));
 if(!before.size)throw Error('依赖装配缺少原锁记录');
 const roots=sources.map(source=>realpathSync(source));
 const flutter=join(environment.FLUTTER_ROOT,'bin/flutter');
 await execute(flutter,['pub','get','--offline'],project,false,environment,'依赖装配');
 const after=records(readFileSync(file,'utf8'));
 for(const [name,record]of before)if(after.get(name)!==record)throw Error('依赖装配改变原锁记录：'+name);
 const configFile=join(project,'.dart_tool/package_config.json');
 const packages=JSON.parse(readFileSync(configFile,'utf8')).packages;
 for(const [name,record]of after){
  if(before.has(name))continue;
  const entry=packages.find(entry=>entry.name===name);
  if(!/^    source: path$/m.test(record)||!entry)throw Error('依赖装配新增非SDK内部包：'+name);
  const path=realpathSync(fileURLToPath(new URL(entry.rootUri,pathToFileURL(configFile))));
  if(!roots.some(source=>path===source||path.startsWith(source+sep)))throw Error('依赖装配新增非SDK内部包：'+name);
 }
 await execute(flutter,['pub','get','--offline','--enforce-lockfile'],project,false,environment,'依赖锁验收');
}

// 正式App测试唯一归lib/test；普通工程按Dart官方test布局装配，保留开发依赖及测试注解语义。
// 只改文件位置和相对URI，不复制测试实现，不在正式主仓生成根test。
export function prepareTests(project){
 const source=join(project,'lib/test'),destination=join(project,'test');
 if(realpathSync(project)===realpathSync(root)||existsSync(destination))throw Error('测试装配只能写尚未生成test的普通工程');
 const visit=directory=>{for(const entry of readdirSync(directory,{withFileTypes:true})){
  const from=join(directory,entry.name);
  if(entry.isDirectory()){visit(from);if(!readdirSync(from).length)rmSync(from,{recursive:true});continue;}
  if(!entry.isFile()||!entry.name.endsWith('.dart'))continue;
  const to=join(destination,relative(source,from));
  const text=readFileSync(from,'utf8').replace(/^((?:import|export|part)\s+)(['"])(\.\.?\/[^'"]+)\2/gm,(_,prefix,quote,uri)=>{
   const target=resolve(dirname(from),uri);
   const mapped=target.startsWith(source+sep)?join(destination,relative(source,target)):target;
   let path=relative(dirname(to),mapped).split(sep).join('/');if(!path.startsWith('.'))path='./'+path;
   return prefix+quote+path+quote;
  });
  mkdirSync(dirname(to),{recursive:true});writeFileSync(to,text);rmSync(from);
 }};
 visit(source);
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
const sources=[];
for (const name of ['citizen_sdk', 'tatachat_sdk']) {
    const record = lock.split('\n  ' + name + ':\n')[1]?.split(/\n  \S/)[0];
    const url = /url: "?(https:\/\/github.com\/[^"\s]+\.git)"?/.exec(record || '')?.[1];
    const repository = url.slice('https://github.com/'.length, -4);
    const product = repository.split('/')[1];
    const local = resolve(root, '..', product);
    const read = path => JSON.parse(execute('gh', ['api', 'repos/' + repository + '/' + path],
        {encoding: 'utf8', env: environment}));
    // 本机读取两个SDK已保存的main；正式自动化消费各SDK原有正式交付。
    const selected = environment.GITHUB_ACTIONS === 'true' ?
        name === 'tatachat_sdk' ? await selectSDKRelease(product, read) : await selectSDKArtifact(read) : null;
    // 正式发布仍与聊天SDK的原消费锁准确一致。
    if (selected && name === 'tatachat_sdk') {
        const locked = /^[ \t]*resolved-ref: ("?)([a-f0-9]{40})\1[ \t]*$/m.exec(record || '')?.[2];
        if (locked !== selected.proof.git_commit_sha) {
            throw Error('tatachatsdk原锁与最新正式Release提交不一致，请更新消费锁');
        }
    }
    const ref = selected ? (name === 'citizen_sdk' ? selected.run.head_sha : selected.proof.git_commit_sha) :
        execute('git', ['-C', local, 'rev-parse', 'refs/heads/main'], {encoding: 'utf8', env: environment}).trim();
    const source = join(work, 'sources', name), output = join(work, 'packages', name);
    mkdirSync(source, {recursive: true});
    execute('git', ['init', source], {env: environment});
    execute('git', ['-C', source, 'fetch', '--depth=1', selected ? url : local, ref], {env: environment});
    execute('git', ['-C', source, 'checkout', '--detach', 'FETCH_HEAD'], {env: environment});
    mkdirSync(dirname(output), {recursive: true});
    const sdk = await import(pathToFileURL(join(source, 'scripts/build.mjs')));
    console.log(product + '：' + (selected ? (name === 'citizen_sdk' ? selected.artifact.name : selected.release.tag_name) : 'main') + ' ' + ref);
    if (selected) {
        const directory = join(work, 'downloads', product);
        mkdirSync(directory, {recursive: true});
        if (name === 'citizen_sdk') {
            await run('gh', ['run', 'download', String(selected.run.id), '--repo', repository,
                '--name', selected.artifact.name, '--dir', directory], root, false, environment);
            await sdk.consume({directory, sourceSha: ref, sourceRun: selected.run.id,
                sourceAttempt: selected.run.run_attempt, output, signal: controller.signal});
        } else {
            for (const extension of ['zip', 'json', 'sha256']) {
                const label = selected.release.tag_name + '.' + extension;
                const asset = selected.release.assets.find(asset => asset.label === label && asset.state === 'uploaded');
                await run('gh', ['release', 'download', selected.release.tag_name, '--repo', repository,
                    '--pattern', asset.name, '--output', join(directory, label)], root, false, environment);
            }
            const expanded = join(directory, 'expanded');
            await run('unzip', ['-q', join(directory, selected.release.tag_name + '.zip'), '-d', expanded], root, false, environment);
            sdk.createFlutterSourceView(join(expanded, 'project'), output);
        }
    } else if (name === 'citizen_sdk') {
            sdk.createFlutterSourceView(source, output);
            const settings = await import(pathToFileURL(join(source, 'scripts/config.mjs')));
            const tools = settings.tools;
            const nativeEnvironment = {...environment,
                ANDROID_NDK_HOME: join(environment.ANDROID_HOME, 'ndk', tools.ndk),
                // 只交付SDK公开声明要求的编译输入，不在App检查或获取依赖。
                CITIZENSDK_ZXING_SOURCE_DIR: environment.CITIZENSDK_ZXING_SOURCE_DIR ||
                    join(root, 'target/cache/sources', settings.nativeSources.zxing.archive_root)};
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
                [join(source, 'scripts/build.mjs'), 'native', environment.PLATFORM === 'ios' ? 'Apple' : 'Android', '--device'],
                source, true, nativeEnvironment));
            cpSync(result.output, output, {recursive: true});
    } else {
        // 聊天SDK完整构建归其公开入口，App只装配返回的普通工程。
        const result = JSON.parse(await run(globalThis.process.execPath,
            [join(source, 'scripts/build.mjs')], source, true, environment));
        cpSync(result.output, output, {recursive: true});
    }
    mapSdkSource(project,name,output);
    sources.push(output);
    declaration=readFileSync(join(project,'pubspec.yaml'),'utf8');
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
// 先移除官方模板示例，再把本产品lib/test装配为工具要求的唯一test目录。
rmSync(join(project, 'test'), {recursive: true, force: true});
prepareTests(project);
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
for (const file of readdirSync(join(root, 'android/tests'))) copy('android/tests/' + file, 'android/app/src/androidTest/' + file);
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
    TATACHATSDK_TEST_WORK_ROOT: work,
    TATACHATSDK_TEST_NATIVE_LIBRARY: join(work,'packages/tatachat_sdk/native/libtatachat_sdk.dylib')
};
// 完整Apple组件的Framework使用标准内部链接；测试只消费同轮真实普通文件。
// 真机专用组件没有宿主切片，不能宣称已交付测试库或沿用外部旧路径。
delete environment.CITIZENSDK_TEST_CORE_LIB_PATH;
const testCore = join(sdkRoot,'darwin/CitizenSDK.xcframework/macos-arm64/CitizenSDK.framework/CitizenSDK');
if (existsSync(testCore)) {
    const file = realpathSync(testCore);
    if (!lstatSync(file).isFile()) throw Error('宿主测试Core不是普通文件');
    values.CITIZENSDK_TEST_CORE_LIB_PATH = file;
}
Object.assign(environment,values);
if(environment.GITHUB_ENV)for (const [key, value] of Object.entries(values)) appendFileSync(environment.GITHUB_ENV, key + '=' + value + '\n');
await preparePackages(project,{sources,environment});
// App随包资源随普通工程一起准备，不增加功能构建入口。
const assets = join(project, 'transaction/web');
const resourceEnvironment = {...environment, npm_config_ignore_scripts: 'true',
    ...(environment.GITHUB_ACTIONS === 'true' ? {} : {npm_config_offline: 'true'})};
await run('npm', ['ci', '--ignore-scripts', '--no-audit', '--no-fund'], assets, false, resourceEnvironment, 'App资源准备');
await run(environment.ESBUILD_BIN || 'esbuild', ['walletconnect.js', '--bundle', '--format=iife',
    '--global-name=CitizenTopup', '--platform=browser', '--target=safari15,chrome100', '--minify',
    '--outfile=walletconnect.bundle.js', '--define:process.env.NODE_ENV="production"'], assets, false, resourceEnvironment, 'App资源准备');
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

const testInputError=message=>Object.assign(Error(message),{code:'TEST_INPUT'});

// 只编译本轮已装配工程的测试；不签名、安装或启动设备。
// ui在模拟器SDK编译隔离宿主；unit/all用真机SDK只编译完整Runner，不连接设备。
export async function buildTests(platform,{work=process.env.WORK,scope='all',environment=process.env,execute=run}={}){
 if(!['ios','android'].includes(platform)||!['all','ui','unit'].includes(scope))throw Error('未知测试编译目标');
 if(!work||!existsSync(work))throw testInputError('测试编译需要独占WORK');
 work=realpathSync(work);
 const project=join(work,'project');
 if(!existsSync(project)||realpathSync(project)===realpathSync(root))throw Error('测试编译只能写本轮普通工程');
 if(environment.GITHUB_ACTIONS==='true')throw Error('测试编译入口不消费正式签名环境');
 const marker=join(work,'tests-active.json');
 writeFileSync(marker,JSON.stringify({pid:process.pid}),{flag:'wx',mode:0o600});
 const cancel=()=>controller.abort();
 for(const signal of ['SIGINT','SIGTERM'])process.once(signal,cancel);
 try{
  if(platform==='android'){
   if(scope!=='all')throw Error('Android测试统一编译Release androidTest');
   if(!environment.GRADLE_BIN)throw testInputError('须交付已安装GRADLE_BIN，禁止wrapper隐式下载');
   if(!environment.FLUTTER_ROOT)throw testInputError('须交付已准备Flutter工具及原锁Pub输入');
   const flutter=join(environment.FLUTTER_ROOT,'bin/flutter');
   // 先按原锁离线解析；官方config-only只更新Release插件登记与配置，不构建或签署APK。
   await execute(flutter,['pub','get','--offline','--enforce-lockfile'],project,false,environment,'Android原锁确认');
   const lock=readFileSync(join(project,'pubspec.lock'));
   await execute(flutter,['build','apk','--config-only','--release','--target-platform','android-arm64'],
    project,false,environment,'Android Release配置准备');
   // Pub会规范化空行；所有版本、来源、摘要和路径记录必须保持逐行一致。
   const records=bytes=>bytes.toString('utf8').split(/\r?\n/).filter(line=>line.trim().length).join('\n');
   if(records(lock)!==records(readFileSync(join(project,'pubspec.lock'))))throw Error('Android配置准备改变了交付原锁记录');
   await execute(environment.GRADLE_BIN,['--offline','--no-daemon','--console=plain',
    ':app:compileReleaseAndroidTestKotlin',':app:compileReleaseAndroidTestJavaWithJavac'],
    join(project,'android'),false,environment,'Android测试编译');
   return {platform,scope,status:'compiled',kind:'classes',output:join(project,'build/app')};
  }
  const simulator=scope==='ui';
  if(!simulator&&!existsSync(join(project,'ios/Pods/Manifest.lock')))throw testInputError('iOS完整原生测试缺少原锁Pods输入');
  if(!simulator&&(!existsSync(join(project,'ios/Podfile.lock'))||!readFileSync(join(project,'ios/Podfile.lock')).equals(readFileSync(join(project,'ios/Pods/Manifest.lock')))))throw testInputError('iOS Pods与交付锁不一致');
  if(!simulator&&!existsSync(join(environment.FLUTTER_ROOT||'','bin/cache/artifacts/engine/ios-release/Flutter.xcframework')))throw testInputError('iOS完整原生测试缺少已准备Flutter Release引擎');
  const container=simulator?['-project',join(project,'ios/Runner.xcodeproj')]:['-workspace',join(project,'ios/Runner.xcworkspace')];
  if(!existsSync(container[1]))throw testInputError('iOS测试缺少对应工程入口');
  const sdk=simulator?'iphonesimulator':'iphoneos';
  const targets=[];
  if(scope!=='ui')targets.push(['331C8080294A63A400263BE5','RunnerTests']);
  if(scope!=='unit')targets.push(['A81100060000000000000000','RunnerUITests']);
  const reference=([id,name])=>'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'+id+'" BuildableName="'+name+'.xctest" BlueprintName="'+name+'" ReferencedContainer="container:Runner.xcodeproj"/>';
  const scheme=join(project,'ios/Runner.xcodeproj/xcshareddata/xcschemes/CitizenTests.xcscheme');
  mkdirSync(dirname(scheme),{recursive:true});
  writeFileSync(scheme,'<?xml version="1.0" encoding="UTF-8"?><Scheme version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>'+targets.map(t=>'<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">'+reference(t)+'</BuildActionEntry>').join('')+'</BuildActionEntries></BuildAction><TestAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES"><Testables>'+targets.map(t=>'<TestableReference skipped="NO">'+reference(t)+'</TestableReference>').join('')+'</Testables></TestAction></Scheme>');
  const output=join(work,'ios-tests');
  await execute('/usr/bin/xcrun',['xcodebuild',...container,
   '-scheme','CitizenTests','-configuration','Release','-sdk',sdk,
   '-destination',simulator?'generic/platform=iOS Simulator':'generic/platform=iOS','-derivedDataPath',output,
   '-disableAutomaticPackageResolution','-skipPackageUpdates','build-for-testing',
   'SUPPORTED_PLATFORMS='+sdk,'ENABLE_TESTABILITY=YES','CODE_SIGNING_ALLOWED=NO','CODE_SIGNING_REQUIRED=NO','CODE_SIGN_IDENTITY='],
   project,false,environment,'iOS测试编译');
  return {platform,scope,status:'compiled',kind:'xctestrun',output:join(output,'Build/Products')};
 }finally{
  for(const signal of ['SIGINT','SIGTERM'])process.removeListener(signal,cancel);
  if(!groups.size)rmSync(marker,{force:true});
 }
}

export async function compile(platform){
 const flutterRoot=existingFlutter(platform);
 const parent=join(root,'target/build');mkdirSync(parent,{recursive:true});
 if(realpathSync(parent)!==parent)throw Error('本机编译现场经过链接');
 const work=mkdtempSync(join(parent,'local-'));let safe=true;
 const cache=join(root,'target/cache');mkdirSync(cache,{recursive:true});
 // 本机构建号取本地声明；两个SDK均用本机main已保存提交，安装仍归控制台。
 const version=/^version:\s*([^+\s]+)(?:\+(\d+))?/mu.exec(readFileSync(join(root,'pubspec.yaml'),'utf8'));
 const environment={...process.env,GITHUB_ACTIONS:'false',GITHUB_WORKSPACE:root,WORK:work,PLATFORM:platform,
  CITIZENAPP_VERSION:version[1],CITIZENAPP_BUILD_NUMBER:version[2]||'1',
  CARGO_NET_OFFLINE:'true',GIT_ALLOW_PROTOCOL:'file:https',
  FLUTTER_ROOT:flutterRoot,PUB_CACHE:process.env.PUB_CACHE||join(process.env.HOME,'.pub-cache'),GRADLE_USER_HOME:process.env.GRADLE_USER_HOME||join(dirname(flutterRoot),'gradle'),
  CARGO_TARGET_DIR:process.env.CARGO_TARGET_DIR||join(cache,'rust'),RUSTUP_TOOLCHAIN:'1.97.1',
  PATH:process.env.HOME+'/.cargo/bin:'+process.env.HOME+'/.nvm/versions/node/v25.2.1/bin:/opt/homebrew/bin:'+(process.env.PATH||'/usr/bin:/bin'),
  ANDROID_HOME:process.env.ANDROID_HOME||join(process.env.HOME,'Library/Android/sdk'),
  JAVA_HOME:process.env.JAVA_HOME||'/Applications/Android Studio.app/Contents/jbr/Contents/Home'};
 delete environment.GH_TOKEN;delete environment.GITHUB_TOKEN;delete environment.GITHUB_ENV;delete environment.GITHUB_RUN_NUMBER;
 try{
  environment.PATH=join(environment.FLUTTER_ROOT,'bin')+':'+environment.PATH;
  await assembleProject(environment);
  await build(platform,'dependencies',{local:true,work,environment});
  // 先离线解析原锁；正常build仍须让Flutter按Release刷新原生插件注册。
  await run(join(flutterRoot,'bin/flutter'),['pub','get','--offline','--enforce-lockfile'],join(work,'project'),false,environment);
  await build(platform,'app',{local:true,work,environment});
  const output=join(work,'artifact'),files=readdirSync(output).filter(name=>name.endsWith(platform==='ios'?'.app':'.apk'));
  const sdk=environment.ANDROID_HOME;
  process.stdout.write('TATA_COMPILE '+JSON.stringify({schema:1,product_id:'citizenapp',platform,work,artifact:join(output,files[0]),signing:platform==='ios'?appleSigning(join(output,files[0]),join(work,'project/ios/Runner/Runner.entitlements')):[],
   tools:platform==='android'?{adb:join(sdk,'platform-tools/adb'),apksigner:join(sdk,'build-tools/36.0.0/apksigner'),apkanalyzer:join(sdk,'cmdline-tools/latest/bin/apkanalyzer')}:{},
   environment:platform==='android'?{JAVA_HOME:environment.JAVA_HOME,ANDROID_HOME:sdk}:{}})+'\n');
  for await(const part of process.stdin) {} // 消费结束后再释放本轮现场。
  controller.signal.throwIfAborted();
 }catch(error){safe=!groups.size&&!error.keepWork;throw error;}finally{if(safe)rmSync(work,{recursive:true,force:true});}
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => controller.abort());
    try {
        if (process.argv[2] === 'tests') console.log(JSON.stringify(await buildTests(process.argv[3],{scope:process.argv[4]||'all'})));
        else if (process.argv[2] === 'compile') await compile(process.argv[3]);
        else await build(process.argv[2], process.argv[3]);
    } catch (error) {
        console.error(error.message);
        process.exitCode = 1;
    }
}
