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
  const {tmpdir}=await import('node:os'),{join}=await import('node:path');
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
