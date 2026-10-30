import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {mapSdkSource,preparePackages} from '../../scripts/build.mjs';

test('SDK路径同时映射根与所有真实消费者，不修改其它依赖',t=>{
 const root=mkdtempSync(join(tmpdir(),'citizen-workspace-'));t.after(()=>rmSync(root,{recursive:true,force:true}));
 const sdk='  citizen_sdk:\n    git:\n      url: https://github.com/crcfrcn/citizensdk.git\n      ref: main\n';
 writeFileSync(join(root,'pubspec.yaml'),'workspace:\n  - account\n  - assets\ndependencies:\n'+sdk+'  http: 1.6.0\n');
 for(const member of ['account','assets'])mkdirSync(join(root,member));
 writeFileSync(join(root,'account/pubspec.yaml'),'dependencies:\n'+sdk+'  http: 1.6.0\n');
 writeFileSync(join(root,'assets/pubspec.yaml'),'dependencies:\n  flutter:\n    sdk: flutter\n');
 assert.equal(mapSdkSource(root,'citizen_sdk','/fixture/current-sdk'),2);
 for(const member of ['', 'account']){const text=readFileSync(join(root,member,'pubspec.yaml'),'utf8');assert.match(text,/path: \/fixture\/current-sdk/);assert.doesNotMatch(text,/git:/);assert.match(text,/http: 1.6.0/);}
 assert.doesNotMatch(readFileSync(join(root,'assets/pubspec.yaml'),'utf8'),/citizen_sdk/);
 assert.throws(()=>mapSdkSource(root,'missing_sdk','/fixture/no'),/没有声明SDK/);
});

const hosted=(version='1.6.0',url='https://pub.dev')=>'  http:\n    dependency: "direct main"\n    description:\n      name: http\n      sha256: "synthetic-lock-record"\n      url: "'+url+'"\n    source: hosted\n    version: "'+version+'"\n';
const internal='  sdk_core:\n    dependency: transitive\n    description:\n      path: "../packages/sdk/core"\n      relative: true\n    source: path\n    version: "1.0.0"\n';
function packagesFixture(t){
 const work=mkdtempSync(join(tmpdir(),'citizen-packages-'));t.after(()=>rmSync(work,{recursive:true,force:true}));
 const project=join(work,'project'),source=join(work,'packages/sdk'),member=join(source,'core');
 mkdirSync(join(project,'.dart_tool'),{recursive:true});mkdirSync(member,{recursive:true});
 const file=join(project,'pubspec.lock'),before='packages:\n'+hosted()+'sdks:\n  dart: ">=3.8.0"\n';
 writeFileSync(file,before);
 const calls=[],environment={FLUTTER_ROOT:'/existing/flutter'};
 const resolve=(lock='packages:\n'+hosted()+internal,uri=pathToFileURL(member).href)=>{
  writeFileSync(file,lock);
  writeFileSync(join(project,'.dart_tool/package_config.json'),JSON.stringify({configVersion:2,packages:[{name:'sdk_core',rootUri:uri}]}));
 };
 return {work,project,source,file,before,calls,environment,resolve};
}
test('SDK拆包由官方离线解析补锁，原记录保留后再严格消费',async t=>{
 const f=packagesFixture(t);
 await preparePackages(f.project,{sources:[f.source],environment:f.environment,execute:async(command,args,cwd,capture,environment)=>{
  f.calls.push(args);assert.equal(command,'/existing/flutter/bin/flutter');assert.equal(cwd,f.project);assert.equal(environment,f.environment);
  if(f.calls.length===1)f.resolve();
 }});
 assert.deepEqual(f.calls,[['pub','get','--offline'],['pub','get','--offline','--enforce-lockfile']]);
 assert.match(readFileSync(f.file,'utf8'),/sdk_core:/);
});
for(const [name,change]of [
 ['版本漂移',()=>hosted('1.7.0')],['来源漂移',()=>hosted('1.6.0','https://other.example')],
 ['原记录删除',()=>internal],['新增第三方',()=>hosted()+hosted().replaceAll('http','another')],
])test('SDK补锁拒绝'+name,async t=>{
 const f=packagesFixture(t);let calls=0;
 await assert.rejects(preparePackages(f.project,{sources:[f.source],environment:f.environment,execute:async()=>{
  calls++;f.resolve('packages:\n'+change());
 }}),/原锁记录|非SDK内部包/);
 assert.equal(calls,1);
});
test('新增path包必须属于冻结SDK源码，不能由同名外部路径冒充',async t=>{
 const f=packagesFixture(t);let calls=0;
 await assert.rejects(preparePackages(f.project,{sources:[f.source],environment:f.environment,execute:async()=>{
  calls++;f.resolve(undefined,pathToFileURL(f.project).href);
 }}),/非SDK内部包/);assert.equal(calls,1);
});
test('已有SDK内部包和Pub空行规范化不会重新改锁',async t=>{
 const f=packagesFixture(t);f.resolve();let calls=0;
 await preparePackages(f.project,{sources:[f.source],environment:f.environment,execute:async()=>{
  calls++;if(calls===1)f.resolve('packages:\n'+hosted()+'\n'+internal);
 }});assert.equal(calls,2);
});
test('离线缺件或严格锁验收失败原样失败，不执行在线重试',async t=>{
 for(const stage of [1,2]){
  const f=packagesFixture(t),failure=Error('合成离线失败');let calls=0;
  await assert.rejects(preparePackages(f.project,{sources:[f.source],environment:f.environment,execute:async()=>{
   calls++;if(calls===stage)throw failure;f.resolve();
  }}),error=>error===failure);assert.equal(calls,stage);
 }
});
