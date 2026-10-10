#!/usr/bin/env node
// 公民App发布只消费GitHub自动化已完成的公开Run、Release与资产，不创建或派发自动化。
import {createHash} from 'node:crypto';

const product='citizenapp',repository='crcfrcn/citizenapp';
const targets=Object.freeze({
 ios:Object.freeze({workflow:'.github/workflows/release-ios.yml',manifest:'citizenapp-release-ios.json',
  binaries:Object.freeze(['citizenapp.ipa']),display:'iOS'}),
 android:Object.freeze({workflow:'.github/workflows/release-android.yml',manifest:'citizenapp-release-android.json',
  binaries:Object.freeze(['citizenapp.apk','citizenapp.aab']),display:'Android'}),
});
const fail=message=>{throw Error('公民App Publish：'+message);};
const sha=value=>typeof value==='string'&&/^[a-f0-9]{64}$/u.test(value);
const sourceSHA=value=>typeof value==='string'&&/^[a-f0-9]{40}$/u.test(value);
const positive=value=>Number.isSafeInteger(value)&&value>0;
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');

// 产品自行读取完整分页的公开运行与Release，不接受调用方裁剪的成功集合。
async function pages(path,field,request){
 const rows=[];
 for(let page=1;page<=10000;page++){
  const response=await request(path+'?per_page=100&page='+page);
  const values=field?response?.[field]:response;
  if(!Array.isArray(values)||values.length>100)fail('GitHub公开分页无效');
  rows.push(...values);if(values.length<100)return rows;
 }
 fail('GitHub公开分页未结束');
}
export async function preparePublication({platform,request}){
 if(!Object.hasOwn(targets,platform))fail('发布平台无效');
 if(typeof request!=='function')fail('GitHub公开读取能力缺失');
 const runs=await pages('actions/runs','workflow_runs',request),releases=await pages('releases',null,request);
 return verifyPublication({platform,runs,releases,
  readTag:tag=>request('git/ref/tags/'+encodeURIComponent(tag)),
  readAsset:async asset=>(await request(asset.url,{raw:true}))?.body});
}

