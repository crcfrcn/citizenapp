import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync,chmodSync,realpathSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {packageRoots,testFiles,verifyReport,testPlan,verifyAndroidReport,verifyAppleReport,verifyMetrics,deviceTests,hostTests} from './run.mjs';

import {describeAction,testSuites} from '../../scripts/config.mjs';
import {buildTests,prepareTests} from '../../scripts/build.mjs';

function fixture(t){const root=mkdtempSync(join(tmpdir(),'citizen-discovery-'));t.after(()=>rmSync(root,{recursive:true,force:true}));return root;}
test('workspace每包只发现所属test，辅助文件和其它源码不登记',t=>{
 const root=fixture(t);writeFileSync(join(root,'pubspec.yaml'),"workspace:\n  - account\n  - '8964'\n");
 for(const owner of ['','account','8964']){const path=join(root,owner,owner?'test':'lib/test');mkdirSync(path,{recursive:true});writeFileSync(join(path,'case_test.dart'),'');writeFileSync(join(path,'fixture.dart'),'');}
 assert.equal(packageRoots(root).length,3);assert.equal(testFiles(root).length,3);
 mkdirSync(join(root,'account/lib'));writeFileSync(join(root,'account/lib','ignored_test.dart'),'');assert.equal(testFiles(root).length,3);
 rmSync(join(root,'8964/test'),{recursive:true});assert.throws(()=>testFiles(root),/缺少唯一测试目录/);
});
test('重复包声明、漏跑、跳过和失败不能形成全量通过',t=>{
 const root=fixture(t),file=join(root,'report.jsonl'),path=join(root,'case_test.dart');
 writeFileSync(join(root,'pubspec.yaml'),'workspace:\n  - account\n  - account\n');assert.throws(()=>packageRoots(root),/重复/);
 const rows=[{type:'suite',suite:{path}},{type:'testStart',test:{id:1}},{type:'testDone',testID:1,result:'success',skipped:false},{type:'done',success:true}];
 const put=()=>writeFileSync(file,rows.map(JSON.stringify).join('\n'));
 put();assert.deepEqual(verifyReport(file,[path]),{files:1,tests:1});assert.throws(()=>verifyReport(file,[path,join(root,'missing_test.dart')]),/漏跑/);
 rows[2].skipped=true;put();assert.throws(()=>verifyReport(file,[path]),/跳过/);rows[2].skipped=false;rows[2].result='error';put();assert.throws(()=>verifyReport(file,[path]),/失败/);
});

