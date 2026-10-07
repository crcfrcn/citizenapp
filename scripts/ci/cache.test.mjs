import assert from 'node:assert/strict';
import test from 'node:test';
import {
  cacheIdentity, cacheKeys, cachePathPlan, parseCacheKey, planCachePrune,
} from './cache.mjs';

const identity = cacheIdentity({
  repository: 'crcfrcn/citizenapp', product: 'citizenapp', platform: 'ios',
  architecture: 'arm64', component: 'citizenapp-ci-ios--ios',
  runnerOs: 'macos', runnerArch: 'arm64', toolchainFingerprint: 'a'.repeat(64),
});

// 合成检出证明测试不能创建固定根，入口初始化后根的身份及既有内容保持。
test('固定target根只由工作区入口准备，测试仅创建子目录',async()=>{
 const fs=await import('node:fs'),{join}=await import('node:path'),build=await import('../build.mjs');
 const area=fs.mkdtempSync(join(build.testRoot(),'fixed-target-owner-'));
 try{
  const scripts=join(area,'scripts');fs.mkdirSync(scripts);
  fs.copyFileSync(new URL('../build.mjs',import.meta.url),join(scripts,'build.mjs'));
  fs.copyFileSync(new URL('../flows.json',import.meta.url),join(scripts,'flows.json'));
  const fixture=await import((await import('node:url')).pathToFileURL(join(scripts,'build.mjs')));
  const target=join(area,'target'),platform=Object.keys(fixture.contract.platforms)[0];
  assert.throws(()=>fixture.temporaryRoot(platform,'test',null),/固定target根/u);assert.equal(fs.existsSync(target),false);
  assert.equal(fixture.prepareTargetRoot(),target);const before=fs.lstatSync(target);
  const marker=join(target,'existing');fs.writeFileSync(marker,'keep');
  fixture.prepareTargetRoot();const child=fixture.temporaryRoot(platform,'test',null);
  assert.equal(fs.lstatSync(target).ino,before.ino);assert.equal(fs.readFileSync(marker,'utf8'),'keep');
  assert.ok(child.startsWith(target+'/'));assert.equal(fs.lstatSync(child).isDirectory(),true);
  fs.rmSync(target,{recursive:true});fs.writeFileSync(target,'file');
  assert.throws(()=>fixture.prepareTargetRoot(),/固定target根/u);assert.throws(()=>fixture.temporaryRoot(platform,'test',null),/固定target根/u);
  fs.unlinkSync(target);fs.symlinkSync(scripts,target);
  assert.throws(()=>fixture.prepareTargetRoot(),/固定target根/u);assert.throws(()=>fixture.temporaryRoot(platform,'test',null),/固定target根/u);
 }finally{fs.rmSync(area,{recursive:true,force:true});}
});

// 子进程制造真实竞争目录/链接/文件，内建绑定改写只在该合成进程内，正式源码与其它测试不受影响。
test('CI并发创建工作目录允许已存在的普通目录，链接、文件和其它错误仍拒绝', async () => {
  const [{mkdtempSync,mkdirSync,rmSync,lstatSync}, {join}, {spawnSync}, build] = await Promise.all([
    import('node:fs'), import('node:path'), import('node:child_process'), import('../build.mjs'),
  ]);
  const area = mkdtempSync(join(build.testRoot(), 'ci-directory-race-'));
  const platform = Object.keys(build.contract.platforms).find(p => area.startsWith(build.productTarget(p) + '/'));
  const program = `import fs from 'node:fs';import {syncBuiltinESMExports} from 'node:module';
const [url,platform,path,kind,destination]=process.argv.slice(1),build=await import(url);
const exists=fs.existsSync,mkdir=fs.mkdirSync;let fired=false;
fs.existsSync=p=>{if(p!==path||fired)return exists(p);fired=true;
if(kind==='directory')mkdir(path);else if(kind==='link')fs.symlinkSync(destination,path);else if(kind==='file')fs.writeFileSync(path,'synthetic competitor');return false;};
fs.mkdirSync=(p,o)=>{if(p===path&&kind==='error'){const e=Error('synthetic denied');e.code='EPERM';throw e;}return mkdir(p,o);};
syncBuiltinESMExports();let result;try{build.temporaryRoot(platform,'test',path);result={ok:true,fired};}catch(e){result={ok:false,fired,error:e.message,code:e.code};}
process.stdout.write(JSON.stringify(result));`;
  try {
    const destination = join(area, 'destination');mkdirSync(destination);
    for (const kind of ['directory','link','file','error']) {
      const path = join(area, kind), run = spawnSync(process.execPath, ['--input-type=module','-e',program,
        new URL('../build.mjs',import.meta.url).href,platform,path,kind,destination], {encoding:'utf8'});
      assert.equal(run.status, 0, run.stderr);const result=JSON.parse(run.stdout);assert.equal(result.fired,true);
      assert.equal(result.ok,kind==='directory');
      if(kind==='directory'){assert.equal(lstatSync(path).isDirectory(),true);assert.equal(lstatSync(path).isSymbolicLink(),false);}
      else if(kind==='error')assert.equal(result.code,'EPERM');
      else assert.match(result.error,/经过链接或非目录/u);
    }
  } finally { rmSync(area,{recursive:true,force:true}); }
});

test('CitizenApp CI缓存身份、键和路径使用唯一共享实现', () => {
  const keys = cacheKeys(identity, '10', '2');
  assert.deepEqual(parseCacheKey(identity, keys.successKey), {
    toolchain: 'a'.repeat(16), state: 'success', runId: '10', attempt: '2',
  });
  const paths = cachePathPlan(identity, '/runner/temp', 'cargo-home\nflutter-build');
  assert.equal(paths.successPaths.length, 2);
  assert.ok(paths.successPaths.every(path => path.startsWith('/runner/temp/ci-cache/')));
});

