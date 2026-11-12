import {test} from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync, spawn, spawnSync} from 'node:child_process';
import {chmodSync, copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {assembleProject,selectSDKRelease,resolveSDK,prepareFlutter,build,buildMls} from '../../scripts/build.mjs';
import {describeAction,testSuites} from '../../scripts/config.mjs';
import {prepareIsar,readVersion,releaseDownloadArgs} from '../../.github/release.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const pubspec = readFileSync(join(root, 'pubspec.yaml'), 'utf8');
const pubLock = readFileSync(join(root, 'pubspec.lock'), 'utf8');
const podLock = readFileSync(join(root, 'ios/Podfile.lock'), 'utf8');

test('发布脚本 CLI 能加载装配模块并返回实际输入错误',()=>{
    const result=spawnSync(process.execPath,[join(root,'.github/release.mjs'),'assemble','ios'],
        {cwd:root,encoding:'utf8',env:{}});
    assert.equal(result.status,1,result.stderr);
    assert.match(result.stderr,/path.*argument.*undefined/u);
});

test('工程装配读取实际工作树并排除本机生成物', async t => {
    const base = join(root, 'target/test');
    mkdirSync(base, {recursive: true});
    const source = mkdtempSync(join(base, 'assemble-source-'));
    t.after(() => rmSync(source, {recursive: true, force: true}));
    const work = join(source, 'target/build');
    mkdirSync(work, {recursive: true});
    assert.equal(spawnSync('git', ['init', '-q', source]).status, 0);
    copyFileSync(join(root, '.gitignore'), join(source, '.gitignore'));

    const put = (path, content) => {
        const file = join(source, path);
        mkdirSync(dirname(file), {recursive: true});
        writeFileSync(file, content);
    };
    const tracked = 'android/app/MainActivity.kt';
    const untracked = 'ios/chat/ChatStorageChannel.swift';
    put(tracked, '已暂存的输入');
    assert.equal(spawnSync('git', ['-C', source, 'add', '--', tracked]).status, 0);
    put(tracked, '工作树中的修改');
    put(untracked, '新增平台源码');
    put('ios/chat/space name.swift', '文件名含空格');
    put('android/app/AndroidManifest.xml', '平台清单');
    put('ios/chat/ChatMediaChannel.swift', '另一份平台源码');
    put('pubspec.yaml', 'name: fixture\n');
    put('pubspec.lock', 'packages:\n');

    const generated = [
        'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
        'ios/Runner/GeneratedPluginRegistrant.m',
        'ios/Flutter/Generated.xcconfig',
        'chat/.dart_tool/pub/workspace_ref.json',
        'topup/web/node_modules/generated.js',
    ];
    for (const path of generated) put(path, '本机生成物');

    const environment = {...process.env, GITHUB_WORKSPACE: source, WORK: work};
    // 缺少 SDK 声明时在源码装配后停止，无需启动工具下载或原生编译。
    await assert.rejects(assembleProject(environment), /pubspec.lock 的 citizen_sdk 条目缺少可解析的 Git URL/);
    const project = join(work, 'project');
    assert.equal(readFileSync(join(project, tracked), 'utf8'), '工作树中的修改');
    assert.equal(readFileSync(join(project, untracked), 'utf8'), '新增平台源码');
    assert.equal(readFileSync(join(project,'ios/chat/space name.swift'),'utf8'),'文件名含空格');
    for (const path of generated) assert.equal(existsSync(join(project, path)), false, path);
});

// 合成工具只记录编译调用和生成占位字节，不下载、不调用Flutter或真实签名。
function fixture(t, platform = 'android') {
    const base = join(root, 'target/test');
    mkdirSync(base, {recursive: true});
    const directory = mkdtempSync(join(base, 'compile-'));
    t.after(() => rmSync(directory, {recursive: true, force: true}));
    for (const path of ['scripts', '.github', 'bin', 'target/build/21-1/project']) {
        mkdirSync(join(directory, path), {recursive: true});
    }
    copyFileSync(join(root, 'scripts/build.mjs'), join(directory, 'scripts/build.mjs'));
    copyFileSync(join(root, '.github/release.mjs'), join(directory, '.github/release.mjs'));
    const executable = (name, code) => {
        const path = join(directory, 'bin', name);
        writeFileSync(path, '#!' + process.execPath + '\n' + code);
        chmodSync(path, 0o700);
    };
    executable('git', 'console.log(process.argv.includes("show")?"version: 1.0.0":"a".repeat(40));');
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
    const android = join(directory, 'android');
    const analyzer = join(android, 'cmdline-tools/latest/bin/apkanalyzer');
    mkdirSync(dirname(analyzer), {recursive: true});
    writeFileSync(analyzer, '#!' + process.execPath + '\n' + `
        const fs=require('node:fs');
        const args=process.argv.slice(2);
        if(args.slice(0,4).join(' ')!=='dex code --class kotlin.Unit'||fs.readFileSync(args[4],'utf8')!=='fixture-apk')process.exit(19);
        fs.appendFileSync(process.env.DEX_CALLS,JSON.stringify(args)+'\\n');
        if(process.env.DEX_MODE==='error')process.exit(17);
        if(process.env.DEX_MODE==='missing-class')console.log('const-string \"kotlin.Unit\" INSTANCE');
        else {
            console.log('.class public final Lkotlin/Unit;');
            if(process.env.DEX_MODE!=='missing-field')console.log('.field public static final INSTANCE:Lkotlin/Unit;');
        }
    `, {mode: 0o700});
    const env = {
        ...process.env, PATH: join(directory, 'bin') + ':' + process.env.PATH,
        GITHUB_ACTIONS: 'true', GITHUB_REPOSITORY: 'crcfrcn/citizenapp',
        GITHUB_REF: 'refs/heads/main', GITHUB_EVENT_NAME: 'workflow_dispatch',
        GITHUB_WORKFLOW_REF: 'crcfrcn/citizenapp/.github/workflows/' + platform + '.yml@refs/heads/main',
        GITHUB_RUN_ID: '21', GITHUB_RUN_ATTEMPT: '1', GITHUB_RUN_NUMBER: '9',
        GITHUB_SHA: 'a'.repeat(40), CITIZENAPP_VERSION: '1.2.3',
        WORK: join(directory, 'target/build/21-1'),
        ANDROID_HOME: android, DEX_CALLS: join(directory, 'dex-calls.json'),
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
        assert.equal(existsSync(value.env.DEX_CALLS),platform==='android');
        if(platform==='android')assert.equal(readFileSync(value.env.DEX_CALLS,'utf8').trim().split('\n').length,1);
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
    const artifact=await build('android',{local:true,work:value.env.WORK,
        environment:{...value.env,CITIZENAPP_BUILD_NUMBER:'40'}});
    assert.equal(artifact,join(value.env.WORK,'project/build/app/outputs/flutter-apk/app-release.apk'));
    assert.equal(existsSync(join(value.env.WORK,'artifact')),false);
    const calls=readFileSync(value.env.CALLS,'utf8').trim().split('\n').map(JSON.parse);
    assert.equal(calls.length,1);
    assert.equal(calls[0][calls[0].indexOf('--build-number')+1],'40');
    assert.equal(calls[0].includes('--no-pub'),false);
    assert.equal(value.env.GITHUB_RUN_NUMBER,'9');
});

test('本机编译接收正式版号，CitizenSDK只取本地HEAD', t => {
    const value=fixture(t);
    writeFileSync(join(value.directory,'pubspec.yaml'),pubspec);
    writeFileSync(join(value.directory,'pubspec.lock'),pubLock);
    writeFileSync(join(value.directory,'bin/git'), '#!'+process.execPath+'\n'+
        'require("node:fs").writeFileSync('+JSON.stringify(join(value.directory,'git-protocol.txt'))+',process.env.GIT_ALLOW_PROTOCOL);\n'+
        'if(process.argv.includes("ls-files")) process.stdout.write(["pubspec.yaml","pubspec.lock",""].join(String.fromCharCode(0)));\n'+
        'else console.log(process.argv.includes("show")?"version: 1.0.0":"a".repeat(40));');
    // 合成git不创建SDK模块；到达本地模块加载后终止，禁止实际工具和网络。
    const code=`const {compile}=await import(${JSON.stringify(pathToFileURL(value.script).href)});
        try{await compile('android',{prepare:async()=>process.env.FLUTTER_ROOT,readVersion:async()=>({version:'1.0.0',buildNumber:'1'})})}
        catch(error){console.error(error.message);process.exitCode=17}`;
    const result=spawnSync(process.execPath,['--input-type=module','-e',code],{env:value.env,encoding:'utf8'});
    assert.equal(result.status,17);
    assert.match(result.stderr,/Cannot find module/);
    assert.doesNotMatch(result.stderr,/合成SDK远端禁止调用|读取GitHub Run失败/);
    assert.equal(existsSync(value.env.CALLS),false);
    assert.equal(readFileSync(join(value.directory,'git-protocol.txt'),'utf8'),'file:https');
});

for (const phase of ['app']) {
    test(phase + '取消等待真实合成工具退出后才释放本轮编译标记', {timeout: 15000}, async t => {
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
}

test('已删除的依赖阶段参数不会启动编译', t => {
    const value = fixture(t);
    const result = spawnSync(process.execPath, [value.script, 'android', 'dependencies'], {env: value.env, encoding: 'utf8'});
    assert.equal(result.status, 1, result.stderr);
    assert.match(result.stderr,/编译只接受平台参数/);
    assert.equal(existsSync(value.env.CALLS), false);
    assert.equal(existsSync(join(value.directory, 'target/build/21-1/build-active.json')), false);
});

test('两端塔塔自动化在装配前调用本机共用的Flutter准备入口', () => {
    for (const platform of ['ios','android']) {
        const workflow = readFileSync(join(root, '.github/workflows', platform + '.yml'), 'utf8');
        const prepare = workflow.indexOf('node .github/release.mjs prepare ' + platform);
        const assemble = workflow.indexOf('node .github/release.mjs assemble ' + platform);
        assert.ok(prepare >= 0 && assemble > prepare);
        assert.doesNotMatch(workflow, /git clone .*github\.com\/flutter\/flutter/u);
    }
});

const releaseScript = join(root,'.github/release.mjs');
for(const platform of ['ios','android']) test(platform+'共用入口准备原版本工具并保护占用现场',t=>{
    const {directory,env}=fixture(t), sdk=join(directory,'Library/Android/sdk');
    const sdkmanager=join(sdk,'cmdline-tools/latest/bin/sdkmanager'), calls=join(directory,'prepare.jsonl');
    const code='process.getBuiltinModule("node:fs").appendFileSync(process.env.PREPARE_CALLS,JSON.stringify(process.argv.slice(1))+"\\n");';
    mkdirSync(dirname(sdkmanager),{recursive:true});
    for(const path of [sdkmanager,...['gem','npm','rustup'].map(name=>join(directory,'bin',name))])
        writeFileSync(path,'#!'+process.execPath+'\n'+code,{mode:0o700});
    writeFileSync(join(directory,'scripts/build.mjs'),code);
    mkdirSync(join(directory,'topup/web'),{recursive:true});
    copyFileSync(join(root,'topup/web/package.json'),join(directory,'topup/web/package.json'));
    const input={...env,HOME:directory,GITHUB_WORKSPACE:directory,GITHUB_ENV:join(directory,'env'),
        GITHUB_PATH:join(directory,'path'),PREPARE_CALLS:calls};
    const invoke=(step,work=env.WORK)=>spawnSync(process.execPath,[releaseScript,step,platform],
        {cwd:directory,env:{...input,WORK:work},encoding:'utf8'});
    const prepared=invoke('prepare');
    assert.equal(prepared.status,0,prepared.stderr);
    const commands=readFileSync(calls,'utf8').trim().split('\n').map(JSON.parse);
    assert.deepEqual(commands.find(([file])=>file.endsWith('build.mjs')).slice(1),['prepare-flutter',platform]);
    assert.ok(commands.some(args=>args.includes('esbuild@0.28.1')));
    const sdkArgs=commands.find(([file])=>file===sdkmanager);
    assert.ok(sdkArgs.includes('cmake;3.31.6'));
    assert.equal(sdkArgs.includes('ndk;28.2.13676358'),platform==='android');
    assert.equal(commands.some(args=>args.includes('cocoapods')),platform==='ios');
    const marker=join(env.WORK,'build-active.json');
    writeFileSync(marker,'{}');
    const occupied=invoke('cleanup-work');
    assert.notEqual(occupied.status,0);
    assert.match(occupied.stderr,/保留现场/);
    assert.notEqual(invoke('cleanup-work',directory).status,0);
    assert.ok(existsSync(marker));
    rmSync(marker);
    const cleaned=invoke('cleanup-work');
    assert.equal(cleaned.status,0,cleaned.stderr);
    assert.ok(!existsSync(env.WORK));
});

function versionFor(platform,{releases=[],read=()=>releases,initial='1.0.0',installed=false}={}) {
    const calls=[];
    return {calls,run:async()=>{
        const version=await readVersion(platform,installed,{},{
            read:path=>{
                if(!path.startsWith('releases?')) calls.push(path);
                return read(path);
            },
            readInitial:()=> 'version: '+initial+'\n'
        });
        return installed?JSON.stringify(version):'version='+version;
    }};
}
for (const platform of ['ios', 'android']) {
    const label = platform === 'ios' ? 'iOS' : 'Android';
    const release = (version,id,date,extra={}) => ({id,tag_name:'公民·'+label+'·v'+version,
      draft:false,prerelease:false,published_at:date,body:JSON.stringify({schema:1,product_id:'citizenapp',
       platform,version,version_code:id,run_id:id,run_attempt:1,source_sha:'a'.repeat(40)}),...extra});
    const run = (conclusion='success') => ({status:'completed',conclusion,path:'.github/workflows/'+platform+'.yml',
      head_branch:'main',event:'workflow_dispatch',head_sha:'a'.repeat(40),run_attempt:1});
    test(platform + '本机与自动化共用分页和成功Run，分别保留构建号与递增版本', async () => {
        const workflow=readFileSync(join(root,'.github/workflows/'+platform+'.yml'),'utf8');
        assert.ok(workflow.includes('run: node .github/release.mjs version ' + platform));
        const latest=release('1.0.99',10,'2026-02-01');
        const read=path=>path.endsWith('&page=1')?[release('1.0.100',11,'2026-03-01'),
            release('9.0.0',12,'2026-04-01',{draft:true}),...Array(98).fill({draft:true})]
            :path.endsWith('&page=2')?[release('1.0.98',9,'2026-01-01'),latest,
                release('8.0.0',13,'2026-05-01',{prerelease:true})]:run(path.endsWith('/11')?'failure':'success');
        const ci=versionFor(platform,{read});
        assert.equal(await ci.run(),'version=1.0.100');
        assert.deepEqual(ci.calls,['actions/runs/11','actions/runs/10']);
        const local=options=>versionFor(platform,{...options,installed:true}).run();
        assert.deepEqual(JSON.parse(await local({read})),{version:'1.0.99',buildNumber:'10'});
        const initial='1.2.3+9';
        assert.equal(await versionFor(platform,{initial}).run(),'version=1.2.3');
        assert.deepEqual(JSON.parse(await local({initial})),{version:'1.2.3',buildNumber:'9'});
        for(const installed of [false,true]){
            const verify=options=>versionFor(platform,{...options,installed}).run;
            await assert.rejects(verify({releases:[release('1.0.01',10,'2026-01-01')]}),/正式版本记录无效/);
            await assert.rejects(verify({read:()=>({})}),/正式Release列表无效/);
            const failure=new Error('合成GitHub读取错误');
            await assert.rejects(verify({read:()=>{throw failure}}),error=>error===failure);
        }
    });
    test(platform + '平台装配正文读取真实原件并生成必要标准配置', () => {
        const all = assembleProject.toString().replaceAll('execute(','execFileSync(');
        const body = all.slice(all.indexOf('// Flutter官方模板'), all.indexOf("environment.CITIZENSDK_SOURCE_DIR = output"));
        const files = new Map(), copies = [], tools = [], removed = [];
        const project = '/fixture/project';
        const generatedActivity = join(project,'android/app/src/main/kotlin/com/crcfrcn/citizenapp/MainActivity.kt');
        const productActivity = join(project,'android/app/MainActivity.kt');
        files.set(productActivity,'产品入口');
        const icon = project + '/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json';
        const fsRead = path => {
            if (files.has(path)) return files.get(path);
            if (path === icon) return JSON.stringify({images:[{size:'20x20',scale:'2x',filename:'Icon-App-20x20@2x.png'}]});
            if (path === '/fixture/flutter/packages/flutter_tools/templates/cocoapods/Podfile-ios') {
                return "# platform :ios, '15.0'\nflutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))\npost_install do |installer|\nflutter_additional_ios_build_settings(target)\nend\n";
            }
            throw Error('未声明读取：' + path);
        };
        new Function('execFileSync', 'readFileSync', 'writeFileSync', 'appendFileSync', 'mkdirSync', 'copyFileSync', 'rmSync', 'readdirSync',
            'join', 'dirname', 'root', 'work', 'project', 'environment', 'lock', body)(
            (command,args) => {
                assert.equal(command, '/fixture/flutter/bin/flutter', '装配不得调用未声明工具');
                assert.equal(args[0], 'create');
                tools.push([command,args]);
                files.set(generatedActivity,'Flutter 模板入口');
                // 对应原锁Flutter的create：--no-pub仍会用模板依赖重写工程锁。
                files.set(project + '/pubspec.lock', '{"packages":{}}');
                files.set(project + '/android/build.gradle.kts', 'rootProject.layout.buildDirectory.dir("../../build")');
                files.set(project + '/android/settings.gradle.kts', 'plugins { id("dev.flutter.flutter-plugin-loader") version "1.0.0"\nid("com.android.application") version "8.0.0" apply false\nid("org.jetbrains.kotlin.android") version "2.0.0" apply false }\ninclude(":app")');
                files.set(project + '/android/gradle.properties', 'android.useAndroidX=true\n');
                files.set(project + '/android/gradle/wrapper/gradle-wrapper.properties', 'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.0.0-bin.zip\n');
                files.set(project + '/ios/Runner/Base.lproj/LaunchScreen.storyboard', '<image name="LaunchImage" width="168" height="185"/>');
                for (const directory of ['drawable','drawable-v21']) {
                    const color = directory === 'drawable' ? '@android:color/white' : '?android:colorBackground';
                    files.set(project + '/android/app/src/main/res/' + directory + '/launch_background.xml',
                        '<layer-list><item android:drawable="' + color + '" /><!-- <item><bitmap android:src="@mipmap/launch_image" /></item> --></layer-list>');
                }
                files.set(project + '/android/app/src/main/res/values/styles.xml', 'Flutter官方主题');
                files.set(project + '/ios/Runner/Runner-Bridging-Header.h', '#import "GeneratedPluginRegistrant.h"');
            }, fsRead, (path,text) => files.set(path,text),
            (path,text) => files.set(path,(files.get(path)||'')+text), () => {},
            (source,destination) => copies.push([source,destination]), path => { removed.push(path); assert.ok(files.delete(path)); },
            path => { assert.equal(path,'/fixture/source/android/tests');return ['MlsTransportSecurityInstrumentedTest.kt','RegistrationRecordSecurityInstrumentedTest.kt','SquareMediaChannelInstrumentedTest.kt']; }, join, dirname,
            '/fixture/source','/fixture',project,{FLUTTER_ROOT:'/fixture/flutter'},pubLock);
        assert.equal(tools.length, 1, '只允许本轮Flutter模板生成命令');
        assert.ok(tools[0][1].includes('--platforms=android,ios'));
        assert.ok(tools[0][1].includes('--empty'));
        assert.equal(files.get(project + '/pubspec.lock'), pubLock, '模板生成后必须完整恢复传入的锁，不重新解版本');
        assert.deepEqual(removed,[generatedActivity]);
        assert.equal(files.get(productActivity),'产品入口');
        assert.ok(copies.some(([source,target]) => source.endsWith('ios/project/Runner.pbxproj') && target.endsWith('Runner.xcodeproj/project.pbxproj')));
        assert.ok(!copies.some(([source]) => /\.(kt|java|swift)$/u.test(source)));
        const gradle=readFileSync(join(root,'android/app/build.gradle.kts'),'utf8');
        for(const path of ['../chat','../square','../tests']) assert.ok(gradle.includes('"'+path+'"'));
        const xcode=readFileSync(join(root,'ios/project/Runner.pbxproj'),'utf8');
        for(const path of ['source/AppDelegate.swift','square/SquareMediaChannel.swift','chat/ChatStorageChannel.swift','tests/RunnerTests.swift','tests/RunnerUITests.swift']){
            assert.ok(xcode.includes('path = '+path+'; sourceTree = SOURCE_ROOT;'));
            assert.ok(existsSync(join(root,'ios',path)));
        }
        assert.ok(copies.some(([source,target]) => source.endsWith('assets/logo/icon40.png') && target.endsWith('Icon-App-20x20@2x.png')));
        assert.match(files.get(project+'/android/app/src/main/res/values/strings.xml'), /<string name="app_name">公民<\/string>/);
        assert.match(files.get(project+'/android/app/src/main/res/values-en/strings.xml'), />CitizenApp</);
        assert.match(files.get(project+'/android/app/src/main/res/xml/network_security_config.xml'), /cleartextTrafficPermitted="false"/);
        assert.match(files.get(project+'/ios/Runner/Runner.entitlements'), /\$\(APS_ENVIRONMENT\)/);
        assert.match(files.get(project+'/ios/Podfile'), /flutter_install_all_ios_pods/);
        assert.match(files.get(project+'/ios/Podfile'), /isar_community_flutter_libs\/libisar\.a/);
        for (const directory of ['drawable','drawable-v21']) {
            const launch = files.get(project + '/android/app/src/main/res/' + directory + '/launch_background.xml');
            assert.match(launch, /@android:color\/white/);
            assert.match(launch, /<item><bitmap android:src="@mipmap\/launch_image" \/><\/item>/);
            assert.doesNotMatch(launch, /<!-- <item>/);
        }
        assert.equal(files.get(project+'/android/app/src/main/res/values/styles.xml'), 'Flutter官方主题');
        assert.equal(files.get(project+'/ios/Runner/Runner-Bridging-Header.h'), '#import "GeneratedPluginRegistrant.h"');
        assert.match(files.get(project+'/ios/Runner/Base.lproj/CitizenLaunchScreen.storyboard'), /name="LaunchImage" width="160" height="160"/);
        const launchImages = 'ios/Runner/Assets.xcassets/LaunchImage.imageset/';
        for (const [size,suffix] of [[160,''],[320,'@2x'],[480,'@3x']]) {
            assert.ok(copies.some(([source,target]) => source.endsWith('/assets/logo/launch'+size+'.png')
                && target === project+'/'+launchImages+'LaunchImage'+suffix+'.png'));
        }
        assert.ok(!files.has(project+'/'+launchImages+'Contents.json'));
        assert.match(files.get(project+'/android/gradle.properties'), /android\.builtInKotlin=false/);
        assert.match(files.get(project+'/android/gradle/wrapper/gradle-wrapper.properties'), /gradle-9\.1\.0-bin\.zip/);
    });
}

test('共用入口从真实包根URI定位Isar，保留转义路径和缺件行为',t=>{
    const {directory:work}=fixture(t), cache=join(work,'cache pub/isar_community_flutter_libs-3.3.2');
    const config=join(work,'project/.dart_tool/package_config.json'), output=join(work,'env');
    mkdirSync(dirname(config),{recursive:true});
    mkdirSync(join(cache,'macos'),{recursive:true});
    const source=join(cache,'macos/libisar.dylib');
    writeFileSync(source,'Isar测试输入');
    const environment={WORK:work,GITHUB_ENV:output};
    for(const uri of [pathToFileURL(cache).href,'../../cache%20pub/isar_community_flutter_libs-3.3.2']){
        for(const suffix of ['', '/']){
            writeFileSync(output,'');
            writeFileSync(config,JSON.stringify({packages:[{name:'isar_community_flutter_libs',rootUri:uri+suffix}]}));
            prepareIsar(environment);
            assert.equal(readFileSync(join(work,'libisar.dylib'),'utf8'),'Isar测试输入');
            assert.equal(readFileSync(output,'utf8'),'ISAR_CORE_LIB_PATH='+join(work,'libisar.dylib')+'\n');
        }
    }
    writeFileSync(output,'');
    rmSync(source);
    assert.throws(()=>prepareIsar(environment),/ENOENT/);
    writeFileSync(config,JSON.stringify({packages:[]}));
    assert.throws(()=>prepareIsar(environment),/原锁缺少Isar/);
    assert.equal(readFileSync(output,'utf8'),'');
});

test('CitizenSDK声明来源，仓库锁只保留SDK基线', () => {
    for (const name of ['citizen_sdk']) {
        const declaration = pubspec.split('  ' + name + ':\n')[1]?.split(/\n  \S/)[0];
        const record = pubLock.split('\n  ' + name + ':\n')[1]?.split(/\n  \S/)[0];
        const ref = /resolved-ref: "?([a-f0-9]{40})"?/.exec(record || '')?.[1];
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
    assert.match(preview, /qr[.]openQrCapture\(purpose\)/u);
    assert.match(preview, /Texture\(textureId: capture[.]textureId\)/u);
    assert.match(display, /qr[.]encodeQr\(widget[.]data, scale: 1\)/u);
    const caller = readFileSync(join(root, 'lib/scan_dispatch_flow.dart'), 'utf8');
    assert.ok(caller.includes("import 'package:citizen_sdk/citizen_sdk.dart';"));
    assert.equal(caller.includes('package:citizen_sdk/src/'), false);
});

test('CitizenSDK自动化均使用正式Release及所属SDK消费入口', async () => {
    const builder = readFileSync(join(root, 'scripts/build.mjs'), 'utf8');
    for (const platform of ['ios', 'android']) {
        const workflow = readFileSync(join(root, '.github/workflows', platform + '.yml'), 'utf8');
        assert.doesNotMatch(workflow, /sdk_run|CITIZENSDK_PACKAGE|CITIZENSDK_ATTEMPT/u);
        assert.ok(workflow.includes('run: node .github/release.mjs assemble ' + platform));
    }
    assert.match(builder, /rev-parse','HEAD\^\{commit\}'/u);
    assert.match(builder, /sdk\.consume\(/u);
    assert.doesNotMatch(builder, /请指定已成功|缺少本产品原锁的完整SDK交付目录/u);
    const action = await describeAction({flow:'release',platform:'android'});
    assert.deepEqual(action,{repository:'crcfrcn/citizenapp',workflow:'android.yml',ref:'main',inputs:{}});
    assert.doesNotMatch(builder,/requireAutomationBuild|sandbox-exec|CITIZENAPP_OFFLINE|缺少SDK声明的现有ZXing/);

});

const flutterRevision = 'd3b14c876900e553bc736ca19295fc09e3853e8e';
function flutterFiles(tool) {
    mkdirSync(join(tool,'.git'), {recursive:true});
    mkdirSync(join(tool,'bin/cache'), {recursive:true});
    writeFileSync(join(tool,'bin/flutter'),'fixture');
}

test('同版Flutter直接交官方precache复用对应平台缓存', async t => {
    const cache = join(fixture(t).directory, 'target/cache/flutter');
    flutterFiles(cache);
    const commands = [];
    const execute = async (file, args) => {
        if (args[0] === 'rev-parse') return flutterRevision;
        commands.push([file,args]);
    };
    const options = {cache, candidates:[cache], execute};
    for (const platform of ['android','ios']) {
        assert.equal(await prepareFlutter(platform, {}, options), cache);
    }
    assert.deepEqual(commands, [
        [join(cache,'bin/flutter'), ['--no-version-check','precache','--android']],
        [join(cache,'bin/flutter'), ['--no-version-check','precache','--ios','--macos']],
    ]);
});

test('Flutter完全缺失时才取官方锁定版本，准备失败保留原错误且不留下半成品', async t => {
    const cache = join(fixture(t).directory, 'target/cache/flutter');
    const commands = [];
    const failure = new Error('官方引擎准备失败');
    let fail = true;
    const execute = async (file,args) => {
        if (args[0] === 'rev-parse') return flutterRevision;
        commands.push(args);
        if (args[0] === 'clone') {
            assert.equal(file, '/usr/bin/git');
            assert.deepEqual(args.slice(0,-1), ['clone','--branch','3.47.2','--depth','1','https://github.com/flutter/flutter.git']);
            flutterFiles(args.at(-1));
            return;
        }
        assert.deepEqual(args, ['--no-version-check','precache','--ios','--macos']);
        if (fail) throw failure;
    };
    const options = {cache, candidates:[cache], execute};
    await assert.rejects(prepareFlutter('ios', {}, options), error => error === failure);
    assert.equal(existsSync(cache), false);
    assert.equal(existsSync(cache + '.lock'), false);
    fail = false;
    assert.equal(await prepareFlutter('ios', {}, options), cache);
    assert.deepEqual(commands.map(args => args[0]), ['clone','--no-version-check','clone','--no-version-check']);
    assert.equal(await prepareFlutter('ios', {}, options), cache);
    assert.equal(commands.length, 5);
});

// CitizenSDK本机取已提交HEAD，云端独立选择正式Release。
function sdkVersion(product, version, id, attempt = 1) {
    const proof = {product_id:product,platform:'sdk',software_version:version,
        git_commit_sha:id.toString(16).padStart(40,'0'),producer_run_id:id,producer_run_attempt:attempt};
    return {
        release:{id,tag_name:product + '-v' + version,draft:false,prerelease:false,
            published_at:'2026-10-28',body:JSON.stringify(proof)},
        run:{id,status:'completed',conclusion:'success',head_sha:proof.git_commit_sha,run_attempt:attempt}
    };
}
test('CitizenSDK云端自动取正式版，App旧SHA不阻断且来源在编译前固定', async () => {
    const selected=sdkVersion('citizensdk','2.0.7',70), calls=[];
    const execute=(command,args)=>{
        assert.equal(command,'gh');calls.push(args[1]);
        assert.ok(args[1].startsWith('repos/crcfrcn/citizensdk/'));
        return JSON.stringify(args[1].includes('/releases?')?[selected.release]:selected.run);
    };
    for(const lock of [pubLock,pubLock.replace(/resolved-ref: .*$/gmu,'resolved-ref: "'+ 'f'.repeat(40)+'"')]){
        const result=await resolveSDK({root:'/workspace/citizenapp',lock,
            environment:{GITHUB_ACTIONS:'true',GITHUB_REPOSITORY:'crcfrcn/citizenapp'},execute});
        assert.deepEqual([result.name,result.ref,result.version],['citizen_sdk',selected.run.head_sha,'2.0.7']);
        const before=result.selected.release.id;
        selected.release={...selected.release,id:before+1};
        assert.equal(result.selected.release.id,before);
    }
    assert.equal(calls.length,4);
});

test('正式附件按唯一标签匹配，SDK仅接受已上传件并按远端名称下载',()=>{
    const request={tag:'sdk-v2.0.7',repo:'crcfrcn/citizensdk',label:'sdk-v2.0.7.zip',output:'/fixture/sdk.zip',uploaded:true};
    const asset={label:request.label,name:'remote.zip',state:'uploaded'};
    const args=['release','download',request.tag,'--repo',request.repo,'--pattern','remote.zip','--output',request.output];
    assert.deepEqual(releaseDownloadArgs({...request,assets:[asset]}),args);
    for(const assets of [[],[asset,asset],[{...asset,state:'new'}]])
        assert.throws(()=>releaseDownloadArgs({...request,assets}),/附件缺失或重复/);
    assert.deepEqual(releaseDownloadArgs({...request,uploaded:false,assets:[{label:asset.label,name:asset.name}]}),args);
});

test('SDK云端附件下载失败后停止，未调用SDK消费',async t=>{
    const {directory,env}=fixture(t), sdk=join(env.WORK,'sources/citizen_sdk/scripts');
    rmSync(join(env.WORK,'project'),{recursive:true});
    writeFileSync(join(directory,'pubspec.lock'),pubLock);
    mkdirSync(sdk,{recursive:true});
    writeFileSync(join(sdk,'build.mjs'),'export function consume(){throw Error("不得消费下载失败的附件")}');
    const selected=sdkVersion('citizensdk','2.0.7',70);
    selected.release.assets=[{label:selected.release.tag_name+'.zip',state:'uploaded',name:'remote.zip'}];
    writeFileSync(join(directory,'bin/gh'),'#!'+process.execPath+'\nconsole.error("合成SDK下载失败");process.exit(17);\n',{mode:0o700});
    const execute=(command,args,options)=>command==='gh'?JSON.stringify(args[1].includes('/releases?')?[selected.release]:selected.run):
        command==='git'?args.includes('ls-files')?'pubspec.lock\0':'':execFileSync(command,args,options);
    await assert.rejects(assembleProject({...env,GITHUB_WORKSPACE:directory},{execFileSync:execute}),/编译失败或已取消/);
});

test('CitizenSDK本机取当前分支已提交HEAD，忽略工作区修改且不访问远端', async t => {
    const work=mkdtempSync(join(root,'target/test/sdk-head-'));t.after(()=>rmSync(work,{recursive:true,force:true}));
    const local=join(work,'citizensdk'), manifest=join(local,'pubspec.yaml');
    mkdirSync(local);
    const git=args=>{
        const result=spawnSync('git',['-C',local,...args],{encoding:'utf8',env:{...process.env,GIT_AUTHOR_NAME:'SDK test',GIT_AUTHOR_EMAIL:'sdk@example.test',GIT_COMMITTER_NAME:'SDK test',GIT_COMMITTER_EMAIL:'sdk@example.test'}});
        assert.equal(result.status,0,result.stderr);return result.stdout.trim();
    };
    git(['init','-b','main']);writeFileSync(manifest,'version: 1.0.0\n');git(['add','.']);git(['commit','-m','baseline']);
    git(['checkout','-b','repair']);writeFileSync(manifest,'version: 1.0.1\n');git(['add','.']);git(['commit','-m','repair']);
    const head=git(['rev-parse','HEAD']);
    writeFileSync(manifest,'version: 9.9.9\n');
    const result=await resolveSDK({root:join(work,'citizenapp'),lock:pubLock,environment:{PATH:process.env.PATH},
        execute:(command,args,options)=>{assert.equal(command,'git');return spawnSync(command,args,options).stdout;}});
    assert.equal(result.ref,head);
    assert.equal(result.version,'1.0.1');
    writeFileSync(manifest,'version: 1.0.2\n');git(['commit','-am','next']);
    assert.equal(result.ref,head,'本轮来源不能随稍后的提交变化');
});

test('本机安装跳过宿主MLS仍生成Android平台库', async t => {
    const work=fixture(t).directory, project=join(work,'target/build/21-1/project');
    const target=join(work,'rust'), release=join(target,'aarch64-linux-android/release'), calls=[];
    mkdirSync(release,{recursive:true});
    writeFileSync(join(release,'libmls.so'),'原平台库');
    await buildMls({project,work,platform:'android',
        environment:{CARGO_TARGET_DIR:target,ANDROID_HOME:'/fixture/android'},
        execute:async(_,args)=>calls.push(args[args.indexOf('--target')+1])});
    assert.deepEqual(calls,['aarch64-linux-android']);
    assert.equal(readFileSync(join(project,'android/app/src/main/jniLibs/arm64-v8a/libmls.so'),'utf8'),'原平台库');
    assert.equal(existsSync(join(work,'mls/host')),false);
});

for (const product of ['citizensdk']) {
    test(product + '分页后按数值版本选择最新成功正式包，忽略不合格Release', async () => {
        const failed = sdkVersion(product,'2.0.0',30), latest = sdkVersion(product,'1.0.10',10,2);
        const older = sdkVersion(product,'1.0.2',200), calls = [];
        const invalid = sdkVersion(product,'9.0.0',40).release;
        const pages = [
            [{...failed.release,draft:true},...Array.from({length:99},() => ({...invalid,body:'null'}))],
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
            'actions/runs/10/attempts/2']);
    });
    test(product + '只承认准确Run和attempt成功且源码一致的正式版本', async () => {
        const latest = sdkVersion(product,'1.0.2',20,2), older = sdkVersion(product,'1.0.1',10);
        for (const change of [
            {status:'in_progress',conclusion:null}, {conclusion:'failure'}, {conclusion:'cancelled'},
            {id:21}, {run_attempt:1}, {head_sha:'f'.repeat(40)}
        ]) {
            await assert.rejects(selectSDKRelease(product, async path => {
                if (path.startsWith('releases?')) return [older.release,latest.release];
                assert.equal(path,'actions/runs/20/attempts/2','最新来源失败不能读取旧来源');
                return {...latest.run,...change};
            }), /没有可用/);
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
    const body = source.slice(start, source.lastIndexOf('}'));
    const execute = new Function('join', 'project', 'root', 'environment', 'run', 'return (async () => {' + body + '})();');
    // 同一真实资源正文分别覆盖产品默认缓存、调用方显式缓存与自动化环境。
    for (const [environment, cache] of [
        [{}, '/fixture/source/target/cache/npm'],
        [{NPM_CONFIG_CACHE:'/fixture/provided-cache'}, '/fixture/provided-cache'],
        [{npm_config_cache:'/fixture/lowercase-cache'}, '/fixture/lowercase-cache'],
        [{GITHUB_ACTIONS:'true'}, undefined],
    ]) {
        for (const failure of [null, 'npm', '/fixture/esbuild']) {
            const calls = [], error = new Error('合成工具失败');
            const result = execute(join, '/fixture/project', '/fixture/source', {...environment,ESBUILD_BIN:'/fixture/esbuild'}, async (...args) => {
                calls.push(args);
                if (args[0] === failure) throw error;
            });
            if (failure) await assert.rejects(result, actual => actual === error);
            else await result;
            assert.equal(calls.length, failure === 'npm' ? 1 : 2);
            assert.deepEqual(calls[0].slice(0, 3), ['npm', ['ci', '--prefer-offline', '--ignore-scripts', '--no-audit', '--no-fund'], '/fixture/project/topup/web']);
            assert.equal(calls[0][4].npm_config_ignore_scripts, 'true');
            assert.equal(calls[0][4].npm_config_cache, cache);
            assert.equal(calls[0][4].npm_config_offline, undefined);
            if (calls.length === 2) {
                assert.equal(calls[1][0], '/fixture/esbuild');
                assert.ok(calls[1][1].includes('--outfile=metamask.bundle.js'));
                assert.equal(calls[1][2], '/fixture/project/topup/web');
            }
        }
    }
    const declaration = JSON.parse(readFileSync(join(root, 'topup/web/package.json')));
    const tools=readFileSync(releaseScript,'utf8');
    for (const platform of ['ios', 'android']) {
        const workflow = readFileSync(join(root, '.github/workflows/' + platform + '.yml'), 'utf8');
        assert.ok(workflow.includes('run: node .github/release.mjs prepare '+platform));
        assert.match(tools, /citizenapp[.]tools[.]esbuild/);
        assert.match(tools, /ESBUILD_BIN/);
        assert.doesNotMatch(workflow, /name: 准备本轮充值构建工具/);
    }
    assert.equal(declaration.citizenapp.tools.esbuild, '0.28.1');
});

for (const [platform, label, extensions] of [
    ['ios','iOS',['ipa','json']], ['android','Android',['apk','aab','json']],
]) test(platform + '共用入口核对正式附件数，数量错误时回滚本轮对象', t => {
    const directory = fixture(t).directory, artifact = join(directory,'artifact');
    mkdirSync(artifact);
    const name = '公民·' + label + '·v1.2.3';
    const assets = extensions.map(ext => ({name:ext,label:name + '.' + ext}));
    for (const asset of assets) writeFileSync(join(artifact,asset.label),asset.name);
    writeFileSync(join(directory,'proof.json'),'{}');
    writeFileSync(join(directory,'pubspec.yaml'),'version: 1.2.3+1\n');
    const calls = join(directory,'gh-calls.jsonl'), output = join(directory,'version-output');
    writeFileSync(join(directory,'bin/gh'),'#!'+process.execPath+'\n'+String.raw`
const fs = require('node:fs');
const a = process.argv.slice(2), env = process.env;
fs.appendFileSync(env.CALLS, JSON.stringify(a) + '\n');
const assets = JSON.parse(env.ASSETS);
const [command, action] = a;
const out = value => console.log(JSON.stringify(value));
if (command === 'api' && a.includes('--slurp')) {
  const rolledBack=env.WRONG_COUNT==='true'&&fs.readFileSync(env.CALLS,'utf8').includes('"edit"');
  out([rolledBack?[{id:77,tag_name:env.TAG,target_commitish:env.GITHUB_SHA,body:JSON.stringify({run_id:20})}]:[]]);
}
else if (command === 'api' && action.endsWith('/releases?per_page=100&page=1')) out([]);
else if (command === 'api' && a.some(v => v.includes('/releases/tags/'))) {
  out({draft:false, prerelease:false, published_at:'published', name:env.TAG, tag_name:env.TAG,
    target_commitish:env.GITHUB_SHA, assets:env.WRONG_COUNT==='true'?assets.slice(1):assets});
} else if (command === 'api' && a.some(v => v.includes('/git/ref/tags/'))) out({object:{type:'commit',sha:env.GITHUB_SHA}});
else if (command === 'api' && (a.includes('POST') || a.includes('DELETE'))) out({});
else if (command === 'release' && action === 'view') out({assets});
else if (command === 'release' && action === 'download') fs.writeFileSync(a.at(-1),a[a.indexOf('--pattern')+1]);
else if (command !== 'release' || !['create','edit'].includes(action)) throw Error('未登记的替身 gh 调用');
`,{mode:0o700});
    const env={PATH:join(directory,'bin')+':'+dirname(process.execPath)+':/usr/bin:/bin',
        WORK:directory,RUNNER_TEMP:directory,GITHUB_OUTPUT:output,GITHUB_REPOSITORY:'crcfrcn/citizenapp',
        GITHUB_SHA:'a'.repeat(40),GITHUB_RUN_ID:'20',CITIZENAPP_VERSION:'1.2.3',TAG:name,CALLS:calls,ASSETS:JSON.stringify(assets)};
    const invoke=(step,wrong=false)=>spawnSync(process.execPath,[releaseScript,step,platform],
        {cwd:directory,encoding:'utf8',env:{...env,WRONG_COUNT:String(wrong)}});
    const version=invoke('version');assert.equal(version.status,0,version.stderr);
    assert.equal(readFileSync(output,'utf8'),'version=1.2.3\n');
    const release=invoke('release');assert.equal(release.status,0,release.stderr);
    rmSync(join(directory,'readback'),{recursive:true});
    writeFileSync(calls,'');
    const failed=invoke('release',true);assert.notEqual(failed.status,0);
    const recorded=readFileSync(calls,'utf8').trim().split('\n').map(JSON.parse);
    assert.ok(recorded.some(a=>a.includes('DELETE')&&a.some(v=>v.endsWith('/releases/77'))));
    assert.ok(recorded.some(a=>a.includes('DELETE')&&a.some(v=>v.includes('/git/refs/tags/'))));
});

// 直接执行共用清理脚本；gh替身只操作本轮JSON现场，不访问网络。
function cleanupGithub() {
    const fs = require('node:fs');
    const path = process.env.CLEANUP_STATE;
    const state = JSON.parse(fs.readFileSync(path, 'utf8'));
    const args = process.argv.slice(2);
    fs.appendFileSync(process.env.CLEANUP_CALLS, JSON.stringify(args) + '\n');
    const missing = (status = 404) => {
        if(status===404 && state.readback?.[request]>0){state.readback[request]--;save();status=200;}
        const end=state.crlf?'\r\n':'\n';
        if(state.proxy)process.stdout.write('HTTP/1.1 200 Connection established'+end+end);
        process.stdout.write('HTTP/2.0 ' + status + (state.reason?' Not Found':'') + end);
        process.exit(status === 404 ? 4 : status === 200 ? 0 : 7);
    };
    const save = () => fs.writeFileSync(path, JSON.stringify(state));
    const owner = artifact => artifact.workflow_run?.id ?? state.artifactOwners?.[artifact.id];
    if (args[0] === 'run' && args[1] === 'delete') {
        const id = Number(args[2]);
        state.runs = state.runs.filter(run => run.id !== id);
        if (!state.keepArtifacts) state.artifacts = state.artifacts.filter(a => owner(a) !== id);
        save();
        return;
    }
    if (args[0] !== 'api') process.exit(90);
    const request = args.at(-1).replace('repos/crcfrcn/citizenapp/', '').split('?')[0];
    const method = args.includes('--method') ? args[args.indexOf('--method') + 1] : 'GET';
    if(method==='GET' && state.network===request)process.exit(1);
    if (method === 'GET' && state.denied?.[request]) missing(state.denied[request]);
    let value;
    if (request.startsWith('actions/workflows/')) value = {workflow_runs: state.runs};
    else if (request === 'releases') value = state.releases;
    else if (request === 'actions/caches') value = {actions_caches: state.caches};
    else if (request === 'actions/artifacts') value = {artifacts: state.artifacts};
    else if (/^actions\/runs\/[0-9]+\/artifacts$/u.test(request)) {
        const id = Number(request.split('/')[2]);
        value = {artifacts:state.artifacts.filter(a => owner(a) === id)};
    } else if (/^actions\/artifacts\/[0-9]+$/u.test(request)) {
        value = state.artifacts.find(a => a.id === Number(request.split('/')[2]));
        if (!value) missing();
    }
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
    assert.ok(section.includes('run: node .github/release.mjs cleanup ' + platform));
    assert.ok(section.includes('ref: ${{ github.sha }}'));
    assert.ok(section.includes('persist-credentials: false'));
    return {state,release,sha,execute(result='success') {
        writeFileSync(file, JSON.stringify(state));
        writeFileSync(calls, '');
        const completed = spawnSync(process.execPath, [releaseScript,'cleanup',platform], {cwd:directory,encoding:'utf8',
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
    test(platform + '按 Run 清理归属字段为空的旧附件并以附件 ID 回查', t => {
        const f = cleanupCase(t,platform);
        f.state.artifacts.push({id:501,workflow_run:null},{id:502,workflow_run:null});
        f.state.artifactOwners={501:10};
        const r=f.execute();
        assert.equal(r.status,0,r.stderr);
        assert.deepEqual(r.state.artifacts.map(a=>a.id),[20,502]);
        assert.ok(r.calls.some(args=>args.includes('--silent')&&args.at(-1).endsWith('/actions/artifacts/501')));
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
    for(const format of ['crlf','reason','proxy'])test(platform+'删除回查接受实际HTTP头格式：'+format,t=>{
        const f=cleanupCase(t,platform);f.state[format]=true;const r=f.execute();assert.equal(r.status,0,r.stderr);
    });
    test(platform+'删除后短暂200只读复查到404，不重复删除',t=>{
        const f=cleanupCase(t,platform);f.state.artifacts.push({id:11,workflow_run:{id:11}});f.state.readback={'actions/artifacts/11':2};
        const r=f.execute();assert.equal(r.status,0,r.stderr);
        const reads=r.calls.filter(a=>a.includes('GET')&&a.at(-1).endsWith('/actions/artifacts/11'));assert.equal(reads.length,3);
        assert.equal(r.calls.filter(a=>a[0]==='run'&&a[1]==='delete'&&a[2]==='11').length,1);
    });
    for(const status of [403,500])test(platform+'删除回查HTTP'+status+'立即失败且不伪装404',t=>{
        const f=cleanupCase(t,platform);f.state.artifacts.push({id:11,workflow_run:{id:11}});f.state.denied={'actions/artifacts/11':status};
        const r=f.execute();assert.notEqual(r.status,0);assert.match(r.stderr,new RegExp('HTTP '+status));assert.equal(r.calls.filter(a=>a.includes('GET')&&a.at(-1).endsWith('/actions/artifacts/11')).length,1);
    });
    test(platform+'删除回查网络失败不能视为对象不存在',t=>{
        const f=cleanupCase(t,platform);f.state.artifacts.push({id:11,workflow_run:{id:11}});f.state.network='actions/artifacts/11';
        const r=f.execute();assert.notEqual(r.status,0);assert.match(r.stderr,/HTTP unknown/);
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

// 执行共享产物核验函数，验证缺类、缺字段及工具失败都会阻断交付。
test('最终Android APK的JNI Unit类与单例按实际DEX定义核验', async () => {
    const {verifyAndroidRuntime} = await import('../../scripts/build.mjs');
    const environment={ANDROID_HOME:'/owned/android'};
    const good='.class public final Lkotlin/Unit;\n.field public static final INSTANCE:Lkotlin/Unit;\n';
    let calls=0;
    await verifyAndroidRuntime('/owned/artifact/app.apk',environment,async(command,args,cwd,capture,env)=>{
        calls++;assert.equal(command,'/owned/android/cmdline-tools/latest/bin/apkanalyzer');
        assert.deepEqual(args,['dex','code','--class','kotlin.Unit','/owned/artifact/app.apk']);
        assert.equal(cwd,'/owned/artifact');assert.equal(capture,true);assert.equal(env,environment);return good;
    });
    assert.equal(calls,1);
    for(const bad of ['kotlin.Unit INSTANCE', '.class public final Lkotlin/Unit;\n', '.field public static final INSTANCE:Lkotlin/Unit;\n', '.class public final Lkotlin/Unit;\n.field public final INSTANCE:Lkotlin/Unit;\n']) {
        await assert.rejects(verifyAndroidRuntime('/owned/app.apk',environment,async()=>bad),/缺少JNI/);
    }
    const failure=Error('synthetic tool failure');
    await assert.rejects(verifyAndroidRuntime('/owned/app.apk',environment,async()=>{throw failure;}),e=>e===failure);
});

for(const mode of ['missing-class','missing-field','error']) {
    test(`Android最终DEX核验${mode}失败时不复制APK交付`,t=>{
        const value=fixture(t);value.env.DEX_MODE=mode;
        const result=spawnSync(process.execPath,[value.script,'android'],{env:value.env,encoding:'utf8'});
        assert.notEqual(result.status,0);
        assert.match(result.stderr,mode==='error'?/Android JNI产物核验失败/:/缺少JNI/);
        assert.equal(existsSync(join(value.env.WORK,'artifact','公民·Android·v1.2.3.apk')),false);
        assert.equal(existsSync(join(value.env.WORK,'build-active.json')),false);
    });
}

// 只检查本产品交付，不引入控制台实现或真实签名资料。
test('Apple签名清单包含嵌套代码和产品明确的主程序权限',async()=>{
 const fs=await import('node:fs'),path=await import('node:path');
 const {appleSigning}=await import('../../scripts/build.mjs');
 const parent=path.join(path.dirname(new URL(import.meta.url).pathname),'../../target/test');
 fs.mkdirSync(parent,{recursive:true});const work=fs.mkdtempSync(path.join(parent,'signing-'));
 try{
  const app=path.join(work,'Fixture.app'),framework=path.join(app,'Frameworks/Fixture.framework');
  fs.mkdirSync(framework,{recursive:true});fs.writeFileSync(path.join(framework,'library.dylib'),'fixture');
  fs.symlinkSync(framework,path.join(app,'linked'));
  const plan=appleSigning(app,'/owned/product.entitlements');
  assert.deepEqual(plan.at(-1),{path:'.',entitlements:'/owned/product.entitlements'});
  assert.ok(plan.some(item=>item.path==='Frameworks/Fixture.framework'));
  assert.ok(plan.some(item=>item.path==='Frameworks/Fixture.framework/library.dylib'));
  assert.ok(plan.every(item=>!item.path.startsWith('linked')));
  assert.equal(appleSigning(app).at(-1).entitlements,null);
  assert.throws(()=>appleSigning(path.join(work,'missing')));
 }finally{fs.rmSync(work,{recursive:true,force:true});}
});


// 原生选择清单必须指向真实用例，防止更名后仍派发一个不存在的历史测试。
test('iOS原生测试清单均指向现有唯一用例',()=>{
 const swift=readFileSync(join(root,'ios/tests/RunnerTests.swift'),'utf8');
 for(const id of testSuites.ios.native){
  const name=id.split('/').at(-1);
  assert.equal([...swift.matchAll(new RegExp('func '+name+'\\s*\\(','g'))].length,1,id);
 }
});
