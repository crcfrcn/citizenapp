import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, realpathSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';
import test from 'node:test';
import { createHash } from 'node:crypto';
import { gradleRecipes, revisedSource, revisionPlan } from './flutter.mjs';
import { jobIdentity as android, workflowSteps as androidSteps } from './android.mjs';
import { jobIdentity as androidCheck, workflowSteps as androidCheckSteps } from './android-check.mjs';
import { jobIdentity as ios, workflowSteps as iosSteps } from './ios.mjs';
import { jobIdentity as iosCheck, workflowSteps as iosCheckSteps } from './ios-check.mjs';
import { runWorkflow } from '../workflow.mjs';

const jobs = [
  [android, androidSteps], [androidCheck, androidCheckSteps],
  [ios, iosSteps], [iosCheck, iosCheckSteps],
];

test('CitizenApp四个CI Job保留准确独立身份且共用唯一执行器', async () => {
  assert.deepEqual(jobs.map(([identity]) => `${identity.pipeline}:${identity.job}`).sort(), [
    'citizenapp.android.ci:android', 'citizenapp.android.ci:check',
    'citizenapp.ios.ci:check', 'citizenapp.ios.ci:ios',
  ]);
  for (const [, steps] of jobs) {
    for (const step of Object.values(steps)) {
      const result = spawnSync('bash', ['-n'], { input: step.source, encoding: 'utf8' });
      assert.equal(result.status, 0, result.stderr);
    }
  }
  await assert.rejects(runWorkflow(ios, iosSteps, {}, {
    argumentsList: ['workflow-step', '999'], environment: { GITHUB_REPOSITORY: 'crcfrcn/citizenapp' },
  }), /阶段无效/u);
  await assert.rejects(runWorkflow(ios, iosSteps, {}, {
    argumentsList: ['workflow-step', '0'], environment: { GITHUB_REPOSITORY: 'crcfrcn/citizenchain' },
  }), /仓库身份/u);
});