test('CitizenApp CI缓存只保留成功与失败各自最新一份', () => {
  const make = (id, state, runId) => ({ id: String(id), ref: 'refs/heads/main',
    key: `${identity.baseKey}-${state}-${runId}-1` });
  const plan = planCachePrune(identity, [
    make(1, 'success', 1), make(2, 'success', 2),
    make(3, 'failure', 1), make(4, 'failure', 3),
  ], 'refs/heads/main');
  assert.deepEqual(plan.retain.map(value => value.id), ['2', '4']);
  assert.deepEqual(plan.remove.map(value => value.id), ['1', '3']);
});

test('CitizenApp CI缓存拒绝身份、指纹和相对路径越界', () => {
  assert.throws(() => cacheIdentity({ ...identity, repository: '../GMB' }), /身份越界/u);
  assert.throws(() => cacheIdentity({ ...identity, toolchainFingerprint: 'bad' }), /SHA-256/u);
  assert.throws(() => cachePathPlan(identity, '/runner/temp', '../outside'), /路径无效/u);
});


test('CitizenApp四个CI缓存命令从真实执行器进入且拒绝错流程错Job',async()=>{
  const {runWorkflow}=await import('../workflow.mjs'),{cacheCommands}=await import('./cache.mjs');
  for(const platform of ['ios','android'])for(const job of ['check',platform]) {
    const remoteJob=job==='check'?'stage_1':'flow',component='citizenapp-ci-'+platform+'--'+job;
    const identity={pipeline:'citizenapp.'+platform+'.ci',job};
    const environment={GITHUB_ACTIONS:'true',GITHUB_REPOSITORY:'crcfrcn/citizenapp',GITHUB_EVENT_NAME:'workflow_dispatch',
      GITHUB_WORKFLOW:identity.pipeline,GITHUB_JOB:remoteJob,GITHUB_REF:'refs/heads/main',GITHUB_RUN_ID:'10',GITHUB_RUN_ATTEMPT:'1',
      CI_CACHE_PRODUCT:'citizenapp',CI_CACHE_PLATFORM:platform,CI_CACHE_ARCHITECTURE:'arm64',CI_CACHE_COMPONENT:component,
      CI_CACHE_WORKFLOW:'citizenapp-'+platform,CI_CACHE_JOB:component,CI_CACHE_TOOLCHAIN_FINGERPRINT:'a'.repeat(64),
      RUNNER_OS:platform==='ios'&&job==='ios'?'macOS':'Linux',RUNNER_ARCH:'ARM64',RUNNER_TEMP:'/runner/temp',
      CI_CACHE_PATHS:'cargo-home',CI_CACHE_FINALS:''};
    const execute=env=>runWorkflow(identity,{},cacheCommands,{argumentsList:['sanitize'],environment:env});
    await execute(environment);
    for(const change of [
      {GITHUB_ACTIONS:'false'},{GITHUB_REPOSITORY:'crcfrcn/citizenchain'},{GITHUB_EVENT_NAME:'push'},
      {GITHUB_WORKFLOW:'citizenapp.'+platform+'.release'},{GITHUB_JOB:remoteJob==='flow'?'stage_1':'flow'},
      {CI_CACHE_PRODUCT:'citizensdk'},{CI_CACHE_PLATFORM:platform==='ios'?'android':'ios'},
      {CI_CACHE_COMPONENT:'other'},{CI_CACHE_JOB:'other'},{CI_CACHE_WORKFLOW:'other'},
    ])await assert.rejects(execute({...environment,...change}),/身份/u);
  }
});

// Apple正式目录名保留大小写；真实删除只作用于准确候选，越界路径继续拒绝。
test('CitizenApp最终候选支持Runner.app且保持路径边界和大小写',async()=>{
  const {mkdtempSync,mkdirSync,writeFileSync,existsSync,readlinkSync,rmSync}=await import('node:fs');
  const {testRoot:tmpdir}=await import('../build.mjs'),{join}=await import('node:path');
  const {sanitizeCacheFinals,wireCacheLinks}=await import('./cache.mjs');
  const temp=mkdtempSync(join(tmpdir(),'citizenapp-cache-finals-'));
  try {
    const plan=cachePathPlan(identity,temp,'cargo-home\nflutter-build');
    const upper=join(plan.root,'flutter-build/ios/iphoneos/Runner.app');
    const lower=join(plan.root,'flutter-build/ios/iphoneos/Neighbor.app');
    mkdirSync(upper,{recursive:true});mkdirSync(lower,{recursive:true});
    writeFileSync(join(upper,'Info.plist'),'candidate');writeFileSync(join(lower,'marker'),'retain');
    wireCacheLinks(identity,temp,'cargo-home\nflutter-build',join(temp,'workspace'),'ios-link=flutter-build/ios/iphoneos/Runner.app');
    assert.equal(readlinkSync(join(temp,'workspace/ios-link')),upper);
    sanitizeCacheFinals(identity,temp,'cargo-home\nflutter-build','flutter-build/ios/iphoneos/Runner.app');
    assert.equal(existsSync(upper),false);assert.equal(existsSync(lower),true);
    for(const value of ['../outside','/outside','flutter-build/../outside','flutter-build//Runner.app','flutter-build/./Runner.app','C:\\outside','flutter-build/Runner app']){
      assert.throws(()=>sanitizeCacheFinals(identity,temp,'flutter-build',value),/路径/u);
      assert.equal(existsSync(join(lower,'marker')),true);
    }
  }finally{rmSync(temp,{recursive:true,force:true});}
});