// 发布候选必须来自本平台唯一保留的成功自动化；其它平台和未完成运行不参与选择。
async function verifyPublication({platform,runs,releases,readTag,readAsset}){
 const target=targets[platform];
 if(!target)fail('发布平台无效');
 if(!Array.isArray(runs)||!Array.isArray(releases)||typeof readTag!=='function'||typeof readAsset!=='function')
  fail('公开自动化输入无效');
 const owned=runs.filter(run=>run?.path===target.workflow&&run.head_branch==='main'
  &&run.event==='workflow_dispatch'&&run.repository?.full_name===repository);
 const success=owned.filter(run=>run.status==='completed'&&run.conclusion==='success');
 if(success.length!==1)fail('缺少唯一保留的成功自动化');
 const run=success[0];
 if(!positive(run.id)||!positive(run.run_attempt)||!positive(run.run_number)
  ||!sourceSHA(run.head_sha)||!Number.isFinite(Date.parse(run.created_at)))fail('成功自动化身份无效');
 const prefix=product+'-'+platform+'-v',suffix='-r'+run.id+'-a'+run.run_attempt;
 const matched=releases.filter(release=>typeof release?.tag_name==='string'
  &&release.tag_name.startsWith(prefix)&&release.tag_name.endsWith(suffix));
 if(matched.length!==1)fail('成功自动化缺少唯一正式Release');
 const release=matched[0],version=release.tag_name.slice(prefix.length,-suffix.length);
 if(!positive(release.id)||!/^\d+\.\d+\.\d+$/u.test(version)
  ||release.draft||release.prerelease||release.target_commitish!==run.head_sha
  ||!Array.isArray(release.assets))fail('正式Release身份无效');
 const tag=await readTag(release.tag_name);
 if(tag?.ref!=='refs/tags/'+release.tag_name||tag.object?.type!=='commit'
  ||tag.object.sha!==run.head_sha)fail('正式Tag与成功自动化提交不一致');
 const needed=[target.manifest,...target.binaries],assets=new Map();
 for(const name of needed){
  const found=release.assets.filter(asset=>asset?.name===name);
  if(found.length!==1)fail('正式资产缺失或重复：'+name);
  const asset=found[0];
  if(!positive(asset.id)||!positive(asset.size)||asset.state!=='uploaded'
    ||typeof asset.digest!=='string'||!asset.digest.startsWith('sha256:')
    ||!sha(asset.digest.slice(7)))fail('正式资产证明无效：'+name);
  let endpoint;try{endpoint=new URL(asset.url);}catch{fail('正式资产地址无效：'+name);}
  if(endpoint.protocol!=='https:'||endpoint.username||endpoint.password||endpoint.hash)
   fail('正式资产地址不是无凭据HTTPS：'+name);
  assets.set(name,asset);
 }
 const load=async(asset,{limit=asset.size,buffer=false}={})=>{
  const stream=await readAsset(asset);
  if(!stream||typeof stream[Symbol.asyncIterator]!=='function')fail('正式资产读取通道无效');
  const hash=createHash('sha256'),parts=[];let size=0;
  for await(const chunk of stream){
   if(!Buffer.isBuffer(chunk)&&!(chunk instanceof Uint8Array))fail('正式资产字节无效');
   size+=chunk.length;if(size>asset.size||size>limit)fail('正式资产超过声明大小');
   hash.update(chunk);if(buffer)parts.push(Buffer.from(chunk));
  }
  if(size!==asset.size||hash.digest('hex')!==asset.digest.slice(7))fail('正式资产回读与Release证明不一致');
  return buffer?Buffer.concat(parts):null;
 };
 const metadata=assets.get(target.manifest);
 const raw=await load(metadata,{limit:1024*1024,buffer:true});
 let manifest;try{manifest=JSON.parse(raw.toString('utf8'));}catch{fail('正式产物清单不是JSON');}
 if(manifest?.product_id!==product||manifest.version!==version
  ||manifest.github_run_number!==run.run_number||manifest.head_sha!==run.head_sha
  ||manifest.bundle_id!=='ios.citizenapp'||manifest.package_name!=='com.crcfrcn.citizenapp'
  ||!Array.isArray(manifest.assets)||manifest.assets.length!==target.binaries.length)
  fail('正式产物清单身份无效');
 const records=[];
 for(const name of target.binaries){
  const rows=manifest.assets.filter(value=>value?.asset_name===name);
  const asset=assets.get(name);
  if(rows.length!==1||rows[0].platform!==target.display||rows[0].asset_sha256!==asset.digest.slice(7))
   fail('正式产物清单与资产不一致');
  await load(asset);
  records.push({asset_id:asset.id,name,size:asset.size,sha256:asset.digest.slice(7)});
 }
 return {schema:1,product_id:product,platform,version,tag:release.tag_name,
  run_id:run.id,run_attempt:run.run_attempt,source_sha:run.head_sha,release_id:release.id,assets:records};
}

