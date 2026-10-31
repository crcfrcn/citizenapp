// 测试发现只读取产品自己的workspace声明；各包全部测试只注册一次。
import {readFileSync,readdirSync,existsSync,writeFileSync,realpathSync,statSync} from 'node:fs';
import {spawn} from 'node:child_process';
import {resolve,join} from 'node:path';
import {fileURLToPath} from 'node:url';

import {testSuites,testArguments,performanceMetrics} from '../../scripts/config.mjs';
import {packageRoots,buildTests} from '../../scripts/build.mjs';
export {packageRoots};

export function testFiles(root,{assembled=false}={}){
 const files=[];
 const walk=path=>{for(const entry of readdirSync(path,{withFileTypes:true})){
  const name=join(path,entry.name);if(entry.isDirectory())walk(name);else if(entry.isFile()&&entry.name.endsWith('_test.dart'))files.push(name);
 }};
 if(!assembled&&existsSync(join(root,'test')))throw Error('产品根目录禁止test目录或文件');
 for(const owner of packageRoots(root)){
  const path=owner===root?join(owner,assembled?'test':'lib/test'):join(owner,'test');if(!existsSync(path))throw Error('包缺少唯一测试目录：'+owner);walk(path);
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
  let timer;
  const cancel=()=>{if(timer)return;cancellation.abort();try{process.kill(-child.pid,'SIGTERM');}catch{}
   timer=setTimeout(()=>{try{process.kill(-child.pid,'SIGKILL');}catch{}},30000);
  };
  for(const signal of ['SIGINT','SIGTERM'])process.once(signal,cancel);
  child.once('error',fail);child.once('close',async code=>{
   for(const signal of ['SIGINT','SIGTERM'])process.removeListener(signal,cancel);
   clearTimeout(timer);
   for(let retry=0;retry<100&&child.pid;retry++){
    try{process.kill(-child.pid,0);}catch(error){if(error.code==='ESRCH')break;}
    try{process.kill(-child.pid,'SIGKILL');}catch{}
    if(retry===99)return fail(Error('测试后代未退出，须保留现场'));
    await new Promise(resolve=>setTimeout(resolve,100));
   }
   code===0&&!cancellation.signal.aborted?done(output):fail(Error('测试命令失败或取消：'+command+' '+code));
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

// 直接使用同版Dart启动官方Flutter工具快照；macOS系统shell会移除SDK夹具所需预载。
export async function hostTests({work},execute=run,environment=process.env){
 const root=resolve(environment.CITIZENAPP_TEST_ROOT||join(work,'project'));
 if(!environment.FLUTTER_ROOT)throw Error('宿主测试须显式交付现有FLUTTER_ROOT');
 const flutter=join(environment.FLUTTER_ROOT,'bin/flutter');
 const dart=join(environment.FLUTTER_ROOT,'bin/cache/dart-sdk/bin/dart');
 const snapshot=join(environment.FLUTTER_ROOT,'bin/cache/flutter_tools.snapshot');
 const source=resolve(environment.CITIZENAPP_SOURCE_ROOT||root);
 const expected=testFiles(root,{assembled:true}),events=join(work,'flutter-report.jsonl');
 await execute(process.execPath,['--test',join(source,'lib/test/release_manifest.test.mjs'),join(source,'lib/test/runner.test.mjs'),join(source,'lib/test/workspace.test.mjs'),join(source,'lib/test/update_delivery.test.mjs'),join(source,'transaction/test/topup/bridge.test.mjs')],source,false,environment);
 await execute(flutter,['analyze','--fatal-infos','--fatal-warnings','--no-pub'],root,false,environment);
 const testEnvironment={...environment,...process.platform==='darwin'&&environment.CITIZENSDK_TEST_LIBRARY?{DYLD_INSERT_LIBRARIES:environment.CITIZENSDK_TEST_LIBRARY}:{}};
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
