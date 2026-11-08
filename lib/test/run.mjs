// 测试发现只读取产品自己的workspace声明；各包全部测试只注册一次。
import {readFileSync,readdirSync,existsSync,writeFileSync,realpathSync,statSync,mkdtempSync,mkdirSync,rmSync,copyFileSync} from 'node:fs';
import {spawn} from 'node:child_process';
import {resolve,join,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';

import {testSuites,testArguments,performanceMetrics} from '../../scripts/config.mjs';
import {buildMls,packageRoots} from '../../scripts/build.mjs';
export {packageRoots};

export function testFiles(root){
 const files=[];
 const walk=path=>{for(const entry of readdirSync(path,{withFileTypes:true})){
  const name=join(path,entry.name);if(entry.isDirectory())walk(name);else if(entry.isFile()&&entry.name.endsWith('_test.dart'))files.push(name);
 }};
 if(existsSync(join(root,'test')))throw Error('产品根目录禁止test目录或文件');
 for(const owner of packageRoots(root)){
  const path=owner===root?join(owner,'lib/test'):join(owner,'test');if(!existsSync(path))throw Error('包缺少唯一测试目录：'+owner);walk(path);
 }
 return files.sort();
}
const cancellation=new AbortController();
async function run(command,args,cwd,capture=false,environment=process.env){
 cancellation.signal.throwIfAborted();
 return await new Promise((done,fail)=>{
  const child=spawn(command,args,{cwd,env:environment,detached:true,stdio:capture?['ignore','pipe','pipe']:'inherit'});
  child.stderr?.resume();
  let output='';if(capture)child.stdout.on('data',bytes=>{output+=bytes;});
  let timer, failure;
  const cancel=()=>{if(timer)return;cancellation.abort();try{process.kill(-child.pid,'SIGTERM');}catch{}
   timer=setTimeout(()=>{try{process.kill(-child.pid,'SIGKILL');}catch{}},30000);
  };
  for(const signal of ['SIGINT','SIGTERM'])process.once(signal,cancel);
  child.once('error',error=>{failure=error;});child.once('close',async code=>{
   for(const signal of ['SIGINT','SIGTERM'])process.removeListener(signal,cancel);
   clearTimeout(timer);
   for(let retry=0;retry<100&&child.pid;retry++){
    try{process.kill(-child.pid,0);}catch(error){if(error.code==='ESRCH')break;}
    try{process.kill(-child.pid,'SIGKILL');}catch{}
    if(retry===99)return fail(Object.assign(Error('测试后代未退出，须保留现场'),{keepWork:true}));
    await new Promise(resolve=>setTimeout(resolve,100));
   }
   code===0&&!cancellation.signal.aborted?done(output):fail(failure||Error('测试命令失败或取消：'+command+' '+code));
  });
 });
}
export function verifyReport(file,expected){
 const events=readFileSync(file,'utf8').trim().split('\n').map(JSON.parse);
 const started=events.filter(row=>row.type==='testStart'),starts=new Set(started.map(row=>row.test.id));
 const ended=events.filter(row=>row.type==='testDone'),done=events.filter(row=>row.type==='done');
 const loaded=new Set(events.filter(row=>row.type==='suite').map(row=>resolve(row.suite.path)));
 if(!starts.size||started.length!==starts.size||new Set(ended.map(row=>row.testID)).size!==ended.length||ended.some(row=>!starts.has(row.testID))||done.length!==1||done[0].success!==true||ended.length!==starts.size||
    ended.some(row=>row.skipped||row.result!=='success')||expected.some(path=>!loaded.has(resolve(path))))throw Error('Flutter回归失败、跳过或漏跑');
 return {files:expected.length,tests:ended.length};
}
// 参数使用配置的同一闭集；空设备或未知组在任何子进程启动前失败。
export function testPlan(argv,environment=process.env){
 const [suite='host',platform,...options]=argv,inputs={suite};
 if(options.length%2)throw Error('测试参数必须成对');
 for(let i=0;i<options.length;i+=2){
  const key=options[i].replace(/^--/,'');
  if(!options[i].startsWith('--')||Object.hasOwn(inputs,key))throw Error('重复或无效测试参数');
  inputs[key]=options[i+1];
 }
 if(suite==='host'&&platform)throw Error('宿主组不接受平台参数');
 testArguments(platform,inputs);
 const work=environment.WORK;
 if(!work||resolve(work)!==work||!existsSync(work)||!statSync(work).isDirectory())throw Error('测试需要本轮独占绝对WORK目录');
 if(suite==='host')return {suite,work};
 if(suite==='compile'){
  if(inputs.scope&&!['all','ui','unit'].includes(inputs.scope))throw Error('未知编译范围');
  return {suite,platform,work,scope:inputs.scope||'all'};
 }
 if(!inputs.device||!/^[A-Za-z0-9_.:-]+$/.test(inputs.device))throw Error('设备测试必须指定有效隔离设备');
 if(inputs.fixture&&!/^[A-Za-z0-9_-]+\.mp4$/.test(inputs.fixture))throw Error('夹具只能是隔离缓存内的合成视频文件名');
 if(platform==='ios'){
  if(!inputs.artifact||!inputs.artifact.endsWith('.xctestrun')||!existsSync(inputs.artifact))throw Error('须提供已编译xctestrun');
 }else if(!/^[A-Za-z0-9_.]+\/[A-Za-z0-9_.]+$/.test(inputs.component||''))throw Error('须提供已安装测试组件');
 return {suite,platform,work,...inputs,cases:testSuites[platform][suite]};
}

export function verifyAndroidReport(output,expected){
 const starts=new Set(),ended=new Map(),metrics=[];let status={},finished=false;
 for(const line of output.split(/\r?\n/)){
  if(finished&&/^INSTRUMENTATION_/.test(line))throw Error('Android终态后仍有运行器状态');
  const field=/^INSTRUMENTATION_STATUS: ([^=]+)=(.*)$/.exec(line);
  if(field){status[field[1]]=field[2];continue;}
  const code=/^INSTRUMENTATION_STATUS_CODE: (-?\d+)$/.exec(line);
  if(code){
   if(status.citizenapp_metrics)metrics.push(JSON.parse(status.citizenapp_metrics));
   const id=status.class+'#'+status.test,value=Number(code[1]);
   if(value===1){if(starts.has(id))throw Error('Android重复开始');starts.add(id);}
   else if(value!==2){if(!starts.has(id)||ended.has(id)||value!==0)throw Error('Android失败、跳过或无开始');ended.set(id,value);}
   status={};
  }
  if(/^INSTRUMENTATION_CODE:/.test(line)){
   if(line!=='INSTRUMENTATION_CODE: -1'||Object.keys(status).length)throw Error('Android终态无效或状态帧未结束');
   finished=true;
  }
  if(/^INSTRUMENTATION_(FAILED|ABORTED):/.test(line))throw Error('Android运行器失败');
 }
 if(!finished||!expected.length||starts.size!==expected.length||ended.size!==expected.length||expected.some(id=>!ended.has(id)))throw Error('Android零用例或漏跑');
 return {tests:ended.size,metrics};
}
const testID=value=>value.replace(/\(\)$/,'').split('/').slice(-2).join('/');
export function verifyAppleReport(report,expected){
 const cases=[];
 const walk=node=>{if(node.nodeType==='Test Case')cases.push(node);for(const child of node.children||[])walk(child);};
 for(const node of report.testNodes||[])walk(node);
 const ids=cases.map(node=>testID(node.nodeIdentifier||''));
 if(!expected.length||cases.length!==expected.length||new Set(ids).size!==ids.length||cases.some(node=>node.result!=='Passed')||expected.some(id=>!ids.includes(testID(id))))throw Error('iOS失败、跳过、零用例或漏跑');
 return {tests:cases.length};
}
export function verifyMetrics(platform,rows,expected){
 const samples=[];
 for(const id of expected){
  if(platform==='ios'){
   const matches=rows.filter(row=>testID(row.testIdentifier)===testID(id));
   const required=performanceMetrics[testID(id)];
   if(matches.length!==1||!required||!matches[0].testRuns?.length)throw Error('iOS缺少唯一性能场景或测量运行');
   const values=[];
   for(const run of matches[0].testRuns){
    if(!Array.isArray(run.metrics)||!run.metrics.length)throw Error('iOS缺少有效性能测量');
    for(const metric of run.metrics){
     if(!Array.isArray(metric.measurements)||!metric.measurements.length||metric.measurements.some(n=>!Number.isFinite(n)))throw Error('iOS缺少有效性能测量');
    }
    for(const item of required){
     const found=run.metrics.filter(metric=>typeof metric.displayName==='string'&&
      (item.name==='Clock Monotonic Time'?metric.displayName===item.name:metric.displayName.startsWith(item.name)));
     if(found.length!==1||!item.units.includes(found[0].unitOfMeasurement)||found[0].measurements.some(n=>n<=0))throw Error('iOS缺少必需性能指标、单位无效或重复');
    }
    values.push(...run.metrics);
   }
   samples.push({test:id,metrics:values.map(({displayName,unitOfMeasurement,measurements})=>({displayName,unitOfMeasurement,measurements}))});
  }else{
   const values=rows.filter(row=>row.test===id);
   if(values.length!==1||values[0].samples?.length!==5||values[0].samples.some(row=>!Number.isFinite(row.elapsed_ns)||row.elapsed_ns<=0||!Number.isFinite(row.pss_kb)||row.pss_kb<=0))throw Error('Android缺少有效性能测量');
   samples.push(values[0]);
  }
 }
 return {assessment:'unassessed',reason:'除创作者首帧1秒断言外，须由固定设备建立基线',samples};
}

// 设备执行单列；只消费显式预编译产物，不调用构建、签名或安装命令。
export async function deviceTests(plan,execute=run,environment=process.env){
 const {platform,suite,work,cases}=plan;
 if(platform==='android'){
  const args=['-s',plan.device,'shell','am','instrument','-w','-r','-e','class',cases.join(',')];
  if(plan.fixture)args.push('-e','media_fixture',plan.fixture);
  const output=await execute(environment.ADB_BIN||'adb',[...args,plan.component],work,true);
  const result=verifyAndroidReport(output,cases);
  return {tests:result.tests,...suite==='performance'?{performance:verifyMetrics(platform,result.metrics,cases)}:{}};
 }
 const bundle=join(work,suite+'.xcresult');
 if(existsSync(bundle))throw Error('结果现场已存在，不能覆盖上次验收');
 await execute('/usr/bin/xcrun',['xcodebuild','test-without-building','-xctestrun',realpathSync(plan.artifact),
  '-destination','id='+plan.device,'-resultBundlePath',bundle,'-parallel-testing-enabled','NO',
  ...cases.map(id=>'-only-testing:'+id)],work,true);
 const result=verifyAppleReport(JSON.parse(await execute('/usr/bin/xcrun',['xcresulttool','get','test-results','tests','--path',bundle,'--compact'],work,true)),cases);
 if(suite==='performance')result.performance=verifyMetrics(platform,JSON.parse(await execute('/usr/bin/xcrun',['xcresulttool','get','test-results','metrics','--path',bundle,'--compact'],work,true)),cases);
 return result;
}

const testInputError=message=>Object.assign(Error(message),{code:'TEST_INPUT'});

// 只编译本轮已装配工程的测试；不签名、安装或启动设备。
// ui在模拟器SDK编译隔离宿主；unit/all用真机SDK只编译完整Runner，不连接设备。
export async function buildTests(platform,{work=process.env.WORK,scope='all',environment=process.env,execute=run}={}){
 if(!['ios','android'].includes(platform)||!['all','ui','unit'].includes(scope))throw Error('未知测试编译目标');
 if(!work||!existsSync(work))throw testInputError('测试编译需要独占WORK');
 work=realpathSync(work);
 const project=join(work,'project');
 if(!existsSync(project)||realpathSync(project)===realpathSync(fileURLToPath(new URL('../../',import.meta.url))))throw Error('测试编译只能写本轮普通工程');
 if(environment.GITHUB_ACTIONS==='true')throw Error('测试编译入口不消费正式签名环境');
 const marker=join(work,'tests-active.json');
 writeFileSync(marker,JSON.stringify({pid:process.pid}),{flag:'wx',mode:0o600});
 let preserve=false;
 try{
  if(platform==='android'){
   if(scope!=='all')throw Error('Android测试统一编译Release androidTest');
   if(!environment.GRADLE_BIN)throw testInputError('须交付已安装GRADLE_BIN，禁止wrapper隐式下载');
   if(!environment.FLUTTER_ROOT)throw testInputError('须交付已准备Flutter工具及原锁Pub输入');
   const flutter=join(environment.FLUTTER_ROOT,'bin/flutter');
   // 先按原锁解析；官方config-only只更新Release插件登记与配置，不构建或签署APK。
   await execute(flutter,['pub','get','--enforce-lockfile'],project,false,environment,'Android原锁确认');
   const lock=readFileSync(join(project,'pubspec.lock'));
   await execute(flutter,['build','apk','--config-only','--release','--target-platform','android-arm64'],
    project,false,environment,'Android Release配置准备');
   // Pub会规范化空行；所有版本、来源、摘要和路径记录必须保持逐行一致。
   const records=bytes=>bytes.toString('utf8').split(/\r?\n/).filter(line=>line.trim().length).join('\n');
   if(records(lock)!==records(readFileSync(join(project,'pubspec.lock'))))throw Error('Android配置准备改变了交付原锁记录');
   await execute(environment.GRADLE_BIN,['--no-daemon','--console=plain','-Ptarget-platform=android-arm64',
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
 }catch(error){
  preserve=error.keepWork===true;
  throw error;
 }finally{
  if(!preserve)rmSync(marker,{force:true});
 }
}

// App回归编译SDK交付的原始系统资源夹具，链接同一正式Core；不实现或替换SDK业务。
async function prepareCitizenSdkTestFixture({sdkRoot,work,environment=process.env}) {
 if(process.platform!=='darwin')throw Error('当前App宿主回归需要macOS SDK组件');
 const framework=join(sdkRoot,'darwin/CitizenSDK.xcframework/macos-arm64/CitizenSDK.framework/CitizenSDK');
 if(!existsSync(framework))throw Error('宿主回归缺少同轮CitizenSDK macOS组件，请由SDK公开Apple入口准备');
 const producer=await import(pathToFileURL(join(sdkRoot,'scripts/build.mjs')));
 const directory=join(work,'sdk-test-support');mkdirSync(directory,{recursive:true});
 writeFileSync(join(directory,'citizensdk_internal.h'),producer.citizenSdkInternalHeader());
 copyFileSync(join(sdkRoot,'image/citizensdk_qr_image.h'),join(directory,'citizensdk_qr_image.h'));
 const output=join(directory,'ffi.dylib'),slice=dirname(dirname(framework));
 await run('/usr/bin/xcrun',['clang++','-std=c++17','-dynamiclib','-fPIC','-Wall','-Wextra','-Wpedantic','-Wconversion','-Wsign-conversion','-Werror',
  '-I'+join(sdkRoot,'include'),'-I'+join(sdkRoot,'core/cpp'),'-I'+directory,join(sdkRoot,'lib/test/cpp.cc'),
  '-F'+slice,'-framework','CitizenSDK','-framework','Security','-framework','SystemConfiguration','-framework','CoreFoundation',
  '-lsqlite3','-lc++','-liconv','-lresolv','-Wl,-rpath,'+slice,'-o',output],sdkRoot,false,environment);
 return output;
}

// 直接使用同版Dart启动官方Flutter工具快照；macOS系统shell会移除SDK夹具所需预载。
export async function hostTests({work},execute=run,environment=process.env){
 const root=resolve(environment.CITIZENAPP_TEST_ROOT||join(work,'project'));
 if(!environment.FLUTTER_ROOT)throw Error('宿主测试须显式交付现有FLUTTER_ROOT');
 const flutter=join(environment.FLUTTER_ROOT,'bin/flutter');
 const dart=join(environment.FLUTTER_ROOT,'bin/cache/dart-sdk/bin/dart');
 const snapshot=join(environment.FLUTTER_ROOT,'bin/cache/flutter_tools.snapshot');
 const source=resolve(environment.CITIZENAPP_SOURCE_ROOT||root);
 const expected=testFiles(root),events=join(work,'flutter-report.jsonl');
 await execute(process.execPath,['--test',join(source,'lib/test/release_manifest.test.mjs'),join(source,'lib/test/runner.test.mjs'),join(source,'lib/test/workspace.test.mjs'),join(source,'lib/test/update_delivery.test.mjs'),join(source,'topup/test/bridge.test.mjs')],source,false,environment);
 await execute(flutter,['analyze','--fatal-infos','--fatal-warnings','--no-pub'],root,false,environment);
 const fixture=environment.CITIZENSDK_TEST_LIBRARY || await prepareCitizenSdkTestFixture({sdkRoot:environment.CITIZENSDK_SOURCE_DIR||join(work,'packages/citizen_sdk'),work,environment});
 const state=mkdtempSync(join(work,'sdk-test-state-'));
 const testEnvironment={...environment,CITIZENAPP_TEST_WORK_DIR:work,MLS_COMPONENT_DIR:join(work,'mls'),
  CITIZENSDK_TEST_LIBRARY:fixture,CITIZENSDK_TEST_WORK_DIR:state};
 if(process.platform==='darwin'){
  testEnvironment.MLS_TEST_LIBRARY=await buildMls({project:root,work,platform:'host',environment,execute});
  testEnvironment.DYLD_INSERT_LIBRARIES=fixture;
 }
 await execute(dart,[snapshot,'test','--no-pub','--concurrency=1','--fail-fast','--file-reporter','json:'+events,...expected],root,false,testEnvironment);
 return {suite:'host',status:'passed',...verifyReport(events,expected)};
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const plan=testPlan(process.argv.slice(2)),{work,suite}=plan;
 const report=join(work,[suite,plan.platform,...suite==='compile'?[plan.scope]:[]].filter(Boolean).join('-')+'-result.json');
 if(existsSync(report))throw Error('本组结果已存在，须使用独占现场');
 try{
  if(suite==='compile'){
   writeFileSync(report,JSON.stringify(await buildTests(plan.platform,plan)));
  }else if(suite!=='host'){
   writeFileSync(report,JSON.stringify({suite,platform:plan.platform,status:'passed',...await deviceTests(plan)}));
  }else{
   const result=await hostTests(plan);
   writeFileSync(report,JSON.stringify(result));console.log(JSON.stringify(result));
  }
 }catch(error){writeFileSync(report,JSON.stringify({suite,platform:plan.platform,status:error.code==='TEST_INPUT'?'not_ready':'failed'}));throw error;}
}
