// 本脚本消费产品声明的工具和原锁依赖，只负责普通工程装配、编译构建和必要注释。
// config.mjs：只负责配置声明；build.mjs：只负责编译构建实现和必要注释；*.yml：负责全部GitHub流程，包括版本、作业编排、发布及历史清理。
import {spawn, execFileSync} from 'node:child_process';
import {accessSync, constants, appendFileSync, copyFileSync, cpSync, existsSync, mkdirSync, mkdtempSync,
    lstatSync, readFileSync, readdirSync, realpathSync, renameSync, rmSync, writeFileSync} from 'node:fs';
import {join, resolve, dirname, relative, sep} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {api,readReleases,releaseDownloadArgs} from '../.github/release.mjs';

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
                if (retry === (code === 0 && !failure && !controller.signal.aborted ? 20 : 0)) {
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

export async function build(platform, options={}) {
    if (!['ios','android'].includes(platform)) throw Error('未知公民编译平台');
    const environment=options.environment||process.env;
    const work = options.work || environment.WORK ||
        join(root, 'target/build', `${environment.GITHUB_RUN_ID}-${environment.GITHUB_RUN_ATTEMPT}`);
    const project = join(work, 'project');
    const activeMarker = join(work, 'build-active.json');
    if (existsSync(activeMarker)) throw Error('本轮编译现场仍被占用');
    writeFileSync(activeMarker, JSON.stringify({pid: process.pid}), {flag: 'wx', mode: 0o600});
    try {
        const flutter = join(environment.FLUTTER_ROOT, 'bin/flutter');
        // 本机由Flutter读取工程pubspec版本；只有塔塔自动化覆盖正式版号及构建号。
        const version = options.local ? [] : ['--build-name', environment.CITIZENAPP_VERSION,
            '--build-number', environment.GITHUB_RUN_NUMBER];
        const output = join(work, 'artifact');
        if (!options.local) mkdirSync(output);
        const title = `公民·${platform === 'ios' ? 'iOS' : 'Android'}·v${environment.CITIZENAPP_VERSION}`;
        if (platform === 'android') {
            for (const [format, source] of (options.local?[['apk','flutter-apk/app-release.apk']]:[['apk', 'flutter-apk/app-release.apk'], ['appbundle', 'bundle/release/app-release.aab']])) {
                await run(flutter, ['build', format, '--release', '--target-platform', 'android-arm64', ...version], project,false,environment);
                const artifact = join(project, 'build/app/outputs', source);
                if (format === 'apk') await verifyAndroidRuntime(artifact, environment);
                if (options.local) return artifact;
                copyFileSync(artifact, join(output, `${title}.${format === 'apk' ? 'apk' : 'aab'}`));
            }
        } else if(options.local){
            await run(flutter,['build','ios','--release','--no-codesign',...version],project,false,environment);
            return join(project,'build/ios/iphoneos/Runner.app');
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

// SDK只在本轮开始时选择一次正式Release，之后固定准确来源。
export async function selectSDKRelease(product, read) {
    const releases = await readReleases(read, product);
    const candidates = releases.flatMap(release => {
        if (release.draft !== false || release.prerelease !== false || !release.published_at) return [];
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

export async function resolveSDK({root,lock,environment,execute=execFileSync}) {
    const name='citizen_sdk';
    const record=lock.split('\n  '+name+':\n')[1]?.split(/\n  \S/)[0];
    const url=/url: "?(https:\/\/github.com\/[^"\s]+\.git)"?/.exec(record||'')?.[1];
    if (!url) throw Error('pubspec.lock 的 '+name+' 条目缺少可解析的 Git URL');
    const repository=url.slice('https://github.com/'.length,-4),product=repository.split('/')[1];
    const local=resolve(root,'..',product);
    const selected=environment.GITHUB_ACTIONS==='true' ? await selectSDKRelease(product,
        path=>api(environment,path,repository,execute)) : null;
    if (selected) return {name,url,repository,product,local,selected,ref:selected.proof.git_commit_sha,version:selected.proof.software_version};
    const ref=execute('git',['-C',local,'rev-parse','HEAD^{commit}'],{encoding:'utf8',env:environment}).trim();
    if (!/^[a-f0-9]{40}$/u.test(ref)) throw Error(name+'提交身份无效');
    const version=/^version: (\S+)$/mu.exec(
        execute('git',['-C',local,'show',ref+':pubspec.yaml'],{encoding:'utf8',env:environment}))?.[1];
    if (!/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/u.test(version||'')) throw Error(name+'版本声明无效');
    return {name,url,repository,product,local,selected,ref,version};
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

// 仅在普通工程解析冻结SDK的新内部包；原有锁记录不变，不手写SDK包清单。
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
 await execute(flutter,['pub','get'],project,false,environment,'依赖装配');
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
 await execute(flutter,['pub','get','--enforce-lockfile'],project,false,environment,'依赖锁验收');
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
 const execute=io.execFileSync||execFileSync;
const root = environment.GITHUB_WORKSPACE, work = environment.WORK;
const project = join(work, 'project');
// 取当前工作树的源码，插件登记与本机配置交给本轮工程生成。
const listed = execute('git', ['-C', root, 'ls-files', '--cached', '--others', '--exclude-standard', '-z'],
    {encoding: 'utf8', env: environment});
const files = [...new Set(listed.split('\0').filter(Boolean))].filter(entry => existsSync(join(root, entry)));
mkdirSync(project);
execute('/usr/bin/rsync', ['-lp','--from0','--files-from=-',root + '/',project + '/'],
    {input: files.join('\0') + '\0', env: environment});
let lock = readFileSync(join(project, 'pubspec.lock'), 'utf8');
const {name,url,repository,product,local,selected,ref,version}=await resolveSDK({root,lock,environment,execute});
writeFileSync(join(work,'sdk-sources.json'),JSON.stringify({[name]:{
    source:selected?'release':'local_git',software_version:version,git_commit_sha:ref,
    ...(selected?{release_id:selected.release.id,tag_name:selected.release.tag_name,
        producer_run_id:selected.proof.producer_run_id,producer_run_attempt:selected.proof.producer_run_attempt,
        assets:selected.proof.assets}:{}),
}}));
const source = join(work, 'sources', name), output = join(work, 'packages', name);
mkdirSync(source, {recursive: true});
execute('git', ['init', source], {env: environment});
execute('git', ['-C', source, 'fetch', '--depth=1', selected ? url : local, ref], {env: environment});
execute('git', ['-C', source, 'checkout', '--detach', 'FETCH_HEAD'], {env: environment});
mkdirSync(dirname(output), {recursive: true});
const sdk = await import(pathToFileURL(join(source, 'scripts/build.mjs')));
console.log(product + '：' + (selected ? selected.release.tag_name : 'HEAD') + ' ' + ref);
if (selected) {
    const directory = join(work, 'downloads', product);
    mkdirSync(directory, {recursive: true});
    for (const extension of ['zip','json','sha256']) {
        const label=selected.release.tag_name+'.'+extension;
        const args=releaseDownloadArgs({tag:selected.release.tag_name,repo:repository,
            assets:selected.release.assets,label,output:join(directory,label),uploaded:true});
        await run('gh',args,root,false,environment);
    }
    await sdk.consume({directory,sourceSha:ref,sourceRun:selected.proof.producer_run_id,
        sourceAttempt:selected.proof.producer_run_attempt,output,signal:controller.signal});
} else {
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
}
mapSdkSource(project,name,output);
lock = lock.replace(new RegExp('  ' + name + ':\n(?:    .*\n)+'), () =>
    '  ' + name + ':\n    dependency: "direct main"\n    description:\n      path: "' + output +
    '"\n      relative: false\n    source: path\n    version: ' +
    JSON.stringify(/^version: (\S+)$/m.exec(readFileSync(join(output,'pubspec.yaml'),'utf8'))[1]) + '\n');
prepareTests(project);
// Flutter官方模板只写本轮工程；保留既有业务源码和平台工程原件。
const flutter = join(environment.FLUTTER_ROOT, 'bin/flutter');
execute(flutter, ['create', '--empty', '--no-pub', '--platforms=android,ios', '--org=com.crcfrcn', '--project-name=citizenapp', project], {stdio: 'inherit'});
// Gradle 仍会编译模板目录，只移除本轮生成的入口，保留产品自己的 MainActivity。
rmSync(join(project,'android/app/src/main/kotlin/com/crcfrcn/citizenapp/MainActivity.kt'),{force:true});
// create即使不执行Pub也会重写锁；完成后写回只映射SDK路径的完整原锁。
writeFileSync(join(project, 'pubspec.lock'), lock);
const write = (path, text) => {
    mkdirSync(dirname(join(project, path)), {recursive: true});
    writeFileSync(join(project, path), text);
};
const copy = (source, destination) => {
    mkdirSync(dirname(join(project, destination)), {recursive: true});
    copyFileSync(join(root, source), join(project, destination));
};
copy('android/app/AndroidManifest.xml', 'android/app/src/main/AndroidManifest.xml');
copy('ios/project/Runner.pbxproj', 'ios/Runner.xcodeproj/project.pbxproj');
copy('ios/project/Runner.xcscheme', 'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme');
copy('ios/source/Info.plist', 'ios/Runner/Info.plist');
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
         官方商店查询和 CitizenSDK 公民链节点。
         默认阻断一切明文流量，防中间人（iOS 侧由默认 ATS 同等阻断）。 -->
    <base-config cleartextTrafficPermitted="false" />
</network-security-config>
`);
// Podfile和启动页正文沿用现有Flutter官方模板，不在脚本重复维护。
const podfile = join(environment.FLUTTER_ROOT, 'packages/flutter_tools/templates/cocoapods/Podfile-ios');
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
for (const directory of ['drawable','drawable-v21']) {
    const path = 'android/app/src/main/res/' + directory + '/launch_background.xml';
    write(path, readFileSync(join(project,path),'utf8')
        .replace('?android:colorBackground','@android:color/white')
        .replace('<!-- <item>','<item>').replace('</item> -->','</item>'));
}
for (const name of ['ic_launcher','ic_launcher_round']) {
    write('android/app/src/main/res/mipmap-anydpi-v26/' + name + '.xml', `<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
`);
}
for (const [density, icon, foreground, launch] of [['mdpi',48,108,120], ['hdpi',72,162,180], ['xhdpi',96,216,240], ['xxhdpi',144,324,360], ['xxxhdpi',192,432,480]]) {
    const destination = 'android/app/src/main/res/mipmap-' + density + '/';
    for (const name of ['ic_launcher', 'ic_launcher_round']) copy('assets/logo/icon' + icon + '.png', destination + name + '.png');
    copy('assets/logo/foreground' + foreground + '.png', destination + 'ic_launcher_foreground.png');
    copy('assets/logo/launch' + launch + '.png', destination + 'launch_image.png');
}
const iconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/';
const icons = JSON.parse(readFileSync(join(project, iconSet, 'Contents.json')));
for (const image of icons.images) {
    if (!image.filename) continue;
    const size = Number(image.size.split('x')[0]) * Number(image.scale.replace('x', ''));
    copy('assets/logo/icon' + size + '.png', iconSet + image.filename);
}
for (const [scale, suffix] of [[1,''], [2,'@2x'], [3,'@3x']]) copy('assets/logo/launch' + 160 * scale + '.png', 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage' + suffix + '.png');
environment.CITIZENSDK_SOURCE_DIR = output;
if (environment.GITHUB_ENV) appendFileSync(environment.GITHUB_ENV, 'CITIZENSDK_SOURCE_DIR=' + output + '\n');
await preparePackages(project,{sources:[output],environment});
await (io.buildMls || buildMls)({project,work,platform:environment.PLATFORM,environment});
// App随包资源随普通工程一起准备，不增加功能构建入口。
// 本机默认复用本仓npm缓存，缺件由npm按原锁获取。
const assets = join(project, 'topup/web');
const resourceEnvironment = {...environment, npm_config_ignore_scripts: 'true',
    ...(environment.GITHUB_ACTIONS === 'true' ? {} : {npm_config_cache: environment.npm_config_cache ?? environment.NPM_CONFIG_CACHE ?? join(root, 'target/cache/npm')})};
await run('npm', ['ci', '--prefer-offline', '--ignore-scripts', '--no-audit', '--no-fund'], assets, false, resourceEnvironment, 'App资源准备');
await run(environment.ESBUILD_BIN || 'esbuild', ['metamask.js', '--bundle', '--format=iife',
    '--global-name=CitizenTopup', '--platform=browser', '--target=safari15,chrome100', '--minify',
    '--outfile=metamask.bundle.js', '--define:process.env.NODE_ENV="production"'], assets, false, resourceEnvironment, 'App资源准备');
}

const flutterSource = 'https://github.com/flutter/flutter.git';
const flutterVersion = '3.47.2';
const flutterRevision = 'd3b14c876900e553bc736ca19295fc09e3853e8e';

function flutterPaths(environment, cache) {
 return [
  environment.FLUTTER_ROOT, cache,
  ...(environment.PATH || '').split(':').filter(Boolean).map(path => resolve(path, '..')),
  ...readdirSync(dirname(root), {withFileTypes:true})
   .filter(entry => entry.isDirectory() && join(dirname(root), entry.name) !== resolve(root))
   .map(entry => join(dirname(root), entry.name, 'target/cache/flutter')),
 ].filter(Boolean);
}

function writableFlutterCache(tool) {
 try {
  accessSync(join(tool,'bin/cache'),constants.W_OK);
  return true;
 } catch (error) {
  if (['ENOENT','EACCES','EROFS','EPERM'].includes(error.code)) return false;
  throw error;
 }
}

// 本机与塔塔自动化共用同一官方工具准备入口。完整的同版工具直接复用。
export async function prepareFlutter(platform, environment = process.env, {
 cache = join(root, 'target/cache/flutter'), candidates, execute = run,
} = {}) {
 if (!['ios','android'].includes(platform)) throw Error('未知Flutter准备平台');
 const tools = {...environment, GIT_ALLOW_PROTOCOL:'https', FLUTTER_SUPPRESS_ANALYTICS:'true'};
 delete tools.FLUTTER_STORAGE_BASE_URL;
 delete tools.PUB_HOSTED_URL;
 const git = (args, cwd) => execute('/usr/bin/git', args, cwd, true, tools, 'Flutter源码准备');
 const pinned = async tool => await git(['rev-parse','HEAD'], tool) === flutterRevision;
 let source;
 for (const candidate of new Set(candidates ?? flutterPaths(environment, cache))) {
  const command = join(candidate, 'bin/flutter');
  if (!existsSync(command)) continue;
  const tool = dirname(dirname(realpathSync(command)));
  if (!existsSync(join(tool, '.git')) || !await pinned(tool)) continue;
  if (!source || tool === cache) source = tool;
 }
 const parent = dirname(cache);
 mkdirSync(parent, {recursive:true});
 const lock = cache + '.lock';
 mkdirSync(lock);
 let stage, preserve = false;
 try {
  const prepare = async tool => {
   // 平台组件的缓存检查和补件交给官方工具。
   const flags = platform === 'ios' ? ['--ios','--macos'] : ['--android'];
   await execute(join(tool,'bin/flutter'), ['--no-version-check','precache',...flags],
    tool, false, tools, 'Flutter平台引擎准备');
  };
  if (source && writableFlutterCache(source)) {
   await prepare(source);
   return source;
  }
  stage = mkdtempSync(join(parent,'flutter-'));
  const tool = join(stage,'sdk');
  if (source) {
   await execute('/bin/cp',['-R',source,tool],stage,false,tools,'复用Flutter源码和缓存');
   await execute('/bin/chmod',['-R','u+w',tool],stage,false,tools,'准备Flutter缓存权限');
  } else {
   await git(['clone','--branch',flutterVersion,'--depth','1',flutterSource,tool],stage);
  }
  if (!await pinned(tool)) throw Error('Flutter ' + flutterVersion + ' 官方提交不匹配');
  await prepare(tool);
  const previous = join(stage,'previous');
  if (existsSync(cache)) renameSync(cache,previous);
  try {
   renameSync(tool,cache);
  } catch (error) {
   if (existsSync(previous)) {
    preserve = true;
    renameSync(previous,cache);
    preserve = false;
   }
   throw error;
  }
  return cache;
 } finally {
  if (!groups.size && !preserve) {
   if (stage) rmSync(stage,{recursive:true,force:true});
   rmSync(lock,{recursive:true});
  }
 }
}

export async function compile(platform,{prepare = prepareFlutter} = {}){
 const flutterRoot=await prepare(platform);
 const parent=join(root,'target/build');mkdirSync(parent,{recursive:true});
 if(realpathSync(parent)!==parent)throw Error('本机编译现场经过链接');
 const work=mkdtempSync(join(parent,'local-'));let safe=true;
 const cache=join(root,'target/cache');mkdirSync(cache,{recursive:true});
 // 本机保留pubspec版本声明，签名及设备安装仍归控制台。
 const environment={...process.env,GITHUB_ACTIONS:'false',GITHUB_WORKSPACE:root,WORK:work,PLATFORM:platform,
  GIT_ALLOW_PROTOCOL:'file:https',
  FLUTTER_ROOT:flutterRoot,PUB_CACHE:process.env.PUB_CACHE||join(process.env.HOME,'.pub-cache'),GRADLE_USER_HOME:process.env.GRADLE_USER_HOME||join(dirname(flutterRoot),'gradle'),
  CARGO_TARGET_DIR:process.env.CARGO_TARGET_DIR||join(cache,'rust'),RUSTUP_TOOLCHAIN:'1.97.1',
  PATH:process.env.HOME+'/.cargo/bin:'+process.env.HOME+'/.nvm/versions/node/v25.2.1/bin:/opt/homebrew/bin:'+(process.env.PATH||'/usr/bin:/bin'),
  ANDROID_HOME:process.env.ANDROID_HOME||join(process.env.HOME,'Library/Android/sdk'),
  JAVA_HOME:process.env.JAVA_HOME||'/Applications/Android Studio.app/Contents/jbr/Contents/Home'};
 delete environment.GH_TOKEN;delete environment.GITHUB_TOKEN;delete environment.GITHUB_ENV;delete environment.GITHUB_RUN_NUMBER;
 try{
  environment.PATH=join(environment.FLUTTER_ROOT,'bin')+':'+environment.PATH;
  await assembleProject(environment);
  const artifact=await build(platform,{local:true,work,environment});
  const sdk=environment.ANDROID_HOME;
  process.stdout.write('TATA_COMPILE '+JSON.stringify({schema:1,product_id:'citizenapp',platform,work,artifact,signing:platform==='ios'?appleSigning(artifact,join(work,'project/ios/Runner/Runner.entitlements')):[],
   sdk_sources:JSON.parse(readFileSync(join(work,'sdk-sources.json'),'utf8')),
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
        else if (process.argv[2] === 'prepare-flutter') {
            const tool = await prepareFlutter(process.argv[3]);
            if (process.env.GITHUB_ENV) appendFileSync(process.env.GITHUB_ENV, 'FLUTTER_ROOT=' + tool + '\n');
            if (process.env.GITHUB_PATH) appendFileSync(process.env.GITHUB_PATH, join(tool,'bin') + '\n');
            console.log('Flutter ' + flutterVersion + '：' + tool);
        }
        else {
            if (process.argv.length !== 3) throw Error('编译只接受平台参数');
            await build(process.argv[2]);
        }
    } catch (error) {
        console.error(error.message);
        process.exitCode = 1;
    }
}


// 聊天是本仓本地业务包；OpenMLS 仅由 App 唯一构建入口编译和链接。
export async function buildMls({project,work,platform,environment=process.env,execute=run}) {
 const manifest=join(project,'chat/mls/Cargo.toml');
 const target=environment.CARGO_TARGET_DIR||join(root,'target/cache/rust');
 const base={...environment,RUSTUP_TOOLCHAIN:'1.97.1',CARGO_TARGET_DIR:target};
 const args=['build','--manifest-path',manifest,'--locked','--release'];
 const own=join(work,'mls');mkdirSync(own,{recursive:true});
 if(platform==='host'){
  const triple='aarch64-apple-darwin', output=join(own,'host/libmls.dylib');
  await execute('cargo',[...args,'--target',triple],project,false,{...base,
   CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS:'-C strip=none -C link-arg=-Wl,-install_name,@rpath/libmls.dylib'},'OpenMLS宿主编译');
  mkdirSync(dirname(output),{recursive:true});
  copyFileSync(join(target,triple,'release/libmls.dylib'),output);
  return output;
 }
 if(platform==='android'){
  if(!environment.ANDROID_HOME)throw Error('OpenMLS Android编译缺少ANDROID_HOME');
  const ndk=join(environment.ANDROID_HOME,'ndk','28.2.13676358','toolchains/llvm/prebuilt',globalThis.process.platform==='darwin'?'darwin-x86_64':'linux-x86_64','bin');
  const clang=join(ndk,'aarch64-linux-android24-clang');
  await execute('cargo',[...args,'--target','aarch64-linux-android'],project,false,{...base,
   CC_aarch64_linux_android:clang,AR_aarch64_linux_android:join(ndk,'llvm-ar'),
   CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER:clang,
   CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS:'-C link-arg=-Wl,-z,max-page-size=16384'},'OpenMLS Android编译');
  const destination=join(project,'android/app/src/main/jniLibs/arm64-v8a');mkdirSync(destination,{recursive:true});
  copyFileSync(join(target,'aarch64-linux-android/release/libmls.so'),join(destination,'libmls.so'));
  const component=join(own,'android/arm64-v8a');mkdirSync(component,{recursive:true});copyFileSync(join(destination,'libmls.so'),join(component,'libmls.so'));
 }
 if(platform==='ios'){
  const slices=[];
  for(const [triple,sdk]of [['aarch64-apple-ios','iphoneos'],['aarch64-apple-ios-sim','iphonesimulator']]){
   const sdkPath=execFileSync('/usr/bin/xcrun',['--sdk',sdk,'--show-sdk-path'],{encoding:'utf8'}).trim();
   const key='CARGO_TARGET_'+triple.toUpperCase().replaceAll('-','_')+'_RUSTFLAGS';
   await execute('cargo',[...args,'--target',triple],project,false,{...base,IPHONEOS_DEPLOYMENT_TARGET:'16.0',
    [key]:'-C strip=none -C link-arg=-isysroot -C link-arg='+sdkPath+' -C link-arg=-Wl,-install_name,@rpath/MLS.framework/MLS'},'OpenMLS iOS编译');
   await verifyMls(join(target,triple,'release/libmls.dylib'),sdk==='iphoneos'?'ios':'ios-simulator');
   const framework=join(own,triple,'MLS.framework');mkdirSync(join(framework,'Headers'),{recursive:true});mkdirSync(join(framework,'Modules'),{recursive:true});
   copyFileSync(join(target,triple,'release/libmls.dylib'),join(framework,'MLS'));
   copyFileSync(join(project,'chat/mls/mls.h'),join(framework,'Headers/mls.h'));
   writeFileSync(join(framework,'Modules/module.modulemap'),'framework module MLS {\n umbrella header "mls.h"\n export *\n}\n');
   writeFileSync(join(framework,'Info.plist'),'<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>MLS</string><key>CFBundleIdentifier</key><string>com.crcfrcn.citizenapp.chat.mls</string><key>CFBundleName</key><string>MLS</string><key>CFBundlePackageType</key><string>FMWK</string><key>CFBundleShortVersionString</key><string>1.0.0</string><key>CFBundleVersion</key><string>1</string><key>MinimumOSVersion</key><string>16.0</string></dict></plist>');
   slices.push('-framework',framework);
  }
  const framework=join(project,'ios/Frameworks/MLS.xcframework');mkdirSync(dirname(framework),{recursive:true});
  rmSync(framework,{recursive:true,force:true});
  await execute('/usr/bin/xcodebuild',['-create-xcframework',...slices,'-output',framework],project,false,base,'OpenMLS iOS装配');
 }
}

export async function verifyMls(file,platform){
 if(!lstatSync(file).isFile())throw Error('OpenMLS产物缺失');
 const nm=platform==='android'?join(process.env.ANDROID_HOME||join(process.env.HOME,'Library/Android/sdk'),'ndk/28.2.13676358/toolchains/llvm/prebuilt',process.platform==='darwin'?'darwin-x86_64':'linux-x86_64','bin/llvm-nm'):'/usr/bin/nm';
 const symbols=execFileSync(nm,platform==='android'?['-D','--defined-only',file]:['-g',file],{encoding:'utf8'});
 const header=readFileSync(join(root,'chat/mls/mls.h'),'utf8');
 const expected=[...header.matchAll(/\b(mls_[a-z_]+)\s*\(/gu)].map(m=>m[1]);
 if(expected.length!==10)throw Error('OpenMLS公开头的符号集合不完整');
 for(const name of expected){
  if(!new RegExp('(?:^|\\s)_?'+name+'(?:\\s|$)','u').test(symbols))throw Error('OpenMLS缺少FFI符号：'+name);
 }
 if(platform!=='android'){
  const commands=execFileSync('/usr/bin/xcrun',['otool','-l',file],{encoding:'utf8'});
  const offset=/cmd LC_SYMTAB[\s\S]*?\bstroff\s+(\d+)/u.exec(commands)?.[1];
  if(!offset||BigInt(offset)%8n!==0n)throw Error('OpenMLS Mach-O字符串表未按8字节对齐');
 }

}