test('设备输入在启动前拒绝缺设备、未知组、重复参数与未声明输入',t=>{
 const root=fixture(t),environment={WORK:root};
 assert.deepEqual(testPlan(['host'],environment),{suite:'host',work:root});
 for(const args of [['native','android','--device','isolated','--component','sample.test/Runner','--fixture','x;echo.mp4'],['native','android','--device','x,platform=other','--component','sample.test/Runner'],['other'],['host','ios'],['e2e','ios'],['native','android','--device','isolated'],['compile','ios','--scope','unknown'],['compile','ios','--scope','ui','--scope','unit'],['e2e','ios','--anything','yes']])assert.throws(()=>testPlan(args,environment));
 const artifact=join(root,'tests.xctestrun');writeFileSync(artifact,'');
 const plan=testPlan(['e2e','ios','--device','isolated','--artifact',artifact],environment);
 assert.equal(plan.cases.length,5);assert.ok(plan.cases.every(id=>id.split('/').length===3&&id.split('/')[2].startsWith('test')));
 assert.throws(()=>describeAction({flow:'test',platform:'ios',inputs:{suite:'compile'}}),/WORK/);
 const action=describeAction({flow:'test',platform:'android',inputs:{work:root,suite:'compile',environment:{GRADLE_BIN:'/existing/gradle'}}});
 assert.deepEqual(action.env,{GRADLE_BIN:'/existing/gradle',WORK:root});
 assert.deepEqual(describeAction({flow:'test',platform:'ios',inputs:{work:root,suite:'compile',scope:'ui'}}).args.slice(-4),['compile','ios','--scope','ui']);
});
const androidOutput=(id,code=0)=>{
 const [owner,name]=id.split('#');
 return `INSTRUMENTATION_STATUS: class=${owner}\nINSTRUMENTATION_STATUS: test=${name}\nINSTRUMENTATION_STATUS_CODE: 1\nINSTRUMENTATION_STATUS: class=${owner}\nINSTRUMENTATION_STATUS: test=${name}\nINSTRUMENTATION_STATUS_CODE: ${code}\nINSTRUMENTATION_CODE: -1\n`;
};
test('Android退出码之外核对开始、唯一结束、失败、忽略、漏跑和运行器终态',()=>{
 const expected=['sample.Test#case'];
 assert.equal(verifyAndroidReport(androidOutput(expected[0]),expected).tests,1);
 for(const code of [-1,-2,-3,-4])assert.throws(()=>verifyAndroidReport(androidOutput(expected[0],code),expected));
 for(const output of ['',androidOutput('other.Test#case'),androidOutput(expected[0])+androidOutput(expected[0]),androidOutput(expected[0]).replace('INSTRUMENTATION_CODE: -1','INSTRUMENTATION_FAILED: unavailable')])assert.throws(()=>verifyAndroidReport(output,expected));
});
test('Apple结构化报告拒绝跳过、预期失败、重复、零用例或漏跑',()=>{
 const expected=['RunnerUITests/RunnerUITests/testExample'];
 const row={nodeType:'Test Case',name:'testExample()',nodeIdentifier:'RunnerUITests/testExample()',result:'Passed'};
 const report={testNodes:[{nodeType:'Test Suite',children:[row]}]};
 assert.deepEqual(verifyAppleReport(report,expected),{tests:1});
 for(const result of ['Failed','Skipped','Expected Failure','unknown'])assert.throws(()=>verifyAppleReport({testNodes:[{...row,result}]},expected));
 assert.throws(()=>verifyAppleReport({testNodes:[]},expected));
 assert.throws(()=>verifyAppleReport({testNodes:[row,row]},expected));
 assert.throws(()=>verifyAppleReport(report,[...expected,'RunnerTests/RunnerTests/testMissing']));
});
test('性能必须有真实有效采样，收集成功也不能冒充基线达标',()=>{
 const id='sample.Test#launch',rows=[{test:id,samples:Array.from({length:5},()=>({elapsed_ns:100,pss_kb:42}))}];
 assert.equal(verifyMetrics('android',rows,[id]).assessment,'unassessed');
 for(const data of [[],[...rows,...rows],[{test:id,samples:[]}],[{test:id,samples:Array(5).fill({elapsed_ns:0,pss_kb:42})}]])assert.throws(()=>verifyMetrics('android',data,[id]));
 const apple=[{testIdentifier:'RunnerUITests/testPerformanceLaunch()',testRuns:[{metrics:[{displayName:'App Launch Duration (First Frame)',unitOfMeasurement:'s',measurements:[0.2,0.3]}]}]}];
 assert.equal(verifyMetrics('ios',apple,['RunnerUITests/RunnerUITests/testPerformanceLaunch']).assessment,'unassessed');
 apple[0].testRuns[0].metrics[0].measurements=[];assert.throws(()=>verifyMetrics('ios',apple,['RunnerUITests/RunnerUITests/testPerformanceLaunch']));
});
test('设备编排只消费已准备输入和闭集选择器，拒绝adb成功退出但漏用例',async t=>{
 const root=fixture(t),plan={suite:'e2e',platform:'android',work:root,device:'isolated',component:'sample.test/Runner',cases:['sample.Test#case']},calls=[];
 const execute=async(command,args,cwd,capture)=>{calls.push({command,args,cwd,capture});return androidOutput(plan.cases[0]);};
 assert.equal((await deviceTests(plan,execute,{ADB_BIN:'/installed/adb'})).tests,1);
 assert.deepEqual(calls[0].args,['-s','isolated','shell','am','instrument','-w','-r','-e','class','sample.Test#case','sample.test/Runner']);
 await assert.rejects(deviceTests(plan,async()=> 'INSTRUMENTATION_CODE: -1',{}),/漏跑/);
 const artifact=join(root,'tests.xctestrun');writeFileSync(artifact,'');
 const expected='RunnerUITests/RunnerUITests/testExample',appleCalls=[];
 const appleExecute=async(command,args)=>{appleCalls.push(args);return args[0]==='xcodebuild'?'':JSON.stringify({testNodes:[{nodeType:'Test Case',nodeIdentifier:'RunnerUITests/testExample()',result:'Passed'}]});};
 assert.equal((await deviceTests({...plan,platform:'ios',artifact,cases:[expected]},appleExecute)).tests,1);
 assert.ok(appleCalls[0].includes('-only-testing:'+expected));
 assert.ok(!appleCalls.flat().some(arg=>arg==='test'||arg==='install'||arg==='build'));
});
test('测试编译拒绝正式源码现场及未声明目标，不启动工具',async()=>{
 await assert.rejects(buildTests('unknown'),/未知/);
 await assert.rejects(buildTests('ios',{work:'/nonexistent'}),/独占/);
});