test('CitizenApp CI Workflow只引用六层内的唯一扁平文件', () => {
  for (const [platform, names] of [['android', ['android.mjs', 'android-check.mjs']], ['ios', ['ios.mjs', 'ios-check.mjs']]]) {
    const workflow = readFileSync(new URL(`../../.github/workflows/citizenapp-${platform}-ci.yml`, import.meta.url), 'utf8');
    for (const name of names) assert.match(workflow, new RegExp(`scripts/ci/${name.replace('.', '[.]')}`, 'u'));
    assert.doesNotMatch(workflow, /scripts\/ci\/(?:android|ios)\//u);
  }
  for (const source of ['./android.mjs', './android-check.mjs', './ios.mjs', './ios-check.mjs']
    .map(path => readFileSync(new URL(path, import.meta.url), 'utf8'))) {
    assert.doesNotMatch(source, /function cacheIdentity|function runExactWorkflowStep/u);
  }
});


test('CitizenApp消费视图实际绑定SDK标准入口且CI重用不丢失Pub状态', () => {
  const source = fileURLToPath(new URL('../../', import.meta.url)).replace(/\/$/u, '');
  const work = realpathSync(mkdtempSync(join(tmpdir(), 'citizenapp-view-')));
  const sdk = join(work, 'git-sources/citizen_sdk');
  const script = join(source, 'scripts/citizenapp-view.mjs');
  const flutter = join(work, 'flutter');
  for (const name of ['gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar']) {
    const path = join(flutter, 'bin/cache/artifacts/gradle_wrapper', name);
    mkdirSync(join(path, '..'), { recursive: true });
    writeFileSync(path, 'synthetic wrapper ' + name);
  }
  const run = command => spawnSync(process.execPath, [script, command,
    '--source-root', source, '--work-root', work], { encoding: 'utf8',
      env: { ...process.env, FLUTTER_ROOT: flutter } });
  try {
    const created = run('create-android');
    assert.equal(created.status, 0, created.stderr);
    const project = created.stdout.trim();
    const sdkView = join(work, 'source-view', sdk.replace(/^\/+/, ''));
    const entry = join(sdkView, 'android/src/main/kotlin/org/citizen/sdk/CitizenSdkPlugin.kt');
    assert.equal(realpathSync(entry), join(sdk, 'android/src/main/kotlin/CitizenSdkPlugin.kt'));
    assert.equal(existsSync(join(sdkView, 'android/src/main/kotlin/CitizenSdkPlugin.kt')), false);
    for (const name of ['gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar']) {
      const output = join(project, 'android', name);
      assert.equal(lstatSync(output).isSymbolicLink(), false);
      assert.deepEqual(readFileSync(output), readFileSync(join(flutter, 'bin/cache/artifacts/gradle_wrapper', name)));
    }
    const settings = join(project, 'android/settings.gradle.kts');
    assert.equal(lstatSync(settings).isSymbolicLink(), false);
    assert.deepEqual(readFileSync(settings), readFileSync(join(source, 'android/settings.gradle.kts')));
    mkdirSync(join(project, '.dart_tool'));
    const config = join(project, '.dart_tool/package_config.json');
    const chatSource = join(work, 'git-sources/tatachat_sdk');
    assert.equal(existsSync(chatSource), true, '声明的聊天SDK必须实际按Git锁取得');
    const chatView = join(work, 'source-view', realpathSync(chatSource).replace(/^\/+/, ''));
    if (chatView) {
      const plugin = join(chatView, 'android/src/main/java/chat/tata/sdk/TataChatSdkPlugin.java');
      assert.equal(realpathSync(plugin), join(realpathSync(chatSource), 'android/TataChatSdkPlugin.java'));
      assert.equal(existsSync(join(chatView, 'android/TataChatSdkPlugin.java')), false);
    }
    const contents = JSON.stringify({ configVersion: 2, packages: [
      { name: 'citizen_sdk', rootUri: pathToFileURL(sdkView + '/').href },
      ...(chatView ? [{ name: 'tatachat_sdk', rootUri: pathToFileURL(chatView + '/').href }] : []),
    ] });
    writeFileSync(config, contents);
    assert.equal(run('verify').status, 0);
    assert.equal(readFileSync(config, 'utf8'), contents);
    writeFileSync(config, JSON.stringify({ packages: [
      { name: 'citizen_sdk', rootUri: pathToFileURL(sdk + '/').href },
    ] }));
    const rejected = run('verify');
    assert.notEqual(rejected.status, 0);
    assert.match(rejected.stderr, /实际SDK依赖未绑定/u);
  } finally { rmSync(work, { recursive: true }); }
});

test('CitizenApp各CI的Pub及构建使用同轮视图', () => {
  for (const steps of [androidCheckSteps, iosCheckSteps]) {
    assert.match(steps['8'].source, /citizenapp-view\.mjs.*create/u);
    assert.match(steps['8'].source, /CITIZENAPP_TEST_PROJECT_ROOT/u);
    assert.match(steps['9'].source, /citizenapp-test\.sh/u);
  }
  assert.match(androidSteps['8'].source, /create-android/u);
  assert.match(androidSteps['9'].source, /project="\$CITIZENAPP_PROJECT_ROOT"/u);
  assert.match(androidSteps['10'].source, /cd "\$CITIZENAPP_PROJECT_ROOT"/u);
  const runner = readFileSync(new URL('../citizenapp-test.sh', import.meta.url), 'utf8');
  assert.match(runner, /"\$VIEW_SCRIPT" verify/u);
});

// 路径边界夹具独立持有临时Git对象；此最小接口只支撑布局拒绝用例。
// 上方真实消费用例仍按产品Git锁取得完整SDK，核对公开标准入口与Pub实际解析。
function seedFixtureDependency(source, work) {
  const sdk = join(work, 'git-sources/citizen_sdk');
  mkdirSync(join(sdk, 'scripts'), { recursive: true });
  writeFileSync(join(sdk, 'pubspec.yaml'), 'name: citizen_sdk\nversion: 1.0.0\n');
  writeFileSync(join(sdk, 'pubspec.lock'), 'packages: {}\n');
  writeFileSync(join(sdk, 'scripts/release.mjs'),
    "import {mkdirSync,copyFileSync} from 'node:fs';import {join} from 'node:path';\n" +
    "export function createFlutterSourceView(source,output) {mkdirSync(output,{recursive:true});" +
    "for(const name of ['pubspec.yaml','pubspec.lock'])copyFileSync(join(source,name),join(output,name));return output;}\n");
  const git = args => execFileSync('git', ['-c','user.name=Fixture',
    '-c','user.email=fixture@example.invalid','-c','commit.gpgsign=false',
    '-c','core.hooksPath=/dev/null','-C',sdk,...args], {encoding:'utf8',
      env:{...process.env,GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:'/dev/null'}}).trim();
  git(['init','--quiet']);git(['remote','add','origin','https://github.com/crcfrcn/citizensdk.git']);
  git(['add','.']);git(['commit','--quiet','-m','fixture']);
  const sha=git(['rev-parse','HEAD']);git(['checkout','--quiet','--detach',sha]);
  writeFileSync(join(source,'pubspec.yaml'), 'name: fixture\ndependencies:\n  citizen_sdk:\n    git:\n' +
    '      url: https://github.com/crcfrcn/citizensdk.git\n      ref: '+sha+'\n      path: .\n');
  writeFileSync(join(source,'pubspec.lock'), 'packages:\n  citizen_sdk:\n    dependency: "direct main"\n    description:\n' +
    '      url: "https://github.com/crcfrcn/citizensdk.git"\n      ref: "'+sha+'"\n      resolved-ref: "'+sha+
    '"\n      path: "."\n    source: git\n    version: "1.0.0"\n');
}

// 直接执行视图装配，覆盖缺少输入、旧平台入口冲突和源目录回写三个失败边界。
test('CitizenApp扁平平台输入缺失或重复时拒绝生成工程', () => {
  const fixture = realpathSync(mkdtempSync(join(tmpdir(), 'citizenapp-platform-')));
  const source = join(fixture, 'source'), work = join(fixture, 'work');
  const script = fileURLToPath(new URL('../citizenapp-view.mjs', import.meta.url));
  mkdirSync(join(source, 'ios'), { recursive: true });
  mkdirSync(join(source, 'android'));
  seedFixtureDependency(source, work);
  const run = output => spawnSync(process.execPath, [script, 'create', '--source-root', source,
    '--work-root', output], { encoding: 'utf8' });
  try {
    assert.match(run(work).stderr, /平台输入缺少/u);
    for (const name of ['Runner', 'RunnerUITests']) writeFileSync(join(source, `ios/${name}.xcscheme`), '<Scheme/>');
    for (const name of ['gradle-wrapper.properties']) writeFileSync(join(source, 'android', name), 'fixture');
    assert.equal(run(work).status, 0);
    const unavailableGit = spawnSync(process.execPath, [script, 'dependencies',
      '--source-root', source, '--work-root', work], { encoding: 'utf8',
      env: { ...process.env, PATH: '' } });
    assert.notEqual(unavailableGit.status, 0);
    assert.match(unavailableGit.stderr, /git ENOENT/u);
    const projected = join(work, 'source-view', source.replace(/^\/+/, ''));
    assert.equal(existsSync(join(projected, 'android/gradlew')), false);
    const missingTools = spawnSync(process.execPath, [script, 'create-android',
      '--source-root', source, '--work-root', work], { encoding: 'utf8',
        env: { ...process.env, FLUTTER_ROOT: join(fixture, 'absent-flutter') } });
    assert.notEqual(missingTools.status, 0);
    assert.match(run(join(source, 'output')).stderr, /必须分离/u);
    const legacy = join(source, 'ios/Runner.xcodeproj/xcshareddata/xcschemes');
    mkdirSync(legacy, { recursive: true });
    writeFileSync(join(legacy, 'Runner.xcscheme'), '<Scheme/>');
    assert.match(run(work).stderr, /平台入口重复/u);
  } finally { rmSync(fixture, { recursive: true }); }
});


// 金标入口实际验真链快照；夹具只提供合成Git提交和无业务含义JSON，不读取正式仓或网络。
test('公民链金标输入拒绝主分支、脏输入和错误来源', async () => {
  const { mkdtempSync, realpathSync, mkdirSync, writeFileSync, rmSync } = await import('node:fs');
  const { join } = await import('node:path'); const { tmpdir } = await import('node:os');
  const { spawnSync } = await import('node:child_process');
  const base = realpathSync(mkdtempSync(join(tmpdir(), 'app-chain-input-')));
  const chain = join(base, 'chain'), work = join(base, 'work'); mkdirSync(chain); mkdirSync(work);
  const git = args => {
    const result = spawnSync('git', ['-c', 'core.hooksPath=/dev/null', '-C', chain, ...args], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr); return result.stdout.trim();
  };
  const run = value => spawnSync(process.execPath, [new URL('../citizenapp-test-inputs.mjs', import.meta.url).pathname, value], {
    encoding: 'utf8', env: { ...process.env, CITIZENCHAIN_ROOT: chain },
  });
  try {
    for (const dir of ['runtime/primitives/tests/fixtures', 'runtime/tests/fixtures']) mkdirSync(join(chain, dir), { recursive: true });
    for (const rel of ['runtime/primitives/tests/fixtures/scale_codec_vectors.json', 'runtime/tests/fixtures/role_permission.json']) writeFileSync(join(chain, rel), '{}\n');
    git(['init', '--quiet', '-b', 'main']); git(['remote', 'add', 'origin', 'https://github.com/crcfrcn/citizenchain.git']);
    git(['add', '.']); git(['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '-m', 'fixture']);
    assert.notEqual(run(work).status, 0); // 正式main没有被当成只读detached测试输入。
    git(['checkout', '--quiet', '--detach']);
    assert.equal(run(work).status, 0);
    assert.notEqual(run('relative').status, 0);
    git(['remote', 'set-url', 'origin', 'https://github.com/crcfrcn/citizenapp.git']);
    assert.notEqual(run(work).status, 0);
    git(['remote', 'set-url', 'origin', 'https://github.com/crcfrcn/citizenchain.git']);
    writeFileSync(join(chain, 'runtime/tests/fixtures/role_permission.json'), 'changed');
    assert.notEqual(run(work).status, 0);
  } finally { rmSync(base, { recursive: true, force: true }); }
});

// 真实执行签名 Shell；替身只记录参数，不生成密钥或原生包。
test('Android CI签名完整传参且签名失败仍移除临时密钥', () => {
  const root=realpathSync(mkdtempSync(join(tmpdir(),'app-ci-sign-')));
  const bin=join(root,'bin'), sdk=join(root,'sdk'), log=join(root,'calls');
  mkdirSync(bin); mkdirSync(join(sdk,'build-tools/36.0.0'),{recursive:true});
  const stub=path=>writeFileSync(path,`#!${process.execPath}
const fs=require('node:fs');fs.appendFileSync(process.env.CALLS,JSON.stringify({tool:require('node:path').basename(process.argv[1]),args:process.argv.slice(2)})+'\\n');
if(process.argv[1].endsWith('openssl'))process.stdout.write('fixture-password');
if(process.argv[1].endsWith('keytool'))fs.writeFileSync(process.argv[process.argv.indexOf('-keystore')+1],'fixture');
if(process.argv[1].endsWith('apksigner')&&process.argv[2]==='sign'&&process.env.FAIL_SIGN)process.exit(72);
`,{mode:0o755});
  stub(join(bin,'openssl'));stub(join(bin,'keytool'));stub(join(sdk,'build-tools/36.0.0/apksigner'));
  writeFileSync(join(bin,'rm'),`#!${process.execPath}
require('node:fs').rmSync(process.argv.at(-1),{force:true});
`,{mode:0o755});
  try {
    for(const fail of [false,true]) {
      writeFileSync(log,'');
      const result=spawnSync('/bin/bash',['-e','-o','pipefail','-c',androidSteps['13'].source],{
        cwd:root,encoding:'utf8',env:{...process.env,PATH:bin+':'+process.env.PATH,
          ANDROID_HOME:sdk,RUNNER_TEMP:root,CALLS:log,...(fail?{FAIL_SIGN:'1'}:{})}});
      assert.equal(result.status,fail?72:0,result.stderr);
      const calls=readFileSync(log,'utf8').trim().split('\n').map(JSON.parse);
      assert.deepEqual(calls.map(x=>x.tool),fail?['openssl','keytool','apksigner']:['openssl','keytool','apksigner','apksigner']);
      assert.deepEqual(calls[1].args,['-genkeypair','-storetype','PKCS12','-keystore',join(root,'citizenapp-ci.p12'),
        '-storepass:env','GMB_CI_STORE_PASSWORD','-keypass:env','GMB_CI_KEY_PASSWORD','-alias','ci',
        '-keyalg','RSA','-keysize','4096','-validity','2','-dname','CN=CitizenApp CI,O=GMB,C=US']);
      assert.deepEqual(calls[2].args,['sign','--ks',join(root,'citizenapp-ci.p12'),'--ks-type','PKCS12',
        '--ks-key-alias','ci','--ks-pass','env:GMB_CI_STORE_PASSWORD','--key-pass','env:GMB_CI_KEY_PASSWORD',
        '--out','build/app/outputs/flutter-apk/公民-CI.apk','build/app/outputs/flutter-apk/app-release.apk']);
      assert.equal(existsSync(join(root,'citizenapp-ci.p12')),false);
    }
  } finally {rmSync(root,{recursive:true,force:true});}
});

// 编译替身严格检查准备顺序与路径；覆盖准确依赖和两个独立SDK的消费装配。
test('双端CI先准备锁定ZXing并通过SDK自有入口装配两份原生库', () => {
  const root=realpathSync(mkdtempSync(join(tmpdir(),'app-ci-native-')));
  try {
    for(const [platform,steps,index] of [['android',androidSteps,'8'],['ios',iosSteps,'7']]) {
      const work=join(root,platform), source=join(work,'source'), cache=join(work,'cache'),bin=join(work,'bin');
      const sdk=join(work,'citizen sdk'),chat=join(work,'chat sdk'), project=join(work,'project'),log=join(work,'calls');
      for(const dir of [source,sdk,chat])mkdirSync(join(dir,'scripts'),{recursive:true});
      mkdirSync(cache);mkdirSync(join(project,'android'),{recursive:true});
      mkdirSync(bin);
      for(const command of ['mkdir','ln'])writeFileSync(join(bin,command),`#!${process.execPath}
const fs=require('node:fs'),args=process.argv.slice(2);
if(${JSON.stringify(command)}==='mkdir')for(const path of args.filter(x=>x!=='-p'))fs.mkdirSync(path,{recursive:true});
else {if(args[0]!=='-s')process.exit(75);fs.symlinkSync(args[1],args[2]);}
`,{mode:0o755});
      writeFileSync(join(project,'android/gradlew'),'fixture');
      writeFileSync(join(source,'scripts/citizenapp-view.mjs'),`
import{appendFileSync}from'node:fs';const command=process.argv[2];
if(command==='dependencies')process.stdout.write(JSON.stringify({citizen_sdk:{root:${JSON.stringify(sdk)}},tatachat_sdk:{root:${JSON.stringify(chat)}}}));
else if(command==='create'||command==='create-android')process.stdout.write(${JSON.stringify(project)});
else if(command==='project-framework')appendFileSync(${JSON.stringify(log)},'project:'+process.argv[process.argv.indexOf('--package-subpath')+1]+'\\n');
else process.exit(71);
`);
      writeFileSync(join(sdk,'scripts/dependencies.mjs'),`
import{mkdirSync,appendFileSync}from'node:fs';import assert from'node:assert/strict';
assert.deepEqual(process.argv.slice(2),['prepare-environment','--scope','citizensdk','--platform',${JSON.stringify(platform==='android'?'Android':'macOS')},'--work',${JSON.stringify(join(cache,'citizensdk-native'))}]);
mkdirSync(${JSON.stringify(join(cache,'citizensdk-native/zxing-cpp-3.1.1'))},{recursive:true});appendFileSync(${JSON.stringify(log)},'prepare\\n');
`);
      writeFileSync(join(sdk,'scripts/build-native.sh'),`#!/bin/bash
set -euo pipefail
test -d "$CITIZENSDK_ZXING_SOURCE_DIR"
${platform==='android'?'test "$ANDROID_NDK_HOME" = "'+work+'/android-sdk/ndk/28.2.13676358"\ntest "$ANDROID_NM" = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-nm"':''}
test "$CITIZENSDK_WORK_DIR" = "${cache}/citizensdk-work"
test "$CITIZENSDK_NATIVE_OUTPUT_DIR" = "${cache}/citizensdk-output"
printf 'citizen:%s\\n' "$1" >> "${log}"
`,{mode:0o755});
      writeFileSync(join(chat,'scripts/build-native.sh'),`#!/bin/bash
set -euo pipefail
test "$TATACHATSDK_WORK_DIR" = "${cache}/tatachatsdk-work"
test "\${TATACHATSDK_NATIVE_ANDROID_DIR:-\${TATACHATSDK_NATIVE_IOS_DIR:-}}" = "${cache}/tatachatsdk-output/${platform}"
printf 'chat:%s\\n' "$1" >> "${log}"
`,{mode:0o755});
      const output=join(work,'github-env');writeFileSync(output,'');
      const result=spawnSync('/bin/bash',['-e','-o','pipefail','-c',steps[index].source],{cwd:source,encoding:'utf8',env:{...process.env,
        PATH:bin+':'+process.env.PATH,ANDROID_HOME:join(work,'android-sdk'),ANDROID_NDK_HOME:join(work,'wrong-inherited-ndk'),ANDROID_NM:join(work,'wrong-inherited-nm'),GITHUB_WORKSPACE:source,RUNNER_TEMP:work,CI_INCREMENTAL_ROOT:cache,GITHUB_ENV:output,GITHUB_RUN_ID:'123',GITHUB_RUN_ATTEMPT:'1'}});
      assert.equal(result.status,0,result.stderr);
      assert.equal(readFileSync(log,'utf8'),platform==='android'?'prepare\ncitizen:android\nchat:android\n':
        'prepare\ncitizen:apple\nchat:ios\nproject:darwin/CitizenSDK.xcframework\nproject:ios/TataChatSDK.xcframework\n');
      const vars=readFileSync(output,'utf8');assert.ok(vars.includes('TATACHATSDK_SOURCE_ROOT='+chat+'\n'));
      if(platform==='android') {
        assert.ok(vars.includes('CITIZENAPP_NATIVE_ANDROID_DIR='+join(cache,'tatachatsdk-output/android')+'\n'));
        assert.ok(vars.includes('ANDROID_NDK_HOME='+join(work,'android-sdk/ndk/28.2.13676358')+'\n'));
        assert.ok(vars.includes('ANDROID_NM='+join(work,'android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-nm')+'\n'));
      }
    }
  } finally {rmSync(root,{recursive:true,force:true});}
});

// 执行真实准备步骤；引擎替身模拟下载失败，不在本机编译或下载原件。
test('双端CI在原生编译前补齐所属Flutter引擎且预加载失败立即停止', () => {
  const root=realpathSync(mkdtempSync(join(tmpdir(),'app-ci-engine-'))),log=join(root,'calls');
  mkdirSync(join(root,'scripts/ci'),{recursive:true});
  writeFileSync(join(root,'scripts/ci/flutter.mjs'),"import{appendFileSync}from'node:fs';\n" +
    "appendFileSync(process.env.CALLS,JSON.stringify(['gradle-revision'])+'\\n');\n" +
    "if(process.env.FAIL_REVISION==='true')process.exit(73);\n");
  writeFileSync(join(root,'flutter'),`#!${process.execPath}
const fs=require('node:fs'),args=process.argv.slice(2);fs.appendFileSync(process.env.CALLS,JSON.stringify(args)+'\\n');
if(process.env.FAIL_ENGINE==='true'&&args[0]==='precache')process.exit(74);
`,{mode:0o755});
  try {
    for(const [steps,targets] of [[androidSteps,['--android']],[iosSteps,['--ios','--macos']]]) {
      for(const failure of ['none','engine',...(steps===androidSteps?['revision']:[])]) {
        const fail=failure==='engine';
        writeFileSync(log,'');
        const r=spawnSync('/bin/bash',['-e','-o','pipefail','-c',steps['6'].source],{encoding:'utf8',env:{
          ...process.env,PATH:root+':'+process.env.PATH,CALLS:log,FAIL_ENGINE:String(fail),
          FAIL_REVISION:String(failure==='revision'),GITHUB_WORKSPACE:root,
        }});
        assert.equal(r.status,fail?74:failure==='revision'?73:0,r.stderr);
        assert.deepEqual(readFileSync(log,'utf8').trim().split('\n').map(JSON.parse),[
          ['--version','--machine'],['--version'],['precache',...targets],
          ...(!fail&&steps===androidSteps?[['gradle-revision']]:[]),
        ]);
      }
    }
  } finally {rmSync(root,{recursive:true,force:true});}
});

// 解析实际YAML引用并执行终态分支，拒绝越界阶段及无状态的无条件record。
// 实际执行摘要和上下文变换，覆盖原始/已修订输入、破坏、链接、路径及整批拒绝。
test('Flutter CI修订核验完整前后摘要且未知输入不形成写入计划', () => {
  const root=realpathSync(mkdtempSync(join(tmpdir(),'app-ci-flutter-')));
  const hash=value=>createHash('sha256').update(value).digest('hex');
  const original='// upstream\nold\nlast\n',result='// upstream\nnew\nextra\nlast\n';
  const recipe={path:'packages/flutter_tools/gradle/fixture.kt',beforeSha256:hash(original),afterSha256:hash(result),
    hunks:[{start:1,before:['old'],after:['new','extra']}]};
  try {
    assert.equal(revisedSource(original,recipe),result);
    assert.equal(revisedSource(result,recipe),result);
    assert.throws(()=>revisedSource(original+'damage',recipe),/原始摘要/);
    assert.throws(()=>revisedSource(original,{...recipe,hunks:[{...recipe.hunks[0],before:['unknown']}]}),/上下文/);
    assert.throws(()=>revisedSource(original,{...recipe,afterSha256:hash('wrong')}),/结果摘要/);
    mkdirSync(join(root,'packages/flutter_tools/gradle'),{recursive:true});
    const file=join(root,recipe.path);writeFileSync(file,original);
    assert.deepEqual(revisionPlan(root,[recipe]),[{path:file,content:result}]);
    const second={...recipe,path:'packages/flutter_tools/gradle/second.kt'};
    writeFileSync(join(root,second.path),'damaged');
    assert.throws(()=>revisionPlan(root,[recipe,second]),/原始摘要/);
    assert.equal(readFileSync(file,'utf8'),original,'后续失败不得写入前一个已核验文件');
    assert.throws(()=>revisionPlan(root,[recipe,recipe]),/重复/);
    assert.throws(()=>revisionPlan(root,[{...recipe,path:'packages/flutter_tools/gradle/../escape.kt'}]),/越界/);
    rmSync(file);
    execFileSync('ln',['-s',join(root,second.path),file]);
    assert.throws(()=>revisionPlan(root,[recipe]),/普通文件/);
    assert.equal(gradleRecipes.length,6);
    assert.equal(new Set(gradleRecipes.map(x=>x.path)).size,6);
    const plugin=gradleRecipes.find(x=>x.path.endsWith('/FlutterPlugin.kt'));
    const revised=plugin.hunks.flatMap(x=>x.after).join('\n');
    assert.match(revised,/androidComponents|components\.onVariants/);
    assert.doesNotMatch(revised,/as AbstractAppExtension|android\.applicationVariants/);
  } finally {rmSync(root,{recursive:true,force:true});}
});

test('App双端CI所有YAML阶段可执行且缓存终态与候选上传顺序准确', () => {
  for(const [platform,steps] of [['android',androidSteps],['ios',iosSteps]]) {
    const yaml=readFileSync(new URL('../../.github/workflows/citizenapp-'+platform+'-ci.yml',import.meta.url),'utf8');
    const flow=yaml.split('\n  flow:\n')[1]; assert.ok(flow);
    const blocks=flow.split('\n    - ').slice(1);
    const records=[];
    for(const block of blocks) {
      const match=block.match(new RegExp('scripts/ci/'+platform+'[.]mjs" workflow-step ([0-9]+)'));
      if(!match)continue;
      const step=steps[match[1]];assert.ok(step,'unknown stage '+match[1]);
      if(!step.source.includes('" record'))continue;
      const terminal=block.match(/CI_CACHE_TERMINAL_STATE: (failure|success)/)?.[1];
      assert.ok(terminal,'unconditional terminal record');
      assert.ok(block.includes(terminal+'()'));
      const result=spawnSync('/bin/bash',['-e','-o','pipefail','-c',
        'node(){ printf "%s:%s\\n" "$2" "$CI_CACHE_TERMINAL_STATE"; };\n'+step.source],{encoding:'utf8',env:{...process.env,
        BASH_ENV:'/dev/null',GITHUB_WORKSPACE:'/fixture',CI_CACHE_TERMINAL_STATE:terminal},
        input:''});
      assert.equal(result.status,0,result.stderr);
      assert.equal(result.stdout,'sanitize:'+terminal+'\nrecord:'+terminal+'\n');
      records.push(terminal);
    }
    assert.deepEqual(records,['failure','success']);
    assert.ok(flow.indexOf('actions/upload-artifact@')<flow.indexOf('CI_CACHE_TERMINAL_STATE: failure'));
    for(const line of yaml.split('\n').filter(x=>x.includes('failure()')))assert.match(line,/__ci_cache[.]outcome == 'success'/);
  }
});