// 同文件回归只用合成GitHub公开回执与字节，不创建Tag、Release或商店交易。
if (process.env.NODE_TEST_CONTEXT&&process.argv.length===2&&process.argv[1]===import.meta.filename){
 const {test}=await import('node:test'),{default:assert}=await import('node:assert/strict');
 const {Readable}=await import('node:stream');
 const fixture=(platform='ios')=>{
  const target=targets[platform],head='a'.repeat(40),run={id:42,run_attempt:2,run_number:17,
   path:target.workflow,head_branch:'main',event:'workflow_dispatch',repository:{full_name:repository},
   status:'completed',conclusion:'success',head_sha:head,created_at:'2026-10-10T00:00:00Z'};
  const binaries=target.binaries.map((name,index)=>({name,body:Buffer.from('signed-'+name+'-'+index)}));
  const manifest={product_id:product,version:'1.2.3',github_run_number:17,head_sha:head,
   bundle_id:'ios.citizenapp',package_name:'com.crcfrcn.citizenapp',
   assets:binaries.map(value=>({platform:target.display,asset_name:value.name,asset_sha256:digest(value.body)}))};
  const all=[{name:target.manifest,body:Buffer.from(JSON.stringify(manifest))},...binaries];
  const assets=all.map((value,index)=>({id:index+1,name:value.name,size:value.body.length,
   state:'uploaded',digest:'sha256:'+digest(value.body),url:'https://api.example.invalid/assets/'+(index+1)}));
  const release={id:7,tag_name:product+'-'+platform+'-v1.2.3-r42-a2',target_commitish:head,
   draft:false,prerelease:false,assets};
  const body=new Map(all.map(value=>[value.name,value.body]));
  return {platform,runs:[run],releases:[release],readTag:async()=>({ref:'refs/tags/'+release.tag_name,
   object:{type:'commit',sha:head}}),readAsset:async asset=>Readable.from([body.get(asset.name)]),body};
 };
 test('只消费唯一成功自动化的正式产物并核对完整字节',async()=>{
  const input=fixture('ios'),result=await verifyPublication(input);
  assert.deepEqual({platform:result.platform,tag:result.tag,run_id:result.run_id,release_id:result.release_id,
   assets:result.assets.map(value=>value.name)},
   {platform:'ios',tag:input.releases[0].tag_name,run_id:42,release_id:7,assets:['citizenapp.ipa']});
  const android=await verifyPublication(fixture('android'));
  assert.deepEqual(android.assets.map(value=>value.name),['citizenapp.apk','citizenapp.aab']);
 });
 test('失败、重复、跨平台与漂移的自动化产物不能发布',async()=>{
  const base=fixture();
  await assert.rejects(verifyPublication({...base,runs:[]}),/唯一保留/);
  await assert.rejects(verifyPublication({...base,runs:[...base.runs,{...base.runs[0],id:43}]}),/唯一保留/);
  await assert.rejects(verifyPublication({...base,runs:[{...base.runs[0],path:targets.android.workflow}]}),/唯一保留/);
  await assert.rejects(verifyPublication({...base,releases:[{...base.releases[0],target_commitish:'b'.repeat(40)}]}),/身份/);
  await assert.rejects(verifyPublication({...base,readTag:async()=>null}),/Tag/);
  await assert.rejects(verifyPublication({...base,releases:[{...base.releases[0],assets:[]}]}),/资产/);
  await assert.rejects(verifyPublication({...base,releases:[{...base.releases[0],assets:base.releases[0].assets.map((asset,index)=>index?asset:{...asset,url:'http://api.example.invalid/asset'})}]}),/HTTPS/);
  await assert.rejects(verifyPublication({...base,readAsset:async()=>Readable.from([Buffer.from('changed')])}),/回读/);
  await assert.rejects(verifyPublication({...base,platform:'windows'}),/平台/);
 });
 test('公开发布入口自行读取完整分页且只发出读取请求',async()=>{
  const input=fixture(),calls=[];
  const request=async(path,options={})=>{
   assert.equal(options.method,undefined);calls.push(path);
   if(path.startsWith('actions/runs?'))return {workflow_runs:input.runs};
   if(path.startsWith('releases?'))return input.releases;
   if(path.startsWith('git/ref/tags/'))return input.readTag();
   const asset=input.releases[0].assets.find(value=>value.url===path);
   if(asset)return {body:await input.readAsset(asset)};
   throw Error('意外公开读取路径');
  };
  const result=await preparePublication({platform:'ios',request});
  assert.equal(result.release_id,7);assert.equal(result.assets[0].name,'citizenapp.ipa');
  assert.equal(calls.filter(path=>path.startsWith('actions/runs?')).length,1);
  assert.equal(calls.filter(path=>path.startsWith('releases?')).length,1);
  await assert.rejects(preparePublication({platform:'ios',request:async()=>({workflow_runs:'invalid'})}),/分页/);
 });
}