test('真实子进程输出进入Android结果核对，不丢失capture结果',async t=>{
 const root=fixture(t),adb=join(root,'adb'),id='sample.Test#case';
 writeFileSync(adb,"#!/bin/sh\nprintf '%s\\n' '"+androidOutput(id)+"'\n");chmodSync(adb,0o755);
 const result=await deviceTests({platform:'android',suite:'native',work:root,device:'isolated',component:'sample.test/Runner',cases:[id]},undefined,{ADB_BIN:adb});
 assert.equal(result.tests,1);
});


test('设备清单对应所属原生真实测试，原生安全用例完整且每组坐标唯一',()=>{
 for(const [platform,suites] of Object.entries(testSuites)){
  for(const [suite,cases] of Object.entries(suites)){
   assert.equal(new Set(cases).size,cases.length);
   for(const id of cases){
    const owner=platform==='ios'?id.split('/')[1]:id.split('#')[0].split('.').at(-1);
    const method=platform==='ios'?id.split('/')[2]:id.split('#')[1];
    const source=readFileSync(new URL('../../'+platform+'/tests/'+owner+(platform==='ios'?'.swift':'.kt'),import.meta.url),'utf8');
    assert.match(source,new RegExp('\\bfun'+(platform==='ios'?'c':'')+' '+method+'\\('),platform+' '+suite+' '+method);
   }
  }
 }
 const source=readFileSync(new URL('../../ios/tests/RunnerTests.swift',import.meta.url),'utf8');
 const methods=[...source.matchAll(/\bfunc (test\w+)\(/g)].map(match=>'RunnerTests/RunnerTests/'+match[1]);
 assert.deepEqual([...testSuites.ios.native,...testSuites.ios.performance.filter(id=>id.startsWith('RunnerTests/'))].sort(),methods.sort());
});

test('完整iOS缺原锁Pods时明确not_ready，清理本轮标记且不启动工具',async t=>{
 const work=fixture(t);mkdirSync(join(work,'project'));
 await assert.rejects(buildTests('ios',{work,scope:'all',environment:{}}),error=>error.code==='TEST_INPUT'&&error.message.includes('Pods'));
});


test('Android终态必须唯一且是最后一帧，矛盾、重复或悬空状态均拒绝',()=>{
 const id='sample.Test#case',valid=androidOutput(id);
 assert.equal(verifyAndroidReport('INSTRUMENTATION_STATUS: stream=progress\nINSTRUMENTATION_STATUS_CODE: 2\n'+valid,[id]).tests,1);
 for(const tail of ['INSTRUMENTATION_CODE: 0\n','INSTRUMENTATION_CODE: -1\n','INSTRUMENTATION_STATUS: class=other\n','INSTRUMENTATION_RESULT: shortMsg=crash\n'])assert.throws(()=>verifyAndroidReport(valid+tail,[id]));
 assert.throws(()=>verifyAndroidReport(valid.replace('INSTRUMENTATION_CODE: -1','INSTRUMENTATION_STATUS: test=unfinished\nINSTRUMENTATION_CODE: -1'),[id]));
 assert.throws(()=>verifyAndroidReport(valid.replace('INSTRUMENTATION_CODE: -1','INSTRUMENTATION_CODE: 0'),[id]));
});
test('iOS每轮必须齐备声明指标，缺内存、跨运行拼凑、重复和错单位均拒绝',()=>{
 const id='RunnerUITests/RunnerUITests/testPerformanceCreatorEntry';
 const clock={displayName:'Clock Monotonic Time',unitOfMeasurement:'s',measurements:[0.2,0.3]};
 const memory={displayName:'Memory Peak Physical',unitOfMeasurement:'kB',measurements:[100,110]};
 const rows=metrics=>[{testIdentifier:'RunnerUITests/testPerformanceCreatorEntry()',testRuns:[{metrics}]}];
 assert.equal(verifyMetrics('ios',rows([clock,memory]),[id]).assessment,'unassessed');
 for(const metrics of [[clock],[memory],[clock,memory,memory],[clock,{...memory,unitOfMeasurement:'s'}],[clock,{...memory,measurements:[NaN]}],[clock,{...memory,measurements:[0]}]])assert.throws(()=>verifyMetrics('ios',rows(metrics),[id]));
 const mixed=rows([clock]);mixed[0].testRuns.push({metrics:[memory]});assert.throws(()=>verifyMetrics('ios',mixed,[id]));
 assert.throws(()=>verifyMetrics('ios',[...rows([clock,memory]),...rows([clock,memory])],[id]));
});
test('iOS测试编译实际命令按scope选择project或Pods workspace',async t=>{
 for(const scope of ['ui','unit','all']){
  const work=fixture(t),project=join(work,'project'),engine=join(work,'flutter/bin/cache/artifacts/engine/ios-release/Flutter.xcframework');
  for(const directory of ['ios/Runner.xcodeproj','ios/Runner.xcworkspace','ios/Pods'])mkdirSync(join(project,directory),{recursive:true});
  mkdirSync(engine,{recursive:true});writeFileSync(join(project,'ios/Pods/Manifest.lock'),'locked');writeFileSync(join(project,'ios/Podfile.lock'),'locked');
  const calls=[];
  await buildTests('ios',{work,scope,environment:{FLUTTER_ROOT:join(work,'flutter')},execute:async(command,args)=>calls.push({command,args})});
  assert.equal(calls.length,1);const args=calls[0].args;
  const flag=scope==='ui'?'-project':'-workspace';assert.equal(args[args.indexOf(flag)+1],realpathSync(join(project,'ios',scope==='ui'?'Runner.xcodeproj':'Runner.xcworkspace')));
  assert.ok(args.includes('CODE_SIGNING_ALLOWED=NO'));assert.ok(args.includes('build-for-testing'));
 }
});

test('iOS已有Pods但Manifest与交付锁不符时拒绝编译',async t=>{
 const work=fixture(t),project=join(work,'project');mkdirSync(join(project,'ios/Pods'),{recursive:true});
 writeFileSync(join(project,'ios/Pods/Manifest.lock'),'old');writeFileSync(join(project,'ios/Podfile.lock'),'current');
 let invoked=false;
 await assert.rejects(buildTests('ios',{work,scope:'all',environment:{},execute:async()=>{invoked=true;}}),/Pods与交付锁不一致/);
 assert.equal(invoked,false);
});


test('根App只发现lib/test，根test无论文件或目录均拒绝',t=>{
 const root=fixture(t);writeFileSync(join(root,'pubspec.yaml'),'workspace:\n  - account\n');
 for(const path of ['lib/test','account/test']){mkdirSync(join(root,path),{recursive:true});writeFileSync(join(root,path,'case_test.dart'),'');}
 assert.equal(testFiles(root).length,2);
 writeFileSync(join(root,'test'),'forbidden');assert.throws(()=>testFiles(root),/根目录禁止test/);rmSync(join(root,'test'));
 mkdirSync(join(root,'test'));assert.throws(()=>testFiles(root),/根目录禁止test/);
});


test('普通工程测试装配保留正文、同包及跨包相对URI，Node入口仍归lib/test',t=>{
 const root=fixture(t);writeFileSync(join(root,'pubspec.yaml'),'workspace:\n  - account\n');
 mkdirSync(join(root,'lib/test/nested'),{recursive:true});mkdirSync(join(root,'account/test'),{recursive:true});
 writeFileSync(join(root,'account/test/case_test.dart'),'void main() {}');
 writeFileSync(join(root,'lib/test/widget_test.dart'),"import '../../account/test/case_test.dart' as member;\nimport 'nested/helper.dart';\nvoid main() { member.main(); }\n");
 writeFileSync(join(root,'lib/test/nested/helper.dart'),"export '../widget_test.dart';\n");
 writeFileSync(join(root,'lib/test/run.mjs'),'// node entry');
 assert.equal(testFiles(root).length,2);
 prepareTests(root);
 const source=readFileSync(join(root,'test/widget_test.dart'),'utf8');
 assert.ok(source.includes("import '../account/test/case_test.dart' as member;"));
 assert.ok(source.includes("import 'nested/helper.dart';"));assert.ok(source.includes('void main() { member.main(); }'));
 assert.ok(readFileSync(join(root,'test/nested/helper.dart'),'utf8').includes("export '../widget_test.dart';"));
 assert.equal(readFileSync(join(root,'lib/test/run.mjs'),'utf8'),'// node entry');
 assert.ok(!existsSync(join(root,'lib/test/widget_test.dart')));assert.equal(testFiles(root,{assembled:true}).length,2);
 assert.throws(()=>testFiles(root),/根目录禁止test/);assert.throws(()=>prepareTests(root),/普通工程/);
});

test('Android测试先离线核对原锁、官方config-only准备Release，再离线编译测试类',async t=>{
 const work=fixture(t);mkdirSync(join(work,'project'));writeFileSync(join(work,'project/pubspec.lock'),'locked');const calls=[];
 const environment={FLUTTER_ROOT:'/existing/flutter',GRADLE_BIN:'/existing/gradle'};
 await buildTests('android',{work,environment,execute:async(command,args)=>calls.push({command,args})});
 assert.deepEqual(calls[0],{command:'/existing/flutter/bin/flutter',args:['pub','get','--offline','--enforce-lockfile']});
 assert.deepEqual(calls[1],{command:'/existing/flutter/bin/flutter',args:['build','apk','--config-only','--release','--target-platform','android-arm64']});
 assert.equal(calls[2].command,'/existing/gradle');assert.ok(calls[2].args.includes('--offline'));
 const spacing=fixture(t);mkdirSync(join(spacing,'project'));writeFileSync(join(spacing,'project/pubspec.lock'),'locked\n\nrecord');
 await buildTests('android',{work:spacing,environment,execute:async(_,args)=>{if(args[0]==='build')writeFileSync(join(spacing,'project/pubspec.lock'),'locked\nrecord');}});
 assert.ok(calls[2].args.includes(':app:compileReleaseAndroidTestKotlin'));
 const other=fixture(t);mkdirSync(join(other,'project'));writeFileSync(join(other,'project/pubspec.lock'),'locked');
 let gradle=false;
 await assert.rejects(buildTests('android',{work:other,environment,execute:async(command,args)=>{
  if(args[0]==='build')writeFileSync(join(other,'project/pubspec.lock'),'changed');
  if(command==='/existing/gradle')gradle=true;
 }}),/改变了交付原锁/);assert.equal(gradle,false);
});


test('宿主入口通过同版Dart运行官方快照，SDK预载只交付测试进程',async t=>{
 const work=fixture(t),project=join(work,'project'),calls=[];
 mkdirSync(join(project,'test'),{recursive:true});mkdirSync(join(project,'account/test'),{recursive:true});
 writeFileSync(join(project,'pubspec.yaml'),'workspace:\n  - account\n');
 for(const file of ['test/root_test.dart','account/test/account_test.dart'])writeFileSync(join(project,file),'');
 const environment={FLUTTER_ROOT:join(work,'flutter'),CITIZENSDK_TEST_LIBRARY:join(work,'ffi.dylib')};
 const result=await hostTests({work},async(command,args,cwd,capture,env)=>{
  calls.push({command,args,cwd,capture,env});
  if(args[1]==='test'){
   const files=testFiles(project,{assembled:true});const rows=[];
   files.forEach((path,id)=>rows.push({type:'suite',suite:{id,path}},{type:'testStart',test:{id,suiteID:id}},{type:'testDone',testID:id,result:'success',skipped:false}));
   rows.push({type:'done',success:true});
   writeFileSync(join(work,'flutter-report.jsonl'),rows.map(JSON.stringify).join('\n'));
  }
 },environment);
 assert.equal(result.status,'passed');assert.equal(result.files,2);assert.equal(calls.length,3);
 assert.equal(calls[0].command,process.execPath);assert.equal(calls[0].env.DYLD_INSERT_LIBRARIES,undefined);
 assert.equal(calls[1].command,join(environment.FLUTTER_ROOT,'bin/flutter'));
 assert.equal(calls[2].command,join(environment.FLUTTER_ROOT,'bin/cache/dart-sdk/bin/dart'));
 assert.equal(calls[2].args[0],join(environment.FLUTTER_ROOT,'bin/cache/flutter_tools.snapshot'));
 assert.equal(calls[2].args[1],'test');
 assert.deepEqual(calls[2].args.slice(-2),testFiles(project,{assembled:true}));
 assert.equal(calls[2].env.DYLD_INSERT_LIBRARIES,process.platform==='darwin'?environment.CITIZENSDK_TEST_LIBRARY:undefined);
 assert.equal(environment.DYLD_INSERT_LIBRARIES,undefined);
});
