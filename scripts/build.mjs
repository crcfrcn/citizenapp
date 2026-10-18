#!/usr/bin/env node
import * as targetFs from 'node:fs';
import * as targetPath from 'node:path';
import * as targetUrl from 'node:url';
import * as targetCrypto from 'node:crypto';
import * as targetAsyncHooks from 'node:async_hooks';
import * as resourceFs from 'node:fs';
import * as resourceFsPromises from 'node:fs/promises';
import * as resourcePath from 'node:path';
import * as resourceUrl from 'node:url';
import * as resourceCrypto from 'node:crypto';
import * as resourceAsyncHooks from 'node:async_hooks';
import * as resourceOs from 'node:os';
import * as resourceZlib from 'node:zlib';
import * as resourceChild from 'node:child_process';
import * as resourceModuleBuiltin from 'node:module';
const directEntry = process.argv[1] === import.meta.filename && !process.execArgv.some(argument=>/^(?:-e|-p|--eval|--print)(?:=|$)/u.test(argument));
const inlineTestEntry = directEntry && Boolean(process.env.NODE_TEST_CONTEXT) && process.argv.length === 2;
// 回归保留原私有闭包与登记顺序，待模块全部初始化完成后统一登记。
const inlineTestRegistrations=[];
// 本产品独立拥有资源需求、工程准备与编译；公开回执仅提供验真资源，不提供执行命令。
import {spawn,spawnSync} from 'node:child_process';
import {AsyncLocalStorage} from 'node:async_hooks';
import {rmSync,rmdirSync,constants,fstatSync,readSync,chmodSync,closeSync,openSync,renameSync,readlinkSync,unlinkSync,copyFileSync,existsSync,lstatSync,mkdirSync,readFileSync,readdirSync,realpathSync,symlinkSync,writeFileSync} from 'node:fs';
import {basename,dirname,isAbsolute,join,parse,relative,resolve,sep} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash,randomBytes,randomUUID} from 'node:crypto';
import {createRequire} from 'node:module';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const requirePlatform=createRequire(import.meta.url);
function platformInputs(source){
 const ios=join(source,'ios/platform.mjs'),android=join(source,'android/platform.mjs');
 const found=[existsSync(ios),existsSync(android)];
 if(found[0]!==found[1])fail('平台输入清单不完整');
 if(!found[0])return {ios:{},android:{}};
 return {ios:requirePlatform(ios).platformFiles,android:requirePlatform(android).platformFiles};
}
// 本仓测试进程领取独立会话并传给子进程，正式Build仍使用平台固定根。
if(process.env.NODE_TEST_CONTEXT&&!process.env.CITIZENAPP_TEST_SESSION)process.env.CITIZENAPP_TEST_SESSION=randomUUID();
const testSession=process.env.NODE_TEST_CONTEXT&&/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/u.test(process.env.CITIZENAPP_TEST_SESSION||'')?process.env.CITIZENAPP_TEST_SESSION:null;
// 独立测试父进程及其子回归分别领取会话；不占用或清理正式平台现场。
const nodeVerificationSessions=new AsyncLocalStorage();
export const contract=Object.freeze({"schema": 1,"product_id": "citizenapp","entry": "scripts/build.mjs","platforms": {
    "ios": {
      "tools": [
        {
          "id": "cmake",
          "version": "3.31.6"
        },
        {
          "id": "git",
          "version": "2.54.0"
        },
        {
          "id": "node",
          "version": "25.2.1"
        },
        {
          "id": "flutter",
          "version": "3.47.2"
        },
        {
          "id": "cocoapods",
          "version": "1.17.0"
        },
        {
          "id": "xcode",
          "version": "27.0"
        },
        {
          "id": "posix",
          "version": "27.0"
        },
        {
          "id": "rust",
          "version": "1.97.1"
        },
        {
          "id": "python",
          "version": "3.14.3"
        },
        {
          "id": "bash",
          "version": "5.3.20"
        },
        {
          "id": "grep",
          "version": "3.12"
        },
        {
          "id": "sed",
          "version": "4.10"
        },
        {
          "id": "perl",
          "version": "5.42.3"
        }
      ],
      "locks": [
        {
          "ecosystem": "pub",
          "path": "pubspec.lock"
        }
      ],
      "completion": "device-install",
      "files": [
        "ios.app.zip"
      ]
    },
    "android": {
      "tools": [
        {
          "id": "cmake",
          "version": "3.31.6"
        },
        {
          "id": "git",
          "version": "2.54.0"
        },
        {
          "id": "node",
          "version": "25.2.1"
        },
        {
          "id": "flutter",
          "version": "3.47.2"
        },
        {
          "id": "java",
          "version": "17.0.20.1"
        },
        {
          "id": "gradle",
          "version": "9.1.0"
        },
        {
          "id": "android",
          "version": "37.0.1"
        },
        {
          "id": "android-sdk",
          "version": "22.0"
        },
        {
          "id": "android-ndk",
          "version": "28.2.13676358"
        },
        {
          "id": "posix",
          "version": "27.0"
        },
        {
          "id": "rust",
          "version": "1.97.1"
        },
        {
          "id": "python",
          "version": "3.14.3"
        },
        {
          "id": "xcode",
          "version": "27.0"
        },
        {
          "id": "bash",
          "version": "5.3.20"
        },
        {
          "id": "grep",
          "version": "3.12"
        },
        {
          "id": "sed",
          "version": "4.10"
        },
        {
          "id": "perl",
          "version": "5.42.3"
        }
      ],
      "locks": [
        {
          "ecosystem": "pub",
          "path": "pubspec.lock"
        }
      ],
      "completion": "device-install",
      "files": [
        "android.apk"
      ]
    }
  }});
const product=contract.product_id, prefix=product.toUpperCase();
// 产品版本规则、显示名和平台隔离只归本编译文件；YAML及控制台消费公开结果。
const buildPlatforms=Object.freeze({ios:Object.freeze({title:'iOS',initialVersion:'1.0.0'}),android:Object.freeze({title:'Android',initialVersion:'1.0.0'})});
export function checkedBuildVersion(version){
 if(typeof version!=='string'||!/^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$/u.test(version)||version.length>48)throw Error('公民App版本无效');return version;
}
export function nextBuildVersion(version){const parts=checkedBuildVersion(version).split('.');parts[2]=String(BigInt(parts[2])+1n);return checkedBuildVersion(parts.join('.'));}
export function buildDisplayName(platform,version){const item=buildPlatforms[platform];if(!item)throw Error('公民App平台无效');return '公民·'+item.title+'·v'+checkedBuildVersion(version);}
export function buildTaskName(platform,flow='编译'){const item=buildPlatforms[platform];if(!item||!['编译','塔塔自动化','发布'].includes(flow))throw Error('公民App任务名称无效');return '公民·'+flow+'·'+item.title;}
const incrementalPaths=Object.freeze(['source-view','work/cargo-target','work/gradle-project','work/flutter','work/flutter-gradle-plugin','work/citizensdk-work/cargo-target','work/citizensdk-work/gradle-project-cache','work/citizensdk-work/gradle-project/.gradle','work/citizensdk-work/gradle-native','dependencies/gradle/caches']);
function runtimeDocument(path){
 const info=lstatSync(path);if(!info.isFile()||info.isSymbolicLink()||info.nlink!==1||info.size>65536||realpathSync(path)!==path)throw Error('公民App运行记录身份无效');
 return JSON.parse(readFileSync(path,'utf8'));
}
export function incrementalIdentity(platform,sources=executions.getStore()?.sdkSelection?.sources||lockedSources()){
 const item=buildPlatforms[platform];if(!item)throw Error('公民App增量平台无效');
 // 此值只作编译缓存兼容坐标，不用于资源字节或源码全树复验。
 if(!Array.isArray(sources)||sources.length!==Object.keys(sdkRepositories).length||Object.entries(sdkRepositories).some(([name,url])=>sources.filter(source=>source?.name===name&&source.url===url&&/^[a-f0-9]{40}$/u.test(source.ref||'')).length!==1))fail('增量SDK提交身份无效');
 const locks=['pubspec.lock',...(platform==='ios'?['ios/Podfile.lock']:[])].map(name=>[name,readFileSync(join(root,name),'utf8')]);
 return createHash('sha256').update(JSON.stringify({product,platform,host:process.platform,arch:process.arch,source:root,tools:contract.platforms[platform].tools,locks,sources:sources.map(({name,url,ref})=>({name,url,ref})),mode:'release',recipe:2})).digest('hex');
}
function checkedRetainedEntry(work,name){
 const kind=name.replace(/\.(?:previous|pending)$/u,'');if(!['incremental','artifact'].includes(kind))throw Error('公民App保留目录类型无效');
 const directory=join(work,name),info=lstatSync(directory,{throwIfNoEntry:false});if(!info)return null;
 if(!info.isDirectory()||info.isSymbolicLink()||realpathSync(directory)!==directory)throw Error('公民App保留目录身份漂移');
 const record=runtimeDocument(join(directory,'receipt.json')),platform=Object.keys(buildPlatforms).find(value=>work===fixedWork('build/'+value));
 if(record.schema!==1||record.product_id!==product||record.platform!==platform)throw Error('公民App保留记录归属不符');
 if(kind==='incremental'&&(!/^[a-f0-9]{64}$/u.test(record.identity||'')||!Array.isArray(record.paths)||new Set(record.paths).size!==record.paths.length||record.paths.some(value=>!incrementalPaths.includes(value))))throw Error('公民App增量记录无效');
 if(kind==='artifact'&&(!Array.isArray(record.files)||!record.files.length||new Set(record.files.map(file=>file.name)).size!==record.files.length||record.files.some(file=>!Number.isSafeInteger(file.size)||file.size<1||typeof file.name!=='string'||file.name.includes('/')||file.name.includes('\\')||!file.name.startsWith(buildDisplayName(platform,record.version)+'.')||!/^[a-f0-9]{64}$/u.test(file.sha256||''))))throw Error('公民App产物记录无效');
 return record;
}
function rememberedAutomation(work){
 const file=join(work,'automation.json');if(!existsSync(file))return null;const record=runtimeDocument(file),platform=Object.keys(buildPlatforms).find(value=>work===fixedWork('build/'+value));
 if(record.schema!==1||record.product_id!==product||record.platform!==platform||record.repository!=='crcfrcn/citizenapp'||!Number.isSafeInteger(record.run_id)||record.run_id<1||!Number.isSafeInteger(record.run_attempt)||record.run_attempt<1||!/^[a-f0-9]{40}$/u.test(record.source_sha||''))throw Error('公民App成功自动化快照无效');
 checkedBuildVersion(record.version);return record;
}
function retainedBuildEntries(work){
 if(!Object.keys(buildPlatforms).some(platform=>work===fixedWork('build/'+platform)))return [];
 const names=['incremental','artifact'].filter(name=>checkedRetainedEntry(work,name));if(rememberedAutomation(work))names.push('automation.json');return names;
}
function localBuildVersion(platform,work){return rememberedAutomation(work)?.version||buildPlatforms[platform].initialVersion;}
function cacheExcluded(name){
 return ['.git','.active.json','.resource-active.json','.product-build.lock','.claim.lock','owner.json','_CodeSignature','embedded.mobileprovision','.npmrc','.netrc','.pypirc','.gitconfig','auth.json','credentials.json'].includes(name)||/^\.env(?:\.|$)/u.test(name)
  ||/\.(?:app|ipa|apk|aab|p12|pfx|mobileprovision|keychain(?:-db)?|jks|keystore|pem|key)$/iu.test(name)||/^(?:sign-stage|.*-signing)$/u.test(name);
}
function copyIncrementalTree(source,target){
 const info=lstatSync(source);if(info.isSymbolicLink())return;
 if(info.isDirectory()){
  mkdirSync(target,{recursive:true,mode:0o700});for(const name of readdirSync(source)){if(!cacheExcluded(name))copyIncrementalTree(join(source,name),join(target,name));}
 }else if(info.isFile()&&info.nlink===1){
  mkdirSync(dirname(target),{recursive:true,mode:0o700});copyFileSync(source,target,constants.COPYFILE_EXCL);chmodSync(target,info.mode&0o777);targetFs.utimesSync(target,info.atime,info.mtime);
 }else throw Error('公民App增量包含特殊文件');
}
function restoreIncremental(platform,work){
 const record=checkedRetainedEntry(work,'incremental');if(!record)return false;
 if(record.identity!==incrementalIdentity(platform)||record.source!==root||record.work!==work){process.stderr.write('本平台增量与当前工具链、锁或路径不兼容，由同一编译器重建\n');return false;}
 const data=join(work,'incremental/data');
 for(const name of record.paths){const target=join(work,name);if(existsSync(target))throw Error('公民App增量恢复目标已存在');copyIncrementalTree(join(data,...name.split('/')),target);}
 return true;
}
function replaceRetainedDirectory(work,name,pending,{retainPrevious=false}={}){
 const target=join(work,name),previous=join(work,name+'.previous');if(existsSync(previous))throw Error('公民App保留事务尚未收尾');
 const existing=checkedRetainedEntry(work,name);if(existing)renameSync(target,previous);
 try{renameSync(pending,target);}catch(error){if(existing)renameSync(previous,target);throw error;}
 if(existing&&!retainPrevious)rmSync(previous,{recursive:true});
}
function finishArtifactRetention(work,commit){
 const record=checkedRetainedEntry(work,'artifact');
 const current=join(work,'artifact'),previous=join(work,'artifact.previous');
 if(!record){
  const staged=checkedRetainedEntry(work,'artifact.pending');
  if(existsSync(previous)){const old=checkedRetainedEntry(work,'artifact.previous');if(commit||!staged?.pending||!staged.previous||old.pending)throw Error('公民App产物换位尚未验真');renameSync(previous,current);}
  if(staged){if(commit||!staged.pending)throw Error('公民App产物候选未完成');rmSync(join(work,'artifact.pending'),{recursive:true});}
  return;
 }
 if(commit)for(const item of record.files){const file=join(current,item.name),info=lstatSync(file);if(!info.isFile()||info.isSymbolicLink()||info.nlink!==1||realpathSync(file)!==file||info.size!==item.size||outputDigest(file)!==item.sha256)throw Error('公民App产物提交前变化');}
 if(!record.pending)return;
 if(typeof record.previous!=='boolean'||record.previous!==existsSync(previous))throw Error('公民App产物事务归属不符');
 if(record.previous){const old=checkedRetainedEntry(work,'artifact.previous');if(old.pending)throw Error('公民App上一产物归属不符');}
 if(!commit){rmSync(current,{recursive:true});if(record.previous)renameSync(previous,current);return;}
 const finalized={...record};delete finalized.pending;delete finalized.previous;
 const candidate=join(current,'receipt.json.pending');if(existsSync(candidate)){if(JSON.stringify(runtimeDocument(candidate))!==JSON.stringify(finalized))throw Error('公民App产物提交候选漂移');}else writeFileSync(candidate,JSON.stringify(finalized)+'\n',{flag:'wx',mode:0o600});renameSync(candidate,join(current,'receipt.json'));
 return record.previous;
}
// 事务标记只属于当前平台现场；阶段换位失败或崩溃都不能靠猜测删除另一集合。
function writeRetentionIntent(work,value){
 const file=join(work,'.build-retain.json'),candidate=file+'.pending';if(existsSync(candidate)){if(JSON.stringify(runtimeDocument(candidate))!==JSON.stringify(value))throw Error('公民App事务候选归属漂移');}else writeFileSync(candidate,JSON.stringify(value)+'\n',{flag:'wx',mode:0o600});
 try{renameSync(candidate,file);}finally{if(existsSync(candidate))unlinkSync(candidate);}
}
function clearRetentionPrevious(work){
 for(const name of ['artifact','incremental'])if(existsSync(join(work,name+'.previous'))){checkedRetainedEntry(work,name+'.previous');rmSync(join(work,name+'.previous'),{recursive:true});}
}
// 只由真实领取者在执行器及工具组退出后提交快照；嵌套执行器不清理或发布自己的现场。
function commitProductRetention(work){
 const marker=join(work,'.build-retain.json');if(!existsSync(marker)){finishArtifactRetention(work,false);return;}
 const intent=runtimeDocument(marker),platform=Object.keys(buildPlatforms).find(value=>work===fixedWork('build/'+value));
 if(intent.schema!==1||intent.product_id!==product||intent.platform!==platform||intent.work!==work)throw Error('公民App保留提交身份不符');checkedBuildVersion(intent.version);
 if(intent.phase!==undefined){
  if(!['prepared','committing'].includes(intent.phase)||typeof intent.cache_previous!=='boolean'||!/^[a-f0-9-]{36}$/u.test(intent.generation||''))throw Error('公民App保留事务阶段无效');
  const intentCandidate=marker+'.pending';if(existsSync(intentCandidate)){const value=runtimeDocument(intentCandidate);if(value.product_id!==product||value.platform!==platform||value.work!==work||value.generation!==intent.generation||!['prepared','committing'].includes(value.phase))throw Error('公民App事务候选归属漂移');unlinkSync(intentCandidate);}
  const cache=checkedRetainedEntry(work,'incremental'),swapped=cache?.generation===intent.generation;
  if(intent.phase==='committing'){
   if(!swapped||cache.source!==root||cache.work!==work||cache.identity!==incrementalIdentity(platform,intent.sdk_sources||lockedSources()))throw Error('公民App提交缓存归属变化');finishArtifactRetention(work,true);clearRetentionPrevious(work);unlinkSync(marker);return;
  }
  // prepared尚未形成提交点；只回滚这个generation的候选。
  const previous=join(work,'incremental.previous');
  if(existsSync(previous)&&(!intent.cache_previous||cache&&!swapped))throw Error('公民App上一增量归属变化');
  if(intent.cache_previous&&!cache&&!existsSync(previous))throw Error('公民App上一增量缺失');
  if(swapped)rmSync(join(work,'incremental'),{recursive:true});
  if(intent.cache_previous&&existsSync(previous)){checkedRetainedEntry(work,'incremental.previous');renameSync(previous,join(work,'incremental'));}
  finishArtifactRetention(work,false);
  const candidate=join(work,'incremental.pending');if(existsSync(candidate)){const record=runtimeDocument(join(candidate,'receipt.json'));if(record.generation!==intent.generation)throw Error('公民App增量候选归属变化');rmSync(candidate,{recursive:true});}
  unlinkSync(marker);return;
 }
 const pending=join(work,'incremental.pending');if(existsSync(pending))throw Error('公民App增量候选未清理');
 mkdirSync(pending,{mode:0o700});let replaced=false,committed=false,hadPrevious=false;
 try{
  const paths=incrementalPaths.filter(name=>existsSync(join(work,name)));
  for(const name of paths)copyIncrementalTree(join(work,name),join(pending,'data',...name.split('/')));
  const generation=randomUUID(),record={schema:1,product_id:product,platform,identity:incrementalIdentity(platform,intent.sdk_sources||lockedSources()),sdk_sources:intent.sdk_sources||lockedSources(),source:root,work,paths,generation};
  writeFileSync(join(pending,'receipt.json'),JSON.stringify(record)+'\n',{flag:'wx',mode:0o600});
  hadPrevious=Boolean(checkedRetainedEntry(work,'incremental'));const transaction={...intent,phase:'prepared',generation,cache_previous:hadPrevious};writeRetentionIntent(work,transaction);
  replaceRetainedDirectory(work,'incremental',pending,{retainPrevious:true});replaced=true;writeRetentionIntent(work,{...transaction,phase:'committing'});
  finishArtifactRetention(work,true);committed=true;clearRetentionPrevious(work);unlinkSync(marker);
 }catch(error){
  if(!committed){if(replaced){rmSync(join(work,'incremental'),{recursive:true});if(hadPrevious)renameSync(join(work,'incremental.previous'),join(work,'incremental'));}finishArtifactRetention(work,false);}
  if(existsSync(pending))rmSync(pending,{recursive:true});if(!committed)error.retentionRolledBack=true;throw error;
 }
}
function retainCompiledArtifacts(platform,work,version,files){
 const pending=join(work,'artifact.pending');if(existsSync(pending))throw Error('公民App产物候选未清理');mkdirSync(pending,{mode:0o700});
 try{
  const assets=files.map(({path,extension})=>{
   const info=lstatSync(path);if(!info.isFile()||info.isSymbolicLink()||info.nlink!==1||realpathSync(path)!==path||!info.size)throw Error('公民App产物不是独占普通文件');
   const name=buildDisplayName(platform,version)+extension,target=join(pending,name);if(existsSync(target))throw Error('公民App产物名称重复');copyFileSync(path,target);
   return {name,size:info.size,sha256:outputDigest(target)};
  });
  const record={schema:1,product_id:product,platform,version,sdk_selection:executions.getStore()?.sdkSelection,files:assets,pending:true,previous:Boolean(checkedRetainedEntry(work,'artifact'))};writeFileSync(join(pending,'receipt.json'),JSON.stringify(record)+'\n',{flag:'wx',mode:0o600});replaceRetainedDirectory(work,'artifact',pending,{retainPrevious:true});
  return assets.map(item=>({...item,path:join(work,'artifact',item.name)}));
 }catch(error){if(existsSync(pending))rmSync(pending,{recursive:true});throw error;}
}
// 新工程视图仍完整重建来源；仅对未变更输入恢复mtime，并迁回明确的编译器状态。
function mergeCompilerState(source,target){
 const before=lstatSync(source),after=lstatSync(target,{throwIfNoEntry:false});if(before.isSymbolicLink()||cacheExcluded(source.slice(source.lastIndexOf(sep)+1)))return;
 if(!after){copyIncrementalTree(source,target);return;}
 if(before.isDirectory()&&after.isDirectory()&&!after.isSymbolicLink())for(const name of readdirSync(source))mergeCompilerState(join(source,name),join(target,name));
}
function restoreViewIncremental(previous,current){
 const generated=new Set(['.dart_tool','.gradle','.kotlin']);
 for(const name of readdirSync(previous)){
  if(cacheExcluded(name))continue;const old=join(previous,name),next=join(current,name),before=lstatSync(old),after=lstatSync(next,{throwIfNoEntry:false});
  if(before.isDirectory()&&!before.isSymbolicLink()){
   if(!after&&generated.has(name))copyIncrementalTree(old,next);
   else if(after?.isDirectory()&&!after.isSymbolicLink()){if(generated.has(name))mergeCompilerState(old,next);restoreViewIncremental(old,next);}
  }else if(before.isFile()&&after?.isFile()&&!after.isSymbolicLink()&&before.size===after.size&&(before.mode&0o111)===(after.mode&0o111)&&readFileSync(old).equals(readFileSync(next)))targetFs.utimesSync(next,before.atime,before.mtime);
 }
}
// 编译流程自身拥有固定工作根；这里是原工作根实现正文。
const targetRuntime = await (async buildContract => {
const fs=targetFs;
const {dirname,join,resolve,parse,relative,sep}=targetPath;
const {fileURLToPath}=targetUrl;
const {randomUUID}=targetCrypto;
const {AsyncLocalStorage}=targetAsyncHooks;
// 本产品的固定工作根与占用生命周期；不访问邻仓或调用方临时目录。
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const product=buildContract.product_id;
const sessions=new AsyncLocalStorage();
const scopes=new Set(['build','test']);
const fail=message=>{throw Error(product+' target：'+message);};
function fixedWork(scope){
 const session=nodeVerificationSessions.getStore()||testSession;
 const testRoot=session?join(root,'target/test/sessions',session):null;
 if(scope==='test')return testRoot||join(root,'target/test');
 if(scope==='build')return join(root,'target/build');
 if(typeof scope==='string'&&scope.startsWith('build/')){
  const platform=scope.slice(6);if(Object.hasOwn(contract.platforms,platform))return testRoot?join(testRoot,'build',platform):join(root,'target/build',platform);
 }
 fail('工作根用途无效');
}
function isBuildWork(work){return typeof work==='string'&&Object.keys(contract.platforms).some(platform=>work===fixedWork('build/'+platform));}
function validWork(work){return work===fixedWork('test')||isBuildWork(work);}
function directory(path,create=false){
 let at=parse(path).root;
 for(const part of relative(at,path).split(sep)){
  at=join(at,part);
  if(create&&!fs.existsSync(at))try{fs.mkdirSync(at,{mode:0o700});}catch(error){if(error.code!=='EEXIST')throw error;}
  const value=fs.lstatSync(at);if(!value.isDirectory()||value.isSymbolicLink()||fs.realpathSync(at)!==at)fail('工作目录经过链接或非目录');
 }
 return fs.lstatSync(path);
}
function checkFixedWork(work,{create=false}={}){
 if(typeof work!=='string'||!validWork(work))fail('工作根只允许本产品target/build或target/test固定目录');
 directory(work,create);return work;
}
function checkScratchPath(path){
 if(typeof path!=='string'||resolve(path)!==path||![fixedWork('test'),...Object.keys(contract.platforms).map(platform=>fixedWork('build/'+platform))].some(work=>path===work||path.startsWith(work+sep)))fail('内部物化目录越出本产品固定工作根');
 directory(path);return path;
}
function fixedScratch(prefix){
 const path=resolve(prefix.replace(/-$/,''));checkScratchPath(dirname(path));
 fs.mkdirSync(path,{mode:0o700});return directory(path)&&path;
}
function assertTargetTopology(){
 const target=join(root,'target');if(!fs.existsSync(target))return;
 directory(target);
 for(const name of fs.readdirSync(target))if(!scopes.has(name))fail('target含非固定目录或根部生成文件：'+name);
 for(const name of fs.readdirSync(target))directory(join(target,name));
}
function regular(path){const value=fs.lstatSync(path);if(!value.isFile()||value.isSymbolicLink()||value.nlink!==1||value.size>65536)fail('任务标记不是准确普通文件');return value;}
function readOwner(work){const path=join(work,'.active.json');if(!fs.existsSync(path))return null;regular(path);let value;try{value=JSON.parse(fs.readFileSync(path,'utf8'));}catch{fail('任务标记损坏，禁止清场');}
 if(value.schema!==1||value.product_id!==product||value.work!==work||!Number.isSafeInteger(value.pid)||value.pid<1||typeof value.nonce!=='string'||!Array.isArray(value.groups)||!value.groups.every(pid=>Number.isSafeInteger(pid)&&pid>1))fail('任务标记身份无效');return value;
}
function alive(pid,group=false){try{process.kill(group&&process.platform!=='win32'?-pid:pid,0);return true;}catch(error){if(error.code==='ESRCH')return false;return true;}}
function writeOwner(owner){regular(join(owner.work,'.active.json'));fs.writeFileSync(join(owner.work,'.active.json'),JSON.stringify(owner)+'\n',{mode:0o600});}
function writable(path){const value=fs.lstatSync(path);if(value.isDirectory()&&!value.isSymbolicLink()){if(fs.realpathSync(path)!==path)fail('清理路径漂移');fs.chmodSync(path,value.mode|0o700);for(const name of fs.readdirSync(path))writable(join(path,name));}}
function removeTree(path){
 const state=fs.lstatSync(path);
 if(state.isSymbolicLink()){fs.unlinkSync(path);return;}
 if(state.isDirectory()){if(fs.realpathSync(path)!==path)fail('清理目录漂移');fs.chmodSync(path,state.mode|0o700);for(const name of fs.readdirSync(path))removeTree(join(path,name));fs.rmdirSync(path);return;}
 fs.unlinkSync(path);
}
// 清场由本产品确认资源供给与配方后代已经退出。
function assertSupplyExited(work){
 for(const name of ['.resource-active.json']){
  const file=join(work,name);if(!fs.existsSync(file))continue;regular(file);const record=JSON.parse(fs.readFileSync(file,'utf8'));
  if(!Number.isSafeInteger(record.pid)||record.pid<2||!Array.isArray(record.groups)||record.groups.some(pid=>!Number.isSafeInteger(pid)||pid<2))fail('资源退出记录无效');
  if((record.pid!==process.pid&&alive(record.pid))||record.groups.some(pid=>alive(pid,true)))fail('资源工具退出未确认');
 }
}
// Cargo原件需要保留大小写不同的同级名称；卷只归本轮已领取的平台工作根。
function vendorVolumeMatches(record,identity){
 return record?.imageDev===identity.imageDev&&record?.imageIno===identity.imageIno&&identity.imageNlink===1
  &&Number.isSafeInteger(record.mountDev)&&record.mountDev===identity.mountDev&&identity.mountDev!==identity.parentDev;
}
function vendorPaths(work){
 checkFixedWork(work);if(!['ios','android'].some(platform=>work===fixedWork('build/'+platform)))fail('临时卷不属于产品平台现场');
 return {image:join(work,'.vendor.sparseimage'),mount:join(work,'dependencies/citizen_sdk/cargo-vendor')};
}
function vendorIdentity(image,mount){
 const file=fs.lstatSync(image);if(!file.isFile()||file.isSymbolicLink()||fs.realpathSync(image)!==image)fail('临时卷映像身份漂移');
 return {imageDev:file.dev,imageIno:file.ino,imageNlink:file.nlink,mountDev:directory(mount).dev,parentDev:directory(dirname(mount)).dev};
}
function vendorCommand(args){return resourceChild.execFileSync('/usr/bin/hdiutil',args,{encoding:'utf8',timeout:120000,maxBuffer:1024*1024,env:{PATH:'/usr/bin:/bin',LANG:'en_US.UTF-8'}});}
function ensureVendorVolume(work){
 if(process.platform!=='darwin')return;
 const {image,mount}=vendorPaths(work),owner=readOwner(work);
 if(!owner||!alive(owner.pid)||owner.state!=='running')fail('临时卷缺少当前编译领取');
 directory(dirname(mount),true);directory(mount,true);
 if(owner.vendorVolume){
  if(!fs.existsSync(image)||!vendorVolumeMatches(owner.vendorVolume,vendorIdentity(image,mount)))fail('临时卷记录与实际挂载不符，保留现场');
  return;
 }
 if(fs.existsSync(image)||directory(mount).dev!==directory(dirname(mount)).dev||fs.readdirSync(mount).length)fail('临时卷现场已被占用');
 vendorCommand(['create','-size','8g','-type','SPARSE','-fs','Case-sensitive APFS','-volname','CitizenVendor','-nospotlight',image]);
 const initial=vendorIdentity(image,mount);
 // 先登记映像所有权，再挂载；中断时清理只会处理这一个已领取映像。
 writeOwner({...owner,vendorVolume:{imageDev:initial.imageDev,imageIno:initial.imageIno,mountDev:null}});
 vendorCommand(['attach',image,'-mountpoint',mount,'-nobrowse','-owners','on']);
 const identity=vendorIdentity(image,mount);if(identity.mountDev===identity.parentDev)fail('临时卷未实际挂载');
 writeOwner({...readOwner(work),vendorVolume:{imageDev:identity.imageDev,imageIno:identity.imageIno,mountDev:identity.mountDev}});
 const probe=join(mount,'.case');fs.mkdirSync(probe,{mode:0o700});
 try{fs.writeFileSync(join(probe,'README'),'upper',{flag:'wx'});fs.writeFileSync(join(probe,'Readme'),'mixed',{flag:'wx'});
  if(fs.readFileSync(join(probe,'README'),'utf8')!=='upper'||fs.readFileSync(join(probe,'Readme'),'utf8')!=='mixed')fail('临时卷不能保留准确大小写');
 }finally{removeTree(probe);}
}
function detachVendorVolume(work){
 const owner=readOwner(work);if(!owner?.vendorVolume)return;
 const {image,mount}=vendorPaths(work),identity=vendorIdentity(image,mount),record=owner.vendorVolume;
 if(record.imageDev!==identity.imageDev||record.imageIno!==identity.imageIno||identity.imageNlink!==1)fail('临时卷映像已替换，禁止清场');
 if(identity.mountDev!==identity.parentDev){
  // 挂载成功但登记中断时拒绝猜测归属；不卸载他人卷，也不强制终止使用者。
  if(!vendorVolumeMatches(record,identity))fail('临时卷挂载身份未确认，保留现场');
  vendorCommand(['detach',mount]);
  if(directory(mount).dev!==directory(dirname(mount)).dev)fail('临时卷卸载未确认，保留现场');
 }else if(record.mountDev!==null)fail('临时卷意外消失，保留现场');
 const current=readOwner(work);if(current?.nonce!==owner.nonce)fail('临时卷所属任务漂移');
 const next={...current};delete next.vendorVolume;writeOwner(next);
}
function empty(work,keep=[]){
 assertSupplyExited(work);detachVendorVolume(work);
 keep=[...new Set([...keep,...retainedBuildEntries(work)])];
 const before=directory(work);
 for(const name of fs.readdirSync(work)){if(keep.includes(name))continue;const path=join(work,name);removeTree(path);}
 const after=directory(work);if(before.dev!==after.dev||before.ino!==after.ino||fs.readdirSync(work).some(name=>!keep.includes(name)))fail('固定工作目录未完全清空或被替换');
}
function short(work,action){const path=isBuildWork(work)?join(dirname(work),'.claim-'+basename(work)):join(work,'.claim.lock');try{fs.mkdirSync(path,{mode:0o700});}catch(error){if(error.code!=='EEXIST')throw error;
 const record=join(path,'owner.json');let holder=null;
 if(fs.existsSync(record)){regular(record);try{holder=JSON.parse(fs.readFileSync(record,'utf8'));}catch{fail('领取锁损坏');}}
 const active=readOwner(work);
 if(holder?(holder.work!==work||!Number.isSafeInteger(holder.pid)||alive(holder.pid)):(Date.now()-fs.lstatSync(path).mtimeMs<30000))fail('固定工作目录正在领取或收尾');
 if(active&&(alive(active.pid)||active.groups.some(pid=>alive(pid,true))))fail('固定工作目录仍有活跃进程');
 writable(path);fs.rmSync(path,{recursive:true});fs.mkdirSync(path,{mode:0o700});}
 fs.writeFileSync(join(path,'owner.json'),JSON.stringify({pid:process.pid,work})+'\n',{flag:'wx',mode:0o600});
 const before=directory(path);try{return action();}finally{const after=directory(path);if(before.dev!==after.dev||before.ino!==after.ino)fail('领取锁漂移');fs.unlinkSync(join(path,'owner.json'));fs.rmdirSync(path);}}
function clearFixedWork(work){
 checkFixedWork(work);const session=sessions.getStore(),owner=readOwner(work);
 if(owner&&!(owner.state==='retained'&&owner.pid===process.pid)&&(!session||session.owner.work!==work||session.owner.nonce!==owner.nonce))fail('固定工作目录属于其他活跃任务');
 if(owner&&owner.groups.some(pid=>alive(pid,true)))fail('工具后代退出未确认，禁止清场');
 if(fs.existsSync(join(work,'.product-build.lock')))fail('产品编译进程仍持有守卫，禁止清场');
 const value=short(work,()=>{assertSupplyExited(work);commitProductRetention(work);empty(work,owner&&!(owner.state==='retained'&&owner.pid===process.pid)?['.active.json','.claim.lock']:['.claim.lock']);if(isBuildWork(work)&&fs.readdirSync(work).length===0)fs.rmdirSync(work);});return value;
}
function claimFixedWork(scope,{environment=process.env,retain=false,run_id}={}){
 const work=checkFixedWork(fixedWork(scope),{create:true}),current=sessions.getStore();
 if(current?.owner.work===work){if(run_id){const owner=readOwner(work);if(owner?.nonce!==current.owner.nonce||owner.run_id&&owner.run_id!==run_id)fail('编译任务编号不一致');owner.run_id=run_id;writeOwner(owner);current.owner=owner;}return {...current,nested:true};}
 const token=environment.PRODUCT_WORK_LEASE;
 return short(work,()=>{
  const previous=readOwner(work);
  if(previous){
   if(token===previous.nonce&&alive(previous.pid))return {owner:previous,nested:true,retain};
   if(previous.groups.some(pid=>alive(pid,true)))fail('上轮工具进程仍运行，禁止领取');
   if(previous.state==='retained')fail('结果尚未由调用方消费，禁止覆盖');
   if(alive(previous.pid))fail('固定工作目录已有活跃任务');
  }
  if(fs.existsSync(join(work,'.product-build.lock')))fail('产品守卫尚未释放，禁止覆盖');
  assertSupplyExited(work);commitProductRetention(work);
  empty(work,['.claim.lock']);
  const github=environment.GITHUB_ACTIONS==='true'&&environment.GITHUB_REPOSITORY==='crcfrcn/citizenapp'
    &&environment.GITHUB_REF==='refs/heads/main'&&environment.GITHUB_EVENT_NAME==='workflow_dispatch'
    &&/^[1-9][0-9]*$/u.test(environment.GITHUB_RUN_ID||'')&&/^[1-9][0-9]*$/u.test(environment.GITHUB_RUN_ATTEMPT||'')
    &&/^[a-f0-9]{40}$/u.test(environment.GITHUB_SHA||'')
    ?{repository:environment.GITHUB_REPOSITORY,run:environment.GITHUB_RUN_ID,attempt:environment.GITHUB_RUN_ATTEMPT,sha:environment.GITHUB_SHA}:null;
  const owner={schema:1,product_id:product,work,pid:process.pid,nonce:randomUUID(),groups:[],state:'running',
    ...(run_id?{run_id}:github?{github}:{})};
  fs.writeFileSync(join(work,'.active.json'),JSON.stringify(owner)+'\n',{flag:'wx',mode:0o600});return {owner,retain};
 });
}
function trackFixedProcess(work,pid){
 if(!pid||!validWork(work))return;
 const owner=readOwner(work);if(!owner)return;
 if(owner.pid!==process.pid&&!(alive(owner.pid)&&process.env.PRODUCT_WORK_LEASE===owner.nonce))fail('工具进程不能写入其他任务');
 if(!owner.groups.includes(pid)){owner.groups.push(pid);writeOwner(owner);}
}
function trackWorkProcess(pid){
 const session=sessions.getStore();if(!session||!pid)return;
 const owner=readOwner(session.owner.work);if(owner?.nonce!==session.owner.nonce)fail('任务所有权漂移');
 if(!owner.groups.includes(pid)){owner.groups.push(pid);writeOwner(owner);}
}
function workEnvironment(environment=process.env){
 const session=sessions.getStore();if(!session)return environment;
 const work=session.owner.work,result={...environment,PRODUCT_WORK_LEASE:session.owner.nonce};
 for(const [key,name]of Object.entries({TMPDIR:'tmp',TMP:'tmp',TEMP:'tmp',CARGO_TARGET_DIR:'cargo',CARGO_HOME:'dependencies/cargo-home',npm_config_cache:'dependencies/npm',PUB_CACHE:'dependencies/pub',GRADLE_USER_HOME:'dependencies/gradle',XDG_CACHE_HOME:'cache',XDG_CONFIG_HOME:'config',CLANG_MODULE_CACHE_PATH:'cache/clang',SWIFT_MODULECACHE_PATH:'cache/swift'})){
  const supplied=result[key];
  if(supplied!==undefined&&typeof supplied!=='string')fail('可写环境目录无效：'+key);
  const local=supplied&&(resolve(supplied)===work||resolve(supplied).startsWith(work+sep));
  result[key]=local?supplied:join(work,name);directory(resolve(result[key]),true);
 }
 return result;
}
function prepareSourceView(){
 const session=sessions.getStore();if(!session)fail('工程视图缺少固定任务');
 const project=join(session.owner.work,'source');
 if(fs.existsSync(project)){directory(project);return project;}
 const omitted=new Set(['target','node_modules','build','dist','.dart_tool','.gradle','.symlinks','Pods','ephemeral','.cache','cache','tasks','tsconfig.tsbuildinfo']);
 // 逐个直接子项复制，Node禁止把整个根直接cp到自身的子目录。
 fs.mkdirSync(project,{mode:0o700});
 const include=path=>!omitted.has(path.slice(path.lastIndexOf(sep)+1))&&!['tools/shared','tools/archives'].some(prefix=>relative(root,path).split(sep).join('/')===prefix);
 for(const name of fs.readdirSync(root)){const source=join(root,name);if(include(source))fs.cpSync(source,join(project,name),{recursive:true,verbatimSymlinks:true,filter:include});}
 return directory(project)&&project;
}
function retainWork(){const session=sessions.getStore();if(!session)fail('缺少当前任务');session.retain=true;}
function releaseFixedWork(session,{unsafe=false}={}){
 if(session.nested)return;
 const work=session.owner.work;
 const value=short(work,()=>{
  const owner=readOwner(work);if(owner?.nonce!==session.owner.nonce)fail('任务所有权漂移');
  const groups=owner.groups.filter(pid=>alive(pid,true));
  if(unsafe||groups.length){writeOwner({...owner,groups,state:'unsafe'});fail('工具后代退出未确认，保留守卫并禁止任务完成');}
  if(fs.existsSync(join(work,'.product-build.lock')))fail('产品编译守卫未释放，禁止完成');
  assertSupplyExited(work);
  try{commitProductRetention(work);}catch(error){
   // 仅在两份旧集合均已恢复后清本轮现场；未知事务或提交后的清理失败保留守卫。
   if(error.retentionRolledBack){empty(work,['.claim.lock']);if(isBuildWork(work)&&fs.readdirSync(work).length===0)fs.rmdirSync(work);}
   throw error;
  }
  if(session.retain){writeOwner({...owner,groups:[],state:'retained'});return;}
  if(fs.existsSync(join(work,'.product-build.lock')))fail('产品编译守卫未释放，禁止完成');
  empty(work,['.claim.lock']);if(isBuildWork(work)&&fs.readdirSync(work).length===0)fs.rmdirSync(work);
 });return value;
}
function withFixedWorkSync(scope,action,options={}){
 const session=claimFixedWork(scope,options);let unsafe=false;
 try{return sessions.run(session,()=>action(session.owner.work,session));}
 catch(error){unsafe=String(error?.message).includes('退出未确认');throw error;}
 finally{releaseFixedWork(session,{unsafe});}
}
async function withFixedWork(scope,action,options={}){
 const session=claimFixedWork(scope,options);let unsafe=false;
 try{return await sessions.run(session,()=>action(session.owner.work,session));}
 catch(error){unsafe=String(error?.message).includes('退出未确认');throw error;}
 finally{releaseFixedWork(session,{unsafe});}
}
// 调用方在消费结果且产品进程退出后，只能收尾这个产品的准确固定目录。
function finishFixedWork(work,{run_id}={}){
 if(run_id&&validWork(work)&&!fs.existsSync(work))return;
 checkFixedWork(work);
 const value=short(work,()=>{
  const owner=readOwner(work);if(run_id&&!owner)return;if(run_id&&owner.run_id!==run_id)fail('编译收尾任务编号不一致');if(owner){
   if((alive(owner.pid)&&!(owner.pid===process.pid&&owner.state==='retained'))||owner.groups.some(pid=>alive(pid,true)))fail('产品进程退出未确认');
  }
  if(fs.existsSync(join(work,'.product-build.lock')))fail('产品守卫尚未释放');
  if(run_id&&fs.existsSync(join(work,'build-result.json'))){regular(join(work,'build-result.json'));if(JSON.parse(fs.readFileSync(join(work,'build-result.json'),'utf8')).run_id!==run_id)fail('结果任务编号不符');}
  commitProductRetention(work);
  empty(work,['.claim.lock']);if(isBuildWork(work)&&fs.readdirSync(work).length===0)fs.rmdirSync(work);
 });return value;
}
function taskScope(work){checkFixedWork(work);if(work===fixedWork('test'))return 'test';const platform=Object.keys(contract.platforms).find(name=>work===fixedWork('build/'+name));if(!platform)fail('编译平台现场无效');return 'build/'+platform;}


// 同文件回归：普通导入和正式命令不注册测试。

if(inlineTestEntry)inlineTestRegistrations.push(async()=>{
 const {default:test}=await import('node:test');
 const {default:assert}=await import('node:assert/strict');
 const {execFileSync}=await import('node:child_process');
const isEmpty=()=>assert.deepEqual(fs.readdirSync(fixedWork('test')),[]);

// 各平台并发领取自己的工作根，正常退出后只删除本平台目录。
test('平台编译现场独立领取且结束删除',async()=>{
 const platforms=Object.keys(contract.platforms).slice(0,2),joined=[];let release;const both=new Promise(resolve=>{release=resolve;});
 await Promise.all(platforms.map(platform=>withFixedWork('build/'+platform,async work=>{
  fs.writeFileSync(join(work,'platform'),platform);joined.push(platform);if(joined.length===platforms.length)release();
  await both;assert.equal(fs.readFileSync(join(work,'platform'),'utf8'),platform);
 })));
 assert.deepEqual(joined.sort(),platforms.sort());for(const platform of platforms)assert.equal(fs.existsSync(fixedWork('build/'+platform)),false);
});

test('固定根拒绝任意任务目录、平台目录和外部临时根',()=>{
 for(const path of [join(root,'target'),join(root,'target/test/other'),join(root,'target/macos/test'),join(root,'target/build/run-123'),'/tmp/test'])assert.throws(()=>checkFixedWork(path),/固定目录/);
});
test('成功入口清空全部现场并保留固定目录',async()=>{
 await withFixedWork('test',async work=>{fs.mkdirSync(join(work,'dependencies'));fs.writeFileSync(join(work,'dependencies/fixture'),'input');fs.chmodSync(join(work,'dependencies'),0o555);});isEmpty();assertTargetTopology();
});
test('失败入口同样清空，不由测试代替被测入口清理',async()=>{
 await assert.rejects(withFixedWork('test',async work=>{fs.writeFileSync(join(work,'partial'),'partial');throw Error('synthetic failure');}),/synthetic failure/);isEmpty();
});
test('第二个真实进程不能领取活跃固定根或清理前一任务',async()=>{
 await withFixedWork('test',async work=>{
  fs.writeFileSync(join(work,'sentinel'),'owned');
  const module=join(import.meta.dirname,'build.mjs');
  assert.throws(()=>execFileSync(process.execPath,['--input-type=module','-e','import {withFixedWork} from '+JSON.stringify(module)+'; await withFixedWork("test",()=>{});'],{env:{PATH:process.env.PATH,NODE_TEST_CONTEXT:'child-v8',CITIZENAPP_TEST_SESSION:testSession},stdio:['ignore','pipe','pipe']}),/活跃任务/);
  assert.equal(fs.readFileSync(join(work,'sentinel'),'utf8'),'owned');
 });isEmpty();
});
test('活跃标记损坏时拒绝覆盖和清理',async()=>{
 await withFixedWork('test',async work=>{const path=join(work,'.active.json'),bytes=fs.readFileSync(path);fs.writeFileSync(path,'{}');try{assert.throws(()=>finishFixedWork(work),/身份无效/);}finally{fs.writeFileSync(path,bytes);}});isEmpty();
});
test('嵌套内部步骤使用同一个任务，外层结束才清空',async()=>{
 await withFixedWork('test',async work=>{await withFixedWork('test',async inner=>{assert.equal(inner,work);fs.writeFileSync(join(work,'nested'),'owned');});assert.equal(fs.readFileSync(join(work,'nested'),'utf8'),'owned');});isEmpty();
});

test('真实工具超时和取消后停止进程组并清场',async()=>{
 const {runResourceProcess}=await import('./build.mjs');
 const run=(work,signal,timeout)=>runResourceProcess(process.execPath,['-e','setInterval(()=>{},1000)'],{cwd:work,env:{PATH:process.env.PATH,PRODUCT_WORK_DIR:work},signal,timeout});
 for(const kind of ['timeout','cancel']){await assert.rejects(withFixedWork('test',async work=>{fs.writeFileSync(join(work,'partial'),'partial');const abort=new AbortController();const timer=kind==='cancel'?setTimeout(()=>abort.abort(Error('synthetic cancel')),50):null;try{await run(work,abort.signal,kind==='timeout'?50:10000);}finally{clearTimeout(timer);}}),/超时|取消|synthetic cancel|失败/);isEmpty();}
});

test('清场删除断开的链接且不跟随链接删除其它固定根',async()=>{
 await withFixedWork('test',async testWork=>{const keep=join(testWork,'keep');fs.writeFileSync(keep,'protected');await withFixedWork('build/'+Object.keys(contract.platforms)[0],async buildWork=>{fs.symlinkSync(keep,join(buildWork,'external'));fs.symlinkSync(join(buildWork,'missing'),join(buildWork,'broken'));});assert.equal(fs.readFileSync(keep,'utf8'),'protected');assert.equal(fs.existsSync(fixedWork('build/'+Object.keys(contract.platforms)[0])),false);});isEmpty();
});

test('实际任务被强制终止后下一轮在同一固定根恢复并清场',async()=>{
 const {spawn}=await import('node:child_process');
 const module=join(import.meta.dirname,'build.mjs');
 const code='import {withFixedWork} from '+JSON.stringify(module)+';import fs from "node:fs";await withFixedWork("test",async work=>{fs.writeFileSync(work+"/interrupted","partial");process.stdout.write("ready");await new Promise(()=>{setInterval(()=>{},1000);});});';
 const child=spawn(process.execPath,['--input-type=module','-e',code],{env:{PATH:process.env.PATH,NODE_TEST_CONTEXT:'child-v8',CITIZENAPP_TEST_SESSION:testSession},stdio:['ignore','pipe','pipe']});
 const finished=new Promise(resolve=>child.once('close',(code,signal)=>resolve({code,signal})));
 try{await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('任务领取超时')),5000);child.once('error',reject);child.stdout.once('data',()=>{clearTimeout(timer);resolve();});});child.kill('SIGKILL');assert.equal((await finished).signal,'SIGKILL');
  assert.equal(fs.readFileSync(join(fixedWork('test'),'interrupted'),'utf8'),'partial');
  await withFixedWork('test',async work=>{assert.equal(fs.existsSync(join(work,'interrupted')),false);fs.writeFileSync(join(work,'next'),'new task');});isEmpty();
 }finally{child.kill('SIGKILL');await finished;}
});

// 工程副本属于同一固定根；实际复制输入且不递归复制target。
test('真实工程视图进入当前固定根并在入口完成后清空',async()=>{
 const {prepareSourceView}=await import('./build.mjs');
 const before=fs.readFileSync(join(root,'scripts/build.mjs'));
 await withFixedWork('test',async work=>{
  const project=prepareSourceView();assert.equal(project,join(work,'source'));
  assert.deepEqual(fs.readFileSync(join(project,'scripts/build.mjs')),before);
  assert.equal(fs.existsSync(join(project,'target')),false);
  assert.equal(prepareSourceView(),project);
 });isEmpty();assert.deepEqual(fs.readFileSync(join(root,'scripts/build.mjs')),before);
});
});

// 本产品收尾拒绝异任务与仍存活的资源后代。
if(inlineTestEntry)inlineTestRegistrations.push(async()=>{
 const {test}=await import('node:test'),{default:assert}=await import('node:assert/strict'),{spawn}=await import('node:child_process');
 test('收尾必须匹配本轮编号并等待资源后代退出',async()=>{
  const work=fixedWork('test');await withFixedWork('test',()=>withFixedWork('test',async()=>{fs.writeFileSync(join(work,'keep'),'owned');},{run_id:'owned-run'}),{retain:true});
  assert.throws(()=>finishFixedWork(work,{run_id:'other-run'}),/任务编号/);assert.equal(fs.readFileSync(join(work,'keep'),'utf8'),'owned');
  const child=spawn(process.execPath,['-e','setInterval(()=>{},1000)'],{detached:true,stdio:'ignore'}),closed=new Promise(resolve=>child.once('close',resolve));
  const marker=join(work,'.resource-active.json');fs.writeFileSync(marker,JSON.stringify({pid:process.pid,groups:[child.pid]}));
  try{assert.throws(()=>finishFixedWork(work,{run_id:'owned-run'}),/退出未确认/);assert.equal(fs.readFileSync(join(work,'keep'),'utf8'),'owned');}
  finally{process.kill(-child.pid,'SIGTERM');await closed;fs.writeFileSync(marker,JSON.stringify({pid:process.pid,groups:[]}));finishFixedWork(work,{run_id:'owned-run'});}
  assert.deepEqual(fs.readdirSync(work),[]);
 });
});

return {ensureVendorVolume,vendorVolumeMatches,fixedWork,checkFixedWork,checkScratchPath,fixedScratch,assertTargetTopology,clearFixedWork,claimFixedWork,trackFixedProcess,trackWorkProcess,workEnvironment,prepareSourceView,retainWork,releaseFixedWork,withFixedWorkSync,withFixedWork,finishFixedWork,taskScope};
})(contract);
export const {ensureVendorVolume,vendorVolumeMatches,fixedWork,checkFixedWork,checkScratchPath,fixedScratch,assertTargetTopology,clearFixedWork,claimFixedWork,trackFixedProcess,trackWorkProcess,workEnvironment,prepareSourceView,retainWork,releaseFixedWork,withFixedWorkSync,withFixedWork,finishFixedWork,taskScope}=targetRuntime;
export const finishBuild=finishFixedWork;
const inside=(base,path)=>{const r=relative(base,path);return r===''||!isAbsolute(r)&&r!=='..'&&!r.startsWith('..'+sep);};
const fail=message=>{throw Error(product+' Build：'+message);};
export function checkWork(work) { return checkFixedWork(work); }

// 产品自己拥有target工作边界；测试与独立入口也不借用调用方的全局缓存。
export function productTarget(platform) {
 platformContract(platform);
 return join(root,'target');
}
// 工作区入口统一保证固定根存在；已存在的根只验真，不清空或重建。
export function prepareTargetRoot() {
 const directory=join(root,'target');
 if(realpathSync(root)!==root)fail('产品根经过链接');
 if(!lstatSync(directory,{throwIfNoEntry:false})){
  try{mkdirSync(directory,{mode:0o700});}catch(error){if(error.code!=='EEXIST')throw error;}
 }
 const info=lstatSync(directory);if(!info.isDirectory()||info.isSymbolicLink())fail('固定target根经过链接或非目录');
 return directory;
}
export function temporaryRoot(platform=Object.keys(contract.platforms)[0],scope='test',suppliedInput) {
 if(!['test','tmp','build','ci','release','publish'].includes(scope))fail('临时目录职责无效');
 platformContract(platform);const expected=fixedWork(scope==='test'?'test':'build/'+platform);
 if(suppliedInput!=null&&suppliedInput!==expected)fail('临时工作根必须是本产品固定目录');
 return checkFixedWork(expected,{create:true});
}
// 测试工作根由产品平台显式选择；没有平台参数时使用本仓首个平台。
export const testRoot=platform=>temporaryRoot(platform||Object.keys(contract.platforms)[0],'test');
// 编译流程自身拥有资源配方与供给；这里是原资源实现正文。
const resourceRuntime = await (async (buildContract,buildTestRoot) => {
const {AsyncLocalStorage}=resourceAsyncHooks;
const {writeFileSync:writeGroupRecord,existsSync,readFileSync,constants}=resourceFs;
const {createHash,randomUUID}=resourceCrypto;
const {lstat,realpath,readdir,readlink,symlink,copyFile,cp,readFile,writeFile,mkdir,mkdtemp,rename,rm:removeResourcePath,chmod,open}=resourceFsPromises;
const {dirname,join,resolve,relative,isAbsolute,sep,parse,win32,posix}=resourcePath;
const {fileURLToPath,pathToFileURL}=resourceUrl;
const {homedir}=resourceOs;
const {gunzipSync,createInflateRaw}=resourceZlib;
const {spawn}=resourceChild;
const {createRequire}=resourceModuleBuiltin;
// 产品资源阶段按本仓原始锁取得并物化输入。
const supplyGroups=new Map();
const resourceSupplies=new AsyncLocalStorage();
const exec=runResourceProcess,execute=exec;
// 工具返回只在主进程和整组后代退出后完成；未确认的输入目录禁止后续清理或改权限。
const retainedResourceRoots=new Set();
function retainedResourcePath(path) {
 const value=resolve(String(path));
 return [...retainedResourceRoots].some(root=>value===root||value.startsWith(root+sep)||root.startsWith(value+sep));
}
async function rm(path,options) {
 if(retainedResourcePath(path))throw Error('资源工具退出未确认，保留工作目录');
 return removeResourcePath(path,options);
}
function runResourceProcess(command,args,{signal,maxBuffer=8*1024**2,timeout=3600000,encoding='utf8',quietOutput=false,...options}={}) {


 signal?.throwIfAborted();
 if(!Number.isSafeInteger(maxBuffer)||maxBuffer<=0||!Number.isSafeInteger(timeout)||timeout<=0)throw Error('资源进程边界参数无效');
 return new Promise((ok,reject)=>{
  const child=spawn(command,args,{...options,env:workEnvironment(options.env),detached:process.platform!=='win32',stdio:['ignore','pipe','pipe']});
  trackWorkProcess(child.pid);
  const supply=resourceSupplies.getStore(),groups=supply?.work?(supplyGroups.get(supply.work)||new Set()):null;
  const record=()=>{if(groups)writeGroupRecord(join(supply.work,'.resource-active.json'),JSON.stringify({pid:process.pid,groups:[...groups]})+'\n');};
  if(groups&&Number.isSafeInteger(child.pid)){supplyGroups.set(supply.work,groups);groups.add(child.pid);record();}
  const output=[],errors=[];let bytes=0,done=false,closed=false,failure=null,probe=null,force=null,limit=null;
  const groupExists=()=>{
   if(process.platform==='win32')return !closed;
   if(!child.pid)return false;
   try{process.kill(-child.pid,0);return true;}catch(error){if(error.code==='ESRCH')return false;return true;}
  };
  const stop=hard=>{
   if(!child.pid)return;
   // 进程组已接收信号时立即返回，禁止同轮再次向组内主进程发送相同信号。
   if(process.platform!=='win32')try{process.kill(-child.pid,hard?'SIGKILL':'SIGTERM');return;}catch(error){if(error.code!=='ESRCH'){failure=Error('资源工具取消无法确认');return;}}
   if(!closed)try{child.kill(hard?'SIGKILL':'SIGTERM');}catch{failure=Error('资源工具取消无法确认');}
  };
  const finish=(error,result)=>{
   if(done)return;done=true;if(groups&&closed&&!groupExists()){groups.delete(child.pid);record();}clearTimeout(timer);clearTimeout(force);clearTimeout(limit);clearTimeout(probe);signal?.removeEventListener('abort',cancel);
   error?reject(error):ok(result);
  };
  const retain=()=>{
   for(const path of [options.cwd,options.env?.PRODUCT_WORK_DIR])if(typeof path==='string'&&isAbsolute(path))retainedResourceRoots.add(resolve(path));
   finish(Error('资源工具退出未确认，保留工作目录'));
  };
  const confirm=()=>{
   if(done)return;
   if(closed&&!groupExists()) {
    const stdout=Buffer.concat(output),stderr=Buffer.concat(errors);
    finish(failure,{stdout:encoding==='buffer'?stdout:stdout.toString(encoding),stderr:encoding==='buffer'?stderr:stderr.toString(encoding)});return;
   }
   probe=setTimeout(confirm,50);
  };
  const requestStop=error=>{
   if(done||force!==null)return;failure=error;stop(false);
   force=setTimeout(()=>stop(true),8000);limit=setTimeout(retain,12000);
   if(probe===null)confirm();
  };
  const cancel=()=>requestStop(signal.reason instanceof Error?signal.reason:Error('资源进程已取消'));
  const timer=setTimeout(()=>requestStop(Error('资源进程超时')),timeout);
  signal?.addEventListener('abort',cancel,{once:true});if(signal?.aborted)cancel();
  for(const [stream,parts]of [[child.stdout,output],[child.stderr,errors]])stream.on('data',chunk=>{
   if(done)return;bytes+=chunk.length;
   if(bytes>maxBuffer){requestStop(Error('资源进程输出超限'));return;}
   parts.push(chunk);if(!quietOutput)process.stderr.write(chunk);
  });
  child.once('error',()=>{if(!child.pid){closed=true;finish(Error('资源工具无法启动'));}else requestStop(Error('资源工具进程错误'));});
  child.once('close',(code,termination)=>{
   closed=true;
   if(!failure&&(code!==0||termination))failure=Error('资源工具失败');
   if(groupExists())requestStop(failure||Error('资源工具后代未结束'));
   if(probe===null)confirm();
  });
 });
}
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const fail=message=>{throw Error('产品资源：'+message);};
const safePath=value=>typeof value==='string'&&value.length>0&&!isAbsolute(value)&&!/[\\\x00-\x1f]/u.test(value)&&value.split('/').every(x=>x&&x!=='.'&&x!=='..');
const inside=(base,path)=>path.startsWith(base+sep);
const stat=async path=>lstat(path).catch(e=>{if(e.code==='ENOENT')return null;throw e;});
async function regular(path){const s=await lstat(path);if(!s.isFile()||s.isSymbolicLink()||await realpath(path)!==path)fail('非独占普通文件：'+path);return s;}
async function directory(path,create=false){if(!isAbsolute(path)||resolve(path)!==path||path===parse(path).root)fail('目录不是准确绝对路径');let at=parse(path).root;for(const name of relative(at,path).split(sep)){at=join(at,name);if(create&&!await stat(at))await mkdir(at,{mode:0o700}).catch(e=>{if(e.code!=='EEXIST')throw e;});const s=await lstat(at);if(!s.isDirectory()||s.isSymbolicLink()||await realpath(at)!==at)fail('目录经过链接或特殊项：'+at);}return path;}
// 普通资源清单保持独占文件要求；工具内部硬链接只由同一扫描器的私有验真现场核对。
// 文件枚举仅服务物化及Cargo原生vendor元数据，不作为资源复验门禁。
async function inventory(base,path=base){
 const files=[];
 for(const name of await readdir(path)){const file=join(path,name),s=await lstat(file),key=relative(base,file);
  if(s.isDirectory())files.push({path:key,directory:true},...await inventory(base,file));
  else if(s.isSymbolicLink())files.push({path:key,target:relative(base,await realpath(file))});
  else if(s.isFile())files.push({path:key,sha256:hash(await readFile(file)),executable:Boolean(s.mode&0o111)});
 }
 return files;
}


async function permissions(path,writable){
 if(retainedResourcePath(path))throw Error('资源工具退出未确认，保留工作目录');const s=await lstat(path);if(s.isSymbolicLink())return;if(s.isDirectory()){if(writable)await chmod(path,0o700);for(const name of await readdir(path))await permissions(join(path,name),writable);if(!writable)await chmod(path,0o555);}else await chmod(path,writable?0o600:s.mode&0o111?0o555:0o444);}
function checkedURL(input){const url=new URL(input);if(url.protocol!=='https:'||url.username||url.password||url.hash)fail('来源必须是无凭据HTTPS');return url.href;}


// 不持下载锁。每个候选独占生成，提交使用同对象短锁与排他重命名，竞争者核验同一字节。
// 候选下载、解包和编译归本产品当前target现场；永久原件只在验真提交后接收。
// 公开任务入口拥有固定根；资源候选可在该根内的私有子目录生成。
async function resourceWork(work){
 const owner=await import('./build.mjs'),path=work||owner.temporaryRoot(undefined,'tmp');
 const base=join(root,'target');if(!inside(base,path)||!['build','test'].includes(relative(base,path).split(sep)[0]))fail('资源候选必须位于本产品target工作目录');
 await directory(path);return directory(join(path,'resource-pending'),true);
}
// 下载诊断只含固定阶段、声明工具名、来源主机、字节数及安全码；不输出URL路径/查询、错误正文或凭据。
function downloadDiagnostic(record){
 try{const receive=resourceSupplies.getStore()?.downloadDiagnostic;if(receive)receive(record);else process.stderr.write('资源下载诊断：'+JSON.stringify(record)+'\n');}catch{}
}
async function acquireArchive(entry,{store,work,offline=false,fetcher=fetch,signal,maxBytes=4*1024**3,toolId='dependency'}={}){
 let bytes=0,stage='prepare',host='unknown',status;
 const tool=[...toolDefinitions.map(value=>value.id),'dependency','parser'].includes(toolId)?toolId:'dependency';
 try{

 const url=checkedURL(entry.url);await directory(store,true);const coordinate=hash(JSON.stringify([url,entry.sha256||entry.integrity]));const target=join(store,coordinate+'.blob');
 const check=async path=>{const info=await regular(path);if(!info.size||info.size>maxBytes)fail('原件大小超限');return path;};
 if(await stat(target))return check(target);


 host=new URL(url).hostname;
 if(offline)fail('离线缺少锁定资源：'+url);signal?.throwIfAborted();let response,current=url;
 for(let i=0;i<=5;i++){stage='request';host=new URL(current).hostname;downloadDiagnostic({stage,tool,host,received_bytes:bytes,code:'none'});response=await fetcher(current,{redirect:'manual',headers:{'accept-encoding':'identity'},signal});if([301,302,303,307,308].includes(response.status)){await response.body?.cancel();if(i===5)fail('来源重定向超限');current=checkedURL(new URL(response.headers.get('location'),current).href);continue;}break;}
 stage='response';status=response?.status;
 if(!response?.ok||!response.body)fail('来源获取失败：'+url);const length=Number(response.headers.get('content-length'));if(length>maxBytes)fail('来源声明超限');
 // Fetch会解码压缩正文，Content-Length仍是传输长度；仅无编码或identity时与正文严格等长。
 // 每跳请求identity；来源仍返回压缩内容时，声明上限和解码后实际字节上限继续分别约束。
 const encoding=(response.headers.get('content-encoding')||'').trim().toLowerCase(),identity=!encoding||encoding==='identity';
 const temporary=join(await resourceWork(work),'.'+coordinate+'.'+randomUUID()+'.pending'),h=await open(temporary,'wx',0o600);
 stage='body';try{for await(const chunk of response.body){signal?.throwIfAborted();bytes+=chunk.length;if(bytes>maxBytes)fail('来源数据超限');let offset=0;while(offset<chunk.length){const n=await h.write(chunk,offset,chunk.length-offset);if(!n.bytesWritten)fail('原件写入中断');offset+=n.bytesWritten;}}if(!bytes)fail('来源数据为空');if(identity&&length&&length!==bytes)fail('来源数据不完整');await h.sync();await h.close();signal?.throwIfAborted();stage='commit';await chmod(temporary,0o444);await commitCandidate(temporary,target,{signal,});return await check(target);}finally{await h.close().catch(()=>{});await rm(temporary,{force:true});await response.body?.cancel().catch(()=>{});}
 }catch(error){downloadDiagnostic({stage,tool,host,received_bytes:bytes,code:safeDiagnosticCode(error,{status,aborted:signal?.aborted})});throw error;}
}
async function downloadTool(entry,target,options){const archive=await acquireArchive(entry,{...options,store:options.store||dirname(target)});await copyFile(archive,target,constants.COPYFILE_EXCL);}
// 解包先解析全部成员并验证闭包，之后才写入；链接不得指向归档外部或成为文件父目录。
// 在本轮独占候选内逐目录验证真实文件系统的名称表示能力；原件名称与字节均不改写。
async function verifyArchiveNames(destination,paths,signal){
 const children=new Map();
 for(const path of paths){
  if(!safePath(path))fail('归档成员越界');
  const parts=path.split('/');let parent='';
  for(const name of parts){if(!children.has(parent))children.set(parent,new Set());children.get(parent).add(name);parent=parent?parent+'/'+name:name;}
 }
 const probe=await fixedScratch(join(destination,'.archive-names-')),owner=await lstat(probe);
 try{
  let number=0;
  for(const names of children.values()){
   signal?.throwIfAborted();const group=join(probe,String(number++));await mkdir(group);
   for(const name of names){
    signal?.throwIfAborted();
    try{await writeFile(join(group,name),'',{flag:'wx',mode:0o600});}
    catch(error){if(error.code==='EEXIST')fail('原件名称在当前工作文件系统发生大小写或Unicode冲突');throw error;}
   }
   const actual=await readdir(group);
   if(actual.length!==names.size||actual.some(name=>!names.has(name)))fail('当前工作文件系统不能保留原件准确名称');
   await rm(group,{recursive:true});
  }
 }finally{
  const current=await lstat(probe);if(current.dev!==owner.dev||current.ino!==owner.ino)fail('原件名称探测现场归属漂移');
  await rm(probe,{recursive:true});
 }
}
// 只按已确认文件句柄的位置读取有界片段；偏移使用安全整数，不把大归档整包装入内存。
async function archiveRange(handle,fileSize,offset,length,signal){
 signal?.throwIfAborted();
 if(![fileSize,offset,length].every(Number.isSafeInteger)||offset<0||length<0||length>256*1024||offset+length>fileSize)fail('归档读取越界');
 const bytes=Buffer.alloc(length);let read=0;
 while(read<length){signal?.throwIfAborted();const value=await handle.read(bytes,read,length-read,offset+read);if(!value.bytesRead)fail('归档内容截断');read+=value.bytesRead;}
 return bytes;
}
async function archiveHead(input,signal){
 const info=await regular(input),handle=await open(input,constants.O_RDONLY|constants.O_NOFOLLOW);
 try{const actual=await handle.stat();if(actual.dev!==info.dev||actual.ino!==info.ino||actual.size!==info.size)fail('归档读取身份漂移');return await archiveRange(handle,info.size,0,Math.min(2,info.size),signal);}
 finally{await handle.close();}
}
function selectedArchiveEntries(entries,prefix){
 const selected=entries.filter(e=>!prefix||e.path===prefix||e.path.startsWith(prefix+'/')).map(e=>({...e,path:prefix?e.path.slice(prefix.length).replace(/^\//u,''):e.path})).filter(e=>e.path);
 if(!selected.length)fail('归档根缺失');const table=new Map(selected.map(e=>[e.path,e])),directories=new Set();
 for(const entry of selected){
  let parent=dirname(entry.path);while(parent!=='.'){if(table.has(parent)&&table.get(parent).type!=='directory')fail('归档父目录不是目录');directories.add(parent);parent=dirname(parent);}
 }
 // 只在归档成员图内逐组件解析：Current等目录链接可前向引用，不能借链逃出根。
 // 每条解析链最多展开40个符号链接，计入起始链接；活动链检测循环，校验完成前不创建成员。
 function resolveTarget(base,target,active,budget){
  if(typeof target!=='string'||!target||isAbsolute(target)||/[\\\x00-\x1f]/u.test(target))fail('归档链接越界或缺失');
  let parts=base.slice();
  for(const component of target.split('/')){
   if(!component||component==='.')continue;
   const parent=parts.join('/'),parentEntry=table.get(parent);
   if(parent&&parentEntry?.type!=='directory'&&!directories.has(parent))fail('归档链接父目录不是目录');
   if(component==='..'){if(!parts.length)fail('归档链接越界或缺失');parts.pop();continue;}
   const path=[...parts,component].join('/'),entry=table.get(path);
   if(entry?.type==='symlink'){
    if(active.has(path)||++budget.hops>40)fail('归档链接循环或跳转超限');
    active.add(path);parts=resolveTarget(parts,entry.target,active,budget);active.delete(path);
   }else{
    if(!entry&&!directories.has(path))fail('归档链接越界或缺失');parts.push(component);
   }
  }
  const path=parts.join('/');if(!safePath(path)||!table.has(path))fail('归档链接越界或缺失');return parts;
 }
 for(const entry of selected){
  if(entry.type==='symlink')entry.resolved=resolveTarget(posix.dirname(entry.path)==='.'?[]:posix.dirname(entry.path).split('/'),entry.target,new Set([entry.path]),{hops:1}).join('/');
  else if(entry.type==='hardlink'){
   const target=prefix?entry.target.replace(new RegExp('^'+prefix+'/'),''):entry.target;
   if(!safePath(target)||!table.has(target))fail('归档链接越界或缺失');entry.resolved=target;
   if(table.get(target).type!=='file')fail('硬链接目标不是普通文件');
  }
 }
 return selected;
}
async function materializeArchiveEntries(destination,selected,{signal,write}){
 const table=new Map(selected.map(entry=>[entry.path,entry]));
 await mkdir(destination,{mode:0o700});
 try{
  await verifyArchiveNames(destination,selected.map(entry=>entry.path),signal);
  for(const entry of selected.filter(x=>['file','directory'].includes(x.type))){
   signal?.throwIfAborted();const file=join(destination,entry.path);await mkdir(dirname(file),{recursive:true,mode:0o700});
   if(entry.type==='directory')await mkdir(file,{recursive:true,mode:0o700});else await write(file,entry);
  }
  for(const entry of selected.filter(x=>['symlink','hardlink'].includes(x.type))){
   signal?.throwIfAborted();const file=join(destination,entry.path);await mkdir(dirname(file),{recursive:true});
   if(entry.type==='hardlink'){if(table.get(entry.resolved).type!=='file')fail('硬链接目标不是普通文件');await copyFile(join(destination,entry.resolved),file,constants.COPYFILE_EXCL);}
   else await symlink(entry.target,file);
  }
  return destination;
 }catch(error){await permissions(destination,true);await rm(destination,{recursive:true});throw error;}
}
async function zipEntryBytes(handle,fileSize,entry,signal,consume){
 const {Readable}=await import('node:stream'),{pipeline}=await import('node:stream/promises');let length=0;
 async function* chunks(){for(let position=0;position<entry.compressed;){const count=Math.min(64*1024,entry.compressed-position);yield await archiveRange(handle,fileSize,entry.start+position,count,signal);position+=count;}}
 const sink=async source=>{for await(const chunk of source){signal?.throwIfAborted();length+=chunk.length;if(length>entry.size)fail('ZIP长度不符');if(consume)await consume(chunk);}if(length!==entry.size)fail('ZIP长度不符');};
 const stages=[Readable.from(chunks())];if(entry.method===8)stages.push(createInflateRaw());stages.push(sink);
 await pipeline(...stages,...(signal?[{signal}]:[]));
}
// ZIP先读取中央目录、校验全部路径与链接闭包；正文逐成员解码，不累计全部展开内容。
async function extractZipArchive(input,destination,{prefix,signal,maxBytes}){
 const identity=await regular(input),handle=await open(input,constants.O_RDONLY|constants.O_NOFOLLOW);
 try{
  const actual=await handle.stat();if(actual.dev!==identity.dev||actual.ino!==identity.ino||actual.size!==identity.size)fail('归档读取身份漂移');
  const fileSize=identity.size,tailLength=Math.min(fileSize,65557),tail=await archiveRange(handle,fileSize,fileSize-tailLength,tailLength,signal);
  let end=-1;for(let at=tail.length-22;at>=0;at--)if(tail.readUInt32LE(at)===0x06054b50&&at+22+tail.readUInt16LE(at+20)===tail.length){end=at;break;}
  if(end<0)fail('ZIP目录缺失');
  const count=tail.readUInt16LE(end+10),directorySize=tail.readUInt32LE(end+12),directoryOffset=tail.readUInt32LE(end+16),directoryEnd=directoryOffset+directorySize;
  if(count===0xffff||directorySize===0xffffffff||directoryOffset===0xffffffff)fail('ZIP加密或Zip64未声明');
  if(tail.readUInt16LE(end+4)||tail.readUInt16LE(end+6)||tail.readUInt16LE(end+8)!==count||directoryEnd>fileSize-tailLength+end)fail('ZIP目录越界或分卷未声明');
  const entries=[],names=new Set();let cursor=directoryOffset,total=0;
  for(let index=0;index<count;index++){
   signal?.throwIfAborted();if(cursor+46>directoryEnd)fail('ZIP成员无效');
   const header=await archiveRange(handle,fileSize,cursor,46,signal);if(header.readUInt32LE(0)!==0x02014b50)fail('ZIP成员无效');
   const flags=header.readUInt16LE(8),method=header.readUInt16LE(10),compressed=header.readUInt32LE(20),size=header.readUInt32LE(24),nameLength=header.readUInt16LE(28),extra=header.readUInt16LE(30),comment=header.readUInt16LE(32),mode=header.readUInt32LE(38)>>>16,offset=header.readUInt32LE(42);
   if(flags&1||size===0xffffffff||compressed===0xffffffff||offset===0xffffffff)fail('ZIP加密或Zip64未声明');
   if(![0,8].includes(method))fail('ZIP压缩方式未声明');total+=size;if(total>maxBytes)fail('ZIP解压超限');
   if(cursor+46+nameLength+extra+comment>directoryEnd)fail('ZIP成员无效');
   const rawName=await archiveRange(handle,fileSize,cursor+46,nameLength,signal),name=rawName.toString('utf8');
   if(offset+30>directoryOffset)fail('ZIP本地记录无效');
   const local=await archiveRange(handle,fileSize,offset,30,signal);if(local.readUInt32LE(0)!==0x04034b50||local.readUInt16LE(8)!==method||local.readUInt16LE(6)&1)fail('ZIP本地记录无效');
   const localNameLength=local.readUInt16LE(26),start=offset+30+localNameLength+local.readUInt16LE(28);
   if(start+compressed>directoryOffset||!(await archiveRange(handle,fileSize,offset+30,localNameLength,signal)).equals(rawName))fail('ZIP本地记录无效');
   const path=name.replace(/\/$/u,'').replace(/^\.\//u,'');cursor+=46+nameLength+extra+comment;
   if(path==='.'||!path)continue;if(!safePath(path))fail('归档成员越界');if(entries.length>=400000||names.has(path))fail('归档成员重复或超限');names.add(path);
   entries.push({path,index,type:name.endsWith('/')?'directory':(mode&0o170000)===0o120000?'symlink':'file',mode:mode||0o644,method,compressed,size,start});
  }
  if(cursor!==directoryEnd)fail('ZIP目录长度不符');
  for(const entry of entries.filter(value=>value.type==='symlink')){
   if(entry.size>65535)fail('ZIP链接内容超限');const parts=[];await zipEntryBytes(handle,fileSize,entry,signal,async chunk=>{parts.push(Buffer.from(chunk));});entry.target=Buffer.concat(parts).toString();
  }
  const selected=selectedArchiveEntries(entries,prefix),chosen=new Set(selected.map(entry=>entry.index));
  // 未选中的成员与目录同样核对解码长度，前缀筛选不能绕过原正文检查。
  for(const entry of entries)if(entry.type==='directory'||!chosen.has(entry.index)&&entry.type!=='symlink')await zipEntryBytes(handle,fileSize,entry,signal);
  const result=await materializeArchiveEntries(destination,selected,{signal,write:async(file,entry)=>{
   const output=await open(file,'wx',entry.mode&0o111?0o755:0o644);
   try{await zipEntryBytes(handle,fileSize,entry,signal,async chunk=>{let at=0;while(at<chunk.length){const value=await output.write(chunk,at,chunk.length-at);if(!value.bytesWritten)fail('原件写入中断');at+=value.bytesWritten;}});}
   finally{await output.close();}
  }});
  const final=await handle.stat(),path=await regular(input);if(final.size!==identity.size||path.dev!==identity.dev||path.ino!==identity.ino||path.size!==identity.size){await permissions(destination,true);await rm(destination,{recursive:true});fail('归档读取身份漂移');}
  return result;
 }finally{await handle.close();}
}
async function extractArchive(input,destination,{prefix='',signal,tar,maxBytes=8*1024**3}={}){
 await regular(input);if(await stat(destination))fail('解包目标已存在');const head=await archiveHead(input,signal);
 if(head[0]===0x50&&head[1]===0x4b)return extractZipArchive(input,destination,{prefix,signal,maxBytes});
 let bytes=await readFile(input),entries=[];
 const add=(path,type,data,mode=0o644,target,mtime)=>{path=path.replace(/\/$/u,'').replace(/^\.\//u,'');if(path==='.'||!path)return;if(!safePath(path))fail('归档成员越界');if(entries.length>=400000||entries.some(x=>x.path===path))fail('归档成员重复或超限');entries.push({path,type,data,mode,target,mtime});};
 {if(bytes[0]===0x1f&&bytes[1]===0x8b)bytes=gunzipSync(bytes,{maxOutputLength:maxBytes});else if(bytes[0]===0xfd&&bytes[1]===0x37){if(!tar)fail('XZ需要已提供基础归档工具');fail('XZ应通过受控tar清单提取');}
  const number=b=>{const v=b.toString().replace(/\0.*$/su,'').trim();if(!/^[0-7]*$/u.test(v))fail('TAR数字无效');return parseInt(v||'0',8);};let pax={},global={};
  for(let cursor=0;cursor+512<=bytes.length;){signal?.throwIfAborted();const block=bytes.subarray(cursor,cursor+512);if(block.every(x=>x===0))break;let sum=0;for(let i=0;i<512;i++)sum+=(i>=148&&i<156)?32:block[i];if(sum!==number(block.subarray(148,156)))fail('TAR头摘要不符');const size=number(block.subarray(124,136)),type=String.fromCharCode(block[156]||48),str=(a,b)=>block.subarray(a,b).toString().replace(/\0.*$/su,''),data=bytes.subarray(cursor+512,cursor+512+size);if(data.length!==size||size>maxBytes)fail('TAR内容超限');cursor+=512+Math.ceil(size/512)*512;
   if(type==='x'||type==='g'){const values={};let at=0;while(at<data.length){const space=data.indexOf(32,at),length=Number(data.subarray(at,space).toString());if(!Number.isInteger(length)||length<=space-at+1||at+length>data.length)fail('PAX长度无效');const record=data.subarray(space+1,at+length-1).toString(),eq=record.indexOf('=');if(eq<1)fail('PAX字段无效');values[record.slice(0,eq)]=record.slice(eq+1);at+=length;}if(type==='g')global={...global,...values};else pax=values;continue;}
   if(type==='L'){pax.path=data.toString().replace(/\0.*$/su,'');continue;}if(type==='K'){pax.linkpath=data.toString().replace(/\0.*$/su,'');continue;}
   const attrs={...global,...pax};pax={};if(Object.keys(attrs).some(x=>x.startsWith('GNU.sparse')))fail('TAR稀疏文件未声明');const name=attrs.path||[str(345,500),str(0,100)].filter(Boolean).join('/'),target=attrs.linkpath||str(157,257);if(!['0','5','2','1'].includes(type))fail('TAR特殊成员未声明');// 发行件的生成文件依赖原mtime；不能按解包写入顺序改变make依赖关系。
   let mtime;
   if(type==='0'){
    if(attrs.mtime!==undefined&&!/^(?:0|[1-9][0-9]*)(?:\.[0-9]{1,9})?$/u.test(attrs.mtime))fail('TAR修改时间无效');
    mtime=attrs.mtime===undefined?number(block.subarray(136,148)):Number(attrs.mtime);
    if(!Number.isFinite(mtime)||mtime<0||mtime>8640000000000||!Number.isSafeInteger(Math.trunc(mtime*1000)))fail('TAR修改时间无效');
   }
   add(name,{'0':'file','5':'directory','2':'symlink','1':'hardlink'}[type],data,number(block.subarray(100,108)),target,mtime);
  }
 }
 const selected=selectedArchiveEntries(entries,prefix);
 return materializeArchiveEntries(destination,selected,{signal,write:async(file,entry)=>{
  const output=await open(file,constants.O_WRONLY|constants.O_CREAT|constants.O_EXCL|constants.O_NOFOLLOW,entry.mode&0o111?0o755:0o644);
  try{await output.writeFile(entry.data);signal?.throwIfAborted();await output.utimes(entry.mtime,entry.mtime);}
  finally{await output.close();}
 }});
}
// XZ由供给的POSIX tar处理；双遍清单、无链接父目录与候选物化后的清单一起保护边界。
async function unpack(input,target,{prefix='',signal,foundation,run=exec}={}){const b=await archiveHead(input,signal);if(!(b[0]===0xfd&&b[1]===0x37))return extractArchive(input,target,{prefix,signal});const tar=foundation?.tools.tar;if(!tar)fail('XZ缺少tar入口');const list=await run(tar,['-tvf',input],{signal,maxBuffer:32*1024**2});if(list.stdout.split('\n').filter(Boolean).some(x=>!/^[-d]/u.test(x)))fail('XZ成员含链接或特殊项');const names=(await run(tar,['-tf',input],{signal,maxBuffer:32*1024**2})).stdout.split('\n').filter(Boolean);if(names.some(x=>!safePath(x.replace(/\/$/u,'').replace(/^\.\//u,''))))fail('XZ成员越界');await mkdir(target);try{await verifyArchiveNames(target,names.map(name=>name.replace(/\/$/u,'').replace(/^\.\//u,'' )).filter(name=>name&&name!=='.'),signal);await run(tar,['-xkf',input,'--no-same-owner','-C',target],{signal,maxBuffer:2*1024**2});if(prefix){const child=join(target,prefix),temporary=target+'.root';await directory(child);await rename(child,temporary);await permissions(target,true);await rm(target,{recursive:true});await rename(temporary,target);}return target;}catch(error){if(await stat(target)){await permissions(target,true);await rm(target,{recursive:true});}throw error;}}
// 本仓准确工具配方；外部供给登记不能改变这些版本和来源。
const posixRecipe=(()=>{

// 只采集官方macOS发行件中的基础入口；不纳入Git/Python/Ruby等独立登记工具。
const posixNames = Object.freeze([
  'sh', 'bash', 'tar', 'awk', 'sed', 'grep', 'cat', 'chmod', 'cp', 'cut', 'dirname',
  'echo', 'env', 'expr', 'false', 'find', 'head', 'install', 'ln', 'ls', 'mkdir',
  'mktemp', 'mv', 'od', 'paste', 'pwd', 'readlink', 'rm', 'rmdir', 'sleep', 'sort',
  'tail', 'tee', 'test', 'touch', 'tr', 'true', 'uname', 'uniq', 'wc', 'xargs',
  'basename', 'printf', 'date', 'cmp', 'comm', 'dd', 'df', 'du', 'hostname',
  'whoami', 'file', 'stat', 'zip', 'unzip', 'plutil', 'ditto', 'rsync', 'patch',
  'sw_vers', 'chflags', 'cpio', 'gzip', 'gunzip', 'bzip2', 'egrep', 'fgrep',
  'open', 'pgrep', 'pkill', 'lsof', 'zsh', 'ps', 'kill', 'diff', 'yes', 'realpath',
  'which', 'sysctl',
]);


const fail = message => { throw new Error('受控POSIX工具：' + message); };

function validatePosixTool(tool) {
  if (tool?.id !== 'posix' || tool.command !== 'bash' || !tool.managed
    || !/^\d+\.\d+(?:\.\d+)?$/u.test(tool.version)
    || tool.source !== 'https://opensource.apple.com/'
    || JSON.stringify(tool.requires) !== JSON.stringify(['node', 'xcode'])
    || tool.archive?.kind !== 'apple-posix'
    || tool.archive.url !== tool.source || tool.archive.root !== 'macos-posix-' + tool.version
    || tool.archive.executable !== 'bin/bash' || !/^[a-f0-9]{64}$/u.test(tool.archive.sha256)
    || tool.dependencies || tool.components || tool.archives) fail('官方发行件登记不完整');
}

async function locatePosixSources({signal,platform=process.platform}={}){
 if(platform!=='darwin')fail('仅限已授权macOS自举');
 const files=[];for(const name of posixNames){signal?.throwIfAborted();const entry=['/bin/','/usr/bin/','/usr/sbin/'].map(prefix=>prefix+name).find(existsSync);if(!entry)fail('缺少官方基础入口：'+name);const path=await realpath(entry),info=await lstat(path);if(!info.isFile()||!(info.mode&0o111))fail('系统输入不是普通可执行文件');files.push({name,path});}return files;
}


// 采集不是常态回退：只有本次明确授权的bootstrap调用可建立候选，发布仍由工具事务完成。
async function buildPosixTool({ tool, payload, bootstrap = false, run, signal }) {
  validatePosixTool(tool);
  if (bootstrap !== true) fail('缺少本次首次自举授权');
  const files = await locatePosixSources({signal});

  await mkdir(payload); await mkdir(join(payload, 'bin'));
  for (const file of files) {

    const target = join(payload, 'bin', file.name);
    await copyFile(file.path, target);

    // 系统原签名带平台限制；候选建立本机运行签名，随后执行实际命令。
    await run('/usr/bin/codesign', ['--force', '--sign', '-', '--timestamp=none', target],
      { signal, timeout: 60000, env: { PATH: '', LANG: 'C' } });

  }
  // 发布前真实执行文件、归档及Flutter宿主探测；只接受同对象内的sysctl。
  const bin = join(payload, 'bin'), probe = join(payload, '.probe');
  await mkdir(probe);
  try {
    const result = await run(join(bin, 'bash'), ['--noprofile', '--norc', '-e', '-o', 'pipefail', '-c',
      'printf "controlled-posix-ok\\n" > input; cp input copy; cmp input copy; awk "{print}" copy | sed -n "1p"; tar -cf check.tar input; tar -tf check.tar; which sysctl; sysctl -n hw.optional.arm64; if which citizen-tool-not-installed > /dev/null 2>&1; then exit 1; fi'],
      { cwd: probe, signal, timeout: 60000, env: { PATH: bin, LANG: 'C' } });
    if (result.stdout !== 'controlled-posix-ok\ninput\n' + join(bin, 'sysctl') + '\n1\n') fail('基础工具真实执行回读不符');
  } finally { await rm(probe, {recursive:true,force:true}); }

}

// 调用方只取得同一只读对象内入口；缺失立即失败，绝不从系统或PATH补齐。
async function controlledPosixTools(library, lookup) {
  const tool = library.tools.find(entry => entry.id === 'posix');
  if (!tool) fail('基础工具未登记');
  validatePosixTool(tool);
  const installed = await lookup(library, tool);
  if (!installed) fail('请先安装已登记基础工具原件');
  const bin = dirname(installed.path), tools = {};
  for (const name of posixNames) {
    const path = join(bin, name), info = await lstat(path);
    if (!info.isFile() || !(info.mode & 0o111) || await realpath(path) !== path) fail('受控入口失效：' + name);
    tools[name] = path;
  }
  return { bin, tools };
}
return {posixNames,buildPosixTool,controlledPosixTools};})();
const sourceRecipe=(()=>{
const controlledPosixTools=(...args)=>productFoundation(...args);

const fail = message => { throw new Error('官方源码工具：' + message); };
const plain = (value, fields) => value && typeof value === 'object' && !Array.isArray(value)
  && Object.keys(value).sort().join(',') === [...fields].sort().join(',');
const hash = value => createHash('sha256').update(value).digest('hex');
const sources = Object.freeze({
  bash: version => { const base=version.split('.').slice(0,2).join('.');return ['https://ftp.gnu.org/gnu/bash/bash-'+base+'.tar.gz','bash-'+base,'bin/bash']; },
  grep: version => ['https://ftp.gnu.org/gnu/grep/grep-' + version + '.tar.xz', 'grep-' + version, 'bin/grep'],
  sed: version => ['https://ftp.gnu.org/gnu/sed/sed-' + version + '.tar.xz', 'sed-' + version, 'bin/sed'],
  m4: version => ['https://ftp.gnu.org/gnu/m4/m4-' + version + '.tar.xz', 'm4-' + version, 'bin/m4'],
  bison: version => ['https://ftp.gnu.org/gnu/bison/bison-' + version + '.tar.xz', 'bison-' + version, 'bin/bison'],
  flex: version => ['https://github.com/westes/flex/releases/download/v' + version + '/flex-' + version + '.tar.gz', 'flex-' + version, 'bin/flex'],
  gettext: version => ['https://ftp.gnu.org/gnu/gettext/gettext-' + version + '.tar.gz', 'gettext-' + version, 'bin/msgfmt'],
  tcl: version => ['https://github.com/tcltk/tcl/releases/download/core-' + version.replaceAll('.', '-') + '/tcl' + version + '-src.tar.gz', 'tcl' + version, 'bin/tclsh' + version.split('.').slice(0, 2).join('.')],
  git: version => ['https://www.kernel.org/pub/software/scm/git/git-' + version + '.tar.xz', 'git-' + version, 'bin/git'],
  python: version => ['https://www.python.org/ftp/python/' + version + '/Python-' + version + '.tar.xz', 'Python-' + version, 'bin/python' + version.split('.').slice(0, 2).join('.')],
  perl: version => ['https://www.cpan.org/src/5.0/perl-' + version + '.tar.xz', 'perl-' + version, 'bin/perl'],
  ruby: version => ['https://cache.ruby-lang.org/pub/ruby/' + version.split('.').slice(0, 2).join('.') + '/ruby-' + version + '.tar.gz', 'ruby-' + version, 'bin/ruby'],
  openssl: version => ['https://github.com/openssl/openssl/releases/download/openssl-' + version + '/openssl-' + version + '.tar.gz', 'openssl-' + version, 'bin/openssl'],
  cocoapods: version => ['https://rubygems.org/downloads/cocoapods-' + version + '.gem', '.', 'bin/pod'],
});
const requirements = Object.freeze({
  bash: ['node', 'xcode', 'posix'], grep: ['node', 'xcode', 'posix'], sed: ['node', 'xcode', 'posix'],
  git: ['node', 'xcode', 'perl', 'python', 'gettext'], python: ['node', 'xcode', 'openssl'],
  m4: ['node', 'xcode'], bison: ['node', 'xcode', 'm4'], flex: ['node', 'xcode', 'm4', 'bison'],
  gettext: ['node', 'xcode', 'perl', 'm4', 'bison', 'flex'], tcl: ['node', 'xcode'],
  perl: ['node', 'xcode'], openssl: ['node', 'xcode', 'perl'],
  ruby: ['node', 'xcode', 'openssl'], cocoapods: ['node', 'xcode', 'ruby', 'git'],
});

// 来源、归档根、执行入口和前置对象形成闭集；运行时绝不解析latest或系统同名命令。
function validateSourceTool(tool) {
  const expected = sources[tool?.id]?.(tool.version);
  if (!expected || !tool.managed || !/^\d+\.\d+(?:\.\d+)?$/u.test(tool.version)
    || JSON.stringify(tool.requires) !== JSON.stringify(requirements[tool.id])
    || tool.archive?.kind !== (tool.id === 'cocoapods' ? 'gem' : 'native-source')
    || JSON.stringify([tool.archive.url, tool.archive.root, tool.archive.executable]) !== JSON.stringify(expected)
    || !/^[a-f0-9]{64}$/u.test(tool.archive.sha256)) fail('官方固定归档或工具前置关系不符');
  const patches = tool.upstream_patches ?? [];
  if (!Array.isArray(patches) || tool.id === 'bash' && patches.length !== Number(tool.version.split('.')[2]||0)
    || tool.id !== 'bash' && patches.length) fail('官方源码补丁闭包不符');
  for (const [i, patch] of patches.entries()) {
    if (!plain(patch, ['url', 'sha256']) || !/^[a-f0-9]{64}$/u.test(patch.sha256)
      || patch.url !== 'https://ftp.gnu.org/gnu/bash/bash-'+tool.version.split('.').slice(0,2).join('.')+'-patches/bash'+tool.version.split('.').slice(0,2).join('')+'-' + String(i + 1).padStart(3, '0')) fail('官方Bash补丁顺序或坐标不符');
  }
  const dependencies = tool.dependencies ?? [];
  if (!Array.isArray(dependencies) || new Set(dependencies.map(entry => entry.name)).size !== dependencies.length) fail('依赖身份重复');
  for (const entry of dependencies) {
    if (tool.id === 'cocoapods') {
      if (!plain(entry, ['name', 'version', 'url', 'sha256']) || entry.name === 'cocoapods'
        || !/^[A-Za-z][A-Za-z0-9_-]*$/u.test(entry.name) || !/^\d+(?:\.\d+){1,3}$/u.test(entry.version)
        || entry.url !== 'https://rubygems.org/downloads/' + entry.name + '-' + entry.version + '.gem') fail('CocoaPods依赖必须是固定官方Gem');
    } else if (tool.id === 'ruby') {
      if (!plain(entry, ['name', 'version', 'url', 'sha256', 'root']) || entry.name !== 'libyaml'
        || entry.url !== 'https://pyyaml.org/download/libyaml/yaml-' + entry.version + '.tar.gz'
        || entry.root !== 'yaml-' + entry.version) fail('Ruby YAML依赖来源不符');
    } else if (tool.id === 'python') {
      if (!plain(entry, ['name', 'version', 'url', 'sha256', 'root']) || entry.name !== 'xz'
        || !/^\d+\.\d+\.\d+$/u.test(entry.version)
        || entry.url !== 'https://github.com/tukaani-project/xz/releases/download/v'+entry.version+'/xz-'+entry.version+'.tar.xz'
        || entry.root !== 'xz-'+entry.version) fail('Python LZMA依赖来源不符');
    } else fail('该工具没有独立外部源码依赖');
    if (!/^[a-f0-9]{64}$/u.test(entry.sha256)) fail('源码依赖摘要缺失');
  }
  if (['ruby', 'python'].includes(tool.id) && dependencies.length !== 1
    || tool.id === 'cocoapods' && (!dependencies.length
      || !dependencies.some(entry => entry.name === 'cocoapods-core' && entry.version === tool.version))) {
    fail('工具运行依赖闭包不完整');
  }
  return true;
}

// Perl实际安装目录只来自本轮官方Configure输出，不猜版本目录或架构名称。
function perlRuntimeLibraries(config, finalPayload, payload) {
  const paths=['installprivlib','installarchlib'].map(name=>{
    const values=[...config.matchAll(new RegExp('^'+name+"='([^']*)'$",'gm'))];
    const value=values.length===1?values[0][1]:null;
    if(!value || !value.startsWith(finalPayload+'/') || value!==resolve(value)
      || /[\x00-\x1f]/u.test(value)) fail('Perl官方安装目录声明无效：'+name);
    return join(payload,relative(finalPayload,value));
  });
  if(new Set(paths).size!==2) fail('Perl普通与架构运行库必须准确隔离');
  return paths;
}

async function directory(path) {
  if (!isAbsolute(path) || path !== resolve(path) || await realpath(path) !== path
    || !(await lstat(path)).isDirectory()) fail('候选目录必须是规范真实目录');
}
async function regular(path, executable = false) {
  const info = await lstat(path);
  if (!info.isFile() || info.isSymbolicLink() || !info.size
    || await realpath(path) !== path || executable && !(info.mode & 0o111)) fail('输入或输出必须是准确普通文件');
}

// 只有此工具对象的候选目录可写；最终前缀固定到已登记摘要，DESTDIR收集后才原子发布。
async function buildSourceTool({ library, tool, source, archive, pending, payload,
  finalPayload, signal, fetcher, exec, lookup, apple, bootstrap = false, environment = process.env,
  prepare = prepareSourceDependencies, download = downloadTool }) {
  validateSourceTool(tool);
  const expected = library.pending;
  if (pending !== expected || payload !== join(pending, 'payload')
    || finalPayload !== library.finalPayload
    || archive !== join(pending, 'archive')
    || source !== (tool.archive.kind === 'gem' ? archive : join(pending, 'unpack', tool.archive.root))) fail('候选对象身份不符');
  await directory(pending); await regular(archive);

  if (tool.archive.kind !== 'gem') await directory(source);
  const installed = {};
  for (const id of tool.requires) {
    const registered = library.tools.find(entry => entry.id === id);
    const result = registered && await lookup(library, registered);
    if (!result) fail('缺少已提供前置工具：' + id);
    installed[id] = result.path;
  }
  const foundation = await controlledPosixTools(library, lookup, { bootstrap, id: tool.id });
  const selected = await apple(library, { names: ['clang', 'clang++', 'ar', 'make', 'ld', 'nm', 'ranlib', 'strip', 'xcrun', 'otool', 'install_name_tool', 'codesign'], signal });
  const sdkResult = await exec(selected.tools.xcrun, ['--sdk', 'macosx', '--show-sdk-path'], {
    env: { PATH: '', DEVELOPER_DIR: selected.developerDirectory }, signal, timeout: 60_000,
  });
  // xcrun返回包内官方SDK链接；固定到同一包内真实目标，不接纳包外SDK。
  const sdkInput = sdkResult.stdout.trim();
  if (!isAbsolute(sdkInput) || sdkInput !== resolve(sdkInput)) fail('SDK返回路径无效');
  const sdk = await realpath(sdkInput); await directory(sdk);
  if (!sdk.startsWith(selected.developerDirectory + '/')) fail('SDK不属于同一Xcode');
  const work = join(pending, 'probe'), stage = join(work, 'stage');
  await mkdir(work); await mkdir(stage);
  const env = { ...environment, HOME: work, TMPDIR: work, DEVELOPER_DIR: selected.developerDirectory,
    SDKROOT: sdk, MACOSX_DEPLOYMENT_TARGET: library.tools.find(entry=>entry.id==='posix').version,
    PATH: [...new Set([...Object.values(installed).map(dirname), foundation.path,
      dirname(selected.tools.clang), dirname(selected.tools.make)])].join(':'),
    // Clang自带汇编器，避免调用带系统解释器shebang的Xcode as脚本。
    CC: selected.tools.clang, CXX: selected.tools['clang++'], AR: selected.tools.ar,
    CPP: selected.tools.clang + ' -E', LD: selected.tools.ld, AS: selected.tools.clang,
    NM: selected.tools.nm, RANLIB: selected.tools.ranlib, STRIP: selected.tools.strip,
    MAKE: selected.tools.make, PERL: installed.perl ?? '', PYTHON: installed.python ?? '',
    RUBY: installed.ruby ?? '', MAKEINFO: 'true', HELP2MAN: 'true', M4: installed.m4 ?? 'false', BISON: installed.bison ?? 'false',
    YACC: installed.bison ? installed.bison + ' -y' : 'false', FLEX: installed.flex ?? 'false',
    // 官方AC_PROG_LEX用冒号表示未安装Lex，false会误入必须生成扫描器的探测。
    LEX: installed.flex ?? ':', COCOAPODS_DISABLE_STATS: 'true',
  };
  for (const key of Object.keys(env)) if (key.startsWith('DYLD_') || ['NODE_OPTIONS', 'NODE_PATH', 'BASH_ENV', 'ENV', 'SHELLOPTS', 'BASHOPTS', 'CDPATH', 'GLOBIGNORE',
    'PYTHONHOME', 'PYTHONPATH', 'RUBYOPT', 'RUBYLIB', 'GEM_HOME', 'GEM_PATH', 'PERL5OPT', 'PERL5LIB',
    'ARCHFLAGS', 'ARCH', 'CC_FOR_BUILD', 'CXX_FOR_BUILD', 'CROSS_COMPILE', 'LD_PRELOAD', 'LD_LIBRARY_PATH',
    'CFLAGS', 'CXXFLAGS', 'CPPFLAGS', 'LDFLAGS', 'CPATH', 'LIBRARY_PATH', 'PKG_CONFIG_PATH', 'CONFIG_SITE', 'GNUMAKEFLAGS', 'MAKEFLAGS', 'MFLAGS',
    'DESTDIR', 'LD_RUN_PATH', 'CMAKE_TOOLCHAIN_FILE', 'npm_execpath', 'npm_node_execpath', 'NVM_BIN', 'NVM_DIR'].includes(key)) delete env[key];
  // 已提供SDK通过SDKROOT传给Clang，避免Configure把嵌入引号当作路径字节。
  env.CFLAGS = '-O2';
  env.CXXFLAGS = env.CFLAGS;
  env.LDFLAGS = '-Wl,-headerpad_max_install_names';
  env.ARCHFLAGS = '-arch arm64';
  env.SHELL = foundation.tools.sh;
  env.CONFIG_SHELL = foundation.tools.sh;
  env.M4PATH = '';
  env.BISON_PKGDATADIR = installed.bison ? join(dirname(dirname(installed.bison)), 'share/bison') : '';
  env.PKG_CONFIG = 'false';
  env.PKG_CONFIG_LIBDIR = '';
  env.CONFIG_SITE = '';
  const run = (command, args, cwd = tool.id === 'tcl' ? join(source, 'unix') : source, extra = {}) => exec(command, args, {
    cwd, env: { ...env, ...extra }, signal, timeout: 3_600_000, maxBuffer: 8 * 1024 * 1024,
  });
  const originals = await prepare({ library, tool, pending, environment: env, signal, fetcher });
  const upstream = [];
  for (const [i, patch] of (tool.upstream_patches ?? []).entries()) {
    const file = join(pending, 'bash53-' + String(i + 1).padStart(3, '0'));

    await download(patch, file, { fetcher, signal });
    await regular(file);

    await run(foundation.tools.patch, ['--batch', '--forward', '--fuzz=0', '-p0', '-i', file]);
    upstream.push(file);
  }
  if (tool.id === 'cocoapods') {
    await mkdir(payload); await mkdir(join(payload, 'bin'));
    const manifest = join(work, 'gems.json');
    await writeFile(manifest, JSON.stringify([{ name: 'cocoapods', version: tool.version, file: archive },
      ...tool.dependencies.map(entry => ({ name: entry.name, version: entry.version, file: originals.get(entry.name) }))]), { flag: 'wx' });
    // Ruby读取声明的Gem内的真实spec并核对整个运行闭包；无在线解析、系统Gem或忽略版本要求。
    const code = [
      "require 'rubygems'; require 'rubygems/package'; require 'rubygems/installer'; require 'json'; require 'fileutils'",
      "entries = JSON.parse(File.read(ARGV.fetch(0))); home = ARGV.fetch(1)",
      "specs = entries.to_h { |e| s = Gem::Package.new(e.fetch('file')).spec; raise 'Gem identity' unless s.name == e.fetch('name') && s.version.to_s == e.fetch('version') && s.platform == Gem::Platform::RUBY; raise 'Ruby requirement' unless s.required_ruby_version.satisfied_by?(Gem::Version.new(RUBY_VERSION)); [s.name, s] }",
      "specs.each_value { |s| s.runtime_dependencies.each { |d| v = specs[d.name]; raise 'Gem closure' unless v && d.requirement.satisfied_by?(v.version) } }",
      "Gem.use_paths(home, [home]); RbConfig::CONFIG['CC'] = ENV.fetch('CC'); RbConfig::CONFIG['CXX'] = ENV.fetch('CXX'); RbConfig::CONFIG['AR'] = ENV.fetch('AR'); RbConfig::CONFIG['MAKE'] = ENV.fetch('MAKE')",
      "entries.each { |e| Gem::Installer.at(e.fetch('file'), install_dir: home, ignore_dependencies: true, wrappers: false, env_shebang: false, document: [], build_args: ['--disable-system-libffi']).install }",
      // 显式install_dir不更新本进程规格缓存；离线安装后刷新，再逐包回读准确版本。
      "Gem::Specification.reset",
      // 只保留Gem原始脚本与唯一pod包装入口，清除换位后会断开的自动命令链接。
      "specs.each_value { |s| raise 'Gem installed version' unless Gem::Specification.find_by_name(s.name, s.version).version == s.version }; FileUtils.rm_rf(File.join(home, 'cache')); FileUtils.rm_rf(File.join(home, 'bin'))",
    ].join('\n');
    await run(installed.ruby, ['--disable-gems', '-e', code, manifest, join(payload, 'gems')], work,
      { GEM_HOME: join(payload, 'gems'), GEM_PATH: join(payload, 'gems') });
    // 只开放当前CocoaPods与同一受控Ruby自带Gem；不继承外部或用户Gem路径。
    const program = "ENV['GEM_HOME'] = File.expand_path('../gems', File.dirname(ARGV.shift)); ENV['GEM_PATH'] = ENV['GEM_HOME']; ENV['COCOAPODS_DISABLE_STATS'] = 'true'; require 'rubygems'; ENV['GEM_PATH'] = [ENV['GEM_HOME'], Gem.default_dir].join(File::PATH_SEPARATOR); Gem.clear_paths; require 'logger'; load Gem.bin_path('cocoapods', 'pod', " + JSON.stringify(tool.version) + ")";
    const quote = value => "'" + value.replaceAll("'", "'\\''") + "'";
    // 运行入口固定安装时已提供的工具路径，确保Git可用并排除调用方PATH。
    const wrapper = '#!' + foundation.tools.sh + '\nunset RUBYOPT RUBYLIB GEM_HOME GEM_PATH DYLD_LIBRARY_PATH DYLD_INSERT_LIBRARIES\n'
      + 'PATH=' + quote(env.PATH) + '\n'
      + 'exec ' + quote(installed.ruby) + ' --disable-gems -e ' + quote(program) + ' "$0" "$@"\n';
    await writeFile(join(payload, 'bin/pod'), wrapper, { flag: 'wx', mode: 0o555 });
  } else {
    let flags = ['--prefix=' + finalPayload];
    if (tool.id === 'ruby') {
      const yaml = join(work, 'yaml'); await mkdir(yaml);
      await run(foundation.tools.tar, ['-xkf', originals.get('libyaml'), '--no-same-owner', '-C', yaml], work);
      const root = join(yaml, tool.dependencies[0].root); await directory(root);
      const prefix = join(work, 'libyaml');
      await run(foundation.tools.sh, [join(root, 'configure'), '--prefix=' + prefix, '--disable-shared'], root);
      await run(selected.tools.make, ['-j8', 'SHELL=' + foundation.tools.sh], root);
      await run(selected.tools.make, ['install', 'SHELL=' + foundation.tools.sh], root);
      flags.push('--with-baseruby=no', '--with-libyaml-dir=' + prefix,
        '--with-openssl-dir=' + dirname(dirname(installed.openssl)), '--disable-install-doc');
    }
    if (tool.id === 'python') {
      // Xcode SDK不提供lzma头文件；仅编译已锁官方liblzma静态库，不借用户或系统缓存。
      const archiveDirectory = join(work, 'xz'); await mkdir(archiveDirectory);
      await run(foundation.tools.tar, ['-xkf', originals.get('xz'), '--no-same-owner', '-C', archiveDirectory], work);
      const root = join(archiveDirectory, tool.dependencies[0].root); await directory(root);
      const prefix = join(work, 'liblzma');
      await run(foundation.tools.sh, [join(root, 'configure'), '--prefix=' + prefix,
        '--disable-shared', '--enable-static', '--with-pic', '--disable-xz', '--disable-xzdec',
        '--disable-lzmadec', '--disable-lzmainfo', '--disable-scripts', '--disable-doc', '--disable-nls'], root);
      await run(selected.tools.make, ['-j8', 'SHELL=' + foundation.tools.sh], root);
      await run(selected.tools.make, ['install', 'SHELL=' + foundation.tools.sh], root);
      await regular(join(prefix, 'include/lzma.h')); await regular(join(prefix, 'lib/liblzma.a'));
      // Python官方configure支持这两个边界变量；静态链接不携带候选运行库路径。
      env.LIBLZMA_CFLAGS = '-I' + join(prefix, 'include');
      env.LIBLZMA_LIBS = join(prefix, 'lib/liblzma.a');
    }
    if (['bison', 'flex', 'bash', 'grep', 'sed'].includes(tool.id)) flags.push('--disable-nls');
    if (tool.id === 'bash') flags.push('--without-bash-malloc');
    if (tool.id === 'grep') flags.push('--disable-perl-regexp');
    // libfl的yylex由消费者扫描器提供；macOS交付静态库，避免共享库链接未定义符号。
    if (tool.id === 'flex') flags.push('--disable-shared');
    if (tool.id === 'gettext') flags.push('--disable-shared', '--disable-java', '--disable-csharp', '--without-emacs');
    if (tool.id === 'tcl') flags.push('--enable-threads', '--enable-shared');
    if (tool.id === 'python') flags.push('--with-openssl=' + dirname(dirname(installed.openssl)), '--with-openssl-rpath=auto');
    if (tool.id === 'perl') {
      await run(foundation.tools.sh, [join(source, 'Configure'), '-des', '-Dprefix=' + finalPayload,
        '-Dcc=' + selected.tools.clang, '-Dld=' + selected.tools.clang, '-Dar=' + selected.tools.ar,
        '-Duseshrplib', '-Dinstallusrbinperl=n', '-Dccflags=' + env.CFLAGS,
        '-Dldflags=' + env.LDFLAGS, '-Dman1dir=none', '-Dman3dir=none']);
    } else if (tool.id === 'openssl') {
      await run(installed.perl, [join(source, 'Configure'), 'darwin64-arm64-cc', '--prefix=' + finalPayload,
        '--openssldir=/private/etc/ssl', 'no-shared']);
    } else if (tool.id !== 'git') await run(foundation.tools.sh, [join(tool.id === 'tcl' ? join(source, 'unix') : source, 'configure'), ...flags]);
    let curlLibrary;
    if (tool.id === 'git') {
      // 官方Makefile允许显式交付CURL输入；固定同一Xcode SDK，不执行未登记curl-config。
      await regular(join(sdk, 'usr/include/curl/curl.h'));
      // Apple SDK的libcurl.tbd是官方链接；只接受同一SDK目录内的真实普通目标。
      curlLibrary = await realpath(join(sdk, 'usr/lib/libcurl.tbd'));
      if (!curlLibrary.startsWith(sdk + '/usr/lib/')) fail('CURL链接输入不属于同一SDK');
      await regular(curlLibrary);
    }
    const makeArgs = tool.id === 'git' ? ['prefix=' + finalPayload,
      'CURL_CFLAGS=-I' + join(sdk, 'usr/include'), 'CURL_LDFLAGS=' + curlLibrary,
      'NO_FINK=YesPlease', 'NO_DARWIN_PORTS=YesPlease', 'NO_HOMEBREW=YesPlease',
      'GETTEXT_PATH=' + join(dirname(installed.gettext), 'gettext'), 'CPPFLAGS=-I' + dirname(dirname(installed.gettext)) + '/include',
      'LDFLAGS=' + env.LDFLAGS + ' -L' + dirname(dirname(installed.gettext)) + '/lib', 'NO_TCLTK=YesPlease', 'PERL_PATH=' + installed.perl, 'PYTHON_PATH=' + installed.python,
      'CC=' + selected.tools.clang, 'AR=' + selected.tools.ar, 'SHELL_PATH=' + foundation.tools.sh, 'SHELL=' + foundation.tools.sh] : ['SHELL=' + foundation.tools.sh];
    await run(selected.tools.make, ['-j8', ...makeArgs]);
    await run(selected.tools.make, ['DESTDIR=' + stage, ...makeArgs,
      tool.id === 'openssl' ? 'install_sw' : 'install']);
    const staged = join(stage, finalPayload.slice(1)); await directory(staged);
    await rename(staged, payload);
  }
  await regular(join(payload, tool.archive.executable), true);
  if (tool.id === 'grep') for (const name of ['egrep', 'fgrep']) {
    const alias = join(payload, 'bin', name);
    const info = await lstat(alias).catch(error => {if (error.code !== 'ENOENT') throw error; return null;});
    if (info) {if (!info.isFile() || info.isSymbolicLink()) fail('上游grep别名不是普通脚本');await rm(alias);}
  }
  if (tool.id === 'bash') {
    // sh是同一个Bash产物的准确普通副本，版本与回执同属唯一工具对象。
    await writeFile(join(payload, 'bin/sh'), await readFile(join(payload, 'bin/bash')), { flag: 'wx', mode: 0o555 });
  }
  if (tool.archive.kind === 'native-source') {
    const walk = async path => {
      const result = [];
      for (const entry of await readdir(path, { withFileTypes: true })) {
        const file = join(path, entry.name);
        if (entry.isDirectory()) result.push(...await walk(file));
        else if (entry.isFile()) result.push(file);
        else if (!entry.isSymbolicLink()) fail('工具输出包含特殊文件');
      }
      return result;
    };
    const binaries = [];
    for (const file of await walk(payload)) {
      const bytes = await readFile(file);
      if (bytes.length >= 32 && bytes.readUInt32LE(0) === 0xfeedfacf) {
        if (bytes.readUInt32LE(4) !== 0x0100000c) fail('源码工具Mach-O架构不是ARM64');
        binaries.push(file);
      }
    }
    if (!binaries.includes(join(payload, tool.archive.executable))) fail('编译没有生成ARM64工具入口');
    const relocated = new Set();
    for (const file of binaries) {
      const identity = await lstat(file), key = identity.dev + ':' + identity.ino;
      if (relocated.has(key)) continue;
      relocated.add(key);
      const listing = await run(selected.tools.otool, ['-L', file], work);
      let ownRuntime = false;
      for (const line of listing.stdout.split('\n').slice(1)) {
        const dependency = line.trim().split(' (')[0];
        if (!dependency) continue;
        if (dependency.startsWith(finalPayload + '/')) {
          ownRuntime = true;
          await run(selected.tools.install_name_tool, ['-change', dependency,
            '@rpath/' + relative(finalPayload, dependency), file], work);
        } else if (isAbsolute(dependency) && !dependency.startsWith('/usr/lib/')
          && !dependency.startsWith('/System/Library/')
          && !Object.values(installed).some(path => dependency.startsWith(dirname(dirname(path)) + '/'))) {
          fail('工具链接到未验真的外部库');
        }
      }
      // 相对工具对象根定位同一候选与最终对象，避免Perl共享库在原子发布前指向不存在的前缀。
      const loader = '@loader_path' + (relative(dirname(file), payload) ? '/' + relative(dirname(file), payload) : '');
      // 仅链接同对象运行库的入口需要新rpath；系统库模块不能平白扩大Mach-O加载命令。
      if (ownRuntime) await run(selected.tools.install_name_tool, ['-add_rpath', loader, file], work);
      if (file.endsWith('.dylib')) await run(selected.tools.install_name_tool, ['-id',
        '@rpath/' + relative(payload, file), file], work);
      await run(selected.tools.codesign, ['--force', '--sign', '-', '--timestamp=none', file], work);
    }
  }

  // 入口版本不能代替运行闭包验收；解释器必须在原子发布前真实加载所需核心与加密模块。
  const executable = join(payload, tool.archive.executable);
  const probe = async (args, extra = {}) => {
    const result = await run(executable, args, work, extra);
    if (result.stdout.trim() !== 'controlled-' + tool.id + '-ok') fail('解释器真实模块探测未返回准确结果');
  };
  if (tool.id === 'python') {
    await probe(['-I', '-c', 'import ssl,zlib,bz2,lzma,sqlite3,ctypes,json; '
      + 'assert ssl.create_default_context().verify_mode == ssl.CERT_REQUIRED; '
      + 'assert ssl.OPENSSL_VERSION.startswith('+JSON.stringify('OpenSSL '+library.tools.find(value=>value.id==='openssl').version+' ')+'); print("controlled-python-ok")'],
    { PYTHONHOME: payload });
  } else if (tool.id === 'perl') {
    const cores=perlRuntimeLibraries(await readFile(join(source,'config.sh'),'utf8'),finalPayload,payload);
    for(const path of cores) await directory(path);
    await regular(join(cores[1],'Config.pm'));
    await probe(['-MConfig', '-MJSON::PP', '-MEncode', '-MFile::Find', '-e',
      'die "Perl version" unless "$^V" eq '+JSON.stringify('v'+tool.version)+'; print "controlled-perl-ok\\n"'],
      {PERL5LIB:cores.join(':')});
  } else if (tool.id === 'ruby') {
    const versions=(await readdir(join(payload,'lib/ruby'))).filter(value=>/^\d+\.\d+\.\d+$/u.test(value));
    if(versions.length!==1)fail('Ruby核心模块版本目录缺失或不唯一');
    const base=join(payload,'lib/ruby',versions[0]); await directory(base);
    const cores=[base];
    for(const entry of await readdir(base,{withFileTypes:true})) {
      if(!entry.isDirectory()) continue;
      const marker=join(base,entry.name,'rbconfig.rb');
      try {await regular(marker);cores.push(join(base,entry.name));}
      catch(error){if(error.code!=='ENOENT')throw error;}
    }
    if(cores.length!==2) fail('Ruby ARM64核心模块目录缺失或不唯一');
    await probe(['--disable-gems', '-rrubygems', '-rpsych', '-ropenssl', '-rjson', '-e',
      'raise "Ruby version" unless RUBY_VERSION == '+JSON.stringify(tool.version)+'; '
      + 'raise "OpenSSL version" unless OpenSSL::OPENSSL_VERSION.start_with?('+JSON.stringify('OpenSSL '+library.tools.find(value=>value.id==='openssl').version+' ')+'); '
      + 'raise "libyaml missing" if Psych.libyaml_version.empty?; puts "controlled-ruby-ok"'],
      {RUBYLIB:cores.join(':'),GEM_HOME:join(payload,'lib/ruby/gems',versions[0]),GEM_PATH:join(payload,'lib/ruby/gems',versions[0])});
  }
  // 保留官方法律全文与原始源码归档；产品需要解释器运行库时可连同其原始许可一起打包。
  if (tool.archive.kind === 'native-source') {
    const legalNames = (await readdir(source)).filter(name => /^(?:COPYING|LICENSE|LICENCE|NOTICE|Artistic|COPYRIGHT|BSDL|GPL|LEGAL)(?:[._-].*)?$/iu.test(name));
    if (!legalNames.length) fail('官方工具源码缺少根许可全文');
    const directory = join(payload, 'licenses'); await mkdir(directory);
    for (const name of legalNames) {
      const file = join(source, name);
      if ((await lstat(file)).isFile()) await writeFile(join(directory, name), await readFile(file), { flag: 'wx', mode: 0o444 });
    }
    if (!(await readdir(directory)).length) fail('工具根许可必须包含真实法律文件');
  }

  if (tool.id === 'tcl') await writeFile(join(payload, 'version.tcl'), 'puts [info patchlevel]\n', { flag: 'wx', mode: 0o444 });
  // 原件与编译输入回执留在唯一工具对象；运行依赖原件仍归rely，不保留第二份Gem缓存。
  await writeFile(join(payload, tool.archive.kind === 'gem' ? 'source.gem' : 'source.archive'),
    await readFile(archive), { flag: 'wx', mode: 0o444 });
  if (upstream.length) {
    const directory = join(payload, 'upstream-patches'); await mkdir(directory);
    for (const [i, file] of upstream.entries()) await writeFile(join(directory, 'bash53-' + String(i + 1).padStart(3, '0')),
      await readFile(file), { flag: 'wx', mode: 0o444 });
    // 原件只保留在回执覆盖的payload内，清除同一安装事务产生的临时重复文件。
    for (const [i, file] of upstream.entries()) {

      await rm(file);
    }
  }

}
return {buildSourceTool,validateSourceTool};})();
const flutterRecipe=(()=>{

const execute = exec;

const digest = value => createHash('sha256').update(value).digest('hex');
const fail = message => { throw new Error('Flutter受控修订：' + message); };
const safePath = value => typeof value === 'string' && value.length > 0 && !isAbsolute(value)
  && !/[\\\x00-\x1f]/u.test(value) && value.split('/').every(part => part && part !== '.' && part !== '..');

// 产品资源阶段先验真共享工具并取得任务目录；这里只生成该任务的配置，不改共享SDK。
async function prepareFlutterTaskTools(root, work, platform, { signal, environment = {} } = {}) {
  signal?.throwIfAborted();
  if (!['android', 'ios', 'macos', 'sdk'].includes(platform)) return {};
  if (await realpath(root) !== root || await realpath(work) !== work
    || work === root || work.startsWith(root + '/') || root.startsWith(work + '/')) fail('工具任务目录不安全');
  const directory = join(work, 'flutter-tools');
  const prepareJava = async () => {
    if (!environment.JAVA_HOME) return {};
    if (!isAbsolute(environment.JAVA_HOME) || /[\r\n\x00]/u.test(environment.JAVA_HOME)) fail('受控Java路径无效');
    // Flutter的jdk-dir优先于Android Studio；配置仅写入当前任务HOME，不影响用户设置。
    await writeFile(join(work, '.flutter_settings'), JSON.stringify({ 'jdk-dir': environment.JAVA_HOME }), { flag: 'wx', mode: 0o600 });
    return { HOME: work };
  };
  if (platform === 'sdk') return prepareJava();
  if (platform !== 'android') {
    signal?.throwIfAborted();
    await mkdir(directory);
    const quote = value => "'" + value.replaceAll("'", "'\\''") + "'";
    // 使用验真rsync，额外处理其未落实的副本权限；入口不覆盖或替换系统工具。
    await writeFile(join(directory, 'rsync'), '#!'+environment.PRODUCT_BASH_BIN+'\n'
      // 验真rsync的本机接收端会经PATH再次调用rsync；协议端必须继承原始stdio，不能进入Node缓冲执行。
      + 'if [ "${1:-}" = "--server" ]; then exec '+quote(environment.PRODUCT_RSYNC_BIN)+' "$@"; fi\n'
      + 'exec ' + quote(process.execPath) + ' '
      + quote(fileURLToPath(import.meta.url)) + ' rsync "$@"\n', { flag: 'wx', mode: 0o700 });
    signal?.throwIfAborted();
    return { ...await prepareJava(), PATH: directory };
  }
  const gradleHome = environment.GRADLE_HOME;
  if (!gradleHome || !isAbsolute(gradleHome) || /[\r\n\x00]/u.test(gradleHome)) fail('Android任务缺少产品资源阶段受控Gradle');
  if (!environment.JAVA_HOME || !isAbsolute(environment.JAVA_HOME) || /[\r\n\x00]/u.test(environment.JAVA_HOME)) fail('Android任务缺少产品资源阶段受控Java');
  // 先校验唯一配置再生成插件目录；链接、双配置与错误入口都不得留下半成品。
  const candidates = [];
  for (const name of ['settings.gradle.kts', 'settings.gradle']) {
    const path = join(work, 'android', name);
    const info = await lstat(path).catch(error => { if (error.code === 'ENOENT') return null; throw error; });
    if (info) candidates.push({ path, info });
  }
  if (candidates.length !== 1) fail('Android任务必须只有一份settings配置');
  const { path: settings, info } = candidates[0];
  if (!info.isFile() || info.nlink !== 1 || info.size > 1024 * 1024 || await realpath(settings) !== settings) fail('Android任务配置不是独占普通文件');
  const handle = await open(settings, constants.O_RDWR | constants.O_NOFOLLOW);
  try {
    const opened = await handle.stat();
    if (opened.dev !== info.dev || opened.ino !== info.ino) fail('Android任务配置已被替换');
    const input = await handle.readFile('utf8');
    const pattern = /includeBuild\((["'])\$flutterSdkPath\/packages\/flutter_tools\/gradle\1\)/gu;
    if ([...input.matchAll(pattern)].length !== 1) fail('Android配置缺少唯一Flutter插件入口');
    signal?.throwIfAborted();
    const target = await prepareGradle(root, work, { signal });
    const current = await lstat(settings);
    if (await realpath(settings) !== settings || current.dev !== info.dev || current.ino !== info.ino
      || current.nlink !== 1 || await readFile(settings, 'utf8') !== input) fail('Android任务配置已被替换或修改');
    signal?.throwIfAborted();
    // 使用已核对的文件描述符写入，不能重新打开后来替换的路径。
    const content = Buffer.from(input.replace(pattern, 'includeBuild(' + JSON.stringify(target) + ')'));
    let offset = 0;
    while (offset < content.length) {
      const { bytesWritten } = await handle.write(content, offset, content.length - offset, offset);
      if (!bytesWritten) fail('Android任务配置写入未完成');
      offset += bytesWritten;
    }
    await handle.truncate(content.length);
    signal?.throwIfAborted();
  } finally { await handle.close(); }
  // Flutter固定调用工程gradlew；仅替换本任务的入口链接，不触碰源工程或共享SDK。
  const wrapper = join(work, 'android/gradlew');
  const existing = await lstat(wrapper).catch(error => { if (error.code === 'ENOENT') return null; throw error; });
  if (existing && !existing.isSymbolicLink() && (!existing.isFile() || existing.nlink !== 1)) fail('Gradle任务入口不是独占文件');
  signal?.throwIfAborted();
  if (existing) {
    const current = await lstat(wrapper);
    if (current.dev !== existing.dev || current.ino !== existing.ino) fail('Gradle任务入口已被替换');
    await rm(wrapper);
  }
  const quote = value => "'" + value.replaceAll("'", "'\\''") + "'";
  await writeFile(wrapper, '#!'+environment.PRODUCT_BASH_BIN+'\n# 只执行本产品验真的工具，不下载Wrapper分发。\nexport JAVA_HOME='
    + quote(environment.JAVA_HOME) + '\nexec '
    + quote(join(gradleHome, 'bin/gradle')) + ' "$@"\n', { flag: 'wx', mode: 0o700 });
  signal?.throwIfAborted();
  return prepareJava();
}

// 只修正受控SDK复制到本任务的framework/dSYM；不跟随链接chmod共享原件。
async function copyFlutterArtifact(args, environment = process.env, run = execute) {
  const root = environment.FLUTTER_ROOT, work = environment.PRODUCT_WORK_DIR;
  if (!root || !work || await realpath(root) !== root || await realpath(work) !== work
    || work === root || work.startsWith(root + '/') || root.startsWith(work + '/')) fail('引擎复制缺少安全任务目录');
  const source = args.at(-2), destination = args.at(-1);
  let copied;
  if (source && isAbsolute(source) && source.startsWith(root + '/')
    && /\.(?:framework|dSYM)\/?$/u.test(source)) {
    const output = resolve(destination || '.');
    if (!output.startsWith(work + '/') || await realpath(output) !== output) fail('引擎副本不属于当前任务');
    if (!safePath(relative(root, await realpath(source)))) fail('引擎原件越界');
    copied = source.endsWith('/') ? output : join(output, source.split('/').at(-1));
    const existing = await lstat(copied).catch(error => { if (error.code === 'ENOENT') return null; throw error; });
    if (existing?.isSymbolicLink()) fail('引擎目标不能是符号链接');
    // 复用目标可能含硬链接，必须在rsync写入前拒绝，不能等复制后才保护原件。
    const inspect = async path => {
      const info = await lstat(path);
      if (info.isSymbolicLink()) return;
      if (await realpath(path) !== path || (!info.isDirectory() && (!info.isFile() || info.nlink !== 1))) fail('引擎目标不是独占生成物');
      if (info.isDirectory()) for (const name of await readdir(path)) await inspect(join(path, name));
    };
    if (existing) await inspect(copied);
    if (args.some(value => ['--inplace', '--keep-dirlinks', '--copy-dirlinks', '--copy-links', '-K', '-k', '-L'].includes(value))) fail('引擎复制禁止跟随目标链接');
  }
  if(!environment.PRODUCT_RSYNC_BIN||!environment.PRODUCT_BASH_BIN)fail('缺少验真同步和Shell入口');
  const result = await run(environment.PRODUCT_RSYNC_BIN, args, { env: environment, maxBuffer: 8 * 1024 * 1024 });
  if (copied) {
    const writable = async path => {
      const info = await lstat(path);
      if (info.isSymbolicLink()) {
        if (path === copied) fail('引擎目标已被替换为链接');
        return;
      }
      if (await realpath(path) !== path || (!info.isDirectory() && (!info.isFile() || info.nlink !== 1))) fail('引擎副本不是独占生成物');
      // 持有无跟随描述符并核对inode，chmod不重新打开可能已被替换的路径。
      const handle = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW);
      try {
        const current = await handle.stat();
        if (current.dev !== info.dev || current.ino !== info.ino || await realpath(path) !== path) fail('引擎副本路径已被替换');
        await handle.chmod((current.mode & 0o777) | 0o200);
      } finally { await handle.close(); }
      if (info.isDirectory()) for (const name of await readdir(path)) await writable(join(path, name));
    };
    await writable(copied);
  }
  return result;
}



// 调用方先取得SDK入口并占有本端工作目录；这里只生成Gradle配置，不复制SDK或业务源码。
async function prepareGradle(root, work, { signal } = {}) {
  signal?.throwIfAborted();
  if (!isAbsolute(root) || !isAbsolute(work) || await realpath(root) !== root || await realpath(work) !== work
    || work === root || work.startsWith(root + '/') || root.startsWith(work + '/')) fail('Gradle工作目录必须独立于SDK原件');
  const sdk = join(root, 'packages/flutter_tools/gradle');
  const source = join(sdk, 'src');
  if (await realpath(source) !== source || !(await lstat(source)).isDirectory()) fail('Gradle源码必须位于SDK原件内');
  const files = [];
  for (const name of ['settings.gradle.kts', 'build.gradle.kts']) {
    const path = join(sdk, name), info = await lstat(path);
    if (!info.isFile() || info.size > 1024 * 1024 || await realpath(path) !== path) fail('Gradle配置不是SDK内受限普通文件');
    files.push([name, await readFile(path)]);
  }
  files.push(['gradle.properties', Buffer.from('# Kotlin只在本任务Gradle进程编译，不创建用户目录守护进程状态。\n'
    + 'kotlin.compiler.execution.strategy=in-process\nkotlin.daemon.useFallbackStrategy=false\n')]);
  const directory = join(work, 'flutter-gradle');
  // mkdir排他创建，已有目录不属于本次准备，禁止接管或清理。
  signal?.throwIfAborted();
  await mkdir(directory, { mode: 0o700 });
  const identity = await lstat(directory);
  const assertDirectory = async () => {
    const current = await lstat(directory);
    if (await realpath(directory) !== directory || current.dev !== identity.dev || current.ino !== identity.ino) fail('Gradle配置目录已被替换，保留现场');
  };
  try {
    for (const [name, content] of files) {
      signal?.throwIfAborted();
      await assertDirectory();
      const handle = await open(join(directory, name), 'wx', 0o600);
      try { await handle.writeFile(content); } finally { await handle.close(); }
    }
    await assertDirectory();
    signal?.throwIfAborted();
    await symlink(source, join(directory, 'src'), 'dir');
    signal?.throwIfAborted();
    return directory;
  } catch (error) {
    await assertDirectory();
    await rm(directory, { recursive: true });
    throw error;
  }
}

function flutterEnvironment(root, env) {
  const work = env.PRODUCT_WORK_DIR;
  const result = { ...env, HOME: work, USERPROFILE: work, TMPDIR: work,
    XDG_CONFIG_HOME: join(work, 'config'), XDG_CACHE_HOME: join(work, 'cache'),
    PUB_CACHE: join(root, 'bin/cache/pub'), BOT: 'true', FLUTTER_ROOT: root,
    // 官方开关在AI环境也返回NoOpAnalytics，防止首次提示混入机器JSON。
    FLUTTER_SUPPRESS_ANALYTICS: 'true' };
  for (const name of ['FLUTTER_ALREADY_LOCKED', 'FLUTTER_TOOL_ARGS', 'FLUTTER_HOST', 'PUB_HOSTED_URL', 'FLUTTER_STORAGE_BASE_URL']) delete result[name];
  return result;
}

// Windows直接执行SDK自带Dart与快照，避免Node把批处理文件当作原生可执行文件。
function flutterCommand(root, args, platform = process.platform) {
  const path = platform === 'win32' ? win32 : posix;
  if (!['win32', 'darwin', 'linux'].includes(platform)) fail('不支持的Flutter宿主');
  return platform === 'win32'
    ? [path.join(root, 'bin/cache/dart-sdk/bin/dart.exe'),
      [path.join(root, 'bin/cache/flutter_tools.snapshot'), ...args]]
    : [path.join(root, 'bin/flutter'), args];
}



// 补丁只接受完整基线与结果摘要；行号、上下文任一不符都拒绝，不做模糊匹配。
function parsePatch(text) {
  if (!text) fail('补丁为空');
  if (typeof text !== 'string' || !text.endsWith('\n')) fail('补丁必须完整换行结束');
  const lines = text.split('\n');
  const files = []; let at = 0;
  while (at < lines.length && !lines[at].startsWith('diff --git ')) {
    if (lines[at] && !lines[at].startsWith('#')) fail('补丁头部存在未登记内容');
    at++;
  }
  while (at < lines.length - 1) {
    const header = /^diff --git a\/(\S+) b\/(\S+)$/u.exec(lines[at++]);
    if (!header || header[1] !== header[2] || !safePath(header[1])) fail('补丁文件路径无效');
    const path = header[1];
    if (files.some(file => file.path === path)) fail('补丁文件重复');
    const hashes = /^index ([a-f0-9]{64})\.\.([a-f0-9]{64})$/u.exec(lines[at++]);
    if (!hashes || lines[at++] !== '--- a/' + path || lines[at++] !== '+++ b/' + path) fail('缺少完整文件摘要');
    const hunks = [];
    while (at < lines.length - 1 && !lines[at].startsWith('diff --git ')) {
      const hunk = /^@@ -(\d+),(\d+) \+(\d+),(\d+) @@$/u.exec(lines[at++]);
      if (!hunk) fail('补丁区块格式错误');
      const old = [], next = [];
      while (at < lines.length - 1 && /^[ +\-]/u.test(lines[at])) {
        const line = lines[at++];
        if (line[0] !== '+') old.push(line.slice(1));
        if (line[0] !== '-') next.push(line.slice(1));
      }
      if (old.length !== Number(hunk[2]) || next.length !== Number(hunk[4])) fail('补丁区块行数错误');
      hunks.push({ oldLine: Number(hunk[1]), nextLine: Number(hunk[3]), old, next });
    }
    if (!hunks.length) fail('补丁文件没有改动区块');
    files.push({ path, before: hashes[1], after: hashes[2], hunks });
  }
  if (!files.length) fail('补丁为空');
  return files;
}

function transformFile(input, file) {

  const lines = input.toString('utf8').split('\n');
  if (lines.pop() !== '') fail('源码必须使用末尾换行');
  const result = []; let cursor = 0;
  for (const hunk of file.hunks) {
    const offset = hunk.oldLine === 0 ? 0 : hunk.oldLine - 1;
    if (offset < cursor || offset > lines.length) fail('补丁区块重叠或越界');
    result.push(...lines.slice(cursor, offset));
    if ((hunk.nextLine === 0 ? 0 : hunk.nextLine - 1) !== result.length
      || JSON.stringify(lines.slice(offset, offset + hunk.old.length)) !== JSON.stringify(hunk.old)) fail('补丁上下文不符');
    result.push(...hunk.next); cursor = offset + hunk.old.length;
  }
  result.push(...lines.slice(cursor));
  const output = Buffer.from(result.join('\n') + '\n');

  return output;
}

async function readPatch(root, patch) {
  if (!patch || !safePath(patch.path) || !/^[a-f0-9]{64}$/u.test(patch.sha256)
    || !/^https:\/\/github\.com\/flutter\/flutter\/commit\/[a-f0-9]{40}$/u.test(patch.source)) fail('修订登记不完整');
  const path = join(root, patch.path);
  if (!(await lstat(path)).isFile() || await realpath(path) !== path) fail('补丁必须为库内普通文件');
  const input = await readFile(path);

  return parsePatch(input.toString('utf8'));
}

// 只在受控安装器独占的候选对象中准备；应用阶段不允许产品重新生成SDK快照。
async function prepareFlutter(root, { tool, files, env, signal, run = execute }) {
  root = resolve(root);
  if (await realpath(root) !== root || !env?.PRODUCT_WORK_DIR) fail('准备环境不完整');
  const work = resolve(env.PRODUCT_WORK_DIR);
  if (await realpath(work) !== work || work === root || work.startsWith(root + sep)) fail('准备状态不能写入SDK原件');
  const cache = join(root, 'bin/cache');
  const version = JSON.parse(await readFile(join(cache, 'flutter.version.json'), 'utf8'));

  await applyPatch(root, files);
  await prepareFlutterSnapshot(root, { tool, files, env, signal, run });
}

// 安装候选的所有源码必须达到唯一目标后才重建快照；已安装原件不得原位修订。
async function prepareFlutterSnapshot(root, { tool, files, env, signal, run = execute, offline = false }) {
  root = resolve(root);
  const work = env?.PRODUCT_WORK_DIR && resolve(env.PRODUCT_WORK_DIR);
  if (await realpath(root) !== root || !work || await realpath(work) !== work
    || work === root || work.startsWith(root + sep)) fail('准备状态不能写入SDK原件');
  const cache = join(root, 'bin/cache');
  const version = JSON.parse(await readFile(join(cache, 'flutter.version.json'), 'utf8'));

  if (!Array.isArray(files) || !files.length) fail('快照缺少完整修订输入');
  for (const file of files) {
    const path = join(root, file.path);

  }
  const tools = join(root, 'packages/flutter_tools');
  const dart = join(cache, 'dart-sdk/bin', process.platform === 'win32' ? 'dart.exe' : 'dart');
  const lock = await readFile(join(tools, 'pubspec.lock'));
  const environment = flutterEnvironment(root, env);
  // 现有验真对象维护使用离线缓存；首次Runner准备仍由正式Pub按锁获取工具依赖。
  await run(dart, ['pub', 'get', '--enforce-lockfile', '--no-precompile', ...(offline ? ['--offline'] : [])], {
    cwd: tools, env: environment, signal, timeout: 600_000, maxBuffer: 2 * 1024 * 1024,
  });
  if (!(await readFile(join(tools, 'pubspec.lock'))).equals(lock)) fail('工具依赖锁文件被改变');
  const configPath = join(tools, '.dart_tool/package_config.json');
  // Pub生成配置后再校验真实位置，不能沿着符号链接改写当前候选之外的文件。
  if (!(await lstat(configPath)).isFile() || await realpath(configPath) !== configPath) fail('Dart包配置不是候选内普通文件');
  const config = JSON.parse(await readFile(configPath, 'utf8'));
  if (!Array.isArray(config.packages) || !config.packages.length) fail('Dart包配置不完整');
  // 候选对象最终会原位改名；包地址全部改为对象内部相对地址，不保留准备目录绝对路径。
  for (const item of config.packages) {
    const path = fileURLToPath(new URL(item.rootUri, pathToFileURL(configPath)));
    const canonical = await realpath(path);
    if (!canonical.startsWith(root + sep)) fail('工具依赖指向共享对象之外');
    item.rootUri = relative(dirname(configPath), canonical).split(sep).map(encodeURIComponent).join('/') + '/';
  }
  const handle = await open(configPath, 'w');
  try { await handle.writeFile(JSON.stringify(config)); } finally { await handle.close(); }
  const snapshot = join(cache, 'flutter_tools.snapshot');
  // 旧快照属于尚未发布的当前候选，必须删除后由修订源码重新产生，失败不保留可运行旧工具。
  await rm(snapshot, { force: true });
  await run(dart, ['--snapshot=' + snapshot, '--snapshot-kind=app-jit', '--packages=' + configPath,
    join(tools, 'bin/flutter_tools.dart'), '--version', '--machine'], {
    cwd: work, env: environment, signal, timeout: 300_000, maxBuffer: 2 * 1024 * 1024,
  });
  if (!(await lstat(snapshot)).isFile() || !(await lstat(snapshot)).size) fail('修订快照没有生成');

}

async function applyPatch(root, files) {
  root = resolve(root);
  if (await realpath(root) !== root || !(await lstat(root)).isDirectory()) fail('准备目录不安全');
  const lockPath = join(root, 'flutter.lock');
  const lock = await open(lockPath, 'wx', 0o600);
  try {
    const prepared = [];
    for (const file of files) {
      if (!safePath(file.path)) fail('源码路径越界');
      const path = join(root, file.path);
      if (!(await lstat(path)).isFile() || await realpath(path) !== path) fail('源码不是准备目录内的普通文件');
      prepared.push({ path, output: transformFile(await readFile(path), file) });
    }
    for (const { path, output } of prepared) {
      const temporary = path + '.pending'; let owned = false;
      try {
        const handle = await open(temporary, 'wx', 0o600); owned = true;
        try { await handle.writeFile(output); await handle.sync(); } finally { await handle.close(); }
        await rename(temporary, path); owned = false;
      } finally { if (owned) await rm(temporary); }
    }
  } finally { await lock.close(); await rm(lockPath); }
}

return {prepareFlutterTaskTools,copyFlutterArtifact,parsePatch,prepareFlutter};})();
const appleSystemTools = Object.freeze({
  codesign: '/usr/bin/codesign', security: '/usr/bin/security',
  xcrun: '/usr/bin/xcrun', 'xcode-select': '/usr/bin/xcode-select',
  xattr: '/usr/bin/xattr',
});
const appleBundleTools = new Set([
  'xcodebuild', 'make', 'clang', 'clang++', 'swift', 'swiftc', 'ar', 'ld', 'as', 'nm', 'ranlib', 'strip', 'lipo', 'libtool',
  'otool', 'install_name_tool', 'codesign_allocate', 'devicectl', 'xctrace', 'actool', 'ibtool', 'notarytool', 'llvm-nm',
]);
// 资源预解析只服从产品显式离线参数，任务上下文不改变联网策略。
function gradleOfflineArguments(options={}){return options.offline===true?['--offline']:[];}
// Apple工具由本机选择入口直接交付，不执行资源签名或版本复验。
async function appleTools(library,{names=['xcodebuild'],signal,run=exec,environment=process.env}={}){
  const wanted=library.tools.find(tool=>tool.id==='xcode');if(!wanted||!Array.isArray(names)||names.some(name=>!appleBundleTools.has(name)&&!Object.hasOwn(appleSystemTools,name)))fail('Apple工具需求无效');
  // 任务上下文仅跟踪进程；Apple工具由本产品既有本机解析入口提供。
  const env=cleanEnvironment(environment),developerDirectory=(await run('/usr/bin/xcode-select',['-p'],{env,signal})).stdout.trim();await directory(developerDirectory);
  const tools={};for(const name of names){
   const system=appleSystemTools[name],path=system||(name==='xcodebuild'?join(developerDirectory,'usr/bin/xcodebuild'):(await run('/usr/bin/xcrun',['--find',name],{env:{...env,DEVELOPER_DIR:developerDirectory},signal})).stdout.trim());
   if(system){await regular(path);tools[name]=await realpath(path);continue;}
   // Xcode的clang++、ranlib等入口本身可为包内链接；普通资源regular规则不变。
   if(!isAbsolute(path)||resolve(path)!==path||/[\x00-\x1f\x7f]/u.test(path)||!inside(developerDirectory,path)||basename(path)!==name)fail('Apple工具入口不属于所选Xcode');
   const entry=await lstat(path);if(!entry.isFile()&&!entry.isSymbolicLink())fail('Apple工具入口不是文件或链接');
   const parent=await realpath(dirname(path)),target=await realpath(path);
   if(!inside(developerDirectory,parent)||!inside(developerDirectory,target))fail('Apple工具目标不属于所选Xcode');
   await directory(parent);const executable=await regular(target);
   if(!(executable.mode&0o111)||await realpath(path)!==target)fail('Apple工具不可执行或入口漂移');
   // 保留原入口名称；把CXX改为clang真实路径会丢失clang++驱动语义。
   tools[name]=path;
  }
  return {developerDirectory,version:wanted.version,tools};
 }


// 针对性回归只使用本轮目录和模拟选择器，不启动Xcode或资源准备。
if(process.env.NODE_TEST_CONTEXT&&process.argv.length===2&&process.argv[1]===import.meta.filename)inlineTestRegistrations.push(async()=>{
 const {test}=await import('node:test'),{default:assert}=await import('node:assert/strict');
 const {mkdir,mkdtemp,writeFile,rm}=await import('node:fs/promises');
 test('任务上下文中的Apple工具仍由产品解析，选择器原始错误保留',async t=>{
  await mkdir(testRoot(),{recursive:true});const work=await realpath(await mkdtemp(join(testRoot(),'apple-context-')));t.after(()=>rm(work,{recursive:true,force:true}));
  const developer=join(work,'Developer');await mkdir(join(developer,'usr/bin'),{recursive:true});
  const executable=join(developer,'usr/bin/xcodebuild');await writeFile(executable,'synthetic',{mode:0o755});
  const library={tools:[{id:'xcode',version:'fixture'}]},calls=[];
  const run=async(command,args)=>{calls.push([command,args]);return {stdout:developer+'\n'};};
  const result=await resourceSupplies.run({work},()=>appleTools(library,{run}));
  assert.equal(result.tools.xcodebuild,executable);assert.deepEqual(calls,[['/usr/bin/xcode-select',['-p']]]);
  const original=Error('synthetic Apple selector failure');
  await assert.rejects(resourceSupplies.run({work},()=>appleTools(library,{run:async()=>{throw original;}})),error=>error===original);
  await assert.rejects(appleTools(library,{names:['undeclared'],run}),/Apple工具需求无效/u);
await resourceSupplies.run({work},async()=>{assert.deepEqual(gradleOfflineArguments({offline:false}),[]);assert.deepEqual(gradleOfflineArguments({offline:true}),['--offline']);assert.deepEqual(gradleOfflineArguments(),[]);});
 });
 test('Apple工具允许同一Xcode内部链接并保留clang++和ranlib原调用名称',async t=>{
  await mkdir(testRoot(),{recursive:true});const work=await realpath(await mkdtemp(join(testRoot(),'apple-links-')));t.after(()=>rm(work,{recursive:true,force:true}));
  const developer=join(work,'Developer'),bin=join(developer,'usr/bin');await mkdir(bin,{recursive:true});
  for(const name of ['clang','libtool'])await writeFile(join(bin,name),'synthetic',{mode:0o755});
  await symlink('clang',join(bin,'clang++'));await symlink('libtool',join(bin,'ranlib'));
  const calls=[],run=async(command,args,options)=>{calls.push([command,args,options.env.DEVELOPER_DIR]);return {stdout:(command==='/usr/bin/xcode-select'?developer:join(bin,args[1]))+'\n'};};
  const result=await appleTools({tools:[{id:'xcode',version:'fixture'}]},{names:['clang++','ranlib'],run});
  assert.equal(result.tools['clang++'],join(bin,'clang++'));assert.equal(result.tools.ranlib,join(bin,'ranlib'));
  assert.equal(await realpath(result.tools['clang++']),join(bin,'clang'));assert.equal(await realpath(result.tools.ranlib),join(bin,'libtool'));
  assert.deepEqual(calls.slice(1),[['/usr/bin/xcrun',['--find','clang++'],developer],['/usr/bin/xcrun',['--find','ranlib'],developer]]);
  await assert.rejects(regular(join(bin,'clang++')),/非独占普通文件/);
 });
 test('Apple工具拒绝包外入口、外链、断链、目录、不可执行目标及异常选择器路径',async t=>{
  await mkdir(testRoot(),{recursive:true});const work=await realpath(await mkdtemp(join(testRoot(),'apple-invalid-')));t.after(()=>rm(work,{recursive:true,force:true}));
  const developer=join(work,'Developer'),bin=join(developer,'usr/bin'),outside=join(work,'outside');await mkdir(bin,{recursive:true});await mkdir(outside);
  const foreign=join(outside,'clang++');await writeFile(foreign,'synthetic',{mode:0o755});
  const cases=['outside','external','broken','directory','noexec','wrong-name','relative','control'];
  for(const mode of cases){
   const folder=join(bin,mode);await mkdir(folder);let path=join(folder,'clang++');
   if(mode==='outside')path=foreign;
   else if(mode==='external')await symlink(foreign,path);
   else if(mode==='broken')await symlink('missing',path);
   else if(mode==='directory')await mkdir(path);
   else if(mode==='noexec')await writeFile(path,'synthetic',{mode:0o644});
   else if(mode==='wrong-name'){path=join(folder,'clang');await writeFile(path,'synthetic',{mode:0o755});}
   else if(mode==='relative')path='relative/clang++';
   else path=join(folder,'bad\u0001','clang++');
   const run=async command=>({stdout:(command==='/usr/bin/xcode-select'?developer:path)+'\n'});
   await assert.rejects(appleTools({tools:[{id:'xcode',version:'fixture'}]},{names:['clang++'],run}),error=>mode==='broken'?error.code==='ENOENT':/Apple工具/.test(error.message),mode);
  }
 });
});

const toolDefinitions=[{"id":"cmake","title":"CMake","version":"3.31.6","source":"https://cmake.org/download/","command":"cmake","archive":null,"archives":{"macos":{"url":"https://dl.google.com/android/repository/cmake-3.31.6-darwin.zip","sha256":"861a219b872cd0d9aee282b617fe3bd32f83925db3a0d28fd45d0553452e903a","root":"."},"linux-arm":{"url":"https://github.com/Kitware/CMake/releases/download/v3.31.6/cmake-3.31.6-linux-aarch64.tar.gz","sha256":"b4cc788d63112b2749b40627e719eb5d3b8ed8f00c36d77189f4019cfe64bc9e","root":"cmake-3.31.6-linux-aarch64"},"linux-amd":{"url":"https://dl.google.com/android/repository/cmake-3.31.6-linux.zip","sha256":"ce136bb4b02580b36e53d9ccfe5275069655e6ef7d46d6fe2fcf88cfdf8fb761","root":"."},"windows":{"url":"https://dl.google.com/android/repository/cmake-3.31.6-windows.zip","sha256":"dd54cc866afbd2cfc46189dd4864cdfb5bf8e2a34ec56e80188da0a138567b5e","root":"."}},"managed":false,"requires":[]},{"id":"git","title":"Git","version":"2.54.0","source":"https://git-scm.com/download/mac","command":"git","archive":{"url":"https://www.kernel.org/pub/software/scm/git/git-2.54.0.tar.xz","sha256":"f689162364c10de79ef89aa8dbf48731eb057e34edbbd20aca510ce0154681a3","root":"git-2.54.0","executable":"bin/git","kind":"native-source"},"managed":true,"requires":["node","xcode","perl","python","gettext"]},{"id":"node","title":"Node.js","version":"25.2.1","source":"https://nodejs.org/dist/v25.2.1/SHASUMS256.txt","command":"node","archives":{"linux-arm":{"url":"https://nodejs.org/dist/v25.2.1/node-v25.2.1-linux-arm64.tar.xz","sha256":"75f910b5234d3ee324ceebcf41e2c3c221c4c2225463a02ecd685b884155e0f6","root":"node-v25.2.1-linux-arm64"},"linux-amd":{"url":"https://nodejs.org/dist/v25.2.1/node-v25.2.1-linux-x64.tar.xz","sha256":"b9f6a97e81c89a9df45526b4f86dafdccaf12b82295f7bf35bdb2b0f5e68744f","root":"node-v25.2.1-linux-x64"},"windows":{"url":"https://nodejs.org/dist/v25.2.1/node-v25.2.1-win-x64.zip","sha256":"f97ba75ead7720652f3925d9cf8661e083a28c6b98ea77acc83903d77a9dd688","root":"node-v25.2.1-win-x64"}},"archive":{"url":"https://nodejs.org/dist/v25.2.1/node-v25.2.1-darwin-arm64.tar.gz","sha256":"be87e21bd235a451fad02c89e5bf7cb17e206e4cd89dd5664f20d19e7dfde6f9","root":"node-v25.2.1-darwin-arm64","executable":"bin/node","kind":"extract"},"managed":true,"requires":[]},{"id":"python","title":"Python","version":"3.14.3","source":"https://www.python.org/downloads/macos/","command":"python3","archive":{"url":"https://www.python.org/ftp/python/3.14.3/Python-3.14.3.tar.xz","sha256":"a97d5549e9ad81fe17159ed02c68774ad5d266c72f8d9a0b5a9c371fe85d902b","root":"Python-3.14.3","executable":"bin/python3.14","kind":"native-source"},"managed":true,"requires":["node","xcode","openssl"],"dependencies":[{"name":"xz","version":"5.8.2","url":"https://github.com/tukaani-project/xz/releases/download/v5.8.2/xz-5.8.2.tar.xz","sha256":"890966ec3f5d5cc151077879e157c0593500a522f413ac50ba26d22a9a145214","root":"xz-5.8.2"}]},{"id":"rust","title":"Rust","version":"1.97.1","source":"https://static.rust-lang.org/dist/channel-rust-1.97.1.toml","command":"rustc","archive":{"url":"https://static.rust-lang.org/dist/2026-07-16/rust-1.97.1-aarch64-apple-darwin.tar.xz","sha256":"c9748cc86107734a2a024069908a895de7caa2d37062fb641eef9f756938ace2","root":"rust-1.97.1-aarch64-apple-darwin","executable":"bin/rustc","kind":"rust"},"components":[{"target":"aarch64-linux-android","url":"https://static.rust-lang.org/dist/2026-07-16/rust-std-1.97.1-aarch64-linux-android.tar.xz","sha256":"d664a49fb80d125d68f779112aa97d2a3f5def5f807a35540aa77fce0b350c4f","root":"rust-std-1.97.1-aarch64-linux-android"},{"target":"aarch64-apple-ios","url":"https://static.rust-lang.org/dist/2026-07-16/rust-std-1.97.1-aarch64-apple-ios.tar.xz","sha256":"1d58e856a295852a419f92445fe6b3db268049eb6222a672d52c52de52f36631","root":"rust-std-1.97.1-aarch64-apple-ios"},{"target":"aarch64-apple-ios-sim","url":"https://static.rust-lang.org/dist/2026-07-16/rust-std-1.97.1-aarch64-apple-ios-sim.tar.xz","sha256":"3deb094abb0f7382aad761b8e1e89cebd68bec0591d39e313330ef709b99f6e4","root":"rust-std-1.97.1-aarch64-apple-ios-sim"},{"target":"aarch64-unknown-linux-gnu","url":"https://static.rust-lang.org/dist/2026-07-16/rust-std-1.97.1-aarch64-unknown-linux-gnu.tar.xz","sha256":"46aed8e63186350004d8ec6afca798811e6530b514352e5a8a26f3dc4939b3be","root":"rust-std-1.97.1-aarch64-unknown-linux-gnu"},{"target":"wasm32-unknown-unknown","url":"https://static.rust-lang.org/dist/2026-07-16/rust-std-1.97.1-wasm32-unknown-unknown.tar.xz","sha256":"fa0edb6e9f34faae5735554d62d50875eded839dc707d0f1c01467a918d8453b","root":"rust-std-1.97.1-wasm32-unknown-unknown"}],"managed":true,"requires":[]},{"id":"flutter","title":"Flutter","version":"3.47.2","source":"https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json","command":"flutter","archive":{"url":"https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.47.2-stable.zip","sha256":"f456fd6733053d9301828a2e702d6cbec872923126809aa8c48eb0a696d6cc01","root":"flutter","executable":"bin/flutter","kind":"extract"},"patch":{"path":"flutter.patch","sha256":"76ef76ca73b2b00423009bd7ebca62f23026e2c9d411504324d2c8ff64da4657","source":"https://github.com/flutter/flutter/commit/d3b14c876900e553bc736ca19295fc09e3853e8e"},"managed":true,"requires":[]},{"id":"java","title":"Java (Temurin)","version":"17.0.20.1","source":"https://api.adoptium.net/v3/assets/feature_releases/17/ga?architecture=aarch64&image_type=jdk&os=mac","command":"java","archive":{"url":"https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20.1%2B1/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.20.1_1.tar.gz","sha256":"196d13ba5f10414bef7f6a05a9b3f00edacb18ebacef2b99485db9e2ee18f0e8","root":"jdk-17.0.20.1+1","executable":"Contents/Home/bin/java","kind":"extract"},"managed":true,"requires":[]},{"id":"gradle","title":"Gradle","version":"9.1.0","source":"https://services.gradle.org/distributions/gradle-9.1.0-bin.zip.sha256","command":"gradle","archive":{"url":"https://services.gradle.org/distributions/gradle-9.1.0-bin.zip","sha256":"a17ddd85a26b6a7f5ddb71ff8b05fc5104c0202c6e64782429790c933686c806","root":"gradle-9.1.0","executable":"bin/gradle","kind":"extract"},"managed":true,"requires":["java"]},{"id":"android","title":"Android SDK","version":"37.0.1","source":"https://developer.android.com/studio","command":"adb","archive":null,"managed":false,"requires":[]},{"id":"android-sdk","title":"Android SDK Manager","version":"22.0","source":"https://developer.android.com/tools/sdkmanager","command":"sdkmanager","archive":null,"managed":false,"requires":[]},{"id":"android-ndk","title":"Android NDK","version":"28.2.13676358","source":"https://developer.android.com/ndk/downloads","command":"ndk-build","archive":null,"managed":false,"requires":[]},{"id":"cocoapods","title":"CocoaPods","version":"1.17.0","source":"https://cocoapods.org","command":"pod","archive":{"url":"https://rubygems.org/downloads/cocoapods-1.17.0.gem","sha256":"dacf6f11ac3b00d60e6dd326485b616935230aacf95f385d145db27bfdf284af","root":".","executable":"bin/pod","kind":"gem"},"managed":true,"requires":["node","xcode","ruby","git"],"dependencies":[{"name":"CFPropertyList","version":"3.0.8","url":"https://rubygems.org/downloads/CFPropertyList-3.0.8.gem","sha256":"2c99d0d980536d3d7ab252f7bd59ac8be50fbdd1ff487c98c949bb66bb114261"},{"name":"activesupport","version":"6.1.7.10","url":"https://rubygems.org/downloads/activesupport-6.1.7.10.gem","sha256":"3f8e1f787a7bfbf765959ba509ef70af8293b35cb864078919365a12bf33d470"},{"name":"addressable","version":"2.9.0","url":"https://rubygems.org/downloads/addressable-2.9.0.gem","sha256":"7fdf6ac3660f7f4e867a0838be3f6cf722ace541dd97767fa42bc6cfa980c7af"},{"name":"algoliasearch","version":"1.27.5","url":"https://rubygems.org/downloads/algoliasearch-1.27.5.gem","sha256":"26c1cddf3c2ec4bd60c148389e42702c98fdac862881dc6b07a4c0b89ffec853"},{"name":"atomos","version":"0.1.3","url":"https://rubygems.org/downloads/atomos-0.1.3.gem","sha256":"7d43b22f2454a36bace5532d30785b06de3711399cb1c6bf932573eda536789f"},{"name":"base64","version":"0.3.0","url":"https://rubygems.org/downloads/base64-0.3.0.gem","sha256":"27337aeabad6ffae05c265c450490628ef3ebd4b67be58257393227588f5a97b"},{"name":"claide","version":"1.1.0","url":"https://rubygems.org/downloads/claide-1.1.0.gem","sha256":"6d3c5c089dde904d96aa30e73306d0d4bd444b1accb9b3125ce14a3c0183f82e"},{"name":"cocoapods-core","version":"1.17.0","url":"https://rubygems.org/downloads/cocoapods-core-1.17.0.gem","sha256":"a9e3d0dd36ab1b48935236d77a15cad9171217f13c6010c8e2ae3c0f455daf5b"},{"name":"cocoapods-deintegrate","version":"1.0.5","url":"https://rubygems.org/downloads/cocoapods-deintegrate-1.0.5.gem","sha256":"517c2a448ef563afe99b6e7668704c27f5de9e02715a88ee9de6974dc1b3f6a2"},{"name":"cocoapods-downloader","version":"2.1","url":"https://rubygems.org/downloads/cocoapods-downloader-2.1.gem","sha256":"bb6ebe1b3966dc4055de54f7a28b773485ac724fdf575d9bee2212d235e7b6d1"},{"name":"cocoapods-plugins","version":"1.0.0","url":"https://rubygems.org/downloads/cocoapods-plugins-1.0.0.gem","sha256":"725d17ce90b52f862e73476623fd91441b4430b742d8a071000831efb440ca9a"},{"name":"cocoapods-search","version":"1.0.1","url":"https://rubygems.org/downloads/cocoapods-search-1.0.1.gem","sha256":"1b133b0e6719ed439bd840e84a1828cca46425ab73a11eff5e096c3b2df05589"},{"name":"cocoapods-trunk","version":"1.6.0","url":"https://rubygems.org/downloads/cocoapods-trunk-1.6.0.gem","sha256":"5f5bda8c172afead48fa2d43a718cf534b1313c367ba1194cebdeb9bfee9ed31"},{"name":"cocoapods-try","version":"1.2.0","url":"https://rubygems.org/downloads/cocoapods-try-1.2.0.gem","sha256":"145b946c6e7747ed0301d975165157951153d27469e6b2763c83e25c84b9defe"},{"name":"colored2","version":"3.1.2","url":"https://rubygems.org/downloads/colored2-3.1.2.gem","sha256":"b13c2bd7eeae2cf7356a62501d398e72fde78780bd26aec6a979578293c28b4a"},{"name":"concurrent-ruby","version":"1.3.7","url":"https://rubygems.org/downloads/concurrent-ruby-1.3.7.gem","sha256":"4412caec3a5ea2e5fdc52076724c071a81f2c0593d83b2ac8cbb8ca63b3151b0"},{"name":"ethon","version":"0.18.0","url":"https://rubygems.org/downloads/ethon-0.18.0.gem","sha256":"b598afc9f30448cb068b850714b7d6948e941476095d04f90a4ac65b8d6efcb2"},{"name":"ffi","version":"1.17.4","url":"https://rubygems.org/downloads/ffi-1.17.4.gem","sha256":"bcd1642e06f0d16fc9e09ac6d49c3a7298b9789bcb58127302f934e437d60acf"},{"name":"fourflusher","version":"2.3.1","url":"https://rubygems.org/downloads/fourflusher-2.3.1.gem","sha256":"1b3de61c7c791b6a4e64f31e3719eb25203d151746bb519a0292bff1065ccaa9"},{"name":"fuzzy_match","version":"2.0.4","url":"https://rubygems.org/downloads/fuzzy_match-2.0.4.gem","sha256":"b5de4f95816589c5b5c3ad13770c0af539b75131c158135b3f3bbba75d0cfca5"},{"name":"gh_inspector","version":"1.1.3","url":"https://rubygems.org/downloads/gh_inspector-1.1.3.gem","sha256":"04cca7171b87164e053aa43147971d3b7f500fcb58177698886b48a9fc4a1939"},{"name":"httpclient","version":"2.9.0","url":"https://rubygems.org/downloads/httpclient-2.9.0.gem","sha256":"4b645958e494b2f86c2f8a2f304c959baa273a310e77a2931ddb986d83e498c8"},{"name":"i18n","version":"1.14.8","url":"https://rubygems.org/downloads/i18n-1.14.8.gem","sha256":"285778639134865c5e0f6269e0b818256017e8cde89993fdfcbfb64d088824a5"},{"name":"json","version":"2.20.0","url":"https://rubygems.org/downloads/json-2.20.0.gem","sha256":"9362bc6e55a952b056abf9167cf053358181c904cb70cd6eee0808ea830fc32b"},{"name":"logger","version":"1.7.0","url":"https://rubygems.org/downloads/logger-1.7.0.gem","sha256":"196edec7cc44b66cfb40f9755ce11b392f21f7967696af15d274dde7edff0203"},{"name":"minitest","version":"5.26.1","url":"https://rubygems.org/downloads/minitest-5.26.1.gem","sha256":"f16a63d4278e230bba342c3bda3006a69c5216d46461b77dd57f7c7c529b5a96"},{"name":"molinillo","version":"0.8.0","url":"https://rubygems.org/downloads/molinillo-0.8.0.gem","sha256":"efbff2716324e2a30bccd3eba1ff3a735f4d5d53ffddbc6a2f32c0ca9433045d"},{"name":"mutex_m","version":"0.3.0","url":"https://rubygems.org/downloads/mutex_m-0.3.0.gem","sha256":"cfcb04ac16b69c4813777022fdceda24e9f798e48092a2b817eb4c0a782b0751"},{"name":"nanaimo","version":"0.4.0","url":"https://rubygems.org/downloads/nanaimo-0.4.0.gem","sha256":"faf069551bab17f15169c1f74a1c73c220657e71b6e900919897a10d991d0723"},{"name":"nap","version":"1.1.0","url":"https://rubygems.org/downloads/nap-1.1.0.gem","sha256":"949691660f9d041d75be611bb2a8d2fd559c467537deac241f4097d9b5eea576"},{"name":"netrc","version":"0.11.0","url":"https://rubygems.org/downloads/netrc-0.11.0.gem","sha256":"de1ce33da8c99ab1d97871726cba75151113f117146becbe45aa85cb3dabee3f"},{"name":"nkf","version":"0.3.0","url":"https://rubygems.org/downloads/nkf-0.3.0.gem","sha256":"357a8dbeba38b727b75930f665146546076a394a1c243faf634ff176e3588895"},{"name":"public_suffix","version":"4.0.7","url":"https://rubygems.org/downloads/public_suffix-4.0.7.gem","sha256":"8be161e2421f8d45b0098c042c06486789731ea93dc3a896d30554ee38b573b8"},{"name":"rexml","version":"3.4.4","url":"https://rubygems.org/downloads/rexml-3.4.4.gem","sha256":"19e0a2c3425dfbf2d4fc1189747bdb2f849b6c5e74180401b15734bc97b5d142"},{"name":"ruby-macho","version":"4.1.0","url":"https://rubygems.org/downloads/ruby-macho-4.1.0.gem","sha256":"23dab37f7de0fe1e14f3bfa73bebc423ae8cd1d4fdb3e5585abc45a841eca920"},{"name":"typhoeus","version":"1.6.0","url":"https://rubygems.org/downloads/typhoeus-1.6.0.gem","sha256":"bacc41c23e379547e29801dc235cd1699b70b955a1ba3d32b2b877aa844c331d"},{"name":"tzinfo","version":"2.0.6","url":"https://rubygems.org/downloads/tzinfo-2.0.6.gem","sha256":"8daf828cc77bcf7d63b0e3bdb6caa47e2272dcfaf4fbfe46f8c3a9df087a829b"},{"name":"xcodeproj","version":"1.28.1","url":"https://rubygems.org/downloads/xcodeproj-1.28.1.gem","sha256":"6f12670f00739d9817ca27ac89d6ef01cc86050e22a0bc08a3131487e5b5cddc"},{"name":"zeitwerk","version":"2.6.18","url":"https://rubygems.org/downloads/zeitwerk-2.6.18.gem","sha256":"bd2d213996ff7b3b364cd342a585fbee9797dbc1c0c6d868dc4150cc75739781"}]},{"id":"xcode","title":"Xcode","version":"27.0","source":"https://developer.apple.com/xcode/","command":"xcodebuild","archive":null,"managed":false,"requires":[]},{"id":"perl","title":"Perl","version":"5.42.3","source":"https://www.cpan.org/src/5.0/","command":"perl","archive":{"url":"https://www.cpan.org/src/5.0/perl-5.42.3.tar.xz","sha256":"c9387e1473a1866935cb047ece7c2e0a80767a3acdecb79d4a375f8a95970ddc","root":"perl-5.42.3","executable":"bin/perl","kind":"native-source"},"managed":true,"requires":["node","xcode"]},{"id":"openssl","title":"OpenSSL","version":"3.6.3","source":"https://github.com/openssl/openssl/releases/download/openssl-3.6.3/","command":"openssl","archive":{"url":"https://github.com/openssl/openssl/releases/download/openssl-3.6.3/openssl-3.6.3.tar.gz","sha256":"243a86649cf6f23eeb6a2ff2456e09e5d77dd9018a54d3d96b0c6bdd6ba6c7f1","root":"openssl-3.6.3","executable":"bin/openssl","kind":"native-source"},"managed":true,"requires":["node","xcode","perl"]},{"id":"ruby","title":"Ruby","version":"3.4.11","source":"https://cache.ruby-lang.org/pub/ruby/3.4/","command":"ruby","archive":{"url":"https://cache.ruby-lang.org/pub/ruby/3.4/ruby-3.4.11.tar.gz","sha256":"5c22be44524312b3d433d68739bcc530633b1da5ef8ba0afa0a37680da17d3de","root":"ruby-3.4.11","executable":"bin/ruby","kind":"native-source"},"managed":true,"requires":["node","xcode","openssl"],"dependencies":[{"name":"libyaml","version":"0.2.5","url":"https://pyyaml.org/download/libyaml/yaml-0.2.5.tar.gz","sha256":"c642ae9b75fee120b2d96c712538bd2cf283228d2337df2cf2988e3c02678ef4","root":"yaml-0.2.5"}]},{"id":"m4","title":"GNU M4","version":"1.4.21","source":"https://ftp.gnu.org/gnu/m4/","command":"m4","archive":{"url":"https://ftp.gnu.org/gnu/m4/m4-1.4.21.tar.xz","sha256":"f25c6ab51548a73a75558742fb031e0625d6485fe5f9155949d6486a2408ab66","root":"m4-1.4.21","executable":"bin/m4","kind":"native-source"},"managed":true,"requires":["node","xcode"]},{"id":"bison","title":"GNU Bison","version":"3.8.2","source":"https://ftp.gnu.org/gnu/bison/","command":"bison","archive":{"url":"https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz","sha256":"9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2","root":"bison-3.8.2","executable":"bin/bison","kind":"native-source"},"managed":true,"requires":["node","xcode","m4"]},{"id":"flex","title":"Flex","version":"2.6.4","source":"https://github.com/westes/flex/releases/download/v2.6.4/","command":"flex","archive":{"url":"https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz","sha256":"e87aae032bf07c26f85ac0ed3250998c37621d95f8bd748b31f15b33c45ee995","root":"flex-2.6.4","executable":"bin/flex","kind":"native-source"},"managed":true,"requires":["node","xcode","m4","bison"]},{"id":"gettext","title":"GNU Gettext","version":"1.0","source":"https://ftp.gnu.org/gnu/gettext/","command":"msgfmt","archive":{"url":"https://ftp.gnu.org/gnu/gettext/gettext-1.0.tar.gz","sha256":"85d99b79c981a404874c02e0342176cf75c7698e2b51fe41031cf6526d974f1a","root":"gettext-1.0","executable":"bin/msgfmt","kind":"native-source"},"managed":true,"requires":["node","xcode","perl","m4","bison","flex"]},{"id":"posix","title":"macOS POSIX 基础工具","version":"27.0","source":"https://opensource.apple.com/","command":"bash","archive":{"url":"https://opensource.apple.com/","sha256":"8ca7560842b9606bcbe9628248866cc52675775a956574199716515dadf020fe","root":"macos-posix-27.0","executable":"bin/bash","kind":"apple-posix"},"managed":true,"requires":["node","xcode"]},{"id":"bash","title":"GNU Bash","version":"5.3.20","source":"https://www.gnu.org/software/bash/","command":"bash","archive":{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3.tar.gz","sha256":"0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba","root":"bash-5.3","executable":"bin/bash","kind":"native-source"},"upstream_patches":[{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-001","sha256":"1f608434364af86b9b45c8b0ea3fb3b165fb830d27697e6cdfc7ac17dee3287f"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-002","sha256":"e385548a00130765ec7938a56fbdca52447ab41fabc95a25f19ade527e282001"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-003","sha256":"f245d9c7dc3f5a20d84b53d249334747940936f09dc97e1dcb89fc3ab37d60ed"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-004","sha256":"9591d245045529f32f0812f94180b9d9ce9023f5a765c039b852e5dfc99747d0"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-005","sha256":"cca1ef52dbbf433bc98e33269b64b2c814028efe2538be1e2c9a377da90bc99d"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-006","sha256":"29119addefed8eff91ae37fd51822c31780ee30d4a28376e96002706c995ff10"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-007","sha256":"c0976bbfffa1453c7cfdd62058f206a318568ff2d690f5d4fa048793fa3eb299"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-008","sha256":"097cd723cbfb8907674ac32214063a3fd85282657ec5b4e544d2c0f719653fb4"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-009","sha256":"eee30fe78a4b0cb2fe20e010e00308899cfc613e0774ebb3c8557a1552f24f8c"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-010","sha256":"cf76f1cce2ea300c18bff9f002d21f280cc931acd17c28518110b93fe6e72569"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-011","sha256":"0298df8f5ea2a31d3be43ed7d269c5b3c7c342dd5b570bea7f64d66dcbbe7531"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-012","sha256":"d71379b39bebaedaf123414414e77fb458a0a43b9ad3116594c6df7ca6754573"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-013","sha256":"042f9cda967e24bf4211944697441e93d06ff42b4b998629a98a1b249279f200"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-014","sha256":"bd4360b401d38507e358783dcad8536a99c6789f0d3a5bd0cfb8c4a34144696c"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-015","sha256":"55b79ceee2fc27f6767eed697e939a7eb2fe2a28c01556bd75f18d581014f46e"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-016","sha256":"9ea29b266b7d24cb34d0ff3f1c4631e4d527bfe2d1ef15d17cdb924bf31ef767"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-017","sha256":"443b927b45c1558ca72052410f8b8f6e5152b617ed707061a2781d4375b0d1c3"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-018","sha256":"ae715d76c50341d7d7095e9a8d2eeed1ca9546152c2ac7289206f90cf30ac697"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-019","sha256":"a25c581e4d0057dea3833918438a930e2e86ee4c6dc17fe15267b7f04cbc4e3d"},{"url":"https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-020","sha256":"df217ed3a9122aa2286d9b67bbe348661b6a9db262b580c29150dae55d532896"}],"managed":true,"requires":["node","xcode","posix"]},{"id":"grep","title":"GNU grep","version":"3.12","source":"https://www.gnu.org/software/grep/","command":"grep","archive":{"url":"https://ftp.gnu.org/gnu/grep/grep-3.12.tar.xz","sha256":"2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9","root":"grep-3.12","executable":"bin/grep","kind":"native-source"},"managed":true,"requires":["node","xcode","posix"]},{"id":"sed","title":"GNU sed","version":"4.10","source":"https://www.gnu.org/software/sed/","command":"sed","archive":{"url":"https://ftp.gnu.org/gnu/sed/sed-4.10.tar.xz","sha256":"b8e72182b2ec96a3574e2998c47b7aaa64cc20ce000d8e9ac313cc07cecf28c7","root":"sed-4.10","executable":"bin/sed","kind":"native-source"},"managed":true,"requires":["node","xcode","posix"]}];
const androidPlatformDefinitions=[{"path":"platforms;android-35","version":"2","source":"https://dl.google.com/android/repository/platform-35_r02.zip","sha256":"14c793e5c50d69bd3a5b15e42bf763b39ea90d8d3fb3a4a690b5a7b05c299d6f"}];
const androidDefinitions=[{"path":"platforms;android-36","version":"2","url":"https://dl.google.com/android/repository/platform-36_r02.zip","sha256":"37607369a28c5b640b3a7998868d45898ebcb777565a0e85f9acf36f29631d2e","root":"android-36"},{"path":"build-tools;36.0.0","version":"36.0.0","url":"https://dl.google.com/android/repository/build-tools_r36_macosx.zip","sha256":"04e7f3a72044de4926fa038fa0e251a37bba1e1c3fb8beab6f8401bfd9eb4bf3","root":"android-16"},{"path":"platform-tools","version":"37.0.1","url":"https://dl.google.com/android/repository/platform-tools_r37.0.1-darwin.zip","sha256":"ee39ad5967e95c2a07f04dbcbde96b1a0c916ba376096db5d2f498b7727a5d1d","root":"platform-tools"},{"path":"cmdline-tools;22.0","version":"22.0","url":"https://dl.google.com/android/repository/commandlinetools-mac_arm64-15859902_latest.zip","sha256":"835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e","root":"cmdline-tools"},{"tool":"cmake"},{"path":"ndk;28.2.13676358","version":"28.2.13676358","url":"https://dl.google.com/android/repository/android-ndk-r28c-darwin.zip","sha256":"0d4599e8bbf1a1668a0d51a541729b2246360f350018a2081d0b302dbb594f2a","root":"android-ndk-r28c"}];
const flutterPatch="# Flutter Android new DSL — fixed source d3b14c876900e553bc736ca19295fc09e3853e8e\n# Copyright notices and the upstream BSD license are retained in the SDK.\ndiff --git a/packages/flutter_tools/gradle/build.gradle.kts b/packages/flutter_tools/gradle/build.gradle.kts\nindex 8bce67c561f7a91bb743b443242b8d804ddc4190dc5524278bdecf8797515008..7438ec7066f34d2b597426a58105e831d677a4278cd3ee415587a9768678d667\n--- a/packages/flutter_tools/gradle/build.gradle.kts\n+++ b/packages/flutter_tools/gradle/build.gradle.kts\n@@ -7,8 +7,13 @@\n plugins {\n     `java-gradle-plugin`\n     groovy\n+    kotlin(\"jvm\") version \"2.2.20\"\n+    kotlin(\"plugin.sam.with.receiver\") version \"2.2.20\"\n+}\n+\n+// 保留Gradle Action的官方隐式接收者语义，编译插件与Kotlin使用同一版本。\n+samWithReceiver {\n+    annotation(\"org.gradle.api.HasImplicitReceiver\")\n-    `kotlin-dsl`\n-    kotlin(\"jvm\") version \"2.2.20\"\n }\n \n group = \"dev.flutter.plugin\"\n@@ -50,12 +55,14 @@\n }\n \n dependencies {\n+    // 使用固定Kotlin编译插件，不应用绑定Gradle内嵌Kotlin版本的kotlin-dsl插件。\n+    implementation(gradleKotlinDsl())\n     // Versions available https://mvnrepository.com/artifact/androidx.annotation/annotation-jvm.\n     // Version release notes https://developer.android.com/jetpack/androidx/releases/annotation\n     compileOnly(\"androidx.annotation:annotation-jvm:1.9.1\")\n     // When bumping, also update:\n     //  * KGP error version in packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt\n+    implementation(\"org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20\")\n-    implementation(\"org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.0\")\n     // Update to 1.8.0 when min kotlin is 2.1\n     // https://github.com/Kotlin/kotlinx.serialization/releases for kotlin version compatibility.\n     // All kotlinx implementation dependencies must work with the oldest kotlin supported versions.\n@@ -65,10 +72,10 @@\n     //  * AGP version constants in packages/flutter_tools/lib/src/android/gradle_utils.dart\n     //  * ndkVersion constant in packages/flutter_tools/lib/src/android/gradle_utils.dart\n     //  * ndkVersion in FlutterExtension in packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt\n+    compileOnly(\"com.android.tools.build:gradle:9.0.1\")\n-    compileOnly(\"com.android.tools.build:gradle:8.11.1\")\n \n     testImplementation(kotlin(\"test\"))\n+    testImplementation(\"com.android.tools.build:gradle:9.0.1\")\n-    testImplementation(\"com.android.tools.build:gradle:8.11.1\")\n     testImplementation(\"org.mockito:mockito-core:5.8.0\")\n     testImplementation(\"io.mockk:mockk:1.13.16\")\n }\ndiff --git a/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt b/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt\nindex a8ca02d55798c200d766e245dae9df20565cb9d638d4887b51bf617abac938a1..383540448a0810cb60e7b6197455fdcf3bd1771720e82a42ed10e5af7e8b43b9\n--- a/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt\n+++ b/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt\n@@ -45,4 +45,5 @@\n      * Specifies the relative directory to the Flutter project directory.\n      * In an app project, this is ../.. since the app's Gradle build file is under android/app.\n      */\n+    // 本机任务在插件应用时即需准确源码根；标准Flutter工程继续使用官方相对路径。\n+    var source: String? = System.getenv(\"PRODUCT_SOURCE_DIR\") ?: \"../..\"\n-    var source: String? = \"../..\"\ndiff --git a/packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt b/packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt\nindex aba6c2f7331ea613227fed69666f8edb3839c09413188ccab64989dabe4bcd6f..afc1c54599c2b8cacbf5d957a198b168106aa95b341a79243bc66e47e4201ed1\n--- a/packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt\n+++ b/packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt\n@@ -7,11 +7,20 @@\n import com.android.build.api.dsl.ApplicationExtension\n import com.android.build.api.dsl.BuildType\n import com.android.build.api.variant.AndroidComponentsExtension\n+import com.android.build.api.variant.ApplicationVariant\n+import com.android.build.api.variant.Variant\n+import com.android.build.api.variant.FilterConfiguration\n+import com.android.build.api.variant.BuiltArtifactsLoader\n+import com.android.build.api.artifact.SingleArtifact\n+import org.gradle.api.DefaultTask\n+import org.gradle.api.file.DirectoryProperty\n+import org.gradle.api.provider.Property\n+import org.gradle.api.tasks.Input\n+import org.gradle.api.tasks.InputDirectory\n+import org.gradle.api.tasks.OutputDirectory\n+import org.gradle.api.tasks.Internal\n+import org.gradle.api.tasks.TaskAction\n+import org.gradle.api.tasks.Sync\n-import com.android.build.gradle.AbstractAppExtension\n-import com.android.build.gradle.LibraryExtension\n-import com.android.build.gradle.api.ApkVariant\n-import com.android.build.gradle.tasks.PackageAndroidArtifact\n-import com.android.build.gradle.tasks.ProcessAndroidResources\n import com.flutter.gradle.FlutterPluginConstants.PLATFORM_ABI_LIST\n import com.flutter.gradle.FlutterPluginUtils.readPropertiesIfExist\n import com.flutter.gradle.plugins.PluginHandler\n@@ -246,12 +255,12 @@\n             }\n             localEngineHost = engineHostOut.name\n         }\n+        FlutterPluginUtils.getAndroidExtension(project).buildTypes.all {\n-        FlutterPluginUtils.getLegacyAndroidExtension(project).buildTypes.all {\n             addFlutterDependencies(this)\n         }\n     }\n \n+    private fun addFlutterDependencies(buildType: BuildType) {\n-    private fun addFlutterDependencies(buildType: com.android.builder.model.BuildType) {\n         FlutterPluginUtils.addFlutterDependencies(\n             project!!,\n             buildType,\n@@ -305,203 +314,15 @@\n             FlutterPluginUtils.addTasksForOutputsAppLinkSettings(projectToAddTasksTo)\n         }\n \n+        val targetPlatforms = FlutterPluginUtils.getTargetPlatforms(projectToAddTasksTo)\n-        val targetPlatforms: List<String> =\n-            FlutterPluginUtils.getTargetPlatforms(projectToAddTasksTo)\n-\n-        // The Android Gradle Plugin is always applied to Flutter Android projects, so its components\n-        // extension is expected to be present. Use getByType (not findByType) so a misconfiguration\n-        // fails loudly rather than silently skipping libapp.so registration.\n-        val androidComponents = projectToAddTasksTo.extensions.getByType(AndroidComponentsExtension::class.java)\n-        val targetPlatformsList = targetPlatforms\n-        androidComponents.onVariants { variant ->\n-            val capitalizeVariantName = FlutterPluginUtils.capitalize(variant.name)\n-            val compileTaskName = flutterCompileTaskName(variant.name)\n-            val copyJniLibsTaskProvider: TaskProvider<CopyFlutterJniLibsTask> =\n-                projectToAddTasksTo.tasks.register(\n-                    \"copyJniLibs${FLUTTER_BUILD_PREFIX}$capitalizeVariantName\",\n-                    CopyFlutterJniLibsTask::class.java\n-                ) {\n-                    // The Flutter compile task is registered later (in the legacy\n-                    // `applicationVariants` callback in addFlutterDeps) and only for variants that\n-                    // are actually built as a Flutter app. It is absent for e.g. an\n-                    // `assembleAndroidTest` build, where `shouldConfigureFlutterTask` returns false.\n-                    // Look it up tolerantly (findByName, not named) so this task degrades to a no-op\n-                    // with empty output instead of failing to be created when there is no Flutter\n-                    // build for the variant. See https://github.com/flutter/flutter/issues/188785.\n-                    dependsOn(projectToAddTasksTo.tasks.matching { it.name == compileTaskName })\n-                    intermediateDir.set(\n-                        projectToAddTasksTo.layout.dir(\n-                            projectToAddTasksTo.provider {\n-                                val compileTask = projectToAddTasksTo.tasks.findByName(compileTaskName) as? FlutterTask\n-                                compileTask?.outputDirectory\n-                            }\n-                        )\n-                    )\n-                    this.targetPlatforms.set(targetPlatformsList)\n-                }\n-            variant.sources.jniLibs?.addGeneratedSourceDirectory(\n-                copyJniLibsTaskProvider,\n-                CopyFlutterJniLibsTask::destinationDir\n-            )\n-        }\n-\n-        val flutterPlugin = this\n-\n         if (FlutterPluginUtils.isFlutterAppProject(projectToAddTasksTo)) {\n+            configureAbis(projectToAddTasksTo, FlutterPluginUtils.getAndroidApplicationExtension(projectToAddTasksTo))\n-            val appExtension = FlutterPluginUtils.getAndroidApplicationExtension(projectToAddTasksTo)\n-            configureAbis(projectToAddTasksTo, appExtension)\n-            val android: AbstractAppExtension =\n-                projectToAddTasksTo.extensions.findByName(\"android\") as AbstractAppExtension\n-            android.applicationVariants.configureEach {\n-                val variant = this\n-                val assembleTask = variant.assembleProvider.get()\n-                if (!FlutterPluginUtils.shouldConfigureFlutterTask(\n-                        projectToAddTasksTo,\n-                        assembleTask\n-                    )\n-                ) {\n-                    return@configureEach\n-                }\n-                val copyFlutterAssetsTask: Task =\n-                    addFlutterDeps(variant, flutterPlugin, targetPlatforms)\n-\n-                // TODO(gmackall): Migrate to AGPs variant api.\n-                //    https://github.com/flutter/flutter/issues/166550\n-                @Suppress(\"DEPRECATION\")\n-                val variantOutput: com.android.build.gradle.api.BaseVariantOutput = variant.outputs.first()\n-                val processResources: ProcessAndroidResources =\n-                    try {\n-                        variantOutput.processResourcesProvider.get()\n-                    } catch (e: UnknownTaskException) {\n-                        // TODO(gmackall): Migrate to AGPs variant api.\n-                        //    https://github.com/flutter/flutter/issues/166550\n-                        @Suppress(\"DEPRECATION\")\n-                        variantOutput.processResources\n-                    }\n-                processResources.dependsOn(copyFlutterAssetsTask)\n-\n-                // Copy the output APKs into a known location, so `flutter run` or `flutter build apk`\n-                // can discover them. By default, this is `<app-dir>/build/app/outputs/flutter-apk/<filename>.apk`.\n-                //\n-                // The filename consists of `app<-abi>?<-flavor-name>?-<build-mode>.apk`.\n-                // Where:\n-                //   * `abi` can be `armeabi-v7a|arm64-v8a|x86_64` only if the flag `split-per-abi` is set.\n-                //   * `flavor-name` is the flavor used to build the app in lower case if the assemble task is called.\n-                //   * `build-mode` can be `release|debug|profile`.\n-                variant.outputs.forEach { output ->\n-                    assembleTask.doLast {\n-                        // TODO(gmackall): Migrate to AGPs variant api.\n-                        //    https://github.com/flutter/flutter/issues/166550\n-                        @Suppress(\"DEPRECATION\")\n-                        output as com.android.build.gradle.api.ApkVariantOutput\n-                        val packageApplicationProvider: PackageAndroidArtifact =\n-                            variant.packageApplicationProvider.get()\n-                        val outputDirectory: Directory =\n-                            packageApplicationProvider.outputDirectory.get()\n-                        val outputDirectoryStr: String = outputDirectory.toString()\n-                        var filename = \"app\"\n-\n-                        // TODO(gmackall): Migrate to AGPs variant api.\n-                        //    https://github.com/flutter/flutter/issues/166550\n-                        @Suppress(\"DEPRECATION\")\n-                        val abi = output.getFilter(com.android.build.VariantOutput.FilterType.ABI)\n-                        if (abi != null && abi.isNotEmpty()) {\n-                            filename += \"-$abi\"\n-                        }\n-                        if (variant.flavorName != null && variant.flavorName.isNotEmpty()) {\n-                            filename += \"-${FlutterPluginUtils.lowercase(variant.flavorName)}\"\n-                        }\n-                        filename += \"-${FlutterPluginUtils.buildModeFor(variant.buildType)}\"\n-                        projectToAddTasksTo.copy {\n-                            from(File(\"$outputDirectoryStr/${output.outputFileName}\"))\n-                            into(projectToAddTasksTo.layout.buildDirectory.dir(\"outputs/flutter-apk\"))\n-                            rename { \"$filename.apk\" }\n-                        }\n-                    }\n-                }\n-            }\n-            getPluginHandler(projectToAddTasksTo).configurePlugins(engineVersion!!)\n-            FlutterPluginUtils.detectLowCompileSdkVersionOrNdkVersion(\n-                projectToAddTasksTo,\n-                getPluginHandler(projectToAddTasksTo).getPluginList()\n-            )\n-            FlutterPluginUtils.detectApplyingKotlinGradlePlugin(\n-                projectToAddTasksTo\n-            )\n-            return\n         }\n+        // 同一个公开变体回调同时注册编译、资源与JNI，避免跨回调按名称猜测任务。\n+        val components = projectToAddTasksTo.extensions.getByType(AndroidComponentsExtension::class.java)\n+        components.onVariants { variant ->\n+            addFlutterDeps(variant, this, targetPlatforms)\n-        // Flutter host module project (Add-to-app).\n-        val hostAppProjectName: String? =\n-            if (projectToAddTasksTo.rootProject.hasProperty(\"flutter.hostAppProjectName\")) {\n-                projectToAddTasksTo.rootProject.property(\n-                    \"flutter.hostAppProjectName\"\n-                ) as? String\n-            } else {\n-                \"app\"\n-            }\n-        val appProject: Project? =\n-            projectToAddTasksTo.rootProject.findProject(\":$hostAppProjectName\")\n-        check(appProject != null) {\n-            \"Project :$hostAppProjectName doesn't exist. To customize the host app project name, set `flutter.hostAppProjectName=<project-name>` in gradle.properties.\"\n         }\n-        // Wait for the host app project configuration.\n-        appProject.afterEvaluate {\n-            val androidLibraryExtension =\n-                projectToAddTasksTo.extensions.findByType(LibraryExtension::class.java)\n-            check(androidLibraryExtension != null)\n-            androidLibraryExtension.libraryVariants.all libraryVariantAll@{\n-                val libraryVariant = this\n-                var copyFlutterAssetsTask: Task? = null\n-                val androidAppExtension =\n-                    appProject.extensions.findByName(\"android\") as? AbstractAppExtension\n-                check(androidAppExtension != null)\n-                androidAppExtension.applicationVariants.all applicationVariantAll@{\n-                    val appProjectVariant = this\n-                    val appAssembleTask: Task = appProjectVariant.assembleProvider.get()\n-                    if (!FlutterPluginUtils.shouldConfigureFlutterTask(project, appAssembleTask)) {\n-                        return@applicationVariantAll\n-                    }\n-\n-                    // Find a compatible application variant in the host app.\n-                    //\n-                    // For example, consider a host app that defines the following variants:\n-                    // | ----------------- | ----------------------------- |\n-                    // |   Build Variant   |   Flutter Equivalent Variant  |\n-                    // | ----------------- | ----------------------------- |\n-                    // |   freeRelease     |   release                     |\n-                    // |   freeDebug       |   debug                       |\n-                    // |   freeDevelop     |   debug                       |\n-                    // |   profile         |   profile                     |\n-                    // | ----------------- | ----------------------------- |\n-                    //\n-                    // This mapping is based on the following rules:\n-                    // 1. If the host app build variant name is `profile` then the equivalent\n-                    //    Flutter variant is `profile`.\n-                    // 2. If the host app build variant is debuggable\n-                    //    (e.g. `buildType.debuggable = true`), then the equivalent Flutter\n-                    //    variant is `debug`.\n-                    // 3. Otherwise, the equivalent Flutter variant is `release`.\n-                    val variantBuildMode: String =\n-                        FlutterPluginUtils.buildModeFor(libraryVariant.buildType)\n-                    if (FlutterPluginUtils.buildModeFor(appProjectVariant.buildType) != variantBuildMode) {\n-                        return@applicationVariantAll\n-                    }\n-                    copyFlutterAssetsTask = copyFlutterAssetsTask ?: addFlutterDeps(\n-                        libraryVariant,\n-                        flutterPlugin,\n-                        targetPlatforms\n-                    )\n-                    // TODO(gmackall): Migrate to AGPs variant api.\n-                    //    https://github.com/flutter/flutter/issues/166550\n-                    val mergeAssets =\n-                        projectToAddTasksTo\n-                            .tasks\n-                            .findByPath(\":$hostAppProjectName:merge${FlutterPluginUtils.capitalize(appProjectVariant.name)}Assets\")\n-                    check(mergeAssets != null)\n-                    mergeAssets.dependsOn(copyFlutterAssetsTask)\n-                }\n-            }\n-        }\n         getPluginHandler(projectToAddTasksTo).configurePlugins(engineVersion!!)\n         FlutterPluginUtils.detectLowCompileSdkVersionOrNdkVersion(\n             projectToAddTasksTo,\n@@ -600,26 +421,12 @@\n             }\n         }\n \n+        // 只消费AGP公开变体，不读取内部打包任务或已删除的变体接口。\n-        /**\n-         * Finds a task by name, returning null if the task does not exist.\n-         */\n-        private fun findTaskOrNull(\n-            project: Project,\n-            taskName: String\n-        ): Task? =\n-            try {\n-                project.tasks.named(taskName).get()\n-            } catch (ignored: UnknownTaskException) {\n-                null\n-            }\n-\n-        // TODO(gmackall): Migrate to AGPs variant api.\n-        //    https://github.com/flutter/flutter/issues/166550\n         private fun addFlutterDeps(\n+            variant: Variant,\n-            @Suppress(\"DEPRECATION\") variant: com.android.build.gradle.api.BaseVariant,\n             flutterPlugin: FlutterPlugin,\n             targetPlatforms: List<String>\n+        ): Unit {\n-        ): Task {\n             // Shorthand\n             val project: Project = flutterPlugin.project!!\n \n@@ -654,51 +461,19 @@\n             val validateDeferredComponentsValue: Boolean =\n                 project.findProperty(\"validate-deferred-components\")?.toString()?.toBoolean() ?: true\n \n+            val buildType = FlutterPluginUtils.getAndroidExtension(project).buildTypes.getByName(requireNotNull(variant.buildType))\n+            val variantBuildMode = FlutterPluginUtils.buildModeFor(buildType)\n+            val flavorValue = variant.flavorName.orEmpty()\n+            if (!FlutterPluginUtils.supportsBuildMode(project, variantBuildMode)) return\n+            if (variant is ApplicationVariant && FlutterPluginUtils.shouldProjectSplitPerAbi(project)) {\n-            if (FlutterPluginUtils.shouldProjectSplitPerAbi(project)) {\n                 variant.outputs.forEach { output ->\n+                    val abi = output.filters.firstOrNull { it.filterType == FilterConfiguration.FilterType.ABI }?.identifier\n+                    val abiVersionCode = FlutterPluginConstants.ABI_VERSION[abi]\n-                    // need to force this as the API does not return the right thing for our use.\n-                    // TODO(gmackall): Migrate to AGPs variant api.\n-                    //    https://github.com/flutter/flutter/issues/166550\n-                    @Suppress(\"DEPRECATION\")\n-                    output as com.android.build.gradle.api.ApkVariantOutput\n-                    val versionCodeIfPresent: Int? = if (variant is ApkVariant) variant.versionCode else null\n-\n-                    // TODO(gmackall): Migrate to AGPs variant api.\n-                    //    https://github.com/flutter/flutter/issues/166550\n-                    @Suppress(\"DEPRECATION\")\n-                    val filterIdentifier: String? =\n-                        output.getFilter(com.android.build.VariantOutput.FilterType.ABI)\n-                    val abiVersionCode: Int? = FlutterPluginConstants.ABI_VERSION[filterIdentifier]\n                     if (abiVersionCode != null && !FlutterPluginUtils.shouldForceVersionCodeIgnoringAbi(project)) {\n+                        output.versionCode.set(output.versionCode.get() + abiVersionCode * 1000)\n-                        output.versionCodeOverride = abiVersionCode * 1000 + (\n-                            versionCodeIfPresent\n-                                ?: variant.mergedFlavor.versionCode as Int\n-                        )\n                     }\n                 }\n             }\n-\n-            // Build an AAR when this property is defined.\n-            val isBuildingAar: Boolean = project.hasProperty(\"is-plugin\")\n-            // In add to app scenarios, a Gradle project contains a `:flutter` and `:app` project.\n-            // `:flutter` is used as a subproject when these tasks exists and the build isn't building an AAR.\n-            // TODO(gmackall): I think this is just always null? Which is great news! Consider removing.\n-            val packageAssets: Task? =\n-                findTaskOrNull(\n-                    project,\n-                    \"package${FlutterPluginUtils.capitalize(variant.name)}Assets\"\n-                )\n-            val cleanPackageAssets: Task? =\n-                findTaskOrNull(\n-                    project,\n-                    \"cleanPackage${FlutterPluginUtils.capitalize(variant.name)}Assets\"\n-                )\n-\n-            val isUsedAsSubproject: Boolean =\n-                packageAssets != null && cleanPackageAssets != null && !isBuildingAar\n-\n-            val variantBuildMode: String = FlutterPluginUtils.buildModeFor(variant.buildType)\n-            val flavorValue: String = variant.flavorName\n             val taskName: String = flutterCompileTaskName(variant.name)\n             // The task provider below will shadow a lot of the variable names, so provide this reference\n             // to access them within that scope.\n@@ -714,7 +489,7 @@\n                     flutterRoot = flutterPlugin.flutterRoot\n                     flutterExecutable = flutterPlugin.flutterExecutable\n                     buildMode = variantBuildMode\n+                    minSdkVersion = variant.minSdk.apiLevel\n-                    minSdkVersion = variant.mergedFlavor.minSdkVersion!!.apiLevel\n                     localEngine = flutterPlugin.localEngine\n                     localEngineHost = flutterPlugin.localEngineHost\n                     localEngineSrcPath = flutterPlugin.localEngineSrcPath\n@@ -742,76 +517,42 @@\n                     validateDeferredComponents = validateDeferredComponentsValue\n                     flavor = flavorValue\n                 }\n+            // 生成目录经Sources API交给AGP，资源/JNI消费者自动获得准确任务依赖。\n+            val assets = project.tasks.register(\n+                \"copyFlutterAssets\" + FlutterPluginUtils.capitalize(variant.name),\n+                FlutterAssetsTask::class.java\n+            ) {\n+                dependsOn(compileTaskProvider)\n+                from(compileTaskProvider.map { File(requireNotNull(it.outputDirectory), \"flutter_assets\") }) { into(\"flutter_assets\") }\n+                destinationDirectory.set(project.layout.buildDirectory.dir(\"intermediates/flutter-assets/\" + variant.name))\n+                into(destinationDirectory)\n+            }\n+            variant.sources.assets?.addGeneratedSourceDirectory(assets, FlutterAssetsTask::destinationDirectory)\n+                ?: throw GradleException(\"Android variant has no assets sources: \" + variant.name)\n+            val jni = project.tasks.register(\n+                \"copyJniLibs\" + FLUTTER_BUILD_PREFIX + FlutterPluginUtils.capitalize(variant.name),\n+                CopyFlutterJniLibsTask::class.java\n+            ) {\n+                dependsOn(compileTaskProvider)\n+                intermediateDir.set(project.layout.dir(compileTaskProvider.map { requireNotNull(it.outputDirectory) }))\n+                this.targetPlatforms.set(targetPlatforms)\n+            }\n+            variant.sources.jniLibs?.addGeneratedSourceDirectory(jni, CopyFlutterJniLibsTask::destinationDir)\n+                ?: throw GradleException(\"Android variant has no JNI sources: \" + variant.name)\n+            if (variant is ApplicationVariant) {\n+                val copyApk = project.tasks.register(\n+                    \"copyFlutterApk\" + FlutterPluginUtils.capitalize(variant.name), FlutterApkTask::class.java\n-            val flutterCompileTask: FlutterTask = compileTaskProvider.get()\n-            val copyFlutterAssetsTaskProvider: TaskProvider<Copy> =\n-                project.tasks.register(\n-                    \"copyFlutterAssets${FlutterPluginUtils.capitalize(variant.name)}\",\n-                    Copy::class.java\n                 ) {\n+                    inputDirectory.set(variant.artifacts.get(SingleArtifact.APK))\n+                    destinationDirectory.set(project.layout.buildDirectory.dir(\"outputs/flutter-apk\"))\n+                    loader.set(variant.artifacts.getBuiltArtifactsLoader())\n+                    buildMode.set(variantBuildMode)\n+                    flavor.set(flavorValue)\n-                    dependsOn(flutterCompileTask)\n-                    with(flutterCompileTask.assets)\n-                    filePermissions {\n-                        user {\n-                            read = true\n-                            write = true\n-                        }\n-                    }\n-                    if (isUsedAsSubproject) {\n-                        // TODO(gmackall): above is always false, can delete\n-                        dependsOn(packageAssets)\n-                        dependsOn(cleanPackageAssets)\n-                        into(packageAssets!!.outputs)\n-                    }\n-                    val mergeAssets =\n-                        try {\n-                            variant.mergeAssetsProvider.get()\n-                        } catch (e: IllegalStateException) {\n-                            // TODO(gmackall): Migrate to AGPs variant api.\n-                            //    https://github.com/flutter/flutter/issues/166550\n-                            @Suppress(\"DEPRECATION\")\n-                            variant.mergeAssets\n-                        }\n-                    dependsOn(mergeAssets)\n-                    dependsOn(\"clean${FlutterPluginUtils.capitalize(mergeAssets.name)}\")\n-                    mergeAssets.mustRunAfter(\"clean${FlutterPluginUtils.capitalize(mergeAssets.name)}\")\n-                    into(mergeAssets.outputDir)\n                 }\n+                // assemble是公开生命周期入口；APK位置与文件清单由Artifacts API提供。\n+                project.tasks.matching { it.name == \"assemble\" + FlutterPluginUtils.capitalize(variant.name) }\n+                    .configureEach { dependsOn(copyApk) }\n-            val copyFlutterAssetsTask: Task = copyFlutterAssetsTaskProvider.get()\n-            if (!isUsedAsSubproject) {\n-                // TODO(gmackall): Migrate to AGPs variant api.\n-                //    https://github.com/flutter/flutter/issues/166550\n-                @Suppress(\"DEPRECATION\")\n-                val variantOutput: com.android.build.gradle.api.BaseVariantOutput = variant.outputs.first()\n-                val processResources =\n-                    try {\n-                        variantOutput.processResourcesProvider.get()\n-                    } catch (e: IllegalStateException) {\n-                        // TODO(gmackall): Migrate to AGPs variant api.\n-                        //    https://github.com/flutter/flutter/issues/166550\n-                        @Suppress(\"DEPRECATION\")\n-                        variantOutput.processResources\n-                    }\n-                processResources.dependsOn(copyFlutterAssetsTask)\n             }\n-            // The following tasks use the output of copyFlutterAssetsTask,\n-            // so it's necessary to declare it as an dependency since Gradle 8.\n-            // See https://docs.gradle.org/8.1/userguide/validation_problems.html#implicit_dependency.\n-            val tasksToCheck =\n-                listOf(\n-                    \"compress${FlutterPluginUtils.capitalize(variant.name)}Assets\",\n-                    \"bundle${FlutterPluginUtils.capitalize(variant.name)}Aar\",\n-                    \"bundle${FlutterPluginUtils.capitalize(variant.name)}LocalLintAar\"\n-                )\n-            tasksToCheck.forEach { taskTocheck ->\n-                try {\n-                    project.tasks.named(taskTocheck).configure {\n-                        dependsOn(copyFlutterAssetsTask)\n-                    }\n-                } catch (ignored: UnknownTaskException) {\n-                    // ignored\n-                }\n-            }\n-            return copyFlutterAssetsTask\n         }\n     }\n \n@@ -823,3 +564,35 @@\n      */\n     private fun isInvokedFromAndroidStudio(): Boolean = project?.hasProperty(\"android.injected.invoked.from.ide\") == true\n }\n+\n+/** 公开资源生成任务：每个变体独占输出，禁止直接写入AGP内部合并目录。 */\n+abstract class FlutterAssetsTask : Sync() {\n+    @get:OutputDirectory\n+    abstract val destinationDirectory: DirectoryProperty\n+}\n+\n+/** 从AGP正式输出清单发现APK，不按内部任务类或固定文件位置猜测。 */\n+abstract class FlutterApkTask : DefaultTask() {\n+    @get:InputDirectory\n+    abstract val inputDirectory: DirectoryProperty\n+    @get:OutputDirectory\n+    abstract val destinationDirectory: DirectoryProperty\n+    @get:Internal\n+    abstract val loader: Property<BuiltArtifactsLoader>\n+    @get:Input\n+    abstract val buildMode: Property<String>\n+    @get:Input\n+    abstract val flavor: Property<String>\n+\n+    @TaskAction\n+    fun copyApks() {\n+        val artifacts = requireNotNull(loader.get().load(inputDirectory.get())) { \"APK metadata is missing\" }\n+        val output = destinationDirectory.get().asFile\n+        output.mkdirs()\n+        artifacts.elements.forEach { artifact ->\n+            val abi = artifact.filters.firstOrNull { it.filterType == FilterConfiguration.FilterType.ABI }?.identifier\n+            val name = listOfNotNull(\"app\", abi, flavor.get().takeIf { it.isNotEmpty() }?.lowercase(), buildMode.get()).joinToString(\"-\")\n+            File(artifact.outputFile).copyTo(File(output, name + \".apk\"), overwrite = true)\n+        }\n+    }\n+}\ndiff --git a/packages/flutter_tools/gradle/src/main/kotlin/FlutterPluginUtils.kt b/packages/flutter_tools/gradle/src/main/kotlin/FlutterPluginUtils.kt\nindex 92f05b75bae280223c3cea04fceb8c7860c65a6b464399a5a51d71dfe90f0c05..8c22286256d2ee68c5b27f60854d74df56f07de9f1cb77423cd3193aa43c8f58\n--- a/packages/flutter_tools/gradle/src/main/kotlin/FlutterPluginUtils.kt\n+++ b/packages/flutter_tools/gradle/src/main/kotlin/FlutterPluginUtils.kt\n@@ -7,10 +7,11 @@\n import com.android.build.api.AndroidPluginVersion\n import com.android.build.api.artifact.SingleArtifact\n import com.android.build.api.dsl.ApplicationExtension\n+import com.android.build.api.dsl.ApplicationBuildType\n import com.android.build.api.dsl.LibraryExtension\n import com.android.build.api.variant.AndroidComponentsExtension\n+import com.android.build.api.dsl.CommonExtension\n+import com.android.build.api.dsl.BuildType\n-import com.android.build.gradle.BaseExtension\n-import com.android.builder.model.BuildType\n import com.flutter.gradle.plugins.PluginHandler\n import com.flutter.gradle.tasks.DeepLinkJsonFromManifestTask\n import com.flutter.gradle.tasks.PrintTask\n@@ -472,7 +473,7 @@\n     internal fun buildModeFor(buildType: BuildType): String {\n         if (buildType.name == \"profile\") {\n             return \"profile\"\n+        } else if ((buildType is ApplicationBuildType && buildType.isDebuggable) || buildType.name == \"debug\") {\n-        } else if (buildType.isDebuggable) {\n             return \"debug\"\n         }\n         return \"release\"\n@@ -498,48 +499,23 @@\n         return project.property(PROP_LOCAL_ENGINE_BUILD_MODE) == flutterBuildMode\n     }\n \n+    // AGP9公共DSL统一入口；没有Android扩展必须立即报错。\n+    internal fun getAndroidExtension(project: Project): CommonExtension =\n+        project.extensions.getByType(CommonExtension::class.java)\n-    /**\n-     * Returns BaseExtension for the project. Used for compatibility.\n-     *\n-     * From BaseExtension docs:\n-     * \"Don't use this extension directly Instead, use one of the following:\n-     *  ApplicationExtension, LibraryExtension, TestExtension, DynamicFeatureExtension\"\n-     *\n-     *  For ApplicationExtension use `getAndroidApplicationExtension`.\n-     *  For LibraryExtension use `getAndroidLibraryExtension`.\n-     */\n-    internal fun getLegacyAndroidExtension(project: Project): BaseExtension {\n-        // Common supertype of the android extension types.\n-        // But maybe this should be https://developer.android.com/reference/tools/gradle-api/8.7/com/android/build/api/dsl/TestedExtension.\n-        return project.extensions.findByType(BaseExtension::class.java)!!\n-    }\n \n-    internal fun getAndroidExtension(project: Project): AgpCommonExtensionWrapper {\n-        // Look up by name to completely avoid importing or resolving CommonExtension\n-        val androidExtension =\n-            project.extensions.findByName(\"android\")\n-                ?: throw IllegalStateException(\"The Android plugin must be applied before accessing the Android extension.\")\n-\n-        return AgpCommonExtensionWrapper(androidExtension)\n-    }\n-\n     internal fun getAndroidLibraryExtension(project: Project): LibraryExtension = project.extensions.getByType(LibraryExtension::class.java)\n \n     internal fun getAndroidApplicationExtension(project: Project): ApplicationExtension =\n         project.extensions.getByType(ApplicationExtension::class.java)\n \n+    internal fun getConfiguredNdkVersion(project: Project): String? = getAndroidExtension(project).ndkVersion\n-    internal fun getConfiguredNdkVersion(project: Project): String? =\n-        project.extensions.findByType(ApplicationExtension::class.java)?.ndkVersion\n-            ?: getLegacyAndroidExtension(project).ndkVersion\n \n-    /**\n-     * Expected format of getAndroidExtension(project).compileSdkVersion is a string of the form\n-     * `android-` followed by either the numeric version, e.g. `android-35`, or a preview version,\n-     * e.g. `android-UpsideDownCake`.\n-     */\n     @JvmStatic\n     @JvmName(\"getCompileSdkFromProject\")\n+    internal fun getCompileSdkFromProject(project: Project): String {\n+        val android = getAndroidExtension(project)\n+        return android.compileSdkPreview ?: requireNotNull(android.compileSdk).toString()\n+    }\n-    internal fun getCompileSdkFromProject(project: Project): String = getLegacyAndroidExtension(project).compileSdkVersion!!.substring(8)\n \n     /**\n      * Returns:\n@@ -794,7 +770,7 @@\n         }\n \n         // If the project is already configuring a native build, we don't need to do anything.\n+        val gradleProjectAndroidExtension = getAndroidExtension(gradleProject)\n-        val gradleProjectAndroidExtension = getLegacyAndroidExtension(gradleProject)\n         val forcingNotRequired: Boolean =\n             gradleProjectAndroidExtension.externalNativeBuild.cmake.path != null\n         if (forcingNotRequired) {\n@@ -920,7 +896,7 @@\n         gradleProject: Project,\n         flutterSdkRootPath: String\n     ) {\n+        val gradleProjectAndroidExtension = getAndroidExtension(gradleProject)\n-        val gradleProjectAndroidExtension = getLegacyAndroidExtension(gradleProject)\n         gradleProjectAndroidExtension.externalNativeBuild.cmake.path(\n             \"$flutterSdkRootPath/packages/flutter_tools/gradle/src/main/scripts/CMakeLists.txt\"\n         )\ndiff --git a/packages/flutter_tools/gradle/src/main/kotlin/VersionFetcher.kt b/packages/flutter_tools/gradle/src/main/kotlin/VersionFetcher.kt\nindex 46dc5b89b2ce5a7554c0b21c52f8ef25cbe0fed25958dd84f8328998b7df75e6..4d1f77d630b102da5155c716ab0959e1e2dbdc72a02d1b59f66cbcc27bc28c5a\n--- a/packages/flutter_tools/gradle/src/main/kotlin/VersionFetcher.kt\n+++ b/packages/flutter_tools/gradle/src/main/kotlin/VersionFetcher.kt\n@@ -6,10 +6,9 @@\n \n import com.android.build.api.AndroidPluginVersion\n import com.android.build.api.variant.AndroidComponentsExtension\n-import com.android.build.gradle.internal.utils.getKotlinAndroidPluginVersion\n import org.gradle.api.JavaVersion\n import org.gradle.api.Project\n+import org.jetbrains.kotlin.gradle.plugin.getKotlinPluginVersion\n-import org.jetbrains.kotlin.gradle.plugin.KotlinAndroidPluginWrapper\n \n internal object VersionFetcher {\n     /**\n@@ -45,43 +44,8 @@\n      * Returns the version of the Kotlin Gradle plugin.\n      */\n     internal fun getKGPVersion(project: Project): Version? {\n+        // 回读实际加载的KGP资源版本，不以声明版本或Gradle内嵌编译器冒充。\n+        return Version.fromString(project.getKotlinPluginVersion())\n-        // AGP and Kgp have methods for getting kotlin version.\n-        // AGP's method is internal, we try to use it anyway.\n-        // KGP's version in org.jetbrains.kotlin.gradle.plugin.DefaultKotlinBasePlugin is not\n-        // available when this method is called.\n-        // When testing call `setAgpKotlinVersionToNull(project)`.\n-        val agpDefinedKgpVersion = getKotlinAndroidPluginVersion(project)\n-        if (agpDefinedKgpVersion != null && agpDefinedKgpVersion != \"unknown\") {\n-            return Version.fromString(agpDefinedKgpVersion)\n-        }\n-\n-        val kotlinVersionProperty = \"kotlin_version\"\n-        val firstKotlinVersionFieldName = \"pluginVersion\"\n-        val secondKotlinVersionFieldName = \"kotlinPluginVersion\"\n-        // This property corresponds to application of the Kotlin Gradle plugin in the\n-        // top-level build.gradle file.\n-        if (project.hasProperty(kotlinVersionProperty)) {\n-            return Version.fromString(project.properties[kotlinVersionProperty] as String)\n-        }\n-        val kotlinPlugin =\n-            project.plugins\n-                .findPlugin(KotlinAndroidPluginWrapper::class.java)\n-        // Partial implementation of getKotlinPluginVersion from the comment above.\n-        var versionString: String? = kotlinPlugin?.pluginVersion\n-        if (!versionString.isNullOrEmpty()) {\n-            return Version.fromString(versionString)\n-        }\n-        // Fall back to reflection.\n-        val versionField =\n-            kotlinPlugin?.javaClass?.kotlin?.members?.firstOrNull {\n-                it.name == firstKotlinVersionFieldName || it.name == secondKotlinVersionFieldName\n-            }\n-        versionString = versionField?.call(kotlinPlugin) as String?\n-        return if (versionString == null) {\n-            null\n-        } else {\n-            Version.fromString(versionString)\n-        }\n     }\n }\n \ndiff --git a/packages/flutter_tools/gradle/src/main/kotlin/plugins/PluginHandler.kt b/packages/flutter_tools/gradle/src/main/kotlin/plugins/PluginHandler.kt\nindex 2e0aabbee4b6699ded8fb75fa38347d1fe6d1c719051a2177bfc6ea7595b4817..cbebdcdb654a74d32901f0f6faee04e635c4914ef5826b43308393e547e52cf8\n--- a/packages/flutter_tools/gradle/src/main/kotlin/plugins/PluginHandler.kt\n+++ b/packages/flutter_tools/gradle/src/main/kotlin/plugins/PluginHandler.kt\n@@ -4,13 +4,14 @@\n \n package com.flutter.gradle.plugins\n \n-import com.android.builder.model.BuildType\n+import com.android.build.api.dsl.BuildType\n+import com.android.build.api.dsl.ApplicationBuildType\n import com.flutter.gradle.FlutterExtension\n import com.flutter.gradle.FlutterPluginUtils\n import com.flutter.gradle.FlutterPluginUtils.addApiDependencies\n import com.flutter.gradle.FlutterPluginUtils.buildModeFor\n import com.flutter.gradle.FlutterPluginUtils.getCompileSdkFromProject\n-import com.flutter.gradle.FlutterPluginUtils.getLegacyAndroidExtension\n+import com.flutter.gradle.FlutterPluginUtils.getAndroidExtension\n import com.flutter.gradle.FlutterPluginUtils.isBuiltAsApp\n import com.flutter.gradle.FlutterPluginUtils.supportsBuildMode\n import com.flutter.gradle.NativePluginLoaderReflectionBridge\n@@ -18,7 +19,7 @@\n import org.gradle.api.Project\n import org.jetbrains.kotlin.gradle.plugin.extraProperties\n import java.io.File\n-import com.android.build.gradle.internal.dsl.BuildType as dslBuildType\n+import java.nio.file.Files\n \n /**\n  * Handles interactions with the flutter plugins (not Gradle plugins) used by the Flutter project,\n@@ -87,6 +88,30 @@\n          */\n         private const val WEBSITE_DEPLOYMENT_ANDROID_BUILD_CONFIG = \"https://flutter.dev/to/review-gradle-config\"\n \n+        private fun prepareBuiltInKotlinPluginScript(pluginProject: Project) {\n+            val pubCache = System.getenv(\"PUB_CACHE\") ?: return\n+            val buildFile = pluginProject.buildFile\n+            if (buildFile.extension !in setOf(\"kts\", \"gradle\") || !buildFile.isFile || Files.isSymbolicLink(buildFile.toPath())) return\n+            val hostedRoot = File(pubCache, \"hosted\").canonicalFile.toPath()\n+            val buildPath = buildFile.canonicalFile.toPath()\n+            if (!buildPath.startsWith(hostedRoot)) return\n+            val input = buildFile.readText()\n+            val kotlinPlugin =\n+                Regex(\"\"\"(?m)^\\s*(?:id\\(\\s*[\"'](?:kotlin-android|org\\.jetbrains\\.kotlin\\.android)[\"']\\s*\\)(?:\\s+version\\s+[\"'][^\"']+[\"'])?|id\\s+[\"'](?:kotlin-android|org\\.jetbrains\\.kotlin\\.android)[\"']|kotlin\\(\\s*[\"']android[\"']\\s*\\)(?:\\s+version\\s+[\"'][^\"']+[\"'])?|apply\\(\\s*plugin\\s*=\\s*[\"'](?:kotlin-android|org\\.jetbrains\\.kotlin\\.android)[\"']\\s*\\)|apply\\s+plugin:\\s*[\"'](?:kotlin-android|org\\.jetbrains\\.kotlin\\.android)[\"'])\\s*$\"\"\")\n+            val kotlinClasspath =\n+                Regex(\"\"\"(?m)^\\s*(?:classpath\\(\\s*[\"']org\\.jetbrains\\.kotlin:kotlin-gradle-plugin:[^\"']+[\"']\\s*\\)|classpath\\s+[\"']org\\.jetbrains\\.kotlin:kotlin-gradle-plugin:[^\"']+[\"'])\\s*$\"\"\")\n+            val agpClasspath =\n+                Regex(\"\"\"(?m)^(\\s*)(?:classpath\\(\\s*[\"']com\\.android\\.tools\\.build:gradle:[^\"']+[\"']\\s*\\)|classpath\\s+[\"']com\\.android\\.tools\\.build:gradle:[^\"']+[\"'])\\s*$\"\"\")\n+            if (!kotlinPlugin.containsMatchIn(input) && !kotlinClasspath.containsMatchIn(input) && !agpClasspath.containsMatchIn(input)) return\n+            // 只修改任务PUB_CACHE副本；插件模块统一使用AGP 9.0.1内置Kotlin，不再重复应用KGP。\n+            buildFile.writeText(\n+                input\n+                    .replace(kotlinPlugin, \"\")\n+                    .replace(kotlinClasspath, \"\")\n+                    .replace(agpClasspath, if (buildFile.extension == \"kts\") \"\\$1classpath(\\\"com.android.tools.build:gradle:9.0.1\\\")\" else \"\\$1classpath 'com.android.tools.build:gradle:9.0.1'\")\n+            )\n+        }\n+\n         /**\n          * Performs configuration related to the plugin's Gradle [Project], including\n          * 1. Adding the plugin itself as a dependency to the main project.\n@@ -104,16 +129,28 @@\n                 requireNotNull(pluginObject[\"name\"] as? String) { \"Plugin name must be a string for plugin object: $pluginObject\" }\n             val pluginProject: Project = project.rootProject.findProject(\":$pluginName\") ?: return\n \n+            // Kotlin DSL compiles each plugin script with that plugin's buildscript classpath.\n+            // Publish the extension type there before evaluation so generated accessors stay typed.\n+            prepareBuiltInKotlinPluginScript(pluginProject)\n+            val flutterPluginClasspath = FlutterExtension::class.java.protectionDomain.codeSource.location.toURI()\n+            pluginProject.buildscript.dependencies.add(\"classpath\", pluginProject.files(flutterPluginClasspath))\n+\n             // Apply the \"flutter\" Gradle extension to plugins so that they can use it's vended\n             // compile/target/min sdk values.\n-            pluginProject.extensions.create(\"flutter\", FlutterExtension::class.java)\n+            pluginProject.pluginManager.withPlugin(\"com.android.library\") {\n+                val pluginFlutterExtensionClass =\n+                    pluginProject.buildscript.classLoader.loadClass(FlutterExtension::class.java.name)\n+                pluginProject.extensions.create(\"flutter\", pluginFlutterExtensionClass)\n+            }\n \n             // Add plugin dependency to the app project. We only want to add dependency\n             // for dev dependencies in non-release builds.\n             project.afterEvaluate {\n-                getLegacyAndroidExtension(project).buildTypes.forEach { buildType ->\n+                getAndroidExtension(project).buildTypes.forEach { buildType ->\n                     if (!(pluginObject[\"dev_dependency\"] as Boolean) || buildType.name != \"release\") {\n-                        project.dependencies.add(\"${buildType.name}Api\", pluginProject)\n+                        // AGP 9应用模块必须进入运行时类路径；library模块保留API传递给宿主。\n+                        val dependencyScope = if (isBuiltAsApp(project)) \"Implementation\" else \"Api\"\n+                        project.dependencies.add(\"${buildType.name}$dependencyScope\", pluginProject)\n                     }\n                 }\n             }\n@@ -135,7 +172,7 @@\n                     )\n                 }\n \n-                getLegacyAndroidExtension(project).buildTypes.forEach { buildType ->\n+                getAndroidExtension(project).buildTypes.forEach { buildType ->\n                     addEmbeddingDependencyToPlugin(project, pluginProject, buildType, engineVersion)\n                 }\n             }\n@@ -164,23 +201,15 @@\n             // This allows to build apps with plugins and custom build types or flavors.\n             // However, only copy if the plugin is also an app project, since library projects\n             // cannot have applicationIdSuffix and other app-specific properties.\n-            if (isBuiltAsApp(pluginProject)) {\n-                (getLegacyAndroidExtension(pluginProject).buildTypes as NamedDomainObjectContainer<dslBuildType>)\n-                    .addAll(getLegacyAndroidExtension(project).buildTypes as NamedDomainObjectContainer<dslBuildType>)\n-            } else {\n-                // For library projects, create compatible build types without app-specific properties\n-                getLegacyAndroidExtension(project).buildTypes.forEach { appBuildType ->\n-                    if (getLegacyAndroidExtension(pluginProject).buildTypes.findByName(appBuildType.name) == null) {\n-                        getLegacyAndroidExtension(pluginProject).buildTypes.create(appBuildType.name) {\n-                            // Copy library-compatible properties only\n-                            isDebuggable = appBuildType.isDebuggable\n-                            isMinifyEnabled = appBuildType.isMinifyEnabled\n-                            // Note: applicationIdSuffix and other app-specific properties are intentionally not copied\n-                        }\n-                    }\n-                }\n-            }\n-\n+            // 库模块只复制公开的共同属性，不把应用专属属性写入库扩展。\n+            getAndroidExtension(project).buildTypes.forEach { appBuildType ->\n+                val target = getAndroidExtension(pluginProject).buildTypes.maybeCreate(appBuildType.name)\n+                if (target is ApplicationBuildType && appBuildType is ApplicationBuildType) {\n+                    target.isDebuggable = appBuildType.isDebuggable\n+                }\n+                // Library插件不能先被R8裁空；仅应用插件继承宿主的压缩设置。\n+                target.isMinifyEnabled = isBuiltAsApp(pluginProject) && appBuildType.isMinifyEnabled\n+            }\n             // The embedding is API dependency of the plugin, so the AGP is able to desugar\n             // default method implementations when the interface is implemented by a plugin.\n             //\n@@ -215,7 +244,7 @@\n                 }\n             val pluginProject: Project = project.rootProject.findProject(\":$pluginName\") ?: return\n \n-            getLegacyAndroidExtension(project).buildTypes.forEach { buildType ->\n+            getAndroidExtension(project).buildTypes.forEach { buildType ->\n                 val flutterBuildMode: String = buildModeFor(buildType)\n                 if (flutterBuildMode == \"release\" && (pluginObject[\"dev_dependency\"] as? Boolean == true)) {\n                     // This plugin is a dev dependency will not be included in the\ndiff --git a/packages/flutter_tools/lib/src/android/gradle.dart b/packages/flutter_tools/lib/src/android/gradle.dart\nindex 84ea6ed0fc6f6b86128a220ba9a8830ad2bcd562f8791b9a9c237c29ffa0694e..b0707a83e5359f37073536654f78b8a5d08b94faf18ff40df4a0f52c550e0d74\n--- a/packages/flutter_tools/lib/src/android/gradle.dart\n+++ b/packages/flutter_tools/lib/src/android/gradle.dart\n@@ -41,8 +41,6 @@\n import 'java.dart';\n import 'migrations/android_studio_java_gradle_conflict_migration.dart';\n import 'migrations/cmake_android_16k_pages_migration.dart';\n-import 'migrations/disable_built_in_kotlin_migration.dart';\n-import 'migrations/disable_new_dsl_migration.dart';\n import 'migrations/min_sdk_version_migration.dart';\n import 'migrations/multidex_removal_migration.dart';\n import 'migrations/top_level_gradle_build_file_migration.dart';\n@@ -517,8 +515,6 @@\n       MinSdkVersionMigration(project.android, _logger),\n       MultidexRemovalMigration(project.android, _logger),\n       CmakeAndroid16kPagesMigration(project.android, _logger),\n-      DisableBuiltInKotlinMigration(project.android, _logger),\n-      DisableNewDslMigration(project.android, _logger),\n     ];\n \n     final migration = ProjectMigration(migrators);\ndiff --git a/packages/flutter_tools/lib/src/android/gradle_errors.dart b/packages/flutter_tools/lib/src/android/gradle_errors.dart\nindex 7a3ba07b414a806e949dcde01beeaa8128c68d3d7d090bc1b26b5245b074cc8b..d79d05bbbf71f3c85e6bb2e044cbcf1755ba83e2aeb91cf5b729795cae8bcb15\n--- a/packages/flutter_tools/lib/src/android/gradle_errors.dart\n+++ b/packages/flutter_tools/lib/src/android/gradle_errors.dart\n@@ -689,10 +689,6 @@\n const String kMigrateToBuiltInKotlinDocsUrl =\n     'https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin';\n \n-/// The URL for documentation on opting out of the new AGP DSL.\n-const String kOptOutOfNewDslDocsUrl =\n-    'https://developer.android.com/build/releases/agp-9-0-0-release-notes';\n-\n /// Handler when applying the kotlin-android plugin results in a build failure. This failure occurs when\n /// using AGP 9+ because built-in Kotlin has become the default behavior.\n @visibleForTesting\n@@ -715,9 +711,7 @@\n   eventLabel: 'applying-kotlin-android-plugin-error',\n );\n \n+/// 插件应用失败时保留真实报错；不得建议关闭新DSL来绕过修订验收。\n-/// Handler when using the new AGP DSL interfaces. Starting AGP 9+, only the new\n-/// DSL interfaces are used. This results in a failure because we still depend\n-/// on old DSL types.\n @visibleForTesting\n final useNewAgpDslErrorHandler = GradleHandledError(\n   test: _lineMatcher(const <String>[\n@@ -731,8 +725,7 @@\n           '''\n ${globals.logger.terminal.warningMark} Starting AGP 9+, only the new DSL interface will be read.\n This results in a build failure when applying the Flutter Gradle plugin at ${appGradleFile.path}.\n+\\nVerify the registered Flutter tool revision and inspect the original plugin error.\n-\\nTo resolve this update flutter or opt out of `android.newDsl`.\n-For instructions on how to opt out, see: $kOptOutOfNewDslDocsUrl\n \\nIf you are not upgrading to AGP 9+, run `flutter analyze --suggestions` to check for incompatible dependencies.''',\n           title: _boxTitle,\n         );\ndiff --git a/packages/flutter_tools/templates/app/android.tmpl/gradle.properties.tmpl b/packages/flutter_tools/templates/app/android.tmpl/gradle.properties.tmpl\nindex 0f82b18017fba6bb5ce3aa4b2d1a00c9382fc8aae7b1d9326e44b18abd66d80b..ce93cd30017008fa20352b9b8debd2554ee946d0ba993329dd251be0207f8dd8\n--- a/packages/flutter_tools/templates/app/android.tmpl/gradle.properties.tmpl\n+++ b/packages/flutter_tools/templates/app/android.tmpl/gradle.properties.tmpl\n@@ -1,6 +1,5 @@\n org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError\n android.useAndroidX=true\n+# 受控工具仅使用新DSL和内置Kotlin。\n+android.newDsl=true\n+android.builtInKotlin=true\n-# This newDsl flag was added by the Flutter template\n-android.newDsl=false\n-# This builtInKotlin flag was added by the Flutter template\n-android.builtInKotlin=false\ndiff --git a/packages/flutter_tools/templates/module/android/gradle/gradle.properties.tmpl b/packages/flutter_tools/templates/module/android/gradle/gradle.properties.tmpl\nindex 0f82b18017fba6bb5ce3aa4b2d1a00c9382fc8aae7b1d9326e44b18abd66d80b..ce93cd30017008fa20352b9b8debd2554ee946d0ba993329dd251be0207f8dd8\n--- a/packages/flutter_tools/templates/module/android/gradle/gradle.properties.tmpl\n+++ b/packages/flutter_tools/templates/module/android/gradle/gradle.properties.tmpl\n@@ -1,6 +1,5 @@\n org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError\n android.useAndroidX=true\n+# 受控工具仅使用新DSL和内置Kotlin。\n+android.newDsl=true\n+android.builtInKotlin=true\n-# This newDsl flag was added by the Flutter template\n-android.newDsl=false\n-# This builtInKotlin flag was added by the Flutter template\n-android.builtInKotlin=false\ndiff --git a/packages/flutter_tools/gradle/src/test/kotlin/FlutterPluginTest.kt b/packages/flutter_tools/gradle/src/test/kotlin/FlutterPluginTest.kt\nindex d275246cdbb7f3ddd6dba8fbbd355067ffa167c7de9ded33707c2f30f877f5a5..ae08e2e418eed63882e86852059a8cc25d7d831454cb912b2ddc33071c13ce1b\n--- a/packages/flutter_tools/gradle/src/test/kotlin/FlutterPluginTest.kt\n+++ b/packages/flutter_tools/gradle/src/test/kotlin/FlutterPluginTest.kt\n@@ -1,342 +1,63 @@\n+// Copyright 2014 The Flutter Authors. All rights reserved.\n+// Use of this source code is governed by a BSD-style license that can be\n+// found in the LICENSE file.\n+\n package com.flutter.gradle\n \n+import com.android.build.api.variant.BuiltArtifactsLoader\n+import com.android.build.api.variant.BuiltArtifacts\n+import com.android.build.api.variant.BuiltArtifact\n-import com.android.build.api.dsl.ApplicationBuildType\n-import com.android.build.api.dsl.ApplicationDefaultConfig\n-import com.android.build.api.dsl.ApplicationExtension\n-import com.android.build.api.dsl.CommonExtension\n-import com.android.build.api.dsl.LibraryExtension\n-import com.android.build.api.variant.AndroidComponentsExtension\n-import com.android.build.gradle.AbstractAppExtension\n-import com.android.build.gradle.BaseExtension\n-import com.android.build.gradle.api.AndroidSourceDirectorySet\n-import com.android.build.gradle.internal.core.InternalBaseVariant\n-import com.android.build.gradle.tasks.MergeSourceSetFolders\n-import com.android.build.gradle.tasks.ProcessAndroidResources\n-import com.flutter.gradle.tasks.FlutterTask\n-import com.flutter.gradle.tasks.PrintTask\n import io.mockk.every\n import io.mockk.mockk\n-import io.mockk.mockkObject\n-import io.mockk.slot\n-import io.mockk.verify\n-import org.gradle.api.Action\n-import org.gradle.api.Project\n-import org.gradle.api.Task\n import org.gradle.api.file.Directory\n+import org.gradle.testfixtures.ProjectBuilder\n-import org.gradle.api.tasks.Copy\n-import org.gradle.api.tasks.TaskContainer\n-import org.gradle.api.tasks.TaskProvider\n-import org.jetbrains.kotlin.gradle.plugin.extraProperties\n-import org.junit.jupiter.api.Assertions.fail\n import org.junit.jupiter.api.io.TempDir\n import java.nio.file.Path\n-import kotlin.io.path.writeText\n import kotlin.test.Test\n+import kotlin.test.assertEquals\n+import kotlin.test.assertFailsWith\n+import kotlin.test.assertTrue\n-import kotlin.test.assertContains\n \n class FlutterPluginTest {\n     @Test\n+    fun `APK任务从公开输出清单读取且缺失清单时失败`(@TempDir root: Path) {\n+        val project = ProjectBuilder.builder().withProjectDir(root.toFile()).build()\n+        val input = root.resolve(\"apk\").toFile().apply { mkdirs() }\n+        val apk = input.resolve(\"upstream-name.apk\").apply { writeText(\"verified fixture\") }\n+        val task = project.tasks.register(\"copyFlutterApkRelease\", FlutterApkTask::class.java).get()\n+        task.inputDirectory.set(input)\n+        task.destinationDirectory.set(root.resolve(\"output\").toFile())\n+        task.buildMode.set(\"release\")\n+        task.flavor.set(\"Shop\")\n+        val metadata = mockk<BuiltArtifacts>()\n+        val artifact = mockk<BuiltArtifact>()\n+        every { artifact.outputFile } returns apk.absolutePath\n+        every { artifact.filters } returns emptyList()\n+        every { metadata.elements } returns listOf(artifact)\n+        val loader = mockk<BuiltArtifactsLoader>()\n+        every { loader.load(any<Directory>()) } returns metadata\n+        task.loader.set(loader)\n+        task.copyApks()\n+        val result = root.resolve(\"output/app-shop-release.apk\").toFile()\n+        assertEquals(\"verified fixture\", result.readText())\n+        every { loader.load(any<Directory>()) } returns null\n+        assertFailsWith<IllegalArgumentException> { task.copyApks() }\n+        assertEquals(\"verified fixture\", result.readText())\n-    fun `FlutterPlugin apply() adds expected tasks`(\n-        @TempDir tempDir: Path\n-    ) {\n-        val projectDir = tempDir.resolve(\"project-dir\").resolve(\"android\").resolve(\"app\")\n-        projectDir.toFile().mkdirs()\n-        val settingsFile = projectDir.parent.resolve(\"settings.gradle\")\n-        settingsFile.writeText(\"empty for now\")\n-        val fakeFlutterSdkDir = tempDir.resolve(\"fake-flutter-sdk\")\n-        fakeFlutterSdkDir.toFile().mkdirs()\n-        val fakeCacheDir = fakeFlutterSdkDir.resolve(\"bin\").resolve(\"cache\")\n-        fakeCacheDir.toFile().mkdirs()\n-        val fakeEngineStampFile = fakeCacheDir.resolve(\"engine.stamp\")\n-        fakeEngineStampFile.writeText(FAKE_ENGINE_STAMP)\n-        val fakeEngineRealmFile = fakeCacheDir.resolve(\"engine.realm\")\n-        fakeEngineRealmFile.writeText(FAKE_ENGINE_REALM)\n-        val project = mockk<Project>(relaxed = true)\n-        val mockAbstractAppExtension =\n-            mockk<AbstractAppExtension>(\n-                moreInterfaces = arrayOf(ApplicationExtension::class),\n-                relaxed = true\n-            )\n-        val mockLibraryExtension = mockk<LibraryExtension>(relaxed = true)\n-        every { project.extensions.findByType(AbstractAppExtension::class.java) } returns mockAbstractAppExtension\n-        val mockAndroidComponentsExtension = mockk<AndroidComponentsExtension<*, *, *>>(relaxed = true)\n-        every { project.extensions.getByType(AndroidComponentsExtension::class.java) } returns mockAndroidComponentsExtension\n-        every { project.extensions.findByType(AndroidComponentsExtension::class.java) } returns mockAndroidComponentsExtension\n-        val mockSelector = mockk<com.android.build.api.variant.VariantSelector>(relaxed = true)\n-        every { mockAndroidComponentsExtension.selector() } returns mockSelector\n-        every { mockSelector.all() } returns mockSelector\n-        every { mockSelector.withName(any<String>()) } returns mockSelector\n-        every { project.extensions.getByType(AbstractAppExtension::class.java) } returns mockAbstractAppExtension\n-        every { project.extensions.getByType(LibraryExtension::class.java) } returns mockLibraryExtension\n-        every { project.extensions.findByName(\"android\") } returns mockAbstractAppExtension\n-        every { project.projectDir } returns projectDir.toFile()\n-        every { project.findProperty(\"flutter.sdk\") } returns fakeFlutterSdkDir.toString()\n-        every { project.file(fakeFlutterSdkDir.toString()) } returns fakeFlutterSdkDir.toFile()\n-        val flutterExtension = FlutterExtension()\n-        every { project.extensions.create(\"flutter\", any<Class<*>>()) } returns flutterExtension\n-        every { project.extensions.findByType(FlutterExtension::class.java) } returns flutterExtension\n-        val mockBaseExtension = mockk<BaseExtension>(relaxed = true)\n-        val mockCommonExtension = mockk<CommonExtension<*, *, *, *, *, *>>(relaxed = true)\n-        val mockDebugBuildType = mockk<com.android.build.api.dsl.ApplicationBuildType>(relaxed = true)\n-        val mockReleaseBuildType = mockk<com.android.build.api.dsl.ApplicationBuildType>(relaxed = true)\n-\n-        // Cast our multi-interface mock instead of creating a brand new one\n-        val mockApplicationExtension = mockAbstractAppExtension as ApplicationExtension\n-\n-        // Mock buildTypes on our new dual-purpose mock so AgpCommonExtensionWrapper can read them\n-        every { mockApplicationExtension.buildTypes.getByName(\"debug\") } returns mockDebugBuildType\n-        every { mockApplicationExtension.buildTypes.getByName(\"release\") } returns mockReleaseBuildType\n-\n-        // Keep the CommonExtension mocks just in case other parts of the plugin look for it\n-        every { mockCommonExtension.buildTypes.getByName(\"debug\") } returns mockDebugBuildType\n-        every { mockCommonExtension.buildTypes.getByName(\"release\") } returns mockReleaseBuildType\n-\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n-        every { project.extensions.findByType(CommonExtension::class.java) } returns mockCommonExtension\n-\n-        // Pass the dual-purpose mock for any ApplicationExtension lookups\n-        every { project.extensions.findByType(ApplicationExtension::class.java) } returns mockApplicationExtension\n-        every { project.extensions.getByType(ApplicationExtension::class.java) } returns mockApplicationExtension\n-\n-        val mockApplicationDefaultConfig =\n-            mockk<com.android.build.gradle.internal.dsl.DefaultConfig>(\n-                moreInterfaces = arrayOf(ApplicationDefaultConfig::class),\n-                relaxed = true\n-            )\n-        every { mockApplicationExtension.defaultConfig } returns mockApplicationDefaultConfig\n-        every { project.rootProject } returns project\n-        every { project.state.failure as Throwable? } returns null\n-        val mockDirectory = mockk<Directory>(relaxed = true)\n-        every { project.layout.buildDirectory.get() } returns mockDirectory\n-        val mockAndroidSourceSet = mockk<com.android.build.gradle.api.AndroidSourceSet>(relaxed = true)\n-        val mockAndroidSourceDirectorySet = mockk<AndroidSourceDirectorySet>(relaxed = true)\n-        every { mockAndroidSourceSet.jniLibs.srcDir(any()) } returns mockAndroidSourceDirectorySet\n-        every { mockAbstractAppExtension.sourceSets.getByName(\"main\") } returns mockAndroidSourceSet\n-        // mock return of NativePluginLoaderReflectionBridge.getPlugins\n-        mockkObject(NativePluginLoaderReflectionBridge)\n-        every { NativePluginLoaderReflectionBridge.getPlugins(any(), any()) } returns\n-            listOf()\n-        // mock method calls that are invoked by the args to NativePluginLoaderReflectionBridge\n-        every { project.extraProperties } returns mockk()\n-        every { project.file(flutterExtension.source!!) } returns mockk()\n-        val flutterPlugin = FlutterPlugin()\n-        flutterPlugin.apply(project)\n-\n-        verify { project.tasks.register(\"generateLockfiles\", any()) }\n-        val registeredPrintTasks = mutableListOf<String>()\n-        verify {\n-            project.tasks.register(capture(registeredPrintTasks), PrintTask::class.java, any())\n-        }\n-\n-        assertContains(registeredPrintTasks, \"javaVersion\")\n-        assertContains(registeredPrintTasks, \"kgpVersion\")\n-        assertContains(registeredPrintTasks, \"printBuildVariants\")\n-        assertContains(registeredPrintTasks, \"printNdkVersion\")\n     }\n \n     @Test\n+    fun `资源任务只写自己的生成目录并保存Flutter目录层级`(@TempDir root: Path) {\n+        val project = ProjectBuilder.builder().withProjectDir(root.toFile()).build()\n+        val input = root.resolve(\"input\").toFile().apply { mkdirs() }\n+        input.resolve(\"AssetManifest.bin\").writeText(\"asset fixture\")\n+        val other = root.resolve(\"other\").toFile().apply { mkdirs() }\n+        other.resolve(\"keep\").writeText(\"other task\")\n+        val task = project.tasks.register(\"copyFlutterAssetsRelease\", FlutterAssetsTask::class.java).get()\n+        task.destinationDirectory.set(root.resolve(\"output\").toFile())\n+        task.from(input) { into(\"flutter_assets\") }\n+        task.into(task.destinationDirectory)\n+        task.actions.forEach { it.execute(task) }\n+        assertTrue(root.resolve(\"output/flutter_assets/AssetManifest.bin\").toFile().isFile)\n+        assertEquals(\"other task\", other.resolve(\"keep\").readText())\n-    fun `copyFlutterAssets task sets filePermissions correctly`(\n-        @TempDir tempDir: Path\n-    ) {\n-        val projectDir = tempDir.resolve(\"project-dir\").resolve(\"android\").resolve(\"app\")\n-        projectDir.toFile().mkdirs()\n-        val settingsFile = projectDir.parent.resolve(\"settings.gradle\")\n-        settingsFile.writeText(\"empty for now\")\n-        val fakeFlutterSdkDir = tempDir.resolve(\"fake-flutter-sdk\")\n-        fakeFlutterSdkDir.toFile().mkdirs()\n-        val fakeCacheDir = fakeFlutterSdkDir.resolve(\"bin\").resolve(\"cache\")\n-        fakeCacheDir.toFile().mkdirs()\n-        val fakeEngineStampFile = fakeCacheDir.resolve(\"engine.stamp\")\n-        fakeEngineStampFile.writeText(FAKE_ENGINE_STAMP)\n-        val fakeEngineRealmFile = fakeCacheDir.resolve(\"engine.realm\")\n-        fakeEngineRealmFile.writeText(FAKE_ENGINE_REALM)\n-        val project = mockk<Project>(relaxed = true)\n-        val mockAbstractAppExtension =\n-            mockk<AbstractAppExtension>(\n-                moreInterfaces = arrayOf(ApplicationExtension::class),\n-                relaxed = true\n-            )\n-        every { project.extensions.findByType(AbstractAppExtension::class.java) } returns mockAbstractAppExtension\n-        every { project.extensions.getByType(AbstractAppExtension::class.java) } returns mockAbstractAppExtension\n-        every { project.extensions.findByName(\"android\") } returns mockAbstractAppExtension\n-        val mockAndroidComponentsExtension = mockk<AndroidComponentsExtension<*, *, *>>(relaxed = true)\n-        every { project.extensions.getByType(AndroidComponentsExtension::class.java) } returns mockAndroidComponentsExtension\n-        every { project.extensions.findByType(AndroidComponentsExtension::class.java) } returns mockAndroidComponentsExtension\n-        val mockSelector = mockk<com.android.build.api.variant.VariantSelector>(relaxed = true)\n-        every { mockAndroidComponentsExtension.selector() } returns mockSelector\n-        every { mockSelector.all() } returns mockSelector\n-        every { mockSelector.withName(any<String>()) } returns mockSelector\n-        every { project.projectDir } returns projectDir.toFile()\n-        every { project.findProperty(\"flutter.sdk\") } returns fakeFlutterSdkDir.toString()\n-        every { project.file(fakeFlutterSdkDir.toString()) } returns fakeFlutterSdkDir.toFile()\n-        val flutterExtension = FlutterExtension()\n-        every { project.extensions.create(\"flutter\", any<Class<*>>()) } returns flutterExtension\n-        every { project.extensions.findByType(FlutterExtension::class.java) } returns flutterExtension\n-        val mockBaseExtension = mockk<BaseExtension>(relaxed = true)\n-        val mockCommonExtension = mockk<CommonExtension<*, *, *, *, *, *>>(relaxed = true)\n-        val mockDebugBuildType = mockk<com.android.build.api.dsl.ApplicationBuildType>(relaxed = true)\n-        val mockReleaseBuildType = mockk<com.android.build.api.dsl.ApplicationBuildType>(relaxed = true)\n-\n-        // Cast our multi-interface mock instead of creating a brand new one\n-        val mockApplicationExtension = mockAbstractAppExtension as ApplicationExtension\n-\n-        // Mock buildTypes on our new dual-purpose mock so AgpCommonExtensionWrapper can read them\n-        every { mockApplicationExtension.buildTypes.getByName(\"debug\") } returns mockDebugBuildType\n-        every { mockApplicationExtension.buildTypes.getByName(\"release\") } returns mockReleaseBuildType\n-\n-        // Keep the CommonExtension mocks just in case other parts of the plugin look for it\n-        every { mockCommonExtension.buildTypes.getByName(\"debug\") } returns mockDebugBuildType\n-        every { mockCommonExtension.buildTypes.getByName(\"release\") } returns mockReleaseBuildType\n-\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n-        every { project.extensions.findByType(CommonExtension::class.java) } returns mockCommonExtension\n-\n-        // Pass the dual-purpose mock for any ApplicationExtension lookups\n-        every { project.extensions.findByType(ApplicationExtension::class.java) } returns mockApplicationExtension\n-        every { project.extensions.getByType(ApplicationExtension::class.java) } returns mockApplicationExtension\n-\n-        val mockApplicationDefaultConfig =\n-            mockk<com.android.build.gradle.internal.dsl.DefaultConfig>(\n-                moreInterfaces = arrayOf(ApplicationDefaultConfig::class),\n-                relaxed = true\n-            )\n-        every { mockApplicationExtension.defaultConfig } returns mockApplicationDefaultConfig\n-        every { project.rootProject } returns project\n-        every { project.state.failure as Throwable? } returns null\n-        val mockDirectory = mockk<Directory>(relaxed = true)\n-        every { project.layout.buildDirectory.get() } returns mockDirectory\n-        val mockAndroidSourceSet = mockk<com.android.build.gradle.api.AndroidSourceSet>(relaxed = true)\n-        val mockAndroidSourceDirectorySet = mockk<AndroidSourceDirectorySet>(relaxed = true)\n-        every { mockAndroidSourceSet.jniLibs.srcDir(any()) } returns mockAndroidSourceDirectorySet\n-        every { mockAbstractAppExtension.sourceSets.getByName(\"main\") } returns mockAndroidSourceSet\n-        // mock return of NativePluginLoaderReflectionBridge.getPlugins\n-        mockkObject(NativePluginLoaderReflectionBridge)\n-        every { NativePluginLoaderReflectionBridge.getPlugins(any(), any()) } returns\n-            listOf()\n-        // mock method calls that are invoked by the args to NativePluginLoaderReflectionBridge\n-        every { project.extraProperties } returns mockk()\n-        every { project.file(flutterExtension.source!!) } returns mockk()\n-        // Set up the task container and our task capture\n-        val taskContainer = mockk<TaskContainer>(relaxed = true)\n-        every { project.tasks } returns taskContainer\n-        val copyTaskActionCaptor = slot<Action<Copy>>()\n-        val copyTask = mockk<Copy>(relaxed = true)\n-        val mockVariant = mockk<com.android.build.gradle.api.ApplicationVariant>(relaxed = true)\n-        every { mockVariant.name } returns \"debug\"\n-        every { mockVariant.buildType.name } returns \"debug\"\n-        every { mockVariant.flavorName } returns \"\"\n-        val mergedFlavor = mockk<InternalBaseVariant.MergedFlavor>(relaxed = true)\n-        every { mockVariant.mergedFlavor } returns mergedFlavor\n-        val apiLevel = mockk<com.android.builder.model.ApiVersion>(relaxed = true)\n-        every { apiLevel.apiLevel } returns 21\n-        every { mergedFlavor.minSdkVersion } returns apiLevel\n-        val variantOutput = mockk<com.android.build.gradle.api.BaseVariantOutput>(relaxed = true)\n-        val outputsIterator = mockk<MutableIterator<com.android.build.gradle.api.BaseVariantOutput>>()\n-        every { outputsIterator.hasNext() } returns true andThen false\n-        every { outputsIterator.next() } returns variantOutput\n-        val variantOutputCollection = mockk<org.gradle.api.DomainObjectCollection<com.android.build.gradle.api.BaseVariantOutput>>()\n-        every { variantOutputCollection.iterator() } returns outputsIterator\n-        every { mockVariant.outputs } returns variantOutputCollection\n-        val processResourcesProvider = mockk<TaskProvider<ProcessAndroidResources>>(relaxed = true)\n-        every { processResourcesProvider.hint(ProcessAndroidResources::class).get() } returns mockk<ProcessAndroidResources>(relaxed = true)\n-        every { variantOutput.processResourcesProvider } returns processResourcesProvider\n-        val assembleTask = mockk<Task>(relaxed = true)\n-        val assembleTaskProvider = mockk<TaskProvider<Task>>(relaxed = true)\n-        every { assembleTaskProvider.get() } returns assembleTask\n-        every { mockVariant.assembleProvider } returns assembleTaskProvider\n-        val variants = listOf(mockVariant)\n-        val variantsIterator = mockk<MutableIterator<com.android.build.gradle.api.ApplicationVariant>>()\n-        every { variantsIterator.hasNext() } returns true andThen false\n-        every { variantsIterator.next() } returns mockVariant\n-        val variantCollection = mockk<org.gradle.api.DomainObjectSet<com.android.build.gradle.api.ApplicationVariant>>()\n-        every { mockAbstractAppExtension.applicationVariants } returns variantCollection\n-        every { variantCollection.iterator() } returns variantsIterator\n-        every {\n-            variantCollection.configureEach(any<Action<com.android.build.gradle.api.ApplicationVariant>>())\n-        } answers {\n-            variants.forEach { firstArg<Action<com.android.build.gradle.api.ApplicationVariant>>().execute(it) }\n-        }\n-        every { mockVariant.mergeAssetsProvider.hint(MergeSourceSetFolders::class).get() } returns\n-            mockk<MergeSourceSetFolders>(relaxed = true)\n-        val flutterTask = mockk<FlutterTask>(relaxed = true)\n-        val copySpec = mockk<org.gradle.api.file.CopySpec>(relaxed = true)\n-        every {\n-            (flutterTask).assets\n-        } returns copySpec\n-        val flutterTaskProvider = mockk<TaskProvider<FlutterTask>>(relaxed = true)\n-        every {\n-            flutterTaskProvider.hint(FlutterTask::class).get()\n-        } returns flutterTask\n-        every {\n-            taskContainer.register(\n-                match { it.contains(\"compileFlutterBuild\") },\n-                any<Class<FlutterTask>>(),\n-                any()\n-            )\n-        } answers {\n-            flutterTaskProvider\n-        }\n-        // Actual task that should be captured to test if permissions have been set\n-        val mockCopyTaskProvider = mockk<TaskProvider<Copy>>(relaxed = true)\n-        every { mockCopyTaskProvider.hint(Copy::class).get() } returns copyTask\n-        every {\n-            taskContainer.register(\n-                match { it.startsWith(\"copyFlutterAssets\") },\n-                eq(Copy::class.java),\n-                capture(copyTaskActionCaptor)\n-            )\n-        } answers {\n-            mockCopyTaskProvider\n-        }\n-        val mockJarTaskProvider = mockk<TaskProvider<org.gradle.api.tasks.bundling.Jar>>(relaxed = true)\n-        every { mockJarTaskProvider.hint(org.gradle.api.tasks.bundling.Jar::class).get() } returns\n-            mockk<org.gradle.api.tasks.bundling.Jar>(relaxed = true)\n-        every {\n-            taskContainer.register(\n-                match { it.contains(\"packJniLibs\") },\n-                eq(org.gradle.api.tasks.bundling.Jar::class.java),\n-                any()\n-            )\n-        } answers {\n-            mockJarTaskProvider\n-        }\n-        val mockTaskProvider = mockk<TaskProvider<Task>>(relaxed = true)\n-        every { mockTaskProvider.hint(Task::class).get() } returns mockk<Task>(relaxed = true)\n-        every {\n-            taskContainer.named(any<String>())\n-        } returns mockTaskProvider\n-        val flutterPlugin = FlutterPlugin()\n-        flutterPlugin.apply(project)\n-\n-        copyTaskActionCaptor.captured.execute(copyTask)\n-        val filePermissionsActionCaptor = slot<Action<org.gradle.api.file.ConfigurableFilePermissions>>()\n-        verify {\n-            copyTask.filePermissions(capture(filePermissionsActionCaptor))\n-        }\n-        if (filePermissionsActionCaptor.isCaptured) {\n-            val mockFilePermissionSet = mockk<org.gradle.api.file.ConfigurableFilePermissions>(relaxed = true)\n-            filePermissionsActionCaptor.captured.execute(mockFilePermissionSet)\n-            val userPermissionsActionCaptor = slot<Action<org.gradle.api.file.ConfigurableUserClassFilePermissions>>()\n-            verify {\n-                mockFilePermissionSet.user(capture(userPermissionsActionCaptor))\n-            }\n-            if (userPermissionsActionCaptor.isCaptured) {\n-                val mockUserPermission = mockk<org.gradle.api.file.ConfigurableUserClassFilePermissions>(relaxed = true)\n-                userPermissionsActionCaptor.captured.execute(mockUserPermission)\n-                verify {\n-                    mockUserPermission.read = true\n-                    mockUserPermission.write = true\n-                }\n-            } else {\n-                fail(\"User permissions configuration action was not captured\")\n-            }\n-        } else {\n-            fail(\"FilePermissions configuration action was not captured\")\n-        }\n     }\n-\n-    companion object {\n-        const val FAKE_ENGINE_STAMP = \"901b0f1afe77c3555abee7b86a26aaa37f131379\"\n-        const val FAKE_ENGINE_REALM = \"made_up_realm\"\n-    }\n }\ndiff --git a/packages/flutter_tools/gradle/src/test/kotlin/VersionFetcherTest.kt b/packages/flutter_tools/gradle/src/test/kotlin/VersionFetcherTest.kt\nindex 47acb2223475b9b6aa230f524982c49b457cfa9d05aa74d57f597db9357adf60..6c80f5e445f94f211d5d86be4ac534c3d9d85bd2b2a71ed71d111dd3a80bc301\n--- a/packages/flutter_tools/gradle/src/test/kotlin/VersionFetcherTest.kt\n+++ b/packages/flutter_tools/gradle/src/test/kotlin/VersionFetcherTest.kt\n@@ -6,65 +6,42 @@\n \n import com.android.build.api.AndroidPluginVersion\n import com.android.build.api.variant.AndroidComponentsExtension\n-import com.flutter.gradle.testing.setAgpKotlinVersionToNull\n import io.mockk.every\n import io.mockk.mockk\n+import io.mockk.mockkStatic\n+import io.mockk.unmockkStatic\n import org.gradle.api.Project\n+import org.jetbrains.kotlin.gradle.plugin.getKotlinPluginVersion\n-import org.jetbrains.kotlin.gradle.plugin.KotlinAndroidPluginWrapper\n import kotlin.test.Test\n import kotlin.test.assertEquals\n+import kotlin.test.assertFailsWith\n \n class VersionFetcherTest {\n-    // getGradleVersion\n     @Test\n+    fun `Gradle版本从实际运行对象读取`() {\n-    fun `getGradleVersion returns version when gradleVersion is set`() {\n-        val gradleVersion = Version(1, 9, 20)\n         val project = mockk<Project>()\n+        every { project.gradle.gradleVersion } returns \"9.1.0\"\n+        assertEquals(Version(9, 1, 0), VersionFetcher.getGradleVersion(project))\n-        every { project.gradle.gradleVersion } returns gradleVersion.toString()\n-        assertEquals(VersionFetcher.getGradleVersion(project), gradleVersion)\n     }\n \n     @Test\n+    fun `AGP版本从公开组件扩展读取`() {\n-    fun `getGradleVersion returns version when gradleVersion has hyphen`() {\n         val project = mockk<Project>()\n+        val extension = mockk<AndroidComponentsExtension<*, *, *>>()\n+        every { project.extensions.findByType(AndroidComponentsExtension::class.java) } returns extension\n+        every { extension.pluginVersion } returns AndroidPluginVersion(9, 0, 1)\n+        assertEquals(AndroidPluginVersion(9, 0, 1), VersionFetcher.getAGPVersion(project))\n-        every { project.gradle.gradleVersion } returns \"2.1.20-2\"\n-        assertEquals(VersionFetcher.getGradleVersion(project), Version(2, 1, 20))\n     }\n \n-    // getAGPVersion\n     @Test\n+    fun `Kotlin版本仅从已加载插件的公开接口读取`() {\n-    fun `getAGPVersion returns version when agpVersion is set`() {\n-        val agpVersion = AndroidPluginVersion(8, 3, 0)\n         val project = mockk<Project>()\n+        mockkStatic(\"org.jetbrains.kotlin.gradle.plugin.KotlinPluginWrapperKt\")\n+        try {\n+            every { project.getKotlinPluginVersion() } returns \"2.2.20\"\n+            assertEquals(Version(2, 4, 10), VersionFetcher.getKGPVersion(project))\n+            every { project.getKotlinPluginVersion() } throws IllegalStateException(\"invalid plugin\")\n+            assertFailsWith<IllegalStateException> { VersionFetcher.getKGPVersion(project) }\n+        } finally { unmockkStatic(\"org.jetbrains.kotlin.gradle.plugin.KotlinPluginWrapperKt\") }\n-        val mockAndroidComponentsExtension = mockk<AndroidComponentsExtension<*, *, *>>()\n-        every { project.extensions.findByType(AndroidComponentsExtension::class.java) } returns mockAndroidComponentsExtension\n-        every { mockAndroidComponentsExtension.pluginVersion } returns agpVersion\n-        assertEquals(VersionFetcher.getAGPVersion(project).toString(), agpVersion.toString())\n     }\n-\n-    // getKGPVersion\n-    @Test\n-    fun `getKGPVersion returns version when kotlin_version is set`() {\n-        val kgpVersion = Version(1, 9, 20)\n-        val project = mockk<Project>()\n-        setAgpKotlinVersionToNull(project)\n-        every { project.hasProperty(eq(\"kotlin_version\")) } returns true\n-        every { project.properties[\"kotlin_version\"] } returns kgpVersion.toString()\n-        val result = VersionFetcher.getKGPVersion(project)\n-        assertEquals(kgpVersion, result!!)\n-    }\n-\n-    @Test\n-    fun `getKGPVersion returns version from KotlinAndroidPluginWrapper`() {\n-        val kgpVersion = Version(1, 9, 20)\n-        val project = mockk<Project>()\n-        setAgpKotlinVersionToNull(project)\n-        every { project.hasProperty(eq(\"kotlin_version\")) } returns false\n-        every { project.plugins.findPlugin(KotlinAndroidPluginWrapper::class.java) } returns\n-            mockk<KotlinAndroidPluginWrapper> {\n-                every { pluginVersion } returns kgpVersion.toString()\n-            }\n-        val result = VersionFetcher.getKGPVersion(project)\n-        assertEquals(kgpVersion, result!!)\n-    }\n }\ndiff --git a/packages/flutter_tools/gradle/src/test/kotlin/FlutterPluginUtilsTest.kt b/packages/flutter_tools/gradle/src/test/kotlin/FlutterPluginUtilsTest.kt\nindex d595101c31d071fd2f4cca3ddae33d59d7e13f4b3bf2c4c897d88a7db72cbbda..52d0d9d2eb6ca5de164b69a2916bd293d5bb16a2abc706ee5a9cb37884997021\n--- a/packages/flutter_tools/gradle/src/test/kotlin/FlutterPluginUtilsTest.kt\n+++ b/packages/flutter_tools/gradle/src/test/kotlin/FlutterPluginUtilsTest.kt\n@@ -9,10 +9,10 @@\n import com.android.build.api.variant.AndroidComponentsExtension\n import com.android.build.api.variant.Variant\n import com.android.build.api.variant.VariantBuilder\n+import com.android.build.api.dsl.CommonExtension\n+import com.android.build.api.dsl.Cmake\n+import com.android.build.api.dsl.DefaultConfig\n+import com.android.build.api.dsl.ApplicationBuildType\n-import com.android.build.gradle.BaseExtension\n-import com.android.build.gradle.internal.dsl.CmakeOptions\n-import com.android.build.gradle.internal.dsl.DefaultConfig\n-import com.android.builder.model.BuildType\n import com.flutter.gradle.FlutterPluginUtils.BUILT_IN_KOTLIN_DOCS\n import com.flutter.gradle.FlutterPluginUtils.BUILT_IN_KOTLIN_DOCS_FOR_APPS\n import com.flutter.gradle.FlutterPluginUtils.BUILT_IN_KOTLIN_DOCS_FOR_PLUGINS\n@@ -500,8 +500,8 @@\n \n     // buildModeFor\n     @Test\n+    fun `buildModeFor returns profile if the ApplicationBuildType has name profile`() {\n+        val buildType = mockk<ApplicationBuildType>()\n-    fun `buildModeFor returns profile if the BuildType has name profile`() {\n-        val buildType = mockk<BuildType>()\n         every { buildType.name } returns \"profile\"\n \n         val result = FlutterPluginUtils.buildModeFor(buildType)\n@@ -509,8 +509,8 @@\n     }\n \n     @Test\n+    fun `buildModeFor returns debug if the ApplicationBuildType is debuggable`() {\n+        val buildType = mockk<ApplicationBuildType>()\n-    fun `buildModeFor returns debug if the BuildType is debuggable`() {\n-        val buildType = mockk<BuildType>()\n         every { buildType.name } returns \"something random\"\n         every { buildType.isDebuggable } returns true\n \n@@ -519,8 +519,8 @@\n     }\n \n     @Test\n+    fun `buildModeFor returns release if the ApplicationBuildType is not debuggable and not named profile`() {\n+        val buildType = mockk<ApplicationBuildType>()\n-    fun `buildModeFor returns release if the BuildType is not debuggable and not named profile`() {\n-        val buildType = mockk<BuildType>()\n         every { buildType.isDebuggable } returns false\n         every { buildType.name } returns \"something random\"\n \n@@ -616,7 +616,8 @@\n     @Test\n     fun `getCompileSdkFromProject returns the compileSdk from the project`() {\n         val project = mockk<Project>()\n+        every { project.extensions.getByType(CommonExtension::class.java).compileSdk } returns 35\n+        every { project.extensions.getByType(CommonExtension::class.java).compileSdkPreview } returns null\n-        every { project.extensions.findByType(BaseExtension::class.java)!!.compileSdkVersion } returns \"android-35\"\n         val result = FlutterPluginUtils.getCompileSdkFromProject(project)\n         assertEquals(\"35\", result)\n     }\n@@ -1874,24 +1875,24 @@\n         val fakeCmakeFile = tempDir.resolve(\"CMakeLists.txt\").toFile()\n         fakeCmakeFile.createNewFile()\n         val project = mockk<Project>()\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n         every { project.extensions.findByType(ApplicationExtension::class.java) } returns null\n         every {\n             project.extensions\n+                .getByType(CommonExtension::class.java)\n-                .findByType(BaseExtension::class.java)!!\n                 .externalNativeBuild.cmake\n+        } returns mockCmake\n+        every { project.extensions.getByType(CommonExtension::class.java).defaultConfig } returns mockDefaultConfig\n-        } returns mockCmakeOptions\n-        every { project.extensions.findByType(BaseExtension::class.java)!!.defaultConfig } returns mockDefaultConfig\n \n+        every { mockCmake.path } returns fakeCmakeFile\n-        every { mockCmakeOptions.path } returns fakeCmakeFile\n \n         FlutterPluginUtils.forceNdkDownload(project, \"ignored\")\n \n         verify(exactly = 1) {\n+            mockCmake.path\n-            mockCmakeOptions.path\n         }\n+        verify(exactly = 0) { mockCmake.path(any()) }\n-        verify(exactly = 0) { mockCmakeOptions.setPath(any()) }\n         verify { mockDefaultConfig wasNot called }\n     }\n \n@@ -1905,14 +1906,14 @@\n         val mockExecSpec = mockk<ExecSpec>()\n         val mockExecResult = mockk<ExecResult>()\n         val mockExecOperations = mockk<ExecOperations>()\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n+        val mockCommonExtension = mockk<CommonExtension>()\n+        every { project.extensions.getByType(CommonExtension::class.java) } returns mockCommonExtension\n+        every { mockCommonExtension.externalNativeBuild.cmake } returns mockCmake\n+        every { mockCommonExtension.defaultConfig } returns mockDefaultConfig\n+        every { mockCommonExtension.ndkVersion } returns \"29.0.13846066\"\n+        every { mockCmake.path } returns null\n-        val mockBaseExtension = mockk<BaseExtension>()\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n-        every { mockBaseExtension.externalNativeBuild.cmake } returns mockCmakeOptions\n-        every { mockBaseExtension.defaultConfig } returns mockDefaultConfig\n-        every { mockBaseExtension.ndkVersion } returns \"29.0.13846066\"\n-        every { mockCmakeOptions.path } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_SDK_MANAGER_PATH) } returns \"/sdkmanager\"\n         every { project.findProperty(FlutterPluginUtils.PROP_ANDROID_SDK_ROOT) } returns tempDir.toString()\n         every { project.findProperty(FlutterPluginUtils.PROP_INSTALLED_NDK_VERSIONS) } returns \"\"\n@@ -1945,7 +1946,7 @@\n                 )\n             )\n         }\n+        verify(exactly = 0) { mockCmake.path(any()) }\n-        verify(exactly = 0) { mockCmakeOptions.path(any()) }\n         verify { mockDefaultConfig wasNot called }\n     }\n \n@@ -1953,14 +1954,14 @@\n     fun `forceNdkDownload skips sdkmanager install when the requested ndk is already installed`() {\n         val project = mockk<Project>()\n         val finalizeDslSlot = captureFinalizeDslAction(project)\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n+        val mockCommonExtension = mockk<CommonExtension>()\n+        every { project.extensions.getByType(CommonExtension::class.java) } returns mockCommonExtension\n+        every { mockCommonExtension.externalNativeBuild.cmake } returns mockCmake\n+        every { mockCommonExtension.defaultConfig } returns mockDefaultConfig\n+        every { mockCommonExtension.ndkVersion } returns \"29.0.13846066\"\n+        every { mockCmake.path } returns null\n-        val mockBaseExtension = mockk<BaseExtension>()\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n-        every { mockBaseExtension.externalNativeBuild.cmake } returns mockCmakeOptions\n-        every { mockBaseExtension.defaultConfig } returns mockDefaultConfig\n-        every { mockBaseExtension.ndkVersion } returns \"29.0.13846066\"\n-        every { mockCmakeOptions.path } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_SDK_MANAGER_PATH) } returns \"/sdkmanager\"\n         every { project.findProperty(FlutterPluginUtils.PROP_ANDROID_SDK_ROOT) } returns \"/sdk/root\"\n         every { project.findProperty(FlutterPluginUtils.PROP_INSTALLED_NDK_VERSIONS) } returns \"29.0.13846066\"\n@@ -1970,7 +1971,7 @@\n         FlutterPluginUtils.forceNdkDownload(project, \"/base/path\")\n         finalizeDslSlot.captured.invoke(Any())\n \n+        verify(exactly = 0) { mockCmake.path(any()) }\n-        verify(exactly = 0) { mockCmakeOptions.path(any()) }\n         verify { mockDefaultConfig wasNot called }\n     }\n \n@@ -1980,20 +1981,20 @@\n     ) {\n         val project = mockk<Project>()\n         val finalizeDslSlot = captureFinalizeDslAction(project)\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n         val mockDirectoryProperty = mockk<DirectoryProperty>()\n         val mockDirectory = mockk<Directory>()\n+        val mockCommonExtension = mockk<CommonExtension>()\n-        val mockBaseExtension = mockk<BaseExtension>()\n         var cmakePath: File? = null\n         every { project.extensions.findByType(ApplicationExtension::class.java) } returns null\n+        every { project.extensions.getByType(CommonExtension::class.java) } returns mockCommonExtension\n+        every { mockCommonExtension.externalNativeBuild.cmake } returns mockCmake\n+        every { mockCommonExtension.defaultConfig } returns mockDefaultConfig\n+        every { mockCommonExtension.ndkVersion } returns \"29.0.13846066\"\n+        every { mockCmake.path } answers { cmakePath }\n+        every { mockCmake.path(any()) } returns Unit\n+        every { mockCmake.buildStagingDirectory(any()) } returns Unit\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n-        every { mockBaseExtension.externalNativeBuild.cmake } returns mockCmakeOptions\n-        every { mockBaseExtension.defaultConfig } returns mockDefaultConfig\n-        every { mockBaseExtension.ndkVersion } returns \"29.0.13846066\"\n-        every { mockCmakeOptions.path } answers { cmakePath }\n-        every { mockCmakeOptions.path(any()) } returns Unit\n-        every { mockCmakeOptions.buildStagingDirectory(any()) } returns Unit\n         every { project.findProperty(FlutterPluginUtils.PROP_SDK_MANAGER_PATH) } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_ANDROID_SDK_ROOT) } returns \"/sdk/root\"\n         every { project.findProperty(FlutterPluginUtils.PROP_INSTALLED_NDK_VERSIONS) } returns \"\"\n@@ -2003,8 +2004,8 @@\n         every { mockDirectoryProperty.get() } returns mockDirectory\n         every { mockDirectory.asFile.path } returns \"/randomapp/build/app/\"\n \n+        val mockBuildType = mockk<com.android.build.api.dsl.ApplicationBuildType>()\n+        every { mockCommonExtension.buildTypes.iterator() } returns mutableListOf(mockBuildType).iterator()\n-        val mockBuildType = mockk<com.android.build.gradle.internal.dsl.BuildType>()\n-        every { mockBaseExtension.buildTypes.iterator() } returns mutableListOf(mockBuildType).iterator()\n         every { mockBuildType.name } returns \"Debug\"\n         every { mockBuildType.externalNativeBuild.cmake.arguments(any(), any(), any()) } returns Unit\n \n@@ -2013,11 +2014,11 @@\n         finalizeDslSlot.captured.invoke(Any())\n \n         verify(exactly = 0) {\n+            mockCmake.path(\n-            mockCmakeOptions.path(\n                 \"/base/path/packages/flutter_tools/gradle/src/main/scripts/CMakeLists.txt\"\n             )\n         }\n+        verify(exactly = 0) { mockCmake.buildStagingDirectory(any()) }\n-        verify(exactly = 0) { mockCmakeOptions.buildStagingDirectory(any()) }\n         verify { mockDefaultConfig wasNot called }\n     }\n \n@@ -2031,15 +2032,15 @@\n         val mockExecSpec = mockk<ExecSpec>()\n         val mockExecResult = mockk<ExecResult>()\n         val mockExecOperations = mockk<ExecOperations>()\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n+        val mockCommonExtension = mockk<CommonExtension>()\n-        val mockBaseExtension = mockk<BaseExtension>()\n         var configuredNdkVersion = \"26.3.11579264\"\n+        every { project.extensions.getByType(CommonExtension::class.java) } returns mockCommonExtension\n+        every { mockCommonExtension.externalNativeBuild.cmake } returns mockCmake\n+        every { mockCommonExtension.defaultConfig } returns mockDefaultConfig\n+        every { mockCommonExtension.ndkVersion } answers { configuredNdkVersion }\n+        every { mockCmake.path } returns null\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n-        every { mockBaseExtension.externalNativeBuild.cmake } returns mockCmakeOptions\n-        every { mockBaseExtension.defaultConfig } returns mockDefaultConfig\n-        every { mockBaseExtension.ndkVersion } answers { configuredNdkVersion }\n-        every { mockCmakeOptions.path } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_SDK_MANAGER_PATH) } returns \"/sdkmanager\"\n         every { project.findProperty(FlutterPluginUtils.PROP_ANDROID_SDK_ROOT) } returns tempDir.toString()\n         every {\n@@ -2075,7 +2076,7 @@\n                 )\n             )\n         }\n+        verify(exactly = 0) { mockCmake.path(any()) }\n-        verify(exactly = 0) { mockCmakeOptions.path(any()) }\n         verify { mockDefaultConfig wasNot called }\n     }\n \n@@ -2089,24 +2090,20 @@\n         val mockExecSpec = mockk<ExecSpec>()\n         val mockExecResult = mockk<ExecResult>()\n         val mockExecOperations = mockk<ExecOperations>()\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n+        val mockCommonExtension = mockk<CommonExtension>()\n-        val mockBaseExtension = mockk<BaseExtension>()\n         val mockApplicationExtension = mockk<ApplicationExtension>()\n         var configuredNdkVersion = \"26.3.11579264\"\n+        every { project.extensions.getByType(CommonExtension::class.java) } returns mockCommonExtension\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n         every {\n             project.extensions.findByType(ApplicationExtension::class.java)\n         } returns mockApplicationExtension\n+        every { mockCommonExtension.externalNativeBuild.cmake } returns mockCmake\n+        every { mockCommonExtension.defaultConfig } returns mockDefaultConfig\n+        every { mockCommonExtension.ndkVersion } answers { configuredNdkVersion }\n-        every { mockBaseExtension.externalNativeBuild.cmake } returns mockCmakeOptions\n-        every { mockBaseExtension.defaultConfig } returns mockDefaultConfig\n-        every { mockBaseExtension.ndkVersion } answers {\n-            throw AssertionError(\n-                \"legacy ndkVersion should not be read when ApplicationExtension is available\"\n-            )\n-        }\n         every { mockApplicationExtension.ndkVersion } answers { configuredNdkVersion }\n+        every { mockCmake.path } returns null\n-        every { mockCmakeOptions.path } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_SDK_MANAGER_PATH) } returns \"/sdkmanager\"\n         every { project.findProperty(FlutterPluginUtils.PROP_ANDROID_SDK_ROOT) } returns tempDir.toString()\n         every {\n@@ -2141,7 +2138,7 @@\n                 )\n             )\n         }\n+        verify(exactly = 0) { mockCmake.path(any()) }\n-        verify(exactly = 0) { mockCmakeOptions.path(any()) }\n         verify { mockDefaultConfig wasNot called }\n     }\n \n@@ -2149,15 +2146,15 @@\n     fun `forceNdkDownload skips fallback when sdkmanager is unavailable but the requested ndk is already installed`() {\n         val project = mockk<Project>()\n         val finalizeDslSlot = captureFinalizeDslAction(project)\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n+        val mockCommonExtension = mockk<CommonExtension>()\n-        val mockBaseExtension = mockk<BaseExtension>()\n         every { project.extensions.findByType(ApplicationExtension::class.java) } returns null\n+        every { project.extensions.getByType(CommonExtension::class.java) } returns mockCommonExtension\n+        every { mockCommonExtension.externalNativeBuild.cmake } returns mockCmake\n+        every { mockCommonExtension.defaultConfig } returns mockDefaultConfig\n+        every { mockCommonExtension.ndkVersion } returns \"29.0.13846066\"\n+        every { mockCmake.path } returns null\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n-        every { mockBaseExtension.externalNativeBuild.cmake } returns mockCmakeOptions\n-        every { mockBaseExtension.defaultConfig } returns mockDefaultConfig\n-        every { mockBaseExtension.ndkVersion } returns \"29.0.13846066\"\n-        every { mockCmakeOptions.path } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_SDK_MANAGER_PATH) } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_ANDROID_SDK_ROOT) } returns \"/sdk/root\"\n         every { project.findProperty(FlutterPluginUtils.PROP_INSTALLED_NDK_VERSIONS) } returns \"29.0.13846066\"\n@@ -2166,27 +2163,25 @@\n         FlutterPluginUtils.forceNdkDownload(project, \"/base/path\")\n         finalizeDslSlot.captured.invoke(Any())\n \n+        verify(exactly = 0) { mockCmake.path(any()) }\n-        verify(exactly = 0) { mockCmakeOptions.path(any()) }\n         verify { mockDefaultConfig wasNot called }\n     }\n \n     @Test\n+    fun `forceNdkDownload读取公开扩展中的已安装NDK版本`() {\n-    fun `forceNdkDownload reads ndkVersion from ApplicationExtension when legacy extension does not expose it`() {\n         val project = mockk<Project>()\n         val finalizeDslSlot = captureFinalizeDslAction(project)\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n+        val mockCommonExtension = mockk<CommonExtension>()\n-        val mockBaseExtension = mockk<BaseExtension>()\n         val mockApplicationExtension = mockk<ApplicationExtension>()\n+        every { project.extensions.getByType(CommonExtension::class.java) } returns mockCommonExtension\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n         every { project.extensions.findByType(ApplicationExtension::class.java) } returns mockApplicationExtension\n+        every { mockCommonExtension.externalNativeBuild.cmake } returns mockCmake\n+        every { mockCommonExtension.defaultConfig } returns mockDefaultConfig\n+        every { mockCommonExtension.ndkVersion } returns \"29.0.13846066\"\n-        every { mockBaseExtension.externalNativeBuild.cmake } returns mockCmakeOptions\n-        every { mockBaseExtension.defaultConfig } returns mockDefaultConfig\n-        every { mockBaseExtension.ndkVersion } answers {\n-            throw AssertionError(\"legacy ndkVersion should not be read when ApplicationExtension is available\")\n-        }\n         every { mockApplicationExtension.ndkVersion } returns \"29.0.13846066\"\n+        every { mockCmake.path } returns null\n-        every { mockCmakeOptions.path } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_SDK_MANAGER_PATH) } returns \"/sdkmanager\"\n         every { project.findProperty(FlutterPluginUtils.PROP_ANDROID_SDK_ROOT) } returns \"/sdk/root\"\n         every { project.findProperty(FlutterPluginUtils.PROP_INSTALLED_NDK_VERSIONS) } returns \"29.0.13846066\"\n@@ -2195,7 +2190,7 @@\n         FlutterPluginUtils.forceNdkDownload(project, \"/base/path\")\n         finalizeDslSlot.captured.invoke(Any())\n \n+        verify(exactly = 0) { mockCmake.path(any()) }\n-        verify(exactly = 0) { mockCmakeOptions.path(any()) }\n         verify { mockDefaultConfig wasNot called }\n     }\n \n@@ -2207,14 +2202,14 @@\n         val finalizeDslSlot = captureFinalizeDslAction(project)\n         val mockExecResult = mockk<ExecResult>()\n         val mockExecOperations = mockk<ExecOperations>()\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n+        val mockCommonExtension = mockk<CommonExtension>()\n+        every { project.extensions.getByType(CommonExtension::class.java) } returns mockCommonExtension\n+        every { mockCommonExtension.externalNativeBuild.cmake } returns mockCmake\n+        every { mockCommonExtension.defaultConfig } returns mockDefaultConfig\n+        every { mockCommonExtension.ndkVersion } returns \"29.0.13846066\"\n+        every { mockCmake.path } returns null\n-        val mockBaseExtension = mockk<BaseExtension>()\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n-        every { mockBaseExtension.externalNativeBuild.cmake } returns mockCmakeOptions\n-        every { mockBaseExtension.defaultConfig } returns mockDefaultConfig\n-        every { mockBaseExtension.ndkVersion } returns \"29.0.13846066\"\n-        every { mockCmakeOptions.path } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_SDK_MANAGER_PATH) } returns \"/sdkmanager\"\n         every { project.findProperty(FlutterPluginUtils.PROP_ANDROID_SDK_ROOT) } returns tempDir.toString()\n         every { project.findProperty(FlutterPluginUtils.PROP_INSTALLED_NDK_VERSIONS) } returns \"\"\n@@ -2231,7 +2226,7 @@\n             finalizeDslSlot.captured.invoke(Any())\n         }\n \n+        verify(exactly = 0) { mockCmake.path(any()) }\n-        verify(exactly = 0) { mockCmakeOptions.path(any()) }\n         verify { mockDefaultConfig wasNot called }\n     }\n \n@@ -2238,13 +2233,13 @@\n     @Test\n     fun `forceNdkDownload skips when invoking the ndk metadata task`() {\n         val project = mockk<Project>()\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n+        val mockCommonExtension = mockk<CommonExtension>()\n+        every { project.extensions.getByType(CommonExtension::class.java) } returns mockCommonExtension\n+        every { mockCommonExtension.externalNativeBuild.cmake } returns mockCmake\n+        every { mockCommonExtension.defaultConfig } returns mockDefaultConfig\n+        every { mockCmake.path } returns null\n-        val mockBaseExtension = mockk<BaseExtension>()\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n-        every { mockBaseExtension.externalNativeBuild.cmake } returns mockCmakeOptions\n-        every { mockBaseExtension.defaultConfig } returns mockDefaultConfig\n-        every { mockCmakeOptions.path } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_SDK_MANAGER_PATH) } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_ANDROID_SDK_ROOT) } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_INSTALLED_NDK_VERSIONS) } returns null\n@@ -2253,7 +2248,7 @@\n \n         FlutterPluginUtils.forceNdkDownload(project, \"/base/path\")\n \n+        verify(exactly = 0) { mockCmake.path(any()) }\n-        verify(exactly = 0) { mockCmakeOptions.path(any()) }\n         verify { mockDefaultConfig wasNot called }\n     }\n \n@@ -2261,19 +2256,19 @@\n     fun `forceNdkDownload falls back when tool properties are present but sdkmanager is unavailable`() {\n         val project = mockk<Project>()\n         val finalizeDslSlot = captureFinalizeDslAction(project)\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n         val mockDirectoryProperty = mockk<DirectoryProperty>()\n         val mockDirectory = mockk<Directory>()\n+        val mockCommonExtension = mockk<CommonExtension>()\n-        val mockBaseExtension = mockk<BaseExtension>()\n         every { project.extensions.findByType(ApplicationExtension::class.java) } returns null\n+        every { project.extensions.getByType(CommonExtension::class.java) } returns mockCommonExtension\n+        every { mockCommonExtension.externalNativeBuild.cmake } returns mockCmake\n+        every { mockCommonExtension.defaultConfig } returns mockDefaultConfig\n+        every { mockCommonExtension.ndkVersion } returns \"29.0.13846066\"\n+        every { mockCmake.path } returns null\n+        every { mockCmake.path(any()) } returns Unit\n+        every { mockCmake.buildStagingDirectory(any()) } returns Unit\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n-        every { mockBaseExtension.externalNativeBuild.cmake } returns mockCmakeOptions\n-        every { mockBaseExtension.defaultConfig } returns mockDefaultConfig\n-        every { mockBaseExtension.ndkVersion } returns \"29.0.13846066\"\n-        every { mockCmakeOptions.path } returns null\n-        every { mockCmakeOptions.path(any()) } returns Unit\n-        every { mockCmakeOptions.buildStagingDirectory(any()) } returns Unit\n         every { project.findProperty(FlutterPluginUtils.PROP_SDK_MANAGER_PATH) } returns null\n         every { project.findProperty(FlutterPluginUtils.PROP_ANDROID_SDK_ROOT) } returns \"/sdk/root\"\n         every { project.findProperty(FlutterPluginUtils.PROP_INSTALLED_NDK_VERSIONS) } returns \"\"\n@@ -2284,8 +2279,8 @@\n         every { mockDirectory.asFile.path } returns \"/randomapp/build/app/\"\n         val basePath = \"/base/path\"\n \n+        val mockBuildType = mockk<com.android.build.api.dsl.ApplicationBuildType>()\n+        every { mockCommonExtension.buildTypes.iterator() } returns mutableListOf(mockBuildType).iterator()\n-        val mockBuildType = mockk<com.android.build.gradle.internal.dsl.BuildType>()\n-        every { mockBaseExtension.buildTypes.iterator() } returns mutableListOf(mockBuildType).iterator()\n         every { mockBuildType.name } returns \"Debug\"\n         every { mockBuildType.externalNativeBuild.cmake.arguments(any(), any(), any()) } returns Unit\n \n@@ -2293,9 +2288,9 @@\n         finalizeDslSlot.captured.invoke(Any())\n \n         verify(exactly = 1) {\n+            mockCmake.path(\"$basePath/packages/flutter_tools/gradle/src/main/scripts/CMakeLists.txt\")\n-            mockCmakeOptions.path(\"$basePath/packages/flutter_tools/gradle/src/main/scripts/CMakeLists.txt\")\n         }\n+        verify(exactly = 1) { mockCmake.buildStagingDirectory(any()) }\n-        verify(exactly = 1) { mockCmakeOptions.buildStagingDirectory(any()) }\n         verify(exactly = 1) {\n             mockBuildType.externalNativeBuild.cmake.arguments(\n                 \"-Wno-dev\",\n@@ -2309,19 +2304,19 @@\n     fun `forceNdkDownload falls back when Gradle is offline`() {\n         val project = mockk<Project>()\n         val finalizeDslSlot = captureFinalizeDslAction(project)\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n         val mockDirectoryProperty = mockk<DirectoryProperty>()\n         val mockDirectory = mockk<Directory>()\n+        val mockCommonExtension = mockk<CommonExtension>()\n-        val mockBaseExtension = mockk<BaseExtension>()\n         every { project.extensions.findByType(ApplicationExtension::class.java) } returns null\n+        every { project.extensions.getByType(CommonExtension::class.java) } returns mockCommonExtension\n+        every { mockCommonExtension.externalNativeBuild.cmake } returns mockCmake\n+        every { mockCommonExtension.defaultConfig } returns mockDefaultConfig\n+        every { mockCommonExtension.ndkVersion } returns \"29.0.13846066\"\n+        every { mockCmake.path } returns null\n+        every { mockCmake.path(any()) } returns Unit\n+        every { mockCmake.buildStagingDirectory(any()) } returns Unit\n-        every { project.extensions.findByType(BaseExtension::class.java) } returns mockBaseExtension\n-        every { mockBaseExtension.externalNativeBuild.cmake } returns mockCmakeOptions\n-        every { mockBaseExtension.defaultConfig } returns mockDefaultConfig\n-        every { mockBaseExtension.ndkVersion } returns \"29.0.13846066\"\n-        every { mockCmakeOptions.path } returns null\n-        every { mockCmakeOptions.path(any()) } returns Unit\n-        every { mockCmakeOptions.buildStagingDirectory(any()) } returns Unit\n         every { project.findProperty(FlutterPluginUtils.PROP_SDK_MANAGER_PATH) } returns \"/sdkmanager\"\n         every { project.findProperty(FlutterPluginUtils.PROP_ANDROID_SDK_ROOT) } returns \"/sdk/root\"\n         every { project.findProperty(FlutterPluginUtils.PROP_INSTALLED_NDK_VERSIONS) } returns \"\"\n@@ -2333,8 +2328,8 @@\n         every { mockDirectory.asFile.path } returns \"/randomapp/build/app/\"\n         val basePath = \"/base/path\"\n \n+        val mockBuildType = mockk<com.android.build.api.dsl.ApplicationBuildType>()\n+        every { mockCommonExtension.buildTypes.iterator() } returns mutableListOf(mockBuildType).iterator()\n-        val mockBuildType = mockk<com.android.build.gradle.internal.dsl.BuildType>()\n-        every { mockBaseExtension.buildTypes.iterator() } returns mutableListOf(mockBuildType).iterator()\n         every { mockBuildType.name } returns \"Debug\"\n         every { mockBuildType.externalNativeBuild.cmake.arguments(any(), any(), any()) } returns Unit\n \n@@ -2342,9 +2337,9 @@\n         finalizeDslSlot.captured.invoke(Any())\n \n         verify(exactly = 1) {\n+            mockCmake.path(\"$basePath/packages/flutter_tools/gradle/src/main/scripts/CMakeLists.txt\")\n-            mockCmakeOptions.path(\"$basePath/packages/flutter_tools/gradle/src/main/scripts/CMakeLists.txt\")\n         }\n+        verify(exactly = 1) { mockCmake.buildStagingDirectory(any()) }\n-        verify(exactly = 1) { mockCmakeOptions.buildStagingDirectory(any()) }\n         verify(exactly = 1) {\n             mockBuildType.externalNativeBuild.cmake.arguments(\n                 \"-Wno-dev\",\n@@ -2357,7 +2352,7 @@\n     @Test\n     fun `forceNdkDownload sets externalNativeBuild properties`() {\n         val project = mockk<Project>()\n+        val mockCmake = mockk<Cmake>()\n-        val mockCmakeOptions = mockk<CmakeOptions>()\n         val mockDefaultConfig = mockk<DefaultConfig>()\n         val mockDirectoryProperty = mockk<DirectoryProperty>()\n         val mockDirectory = mockk<Directory>()\n@@ -2367,25 +2362,25 @@\n         every { project.findProperty(FlutterPluginUtils.PROP_INSTALLED_NDK_VERSIONS) } returns null\n         every {\n             project.extensions\n+                .getByType(CommonExtension::class.java)\n-                .findByType(BaseExtension::class.java)!!\n                 .externalNativeBuild.cmake\n+        } returns mockCmake\n+        every { project.extensions.getByType(CommonExtension::class.java).defaultConfig } returns mockDefaultConfig\n-        } returns mockCmakeOptions\n-        every { project.extensions.findByType(BaseExtension::class.java)!!.defaultConfig } returns mockDefaultConfig\n \n         val basePath = \"/base/path\"\n         val fakeBuildPath = \"/randomapp/build/app/\"\n+        every { mockCmake.path } returns null\n+        every { mockCmake.path(any()) } returns Unit\n+        every { mockCmake.buildStagingDirectory(any()) } returns Unit\n-        every { mockCmakeOptions.path } returns null\n-        every { mockCmakeOptions.path(any()) } returns Unit\n-        every { mockCmakeOptions.buildStagingDirectory(any()) } returns Unit\n         every { project.layout.buildDirectory } returns mockDirectoryProperty\n         every { mockDirectoryProperty.dir(any<String>()) } returns mockDirectoryProperty\n         every { mockDirectoryProperty.get() } returns mockDirectory\n         every { mockDirectory.asFile.path } returns fakeBuildPath\n \n+        val mockBuildType = mockk<com.android.build.api.dsl.ApplicationBuildType>()\n-        val mockBuildType = mockk<com.android.build.gradle.internal.dsl.BuildType>()\n         every {\n             project.extensions\n+                .getByType(CommonExtension::class.java)\n-                .findByType(BaseExtension::class.java)!!\n                 .buildTypes\n                 .iterator()\n         } returns mutableListOf(mockBuildType).iterator()\n@@ -2395,10 +2390,10 @@\n         FlutterPluginUtils.forceNdkDownload(project, basePath)\n \n         verify(exactly = 1) {\n+            mockCmake.path\n-            mockCmakeOptions.path\n         }\n+        verify(exactly = 1) { mockCmake.path(\"$basePath/packages/flutter_tools/gradle/src/main/scripts/CMakeLists.txt\") }\n+        verify(exactly = 1) { mockCmake.buildStagingDirectory(any()) }\n-        verify(exactly = 1) { mockCmakeOptions.path(\"$basePath/packages/flutter_tools/gradle/src/main/scripts/CMakeLists.txt\") }\n-        verify(exactly = 1) { mockCmakeOptions.buildStagingDirectory(any()) }\n         verify(exactly = 1) {\n             mockBuildType.externalNativeBuild.cmake.arguments(\n                 \"-Wno-dev\",\n@@ -2440,7 +2435,7 @@\n         val pluginHandler = PluginHandler(project)\n         mockkObject(NativePluginLoaderReflectionBridge)\n         every { NativePluginLoaderReflectionBridge.getPlugins(any(), any()) } returns pluginListWithoutDevDependency\n+        val buildType: ApplicationBuildType = mockk<ApplicationBuildType>()\n-        val buildType: BuildType = mockk<BuildType>()\n         every { buildType.name } returns \"debug\"\n         every { buildType.isDebuggable } returns true\n         every { project.hasProperty(\"local-engine-repo\") } returns true\n@@ -2472,7 +2467,7 @@\n         val pluginHandler = PluginHandler(project)\n         mockkObject(NativePluginLoaderReflectionBridge)\n         every { NativePluginLoaderReflectionBridge.getPlugins(any(), any()) } returns pluginListWithoutDevDependency\n+        val buildType: ApplicationBuildType = mockk<ApplicationBuildType>()\n-        val buildType: BuildType = mockk<BuildType>()\n         val engineVersion = EXAMPLE_ENGINE_VERSION\n         every { buildType.name } returns \"debug\"\n         every { buildType.isDebuggable } returns true\n@@ -2510,7 +2505,7 @@\n         val pluginHandler = PluginHandler(project)\n         mockkObject(NativePluginLoaderReflectionBridge)\n         every { NativePluginLoaderReflectionBridge.getPlugins(any(), any()) } returns pluginListWithSingleDevDependency\n+        val buildType: ApplicationBuildType = mockk<ApplicationBuildType>()\n-        val buildType: BuildType = mockk<BuildType>()\n         val engineVersion = EXAMPLE_ENGINE_VERSION\n         every { buildType.name } returns \"release\"\n         every { buildType.isDebuggable } returns false\n@@ -2564,7 +2559,7 @@\n         val pluginHandler = PluginHandler(project)\n         mockkObject(NativePluginLoaderReflectionBridge)\n         every { NativePluginLoaderReflectionBridge.getPlugins(any(), any()) } returns pluginListWithSingleDevDependency\n+        val buildType: ApplicationBuildType = mockk<ApplicationBuildType>()\n-        val buildType: BuildType = mockk<BuildType>()\n         val engineVersion = EXAMPLE_ENGINE_VERSION\n         every { buildType.name } returns \"debug\"\n         every { buildType.isDebuggable } returns true\ndiff --git a/packages/flutter_tools/gradle/src/test/kotlin/plugins/PluginHandlerTest.kt b/packages/flutter_tools/gradle/src/test/kotlin/plugins/PluginHandlerTest.kt\nindex 5a4b7b28f038d39e7c2322923e2abe191d5fc68822c59d73b27c86ffb708f7c5..d90e2dd7a0e21ef03c6a05722b4afa38f8c88da5b8f3a6afe0fb14f86d722311\n--- a/packages/flutter_tools/gradle/src/test/kotlin/plugins/PluginHandlerTest.kt\n+++ b/packages/flutter_tools/gradle/src/test/kotlin/plugins/PluginHandlerTest.kt\n@@ -4,7 +4,7 @@\n \n package com.flutter.gradle.plugins\n \n-import com.android.build.gradle.BaseExtension\n+import com.android.build.api.dsl.CommonExtension\n import com.flutter.gradle.FlutterExtension\n import com.flutter.gradle.FlutterPluginUtils\n import com.flutter.gradle.FlutterPluginUtilsTest.Companion.EXAMPLE_ENGINE_VERSION\n@@ -169,10 +169,13 @@\n         settingsGradle.createNewFile()\n         val mockLogger = mockk<Logger>()\n         every { project.logger } returns mockLogger\n+        val mockAppPluginContainer = mockk<org.gradle.api.plugins.PluginContainer>()\n+        every { project.plugins } returns mockAppPluginContainer\n+        every { mockAppPluginContainer.hasPlugin(\"com.android.application\") } returns true\n \n         val pluginProject = mockk<Project>()\n         val pluginDependencyProject = mockk<Project>()\n-        val mockBuildType = mockk<com.android.build.gradle.internal.dsl.BuildType>()\n+        val mockBuildType = mockk<com.android.build.api.dsl.ApplicationBuildType>()\n         every { pluginProject.hasProperty(\"local-engine-repo\") } returns false\n         every { pluginProject.hasProperty(\"android\") } returns true\n         val mockPluginContainer = mockk<org.gradle.api.plugins.PluginContainer>()\n@@ -189,18 +192,18 @@\n         every { pluginProject.afterEvaluate(any<Action<Project>>()) } returns Unit\n \n         val mockProjectBuildTypes =\n-            mockk<NamedDomainObjectContainer<com.android.build.gradle.internal.dsl.BuildType>>()\n+            mockk<NamedDomainObjectContainer<com.android.build.api.dsl.ApplicationBuildType>>()\n         val mockPluginProjectBuildTypes =\n-            mockk<NamedDomainObjectContainer<com.android.build.gradle.internal.dsl.BuildType>>()\n-        every { project.extensions.findByType(BaseExtension::class.java)!!.buildTypes } returns mockProjectBuildTypes\n-        every { pluginProject.extensions.findByType(BaseExtension::class.java)!!.buildTypes } returns mockPluginProjectBuildTypes\n+            mockk<NamedDomainObjectContainer<com.android.build.api.dsl.ApplicationBuildType>>()\n+        every { project.extensions.getByType(CommonExtension::class.java).buildTypes } returns mockProjectBuildTypes\n+        every { pluginProject.extensions.getByType(CommonExtension::class.java).buildTypes } returns mockPluginProjectBuildTypes\n         every { mockPluginProjectBuildTypes.addAll(any()) } returns true\n         every { pluginProject.configurations.named(any<String>()) } returns mockk()\n         every { pluginProject.dependencies.add(any(), any()) } returns mockk()\n \n         every {\n             project.extensions\n-                .findByType(BaseExtension::class.java)!!\n+                .getByType(CommonExtension::class.java)\n                 .buildTypes\n                 .iterator()\n         } returns\n@@ -214,8 +217,10 @@\n                 mockBuildType\n             ).iterator()\n         every { project.dependencies.add(any(), any()) } returns mockk()\n-        every { project.extensions.findByType(BaseExtension::class.java)!!.compileSdkVersion } returns \"android-35\"\n-        every { pluginProject.extensions.findByType(BaseExtension::class.java)!!.compileSdkVersion } returns \"android-35\"\n+        every { project.extensions.getByType(CommonExtension::class.java).compileSdk } returns 35\n+        every { project.extensions.getByType(CommonExtension::class.java).compileSdkPreview } returns null\n+        every { pluginProject.extensions.getByType(CommonExtension::class.java).compileSdk } returns 35\n+        every { pluginProject.extensions.getByType(CommonExtension::class.java).compileSdkPreview } returns null\n \n         val pluginHandler = PluginHandler(project)\n         mockkObject(NativePluginLoaderReflectionBridge)\n@@ -248,7 +253,7 @@\n                 \"io.flutter:flutter_embedding_debug:$EXAMPLE_ENGINE_VERSION\"\n             )\n         }\n-        verify { project.dependencies.add(\"debugApi\", pluginProject) }\n+        verify { project.dependencies.add(\"debugImplementation\", pluginProject) }\n         verify { mockLogger wasNot called }\n         // For library projects, individual build types should be created, not addAll\n         verify(exactly = 0) { mockPluginProjectBuildTypes.addAll(any()) }\n@@ -272,7 +277,7 @@\n         every { project.logger } returns mockLogger\n \n         val pluginProject = mockk<Project>()\n-        val mockBuildType = mockk<com.android.build.gradle.internal.dsl.BuildType>()\n+        val mockBuildType = mockk<com.android.build.api.dsl.ApplicationBuildType>()\n         every { pluginProject.hasProperty(\"local-engine-repo\") } returns false\n         every { pluginProject.hasProperty(\"android\") } returns true\n         every { mockBuildType.name } returns \"debug\"\n@@ -285,18 +290,18 @@\n         every { pluginProject.afterEvaluate(any<Action<Project>>()) } returns Unit\n \n         val mockProjectBuildTypes =\n-            mockk<NamedDomainObjectContainer<com.android.build.gradle.internal.dsl.BuildType>>()\n+            mockk<NamedDomainObjectContainer<com.android.build.api.dsl.ApplicationBuildType>>()\n         val mockPluginProjectBuildTypes =\n-            mockk<NamedDomainObjectContainer<com.android.build.gradle.internal.dsl.BuildType>>()\n-        every { project.extensions.findByType(BaseExtension::class.java)!!.buildTypes } returns mockProjectBuildTypes\n-        every { pluginProject.extensions.findByType(BaseExtension::class.java)!!.buildTypes } returns mockPluginProjectBuildTypes\n+            mockk<NamedDomainObjectContainer<com.android.build.api.dsl.ApplicationBuildType>>()\n+        every { project.extensions.getByType(CommonExtension::class.java).buildTypes } returns mockProjectBuildTypes\n+        every { pluginProject.extensions.getByType(CommonExtension::class.java).buildTypes } returns mockPluginProjectBuildTypes\n         every { mockPluginProjectBuildTypes.addAll(any()) } returns true\n         every { pluginProject.configurations.named(any<String>()) } returns mockk()\n         every { pluginProject.dependencies.add(any(), any()) } returns mockk()\n \n         every {\n             project.extensions\n-                .findByType(BaseExtension::class.java)!!\n+                .getByType(CommonExtension::class.java)\n                 .buildTypes\n                 .iterator()\n         } returns\n@@ -310,8 +315,10 @@\n                 mockBuildType\n             ).iterator()\n         every { project.dependencies.add(any(), any()) } returns mockk()\n-        every { project.extensions.findByType(BaseExtension::class.java)!!.compileSdkVersion } returns \"android-35\"\n-        every { pluginProject.extensions.findByType(BaseExtension::class.java)!!.compileSdkVersion } returns \"android-35\"\n+        every { project.extensions.getByType(CommonExtension::class.java).compileSdk } returns 35\n+        every { project.extensions.getByType(CommonExtension::class.java).compileSdkPreview } returns null\n+        every { pluginProject.extensions.getByType(CommonExtension::class.java).compileSdk } returns 35\n+        every { pluginProject.extensions.getByType(CommonExtension::class.java).compileSdkPreview } returns null\n \n         val pluginHandler = PluginHandler(project)\n         mockkObject(NativePluginLoaderReflectionBridge)\n@@ -347,19 +354,19 @@\n         mockkObject(FlutterPluginUtils)\n         every { FlutterPluginUtils.isBuiltAsApp(pluginProject) } returns true\n \n-        val mockProjectBuildTypes = mockk<NamedDomainObjectContainer<com.android.build.gradle.internal.dsl.BuildType>>()\n-        val mockPluginProjectBuildTypes = mockk<NamedDomainObjectContainer<com.android.build.gradle.internal.dsl.BuildType>>()\n-\n-        every { project.extensions.findByType(BaseExtension::class.java)!!.buildTypes } returns mockProjectBuildTypes\n-        every { pluginProject.extensions.findByType(BaseExtension::class.java)!!.buildTypes } returns mockPluginProjectBuildTypes\n+        val mockProjectBuildTypes = mockk<NamedDomainObjectContainer<com.android.build.api.dsl.ApplicationBuildType>>()\n+        val mockPluginProjectBuildTypes = mockk<NamedDomainObjectContainer<com.android.build.api.dsl.ApplicationBuildType>>()\n+\n+        every { project.extensions.getByType(CommonExtension::class.java).buildTypes } returns mockProjectBuildTypes\n+        every { pluginProject.extensions.getByType(CommonExtension::class.java).buildTypes } returns mockPluginProjectBuildTypes\n         every { mockPluginProjectBuildTypes.addAll(any()) } returns true\n-        every { mockProjectBuildTypes.iterator() } returns mutableListOf<com.android.build.gradle.internal.dsl.BuildType>().iterator()\n+        every { mockProjectBuildTypes.iterator() } returns mutableListOf<com.android.build.api.dsl.ApplicationBuildType>().iterator()\n \n         // Mock FlutterPluginUtils calls that our logic depends on\n         mockkObject(FlutterPluginUtils)\n-        every { FlutterPluginUtils.getLegacyAndroidExtension(project) } returns project.extensions.findByType(BaseExtension::class.java)!!\n-        every { FlutterPluginUtils.getLegacyAndroidExtension(pluginProject) } returns\n-            pluginProject.extensions.findByType(BaseExtension::class.java)!!\n+        every { FlutterPluginUtils.getAndroidExtension(project) } returns project.extensions.getByType(CommonExtension::class.java)\n+        every { FlutterPluginUtils.getAndroidExtension(pluginProject) } returns\n+            pluginProject.extensions.getByType(CommonExtension::class.java)\n \n         // For app plugins, the old addAll behavior should be used\n         // This is tested implicitly by verifying the absence of individual create calls\n@@ -367,7 +374,7 @@\n         verify(exactly = 0) {\n             mockPluginProjectBuildTypes.create(\n                 any<String>(),\n-                any<Action<com.android.build.gradle.internal.dsl.BuildType>>()\n+                any<Action<com.android.build.api.dsl.ApplicationBuildType>>()\n             )\n         }\n     }\n@@ -387,22 +394,22 @@\n         mockkObject(FlutterPluginUtils)\n         every { FlutterPluginUtils.isBuiltAsApp(pluginProject) } returns false\n \n-        val mockProjectBuildTypes = mockk<NamedDomainObjectContainer<com.android.build.gradle.internal.dsl.BuildType>>()\n-        val mockPluginProjectBuildTypes = mockk<NamedDomainObjectContainer<com.android.build.gradle.internal.dsl.BuildType>>()\n-        val mockCreatedBuildType = mockk<com.android.build.gradle.internal.dsl.BuildType>(relaxed = true)\n-\n-        every { project.extensions.findByType(BaseExtension::class.java)!!.buildTypes } returns mockProjectBuildTypes\n-        every { pluginProject.extensions.findByType(BaseExtension::class.java)!!.buildTypes } returns mockPluginProjectBuildTypes\n+        val mockProjectBuildTypes = mockk<NamedDomainObjectContainer<com.android.build.api.dsl.ApplicationBuildType>>()\n+        val mockPluginProjectBuildTypes = mockk<NamedDomainObjectContainer<com.android.build.api.dsl.ApplicationBuildType>>()\n+        val mockCreatedBuildType = mockk<com.android.build.api.dsl.ApplicationBuildType>(relaxed = true)\n+\n+        every { project.extensions.getByType(CommonExtension::class.java).buildTypes } returns mockProjectBuildTypes\n+        every { pluginProject.extensions.getByType(CommonExtension::class.java).buildTypes } returns mockPluginProjectBuildTypes\n         every { mockPluginProjectBuildTypes.findByName(\"debug\") } returns null\n         every {\n             mockPluginProjectBuildTypes.create(\n                 \"debug\",\n-                any<Action<com.android.build.gradle.internal.dsl.BuildType>>()\n+                any<Action<com.android.build.api.dsl.ApplicationBuildType>>()\n             )\n         } returns mockCreatedBuildType\n \n         // Mock the iterator for forEach\n-        val testBuildType = mockk<com.android.build.gradle.internal.dsl.BuildType>()\n+        val testBuildType = mockk<com.android.build.api.dsl.ApplicationBuildType>()\n         every { testBuildType.name } returns \"debug\"\n         every { testBuildType.isDebuggable } returns true\n         every { testBuildType.isMinifyEnabled } returns false\n@@ -410,9 +417,9 @@\n \n         // Mock FlutterPluginUtils calls that our logic depends on\n         mockkObject(FlutterPluginUtils)\n-        every { FlutterPluginUtils.getLegacyAndroidExtension(project) } returns project.extensions.findByType(BaseExtension::class.java)!!\n-        every { FlutterPluginUtils.getLegacyAndroidExtension(pluginProject) } returns\n-            pluginProject.extensions.findByType(BaseExtension::class.java)!!\n+        every { FlutterPluginUtils.getAndroidExtension(project) } returns project.extensions.getByType(CommonExtension::class.java)\n+        every { FlutterPluginUtils.getAndroidExtension(pluginProject) } returns\n+            pluginProject.extensions.getByType(CommonExtension::class.java)\n \n         // For library plugins, individual build type creation should happen\n         // This is tested by verifying that create is called for the build type\n@@ -423,7 +430,7 @@\n     private fun setupBasicMocks(\n         project: Project,\n         pluginProject: Project,\n-        mockBuildType: com.android.build.gradle.internal.dsl.BuildType,\n+        mockBuildType: com.android.build.api.dsl.ApplicationBuildType,\n         tempDir: Path\n     ) {\n         // Configuration for project directory\n@@ -452,8 +459,10 @@\n         every { pluginProject.configurations.named(any<String>()) } returns mockk()\n         every { pluginProject.dependencies.add(any(), any()) } returns mockk()\n         every { project.dependencies.add(any(), any()) } returns mockk()\n-        every { project.extensions.findByType(BaseExtension::class.java)!!.compileSdkVersion } returns \"android-35\"\n-        every { pluginProject.extensions.findByType(BaseExtension::class.java)!!.compileSdkVersion } returns \"android-35\"\n+        every { project.extensions.getByType(CommonExtension::class.java).compileSdk } returns 35\n+        every { project.extensions.getByType(CommonExtension::class.java).compileSdkPreview } returns null\n+        every { pluginProject.extensions.getByType(CommonExtension::class.java).compileSdk } returns 35\n+        every { pluginProject.extensions.getByType(CommonExtension::class.java).compileSdkPreview } returns null\n     }\n \n     private fun setupPluginMocks(project: Project) {\ndiff --git a/packages/flutter_tools/gradle/src/test/kotlin/DeeplinkTest.kt b/packages/flutter_tools/gradle/src/test/kotlin/DeeplinkTest.kt\nindex 525fc434a271b6540e4665e6a3bb48c7250d751c4c060198ec7fdf7559abe648..ee5e509830ba5827d7db7dd7619d73abc56861c80df62d7bcf2cb827bce4e454\n--- a/packages/flutter_tools/gradle/src/test/kotlin/DeeplinkTest.kt\n+++ b/packages/flutter_tools/gradle/src/test/kotlin/DeeplinkTest.kt\n@@ -4,7 +4,7 @@\n \n package com.flutter.gradle\n \n+import kotlin.test.assertFailsWith\n-import org.gradle.internal.impldep.org.junit.Assert.assertThrows\n import kotlin.test.Test\n import kotlin.test.assertContains\n import kotlin.test.assertFalse\n@@ -41,7 +41,7 @@\n         val deeplink1 = Deeplink(\"scheme1\", \"host1\", \"path1\", IntentFilterCheck())\n         val deeplink2 = null\n \n+        assertFailsWith<NullPointerException> { deeplink1.equals(deeplink2) }\n-        assertThrows(NullPointerException::class.java) { deeplink1.equals(deeplink2) }\n     }\n \n     @Test\ndiff --git a/packages/flutter_tools/gradle/src/test/kotlin/DependencyVersionCheckerTest.kt b/packages/flutter_tools/gradle/src/test/kotlin/DependencyVersionCheckerTest.kt\nindex 66ec59b37378f70f347075b2c05393d4ce09c8f577e252200590db8bfe3fd933..8085404b25222899179e52fa5f59ff66ed97175ac7f534e5c0d0cc00b2deac63\n--- a/packages/flutter_tools/gradle/src/test/kotlin/DependencyVersionCheckerTest.kt\n+++ b/packages/flutter_tools/gradle/src/test/kotlin/DependencyVersionCheckerTest.kt\n@@ -30,7 +30,7 @@\n import com.flutter.gradle.DependencyVersionChecker.warnGradleVersion\n import com.flutter.gradle.DependencyVersionChecker.warnKGPVersion\n import com.flutter.gradle.DependencyVersionChecker.warnMinSdkVersion\n+import com.flutter.gradle.testing.setKotlinVersion\n-import com.flutter.gradle.testing.setAgpKotlinVersionToNull\n import io.mockk.every\n import io.mockk.mockk\n import io.mockk.mockkStatic\n@@ -55,7 +55,7 @@\n private const val SUPPORTED_GRADLE_VERSION: String = \"9.1.0\"\n private val SUPPORTED_JAVA_VERSION: JavaVersion = JavaVersion.VERSION_17\n private val SUPPORTED_AGP_VERSION: AndroidPluginVersion = AndroidPluginVersion(9, 0, 1)\n+private const val SUPPORTED_KGP_VERSION: String = \"2.2.20\"\n-private const val SUPPORTED_KGP_VERSION: String = \"2.3.20\"\n private val SUPPORTED_SDK_VERSION: MinSdkVersion = MinSdkVersion(\"release\", 30)\n \n class DependencyVersionCheckerTest {\n@@ -439,8 +439,7 @@\n         every { mockAndroidComponentsExtension.pluginVersion } returns agpVersion\n \n         // KGP\n+        setKotlinVersion(mockProject, kgpVersion)\n-        every { mockProject.hasProperty(eq(\"kotlin_version\")) } returns true\n-        every { mockProject.properties[\"kotlin_version\"] } returns kgpVersion\n \n         // Logger\n         val mockLogger = mockk<Logger>()\n@@ -499,7 +498,6 @@\n             }\n             return@answers Unit\n         }\n-        setAgpKotlinVersionToNull(mockProject)\n \n         return mockProject\n     }\ndiff --git a/packages/flutter_tools/gradle/src/test/kotlin/testing/VersionFetcherTestHelper.kt b/packages/flutter_tools/gradle/src/test/kotlin/testing/VersionFetcherTestHelper.kt\nindex 44682af9e0455c4060855f502f4b35247b5adb29465669486cbf688daf519fc7..17ee0eb03af0751f7b4a02af0fca0b7fcd82b432a964502f169e7fed4b55f129\n--- a/packages/flutter_tools/gradle/src/test/kotlin/testing/VersionFetcherTestHelper.kt\n+++ b/packages/flutter_tools/gradle/src/test/kotlin/testing/VersionFetcherTestHelper.kt\n@@ -1,22 +1,12 @@\n package com.flutter.gradle.testing\n \n import io.mockk.every\n+import io.mockk.mockkStatic\n-import io.mockk.mockk\n import org.gradle.api.Project\n+import org.jetbrains.kotlin.gradle.plugin.getKotlinPluginVersion\n-import org.jetbrains.kotlin.gradle.plugin.KotlinBaseApiPlugin\n \n+/** 测试通过KGP公开接口注入版本，不复刻AGP内部实现。 */\n+internal fun setKotlinVersion(mockProject: Project, version: String) {\n+    mockkStatic(\"org.jetbrains.kotlin.gradle.plugin.KotlinPluginWrapperKt\")\n+    every { mockProject.getKotlinPluginVersion() } returns version\n-/**\n- * Prevent AGP's kotlin version checker from throwing `no answer found`\n- *\n- * Intended to be called by tests that call `VersionFetcher.getKGPVersion(project)`\n- * and who do not care about the internal implementation of\n- * `com.android.build.gradle.internal.utils.getKotlinAndroidPluginVersion`\n- */\n-internal fun setAgpKotlinVersionToNull(mockProject: Project) {\n-    // The internals of `getKotlinAndroidPluginVersion` depend on `getKotlinPluginVersionFromPlugin`\n-    // which relies on reflection to get the value. Instead make sure fetching the plugin has valid\n-    // response then rely on the default behavior in `getKotlinPluginVersionFromPlugin` to\n-    // return null.\n-    every { mockProject.plugins.findPlugin(any<Class<KotlinBaseApiPlugin>>()) } returns mockk()\n-    every { mockProject.plugins.findPlugin(\"kotlin-android\") } returns mockk()\n }\ndiff --git a/bin/internal/shared.sh b/bin/internal/shared.sh\nindex 7029bb28e9f60927807f2119d2afe388742db41d34c26f5e263bf15568911fa2..5c6e3bfa4647025cba26e3a6f6cc9fa0d2dcd670062870d6fda85f6764a27fe4\n--- a/bin/internal/shared.sh\n+++ b/bin/internal/shared.sh\n@@ -1,283 +1,35 @@\n-#!/usr/bin/env bash\n-# Copyright 2014 The Flutter Authors. All rights reserved.\n-# Use of this source code is governed by a BSD-style license that can be\n-# found in the LICENSE file.\n-\n-# ---------------------------------- NOTE ---------------------------------- #\n-#\n-# Please keep the logic in this file consistent with the logic in the\n-# `shared.bat` script in the same directory to ensure that Flutter & Dart continue\n-# to work across all platforms!\n-#\n-# -------------------------------------------------------------------------- #\n-\n-set -e\n-\n-# Needed because if it is set, cd may print the path it changed to.\n-unset CDPATH\n-\n-function pub_upgrade_with_retry {\n-  local total_tries=\"10\"\n-  local remaining_tries=$((total_tries - 1))\n-  while [[ \"$remaining_tries\" -gt 0 ]]; do\n-    (cd \"$FLUTTER_TOOLS_DIR\" && \"$DART\" pub upgrade --suppress-analytics >&2) && break\n-    >&2 echo \"Error: Unable to 'pub upgrade' flutter tool. Retrying in five seconds... ($remaining_tries tries left)\"\n-    remaining_tries=$((remaining_tries - 1))\n-    sleep 5\n-  done\n-\n-  if [[ \"$remaining_tries\" == 0 ]]; then\n-    >&2 echo \"Command 'pub upgrade' still failed after $total_tries tries, giving up.\"\n-    return 1\n-  fi\n-\n-  # Touch the pubspec.lock to ensure, even if this was a NOP, it is newer than pubspec.yaml.\n-  # See https://github.com/flutter/flutter/issues/171024.\n-  touch \"$FLUTTER_TOOLS_DIR/pubspec.lock\" >&2\n-\n-  return 0\n-}\n-\n-# Trap function for removing any remaining lock file at exit.\n-function _rmlock () {\n-  [ -n \"$FLUTTER_UPGRADE_LOCK\" ] && rm -rf -- \"$FLUTTER_UPGRADE_LOCK\"\n-}\n-\n-# Determines which lock method to use, based on what is available on the system.\n-# Returns a non-zero value if the lock was not acquired, zero if acquired.\n-function _lock () {\n-  if hash flock 2>/dev/null; then\n-    flock --nonblock --exclusive 7 2>/dev/null\n-  elif hash shlock 2>/dev/null; then\n-    shlock -f \"$1\" -p $$\n-  else\n-    mkdir \"$1\" 2>/dev/null\n-  fi\n-}\n-\n-# Waits for an update lock to be acquired.\n-#\n-# To ensure that we don't simultaneously update Dart in multiple parallel\n-# instances, we try to obtain an exclusive lock on this file descriptor (and\n-# thus this script's source file) while we are updating Dart and compiling the\n-# script. To do this, we try to use the command line program \"flock\", which is\n-# available on many Unix-like platforms, in particular on most Linux\n-# distributions. You give it a file descriptor, and it locks the corresponding\n-# file, having inherited the file descriptor from the shell.\n-#\n-# Complicating matters, there are two major scenarios where this will not\n-# work.\n-#\n-# The first is if the platform doesn't have \"flock\", for example on macOS. There\n-# is not a direct equivalent, so on platforms that don't have flock, we fall\n-# back to using trying to use the shlock command, and if that doesn't exist,\n-# then we use mkdir as an atomic operation to create a lock directory. If mkdir\n-# is able to create the directory, then the lock is acquired. To determine if we\n-# have \"flock\" or \"shlock\" available, we use the \"hash\" shell built-in.\n-#\n-# The second complication is on network file shares. On NFS, to obtain an\n-# exclusive lock you need a file descriptor that is open for writing. Thus, we\n-# ignore errors from flock by redirecting all output to /dev/null, since users\n-# will typically not care about errors from flock and are more likely to be\n-# confused by them than helped. The \"shlock\" method doesn't work for network\n-# shares, since it is PID-based. The \"mkdir\" method does work over NFS\n-# implementations that support atomic directory creation (which is most of\n-# them). The \"schlock\" and \"flock\" commands are more reliable than the mkdir\n-# method, however, or we would use mkdir in all cases.\n-#\n-# The upgrade_flutter function calling _wait_for_lock is executed in a subshell\n-# with a redirect that pipes the source of this script into file descriptor 7.\n-# A flock lock is released when this subshell exits and file descriptor 7 is\n-# closed. The mkdir lock is released via an exit trap from the subshell that\n-# deletes the lock directory.\n-function _wait_for_lock () {\n-  FLUTTER_UPGRADE_LOCK=\"$FLUTTER_ROOT/bin/cache/.upgrade_lock\"\n-  local waiting_message_displayed\n-  while ! _lock \"$FLUTTER_UPGRADE_LOCK\"; do\n-    if [[ -z $waiting_message_displayed ]]; then\n-      # Print with a return so that if the Dart code also prints this message\n-      # when it does its own lock, the message won't appear twice. Be sure that\n-      # the clearing printf below has the same number of space characters.\n-      printf \"Waiting for another flutter command to release the startup lock...\\r\" >&2;\n-      waiting_message_displayed=\"true\"\n-    fi\n-    sleep .1;\n-  done\n-  if [[ $waiting_message_displayed == \"true\" ]]; then\n-    # Clear the waiting message so it doesn't overlap any following text.\n-    printf \"                                                                  \\r\" >&2;\n-  fi\n-  unset waiting_message_displayed\n-  # If the lock file is acquired, make sure that it is removed on exit.\n-  trap _rmlock INT TERM EXIT\n-}\n-\n-# This function is always run in a subshell. Running the function in a subshell\n-# is required to make sure any lock directory is cleaned up by the exit trap in\n-# _wait_for_lock.\n-function upgrade_flutter () (\n-  mkdir -p \"$FLUTTER_ROOT/bin/cache\"\n-\n-  # Ensure the engine.version is populated\n-  \"$FLUTTER_ROOT/bin/internal/update_engine_version.sh\"\n-\n-  local revision=\"$(git -C \"$FLUTTER_ROOT\" rev-parse HEAD)\"\n-  local compilekey=\"$revision:$FLUTTER_TOOL_ARGS\"\n-\n-  # Invalidate cache if:\n-  #  * SNAPSHOT_PATH is not a file, or\n-  #  * STAMP_PATH is not a file, or\n-  #  * STAMP_PATH is an empty file, or\n-  #  * Contents of STAMP_PATH is not what we are going to compile, or\n-  #  * pubspec.yaml last modified after pubspec.lock\n-  if [[ ! -f \"$SNAPSHOT_PATH\" || \\\n-        ! -s \"$STAMP_PATH\" || \\\n-        \"$(< \"$STAMP_PATH\")\" != \"$compilekey\" || \\\n-        \"$FLUTTER_TOOLS_DIR/pubspec.yaml\" -nt \"$FLUTTER_TOOLS_DIR/pubspec.lock\" ]]; then\n-    # Waits for the update lock to be acquired. Placing this check inside the\n-    # conditional allows the majority of flutter/dart installations to bypass\n-    # the lock entirely, but as a result this required a second verification that\n-    # the SDK is up to date.\n-    _wait_for_lock\n-\n-    # A different shell process might have updated the tool/SDK.\n-    if [[ -f \"$SNAPSHOT_PATH\" && -s \"$STAMP_PATH\" && \"$(< \"$STAMP_PATH\")\" == \"$compilekey\" && \"$FLUTTER_TOOLS_DIR/pubspec.yaml\" -ot \"$FLUTTER_TOOLS_DIR/pubspec.lock\" ]]; then\n-      exit $?\n-    fi\n-\n-    # Fetch Dart...\n-    rm -f \"$FLUTTER_ROOT/version\"\n-    rm -f \"$FLUTTER_ROOT/bin/cache/flutter.version.json\"\n-    touch \"$FLUTTER_ROOT/bin/cache/.dartignore\"\n-    \"$FLUTTER_ROOT/bin/internal/update_dart_sdk.sh\"\n-\n-    if [[ \"$BIN_NAME\" == 'dart' || \"$BIN_NAME\" == 'flutter-dev' ]]; then\n-      # Don't try to build tool\n-      return\n-    fi\n-\n-    >&2 echo Building flutter tool...\n-\n-    # Prepare packages...\n-    if [[ \"$CI\" == \"true\" || \"$BOT\" == \"true\" || \"$CONTINUOUS_INTEGRATION\" == \"true\" || \"$CHROME_HEADLESS\" == \"1\" ]]; then\n-      PUB_ENVIRONMENT=\"$PUB_ENVIRONMENT:flutter_bot\"\n-    else\n-      export PUB_SUMMARY_ONLY=1\n-    fi\n-    export PUB_ENVIRONMENT=\"$PUB_ENVIRONMENT:flutter_install\"\n-    pub_upgrade_with_retry\n-\n-    # Move the old snapshot - we can't just overwrite it as the VM might currently have it\n-    # memory mapped (e.g. on flutter upgrade). For downloading a new dart sdk the folder is moved,\n-    # so we take the same approach of moving the file here.\n-    SNAPSHOT_PATH_OLD=\"$SNAPSHOT_PATH.old\"\n-    if [ -f \"$SNAPSHOT_PATH\" ]; then\n-      mv \"$SNAPSHOT_PATH\" \"$SNAPSHOT_PATH_OLD\"\n-    fi\n-\n-    # Compile...\n-    \"$DART\" --verbosity=error $FLUTTER_TOOL_ARGS --snapshot=\"$SNAPSHOT_PATH\" --snapshot-kind=\"app-jit\" --packages=\"$FLUTTER_TOOLS_DIR/.dart_tool/package_config.json\" --no-enable-mirrors \"$SCRIPT_PATH\" > /dev/null\n-    echo \"$compilekey\" > \"$STAMP_PATH\"\n-\n-    # Delete any temporary snapshot path.\n-    if [ -f \"$SNAPSHOT_PATH_OLD\" ]; then\n-      rm -f \"$SNAPSHOT_PATH_OLD\"\n-    fi\n-  fi\n-  # The exit here is extraneous since the function is run in a subshell, but\n-  # this serves as documentation that running the function in a subshell is\n-  # required to make sure any lock directory created by mkdir is cleaned up.\n-  exit $?\n-)\n-\n-# This function is intended to be executed by entrypoints (e.g. `//bin/flutter`\n-# and `//bin/dart`). PROG_NAME and BIN_DIR should already be set by those\n-# entrypoints.\n-function shared::execute() {\n-  export FLUTTER_ROOT=\"$(cd \"${BIN_DIR}/..\" ; pwd -P)\"\n-\n-  # If present, run the bootstrap script first\n-  BOOTSTRAP_PATH=\"$FLUTTER_ROOT/bin/internal/bootstrap.sh\"\n-  if [ -f \"$BOOTSTRAP_PATH\" ]; then\n-    source \"$BOOTSTRAP_PATH\"\n-  fi\n-\n-  FLUTTER_TOOLS_DIR=\"$FLUTTER_ROOT/packages/flutter_tools\"\n-  SNAPSHOT_PATH=\"$FLUTTER_ROOT/bin/cache/flutter_tools.snapshot\"\n-  STAMP_PATH=\"$FLUTTER_ROOT/bin/cache/flutter_tools.stamp\"\n-  SCRIPT_PATH=\"$FLUTTER_TOOLS_DIR/bin/flutter_tools.dart\"\n-  DART_SDK_PATH=\"$FLUTTER_ROOT/bin/cache/dart-sdk\"\n-\n-  DART=\"$DART_SDK_PATH/bin/dart\"\n-\n-  # If running over git-bash, overrides the default UNIX executables with win32\n-  # executables\n-  case \"$(uname -s)\" in\n-    MINGW* | MSYS* )\n-      DART=\"$DART.exe\"\n-      ;;\n-  esac\n-\n-  # Test if running as superuser – but don't warn if running within Docker or CI.\n-  if [[ \"$EUID\" == \"0\" && ! -f /.dockerenv && \"$CI\" != \"true\" && \"$BOT\" != \"true\" && \"$CONTINUOUS_INTEGRATION\" != \"true\" ]]; then\n-    >&2 echo \"   Woah! You appear to be trying to run flutter as root.\"\n-    >&2 echo \"   We strongly recommend running the flutter tool without superuser privileges.\"\n-    >&2 echo \"  /\"\n-    >&2 echo \"📎\"\n-  fi\n-\n-  # Test if Git is available on the Host\n-  if ! hash git 2>/dev/null; then\n-    >&2 echo \"Error: Unable to find git in your PATH.\"\n-    exit 1\n-  fi\n-  # Test if the flutter directory is a git clone (otherwise git rev-parse HEAD\n-  # would fail)\n-  if [[ ! -e \"$FLUTTER_ROOT/.git\" ]]; then\n-    >&2 echo \"Error: The Flutter directory is not a clone of the GitHub project.\"\n-    >&2 echo \"       The flutter tool requires Git in order to operate properly;\"\n-    >&2 echo \"       to install Flutter, see the instructions at:\"\n-    >&2 echo \"       https://docs.flutter.dev/get-started\"\n-    exit 1\n-  fi\n-\n-  BIN_NAME=\"$(basename \"$PROG_NAME\")\"\n-\n-  # File descriptor 7 is prepared here so that we can use it with\n-  # flock(1) in _lock() (see above).\n-  #\n-  # We use number 7 because it's a luckier number than 3; luck is\n-  # important when making locks work reliably. Also because that way\n-  # if anyone is redirecting other file descriptors there's less\n-  # chance of a conflict.\n-  #\n-  # In any case, the file we redirect into this file descriptor is\n-  # this very source file you are reading right now, because that's\n-  # the only file we can truly guarantee exists, since we're running\n-  # it. We don't use PROG_NAME because otherwise if you run `dart` and\n-  # `flutter` simultaneously they'll end up using different lock files\n-  # and will corrupt each others' downloads.\n-  #\n-  # SHARED_NAME itself is prepared by the caller script.\n-  upgrade_flutter 7< \"$SHARED_NAME\"\n-\n-  case \"$BIN_NAME\" in\n-    flutter-dev)\n-      # FLUTTER_TOOL_ARGS aren't quoted below, because it is meant to be\n-      # considered as separate space-separated args.\n-      exec \"$DART\" run --resident --packages=\"$FLUTTER_TOOLS_DIR/.dart_tool/package_config.json\" $FLUTTER_TOOL_ARGS \"$SCRIPT_PATH\" \"$@\"\n-      ;;\n-    flutter*)\n-      # FLUTTER_TOOL_ARGS aren't quoted below, because it is meant to be\n-      # considered as separate space-separated args.\n-      exec \"$DART\" --packages=\"$FLUTTER_TOOLS_DIR/.dart_tool/package_config.json\" $FLUTTER_TOOL_ARGS \"$SNAPSHOT_PATH\" \"$@\"\n-      ;;\n-    dart*)\n-      exec \"$DART\" \"$@\"\n-      ;;\n-    *)\n-      >&2 echo \"Error! Executable name $BIN_NAME not recognized!\"\n-      exit 1\n-      ;;\n-  esac\n-}\n+#!/usr/bin/env bash\n+# Copyright 2014 The Flutter Authors. All rights reserved.\n+# Use of this source code is governed by a BSD-style license that can be\n+# found in the LICENSE file.\n+\n+set -e\n+unset CDPATH\n+\n+# SDK是可直接使用的工具，不要求产品必须由塔塔控制台启动。版本检查关闭只用于\n+# 避免编译命令隐式修改或更新SDK；产品自己的依赖和构建流程保持原样。\n+function shared::execute() {\n+  export FLUTTER_ROOT=\"$(cd \"${BIN_DIR}/..\" && pwd -P)\"\n+  local tools=\"$FLUTTER_ROOT/packages/flutter_tools\"\n+  local dart=\"$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart\"\n+  local snapshot=\"$FLUTTER_ROOT/bin/cache/flutter_tools.snapshot\"\n+  local config=\"$tools/.dart_tool/package_config.json\"\n+  local name=\"$(basename \"$PROG_NAME\")\"\n+  if [[ ! -x \"$dart\" || ! -s \"$snapshot\" || ! -s \"$config\" ||\n+        ! -s \"$FLUTTER_ROOT/bin/cache/flutter.version.json\" ]]; then\n+    >&2 echo \"Flutter SDK 不完整。\"\n+    return 1\n+  fi\n+  case \"$name\" in\n+    flutter)\n+      exec \"$dart\" --packages=\"$config\" \"$snapshot\" --no-version-check \"$@\"\n+      ;;\n+    dart)\n+      exec \"$dart\" \"$@\"\n+      ;;\n+    *)\n+      >&2 echo \"Flutter工具入口不支持：$name\"\n+      return 1\n+      ;;\n+  esac\n+}\ndiff --git a/packages/flutter_tools/lib/src/cache.dart b/packages/flutter_tools/lib/src/cache.dart\nindex 36c8addec9a603f8e5d89288059d7def5406b09de28ab78544e3129db76d83b8..dffe24408031cc33b047be33585dc1ec78e2f687f613d71fc42838c00585030a\n--- a/packages/flutter_tools/lib/src/cache.dart\n+++ b/packages/flutter_tools/lib/src/cache.dart\n@@ -1,1776 +1,1692 @@\n-// Copyright 2014 The Flutter Authors. All rights reserved.\n-// Use of this source code is governed by a BSD-style license that can be\n-// found in the LICENSE file.\n-\n-/// @docImport 'flutter_cache.dart';\n-/// @docImport 'runner/flutter_command.dart';\n-/// @docImport 'runner/flutter_command_runner.dart';\n-library;\n-\n-import 'dart:async';\n-import 'dart:ffi' show Abi;\n-import 'dart:math' show max;\n-\n-import 'package:crypto/crypto.dart';\n-import 'package:file/memory.dart';\n-import 'package:meta/meta.dart';\n-import 'package:process/process.dart';\n-\n-import 'artifacts.dart';\n-import 'base/common.dart';\n-import 'base/context.dart';\n-import 'base/error_handling_io.dart';\n-import 'base/file_system.dart';\n-import 'base/io.dart'\n-    show\n-        HttpClient,\n-        HttpClientRequest,\n-        HttpClientResponse,\n-        HttpHeaders,\n-        HttpStatus,\n-        SocketException,\n-        Stdio;\n-import 'base/logger.dart';\n-import 'base/net.dart';\n-import 'base/os.dart' show OperatingSystemUtils;\n-import 'base/platform.dart';\n-import 'base/terminal.dart';\n-import 'base/user_messages.dart';\n-import 'base/utils.dart' show getElapsedAsSeconds, getSizeAsPlatformMB;\n-import 'convert.dart';\n-import 'features.dart';\n-\n-const kFlutterRootEnvironmentVariableName =\n-    'FLUTTER_ROOT'; // should point to //flutter/ (root of flutter/flutter repo)\n-const kFlutterEngineEnvironmentVariableName =\n-    'FLUTTER_ENGINE'; // should point to //engine/src/ (root of flutter/engine repo)\n-const kSnapshotFileName = 'flutter_tools.snapshot'; // in //flutter/bin/cache/\n-const kFlutterToolsScriptFileName =\n-    'flutter_tools.dart'; // in //flutter/packages/flutter_tools/bin/\n-const kFlutterEnginePackageName = 'sky_engine';\n-\n-/// A tag for a set of development artifacts that need to be cached.\n-class DevelopmentArtifact {\n-  const DevelopmentArtifact._(this.name, {this.feature});\n-\n-  /// The name of the artifact.\n-  ///\n-  /// This should match the flag name in precache.dart.\n-  final String name;\n-\n-  /// A feature to control the visibility of this artifact.\n-  final Feature? feature;\n-\n-  /// Artifacts required for Android development.\n-  static const androidGenSnapshot = DevelopmentArtifact._(\n-    'android_gen_snapshot',\n-    feature: flutterAndroidFeature,\n-  );\n-  static const androidMaven = DevelopmentArtifact._(\n-    'android_maven',\n-    feature: flutterAndroidFeature,\n-  );\n-\n-  // Artifacts used for internal builds.\n-  static const androidInternalBuild = DevelopmentArtifact._(\n-    'android_internal_build',\n-    feature: flutterAndroidFeature,\n-  );\n-\n-  /// Artifacts required for iOS development.\n-  static const iOS = DevelopmentArtifact._('ios', feature: flutterIOSFeature);\n-\n-  /// Artifacts required for web development.\n-  static const web = DevelopmentArtifact._('web', feature: flutterWebFeature);\n-\n-  /// Artifacts required for desktop macOS.\n-  static const macOS = DevelopmentArtifact._('macos', feature: flutterMacOSDesktopFeature);\n-\n-  /// Artifacts required for desktop Windows.\n-  static const windows = DevelopmentArtifact._('windows', feature: flutterWindowsDesktopFeature);\n-\n-  /// Artifacts required for desktop Linux.\n-  static const linux = DevelopmentArtifact._('linux', feature: flutterLinuxDesktopFeature);\n-\n-  /// Artifacts required for Fuchsia.\n-  static const fuchsia = DevelopmentArtifact._('fuchsia', feature: flutterFuchsiaFeature);\n-\n-  /// Artifacts required for the Flutter Runner.\n-  static const flutterRunner = DevelopmentArtifact._(\n-    'flutter_runner',\n-    feature: flutterFuchsiaFeature,\n-  );\n-\n-  /// Artifacts required for any development platform.\n-  ///\n-  /// This does not need to be explicitly returned from requiredArtifacts as\n-  /// it will always be downloaded.\n-  static const universal = DevelopmentArtifact._('universal');\n-\n-  /// Artifacts which contain build information for the flutter tool.\n-  static const informative = DevelopmentArtifact._('informative');\n-\n-  /// The values of DevelopmentArtifacts.\n-  static final values = <DevelopmentArtifact>[\n-    androidGenSnapshot,\n-    androidMaven,\n-    androidInternalBuild,\n-    iOS,\n-    web,\n-    macOS,\n-    windows,\n-    linux,\n-    fuchsia,\n-    universal,\n-    flutterRunner,\n-    informative,\n-  ];\n-\n-  @override\n-  String toString() => 'Artifact($name)';\n-}\n-\n-/// A wrapper around the `bin/cache/` directory.\n-///\n-/// This does not provide any artifacts by default. See [FlutterCache] for the default\n-/// artifact set.\n-///\n-/// ## Artifact mirrors\n-///\n-/// Some environments cannot reach the Google Cloud Storage buckets and CIPD due\n-/// to regional or corporate policies.\n-///\n-/// To enable Flutter users in these environments, the Flutter tool supports\n-/// custom artifact mirrors that the administrators of such environments may\n-/// provide. To use an artifact mirror, the user defines the [kFlutterStorageBaseUrl]\n-/// (`FLUTTER_STORAGE_BASE_URL`) environment variable that points to the mirror.\n-/// Flutter tool reads this variable and uses it instead of the default URLs.\n-///\n-/// For more details on specific URLs used to download artifacts, see\n-/// [storageBaseUrl] and [cipdBaseUrl].\n-class Cache {\n-  /// [rootOverride] is configurable for testing.\n-  /// [artifacts] is configurable for testing.\n-  Cache({\n-    @protected Directory? rootOverride,\n-    @protected List<ArtifactSet>? artifacts,\n-    required Logger logger,\n-    required FileSystem fileSystem,\n-    required Platform platform,\n-    required OperatingSystemUtils osUtils,\n-    Stdio? stdio,\n-  }) : _rootOverride = rootOverride,\n-       _logger = logger,\n-       _fileSystem = fileSystem,\n-       _platform = platform,\n-       _osUtils = osUtils,\n-       _stdio = stdio,\n-       _net = Net(logger: logger, platform: platform),\n-       _fsUtils = FileSystemUtils(fileSystem: fileSystem, platform: platform),\n-       _artifacts = artifacts ?? <ArtifactSet>[];\n-\n-  /// Create a [Cache] for testing.\n-  ///\n-  /// Defaults to a memory file system, fake platform,\n-  /// buffer logger, and no accessible artifacts.\n-  /// By default, the root cache directory path is \"cache\".\n-  factory Cache.test({\n-    Directory? rootOverride,\n-    List<ArtifactSet>? artifacts,\n-    Logger? logger,\n-    FileSystem? fileSystem,\n-    Platform? platform,\n-    Stdio? stdio,\n-    required ProcessManager processManager,\n-    Abi? currentAbi,\n-  }) {\n-    if (rootOverride?.fileSystem != null &&\n-        fileSystem != null &&\n-        rootOverride!.fileSystem != fileSystem) {\n-      throw ArgumentError(\n-        'If rootOverride and fileSystem are both non-null, '\n-            'rootOverride.fileSystem must be the same as fileSystem.',\n-        'fileSystem',\n-      );\n-    }\n-    fileSystem ??= rootOverride?.fileSystem ?? MemoryFileSystem.test();\n-    platform ??= FakePlatform(environment: <String, String>{});\n-    logger ??= BufferLogger.test();\n-    return Cache(\n-      rootOverride: rootOverride ?? fileSystem.currentDirectory,\n-      artifacts: artifacts ?? <ArtifactSet>[],\n-      logger: logger,\n-      fileSystem: fileSystem,\n-      platform: platform,\n-      stdio: stdio,\n-      osUtils: OperatingSystemUtils(\n-        fileSystem: fileSystem,\n-        logger: logger,\n-        platform: platform,\n-        processManager: processManager,\n-        currentAbi: currentAbi,\n-      ),\n-    );\n-  }\n-\n-  final Logger _logger;\n-  final Platform _platform;\n-  final FileSystem _fileSystem;\n-  final OperatingSystemUtils _osUtils;\n-  final Directory? _rootOverride;\n-  final List<ArtifactSet> _artifacts;\n-  final Stdio? _stdio;\n-  final Net _net;\n-  final FileSystemUtils _fsUtils;\n-\n-  late final ArtifactUpdater _artifactUpdater = _createUpdater();\n-\n-  @visibleForTesting\n-  @protected\n-  void registerArtifact(ArtifactSet artifactSet) {\n-    _artifacts.add(artifactSet);\n-  }\n-\n-  /// This has to be lazy because it requires FLUTTER_ROOT to be initialized.\n-  ArtifactUpdater _createUpdater() {\n-    return ArtifactUpdater(\n-      operatingSystemUtils: _osUtils,\n-      logger: _logger,\n-      fileSystem: _fileSystem,\n-      tempStorage: getDownloadDir(),\n-      platform: _platform,\n-      httpClient: HttpClient(),\n-      allowedBaseUrls: <String>[storageBaseUrl, realmlessStorageBaseUrl, cipdBaseUrl],\n-      stdio: _stdio,\n-    );\n-  }\n-\n-  static const _hostsBlockedInChina = <String>[\n-    'storage.googleapis.com',\n-    'chrome-infra-packages.appspot.com',\n-  ];\n-\n-  // Initialized by FlutterCommandRunner on startup.\n-  // Explore making this field lazy to catch non-initialized access.\n-  static String? flutterRoot;\n-\n-  /// Determine the absolute and normalized path for the root of the current\n-  /// Flutter checkout.\n-  ///\n-  /// This method has a series of fallbacks for determining the repo location. The\n-  /// first success will immediately return the root without further checks.\n-  ///\n-  /// The order of these tests is:\n-  ///   1. FLUTTER_ROOT environment variable contains the path.\n-  ///   2. Platform script is a data URI scheme, returning `../..` to support\n-  ///      tests run from `packages/flutter_tools`.\n-  ///   3. Platform script is package URI scheme, returning the grandgrandparent\n-  ///      directory of the package config file location from\n-  ///      `packages/flutter_tools/.dart_tool/package_config.json`.\n-  ///   4. Platform script file path is the snapshot path generated by `bin/flutter`,\n-  ///      returning the grandparent directory from `bin/cache`.\n-  ///   5. Platform script file name is the entrypoint in `packages/flutter_tools/bin/flutter_tools.dart`,\n-  ///      returning the 4th parent directory.\n-  ///   6. The current directory\n-  ///\n-  /// If an exception is thrown during any of these checks, an error message is\n-  /// printed and `.` is returned by default (6).\n-  static String defaultFlutterRoot({\n-    required Platform platform,\n-    required FileSystem fileSystem,\n-    required UserMessages userMessages,\n-  }) {\n-    String normalize(String path) {\n-      return fileSystem.path.normalize(fileSystem.path.absolute(path));\n-    }\n-\n-    if (platform.environment.containsKey(kFlutterRootEnvironmentVariableName)) {\n-      return normalize(platform.environment[kFlutterRootEnvironmentVariableName]!);\n-    }\n-    try {\n-      if (platform.script.scheme == 'data') {\n-        return normalize('../..'); // The tool is running as a test.\n-      }\n-      final String Function(String) dirname = fileSystem.path.dirname;\n-\n-      if (platform.script.scheme == 'package') {\n-        final String packageConfigPath = Uri.parse(\n-          platform.packageConfig!,\n-        ).toFilePath(windows: platform.isWindows);\n-        return normalize(dirname(dirname(dirname(dirname(packageConfigPath)))));\n-      }\n-\n-      if (platform.script.scheme == 'file') {\n-        final String script = platform.script.toFilePath(windows: platform.isWindows);\n-        if (fileSystem.path.basename(script) == kSnapshotFileName) {\n-          return normalize(dirname(dirname(fileSystem.path.dirname(script))));\n-        }\n-        if (fileSystem.path.basename(script) == kFlutterToolsScriptFileName) {\n-          return normalize(dirname(dirname(dirname(dirname(script)))));\n-        }\n-      }\n-    } on Exception catch (error) {\n-      // There is currently no logger attached since this is computed at startup.\n-      // ignore: avoid_print\n-      print(userMessages.runnerNoRoot('$error'));\n-    }\n-    return normalize('.');\n-  }\n-\n-  // Whether to cache artifacts for all platforms. Defaults to only caching\n-  // artifacts for the current platform.\n-  bool includeAllPlatforms = false;\n-\n-  // Names of artifacts which should be cached even if they would normally\n-  // be filtered out for the current platform.\n-  Set<String>? platformOverrideArtifacts;\n-\n-  // Whether to cache the unsigned mac binaries. Defaults to caching the signed binaries.\n-  bool useUnsignedMacBinaries = false;\n-\n-  // Whether the warning printed when a custom artifact URL is used is fatal.\n-  bool fatalStorageWarning = true;\n-\n-  static RandomAccessFile? _lock;\n-  static var _lockEnabled = true;\n-\n-  /// Turn off the [lock]/[releaseLock] mechanism.\n-  ///\n-  /// This is used by the tests since they run simultaneously and all in one\n-  /// process and so it would be a mess if they had to use the lock.\n-  @visibleForTesting\n-  static void disableLocking() {\n-    _lockEnabled = false;\n-  }\n-\n-  /// Turn on the [lock]/[releaseLock] mechanism.\n-  ///\n-  /// This is used by the tests.\n-  @visibleForTesting\n-  static void enableLocking() {\n-    _lockEnabled = true;\n-  }\n-\n-  /// Check if lock acquired, skipping FLUTTER_ALREADY_LOCKED reentrant checks.\n-  ///\n-  /// This is used by the tests.\n-  @visibleForTesting\n-  static bool isLocked() {\n-    return _lock != null;\n-  }\n-\n-  /// Lock the cache directory.\n-  ///\n-  /// This happens while required artifacts are updated\n-  /// (see [FlutterCommandRunner.runCommand]).\n-  ///\n-  /// This uses normal POSIX flock semantics.\n-  Future<void> lock() async {\n-    if (!_lockEnabled) {\n-      return;\n-    }\n-    assert(_lock == null);\n-    final File lockFile = _fileSystem.file(\n-      _fileSystem.path.join(flutterRoot!, 'bin', 'cache', 'lockfile'),\n-    );\n-    try {\n-      _lock = lockFile.openSync(mode: FileMode.write);\n-    } on FileSystemException catch (e) {\n-      _logger.printError('Failed to open or create the artifact cache lockfile: \"$e\"');\n-      _logger.printError('Please ensure you have permissions to create or open ${lockFile.path}');\n-      throwToolExit('Failed to open or create the lockfile');\n-    }\n-    var locked = false;\n-    var printed = false;\n-    while (!locked) {\n-      try {\n-        _lock!.lockSync();\n-        locked = true;\n-      } on FileSystemException {\n-        if (!printed) {\n-          _logger.printTrace(\n-            'Waiting to be able to obtain lock of Flutter binary artifacts directory: ${_lock!.path}',\n-          );\n-          // This needs to go to stderr to avoid cluttering up stdout if a\n-          // parent process is collecting stdout (e.g. when calling \"flutter\n-          // version --machine\"). It's not really a \"warning\" though, so print it\n-          // in grey. Also, make sure that it isn't counted as a warning for\n-          // Logger.warningsAreFatal.\n-          _logger.printWarning(\n-            'Waiting for another flutter command to release the startup lock...',\n-            color: TerminalColor.grey,\n-            fatal: false,\n-          );\n-          printed = true;\n-        }\n-        await Future<void>.delayed(const Duration(milliseconds: 50));\n-      }\n-    }\n-  }\n-\n-  /// Releases the lock.\n-  ///\n-  /// This happens automatically on startup (see [FlutterCommand.verifyThenRunCommand])\n-  /// after the command's required artifacts are updated.\n-  void releaseLock() {\n-    if (!_lockEnabled || _lock == null) {\n-      return;\n-    }\n-    _lock!.closeSync();\n-    _lock = null;\n-  }\n-\n-  /// Checks if the current process owns the lock for the cache directory at\n-  /// this very moment; throws a [StateError] if it doesn't.\n-  void checkLockAcquired() {\n-    if (_lockEnabled &&\n-        _lock == null &&\n-        _platform.environment['FLUTTER_ALREADY_LOCKED'] != 'true') {\n-      throw StateError(\n-        'The current process does not own the lock for the cache directory. This is a bug in Flutter CLI tools.',\n-      );\n-    }\n-  }\n-\n-  String get devToolsVersion {\n-    if (_devToolsVersion == null) {\n-      const devToolsDirPath = 'dart-sdk/bin/resources/devtools';\n-      final Directory devToolsDir = getCacheDir(devToolsDirPath, shouldCreate: false);\n-      if (!devToolsDir.existsSync()) {\n-        throw Exception('Could not find directory at ${devToolsDir.path}');\n-      }\n-      final versionFilePath = '${devToolsDir.path}/version.json';\n-      final File versionFile = _fileSystem.file(versionFilePath);\n-      if (!versionFile.existsSync()) {\n-        throw Exception('Could not find file at $versionFilePath');\n-      }\n-      final dynamic data = jsonDecode(versionFile.readAsStringSync());\n-      if (data is! Map<String, Object?>) {\n-        throw Exception(\n-          \"Expected object of type 'Map<String, Object?>' but got one of type '${data.runtimeType}'\",\n-        );\n-      }\n-      final Object? version = data['version'];\n-      if (version == null) {\n-        throw Exception('Could not parse DevTools version from $version');\n-      }\n-      if (version is! String) {\n-        throw Exception(\n-          \"Could not parse DevTools version. Expected object of type 'String', but got one of type '${version.runtimeType}'\",\n-        );\n-      }\n-      return _devToolsVersion = version;\n-    }\n-    return _devToolsVersion!;\n-  }\n-\n-  String? _devToolsVersion;\n-\n-  /// The current version of Dart used to build Flutter and run the tool.\n-  String get dartSdkVersion {\n-    if (_dartSdkVersion == null) {\n-      // Make the version string more customer-friendly.\n-      // Changes '2.1.0-dev.8.0.flutter-4312ae32' to '2.1.0 (build 2.1.0-dev.8.0 4312ae32)'\n-      final String justVersion = _platform.version.split(' ')[0];\n-      _dartSdkVersion = justVersion.replaceFirstMapped(RegExp(r'(\\d+\\.\\d+\\.\\d+)(.+)'), (\n-        Match match,\n-      ) {\n-        final String noFlutter = match[2]!.replaceAll('.flutter-', ' ');\n-        return '${match[1]} (build ${match[1]}$noFlutter)';\n-      });\n-    }\n-    return _dartSdkVersion!;\n-  }\n-\n-  String? _dartSdkVersion;\n-\n-  /// The current version of Dart used to build Flutter and run the tool.\n-  String get dartSdkBuild {\n-    if (_dartSdkBuild == null) {\n-      // Make the version string more customer-friendly.\n-      // Changes '2.1.0-dev.8.0.flutter-4312ae32' to '2.1.0 (build 2.1.0-dev.8.0 4312ae32)'\n-      final String justVersion = _platform.version.split(' ')[0];\n-      _dartSdkBuild = justVersion.replaceFirstMapped(RegExp(r'(\\d+\\.\\d+\\.\\d+)(.+)'), (Match match) {\n-        final String noFlutter = match[2]!.replaceAll('.flutter-', ' ');\n-        return '${match[1]}$noFlutter';\n-      });\n-    }\n-    return _dartSdkBuild!;\n-  }\n-\n-  String? _dartSdkBuild;\n-\n-  /// The current version of the Flutter engine the flutter tool will download.\n-  String get engineRevision {\n-    _engineRevision ??= getStampFor('engine');\n-    if (_engineRevision == null) {\n-      throwToolExit('Could not determine engine revision.');\n-    }\n-    return _engineRevision!;\n-  }\n-\n-  String? _engineRevision;\n-\n-  /// The \"realm\" for the storage URL.\n-  ///\n-  /// For production artifacts from Engine post-submit and release builds,\n-  /// this string will be empty, and the `storageBaseUrl` will be unmodified.\n-  /// When non-empty, this string will be appended to the `storageBaseUrl` after\n-  /// a '/'. For artifacts generated by Engine presubmits, the realm should be\n-  /// \"flutter_archives_v2\".\n-  String get storageRealm {\n-    _storageRealm ??= getRealmFor('engine');\n-    if (_storageRealm == null) {\n-      throwToolExit('Could not determine engine realm.');\n-    }\n-    return _storageRealm!;\n-  }\n-\n-  String? _storageRealm;\n-\n-  /// The base for URLs that store Flutter engine artifacts that are fetched\n-  /// during the installation of the Flutter SDK.\n-  ///\n-  /// By default the base URL is https://storage.googleapis.com. However, if\n-  /// `FLUTTER_STORAGE_BASE_URL` environment variable ([kFlutterStorageBaseUrl])\n-  /// is provided, the environment variable value is returned instead.\n-  ///\n-  /// See also:\n-  ///\n-  ///  * [cipdBaseUrl], which determines how CIPD artifacts are fetched.\n-  ///  * [Cache] class-level dartdocs that explain how artifact mirrors work.\n-  String get storageBaseUrl {\n-    String? overrideUrl = _platform.environment[kFlutterStorageBaseUrl];\n-    if (overrideUrl == null) {\n-      return storageRealm.isEmpty\n-          ? 'https://storage.googleapis.com'\n-          : 'https://storage.googleapis.com/$storageRealm';\n-    }\n-    // verify that this is a valid URI.\n-    overrideUrl = storageRealm.isEmpty ? overrideUrl : '$overrideUrl/$storageRealm';\n-    try {\n-      Uri.parse(overrideUrl);\n-    } on FormatException catch (err) {\n-      throwToolExit('\"$kFlutterStorageBaseUrl\" contains an invalid URL:\\n$err');\n-    }\n-    _maybeWarnAboutStorageOverride(overrideUrl);\n-    return overrideUrl;\n-  }\n-\n-  String get realmlessStorageBaseUrl {\n-    return storageRealm.isEmpty ? storageBaseUrl : storageBaseUrl.replaceAll('/$storageRealm', '');\n-  }\n-\n-  /// The base for URLs that store Flutter engine artifacts in CIPD.\n-  ///\n-  /// For some platforms, such as Web and Fuchsia, CIPD artifacts are fetched\n-  /// during the installation of the Flutter SDK, in addition to those fetched\n-  /// from [storageBaseUrl].\n-  ///\n-  /// By default the base URL is https://chrome-infra-packages.appspot.com/dl.\n-  /// However, if `FLUTTER_STORAGE_BASE_URL` environment variable is provided\n-  /// ([kFlutterStorageBaseUrl]), then the following value is used:\n-  ///\n-  ///     FLUTTER_STORAGE_BASE_URL/flutter_infra_release/cipd\n-  ///\n-  /// See also:\n-  ///\n-  ///  * [storageBaseUrl], which determines how engine artifacts stored in the\n-  ///    Google Cloud Storage buckets are fetched.\n-  ///  * https://chromium.googlesource.com/infra/luci/luci-go/+/refs/heads/main/cipd,\n-  ///    which contains information about CIPD.\n-  ///  * [Cache] class-level dartdocs that explain how artifact mirrors work.\n-  String get cipdBaseUrl {\n-    final String? overrideUrl = _platform.environment[kFlutterStorageBaseUrl];\n-    if (overrideUrl == null) {\n-      return 'https://chrome-infra-packages.appspot.com/dl';\n-    }\n-\n-    final Uri original;\n-    try {\n-      original = Uri.parse(overrideUrl);\n-    } on FormatException catch (err) {\n-      throwToolExit('\"$kFlutterStorageBaseUrl\" contains an invalid URL:\\n$err');\n-    }\n-\n-    final cipdOverride = original\n-        .replace(pathSegments: <String>[...original.pathSegments, 'flutter_infra_release', 'cipd'])\n-        .toString();\n-    return cipdOverride;\n-  }\n-\n-  var _hasWarnedAboutStorageOverride = false;\n-\n-  void _maybeWarnAboutStorageOverride(String overrideUrl) {\n-    if (_hasWarnedAboutStorageOverride) {\n-      return;\n-    }\n-    _logger.printWarning(\n-      'Flutter assets will be downloaded from $overrideUrl. Make sure you trust this source!',\n-      emphasis: true,\n-      fatal: false,\n-    );\n-    _hasWarnedAboutStorageOverride = true;\n-  }\n-\n-  /// Return the top-level directory in the cache; this is `bin/cache`.\n-  Directory getRoot() {\n-    return _fileSystem.directory(\n-      _fileSystem.path.join(_rootOverride?.path ?? flutterRoot!, 'bin', 'cache'),\n-    );\n-  }\n-\n-  String getHostPlatformArchName() {\n-    return _osUtils.hostPlatform.platformName;\n-  }\n-\n-  /// Return a directory in the cache dir. For `pkg`, this will return `bin/cache/pkg`.\n-  ///\n-  /// When [shouldCreate] is true, the cache directory at [name] will be created\n-  /// if it does not already exist.\n-  Directory getCacheDir(String name, {bool shouldCreate = true}) {\n-    final Directory dir = _fileSystem.directory(_fileSystem.path.join(getRoot().path, name));\n-    if (!dir.existsSync() && shouldCreate) {\n-      dir.createSync(recursive: true);\n-      _osUtils.chmod(dir, '755');\n-    }\n-    return dir;\n-  }\n-\n-  /// Return the top-level directory for artifact downloads.\n-  Directory getDownloadDir() => getCacheDir('downloads');\n-\n-  /// Return the top-level mutable directory in the cache; this is `bin/cache/artifacts`.\n-  Directory getCacheArtifacts() => getCacheDir('artifacts');\n-\n-  /// Location of LICENSE file.\n-  File getLicenseFile() => _fileSystem.file(_fileSystem.path.join(flutterRoot!, 'LICENSE'));\n-\n-  /// Get a named directory from with the cache's artifact directory; for example,\n-  /// `material_fonts` would return `bin/cache/artifacts/material_fonts`.\n-  Directory getArtifactDirectory(String name) {\n-    return getCacheArtifacts().childDirectory(name);\n-  }\n-\n-  MapEntry<String, String> get dyLdLibEntry {\n-    if (_dyLdLibEntry != null) {\n-      return _dyLdLibEntry!;\n-    }\n-    final paths = <String>[];\n-    for (final ArtifactSet artifact in _artifacts) {\n-      final Map<String, String> env = artifact.environment;\n-      if (!env.containsKey('DYLD_LIBRARY_PATH')) {\n-        continue;\n-      }\n-      final String path = env['DYLD_LIBRARY_PATH']!;\n-      if (path.isEmpty) {\n-        continue;\n-      }\n-      paths.add(path);\n-    }\n-    _dyLdLibEntry = MapEntry<String, String>('DYLD_LIBRARY_PATH', paths.join(':'));\n-    return _dyLdLibEntry!;\n-  }\n-\n-  MapEntry<String, String>? _dyLdLibEntry;\n-\n-  /// The web sdk has to be co-located with the dart-sdk so that they can share source\n-  /// code.\n-  Directory getWebSdkDirectory() {\n-    return getRoot().childDirectory('flutter_web_sdk');\n-  }\n-\n-  String? getVersionFor(String artifactName) {\n-    final File versionFile = _fileSystem.file(\n-      _fileSystem.path.join(\n-        _rootOverride?.path ?? flutterRoot!,\n-        'bin',\n-        'internal',\n-        '$artifactName.version',\n-      ),\n-    );\n-    return versionFile.existsSync() ? versionFile.readAsStringSync().trim() : null;\n-  }\n-\n-  // TODO(matanlurey): Remove the ability to do \"generic\" realms, and special case for engine.\n-  // https://github.com/flutter/flutter/issues/164315\n-  String? getRealmFor(String artifactName) {\n-    final File realmFile = _fileSystem.file(\n-      _fileSystem.path.join(\n-        _rootOverride?.path ?? flutterRoot!,\n-        'bin',\n-        'cache',\n-        '$artifactName.realm',\n-      ),\n-    );\n-    return realmFile.existsSync() ? realmFile.readAsStringSync().trim() : '';\n-  }\n-\n-  /// Delete all stamp files maintained by the cache.\n-  void clearStampFiles() {\n-    try {\n-      getStampFileFor('flutter_tools').deleteSync();\n-      for (final ArtifactSet artifact in _artifacts) {\n-        final File file = getStampFileFor(artifact.stampName);\n-        ErrorHandlingFileSystem.deleteIfExists(file);\n-      }\n-    } on FileSystemException catch (err) {\n-      _logger.printWarning('Failed to delete some stamp files: $err');\n-    }\n-  }\n-\n-  /// Read the stamp for [artifactName].\n-  ///\n-  /// If the file is missing or cannot be parsed, returns `null`.\n-  String? getStampFor(String artifactName) {\n-    final File stampFile = getStampFileFor(artifactName);\n-    if (!stampFile.existsSync()) {\n-      return null;\n-    }\n-    try {\n-      return stampFile.readAsStringSync().trim();\n-    } on FileSystemException {\n-      return null;\n-    }\n-  }\n-\n-  void setStampFor(String artifactName, String version) {\n-    getStampFileFor(artifactName).writeAsStringSync(version);\n-  }\n-\n-  File getStampFileFor(String artifactName) {\n-    return _fileSystem.file(_fileSystem.path.join(getRoot().path, '$artifactName.stamp'));\n-  }\n-\n-  /// Returns `true` if either [entity] is older than the tools stamp or if\n-  /// [entity] doesn't exist.\n-  bool isOlderThanToolsStamp(FileSystemEntity entity) {\n-    final File flutterToolsStamp = getStampFileFor('flutter_tools');\n-    return _fsUtils.isOlderThanReference(entity: entity, referenceFile: flutterToolsStamp);\n-  }\n-\n-  Future<bool> isUpToDate() async {\n-    for (final ArtifactSet artifact in _artifacts) {\n-      if (!await artifact.isUpToDate(_fileSystem)) {\n-        return false;\n-      }\n-    }\n-    return true;\n-  }\n-\n-  /// Returns the list of artifacts that need updating from [requiredArtifacts].\n-  Future<List<ArtifactSet>> _collectArtifactsToUpdate(\n-    Set<DevelopmentArtifact> requiredArtifacts,\n-  ) async {\n-    final artifactsToUpdate = <ArtifactSet>[];\n-    final isLocalEngine = context.get<Artifacts>()?.localEngineInfo != null;\n-\n-    for (final ArtifactSet artifact in _artifacts) {\n-      if (!requiredArtifacts.contains(artifact.developmentArtifact)) {\n-        _logger.printTrace('Artifact $artifact is not required, skipping update.');\n-        continue;\n-      }\n-      if (isLocalEngine && (artifact is EngineCachedArtifact || artifact.name == 'engine_stamp')) {\n-        _logger.printTrace(\n-          'Artifact $artifact is an engine artifact or stamp and local engine is provided, skipping update.',\n-        );\n-        continue;\n-      }\n-      if (await artifact.isUpToDate(_fileSystem)) {\n-        continue;\n-      }\n-      artifactsToUpdate.add(artifact);\n-    }\n-    return artifactsToUpdate;\n-  }\n-\n-  /// Update the cache to contain all `requiredArtifacts`.\n-  Future<void> updateAll(Set<DevelopmentArtifact> requiredArtifacts, {bool offline = false}) async {\n-    if (!_lockEnabled) {\n-      return;\n-    }\n-\n-    final List<ArtifactSet> artifactsToUpdate = await _collectArtifactsToUpdate(requiredArtifacts);\n-\n-    if (artifactsToUpdate.isEmpty) {\n-      return;\n-    }\n-\n-    // Download artifacts and display progress\n-    final int total = artifactsToUpdate.length;\n-    for (var i = 0; i < artifactsToUpdate.length; i++) {\n-      final ArtifactSet artifact = artifactsToUpdate[i];\n-      final int current = i + 1;\n-\n-      // Set progress context for the artifact updater\n-      _artifactUpdater.setProgressContext(\n-        artifactIndex: current,\n-        artifactTotal: total,\n-        downloadTotal: artifact.downloadCount,\n-      );\n-\n-      // For artifacts containing multiple downloads, print the artifact name\n-      if (artifact.downloadCount > 1) {\n-        _logger.printStatus('[$current/$total] ${artifact.displayName}');\n-      }\n-\n-      try {\n-        await artifact.update(_artifactUpdater, _logger, _fileSystem, _osUtils, offline: offline);\n-      } on SocketException catch (e) {\n-        if (_hostsBlockedInChina.contains(e.address?.host)) {\n-          _logger.printError(\n-            'Failed to retrieve Flutter tool dependencies: ${e.message}.\\n'\n-            \"If you're in China, please see this page: \"\n-            'https://flutter.dev/to/china-setup',\n-            emphasis: true,\n-          );\n-        }\n-        rethrow;\n-      }\n-    }\n-    _artifactUpdater.resetProgressContext();\n-  }\n-\n-  Future<bool> areRemoteArtifactsAvailable({\n-    String? engineVersion,\n-    bool includeAllPlatforms = true,\n-  }) async {\n-    final bool includeAllPlatformsState = this.includeAllPlatforms;\n-    var allAvailable = true;\n-    this.includeAllPlatforms = includeAllPlatforms;\n-    for (final ArtifactSet cachedArtifact in _artifacts) {\n-      if (cachedArtifact is EngineCachedArtifact) {\n-        allAvailable &= await cachedArtifact.checkForArtifacts(engineVersion);\n-      }\n-    }\n-    this.includeAllPlatforms = includeAllPlatformsState;\n-    return allAvailable;\n-  }\n-\n-  Future<bool> doesRemoteExist(String message, Uri url) async {\n-    final Status status = _logger.startProgress(message);\n-    bool exists;\n-    try {\n-      exists = await _net.doesRemoteFileExist(url);\n-    } finally {\n-      status.stop();\n-    }\n-    return exists;\n-  }\n-}\n-\n-/// Representation of a set of artifacts used by the tool.\n-abstract class ArtifactSet {\n-  ArtifactSet(this.developmentArtifact);\n-\n-  /// The development artifact.\n-  final DevelopmentArtifact developmentArtifact;\n-\n-  /// Whether the artifact is up to date.\n-  Future<bool> isUpToDate(FileSystem fileSystem);\n-\n-  /// The environment variables (if any) required to consume the artifacts.\n-  Map<String, String> get environment {\n-    return const <String, String>{};\n-  }\n-\n-  /// Updates the artifact.\n-  Future<void> update(\n-    ArtifactUpdater artifactUpdater,\n-    Logger logger,\n-    FileSystem fileSystem,\n-    OperatingSystemUtils operatingSystemUtils, {\n-    bool offline = false,\n-  });\n-\n-  /// The canonical name of the artifact.\n-  String get name;\n-\n-  /// A prettier display name.\n-  ///\n-  /// Defaults to the canonical name.\n-  String get displayName => name;\n-\n-  /// The name of the stamp file.\n-  ///\n-  /// Defaults to the same as the artifact name.\n-  String get stampName => name;\n-\n-  /// The number of individual downloads this artifact will perform.\n-  ///\n-  /// Defaults to 1.\n-  int get downloadCount => 1;\n-}\n-\n-/// An artifact set managed by the cache.\n-abstract class CachedArtifact extends ArtifactSet {\n-  CachedArtifact(this.name, this.cache, DevelopmentArtifact developmentArtifact)\n-    : super(developmentArtifact);\n-\n-  final Cache cache;\n-\n-  @override\n-  final String name;\n-\n-  @override\n-  String get stampName => name;\n-\n-  Directory get location => cache.getArtifactDirectory(name);\n-\n-  String? get version => cache.getVersionFor(name);\n-\n-  // Whether or not to bypass normal platform filtering for this artifact.\n-  bool get ignorePlatformFiltering {\n-    return cache.includeAllPlatforms ||\n-        (cache.platformOverrideArtifacts != null &&\n-            cache.platformOverrideArtifacts!.contains(developmentArtifact.name));\n-  }\n-\n-  @override\n-  Future<bool> isUpToDate(FileSystem fileSystem) async {\n-    if (!location.existsSync()) {\n-      return false;\n-    }\n-    if (version != cache.getStampFor(stampName)) {\n-      return false;\n-    }\n-    return isUpToDateInner(fileSystem);\n-  }\n-\n-  @override\n-  Future<void> update(\n-    ArtifactUpdater artifactUpdater,\n-    Logger logger,\n-    FileSystem fileSystem,\n-    OperatingSystemUtils operatingSystemUtils, {\n-    bool offline = false,\n-  }) async {\n-    if (!location.existsSync()) {\n-      try {\n-        location.createSync(recursive: true);\n-      } on FileSystemException catch (err) {\n-        logger.printError(err.toString());\n-        throwToolExit(\n-          'Failed to create directory for flutter cache at ${location.path}. '\n-          'Flutter may be missing permissions in its cache directory.',\n-        );\n-      }\n-    }\n-    await updateInner(artifactUpdater, fileSystem, operatingSystemUtils);\n-    try {\n-      if (version == null) {\n-        logger.printWarning(\n-          'No known version for the artifact name \"$name\". '\n-          'Flutter can continue, but the artifact may be re-downloaded on '\n-          'subsequent invocations until the problem is resolved.',\n-        );\n-      } else {\n-        cache.setStampFor(stampName, version!);\n-      }\n-    } on FileSystemException catch (err) {\n-      logger.printWarning(\n-        'The new artifact \"$name\" was downloaded, but Flutter failed to update '\n-        'its stamp file, receiving the error \"$err\". '\n-        'Flutter can continue, but the artifact may be re-downloaded on '\n-        'subsequent invocations until the problem is resolved.',\n-      );\n-    }\n-    artifactUpdater.removeDownloadedFiles();\n-  }\n-\n-  /// Hook method for extra checks for being up-to-date.\n-  bool isUpToDateInner(FileSystem fileSystem) => true;\n-\n-  Future<void> updateInner(\n-    ArtifactUpdater artifactUpdater,\n-    FileSystem fileSystem,\n-    OperatingSystemUtils operatingSystemUtils,\n-  );\n-}\n-\n-abstract class EngineCachedArtifact extends CachedArtifact {\n-  EngineCachedArtifact(this.stampName, Cache cache, DevelopmentArtifact developmentArtifact)\n-    : super('engine', cache, developmentArtifact);\n-\n-  @override\n-  final String stampName;\n-\n-  @override\n-  String? get version => cache.engineRevision;\n-\n-  @override\n-  int get downloadCount => getPackageDirs().length + getBinaryDirs().length;\n-\n-  /// Return a list of (directory path, download URL path) tuples.\n-  List<List<String>> getBinaryDirs();\n-\n-  /// A list of cache directory paths to which the LICENSE file should be copied.\n-  List<String> getLicenseDirs();\n-\n-  /// A list of the dart package directories to download.\n-  List<String> getPackageDirs();\n-\n-  @override\n-  bool isUpToDateInner(FileSystem fileSystem) {\n-    final Directory pkgDir = cache.getCacheDir('pkg');\n-    for (final String pkgName in getPackageDirs()) {\n-      final String pkgPath = fileSystem.path.join(pkgDir.path, pkgName);\n-      if (!fileSystem.directory(pkgPath).existsSync()) {\n-        return false;\n-      }\n-    }\n-\n-    for (final List<String> toolsDir in getBinaryDirs()) {\n-      final Directory dir = fileSystem.directory(fileSystem.path.join(location.path, toolsDir[0]));\n-      if (!dir.existsSync()) {\n-        return false;\n-      }\n-    }\n-\n-    for (final String licenseDir in getLicenseDirs()) {\n-      final File file = fileSystem.file(fileSystem.path.join(location.path, licenseDir, 'LICENSE'));\n-      if (!file.existsSync()) {\n-        return false;\n-      }\n-    }\n-    return true;\n-  }\n-\n-  @override\n-  Future<void> updateInner(\n-    ArtifactUpdater artifactUpdater,\n-    FileSystem fileSystem,\n-    OperatingSystemUtils operatingSystemUtils,\n-  ) async {\n-    final url = '${cache.storageBaseUrl}/flutter_infra_release/flutter/$version/';\n-\n-    final Directory pkgDir = cache.getCacheDir('pkg');\n-    for (final String pkgName in getPackageDirs()) {\n-      await artifactUpdater.downloadZipArchive(pkgName, Uri.parse('$url$pkgName.zip'), pkgDir);\n-    }\n-\n-    for (final List<String> toolsDir in getBinaryDirs()) {\n-      final String cacheDir = toolsDir[0];\n-      final String urlPath = toolsDir[1];\n-      final Directory dir = fileSystem.directory(fileSystem.path.join(location.path, cacheDir));\n-\n-      final String friendlyName = urlPath.replaceAll('/artifacts.zip', '').replaceAll('.zip', '');\n-      await artifactUpdater.downloadZipArchive(friendlyName, Uri.parse(url + urlPath), dir);\n-\n-      _makeFilesExecutable(dir, operatingSystemUtils);\n-    }\n-\n-    final File licenseSource = cache.getLicenseFile();\n-    for (final String licenseDir in getLicenseDirs()) {\n-      final String licenseDestinationPath = fileSystem.path.join(\n-        location.path,\n-        licenseDir,\n-        'LICENSE',\n-      );\n-      await licenseSource.copy(licenseDestinationPath);\n-    }\n-  }\n-\n-  Future<bool> checkForArtifacts(String? engineVersion) async {\n-    engineVersion ??= version;\n-    final url = '${cache.storageBaseUrl}/flutter_infra_release/flutter/$engineVersion/';\n-\n-    var exists = false;\n-    for (final String pkgName in getPackageDirs()) {\n-      exists = await cache.doesRemoteExist(\n-        'Checking package $pkgName is available...',\n-        Uri.parse('$url$pkgName.zip'),\n-      );\n-      if (!exists) {\n-        return false;\n-      }\n-    }\n-\n-    for (final List<String> toolsDir in getBinaryDirs()) {\n-      final String cacheDir = toolsDir[0];\n-      final String urlPath = toolsDir[1];\n-      exists = await cache.doesRemoteExist(\n-        'Checking $cacheDir tools are available...',\n-        Uri.parse(url + urlPath),\n-      );\n-      if (!exists) {\n-        return false;\n-      }\n-    }\n-    return true;\n-  }\n-\n-  void _makeFilesExecutable(Directory dir, OperatingSystemUtils operatingSystemUtils) {\n-    operatingSystemUtils.chmod(dir, 'a+r,a+x');\n-    for (final File file in dir.listSync(recursive: true).whereType<File>()) {\n-      final FileStat stat = file.statSync();\n-      final isUserExecutable = ((stat.mode >> 6) & 0x1) == 1;\n-      if (file.basename == 'flutter_tester' || isUserExecutable) {\n-        // Make the file readable and executable by all users.\n-        operatingSystemUtils.chmod(file, 'a+r,a+x');\n-      }\n-    }\n-  }\n-}\n-\n-/// An API for downloading and un-archiving artifacts, such as engine binaries or\n-/// additional source code.\n-class ArtifactUpdater {\n-  ArtifactUpdater({\n-    required OperatingSystemUtils operatingSystemUtils,\n-    required Logger logger,\n-    required FileSystem fileSystem,\n-    required Directory tempStorage,\n-    required HttpClient httpClient,\n-    required Platform platform,\n-    required List<String> allowedBaseUrls,\n-    Stdio? stdio,\n-  }) : _operatingSystemUtils = operatingSystemUtils,\n-       _httpClient = httpClient,\n-       _logger = logger,\n-       _fileSystem = fileSystem,\n-       _tempStorage = tempStorage,\n-       _platform = platform,\n-       _allowedBaseUrls = allowedBaseUrls,\n-       _stdio = stdio;\n-\n-  /// The number of times the artifact updater will repeat the artifact download loop.\n-  static const _kRetryCount = 2;\n-\n-  final Logger _logger;\n-  final OperatingSystemUtils _operatingSystemUtils;\n-  final FileSystem _fileSystem;\n-  final Directory _tempStorage;\n-  final HttpClient _httpClient;\n-  final Platform _platform;\n-\n-  /// Artifacts should only be downloaded from URLs that use one of these\n-  /// prefixes.\n-  ///\n-  /// [ArtifactUpdater] will issue a warning if an attempt to download from a\n-  /// non-compliant URL is made.\n-  final List<String> _allowedBaseUrls;\n-\n-  final Stdio? _stdio;\n-\n-  /// Keep track of the files we've downloaded for this execution so we\n-  /// can delete them after completion. We don't delete them right after\n-  /// extraction in case [ArtifactSet.update] is interrupted, so we can\n-  /// restart without starting from scratch.\n-  @visibleForTesting\n-  final downloadedFiles = <File>[];\n-\n-  // Progress tracking state for download output formatting.\n-  int _artifactIndex = 0;\n-  int _artifactTotal = 0;\n-  int _downloadIndex = 0;\n-  int _downloadTotal = 0;\n-\n-  /// Sets the progress context for artifact downloads.\n-  ///\n-  /// This is called before each artifact update to enable progress output.\n-  /// The [downloadIndex] can be used to set the current download index\n-  /// within an artifact (1-based).\n-  void setProgressContext({\n-    required int artifactIndex,\n-    required int artifactTotal,\n-    required int downloadTotal,\n-    int downloadIndex = 0,\n-  }) {\n-    _artifactIndex = artifactIndex;\n-    _artifactTotal = artifactTotal;\n-    _downloadIndex = downloadIndex;\n-    _downloadTotal = downloadTotal;\n-  }\n-\n-  void resetProgressContext() {\n-    _artifactIndex = 0;\n-    _artifactTotal = 0;\n-    _downloadIndex = 0;\n-    _downloadTotal = 0;\n-  }\n-\n-  /// Creates the appropriate display for the current terminal capabilities.\n-  _DownloadDisplay _createDisplay(String statusMessage) {\n-    if (_stdio != null && _logger.supportsColor) {\n-      return _ProgressBarDisplay(stdio: _stdio, statusMessage: statusMessage);\n-    }\n-    return _SpinnerDisplay(logger: _logger, statusMessage: statusMessage);\n-  }\n-\n-  /// These filenames, should they exist after extracting an archive, should be deleted.\n-  static const _denylistedBasenames = <String>{\n-    'entitlements.txt',\n-    'without_entitlements.txt',\n-    'unsigned_binaries.txt',\n-  };\n-  void _removeDenylistedFiles(Directory directory) {\n-    for (final FileSystemEntity entity in directory.listSync(recursive: true)) {\n-      if (entity is! File) {\n-        continue;\n-      }\n-      if (_denylistedBasenames.contains(entity.basename)) {\n-        entity.deleteSync();\n-      }\n-    }\n-  }\n-\n-  /// Download a zip archive from the given [url] and unzip it to [location].\n-  Future<void> downloadZipArchive(String artifactName, Uri url, Directory location) {\n-    return _downloadArchive(artifactName, url, location, _operatingSystemUtils.unzip);\n-  }\n-\n-  /// Download a gzipped tarball from the given [url] and unpack it to [location].\n-  Future<void> downloadZippedTarball(String artifactName, Uri url, Directory location) {\n-    return _downloadArchive(artifactName, url, location, _operatingSystemUtils.unpack);\n-  }\n-\n-  /// Download a file from the given [url] and copy it to [location].\n-  Future<void> downloadFile(String artifactName, Uri url, Directory location) {\n-    return _downloadArchive(artifactName, url, location, (File file, Directory dir) {\n-      file.copySync(dir.childFile(file.basename).path);\n-    });\n-  }\n-\n-  /// Formats a download message with progress context.\n-  @visibleForTesting\n-  String formatProgressMessage(String artifactName) {\n-    final int displayIndex = _downloadIndex + 1;\n-    if (_downloadTotal == 1) {\n-      return '[$_artifactIndex/$_artifactTotal] $artifactName';\n-    } else {\n-      final prefix = displayIndex == _downloadTotal ? '└─' : '├─';\n-      return '  $prefix [$displayIndex/$_downloadTotal] $artifactName';\n-    }\n-  }\n-\n-  /// Download an archive from the given [url] and unzip it to [location].\n-  Future<void> _downloadArchive(\n-    String artifactName,\n-    Uri url,\n-    Directory location,\n-    void Function(File, Directory) extractor,\n-  ) async {\n-    final String downloadPath = flattenNameSubdirs(url, _fileSystem);\n-    final File tempFile = _createDownloadFile(downloadPath);\n-    int retries = _kRetryCount;\n-    final String formattedMessage = formatProgressMessage(artifactName);\n-    _downloadIndex++;\n-\n-    while (retries > 0) {\n-      final _DownloadDisplay display = _createDisplay(formattedMessage);\n-      display.start();\n-\n-      try {\n-        _ensureExists(tempFile.parent);\n-        if (tempFile.existsSync()) {\n-          tempFile.deleteSync();\n-        }\n-        await _download(url, tempFile, display);\n-\n-        if (!tempFile.existsSync()) {\n-          throw Exception('Did not find downloaded file ${tempFile.path}');\n-        }\n-        display.finish();\n-      } on Exception catch (err) {\n-        display.cancel();\n-        _logger.printTrace(err.toString());\n-        retries -= 1;\n-        if (retries == 0) {\n-          throwToolExit(\n-            'Failed to download $url. Ensure you have network connectivity and then try again.\\n$err',\n-          );\n-        }\n-        continue;\n-      } on ArgumentError catch (error) {\n-        display.cancel();\n-        final String? overrideUrl = _platform.environment[kFlutterStorageBaseUrl];\n-        if (overrideUrl != null && url.toString().contains(overrideUrl)) {\n-          _logger.printError(error.toString());\n-          throwToolExit(\n-            'The value of $kFlutterStorageBaseUrl ($overrideUrl) could not be '\n-            'parsed as a valid url. Please see https://flutter.dev/to/use-mirror-site '\n-            'for an example of how to use it.\\n'\n-            'Full URL: $url',\n-            exitCode: kNetworkProblemExitCode,\n-          );\n-        }\n-        // This error should not be hit if there was not a storage URL override, allow the\n-        // tool to crash.\n-        rethrow;\n-      }\n-\n-      /// Unzipping multiple file into a directory will not remove old files\n-      /// from previous versions that are not present in the new bundle.\n-      final Directory destination = location.childDirectory(\n-        tempFile.fileSystem.path.basenameWithoutExtension(tempFile.path),\n-      );\n-      try {\n-        ErrorHandlingFileSystem.deleteIfExists(destination, recursive: true);\n-      } on FileSystemException catch (error) {\n-        // Error that indicates another program has this file open and that it\n-        // cannot be deleted. For the cache, this is either the analyzer reading\n-        // the sky_engine package or a running flutter_tester device.\n-        const kSharingViolation = 32;\n-        if (_platform.isWindows && error.osError?.errorCode == kSharingViolation) {\n-          throwToolExit(\n-            'Failed to delete ${destination.path} because the local file/directory is in use '\n-            'by another process. Try closing any running IDEs or editors and trying '\n-            'again',\n-          );\n-        }\n-      }\n-      _ensureExists(location);\n-\n-      try {\n-        extractor(tempFile, location);\n-      } on Exception catch (err) {\n-        retries -= 1;\n-        if (retries == 0) {\n-          throwToolExit(\n-            'Flutter could not download and/or extract $url. Ensure you have '\n-            'network connectivity and all of the required dependencies listed at '\n-            'https://flutter.dev/setup.\\nThe original exception was: $err.',\n-          );\n-        }\n-        _deleteIgnoringErrors(tempFile);\n-        continue;\n-      }\n-      _removeDenylistedFiles(location);\n-      return;\n-    }\n-  }\n-\n-  /// Download bytes from [url], throwing non-200 responses as an exception.\n-  ///\n-  /// Validates that the md5 of the content bytes matches the provided\n-  /// `x-goog-hash` header, if present. This header should contain an md5 hash\n-  /// if the download source is Google cloud storage.\n-  ///\n-  /// See also:\n-  ///   * https://cloud.google.com/storage/docs/xml-api/reference-headers#xgooghash\n-  Future<void> _download(Uri url, File file, _DownloadDisplay display) async {\n-    final bool isAllowedUrl = _allowedBaseUrls.any(\n-      (String baseUrl) => url.toString().startsWith(baseUrl),\n-    );\n-\n-    // In tests make this a hard failure.\n-    assert(\n-      isAllowedUrl,\n-      'URL not allowed: $url\\n'\n-      'Allowed URLs must be based on one of: ${_allowedBaseUrls.join(', ')}',\n-    );\n-\n-    // In production, issue a warning but allow the download to proceed.\n-    if (!isAllowedUrl) {\n-      display.pause();\n-      _logger.printWarning(\n-        'Downloading an artifact that may not be reachable in some environments (e.g. firewalled environments): $url\\n'\n-        'This should not have happened. This is likely a Flutter SDK bug. Please file an issue at https://github.com/flutter/flutter/issues/new?template=01_activation.yml',\n-      );\n-      display.resume();\n-    }\n-\n-    final HttpClientRequest request = await _httpClient.getUrl(url);\n-    final HttpClientResponse response = await request.close();\n-    if (response.statusCode != HttpStatus.ok) {\n-      throw Exception(response.statusCode);\n-    }\n-\n-    final String? md5Hash = _expectedMd5(response.headers);\n-    ByteConversionSink? inputSink;\n-    late StreamController<Digest> digests;\n-    if (md5Hash != null) {\n-      _logger.printTrace('Content $url md5 hash: $md5Hash');\n-      digests = StreamController<Digest>();\n-      inputSink = md5.startChunkedConversion(digests);\n-    }\n-    final int contentLength = response.contentLength;\n-    final RandomAccessFile randomAccessFile = file.openSync(mode: FileMode.writeOnly);\n-    await response.forEach((List<int> chunk) {\n-      inputSink?.add(chunk);\n-      randomAccessFile.writeFromSync(chunk);\n-      display.onChunk(chunk.length, contentLength);\n-    });\n-    randomAccessFile.closeSync();\n-    if (inputSink != null) {\n-      inputSink.close();\n-      final Digest digest = await digests.stream.last;\n-      final String rawDigest = base64.encode(digest.bytes);\n-      if (rawDigest != md5Hash) {\n-        throw Exception(\n-          'Expected $url to have md5 checksum $md5Hash, but was $rawDigest. This '\n-          'may indicate a problem with your connection to the Flutter backend servers. '\n-          'Please re-try the download after confirming that your network connection is '\n-          'stable.',\n-        );\n-      }\n-    }\n-  }\n-\n-  String? _expectedMd5(HttpHeaders httpHeaders) {\n-    final List<String>? values = httpHeaders['x-goog-hash'];\n-    if (values == null) {\n-      return null;\n-    }\n-    String? rawMd5Hash;\n-    for (final String value in values) {\n-      if (value.startsWith('md5=')) {\n-        rawMd5Hash = value;\n-        break;\n-      }\n-    }\n-    if (rawMd5Hash == null) {\n-      return null;\n-    }\n-    final List<String> segments = rawMd5Hash.split('md5=');\n-    if (segments.length < 2) {\n-      return null;\n-    }\n-    final String md5Hash = segments[1];\n-    if (md5Hash.isEmpty) {\n-      return null;\n-    }\n-    return md5Hash;\n-  }\n-\n-  /// Create a temporary file and add it to the [downloadedFiles].\n-  File _createDownloadFile(String name) {\n-    final File tempFile = _fileSystem.file(_fileSystem.path.join(_tempStorage.path, name));\n-    downloadedFiles.add(tempFile);\n-    return tempFile;\n-  }\n-\n-  /// Create the given [directory] and parents, as necessary.\n-  void _ensureExists(Directory directory) {\n-    if (!directory.existsSync()) {\n-      directory.createSync(recursive: true);\n-    }\n-  }\n-\n-  /// Clear any zip/gzip files downloaded.\n-  void removeDownloadedFiles() {\n-    for (final File file in downloadedFiles) {\n-      if (!file.existsSync()) {\n-        continue;\n-      }\n-      try {\n-        file.deleteSync();\n-      } on FileSystemException catch (e) {\n-        _logger.printWarning('Failed to delete \"${file.path}\". Please delete manually. $e');\n-        continue;\n-      }\n-      for (\n-        Directory directory = file.parent;\n-        directory.absolute.path != _tempStorage.absolute.path;\n-        directory = directory.parent\n-      ) {\n-        // Handle race condition when the directory is deleted before this step\n-        if (!directory.existsSync()) {\n-          break;\n-        }\n-        if (directory.listSync().isNotEmpty) {\n-          break;\n-        }\n-        _deleteIgnoringErrors(directory);\n-      }\n-    }\n-  }\n-\n-  static void _deleteIgnoringErrors(FileSystemEntity entity) {\n-    if (!entity.existsSync()) {\n-      return;\n-    }\n-    try {\n-      entity.deleteSync();\n-    } on FileSystemException {\n-      // Ignore errors.\n-    }\n-  }\n-}\n-\n-@visibleForTesting\n-String flattenNameSubdirs(Uri url, FileSystem fileSystem) {\n-  final pieces = <String>[url.host, ...url.pathSegments];\n-  final Iterable<String> convertedPieces = pieces.map<String>(_flattenNameNoSubdirs);\n-  return fileSystem.path.joinAll(convertedPieces);\n-}\n-\n-/// Given a name containing slashes, colons, and backslashes, expand it into\n-/// something that doesn't.\n-String _flattenNameNoSubdirs(String fileName) {\n-  final replacedCodeUnits = <int>[\n-    for (final int codeUnit in fileName.codeUnits)\n-      ..._flattenNameSubstitutions[codeUnit] ?? <int>[codeUnit],\n-  ];\n-  return String.fromCharCodes(replacedCodeUnits);\n-}\n-\n-// Many characters are problematic in filenames, especially on Windows.\n-final _flattenNameSubstitutions = <int, List<int>>{\n-  r'@'.codeUnitAt(0): '@@'.codeUnits,\n-  r'/'.codeUnitAt(0): '@s@'.codeUnits,\n-  r'\\'.codeUnitAt(0): '@bs@'.codeUnits,\n-  r':'.codeUnitAt(0): '@c@'.codeUnits,\n-  r'%'.codeUnitAt(0): '@per@'.codeUnits,\n-  r'*'.codeUnitAt(0): '@ast@'.codeUnits,\n-  r'<'.codeUnitAt(0): '@lt@'.codeUnits,\n-  r'>'.codeUnitAt(0): '@gt@'.codeUnits,\n-  r'\"'.codeUnitAt(0): '@q@'.codeUnits,\n-  r'|'.codeUnitAt(0): '@pip@'.codeUnits,\n-  r'?'.codeUnitAt(0): '@ques@'.codeUnits,\n-};\n-\n-/// Abstraction for displaying download progress.\n-///\n-/// Two implementations exist:\n-/// - [_ProgressBarDisplay]: ANSI progress bar for terminals with color support.\n-/// - [_SpinnerDisplay]: Spinner-based display via [Logger.startProgress].\n-abstract class _DownloadDisplay {\n-  /// Called when the download begins.\n-  void start();\n-\n-  /// Called when a chunk of data is received.\n-  void onChunk(int chunkSize, int contentLength);\n-\n-  /// Called when the download completes successfully.\n-  void finish();\n-\n-  /// Called when the download is cancelled or fails.\n-  void cancel();\n-\n-  /// Pauses the display (e.g. when another status message needs the terminal).\n-  void pause();\n-\n-  /// Resumes the display after a pause.\n-  void resume();\n-}\n-\n-/// Displays an ANSI progress bar with speed, ETA, and percentage.\n-class _ProgressBarDisplay extends _DownloadDisplay {\n-  _ProgressBarDisplay({required Stdio stdio, required this.statusMessage}) : _stdio = stdio;\n-\n-  static const int _maxTerminalWidth = 80;\n-  static const int _progressUpdateIntervalMs = 100;\n-\n-  final Stdio _stdio;\n-  final String statusMessage;\n-  final DownloadProgress _progress = DownloadProgress();\n-  final Stopwatch _stopwatch = Stopwatch();\n-  int _lastUpdateMs = 0;\n-\n-  int get _terminalWidth =>\n-      (_stdio.terminalColumns ?? _maxTerminalWidth).clamp(0, _maxTerminalWidth);\n-\n-  @override\n-  void start() {\n-    _stopwatch.start();\n-    _stdio.stdoutWrite('$statusMessage\\n');\n-  }\n-\n-  @override\n-  void onChunk(int chunkSize, int contentLength) {\n-    if (_progress.totalBytes < 0) {\n-      _progress.totalBytes = contentLength;\n-    }\n-    _progress.addBytesReceived(chunkSize);\n-    final int currentMs = _stopwatch.elapsedMilliseconds;\n-    if (currentMs >= _lastUpdateMs + _progressUpdateIntervalMs) {\n-      _lastUpdateMs = currentMs;\n-      final String line = _progress.formatProgressLine(\n-        elapsed: _stopwatch.elapsed,\n-        terminalWidth: _terminalWidth,\n-      );\n-      _stdio.stdoutWrite('${AnsiTerminal.clearAndReturnCode}$line');\n-    }\n-  }\n-\n-  void _stopAndClear() {\n-    _stopwatch.stop();\n-    _stdio.stdoutWrite(\n-      '${AnsiTerminal.clearAndReturnCode}'\n-      '${AnsiTerminal.cursorUpLineCode}'\n-      '${AnsiTerminal.clearAndReturnCode}',\n-    );\n-  }\n-\n-  @override\n-  void finish() {\n-    _stopAndClear();\n-    final String summary = _progress.formatCompletionSummary(_stopwatch.elapsed);\n-    final int padding = _terminalWidth - statusMessage.length - summary.length;\n-    final line = '$statusMessage${' ' * max(1, padding)}$summary';\n-    _stdio.stdoutWrite('$line\\n');\n-  }\n-\n-  @override\n-  void cancel() {\n-    _stopAndClear();\n-  }\n-\n-  @override\n-  void pause() {}\n-\n-  @override\n-  void resume() {}\n-}\n-\n-/// Displays a spinner via [Logger.startProgress].\n-class _SpinnerDisplay extends _DownloadDisplay {\n-  _SpinnerDisplay({required Logger logger, required String statusMessage})\n-    : _logger = logger,\n-      _statusMessage = statusMessage;\n-\n-  final Logger _logger;\n-  final String _statusMessage;\n-  Status? _status;\n-\n-  @override\n-  void start() {\n-    _status = _logger.startProgress(_statusMessage);\n-  }\n-\n-  @override\n-  void onChunk(int chunkSize, int contentLength) {}\n-\n-  @override\n-  void finish() {\n-    _status?.stop();\n-  }\n-\n-  @override\n-  void cancel() {\n-    _status?.stop();\n-  }\n-\n-  @override\n-  void pause() {\n-    _status?.pause();\n-  }\n-\n-  @override\n-  void resume() {\n-    _status?.resume();\n-  }\n-}\n-\n-/// Tracks download progress and provides formatted display strings.\n-@visibleForTesting\n-class DownloadProgress {\n-  /// Total expected bytes, or -1 if unknown.\n-  int totalBytes = -1;\n-\n-  int _bytesReceived = 0;\n-  int get bytesReceived => _bytesReceived;\n-\n-  void addBytesReceived(int bytes) {\n-    _bytesReceived += bytes;\n-  }\n-\n-  bool get hasKnownSize => totalBytes > 0;\n-\n-  double get fractionReceived => hasKnownSize ? (_bytesReceived / totalBytes).clamp(0.0, 1.0) : 0.0;\n-\n-  int get percentReceived => (fractionReceived * 100).round();\n-\n-  /// Download speed in bytes per second.\n-  double speedBytesPerSecond(Duration elapsed) {\n-    if (elapsed.inMilliseconds == 0) {\n-      return 0;\n-    }\n-    return _bytesReceived * 1000 / elapsed.inMilliseconds;\n-  }\n-\n-  /// Estimated time remaining.\n-  Duration? timeRemaining(Duration elapsed) {\n-    final double speed = speedBytesPerSecond(elapsed);\n-    if (!hasKnownSize || speed == 0) {\n-      return null;\n-    }\n-    final int totalRemainingBytes = totalBytes - _bytesReceived;\n-    return Duration(milliseconds: (totalRemainingBytes * 1000 / speed).round());\n-  }\n-\n-  static const _subBlocks = ['▏', '▎', '▍', '▌', '▋', '▊', '▉'];\n-\n-  /// Renders a progress bar with sub-character precision.\n-  ///\n-  /// Uses 1/8-block characters for a smooth fill edge.\n-  String renderProgressBar(int width) {\n-    if (!hasKnownSize || width <= 0) {\n-      return '';\n-    }\n-    final int totalEighths = (fractionReceived * width * 8).round();\n-    final int fullBlocks = totalEighths ~/ 8;\n-    final int remainder = totalEighths % 8;\n-    final int emptyBlocks = width - fullBlocks - 1;\n-    final String filled = '█' * fullBlocks;\n-    final String partial = remainder > 0 ? _subBlocks[remainder - 1] : ' ';\n-    final String empty = ' ' * emptyBlocks;\n-    return '$filled$partial$empty';\n-  }\n-\n-  /// Formats download speed as a human-readable string.\n-  String formatSpeed(Duration elapsed) {\n-    return '${getSizeAsPlatformMB(speedBytesPerSecond(elapsed).round())}/s';\n-  }\n-\n-  /// Formats bytes received and total.\n-  String formatBytes() {\n-    if (hasKnownSize) {\n-      return '${getSizeAsPlatformMB(_bytesReceived)}'\n-          '/${getSizeAsPlatformMB(totalBytes)}';\n-    }\n-    return getSizeAsPlatformMB(_bytesReceived);\n-  }\n-\n-  /// Formats estimated time remaining.\n-  String formatRemaining(Duration elapsed) {\n-    final Duration? rem = timeRemaining(elapsed);\n-    if (rem == null) {\n-      return '';\n-    }\n-    return 'ETA ${getElapsedAsSeconds(rem)}';\n-  }\n-\n-  /// Formats the full progress line for terminal display.\n-  String formatProgressLine({required Duration elapsed, required int terminalWidth}) {\n-    final String indent = ' ' * 5;\n-    final percentReceivedStr = hasKnownSize ? '${percentReceived.toString().padLeft(3)}%' : '';\n-    final String bytesStr = formatBytes();\n-    final String speedStr = formatSpeed(elapsed);\n-    final String etaStr = formatRemaining(elapsed);\n-\n-    final parts = <String>[percentReceivedStr, bytesStr, speedStr, etaStr];\n-    final String info = parts.where((String s) => s.isNotEmpty).join('  ');\n-\n-    // The progress bar is 28 characters wide and terminated on either side by\n-    // thin vertical lines which take up another 2 characters. 28 characters was\n-    // chosen empirically to make the progress bar take up enough space to look\n-    // good while leaving enough space for the detailed info under \"normal\"\n-    // conditions (artifact size <1GB, download speed >1MB/s).\n-    const barInner = 28;\n-    const int barTotal = barInner + 2; // ▕ + bar + ▏\n-    final String line;\n-\n-    // Only show the progress bar if we have enough room to show it along with\n-    // the info, otherwise just show the info right-aligned.\n-    if (hasKnownSize && terminalWidth >= indent.length + barTotal + info.length) {\n-      final String bar = renderProgressBar(barInner);\n-      final int padding = terminalWidth - indent.length - barTotal - info.length;\n-      line = '$indent▕$bar▏${' ' * padding}$info';\n-    } else {\n-      final int padding = terminalWidth - indent.length - info.length;\n-      final unclipped = '$indent${' ' * max(0, padding)}$info';\n-      line = unclipped.length <= terminalWidth ? unclipped : unclipped.substring(0, terminalWidth);\n-    }\n-    return line;\n-  }\n-\n-  /// Formats the completion summary like `(21.1MB in 5.0s)`.\n-  String formatCompletionSummary(Duration elapsed) {\n-    final String size = getSizeAsPlatformMB(_bytesReceived);\n-    final String time = getElapsedAsSeconds(elapsed);\n-    return '($size in $time)';\n-  }\n-}\n+// Copyright 2014 The Flutter Authors. All rights reserved.\n+// Use of this source code is governed by a BSD-style license that can be\n+// found in the LICENSE file.\n+\n+/// @docImport 'flutter_cache.dart';\n+/// @docImport 'runner/flutter_command.dart';\n+/// @docImport 'runner/flutter_command_runner.dart';\n+library;\n+\n+import 'dart:async';\n+import 'dart:ffi' show Abi;\n+import 'dart:math' show max;\n+\n+import 'package:crypto/crypto.dart';\n+import 'package:file/memory.dart';\n+import 'package:meta/meta.dart';\n+import 'package:process/process.dart';\n+\n+import 'artifacts.dart';\n+import 'base/common.dart';\n+import 'base/context.dart';\n+import 'base/error_handling_io.dart';\n+import 'base/file_system.dart';\n+import 'base/io.dart'\n+    show\n+        HttpClient,\n+        HttpClientRequest,\n+        HttpClientResponse,\n+        HttpHeaders,\n+        HttpStatus,\n+        Stdio;\n+import 'base/logger.dart';\n+import 'base/net.dart';\n+import 'base/os.dart' show OperatingSystemUtils;\n+import 'base/platform.dart';\n+import 'base/terminal.dart';\n+import 'base/user_messages.dart';\n+import 'base/utils.dart' show getElapsedAsSeconds, getSizeAsPlatformMB;\n+import 'convert.dart';\n+import 'features.dart';\n+\n+const kFlutterRootEnvironmentVariableName =\n+    'FLUTTER_ROOT'; // should point to //flutter/ (root of flutter/flutter repo)\n+const kFlutterEngineEnvironmentVariableName =\n+    'FLUTTER_ENGINE'; // should point to //engine/src/ (root of flutter/engine repo)\n+const kSnapshotFileName = 'flutter_tools.snapshot'; // in //flutter/bin/cache/\n+const kFlutterToolsScriptFileName =\n+    'flutter_tools.dart'; // in //flutter/packages/flutter_tools/bin/\n+const kFlutterEnginePackageName = 'sky_engine';\n+\n+/// A tag for a set of development artifacts that need to be cached.\n+class DevelopmentArtifact {\n+  const DevelopmentArtifact._(this.name, {this.feature});\n+\n+  /// The name of the artifact.\n+  ///\n+  /// This should match the flag name in precache.dart.\n+  final String name;\n+\n+  /// A feature to control the visibility of this artifact.\n+  final Feature? feature;\n+\n+  /// Artifacts required for Android development.\n+  static const androidGenSnapshot = DevelopmentArtifact._(\n+    'android_gen_snapshot',\n+    feature: flutterAndroidFeature,\n+  );\n+  static const androidMaven = DevelopmentArtifact._(\n+    'android_maven',\n+    feature: flutterAndroidFeature,\n+  );\n+\n+  // Artifacts used for internal builds.\n+  static const androidInternalBuild = DevelopmentArtifact._(\n+    'android_internal_build',\n+    feature: flutterAndroidFeature,\n+  );\n+\n+  /// Artifacts required for iOS development.\n+  static const iOS = DevelopmentArtifact._('ios', feature: flutterIOSFeature);\n+\n+  /// Artifacts required for web development.\n+  static const web = DevelopmentArtifact._('web', feature: flutterWebFeature);\n+\n+  /// Artifacts required for desktop macOS.\n+  static const macOS = DevelopmentArtifact._('macos', feature: flutterMacOSDesktopFeature);\n+\n+  /// Artifacts required for desktop Windows.\n+  static const windows = DevelopmentArtifact._('windows', feature: flutterWindowsDesktopFeature);\n+\n+  /// Artifacts required for desktop Linux.\n+  static const linux = DevelopmentArtifact._('linux', feature: flutterLinuxDesktopFeature);\n+\n+  /// Artifacts required for Fuchsia.\n+  static const fuchsia = DevelopmentArtifact._('fuchsia', feature: flutterFuchsiaFeature);\n+\n+  /// Artifacts required for the Flutter Runner.\n+  static const flutterRunner = DevelopmentArtifact._(\n+    'flutter_runner',\n+    feature: flutterFuchsiaFeature,\n+  );\n+\n+  /// Artifacts required for any development platform.\n+  ///\n+  /// This does not need to be explicitly returned from requiredArtifacts as\n+  /// it will always be downloaded.\n+  static const universal = DevelopmentArtifact._('universal');\n+\n+  /// Artifacts which contain build information for the flutter tool.\n+  static const informative = DevelopmentArtifact._('informative');\n+\n+  /// The values of DevelopmentArtifacts.\n+  static final values = <DevelopmentArtifact>[\n+    androidGenSnapshot,\n+    androidMaven,\n+    androidInternalBuild,\n+    iOS,\n+    web,\n+    macOS,\n+    windows,\n+    linux,\n+    fuchsia,\n+    universal,\n+    flutterRunner,\n+    informative,\n+  ];\n+\n+  @override\n+  String toString() => 'Artifact($name)';\n+}\n+\n+/// A wrapper around the `bin/cache/` directory.\n+///\n+/// This does not provide any artifacts by default. See [FlutterCache] for the default\n+/// artifact set.\n+///\n+/// ## Artifact mirrors\n+///\n+/// Some environments cannot reach the Google Cloud Storage buckets and CIPD due\n+/// to regional or corporate policies.\n+///\n+/// To enable Flutter users in these environments, the Flutter tool supports\n+/// custom artifact mirrors that the administrators of such environments may\n+/// provide. To use an artifact mirror, the user defines the [kFlutterStorageBaseUrl]\n+/// (`FLUTTER_STORAGE_BASE_URL`) environment variable that points to the mirror.\n+/// Flutter tool reads this variable and uses it instead of the default URLs.\n+///\n+/// For more details on specific URLs used to download artifacts, see\n+/// [storageBaseUrl] and [cipdBaseUrl].\n+class Cache {\n+  /// [rootOverride] is configurable for testing.\n+  /// [artifacts] is configurable for testing.\n+  Cache({\n+    @protected Directory? rootOverride,\n+    @protected List<ArtifactSet>? artifacts,\n+    required Logger logger,\n+    required FileSystem fileSystem,\n+    required Platform platform,\n+    required OperatingSystemUtils osUtils,\n+    Stdio? stdio,\n+  }) : _rootOverride = rootOverride,\n+       _logger = logger,\n+       _fileSystem = fileSystem,\n+       _platform = platform,\n+       _osUtils = osUtils,\n+       _net = Net(logger: logger, platform: platform),\n+       _fsUtils = FileSystemUtils(fileSystem: fileSystem, platform: platform),\n+       _artifacts = artifacts ?? <ArtifactSet>[];\n+\n+  /// Create a [Cache] for testing.\n+  ///\n+  /// Defaults to a memory file system, fake platform,\n+  /// buffer logger, and no accessible artifacts.\n+  /// By default, the root cache directory path is \"cache\".\n+  factory Cache.test({\n+    Directory? rootOverride,\n+    List<ArtifactSet>? artifacts,\n+    Logger? logger,\n+    FileSystem? fileSystem,\n+    Platform? platform,\n+    Stdio? stdio,\n+    required ProcessManager processManager,\n+    Abi? currentAbi,\n+  }) {\n+    if (rootOverride?.fileSystem != null &&\n+        fileSystem != null &&\n+        rootOverride!.fileSystem != fileSystem) {\n+      throw ArgumentError(\n+        'If rootOverride and fileSystem are both non-null, '\n+            'rootOverride.fileSystem must be the same as fileSystem.',\n+        'fileSystem',\n+      );\n+    }\n+    fileSystem ??= rootOverride?.fileSystem ?? MemoryFileSystem.test();\n+    platform ??= FakePlatform(environment: <String, String>{});\n+    logger ??= BufferLogger.test();\n+    return Cache(\n+      rootOverride: rootOverride ?? fileSystem.currentDirectory,\n+      artifacts: artifacts ?? <ArtifactSet>[],\n+      logger: logger,\n+      fileSystem: fileSystem,\n+      platform: platform,\n+      stdio: stdio,\n+      osUtils: OperatingSystemUtils(\n+        fileSystem: fileSystem,\n+        logger: logger,\n+        platform: platform,\n+        processManager: processManager,\n+        currentAbi: currentAbi,\n+      ),\n+    );\n+  }\n+\n+  final Logger _logger;\n+  final Platform _platform;\n+  final FileSystem _fileSystem;\n+  final OperatingSystemUtils _osUtils;\n+  final Directory? _rootOverride;\n+  final List<ArtifactSet> _artifacts;\n+  final Net _net;\n+  final FileSystemUtils _fsUtils;\n+\n+  @visibleForTesting\n+  @protected\n+  void registerArtifact(ArtifactSet artifactSet) {\n+    _artifacts.add(artifactSet);\n+  }\n+\n+  // Initialized by FlutterCommandRunner on startup.\n+  // Explore making this field lazy to catch non-initialized access.\n+  static String? flutterRoot;\n+\n+  /// Determine the absolute and normalized path for the root of the current\n+  /// Flutter checkout.\n+  ///\n+  /// This method has a series of fallbacks for determining the repo location. The\n+  /// first success will immediately return the root without further checks.\n+  ///\n+  /// The order of these tests is:\n+  ///   1. FLUTTER_ROOT environment variable contains the path.\n+  ///   2. Platform script is a data URI scheme, returning `../..` to support\n+  ///      tests run from `packages/flutter_tools`.\n+  ///   3. Platform script is package URI scheme, returning the grandgrandparent\n+  ///      directory of the package config file location from\n+  ///      `packages/flutter_tools/.dart_tool/package_config.json`.\n+  ///   4. Platform script file path is the snapshot path generated by `bin/flutter`,\n+  ///      returning the grandparent directory from `bin/cache`.\n+  ///   5. Platform script file name is the entrypoint in `packages/flutter_tools/bin/flutter_tools.dart`,\n+  ///      returning the 4th parent directory.\n+  ///   6. The current directory\n+  ///\n+  /// If an exception is thrown during any of these checks, an error message is\n+  /// printed and `.` is returned by default (6).\n+  static String defaultFlutterRoot({\n+    required Platform platform,\n+    required FileSystem fileSystem,\n+    required UserMessages userMessages,\n+  }) {\n+    String normalize(String path) {\n+      return fileSystem.path.normalize(fileSystem.path.absolute(path));\n+    }\n+\n+    if (platform.environment.containsKey(kFlutterRootEnvironmentVariableName)) {\n+      return normalize(platform.environment[kFlutterRootEnvironmentVariableName]!);\n+    }\n+    try {\n+      if (platform.script.scheme == 'data') {\n+        return normalize('../..'); // The tool is running as a test.\n+      }\n+      final String Function(String) dirname = fileSystem.path.dirname;\n+\n+      if (platform.script.scheme == 'package') {\n+        final String packageConfigPath = Uri.parse(\n+          platform.packageConfig!,\n+        ).toFilePath(windows: platform.isWindows);\n+        return normalize(dirname(dirname(dirname(dirname(packageConfigPath)))));\n+      }\n+\n+      if (platform.script.scheme == 'file') {\n+        final String script = platform.script.toFilePath(windows: platform.isWindows);\n+        if (fileSystem.path.basename(script) == kSnapshotFileName) {\n+          return normalize(dirname(dirname(fileSystem.path.dirname(script))));\n+        }\n+        if (fileSystem.path.basename(script) == kFlutterToolsScriptFileName) {\n+          return normalize(dirname(dirname(dirname(dirname(script)))));\n+        }\n+      }\n+    } on Exception catch (error) {\n+      // There is currently no logger attached since this is computed at startup.\n+      // ignore: avoid_print\n+      print(userMessages.runnerNoRoot('$error'));\n+    }\n+    return normalize('.');\n+  }\n+\n+  // Whether to cache artifacts for all platforms. Defaults to only caching\n+  // artifacts for the current platform.\n+  bool includeAllPlatforms = false;\n+\n+  // Names of artifacts which should be cached even if they would normally\n+  // be filtered out for the current platform.\n+  Set<String>? platformOverrideArtifacts;\n+\n+  // Whether to cache the unsigned mac binaries. Defaults to caching the signed binaries.\n+  bool useUnsignedMacBinaries = false;\n+\n+  // Whether the warning printed when a custom artifact URL is used is fatal.\n+  bool fatalStorageWarning = true;\n+\n+  static RandomAccessFile? _lock;\n+  static var _lockEnabled = true;\n+\n+  /// Turn off the [lock]/[releaseLock] mechanism.\n+  ///\n+  /// This is used by the tests since they run simultaneously and all in one\n+  /// process and so it would be a mess if they had to use the lock.\n+  @visibleForTesting\n+  static void disableLocking() {\n+    _lockEnabled = false;\n+  }\n+\n+  /// Turn on the [lock]/[releaseLock] mechanism.\n+  ///\n+  /// This is used by the tests.\n+  @visibleForTesting\n+  static void enableLocking() {\n+    _lockEnabled = true;\n+  }\n+\n+  /// Check if lock acquired, skipping FLUTTER_ALREADY_LOCKED reentrant checks.\n+  ///\n+  /// This is used by the tests.\n+  @visibleForTesting\n+  static bool isLocked() {\n+    return _lock != null;\n+  }\n+\n+  /// Lock the cache directory.\n+  ///\n+  /// This happens while required artifacts are updated\n+  /// (see [FlutterCommandRunner.runCommand]).\n+  ///\n+  /// This uses normal POSIX flock semantics.\n+  Future<void> lock() async {\n+    if (!_lockEnabled) {\n+      return;\n+    }\n+    assert(_lock == null);\n+    final File lockFile = _fileSystem.file(\n+      _fileSystem.path.join(flutterRoot!, 'bin', 'cache', 'lockfile'),\n+    );\n+    try {\n+      _lock = lockFile.openSync(mode: FileMode.write);\n+    } on FileSystemException catch (e) {\n+      _logger.printError('Failed to open or create the artifact cache lockfile: \"$e\"');\n+      _logger.printError('Please ensure you have permissions to create or open ${lockFile.path}');\n+      throwToolExit('Failed to open or create the lockfile');\n+    }\n+    var locked = false;\n+    var printed = false;\n+    while (!locked) {\n+      try {\n+        _lock!.lockSync();\n+        locked = true;\n+      } on FileSystemException {\n+        if (!printed) {\n+          _logger.printTrace(\n+            'Waiting to be able to obtain lock of Flutter binary artifacts directory: ${_lock!.path}',\n+          );\n+          // This needs to go to stderr to avoid cluttering up stdout if a\n+          // parent process is collecting stdout (e.g. when calling \"flutter\n+          // version --machine\"). It's not really a \"warning\" though, so print it\n+          // in grey. Also, make sure that it isn't counted as a warning for\n+          // Logger.warningsAreFatal.\n+          _logger.printWarning(\n+            'Waiting for another flutter command to release the startup lock...',\n+            color: TerminalColor.grey,\n+            fatal: false,\n+          );\n+          printed = true;\n+        }\n+        await Future<void>.delayed(const Duration(milliseconds: 50));\n+      }\n+    }\n+  }\n+\n+  /// Releases the lock.\n+  ///\n+  /// This happens automatically on startup (see [FlutterCommand.verifyThenRunCommand])\n+  /// after the command's required artifacts are updated.\n+  void releaseLock() {\n+    if (!_lockEnabled || _lock == null) {\n+      return;\n+    }\n+    _lock!.closeSync();\n+    _lock = null;\n+  }\n+\n+  /// Checks if the current process owns the lock for the cache directory at\n+  /// this very moment; throws a [StateError] if it doesn't.\n+  void checkLockAcquired() {\n+    if (_lockEnabled &&\n+        _lock == null &&\n+        _platform.environment['FLUTTER_ALREADY_LOCKED'] != 'true') {\n+      throw StateError(\n+        'The current process does not own the lock for the cache directory. This is a bug in Flutter CLI tools.',\n+      );\n+    }\n+  }\n+\n+  String get devToolsVersion {\n+    if (_devToolsVersion == null) {\n+      const devToolsDirPath = 'dart-sdk/bin/resources/devtools';\n+      final Directory devToolsDir = getCacheDir(devToolsDirPath, shouldCreate: false);\n+      if (!devToolsDir.existsSync()) {\n+        throw Exception('Could not find directory at ${devToolsDir.path}');\n+      }\n+      final versionFilePath = '${devToolsDir.path}/version.json';\n+      final File versionFile = _fileSystem.file(versionFilePath);\n+      if (!versionFile.existsSync()) {\n+        throw Exception('Could not find file at $versionFilePath');\n+      }\n+      final dynamic data = jsonDecode(versionFile.readAsStringSync());\n+      if (data is! Map<String, Object?>) {\n+        throw Exception(\n+          \"Expected object of type 'Map<String, Object?>' but got one of type '${data.runtimeType}'\",\n+        );\n+      }\n+      final Object? version = data['version'];\n+      if (version == null) {\n+        throw Exception('Could not parse DevTools version from $version');\n+      }\n+      if (version is! String) {\n+        throw Exception(\n+          \"Could not parse DevTools version. Expected object of type 'String', but got one of type '${version.runtimeType}'\",\n+        );\n+      }\n+      return _devToolsVersion = version;\n+    }\n+    return _devToolsVersion!;\n+  }\n+\n+  String? _devToolsVersion;\n+\n+  /// The current version of Dart used to build Flutter and run the tool.\n+  String get dartSdkVersion {\n+    if (_dartSdkVersion == null) {\n+      // Make the version string more customer-friendly.\n+      // Changes '2.1.0-dev.8.0.flutter-4312ae32' to '2.1.0 (build 2.1.0-dev.8.0 4312ae32)'\n+      final String justVersion = _platform.version.split(' ')[0];\n+      _dartSdkVersion = justVersion.replaceFirstMapped(RegExp(r'(\\d+\\.\\d+\\.\\d+)(.+)'), (\n+        Match match,\n+      ) {\n+        final String noFlutter = match[2]!.replaceAll('.flutter-', ' ');\n+        return '${match[1]} (build ${match[1]}$noFlutter)';\n+      });\n+    }\n+    return _dartSdkVersion!;\n+  }\n+\n+  String? _dartSdkVersion;\n+\n+  /// The current version of Dart used to build Flutter and run the tool.\n+  String get dartSdkBuild {\n+    if (_dartSdkBuild == null) {\n+      // Make the version string more customer-friendly.\n+      // Changes '2.1.0-dev.8.0.flutter-4312ae32' to '2.1.0 (build 2.1.0-dev.8.0 4312ae32)'\n+      final String justVersion = _platform.version.split(' ')[0];\n+      _dartSdkBuild = justVersion.replaceFirstMapped(RegExp(r'(\\d+\\.\\d+\\.\\d+)(.+)'), (Match match) {\n+        final String noFlutter = match[2]!.replaceAll('.flutter-', ' ');\n+        return '${match[1]}$noFlutter';\n+      });\n+    }\n+    return _dartSdkBuild!;\n+  }\n+\n+  String? _dartSdkBuild;\n+\n+  /// The current version of the Flutter engine the flutter tool will download.\n+  String get engineRevision {\n+    _engineRevision ??= getStampFor('engine');\n+    if (_engineRevision == null) {\n+      throwToolExit('Could not determine engine revision.');\n+    }\n+    return _engineRevision!;\n+  }\n+\n+  String? _engineRevision;\n+\n+  /// The \"realm\" for the storage URL.\n+  ///\n+  /// For production artifacts from Engine post-submit and release builds,\n+  /// this string will be empty, and the `storageBaseUrl` will be unmodified.\n+  /// When non-empty, this string will be appended to the `storageBaseUrl` after\n+  /// a '/'. For artifacts generated by Engine presubmits, the realm should be\n+  /// \"flutter_archives_v2\".\n+  String get storageRealm {\n+    _storageRealm ??= getRealmFor('engine');\n+    if (_storageRealm == null) {\n+      throwToolExit('Could not determine engine realm.');\n+    }\n+    return _storageRealm!;\n+  }\n+\n+  String? _storageRealm;\n+\n+  /// The base for URLs that store Flutter engine artifacts that are fetched\n+  /// during the installation of the Flutter SDK.\n+  ///\n+  /// By default the base URL is https://storage.googleapis.com. However, if\n+  /// `FLUTTER_STORAGE_BASE_URL` environment variable ([kFlutterStorageBaseUrl])\n+  /// is provided, the environment variable value is returned instead.\n+  ///\n+  /// See also:\n+  ///\n+  ///  * [cipdBaseUrl], which determines how CIPD artifacts are fetched.\n+  ///  * [Cache] class-level dartdocs that explain how artifact mirrors work.\n+  String get storageBaseUrl {\n+    String? overrideUrl = _platform.environment[kFlutterStorageBaseUrl];\n+    if (overrideUrl == null) {\n+      return storageRealm.isEmpty\n+          ? 'https://storage.googleapis.com'\n+          : 'https://storage.googleapis.com/$storageRealm';\n+    }\n+    // verify that this is a valid URI.\n+    overrideUrl = storageRealm.isEmpty ? overrideUrl : '$overrideUrl/$storageRealm';\n+    try {\n+      Uri.parse(overrideUrl);\n+    } on FormatException catch (err) {\n+      throwToolExit('\"$kFlutterStorageBaseUrl\" contains an invalid URL:\\n$err');\n+    }\n+    _maybeWarnAboutStorageOverride(overrideUrl);\n+    return overrideUrl;\n+  }\n+\n+  String get realmlessStorageBaseUrl {\n+    return storageRealm.isEmpty ? storageBaseUrl : storageBaseUrl.replaceAll('/$storageRealm', '');\n+  }\n+\n+  /// The base for URLs that store Flutter engine artifacts in CIPD.\n+  ///\n+  /// For some platforms, such as Web and Fuchsia, CIPD artifacts are fetched\n+  /// during the installation of the Flutter SDK, in addition to those fetched\n+  /// from [storageBaseUrl].\n+  ///\n+  /// By default the base URL is https://chrome-infra-packages.appspot.com/dl.\n+  /// However, if `FLUTTER_STORAGE_BASE_URL` environment variable is provided\n+  /// ([kFlutterStorageBaseUrl]), then the following value is used:\n+  ///\n+  ///     FLUTTER_STORAGE_BASE_URL/flutter_infra_release/cipd\n+  ///\n+  /// See also:\n+  ///\n+  ///  * [storageBaseUrl], which determines how engine artifacts stored in the\n+  ///    Google Cloud Storage buckets are fetched.\n+  ///  * https://chromium.googlesource.com/infra/luci/luci-go/+/refs/heads/main/cipd,\n+  ///    which contains information about CIPD.\n+  ///  * [Cache] class-level dartdocs that explain how artifact mirrors work.\n+  String get cipdBaseUrl {\n+    final String? overrideUrl = _platform.environment[kFlutterStorageBaseUrl];\n+    if (overrideUrl == null) {\n+      return 'https://chrome-infra-packages.appspot.com/dl';\n+    }\n+\n+    final Uri original;\n+    try {\n+      original = Uri.parse(overrideUrl);\n+    } on FormatException catch (err) {\n+      throwToolExit('\"$kFlutterStorageBaseUrl\" contains an invalid URL:\\n$err');\n+    }\n+\n+    final cipdOverride = original\n+        .replace(pathSegments: <String>[...original.pathSegments, 'flutter_infra_release', 'cipd'])\n+        .toString();\n+    return cipdOverride;\n+  }\n+\n+  var _hasWarnedAboutStorageOverride = false;\n+\n+  void _maybeWarnAboutStorageOverride(String overrideUrl) {\n+    if (_hasWarnedAboutStorageOverride) {\n+      return;\n+    }\n+    _logger.printWarning(\n+      'Flutter assets will be downloaded from $overrideUrl. Make sure you trust this source!',\n+      emphasis: true,\n+      fatal: false,\n+    );\n+    _hasWarnedAboutStorageOverride = true;\n+  }\n+\n+  /// Return the top-level directory in the cache; this is `bin/cache`.\n+  Directory getRoot() {\n+    return _fileSystem.directory(\n+      _fileSystem.path.join(_rootOverride?.path ?? flutterRoot!, 'bin', 'cache'),\n+    );\n+  }\n+\n+  String getHostPlatformArchName() {\n+    return _osUtils.hostPlatform.platformName;\n+  }\n+\n+  /// Return a directory in the cache dir. For `pkg`, this will return `bin/cache/pkg`.\n+  ///\n+  /// When [shouldCreate] is true, the cache directory at [name] will be created\n+  /// if it does not already exist.\n+  Directory getCacheDir(String name, {bool shouldCreate = true}) {\n+    final Directory dir = _fileSystem.directory(_fileSystem.path.join(getRoot().path, name));\n+    if (!dir.existsSync() && shouldCreate) {\n+      throwToolExit('Flutter受控SDK缺少已准备目录：$name，请先完成工具库准备。');\n+    }\n+    return dir;\n+  }\n+\n+  /// Return the top-level directory for artifact downloads.\n+  Directory getDownloadDir() => getCacheDir('downloads');\n+\n+  /// Return the top-level mutable directory in the cache; this is `bin/cache/artifacts`.\n+  Directory getCacheArtifacts() => getCacheDir('artifacts');\n+\n+  /// Location of LICENSE file.\n+  File getLicenseFile() => _fileSystem.file(_fileSystem.path.join(flutterRoot!, 'LICENSE'));\n+\n+  /// Get a named directory from with the cache's artifact directory; for example,\n+  /// `material_fonts` would return `bin/cache/artifacts/material_fonts`.\n+  Directory getArtifactDirectory(String name) {\n+    return getCacheArtifacts().childDirectory(name);\n+  }\n+\n+  MapEntry<String, String> get dyLdLibEntry {\n+    if (_dyLdLibEntry != null) {\n+      return _dyLdLibEntry!;\n+    }\n+    final paths = <String>[];\n+    for (final ArtifactSet artifact in _artifacts) {\n+      final Map<String, String> env = artifact.environment;\n+      if (!env.containsKey('DYLD_LIBRARY_PATH')) {\n+        continue;\n+      }\n+      final String path = env['DYLD_LIBRARY_PATH']!;\n+      if (path.isEmpty) {\n+        continue;\n+      }\n+      paths.add(path);\n+    }\n+    _dyLdLibEntry = MapEntry<String, String>('DYLD_LIBRARY_PATH', paths.join(':'));\n+    return _dyLdLibEntry!;\n+  }\n+\n+  MapEntry<String, String>? _dyLdLibEntry;\n+\n+  /// The web sdk has to be co-located with the dart-sdk so that they can share source\n+  /// code.\n+  Directory getWebSdkDirectory() {\n+    return getRoot().childDirectory('flutter_web_sdk');\n+  }\n+\n+  String? getVersionFor(String artifactName) {\n+    final File versionFile = _fileSystem.file(\n+      _fileSystem.path.join(\n+        _rootOverride?.path ?? flutterRoot!,\n+        'bin',\n+        'internal',\n+        '$artifactName.version',\n+      ),\n+    );\n+    return versionFile.existsSync() ? versionFile.readAsStringSync().trim() : null;\n+  }\n+\n+  // TODO(matanlurey): Remove the ability to do \"generic\" realms, and special case for engine.\n+  // https://github.com/flutter/flutter/issues/164315\n+  String? getRealmFor(String artifactName) {\n+    final File realmFile = _fileSystem.file(\n+      _fileSystem.path.join(\n+        _rootOverride?.path ?? flutterRoot!,\n+        'bin',\n+        'cache',\n+        '$artifactName.realm',\n+      ),\n+    );\n+    return realmFile.existsSync() ? realmFile.readAsStringSync().trim() : '';\n+  }\n+\n+  /// Delete all stamp files maintained by the cache.\n+  void clearStampFiles() {\n+    try {\n+      getStampFileFor('flutter_tools').deleteSync();\n+      for (final ArtifactSet artifact in _artifacts) {\n+        final File file = getStampFileFor(artifact.stampName);\n+        ErrorHandlingFileSystem.deleteIfExists(file);\n+      }\n+    } on FileSystemException catch (err) {\n+      _logger.printWarning('Failed to delete some stamp files: $err');\n+    }\n+  }\n+\n+  /// Read the stamp for [artifactName].\n+  ///\n+  /// If the file is missing or cannot be parsed, returns `null`.\n+  String? getStampFor(String artifactName) {\n+    final File stampFile = getStampFileFor(artifactName);\n+    if (!stampFile.existsSync()) {\n+      return null;\n+    }\n+    try {\n+      return stampFile.readAsStringSync().trim();\n+    } on FileSystemException {\n+      return null;\n+    }\n+  }\n+\n+  void setStampFor(String artifactName, String version) {\n+    getStampFileFor(artifactName).writeAsStringSync(version);\n+  }\n+\n+  File getStampFileFor(String artifactName) {\n+    return _fileSystem.file(_fileSystem.path.join(getRoot().path, '$artifactName.stamp'));\n+  }\n+\n+  /// Returns `true` if either [entity] is older than the tools stamp or if\n+  /// [entity] doesn't exist.\n+  bool isOlderThanToolsStamp(FileSystemEntity entity) {\n+    final File flutterToolsStamp = getStampFileFor('flutter_tools');\n+    return _fsUtils.isOlderThanReference(entity: entity, referenceFile: flutterToolsStamp);\n+  }\n+\n+  Future<bool> isUpToDate() async {\n+    for (final ArtifactSet artifact in _artifacts) {\n+      if (!await artifact.isUpToDate(_fileSystem)) {\n+        return false;\n+      }\n+    }\n+    return true;\n+  }\n+\n+  /// Returns the list of artifacts that need updating from [requiredArtifacts].\n+  Future<List<ArtifactSet>> _collectArtifactsToUpdate(\n+    Set<DevelopmentArtifact> requiredArtifacts,\n+  ) async {\n+    final artifactsToUpdate = <ArtifactSet>[];\n+    final isLocalEngine = context.get<Artifacts>()?.localEngineInfo != null;\n+\n+    for (final ArtifactSet artifact in _artifacts) {\n+      if (!requiredArtifacts.contains(artifact.developmentArtifact)) {\n+        _logger.printTrace('Artifact $artifact is not required, skipping update.');\n+        continue;\n+      }\n+      if (isLocalEngine && (artifact is EngineCachedArtifact || artifact.name == 'engine_stamp')) {\n+        _logger.printTrace(\n+          'Artifact $artifact is an engine artifact or stamp and local engine is provided, skipping update.',\n+        );\n+        continue;\n+      }\n+      if (await artifact.isUpToDate(_fileSystem)) {\n+        continue;\n+      }\n+      artifactsToUpdate.add(artifact);\n+    }\n+    return artifactsToUpdate;\n+  }\n+\n+  /// Update the cache to contain all `requiredArtifacts`.\n+  Future<void> updateAll(Set<DevelopmentArtifact> requiredArtifacts, {bool offline = false}) async {\n+    if (!_lockEnabled) {\n+      return;\n+    }\n+\n+    final List<ArtifactSet> artifactsToUpdate = await _collectArtifactsToUpdate(requiredArtifacts);\n+\n+    if (artifactsToUpdate.isEmpty) {\n+      return;\n+    }\n+\n+    // 缺失资源明确失败；产品不得下载或更新其他任务正在读取的共享原件。\n+    throwToolExit(\n+      'Flutter受控SDK缺少已准备资源：${artifactsToUpdate.map((artifact) => artifact.name).join(', ')}。',\n+    );\n+  }\n+\n+  Future<bool> areRemoteArtifactsAvailable({\n+    String? engineVersion,\n+    bool includeAllPlatforms = true,\n+  }) async {\n+    final bool includeAllPlatformsState = this.includeAllPlatforms;\n+    var allAvailable = true;\n+    this.includeAllPlatforms = includeAllPlatforms;\n+    for (final ArtifactSet cachedArtifact in _artifacts) {\n+      if (cachedArtifact is EngineCachedArtifact) {\n+        allAvailable &= await cachedArtifact.checkForArtifacts(engineVersion);\n+      }\n+    }\n+    this.includeAllPlatforms = includeAllPlatformsState;\n+    return allAvailable;\n+  }\n+\n+  Future<bool> doesRemoteExist(String message, Uri url) async {\n+    final Status status = _logger.startProgress(message);\n+    bool exists;\n+    try {\n+      exists = await _net.doesRemoteFileExist(url);\n+    } finally {\n+      status.stop();\n+    }\n+    return exists;\n+  }\n+}\n+\n+/// Representation of a set of artifacts used by the tool.\n+abstract class ArtifactSet {\n+  ArtifactSet(this.developmentArtifact);\n+\n+  /// The development artifact.\n+  final DevelopmentArtifact developmentArtifact;\n+\n+  /// Whether the artifact is up to date.\n+  Future<bool> isUpToDate(FileSystem fileSystem);\n+\n+  /// The environment variables (if any) required to consume the artifacts.\n+  Map<String, String> get environment {\n+    return const <String, String>{};\n+  }\n+\n+  /// Updates the artifact.\n+  Future<void> update(\n+    ArtifactUpdater artifactUpdater,\n+    Logger logger,\n+    FileSystem fileSystem,\n+    OperatingSystemUtils operatingSystemUtils, {\n+    bool offline = false,\n+  });\n+\n+  /// The canonical name of the artifact.\n+  String get name;\n+\n+  /// A prettier display name.\n+  ///\n+  /// Defaults to the canonical name.\n+  String get displayName => name;\n+\n+  /// The name of the stamp file.\n+  ///\n+  /// Defaults to the same as the artifact name.\n+  String get stampName => name;\n+\n+  /// The number of individual downloads this artifact will perform.\n+  ///\n+  /// Defaults to 1.\n+  int get downloadCount => 1;\n+}\n+\n+/// An artifact set managed by the cache.\n+abstract class CachedArtifact extends ArtifactSet {\n+  CachedArtifact(this.name, this.cache, DevelopmentArtifact developmentArtifact)\n+    : super(developmentArtifact);\n+\n+  final Cache cache;\n+\n+  @override\n+  final String name;\n+\n+  @override\n+  String get stampName => name;\n+\n+  Directory get location => cache.getArtifactDirectory(name);\n+\n+  String? get version => cache.getVersionFor(name);\n+\n+  // Whether or not to bypass normal platform filtering for this artifact.\n+  bool get ignorePlatformFiltering {\n+    return cache.includeAllPlatforms ||\n+        (cache.platformOverrideArtifacts != null &&\n+            cache.platformOverrideArtifacts!.contains(developmentArtifact.name));\n+  }\n+\n+  @override\n+  Future<bool> isUpToDate(FileSystem fileSystem) async {\n+    if (!location.existsSync()) {\n+      return false;\n+    }\n+    if (version != cache.getStampFor(stampName)) {\n+      return false;\n+    }\n+    return isUpToDateInner(fileSystem);\n+  }\n+\n+  @override\n+  Future<void> update(\n+    ArtifactUpdater artifactUpdater,\n+    Logger logger,\n+    FileSystem fileSystem,\n+    OperatingSystemUtils operatingSystemUtils, {\n+    bool offline = false,\n+  }) async {\n+    throwToolExit('Flutter受控SDK资源只能在工具库准备阶段更新：$name。');\n+  }\n+\n+  /// Hook method for extra checks for being up-to-date.\n+  bool isUpToDateInner(FileSystem fileSystem) => true;\n+\n+  Future<void> updateInner(\n+    ArtifactUpdater artifactUpdater,\n+    FileSystem fileSystem,\n+    OperatingSystemUtils operatingSystemUtils,\n+  );\n+}\n+\n+abstract class EngineCachedArtifact extends CachedArtifact {\n+  EngineCachedArtifact(this.stampName, Cache cache, DevelopmentArtifact developmentArtifact)\n+    : super('engine', cache, developmentArtifact);\n+\n+  @override\n+  final String stampName;\n+\n+  @override\n+  String? get version => cache.engineRevision;\n+\n+  @override\n+  int get downloadCount => getPackageDirs().length + getBinaryDirs().length;\n+\n+  /// Return a list of (directory path, download URL path) tuples.\n+  List<List<String>> getBinaryDirs();\n+\n+  /// A list of cache directory paths to which the LICENSE file should be copied.\n+  List<String> getLicenseDirs();\n+\n+  /// A list of the dart package directories to download.\n+  List<String> getPackageDirs();\n+\n+  @override\n+  bool isUpToDateInner(FileSystem fileSystem) {\n+    final Directory pkgDir = cache.getCacheDir('pkg');\n+    for (final String pkgName in getPackageDirs()) {\n+      final String pkgPath = fileSystem.path.join(pkgDir.path, pkgName);\n+      if (!fileSystem.directory(pkgPath).existsSync()) {\n+        return false;\n+      }\n+    }\n+\n+    for (final List<String> toolsDir in getBinaryDirs()) {\n+      final Directory dir = fileSystem.directory(fileSystem.path.join(location.path, toolsDir[0]));\n+      if (!dir.existsSync()) {\n+        return false;\n+      }\n+    }\n+\n+    for (final String licenseDir in getLicenseDirs()) {\n+      final File file = fileSystem.file(fileSystem.path.join(location.path, licenseDir, 'LICENSE'));\n+      if (!file.existsSync()) {\n+        return false;\n+      }\n+    }\n+    return true;\n+  }\n+\n+  @override\n+  Future<void> updateInner(\n+    ArtifactUpdater artifactUpdater,\n+    FileSystem fileSystem,\n+    OperatingSystemUtils operatingSystemUtils,\n+  ) async {\n+    final url = '${cache.storageBaseUrl}/flutter_infra_release/flutter/$version/';\n+\n+    final Directory pkgDir = cache.getCacheDir('pkg');\n+    for (final String pkgName in getPackageDirs()) {\n+      await artifactUpdater.downloadZipArchive(pkgName, Uri.parse('$url$pkgName.zip'), pkgDir);\n+    }\n+\n+    for (final List<String> toolsDir in getBinaryDirs()) {\n+      final String cacheDir = toolsDir[0];\n+      final String urlPath = toolsDir[1];\n+      final Directory dir = fileSystem.directory(fileSystem.path.join(location.path, cacheDir));\n+\n+      final String friendlyName = urlPath.replaceAll('/artifacts.zip', '').replaceAll('.zip', '');\n+      await artifactUpdater.downloadZipArchive(friendlyName, Uri.parse(url + urlPath), dir);\n+\n+      _makeFilesExecutable(dir, operatingSystemUtils);\n+    }\n+\n+    final File licenseSource = cache.getLicenseFile();\n+    for (final String licenseDir in getLicenseDirs()) {\n+      final String licenseDestinationPath = fileSystem.path.join(\n+        location.path,\n+        licenseDir,\n+        'LICENSE',\n+      );\n+      await licenseSource.copy(licenseDestinationPath);\n+    }\n+  }\n+\n+  Future<bool> checkForArtifacts(String? engineVersion) async {\n+    engineVersion ??= version;\n+    final url = '${cache.storageBaseUrl}/flutter_infra_release/flutter/$engineVersion/';\n+\n+    var exists = false;\n+    for (final String pkgName in getPackageDirs()) {\n+      exists = await cache.doesRemoteExist(\n+        'Checking package $pkgName is available...',\n+        Uri.parse('$url$pkgName.zip'),\n+      );\n+      if (!exists) {\n+        return false;\n+      }\n+    }\n+\n+    for (final List<String> toolsDir in getBinaryDirs()) {\n+      final String cacheDir = toolsDir[0];\n+      final String urlPath = toolsDir[1];\n+      exists = await cache.doesRemoteExist(\n+        'Checking $cacheDir tools are available...',\n+        Uri.parse(url + urlPath),\n+      );\n+      if (!exists) {\n+        return false;\n+      }\n+    }\n+    return true;\n+  }\n+\n+  void _makeFilesExecutable(Directory dir, OperatingSystemUtils operatingSystemUtils) {\n+    operatingSystemUtils.chmod(dir, 'a+r,a+x');\n+    for (final File file in dir.listSync(recursive: true).whereType<File>()) {\n+      final FileStat stat = file.statSync();\n+      final isUserExecutable = ((stat.mode >> 6) & 0x1) == 1;\n+      if (file.basename == 'flutter_tester' || isUserExecutable) {\n+        // Make the file readable and executable by all users.\n+        operatingSystemUtils.chmod(file, 'a+r,a+x');\n+      }\n+    }\n+  }\n+}\n+\n+/// An API for downloading and un-archiving artifacts, such as engine binaries or\n+/// additional source code.\n+class ArtifactUpdater {\n+  ArtifactUpdater({\n+    required OperatingSystemUtils operatingSystemUtils,\n+    required Logger logger,\n+    required FileSystem fileSystem,\n+    required Directory tempStorage,\n+    required HttpClient httpClient,\n+    required Platform platform,\n+    required List<String> allowedBaseUrls,\n+    Stdio? stdio,\n+  }) : _operatingSystemUtils = operatingSystemUtils,\n+       _httpClient = httpClient,\n+       _logger = logger,\n+       _fileSystem = fileSystem,\n+       _tempStorage = tempStorage,\n+       _platform = platform,\n+       _allowedBaseUrls = allowedBaseUrls,\n+       _stdio = stdio;\n+\n+  /// The number of times the artifact updater will repeat the artifact download loop.\n+  static const _kRetryCount = 2;\n+\n+  final Logger _logger;\n+  final OperatingSystemUtils _operatingSystemUtils;\n+  final FileSystem _fileSystem;\n+  final Directory _tempStorage;\n+  final HttpClient _httpClient;\n+  final Platform _platform;\n+\n+  /// Artifacts should only be downloaded from URLs that use one of these\n+  /// prefixes.\n+  ///\n+  /// [ArtifactUpdater] will issue a warning if an attempt to download from a\n+  /// non-compliant URL is made.\n+  final List<String> _allowedBaseUrls;\n+\n+  final Stdio? _stdio;\n+\n+  /// Keep track of the files we've downloaded for this execution so we\n+  /// can delete them after completion. We don't delete them right after\n+  /// extraction in case [ArtifactSet.update] is interrupted, so we can\n+  /// restart without starting from scratch.\n+  @visibleForTesting\n+  final downloadedFiles = <File>[];\n+\n+  // Progress tracking state for download output formatting.\n+  int _artifactIndex = 0;\n+  int _artifactTotal = 0;\n+  int _downloadIndex = 0;\n+  int _downloadTotal = 0;\n+\n+  /// Sets the progress context for artifact downloads.\n+  ///\n+  /// This is called before each artifact update to enable progress output.\n+  /// The [downloadIndex] can be used to set the current download index\n+  /// within an artifact (1-based).\n+  void setProgressContext({\n+    required int artifactIndex,\n+    required int artifactTotal,\n+    required int downloadTotal,\n+    int downloadIndex = 0,\n+  }) {\n+    _artifactIndex = artifactIndex;\n+    _artifactTotal = artifactTotal;\n+    _downloadIndex = downloadIndex;\n+    _downloadTotal = downloadTotal;\n+  }\n+\n+  void resetProgressContext() {\n+    _artifactIndex = 0;\n+    _artifactTotal = 0;\n+    _downloadIndex = 0;\n+    _downloadTotal = 0;\n+  }\n+\n+  /// Creates the appropriate display for the current terminal capabilities.\n+  _DownloadDisplay _createDisplay(String statusMessage) {\n+    if (_stdio != null && _logger.supportsColor) {\n+      return _ProgressBarDisplay(stdio: _stdio, statusMessage: statusMessage);\n+    }\n+    return _SpinnerDisplay(logger: _logger, statusMessage: statusMessage);\n+  }\n+\n+  /// These filenames, should they exist after extracting an archive, should be deleted.\n+  static const _denylistedBasenames = <String>{\n+    'entitlements.txt',\n+    'without_entitlements.txt',\n+    'unsigned_binaries.txt',\n+  };\n+  void _removeDenylistedFiles(Directory directory) {\n+    for (final FileSystemEntity entity in directory.listSync(recursive: true)) {\n+      if (entity is! File) {\n+        continue;\n+      }\n+      if (_denylistedBasenames.contains(entity.basename)) {\n+        entity.deleteSync();\n+      }\n+    }\n+  }\n+\n+  /// Download a zip archive from the given [url] and unzip it to [location].\n+  Future<void> downloadZipArchive(String artifactName, Uri url, Directory location) {\n+    return _downloadArchive(artifactName, url, location, _operatingSystemUtils.unzip);\n+  }\n+\n+  /// Download a gzipped tarball from the given [url] and unpack it to [location].\n+  Future<void> downloadZippedTarball(String artifactName, Uri url, Directory location) {\n+    return _downloadArchive(artifactName, url, location, _operatingSystemUtils.unpack);\n+  }\n+\n+  /// Download a file from the given [url] and copy it to [location].\n+  Future<void> downloadFile(String artifactName, Uri url, Directory location) {\n+    return _downloadArchive(artifactName, url, location, (File file, Directory dir) {\n+      file.copySync(dir.childFile(file.basename).path);\n+    });\n+  }\n+\n+  /// Formats a download message with progress context.\n+  @visibleForTesting\n+  String formatProgressMessage(String artifactName) {\n+    final int displayIndex = _downloadIndex + 1;\n+    if (_downloadTotal == 1) {\n+      return '[$_artifactIndex/$_artifactTotal] $artifactName';\n+    } else {\n+      final prefix = displayIndex == _downloadTotal ? '└─' : '├─';\n+      return '  $prefix [$displayIndex/$_downloadTotal] $artifactName';\n+    }\n+  }\n+\n+  /// Download an archive from the given [url] and unzip it to [location].\n+  Future<void> _downloadArchive(\n+    String artifactName,\n+    Uri url,\n+    Directory location,\n+    void Function(File, Directory) extractor,\n+  ) async {\n+    final String downloadPath = flattenNameSubdirs(url, _fileSystem);\n+    final File tempFile = _createDownloadFile(downloadPath);\n+    int retries = _kRetryCount;\n+    final String formattedMessage = formatProgressMessage(artifactName);\n+    _downloadIndex++;\n+\n+    while (retries > 0) {\n+      final _DownloadDisplay display = _createDisplay(formattedMessage);\n+      display.start();\n+\n+      try {\n+        _ensureExists(tempFile.parent);\n+        if (tempFile.existsSync()) {\n+          tempFile.deleteSync();\n+        }\n+        await _download(url, tempFile, display);\n+\n+        if (!tempFile.existsSync()) {\n+          throw Exception('Did not find downloaded file ${tempFile.path}');\n+        }\n+        display.finish();\n+      } on Exception catch (err) {\n+        display.cancel();\n+        _logger.printTrace(err.toString());\n+        retries -= 1;\n+        if (retries == 0) {\n+          throwToolExit(\n+            'Failed to download $url. Ensure you have network connectivity and then try again.\\n$err',\n+          );\n+        }\n+        continue;\n+      } on ArgumentError catch (error) {\n+        display.cancel();\n+        final String? overrideUrl = _platform.environment[kFlutterStorageBaseUrl];\n+        if (overrideUrl != null && url.toString().contains(overrideUrl)) {\n+          _logger.printError(error.toString());\n+          throwToolExit(\n+            'The value of $kFlutterStorageBaseUrl ($overrideUrl) could not be '\n+            'parsed as a valid url. Please see https://flutter.dev/to/use-mirror-site '\n+            'for an example of how to use it.\\n'\n+            'Full URL: $url',\n+            exitCode: kNetworkProblemExitCode,\n+          );\n+        }\n+        // This error should not be hit if there was not a storage URL override, allow the\n+        // tool to crash.\n+        rethrow;\n+      }\n+\n+      /// Unzipping multiple file into a directory will not remove old files\n+      /// from previous versions that are not present in the new bundle.\n+      final Directory destination = location.childDirectory(\n+        tempFile.fileSystem.path.basenameWithoutExtension(tempFile.path),\n+      );\n+      try {\n+        ErrorHandlingFileSystem.deleteIfExists(destination, recursive: true);\n+      } on FileSystemException catch (error) {\n+        // Error that indicates another program has this file open and that it\n+        // cannot be deleted. For the cache, this is either the analyzer reading\n+        // the sky_engine package or a running flutter_tester device.\n+        const kSharingViolation = 32;\n+        if (_platform.isWindows && error.osError?.errorCode == kSharingViolation) {\n+          throwToolExit(\n+            'Failed to delete ${destination.path} because the local file/directory is in use '\n+            'by another process. Try closing any running IDEs or editors and trying '\n+            'again',\n+          );\n+        }\n+      }\n+      _ensureExists(location);\n+\n+      try {\n+        extractor(tempFile, location);\n+      } on Exception catch (err) {\n+        retries -= 1;\n+        if (retries == 0) {\n+          throwToolExit(\n+            'Flutter could not download and/or extract $url. Ensure you have '\n+            'network connectivity and all of the required dependencies listed at '\n+            'https://flutter.dev/setup.\\nThe original exception was: $err.',\n+          );\n+        }\n+        _deleteIgnoringErrors(tempFile);\n+        continue;\n+      }\n+      _removeDenylistedFiles(location);\n+      return;\n+    }\n+  }\n+\n+  /// Download bytes from [url], throwing non-200 responses as an exception.\n+  ///\n+  /// Validates that the md5 of the content bytes matches the provided\n+  /// `x-goog-hash` header, if present. This header should contain an md5 hash\n+  /// if the download source is Google cloud storage.\n+  ///\n+  /// See also:\n+  ///   * https://cloud.google.com/storage/docs/xml-api/reference-headers#xgooghash\n+  Future<void> _download(Uri url, File file, _DownloadDisplay display) async {\n+    final bool isAllowedUrl = _allowedBaseUrls.any(\n+      (String baseUrl) => url.toString().startsWith(baseUrl),\n+    );\n+\n+    // In tests make this a hard failure.\n+    assert(\n+      isAllowedUrl,\n+      'URL not allowed: $url\\n'\n+      'Allowed URLs must be based on one of: ${_allowedBaseUrls.join(', ')}',\n+    );\n+\n+    // In production, issue a warning but allow the download to proceed.\n+    if (!isAllowedUrl) {\n+      display.pause();\n+      _logger.printWarning(\n+        'Downloading an artifact that may not be reachable in some environments (e.g. firewalled environments): $url\\n'\n+        'This should not have happened. This is likely a Flutter SDK bug. Please file an issue at https://github.com/flutter/flutter/issues/new?template=01_activation.yml',\n+      );\n+      display.resume();\n+    }\n+\n+    final HttpClientRequest request = await _httpClient.getUrl(url);\n+    final HttpClientResponse response = await request.close();\n+    if (response.statusCode != HttpStatus.ok) {\n+      throw Exception(response.statusCode);\n+    }\n+\n+    final String? md5Hash = _expectedMd5(response.headers);\n+    ByteConversionSink? inputSink;\n+    late StreamController<Digest> digests;\n+    if (md5Hash != null) {\n+      _logger.printTrace('Content $url md5 hash: $md5Hash');\n+      digests = StreamController<Digest>();\n+      inputSink = md5.startChunkedConversion(digests);\n+    }\n+    final int contentLength = response.contentLength;\n+    final RandomAccessFile randomAccessFile = file.openSync(mode: FileMode.writeOnly);\n+    await response.forEach((List<int> chunk) {\n+      inputSink?.add(chunk);\n+      randomAccessFile.writeFromSync(chunk);\n+      display.onChunk(chunk.length, contentLength);\n+    });\n+    randomAccessFile.closeSync();\n+    if (inputSink != null) {\n+      inputSink.close();\n+      final Digest digest = await digests.stream.last;\n+      final String rawDigest = base64.encode(digest.bytes);\n+      if (rawDigest != md5Hash) {\n+        throw Exception(\n+          'Expected $url to have md5 checksum $md5Hash, but was $rawDigest. This '\n+          'may indicate a problem with your connection to the Flutter backend servers. '\n+          'Please re-try the download after confirming that your network connection is '\n+          'stable.',\n+        );\n+      }\n+    }\n+  }\n+\n+  String? _expectedMd5(HttpHeaders httpHeaders) {\n+    final List<String>? values = httpHeaders['x-goog-hash'];\n+    if (values == null) {\n+      return null;\n+    }\n+    String? rawMd5Hash;\n+    for (final String value in values) {\n+      if (value.startsWith('md5=')) {\n+        rawMd5Hash = value;\n+        break;\n+      }\n+    }\n+    if (rawMd5Hash == null) {\n+      return null;\n+    }\n+    final List<String> segments = rawMd5Hash.split('md5=');\n+    if (segments.length < 2) {\n+      return null;\n+    }\n+    final String md5Hash = segments[1];\n+    if (md5Hash.isEmpty) {\n+      return null;\n+    }\n+    return md5Hash;\n+  }\n+\n+  /// Create a temporary file and add it to the [downloadedFiles].\n+  File _createDownloadFile(String name) {\n+    final File tempFile = _fileSystem.file(_fileSystem.path.join(_tempStorage.path, name));\n+    downloadedFiles.add(tempFile);\n+    return tempFile;\n+  }\n+\n+  /// Create the given [directory] and parents, as necessary.\n+  void _ensureExists(Directory directory) {\n+    if (!directory.existsSync()) {\n+      directory.createSync(recursive: true);\n+    }\n+  }\n+\n+  /// Clear any zip/gzip files downloaded.\n+  void removeDownloadedFiles() {\n+    for (final File file in downloadedFiles) {\n+      if (!file.existsSync()) {\n+        continue;\n+      }\n+      try {\n+        file.deleteSync();\n+      } on FileSystemException catch (e) {\n+        _logger.printWarning('Failed to delete \"${file.path}\". Please delete manually. $e');\n+        continue;\n+      }\n+      for (\n+        Directory directory = file.parent;\n+        directory.absolute.path != _tempStorage.absolute.path;\n+        directory = directory.parent\n+      ) {\n+        // Handle race condition when the directory is deleted before this step\n+        if (!directory.existsSync()) {\n+          break;\n+        }\n+        if (directory.listSync().isNotEmpty) {\n+          break;\n+        }\n+        _deleteIgnoringErrors(directory);\n+      }\n+    }\n+  }\n+\n+  static void _deleteIgnoringErrors(FileSystemEntity entity) {\n+    if (!entity.existsSync()) {\n+      return;\n+    }\n+    try {\n+      entity.deleteSync();\n+    } on FileSystemException {\n+      // Ignore errors.\n+    }\n+  }\n+}\n+\n+@visibleForTesting\n+String flattenNameSubdirs(Uri url, FileSystem fileSystem) {\n+  final pieces = <String>[url.host, ...url.pathSegments];\n+  final Iterable<String> convertedPieces = pieces.map<String>(_flattenNameNoSubdirs);\n+  return fileSystem.path.joinAll(convertedPieces);\n+}\n+\n+/// Given a name containing slashes, colons, and backslashes, expand it into\n+/// something that doesn't.\n+String _flattenNameNoSubdirs(String fileName) {\n+  final replacedCodeUnits = <int>[\n+    for (final int codeUnit in fileName.codeUnits)\n+      ..._flattenNameSubstitutions[codeUnit] ?? <int>[codeUnit],\n+  ];\n+  return String.fromCharCodes(replacedCodeUnits);\n+}\n+\n+// Many characters are problematic in filenames, especially on Windows.\n+final _flattenNameSubstitutions = <int, List<int>>{\n+  r'@'.codeUnitAt(0): '@@'.codeUnits,\n+  r'/'.codeUnitAt(0): '@s@'.codeUnits,\n+  r'\\'.codeUnitAt(0): '@bs@'.codeUnits,\n+  r':'.codeUnitAt(0): '@c@'.codeUnits,\n+  r'%'.codeUnitAt(0): '@per@'.codeUnits,\n+  r'*'.codeUnitAt(0): '@ast@'.codeUnits,\n+  r'<'.codeUnitAt(0): '@lt@'.codeUnits,\n+  r'>'.codeUnitAt(0): '@gt@'.codeUnits,\n+  r'\"'.codeUnitAt(0): '@q@'.codeUnits,\n+  r'|'.codeUnitAt(0): '@pip@'.codeUnits,\n+  r'?'.codeUnitAt(0): '@ques@'.codeUnits,\n+};\n+\n+/// Abstraction for displaying download progress.\n+///\n+/// Two implementations exist:\n+/// - [_ProgressBarDisplay]: ANSI progress bar for terminals with color support.\n+/// - [_SpinnerDisplay]: Spinner-based display via [Logger.startProgress].\n+abstract class _DownloadDisplay {\n+  /// Called when the download begins.\n+  void start();\n+\n+  /// Called when a chunk of data is received.\n+  void onChunk(int chunkSize, int contentLength);\n+\n+  /// Called when the download completes successfully.\n+  void finish();\n+\n+  /// Called when the download is cancelled or fails.\n+  void cancel();\n+\n+  /// Pauses the display (e.g. when another status message needs the terminal).\n+  void pause();\n+\n+  /// Resumes the display after a pause.\n+  void resume();\n+}\n+\n+/// Displays an ANSI progress bar with speed, ETA, and percentage.\n+class _ProgressBarDisplay extends _DownloadDisplay {\n+  _ProgressBarDisplay({required Stdio stdio, required this.statusMessage}) : _stdio = stdio;\n+\n+  static const int _maxTerminalWidth = 80;\n+  static const int _progressUpdateIntervalMs = 100;\n+\n+  final Stdio _stdio;\n+  final String statusMessage;\n+  final DownloadProgress _progress = DownloadProgress();\n+  final Stopwatch _stopwatch = Stopwatch();\n+  int _lastUpdateMs = 0;\n+\n+  int get _terminalWidth =>\n+      (_stdio.terminalColumns ?? _maxTerminalWidth).clamp(0, _maxTerminalWidth);\n+\n+  @override\n+  void start() {\n+    _stopwatch.start();\n+    _stdio.stdoutWrite('$statusMessage\\n');\n+  }\n+\n+  @override\n+  void onChunk(int chunkSize, int contentLength) {\n+    if (_progress.totalBytes < 0) {\n+      _progress.totalBytes = contentLength;\n+    }\n+    _progress.addBytesReceived(chunkSize);\n+    final int currentMs = _stopwatch.elapsedMilliseconds;\n+    if (currentMs >= _lastUpdateMs + _progressUpdateIntervalMs) {\n+      _lastUpdateMs = currentMs;\n+      final String line = _progress.formatProgressLine(\n+        elapsed: _stopwatch.elapsed,\n+        terminalWidth: _terminalWidth,\n+      );\n+      _stdio.stdoutWrite('${AnsiTerminal.clearAndReturnCode}$line');\n+    }\n+  }\n+\n+  void _stopAndClear() {\n+    _stopwatch.stop();\n+    _stdio.stdoutWrite(\n+      '${AnsiTerminal.clearAndReturnCode}'\n+      '${AnsiTerminal.cursorUpLineCode}'\n+      '${AnsiTerminal.clearAndReturnCode}',\n+    );\n+  }\n+\n+  @override\n+  void finish() {\n+    _stopAndClear();\n+    final String summary = _progress.formatCompletionSummary(_stopwatch.elapsed);\n+    final int padding = _terminalWidth - statusMessage.length - summary.length;\n+    final line = '$statusMessage${' ' * max(1, padding)}$summary';\n+    _stdio.stdoutWrite('$line\\n');\n+  }\n+\n+  @override\n+  void cancel() {\n+    _stopAndClear();\n+  }\n+\n+  @override\n+  void pause() {}\n+\n+  @override\n+  void resume() {}\n+}\n+\n+/// Displays a spinner via [Logger.startProgress].\n+class _SpinnerDisplay extends _DownloadDisplay {\n+  _SpinnerDisplay({required Logger logger, required String statusMessage})\n+    : _logger = logger,\n+      _statusMessage = statusMessage;\n+\n+  final Logger _logger;\n+  final String _statusMessage;\n+  Status? _status;\n+\n+  @override\n+  void start() {\n+    _status = _logger.startProgress(_statusMessage);\n+  }\n+\n+  @override\n+  void onChunk(int chunkSize, int contentLength) {}\n+\n+  @override\n+  void finish() {\n+    _status?.stop();\n+  }\n+\n+  @override\n+  void cancel() {\n+    _status?.stop();\n+  }\n+\n+  @override\n+  void pause() {\n+    _status?.pause();\n+  }\n+\n+  @override\n+  void resume() {\n+    _status?.resume();\n+  }\n+}\n+\n+/// Tracks download progress and provides formatted display strings.\n+@visibleForTesting\n+class DownloadProgress {\n+  /// Total expected bytes, or -1 if unknown.\n+  int totalBytes = -1;\n+\n+  int _bytesReceived = 0;\n+  int get bytesReceived => _bytesReceived;\n+\n+  void addBytesReceived(int bytes) {\n+    _bytesReceived += bytes;\n+  }\n+\n+  bool get hasKnownSize => totalBytes > 0;\n+\n+  double get fractionReceived => hasKnownSize ? (_bytesReceived / totalBytes).clamp(0.0, 1.0) : 0.0;\n+\n+  int get percentReceived => (fractionReceived * 100).round();\n+\n+  /// Download speed in bytes per second.\n+  double speedBytesPerSecond(Duration elapsed) {\n+    if (elapsed.inMilliseconds == 0) {\n+      return 0;\n+    }\n+    return _bytesReceived * 1000 / elapsed.inMilliseconds;\n+  }\n+\n+  /// Estimated time remaining.\n+  Duration? timeRemaining(Duration elapsed) {\n+    final double speed = speedBytesPerSecond(elapsed);\n+    if (!hasKnownSize || speed == 0) {\n+      return null;\n+    }\n+    final int totalRemainingBytes = totalBytes - _bytesReceived;\n+    return Duration(milliseconds: (totalRemainingBytes * 1000 / speed).round());\n+  }\n+\n+  static const _subBlocks = ['▏', '▎', '▍', '▌', '▋', '▊', '▉'];\n+\n+  /// Renders a progress bar with sub-character precision.\n+  ///\n+  /// Uses 1/8-block characters for a smooth fill edge.\n+  String renderProgressBar(int width) {\n+    if (!hasKnownSize || width <= 0) {\n+      return '';\n+    }\n+    final int totalEighths = (fractionReceived * width * 8).round();\n+    final int fullBlocks = totalEighths ~/ 8;\n+    final int remainder = totalEighths % 8;\n+    final int emptyBlocks = width - fullBlocks - 1;\n+    final String filled = '█' * fullBlocks;\n+    final String partial = remainder > 0 ? _subBlocks[remainder - 1] : ' ';\n+    final String empty = ' ' * emptyBlocks;\n+    return '$filled$partial$empty';\n+  }\n+\n+  /// Formats download speed as a human-readable string.\n+  String formatSpeed(Duration elapsed) {\n+    return '${getSizeAsPlatformMB(speedBytesPerSecond(elapsed).round())}/s';\n+  }\n+\n+  /// Formats bytes received and total.\n+  String formatBytes() {\n+    if (hasKnownSize) {\n+      return '${getSizeAsPlatformMB(_bytesReceived)}'\n+          '/${getSizeAsPlatformMB(totalBytes)}';\n+    }\n+    return getSizeAsPlatformMB(_bytesReceived);\n+  }\n+\n+  /// Formats estimated time remaining.\n+  String formatRemaining(Duration elapsed) {\n+    final Duration? rem = timeRemaining(elapsed);\n+    if (rem == null) {\n+      return '';\n+    }\n+    return 'ETA ${getElapsedAsSeconds(rem)}';\n+  }\n+\n+  /// Formats the full progress line for terminal display.\n+  String formatProgressLine({required Duration elapsed, required int terminalWidth}) {\n+    final String indent = ' ' * 5;\n+    final percentReceivedStr = hasKnownSize ? '${percentReceived.toString().padLeft(3)}%' : '';\n+    final String bytesStr = formatBytes();\n+    final String speedStr = formatSpeed(elapsed);\n+    final String etaStr = formatRemaining(elapsed);\n+\n+    final parts = <String>[percentReceivedStr, bytesStr, speedStr, etaStr];\n+    final String info = parts.where((String s) => s.isNotEmpty).join('  ');\n+\n+    // The progress bar is 28 characters wide and terminated on either side by\n+    // thin vertical lines which take up another 2 characters. 28 characters was\n+    // chosen empirically to make the progress bar take up enough space to look\n+    // good while leaving enough space for the detailed info under \"normal\"\n+    // conditions (artifact size <1GB, download speed >1MB/s).\n+    const barInner = 28;\n+    const int barTotal = barInner + 2; // ▕ + bar + ▏\n+    final String line;\n+\n+    // Only show the progress bar if we have enough room to show it along with\n+    // the info, otherwise just show the info right-aligned.\n+    if (hasKnownSize && terminalWidth >= indent.length + barTotal + info.length) {\n+      final String bar = renderProgressBar(barInner);\n+      final int padding = terminalWidth - indent.length - barTotal - info.length;\n+      line = '$indent▕$bar▏${' ' * padding}$info';\n+    } else {\n+      final int padding = terminalWidth - indent.length - info.length;\n+      final unclipped = '$indent${' ' * max(0, padding)}$info';\n+      line = unclipped.length <= terminalWidth ? unclipped : unclipped.substring(0, terminalWidth);\n+    }\n+    return line;\n+  }\n+\n+  /// Formats the completion summary like `(21.1MB in 5.0s)`.\n+  String formatCompletionSummary(Duration elapsed) {\n+    final String size = getSizeAsPlatformMB(_bytesReceived);\n+    final String time = getElapsedAsSeconds(elapsed);\n+    return '($size in $time)';\n+  }\n+}\ndiff --git a/packages/flutter_tools/lib/src/windows/visual_studio.dart b/packages/flutter_tools/lib/src/windows/visual_studio.dart\nindex 2edeca77dc9bace3712d03acb6fde98d2d3c5473df1f9d1e8d2b86fc2fdabad1..8cb3c92a52b3d0ea2c5fc5a6f7fc2c92db5362ee8af211b51244f33e9fe8aa7c\n--- a/packages/flutter_tools/lib/src/windows/visual_studio.dart\n+++ b/packages/flutter_tools/lib/src/windows/visual_studio.dart\n@@ -159,21 +159,36 @@\n-  /// The path to CMake, or null if no Visual Studio installation has\n-  /// the components necessary to build.\n+  /// 受控准备器已验真固定归档；这里只接受准确入口并检查原VS生成器能力。\n   String? get cmakePath {\n     final VswhereDetails? details = _bestVisualStudioDetails;\n     if (details == null || !details.isUsable || details.installationPath == null) {\n       return null;\n     }\n-\n-    return _fileSystem.path.joinAll(<String>[\n-      details.installationPath!,\n-      'Common7',\n-      'IDE',\n-      'CommonExtensions',\n-      'Microsoft',\n-      'CMake',\n-      'CMake',\n-      'bin',\n-      'cmake.exe',\n-    ]);\n+    final String? command = _platform.environment['CMAKE_COMMAND'];\n+    if (command == null || !_fileSystem.path.isAbsolute(command) ||\n+        RegExp(r'[\\x00-\\x1f]').hasMatch(command) ||\n+        _fileSystem.path.basename(command) != 'cmake.exe' ||\n+        _fileSystem.typeSync(command, followLinks: false) != FileSystemEntityType.file ||\n+        _fileSystem.file(command).resolveSymbolicLinksSync() != command) {\n+      throwToolExit('Windows编译缺少验真的受控CMAKE_COMMAND绝对入口。');\n+    }\n+    // 不改变VS编译器或生成器；不支持的组合在产品编译前明确拒绝。\n+    final RunResult result = _processUtils.runSync(<String>[command, '-E', 'capabilities']);\n+    if (result.exitCode != 0) {\n+      throwToolExit('受控CMake能力读取失败。');\n+    }\n+    Object? capabilities;\n+    try {\n+      capabilities = json.decode(result.stdout);\n+    } on FormatException {\n+      throwToolExit('受控CMake能力输出无效。');\n+    }\n+    if (capabilities is! Map<String, dynamic> ||\n+        capabilities['generators'] is! List<dynamic> ||\n+        !(capabilities['generators'] as List<dynamic>).any(\n+          (dynamic generator) => generator is Map<String, dynamic> &&\n+              generator['name'] == cmakeGenerator,\n+        )) {\n+      throwToolExit('受控CMake不支持当前Visual Studio生成器：$cmakeGenerator。');\n+    }\n+    return command;\n   }\n-\n+\n@@ -312,2 +327,0 @@\n-      // CMake\n-      'Microsoft.VisualStudio.Component.VC.CMake.Project': 'C++ CMake tools for Windows',\ndiff --git a/packages/flutter_tools/lib/src/isolated/native_assets/macos/native_assets_host.dart b/packages/flutter_tools/lib/src/isolated/native_assets/macos/native_assets_host.dart\nindex a7e4310dc61574a1e03b6b25bc104a5bd55c0de824131255c779feeb66d36ee0..6f2ceb11402e01e33b030a0516f3865b817a2b9e44cc5009a1e76a1420e584dd\n--- a/packages/flutter_tools/lib/src/isolated/native_assets/macos/native_assets_host.dart\n+++ b/packages/flutter_tools/lib/src/isolated/native_assets/macos/native_assets_host.dart\n@@ -66,7 +66,8 @@\n /// ios device or macos arm64.\n Future<void> lipoDylibs(File target, List<File> sources) async {\n   final RunResult lipoResult = await globals.processUtils.run(<String>[\n-    'xcrun',\n+    // 固定Apple定位入口在每次交付前验真，不能从PATH选取副本。\n+    '/usr/bin/xcrun',\n     'lipo',\n     '-create',\n     '-output',\n@@ -96,7 +97,8 @@\n   Map<String, String> oldToNewInstallNames,\n ) async {\n   final RunResult setInstallNamesResult = await globals.processUtils.run(<String>[\n-    'xcrun',\n+    // 固定Apple定位入口在每次交付前验真，不能从PATH选取副本。\n+    '/usr/bin/xcrun',\n     'install_name_tool',\n     '-id',\n     newInstallName,\n@@ -119,7 +121,8 @@\n \n Future<Set<String>> getInstallNamesDylib(File dylibFile) async {\n   final RunResult installNameResult = await globals.processUtils.run(<String>[\n-    'xcrun',\n+    // 固定Apple定位入口在每次交付前验真，不能从PATH选取副本。\n+    '/usr/bin/xcrun',\n     'otool',\n     '-D',\n     dylibFile.path,\n@@ -141,7 +144,8 @@\n /// Creates a dSYM bundle for a dylib.\n Future<void> dsymutilDylib(File dylibFile, String dsymPath) async {\n   final RunResult result = await globals.processUtils.run(<String>[\n-    'xcrun',\n+    // 固定Apple定位入口在每次交付前验真，不能从PATH选取副本。\n+    '/usr/bin/xcrun',\n     'dsymutil',\n     dylibFile.path,\n     '-o',\n@@ -157,7 +161,8 @@\n /// This is useful for release builds to reduce binary size.\n Future<void> stripDylib(File dylibFile) async {\n   final RunResult result = await globals.processUtils.run(<String>[\n-    'xcrun',\n+    // 固定Apple定位入口在每次交付前验真，不能从PATH选取副本。\n+    '/usr/bin/xcrun',\n     'strip',\n     '-x', // Remove local symbols.\n     '-S', // Remove debugging symbol table.\n@@ -179,7 +184,8 @@\n     codesignIdentity = '-';\n   }\n   final codesignCommand = <String>[\n-    'xcrun',\n+    // 固定Apple定位入口在每次交付前验真，不能从PATH选取副本。\n+    '/usr/bin/xcrun',\n     'codesign',\n     '--force',\n     '--sign',\n@@ -221,7 +227,8 @@\n /// Invokes `xcrun --find` to find the full path to [binaryName].\n Future<Uri?> _findXcrunBinary(String binaryName, bool throwIfNotFound) async {\n   final RunResult xcrunResult = await globals.processUtils.run(<String>[\n-    'xcrun',\n+    // 固定Apple定位入口在每次交付前验真，不能从PATH选取副本。\n+    '/usr/bin/xcrun',\n     '--find',\n     binaryName,\n   ]);\n";
const parserDefinitions={"yaml":{"name":"yaml","version":"2.8.3","url":"https://registry.npmjs.org/yaml/-/yaml-2.8.3.tgz","sha256":"9539805d7447def2bed5c5b4acacc283362c5e80abc5d93472b2f35f0cbf85ad","integrity":"sha512-AvbaCLOO2Otw/lW5bmh9d/WEdcDFdQp2Z2ZUH3pX9U2ihyUY0nvLv7J6TrWowklRGPYbB/IuIMfYgxaCPg5Bpg=="},"toml":{"name":"smol-toml","version":"1.4.2","url":"https://registry.npmjs.org/smol-toml/-/smol-toml-1.4.2.tgz","sha256":"829eee8dc90490d9671554b5cfd075976b61195221576ef8adec9732d3a94fef","integrity":"sha512-rInDH6lCNiEyn3+hH8KVGFdbjc099j47+OSgbMrfDYX1CmXLfdKd7qi6IfcWj2wFxvSVkuI46M+wPGYfEOEj6g=="}};
const cleanEnvironment=environment=>Object.fromEntries(['HOME','USER','LOGNAME','LANG','LC_ALL'].filter(k=>typeof environment[k]==='string').map(k=>[k,environment[k]]));
// Android SDK/NDK组件由既有组件配方准备，不能当作独立归档工具生成缓存键。
const androidSdkToolIds=new Set(['android','android-sdk','android-ndk']);
const isAndroidSdkComponent=tool=>androidSdkToolIds.has(tool?.id);
function toolArchive(tool){if(tool?.archive)return tool.archive;if(tool?.id==='cmake'&&tool.archives?.macos)return {...tool.archives.macos,kind:'extract',executable:'bin/cmake'};return null;}


async function installedToolObject(directory,tool){
 const path=join(directory,'payload',toolArchive(tool).executable);
 if(!await stat(path))return null;
 return {path,version:tool.version};
}
const directoryCheck=path=>directory(path);
// 基础工具的正式PATH投影排除发行件旧Shell/grep/sed；自举仅限本产品已声明GNU三工具。
async function productFoundation(library,lookup,{bootstrap=false,id}={}){
 if(library.gateLinuxFoundation)return library.gateLinuxFoundation;
 const base=await posixRecipe.controlledPosixTools(library,lookup);if(bootstrap){if(!['bash','grep','sed'].includes(id))fail('自举仅限GNU三工具');return {...base,path:base.bin};}
 const tools={...base.tools},paths=[];for(const name of ['bash','grep','sed']){const tool=library.tools.find(x=>x.id===name),value=tool&&await lookup(library,tool);if(!value)fail('GNU闭包缺失：'+name);tools[name]=value.path;paths.push(dirname(value.path));}tools.sh=tools.bash;delete tools.egrep;delete tools.fgrep;
 const view=join(library.work,'resource-tools');await directory(view,true);const shell=join(view,'sh');if(await stat(shell)){if(!((await lstat(shell)).isSymbolicLink())||await realpath(shell)!==tools.sh)fail('GNU sh交付漂移');}else await symlink(tools.sh,shell);for(const [name,path]of Object.entries(base.tools)){if(['sh','bash','grep','sed','egrep','fgrep'].includes(name))continue;const link=join(view,name);if(await stat(link)){if(!((await lstat(link)).isSymbolicLink())||await realpath(link)!==path)fail('基础交付漂移');}else await symlink(path,link);}return {tools,bin:view,path:[...paths,view].join(':')};
}
async function prepareSourceDependencies({library,tool,pending,signal,fetcher,options={}}){const result=new Map();for(const entry of tool.dependencies||[])result.set(entry.name,await acquireArchive(entry,{toolId:tool.id,work:library.work,store:join(library.root,'archives'),offline:options.offline,signal,fetcher}));return result;}

// 跨卷原件先在所属target中同目标卷的临时目录复制验真；长复制不持提交锁。
async function candidateOnTargetVolume(pending,target,{signal}={}){
 if((await lstat(pending)).dev===(await lstat(dirname(target))).dev)return {pending,dispose:async()=>{}};
 const boundary=join(root,'target');if(!inside(boundary,pending))fail('跨卷候选不在本产品target');
 let parent=dirname(pending);const volume=(await lstat(dirname(target))).dev;
 while(parent!==boundary&&(await lstat(parent)).dev!==volume)parent=dirname(parent);
 if((await lstat(parent)).dev!==volume)fail('target内没有目标卷临时目录');
 const stage=await fixedScratch(join(parent,'.resource-transfer-')),copy=join(stage,'candidate');
 try{signal?.throwIfAborted();await cp(pending,copy,{recursive:true,force:false,errorOnExist:true,verbatimSymlinks:true});
 return {pending:copy,dispose:async()=>{await permissions(stage,true);await rm(stage,{recursive:true});}};
 }catch(error){await permissions(stage,true);await rm(stage,{recursive:true});throw error;}
}
async function commitCandidate(pending,target,{signal}={}){


 const transfer=await candidateOnTargetVolume(pending,target,{signal});pending=transfer.pending;
 try{
 // 下载与编译已完成后才取得短锁；等待可取消，已有对象永不覆盖。
 const lock=target+'.lock';let handle;for(let n=0;n<500;n++){signal?.throwIfAborted();try{handle=await open(lock,'wx',0o600);break;}catch(e){if(e.code!=='EEXIST')throw e;await new Promise(r=>setTimeout(r,20));}}if(!handle)fail('原件提交锁等待超限');
 try{signal?.throwIfAborted();if(await stat(target)){}else {
   // macOS跨父目录重命名会修改目录自身的父链接；仅临时开放候选根的owner写权限。
   // 文件和子目录保持只读，提交短锁在恢复原模式后才释放。
   const info=await lstat(pending),mode=info.mode&0o777;
   const writableRoot=process.platform==='darwin'&&info.isDirectory()&&!(mode&0o200);
   if(writableRoot)await chmod(pending,mode|0o200);
   let renamed=false;
   try{await rename(pending,target);renamed=true;}
   finally{if(writableRoot)await chmod(renamed?target:pending,mode);}
  }}finally{await handle.close();await rm(lock);}
 }finally{await transfer.dispose();}
}
// 准备产物身份与使用验收由本产品定义，供应端不解释组件布局。




// 宿主发行件只请求本产品实际使用的五个组件；原归档缺少任一必需项仍失败，不能静默过滤。
function rustHostComponentPlan(text){
 if(typeof text!=='string'||Buffer.byteLength(text)>65536)fail('Rust组件清单超限或无效');
 const available=text.trimEnd().split(/\r?\n/u);
 if(!available.length||available.some(name=>! /^[a-z0-9]+(?:-[a-z0-9]+)*$/u.test(name))||new Set(available).size!==available.length)fail('Rust组件清单格式无效');
 const required=['rustc','cargo','rust-std-aarch64-apple-darwin','rustfmt-preview','clippy-preview'];
 for(const name of required)if(!available.includes(name))fail('Rust宿主缺少必需组件：'+name);
 return required;
}
async function installRustTool({source,payload,tool,canonical,library,foundation,environment,options},{run=exec,acquire=acquireArchive,extract=unpack}={}){
 options.signal?.throwIfAborted();const manifest=join(source,'components');await regular(manifest);
 if((await lstat(manifest)).size>65536)fail('Rust组件清单超限或无效');
 const components=rustHostComponentPlan(new TextDecoder('utf-8',{fatal:true}).decode(await readFile(manifest)));
 await run(foundation.tools.bash,[join(source,'install.sh'),'--prefix='+payload,'--disable-ldconfig','--components='+components.join(',')],{signal:options.signal,env:environment,maxBuffer:2*1024**2,timeout:300000});
 // 五个目标标准库仍按既有声明逐个获取、展开和安装；失败/取消立即中止，外层负责原候选清场。
 for(const component of tool.components||[]){
  options.signal?.throwIfAborted();const file=await acquire(component,{toolId:tool.id,work:library.work,store:join(library.root,'archives'),offline:options.offline,fetcher:options.fetcher,signal:options.signal}),dir=join(canonical,component.target);
  await extract(file,dir,{foundation,signal:options.signal});
  await run(foundation.tools.bash,[join(dir,component.root,'install.sh'),'--prefix='+payload,'--disable-ldconfig'],{signal:options.signal,env:environment,maxBuffer:2*1024**2,timeout:300000});
 }
}

async function installTool(library,tool,options,visiting=new Set()){


 if(library.installed.has(tool.id))return library.installed.get(tool.id);if(visiting.has(tool.id))fail('工具声明循环：'+tool.id);visiting=new Set([...visiting,tool.id]);const archive=toolArchive(tool);
 if(tool.id==='xcode'){const apple=await appleTools(library,{environment:cleanEnvironment(options.environment),signal:options.signal});const value={path:apple.tools.xcodebuild,version:tool.version};library.installed.set(tool.id,value);return value;}
 if(!archive)fail('工具归档未声明：'+tool.id);const shared=join(library.root,'shared');await directory(shared,true);const names=await readdir(shared),existing=[archive.sha256,...names.filter(name=>name.startsWith(archive.sha256+'-'))].find(name=>existsSync(join(shared,name,'payload',archive.executable)));const target=join(shared,existing||archive.sha256);const lookup=p=>installedToolObject(p,tool,{produced:true});let value=await lookup(target);
 if(!value&&options.optionalTools&&await stat(options.optionalTools)){await directory(options.optionalTools);value=await installedToolObject(join(options.optionalTools,'shared',archive.sha256),tool);}
 if(!value&&tool.id==='cmake'&&options.optionalTools&&await stat(join(options.optionalTools,'shared/android'))){await installAndroidResources({...options,library,offline:true});value=library.installed.get('cmake');}
 for(const id of tool.requires||[]){const entry=library.tools.find(x=>x.id===id);if(!entry)fail('前置工具未声明：'+id);await installTool(library,entry,options,visiting);}
 if(value){library.installed.set(tool.id,value);return value;}if(options.offline)fail('离线缺少工具：'+tool.id);
 // Node用内置解包形成最小宿主，POSIX用固定签名输入；其余工具只能使用完成GNU接管的基础工具。
 let foundation;if(!['node','posix'].includes(tool.id)){for(const id of ['posix',...(['bash','grep','sed'].includes(tool.id)?[]:['bash','grep','sed'])]){if(visiting.has(id))fail('工具自举循环');await installTool(library,library.tools.find(x=>x.id===id),options,visiting);}foundation=await productFoundation(library,async(_,t)=>library.installed.get(t.id),{bootstrap:['bash','grep','sed'].includes(tool.id),id:tool.id});}
 const pending=await fixedScratch(join(await resourceWork(library.work),'.'+archive.sha256+'-'));const canonical=join(pending,'library/shared',archive.sha256+'.pending'),payload=join(canonical,'payload');const localLibrary={...library,pending:canonical,finalPayload:options.finalPayload||join(target,'payload')};await directory(canonical,true);const original=join(canonical,'archive');
 try{
  let source;if(archive.kind==='apple-posix'){await appleTools(library,{names:['codesign'],environment:cleanEnvironment(options.environment),signal:options.signal});await posixRecipe.buildPosixTool({tool,payload,bootstrap:true,run:exec,signal:options.signal});source=payload;}
  else{const file=await acquireArchive(archive,{toolId:tool.id,work:library.work,store:join(library.root,'archives'),offline:options.offline,fetcher:options.fetcher,signal:options.signal});await copyFile(file,original);if(['gem','binary','phar'].includes(archive.kind))source=original;else {const unpacked=join(canonical,'unpack');await unpack(original,unpacked,{foundation,signal:options.signal});source=archive.root==='.'?unpacked:join(unpacked,archive.root);await directory(source);}}
  const environment={...cleanEnvironment(options.environment),HOME:canonical,TMPDIR:canonical,PATH:foundation?.path||'',PRODUCT_WORK_DIR:canonical};
  const lookupInstalled=async(_,t)=>library.installed.get(t.id)||null;
  if(['native-source','gem'].includes(archive.kind))await sourceRecipe.buildSourceTool({library:localLibrary,tool,source,archive:original,pending:canonical,payload,finalPayload:localLibrary.finalPayload,signal:options.signal,fetcher:options.fetcher,exec,lookup:lookupInstalled,apple:appleTools,bootstrap:['bash','grep','sed'].includes(tool.id),environment,prepare:input=>prepareSourceDependencies({...input,options}),download:(entry,target,context)=>downloadTool(entry,target,{...context,...options,toolId:tool.id,work:library.work,store:join(library.root,'archives')})});
  else if(['binary','phar'].includes(archive.kind)){await mkdir(dirname(join(payload,archive.executable)),{recursive:true});await copyFile(original,join(payload,archive.executable));await chmod(join(payload,archive.executable),0o555);}
  else if(archive.kind==='rust'){
   await installRustTool({source,payload,tool,canonical,library,foundation,environment,options});
  }else if(archive.kind==='cargo-source'){
   await directory(payload,true);const rust=library.installed.get('rust').path,apple=await appleTools(library,{names:['clang','ar'],environment:cleanEnvironment(options.environment),signal:options.signal}),work=join(canonical,'cargo');await directory(work,true);
   const deps=await prepareCargo([join(source,'Cargo.lock')],work,{...options,library});await exec(join(dirname(rust),'cargo'),['build','--manifest-path',join(source,'Cargo.toml'),'--release','--locked','--offline','--bin',tool.command],{cwd:work,signal:options.signal,timeout:1800000,maxBuffer:8*1024**2,env:{...environment,PATH:dirname(rust)+':'+environment.PATH,RUSTC:rust,CC:apple.tools.clang,AR:apple.tools.ar,DEVELOPER_DIR:apple.developerDirectory,CARGO_HOME:deps.cargoHome,CARGO_TARGET_DIR:join(work,'target')}});await mkdir(join(payload,'bin'));await copyFile(join(work,'target/release',tool.command),join(payload,archive.executable));await copyFile(original,join(payload,'source.crate'));
  }else if(archive.kind!=='apple-posix')await rename(source,payload);
  if(tool.id==='pnpm')await symlink('pnpm.cjs',join(payload,'bin/pnpm'));
  if(tool.id==='flutter'){const dart=join(payload,'bin/cache/dart-sdk/bin/dart');await preparePub([join(payload,'packages/flutter_tools/pubspec.lock')],join(payload,'bin/cache/pub'),{...options,library,dart});environment.PATH=dirname(library.installed.get('node').path)+':'+foundation.path;await flutterRecipe.prepareFlutter(payload,{tool,files:flutterRecipe.parsePatch(flutterPatch),env:environment,signal:options.signal});}
  if(tool.id==='java')environment.JAVA_HOME=dirname(dirname(join(payload,archive.executable)));if(tool.id==='gradle')environment.JAVA_HOME=dirname(dirname(library.installed.get('java').path));if(tool.id==='python')environment.PYTHONHOME=payload;

  await permissions(payload,false);
  if(tool.id==='flutter'){await chmod(join(payload,'bin/cache/lockfile'),0o600);await chmod(join(payload,'packages/flutter_tools/gradle'),0o755);}
  options.signal?.throwIfAborted();await commitCandidate(canonical,target,{signal:options.signal});value=await lookup(target);library.installed.set(tool.id,value);return value;
 }finally{if(await stat(pending)){await permissions(pending,true);await rm(pending,{recursive:true});}}
}
async function parser(kind,options){
 const entry=parserDefinitions[kind],work=await resourceWork(options.library.work),parserRoot=join(work,'parsers',hash(JSON.stringify(entry))),payload=join(parserRoot,'payload');
 await directoryCheck(options.library.root);await directoryCheck(options.library.work);
 if(!await stat(payload)){
  if(await stat(parserRoot))fail('本轮解析器现场不完整');
  const file=await acquireArchive(entry,{toolId:'parser',work:options.library.work,store:join(options.library.root,'archives'),offline:options.offline,fetcher:options.fetcher,signal:options.signal});
  await directory(parserRoot,true);
  try{await extractArchive(file,payload,{prefix:'package',signal:options.signal});}
  catch(error){await rm(parserRoot,{recursive:true,force:true});throw error;}
 }
 const mod=createRequire(import.meta.url)(payload);if(kind==='yaml')return text=>mod.parse(text,{uniqueKeys:true});const parse=text=>mod.parse(text);parse.stringify=mod.stringify;return parse;
}
async function checkedLock(path){await regular(path);const s=await lstat(path);if(s.size>32*1024**2)fail('锁文件超限');return readFile(path,'utf8');}
async function packageOriginal(entry,options){return acquireArchive(entry,{work:options.library.work,store:join(options.dependencyRoot||join(options.library.root,'..','rely'),'archives'),offline:options.offline,fetcher:options.fetcher,signal:options.signal});}
async function prepareNpm(locks,work,options){const cache=join(work,'npm');await directory(cache,true);const node=options.library.installed.get('node').path,require=createRequire(join(dirname(node),'../lib/node_modules/npm/bin/npm-cli.js')),cacache=require('cacache');for(const lock of locks){const document=JSON.parse(await checkedLock(lock));if(![2,3].includes(document.lockfileVersion)||!document.packages)fail('npm原始锁格式无效');for(const [path,entry]of Object.entries(document.packages)){if(!path||entry.link)continue;if(!entry.resolved||!entry.integrity||!entry.version)fail('npm包未锁定来源');const file=await packageOriginal({url:entry.resolved,integrity:entry.integrity},options);await cacache.put(join(cache,'_cacache'),'make-fetch-happen:request-cache:'+entry.resolved,await readFile(file),{integrity:entry.integrity,metadata:{time:Date.now(),url:entry.resolved,reqHeaders:{},resHeaders:{'content-type':'application/octet-stream'}}});}}return {npmCache:cache};}

// Pub读取的内容摘要必须是准确64位十六进制文本，不能附加换行或其它字节。
async function materializePubArchive(entry,cache,{signal}={}){
 signal?.throwIfAborted();if(!safePath(entry.name)||entry.name.includes('/')||!/^[a-f0-9]{64}$/u.test(entry.sha256))fail('Pub归档坐标无效');
 await regular(entry.file);
 const target=join(cache,'hosted/pub.dev',entry.name),proof=join(cache,'hosted-hashes/pub.dev',entry.name+'.sha256');
 await directory(dirname(target),true);await directory(dirname(proof),true);
 if(await stat(target)){await directory(target);return target;}
 if(await stat(proof))fail('Pub摘要存在但包目录缺失');
 await extractArchive(entry.file,target,{signal});
 try{signal?.throwIfAborted();await writeFile(proof,entry.sha256,{flag:'wx'});return target;}
 catch(error){await rm(target,{recursive:true});throw error;}
}

async function preparePub(locks,cache,options){await directory(cache,true);const parse=await parser('yaml',options),files=[];for(const lock of locks){const d=parse(await checkedLock(lock));if(!d.packages)fail('Pub锁格式无效');for(const [name,entry]of Object.entries(d.packages)){if(['sdk','path'].includes(entry.source))continue;if(entry.source==='git'){const d=entry.description;if(!d||d.ref!==d['resolved-ref']||!options.sources?.some(x=>x.name===name&&x.url===d.url&&x.ref===d.ref))fail('Pub Git来源不属于产品固定闭包：'+name);continue;}if(entry.source!=='hosted'||entry.description?.name!==name||!['https://pub.dev','https://pub.dev/'].includes(entry.description.url)||!entry.description.sha256)fail('Pub来源未锁定');const coordinate={url:'https://pub.dev/api/archives/'+name+'-'+entry.version+'.tar.gz',sha256:entry.description.sha256};process.stderr.write('资源阶段：Pub '+name+'@'+entry.version+'\n');const original=await packageOriginal(coordinate,options).catch(error=>{throw Error('Pub原件获取失败：'+name+'@'+entry.version+'：'+error.message);});files.push({name:name+'-'+entry.version,sha256:coordinate.sha256,file:original});}}
 for(const entry of files)await materializePubArchive(entry,cache,{signal:options.signal});
 await directory(join(cache,'_temp'),true);return {pubCache:cache};}
function gitCoordinate(source){const u=new URL(source.replace(/^git\+/u,''));const ref=u.searchParams.get('rev');if(u.protocol!=='https:'||u.hostname!=='github.com'||u.username||u.password||!u.pathname.endsWith('.git')||!/^[a-f0-9]{40}$/u.test(ref||'')||u.hash!=='#'+ref||[...u.searchParams.keys()].length!==1)fail('Git来源不是唯一锁定提交');return {url:u.origin+u.pathname,ref};}
async function gitCheckout(source,target,options){
 const git=options.library.installed.get('git')?.path;if(!git||!/^[a-f0-9]{40}$/u.test(source.ref||''))fail('Git未验真或来源没有固定提交');checkedURL(source.url);
 const environment={...cleanEnvironment(options.environment),PATH:(await productFoundation(options.library,async(_,t)=>options.library.installed.get(t.id))).path,GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:'/dev/null',GIT_TERMINAL_PROMPT:'0',HOME:options.library.work};
 const run=args=>exec(git,['-c','credential.helper=','-c','core.hooksPath=/dev/null','-c','protocol.file.allow=always',...args],{signal:options.signal,env:environment,maxBuffer:16*1024**2,timeout:600000});
 if(await stat(target)){
  await directory(target);await directory(join(target,'.git'));
  const head=await run(['-C',target,'rev-parse','HEAD']),origin=await run(['-C',target,'remote','get-url','origin']);
  const dirty=await run(['-C',target,'status','--porcelain','--untracked-files=all']);
  if(head.stdout.trim()!==source.ref||origin.stdout.trim()!==source.url||dirty.stdout.trim())fail('本轮Git来源与声明或干净状态不符');
  return target;
 }
 // Git bundle只在当前任务使用，来源仍由固定提交闭合。
 const bundle=gitBundlePath(source,options.dependencyRoot);await directory(dirname(bundle),true);
 if(!await stat(bundle)){const candidate=await fixedScratch(join(await resourceWork(options.library.work),'.git-'));try{const file=join(candidate,'source.bundle');

   if(options.offline&&!source.local_root)fail('离线缺少Git提交');
   let origin=source.url;if(source.local_root){const selection=checkedSdkSelection({schema:1,product_id:product,mode:'local',sources:options.sources});const selected=selection.sources.find(item=>item.name===source.name);if(!selected||selected.ref!==source.ref)fail('本机SDK选择记录不符');await directory(selected.local_root);await directory(join(selected.local_root,'.git'));if((await realpath(selected.local_root))!==selected.local_root||(await realpath(join(selected.local_root,'.git')))!==join(selected.local_root,'.git')||(await run(['-C',selected.local_root,'rev-parse','--absolute-git-dir'])).stdout.trim()!==join(selected.local_root,'.git')||resolve(selected.local_root,(await run(['-C',selected.local_root,'rev-parse','--git-common-dir'])).stdout.trim())!==join(selected.local_root,'.git')||(await run(['-C',selected.local_root,'remote','get-url','origin'])).stdout.trim()!==source.url)fail('本机SDK来源漂移');origin=selected.local_root;}
   const checkout=join(candidate,'repository');await mkdir(checkout);await run(['init','--quiet',checkout]);await run(['-C',checkout,'fetch','--no-tags',origin,source.ref]);await run(['-C',checkout,'update-ref','refs/heads/locked',source.ref]);await run(['-C',checkout,'bundle','create',file,'refs/heads/locked']);await rm(checkout,{recursive:true});
   options.signal?.throwIfAborted();await commitCandidate(file,bundle,{signal:options.signal});
  }finally{await rm(candidate,{recursive:true,force:true});}}
 await directory(dirname(target),true);const pending=await fixedScratch(join(dirname(target),'.checkout-'));try{const checkout=join(pending,'source');await run(['clone','--quiet','--no-checkout','--',bundle,checkout]);await run(['-C',checkout,'remote','set-url','origin',source.url]);await run(['-C',checkout,'checkout','--quiet','--detach',source.ref]);options.signal?.throwIfAborted();await rename(checkout,target);}finally{await rm(pending,{recursive:true});}return gitCheckout(source,target,options);
}
// Git工作区包转为目录源时展开workspace继承，并把相对path依赖固定到同一锁中的准确版本。
function normalizeCargoManifest(document,workspace,locked) {
 const d=structuredClone(document),w=workspace?.workspace||{};
 for(const [key,value]of Object.entries(d.package||{}))if(value&&typeof value==='object'&&value.workspace===true){if(w.package?.[key]===undefined)fail('Git包workspace字段缺失：'+key);d.package[key]=w.package[key];}
 const section=values=>{for(const [name,value]of Object.entries(values||{})){let dep=typeof value==='string'?{version:value}:{...value};if(dep.workspace){const inherited=w.dependencies?.[name];if(!inherited)fail('Git包workspace依赖缺失：'+name);const source=typeof inherited==='string'?{version:inherited}:inherited;dep={...source,...dep,features:[...(source.features||[]),...(dep.features||[])]};delete dep.workspace;}
  if(dep.path){delete dep.path;if(!dep.version){const matches=locked.filter(x=>x.name===(dep.package||name));if(matches.length!==1)fail('相对依赖没有唯一锁定版本：'+name);dep.version='='+matches[0].version;}}values[name]=dep;}};
 for(const key of ['dependencies','build-dependencies','dev-dependencies'])section(d[key]);for(const target of Object.values(d.target||{}))for(const key of ['dependencies','build-dependencies','dev-dependencies'])section(target[key]);if(d.lints?.workspace){if(!w.lints)fail('Git包workspace lints缺失');d.lints=w.lints;}delete d.workspace;return d;
}
async function prepareCargo(locks,work,options){await directory(work,true);const parse=await parser('toml',options),packages=new Map(),gitSources=new Map(),allPackages=[],vendor=options.cargoVendor||join(work,'cargo-vendor/packages');await directory(vendor,true);
 for(const lock of locks){const doc=parse(await checkedLock(lock));if(!Array.isArray(doc.package))fail('Cargo锁格式无效');allPackages.push(...doc.package);for(const pkg of doc.package){if(!pkg.source)continue;if(pkg.source==='registry+https://github.com/rust-lang/crates.io-index'){if(!/^[a-f0-9]{64}$/u.test(pkg.checksum||''))fail('Cargo包缺少摘要');const key=pkg.name+'-'+pkg.version;if(packages.has(key)&&packages.get(key)!==pkg.checksum)fail('Cargo包版本冲突');packages.set(key,pkg.checksum);const target=join(vendor,key),file=await packageOriginal({url:'https://static.crates.io/crates/'+pkg.name+'/'+key+'.crate',sha256:pkg.checksum},options);if(!await stat(target)){await extractArchive(file,target,{prefix:key,signal:options.signal});const files=Object.fromEntries((await inventory(target)).filter(x=>x.sha256).map(x=>[x.path,x.sha256]));await writeFile(join(target,'.cargo-checksum.json'),JSON.stringify({files,package:pkg.checksum}),{flag:'wx'});}}
 else if(pkg.source.startsWith('git+')){const coordinate=gitCoordinate(pkg.source);if(!gitSources.has(pkg.source))gitSources.set(pkg.source,{coordinate,packages:[]});gitSources.get(pkg.source).packages.push(pkg);}else fail('Cargo来源未声明');}}
 let config='[net]\noffline = true\n[source.crates-io]\nreplace-with = "product-vendor"\n[source.product-vendor]\ndirectory = '+JSON.stringify(vendor)+'\n';
 for(const [source,entry]of gitSources){const checkout=await gitCheckout(entry.coordinate,join(work,'cargo-git',hash(source)),options);const manifests=[];async function walk(path){for(const name of await readdir(path)){if(['.git','target'].includes(name))continue;const file=join(path,name),s=await lstat(file);if(s.isDirectory())await walk(file);else if(name==='Cargo.toml'&&s.isFile())manifests.push(file);}}await walk(checkout);for(const pkg of entry.packages){let found;for(const manifest of manifests){const doc=parse(await readFile(manifest,'utf8'));if(doc.package?.name===pkg.name){let version=doc.package.version;if(typeof version==='object'&&version.workspace)version=parse(await readFile(join(checkout,'Cargo.toml'),'utf8')).workspace?.package?.version;if(version===pkg.version){if(found)fail('Git包路径不唯一');found=dirname(manifest);}}}if(!found)fail('Git包名称版本与锁不一致');const target=join(vendor,pkg.name+'-'+pkg.version+'-'+hash(source).slice(0,12));if(!await stat(target)){await copyTree(found,target);let workspace={};for(let at=found;inside(checkout,at)||at===checkout;at=dirname(at)){const file=join(at,'Cargo.toml');if(await stat(file)){const candidate=parse(await readFile(file,'utf8'));if(candidate.workspace){workspace=candidate;break;}}if(at===checkout)break;}const manifest=normalizeCargoManifest(parse(await readFile(join(found,'Cargo.toml'),'utf8')),workspace,allPackages);await writeFile(join(target,'Cargo.toml'),parse.stringify(manifest));const files=Object.fromEntries((await inventory(target)).filter(x=>x.sha256).map(x=>[x.path,x.sha256]));await writeFile(join(target,'.cargo-checksum.json'),JSON.stringify({files,package:null}));}}
 const key='product-git-'+hash(source).slice(0,12);config+='[source.'+key+']\ngit = '+JSON.stringify(entry.coordinate.url)+'\nrev = '+JSON.stringify(entry.coordinate.ref)+'\nreplace-with = "product-vendor"\n';}
 const cargoHome=join(work,'cargo-home');await directory(cargoHome,true);await writeFile(join(cargoHome,'config.toml'),config);return {cargoHome};
}
async function copyTree(source,target){await directory(source);await mkdir(target);for(const name of await readdir(source)){if(['.git','target'].includes(name))continue;const a=join(source,name),b=join(target,name),s=await lstat(a);if(s.isDirectory())await copyTree(a,b);else if(s.isFile())await copyFile(a,b);else fail('目录源链接或特殊项未声明');}}
// 2026-10-06只读核对官方GitHub tag/Release资产元数据；未下载或安装这些原件。
const podSourceDefinitions=[{"name":"Firebase","version":"12.15.0","url":"https://github.com/firebase/firebase-ios-sdk.git","tag":"CocoaPods-12.15.0","ref":"42e81d245e30e49ea6a5830cf2842d44a1591270"},{"name":"FirebaseCore","version":"12.15.0","url":"https://github.com/firebase/firebase-ios-sdk.git","tag":"CocoaPods-12.15.0","ref":"42e81d245e30e49ea6a5830cf2842d44a1591270"},{"name":"FirebaseCoreInternal","version":"12.15.0","url":"https://github.com/firebase/firebase-ios-sdk.git","tag":"CocoaPods-12.15.0","ref":"42e81d245e30e49ea6a5830cf2842d44a1591270"},{"name":"FirebaseInstallations","version":"12.15.0","url":"https://github.com/firebase/firebase-ios-sdk.git","tag":"CocoaPods-12.15.0","ref":"42e81d245e30e49ea6a5830cf2842d44a1591270"},{"name":"FirebaseMessaging","version":"12.15.0","url":"https://github.com/firebase/firebase-ios-sdk.git","tag":"CocoaPods-12.15.0","ref":"42e81d245e30e49ea6a5830cf2842d44a1591270"},{"name":"GoogleDataTransport","version":"10.1.0","url":"https://github.com/google/GoogleDataTransport.git","tag":"CocoaPods-10.1.0","ref":"617af071af9aa1d6a091d59a202910ac482128f9"},{"name":"GoogleUtilities","version":"8.1.2","url":"https://github.com/google/GoogleUtilities.git","tag":"CocoaPods-8.1.2","ref":"9f183ae842be978784f2963a343682e0c46d8fb3"},{"name":"libwebp","version":"1.5.0","url":"https://github.com/webmproject/libwebp.git","tag":"v1.5.0","ref":"a4d7a715337ded4451fec90ff8ce79728e04126c"},{"name":"nanopb","version":"3.30910.0","url":"https://github.com/nanopb/nanopb.git","tag":"0.3.9.10","ref":"b7e1104502eca3a213b46303391ca4d3bc8ddec1"},{"name":"PromisesObjC","version":"2.4.1","url":"https://github.com/google/promises.git","tag":"2.4.1","ref":"f4a19a3c313dc2616c70bb49d29a799fb16be837"},{"name":"SDWebImage","version":"5.21.7","url":"https://github.com/SDWebImage/SDWebImage.git","tag":"5.21.7","ref":"2de3a496eaf6df9a1312862adcfd54acd73c39c0"},{"name":"SDWebImageWebPCoder","version":"0.15.0","url":"https://github.com/SDWebImage/SDWebImageWebPCoder.git","tag":"0.15.0","ref":"12d83edbcc795fb7b5c0c3cb74d739108d3357d2"},{"name":"WebRTC-SDK","version":"144.7559.09","url":"https://github.com/webrtc-sdk/Specs/releases/download/144.7559.09/WebRTC.xcframework.zip","sha256":"8edb3c20a3f5cef76bfc77ec79d749f3a4ae644d099e466972fcd7312d32a854"}];
// 官方tag仅用于核对声明；产品预先锁定其40位提交，运行时不解析浮动tag。
function podSourceCoordinate(spec, definitions = podSourceDefinitions) {
 const source=spec.source,entry=definitions.find(x=>x.name===spec.name&&x.version===spec.version);
 if(!source||typeof source!=='object')fail('Pod缺少官方来源');
 if(entry){if(source.git!==entry.url&&source.http!==entry.url||source.tag!==entry.tag&&entry.tag!==undefined)fail('Pod官方来源与产品固定坐标不一致');
  if(entry.ref){if(source.commit&&source.commit!==entry.ref)fail('Pod提交漂移');return {url:checkedURL(entry.url),ref:entry.ref};}
  if(source.sha256&&source.sha256!==entry.sha256)fail('Pod发行摘要漂移');return {url:checkedURL(entry.url),sha256:entry.sha256};}
 if(source.git&&/^[a-f0-9]{40}$/u.test(source.commit||''))return {url:checkedURL(source.git),ref:source.commit};
 if(source.http&&/^[a-f0-9]{64}$/u.test(source.sha256||''))return {url:checkedURL(source.http),sha256:source.sha256};
 fail('Pod来源没有产品锁定提交或SHA256：'+spec.name);
}
async function responseBytes(response,limit,signal){
 if(!response.ok||!response.body)fail('官方来源响应失败');if(Number(response.headers.get('content-length'))>limit)fail('官方响应声明超限');
 const chunks=[];let size=0;try{for await(const chunk of response.body){signal?.throwIfAborted();size+=chunk.length;if(size>limit)fail('官方响应数据超限');chunks.push(chunk);}if(!size)fail('官方响应为空');return Buffer.concat(chunks);}finally{await response.body.cancel().catch(()=>{});}
}
async function podSpecBytes(url,options){
 // 官方CDN只允许同一Specs路径的一跳HTTPS分发；锁摘要仍由readPodSpec核验。
 const canonical=new URL(url);if(canonical.origin!=='https://cdn.cocoapods.org'||canonical.href!==url||canonical.username||canonical.password||canonical.search||canonical.hash||!canonical.pathname.startsWith('/Specs/'))fail('Pod spec官方地址无效');
 options.signal?.throwIfAborted();
 let response=await options.fetcher(url,{signal:options.signal,redirect:'manual'});
 if([301,302,303,307,308].includes(response.status)){
  const location=response.headers.get('location'),expected='https://cdn.jsdelivr.net/cocoa'+canonical.pathname;
  await response.body?.cancel();
  if(location!==expected)fail('Pod spec官方分发重定向越界');
  options.signal?.throwIfAborted();
  response=await options.fetcher(expected,{signal:options.signal,redirect:'error'});
 }
 return responseBytes(response,2*1024**2,options.signal);
}
async function readPodSpec(file){return JSON.parse(await readFile(file,'utf8'));}
async function copyPodSource(source,target,base=source){
 await directory(source);await directory(target,true);for(const name of await readdir(source)){if(name==='.git')continue;const input=join(source,name),output=join(target,name),s=await lstat(input);
  if(s.isDirectory())await copyPodSource(input,output,base);else if(s.isFile()){await regular(input);await copyFile(input,output,constants.COPYFILE_EXCL);await chmod(output,s.mode&0o111?0o755:0o644);}else if(s.isSymbolicLink()){const resolved=await realpath(input);if(!inside(base,resolved))fail('Pod源码链接越界');await symlink(await readlink(input),output);}else fail('Pod源码含特殊项');}
}
async function preparePods(lockfile,work,options){const parse=await parser('yaml',options),text=await checkedLock(lockfile),lock=parse(text),podHome=join(work,'cocoapods');await directory(podHome,true);


 const local=new Set();for(const [name,source]of Object.entries(lock['EXTERNAL SOURCES']||{})){if(typeof source[':path']!=='string'||Object.keys(source).some(x=>x!==':path'))fail('Pod外部来源必须另有产品固定锁：'+name);local.add(name);}
 const handled=new Set();for(const item of lock.PODS||[]){const record=typeof item==='string'?item:Object.keys(item)[0],m=/^([^/( ]+)(?:\/[^ (]+)? \(([^)]+)\)$/u.exec(record);if(!m)fail('Pod锁记录无效');const [,name,version]=m;if(local.has(name)||handled.has(name))continue;handled.add(name);
  const checksum=lock['SPEC CHECKSUMS']?.[name];if(!/^[a-f0-9]{40}$/u.test(checksum||''))fail('Pod缺少锁定spec摘要');const key=version+'-'+checksum.slice(0,5),specPath=join(podHome,'cache/Pods/Specs/Release',name,key+'.podspec.json'),release=join(podHome,'cache/Pods/Release',name,key);

  // Pod spec与源码仅物化到当前任务的CocoaPods视图。
  if(!await stat(specPath)||!await stat(release)){const candidate=await fixedScratch(join(await resourceWork(options.library.work),'.pod-'));try{const payload=join(candidate,'payload');await mkdir(payload);const specFile=join(payload,'spec.json');
    if(await stat(specPath))await copyFile(specPath,specFile,constants.COPYFILE_EXCL);else{if(options.offline)fail('离线缺少Pod spec');const md5=createHash('md5').update(name).digest('hex'),url='https://cdn.cocoapods.org/Specs/'+md5[0]+'/'+md5[1]+'/'+md5[2]+'/'+name+'/'+version+'/'+name+'.podspec.json';await writeFile(specFile,await podSpecBytes(url,options),{flag:'wx'});}
    const spec=await readPodSpec(specFile,name,version,checksum,options),coordinate=podSourceCoordinate(spec),source=join(payload,'source');
    if(await stat(release)){await copyPodSource(release,source);}else if(coordinate.ref){const checkout=join(candidate,'checkout');await gitCheckout(coordinate,checkout,options);await copyPodSource(checkout,source);await rm(checkout,{recursive:true});}else{const file=await packageOriginal(coordinate,options);await extractArchive(file,source,{signal:options.signal});}
    if(!await stat(release)&&spec.prepare_command){if(typeof spec.prepare_command!=='string')fail('Pod准备命令不是锁定文本');const foundation=await productFoundation(options.library,async(_,t)=>options.library.installed.get(t.id));await exec(foundation.tools.bash,['-ec',spec.prepare_command],{cwd:source,signal:options.signal,env:{...cleanEnvironment(options.environment),PATH:foundation.path,HOME:options.library.work,COCOAPODS_VERSION:options.library.tools.find(x=>x.id==='cocoapods').version}});}
    if(!await stat(specPath)){await directory(dirname(specPath),true);await copyFile(specFile,specPath,constants.COPYFILE_EXCL);}await readPodSpec(specPath,name,version,checksum,options);
    if(!await stat(release))await copyPodSource(source,release);
   }finally{await rm(candidate,{recursive:true,force:true});}}
  await readPodSpec(specPath,name,version,checksum,options);
 }
 const version=options.library.tools.find(x=>x.id==='cocoapods')?.version,file=join(podHome,'cache/Pods/VERSION');await directory(dirname(file),true);if(await stat(file)){await regular(file);}else await writeFile(file,version,{flag:'wx'});
 checkCocoaPodsResources(lockfile,podHome);
}

async function acquireOfficialPlatform(item,options){
 // 固定官方发行树先有界下载，再以产品登记的整树摘要验真；候选归入同一取消清理范围。
 if(options.offline)fail('离线缺少额外Android发行件');const data=await responseBytes(await options.fetcher(checkedURL(item.source),{signal:options.signal,redirect:'error'}),512*1024**2,options.signal);const file=join(options.library.work,'.platform-'+randomUUID()+'.zip');await writeFile(file,data,{flag:'wx'});return file;
}
// SDK原件只供读取；Gradle可写元数据限定在本任务独占副本，工具字节不得漂移。
// Android工具路径直接复用供给；包管理器可写状态只进入本轮固定根。
async function prepareAndroidSDKView(payload,work,{signal}={}){
 signal?.throwIfAborted();const owner=await import('./build.mjs');owner.checkWork(work);
 const target=join(work,'dependencies/android-sdk-view');await directory(dirname(target),true);
 if(!await stat(target)){
  try{await cp(payload,target,{recursive:true,force:false,errorOnExist:true,verbatimSymlinks:true,filter:()=>{signal?.throwIfAborted();return true;}});}
  catch(error){await rm(target,{recursive:true,force:true});throw error;}
  async function writable(path){const value=await lstat(path);if(value.isSymbolicLink())return;if(value.isDirectory()){await chmod(path,value.mode|0o700);for(const name of await readdir(path))await writable(join(path,name));}else await chmod(path,value.mode|0o600);}
  await writable(target);
 }
 return target;
}
async function installAndroidResources(options){const library=options.library,cmake=library.tools.find(x=>x.id==='cmake'),packages=androidDefinitions.map(x=>x.tool?{path:'cmake;'+cmake.version,version:cmake.version,...cmake.archives.macos}:x),wanted=library.requested.flatMap(x=>x.packages||[]);for(const item of wanted){const match=library.androidPlatforms?.find(x=>x.path===item.path&&x.version===item.version);if(!match)fail('SDK平台没有产品准确登记');if(!packages.some(x=>x.path===match.path))packages.push(match);}
 const sha256=hash(JSON.stringify(packages)),store=join(library.root,'shared');await directory(store,true);const target=join(store,'android-'+sha256);const locateSDK=async directory=>{const payload=join(directory,'payload');return await stat(payload)?payload:null;};
 let payload=await locateSDK(target);if(!payload&&options.optionalTools){const supplied=join(options.optionalTools,'shared/android');if(await stat(supplied))payload=await locateSDK(supplied);}
 if(!payload){if(options.offline)fail('离线缺少SDK闭包');const pending=await fixedScratch(join(await resourceWork(options.library.work),'.android-'));try{payload=join(pending,'payload');await mkdir(payload);for(const item of packages){const at=join(payload,...item.path.split(';'));await directory(dirname(at),true);if(item.source){const file=await acquireOfficialPlatform(item,options),unpacked=join(pending,'unpack');try{await extractArchive(file,unpacked,{signal:options.signal});const names=await readdir(unpacked);if(names.length!==1)fail('额外平台归档根不唯一');await rename(join(unpacked,names[0]),at);await rm(unpacked,{recursive:true});}finally{await rm(file,{force:true});}}else{const file=await packageOriginal(item,options),unpacked=join(pending,'unpack');await extractArchive(file,unpacked,{signal:options.signal});await rename(item.root==='.'?unpacked:join(unpacked,item.root),at);if(await stat(unpacked))await rm(unpacked,{recursive:true});}}await permissions(payload,false);await writeFile(join(pending,'receipt.json'),JSON.stringify({sha256}),{flag:'wx',mode:0o444});await commitCandidate(pending,target,{signal:options.signal});payload=await locateSDK(target);}finally{if(await stat(pending)){await permissions(pending,true);await rm(pending,{recursive:true});}}}
 if(library.requested.some(isAndroidSdkComponent))payload=await prepareAndroidSDKView(payload,library.work,{signal:options.signal});
 const versions=id=>library.tools.find(x=>x.id===id)?.version;for(const [id,file]of [['android','platform-tools/adb'],['android-sdk','cmdline-tools/'+versions('android-sdk')+'/bin/sdkmanager'],['android-ndk','ndk/'+versions('android-ndk')+'/ndk-build'],['cmake','cmake/'+versions('cmake')+'/bin/cmake']])if(library.requested.some(x=>x.id===id))library.installed.set(id,{path:join(payload,file),version:versions(id)});
 return {ANDROID_HOME:payload,ANDROID_SDK_ROOT:payload,ANDROID_NDK_HOME:join(payload,'ndk',versions('android-ndk')),ANDROID_USER_HOME:join(library.work,'android-user'),ANDROID_EMULATOR_HOME:join(library.work,'android-user')};
}
async function appleEnvironment(library,options){if(!library.installed.has('xcode'))return {};const mapping={xcodebuild:'XCODEBUILD',codesign:'CODESIGN',xattr:'XATTR',security:'SECURITY',xcrun:'XCRUN','xcode-select':'XCODE_SELECT',clang:'CC','clang++':'CXX',swift:'SWIFT',swiftc:'SWIFTC',otool:'OTOOL',install_name_tool:'INSTALL_NAME_TOOL',lipo:'LIPO',make:'MAKE',ar:'AR',ranlib:'RANLIB',nm:'NM',strip:'STRIP','llvm-nm':'LLVM_NM'};const apple=await appleTools(library,{names:Object.keys(mapping),signal:options.signal,environment:cleanEnvironment(options.environment)}),environment={DEVELOPER_DIR:apple.developerDirectory};const bin=join(library.work,'apple-tools');await directory(bin,true);for(const [name,key]of Object.entries(mapping)){environment[key]=apple.tools[name];const target=join(bin,name);if(await stat(target)){if(!((await lstat(target)).isSymbolicLink())||await realpath(target)!==await realpath(apple.tools[name]))fail('Apple任务入口漂移');}else await symlink(apple.tools[name],target);}environment.PATH=bin;environment.LD=apple.tools.clang;environment.LDCXX=apple.tools['clang++'];environment.CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER=apple.tools.clang;const sdk=(await exec(apple.tools.xcrun,['--sdk','macosx','--show-sdk-path'],{signal:options.signal,env:{PATH:'',DEVELOPER_DIR:apple.developerDirectory},timeout:60000})).stdout.trim();environment.SDKROOT=await realpath(sdk);if(!inside(apple.developerDirectory,environment.SDKROOT))fail('SDK越出Xcode');return environment;}

// 远程Pod必须同时交付锁定spec与完整源码；本地路径Pod由本轮产品工程产生。
function checkCocoaPodsResources(lockfile,directory) {
 const text=readFileSync(lockfile,'utf8'),local=[...text.matchAll(/^  ([A-Za-z0-9_.+-]+):\n    :path: /gmu)].map(x=>x[1]);const checksums=new Map([...text.matchAll(/^  ([A-Za-z0-9_.+-]+): ([a-f0-9]{40})$/gmu)].map(x=>[x[1],x[2]]));
 for(const match of text.matchAll(/^  - "?([A-Za-z0-9_.+-]+)(?:\/[A-Za-z0-9_.+-]+)* \(([^()\s]+)\)"?/gmu)){const [,name,version]=match;if(local.includes(name))continue;const checksum=checksums.get(name);if(!checksum)fail('远程Pod缺少锁定spec摘要');const key=version+'-'+checksum.slice(0,5),spec=join(directory,'cache/Pods/Specs/Release',name,key+'.podspec.json'),release=join(directory,'cache/Pods/Release',name,key);if(!existsSync(spec)||!existsSync(release))fail('锁定CocoaPods原件尚未完整存在：'+name);}
 return {paths:local.map(name=>({name}))};
}

// Gradle资源解析发生在编译之前，产品工作视图必须先获得当前回执的SDK配置。
async function prepareAndroidResourceProperties(project,work,flutterRoot,sdkRoot,{signal}={}){
 signal?.throwIfAborted();if(!inside(work,project))fail('Android资源工程越出工作根');await directory(project);
 for(const path of [flutterRoot,sdkRoot]){if(typeof path!=='string'||/[\r\n\x00]/u.test(path))fail('Android资源SDK路径无效');await directory(path);}
 const manifest=await readFile(join(dirname(project),'pubspec.yaml'),'utf8'),versions=[...manifest.matchAll(/^version:\s*(\d+\.\d+\.\d+)\+([1-9][0-9]*)\s*$/gmu)];
 if(versions.length!==1)fail('Android资源产品版本不唯一或无效');
 const escape=value=>value.split('').map(c=>c==='\\'?'\\\\':c.charCodeAt(0)>127?'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0'):c).join('');
 const text='sdk.dir='+escape(sdkRoot)+'\nflutter.sdk='+escape(flutterRoot)+'\nflutter.buildMode=release\nflutter.versionName='+versions[0][1]+'\nflutter.versionCode='+versions[0][2]+'\n',file=join(project,'local.properties');
 signal?.throwIfAborted();if(await stat(file)){
  await regular(file);const current=await readFile(file,'utf8');
  if(current!==text){
   const values=new Map(),allowed=new Set(['sdk.dir','flutter.sdk','flutter.buildMode','flutter.versionName','flutter.versionCode']);
   for(const line of current.split(/\r?\n/u)){
    if(!line||line.startsWith('#')||line.startsWith('!'))continue;
    const equal=line.indexOf('='),key=line.slice(0,equal),value=line.slice(equal+1);
    if(equal<=0||!allowed.has(key)||values.has(key))fail('Android资源SDK配置漂移');values.set(key,value);
   }
   if(values.get('flutter.sdk')!==escape(flutterRoot)
    ||values.has('sdk.dir')&&values.get('sdk.dir')!==escape(sdkRoot)
    ||values.has('flutter.buildMode')&&values.get('flutter.buildMode')!=='release'
    ||values.has('flutter.versionName')&&values.get('flutter.versionName')!==versions[0][1]
    ||values.has('flutter.versionCode')&&values.get('flutter.versionCode')!==versions[0][2])fail('Android资源SDK配置漂移');
   await writeFile(file,text);
  }
 }else await writeFile(file,text,{flag:'wx',mode:0o600});
// 工具和依赖原件由本产品独立准备及复用。
 const original=join(flutterRoot,'packages/integration_test/android');await directory(original);
 const parent=join(dirname(project),'.flutter-plugin-views/integration_test');await directory(parent,true);
 const view=join(parent,'android');
 const copyTree=async(from,to)=>{
  signal?.throwIfAborted();const info=await lstat(from);
  if(info.isSymbolicLink())fail('Flutter插件原件包含链接');
  const prior=await lstat(to).catch(error=>{if(error.code==='ENOENT')return null;throw error;});
  if(info.isDirectory()){
   if(prior){if(!prior.isDirectory()||prior.isSymbolicLink()||!(prior.mode&0o200))fail('Flutter插件任务视图漂移');}
   else await mkdir(to,{mode:0o700});
   const names=await readdir(from),existing=await readdir(to);
   if(existing.some(name=>!names.includes(name)))fail('Flutter插件任务视图含额外文件');
   for(const name of names)await copyTree(join(from,name),join(to,name));
  }else if(info.isFile()){
   if(prior){if(!prior.isFile()||prior.isSymbolicLink()||!(prior.mode&0o200)
    ||!(await readFile(from)).equals(await readFile(to)))fail('Flutter插件任务视图漂移');}
   else{await copyFile(from,to);await chmod(to,info.mode&0o111?0o700:0o600);}
  }else fail('Flutter插件原件包含特殊文件');
 };
 await copyTree(original,view);
 return file;
}

// 与产品唯一Android编译入口一致，只准备Release ARM64外部制品，不解析测试或本地生成输出。
function androidGradleResourceInit(){return '// 本任务解析Release编译、运行及插件构建脚本闭包，不编译、不扩展版本。\nimport org.gradle.api.artifacts.component.ModuleComponentIdentifier\nallprojects { p -> p.tasks.register("productResolveResources") { doLast { p.buildscript.configurations.findAll { it.canBeResolved && it.name == "classpath" }.each { c -> c.incoming.artifactView { componentFilter { id -> id instanceof ModuleComponentIdentifier } }.files.files }; p.configurations.findAll { it.canBeResolved && it.name in ["releaseCompileClasspath", "releaseRuntimeClasspath"] }.each { c -> c.incoming.artifactView { componentFilter { id -> id instanceof ModuleComponentIdentifier } }.files.files } } } }\n';}

async function prepareGradleResources(work,options,environment,projectEnvironment){const gradle=options.library.installed.get('gradle');if(!gradle)return;const home=join(work,'dependencies/gradle');await directory(home,true);environment.GRADLE_USER_HOME=home;


 // 只解析当前产品的任务工程，不递归把SDK或插件示例误认为可写产品工程。
 const owner=await import('./build.mjs');owner.checkWork(work);
 const productRoot=projectEnvironment?.CITIZENAPP_PROJECT_ROOT;
 if(typeof productRoot!=='string'||productRoot!==join(work,'source-view',root.replace(/^\/+/,'')))fail('Android资源工程不属于当前任务');
 const project=join(productRoot,'android');if(!await stat(project))return;
 await directory(productRoot);await directory(project);
 // 先按产品锁在任务视图生成插件清单，后续 Gradle 才能看见各插件 buildscript 的真实闭包。
 const flutterTool=options.library.installed.get('flutter');if(!flutterTool)fail('Android资源缺少Flutter工具');
 await exec(flutterTool.path,['pub','get','--enforce-lockfile','--offline'],{
  cwd:productRoot,signal:options.signal,timeout:600000,maxBuffer:4*1024**2,
  env:{...cleanEnvironment(options.environment),...projectEnvironment,FLUTTER_SUPPRESS_ANALYTICS:'true'},
 });
 const plugins=join(productRoot,'.flutter-plugins-dependencies');await regular(plugins);
 const pluginList=JSON.parse(await readFile(plugins,'utf8'))?.plugins?.android;
 if(!Array.isArray(pluginList)||!pluginList.some(value=>value?.name==='audio_session'))fail('Android插件清单缺少聊天音频依赖');
 // SDK原生AAR的buildscript有独立依赖图，按SDK公开包装输入预解析，不能用宿主Flutter图替代。
 const sdkSource=owner.resourceSourceRoot('citizen_sdk',work),sdkEntry=join(sdkSource,'scripts/build.mjs');await regular(sdkEntry);
 const sdk=await import(pathToFileURL(sdkEntry).href+'?revision='+hash(await readFile(sdkEntry)));
 if(typeof sdk.androidGradleProjectFiles!=='function')fail('SDK未交付原生Gradle资源接口');
 const sdkWork=join(work,'work/citizensdk-work'),sdkProject=join(sdkWork,'gradle-project');await directory(join(sdkProject,'native'),true);
 const inputs=sdk.androidGradleProjectFiles();
 if(Object.keys(inputs).sort().join(',')!=='build.gradle,native/build.gradle,settings.gradle')fail('SDK原生Gradle输入身份无效');
 for(const [name,text]of Object.entries(inputs)){if(typeof text!=='string'||text.length>4096)fail('SDK原生Gradle输入无效');const file=join(sdkProject,name);
  if(await stat(file)){await regular(file);if(await readFile(file,'utf8')!==text)fail('SDK原生Gradle包装输入漂移');}else await writeFile(file,text,{flag:'wx',mode:0o600});
 }
 if(typeof sdk.createNativeSourceView!=='function')fail('SDK未交付原生工程视图');
 const nativeSource=sdk.createNativeSourceView(sdkSource,join(sdkWork,'native-source'));
 const cargo=join(dirname(options.library.installed.get('rust').path),'cargo'),cargoHome=join(work,'dependencies/citizen_sdk/cargo-home');
 const metadata=JSON.parse((await exec(cargo,['metadata','--manifest-path',join(nativeSource,'native/ffi/Cargo.toml'),'--format-version','1','--locked','--offline'],{
  signal:options.signal,timeout:600000,maxBuffer:16*1024**2,quietOutput:true,env:{...environment,CARGO_HOME:cargoHome,CARGO_TARGET_DIR:join(sdkWork,'cargo-target')},
 })).stdout);
 if(typeof sdk.androidGradleLocalRepository!=='function')fail('SDK未交付原锁Android证书组件接口');
 const verifier=sdk.androidGradleLocalRepository(metadata);if(!inside(work,verifier.maven)||await realpath(verifier.maven)!==verifier.maven)fail('SDK Android证书组件来源越界');
 await regular(verifier.aar);const verifierLink=join(home,'citizensdk-verifier-maven');
 const linkInfo=await lstat(verifierLink).catch(error=>{if(error.code==='ENOENT')return null;throw error;});
 if(linkInfo){if(!linkInfo.isSymbolicLink()||await readlink(verifierLink)!==verifier.maven)fail('SDK证书组件Maven视图漂移');}else await symlink(verifier.maven,verifierLink);
 const sdkInit=join(sdkWork,'gradle-resource-init.gradle'),sdkText="// 解析SDK真实Release及测试模块闭包，不编译、不覆盖版本。\nimport org.gradle.api.artifacts.component.ModuleComponentIdentifier\nallprojects { p -> p.tasks.register('productResolveResources') { doLast { p.configurations.findAll { it.canBeResolved && it.name in ['releaseCompileClasspath','releaseRuntimeClasspath','releaseUnitTestCompileClasspath','releaseUnitTestRuntimeClasspath','compileClasspath','runtimeClasspath','testCompileClasspath','testRuntimeClasspath'] }.each { c -> c.incoming.artifactView { componentFilter { id -> id instanceof ModuleComponentIdentifier } }.files.files } } } }\n";
 if(await stat(sdkInit)){await regular(sdkInit);if(await readFile(sdkInit,'utf8')!==sdkText)fail('SDK资源初始化脚本漂移');}else await writeFile(sdkInit,sdkText,{flag:'wx'});
 process.stderr.write('资源阶段：CitizenSDK Gradle\n');
 const sdkGradleArgs=['--no-daemon','--console=plain','--project-cache-dir',join(sdkWork,'gradle-project-cache'),'--init-script',sdkInit,...gradleOfflineArguments(options),'productResolveResources'];
 const sdkBash=options.library.installed.get('bash')?.path;if(!sdkBash)fail('CitizenSDK资源缺少已交付Shell');
 const sdkResponse=await exec(sdkBash,['--noprofile','--norc','-c','status=0; "$@" || status=$?; printf "\\nPRODUCT_SDK_GRADLE_STATUS=%s\\n" "$status"','sdk-gradle',gradle.path,...sdkGradleArgs],{
  cwd:sdkProject,signal:options.signal,timeout:1800000,maxBuffer:8*1024**2,
  env:{...cleanEnvironment(options.environment),...environment,CITIZENSDK_SOURCE_DIR:sdkSource,CITIZENSDK_WORK_DIR:sdkWork,
   CITIZENSDK_ANDROID_BUILD_DIR:join(sdkWork,'gradle-native'),CITIZENSDK_ANDROID_CORE_DIR:join(sdkWork,'android-core/arm64-v8a'),
   JAVA_HOME:dirname(dirname(options.library.installed.get('java').path)),PATH:(await productFoundation(options.library,async(_,t)=>options.library.installed.get(t.id))).path},
 });
 const sdkStatus=sdkResponse.stdout.match(/(?:^|\n)PRODUCT_SDK_GRADLE_STATUS=(\d+)\n$/u)?.[1];
 if(!sdkStatus||sdkStatus!=='0')fail('CitizenSDK Gradle资源预解析失败，退出码'+(sdkStatus||'未知'));
 {const flutter=options.library.installed.get('flutter');if(flutter&&!await stat(join(dirname(project),'flutter-gradle')))await flutterRecipe.prepareFlutterTaskTools(dirname(dirname(flutter.path)),dirname(project),'android',{signal:options.signal,environment:{...environment,JAVA_HOME:dirname(dirname(options.library.installed.get('java').path)),GRADLE_HOME:dirname(dirname(gradle.path)),PRODUCT_BASH_BIN:options.library.installed.get('bash').path}});
  if(!flutter||!environment.ANDROID_HOME)fail('Android资源缺少已提供Flutter或SDK');await prepareAndroidResourceProperties(project,work,dirname(dirname(flutter.path)),environment.ANDROID_HOME,{signal:options.signal});
  const init=join(work,'gradle-resource-init.gradle'),initText=androidGradleResourceInit();if(await stat(init)){await regular(init);if(await readFile(init,'utf8')!==initText)fail('Gradle资源任务配置漂移');}else await writeFile(init,initText,{flag:'wx'});
  const gradleArgs=['--no-daemon','--console=plain','-Ptarget-platform=android-arm64','-Dorg.gradle.project.android.builder.sdkDownload=false','--init-script',init,...gradleOfflineArguments(options),'productResolveResources'];
  const bash=options.library.installed.get('bash')?.path;if(!bash)fail('Android资源缺少已交付Shell');
  process.stderr.write('资源阶段：CitizenApp Gradle\n');
  const response=await exec(bash,['--noprofile','--norc','-c','status=0; "$@" || status=$?; printf "\\nPRODUCT_GRADLE_STATUS=%s\\n" "$status"','product-gradle',gradle.path,...gradleArgs],{cwd:project,signal:options.signal,timeout:1800000,maxBuffer:8*1024**2,env:{...cleanEnvironment(options.environment),...environment,CITIZENAPP_BUILD_DIR:join(work,'work/flutter'),JAVA_HOME:dirname(dirname(options.library.installed.get('java').path)),PATH:(await productFoundation(options.library,async(_,t)=>options.library.installed.get(t.id))).path}});
  const status=response.stdout.match(/(?:^|\n)PRODUCT_GRADLE_STATUS=(\d+)\n$/u)?.[1];
  if(!status||status!=='0')fail('Android Gradle资源预解析失败，退出码'+(status||'未知'));
 }
}
const buildSourceTool=sourceRecipe.buildSourceTool;
const posixNames=posixRecipe.posixNames;
function resourceDeclarations(){return {tools:toolDefinitions,parsers:parserDefinitions,android:androidDefinitions,pods:podSourceDefinitions};}
// 完整入口可由调用方的启动Node进入；产品自行取得锁定Node并重新进入自己的入口。
// 启动Node只执行内置下载/摘要/解包，不成为产品编译工具版本的第二真源。
async function bootstrapNode(work,options={}) {
 const owner=await import('./build.mjs');owner.checkWork(work);const environment=options.environment||process.env;
 if(process.platform!=='darwin'||process.arch!=='arm64')fail('本机入口仅支持声明的macOS ARM宿主');
 const store=options.storeRoot||join(homedir(),'.local/share/product-resources');
 if(inside(root,store)||inside(store,root)||inside(work,store)||inside(store,work)||store===work)fail('启动原件库边界交叉');
 const library={root:join(store,'tools'),work,tools:toolDefinitions,installed:new Map()};await directory(library.root,true);
 const context={environment,offline:false,fetcher:fetch,...options,library,optionalTools:undefined};
 return installTool(library,toolDefinitions.find(x=>x.id==='node'),context);
}

function gitBundlePath(source,dependencyRoot){
 const coordinate=new URL(checkedURL(source.url));return join(dependencyRoot,'git',coordinate.hostname,...coordinate.pathname.split('/').filter(Boolean),source.ref+'.bundle');
}
// 完整Build先按自身声明准备选择SDK所需的Git；不在控制台查询或供应依赖。
async function prepareSdkInputs(work,{environment=process.env,signal,delivery='local',ciEnvironment,offline=false}={}){return resourceSupplies.run({work},async()=>{
 const owner=await import('./build.mjs');owner.checkWork(work);owner.lockedSources();
 if(delivery==='automation'){
  const locked=automationSdkInputs(ciEnvironment||environment);
  return selectReleaseSdkInputs((ciEnvironment||environment).GH_TOKEN||(ciEnvironment||environment).GITHUB_TOKEN,{locked});
 }
 const store=join(homedir(),'.local/share/product-resources');
 if(inside(root,store)||inside(store,root)||inside(work,store)||inside(store,work))fail('SDK选择资源边界交叉');
 const library={root:join(store,'tools'),work,tools:toolDefinitions,installed:new Map()};await directory(library.root,true);
 const options={library,environment,signal,offline,fetcher:fetch};
 for(const id of ['node','posix','bash','grep','sed','git'])await installTool(library,toolDefinitions.find(tool=>tool.id===id),options);
 const foundation=await productFoundation(library,async(_,tool)=>library.installed.get(tool.id));
 return owner.selectLocalSdkInputs(library.installed.get('git').path,work,{...cleanEnvironment(environment),PATH:foundation.path});
});}
// Node独立验收复用既有工具，本机准确提交只读物化为本任务Git输入；不下载、安装或编译资源。
async function nodeTestResources(work,{environment=process.env,signal}={}){return resourceSupplies.run({work},async()=>{
 const owner=await import('./build.mjs');owner.checkWork(work);signal?.throwIfAborted();
 if(process.platform!=='darwin'||process.arch!=='arm64')fail('独立Node验收仅支持声明的macOS ARM宿主');
 const store=join(homedir(),'.local/share/product-resources'),library={root:join(store,'tools'),work,tools:toolDefinitions,installed:new Map()};
 if(inside(root,store)||inside(store,root)||inside(work,store)||inside(store,work)||store===work)fail('Node验收原件库边界交叉');
 await directory(store);await directory(library.root);const shared=join(library.root,'shared');await directory(shared);
 const names=await readdir(shared);
 for(const id of ['node','git','posix','bash','grep','sed']){
  signal?.throwIfAborted();const tool=toolDefinitions.find(value=>value.id===id),archive=tool&&toolArchive(tool);
  if(!archive)fail('Node验收工具未声明：'+id);
  const candidates=[archive.sha256,...names.filter(name=>name.startsWith(archive.sha256+'-'))];let installed;
  for(const name of candidates){const candidate=join(shared,name);if(!await stat(candidate))continue;await directory(candidate);const value=await installedToolObject(candidate,tool);if(!value)continue;const target=await realpath(value.path);if(!inside(join(candidate,'payload'),target))fail('Node验收工具越出原对象：'+id);await regular(target);if(!((await lstat(target)).mode&0o111))fail('Node验收工具不可执行：'+id);installed=value;break;}
  if(!installed)fail('Node验收缺少已准备工具：'+id);library.installed.set(id,installed);
 }
 const foundation=await productFoundation(library,async(_,tool)=>library.installed.get(tool.id));
 const state=executions.getStore();if(!state)fail('Node验收缺少独立任务上下文');state.sdkWork=work;
 if(environment.GITHUB_ACTIONS==='true')fail('独立Node验收只接受本机SDK输入；自动化测试使用完整Build的已锁定输入');
 state.sdkSelection=await owner.selectLocalSdkInputs(library.installed.get('git').path,work,{...cleanEnvironment(environment),PATH:foundation.path});
 const sources=owner.effectiveSdkSources(work),options={library,environment,signal,offline:true,dependencyRoot:join(store,'rely'),sources};
 for(const source of sources){const bundle=gitBundlePath(source,options.dependencyRoot);if(await stat(bundle))await regular(bundle);}
 for(const source of sources)await gitCheckout(source,join(work,'git-sources',source.name),options);
 const apple=await appleTools(library,{names:['swiftc','xcrun'],environment,signal});
 const sdk=(await exec(apple.tools.xcrun,['--sdk','macosx','--show-sdk-path'],{env:{...cleanEnvironment(environment),DEVELOPER_DIR:apple.developerDirectory,PATH:''},signal,timeout:60000})).stdout.trim();
 if(!isAbsolute(sdk)||resolve(sdk)!==sdk)fail('Node验收Apple SDK路径无效');const sdkRoot=await realpath(sdk);await directory(sdkRoot);if(!inside(apple.developerDirectory,sdkRoot))fail('Node验收Apple SDK越界');
 return {node:library.installed.get('node'),environment:{...cleanEnvironment(environment),...sdkSelectionEnvironment(work,state.sdkSelection),PATH:[dirname(library.installed.get('git').path),foundation.path,dirname(library.installed.get('node').path)].join(':'),PRODUCT_GIT_BIN:library.installed.get('git').path,PRODUCT_TEST_SWIFTC:apple.tools.swiftc,PRODUCT_TEST_DEVELOPER_DIR:apple.developerDirectory,PRODUCT_TEST_SDKROOT:sdkRoot,CITIZENAPP_TEST_WORK_DIR:work}};
});}

async function resources(platform,work,previous={},options={}){return resourceSupplies.run({work},async()=>{
 const current=executions.getStore();if(current?.sdkSelection)return materializeResources(platform,work,previous,options);
 const environment=options.environment||process.env,state={signal:options.signal,sdkWork:work};
 state.sdkSelection=previous.sdk_selection?checkedSdkSelection(previous.sdk_selection):await prepareSdkInputs(work,{...options,environment,delivery:environment.GITHUB_ACTIONS==='true'?'automation':'local',ciEnvironment:environment});
 return executions.run(state,()=>materializeResources(platform,work,previous,options));
});}

async function materializeResources(platform,work,previous={},options={}){
 const owner=await import('./build.mjs');owner.checkWork(work);const request=()=>owner.requirements(platform,work);const requirement=request(),environment=options.environment||process.env;
 if(previous.schema!==undefined&&(previous.schema!==1||previous.product_id!==requirement.product_id||previous.platform!==platform||previous.work!==work))fail('资源请求身份无效');options={environment,fetcher:fetch,offline:false,...options};options.signal?.throwIfAborted();
 if(previous.sdk_selection&&JSON.stringify(checkedSdkSelection(previous.sdk_selection))!==JSON.stringify(sdkSelectionForWork(work,environment)))fail('资源阶段SDK任务锁漂移');
 const store=options.storeRoot||join(homedir(),'.local/share/product-resources'),optionalTools=options.toolRoot;
 await directory(store,true);if(inside(root,store)||inside(store,root)||inside(work,store)||inside(store,work)||store===work)fail('原件库与源码或工作区交叉');
 // tools承载工具发行件/编译输入，rely承载产品依赖原件；不把可写任务缓存混入任一原件库。
 const library={root:options.toolRoot||join(store,'tools'),work,tools:toolDefinitions,requested:requirement.tools,installed:new Map(),androidPlatforms:androidPlatformDefinitions};await directory(library.root,true);options={...options,platform,optionalTools,library,dependencyRoot:options.dependencyRoot||join(store,'rely'),sources:requirement.sources};
 for(const request of requirement.tools){const definition=toolDefinitions.find(x=>x.id===request.id);if(!definition||definition.version!==request.version)fail('需求与产品自己的工具配方不一致：'+request.id);}
 // 直接使用声明的工具入口。
 const node=toolDefinitions.find(x=>x.id==='node');await installTool(library,node,options);
 const android=requirement.tools.some(isAndroidSdkComponent);for(const request of requirement.tools){if(android&&(isAndroidSdkComponent(request)||request.id==='cmake'))continue;await installTool(library,toolDefinitions.find(x=>x.id===request.id),options);}
 const receipt={schema:1,product_id:requirement.product_id,platform,work,sdk_selection:sdkSelectionForWork(work,environment),tools:Object.fromEntries(library.installed),dependencies:{},archives:{},environment:{},offline:true};for(const key of ['run_id','program_digest'])if(previous[key]!==undefined)receipt[key]=previous[key];
 for(const id of ['posix','bash','grep','sed'])await installTool(library,toolDefinitions.find(x=>x.id===id),options);receipt.tools=Object.fromEntries(library.installed);const foundation=await productFoundation(library,async(_,t)=>library.installed.get(t.id));receipt.environment=await appleEnvironment(library,options);receipt.environment.PATH=[receipt.environment.PATH,foundation.path,...[...library.installed].filter(([id])=>id!=='posix').map(([,x])=>dirname(x.path))].filter(Boolean).join(':');receipt.environment.PRODUCT_WORK_DIR=work;
 if(android)Object.assign(receipt.environment,await installAndroidResources(options));receipt.tools=Object.fromEntries(library.installed);
 for(const source of requirement.sources){process.stderr.write('资源阶段：Git '+source.name+'\n');await gitCheckout(source,join(work,'git-sources',source.name),options);}
 // 宿主原锁保持完整校验；本任务SDK提交只在消费视图投影，传递依赖仍执行原锁约束。
 // 归属扩展由本产品判断：prepare产生的原生源码根也只能在同一work中消费。
 const groups=new Map();for(const lock of requirement.locks){const name=lock.source_package||'own';if(!groups.has(name))groups.set(name,[]);groups.get(name).push(lock);}for(const [name,locks]of groups){process.stderr.write('资源阶段：锁 '+name+'\n');const base=name==='own'?root:owner.resourceSourceRoot(name,work);await directory(base);const files=kind=>locks.filter(x=>x.ecosystem===kind).map(x=>{if(!safePath(x.path))fail('锁路径越界');return join(base,x.path);}),target=join(work,'dependencies',name);await directory(target,true);let result={request:JSON.stringify(locks)};
  if(files('npm').length)Object.assign(result,await prepareNpm(files('npm'),target,options));if(files('cargo').length){const sdk=['citizen_sdk','tatachat_sdk'].includes(name);if(sdk)owner.ensureVendorVolume(work);Object.assign(result,await prepareCargo(files('cargo'),target,{...options,...(sdk?{cargoVendor:join(work,'dependencies/citizen_sdk/cargo-vendor/packages',name)}:{})}));}if(files('pub').length)Object.assign(result,await preparePub(files('pub'),join(target,'pub'),{...options,sources:name==='own'?owner.lockedSources():options.sources}));for(const file of files('cocoapods'))await preparePods(file,join(work,'dependencies'),options);receipt.dependencies[name]=result;
 }
 for(const item of requirement.archives){process.stderr.write('资源阶段：归档 '+item.group+'/'+item.name+'\n');if(!safePath(item.group))fail('归档分组无效');const file=await packageOriginal(item,options),directory=join(work,'dependencies/archives',item.group);await directoryCheck(directory).catch(async e=>{if(e.code!=='ENOENT')throw e;await directoryCheck(work);await mkdir(directory,{recursive:true});});const path=join(directory,item.sha256+'.blob');if(!await stat(path))await copyFile(file,path,constants.COPYFILE_EXCL);await regular(path);(receipt.archives[item.group]??=[]).push({...item,path});}
 const flutter=library.installed.get('flutter');if(flutter){const sdk=dirname(dirname(flutter.path));receipt.environment.DART_EXECUTABLE=join(sdk,'bin/cache/dart-sdk/bin/dart');const os=platform.endsWith('ios')?'ios':platform.endsWith('macos')?'macos':null;if(os&&!await stat(join(work,'flutter-tools'))){const delivery=await flutterRecipe.prepareFlutterTaskTools(sdk,work,os,{signal:options.signal,environment:{PRODUCT_BASH_BIN:library.installed.get('bash').path,PRODUCT_RSYNC_BIN:foundation.tools.rsync}});if(delivery.PATH)receipt.environment.PATH=delivery.PATH+':'+receipt.environment.PATH;}if(os)receipt.environment.PATH=join(work,'flutter-tools')+':'+receipt.environment.PATH;receipt.environment.PRODUCT_RSYNC_BIN=foundation.tools.rsync;receipt.environment.PRODUCT_BASH_BIN=library.installed.get('bash').path;}
 // 缓存工程视图先按本次源码重建，资源预解析不得执行已删除的旧构建输入。
 if(library.installed.has('gradle')&&await stat(join(work,'source-view')))await owner.prepare(platform,work,receipt,cleanEnvironment(environment));
 await prepareGradleResources(work,options,receipt.environment,owner.resourceEnvironment(platform,work,receipt,cleanEnvironment(environment)));options.signal?.throwIfAborted();if(JSON.stringify(request())!==JSON.stringify(requirement)){if((options.depth||0)>=8)fail('资源递归闭包超限');return materializeResources(platform,work,receipt,{...options,depth:(options.depth||0)+1});}owner.resourceEnvironment(platform,work,receipt,cleanEnvironment(environment));return receipt;
}
async function flutterGradleImplementation() {
// 产品只在本轮Flutter副本应用固定AGP 9修订；上游版本、原件和产品DSL不变。
// Copyright 2014 The Flutter Authors. All rights reserved.
// The upstream Gradle source fragments retain Flutter's BSD-style LICENSE.
const { createHash } = await import("node:crypto");
const { lstatSync, readFileSync, realpathSync } = await import("node:fs");
const { isAbsolute, join, resolve } = await import("node:path");
const { fileURLToPath } = await import("node:url");

const flutterCommit = 'd3b14c876900e553bc736ca19295fc09e3853e8e';
const gradleRecipes = Object.freeze([{"path":"packages/flutter_tools/gradle/build.gradle.kts","beforeSha256":"8bce67c561f7a91bb743b443242b8d804ddc4190dc5524278bdecf8797515008","afterSha256":"7438ec7066f34d2b597426a58105e831d677a4278cd3ee415587a9768678d667","hunks":[{"start":6,"after":["plugins {","    `java-gradle-plugin`","    groovy","    kotlin(\"jvm\") version \"2.2.20\"","    kotlin(\"plugin.sam.with.receiver\") version \"2.2.20\"","}","","// 保留Gradle Action的官方隐式接收者语义，编译插件与Kotlin使用同一版本。","samWithReceiver {","    annotation(\"org.gradle.api.HasImplicitReceiver\")","}","","group = \"dev.flutter.plugin\""],"beforeCount":8,"beforeSha256":"9864a2adea50b5ab74fbc1fb1900bfc9aff7c0e09702482d0a6d3ad8d4a16174"},{"start":49,"after":["}","","dependencies {","    // 使用固定Kotlin编译插件，不应用绑定Gradle内嵌Kotlin版本的kotlin-dsl插件。","    implementation(gradleKotlinDsl())","    // Versions available https://mvnrepository.com/artifact/androidx.annotation/annotation-jvm.","    // Version release notes https://developer.android.com/jetpack/androidx/releases/annotation","    compileOnly(\"androidx.annotation:annotation-jvm:1.9.1\")","    // When bumping, also update:","    //  * KGP error version in packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt","    implementation(\"org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20\")","    // Update to 1.8.0 when min kotlin is 2.1","    // https://github.com/Kotlin/kotlinx.serialization/releases for kotlin version compatibility.","    // All kotlinx implementation dependencies must work with the oldest kotlin supported versions."],"beforeCount":12,"beforeSha256":"604dec9c28c3c2e4cbb5b57947fceeda3ef62fcf213658edf397723b6c9c374e"},{"start":64,"after":["    //  * AGP version constants in packages/flutter_tools/lib/src/android/gradle_utils.dart","    //  * ndkVersion constant in packages/flutter_tools/lib/src/android/gradle_utils.dart","    //  * ndkVersion in FlutterExtension in packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt","    compileOnly(\"com.android.tools.build:gradle:9.0.1\")","","    testImplementation(kotlin(\"test\"))","    testImplementation(\"com.android.tools.build:gradle:9.0.1\")","    testImplementation(\"org.mockito:mockito-core:5.8.0\")","    testImplementation(\"io.mockk:mockk:1.13.16\")","}"],"beforeCount":10,"beforeSha256":"fd96b408a079615dbd8b75caf6bbf135a84d4872a21c1614fbdc19a685381ce5"}]},{"path":"packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt","beforeSha256":"a8ca02d55798c200d766e245dae9df20565cb9d638d4887b51bf617abac938a1","afterSha256":"383540448a0810cb60e7b6197455fdcf3bd1771720e82a42ed10e5af7e8b43b9","hunks":[{"start":44,"after":["     * Specifies the relative directory to the Flutter project directory.","     * In an app project, this is ../.. since the app's Gradle build file is under android/app.","     */","    // 本机任务在插件应用时即需准确源码根；标准Flutter工程继续使用官方相对路径。","    var source: String? = System.getenv(\"PRODUCT_SOURCE_DIR\") ?: \"../..\""],"beforeCount":4,"beforeSha256":"a6a5039fdaf04c6911cce31745fc9553118b68bcbfaa62ca3e4796d6a397997f"}]},{"path":"packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt","beforeSha256":"aba6c2f7331ea613227fed69666f8edb3839c09413188ccab64989dabe4bcd6f","afterSha256":"afc1c54599c2b8cacbf5d957a198b168106aa95b341a79243bc66e47e4201ed1","hunks":[{"start":6,"after":["import com.android.build.api.dsl.ApplicationExtension","import com.android.build.api.dsl.BuildType","import com.android.build.api.variant.AndroidComponentsExtension","import com.android.build.api.variant.ApplicationVariant","import com.android.build.api.variant.Variant","import com.android.build.api.variant.FilterConfiguration","import com.android.build.api.variant.BuiltArtifactsLoader","import com.android.build.api.artifact.SingleArtifact","import org.gradle.api.DefaultTask","import org.gradle.api.file.DirectoryProperty","import org.gradle.api.provider.Property","import org.gradle.api.tasks.Input","import org.gradle.api.tasks.InputDirectory","import org.gradle.api.tasks.OutputDirectory","import org.gradle.api.tasks.Internal","import org.gradle.api.tasks.TaskAction","import org.gradle.api.tasks.Sync","import com.flutter.gradle.FlutterPluginConstants.PLATFORM_ABI_LIST","import com.flutter.gradle.FlutterPluginUtils.readPropertiesIfExist","import com.flutter.gradle.plugins.PluginHandler"],"beforeCount":11,"beforeSha256":"9d1cfe233b1c21f67344d9f58a31eb37cb0dc3dd9d86bb5a6f55c3aca94f5ba8"},{"start":245,"after":["            }","            localEngineHost = engineHostOut.name","        }","        FlutterPluginUtils.getAndroidExtension(project).buildTypes.all {","            addFlutterDependencies(this)","        }","    }","","    private fun addFlutterDependencies(buildType: BuildType) {","        FlutterPluginUtils.addFlutterDependencies(","            project!!,","            buildType,"],"beforeCount":12,"beforeSha256":"2861c2e8a3da3140efb7933e5feeb1f64040edf74e01bee1749ac4a0a26682ee"},{"start":304,"after":["            FlutterPluginUtils.addTasksForOutputsAppLinkSettings(projectToAddTasksTo)","        }","","        val targetPlatforms = FlutterPluginUtils.getTargetPlatforms(projectToAddTasksTo)","        if (FlutterPluginUtils.isFlutterAppProject(projectToAddTasksTo)) {","            configureAbis(projectToAddTasksTo, FlutterPluginUtils.getAndroidApplicationExtension(projectToAddTasksTo))","        }","        // 同一个公开变体回调同时注册编译、资源与JNI，避免跨回调按名称猜测任务。","        val components = projectToAddTasksTo.extensions.getByType(AndroidComponentsExtension::class.java)","        components.onVariants { variant ->","            addFlutterDeps(variant, this, targetPlatforms)","        }","        getPluginHandler(projectToAddTasksTo).configurePlugins(engineVersion!!)","        FlutterPluginUtils.detectLowCompileSdkVersionOrNdkVersion(","            projectToAddTasksTo,"],"beforeCount":203,"beforeSha256":"9b44216a3c13ab110ccf6cb30703a78c3a6124c086d9583f912f2533814a8606"},{"start":599,"after":["            }","        }","","        // 只消费AGP公开变体，不读取内部打包任务或已删除的变体接口。","        private fun addFlutterDeps(","            variant: Variant,","            flutterPlugin: FlutterPlugin,","            targetPlatforms: List<String>","        ): Unit {","            // Shorthand","            val project: Project = flutterPlugin.project!!",""],"beforeCount":26,"beforeSha256":"7badcf6303290de6984c79cb9cde1bcc34a4516e44987111cba18f2ed614824e"},{"start":653,"after":["            val validateDeferredComponentsValue: Boolean =","                project.findProperty(\"validate-deferred-components\")?.toString()?.toBoolean() ?: true","","            val buildType = FlutterPluginUtils.getAndroidExtension(project).buildTypes.getByName(requireNotNull(variant.buildType))","            val variantBuildMode = FlutterPluginUtils.buildModeFor(buildType)","            val flavorValue = variant.flavorName.orEmpty()","            if (!FlutterPluginUtils.supportsBuildMode(project, variantBuildMode)) return","            if (variant is ApplicationVariant && FlutterPluginUtils.shouldProjectSplitPerAbi(project)) {","                variant.outputs.forEach { output ->","                    val abi = output.filters.firstOrNull { it.filterType == FilterConfiguration.FilterType.ABI }?.identifier","                    val abiVersionCode = FlutterPluginConstants.ABI_VERSION[abi]","                    if (abiVersionCode != null && !FlutterPluginUtils.shouldForceVersionCodeIgnoringAbi(project)) {","                        output.versionCode.set(output.versionCode.get() + abiVersionCode * 1000)","                    }","                }","            }","            val taskName: String = flutterCompileTaskName(variant.name)","            // The task provider below will shadow a lot of the variable names, so provide this reference","            // to access them within that scope."],"beforeCount":51,"beforeSha256":"eca69a129c06c4722fdd782d4e4195d1fb14a15a2c7f82108ccd9047d09d1514"},{"start":713,"after":["                    flutterRoot = flutterPlugin.flutterRoot","                    flutterExecutable = flutterPlugin.flutterExecutable","                    buildMode = variantBuildMode","                    minSdkVersion = variant.minSdk.apiLevel","                    localEngine = flutterPlugin.localEngine","                    localEngineHost = flutterPlugin.localEngineHost","                    localEngineSrcPath = flutterPlugin.localEngineSrcPath"],"beforeCount":7,"beforeSha256":"6356ee8a218ccec165aae916f5a08263d40f48a07b34fe5bf755459070133f3b"},{"start":741,"after":["                    validateDeferredComponents = validateDeferredComponentsValue","                    flavor = flavorValue","                }","            // 生成目录经Sources API交给AGP，资源/JNI消费者自动获得准确任务依赖。","            val assets = project.tasks.register(","                \"copyFlutterAssets\" + FlutterPluginUtils.capitalize(variant.name),","                FlutterAssetsTask::class.java","            ) {","                dependsOn(compileTaskProvider)","                from(compileTaskProvider.map { File(requireNotNull(it.outputDirectory), \"flutter_assets\") }) { into(\"flutter_assets\") }","                destinationDirectory.set(project.layout.buildDirectory.dir(\"intermediates/flutter-assets/\" + variant.name))","                into(destinationDirectory)","            }","            variant.sources.assets?.addGeneratedSourceDirectory(assets, FlutterAssetsTask::destinationDirectory)","                ?: throw GradleException(\"Android variant has no assets sources: \" + variant.name)","            val jni = project.tasks.register(","                \"copyJniLibs\" + FLUTTER_BUILD_PREFIX + FlutterPluginUtils.capitalize(variant.name),","                CopyFlutterJniLibsTask::class.java","            ) {","                dependsOn(compileTaskProvider)","                intermediateDir.set(project.layout.dir(compileTaskProvider.map { requireNotNull(it.outputDirectory) }))","                this.targetPlatforms.set(targetPlatforms)","            }","            variant.sources.jniLibs?.addGeneratedSourceDirectory(jni, CopyFlutterJniLibsTask::destinationDir)","                ?: throw GradleException(\"Android variant has no JNI sources: \" + variant.name)","            if (variant is ApplicationVariant) {","                val copyApk = project.tasks.register(","                    \"copyFlutterApk\" + FlutterPluginUtils.capitalize(variant.name), FlutterApkTask::class.java","                ) {","                    inputDirectory.set(variant.artifacts.get(SingleArtifact.APK))","                    destinationDirectory.set(project.layout.buildDirectory.dir(\"outputs/flutter-apk\"))","                    loader.set(variant.artifacts.getBuiltArtifactsLoader())","                    buildMode.set(variantBuildMode)","                    flavor.set(flavorValue)","                }","                // assemble是公开生命周期入口；APK位置与文件清单由Artifacts API提供。","                project.tasks.matching { it.name == \"assemble\" + FlutterPluginUtils.capitalize(variant.name) }","                    .configureEach { dependsOn(copyApk) }","            }","        }","    }",""],"beforeCount":76,"beforeSha256":"b7d12bc740b50d79f8bfecf1e970595a3d0c56a1b1cc61949b73d7bf8db1a061"},{"start":822,"after":["     */","    private fun isInvokedFromAndroidStudio(): Boolean = project?.hasProperty(\"android.injected.invoked.from.ide\") == true","}","","/** 公开资源生成任务：每个变体独占输出，禁止直接写入AGP内部合并目录。 */","abstract class FlutterAssetsTask : Sync() {","    @get:OutputDirectory","    abstract val destinationDirectory: DirectoryProperty","}","","/** 从AGP正式输出清单发现APK，不按内部任务类或固定文件位置猜测。 */","abstract class FlutterApkTask : DefaultTask() {","    @get:InputDirectory","    abstract val inputDirectory: DirectoryProperty","    @get:OutputDirectory","    abstract val destinationDirectory: DirectoryProperty","    @get:Internal","    abstract val loader: Property<BuiltArtifactsLoader>","    @get:Input","    abstract val buildMode: Property<String>","    @get:Input","    abstract val flavor: Property<String>","","    @TaskAction","    fun copyApks() {","        val artifacts = requireNotNull(loader.get().load(inputDirectory.get())) { \"APK metadata is missing\" }","        val output = destinationDirectory.get().asFile","        output.mkdirs()","        artifacts.elements.forEach { artifact ->","            val abi = artifact.filters.firstOrNull { it.filterType == FilterConfiguration.FilterType.ABI }?.identifier","            val name = listOfNotNull(\"app\", abi, flavor.get().takeIf { it.isNotEmpty() }?.lowercase(), buildMode.get()).joinToString(\"-\")","            File(artifact.outputFile).copyTo(File(output, name + \".apk\"), overwrite = true)","        }","    }","}"],"beforeCount":3,"beforeSha256":"22722626e876d2bc2d93e7076b51fad1398ce730061c59385098317b0afa3ee2"}]},{"path":"packages/flutter_tools/gradle/src/main/kotlin/FlutterPluginUtils.kt","beforeSha256":"92f05b75bae280223c3cea04fceb8c7860c65a6b464399a5a51d71dfe90f0c05","afterSha256":"8c22286256d2ee68c5b27f60854d74df56f07de9f1cb77423cd3193aa43c8f58","hunks":[{"start":6,"after":["import com.android.build.api.AndroidPluginVersion","import com.android.build.api.artifact.SingleArtifact","import com.android.build.api.dsl.ApplicationExtension","import com.android.build.api.dsl.ApplicationBuildType","import com.android.build.api.dsl.LibraryExtension","import com.android.build.api.variant.AndroidComponentsExtension","import com.android.build.api.dsl.CommonExtension","import com.android.build.api.dsl.BuildType","import com.flutter.gradle.plugins.PluginHandler","import com.flutter.gradle.tasks.DeepLinkJsonFromManifestTask","import com.flutter.gradle.tasks.PrintTask"],"beforeCount":10,"beforeSha256":"3ca5b943fdd5390a6e3ad12ba16efea3c76a9062a369dc9d84cd8abfa250d560"},{"start":471,"after":["    internal fun buildModeFor(buildType: BuildType): String {","        if (buildType.name == \"profile\") {","            return \"profile\"","        } else if ((buildType is ApplicationBuildType && buildType.isDebuggable) || buildType.name == \"debug\") {","            return \"debug\"","        }","        return \"release\""],"beforeCount":7,"beforeSha256":"d4a2d1e97d1c8d0e7d9ffc6ca2fc6ce6566bb2a61ce39df573fe2a9732cdb9c6"},{"start":497,"after":["        return project.property(PROP_LOCAL_ENGINE_BUILD_MODE) == flutterBuildMode","    }","","    // AGP9公共DSL统一入口；没有Android扩展必须立即报错。","    internal fun getAndroidExtension(project: Project): CommonExtension =","        project.extensions.getByType(CommonExtension::class.java)","","    internal fun getAndroidLibraryExtension(project: Project): LibraryExtension = project.extensions.getByType(LibraryExtension::class.java)","","    internal fun getAndroidApplicationExtension(project: Project): ApplicationExtension =","        project.extensions.getByType(ApplicationExtension::class.java)","","    internal fun getConfiguredNdkVersion(project: Project): String? = getAndroidExtension(project).ndkVersion","","    @JvmStatic","    @JvmName(\"getCompileSdkFromProject\")","    internal fun getCompileSdkFromProject(project: Project): String {","        val android = getAndroidExtension(project)","        return android.compileSdkPreview ?: requireNotNull(android.compileSdk).toString()","    }","","    /**","     * Returns:"],"beforeCount":48,"beforeSha256":"b69717773555f4edb52075408c1e28040865b64513cf909442180c04c7f8661a"},{"start":793,"after":["        }","","        // If the project is already configuring a native build, we don't need to do anything.","        val gradleProjectAndroidExtension = getAndroidExtension(gradleProject)","        val forcingNotRequired: Boolean =","            gradleProjectAndroidExtension.externalNativeBuild.cmake.path != null","        if (forcingNotRequired) {"],"beforeCount":7,"beforeSha256":"f077eef16d0dbffd330253cc3c4dcf1fba6ff65b6894e294e470f79328e04dc2"},{"start":919,"after":["        gradleProject: Project,","        flutterSdkRootPath: String","    ) {","        val gradleProjectAndroidExtension = getAndroidExtension(gradleProject)","        gradleProjectAndroidExtension.externalNativeBuild.cmake.path(","            \"$flutterSdkRootPath/packages/flutter_tools/gradle/src/main/scripts/CMakeLists.txt\"","        )"],"beforeCount":7,"beforeSha256":"d9ffcc93e126bf54cd3a7a04e4cbe8f6e092a6e24e5065e8a86fff35a6ac922b"}]},{"path":"packages/flutter_tools/gradle/src/main/kotlin/VersionFetcher.kt","beforeSha256":"46dc5b89b2ce5a7554c0b21c52f8ef25cbe0fed25958dd84f8328998b7df75e6","afterSha256":"4d1f77d630b102da5155c716ab0959e1e2dbdc72a02d1b59f66cbcc27bc28c5a","hunks":[{"start":5,"after":["","import com.android.build.api.AndroidPluginVersion","import com.android.build.api.variant.AndroidComponentsExtension","import org.gradle.api.JavaVersion","import org.gradle.api.Project","import org.jetbrains.kotlin.gradle.plugin.getKotlinPluginVersion","","internal object VersionFetcher {","    /**"],"beforeCount":10,"beforeSha256":"b0ec52e151d787ba9796f13900c4c1083d84d72261274120439ca5ac049069ee"},{"start":44,"after":["     * Returns the version of the Kotlin Gradle plugin.","     */","    internal fun getKGPVersion(project: Project): Version? {","        // 回读实际加载的KGP资源版本，不以声明版本或Gradle内嵌编译器冒充。","        return Version.fromString(project.getKotlinPluginVersion())","    }","}",""],"beforeCount":43,"beforeSha256":"6f356dcfd1ced7e3e495069e671d0221bc5adc8d83e79226c35644bf9272c57d"}]},{"path":"packages/flutter_tools/gradle/src/main/kotlin/plugins/PluginHandler.kt","beforeSha256":"2e0aabbee4b6699ded8fb75fa38347d1fe6d1c719051a2177bfc6ea7595b4817","afterSha256":"cbebdcdb654a74d32901f0f6faee04e635c4914ef5826b43308393e547e52cf8","hunks":[{"start":3,"after":["","package com.flutter.gradle.plugins","","import com.android.build.api.dsl.BuildType","import com.android.build.api.dsl.ApplicationBuildType","import com.flutter.gradle.FlutterExtension","import com.flutter.gradle.FlutterPluginUtils","import com.flutter.gradle.FlutterPluginUtils.addApiDependencies","import com.flutter.gradle.FlutterPluginUtils.buildModeFor","import com.flutter.gradle.FlutterPluginUtils.getCompileSdkFromProject","import com.flutter.gradle.FlutterPluginUtils.getAndroidExtension","import com.flutter.gradle.FlutterPluginUtils.isBuiltAsApp","import com.flutter.gradle.FlutterPluginUtils.supportsBuildMode","import com.flutter.gradle.NativePluginLoaderReflectionBridge"],"beforeCount":13,"beforeSha256":"8d1af3ee2223f5844b86cbe220c0fc728b82c829a4d4de109d5c30ee7a9a7e93"},{"start":17,"after":["import org.gradle.api.Project","import org.jetbrains.kotlin.gradle.plugin.extraProperties","import java.io.File","import java.nio.file.Files","","/**"," * Handles interactions with the flutter plugins (not Gradle plugins) used by the Flutter project,"],"beforeCount":7,"beforeSha256":"77da85363c7f673162cb9135cb4d02326a66f591a41f6e01ca308d93655bf978"},{"start":86,"after":["         */","        private const val WEBSITE_DEPLOYMENT_ANDROID_BUILD_CONFIG = \"https://flutter.dev/to/review-gradle-config\"","","        private fun prepareBuiltInKotlinPluginScript(pluginProject: Project) {","            val pubCache = System.getenv(\"PUB_CACHE\") ?: return","            val buildFile = pluginProject.buildFile","            if (buildFile.extension !in setOf(\"kts\", \"gradle\") || !buildFile.isFile || Files.isSymbolicLink(buildFile.toPath())) return","            val hostedRoot = File(pubCache, \"hosted\").canonicalFile.toPath()","            val buildPath = buildFile.canonicalFile.toPath()","            if (!buildPath.startsWith(hostedRoot)) return","            val input = buildFile.readText()","            val kotlinPlugin =","                Regex(\"\"\"(?m)^\\s*(?:id\\(\\s*[\"'](?:kotlin-android|org\\.jetbrains\\.kotlin\\.android)[\"']\\s*\\)(?:\\s+version\\s+[\"'][^\"']+[\"'])?|id\\s+[\"'](?:kotlin-android|org\\.jetbrains\\.kotlin\\.android)[\"']|kotlin\\(\\s*[\"']android[\"']\\s*\\)(?:\\s+version\\s+[\"'][^\"']+[\"'])?|apply\\(\\s*plugin\\s*=\\s*[\"'](?:kotlin-android|org\\.jetbrains\\.kotlin\\.android)[\"']\\s*\\)|apply\\s+plugin:\\s*[\"'](?:kotlin-android|org\\.jetbrains\\.kotlin\\.android)[\"'])\\s*$\"\"\")","            val kotlinClasspath =","                Regex(\"\"\"(?m)^\\s*(?:classpath\\(\\s*[\"']org\\.jetbrains\\.kotlin:kotlin-gradle-plugin:[^\"']+[\"']\\s*\\)|classpath\\s+[\"']org\\.jetbrains\\.kotlin:kotlin-gradle-plugin:[^\"']+[\"'])\\s*$\"\"\")","            val agpClasspath =","                Regex(\"\"\"(?m)^(\\s*)(?:classpath\\(\\s*[\"']com\\.android\\.tools\\.build:gradle:[^\"']+[\"']\\s*\\)|classpath\\s+[\"']com\\.android\\.tools\\.build:gradle:[^\"']+[\"'])\\s*$\"\"\")","            if (!kotlinPlugin.containsMatchIn(input) && !kotlinClasspath.containsMatchIn(input) && !agpClasspath.containsMatchIn(input)) return","            // 只修改任务PUB_CACHE副本；插件模块统一使用AGP 9.0.1内置Kotlin，不再重复应用KGP。","            buildFile.writeText(","                input","                    .replace(kotlinPlugin, \"\")","                    .replace(kotlinClasspath, \"\")","                    .replace(agpClasspath, if (buildFile.extension == \"kts\") \"\\$1classpath(\\\"com.android.tools.build:gradle:9.0.1\\\")\" else \"\\$1classpath 'com.android.tools.build:gradle:9.0.1'\")","            )","        }","","        /**","         * Performs configuration related to the plugin's Gradle [Project], including","         * 1. Adding the plugin itself as a dependency to the main project."],"beforeCount":6,"beforeSha256":"9812cb4bc172b698dc457a90147633af37d47c0655e9295917fa5f53e954b2ce"},{"start":103,"after":["                requireNotNull(pluginObject[\"name\"] as? String) { \"Plugin name must be a string for plugin object: $pluginObject\" }","            val pluginProject: Project = project.rootProject.findProject(\":$pluginName\") ?: return","","            // Kotlin DSL compiles each plugin script with that plugin's buildscript classpath.","            // Publish the extension type there before evaluation so generated accessors stay typed.","            prepareBuiltInKotlinPluginScript(pluginProject)","            val flutterPluginClasspath = FlutterExtension::class.java.protectionDomain.codeSource.location.toURI()","            pluginProject.buildscript.dependencies.add(\"classpath\", pluginProject.files(flutterPluginClasspath))","","            // Apply the \"flutter\" Gradle extension to plugins so that they can use it's vended","            // compile/target/min sdk values.","            pluginProject.pluginManager.withPlugin(\"com.android.library\") {","                val pluginFlutterExtensionClass =","                    pluginProject.buildscript.classLoader.loadClass(FlutterExtension::class.java.name)","                pluginProject.extensions.create(\"flutter\", pluginFlutterExtensionClass)","            }","","            // Add plugin dependency to the app project. We only want to add dependency","            // for dev dependencies in non-release builds.","            project.afterEvaluate {","                getAndroidExtension(project).buildTypes.forEach { buildType ->","                    if (!(pluginObject[\"dev_dependency\"] as Boolean) || buildType.name != \"release\") {","                        // AGP 9应用模块必须进入运行时类路径；library模块保留API传递给宿主。","                        val dependencyScope = if (isBuiltAsApp(project)) \"Implementation\" else \"Api\"","                        project.dependencies.add(\"${buildType.name}$dependencyScope\", pluginProject)","                    }","                }","            }"],"beforeCount":16,"beforeSha256":"2c535e52291240b97a869e7b0c3d629fe79404676b61114f27d3343f4753ccf7"},{"start":134,"after":["                    )","                }","","                getAndroidExtension(project).buildTypes.forEach { buildType ->","                    addEmbeddingDependencyToPlugin(project, pluginProject, buildType, engineVersion)","                }","            }"],"beforeCount":7,"beforeSha256":"462417afc307f736dba022e30a8162b50d3f06e012b1f75983fd86b6eaa681e1"},{"start":163,"after":["            // This allows to build apps with plugins and custom build types or flavors.","            // However, only copy if the plugin is also an app project, since library projects","            // cannot have applicationIdSuffix and other app-specific properties.","            // 库模块只复制公开的共同属性，不把应用专属属性写入库扩展。","            getAndroidExtension(project).buildTypes.forEach { appBuildType ->","                val target = getAndroidExtension(pluginProject).buildTypes.maybeCreate(appBuildType.name)","                if (target is ApplicationBuildType && appBuildType is ApplicationBuildType) {","                    target.isDebuggable = appBuildType.isDebuggable","                }","                // Library插件不能先被R8裁空；仅应用插件继承宿主的压缩设置。","                target.isMinifyEnabled = isBuiltAsApp(pluginProject) && appBuildType.isMinifyEnabled","            }","            // The embedding is API dependency of the plugin, so the AGP is able to desugar","            // default method implementations when the interface is implemented by a plugin.","            //"],"beforeCount":23,"beforeSha256":"0b465c5a40b1d23d948890a1f73f1956d889bdb73bea373401d3ce6c56ceba46"},{"start":214,"after":["                }","            val pluginProject: Project = project.rootProject.findProject(\":$pluginName\") ?: return","","            getAndroidExtension(project).buildTypes.forEach { buildType ->","                val flutterBuildMode: String = buildModeFor(buildType)","                if (flutterBuildMode == \"release\" && (pluginObject[\"dev_dependency\"] as? Boolean == true)) {","                    // This plugin is a dev dependency will not be included in the"],"beforeCount":7,"beforeSha256":"4fa9a1c03c068b4b06714d3a467e35df6b473b693db4d33a50f68bffd27fe633"}]}]);
const sha256 = value => createHash('sha256').update(value).digest('hex');
function fail(message) { throw new Error('Flutter AGP 9修订失败：' + message); }

// 每个上下文、前后完整摘要都必须一致；旧片段仅登记摘要，不复制已删除的上游实现。
// 先形成整批计划；任何未知输入都不得写入，其余源文件保留上游版权与许可。
function revisedSource(input,recipe){
 const lines=input.split('\n');let offset=0;
 const applied=recipe.hunks.every(hunk=>{const start=hunk.start+offset;offset+=hunk.after.length-hunk.beforeCount;return JSON.stringify(lines.slice(start,start+hunk.after.length))===JSON.stringify(hunk.after);});
 if(applied)return input;
 const output=[];let at=0;
 for(const hunk of recipe.hunks){if(!Number.isSafeInteger(hunk.start)||hunk.start<at||!Number.isSafeInteger(hunk.beforeCount)||hunk.beforeCount<0||hunk.start+hunk.beforeCount>lines.length)fail('修订区块越界：'+recipe.path);output.push(...lines.slice(at,hunk.start),...hunk.after);at=hunk.start+hunk.beforeCount;}
 output.push(...lines.slice(at));return output.join('\n');
}

function revisionPlan(root, recipes = gradleRecipes) {
  if (!isAbsolute(root) || resolve(root) !== root || realpathSync(root) !== root) fail('工具根不是真实绝对目录');
  const paths = new Set();
  return recipes.map(recipe => {
    if (!recipe.path.startsWith('packages/flutter_tools/gradle/') || recipe.path.includes('..')
      || paths.has(recipe.path)) fail('修订路径越界或重复');
    paths.add(recipe.path);
    const path = join(root, recipe.path);
    const info = lstatSync(path);
    if (!info.isFile() || info.isSymbolicLink() || realpathSync(path) !== path) fail('修订输入不是普通文件');
    return { path, content: revisedSource(readFileSync(path, 'utf8'), recipe) };
  });
}

return {flutterCommit,gradleRecipes,revisedSource,revisionPlan};
}
const flutterGradle = await flutterGradleImplementation();
const {flutterCommit,gradleRecipes,revisedSource,revisionPlan} = flutterGradle;



function assertWorkQuiescent(work){for(const pid of supplyGroups.get(work)||[])try{process.kill(-pid,0);fail('资源工具退出未确认');}catch(error){if(error.code!=='ESRCH')throw error;}if(retainedResourcePath(work))fail('资源工具退出未确认');}



// 资源回归统一随正式实现归档；仅本文件被明确选为测试入口时加载测试工具。
if(inlineTestEntry)inlineTestRegistrations.push(async()=>{
 const {test}=await import('node:test');
 const {default:assert}=await import('node:assert/strict');
 const {createHash}=await import('node:crypto');
 const {mkdtemp,realpath,mkdir,readFile,writeFile,readdir,rm,symlink,chmod,lstat,rename}=await import('node:fs/promises');
 const {dirname,join,resolve}=await import('node:path');
 const tmpdir=buildTestRoot,contract=buildContract;
 const {spawnSync}=await import('node:child_process');
 const {gzipSync}=await import('node:zlib');
const hash=b=>createHash('sha256').update(b).digest('hex');
async function sandbox(t){const root=await realpath(await fixedScratch(join(tmpdir(),contract.product_id+'-resources-')));t.after(()=>rm(root,{recursive:true,force:true}));return root;}
const archive=(body,url='https://example.invalid/locked.tgz')=>({url,sha256:hash(body)});
function tar(entries){const records=[];for(const {name,body='',type='0',target='',mtime=0}of entries){const b=Buffer.from(body),h=Buffer.alloc(512);h.write(name,0,100);h.write('0000644\0',100);h.write('0000000\0',108);h.write('0000000\0',116);h.write(b.length.toString(8).padStart(11,'0')+'\0',124);h.write(mtime.toString(8).padStart(11,'0')+'\0',136);h.fill(32,148,156);h.write(type,156);h.write(target,157,100);h.write('ustar\0',257);h.write('00',263);h.write([...h].reduce((a,b)=>a+b,0).toString(8).padStart(6,'0')+'\0 ',148);records.push(h,b,Buffer.alloc((512-b.length%512)%512));}return gzipSync(Buffer.concat([...records,Buffer.alloc(1024)]));}
test('Rust宿主组件与官方清单一致，缺必需项、重复、非法及过大清单拒绝',()=>{
 const required=['rustc','cargo','rust-std-aarch64-apple-darwin','rustfmt-preview','clippy-preview'];
 assert.deepEqual(rustHostComponentPlan([...required,'rust-docs','rust-analyzer-preview'].join('\n')+'\n'),required);
 assert.equal(rustHostComponentPlan(required.join('\r\n')).includes('rust-src'),false);
 for(const missing of required)assert.throws(()=>rustHostComponentPlan(required.filter(name=>name!==missing).join('\n')),/缺少必需组件/);
 for(const text of ['',required.join('\n')+'\nrustc',required.join('\n')+'\n../outside','x'.repeat(65537)])assert.throws(()=>rustHostComponentPlan(text),/组件清单/);
});
test('Rust安装保留全部目标标准库和原参数，缺件、失败及取消不跳过',async t=>{
 const root=await sandbox(t),source=join(root,'source');await mkdir(source);
 const manifest=join(source,'components'),valid='rustc\ncargo\nrust-std-aarch64-apple-darwin\nrustfmt-preview\nclippy-preview\n';await writeFile(manifest,valid);
 const tool=toolDefinitions.find(item=>item.id==='rust'),events=[],signal=new AbortController().signal;
 const input={source,payload:join(root,'payload'),canonical:root,tool,library:{root:join(root,'library'),work:root},foundation:{tools:{bash:join(root,'bash')}},environment:{PATH:root},options:{offline:true,signal,fetcher:()=>assert.fail('夹具联网')}};
 const simulation={
  acquire:async(component,options)=>{assert.equal(options.offline,true);assert.equal(options.signal,signal);events.push(['acquire',component.target]);return join(root,component.target+'.tar.xz');},
  extract:async(file,dir,options)=>{assert.equal(options.signal,signal);events.push(['extract',dir]);},
  run:async(command,args,options)=>{assert.equal(command,input.foundation.tools.bash);assert.equal(options.maxBuffer,2*1024**2);assert.equal(options.timeout,300000);assert.equal(options.signal,signal);assert.equal(options.env,input.environment);events.push(['run',args]);}
 };
 await installRustTool(input,simulation);const runs=events.filter(event=>event[0]==='run');
 assert.deepEqual(runs[0][1],[join(source,'install.sh'),'--prefix='+input.payload,'--disable-ldconfig','--components=rustc,cargo,rust-std-aarch64-apple-darwin,rustfmt-preview,clippy-preview']);
 assert.deepEqual(events.filter(event=>event[0]==='acquire').map(event=>event[1]),tool.components.map(component=>component.target));
 assert.equal(runs.length,1+tool.components.length);
 for(const [index,component]of tool.components.entries())assert.deepEqual(runs[index+1][1],[join(root,component.target,component.root,'install.sh'),'--prefix='+input.payload,'--disable-ldconfig']);
 events.length=0;await writeFile(manifest,'rustc\n');await assert.rejects(installRustTool(input,simulation),/缺少必需组件/);assert.equal(events.length,0);
 await writeFile(manifest,valid);const failure=Error('synthetic target install failed');let calls=0;
 await assert.rejects(installRustTool(input,{...simulation,run:async()=>{if(++calls===3)throw failure;}}),error=>error===failure);assert.equal(calls,3);
 await assert.rejects(installRustTool({...input,options:{...input.options,signal:AbortSignal.abort()}},simulation),/abort/iu);
});
test('按声明取得原件，复用路径不重新校验字节',async t=>{
 const root=await sandbox(t),entry=archive(Buffer.from('declared'));let requests=0;
 const options={store:root,fetcher:async()=>{requests++;return new Response('supplied');}};
 const file=await acquireArchive(entry,options);await chmod(file,0o600);await writeFile(file,'changed');
 assert.equal(await acquireArchive(entry,{...options,offline:true,fetcher:()=>assert.fail('离线联网')}),file);
 assert.equal(await readFile(file,'utf8'),'changed');assert.equal(requests,1);
});
test('取消自建摘要验真，离线缺件、非HTTPS和下载失败仍报错',async t=>{
 const root=await sandbox(t),entry=archive(Buffer.from('declared'));
 await assert.rejects(acquireArchive(entry,{store:root,offline:true}),/离线/);
 const url=new URL(entry.url);url.protocol='http:';
 await assert.rejects(acquireArchive({...entry,url:url.href},{store:root,fetcher:()=>assert.fail('明文联网')}),/HTTPS/);
 await assert.rejects(acquireArchive(entry,{store:root,fetcher:async()=>new Response('',{status:503})}),/获取失败/);
 const file=await acquireArchive(entry,{store:root,fetcher:async()=>new Response('delivered')});assert.equal(await readFile(file,'utf8'),'delivered');
});

test('资源每跳请求identity，保留HTTPS重定向和无编码等长校验',async t=>{
 const root=await sandbox(t),body=Buffer.from('identity archive'),entry=archive(body),calls=[];
 const file=await acquireArchive(entry,{store:join(root,'store'),work:root,fetcher:async(url,options)=>{
  calls.push(url);assert.equal(new Headers(options.headers).get('accept-encoding'),'identity');assert.equal(options.redirect,'manual');
  return calls.length===1?new Response(null,{status:302,headers:{location:'https://example.invalid/final.tgz'}}):new Response(body,{headers:{'content-length':String(body.length)}});
 }});
 assert.deepEqual(calls,[entry.url,'https://example.invalid/final.tgz']);assert.deepEqual(await readFile(file),body);
 await assert.rejects(acquireArchive({...entry,url:'https://example.invalid/downgrade'},{store:join(root,'downgrade'),work:root,fetcher:async()=>new Response(null,{status:302,headers:{location:'http://example.invalid/plain'}})}),/HTTPS/);
 let redirects=0;await assert.rejects(acquireArchive({...entry,url:'https://example.invalid/loop'},{store:join(root,'loop'),work:root,fetcher:async()=>{redirects++;return new Response(null,{status:307,headers:{location:'/loop'}});}}),/重定向超限/);assert.equal(redirects,6);
});
test('压缩传输长度不与Fetch已解码正文混比',async t=>{
 const root=await sandbox(t),body=Buffer.alloc(1000,97),wire=gzipSync(body);assert.notEqual(wire.length,body.length);
 // Response夹具模拟Fetch已完成解码的正文与保留的传输头，不在下载器另做解压。
 const file=await acquireArchive(archive(body),{store:join(root,'store'),work:root,maxBytes:2048,fetcher:async(url,options)=>{
  assert.equal(new Headers(options.headers).get('accept-encoding'),'identity');return new Response(body,{headers:{'content-encoding':' GZip ','content-length':String(wire.length)}});
 }});
 assert.deepEqual(await readFile(file),body);assert.deepEqual(await readdir(join(root,'resource-pending')),[]);
});
test('无编码及identity长度不符仍拒绝且不提交原件',async t=>{
 const root=await sandbox(t),body=Buffer.from('plain');
 for(const [index,encoding]of ['', 'identity',' Identity '].entries()){
  const store=join(root,String(index)),headers={'content-length':String(body.length+1)};if(encoding)headers['content-encoding']=encoding;
  await assert.rejects(acquireArchive(archive(body),{store,work:root,fetcher:async()=>new Response(body,{headers})}),/数据不完整/);
  assert.deepEqual(await readdir(store),[]);assert.deepEqual(await readdir(join(root,'resource-pending')),[]);
 }
});
test('压缩响应仍拒绝声明超限、解码正文超限及空正文',async t=>{
 const root=await sandbox(t);
 for(const [index,body,length,error]of [[0,'a',9,/声明超限/],[1,'123456789',2,/数据超限/],[2,'',1,/数据为空/]]){
  const store=join(root,String(index));await assert.rejects(acquireArchive(archive(Buffer.from(body)),{store,work:root,maxBytes:8,fetcher:async()=>new Response(body,{headers:{'content-encoding':'gzip','content-length':String(length)}})}),error);
  assert.deepEqual(await readdir(store),[]);
 }
 assert.deepEqual(await readdir(join(root,'resource-pending')),[]);
});
test('下载诊断标明工具、当前来源主机及已收字节，保留超时原异常且不回显URL或错误正文',async t=>{
 const root=await sandbox(t),store=join(root,'store'),marker='synthetic-diagnostic-marker',records=[];
 const failure=Object.assign(Error(marker),{cause:Object.assign(Error(marker),{code:'ETIMEDOUT'})});
 const entry=archive(Buffer.from('partial'),'https://example.invalid/archive?authorization='+marker);
 const fetcher=async(_url,options)=>{assert.equal(options.redirect,'manual');assert.equal(options.headers['accept-encoding'],'identity');return {ok:true,status:200,headers:new Headers(),body:{async *[Symbol.asyncIterator](){yield Buffer.from('partial');throw failure;},async cancel(){}}};};
 await assert.rejects(resourceSupplies.run({work:root,downloadDiagnostic:record=>records.push(record)},()=>acquireArchive(entry,{store,work:root,toolId:'java',fetcher})),error=>error===failure);
 assert.deepEqual(records[0],{stage:'request',tool:'java',host:'example.invalid',received_bytes:0,code:'none'});
 assert.deepEqual(records.at(-1),{stage:'body',tool:'java',host:'example.invalid',received_bytes:7,code:'ETIMEDOUT'});
 assert.equal(JSON.stringify(records).includes(marker),false);assert.equal(JSON.stringify(records).includes('/archive'),false);
 assert.deepEqual(await readdir(store),[]);assert.deepEqual(await readdir(join(root,'resource-pending')),[]);
});
test('下载诊断覆盖HTTP拒绝、TLS、重定向来源和取消，缓存复用不伪报下载',async t=>{
 const root=await sandbox(t),entry=archive(Buffer.from('ok')),records=[];
 const scope=action=>resourceSupplies.run({work:root,downloadDiagnostic:record=>records.push(record)},action);
 await assert.rejects(scope(()=>acquireArchive(entry,{work:root,store:join(root,'http'),fetcher:async()=>new Response('',{status:503})})),/获取失败/);
 assert.equal(records.at(-1).stage,'response');assert.equal(records.at(-1).code,'HTTP_503');
 const tls=Object.assign(Error('synthetic TLS detail'),{cause:{code:'ERR_TLS_CERT_ALTNAME_INVALID'}});
 await assert.rejects(scope(()=>acquireArchive(entry,{work:root,store:join(root,'tls'),toolId:'git',fetcher:async()=>{throw tls;}})),error=>error===tls);
 assert.equal(records.at(-1).code,'ERR_TLS_CERT_ALTNAME_INVALID');assert.equal(records.at(-1).received_bytes,0);
 let calls=0;await assert.rejects(scope(()=>acquireArchive(entry,{work:root,store:join(root,'redirect'),fetcher:async()=>++calls===1?new Response(null,{status:302,headers:{location:'https://cdn.example.invalid/file?signature=synthetic-query'}}):Promise.reject(tls)})),error=>error===tls);
 assert.equal(calls,2);assert.equal(records.at(-1).host,'cdn.example.invalid');assert.equal(JSON.stringify(records).includes('synthetic-query'),false);
 const abort=new AbortController();
 await assert.rejects(scope(()=>acquireArchive(entry,{work:root,store:join(root,'cancel'),signal:abort.signal,fetcher:async()=>({ok:true,status:200,headers:new Headers(),body:{async *[Symbol.asyncIterator](){yield Buffer.from('ok');abort.abort();},async cancel(){}}})})),/abort/iu);
 assert.equal(records.at(-1).code,'ABORT_ERR');assert.equal(records.at(-1).received_bytes,2);
 const cache=join(root,'cache');await scope(()=>acquireArchive(entry,{work:root,store:cache,fetcher:async()=>new Response('ok')}));records.length=0;
 await scope(()=>acquireArchive(entry,{work:root,store:cache,offline:true,fetcher:()=>assert.fail('缓存不联网')}));assert.deepEqual(records,[]);
 assert.equal(safeDiagnosticCode({code:'synthetic-private-marker'}),'UNKNOWN');assert.equal(safeDiagnosticCode({code:'ENOTFOUND'}),'ENOTFOUND');const cycle={};cycle.cause=cycle;assert.equal(safeDiagnosticCode(cycle),'UNKNOWN');
});
test('压缩响应流错误保留原异常并清除半包',async t=>{
 const root=await sandbox(t),store=join(root,'store'),failure=new Error('资源流夹具中断');let reads=0;
 const fetcher=async()=>new Response(new ReadableStream({pull(controller){if(reads++===0)controller.enqueue(Buffer.from('partial'));else controller.error(failure);}}),{headers:{'content-encoding':'gzip','content-length':'2'}});
 await assert.rejects(acquireArchive(archive(Buffer.from('partial')),{store,work:root,fetcher}),error=>error===failure);
 assert.deepEqual(await readdir(store),[]);assert.deepEqual(await readdir(join(root,'resource-pending')),[]);
});
test('取消下载清理本次候选；短锁只在提交阶段取得',async t=>{
 const root=await sandbox(t),entry=archive(Buffer.from('ab')),abort=new AbortController();
 const fetcher=async()=>new Response(new ReadableStream({start(controller){controller.enqueue(Buffer.from('a'));abort.abort();controller.close();}}));
 await assert.rejects(acquireArchive(entry,{store:root,fetcher,signal:abort.signal}));assert.deepEqual(await readdir(root),[]);
 let state;const file=await acquireArchive(entry,{store:root,fetcher:async()=>{state=await readdir(root);return new Response('ab');}});assert.deepEqual(state,[]);assert.equal(await readFile(file,'utf8'),'ab');
});
test('同对象并发提交只保留一份验真原件，不留全局下载锁',async t=>{
 const root=await sandbox(t),body=Buffer.from('concurrent'),entry=archive(body);let calls=0;const options={store:root,fetcher:async()=>{calls++;await new Promise(r=>setTimeout(r,10));return new Response(body);}};
 const paths=await Promise.all(Array.from({length:8},()=>acquireArchive(entry,options)));assert.equal(new Set(paths).size,1);assert.equal(await readFile(paths[0],'utf8'),'concurrent');assert.equal(calls,8);assert.deepEqual(await readdir(root),[paths[0].slice(root.length+1)]);
});
// 稀疏ZIP只在指定偏移写少量真实记录；覆盖大文件寻址，不分配或下载数GiB测试正文。
async function zipFixture(file,items,{base=0}={}){
 const {deflateRawSync}=await import('node:zlib'),output=await open(file,'wx'),directory=[],records=[];let cursor=base;
 try{
  if(base)await output.write(Buffer.from([0x50,0x4b,3,4]),0,4,0);
  for(const item of items){
   const name=Buffer.from(item.name),body=Buffer.from(item.body||''),method=item.method??0,packed=method===8?deflateRawSync(body):body,size=item.size??body.length,flags=item.flags??0,mode=item.mode??0o100644;
   const local=Buffer.alloc(30);local.writeUInt32LE(0x04034b50);local.writeUInt16LE(flags,6);local.writeUInt16LE(method,8);local.writeUInt32LE(packed.length,18);local.writeUInt32LE(size,22);local.writeUInt16LE(name.length,26);
   const start=cursor+local.length+name.length;for(const part of [local,name,packed]){await output.write(part,0,part.length,cursor);cursor+=part.length;}
   const central=Buffer.alloc(46);central.writeUInt32LE(0x02014b50);central.writeUInt16LE(flags,8);central.writeUInt16LE(method,10);central.writeUInt32LE(packed.length,20);central.writeUInt32LE(size,24);central.writeUInt16LE(name.length,28);central.writeUInt32LE((mode*65536)>>>0,38);central.writeUInt32LE(start-local.length-name.length,42);
   directory.push(central,name);records.push({method,compressed:packed.length,size,start});
  }
  const directoryOffset=cursor;
  for(const part of directory){await output.write(part,0,part.length,cursor);cursor+=part.length;}
  const end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(items.length,8);end.writeUInt16LE(items.length,10);end.writeUInt32LE(cursor-directoryOffset,12);end.writeUInt32LE(directoryOffset,16);await output.write(end,0,end.length,cursor);
  return records;
 }finally{await output.close();}
}
test('大于2GiB稀疏ZIP离线复用、格式识别与流式解包保留准确正文和链接',async t=>{
 const root=await sandbox(t),store=join(root,'store');await mkdir(store);
 const entry=archive(Buffer.from('large-zip-coordinate'),'https://example.invalid/large.zip'),file=join(store,hash(JSON.stringify([entry.url,entry.sha256]))+'.blob');
 await zipFixture(file,[{name:'package/a',body:'original',method:8,mode:0o100755},{name:'package/b',body:'a',mode:0o120777}],{base:2**31+128});
 assert.ok((await lstat(file)).size>2**31);
 assert.equal(await acquireArchive(entry,{store,work:root,offline:true,fetcher:()=>assert.fail('离线联网')}),file);
 const output=join(root,'output');await unpack(file,output,{prefix:'package'});assert.equal(await readFile(join(output,'a'),'utf8'),'original');assert.equal(await realpath(join(output,'b')),join(output,'a'));assert.ok((await lstat(join(output,'a'))).mode&0o111);
});
test('ZIP保留路径、重复、链接父目录、加密、Zip64、方式及展开上限拒绝',async t=>{
 const root=await sandbox(t),cases=[
  [[{name:'../outside',body:'x'}],/越界/],
  [[{name:'a',body:'x'},{name:'a',body:'y'}],/重复/],
  [[{name:'a',body:'../x',mode:0o120777}],/链接越界/],
  [[{name:'a',body:'b',mode:0o120777},{name:'a/child',body:'x'},{name:'b',body:'x'}],/父目录/],
  [[{name:'a',body:'x',flags:1}],/加密/],
  [[{name:'a',body:'x',size:0xffffffff}],/Zip64/],
  [[{name:'a',body:'x',method:99}],/压缩方式/],
  [[{name:'a',body:'12345678901'}],/解压超限/],
  [[{name:'a',body:'x',size:2}],/长度不符/]
 ];
 for(const [index,[items,error]]of cases.entries()){
  const input=join(root,index+'.zip'),output=join(root,'output'+index);await zipFixture(input,items);
  await assert.rejects(extractArchive(input,output,{maxBytes:10}),error);assert.equal(await stat(output),null);
 }
 const input=join(root,'truncated.zip');await zipFixture(input,[{name:'a',body:'x'}]);const handle=await open(input,'r+');await handle.truncate((await handle.stat()).size-1);await handle.close();await assert.rejects(extractArchive(input,join(root,'truncated')),/目录缺失/);
});
test('ZIP内部Framework目录链和前向引用在物化前解析且保留链接正文',async t=>{
 const root=await sandbox(t),input=join(root,'framework.zip'),output=join(root,'output');
 await zipFixture(input,[{name:'package/F/Resources',body:'Versions/Current/Resources',mode:0o120777},
  {name:'package/F/Versions/Current',body:'A',mode:0o120777},{name:'package/F/Versions/A/',mode:0o40755},
  {name:'package/F/Versions/A/Resources/',mode:0o40755},{name:'package/F/Versions/A/Resources/data',body:'original'}]);
 await extractArchive(input,output,{prefix:'package'});
 assert.equal(await realpath(join(output,'F/Resources')),join(output,'F/Versions/A/Resources'));
 assert.equal(await readFile(join(output,'F/Resources/data'),'utf8'),'original');
 assert.equal(await readlink(join(output,'F/Resources')),'Versions/Current/Resources');assert.equal(await readlink(join(output,'F/Versions/Current')),'A');
});
test('ZIP链接解析拒绝循环、自指、链式越界、缺失、绝对目标及非目录父项',async t=>{
 const root=await sandbox(t),link=(name,body)=>({name,body,mode:0o120777}),cases=[
  [link('a','b'),link('b','a')],[link('a','a')],
  [link('a','b/file'),link('b','../outside')],
  [link('a','b/file'),link('b','missing')],
  [link('a','/file'),{name:'file',body:'x'}],
  [link('a','b/child'),{name:'b',body:'x'}],
  [link('a','b/../file'),{name:'b',body:'x'},{name:'file',body:'x'}],
  Array.from({length:42},(_,i)=>i===41?{name:'link41',body:'x'}:link('link'+i,'link'+(i+1)))
 ];
 for(const [index,items]of cases.entries()){
  const input=join(root,index+'.zip'),output=join(root,'output'+index);await zipFixture(input,items);
  await assert.rejects(extractArchive(input,output),/链接越界|循环|跳转超限|父目录/);assert.equal(await stat(output),null);
 }
 // 硬链接仍只允许直接指向普通成员，不借目录链扩展原硬链接合同。
 assert.throws(()=>selectedArchiveEntries([{path:'a',type:'hardlink',target:'b'},{path:'b',type:'symlink',target:'c'},{path:'c',type:'file'}],''),/硬链接目标不是普通文件/);
});
// ZIP与TAR共用成员图规则；只检查链接正文，不依赖宿主系统对长链的跟随次数限制。
test('ZIP与TAR符号链接计入起点，40条通过而41条在物化前拒绝',async t=>{
 const root=await sandbox(t);
 for(const count of [40,41]){
  const links=Array.from({length:count},(_,i)=>({name:'link'+i,body:i===count-1?'file':'link'+(i+1),mode:0o120777}));
  const members=[...links.map(({name,body})=>({path:name,type:'symlink',target:body})),{path:'file',type:'file'}];
  if(count===40){const selected=selectedArchiveEntries(members,'');assert.equal(selected[0].resolved,'file');}
  else assert.throws(()=>selectedArchiveEntries(members,''),/跳转超限/);
  for(const format of ['zip','tgz']){
   const input=join(root,count+'.'+format),output=join(root,'output-'+count+'-'+format);
   if(format==='zip')await zipFixture(input,[...links,{name:'file',body:'original'}]);
   else await writeFile(input,tar([...links.map(({name,body})=>({name,type:'2',target:body})),{name:'file',body:'original'}]));
   if(count===40){await extractArchive(input,output);assert.equal(await readlink(join(output,'link0')),'link1');assert.equal(await readlink(join(output,'link39')),'file');assert.equal(await readFile(join(output,'file'),'utf8'),'original');}
   else{await assert.rejects(extractArchive(input,output),/跳转超限/);assert.equal(await stat(output),null);}
  }
 }
});
test('ZIP分块流错误和取消保留失败、关闭流且候选写入失败清场',async t=>{
 const root=await sandbox(t),input=join(root,'stream.zip'),body=Buffer.alloc(256*1024,97),[entry]=await zipFixture(input,[{name:'a',body}]),handle=await open(input,'r'),size=(await handle.stat()).size;
 try{
  const failure=Error('ZIP流夹具中断');await assert.rejects(zipEntryBytes(handle,size,entry,undefined,async()=>{throw failure;}),error=>error===failure);
  const controller=new AbortController();await assert.rejects(zipEntryBytes(handle,size,entry,controller.signal,async()=>controller.abort()),/abort/iu);
  const output=join(root,'output');await assert.rejects(materializeArchiveEntries(output,[{path:'a',type:'file',mode:0o644}],{write:async()=>{throw failure;}}),error=>error===failure);assert.equal(await stat(output),null);
 }finally{await handle.close();}
 await assert.rejects(extractArchive(input,join(root,'cancelled'),{signal:AbortSignal.abort()}),/abort/iu);assert.equal(await stat(join(root,'cancelled')),null);
});
test('TAR恢复原文件时间顺序，先解出的configure仍晚于configure.ac',async t=>{
 const root=await sandbox(t),input=join(root,'ruby.tgz'),output=join(root,'output');
 await writeFile(input,tar([{name:'package/configure',body:'generated',mtime:1790141562},{name:'package/configure.ac',body:'input',mtime:1790141560}]));
 await extractArchive(input,output,{prefix:'package'});
 assert.equal((await lstat(join(output,'configure'))).mtimeMs,1790141562000);
 assert.equal((await lstat(join(output,'configure.ac'))).mtimeMs,1790141560000);
 assert.ok((await lstat(join(output,'configure'))).mtimeMs>(await lstat(join(output,'configure.ac'))).mtimeMs);
 assert.equal(await readFile(join(output,'configure'),'utf8'),'generated');assert.equal(await readFile(join(output,'configure.ac'),'utf8'),'input');
});
test('TAR拒绝非法PAX时间且写入时间失败仍关闭句柄并清理本轮候选',async t=>{
 const root=await sandbox(t),record=value=>{const body='mtime='+value+'\n';let length=body.length+2;while(String(length).length+1+body.length!==length)length=String(length).length+1+body.length;return length+' '+body;};
 const valid=join(root,'fraction.tgz');await writeFile(valid,tar([{name:'PaxHeaders/a',type:'x',body:record('1790141560.125')},{name:'a',body:'x'}]));
 const fraction=join(root,'fraction');await extractArchive(valid,fraction);assert.equal((await lstat(join(fraction,'a'))).mtimeMs,1790141560125);
 for(const [index,value]of ['NaN','Infinity','-1','1e3','8640000000001','1.1234567890'].entries()){
  const input=join(root,index+'.tgz'),output=join(root,'invalid'+index);await writeFile(input,tar([{name:'PaxHeaders/a',type:'x',body:record(value)},{name:'a',body:'x'}]));
  await assert.rejects(extractArchive(input,output),/TAR修改时间无效/);assert.equal(await stat(output),null);
 }
 const output=join(root,'utimes'),failure=Error('synthetic TAR utimes failure');let closed=false;
 await assert.rejects(materializeArchiveEntries(output,[{path:'a',type:'file',mode:0o644,mtime:1}],{write:async(file,entry)=>{
  const handle=await open(file,'wx');try{await handle.writeFile('x');await handle.utimes(NaN,entry.mtime);}catch{throw failure;}finally{await handle.close();closed=true;}
 }}),error=>error===failure);
 assert.equal(closed,true);assert.equal(await stat(output),null);
});
test('归档安全解包并隔离不同任务，拒绝路径和链接越界',async t=>{
 const root=await sandbox(t),source=join(root,'source.tgz'),data=tar([{name:'package/a',body:'source'},{name:'package/b',type:'2',target:'a'}]);await writeFile(source,data);
 const first=join(root,'first'),second=join(root,'second');await extractArchive(source,first,{prefix:'package'});await extractArchive(source,second,{prefix:'package'});assert.equal(await realpath(join(first,'b')),join(first,'a'));await writeFile(join(first,'a'),'task1');assert.equal(await readFile(join(second,'a'),'utf8'),'source');
 for(const [name,entries]of [['path',[{name:'../outside',body:'x'}]],['link',[{name:'package/a',body:'x'},{name:'package/b',type:'2',target:'../../outside'}]],['parent',[{name:'package/a',type:'2',target:'b'},{name:'package/a/child',body:'x'},{name:'package/b',body:'x'}]]]){const file=join(root,name+'.tgz');await writeFile(file,tar(entries));await assert.rejects(extractArchive(file,join(root,name),{prefix:name==='path'?'':'package'}),/越界|父目录/);assert.equal((await readdir(root)).includes(name),false);}
});
test('链接原件目录、重复成员与解包取消拒绝且不写第三方目录',async t=>{
 const root=await sandbox(t),external=join(root,'external'),link=join(root,'link');await mkdir(external);await symlink(external,link);await assert.rejects(acquireArchive(archive(Buffer.from('source')),{store:link,offline:true}),/链接/);assert.deepEqual(await readdir(external),[]);
 const input=join(root,'input.tgz');await writeFile(input,tar([{name:'a',body:'x'},{name:'a',body:'y'}]));await assert.rejects(extractArchive(input,join(root,'duplicate')),/重复/);
 const signal=AbortSignal.abort();await assert.rejects(extractArchive(input,join(root,'cancelled'),{signal}));assert.equal((await readdir(root)).includes('cancelled'),false);
});
test('产品配方覆盖自身需求和递归工具，模块只使用内置依赖，独立CLI拒绝错误输入',async t=>{
 const root=await sandbox(t),declarations=resourceDeclarations(),tools=new Map(declarations.tools.map(x=>[x.id,x]));for(const platform of Object.values(contract.platforms))for(const tool of platform.tools){assert.equal(tools.get(tool.id)?.version,tool.version);}
 for(const tool of tools.values())for(const id of tool.requires||[])assert.ok(tools.has(id),'缺少递归工具 '+id);
 for(const name of ['node','posix','bash','grep','sed'])assert.ok(tools.has(name));const source=await readFile(new URL('./build.mjs',import.meta.url),'utf8');assert.ok([...source.matchAll(/^import .*? from ['"]([^'"]+)['"]/gmu)].every(m=>m[1].startsWith('node:')));
 const result=spawnSync(process.execPath,[join(import.meta.dirname,'build.mjs'),'unknown','--work',root,'--offline'],{env:{HOME:root,LANG:'C',PATH:''},encoding:'utf8'});assert.notEqual(result.status,0);assert.match(result.stderr,/平台|固定目录|固定入口/);assert.deepEqual(await readdir(root),[]);
});

test('Git Cargo工作区继承按当前产品锁展开，不留下跨包路径',()=>{
 const input={package:{name:'one',version:{workspace:true}},dependencies:{two:{workspace:true},third:{path:'../third'}}};const workspace={workspace:{package:{version:'1.0.0'},dependencies:{two:{path:'two',version:'2.0.0',features:['a']}}}};const lock=[{name:'third',version:'3.0.0'}];
 const result=normalizeCargoManifest(input,workspace,lock);assert.equal(result.package.version,'1.0.0');assert.equal(result.dependencies.two.path,undefined);assert.equal(result.dependencies.third.version,'=3.0.0');assert.deepEqual(input.package.version,{workspace:true});assert.throws(()=>normalizeCargoManifest(input,workspace,[]),/唯一锁定版本/);
});
test('资源子进程可取消，不能继续输出成功回执',async()=>{
 const signal=AbortSignal.timeout(150);await assert.rejects(runResourceProcess(process.execPath,['-e','setInterval(()=>{},1000)'],{signal,env:{PATH:''}}),/abort|timeout|取消/iu);
});

// 使用产品真实源码工具生产器；编译/Apple能力边界受控，文件事务和输出验真实际执行。
const registry=resourceDeclarations();
async function sourceFixture(t, behavior = {}) {
  const root = await realpath(await fixedScratch(join(tmpdir(), 'source-tool-')));
  const owner = await lstat(root);
  t.after(async () => {
    const current = await lstat(root);
    assert.equal(current.dev, owner.dev); assert.equal(current.ino, owner.ino);
    await rm(root, { recursive: true, force: true });
  });
  const library = { root: join(root, 'tools'), work:join(root,'work'), tools: registry.tools };await mkdir(library.work);
  const tool = structuredClone(registry.tools.find(tool => tool.id === 'perl'));
  const bytes = Buffer.from('official-fixture-archive');
  tool.archive.sha256 = createHash('sha256').update(bytes).digest('hex');
  const pending = join(library.root, 'shared', tool.archive.sha256 + '.pending');
  const payload = join(pending, 'payload'), source = join(pending, 'unpack', tool.archive.root);
  const finalPayload = join(library.root, 'shared', tool.archive.sha256, 'payload');library.pending=pending;library.finalPayload=finalPayload;
  const developerDirectory = join(root, 'Xcode.app/Contents/Developer');
  const sdk = join(developerDirectory, 'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk');
  await mkdir(source, { recursive: true }); await mkdir(sdk, { recursive: true });
  await writeFile(join(pending, 'archive'), bytes);
  await writeFile(join(source, 'Artistic'), 'fixture upstream legal text');
  // 本夹具只声明实际Configure安装路径和受控入口，不复制任何真实工具原件。
  await writeFile(join(source,'config.sh'),
    "installprivlib='"+finalPayload+"/lib/5.42.3'\ninstallarchlib='"+finalPayload+"/lib/5.42.3/aarch64-darwin'\n");
  const posix=join(root,'verified/posix/bin');await mkdir(posix,{recursive:true});
  for(const name of posixNames)await writeFile(join(posix,name),'fixture executable '+name,{mode:0o755});
  // 完整基础工具交付属于夹具输入；不会复制或安装真实工具原件。
  for(const id of ['bash','grep','sed']) {
    const bin=join(root,'verified',id,'bin');await mkdir(bin,{recursive:true});
    await writeFile(join(bin,id),'fixture executable '+id,{mode:0o755});
  }
  const calls = [];
  const exec = async (command, args, options) => {
    calls.push({ command, args, options });
    if (command.endsWith('/xcrun')) return { stdout: sdk + '\n' };
    if (args.includes('-MJSON::PP')) return { stdout: behavior.coreFails ? '' : 'controlled-perl-ok\n' };
    if (behavior.compilerFails && args.includes('-j8')) throw new Error('compiler failed');
    if (args.includes('install')) {
      const destination = args.find(value => value.startsWith('DESTDIR=')).slice(8);
      const staged = join(destination, finalPayload.slice(1));
      await mkdir(join(staged, 'bin'), { recursive: true });
      if (behavior.linkOutput) await symlink(join(pending, 'archive'), join(staged, 'bin/perl'));
      else if (!behavior.missingOutput) {
        const macho = Buffer.alloc(32); macho.writeUInt32LE(0xfeedfacf, 0); macho.writeUInt32LE(0x0100000c, 4);
        await writeFile(join(staged, 'bin/perl'), macho, { mode: 0o755 });
        await mkdir(join(staged, 'lib/5.42.3/aarch64-darwin'), { recursive: true });
        await writeFile(join(staged, 'lib/5.42.3/aarch64-darwin/Config.pm'), 'fixture core module');
      }
    }
    return { stdout: '' };
  };
  const input = { library, tool, pending, payload, source, archive: join(pending, 'archive'), finalPayload,
    environment: { PATH: '/untrusted/bin', RUBYOPT: '-rmalicious', PYTHONPATH: '/untrusted',
      DYLD_INSERT_LIBRARIES: '/untrusted', LD_PRELOAD: '/untrusted', ARCHFLAGS: '-arch x86_64', CFLAGS: 'malicious', PERL5OPT: '-Mmalicious' },
    exec, lookup: async (_, tool) => behavior.missingTool === tool.id ? null
      : { path: join(root, 'verified', tool.id, 'bin', tool.command), version: tool.version },
    apple: async () => ({ developerDirectory, version: '27.0',
      tools: Object.fromEntries(['clang', 'clang++', 'ar', 'make', 'ld', 'as', 'nm', 'ranlib', 'strip', 'xcrun', 'otool', 'install_name_tool', 'codesign'].map(name => [name, join(developerDirectory, 'usr/bin', name)])) }),
    // 产品依赖准备只返回归档映射，不创建旧工具库的originals目录。
    prepare: async () => new Map() };
  return { input, calls, bytes };
}
test('源码工具使用准确Apple编译入口并只在候选中收集输出、原件和编译输入', async t => {
  const { input, calls, bytes } = await sourceFixture(t);
  await buildSourceTool(input);
  const configure = calls.find(call => call.args.includes('-des'));
  assert.ok(configure.args.includes('-Dinstallusrbinperl=n'));
  for (const key of ['RUBYOPT', 'PYTHONPATH', 'DYLD_INSERT_LIBRARIES', 'PERL5OPT', 'LD_PRELOAD']) assert.equal(configure.options.env[key], undefined);
  assert.equal(configure.options.env.CFLAGS,'-O2');
  assert.equal(configure.options.env.MACOSX_DEPLOYMENT_TARGET,registry.tools.find(t=>t.id==='posix').version);
  assert.ok(configure.options.env.SDKROOT.startsWith(configure.options.env.DEVELOPER_DIR+'/'));
  assert.equal(configure.options.env.CPP,configure.options.env.CC+' -E');
  assert.ok(!configure.options.env.PATH.split(':').some(p=>['/usr/bin','/bin','/opt/homebrew/bin'].includes(p)));
  assert.equal(configure.options.env.ARCHFLAGS, '-arch arm64');
  assert.ok(configure.options.env.CC.startsWith(input.pending.split('/tools/')[0] + '/Xcode.app/'));
  assert.ok(!configure.options.env.PATH.includes('/untrusted/'));
  assert.ok(calls.some(call => call.args.includes('-MJSON::PP') && call.options.env.PERL5LIB.startsWith(input.payload + '/lib/')));
  assert.equal(await readFile(join(input.payload, 'licenses/Artistic'), 'utf8'), 'fixture upstream legal text');
});
for (const behavior of [{ compilerFails: true }, { missingOutput: true }, { linkOutput: true }, { missingTool: 'node' }, { coreFails: true }]) {
  test('源码工具失败边界保留失败且不写入最终工具对象：' + JSON.stringify(behavior), async t => {
    const { input } = await sourceFixture(t, behavior);
    await assert.rejects(buildSourceTool(input));
    await assert.rejects(readFile(join(input.finalPayload, 'bin/perl')), { code: 'ENOENT' });
  });
}

test('候选路径不属于当前工具摘要时在任何编译前失败', async t => {
  const { input, calls } = await sourceFixture(t);
  input.finalPayload += '-other';
  await assert.rejects(buildSourceTool(input), /候选对象身份/);
  assert.equal(calls.length, 0);
});



test('Pod浮动tag必须由产品固定提交闭合，来源漂移或无摘要HTTP发行件失败',()=>{
 const url='https://github.com/example/project.git',ref='a'.repeat(40),spec={name:'Example',version:'1.0.0',source:{git:url,tag:'v1.0.0'}},definitions=[{name:'Example',version:'1.0.0',url,tag:'v1.0.0',ref}];
 assert.deepEqual(podSourceCoordinate(spec,definitions),{url,ref});assert.throws(()=>podSourceCoordinate(spec,[]),/锁定/);
 assert.throws(()=>podSourceCoordinate({...spec,source:{git:'https://github.com/example/other.git',tag:'v1.0.0'}},definitions),/来源/);
 assert.throws(()=>podSourceCoordinate({...spec,source:{git:url,tag:'v2.0.0'}},definitions),/来源/);
 assert.throws(()=>podSourceCoordinate({name:'HTTP',version:'1',source:{http:'https://example.invalid/archive.zip'}},[]),/锁定/);
 for(const entry of resourceDeclarations().pods){const source=entry.ref?{git:entry.url,tag:entry.tag}:{http:entry.url};const coordinate=podSourceCoordinate({name:entry.name,version:entry.version,source});assert.equal(coordinate.ref||coordinate.sha256,entry.ref||entry.sha256);}
});

// 真实进程退出顺序：取消回执必须晚于子工具完成清理，不能用发送信号代替退出确认。
test('资源取消等待真实工具清理并确认退出后才返回失败',{timeout:20000},async t=>{
 const directory=await sandbox(t),ready=join(directory,'ready'),closed=join(directory,'closed');
 const code=`import {writeFileSync} from 'node:fs';process.once('SIGTERM',()=>setTimeout(()=>{writeFileSync(${JSON.stringify(closed)},'closed');process.exit(0);},600));writeFileSync(${JSON.stringify(ready)},'ready');setInterval(()=>{},1000);`;
 const controller=new AbortController();const running=runResourceProcess(process.execPath,['--input-type=module','-e',code],{cwd:directory,env:{PRODUCT_WORK_DIR:directory},signal:controller.signal});
 for(let n=0;n<200;n++){try{await readFile(ready);break;}catch{await new Promise(ok=>setTimeout(ok,10));}}
 assert.equal(await readFile(ready,'utf8'),'ready');const start=Date.now();controller.abort(Error('资源进程取消'));
 await assert.rejects(running,/取消/u);assert.equal(await readFile(closed,'utf8'),'closed');assert.ok(Date.now()-start>=500);
});
test('资源超时等待退出，错误入口和输出超限不产生成功回执',{timeout:20000},async t=>{
 const directory=await sandbox(t),closed=join(directory,'timeout-closed');
 const code=`import {writeFileSync} from 'node:fs';process.once('SIGTERM',()=>setTimeout(()=>{writeFileSync(${JSON.stringify(closed)},'closed');process.exit(0);},400));setInterval(()=>{},1000);`;
 await assert.rejects(runResourceProcess(process.execPath,['--input-type=module','-e',code],{cwd:directory,timeout:500}),/超时/u);
 assert.equal(await readFile(closed,'utf8'),'closed');
 await assert.rejects(runResourceProcess(join(directory,'missing'),[],{cwd:directory}),/无法启动/u);
 await assert.rejects(runResourceProcess(process.execPath,['-e','process.stdout.write("x".repeat(4096))'],{cwd:directory,maxBuffer:64}),/输出超限/u);
});










// 真实文件事务验证下载候选的归属，不执行真实工具安装或编译。
test('资源下载候选只属于当前产品target现场，永久库不接收半包',async t=>{
 const root=await sandbox(t),work=join(root,'work'),store=join(root,'originals');await mkdir(work);await mkdir(store);
 const body=Buffer.from('owned-pending'),entry=archive(body);let inspected=false;
 const fetcher=async()=>({ok:true,headers:new Headers(),body:{async *[Symbol.asyncIterator](){
  const candidates=await readdir(join(work,'resource-pending'));
  assert.equal(candidates.filter(name=>name.endsWith('.pending')).length,1);
  assert.deepEqual(await readdir(store),[]);inspected=true;yield body;
 },cancel:async()=>{}}});
 const file=await acquireArchive(entry,{store,work,fetcher});assert.equal(inspected,true);
 assert.equal(await readFile(file,'utf8'),body.toString());assert.deepEqual(await readdir(join(work,'resource-pending')),[]);
 await assert.rejects(acquireArchive(archive(Buffer.from('other')),{store,work:dirname(resolve(import.meta.dirname,'..')),fetcher}),/target/);
});





// 同文件私有函数直接接受合成响应；测试不复制或执行第二份资源实现。
test('Pod官方CDN严格一跳HTTPS分发，错源、错路径、再跳转、超限和取消拒绝',async t=>{
 await sandbox(t);
 const url='https://cdn.cocoapods.org/Specs/0/3/5/Firebase/12.15.0/Firebase.podspec.json',mirror='https://cdn.jsdelivr.net/cocoa/Specs/0/3/5/Firebase/12.15.0/Firebase.podspec.json';
 let pass=0;
assert.equal((await podSpecBytes(url,{fetcher:async(_,o)=>{assert.equal(o.redirect,'manual');return new Response('fixed-spec')}})).toString(),'fixed-spec');pass++;
let calls=[];assert.equal((await podSpecBytes(url,{fetcher:async(u,o)=>{calls.push([u,o.redirect]);return calls.length===1?new Response(null,{status:301,headers:{location:mirror}}):new Response('fixed-spec')}})).toString(),'fixed-spec');assert.deepEqual(calls,[[url,'manual'],[mirror,'error']]);pass++;
// 明文负例只改变合成URL的协议；准确官方路径保持，实际拒绝不得发出第二次请求。
const insecureMirror=new URL(mirror);insecureMirror.protocol='http:';assert.equal(insecureMirror.protocol,'http:');
for(const location of [insecureMirror.href,'https://example.invalid/spec',mirror+'?different=1',mirror+'#fragment',mirror.replace('/12.15.0/','/12.14.0/'),'https://user@cdn.jsdelivr.net/cocoa/Specs/0/3/5/Firebase/12.15.0/Firebase.podspec.json']){let n=0;await assert.rejects(podSpecBytes(url,{fetcher:async()=>{n++;return new Response(null,{status:301,headers:{location}})}}),/重定向越界/);assert.equal(n,1);pass++;}
await assert.rejects(podSpecBytes(url,{fetcher:async u=>u===url?new Response(null,{status:301,headers:{location:mirror}}):new Response(null,{status:301,headers:{location:mirror}})}),/官方来源响应失败/);pass++;
await assert.rejects(podSpecBytes(url,{fetcher:async()=>new Response('x'.repeat(2*1024**2+1))}),/超限/);pass++;
const signal=AbortSignal.abort(Error('cancelled'));await assert.rejects(podSpecBytes(url,{signal,fetcher:async()=>new Response(null,{status:301,headers:{location:mirror}})}),/cancelled/);pass++;
for(const input of [url+'?different=1',url+'#fragment',url.replace('https:','http:'),url.replace('https://','https://user@')]){let requests=0;await assert.rejects(podSpecBytes(input,{fetcher:async()=>{requests++;return new Response('unexpected')}}),/官方地址无效/);assert.equal(requests,0);pass++;}
let cancelled=false;const body=new ReadableStream({cancel(){cancelled=true;}});await assert.rejects(podSpecBytes(url,{fetcher:async()=>new Response(body,{status:301,headers:{location:'https://example.invalid/spec'}})}),/重定向越界/);assert.equal(cancelled,true);pass++;
assert.equal(pass,16);

});


// Linux来源与对象回执使用产品自己的真实验真函数，整项完成后统一执行。


// 完整源码仅在target暴露私有事务；合成设备号覆盖跨卷复制，真实两卷验收另行记录。




test('Gradle解析前准确生成本轮SDK配置，重复稳定并拒绝漂移/链接/错版本/取消',async t=>{
 const area=await sandbox(t);
 for(const mode of ['normal','generated','drift','link','version','cancel','outside']){
  const work=join(area,mode),project=join(work,'app/android'),flutter=join(work,'flutter'),sdk=join(work,'sdk');
  for(const dir of [project,flutter,sdk])await mkdir(dir,{recursive:true});await writeFile(join(dirname(project),'pubspec.yaml'),mode==='version'?'version: bad\n':'version: 1.2.3+7\n');
  const plugin=join(flutter,'packages/integration_test/android');await mkdir(plugin,{recursive:true});await writeFile(join(plugin,'build.gradle.kts'),'plugins { id("com.android.library") }\n');
  const file=join(project,'local.properties'),signal=mode==='cancel'?AbortSignal.abort(Error('cancelled')):undefined;
  if(mode==='generated')await writeFile(file,'flutter.sdk='+flutter+'\n');
  if(mode==='drift')await writeFile(file,'drift');if(mode==='link'){await writeFile(join(work,'external'),'preserve');await symlink(join(work,'external'),file);}
  const action=()=>prepareAndroidResourceProperties(project,mode==='outside'?join(work,'foreign'):work,flutter,sdk,{signal});
  if(mode==='normal'||mode==='generated'){
   assert.equal(await action(),file);const identity=(await lstat(file)).ino;assert.equal(await action(),file);assert.equal((await lstat(file)).ino,identity);
   assert.equal(await readFile(file,'utf8'),'sdk.dir='+sdk+'\nflutter.sdk='+flutter+'\nflutter.buildMode=release\nflutter.versionName=1.2.3\nflutter.versionCode=7\n');
   const view=join(dirname(project),'.flutter-plugin-views/integration_test/android/build.gradle.kts');
   assert.equal(await readFile(view,'utf8'),await readFile(join(plugin,'build.gradle.kts'),'utf8'));
   await writeFile(view,'drift');await assert.rejects(action(),/插件任务视图漂移/);
  }else{
   await assert.rejects(action,/漂移|普通|版本|cancelled|越出/);
   if(mode==='drift')assert.equal(await readFile(file,'utf8'),'drift');
   if(mode==='link')assert.equal(await readFile(join(work,'external'),'utf8'),'preserve');
   if(['version','cancel','outside'].includes(mode))assert.equal((await readdir(project)).includes('local.properties'),false);
  }
 }
});

// SDK供给使用产品准确六组件摘要与全树清单，不联网或修改可选原件。






test('Android资源准备绑定实际Release外部依赖及ARM64，拒绝旧测试配置解析',async t=>{
 await sandbox(t);const text=androidGradleResourceInit();assert.match(text,/releaseCompileClasspath/);assert.match(text,/releaseRuntimeClasspath/);assert.match(text,/buildscript\.configurations/);assert.match(text,/ModuleComponentIdentifier/);assert.doesNotMatch(text,/AndroidTest|debug|it.resolve\(\)/);const source=await readFile(new URL('./build.mjs',import.meta.url),'utf8');assert.match(source,/-Ptarget-platform=android-arm64/);assert.match(source,/Gradle资源任务配置漂移/);
 assert.ok(source.indexOf("await exec(flutterTool.path,['pub','get'")<source.indexOf('await prepareAndroidResourceProperties(project,work,'));
});

// 资源需求由本仓功能入口推导，协议测试不下载、安装或替代真实原生库。
// 名称冲突按当前真实文件系统判定；能表示时保留两份原始成员，否则在写成员前失败并清场。
test('原件README与Readme及同名大小写目录必须完整保留或提前失败',async t=>{
 const area=await sandbox(t),probe=join(area,'case-probe');await mkdir(probe);await writeFile(join(probe,'README'),'upper',{flag:'wx'});
 let caseSensitive=true;try{await writeFile(join(probe,'Readme'),'mixed',{flag:'wx'});}catch(error){if(error.code!=='EEXIST')throw error;caseSensitive=false;}await rm(probe,{recursive:true});
 for(const entries of [
  [{name:'README',body:'upper-original'},{name:'Readme',body:'mixed-original'}],
  [{name:'Folder/a',body:'upper-original'},{name:'folder/a',body:'mixed-original'}]
 ]){
  const input=join(area,'archive-'+entries[0].name.split('/')[0]+'.tgz'),output=input+'.out';await writeFile(input,tar(entries));const digest=hash(await readFile(input));
  if(caseSensitive){await extractArchive(input,output);for(const entry of entries)assert.equal(await readFile(join(output,entry.name),'utf8'),entry.body);}
  else{await assert.rejects(extractArchive(input,output),/大小写|准确名称/);assert.equal((await readdir(area)).includes(output.slice(area.length+1)),false);}
  assert.equal(hash(await readFile(input)),digest);
 }
});
test('名称预检取消只清理本轮探测目录并保护既有成员',async t=>{
 const area=await sandbox(t),sentinel=join(area,'keep');await writeFile(sentinel,'preserve');
 await assert.rejects(verifyArchiveNames(area,['README','Readme'],AbortSignal.abort(Error('取消名称预检'))),/取消名称预检/);
 assert.deepEqual(await readdir(area),['keep']);assert.equal(await readFile(sentinel,'utf8'),'preserve');
});

test('资源普通导入在Node测试环境中也不注册末尾用例或进入资源CLI',async()=>{
 const environment={...process.env,PATH:''};environment.NODE_TEST_CONTEXT='child-v8';
 const source="await import("+JSON.stringify(new URL('./build.mjs',import.meta.url).href)+");process.stdout.write('import-only');";
 const result=spawnSync(process.execPath,['--input-type=module','-e',source],{env:environment,encoding:'utf8',timeout:30000});
 assert.equal(result.status,0);assert.equal(result.signal,null);assert.equal(result.stdout,'import-only');assert.equal(result.stderr,'');
});


test('XZ名称预检与解包失败均清理本轮目标，取消不调用提取',async t=>{
 const area=await sandbox(t),input=join(area,'fixture.xz');await writeFile(input,Buffer.from([0xfd,0x37]));
 for(const mode of ['normal','failed','cancel']){
  const output=join(area,mode),controller=new AbortController();let extractions=0;
  const run=async(command,args)=>{
   assert.equal(command,join(area,'declared-tar'));
   if(args[0]==='-tvf')return {stdout:'- fixture\n'};
   if(args[0]==='-tf'){if(mode==='cancel')controller.abort(Error('取消XZ'));return {stdout:'locked/file\n'};}
   assert.equal(args[0],'-xkf');extractions++;await mkdir(join(output,'locked'));await writeFile(join(output,'locked/file'),'original');
   if(mode==='failed')throw Error('提取失败');return {stdout:''};
  };
  const action=()=>unpack(input,output,{foundation:{tools:{tar:join(area,'declared-tar')}},run,signal:controller.signal});
  if(mode==='normal'){await action();assert.equal(await readFile(join(output,'locked/file'),'utf8'),'original');}
  else{await assert.rejects(action,/提取失败|取消XZ/);assert.equal((await readdir(area)).includes(mode),false);}
  assert.equal(extractions,mode==='cancel'?0:1);assert.deepEqual(await readFile(input),Buffer.from([0xfd,0x37]));
 }
});



});

// 同文件回归只准备夹具归档，验证候选职责和失败清理，不下载或运行产品编译。
if(inlineTestEntry)inlineTestRegistrations.push(async()=>{
 const {test}=await import('node:test'),{default:assert}=await import('node:assert/strict'),{execFileSync}=await import('node:child_process'),fs=await import('node:fs');
 const {withFixedWork}=targetRuntime;

});




// 使用真实本轮目录验证解析器取得、复用及失败清场，不触碰共享工具库。


async function prepareRunnerFlutter(sdk,work,environment){
 const tool=toolDefinitions.find(value=>value.id==='flutter');
 if(!tool||createHash('sha256').update(flutterPatch).digest('hex')!==tool.patch?.sha256)
  fail('Flutter 修订声明不匹配');
 return flutterRecipe.prepareFlutter(sdk,{tool,files:flutterRecipe.parsePatch(flutterPatch),
  env:{...environment,PRODUCT_WORK_DIR:work}});
}
return {runResourceProcess,inventory,acquireArchive,extractArchive,normalizeCargoManifest,podSourceCoordinate,checkCocoaPodsResources,buildSourceTool,posixNames,resourceDeclarations,bootstrapNode,prepareSdkInputs,nodeTestResources,resources,flutterCommit,gradleRecipes,revisedSource,revisionPlan,assertWorkQuiescent,copyFlutterArtifact:flutterRecipe.copyFlutterArtifact,prepareRunnerFlutter};
})(contract,testRoot);
export const {runResourceProcess,inventory,acquireArchive,extractArchive,normalizeCargoManifest,podSourceCoordinate,checkCocoaPodsResources,buildSourceTool,posixNames,resourceDeclarations,bootstrapNode,resources,flutterCommit,gradleRecipes,revisedSource,revisionPlan,assertWorkQuiescent,copyFlutterArtifact}=resourceRuntime;

// SDK来源始终由本产品原始声明和锁决定；没有邻仓工作树模式。
export function resourceSourceRoot(name,work){checkWork(work);if(!/^[a-z][a-z0-9_]*$/u.test(name))fail('来源名称无效');return join(work,'git-sources',name);}
// 清理只针对当前执行拥有的工作根；工具全部退出后删除并回读，固定根本身保留。
export function clearWork(work) { return clearFixedWork(work); }

export function platformContract(platform) {
 if(!Object.hasOwn(contract.platforms,platform))fail('平台未声明');
 return contract.platforms[platform];
}
const nativePlatform=platform=>platform.endsWith('android')?'Android':platform.includes('linux-arm')?'LinuxARM':platform.includes('linux-amd')?'LinuxAMD':platform.endsWith('windows')?'Windows':'macOS';
const osPlatform=platform=>platform.includes('linux-')?'linux':platform.replace(/^(?:host|client)-/u,'');

// SDK依赖只经当前选中来源的公开plan取得坐标；调用方不解析SDK私有锁结构。
export function sdkDependencyPlan(sdkRoot,platform){
 if(!['Android','macOS','LinuxARM','LinuxAMD','Windows'].includes(platform))fail('SDK公开依赖平台无效');
 const entry=join(sdkRoot,'scripts/build.mjs');
 if(realpathSync(sdkRoot)!==sdkRoot||!lstatSync(sdkRoot).isDirectory()
  ||realpathSync(entry)!==entry||!lstatSync(entry).isFile()||lstatSync(entry).isSymbolicLink())
  fail('SDK公开依赖入口无效');
 const result=spawnSync(process.execPath,[entry,'plan','--platform',platform],{
  cwd:sdkRoot,env:{HOME:sdkRoot,LANG:'C',LC_ALL:'C',PATH:'',NODE_OPTIONS:''},
  encoding:'utf8',timeout:30000,maxBuffer:65536});
 if(result.error||result.signal||result.status!==0||result.stderr||!result.stdout?.endsWith('\n'))
  fail('SDK公开依赖计划失败');
 let plan;try{plan=JSON.parse(result.stdout);}catch{fail('SDK公开依赖计划不是JSON');}
 if(plan?.schema!==1||plan.platform!==platform||!Array.isArray(plan.archives)||!plan.archives.length)
  fail('SDK公开依赖计划身份无效');
 const seen=new Set();
 for(const item of plan.archives){
  if(!item||Object.keys(item).sort().join(',')!=='archive_root,name,sha256,size,url,version'
   ||typeof item.name!=='string'||!/^[a-z][a-z0-9-]*$/u.test(item.name)||seen.has(item.name)
   ||typeof item.version!=='string'||!item.version||!Number.isSafeInteger(item.size)||item.size<=0
   ||typeof item.sha256!=='string'||!/^[a-f0-9]{64}$/u.test(item.sha256)
   ||typeof item.archive_root!=='string'||!item.archive_root||item.archive_root.split('/').some(value=>!value||value==='.'||value==='..'))
   fail('SDK公开依赖归档无效');
  let url;try{url=new URL(item.url);}catch{fail('SDK公开依赖来源无效');}
  if(url.protocol!=='https:'||url.username||url.password||url.hash)fail('SDK公开依赖来源无效');
  seen.add(item.name);
 }
 return plan.archives;
}

// SDK选择只在任务边界执行；以下记录不改宿主原始声明，也不接受未提交工作树。
const sdkRepositories=Object.freeze({citizen_sdk:'https://github.com/crcfrcn/citizensdk.git',tatachat_sdk:'https://github.com/tuyutata/tatachatsdk.git'});
function checkedSdkTag(tag){
 if(typeof tag!=='string'||!tag||tag.length>200||/[\x00-\x20\x7f~^:?*\[\\]/u.test(tag)||tag.includes('..')||tag.includes('@{')||tag.split('/').some(part=>!part||part.startsWith('.')||part.endsWith('.')||part.endsWith('.lock')))fail('SDK正式Tag名称无效');
 return tag;
}
export function checkedSdkSelection(value,{mode}={}){
 if(!value||value.schema!==1||value.product_id!==product||!['local','release'].includes(value.mode)||mode&&value.mode!==mode
  ||Object.keys(value).some(key=>!['schema','product_id','mode','sources'].includes(key))||!Array.isArray(value.sources)||value.sources.length!==Object.keys(sdkRepositories).length)fail('SDK任务锁身份无效');
 const sources=Object.entries(sdkRepositories).map(([name,url])=>{
  const matches=value.sources.filter(source=>source?.name===name);if(matches.length!==1)fail('SDK任务锁来源不唯一');const source=matches[0];
  const keys=value.mode==='local'?['name','url','ref','local_root']:['name','url','ref','release_id','tag'];
  if(Object.keys(source).some(key=>!keys.includes(key))||source.url!==url||!/^[a-f0-9]{40}$/u.test(source.ref||''))fail('SDK任务锁来源或提交无效');
  if(value.mode==='local'){
   const expected=join(resourceOs.homedir(),basename(new URL(url).pathname,'.git'));
   if(source.local_root!==expected)fail('本机SDK必须来自指定正式仓库');
  }else {if(!Number.isSafeInteger(source.release_id)||source.release_id<1)fail('SDK正式版记录无效');checkedSdkTag(source.tag);}
  return {...source};
 });return {schema:1,product_id:product,mode:value.mode,sources};
}
function sdkSelectionForWork(work,environment=process.env){
 const state=executions.getStore();
 if(state?.sdkSelection){if(state.sdkWork!==work)fail('SDK任务锁工作根不符');return checkedSdkSelection(state.sdkSelection);}
 const text=environment.CITIZENAPP_SDK_SELECTION;if(text===undefined)return null;
 if(typeof text!=='string'||Buffer.byteLength(text)>16384)fail('SDK任务锁长度无效');
 const record=JSON.parse(text);if(record.work!==work||Object.keys(record).some(key=>!['work','selection'].includes(key)))fail('SDK任务锁工作根不符');
 return checkedSdkSelection(record.selection);
}
function sdkSelectionEnvironment(work,selection){return {CITIZENAPP_SDK_SELECTION:JSON.stringify({work,selection:checkedSdkSelection(selection)})};}
export function effectiveSdkSources(work,environment=process.env){return sdkSelectionForWork(work,environment)?.sources||lockedSources();}
// 本机只读取固定仓库的已提交HEAD；检出和bundle的可写数据仍全部归本任务。
export async function selectLocalSdkInputs(git,work,environment,{readGit,inspect}={}){
 checkWork(work);if((readGit||inspect)&&!process.env.NODE_TEST_CONTEXT)fail('合成SDK输入仅用于本仓测试');
 const read=readGit|| (async(path,args)=>(await runBuildProcess(git,['-c','credential.helper=','-c','core.hooksPath=/dev/null','-C',path,...args],
  {HOME:environment.HOME,PATH:environment.PATH,GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:'/dev/null',GIT_TERMINAL_PROMPT:'0'},root,{capture:true})).stdout.trim());
 const sources=[];
 for(const [name,url]of Object.entries(sdkRepositories)){
  const local_root=join(resourceOs.homedir(),basename(new URL(url).pathname,'.git'));
  const inspectPath=inspect|| (path=>{const info=lstatSync(path);if(!info.isDirectory()||info.isSymbolicLink()||realpathSync(path)!==path)fail('本机SDK不是正式普通仓库');});
  for(const path of [local_root,join(local_root,'.git')])inspectPath(path);
  if(await read(local_root,['rev-parse','--show-toplevel'])!==local_root||await read(local_root,['rev-parse','--absolute-git-dir'])!==join(local_root,'.git')
   ||resolve(local_root,await read(local_root,['rev-parse','--git-common-dir']))!==join(local_root,'.git')||await read(local_root,['remote','get-url','origin'])!==url)fail('本机SDK仓库或HTTPS来源不符');
  const ref=await read(local_root,['rev-parse','--verify','HEAD^{commit}']);sources.push({name,url,ref,local_root});
 }
 return checkedSdkSelection({schema:1,product_id:product,mode:'local',sources});
}
// SDK接口仅允许读取所属官方仓库的正式Release及Tag，沿用产品受限传输和测试注入。
async function sdkGitHubRead(url,path,token){
 if(!Object.values(sdkRepositories).includes(url)||! /^(?:releases\/(?:latest|[1-9]\d*)|git\/ref\/tags\/[^/?#]+|git\/tags\/[a-f0-9]{40})$/u.test(path))fail('SDK正式版查询路径无效');
 const repository=new URL(url).pathname.slice(1,-4),headers={Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2026-03-10'};
 if(token)headers.Authorization='Bearer '+token;
 const response=await (automationTransport.getStore()?.fetchImpl??fetch)('https://api.github.com/repos/'+repository+'/'+path,
  {method:'GET',redirect:'error',credentials:'omit',headers,signal:executions.getStore()?.signal?AbortSignal.any([executions.getStore().signal,AbortSignal.timeout(30000)]):AbortSignal.timeout(30000)});
 if(!response.ok)fail('SDK正式版查询失败：'+repository+' HTTP '+response.status);
 if(!response.body)fail('SDK正式版回执缺失');let bytes=0;const chunks=[];
 for await(const chunk of response.body){bytes+=chunk.length;if(bytes>1024*1024)fail('SDK正式版回执超限');chunks.push(chunk);}
 return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(chunks)));
}
async function sdkReleaseSource(name,url,token,locked){
 const release=await sdkGitHubRead(url,locked?'releases/'+locked.release_id:'releases/latest',token);
 const repository=new URL(url).pathname.slice(1,-4);
 if(!Number.isSafeInteger(release?.id)||release.id<1||release.draft!==false||release.prerelease!==false||typeof release.published_at!=='string'||!Number.isFinite(Date.parse(release.published_at))
  )fail('SDK不是有效正式Release');
 checkedSdkTag(release.tag_name);const address=new URL(release.html_url);
 if(address.origin!=='https://github.com'||address.username||address.password||address.search||address.hash||decodeURIComponent(address.pathname)!=='/'+repository+'/releases/tag/'+release.tag_name)fail('SDK正式Release地址不符');
 const candidate={name,url,release_id:release.id,tag:release.tag_name};
 if(locked&&(release.id!==locked.release_id||release.tag_name!==locked.tag))fail('SDK正式Release归属漂移');
 const reference=await sdkGitHubRead(url,'git/ref/tags/'+encodeURIComponent(release.tag_name),token);
 if(reference.ref!=='refs/tags/'+release.tag_name)fail('SDK正式Tag归属不符');let object=reference.object;const visited=new Set();
 for(let depth=0;object?.type==='tag';depth++){
  if(depth>=8||!/^[a-f0-9]{40}$/u.test(object.sha||'')||visited.has(object.sha))fail('SDK正式Tag链无效');visited.add(object.sha);
  const tag=await sdkGitHubRead(url,'git/tags/'+object.sha,token);if(tag.sha!==object.sha)fail('SDK正式Tag对象漂移');object=tag.object;
 }
 if(object?.type!=='commit'||!/^[a-f0-9]{40}$/u.test(object.sha||'')||locked&&object.sha!==locked.ref)fail('SDK正式Tag提交不符');
 return {...candidate,ref:object.sha};
}
export async function selectReleaseSdkInputs(token,{locked}={}){
 const previous=locked&&checkedSdkSelection(locked,{mode:'release'}),sources=[];
 for(const [name,url]of Object.entries(sdkRepositories))sources.push(await sdkReleaseSource(name,url,token,previous?.sources.find(source=>source.name===name)));
 return checkedSdkSelection({schema:1,product_id:product,mode:'release',sources});
}
function automationSdkInputs(environment){
 const text=environment.CITIZENAPP_SDK_RELEASES;if(typeof text!=='string'||Buffer.byteLength(text)>16384)fail('自动化缺少固定SDK正式版输入');
 return checkedSdkSelection(JSON.parse(text),{mode:'release'});
}

// 只读声明与原始锁；每个第一方Git来源必须同时匹配固定URL、40位提交和resolved-ref。
export function lockedSources() {
 const source=root,path=join(source,'pubspec.yaml');if(!existsSync(path))return [];
 const manifest=readFileSync(path,'utf8'),lock=readFileSync(join(source,'pubspec.lock'),'utf8'),result=[];
 for(const name of ['citizen_sdk','tatachat_sdk']) {
  const block=text=>[...text.matchAll(new RegExp('^  '+name+':\\r?\\n(?: {4,}[^\\n]*\\n|[ \\t]*\\n)+','gm'))];
  const a=block(manifest),b=block(lock);if(!a.length)continue;
  if(a.length!==1||b.length!==1)fail('Git来源记录不唯一');
  const value=(text,key)=>{const m=[...text.matchAll(new RegExp('^ +'+key+':\\s*([^\\n]+)$','gm'))];if(m.length!==1)fail('Git来源字段不唯一');return m[0][1].trim().replace(/^["']|["']$/gu,'');};
  const url=value(a[0][0],'url'),ref=value(a[0][0],'ref');
  if(!/^https:\/\/github\.com\/[a-z0-9-]+\/[a-z0-9-]+\.git$/u.test(url)||!/^[a-f0-9]{40}$/u.test(ref)
   ||value(a[0][0],'path')!=='.'||value(b[0][0],'url')!==url||value(b[0][0],'resolved-ref')!==ref||value(b[0][0],'ref')!==ref)fail('Git声明和锁不一致');
  result.push({name,url,ref});
 }return result;
}
export function requirements(platform,work) {
 checkWork(work);const declared=platformContract(platform);
 const locks=declared.locks.map(value=>({...value})),sources=effectiveSdkSources(work),archives=[];
 const packages=sources.map(source=>({name:source.name,packageRoot:join(work,'git-sources',source.name)}));
 for(const {name,packageRoot} of packages) {
  if(existsSync(packageRoot)) {
   const path=name==='citizen_sdk'?'Cargo.lock':'native/Cargo.lock';
   locks.push({ecosystem:'cargo',path,source_package:name});
   if(name==='citizen_sdk') {
    for(const value of sdkDependencyPlan(packageRoot,nativePlatform(platform)))
     archives.push({ecosystem:'native',...value,group:'sdk-native'});
   }
  }
 }
 // Apple依赖方式由本产品集中输入决定；Podfile 在本轮视图生成，原始锁仍在源码根。
 const apple=platform.endsWith('ios')?'ios':platform.endsWith('macos')?'macos':null;
 if(apple){const base=root,pod=join(base,apple,'Podfile'),lock=join(base,apple,'Podfile.lock');
  if((apple==='ios'&&typeof platformInputs(root).ios['ios/Podfile']==='string')||existsSync(pod)){if(!existsSync(lock))fail('CocoaPods原始锁缺失：'+relative(root,lock));locks.push({ecosystem:'cocoapods',path:relative(root,lock)});}
  else {const project=[join(base,apple,'project/Runner.pbxproj')].find(existsSync);
   if(!project||!readFileSync(project,'utf8').includes('FlutterGeneratedPluginSwiftPackage'))fail('Apple工程缺少明确依赖方式');}
 }
 // 原生源归档坐标归本产品已有声明；准备后才提出展开源码的Cargo锁。
 for(const lock of declared.locks){const file=join(root,lock.path);if(!existsSync(file)||!lstatSync(file).isFile()||lstatSync(file).isSymbolicLink())fail('原始锁缺失或带链接：'+lock.path);}
 return {schema:1,product_id:product,platform,tools:declared.tools,locks,sources,archives};
}

export function resourceEnvironment(platform,work,receipt,base={}) {
 checkWork(work);const declared=platformContract(platform);
 if(!receipt||receipt.schema!==1||receipt.product_id!==product||receipt.platform!==platform||receipt.work!==work||receipt.offline!==true
  ||!receipt.tools||!receipt.dependencies||!receipt.archives)fail('资源回执身份无效');
 const env={HOME:base.HOME,USER:base.USER,LOGNAME:base.LOGNAME,LANG:'zh_CN.UTF-8',LC_ALL:'zh_CN.UTF-8',
  ...receipt.environment,
  // 公开调度身份随同一真实任务传递；令牌不进入工具及SDK测试环境。
  ...(base.GITHUB_ACTIONS==='true'?Object.fromEntries(
    ['GITHUB_ACTIONS','GITHUB_REPOSITORY','GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_SHA']
      .filter(key=>typeof base[key]==='string').map(key=>[key,base[key]])):{}),
  TMPDIR:join(work,'tmp')+sep,TMP:join(work,'tmp'),TEMP:join(work,'tmp'),XDG_CACHE_HOME:join(work,'cache'),XDG_CONFIG_HOME:join(work,'config'),
  CARGO_TARGET_DIR:join(work,'work/cargo-target'),CARGO_NET_OFFLINE:'true',CARGO_INCREMENTAL:'1',
  npm_config_offline:'true',npm_config_audit:'false',npm_config_fund:'false'};
 const expectedSelection=sdkSelectionForWork(work,base),selected=receipt.sdk_selection||expectedSelection;
 if(expectedSelection&&JSON.stringify(checkedSdkSelection(selected))!==JSON.stringify(expectedSelection))fail('资源回执SDK任务锁漂移');
 if(selected)Object.assign(env,sdkSelectionEnvironment(work,selected));
 const allowedEnvironment=new Set(['PRODUCT_WORK_DIR','PRODUCT_BASH_BIN','PRODUCT_RSYNC_BIN','PATH','DEVELOPER_DIR','SDKROOT','DART_EXECUTABLE','XCODEBUILD','XATTR','CODESIGN','SECURITY','XCRUN','XCODE_SELECT','CC','CXX','SWIFT','SWIFTC','OTOOL','INSTALL_NAME_TOOL','LIPO','MAKE','AR','RANLIB','NM','STRIP','LLVM_NM','LD','LDCXX','CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER','ANDROID_HOME','ANDROID_SDK_ROOT','ANDROID_NDK_HOME','ANDROID_USER_HOME','ANDROID_EMULATOR_HOME','GRADLE_INIT_SCRIPT','GRADLE_USER_HOME']);
 if(Object.keys(receipt.environment||{}).some(key=>!allowedEnvironment.has(key)))fail('资源回执包含未声明环境或注入变量');
 for(const tool of declared.tools) {
  const value=receipt.tools[tool.id];
  if(!value||typeof value.path!=='string'||!isAbsolute(value.path)||resolve(value.path)!==value.path)fail('缺少准确版本的工具：'+tool.id);
  const s=lstatSync(value.path);if(!s.isFile()||!(s.mode&0o111))fail('工具入口必须是普通执行器：'+tool.id);
 }
 const aliases={node:'NODE',git:'GIT',flutter:'FLUTTER',rust:'RUSTC',python:'PYTHON',java:'JAVA',gradle:'GRADLE',
  cmake:'CMAKE',cocoapods:'POD',protoc:'PROTOC',zig:'ZIG','worker-build':'WORKER_BUILD','wasm-bindgen':'WASM_BINDGEN_BIN','wasm-opt':'WASM_OPT_BIN',esbuild:'ESBUILD_BIN',
  perl:'PERL',m4:'M4',bison:'BISON',flex:'FLEX',tcl:'TCLSH',gettext:'GETTEXT',openssl:'OPENSSL'};
 for(const [id,name]of Object.entries(aliases))if(receipt.tools[id])env[name]=receipt.tools[id].path;
 // swiftc 是指向 swift-frontend 的官方入口；执行时必须保留 swiftc 名称。
 if(env.SWIFTC&&env.DEVELOPER_DIR){
  const selected=spawnSync('/usr/bin/xcrun',['--find','swiftc'],{encoding:'utf8',env:{PATH:'/usr/bin:/bin',DEVELOPER_DIR:env.DEVELOPER_DIR}});
  const entry=selected.stdout?.trim();
  if(selected.status!==0||!entry||!inside(env.DEVELOPER_DIR,entry)
   ||realpathSync(entry)!==realpathSync(env.SWIFTC))fail('Swift编译入口与已交付Xcode原件不一致');
  env.SWIFTC=entry;
 }
 // POSIX旧Shell不进入正式PATH；基础工具只通过产品已验真的GNU投影交付。
 const paths=Object.entries(receipt.tools).filter(([id])=>id!=='posix').map(([,value])=>dirname(value.path));
 // 官方命令名只投影到回执已验真的准确执行器，优先于Xcode随包的其它版本。
 const commands=join(work,'build-tools'),entries=Object.entries({python3:env.PYTHON,cc:env.CC,'c++':env.CXX}).filter(([,path])=>path);
 if(entries.length){
  const existing=lstatSync(commands,{throwIfNoEntry:false});
  if(existing&&(!existing.isDirectory()||existing.isSymbolicLink()||realpathSync(commands)!==commands))fail('构建工具目录经过链接或非目录');
  if(!existing)mkdirSync(commands,{mode:0o700});
  for(const [name,inputPath]of entries){
   if(typeof inputPath!=='string'||!isAbsolute(inputPath)||resolve(inputPath)!==inputPath)fail('构建工具目标不是规范路径：'+name);
   const target=realpathSync(inputPath),input=lstatSync(target);if(!input.isFile()||input.isSymbolicLink()||!(input.mode&0o111))fail('构建工具目标不是普通执行器：'+name);
   if(name!=='python3'&&(!env.DEVELOPER_DIR||!inside(env.DEVELOPER_DIR,target)))fail('构建编译器越出已验真Xcode');
   const path=join(commands,name),prior=lstatSync(path,{throwIfNoEntry:false});
   if(prior){if(!prior.isSymbolicLink()||readlinkSync(path)!==target||realpathSync(path)!==target)fail('构建工具入口漂移：'+name);}
   else symlinkSync(target,path);
  }
 }
 env.PATH=[...new Set([...(entries.length?[commands]:[]),...paths,...(env.PATH||'').split(':')].filter(Boolean))].join(':');
 if(env.GIT)env.PRODUCT_GIT_BIN=env.GIT;
 if(env.RUSTC)env.CARGO=join(dirname(env.RUSTC),'cargo');
 if(env.FLUTTER){env.FLUTTER_ROOT=dirname(dirname(env.FLUTTER));env.DART_EXECUTABLE=join(env.FLUTTER_ROOT,'bin/cache/dart-sdk/bin/dart');}
 if(env.PYTHON)env.PYTHONHOME=dirname(dirname(env.PYTHON));
 if(env.JAVA)env.JAVA_HOME=dirname(dirname(env.JAVA));
 if(env.OPENSSL)env.TUYU_OPENSSL_PREFIX=dirname(dirname(env.OPENSSL));
 const own=receipt.dependencies.own||{};
 // 原始锁要求的目录必须显式交付，不能落入用户默认缓存。
 for(const lock of declared.locks){const key={npm:'npmCache',pub:'pubCache',cargo:'cargoHome'}[lock.ecosystem];if(key&&!own[key])fail('缺少原始锁依赖回执：'+lock.ecosystem);}
 for(const [key,name]of [['npmCache','npm_config_cache'],['pubCache','PUB_CACHE'],['cargoHome','CARGO_HOME']])if(own[key]){
  checkDependency(work,own[key]);env[name]=own[key];
 }
 for(const [name,value]of Object.entries(receipt.dependencies))if(name!=='own'&&value.cargoHome){checkDependency(work,value.cargoHome);env[name==='citizen_sdk'?'CITIZENAPP_SDK_CARGO_HOME':'CITIZENAPP_CHAT_CARGO_HOME']=value.cargoHome;}
 env[prefix+'_WORK_DIR']=work;env[prefix+'_BUILD_WORK_DIR']=join(work,'work');env[prefix+'_DEPENDENCY_DIR']=join(work,'dependencies');
 env[prefix+'_BUILD_DIR']=join(work,'work/flutter');env[prefix+'_ARTIFACT_DIR']=work;env[prefix+'_OFFLINE']='true';
 env.BUILD_DIR=join(work,'work/flutter');env[prefix+'_NODE_BIN']=env.NODE;
 env[prefix+'_PROJECT_ROOT']=join(work,'source-view',root.replace(/^\/+/u,''));
 env.PRODUCT_SOURCE_DIR=env[prefix+'_PROJECT_ROOT'];
 if(env.GRADLE)env[prefix+'_GRADLE_BIN']=env.GRADLE;
 if(env.GRADLE)env.CITIZENAPP_GRADLE=env.GRADLE;
 env.CITIZENAPP_GRADLE_OFFLINE='true';
 env.GRADLE_USER_HOME=join(work,'dependencies/gradle');env.CP_HOME_DIR=join(work,'dependencies/cocoapods');
 env[prefix+'_PUB_OFFLINE']='true';env.GRADLE_OPTS='-Dorg.gradle.project.android.builder.sdkDownload=false';
 if(receipt.archives.native)env.CHATSERVER_NATIVE_ARCHIVE=receipt.archives.native[0].path;
 if(receipt.archives.protocol)env.CHATSERVER_PROTOCOL_ARCHIVE=receipt.archives.protocol[0].path;


 const execution=executions.getStore();
 env.CITIZENAPP_BUILD_VERSION=execution?.version||localBuildVersion(platform,work);
 if(execution?.delivery==='automation'){env.CITIZENAPP_CI_BUILD='true';env.CITIZENAPP_CI_BUILD_NUMBER=execution.ciEnvironment.GITHUB_RUN_NUMBER;}
 if(execution)execution.buildEnvironment=env;
 return env;
}
function checkDependency(work,path){if(!isAbsolute(path)||resolve(path)!==path||!inside(work,path)||path===work||!lstatSync(path).isDirectory()||realpathSync(path)!==path)fail('依赖回执越界或无效');}
// 工程输入复制到本轮真实目录，保证包解析与写入均不进入正式源码；内部链接映射到同轮副本。
export function createView(source,destination) {
 if(realpathSync(source)!==source||!lstatSync(source).isDirectory()||!isAbsolute(destination)||resolve(destination)!==destination||inside(source,destination)||inside(destination,source))fail('工程输入与输出边界无效');
 let parent=dirname(destination);while(!existsSync(parent))parent=dirname(parent);
 if(!lstatSync(parent).isDirectory()||realpathSync(parent)!==parent)fail('工程输出经过链接');
 if(lstatSync(destination,{throwIfNoEntry:false}))fail('本轮工程已存在');mkdirSync(destination,{recursive:true,mode:0o700});
 const generated=new Set(['.git','.dart_tool','.gradle','.symlinks','Pods','build','target','node_modules','ephemeral','.cache','.DS_Store','swiftpm','dist','tsconfig.tsbuildinfo']);
 function visit(from,to){for(const name of readdirSync(from).sort()){if(generated.has(name))continue;const a=join(from,name),b=join(to,name),s=lstatSync(a);
  if(s.isDirectory()){mkdirSync(b);visit(a,b);}else if(s.isFile()){copyFileSync(a,b);}
  else if(s.isSymbolicLink()){const target=realpathSync(a);if(!inside(source,target)||!lstatSync(target).isFile())fail('源码链接越界');symlinkSync(join(destination,relative(source,target)),b);}else fail('源码文件类型无效');
 }}visit(source,destination);materializePlatformInputs(source,destination);return destination;
}
// 归档坐标只接受本产品当前锁；完整性在build前核验，prepare允许稍后展开的锁。

async function stageArchives(work,receipt) {
 // 归档都来自回执；先按本产品锁回读摘要，再交给现有原生准备器，缺失时禁止下载。
 for(const item of receipt.archives['sdk-native']||[]) {

  const directory=join(work,'dependencies/citizensdk-native/archives');mkdirSync(directory,{recursive:true});
  const suffix=new URL(item.url).pathname.endsWith('.zip')?'.zip':'.tar.gz';
  const target=join(directory,item.sha256+suffix);if(!existsSync(target))copyFileSync(item.path,target);
 }
}
export async function prepare(platform,work,receipt,base) {
 const env=resourceEnvironment(platform,work,receipt,base),source=root;
 for(const name of ['work','tmp','cache','config','dependencies','stage'])mkdirSync(join(work,name),{recursive:true,mode:0o700});
 await stageArchives(work,receipt);
 await run(env.NODE,[join(root,'scripts/build.mjs'),'view',platform==='android'?'create-android':'create','--source-root',source,'--work-root',work],env);
 return {schema:1,product_id:product,platform,work};
}
export async function build(platform,work,receipt,base) {
 const env=resourceEnvironment(platform,work,receipt,base),declared=platformContract(platform);
 await stageArchives(work,receipt);
 const shell=receipt.tools.bash?.path;
 if(!shell)fail('缺少显式Shell资源');
 const project=env[prefix+'_PROJECT_ROOT'];

  // 本仓既有入口要求SDK来源位于本轮依赖目录内；与SDK Cargo环境独立交付。
  env.CITIZENAPP_SDK_DEPENDENCY_WORK_DIR=join(work,'dependencies/citizensdk-native');
  await runShell('run',[platform],env,project,shell);

 const state=executions.getStore();process.stderr.write(buildDisplayName(platform,state?.version||localBuildVersion(platform,work))+'编译完成，开始交付验收\n');
 if(state?.delivery==='automation')return completeAutomation(platform,work,receipt,env,state.ciEnvironment,state.version);
 return completeBuild(platform,work,receipt,env);
}

// 产品自有Security.framework验真器源码，只在本轮工作目录编译。
export const IOS_VERIFIER_SOURCE = String.raw`import Foundation
import Security

struct ProductFailure: Error { let message: String }
enum ProductIOS {
    static let bundleIdentifier = "ios.citizenapp"
    static let productIdentifier = "citizenapp"
    static func numericVersion(_ value: String) -> Bool {
        value.range(of: "^[0-9]+(?:\\.[0-9]+){0,2}$", options: .regularExpression) != nil
    }
    static func inspect(_ app: URL) throws -> [String: Any] {
        let infoURL = app.appendingPathComponent("Info.plist")
        guard let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil) as? [String: Any],
              info["CFBundleIdentifier"] as? String == bundleIdentifier,
              let version = info["CFBundleShortVersionString"] as? String, numericVersion(version),
              let build = info["CFBundleVersion"] as? String, numericVersion(build) else {
            throw ProductFailure(message: "产品iOS Bundle身份或版本无效")
        }
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, SecCSFlags(), &code) == errSecSuccess,
              let code,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode), nil) == errSecSuccess else {
            throw ProductFailure(message: "Apple代码签名API拒绝iOS候选")
        }
        var details: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &details) == errSecSuccess,
              let values = details as? [String: Any],
              values[kSecCodeInfoIdentifier as String] as? String == bundleIdentifier else {
            throw ProductFailure(message: "iOS签名身份与本产品Bundle不符")
        }
        let team = values[kSecCodeInfoTeamIdentifier as String] as? String ?? ""
        if !team.isEmpty && team.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) == nil {
            throw ProductFailure(message: "iOS签名团队标识无效")
        }
        return ["version": version, "build": build, "bundle_id": bundleIdentifier, "team": team]
    }
}

func development(_ product: String, value: Data?) throws -> Data? {
    guard product == ProductIOS.productIdentifier else { throw ProductFailure(message: "citizenapp开发材料身份无效") }
    let service = product + " Development", account = "development:DEV_KEY"
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service, kSecAttrAccount as String: account]
    func read() throws -> Data? {
        var output: CFTypeRef?
        let status = SecItemCopyMatching(query.merging([kSecReturnData as String: true]) { _, v in v } as CFDictionary, &output)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = output as? Data else { throw ProductFailure(message: "产品开发材料读取失败") }
        return data
    }
    if let current = try read() { return current }
    guard let value else { return nil }
    let status = SecItemAdd(query.merging([kSecValueData as String: value,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]) { _, v in v } as CFDictionary, nil)
    guard status == errSecSuccess || status == errSecDuplicateItem else { throw ProductFailure(message: "产品开发材料存储失败") }
    guard let stored = try read() else { throw ProductFailure(message: "产品开发材料写后回读缺失") }
    return stored
}
do {
    let bytes = FileHandle.standardInput.readDataToEndOfFile()
    guard bytes.count <= 128 * 1024,
          let request = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
          let operation = request["operation"] as? String else { throw ProductFailure(message: "产品安全输入无效") }
    let result: Any
    if operation == "ios.verify", let path = request["app"] as? String {
        result = try ProductIOS.inspect(URL(fileURLWithPath: path))
    } else if ["development.read", "development.create"].contains(operation),
              let product = request["product_id"] as? String, product.range(of: "^[a-z][a-z0-9-]*$", options: .regularExpression) != nil {
        var value = (request["value"] as? String).flatMap { Data(base64Encoded: $0) }
        defer { if var bytes = value { bytes.resetBytes(in: 0..<bytes.count) }; value = nil }
        guard operation != "development.create" || value != nil else { throw ProductFailure(message: "开发材料缺失") }
        var stored = try development(product, value: value)
        defer { if var bytes = stored { bytes.resetBytes(in: 0..<bytes.count) }; stored = nil }
        result = ["value": stored?.base64EncodedString() as Any? ?? NSNull()]
    } else { throw ProductFailure(message: "产品安全操作未声明") }
    FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: result))
} catch {
    FileHandle.standardError.write(Data("产品安全验真失败\\n".utf8)); exit(1)
}`;

// 包标识来自本产品唯一原始Android配置，不从调用方登记或另一端推导。
// 本产品独立拥有此实现，通过自身公开接口执行。
function storePath(base,name) {
 if(typeof base!=='string'||!isAbsolute(base)||resolve(base)!==base||realpathSync(base)!==base)fail('商店身份源码根不是准确物理目录');
 if(typeof name!=='string'||!name||name.includes('\\')||/[\x00-\x1f\x7f]/u.test(name)||name.split('/').some(v=>!v||v==='.'||v==='..'))fail('商店身份源码路径无效');
 const path=join(base,name);
 let ancestor=parse(path).root;
 for(const part of relative(ancestor,dirname(path)).split(sep)){
  ancestor=join(ancestor,part);if(!lstatSync(ancestor).isDirectory()||realpathSync(ancestor)!==ancestor)fail('商店身份源码父目录不安全');
 }
 return path;
}
export function readStoreSource(base,name) {
 const path=storePath(base,name),before=lstatSync(path);
 if(!before.isFile()||before.nlink!==1||before.size<=0||before.size>1_048_576)fail('商店身份源码不是有界独占普通文件');
 const fd=openSync(path,constants.O_RDONLY|constants.O_NOFOLLOW|constants.O_NONBLOCK);
 try{
  const opened=fstatSync(fd);
  if(!opened.isFile()||opened.nlink!==1||opened.dev!==before.dev||opened.ino!==before.ino||opened.size!==before.size)fail('商店身份源码打开期间变化');
  const data=Buffer.alloc(opened.size);let offset=0;
  while(offset<data.length){let count;try{count=readSync(fd,data,offset,data.length-offset,offset);}catch(error){if(error.code==='EINTR')continue;throw error;}if(count<=0)fail('商店身份源码读取失败');offset+=count;}
  const after=fstatSync(fd),current=lstatSync(storePath(base,name));
  const same=value=>value.isFile()&&value.nlink===1&&['dev','ino','size','mtimeMs','ctimeMs'].every(key=>value[key]===opened[key]);
  if(data.length!==opened.size||!same(after)||!same(current))fail('商店身份源码读取期间变化');
  return data;
 }finally{closeSync(fd);}
}
// OpenStep工程由产品自己的解析器读取。拒绝重复键、未闭合语法、过深结构和尾随内容。
export function iosStoreBundleID(text) {
 if(typeof text!=='string'||Buffer.byteLength(text)>1_048_576)fail('iOS商店工程超过边界');
 let offset=0,count=0;
 const bad=()=>fail('iOS商店工程语法无效');
 const next=()=>{
  while(offset<text.length){
   if(/\s/u.test(text[offset])){offset++;continue;}
   if(text.startsWith('//',offset)){const end=text.indexOf('\n',offset+2);offset=end<0?text.length:end+1;continue;}
   if(text.startsWith('/*',offset)){const end=text.indexOf('*/',offset+2);if(end<0)bad();offset=end+2;continue;}
   break;
  }
  if(++count>100_000)bad();if(offset===text.length)return null;
  const first=text[offset++];if('{}()=;,'.includes(first))return {symbol:first};
  if(first==='"'){
   let value='';while(offset<text.length){const c=text[offset++];if(c==='"')return {value};
    if(c==='\\'){
     if(offset===text.length)bad();const escaped=text[offset++];
     if(/[0-7]/u.test(escaped)){let octal=escaped;for(let n=0;n<2&&/[0-7]/u.test(text[offset]||'x');n++)octal+=text[offset++];value+=String.fromCharCode(parseInt(octal,8));}
     else if(escaped==='U'){const hex=text.slice(offset,offset+4);if(!/^[0-9a-fA-F]{4}$/u.test(hex))bad();value+=String.fromCharCode(parseInt(hex,16));offset+=4;}
     else if(Object.hasOwn({n:'\n',r:'\r',t:'\t','"':'"','\\':'\\'},escaped))value+=({n:'\n',r:'\r',t:'\t','"':'"','\\':'\\'})[escaped];else bad();
    }else value+=c;
   }bad();
  }
  const start=offset-1;while(offset<text.length&&!/\s/u.test(text[offset])&&!('{}()=;,"'.includes(text[offset]))&&!text.startsWith('/*',offset)&&!text.startsWith('//',offset))offset++;
  return {value:text.slice(start,offset)};
 };
 let token=next();const take=()=>{const value=token;token=next();return value;};
 const expect=symbol=>{if(token?.symbol!==symbol)bad();take();};
 const value=depth=>{
  if(depth>64||!token)bad();
  if(token.symbol==='{'){
   take();const object=Object.create(null);
   while(token?.symbol!=='}'){if(typeof token?.value!=='string')bad();const key=take().value;if(Object.hasOwn(object,key))bad();expect('=');object[key]=value(depth+1);expect(';');}
   take();return object;
  }
  if(token.symbol==='('){take();const array=[];while(token?.symbol!==')'){array.push(value(depth+1));if(token?.symbol===',')take();else if(token?.symbol!==')')bad();}take();return array;}
  if(typeof token.value!=='string')bad();return take().value;
 };
 const document=value(0);if(token!==null)bad();
 const objects=document?.objects,project=objects?.[document.rootObject];
 if(!objects||project?.isa!=='PBXProject'||!Array.isArray(project.targets))fail('iOS商店主工程无效');
 const targets=project.targets.map(id=>objects[id]).filter(v=>v?.isa==='PBXNativeTarget'&&v.name==='Runner'&&v.productType==='com.apple.product-type.application');
 if(targets.length!==1)fail('iOS商店Runner目标不唯一');
 const release=owner=>{
  const list=objects[owner.buildConfigurationList];if(list?.isa!=='XCConfigurationList'||!Array.isArray(list.buildConfigurations))fail('iOS商店配置列表无效');
  const configurations=list.buildConfigurations.map(id=>objects[id]).filter(v=>v?.isa==='XCBuildConfiguration'&&v.name==='Release');
  if(configurations.length!==1||!configurations[0].buildSettings||Array.isArray(configurations[0].buildSettings)||typeof configurations[0].buildSettings!=='object')fail('iOS商店Release配置不唯一');
  return configurations[0].buildSettings;
 };
 const bundle={...release(project),...release(targets[0])}.PRODUCT_BUNDLE_IDENTIFIER;
 if(typeof bundle!=='string'||/[\r\n]/u.test(bundle)||!/^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/u.test(bundle))fail('iOS商店应用标识无效');
 return bundle;
}
export function androidStorePackageName(text) {
 const matches=[...text.matchAll(/\bapplicationId\s*(?:=\s*)?["']([A-Za-z0-9_.]+)["']/gu)];
 if(matches.length!==1||!/^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+$/u.test(matches[0][1]))fail('Android应用标识无效');return matches[0][1];
}
export function storeIdentity() {
 const source=root,choose=names=>{
  const found=names.filter(name=>{try{lstatSync(storePath(root,name));return true;}catch(error){if(error.code==='ENOENT')return false;throw error;}});
  if(found.length!==1)fail('商店身份原始工程不唯一');return found[0];
 };
 const names=['scripts/build.mjs',
  choose(['project/Runner.pbxproj','Runner.pbxproj'].map(name=>relative(root,join(source,'ios',name)))),
  choose(['build.gradle.kts','build.gradle'].map(name=>relative(root,join(source,'android/app',name))))];
 const data=names.map(name=>readStoreSource(root,name)),sha=data=>createHash('sha256').update(data).digest('hex');
 if(contract.schema!==1||contract.product_id!==product||contract.entry!=='scripts/build.mjs')fail('商店身份公开入口不一致');
 const receipt={schema:1,product_id:product,bundle_id:iosStoreBundleID(data[1].toString('utf8')),package_name:androidStorePackageName(data[2].toString('utf8')),
  source_files:names.map((path,n)=>({path,sha256:sha(data[n])}))};
 if(names.some((name,n)=>sha(readStoreSource(root,name))!==receipt.source_files[n].sha256))fail('商店身份源码在解析期间变化');
 return receipt;
}

export function androidPackageName() {
 const directory=join(root,'android/app');const paths=['build.gradle.kts','build.gradle'].map(n=>join(directory,n)).filter(existsSync);
 if(paths.length!==1)fail('Android应用工程不唯一');
 return androidStorePackageName(readFileSync(paths[0],'utf8'));
}
export function androidUSBSerials(text) {
 const lines=text.trim().split(/\r?\n/u);if(lines.shift()!=='List of devices attached')fail('ADB设备列表无效');
 const serials=[],seen=new Set();for(const line of lines.filter(Boolean)){
  const parts=line.trim().split(/\s+/u),serial=parts[0];if(!parts.some(x=>x.startsWith('usb:')))continue;
  if(parts[1]!=='device'||!serial||serial.includes(':')||serial.startsWith('emulator-')||!/^[A-Za-z0-9._-]+$/u.test(serial)||seen.has(serial))fail('USB设备状态或身份无效');
  seen.add(serial);serials.push(serial);
 }if(serials.length<2)fail('多台USB目标回读不一致');return serials;
}
export function androidInstalledPath(result) {
 if(result.code===1&&!result.stdout.trim()&&!result.stderr.trim())return null;
 if(result.code!==0||result.stderr.trim()||!/^package:\/data\/app\/[A-Za-z0-9_./=+~-]+\/base\.apk\s*$/u.test(result.stdout)||result.stdout.includes('..'))fail('Android安装路径回读无效');
 return result.stdout.trim().slice('package:'.length);
}
export function androidCertificate(text) {
 const matches=[...text.matchAll(/Signer #\d+ certificate SHA-256 digest:\s*([a-fA-F0-9]{64})/gu)];
 if(matches.length!==1||!text.includes('Verified using v2 scheme (APK Signature Scheme v2): true'))fail('Android签名证书或v2验真失败');return matches[0][1].toLowerCase();
}
async function nativeVerifier(work,env) {
 const state=executions.getStore();if(state?.verifier)return state.verifier;
 const dir=join(work,'product-verifier');mkdirSync(dir,{mode:0o700});const source=join(dir,'verify.swift'),binary=join(dir,'verify');
 writeFileSync(source,IOS_VERIFIER_SOURCE,{flag:'wx',mode:0o600});
 await run(env.SWIFTC,['-emit-executable','-O','-module-cache-path',join(work,'cache/swift'),'-framework','Security',source,'-o',binary],env,work);
 const digest=outputDigest(binary);
 const verify=async request=>{if(outputDigest(binary)!==digest)fail('产品安全验真器发生变化');return JSON.parse((await runBuildProcess(binary,[],env,work,{capture:true,input:JSON.stringify(request),timeout:300000})).stdout);};
 if(state)state.verifier=verify;return verify;
}
async function developmentMaterial(work,env,value) {
 const operation=value===undefined?'development.read':'development.create';
 const verifier=await nativeVerifier(work,env);return (await verifier({operation,product_id:product,...(value===undefined?{}:{value})})).value;
}
export function parseAndroidSigning(encoded) {
 if(typeof encoded!=='string'||encoded.length>128*1024)fail('开发签名材料无效');const bytes=Buffer.from(encoded,'base64');
 try{const fields={};for(const raw of bytes.toString('utf8').split(/\r?\n/u)){const line=raw.trim();if(!line||line.startsWith('#'))continue;const at=line.indexOf('='),key=line.slice(0,at).trim(),value=line.slice(at+1).trim();if(at<1||!['keystore','password','alias','keyPassword'].includes(key)||Object.hasOwn(fields,key)||!value)fail('开发签名字段无效');fields[key]=value;}
  const keystore=Buffer.from(fields.keystore||'','base64');if(keystore.length<1024||keystore.length>64*1024||!fields.password||Buffer.byteLength(fields.password)>1024||Buffer.byteLength(fields.keyPassword||fields.password)>1024||!/^[A-Za-z0-9._-]{1,128}$/u.test(fields.alias||'development')){keystore.fill(0);fail('开发签名材料缺失');}
  return {keystore,password:fields.password,alias:fields.alias||'development',keyPassword:fields.keyPassword||fields.password};
 }finally{bytes.fill(0);}
}
function installationFailure(message){const error=Error(message);error.code='PRODUCT_INSTALLATION_FAILED';return error;}
async function checkedInstallationOutcome(error,state){
 state?.signal?.throwIfAborted();if(error.code!=='PRODUCT_INSTALLATION_FAILED'||state?.unconfirmed||!state?.verifyLocalArtifact)throw error;
 await state.verifyLocalArtifact();return {state:'failed',code:error.code,message:error.message};
}
async function completeAndroid(platform,work,receipt,env) {
 const packageName=androidPackageName(),sdk=env.ANDROID_HOME;
 const definitions=resourceRuntime.resourceDeclarations().android;
 const buildTools=definitions.filter(x=>x.path.startsWith('build-tools;'));if(buildTools.length!==1)fail('Android签名工具版本不唯一');
 const signer=join(sdk,...buildTools[0].path.split(';'),'apksigner'),analyzer=join(dirname(receipt.tools['android-sdk'].path),'apkanalyzer'),adb=receipt.tools.android.path,keytool=join(dirname(env.JAVA),'keytool');
 for(const file of [signer,analyzer,adb,keytool]){const s=lstatSync(file);if(!s.isFile()||!(s.mode&0o111)||realpathSync(file)!==file)fail('Android签名安装工具入口无效');}
 const call=(file,args,extra={})=>runBuildProcess(file,args,{...env,...extra},work,{capture:true,timeout:600000});
 const candidate=join(work,'android.apk'),signed=join(work,'android.signed.apk');
 if(existsSync(signed)||!lstatSync(candidate).isFile()||realpathSync(candidate)!==candidate)fail('Android本轮候选无效');
 const manifest=async(apk,field)=>(await call(analyzer,['manifest',field,apk])).stdout.trim();
 const inspect=async(apk,certificate)=>{
  if(await manifest(apk,'application-id')!==packageName||await manifest(apk,'debuggable')!=='false')fail('Android候选产品或Release配置无效');
  const version={name:await manifest(apk,'version-name'),code:await manifest(apk,'version-code')};if(!version.name||version.name.length>128||!/^[1-9]\d*$/u.test(version.code))fail('Android候选版本无效');
  if(certificate&&androidCertificate((await call(signer,['verify','--verbose','--print-certs',apk])).stdout)!==certificate)fail('Android安装证书不一致');return version;
 };
 const version=await inspect(candidate);if(version.name!==env.CITIZENAPP_BUILD_VERSION)fail('Android产品版本与本平台编译版本不符');
 const unsigned=await runBuildProcess(signer,['verify','--print-certs',candidate],env,work,{capture:true,accepted:[0,1],timeout:300000});
 if(unsigned.code!==1||!(unsigned.stdout+unsigned.stderr).includes('DOES NOT VERIFY'))fail('Android候选必须是未签名Release包');
 let encoded=await developmentMaterial(work,env);
 if(encoded===null){
  const generated=join(work,'development.p12'),password=randomBytes(32).toString('base64url');
  try{
   await call(keytool,['-genkeypair','-storetype','PKCS12','-keystore',generated,'-storepass:env','PRODUCT_STORE_PASSWORD','-keypass:env','PRODUCT_KEY_PASSWORD','-alias','development','-keyalg','RSA','-keysize','4096','-validity','36500','-dname','CN=Product Development,O=GMB,C=US'],{PRODUCT_STORE_PASSWORD:password,PRODUCT_KEY_PASSWORD:password});
   const material=readFileSync(generated);try{unlinkSync(generated);encoded=await developmentMaterial(work,env,Buffer.from('keystore='+material.toString('base64')+'\npassword='+password+'\nalias=development\nkeyPassword='+password+'\n').toString('base64'));}finally{material.fill(0);}
  }finally{if(existsSync(generated)&&!executions.getStore()?.unconfirmed)unlinkSync(generated);}
 }
 const signing=parseAndroidSigning(encoded);encoded='';const temporary=join(work,'android-signing.keystore');
 try{
  writeFileSync(temporary,signing.keystore,{flag:'wx',mode:0o600});signing.keystore.fill(0);
  await call(signer,['sign','--ks',temporary,'--ks-pass','env:PRODUCT_STORE_PASSWORD','--key-pass','env:PRODUCT_KEY_PASSWORD','--ks-key-alias',signing.alias,'--out',signed,candidate],{PRODUCT_STORE_PASSWORD:signing.password,PRODUCT_KEY_PASSWORD:signing.keyPassword});
 }finally{signing.keystore.fill(0);signing.password='';signing.keyPassword='';if(existsSync(temporary)&&!executions.getStore()?.unconfirmed)unlinkSync(temporary);}
 const certificate=androidCertificate((await call(signer,['verify','--verbose','--print-certs',signed])).stdout);
 if(JSON.stringify(await inspect(signed,certificate))!==JSON.stringify(version))fail('Android签名后版本漂移');const digest=outputDigest(signed);
 const install=async(target,index)=>{
  if(outputDigest(signed)!==digest)fail('Android安装前签名产物改变');
  const result=await runBuildProcess(adb,[...target,'install','-r',signed],env,work,{capture:true,accepted:[0,1],timeout:600000});if(result.code===1)throw installationFailure('Android设备安装失败');if(!result.stdout.split(/\r?\n/u).includes('Success'))fail('Android安装成功回执无效');
  await readback(target,index);
 };
 const readback=async(target,index)=>{
  const result=await runBuildProcess(adb,[...target,'shell','pm','path',packageName],env,work,{capture:true,accepted:[0,1],timeout:300000}),path=androidInstalledPath(result);
  if(!path)fail('Android安装后包缺失');const file=join(work,'installed-after-'+index+'.apk');
  if(existsSync(file))fail('Android回读路径已存在');await call(adb,[...target,'pull',path,file]);
  if(realpathSync(file)!==file||JSON.stringify(await inspect(file,certificate))!==JSON.stringify(version))fail('Android安装后产品、证书或版本不一致');
 };
 await saveMobileArtifact(platform,work,signed);
 const state=executions.getStore();if(state)state.verifyLocalArtifact=async()=>{if(outputDigest(signed)!==digest||outputDigest(join(work,'android.apk'))!==digest||JSON.stringify(await inspect(signed,certificate))!==JSON.stringify(version))fail('Android签名产物在交付失败后漂移');};
 if(outputDigest(signed)!==digest)fail('Android安装前签名产物改变');
 const first=await runBuildProcess(adb,['-d','install','-r',signed],env,work,{capture:true,accepted:[0,1],timeout:300000});
 if(first.code===0&&first.stdout.split(/\r?\n/u).includes('Success'))await readback(['-d'],0);
 else{
  if(first.code===1&&!first.stderr.includes('more than one device'))throw installationFailure('ADB直接USB安装失败');if(first.code!==1)fail('ADB直接USB安装回执无效');
  const serials=androidUSBSerials((await call(adb,['devices','-l'])).stdout);let failures=0,unsafe=null;
  for(let i=0;i<serials.length;i++){executions.getStore()?.signal?.throwIfAborted();try{await install(['-s',serials[i]],i);}catch(error){executions.getStore()?.signal?.throwIfAborted();if(error.code!=='PRODUCT_INSTALLATION_FAILED')unsafe??=error;failures++;}}
  if(unsafe)throw unsafe;if(failures)throw installationFailure('Android USB安装失败'+failures+'/'+serials.length+'，已尝试全部设备');
 }
 renameSync(signed,join(work,'android.apk'));
 process.stderr.write('本机移动产物已签名验真；设备安装及产品身份、版本回读通过\n');
}
export function iosDeviceCandidates(response) {
 if(response?.info?.outcome!=='success'||!Array.isArray(response?.result?.devices))fail('iOS设备列表无效');
 const candidates=response.result.devices.filter(d=>d?.properties?.hardware?.reality==='physical'&&d.properties.hardware.platform==='iOS'&&d.properties.connection?.pairingState==='paired'&&d.properties.state?.developerModeStatus?.enabled?.mode===1);
 for(const d of candidates)if(!/^[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$/u.test(d.identifier)||!/^(?:[a-fA-F0-9]{40}|[a-fA-F0-9]{8}-[a-fA-F0-9]{16})$/u.test(d.properties.hardware.udid))fail('iOS物理设备身份无效');
 return candidates.map(d=>({identifier:d.identifier,udid:d.properties.hardware.udid}));
}
export function iosInstalled(response,device,bundle) {
 const result=response?.result;
 if(response?.info?.outcome!=='success'||result?.deviceIdentifier!==device||result.matchingBundleIdentifier!==bundle||!Array.isArray(result.apps)||result.apps.length>1)fail('iOS安装回读设备或过滤身份无效');
 if(!result.apps.length)return null;const app=result.apps[0];if(app.bundleIdentifier!==bundle||typeof app.version!=='string'||typeof app.bundleVersion!=='string')fail('iOS应用版本回读无效');return {version:app.version,build:app.bundleVersion};
}
export function iosVersion(value) {if(typeof value!=='string'||!/^\d+(?:\.\d+){0,2}$/u.test(value))fail('iOS版本无效');return [...value.split('.').map(BigInt),0n,0n].slice(0,3);}
async function completeIOS(platform,work,receipt,env) {
 const signal=executions.getStore()?.signal,helper=await nativeVerifier(work,env),archive=join(work,'ios.app.zip'),archiveDigest=outputDigest(archive),directory=join(work,'ios-product');
 await resourceRuntime.extractArchive(archive,directory,{signal,maxBytes:2*1024**3});
 if(readdirSync(directory).join(',')!=='Runner.app')fail('iOS归档只能包含唯一Runner.app');const app=join(directory,'Runner.app');
 let sequence=0;
 // devicectl官方入口可能是无签名启动脚本；只接受本轮Xcode所定位且Apple签名通过的真实执行器。
 const found=(await runBuildProcess(env.XCRUN,['--find','devicectl'],env,work,{capture:true,timeout:60000})).stdout.trim();
 const installed='/Library/Developer/PrivateFrameworks/CoreDevice.framework/Versions/A/Resources/bin/devicectl';
 const tool=realpathSync(existsSync(installed)?installed:found);
 if(!tool.startsWith(env.DEVELOPER_DIR+'/')&&tool!==installed)fail('devicectl不属于当前Apple工具边界');
 await runBuildProcess(env.CODESIGN,['--verify','--strict','-R','=anchor apple',tool],env,work,{capture:true,timeout:60000});
 const deviceCall=async(args,seconds=120)=>{
  const file=join(work,'device-'+(++sequence)+'.json');
  await runBuildProcess(tool,[...args,'--json-output',file,'--omit-deprecated-fields-in-json','--timeout',String(seconds)],env,work,{capture:true,timeout:(seconds+10)*1000});
  if(realpathSync(file)!==file||!lstatSync(file).isFile()||lstatSync(file).size>4*1024*1024)fail('iOS设备结果文件无效');
  const response=JSON.parse(readFileSync(file,'utf8'));unlinkSync(file);if(response?.info?.outcome!=='success')fail('iOS设备命令失败');return response;
 };
 const findDevice=async()=>{
  for(let attempt=0;attempt<8;attempt++){
   signal?.throwIfAborted();const candidates=iosDeviceCandidates(await deviceCall(['list','devices'],5)),reachable=[];
   for(const d of candidates){let response;try{response=await deviceCall(['device','info','details','--device',d.identifier],5);}catch{signal?.throwIfAborted();continue;}
    const found=response.result,properties=found?.properties;
    if(found?.identifier!==d.identifier||properties?.hardware?.udid!==d.udid||properties.hardware.reality!=='physical'||properties.hardware.platform!=='iOS'||properties.connection?.pairingState!=='paired'||properties.state?.developerModeStatus?.enabled?.mode!==1)fail('iOS主动探测设备身份漂移');reachable.push(d);
   }
   if(reachable.length>1)throw installationFailure('多台可用iOS真机无法确定安装设备');if(reachable.length===1)return reachable[0];
   if(attempt<7)await pauseBuild(2000,signal);
  }throw installationFailure('iOS真机等待就绪超时');
 };
 const prepared=await helper({operation:'ios.verify',app});if(prepared.version!==env.CITIZENAPP_BUILD_VERSION)fail('iOS产品版本与本平台编译版本不符');
 const state=executions.getStore();if(state)state.verifyLocalArtifact=async()=>{if(outputDigest(archive)!==archiveDigest||JSON.stringify(await helper({operation:'ios.verify',app}))!==JSON.stringify(prepared))fail('iOS签名产物在交付失败后漂移');};
 const device=await findDevice();
 const before=iosInstalled(await deviceCall(['device','info','apps','--device',device.identifier,'--include-all-apps','--bundle-id',prepared.bundle_id]),device.identifier,prepared.bundle_id);
 const less=(a,b)=>{for(let i=0;i<3;i++){if(a[i]<b[i])return true;if(a[i]>b[i])return false;}return false;};
 if(before&&(less(iosVersion(prepared.version),iosVersion(before.version))||!less(iosVersion(prepared.version),iosVersion(before.version))&&!less(iosVersion(before.version),iosVersion(prepared.version))&&less(iosVersion(prepared.build),iosVersion(before.build))))fail('iOS禁止降级安装');
 const refreshed=await findDevice();if(JSON.stringify(refreshed)!==JSON.stringify(device)||JSON.stringify(await helper({operation:'ios.verify',app}))!==JSON.stringify(prepared))fail('iOS安装前设备或签名产物漂移');
 if(outputDigest(archive)!==archiveDigest)fail('iOS归档输入漂移');
 await saveMobileArtifact(platform,work,archive);
 try{await deviceCall(['device','install','app','--device',device.identifier,app]);}catch(error){signal?.throwIfAborted();if(executions.getStore()?.unconfirmed||!(/^产品工具执行失败（exit=[1-9]\d*，signal=none，errors=none，/u.test(error.message)||error.message.endsWith('iOS设备命令失败')))throw error;throw installationFailure('iOS设备安装命令失败');}
 const after=iosInstalled(await deviceCall(['device','info','apps','--device',device.identifier,'--include-all-apps','--bundle-id',prepared.bundle_id]),device.identifier,prepared.bundle_id);
 if(!after||after.version!==prepared.version||after.build!==prepared.build)fail('iOS安装后产品或版本回读不一致');
 if(outputDigest(archive)!==archiveDigest||JSON.stringify(await helper({operation:'ios.verify',app}))!==JSON.stringify(prepared))fail('iOS安装期间签名产物漂移');
 process.stderr.write('本机移动产物已签名验真；设备安装及产品身份、版本回读通过\n');
}
function pauseBuild(ms,signal){signal?.throwIfAborted();return new Promise((resolve,reject)=>{const abort=()=>{clearTimeout(timer);reject(Error('产品任务已取消'));};const timer=setTimeout(()=>{signal?.removeEventListener('abort',abort);resolve();},ms);signal?.addEventListener('abort',abort,{once:true});if(signal?.aborted)abort();});}
async function saveMobileArtifact(platform,work,path) {
 const declared=platformContract(platform);if(declared.files.length!==1)fail('移动候选登记不唯一');
 const publicPath=join(work,declared.files[0]);
 if(path!==publicPath){unlinkSync(publicPath);copyFileSync(path,publicPath);}
}
async function completeMobile(platform,work,receipt,env) {
 executions.getStore()?.signal?.throwIfAborted();if(platform.endsWith('android'))await completeAndroid(platform,work,receipt,env);else await completeIOS(platform,work,receipt,env);
}

// 每次调用拥有自己的取消和进程集合，导入API并发也不能共享执行状态。
const executions=new AsyncLocalStorage();
// 退出诊断仅接受系统错误码；命令、参数、环境和原始错误正文不进入诊断。
function processErrorCode(error) {
 const code=error?.code;
 return typeof code==='string'&&(Object.hasOwn(resourceOs.constants.errno,code)||['ERR_INVALID_ARG_TYPE','ERR_OUT_OF_RANGE','ERR_UNKNOWN_SIGNAL'].includes(code))?code:'UNKNOWN';
}
// ps只请求数字归属和状态；仅保留本轮进程组及可证实的后代，不读取命令行。
function processGroupMembers(source,pid) {
 const rows=[];
 for(const line of source.split('\n')){
  const match=/^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([A-Za-z+<>=-]{1,16})\s*$/u.exec(line);
  if(!match)continue;
  const [member,ppid,pgid,uid]=match.slice(1,5).map(Number);
  if(![member,ppid,pgid,uid].every(Number.isSafeInteger)||member<1)continue;
  rows.push({pid:member,ppid,pgid,uid,state:match[5][0]});
 }
 const descendants=new Set([pid]);let changed=true;
 while(changed){changed=false;for(const row of rows)if(descendants.has(row.ppid)&&!descendants.has(row.pid)){descendants.add(row.pid);changed=true;}}
 const members=rows.filter(row=>row.pgid===pid||descendants.has(row.pid));
 return {members:members.slice(0,32),truncated:members.length>32};
}
function processGroupSnapshot(pid) {
 if(!Number.isSafeInteger(pid)||pid<1)return {status:'notStarted',members:[],truncated:false};
 if(process.platform==='win32')return {status:'unsupported',members:[],truncated:false};
 try{
  const result=spawnSync('/bin/ps',['-axo','pid=,ppid=,pgid=,uid=,stat='],{encoding:'utf8',timeout:1000,maxBuffer:256*1024,env:{PATH:'/usr/bin:/bin',LANG:'C',LC_ALL:'C'}});
  if(result.error||result.status!==0)return {status:'unavailable',code:processErrorCode(result.error),members:[],truncated:false};
  return {status:'ok',...processGroupMembers(result.stdout,pid)};
 }catch(error){return {status:'unavailable',code:processErrorCode(error),members:[],truncated:false};}
}
export async function runBuildProcess(file,args,env,cwd=root,{capture=false,input,accepted=[0],timeout=7200000,signal=executions.getStore()?.signal,passHost=false,streamError=false,outputLimit=16*1024*1024}={}) {
 if(!Number.isSafeInteger(outputLimit)||outputLimit<1||outputLimit>16*1024*1024)fail('产品工具输出上限无效');
 signal?.throwIfAborted();
 return new Promise((ok,reject)=>{
  const started=performance.now(),timeline=[],snapshots=[];let omitted=0;
  const elapsed=()=>Math.round(performance.now()-started);
  const mark=(event,fields={})=>{if(timeline.length<48)timeline.push({ms:elapsed(),event,...fields});else omitted++;};
  const signalName=value=>typeof value==='string'&&Object.hasOwn(resourceOs.constants.signals,value)?value:'none';
  const child=spawn(file,args,{cwd,env:workEnvironment(env),detached:true,stdio:['pipe','pipe','pipe',...(passHost?[3]:[])]});
  mark('created');
  trackWorkProcess(child.pid);
  let stdout=[],stderr=[],bytes=0,reason,settled=false;
  // 最多两次只读快照；采样失败不改变原有探测、信号或退出判定。
  const sample=stage=>{if(snapshots.length<2)snapshots.push({ms:elapsed(),stage,...processGroupSnapshot(child.pid)});};
  const diagnostics=new Map(),record=(stage,error)=>{const code=processErrorCode(error);diagnostics.set(stage,code);mark(stage,{code});if(stage==='probe'&&snapshots.length===0)sample('probeError');};
  const stop=()=>{try{process.kill(-child.pid,'SIGTERM');mark('SIGTERM',{code:'sent'});}catch(error){if(error.code!=='ESRCH'){record('SIGTERM',error);reason='无法取消产品工具进程组';}else mark('SIGTERM',{code:'ESRCH'});}};
  let killer;
  const terminate=()=>{stop();clearTimeout(killer);killer=setTimeout(()=>{try{process.kill(-child.pid,'SIGKILL');mark('SIGKILL',{code:'sent'});}catch(error){if(error.code!=='ESRCH')record('SIGKILL',error);else mark('SIGKILL',{code:'ESRCH'});}},1500);};
  const forced=setTimeout(()=>{mark('timeout');reason='产品工具超时';terminate();},timeout);forced.unref();
  const abort=()=>{mark('abort');reason='产品任务已取消';terminate();};
  signal?.addEventListener('abort',abort,{once:true});
  const consume=(chunk,out)=>{bytes+=chunk.length;if(bytes>outputLimit){reason='产品工具输出超限';terminate();return;}out.push(chunk);if(!capture)process.stderr.write(chunk);};
  child.stdout.on('data',chunk=>consume(chunk,stdout));child.stderr.on('data',chunk=>{if(capture&&streamError)process.stderr.write(chunk);else consume(chunk,stderr);});
  child.stdin.on('error',error=>{record('stdin',error);reason='产品工具输入失败';stop();});
  child.once('error',error=>{record('spawn',error);reason='产品工具无法启动';});
  child.once('spawn',()=>mark('spawn'));
  child.once('exit',(code,termination)=>mark('exit',{code:Number.isSafeInteger(code)?code:null,signal:signalName(termination)}));
  child.once('close',async(code,termination)=>{
   mark('close',{code:Number.isSafeInteger(code)?code:null,signal:signalName(termination)});
   clearTimeout(forced);clearTimeout(killer);
   // 主进程close不代表后代退出；未退出的同组工具必须停止并确认，之后才能清理材料。
   const alive=()=>{if(!child.pid)return false;try{process.kill(-child.pid,0);mark('probe',{code:'alive'});return true;}catch(error){if(error.code!=='ESRCH')record('probe',error);else mark('probe',{code:'ESRCH'});return error.code!=='ESRCH';}};
   if(alive()){if(snapshots.length===0)sample('beforeStop');reason??='产品工具退出后仍有后代';stop();for(let n=0;n<15&&alive();n++)await new Promise(r=>setTimeout(r,100));if(alive())try{process.kill(-child.pid,'SIGKILL');mark('SIGKILL',{code:'sent'});}catch(error){if(error.code!=='ESRCH')record('SIGKILL',error);else mark('SIGKILL',{code:'ESRCH'});};for(let n=0;n<15&&alive();n++)await new Promise(r=>setTimeout(r,100));}
   if(alive()){reason='产品工具后代退出未确认，保留工作目录';const state=executions.getStore();if(state)state.unconfirmed=true;}
   signal?.removeEventListener('abort',abort);clearTimeout(killer);
   if(signal?.aborted)reason='产品任务已取消';
   if(settled)return;settled=true;
   if(reason||termination||!accepted.includes(code)){
    const exit=Number.isSafeInteger(code)?String(code):'none';
    sample('settled');
    const processDetails={pid:Number.isSafeInteger(child.pid)?child.pid:null,expectedPgid:Number.isSafeInteger(child.pid)?child.pid:null,parentPid:process.pid,parentUid:process.getuid?.()??null,elapsedMs:elapsed(),timeline,omitted,snapshots};
    reject(Error(`${reason||'产品工具执行失败'}（exit=${exit}，signal=${signalName(termination)}，errors=${[...diagnostics].map(([stage,value])=>`${stage}:${value}`).join(',')||'none'}，process=${JSON.stringify(processDetails)}）`));
   }
   else ok({stdout:Buffer.concat(stdout).toString('utf8'),stderr:Buffer.concat(stderr).toString('utf8'),code});
  });
  child.stdin.end(input);
 });
}
const run=async(file,args,env,cwd=root,capture=false)=>(await runBuildProcess(file,args,env,cwd,{capture})).stdout;

export function outputDigest(path) {
 const hash=createHash('sha256');const base=path;
 function visit(file){const info=lstatSync(file);const name=relative(base,file);
  if(info.isSymbolicLink()){const real=realpathSync(file);if(!inside(base,real))fail('输出链接越界');hash.update(JSON.stringify([name,'link',readlinkSync(file)])+'\n');}
  else if(info.isDirectory()){hash.update(JSON.stringify([name,'directory'])+'\n');for(const child of readdirSync(file).sort())visit(join(file,child));}
  else if(info.isFile()&&info.nlink===1){hash.update(JSON.stringify([name,'file',Boolean(info.mode&0o111),info.size])+'\n');hash.update(readFileSync(file));}
  else fail('输出包含特殊文件或硬链接');
 }visit(path);return hash.digest('hex');
}

// 宿主完整Build先由调用方消费回执、安装并收尾；独立执行由本产品清空现场。
// 本产品拥有测试清单、资源准备和执行顺序。
function testFiles(){
 const result=['scripts/build.mjs','scripts/publish.mjs'];
 const visit=directory=>{for(const row of readdirSync(directory,{withFileTypes:true})){
  const path=join(directory,row.name);if(row.isSymbolicLink())fail('Node测试目录禁止链接');
  if(row.isDirectory())visit(path);else if(row.isFile()&&row.name.endsWith('.test.mjs'))result.push(relative(root,path));
 }};visit(join(root,'test'));return result.sort();
}
// 清单与Node版本只有本产品这一处定义，独立验收和完整Build共同消费。
export function nodeVerificationPlan(){
 const versions=[...new Set(Object.values(contract.platforms).flatMap(value=>value.tools.filter(tool=>tool.id==='node').map(tool=>tool.version)))];
 if(versions.length!==1)fail('本产品Node测试版本不唯一');
 return {schema:1,product_id:product,mode:'node',node_version:versions[0],files:testFiles()};
}
export function parseNodeTestReport(text,exitCode){
 if(typeof text!=='string'||Buffer.byteLength(text)>16*1024*1024||!/^TAP version 13\r?\n/u.test(text)||![0,1].includes(exitCode))fail('Node测试报告或退出码无效');
 const plans=[...text.matchAll(/^1\.\.([0-9]+)\r?$/gm)],roots=[...text.matchAll(/^(ok|not ok) ([1-9][0-9]*)(?: - [^\r\n]*)?\r?$/gm)];
 if(plans.length!==1||!Number.isSafeInteger(Number(plans[0][1]))||Number(plans[0][1])<1||roots.length!==Number(plans[0][1])||roots.some((row,index)=>Number(row[2])!==index+1))fail('Node测试报告计划或完成事件不完整');
 const names={tests:'tests',pass:'passed',fail:'failed',cancelled:'cancelled',skipped:'skipped',todo:'todo'},result={};
 for(const [name,key]of Object.entries(names)){
  const matches=[...text.matchAll(new RegExp('^# '+name+' ([0-9]+)\\r?$','gm'))];
  if(matches.length!==1)fail('Node测试报告计数缺失或重复：'+name);
  const value=Number(matches[0][1]);if(!Number.isSafeInteger(value)||value<0)fail('Node测试报告计数无效');result[key]=value;
 }
 if(!result.tests||result.passed+result.failed+result.cancelled+result.skipped+result.todo!==result.tests)fail('Node测试报告不完整');
 return {...result,exit_code:exitCode,signal:null,status:exitCode===0&&result.passed===result.tests&&roots.every(row=>row[1]==='ok')?'success':'failed'};
}
function nodeTestEnvironment(base,work,session){
 checkWork(work);
 const environment={...base};
 for(const key of Object.keys(environment))if(/TOKEN|PASSWORD|SECRET|PRIVATE_KEY|CREDENTIAL|API_KEY|PASSPHRASE/iu.test(key)||['APP_KEY','IOS_KEY','IOS_PROVISIONING_PROFILE','NODE_OPTIONS','NODE_PATH','NODE_TEST_CONTEXT','NODE_V8_COVERAGE','NODE_REPL_HISTORY','NODE_EXTRA_CA_CERTS','NODE_TLS_REJECT_UNAUTHORIZED','PRODUCT_WORK_LEASE','SSH_AUTH_SOCK','SSH_AGENT_PID','GIT_SSH','GIT_SSH_COMMAND','RUBYOPT','RUBYLIB','DYLD_LIBRARY_PATH','DYLD_INSERT_LIBRARIES','LD_PRELOAD','FORCE_COLOR'].includes(key))delete environment[key];
 return {...environment,CI:'true',NO_COLOR:'1',NODE_DISABLE_COLORS:'1',CITIZENAPP_OFFLINE:'true',CITIZENAPP_TEST_SESSION:session};
}
function withNodeTestSession(session,action){
 if(typeof session!=='string'||!/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/u.test(session))fail('Node测试会话无效');
 return nodeVerificationSessions.run(session,action);
}
function clearNodeTestSession(session){
 return withNodeTestSession(session,()=>{
  for(const platform of Object.keys(contract.platforms)){const path=fixedWork('build/'+platform);if(existsSync(path))finishFixedWork(path);}
  const work=fixedWork('test');if(existsSync(work)){finishFixedWork(work);if(readdirSync(work).length)fail('Node测试会话未清空');rmdirSync(work);}
 });
}
function checkedNodeTestRuntime(node){
 const plan=nodeVerificationPlan(),path=node?.path;
 if(node?.version!==plan.node_version||typeof path!=='string'||!isAbsolute(path)||realpathSync(path)!==path)fail('Node测试工具与本产品声明不一致');
 const info=lstatSync(path);if(!info.isFile()||info.isSymbolicLink()||!(info.mode&0o111))fail('Node测试工具不是普通可执行文件');
 return plan;
}
function summarizeNodeTests(report){
 report.output_bytes??=0;report.files_executed=report.results.length;report.files_total=report.files.length;
 report.counts_complete=report.files_executed===report.files_total&&report.results.every(value=>Number.isSafeInteger(value.tests));
 report.totals=report.results.reduce((sum,value)=>{for(const key of ['tests','passed','failed','cancelled','skipped','todo'])if(Number.isSafeInteger(value[key]))sum[key]+=value[key];return sum;},{tests:0,passed:0,failed:0,cancelled:0,skipped:0,todo:0});return report;
}
// 每次只运行一个清单文件，失败即停止后续文件；不以部分通过冒充完整验收。
async function runNodeTestFiles(node,work,base,{runProcess=runBuildProcess}={}){
 const plan=checkedNodeTestRuntime(node),files=plan.files.map(file=>join(root,file));
 for(const file of files){const info=lstatSync(file);if(!info.isFile()||info.isSymbolicLink()||realpathSync(file)!==file)fail('本仓测试文件无效');}
 const digests=files.map(file=>createHash('sha256').update(readFileSync(file)).digest('hex'));
 const report={...plan,status:'failed',results:[],cleanup:{state:'completed'}},limit=16*1024*1024,started=performance.now();let bytes=0;
 for(const [index,file]of files.entries()){
  const session=randomUUID(),environment=nodeTestEnvironment(base,work,session);
  if(plan.files[index]!=='test/release_manifest.test.mjs'){delete environment.CITIZENAPP_SDK_SELECTION;delete environment.CITIZENAPP_SDK_RELEASES;}
  let result,record,failure;
  try{
   executions.getStore()?.signal?.throwIfAborted();if(bytes>=limit)fail('Node测试累计输出超限');
   const remaining=7200000-(performance.now()-started);if(remaining<=0)fail('Node测试累计超时');
   result=await runProcess(node.path,['--test','--test-concurrency=1','--test-reporter=tap',file],environment,root,{accepted:[0,1],outputLimit:limit-bytes,timeout:Math.max(1,Math.floor(remaining))});
   bytes+=Buffer.byteLength(result.stdout)+Buffer.byteLength(result.stderr);if(bytes>limit)fail('Node测试累计输出超限');
   record={file:plan.files[index],...parseNodeTestReport(result.stdout,result.code)};report.results.push(record);
   if(files.some((path,i)=>createHash('sha256').update(readFileSync(path)).digest('hex')!==digests[i]))fail('本仓测试期间源码改变');
   if(record.status!=='success')fail('Node回归失败：'+plan.files[index]);
  }catch(error){failure=error;}
  try{clearNodeTestSession(session);}catch(error){
   const message='Node测试现场退出未确认：'+error.message;
   if(failure)failure.message+='；'+message;else failure=Error(message);
   report.cleanup={state:'pending',reason:message};const state=executions.getStore();if(state)state.unconfirmed=true;
  }
  if(failure){
   if(!record){record={file:plan.files[index],status:'failed',exit_code:result?.code??null,signal:null,counts_complete:false};report.results.push(record);}
   record.status='failed';record.reason=failure.message;record.exit_confirmed=Boolean(result);report.stopped_at=plan.files[index];report.output_bytes=bytes;report.duration_ms=Math.round(performance.now()-started);failure.nodeReport=summarizeNodeTests(report);throw failure;
  }
 }
 report.status='success';report.output_bytes=bytes;report.duration_ms=Math.round(performance.now()-started);return summarizeNodeTests(report);
}
// 独立入口只准备已存在的测试输入；没有资源安装、App/SDK构建或远端交付阶段。
export async function verifyNode({environment=process.env,signal}={}){
 const plan=nodeVerificationPlan();if(process.version!=='v'+plan.node_version)fail('请使用本产品声明的Node '+plan.node_version+'运行独立验收');
 const session=randomUUID(),state={signal,unconfirmed:false};let work,claimed=false,report,primary,failure;
 return executions.run(state,()=>withNodeTestSession(session,async()=>{
  try{
   report=await withFixedWork('test',async path=>{
    work=path;claimed=true;
    try{const resources=await resourceRuntime.nodeTestResources(path,{environment:nodeTestEnvironment(environment,path,session),signal});
     report=await runNodeTestFiles(resources.node,path,resources.environment);report.sdk_selection=checkedSdkSelection(state.sdkSelection);return report;
    }catch(error){primary=error;throw error;}
   },{environment});
  }catch(error){
   failure=primary||error;
   if(primary&&primary!==error){failure.message+='；Node父会话收尾失败：'+error.message;state.unconfirmed=true;}
  }
  try{
   // 只有正常收尾且已空的本次根可移除；异常守卫和其它会话保持原样。
   if(claimed&&!state.unconfirmed&&existsSync(work)&&readdirSync(work).length===0)rmdirSync(work);
  }catch(error){
   if(failure)failure.message+='；Node父会话清理失败：'+error.message;else failure=error;
   state.unconfirmed=true;
  }
  if(failure){
   const value=failure.nodeReport||report||summarizeNodeTests({...plan,status:'failed',results:[],stage:'preparation',cleanup:{state:'not-started'}});
   value.status='failed';value.reason=failure.message;if(state.sdkSelection)value.sdk_selection=checkedSdkSelection(state.sdkSelection);
   if(state.unconfirmed||claimed&&existsSync(work))value.cleanup={state:'pending',reason:failure.message};else if(claimed)value.cleanup={state:'completed'};
   failure.nodeReport=value;throw failure;
  }
  return report;
 }));
}
function flutterTestFiles(project){
 const result=[];const visit=directory=>{for(const row of readdirSync(directory,{withFileTypes:true})){
  const path=join(directory,row.name);if(row.isSymbolicLink())fail('Dart测试目录禁止链接');
  if(row.isDirectory())visit(path);else if(row.isFile()&&row.name.endsWith('_test.dart'))result.push(path);
 }};visit(join(project,'test'));if(!result.length)fail('没有Dart回归测试');return result;
}
// 消费Flutter标准JSON事件，零测试、未完成、失败或跳过均不能冒充完整验收。
export function checkFlutterReport(file,expected,project=root){
 if(!lstatSync(file).isFile()||lstatSync(file).size>32*1024**2)fail('Flutter测试报告缺失或超限');
 const tests=new Map(),suites=new Map(),covered=new Set();let done=false,passed=0,skipped=0,failed=0;
 for(const line of readFileSync(file,'utf8').split('\n').filter(Boolean)){
  const event=JSON.parse(line);if(done)fail('Flutter报告在终态之后仍有事件');
  if(event.type==='suite')suites.set(event.suite.id,event.suite.path);
  if(event.type==='testStart')tests.set(event.test.id,event.test);
  if(event.type==='error')failed++;
  if(event.type==='testDone'){
   const test=tests.get(event.testID);if(!test||test.finished)fail('Flutter测试终态不唯一');test.finished=true;
   if(event.skipped)skipped++;else if(event.result!=='success')failed++;
   else if(!event.hidden){passed++;const path=suites.get(test.suiteID);if(path)covered.add(resolve(project,path.startsWith('file:')?fileURLToPath(path):path));}
  }
  if(event.type==='done'){done=event.success===true;if(!done)fail('Flutter全套回归失败');}
 }
 if(!done||!passed||failed||skipped||[...tests.values()].some(value=>!value.finished)
  ||expected.some(path=>!covered.has(resolve(path))))fail('Flutter报告未覆盖全部用例或存在失败/跳过');
 return {passed,failed,skipped,files:expected.length};
}
async function runProductTests(platform,work,receipt,base){
 const env=resourceEnvironment(platform,work,receipt,base),node=receipt.tools.node;
 if(!node||!isAbsolute(node.path)||realpathSync(node.path)!==node.path)fail('本仓测试缺少准确Node入口');
 const project=env.CITIZENAPP_PROJECT_ROOT,flutter=receipt.tools.flutter?.path;
 if(!project||!flutter)fail('完整验收缺少本轮工程或Flutter');
 const testEnvironment={...env,CI:'true',CITIZENAPP_TEST_WORK_DIR:work,
  CITIZENAPP_TEST_PROJECT_ROOT:project,CITIZENAPP_TEST_BUILD_DIR:join(work,'work/tests'),
  CITIZENAPP_TEST_DEPENDENCY_DIR:join(work,'dependencies'),CITIZENAPP_OFFLINE:'true',FLUTTER_BIN:flutter,
  PRODUCT_GIT_BIN:env.GIT,PRODUCT_TEST_SWIFTC:env.SWIFTC,
  PRODUCT_TEST_DEVELOPER_DIR:env.DEVELOPER_DIR,PRODUCT_TEST_SDKROOT:env.SDKROOT};
 for(const key of ['APP_KEY','IOS_KEY','IOS_PROVISIONING_PROFILE','GH_TOKEN','GITHUB_TOKEN','NODE_OPTIONS','NODE_TEST_CONTEXT'])delete testEnvironment[key];
 await runNodeTestFiles(node,work,testEnvironment);
 await runBuildProcess(flutter,['pub','get','--offline','--enforce-lockfile'],testEnvironment,project);
 const report=join(work,'flutter-tests.jsonl'),expected=flutterTestFiles(project);
 await runShell('test',['--file-reporter=json:'+report],testEnvironment,root,receipt.tools.bash.path);
 const counts=checkFlutterReport(report,expected,project);
 if(base.GITHUB_STEP_SUMMARY)writeFileSync(base.GITHUB_STEP_SUMMARY,
  '## 公民App完整验收\n\nDart分析通过；Flutter '+counts.passed+'通过，'+counts.failed+'失败，'+counts.skipped+'跳过；覆盖'+counts.files+'个测试文件。\n',{flag:'a'});
 return counts;
}

if(testSession&&process.argv.length===2&&testFiles().some(file=>join(root,file)===resolve(process.argv[1]||'')))process.on('exit',()=>{
 // 按本仓守卫只清当前测试会话；活跃工具或身份不符时保留现场并失败。
 try{
  for(const platform of Object.keys(contract.platforms)){const work=fixedWork('build/'+platform);if(existsSync(work))finishFixedWork(work);}
  const session=fixedWork('test');if(existsSync(session)){finishFixedWork(session);rmdirSync(session);}
  const sessions=join(root,'target/test/sessions');if(existsSync(sessions)&&readdirSync(sessions).length===0)rmdirSync(sessions);
 }catch(error){process.stderr.write('公民App测试会话收尾失败：'+error.message+'\n');process.exitCode=1;}
});
if(testSession&&process.argv.length===2&&resolve(process.argv[1]||'')===fileURLToPath(import.meta.url))inlineTestRegistrations.push(async()=>{
 const {test}=await import('node:test'),{default:assert}=await import('node:assert/strict');
 const nodeTap=({tests=1,passed=1,failed=0,cancelled=0,skipped=0,todo=0}={})=>'TAP version 13\n'+(failed?'not ok':'ok')+' 1 - synthetic\n1..1\n# tests '+tests+'\n# pass '+passed+'\n# fail '+failed+'\n# cancelled '+cancelled+'\n# skipped '+skipped+'\n# todo '+todo+'\n';
 test('独立Node验收计划只有本仓唯一清单和准确工具版本',()=>{
  const plan=nodeVerificationPlan();assert.equal(plan.product_id,product);assert.equal(plan.mode,'node');
  assert.deepEqual(plan.files,['scripts/build.mjs','scripts/publish.mjs','test/release_manifest.test.mjs']);
  assert.equal(plan.node_version,contract.platforms.ios.tools.find(value=>value.id==='node').version);
  assert.throws(()=>checkedNodeTestRuntime({path:process.execPath,version:'0.0.0'}),/声明不一致/);
  assert.throws(()=>withNodeTestSession('../foreign',()=>assert.fail('不能进入非法会话')),/会话无效/);
 });
 test('Node报告核验计划、全部计数与退出，零用例残缺或跳过不能冒充通过',()=>{
  assert.equal(parseNodeTestReport(nodeTap(),0).status,'success');
  assert.equal(parseNodeTestReport(nodeTap().replaceAll('\n','\r\n'),0).passed,1);
  assert.equal(parseNodeTestReport(nodeTap({passed:0,failed:1}),1).status,'failed');
  assert.equal(parseNodeTestReport(nodeTap({passed:0,skipped:1}),0).status,'failed');
  assert.equal(parseNodeTestReport(nodeTap({passed:0,todo:1}),0).status,'failed');
  for(const text of ['',nodeTap({tests:0,passed:0}),nodeTap().replace('# pass 1\n',''),nodeTap()+'# tests 1\n',nodeTap().replace('1..1','1..2'),nodeTap().replace('ok 1','ok 2')])assert.throws(()=>parseNodeTestReport(text,0),/报告/);
  assert.throws(()=>parseNodeTestReport(nodeTap(),2),/退出码/);
 });
 test('共同Node执行器逐文件使用独立会话并去除凭据，成功报告完整计数',async()=>{
  const plan=nodeVerificationPlan(),sessions=new Set(),calls=[];
  const report=await runNodeTestFiles({path:process.execPath,version:plan.node_version},testRoot(),{HOME:process.env.HOME,APP_KEY:'synthetic',GITHUB_TOKEN:'synthetic',SAMPLE_API_KEY:'synthetic',NODE_OPTIONS:'--invalid',FORCE_COLOR:'1'},{
   runProcess:async(file,args,env,cwd,options)=>{
    assert.equal(file,process.execPath);assert.equal(cwd,root);assert.deepEqual(args.slice(0,3),['--test','--test-concurrency=1','--test-reporter=tap']);calls.push(args.at(-1));sessions.add(env.CITIZENAPP_TEST_SESSION);
    for(const name of ['APP_KEY','GITHUB_TOKEN','SAMPLE_API_KEY','NODE_OPTIONS','NODE_TEST_CONTEXT','FORCE_COLOR'])assert.equal(Object.hasOwn(env,name),false);
    assert.deepEqual(options.accepted,[0,1]);assert.ok(options.outputLimit>0&&options.outputLimit<=16*1024*1024);assert.ok(options.timeout>0&&options.timeout<=7200000);return {stdout:nodeTap(),stderr:'',code:0};
   }
  });
  assert.equal(report.status,'success');assert.equal(report.counts_complete,true);assert.equal(report.totals.passed,plan.files.length);assert.equal(sessions.size,plan.files.length);assert.deepEqual(calls,plan.files.map(file=>join(root,file)));
 });
 test('共同Node执行器失败停止后续文件，异常退出及取消保留未完成事实',async()=>{
  const node={path:process.execPath,version:nodeVerificationPlan().node_version};let calls=0;
  await assert.rejects(runNodeTestFiles(node,testRoot(),{}, {runProcess:async()=>{calls++;return {stdout:nodeTap({passed:0,failed:1}),stderr:'',code:1};}}),error=>{
   assert.equal(error.nodeReport.results[0].exit_code,1);assert.equal(error.nodeReport.totals.failed,1);assert.equal(error.nodeReport.counts_complete,false);assert.equal(error.nodeReport.cleanup.state,'completed');return true;
  });assert.equal(calls,1);
  const original=Error('synthetic process failure');await assert.rejects(runNodeTestFiles(node,testRoot(),{}, {runProcess:async()=>{throw original;}}),error=>{assert.equal(error,original);assert.equal(error.nodeReport.results[0].exit_code,null);assert.equal(error.nodeReport.counts_complete,false);return true;});
  calls=0;await assert.rejects(executions.run({signal:AbortSignal.abort()},()=>runNodeTestFiles(node,testRoot(),{}, {runProcess:async()=>{calls++;}})),/abort/iu);assert.equal(calls,0);
 });
 test('Node会话清理拒绝仍活动的所属进程，不接管其它会话',async()=>{
  const session=randomUUID();let path;
  await withNodeTestSession(session,()=>withFixedWork('test',async work=>{
   path=work;writeFileSync(join(work,'owned'),'synthetic');assert.throws(()=>clearNodeTestSession(session),/进程退出未确认/);assert.equal(readFileSync(join(work,'owned'),'utf8'),'synthetic');
  }));
  clearNodeTestSession(session);assert.equal(existsSync(path),false);
 });
 test('Node测试失败与活动清理同时发生仍保留首错和待清理事实',async()=>{
  let session,release,holder;const hold=new Promise(resolve=>{release=resolve;});
  try{
   await assert.rejects(runNodeTestFiles({path:process.execPath,version:nodeVerificationPlan().node_version},testRoot(),{},{
    runProcess:async(_file,_args,env)=>{
     session=env.CITIZENAPP_TEST_SESSION;let entered;const ready=new Promise(resolve=>{entered=resolve;});
     holder=withNodeTestSession(session,()=>withFixedWork('test',async()=>{entered();await hold;}));await ready;
     return {stdout:nodeTap({passed:0,failed:1}),stderr:'',code:1};
    }
   }),error=>{assert.match(error.message,/Node回归失败/);assert.match(error.message,/退出未确认/);assert.equal(error.nodeReport.cleanup.state,'pending');assert.equal(error.nodeReport.totals.failed,1);return true;});
  }finally{release();if(holder)await holder;if(session)clearNodeTestSession(session);}
  for(const outputLimit of [0,-1,16*1024*1024+1])await assert.rejects(runBuildProcess('/not-executed',[],{},root,{outputLimit}),/输出上限无效/);
 });
 test('verify错误参数在准备工具和执行测试前拒绝',()=>{
  for(const args of [['verify'],['verify','other'],['verify','node','extra']]){
   const result=spawnSync(process.execPath,[fileURLToPath(import.meta.url),...args],{encoding:'utf8',env:{HOME:process.env.HOME,PATH:process.env.PATH}});
   assert.notEqual(result.status,0);assert.match(result.stderr,/只接受verify node/);assert.equal(result.stdout,'');
  }
 });
 test('安装失败仅在签名身份重新验真后保留编译成功，安全失败取消和未知退出不降级',async()=>{
  const failure=installationFailure('设备安装失败');let verified=0;
  assert.deepEqual(await checkedInstallationOutcome(failure,{verifyLocalArtifact:async()=>{verified++;}}),{state:'failed',code:'PRODUCT_INSTALLATION_FAILED',message:'设备安装失败'});assert.equal(verified,1);
  const unsafe=Error('签名漂移');await assert.rejects(checkedInstallationOutcome(failure,{verifyLocalArtifact:async()=>{throw unsafe;}}),error=>error===unsafe);
  await assert.rejects(checkedInstallationOutcome(unsafe,{verifyLocalArtifact:async()=>{verified++;}}),error=>error===unsafe);
  await assert.rejects(checkedInstallationOutcome(failure,{unconfirmed:true,verifyLocalArtifact:async()=>{verified++;}}),error=>error===failure);
  await assert.rejects(checkedInstallationOutcome(failure,{}),error=>error===failure);
  await assert.rejects(checkedInstallationOutcome(failure,{signal:AbortSignal.abort(),verifyLocalArtifact:async()=>{verified++;}}),/abort/iu);assert.equal(verified,1);
 });
 test('产品任务与交付名称严格分离且平台版本独立',()=>{
  assert.equal(buildTaskName('ios','塔塔自动化'),'公民·塔塔自动化·iOS');assert.equal(buildDisplayName('android','1.2.3'),'公民·Android·v1.2.3');
  assert.equal(nextBuildVersion('1.2.9'),'1.2.10');assert.equal(buildPlatforms.ios.initialVersion,'1.0.0');assert.equal(buildPlatforms.android.initialVersion,'1.0.0');
  for(const value of ['v1.0.0','01.0.0','1.0','1.0.0 ','1.0.0\n','1.0.0/other'])assert.throws(()=>checkedBuildVersion(value));
  assert.throws(()=>buildTaskName('other'));assert.throws(()=>buildTaskName('ios','任意流程'));assert.throws(()=>buildDisplayName('other','1.0.0'));
 });
 test('增量只在真实领取者成功收尾后替换，失败保留上一份且平台隔离',async()=>{
  const work=fixedWork('build/ios');
  try{
   await withFixedWork('build/ios',async path=>{
    mkdirSync(join(path,'source-view'));writeFileSync(join(path,'source-view/input.dart'),'first');
    writeFileSync(join(path,'.build-retain.json'),JSON.stringify({schema:1,product_id:product,platform:'ios',work:path,version:'1.0.0'}));
   });
   const cache=join(work,'incremental/data/source-view/input.dart');assert.equal(readFileSync(cache,'utf8'),'first');assert.equal(checkedRetainedEntry(work,'incremental').platform,'ios');
   await assert.rejects(withFixedWork('build/ios',async path=>{assert.equal(restoreIncremental('ios',path),true);assert.equal(readFileSync(join(path,'source-view/input.dart'),'utf8'),'first');writeFileSync(join(path,'source-view/input.dart'),'failed');throw Error('增量夹具失败');}),/增量夹具失败/);
   assert.equal(readFileSync(cache,'utf8'),'first');assert.equal(existsSync(join(work,'source-view')),false);
   assert.notEqual(incrementalIdentity('ios'),incrementalIdentity('android'));
   await withFixedWork('build/ios',async path=>{restoreIncremental('ios',path);writeFileSync(join(path,'.build-retain.json'),JSON.stringify({schema:1,product_id:product,platform:'ios',work:path,version:'1.0.2'}));writeFileSync(join(path,'input.apk'),'signed-fixture');const files=retainCompiledArtifacts('ios',path,'1.0.2',[{path:join(path,'input.apk'),extension:'.app.zip'}]);assert.equal(files[0].name,'公民·iOS·v1.0.2.app.zip');});
   assert.equal(checkedRetainedEntry(work,'artifact').version,'1.0.2');assert.equal(readFileSync(cache,'utf8'),'first');
  }finally{if(existsSync(work))rmSync(work,{recursive:true});}
 });
 test('产物在最终回执之前失败恢复上一集合，增量提交失败也回滚',async()=>{
  const work=fixedWork('build/ios'),mark=path=>writeFileSync(join(path,'.build-retain.json'),JSON.stringify({schema:1,product_id:product,platform:'ios',work:path,version:'1.0.1'}));
  try{
   await withFixedWork('build/ios',async path=>{writeFileSync(join(path,'first'),'first');retainCompiledArtifacts('ios',path,'1.0.1',[{path:join(path,'first'),extension:'.app.zip'}]);mark(path);});
   for(const mode of ['result','cache']){
    await assert.rejects(withFixedWork('build/ios',async path=>{writeFileSync(join(path,'second'),'second');retainCompiledArtifacts('ios',path,'1.0.2',[{path:join(path,'second'),extension:'.app.zip'}]);if(mode==='result')throw Error('最终回执失败');mkdirSync(join(path,'source-view'));writeFileSync(join(path,'source-view/a'),'a');targetFs.linkSync(join(path,'source-view/a'),join(path,'source-view/b'));mark(path);}),/最终回执|特殊文件/);
    assert.equal(checkedRetainedEntry(work,'artifact').version,'1.0.1');assert.equal(readFileSync(join(work,'artifact/公民·iOS·v1.0.1.app.zip'),'utf8'),'first');assert.equal(existsSync(join(work,'artifact.previous')),false);
   }
  }finally{if(existsSync(work))rmSync(work,{recursive:true});}
 });
 test('增量与产物事务按阶段恢复，未知归属拒绝且凭据不进入缓存',async()=>{
  const work=fixedWork('build/ios');
  try{
   for(const phase of ['prepared','committing']){
    await withFixedWork('build/ios',async path=>{
     const generation=randomUUID(),pending=join(path,'incremental.pending');mkdirSync(pending);
     const record={schema:1,product_id:product,platform:'ios',identity:incrementalIdentity('ios'),source:root,work:path,paths:[],generation};writeFileSync(join(pending,'receipt.json'),JSON.stringify(record));
     const hadPrevious=Boolean(checkedRetainedEntry(path,'incremental'));replaceRetainedDirectory(path,'incremental',pending,{retainPrevious:true});
     writeRetentionIntent(path,{schema:1,product_id:product,platform:'ios',work:path,version:'1.0.1',phase,generation,cache_previous:hadPrevious});
    });
    assert.equal(existsSync(join(work,'incremental.previous')),false);assert.equal(existsSync(join(work,'.build-retain.json')),false);
    if(phase==='prepared')assert.equal(existsSync(join(work,'incremental')),false);else assert.equal(checkedRetainedEntry(work,'incremental').platform,'ios');
   }
   await withFixedWork('build/ios',async path=>{
    writeFileSync(join(path,'.build-retain.json'),JSON.stringify({schema:1,product_id:'foreign',platform:'ios',work:path,version:'1.0.1'}));
    assert.throws(()=>commitProductRetention(path),/提交身份不符/);unlinkSync(join(path,'.build-retain.json'));
   });
   const area=fixedScratch(join(testRoot(),'cache-sensitive-'));try{
    const source=join(area,'source'),output=join(area,'output');mkdirSync(source);for(const name of ['.env','.env.local','.npmrc','credentials.json','signing.key','public.dart'])writeFileSync(join(source,name),'synthetic');
    copyIncrementalTree(source,output);assert.deepEqual(readdirSync(output),['public.dart']);
   }finally{rmSync(area,{recursive:true});}
  }finally{if(existsSync(work))rmSync(work,{recursive:true});}
 });
 test('产物换位中断恢复旧集合，已写提交候选必须逐字匹配',async()=>{
  const work=fixedWork('build/ios'),mark=path=>writeFileSync(join(path,'.build-retain.json'),JSON.stringify({schema:1,product_id:product,platform:'ios',work:path,version:'1.0.1'}));
  try{
   await withFixedWork('build/ios',async path=>{writeFileSync(join(path,'first'),'first');retainCompiledArtifacts('ios',path,'1.0.1',[{path:join(path,'first'),extension:'.app.zip'}]);mark(path);});
   await withFixedWork('build/ios',async path=>{
    writeFileSync(join(path,'second'),'second');retainCompiledArtifacts('ios',path,'1.0.2',[{path:join(path,'second'),extension:'.app.zip'}]);renameSync(join(path,'artifact'),join(path,'artifact.pending'));
   });
   assert.equal(checkedRetainedEntry(work,'artifact').version,'1.0.1');assert.equal(existsSync(join(work,'artifact.pending')),false);
   await withFixedWork('build/ios',async path=>{
    writeFileSync(join(path,'second'),'second');retainCompiledArtifacts('ios',path,'1.0.2',[{path:join(path,'second'),extension:'.app.zip'}]);const record=checkedRetainedEntry(path,'artifact'),finalized={...record};delete finalized.pending;delete finalized.previous;writeFileSync(join(path,'artifact/receipt.json.pending'),JSON.stringify(finalized));mark(path);
   });
   assert.equal(checkedRetainedEntry(work,'artifact').version,'1.0.2');assert.equal(existsSync(join(work,'artifact/receipt.json.pending')),false);
  }finally{if(existsSync(work))rmSync(work,{recursive:true});}
 });
 test('工程视图只复用未变更mtime与编译状态，删除源码不恢复',()=>{
  const area=fixedScratch(join(testRoot(),'view-incremental-')),before=join(area,'before'),after=join(area,'after');
  try{
   for(const path of [before,after])mkdirSync(path);writeFileSync(join(before,'same.dart'),'same');writeFileSync(join(after,'same.dart'),'same');targetFs.utimesSync(join(before,'same.dart'),100,100);
   writeFileSync(join(before,'deleted.dart'),'deleted');writeFileSync(join(before,'changed.dart'),'old');writeFileSync(join(after,'changed.dart'),'new');mkdirSync(join(before,'.dart_tool'));writeFileSync(join(before,'.dart_tool/state.bin'),'compiler');
   restoreViewIncremental(before,after);assert.equal(lstatSync(join(after,'same.dart')).mtimeMs,100000);assert.equal(existsSync(join(after,'deleted.dart')),false);assert.equal(readFileSync(join(after,'changed.dart'),'utf8'),'new');assert.equal(readFileSync(join(after,'.dart_tool/state.bin'),'utf8'),'compiler');
  }finally{rmSync(area,{recursive:true});}
 });
 test('本仓测试固定根归随机会话，正式平台根不变',()=>{
  assert.equal(fixedWork('test'),join(root,'target/test/sessions',testSession));
  for(const platform of Object.keys(contract.platforms))assert.equal(fixedWork('build/'+platform),join(fixedWork('test'),'build',platform));
 });
 test('正式入口在领取工作根前拒绝合成阶段',()=>{
  const module=JSON.stringify(fileURLToPath(import.meta.url));
  const child=spawnSync(process.execPath,['--input-type=module','-e','import {execute} from '+module+';await execute("bad","/bad",{}, {stages:{}});'],{env:{PATH:process.env.PATH,HOME:process.env.HOME},encoding:'utf8'});
  assert.notEqual(child.status,0);assert.match(child.stderr,/合成阶段仅用于本仓测试/);
 });
});

export async function execute(platform,work,request={},options={}) {
 if(options.stages&&!process.env.NODE_TEST_CONTEXT)fail('合成阶段仅用于本仓测试');
 checkFixedWork(work,{create:true});
 return withFixedWork(taskScope(work),()=>executeTask(platform,work,request,options),{run_id:request.run_id,environment:options.environment||process.env});
}
async function executeTask(platform,work,request={},options={}) {
 checkWork(work);platformContract(platform);
 if(!inside(productTarget(platform),work)||work===productTarget(platform))fail('执行工作根与当前产品平台不一致');
 options.signal?.throwIfAborted();
 if(!request||typeof request!=='object'||Array.isArray(request)||Object.keys(request).some(k=>!['run_id','program_digest'].includes(k))
  ||request.run_id!==undefined&&!/^[1-9][0-9]{8}$/u.test(request.run_id)||request.program_digest!==undefined&&!/^[a-f0-9]{64}$/u.test(request.program_digest)
  )fail('本仓Build只接受任务编号、程序输入记录及显式供给方式');
 chmodSync(work,0o700);
 const lock=join(work,'.product-build.lock'),resultFile=join(work,'build-result.json');
 if(existsSync(resultFile))fail('本轮完整Build已有结果，禁止复用旧终态');
 const handle=openSync(lock,'wx',0o600);closeSync(handle);
 const cancellation=new AbortController(),abort=()=>cancellation.abort();options.signal?.addEventListener('abort',abort,{once:true});if(options.signal?.aborted)abort();
 const delivery=options.delivery||'local';if(!['local','automation'].includes(delivery))fail('编译交付环境无效');
 const version=checkedBuildVersion(options.version||localBuildVersion(platform,work));
 if(delivery==='automation')checkedAutomationEnvironment(platform,options.ciEnvironment||{});
 const state={signal:cancellation.signal,cancellation,unconfirmed:false,finished:false,delivery,version,ciEnvironment:options.ciEnvironment};
 try{return await executions.run(state,async()=>{
  const stages=options.stages||{requirements,resources:(...args)=>Promise.resolve(resourceRuntime.resources(...args)),prepare,build};
  const resourcesOptions={signal:state.signal,offline:Boolean(options.offline),environment:options.environment||process.env};

  if(!options.stages){state.sdkWork=work;state.sdkSelection=await resourceRuntime.prepareSdkInputs(work,{...resourcesOptions,delivery,ciEnvironment:options.ciEnvironment});restoreIncremental(platform,work);}
  await stages.requirements(platform,work);state.signal.throwIfAborted();
  let receipt=await stages.resources(platform,work,request,resourcesOptions);state.signal.throwIfAborted();
  await stages.prepare(platform,work,receipt,resourcesOptions.environment);state.signal.throwIfAborted();
  if(!options.stages)await runProductTests(platform,work,receipt,resourcesOptions.environment);
  state.signal.throwIfAborted();
  await stages.requirements(platform,work);
  receipt=await stages.resources(platform,work,receipt,resourcesOptions);state.signal.throwIfAborted();
  const result=await stages.build(platform,work,receipt,resourcesOptions.environment);state.signal.throwIfAborted();
  if(delivery==='automation'){if(result.product_id!==product||result.platform!==platform||result.version!==version||result.tag!==buildDisplayName(platform,version))fail('自动化编译回执无效');}
  else checkBuildResult(result,platform,work,request.run_id);
  if(state.sdkSelection)result.sdk_selection=checkedSdkSelection(state.sdkSelection);
  writeFileSync(resultFile,JSON.stringify(result)+'\n',{flag:'wx',mode:0o600});
  if(!options.stages)writeFileSync(join(work,'.build-retain.json'),JSON.stringify({schema:1,product_id:product,platform,work,version,sdk_sources:state.sdkSelection?.sources})+'\n',{flag:'wx',mode:0o600});return result;
 });}catch(error){if(String(error?.message).includes('退出未确认'))state.unconfirmed=true;throw error;}finally{
  state.finished=true;options.signal?.removeEventListener('abort',abort);
  // 本层仅释放自己创建的编译守卫；嵌套执行器仍属于外层登记的活跃进程组。
  // 平台现场由withFixedWork的真实领取者在子执行器退出后统一收尾，避免提前清场覆盖阶段原错。
  if(!state.unconfirmed)unlinkSync(lock);
 }
}
export function checkBuildResult(value,platform,work,runId) {
 const app=platformContract(platform);
 if(!['ios','android'].includes(platform)||app.completion!=='device-install'||app.files.length!==1)
  fail('公民App本机Build必须完成自身移动端安装');
 const extension=platform==='ios'?'.app.zip':'.apk';
 if(!app.files[0].endsWith(extension))fail('公民App平台与移动产物类型不一致');
 if(value?.schema!==1||value.product_id!==product||value.platform!==platform||value.work!==work
  ||value.run_id!==runId||!(value.completion==='device-install'||value.version!==undefined&&value.completion==='compile-only'&&value.installation?.state==='failed'&&value.installation.code==='PRODUCT_INSTALLATION_FAILED')||!Array.isArray(value.files)||value.files.length!==1)fail('公民App安装终态无效');
 const artifact=value.files[0],path=join(work,app.files[0]);
 if(artifact.path!==path||realpathSync(path)!==path||!inside(work,path)||!lstatSync(path).isFile()
  ||Object.keys(artifact).sort().join(',')!=='path,sha256'||!/^[a-f0-9]{64}$/u.test(artifact.sha256)||outputDigest(path)!==artifact.sha256)fail('公民App签名安装产物在交付前变化');
 const allowed=new Set(['schema','product_id','platform','work','completion','files']);if(runId)allowed.add('run_id');
 if(value.version!==undefined){
  checkedBuildVersion(value.version);allowed.add('version');allowed.add('artifacts');allowed.add('installation');
  if(!value.installation||!['success','failed'].includes(value.installation.state)||value.installation.state==='success'&&Object.keys(value.installation).join(',')!=='state'||value.installation.state==='failed'&&(Object.keys(value.installation).sort().join(',')!=='code,message,state'||value.installation.code!=='PRODUCT_INSTALLATION_FAILED'||typeof value.installation.message!=='string'||value.installation.message.length>256))fail('公民App安装分阶段回执无效');
  if(value.installation.state==='failed'&&(value.completion!=='compile-only'||/[\x00-\x1f\x7f]/u.test(value.installation.message))||value.installation.state==='success'&&value.completion!=='device-install')fail('公民App安装状态与终态不一致');
  if(!Array.isArray(value.artifacts)||value.artifacts.length!==1)fail('公民App公开产物登记无效');
  const retained=value.artifacts[0],name=buildDisplayName(platform,value.version)+extension;
  if(retained.name!==name||retained.path!==join(work,'artifact',name)||realpathSync(retained.path)!==retained.path||retained.sha256!==outputDigest(retained.path))fail('公民App公开产物身份漂移');
 }
 if(Object.keys(value).length!==allowed.size||Object.keys(value).some(field=>!allowed.has(field)))fail('公民App结果含未公开字段');
 return value;
}
async function completeBuild(platform,work,receipt,env) {
 const declared=platformContract(platform);
 let installation={state:'success'};
 if(declared.completion==='device-install')try{await completeMobile(platform,work,receipt,env);}catch(error){
  installation=await checkedInstallationOutcome(error,executions.getStore());process.stderr.write('编译及签名验真成功；设备安装失败：'+error.message+'\n');
 }
 if(declared.completion==='macos-artifact')for(const name of declared.files)await run(env.CODESIGN,['--verify','--deep','--strict',join(work,name)],env);
 const result={schema:1,product_id:product,platform,work,completion:declared.completion,
  files:declared.files.map(name=>{const path=join(work,name);if(!inside(work,path)||realpathSync(path)!==path)fail('Build候选越界');return {path,sha256:outputDigest(path)};})};
 if(receipt.run_id)result.run_id=receipt.run_id;
 const state=executions.getStore();if(state?.version){result.version=state.version;result.installation=installation;if(installation.state==='failed')result.completion='compile-only';result.artifacts=retainCompiledArtifacts(platform,work,state.version,result.files.map(file=>({path:file.path,extension:platform==='ios'?'.app.zip':'.apk'})));}
 return checkBuildResult(result,platform,work,receipt.run_id);
}

// 全双工宿主通道只传开发签名材料，不与stdout结果、stderr日志或资源回执混用。

// 模块先完成初始化，资源模块才能反向导入本文件的唯一校验；异步CLI在独立Promise中执行。

// 广场原生实现归平台一级square目录；Xcode/Gradle消费路径只在target恢复，Logo仍只读assets/logo。
export const PLATFORM_INPUTS=Object.freeze([["android/app/InstrumentedTests.kt","android/app/src/androidTest/InstrumentedTests.kt"],["android/app/AndroidManifest.xml","android/app/src/main/AndroidManifest.xml"],["android/app/MainActivity.kt","android/app/src/main/MainActivity.kt"],["android/square/SquareMediaChannel.kt","android/app/src/main/SquareMediaChannel.kt"],["android/square/SquareMp4FastStart.kt","android/app/src/main/SquareMp4FastStart.kt"],["android/square/SquareVideoTranscoder.kt","android/app/src/main/SquareVideoTranscoder.kt"],["assets/logo/icon72.png","android/app/src/main/res/mipmap-hdpi/ic_launcher.png"],["assets/logo/foreground162.png","android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png"],["assets/logo/icon72.png","android/app/src/main/res/mipmap-hdpi/ic_launcher_round.png"],["assets/logo/launch180.png","android/app/src/main/res/mipmap-hdpi/launch_image.png"],["assets/logo/icon48.png","android/app/src/main/res/mipmap-mdpi/ic_launcher.png"],["assets/logo/foreground108.png","android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png"],["assets/logo/icon48.png","android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png"],["assets/logo/launch120.png","android/app/src/main/res/mipmap-mdpi/launch_image.png"],["assets/logo/icon96.png","android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"],["assets/logo/foreground216.png","android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png"],["assets/logo/icon96.png","android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.png"],["assets/logo/launch240.png","android/app/src/main/res/mipmap-xhdpi/launch_image.png"],["assets/logo/icon144.png","android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"],["assets/logo/foreground324.png","android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png"],["assets/logo/icon144.png","android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png"],["assets/logo/launch360.png","android/app/src/main/res/mipmap-xxhdpi/launch_image.png"],["assets/logo/icon192.png","android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"],["assets/logo/foreground432.png","android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png"],["assets/logo/icon192.png","android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png"],["assets/logo/launch480.png","android/app/src/main/res/mipmap-xxxhdpi/launch_image.png"],["ios/project/Runner.pbxproj","ios/Runner.xcodeproj/project.pbxproj"],["ios/project/Runner.xcscheme","ios/Runner.xcscheme"],["ios/source/AppDelegate.swift","ios/Runner/AppDelegate.swift"],["assets/logo/icon1024.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"],["assets/logo/icon20.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png"],["assets/logo/icon40.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png"],["assets/logo/icon60.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png"],["assets/logo/icon29.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png"],["assets/logo/icon58.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png"],["assets/logo/icon87.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png"],["assets/logo/icon40.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png"],["assets/logo/icon80.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png"],["assets/logo/icon120.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png"],["assets/logo/icon120.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png"],["assets/logo/icon180.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png"],["assets/logo/icon76.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png"],["assets/logo/icon152.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png"],["assets/logo/icon167.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png"],["assets/logo/launch160.png","ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/CitizenLaunchLogo.png"],["assets/logo/launch320.png","ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/CitizenLaunchLogo@2x.png"],["assets/logo/launch480.png","ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/CitizenLaunchLogo@3x.png"],["ios/source/Info.plist","ios/Runner/Info.plist"],["ios/source/InfoPlist.xcstrings","ios/Runner/InfoPlist.xcstrings"],["ios/square/SquareMediaChannel.swift","ios/Runner/SquareMediaChannel.swift"],["ios/square/SquareVideoTranscoder.swift","ios/Runner/SquareVideoTranscoder.swift"],["ios/source/SystemProtectedDataChannel.swift","ios/Runner/SystemProtectedDataChannel.swift"],["ios/tests/RunnerTests.swift","ios/RunnerTests.swift"],["ios/tests/RunnerUITests.swift","ios/RunnerUITests.swift"]]);
export function materializePlatformInputs(source,destination) {
 for(const [inputName,outputName] of PLATFORM_INPUTS) {
  const input=join(source,inputName);if(!existsSync(input))continue;
  const output=join(destination,outputName);mkdirSync(dirname(output),{recursive:true,mode:0o700});
  copyHostInput(input,output,source);
 }
 // 平台工具所需的短输入由本仓唯一清单还原为本轮普通文件；夹具源根不投影产品配置。
 if(source===root)for(const [outputName,contents] of Object.entries({...platformInputs(root).ios,...platformInputs(root).android})) {
  if(!/^(?:ios|android)\/[A-Za-z0-9_./-]+$/u.test(outputName)||outputName.split('/').some(part=>!part||part==='.'||part==='..')||typeof contents!=='string')fail('平台输入清单无效');
  const output=join(destination,outputName);if(existsSync(output))fail('平台输入重复：'+outputName);
  mkdirSync(dirname(output),{recursive:true,mode:0o700});writeFileSync(output,contents,{flag:'wx'});
 }
 writeFileSync(join(destination,'analysis_options.yaml'),ANALYSIS_OPTIONS_SOURCE);
 writeFileSync(join(destination,'dart_test.yaml'),DART_TEST_SOURCE);
}
export const ANALYSIS_OPTIONS_SOURCE = "include: package:flutter_lints/flutter.yaml\n\nanalyzer:\n  exclude:\n    - \"**/*.g.dart\"\n    # 工程视图内的锁定SDK与生成缓存归target，不扫描其独立测试。\n    - \"target/**\"\n\nlinter:\n  rules:\n    prefer_const_constructors: true\n    use_build_context_synchronously: true\n";
export const DART_TEST_SOURCE = "# CitizenApp 测试配置。\n# Isar(isar_community / MDBX)是进程级 native;跨文件隔离由 test/support/isar_test_env.dart\n# 的唯一临时目录保证,此处再钉死串行执行 + 合理超时作保险(默认并发会让多 isolate 抢\n# 同一 native 层、更慢且易 flaky)。\nconcurrency: 1\ntimeout: 90s\n";
export const LOGO_ASSETS_SOURCE = "{\n  \"schema\": 1,\n  \"product\": \"citizenapp\",\n  \"source\": {\n    \"repository\": \"crcfrcn/citizenchain\",\n    \"path\": \"icons/logo.png\",\n    \"sha256\": \"81e11c03b8b2c2702d745870424660239308c1b2d1caf91cfb1b688367fe8a53\"\n  },\n  \"files\": {\n    \"assets/logo/foreground108.png\": \"ed7d9b1eabd510ebcae47221ff78381a2ba2d41e5a4990e56d25ebabdad3c65a\",\n    \"assets/logo/foreground162.png\": \"7ff1c4ae15d00f6a65a8ce6471054d6e37c5664cc9104f844aa9904882591e63\",\n    \"assets/logo/foreground216.png\": \"f8c5bbeb68c77abaa74ffb1f402221f5115bcf4d24ebf7e854490ff34e081e5e\",\n    \"assets/logo/foreground324.png\": \"57afe78264c3179f166cbae09c47c70f1535e07ac3ba25db319efbd3c8ed8656\",\n    \"assets/logo/foreground432.png\": \"6f2b955dfdd30cf4c0613d4c78255be0de43d06281fd0ec57ee6feb10bd1b06d\",\n    \"assets/logo/icon1024.png\": \"b79d8b2c3ff321af5bbfed756f843234fb98d4d7c0cf9109b2fbea183b29413d\",\n    \"assets/logo/icon120.png\": \"9bde3a24f31c602e5ad759d12ca861525163258d3ef368dc9c0aac71a9bd4bed\",\n    \"assets/logo/icon152.png\": \"31c6e6724a648c4aebdfee9d50a90fb8fbc2e0f5833912967a889893504b8818\",\n    \"assets/logo/icon167.png\": \"07fa68c82a6a71f0dfaa70f7a6b49bcd13cf9c595594ab49f35bda799f0db153\",\n    \"assets/logo/icon180.png\": \"ef6f852849fe7d6ccefa6928548df05e1b20afefa73fa2182e3816bff6a89154\",\n    \"assets/logo/icon20.png\": \"186ee5943cba56e68615de3de410d8813b81fa175deb9abcc0d9b8b8cd2a97e0\",\n    \"assets/logo/icon29.png\": \"1200ad5ae52d5b1991116bb323f64dfa3efc4a2d4ffd91a493d57d92386f54a9\",\n    \"assets/logo/icon40.png\": \"b3af1ab701c34e7d35bfc348ef7b4720eee4182b1f2a795bd70cc5d336357541\",\n    \"assets/logo/icon58.png\": \"116e7257b5e5cdb81a86704db37b584a8ebee07ab84d424b495d5bb9c36c1a86\",\n    \"assets/logo/icon60.png\": \"fb3628fe0d573ea189dec5fb2354524c0a4f31e0876fee64c0085f6351264f0e\",\n    \"assets/logo/icon76.png\": \"4b03895eb0e1db9b6cf7ebd467a34383315e68aa8b5b63ed3a5e51f7fe70a138\",\n    \"assets/logo/icon80.png\": \"b2ccd91bc44810cdf5ddc2094e597a49a7eab2a8563593aa8b2e00e85c643d17\",\n    \"assets/logo/icon87.png\": \"7b226f834d9aedf30c1f07b742a9aa4793c89afaa9f3f953480b764380ad85af\",\n    \"assets/logo/launch120.png\": \"1ce729c3a23ac185f6a54397bef5d5c8a317f67b38f66bea1f3393b6dec9da2a\",\n    \"assets/logo/icon144.png\": \"f203f0700e86403515c280f2a0c6c933ab1bdb95c63a12f5187de1629ad87b7f\",\n    \"assets/logo/launch160.png\": \"b7ce607af0ecd513fababdda9831aa3056cb99e3fd45234bea7ef4d0de9c88aa\",\n    \"assets/logo/launch180.png\": \"81789009c4dc03a283f610183cf0b462dc7e473dbdbbd6edb4da12a62a4f5177\",\n    \"assets/logo/icon192.png\": \"092869629be4dd591352237a789f08a21e09c5c28faf66b503e16e9cc7e0f5d6\",\n    \"assets/logo/launch240.png\": \"fff07730b40f242d922c023d21f7db62555acac86365c9fc96276daf0b65c488\",\n    \"assets/logo/launch320.png\": \"9188e7f70e8a492d2bd3af021f1f2be7688e64d3bebc317d88f2ad1a169c2432\",\n    \"assets/logo/launch360.png\": \"06c6b7d208914e36eb4f6fedb62828027534eac81c338a0bf6060872fa61f9d0\",\n    \"assets/logo/icon48.png\": \"4c03ec508fdcb94a1a037aa66477d749ff96d2c35e46a3adbe3b27ba64c27632\",\n    \"assets/logo/launch480.png\": \"34a50a60d559d09fdd1037fad391ad62b242c842f6845f2cb76c57486ef150be\",\n    \"assets/logo/icon72.png\": \"c8cfdefdbc3b28e2e7d123bc36cd509fb93fc60c9436632afc69265554e81b62\",\n    \"assets/logo/icon96.png\": \"278eb6a62a06c0ef22a50b6c358533f88d5b9fd1e6c93e711e298155908d9bee\",\n    \"assets/logo/mark256.png\": \"f097de9e416019941ec61635ed5bcf7119000a0ad1e9f7c24359110088446d64\"\n  }\n}\n";
export const TEST_INPUTS_SOURCE = "{\n  \"schema\": 1,\n  \"citizenchain\": {\n    \"url\": \"https://github.com/crcfrcn/citizenchain.git\",\n    \"ref\": \"main\",\n    \"paths\": [\n      \"runtime/primitives/tests/fixtures/scale_codec_vectors.json\",\n      \"runtime/primitives/tests/fixtures/role_permission.json\"\n    ]\n  }\n}\n";
async function sourceViewImplementation() {
// CitizenApp本机Build的target内消费工程；宿主输入复制独占文件，源码只供读取。
// 平台固定布局仅在工程视图装配；Wrapper 按原字节复制，源码目录不承载生成物。
const { execFileSync } = await import("node:child_process");
const {
  constants, chmodSync, copyFileSync, existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, realpathSync, rmSync,
  symlinkSync, writeFileSync,
} = await import("node:fs");
const { dirname, isAbsolute, join, parse, relative, resolve, sep } = await import("node:path");
const { fileURLToPath, pathToFileURL } = await import("node:url");

// 所有视图消费本任务准确SDK锁；本机仓库只在选择阶段读取HEAD，视图仅消费隔离检出。
// 两种模式都只在本轮工作根改写Flutter消费视图，宿主原始声明与锁保持原字节。
const firstPartyRepositories = Object.freeze({
  citizen_sdk: 'https://github.com/crcfrcn/citizensdk.git',
  tatachat_sdk: 'https://github.com/tuyutata/tatachatsdk.git',
});
function dependencyBlock(text, name) {
  const matches = [...text.matchAll(new RegExp('^  ' + name + ':\\n(?:[ \\t]{4,}[^\\n]*\\n)+', 'gm'))];
  if (matches.length !== 1) fail('第一方依赖块不唯一：' + name);
  return matches[0][0];
}
function dependencyField(block, key) {
  const matches = [...block.matchAll(new RegExp('^[ \\t]+' + key + ':\\s*(.*?)\\s*$', 'gm'))];
  if (matches.length !== 1) fail('第一方依赖字段不唯一：' + key);
  const value = matches[0][1];
  return value.startsWith('"') && value.endsWith('"') ? JSON.parse(value)
    : value.startsWith("'") && value.endsWith("'") ? value.slice(1, -1) : value;
}
// Git只由调用方受控PATH交付；缺失直接失败，不回退系统目录。
function sourceGit(root, args) {
  return execFileSync('git', ['-c', 'credential.helper=', '-c', 'core.hooksPath=/dev/null',
    '-c', 'protocol.file.allow=never', '-c', 'gc.auto=0', '-C', root, ...args], {
    encoding: 'utf8', timeout: 180000, maxBuffer: 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
    env: { HOME: process.env.HOME, PATH: process.env.PATH, LANG: 'C',
      GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null', GIT_TERMINAL_PROMPT: '0' },
  }).trim();
}
function verifyGitDirectory(root) {
  if (!isAbsolute(root) || resolve(root) !== root || root === parse(root).root) fail('Git来源根无效');
  let at = parse(root).root;
  for (const part of relative(at, root).split(sep)) {
    at = join(at, part);
    const info = lstatSync(at, { throwIfNoEntry: false });
    if (!info?.isDirectory() || info.isSymbolicLink()) fail('Git来源根缺失或经过链接');
  }
}
function resolveFirstPartyDependencies(source, work) {
  verifyGitDirectory(source); verifyGitDirectory(work);
  if (existsSync(join(source, 'pubspec_overrides.yaml'))) fail('第一方依赖禁止override');
  const manifest = readFileSync(join(source, 'pubspec.yaml'), 'utf8');
  const lock = readFileSync(join(source, 'pubspec.lock'), 'utf8');
  const result = {};
  for (const [name, url] of Object.entries(firstPartyRepositories)) {
    if (!new RegExp('^  ' + name + ':$', 'm').test(manifest)) continue;
    const declared = dependencyBlock(manifest, name), locked = dependencyBlock(lock, name);
    const declaredSha = dependencyField(declared, 'ref');
    if (!/^    git:\s*$/m.test(declared) || !/^[0-9a-f]{40}$/.test(declaredSha)
      || dependencyField(declared, 'url') !== url || dependencyField(declared, 'path') !== '.'
      || dependencyField(locked, 'source') !== 'git' || dependencyField(locked, 'url') !== url
      || dependencyField(locked, 'path') !== '.' || dependencyField(locked, 'ref') !== declaredSha
      || dependencyField(locked, 'resolved-ref') !== declaredSha
      || dependencyField(locked, 'version') !== '1.0.0') fail('第一方声明、锁和唯一Git来源不一致：' + name);
    const parent = join(work, 'git-sources'); mkdirSync(parent, { recursive: true, mode: 0o700 });
    verifyGitDirectory(parent);
    const root = join(parent, name);
    if (!existsSync(root)) fail('第一方来源尚未由本产品资源入口按锁准备：' + name);
    verifyGitDirectory(root); verifyGitDirectory(join(root, '.git'));
    const selected=source===resolve(dirname(fileURLToPath(import.meta.url)),'..')?sdkSelectionForWork(work):null;
    const sha=selected?.sources.find(item=>item.name===name)?.ref||declaredSha;
    if (resolve(sourceGit(root, ['rev-parse', '--show-toplevel'])) !== root
      || resolve(sourceGit(root, ['rev-parse', '--absolute-git-dir'])) !== join(root, '.git')
      || resolve(root, sourceGit(root, ['rev-parse', '--git-common-dir'])) !== join(root, '.git')
      || sourceGit(root, ['rev-parse', '--abbrev-ref', 'HEAD']) !== 'HEAD'
      || sourceGit(root, ['rev-parse', 'HEAD']) !== sha || sourceGit(root, ['remote', 'get-url', 'origin']) !== url
      || sourceGit(root, ['status', '--porcelain=v1', '--untracked-files=all']) !== ''
      || !new RegExp('^name:\\s*' + name + '\\s*$', 'm').test(readFileSync(join(root, 'pubspec.yaml'), 'utf8'))) {
      fail('第一方Git检出身份或源码已变：' + name);
    }
    const versions=[...readFileSync(join(root,'pubspec.yaml'),'utf8').matchAll(/^version:\s*([^\s]+)\s*$/gmu)];
    if(versions.length!==1||!/^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$/u.test(versions[0][1]))fail('SDK包版本不唯一或无效');
    result[name] = { root, url, sha, version:versions[0][1] };
  }
  if (!result.citizen_sdk) fail('宿主缺少唯一CitizenSDK直接依赖');
  return result;
}
function projectedPubMetadata(source, dependencies, views) {
  let manifest = readFileSync(join(source, 'pubspec.yaml'), 'utf8');
  let lock = readFileSync(join(source, 'pubspec.lock'), 'utf8');
  for (const [name] of Object.entries(dependencies)) {
    const target = views[name];
    if (typeof target !== 'string' || !isAbsolute(target) || target !== resolve(target)) fail('SDK视图路径无效');
    manifest = manifest.replace(dependencyBlock(manifest, name), '  ' + name + ':\n    path: ' + JSON.stringify(target) + '\n');
    lock = lock.replace(dependencyBlock(lock, name), '  ' + name + ':\n    dependency: "direct main"\n    description:\n      path: '
      + JSON.stringify(target) + '\n      relative: false\n    source: path\n    version: ' + JSON.stringify(dependencies[name].version||'1.0.0') + '\n');
  }
  return { 'pubspec.yaml': manifest, 'pubspec.lock': lock };
}

function fail(message) {
  throw new Error(`CitizenApp工程视图失败：${message}`);
}

function argumentsFor(command, values) {
  const allowed = (['create', 'create-android', 'verify', 'dependencies'].includes(command))
    ? new Set(['source-root', 'work-root'])
    : command === 'project-framework'
      ? new Set(['source-root', 'project-root', 'work-root', 'package-root', 'package-subpath', 'framework'])
      : fail(`未知命令：${command || '<empty>'}`);
  const result = {};
  for (let index = 0; index < values.length; index += 2) {
    const key = values[index]?.replace(/^--/u, '');
    const value = values[index + 1];
    if (!key || !allowed.has(key) || result[key] !== undefined || value === undefined || value === '') {
      fail('参数不完整、重复或越界');
    }
    result[key] = value;
  }
  if (Object.keys(result).length !== allowed.size) fail('参数闭集不完整');
  return result;
}

function absolutePath(value, label) {
  if (typeof value !== 'string' || !isAbsolute(value) || value !== resolve(value)
    || value === parse(value).root || value.endsWith(sep) || value.includes(`${sep}.${sep}`)
    || value.includes(`${sep}..${sep}`)) fail(`${label}必须是规范绝对路径`);
  return value;
}

function inside(root, candidate) {
  const part = relative(root, candidate);
  return part === '' || (part !== '..' && !part.startsWith(`..${sep}`) && !isAbsolute(part));
}

function ordinaryDirectory(directory, label) {
  const info = lstatSync(directory, { throwIfNoEntry: false });
  if (!info?.isDirectory() || info.isSymbolicLink() || realpathSync(directory) !== directory) {
    fail(`${label}必须是无链接普通目录`);
  }
}

function existingAncestors(path, label) {
  const root = parse(path).root;
  let current = root;
  for (const part of path.slice(root.length).split(sep).filter(Boolean)) {
    current = join(current, part);
    const info = lstatSync(current, { throwIfNoEntry: false });
    if (!info) break;
    if (!info.isDirectory() || info.isSymbolicLink() || realpathSync(current) !== current) {
      fail(`${label}包含链接或非目录祖先：${current}`);
    }
  }
}

// 全部宿主输入均为独立普通文件；工具改写锁、项目或测试只能发生在本任务。
function copyHostInput(input,output,sourceRoot){
 const real=realpathSync(input),info=lstatSync(input);
 if(!inside(sourceRoot,input)||!inside(sourceRoot,real)||!info.isFile()||info.isSymbolicLink()||info.nlink!==1)fail('宿主输入不是源码内独占普通文件');
 const bytes=readFileSync(input);copyFileSync(input,output,constants.COPYFILE_EXCL);
 const copied=lstatSync(output);if(!copied.isFile()||copied.isSymbolicLink()||copied.nlink!==1||realpathSync(output)!==output||!readFileSync(output).equals(bytes)||!readFileSync(input).equals(bytes))fail('宿主输入复制期间漂移');
}

const generatedDirectories = new Set([
  '.dart_tool', '.git', '.gradle', '.pub-cache', '.symlinks', 'Pods', 'build', 'ephemeral',
  'node_modules', 'target',
]);
const generatedFiles = new Set([
  '.flutter-plugins', '.flutter-plugins-dependencies', '.packages',
  'Generated.xcconfig', 'flutter_export_environment.sh', 'local.properties',
  'generated_config.cmake', 'generated_plugin_registrant.cc',
  'generated_plugin_registrant.h', 'generated_plugin_registrant.dart',
  'GeneratedPluginRegistrant.h', 'GeneratedPluginRegistrant.m',
  'GeneratedPluginRegistrant.swift', 'GeneratedPluginRegistrant.java', 'generated_plugins.cmake',
]);
const excludedFiles = new Set(['settings.gradle', 'settings.gradle.kts']);

// Wrapper 属于已选 Flutter 工具；只有直接调用 Wrapper 的 Android 工程才需要复制。
// 本机使用显式 Gradle，iOS 与 Dart 测试均不向工程引入 Android 工具副本。
function wrapperInputs() {
  const flutterRoot = absolutePath(process.env.FLUTTER_ROOT, 'Flutter工具根');
  ordinaryDirectory(flutterRoot, 'Flutter工具根');
  const root = join(flutterRoot, 'bin/cache/artifacts/gradle_wrapper');
  return ['gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar'].map(name => {
    const input = join(root, name);
    existingAncestors(dirname(input), 'Wrapper工具来源');
    const info = lstatSync(input, { throwIfNoEntry: false });
    if (!info?.isFile() || info.isSymbolicLink() || !info.size) fail('Flutter Wrapper原件缺失：' + name);
    return { input, name };
  });
}

// 第一方依赖按锁定提交的公开视图接口装配；旧提交仍使用其公开 createView。
async function firstPartyViewApi(packageRoot) {
  const manifest = readFileSync(join(packageRoot, 'pubspec.yaml'), 'utf8');
  if (!/^name: (?:citizen_sdk|tatachat_sdk)\r?$/mu.test(manifest)) return null;
  const entry = join(packageRoot, 'scripts/build.mjs');
  const info = lstatSync(entry, { throwIfNoEntry: false });
  if (!info?.isFile() || info.isSymbolicLink()) fail('第一方SDK编译入口必须是普通文件');
  const revision=createHash('sha256').update(readFileSync(entry)).digest('hex');
  const api=await import(pathToFileURL(entry).href+'?revision='+revision);
  if (!(typeof api.createFlutterSourceView === 'function' && typeof api.assertFlutterSourceView === 'function')
      && typeof api.createView !== 'function') fail('第一方SDK缺少工程视图入口');
  return api;
}

async function createFirstPartyView(source, output) {
  const api = await firstPartyViewApi(source);
  if (!api) fail('第一方SDK身份无效');
  return typeof api.createFlutterSourceView === 'function' && typeof api.assertFlutterSourceView === 'function'
    ? api.createFlutterSourceView(source, output) : api.createView(source, output);
}

async function assertFirstPartyView(source, view) {
  const api = await firstPartyViewApi(source);
  if (!api) fail('第一方SDK身份无效');
  if (typeof api.createFlutterSourceView === 'function' && typeof api.assertFlutterSourceView === 'function')
    return api.assertFlutterSourceView(source, view);
  ordinaryDirectory(source, 'SDK源码根');
  ordinaryDirectory(view, 'SDK视图根');
  const generated = new Set(['.git', '.dart_tool', '.gradle', '.symlinks', 'Pods', 'build',
    'target', 'node_modules', 'ephemeral', '.cache', '.DS_Store', 'swiftpm', 'dist', 'tsconfig.tsbuildinfo']);
  function visit(inputRoot, outputRoot) {
    for (const name of readdirSync(inputRoot).sort()) {
      if (generated.has(name)) continue;
      const input = join(inputRoot, name), output = join(outputRoot, name);
      const original = lstatSync(input), copied = lstatSync(output, { throwIfNoEntry: false });
      if (original.isDirectory()) {
        if (!copied?.isDirectory() || copied.isSymbolicLink()) fail('SDK视图目录漂移：' + name);
        visit(input, output);
      } else if (original.isFile()) {
        if (!copied?.isFile() || copied.isSymbolicLink() || copied.nlink !== 1
            || !readFileSync(input).equals(readFileSync(output))) fail('SDK视图文件漂移：' + name);
      } else if (original.isSymbolicLink()) {
        const target = realpathSync(input);
        if (!inside(source, target) || !copied?.isSymbolicLink()
            || realpathSync(output) !== join(view, relative(source, target))) fail('SDK视图链接漂移：' + name);
      } else fail('SDK源码包含不支持的条目：' + name);
    }
  }
  visit(source, view);
  if (typeof api.analysisOptionsBytes === 'function') {
    const options = join(view, 'analysis_options.yaml');
    if (!readFileSync(options).equals(api.analysisOptionsBytes(source))) fail('SDK分析配置漂移');
  }
  return view;
}

async function createView(sourceInput, workInput, android = false) {
  const wrappers = android ? wrapperInputs() : [];
  const sourceRoot = absolutePath(sourceInput, '产品源码根');
  const workRoot = absolutePath(workInput, '产品工作根');
  ordinaryDirectory(sourceRoot, '产品源码根');
  existingAncestors(workRoot, '产品工作根');
  if (!inside(join(sourceRoot, 'target'), workRoot) || workRoot === join(sourceRoot, 'target')) fail('产品工作根必须在本仓target内');
  mkdirSync(workRoot, { recursive: true, mode: 0o700 });
  ordinaryDirectory(workRoot, '产品工作根');
  const viewRoot = join(workRoot, 'source-view');
  const prior = lstatSync(viewRoot, { throwIfNoEntry: false });
  if (prior) {
    if (!prior.isDirectory() || prior.isSymbolicLink() || !inside(workRoot, viewRoot)) {
      fail('旧工程视图归属无效');
    }
    if(existsSync(viewRoot+'.previous'))fail('旧工程视图事务尚未完成');
    renameSync(viewRoot,viewRoot+'.previous');
  }
  try{
  mkdirSync(viewRoot, { recursive: true, mode: 0o700 });
  const visited = new Set();
  const mappedPath = source => join(viewRoot, source.replace(/^\/+/, ''));

  async function materialize(packageRoot, allowPackageLink = false) {
    packageRoot = resolve(packageRoot);
    if (visited.has(packageRoot)) return;
    const packageInfo = lstatSync(packageRoot, { throwIfNoEntry: false });
    let sourceDirectory = packageRoot;
    if (packageInfo?.isSymbolicLink()) {
      if (!allowPackageLink) fail('产品源码根不得是链接');
      existingAncestors(parse(packageRoot).dir, '本地path依赖父目录');
      sourceDirectory = realpathSync(packageRoot);
    }
    ordinaryDirectory(sourceDirectory, '本地path依赖真实根');
    // 产品根已经核验target工作边界；只有path依赖需要与该工作根保持分离。
    if (packageRoot !== sourceRoot && ((!inside(join(workRoot, 'git-sources'), packageRoot) && inside(packageRoot, workRoot))
      || inside(sourceDirectory, viewRoot) || inside(viewRoot, sourceDirectory))) {
      fail('工程视图与path依赖必须分离');
    }
    visited.add(packageRoot);
    const destinationRoot = mappedPath(packageRoot);
    if (await firstPartyViewApi(sourceDirectory)) {
      await createFirstPartyView(sourceDirectory, destinationRoot);
      return;
    }
    mkdirSync(destinationRoot, { recursive: true, mode: 0o700 });

    function visit(source, destination) {
      for (const name of readdirSync(source).sort()) {
        const input = join(source, name);
        const output = join(destination, name);
        const info = lstatSync(input);
        // 远端Flutter直接启动Gradle：settings保留原字节的普通文件，防止Gradle把
        // 跨根链接解析成源码工程。其余宿主输入同样复制独立普通文件，SDK装配继续归SDK公开入口。
        if (android && sourceDirectory === sourceRoot && input === join(sourceRoot, 'android/settings.gradle.kts')) {
          if (!info.isFile() || info.isSymbolicLink()) fail('Android settings来源必须是普通文件');
          copyFileSync(input, output);
          continue;
        }
        if (sourceDirectory === sourceRoot && ['android/gradlew', 'android/gradlew.bat',
          'android/gradle'].includes(relative(sourceRoot, input).split(sep).join('/'))) {
          fail('产品源码残留Wrapper副本：' + input);
        }
        if (info.isDirectory() && name === 'swiftpm') continue;
        if (generatedDirectories.has(name) || generatedFiles.has(name) || excludedFiles.has(name)
          || input.endsWith(`${sep}.idea${sep}workspace.xml`)) continue;
        if (info.isDirectory() && !info.isSymbolicLink()) {
          mkdirSync(output, { recursive: true, mode: 0o700 });
          visit(input, output);
        } else if (info.isFile() || info.isSymbolicLink()) {
          if(sourceDirectory===sourceRoot)copyHostInput(input,output,sourceRoot);else symlinkSync(input, output);
        } else fail(`源码视图遇到不支持的条目：${input}`);
      }
    }

    visit(sourceDirectory, destinationRoot);
    if(sourceDirectory===sourceRoot) materializePlatformInputs(sourceRoot,destinationRoot);
    if (sourceDirectory === sourceRoot) {
      // Xcode/Gradle 固定入口只在target内生成；每个入口绑定一个已核对的源文件。
      const mappings = [
        ['ios/project/Runner.xcscheme', 'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme'],
      ];
      for (const [sourcePath, targetPath] of mappings) {
        const input = join(sourceRoot, sourcePath), output = join(destinationRoot, targetPath);
        const info = lstatSync(input, { throwIfNoEntry: false });
        if (!info?.isFile() || info.isSymbolicLink()) fail(`平台输入缺少普通文件：${sourcePath}`);
        existingAncestors(dirname(output), '平台输出');
        if (lstatSync(output, { throwIfNoEntry: false })) fail(`平台入口重复：${targetPath}`);
        mkdirSync(dirname(output), { recursive: true, mode: 0o700 });
        copyHostInput(input,output,sourceRoot);
      }
      for (const { input, name } of wrappers) {
        const output = join(destinationRoot, 'android', name);
        existingAncestors(dirname(output), 'Wrapper目标');
        if (lstatSync(output, { throwIfNoEntry: false })) fail('Wrapper目标重复：' + name);
        mkdirSync(dirname(output), { recursive: true, mode: 0o700 });
        copyFileSync(input, output);
        if (name === 'gradlew') chmodSync(output, 0o755);
      }
    }
  }

  const dependencies = resolveFirstPartyDependencies(sourceRoot, workRoot);
  await materialize(sourceRoot);
  const views = {};
  for (const [name, item] of Object.entries(dependencies)) {
    await materialize(item.root);
    views[name] = mappedPath(item.root);
  }
  for (const [name, value] of Object.entries(projectedPubMetadata(sourceRoot, dependencies, views))) {
    const path = join(mappedPath(sourceRoot), name);
    if (lstatSync(path, { throwIfNoEntry: false })?.isSymbolicLink()) rmSync(path);
    writeFileSync(path, value);
  }
  if(prior){restoreViewIncremental(viewRoot+'.previous',viewRoot);rmSync(viewRoot+'.previous',{recursive:true});}
  return mappedPath(sourceRoot);
  }catch(error){if(existsSync(viewRoot))rmSync(viewRoot,{recursive:true});if(prior&&existsSync(viewRoot+'.previous'))renameSync(viewRoot+'.previous',viewRoot);throw error;}
}

// CI预先解析Pub后复用同一视图；不接受另一工作根、源码副本或漂移的SDK依赖。
async function verifyView(sourceInput, workInput) {
  const sourceRoot = absolutePath(sourceInput, '产品源码根');
  const workRoot = absolutePath(workInput, '产品工作根');
  ordinaryDirectory(sourceRoot, '产品源码根');
  ordinaryDirectory(workRoot, '产品工作根');
  existingAncestors(workRoot, '产品工作根');
  if (!inside(join(sourceRoot, 'target'), workRoot) || workRoot === join(sourceRoot, 'target')) fail('产品工作根必须在本仓target内');
  const viewRoot = join(workRoot, 'source-view');
  const projectRoot = join(viewRoot, sourceRoot.replace(/^\/+/, ''));
  ordinaryDirectory(projectRoot, '产品视图根');
  const dependencies = resolveFirstPartyDependencies(sourceRoot, workRoot), views = {};
  for (const [name, item] of Object.entries(dependencies)) {
    const view = join(viewRoot, item.root.replace(/^\/+/, ''));
    await assertFirstPartyView(item.root, view);
    views[name] = view;
  }
  for (const [name, expected] of Object.entries(projectedPubMetadata(sourceRoot, dependencies, views))) {
    const path = join(projectRoot, name), info = lstatSync(path, { throwIfNoEntry: false });
    if (!info?.isFile() || info.isSymbolicLink() || readFileSync(path, 'utf8') !== expected) fail('本轮Pub声明或锁漂移');
  }
  const expectedPackages = Object.entries(views);
  const configPath = join(projectRoot, '.dart_tool/package_config.json');
  if (existsSync(configPath)) {
    const config = JSON.parse(readFileSync(configPath, 'utf8'));
    for (const [name, view] of expectedPackages) {
      const dependencies = config.packages?.filter(item => item.name === name) ?? [];
      if (dependencies.length !== 1
          || fileURLToPath(new URL(dependencies[0].rootUri, pathToFileURL(configPath))).replace(/[\/]$/u, '') !== view) {
        fail('Pub实际SDK依赖未绑定本轮消费视图');
      }
    }
  }
  return projectRoot;
}

async function projectFramework(values) {
  const sourceRoot = absolutePath(values['source-root'], '产品源码根');
  const projectRoot = absolutePath(values['project-root'], '产品视图根');
  const workRoot = absolutePath(values['work-root'], '产品工作根');
  const packageRoot = absolutePath(values['package-root'], 'SDK源码根');
  const framework = absolutePath(values.framework, 'Framework目录');
  const packageSubpath = values['package-subpath'];
  if (packageSubpath.startsWith('/') || packageSubpath.includes('\\')
    || packageSubpath.split('/').some(part => !part || part === '.' || part === '..')
    || !packageSubpath.endsWith('.xcframework')) fail('Framework投影子路径无效');
  ordinaryDirectory(sourceRoot, '产品源码根');
  ordinaryDirectory(packageRoot, 'SDK源码根');
  ordinaryDirectory(projectRoot, '产品视图根');
  ordinaryDirectory(workRoot, '产品工作根');
  ordinaryDirectory(framework, 'Framework目录');
  if (!inside(workRoot, projectRoot) || !inside(workRoot, framework)) {
    fail('工程视图与Framework必须归属同一产品工作根');
  }
  const suffix = sourceRoot.replace(/^\/+/, '');
  if (!projectRoot.endsWith(`${sep}${suffix}`)) fail('产品视图没有保留源绝对路径映射');
  const viewRoot = projectRoot.slice(0, -(suffix.length + 1));
  if (!inside(workRoot, viewRoot)) fail('工程视图映射根越界');
  const packageView = join(viewRoot, packageRoot.replace(/^\/+/, ''));
  ordinaryDirectory(packageView, 'SDK视图根');
  const manifest = join(packageView, 'pubspec.yaml');
  const manifestInfo = lstatSync(manifest, { throwIfNoEntry: false });
  if (await firstPartyViewApi(packageRoot)) await assertFirstPartyView(packageRoot, packageView);
  else if (!manifestInfo?.isSymbolicLink() || realpathSync(manifest) !== join(packageRoot, 'pubspec.yaml')) {
    fail('SDK视图与源码根绑定无效');
  }
  const destination = join(packageView, ...packageSubpath.split('/'));
  const parent = parse(destination).dir;
  ordinaryDirectory(parent, 'Framework投影父目录');
  const existing = lstatSync(destination, { throwIfNoEntry: false });
  if (existing) {
    if (!existing.isSymbolicLink() || realpathSync(destination) !== framework) {
      fail('Framework投影目标被其它条目占用');
    }
    return destination;
  }
  symlinkSync(framework, destination, 'dir');
  if (!lstatSync(destination).isSymbolicLink() || realpathSync(destination) !== framework) {
    fail('Framework投影回读验真失败');
  }
  return destination;
}

async function runViewCLI(argv) {
try {
  const [command, ...values] = argv;
  const parsed = argumentsFor(command, values);
  const result = command === 'dependencies'
    ? JSON.stringify(resolveFirstPartyDependencies(parsed['source-root'], parsed['work-root']))
    : (command === 'create' || command === 'create-android')
    ? await createView(parsed['source-root'], parsed['work-root'], command === 'create-android')
    : command === 'verify'
      ? await verifyView(parsed['source-root'], parsed['work-root'])
      : await projectFramework(parsed);
  process.stdout.write(`${result}\n`);
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
}

}

return {resolveFirstPartyDependencies,runViewCLI,copyHostInput};
}
const sourceView = await sourceViewImplementation();
export const {resolveFirstPartyDependencies,copyHostInput}=sourceView;
export const SOURCE_VIEW_SOURCE=sourceViewImplementation.toString();
async function nativeTestsImplementation() {
// 测试库来自本轮SDK产物和锁定Pub包，禁止默认HOME缓存、邻仓或目录扫描回退。
const {lstatSync, readFileSync, realpathSync} = await import("node:fs");
const {isAbsolute, join, relative, resolve, sep} = await import("node:path");
const {fileURLToPath, pathToFileURL} = await import("node:url");

function ordinary(path, directory=false) {
  if(typeof path!=='string'||!isAbsolute(path)||resolve(path)!==path)throw Error('测试原生库路径无效');
  const stat=lstatSync(path,{throwIfNoEntry:false});
  if(!(directory?stat?.isDirectory():stat?.isFile())||stat.isSymbolicLink()||realpathSync(path)!==path)throw Error('测试原生库不是本轮普通文件或目录');
  return path;
}
function inside(root,path) {
  const rel=relative(root,path);
  if(!rel||rel==='..'||rel.startsWith('..'+sep)||isAbsolute(rel))throw Error('测试原生库越出本轮缓存');
}
function host(platform,arch) {
  if(platform==='linux'&&arch==='x64')return {core:'libcitizensdk.so',isar:'linux/libisar.so'};
  if(platform==='darwin'&&(arch==='arm64'||arch==='x64'))return {core:'libcitizensdk.dylib',isar:'macos/libisar.dylib'};
  throw Error('测试原生库宿主不受支持');
}
function citizenCorePath(output,platform=process.platform,arch=process.arch) {
  return ordinary(join(ordinary(output,true),'abi-host',host(platform,arch).core));
}
function isarCorePath(configPath,pubCache,lockPath,platform=process.platform,arch=process.arch) {
  ordinary(configPath); ordinary(pubCache,true); ordinary(lockPath);
  const lock=readFileSync(lockPath,'utf8');
  const blocks=[...lock.matchAll(/^  isar_community_flutter_libs:\n(?:[ \t]{4,}[^\n]*\n)+/gm)];
  if(blocks.length!==1||!/^    source: hosted$/m.test(blocks[0][0]))throw Error('Isar锁定包无效');
  const versions=[...blocks[0][0].matchAll(/^    version: "([0-9]+\.[0-9]+\.[0-9]+)"$/gm)];
  if(versions.length!==1)throw Error('Isar锁定版本不唯一');
  const config=JSON.parse(readFileSync(configPath,'utf8'));
  const packages=Array.isArray(config.packages)?config.packages.filter(p=>p.name==='isar_community_flutter_libs'):[];
  if(config.configVersion!==2||packages.length!==1||typeof packages[0].rootUri!=='string')throw Error('Isar本轮包坐标不唯一');
  const url=new URL(packages[0].rootUri,pathToFileURL(configPath));
  if(url.protocol!=='file:'||url.search||url.hash)throw Error('Isar本轮包坐标无效');
  const root=ordinary(fileURLToPath(url).replace(/[\/]$/u,''),true);
  inside(pubCache,root);
  const expected=join(pubCache,'hosted','pub.dev','isar_community_flutter_libs-'+versions[0][1]);
  if(root!==expected)throw Error('Isar包坐标与锁定缓存不一致');
  const manifest=readFileSync(ordinary(join(root,'pubspec.yaml')),'utf8');
  if(!/^name: isar_community_flutter_libs$/m.test(manifest)||!new RegExp('^version: '+versions[0][1].replaceAll('.','\\.')+'$','m').test(manifest))throw Error('Isar包身份与锁不一致');
  return ordinary(join(root,host(platform,arch).isar));
}
function runNativeCLI(argv) {
  const [command,...args]=argv;
  if(command==='core'&&args.length===1)process.stdout.write(citizenCorePath(...args));
  else if(command==='isar'&&args.length===3)process.stdout.write(isarCorePath(...args));
  else throw Error('测试原生库入口参数无效');
}

return {citizenCorePath,isarCorePath,runNativeCLI};
}
const nativeTests = await nativeTestsImplementation();
export const {citizenCorePath,isarCorePath}=nativeTests;
async function institutionsImplementation() {
// CitizenApp 公权机构 finalized 链快照生成器。
//
// 从节点 JSON-RPC 的同一 finalized 块读取 `PublicManage.Institutions` 与
// `PublicManage.InstitutionAccounts`，直接生成链快照索引。
// 生成结果只是 App 本地查询索引；身份、绑定、付款和权限仍在操作前精确读链。
//
// 用法:
//   CHAIN_RPC_URL=https://rpc.example.invalid node scripts/build.mjs generate institutions
//   node scripts/build.mjs generate institutions \
//     --rpc-url https://rpc.example.invalid --at 0x... \
//     --chainspec ../target/chainspec/chainspec.app.json \
//     --out-dir target/test/snapshot/institutions
//
// 正式冻结由 bake-chainspec.sh 显式传入块 0、轻形态 chainspec 和暂存目录；
// 默认路径只服务于人工刷新当前 App 缓存，不构成第二个创世真源。
// Cloudflare Access HTTP 入口可选从环境读取 `CF_ACCESS_CLIENT_ID` 和
// `CF_ACCESS_CLIENT_SECRET`，脚本不会把凭据写入产物或日志。

const { createHash } = await import("node:crypto");
const { writeFileSync, mkdirSync, readFileSync, existsSync } = await import("node:fs");
const { dirname, join, resolve } = await import("node:path");
const { fileURLToPath } = await import("node:url");

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = arg(
  '--out-dir',
  join(__dirname, '..', 'assets', 'institutions'),
);
const CHAIN_SPEC = arg(
  '--chainspec',
  join(__dirname, '..', 'assets', 'chainspec.json'),
);
const CHAIN_RPC_URL = arg(
  '--rpc-url',
  process.env.CHAIN_RPC_URL || '',
);
const PAGE_SIZE = 500;
const BATCH_SIZE = 200;

// twox128("PublicManage") + twox128(storage)。名称变化时必须同时更新链元数据契约。
const INSTITUTIONS_PREFIX =
  '0x3fdf0b7e6001a27b1f4c2913ca162bf72ef145c44f710c6fe55cae381219f7b2';
const ACCOUNTS_PREFIX =
  '0x3fdf0b7e6001a27b1f4c2913ca162bf7ca63afb529001c3370b9aa5ba2bd1fd7';

const PROVINCES = [
  ['ZS', '中枢省'], ['LN', '岭南省'], ['GD', '广东省'], ['GX', '广西省'],
  ['FJ', '福建省'], ['HN', '海南省'], ['YN', '云南省'], ['GZ', '贵州省'],
  ['HU', '湖南省'], ['JX', '江西省'], ['ZJ', '浙江省'], ['JS', '江苏省'],
  ['SD', '山东省'], ['SX', '山西省'], ['HE', '河南省'], ['HB', '河北省'],
  ['HI', '湖北省'], ['SI', '陕西省'], ['CQ', '重庆省'], ['SC', '四川省'],
  ['GS', '甘肃省'], ['BP', '北平省'], ['HA', '海滨省'], ['SJ', '松江省'],
  ['LJ', '龙江省'], ['JL', '吉林省'], ['LI', '辽宁省'], ['NX', '宁夏省'],
  ['QH', '青海省'], ['AH', '安徽省'], ['TW', '台湾省'], ['XZ', '西藏省'],
  ['XJ', '新疆省'], ['XK', '西康省'], ['AL', '阿里省'], ['CL', '葱岭省'],
  ['YL', '伊犁省'], ['HX', '河西省'], ['KL', '昆仑省'], ['HT', '河套省'],
  ['RH', '热河省'], ['XA', '兴安省'], ['HJ', '合江省'],
];
const RESERVED_ACCOUNT_NAMES = new Set([
  '主账户', '费用账户', '永久质押', '安全基金', '两和基金',
]);

function arg(name, fallback) {
  const index = process.argv.indexOf(name);
  return index >= 0 && index + 1 < process.argv.length
    ? process.argv[index + 1]
    : fallback;
}

function sha256Text(text) {
  return createHash('sha256').update(text).digest('hex');
}

function sha256File(path) {
  return existsSync(path) ? sha256Text(readFileSync(path)) : '';
}

function bytes(hex) {
  const clean = hex.startsWith('0x') ? hex.slice(2) : hex;
  return Buffer.from(clean, 'hex');
}

function readCompact(data, offset) {
  const first = data[offset];
  const mode = first & 3;
  if (mode === 0) return [first >> 2, 1];
  if (mode === 1) return [data.readUInt16LE(offset) >> 2, 2];
  if (mode === 2) return [data.readUInt32LE(offset) >>> 2, 4];
  throw new Error('不支持大整数 SCALE compact 长度');
}

function readVec(data, offset) {
  const [length, lengthBytes] = readCompact(data, offset);
  const start = offset + lengthBytes;
  const end = start + length;
  if (end > data.length) throw new Error('SCALE Vec 越界');
  return [data.subarray(start, end), end];
}

// SCALE Option:None=1 字节(0x00);Some=0x01 + 值。readInner(data, o) 返回值结束后的
// offset。仅用于跳过字段推进 offset（生成包不需要法定代表人字段值）。
function skipOption(data, offset, readInner) {
  const tag = data[offset];
  if (tag === 0) return offset + 1;
  if (tag === 1) return readInner(data, offset + 1);
  throw new Error(`非法 SCALE Option tag=${tag}`);
}

// 当前链上法定代表人是一个原子 Option；Some 内严格依次编码姓、名、公民 CID 和账户。
function skipLegalRepresentative(data, offset) {
  return skipOption(data, offset, (value, innerOffset) => {
    let next = readVec(value, innerOffset)[1];
    next = readVec(value, next)[1];
    next = readVec(value, next)[1];
    if (next + 32 > value.length) throw new Error('法定代表人账户 SCALE 越界');
    return next + 32;
  });
}

// 机构码真源:从 cid_number 核心段还原,与链上 parse_cid_number_parts 逐字一致,
// 免疫链上 InstitutionInfo 结构体字段漂移(primitives/cid/number.rs)。
// 格式 R5(5)-核心段(5)-N9(9)-D4(4);核心段 seg2[3] 为数字→3 字符码,为字母→4 字符码。
function institutionCodeFromCid(cidNumber) {
  const seg2 = cidNumber.split('-')[1] ?? '';
  if (seg2.length !== 5) throw new Error(`cid 核心段格式非法: ${cidNumber}`);
  const isDigit = seg2[3] >= '0' && seg2[3] <= '9';
  return isDigit ? seg2.slice(0, 3) : seg2.slice(0, 4);
}

function decodeInstitutionKey(keyHex) {
  const key = bytes(keyHex);
  const [cid] = readVec(key, 48);
  return cid.toString('utf8');
}

function decodeAccountKey(keyHex) {
  const key = bytes(keyHex);
  const [cid, afterCid] = readVec(key, 48);
  const [accountName] = readVec(key, afterCid + 16);
  return [cid.toString('utf8'), accountName.toString('utf8')];
}

function decodeInstitution(cidNumber, valueHex) {
  const value = bytes(valueHex);
  let offset = 0;
  const [fullName, afterFullName] = readVec(value, offset);
  offset = afterFullName;
  const [shortName, afterShortName] = readVec(value, offset);
  offset = afterShortName;
  const [townCode, afterTownCode] = readVec(value, offset);
  offset = afterTownCode;
  // town_code 与 institution_code 之间只有一个原子 legal_representative Option。
  // 必须按 entity-primitives 的字段顺序整体跳过，不能拆成多个独立 Option。
  offset = skipLegalRepresentative(value, offset);
  if (offset + 8 > value.length) throw new Error(`机构 ${cidNumber} 链值长度不足`);
  // 机构码不从 value blob 切(易随结构漂移),直接从 cid_number 核心段还原(方案B)。
  const institutionCode = institutionCodeFromCid(cidNumber);
  offset += 4; // 跳过 blob 里的 [u8;4] institution_code
  const createdAt = value.readUInt32LE(offset);
  offset += 4;
  // InstitutionInfo 已删除重复 lifecycle/status；Institutions 中存在即为当前有效机构，
  // 关闭时整条身份记录被清理。派生缓存不得继续猜测历史状态字节。
  if (offset !== value.length) {
    throw new Error(`机构 ${cidNumber} 存在未识别 SCALE 尾部字段`);
  }
  const match = /^([A-Z]{2})(\d{3})-/u.exec(cidNumber);
  if (!match) throw new Error(`机构号格式无效: ${cidNumber}`);
  return {
    cid_number: cidNumber,
    cid_full_name: fullName.toString('utf8'),
    cid_short_name: shortName.toString('utf8'),
    status: 'ACTIVE',
    province_code: match[1],
    city_code: match[2],
    town_code: townCode.toString('utf8'),
    institution_code: institutionCode,
    account_count: 0,
    custom_account_names: [],
    created_at_block: createdAt,
  };
}

class JsonRpc {
  constructor(url) {
    // 中文注释：显式配置 Cloudflare Edge 或受信任局域网入口；无明文与隐式回退。
    let endpoint;
    try { endpoint = new URL(url); } catch { throw new Error('链 RPC 必须配置完整 HTTPS/WSS 地址'); }
    if (!['https:', 'wss:'].includes(endpoint.protocol) || endpoint.username || endpoint.password || endpoint.hash) {
      throw new Error('链 RPC 必须配置完整 HTTPS/WSS 地址');
    }
    this.url = endpoint.href;
    this.nextId = 1;
    this.socket = null;
    this.pending = new Map();
  }

  async request(method, params = []) {
    if (this.url.startsWith('https://')) {
      return this.requestHttp(method, params);
    }
    return this.requestWebSocket(method, params);
  }

  async requestHttp(method, params) {
    const id = this.nextId++;
    const headers = { 'content-type': 'application/json' };
    if (process.env.CF_ACCESS_CLIENT_ID && process.env.CF_ACCESS_CLIENT_SECRET) {
      headers['CF-Access-Client-Id'] = process.env.CF_ACCESS_CLIENT_ID;
      headers['CF-Access-Client-Secret'] = process.env.CF_ACCESS_CLIENT_SECRET;
    }
    const response = await fetch(this.url, {
      method: 'POST',
      redirect: 'error',
      signal: AbortSignal.timeout(15_000),
      headers,
      body: JSON.stringify({ jsonrpc: '2.0', id, method, params }),
    });
    if (!response.ok) throw new Error(`${method} HTTP ${response.status}`);
    const payload = await response.json();
    if (payload.error) throw new Error(`${method}: ${JSON.stringify(payload.error)}`);
    return payload.result;
  }

  async requestWebSocket(method, params) {
    await this.ensureSocket();
    const id = this.nextId++;
    const result = new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
    });
    this.socket.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
    return result;
  }

  async ensureSocket() {
    if (this.socket?.readyState === WebSocket.OPEN) return;
    this.socket = new WebSocket(this.url);
    this.socket.addEventListener('message', (event) => {
      const payload = JSON.parse(event.data.toString());
      const pending = this.pending.get(payload.id);
      if (!pending) return;
      this.pending.delete(payload.id);
      if (payload.error) pending.reject(new Error(JSON.stringify(payload.error)));
      else pending.resolve(payload.result);
    });
    await new Promise((resolve, reject) => {
      this.socket.addEventListener('open', resolve, { once: true });
      this.socket.addEventListener('error', reject, { once: true });
    });
  }

  close() {
    this.socket?.close();
  }
}

async function readKeys(rpc, prefix, blockHash) {
  const keys = [];
  let startKey = null;
  for (;;) {
    const page = await rpc.request('state_getKeysPaged', [
      prefix, PAGE_SIZE, startKey, blockHash,
    ]);
    if (!page?.length) break;
    keys.push(...page);
    if (page.length < PAGE_SIZE) break;
    startKey = page.at(-1);
  }
  return keys;
}

async function readValues(rpc, keys, blockHash) {
  const values = new Map();
  for (let start = 0; start < keys.length; start += BATCH_SIZE) {
    const batch = keys.slice(start, start + BATCH_SIZE);
    const result = await rpc.request('state_queryStorageAt', [batch, blockHash]);
    for (const [key, value] of result?.[0]?.changes ?? []) values.set(key, value);
  }
  return values;
}

async function main() {
  if (process.argv.includes('--self-test')) return runInstitutionSelfTest();
  if (!existsSync(CHAIN_SPEC)) {
    throw new Error(`chainspec 不存在: ${CHAIN_SPEC}`);
  }
  const requestedBlockHash = arg('--at', '').trim().toLowerCase();
  if (requestedBlockHash && !/^0x[0-9a-f]{64}$/.test(requestedBlockHash)) {
    throw new Error('--at 必须为 0x + 64 位十六进制块哈希');
  }
  const selectedNames = new Set(
    arg('--provinces', '').split(',').map((value) => value.trim()).filter(Boolean),
  );
  const provinces = selectedNames.size === 0
    ? PROVINCES
    : PROVINCES.filter(([, name]) => selectedNames.has(name));
  if (provinces.length === 0) throw new Error('没有匹配的省份');

  const rpc = new JsonRpc(CHAIN_RPC_URL);
  try {
    const snapshotBlockHash = requestedBlockHash
      || await rpc.request('chain_getFinalizedHead');
    const header = await rpc.request('chain_getHeader', [snapshotBlockHash]);
    const genesisHash = await rpc.request('chain_getBlockHash', [0]);
    if (!header) throw new Error(`找不到快照块头: ${snapshotBlockHash}`);
    if (requestedBlockHash && snapshotBlockHash !== requestedBlockHash) {
      throw new Error(`节点返回了非请求块: ${snapshotBlockHash}`);
    }
    const snapshotBlockNumber = Number.parseInt(header.number, 16);

    const institutionKeys = await readKeys(rpc, INSTITUTIONS_PREFIX, snapshotBlockHash);
    const institutionValues = await readValues(rpc, institutionKeys, snapshotBlockHash);
    const accountKeys = await readKeys(rpc, ACCOUNTS_PREFIX, snapshotBlockHash);

    const accountNames = new Map();
    for (const key of accountKeys) {
      const [cidNumber, accountName] = decodeAccountKey(key);
      if (!accountNames.has(cidNumber)) accountNames.set(cidNumber, []);
      accountNames.get(cidNumber).push(accountName);
    }

    const institutions = [];
    for (const key of institutionKeys) {
      const value = institutionValues.get(key);
      if (!value) continue;
      const institution = decodeInstitution(decodeInstitutionKey(key), value);
      const names = [...new Set(accountNames.get(institution.cid_number) ?? [])];
      institution.account_count = names.length;
      institution.custom_account_names = names
        .filter((name) => !RESERVED_ACCOUNT_NAMES.has(name))
        .sort();
      institutions.push(institution);
    }
    institutions.sort((a, b) => a.cid_number.localeCompare(b.cid_number));

    mkdirSync(OUT_DIR, { recursive: true });
    const shardHashes = {};
    const provinceVersions = [];
    const rootParts = [];
    let total = 0;
    for (const [provinceCode, provinceName] of provinces) {
      const rows = institutions.filter((row) => row.province_code === provinceCode);
      const manifestVersion = sha256Text(JSON.stringify(rows));
      const shard = {
        province_name: provinceName,
        manifest_version: manifestVersion,
        count: rows.length,
        institutions: rows,
      };
      const shardJson = `${JSON.stringify(shard)}\n`;
      writeFileSync(join(OUT_DIR, `${provinceName}.json`), shardJson);
      const shardHash = sha256Text(shardJson);
      shardHashes[provinceName] = shardHash;
      const item = {
        province_name: provinceName,
        manifest_version: manifestVersion,
        shard_hash: shardHash,
        count: rows.length,
      };
      provinceVersions.push(item);
      rootParts.push(item);
      total += rows.length;
      process.stdout.write(`  ${provinceName}: ${rows.length} 机构\n`);
    }

    const publicInstitutionRoot = sha256Text(JSON.stringify(rootParts));
    writeFileSync(
      join(OUT_DIR, 'manifest.json'),
      `${JSON.stringify({
        chain_id: arg('--chain-id', 'citizenchain'),
        snapshot_block_number: snapshotBlockNumber,
        snapshot_block_hash: snapshotBlockHash,
        genesis_hash: genesisHash,
        state_root: header.stateRoot,
        chainspec_hash: sha256File(CHAIN_SPEC),
        public_institution_root: publicInstitutionRoot,
        version: `${snapshotBlockHash}:${publicInstitutionRoot}`,
        shard_hashes: shardHashes,
        provinces: provinceVersions,
      }, null, 2)}\n`,
    );
    process.stdout.write(
      `snapshot #${snapshotBlockNumber}: ${provinces.length} 省，共 ${total} 机构；`
      + `public_institution_root=${publicInstitutionRoot}\n`,
    );
  } finally {
    rpc.close();
  }
}

return {JsonRpc,main,decodeInstitution};
}
const institutions = await institutionsImplementation();
export const {JsonRpc}=institutions;
async function generateDivisions() {
// 行政区字典数据包生成器(ADR-021 §A2)。
//
// 唯一真源 = citizenchain/onchina/src/cid/china/china.sqlite。本生成器**直接 dump 三表,零映射**:
// 任何「修正名字」逻辑禁止进此文件——改名只改 china.sqlite,这里纯搬运。
// 铁律：china.sqlite 行政区 code 不可变、不复用，生成器禁止改写源数据。
//
// 产物(按省分片,客户端按需懒加载;首启灌 Isar AdminDivisionEntity 作字典):
//   assets/divisions/manifest.json
//     = { version, generated_at, china_sqlite_sha256, province_count, city_count, town_count }
//   assets/divisions/provinces.json          = [{ code, name }]
//   assets/divisions/cities/<省code>.json    = [{ code, name }]
//   assets/divisions/towns/<省code>.json     = [{ city_code, code, name }]
//
// manifest 带 china_sqlite_sha256 + version,与机构包同批生成、版本耦合:客户端可校验
// 机构包与字典是否同一份 china.sqlite 派生(hash 不一致即提示需更新)。
//
// 用法:
//   node scripts/build.mjs generate divisions [--version 2] [--db <路径>]

const { DatabaseSync } = await import("node:sqlite");
const { writeFileSync, mkdirSync, readFileSync, rmSync } = await import("node:fs");
const { createHash } = await import("node:crypto");
const { dirname, join, resolve } = await import("node:path");
const { fileURLToPath } = await import("node:url");

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, '..', 'assets', 'divisions');
const DEFAULT_DB = resolve(
  __dirname,
  '..',
  '..',
  'citizenchain',
  'onchina',
  'src',
  'cid',
  'china',
  'china.sqlite',
);

function arg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i >= 0 && i + 1 < process.argv.length ? process.argv[i + 1] : fallback;
}

function main() {
  const dbPath = arg('--db', DEFAULT_DB);
  const sha256 = createHash('sha256').update(readFileSync(dbPath)).digest('hex');

  const db = new DatabaseSync(dbPath, { readOnly: true });
  const metadataVersion = db
    .prepare("SELECT value FROM metadata WHERE key = 'admin_division_version'")
    .get()?.value;
  const version = arg('--version', metadataVersion ? String(metadataVersion) : '0');

  // 省:全量一份
  const provinces = db
    .prepare('SELECT code, name FROM provinces ORDER BY sort_order, code')
    .all();

  // 市:按省分片
  const cities = db
    .prepare('SELECT province_code, code, name FROM cities ORDER BY province_code, sort_order, code')
    .all();
  const citiesByProv = new Map();
  for (const r of cities) {
    if (!citiesByProv.has(r.province_code)) citiesByProv.set(r.province_code, []);
    citiesByProv.get(r.province_code).push({ code: r.code, name: r.name });
  }

  // 镇:按省分片(最大头)
  const towns = db
    .prepare('SELECT province_code, city_code, code, name FROM towns ORDER BY province_code, city_code, code')
    .all();
  const townsByProv = new Map();
  for (const r of towns) {
    if (!townsByProv.has(r.province_code)) townsByProv.set(r.province_code, []);
    townsByProv.get(r.province_code).push({ city_code: r.city_code, code: r.code, name: r.name });
  }

  db.close();

  // 先清空分片目录,避免省 code 改名后旧分片继续留在安装包中。
  rmSync(join(OUT_DIR, 'cities'), { recursive: true, force: true });
  rmSync(join(OUT_DIR, 'towns'), { recursive: true, force: true });
  mkdirSync(join(OUT_DIR, 'cities'), { recursive: true });
  mkdirSync(join(OUT_DIR, 'towns'), { recursive: true });

  writeFileSync(join(OUT_DIR, 'provinces.json'), JSON.stringify(provinces, null, 0));
  for (const [pcode, list] of citiesByProv) {
    writeFileSync(join(OUT_DIR, 'cities', `${pcode}.json`), JSON.stringify(list, null, 0));
  }
  for (const [pcode, list] of townsByProv) {
    writeFileSync(join(OUT_DIR, 'towns', `${pcode}.json`), JSON.stringify(list, null, 0));
  }

  // 省级内容版本(增量同步用):客户端按 ver 跳过没变的省,只 reconcile 变了的省。
  // ver = 该省"市分片 + 镇分片"内容的 sha256 前 16 位,内容(含改名/删码/重排)一变即变。
  const provinceVersions = provinces.map((p) => {
    const payload =
      JSON.stringify(citiesByProv.get(p.code) ?? []) +
      JSON.stringify(townsByProv.get(p.code) ?? []);
    return { code: p.code, ver: createHash('sha256').update(payload).digest('hex').slice(0, 16) };
  });

  writeFileSync(
    join(OUT_DIR, 'manifest.json'),
    JSON.stringify(
      {
        version,
        generated_at: version,
        china_sqlite_sha256: sha256,
        province_count: provinces.length,
        city_count: cities.length,
        town_count: towns.length,
        // 省级版本表:[{ code, ver }],客户端逐省比对,只重灌 ver 变了的省。
        provinces: provinceVersions,
      },
      null,
      2,
    ),
  );

  // 命令行生成器的正式结果直接写入标准输出，不使用会被开发残留门禁禁止的调试日志接口。
  process.stdout.write(
    `行政区字典生成完成:省 ${provinces.length} / 市 ${cities.length} / 镇 ${towns.length}` +
      `\n  version=${version}\n  china_sqlite_sha256=${sha256.slice(0, 16)}…\n  out=${OUT_DIR}\n`,
  );
}

main();

}
async function generateRegistry() {
const { execFileSync } = await import("node:child_process");
const {default: fs} = await import("node:fs");
const {default: path} = await import("node:path");
const { fileURLToPath } = await import("node:url");

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const cbPath = path.join(repoRoot, 'citizenchain/runtime/primitives/cid/china/china_cb.rs');
const chPath = path.join(repoRoot, 'citizenchain/runtime/primitives/cid/china/china_ch.rs');
const zfPath = path.join(repoRoot, 'citizenchain/runtime/primitives/cid/china/china_zf.rs');
const sfPath = path.join(repoRoot, 'citizenchain/runtime/primitives/cid/china/china_sf.rs');
const outPath = path.join(
  repoRoot,
  'citizenapp/lib/citizen/institution/governance_registry.generated.dart',
);

function extractField(block, name) {
  const quoted = new RegExp(`${name}:\\s*"([^"]+)"`).exec(block);
  if (quoted) return quoted[1];
  const hex = new RegExp(`${name}:\\s*hex!\\("([0-9a-fA-F]+)"\\)`).exec(block);
  if (hex) return hex[1].toLowerCase();
  throw new Error(`missing ${name} in block:\n${block.slice(0, 240)}`);
}

function extractStructs(source, structName) {
  const blocks = [];
  const pattern = new RegExp(`${structName}\\s*\\{([\\s\\S]*?)\\n\\s*\\},`, 'g');
  let match;
  while ((match = pattern.exec(source)) !== null) {
    blocks.push(match[1]);
  }
  // 数据块必含带引号的 cid_number；懒惰正则会把 struct 定义体与后续
  // 非数据常量(如 FscGenesisAssignment)误捕成块,在此过滤。
  return blocks.filter((block) => /cid_number:\s*"/.test(block));
}

function dartString(value) {
  return `'${value.replaceAll('\\', '\\\\').replaceAll("'", "\\'")}'`;
}

/// AccountId 规范形式（ADR-040）：小写 `0x` + 64 位十六进制。
/// china_*.rs 里是 `hex!("…")` 裸 hex，落到 Dart 必须补 `0x`，
/// 否则 `isAccountIdText()` 判定失败。
function dartAccountId(hex) {
  if (!/^[0-9a-f]{64}$/.test(hex)) {
    throw new Error(`invalid account id hex: ${hex}`);
  }
  return dartString(`0x${hex}`);
}

function dartInstitution(item) {
  const lines = [
    '  InstitutionInfo(',
    `    cidFullName: ${dartString(item.cidFullName)},`,
    `    cidShortName: ${dartString(item.cidShortName)},`,
    `    cidFullNameEn: ${dartString(item.cidFullNameEn)},`,
    `    cidShortNameEn: ${dartString(item.cidShortNameEn)},`,
    `    cidNumber: ${dartString(item.cidNumber)},`,
    `    orgType: OrgType.${item.orgType},`,
  ];
  if (item.adminAccountCode) {
    lines.push(`    adminAccountCode: ${dartString(item.adminAccountCode)},`);
  }
  lines.push(
    '    accounts: InstitutionAccounts(',
    `      mainAccountId: ${dartAccountId(item.mainAccount)},`,
    `      feeAccountId: ${dartAccountId(item.feeAccount)},`,
  );
  if (item.safetyFundAccount) {
    lines.push(`      safetyFundAccountId: ${dartAccountId(item.safetyFundAccount)},`);
  }
  if (item.heAccount) {
    lines.push(`      heAccountId: ${dartAccountId(item.heAccount)},`);
  }
  if (item.stakeAccount) {
    lines.push(`      stakeAccountId: ${dartAccountId(item.stakeAccount)},`);
  }
  lines.push('    ),', '  ),');
  return lines.join('\n');
}

const cbSource = fs.readFileSync(cbPath, 'utf8');
const chSource = fs.readFileSync(chPath, 'utf8');
const zfSource = fs.readFileSync(zfPath, 'utf8');
const sfSource = fs.readFileSync(sfPath, 'utf8');
const safetyFundMatch = /SAFETY_FUND_ACCOUNT:\s*\[u8;\s*32\]\s*=\s*hex!\("([0-9a-fA-F]+)"\)/.exec(
  cbSource,
);
if (!safetyFundMatch) throw new Error('missing SAFETY_FUND_ACCOUNT');
const safetyFundAccount = safetyFundMatch[1].toLowerCase();
const heFundMatch = /NRC_HE_ACCOUNT:\s*\[u8;\s*32\]\s*=\s*hex!\("([0-9a-fA-F]+)"\)/.exec(
  cbSource,
);
if (!heFundMatch) throw new Error('missing NRC_HE_ACCOUNT');
const heAccount = heFundMatch[1].toLowerCase();

const cbItems = extractStructs(cbSource, 'ChinaCb').map((block, index) => ({
  cidFullName: extractField(block, 'cid_full_name'),
  cidShortName: extractField(block, 'cid_short_name'),
  cidFullNameEn: extractField(block, 'cid_full_name_en'),
  cidShortNameEn: extractField(block, 'cid_short_name_en'),
  cidNumber: extractField(block, 'cid_number'),
  orgType: index === 0 ? 'nrc' : 'prc',
  mainAccount: extractField(block, 'main_account'),
  feeAccount: extractField(block, 'fee_account'),
  safetyFundAccount: index === 0 ? safetyFundAccount : null,
  heAccount: index === 0 ? heAccount : null,
  stakeAccount: null,
}));

const chItems = extractStructs(chSource, 'ChinaCh').map((block) => ({
  cidFullName: extractField(block, 'cid_full_name'),
  cidShortName: extractField(block, 'cid_short_name'),
  cidFullNameEn: extractField(block, 'cid_full_name_en'),
  cidShortNameEn: extractField(block, 'cid_short_name_en'),
  cidNumber: extractField(block, 'cid_number'),
  orgType: 'prb',
  mainAccount: extractField(block, 'main_account'),
  feeAccount: extractField(block, 'fee_account'),
  safetyFundAccount: null,
  heAccount: null,
  stakeAccount: extractField(block, 'stake_account'),
}));

function codeFromCidNumber(cidNumber) {
  const parts = cidNumber.split('-');
  if (parts.length < 2) throw new Error(`invalid cid_number: ${cidNumber}`);
  return parts[1].slice(0, 3);
}

function fixedGovernanceItemFrom(source, structName, code) {
  const block = extractStructs(source, structName).find(
    (item) => codeFromCidNumber(extractField(item, 'cid_number')) === code,
  );
  if (!block) throw new Error(`missing ${code} in ${structName}`);
  return {
    cidFullName: extractField(block, 'cid_full_name'),
    cidShortName: extractField(block, 'cid_short_name'),
    cidFullNameEn: extractField(block, 'cid_full_name_en'),
    cidShortNameEn: extractField(block, 'cid_short_name_en'),
    cidNumber: extractField(block, 'cid_number'),
    orgType: 'institution',
    adminAccountCode: code,
    mainAccount: extractField(block, 'main_account'),
    feeAccount: extractField(block, 'fee_account'),
    safetyFundAccount: null,
    heAccount: null,
    stakeAccount: null,
  };
}

const fixedGovernanceItems = [
  fixedGovernanceItemFrom(zfSource, 'ChinaZf', 'FRG'),
  fixedGovernanceItemFrom(sfSource, 'ChinaSf', 'NJD'),
];

if (cbItems.length !== 44) {
  throw new Error(`CHINA_CB count mismatch: ${cbItems.length}`);
}
if (chItems.length !== 43) {
  throw new Error(`CHINA_CH count mismatch: ${chItems.length}`);
}

const content = [
  "part of 'governance_registry.dart';",
  '',
  '// 本文件由 node scripts/build.mjs generate registry 自动生成。',
  '// 中文注释：创世治理机构中英全称/简称、cid_number 和制度账户来自 runtime primitives；管理员必须动态读取链上 AdminAccounts。',
  '',
  '/// 国储会（1 个）。',
  'const List<InstitutionInfo> kNrc = [',
  dartInstitution(cbItems[0]),
  '];',
  '',
  '/// 省储会（43 个）。',
  'const List<InstitutionInfo> kPrcs = [',
  cbItems.slice(1).map(dartInstitution).join('\n'),
  '];',
  '',
  '/// 省储行（43 个）。',
  'const List<InstitutionInfo> kProvincialBanks = [',
  chItems.map(dartInstitution).join('\n'),
  '];',
  '',
  '/// 其它固定治理机构（不进入治理 tab 联合投票列表）。',
  'const List<InstitutionInfo> kFixedGovernanceInstitutions = [',
  fixedGovernanceItems.map(dartInstitution).join('\n'),
  '];',
  '',
].join('\n');

fs.writeFileSync(outPath, content, 'utf8');
// 生成物必须是 dart format 稳定态，否则每次重生都在格式上打架。
execFileSync('dart', ['format', outPath], { stdio: 'inherit' });
console.log(`generated ${path.relative(repoRoot, outPath)} (${cbItems.length + chItems.length + fixedGovernanceItems.length} institutions)`);

}
// 仅保留系统/传输错误码；递归cause有界，未知值不回显，原Error对象与失败语义不改。
function safeDiagnosticCode(error,{status,aborted=false}={}){
 const permitted=['ABORT_ERR','ENOTFOUND','EAI_AGAIN','UND_ERR_SOCKET','UND_ERR_CONNECT_TIMEOUT','UND_ERR_HEADERS_TIMEOUT','UND_ERR_BODY_TIMEOUT','ERR_TLS_CERT_ALTNAME_INVALID','CERT_HAS_EXPIRED','DEPTH_ZERO_SELF_SIGNED_CERT','UNABLE_TO_VERIFY_LEAF_SIGNATURE','UNABLE_TO_GET_ISSUER_CERT_LOCALLY'];
 try{const seen=new Set();for(let depth=0;error&&depth<8&&!seen.has(error);depth++,error=error.cause){seen.add(error);const code=processErrorCode(error);if(code!=='UNKNOWN')return code;if(permitted.includes(error.code))return error.code;}}catch{}
 if(aborted)return 'ABORT_ERR';if(Number.isInteger(status)&&status>=400&&status<=599)return 'HTTP_'+status;return 'UNKNOWN';
}
function testInputGitStep(args){
 const step=args[0];if(['ls-remote','init','fetch','checkout','status'].includes(step))return step;
 if(step==='remote')return args[1]==='add'?'configure-origin':'verify-origin';
 if(step==='rev-parse')return ({HEAD:'verify-head','--abbrev-ref':'verify-branch','--show-toplevel':'verify-root','--absolute-git-dir':'verify-gitdir','--git-common-dir':'verify-common-dir'})[args[1]]||'verify-repository';
 return 'unknown';
}
function testInputGitDiagnostic(args,result){
 let code=safeDiagnosticCode(result.error);
 // Git常将传输原因写入stderr；只匹配固定类别，不输出任何正文、路径、参数或远端回显。
 if(code==='UNKNOWN'){
  const text=typeof result.stderr==='string'?result.stderr.slice(0,8192):'';
  if(/timed out|\btimeout\b/iu.test(text))code='ETIMEDOUT';
  else if(/could not resolve (?:host|proxy)/iu.test(text))code='ENOTFOUND';
  else if(/connection reset|connection was reset/iu.test(text))code='ECONNRESET';
  else if(/SSL certificate problem|certificate verify failed|server certificate verification failed/iu.test(text))code='TLS_CERTIFICATE_ERROR';
  else if(/authentication failed|terminal prompts disabled/iu.test(text))code='GIT_AUTH_FAILED';
  else if(/early EOF|unexpected disconnect|RPC failed/iu.test(text))code='GIT_TRANSPORT_ERROR';
 }
 const signal=result.signal==null?'none':Object.hasOwn(resourceOs.constants.signals,result.signal)?result.signal:'UNKNOWN';
 return {step:testInputGitStep(args),exit_code:Number.isSafeInteger(result.status)?result.status:null,signal,code};
}
function runTestInputGit(root,args,{spawnGit=spawnSync,environment=process.env,report=record=>process.stderr.write('链测试Git诊断：'+JSON.stringify(record)+'\n')}={}){
 const emit=record=>{try{report(record);}catch{}};
 emit({step:testInputGitStep(args),exit_code:null,signal:'none',code:'none'});
 let result;try{result=spawnGit('git',['-c','credential.helper=','-c','core.hooksPath=/dev/null','-c','protocol.file.allow=never','-c','gc.auto=0','-C',root,...args],{
  encoding:'utf8',env:{...environment,GIT_TERMINAL_PROMPT:'0',GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:process.platform==='win32'?'NUL':'/dev/null'}
 });}catch(error){emit(testInputGitDiagnostic(args,{error,status:null,signal:null}));throw error;}
 if(result.error||result.status!==0){emit(testInputGitDiagnostic(args,result));throw Error('链测试源取得或验真失败');}
 return result.stdout.trim();
}
async function runTestInputs(argv) {
// App金标读取链所有者已保存的不可变Git快照；不复制金标，不猜测邻仓。
const { readFileSync, lstatSync, realpathSync, mkdirSync, existsSync, rmSync } = await import("node:fs");
const { fileURLToPath } = await import("node:url");
const { join, resolve, isAbsolute } = await import("node:path");
const source = realpathSync(fileURLToPath(new URL('..', import.meta.url)));
const contract = JSON.parse(TEST_INPUTS_SOURCE);
const url = 'https://github.com/crcfrcn/citizenchain.git';
function fail(value) { throw Error(value); }
function directory(p) {
  const i = lstatSync(p);
  if (!i.isDirectory() || i.isSymbolicLink() || realpathSync(p) !== p) fail('链测试源目录无效');
}
function git(root, args) { return runTestInputGit(root,args); }
try {
  if (argv.length !== 1 || contract.schema !== 1 || contract.citizenchain?.url !== url
      || contract.citizenchain.ref !== 'main'
      || contract.citizenchain.paths.join('\n') !==
      'runtime/primitives/tests/fixtures/scale_codec_vectors.json\nruntime/primitives/tests/fixtures/role_permission.json') fail('链测试输入合同无效');
  const work = argv[0];
  if (!isAbsolute(work) || resolve(work) !== work || !work.startsWith(join(source, 'target') + '/')) fail('链测试工作根必须是本产品target内绝对路径');
  directory(work);
  let root = process.env.CITIZENCHAIN_ROOT;
  let expected;
  if (root) {
    if (!isAbsolute(root) || resolve(root) !== root) fail('明确链测试源不是绝对路径');
    expected = git(root, ['rev-parse', 'HEAD']);
  } else {
    root = join(work, 'chain-test-source');
    if (existsSync(root)) fail('链测试源目录已存在，拒绝混入旧输入');
    const reference = git(work, ['ls-remote', '--refs', url, 'refs/heads/main']);
    const match = /^([0-9a-f]{40})\s+refs\/heads\/main$/.exec(reference);
    if (!match) fail('链测试main没有唯一实际提交');
    expected = match[1]; mkdirSync(root, { mode: 0o700 }); const owned = lstatSync(root);
    try {
      git(root, ['init', '--quiet']); git(root, ['remote', 'add', 'origin', url]);
      git(root, ['fetch', '--no-tags', '--depth=1', 'origin', expected]);
      git(root, ['checkout', '--quiet', '--detach', expected]);
    } catch (error) {
      const now = lstatSync(root, { throwIfNoEntry: false });
      if (now?.isDirectory() && !now.isSymbolicLink() && now.dev === owned.dev && now.ino === owned.ino) rmSync(root, { recursive: true });
      throw error;
    }
  }
  directory(root); directory(join(root, '.git'));
  if (!/^[0-9a-f]{40}$/.test(expected) || git(root, ['rev-parse', 'HEAD']) !== expected
      || git(root, ['rev-parse', '--abbrev-ref', 'HEAD']) !== 'HEAD'
      || resolve(git(root, ['rev-parse', '--show-toplevel'])) !== root
      || resolve(git(root, ['rev-parse', '--absolute-git-dir'])) !== join(root, '.git')
      || resolve(root, git(root, ['rev-parse', '--git-common-dir'])) !== join(root, '.git')
      || git(root, ['remote', 'get-url', 'origin']) !== url
      || git(root, ['status', '--porcelain=v1', '--untracked-files=all'])) fail('链测试Git快照身份无效');
  for (const rel of contract.citizenchain.paths) {
    const p = join(root, rel), info = lstatSync(p);
    if (!info.isFile() || info.isSymbolicLink() || !info.size || realpathSync(p) !== p) fail('链所有者金标缺失或类型无效');
  }
  process.stdout.write(root + '\n');
} catch (error) { process.stderr.write(error.message + '\n'); process.exitCode = 1; }

}
async function checkLogos() {
// assets/logo是本产品Logo文件的唯一消费来源；记录原设计来源并拒绝重复副本。
const {createHash} = await import("node:crypto");
const {lstatSync, readFileSync} = await import("node:fs");
const {dirname, join, resolve, sep} = await import("node:path");
const {fileURLToPath} = await import("node:url");
const root=resolve(dirname(fileURLToPath(import.meta.url)), '..');
const manifest=JSON.parse(LOGO_ASSETS_SOURCE);
if(manifest.schema!==1||manifest.product!=='citizenapp'
 ||manifest.source?.repository!=='crcfrcn/citizenchain'
 ||manifest.source?.path!=='icons/logo.png'
 ||!/^[a-f0-9]{64}$/.test(manifest.source?.sha256||'')
 ||Object.keys(manifest.files||{}).length<30) throw Error('公民Logo来源清单无效');
const imageHashes=new Set(),images=new Set();
for(const [relative,hash] of Object.entries(manifest.files)) {
 if(!/^assets\/logo\/(?:icon|foreground|launch|mark)[1-9][0-9]*[.]png$/.test(relative)
  ||relative.split('/').some(part=>!part||part==='.'||part==='..')
  ||!/^[a-f0-9]{64}$/.test(hash)) throw Error('公民Logo清单路径或摘要无效');
 let current=root;
 for(const part of relative.split('/').slice(0,-1)) {
  current=join(current,part); const info=lstatSync(current);
  if(!info.isDirectory()||info.isSymbolicLink()) throw Error('公民Logo目录来源无效');
 }
 const file=join(root,...relative.split('/')),info=lstatSync(file);
 if(!file.startsWith(root+sep)||!info.isFile()||info.isSymbolicLink()
  ||createHash('sha256').update(readFileSync(file)).digest('hex')!==hash) throw Error('公民Logo派生物与受控清单不一致：'+relative);
 if(relative.startsWith('assets/logo/')){
  if(imageHashes.has(hash))throw Error('公民Logo存在重复图片来源');
  imageHashes.add(hash);images.add(relative.slice('assets/logo/'.length));
 }
}
if(images.size<2||JSON.stringify([...images].sort())!==JSON.stringify(readdirSync(join(root,'assets/logo')).sort()))throw Error('公民Logo唯一目录存在未登记或缺失文件');
function rejectPlatformCopies(directory){
 for(const name of readdirSync(directory)){
  const file=join(directory,name),info=lstatSync(file);
  if(info.isSymbolicLink())throw Error('原生资源来源经过链接');
  if(info.isDirectory())rejectPlatformCopies(file);
  else if(name.endsWith('.png'))throw Error('原生源码目录不得重复保存Logo图片');
 }
}
// 扁平平台源码不再有 resources 子目录；扫描整个平台输入树拒绝图标副本。
for(const platform of ['android','ios'])rejectPlatformCopies(join(root,platform));
process.stdout.write('公民Logo派生物清单检查通过\n');

}
export const BUILD_SHELL_SOURCES=Object.freeze({"run":"#!/usr/bin/env bash\n# 在调用方指定的源码外工作根生成本机优化安装包；本脚本不启动、不安装产品。\n#\n# 用法：node scripts/build.mjs run <ios|android>\n# 只读包检查：node scripts/build.mjs run <verify-ios-localization|verify-android-localization> <产物路径>\n# Isar 生成后补齐职责注释：node scripts/build.mjs run normalize-isar-comments\n#\n# 目标平台是必填参数，不做任何自动探测：探测总要在失败时选一个回落，\n# 而回落的那一端会被当成用户想编的那一端——「以为编了 iOS、实际编的 Android」\n# 就是这么来的。任意调用方都必须显式传入且只能构建这一端。\n#\n# 调用方可提供本仓target内的独立缓存目录；默认使用target/build/<平台>。\n# 公民链轻节点、交易和链存储全部由 CitizenSDK Flutter plugin 提供。\nset -euo pipefail\nSCRIPT_DIR=\"${CITIZENAPP_SCRIPTS_ROOT:?缺少源码脚本根}\"\n# 消解 scripts/..，确保直接产品源码身份使用唯一真实路径。\nAPP_ROOT=\"${CITIZENAPP_SOURCE_ROOT:?缺少产品源码根}\"\nREPO_ROOT=\"$APP_ROOT\"\n# 只补齐两份既定生成文件的职责说明；全部输入通过检查后才允许写入。\nif [[ \"${1:-}\" == normalize-isar-comments ]]; then\n  [[ \"$#\" == 1 ]] || { echo 'Isar 注释规范化不接受额外参数' >&2; exit 1; }\n  node - \"$APP_ROOT\" <<'NORMALIZE_ISAR_COMMENTS'\nconst { lstatSync, readFileSync, writeFileSync } = require('node:fs');\nconst { join } = require('node:path');\nconst root = process.argv[2];\nfor (const path of [root, join(root, 'lib'), join(root, 'lib/storage')]) {\n  if (!lstatSync(path).isDirectory() || lstatSync(path).isSymbolicLink()) {\n    throw new Error('Isar 输入目录必须为真实目录');\n  }\n}\nconst entries = [\n  ['user_isar', '// 由 user_isar.dart 生成用户域集合、序列化与查询；身份展示缓存不得作为授权真源。'],\n  ['wallet_isar', '// 由 wallet_isar.dart 生成钱包域集合、序列化与查询；余额展示快照不得作为链上授权真源。'],\n];\nconst header = '// GENERATED CODE - DO NOT MODIFY BY HAND\\n';\nconst updates = entries.map(([name, comment]) => {\n  const path = join(root, 'lib/storage', `${name}.g.dart`);\n  if (!lstatSync(path).isFile() || lstatSync(path).isSymbolicLink()) {\n    throw new Error(`Isar 生成文件必须为普通文件：${name}`);\n  }\n  const original = readFileSync(path, 'utf8');\n  const normalized = `${header}${comment}\\n`;\n  const body = original.startsWith(normalized) ? original.slice(normalized.length)\n    : original.startsWith(header) ? original.slice(header.length) : null;\n  if (body === null || !body.startsWith(`\\npart of '${name}.dart';\\n`)) {\n    throw new Error(`Isar 生成头或所属源文件不匹配：${name}`);\n  }\n  return { path, original, next: normalized + body };\n});\nfor (const { path, original, next } of updates) {\n  if (original !== next) writeFileSync(path, next);\n}\nprocess.stdout.write('Isar 两份生成文件职责注释已规范化，生成正文保持不变\\n');\nNORMALIZE_ISAR_COMMENTS\n  exit 0\nfi\nCITIZENSDK_ROOT=''\nTATACHATSDK_ROOT=''\nVIEW_SCRIPT=\"$SCRIPT_DIR/build.mjs\"\nPLATFORM=\"${1:?缺少目标平台，用法：$0 <ios|android>}\"\n[[ \"$PLATFORM\" == ios || \"$PLATFORM\" == android \\\n  || \"$PLATFORM\" == verify-ios-localization || \"$PLATFORM\" == verify-android-localization ]] \\\n  || { echo \"目标平台或检查模式不合法：$PLATFORM\" >&2; exit 1; }\nif [[ \"$PLATFORM\" == ios || \"$PLATFORM\" == android ]]; then\n  CITIZENAPP_WORK_DIR=\"${CITIZENAPP_WORK_DIR:-$APP_ROOT/target/build/$PLATFORM}\"\n  # macOS 的 /tmp、/var 可能是系统链接；先创建再读取物理路径，使默认直接开发路径\n  # 与工程视图的“规范绝对路径、无链接祖先”安全合同一致。\n  mkdir -p \"$CITIZENAPP_WORK_DIR\"\n  CITIZENAPP_WORK_DIR=\"$(cd \"$CITIZENAPP_WORK_DIR\" && pwd -P)\"\n  dependency_sources=\"$(node \"$VIEW_SCRIPT\" view dependencies --source-root \"$APP_ROOT\" --work-root \"$CITIZENAPP_WORK_DIR\")\"\n  CITIZENSDK_ROOT=\"$(printf '%s' \"$dependency_sources\" | node -e 'let s=\"\";process.stdin.on(\"data\",c=>s+=c);process.stdin.on(\"end\",()=>process.stdout.write(JSON.parse(s).citizen_sdk.root));')\"\n  TATACHATSDK_ROOT=\"$(printf '%s' \"$dependency_sources\" | node -e 'let s=\"\";process.stdin.on(\"data\",c=>s+=c);process.stdin.on(\"end\",()=>process.stdout.write(JSON.parse(s).tatachat_sdk.root));')\"\n  # 源码根只用于读取输入和调用原生脚本；Flutter可写状态始终进入调用方工作目录。\n  [[ \"$APP_ROOT\" == \"$REPO_ROOT\" ]] || {\n    echo \"citizenapp本机Build源码身份无效：$APP_ROOT\" >&2\n    exit 1\n  }\n  if [[ -z \"${CITIZENAPP_PROJECT_ROOT:-}\" ]]; then\n    CITIZENAPP_PROJECT_ROOT=\"$(node \"$VIEW_SCRIPT\" view create \\\n      --source-root \"$APP_ROOT\" --work-root \"$CITIZENAPP_WORK_DIR\")\"\n  fi\n  [[ -d \"$CITIZENAPP_PROJECT_ROOT\" && -f \"$CITIZENAPP_PROJECT_ROOT/pubspec.yaml\" ]] \\\n    || { echo 'CitizenApp Flutter 产品目录无效' >&2; exit 1; }\n  export CITIZENAPP_PROJECT_ROOT\n  cd \"$CITIZENAPP_PROJECT_ROOT\"\n  BUILD_WORK_DIR=\"${CITIZENAPP_BUILD_WORK_DIR:-$CITIZENAPP_WORK_DIR/work}\"\n  DEPENDENCY_WORK_DIR=\"${CITIZENAPP_DEPENDENCY_DIR:-$CITIZENAPP_WORK_DIR/dependencies}\"\n  BUILD_DIR=\"${CITIZENAPP_BUILD_DIR:-$BUILD_WORK_DIR/flutter}\"\n  ARTIFACT_ROOT=\"${CITIZENAPP_ARTIFACT_DIR:-$CITIZENAPP_WORK_DIR}\"\n  python3 - \"$APP_ROOT\" \"$CITIZENAPP_WORK_DIR\" \"$BUILD_WORK_DIR\" \"$DEPENDENCY_WORK_DIR\" \"$BUILD_DIR\" \"$ARTIFACT_ROOT\" <<'CHECK_OUTPUTS'\nfrom pathlib import Path\nimport sys\nsource = Path(sys.argv[1]).resolve()\nfor value in sys.argv[2:]:\n    raw = Path(value)\n    target = raw.resolve()\n    if not raw.is_absolute() or source / 'target' not in target.parents:\n        raise SystemExit(f'CitizenApp可写目录必须是本仓target内绝对路径：{value}')\nCHECK_OUTPUTS\n  export CITIZENAPP_BUILD_DIR=\"$BUILD_DIR\"\n  export CITIZENAPP_NATIVE_ANDROID_DIR=\"${CITIZENAPP_NATIVE_ANDROID_DIR:-$BUILD_WORK_DIR/native/android}\"\n  export CITIZENAPP_NATIVE_IOS_DIR=\"${CITIZENAPP_NATIVE_IOS_DIR:-$BUILD_WORK_DIR/native/ios}\"\n  export CARGO_TARGET_DIR=\"${CARGO_TARGET_DIR:-$BUILD_WORK_DIR/cargo}\"\n  export XDG_CONFIG_HOME=\"${XDG_CONFIG_HOME:-$DEPENDENCY_WORK_DIR/flutter-config}\"\n  export PUB_CACHE=\"${PUB_CACHE:-$DEPENDENCY_WORK_DIR/pub}\"\n  export GRADLE_USER_HOME=\"$DEPENDENCY_WORK_DIR/gradle\"\n  # 只有 Android 使用 Gradle；iOS 工程不装配 Wrapper，也不依赖 Android 工具。\n  if [[ \"$PLATFORM\" == android ]]; then\n    GRADLE_EXECUTABLE=\"${CITIZENAPP_GRADLE:-$CITIZENAPP_PROJECT_ROOT/android/gradlew}\"\n    [[ \"$GRADLE_EXECUTABLE\" == /* && -f \"$GRADLE_EXECUTABLE\" && ! -L \"$GRADLE_EXECUTABLE\"\n        && -x \"$GRADLE_EXECUTABLE\" ]] \\\n      || { echo 'CitizenApp Gradle执行器必须是绝对普通可执行文件' >&2; exit 1; }\n  fi\n  export CP_HOME_DIR=\"$DEPENDENCY_WORK_DIR/cocoapods\"\n  export TMPDIR=\"$CITIZENAPP_WORK_DIR/tmp/\"\n  export FLUTTER_SUPPRESS_ANALYTICS=true COCOAPODS_DISABLE_STATS=true\n  CITIZENAPP_GRADLE_INIT_SCRIPT=\"${CITIZENAPP_GRADLE_INIT_SCRIPT:-$CITIZENAPP_WORK_DIR/gradle.init.gradle}\"\n  CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR=\"${CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR:-$BUILD_WORK_DIR/flutter-gradle-plugin}\"\n  export CITIZENAPP_GRADLE_INIT_SCRIPT CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR\n  mkdir -p \"$XDG_CONFIG_HOME\" \"$TMPDIR\" \"$CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR\"\n  printf '%s\\n' \\\n    'gradle.beforeSettings { settings ->' \\\n    '    def source = System.getenv(\"CITIZENAPP_FLUTTER_GRADLE_ROOT\")' \\\n    '    if (source && settings.settingsDir.canonicalPath == new File(source).canonicalPath) {' \\\n    '        settings.pluginManagement.repositories {' \\\n    '            clear()' \\\n    '            mavenCentral()' \\\n    '            google()' \\\n    '            gradlePluginPortal()' \\\n    '        }' \\\n    '    }' \\\n    '}' \\\n    'gradle.beforeProject { project ->' \\\n    '    def source = System.getenv(\"CITIZENAPP_FLUTTER_GRADLE_ROOT\")' \\\n    '    def output = System.getenv(\"CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR\")' \\\n    '    if (source && output && project.rootDir.canonicalPath == new File(source).canonicalPath) {' \\\n    '        def suffix = project.path == \":\" ? \"root\" : project.path.substring(1).replace(\":\", \"/\")' \\\n    '        project.layout.buildDirectory.set(new File(output, suffix))' \\\n    '    }' \\\n    '}' >\"$CITIZENAPP_GRADLE_INIT_SCRIPT\"\n  # Flutter只接受相对产品根的build-dir配置；把源码外绝对目录换算为相对路径，\n  # 不能写死为产品源码下的cache/build，也不能在产品根生成build。\n  FLUTTER_BUILD_RELATIVE=\"$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' \"$BUILD_DIR\" \"$CITIZENAPP_PROJECT_ROOT\")\"\n  flutter config --build-dir=\"$FLUTTER_BUILD_RELATIVE\" >/dev/null\nfi\n\n# Android的SDK原生Gradle与最终App Gradle必须使用同一个产品JDK。\n# 直接开发可显式传JAVA_HOME；macOS本机默认使用Android Studio自带JBR。\nANDROID_JAVA_HOME=''\nANDROID_SDK_HOME=''\nif [[ \"$PLATFORM\" == android ]]; then\n  if [[ -n \"${ANDROID_HOME:-}\" && -n \"${ANDROID_SDK_ROOT:-}\" \\\n    && \"$ANDROID_HOME\" != \"$ANDROID_SDK_ROOT\" ]]; then\n    echo 'CitizenApp Android的ANDROID_HOME与ANDROID_SDK_ROOT必须一致' >&2\n    exit 1\n  fi\n  ANDROID_SDK_HOME=\"${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}\"\n  ANDROID_JAVA_HOME=\"${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}\"\n  [[ \"$ANDROID_SDK_HOME\" == /* && -d \"$ANDROID_SDK_HOME\" \\\n    && -d \"$ANDROID_SDK_HOME/ndk/28.2.13676358\" ]] \\\n    || { echo 'CitizenApp Android缺少带固定NDK的产品SDK目录' >&2; exit 1; }\n  [[ \"$ANDROID_JAVA_HOME\" == /* && -x \"$ANDROID_JAVA_HOME/bin/java\" ]] \\\n    || { echo 'CitizenApp Android缺少可执行产品JDK' >&2; exit 1; }\nfi\n\nPUB_GET_ARGS=(--enforce-lockfile)\ncase \"${CITIZENAPP_OFFLINE:-false}\" in\n  true) PUB_GET_ARGS+=(--offline); export CARGO_NET_OFFLINE=true ;;\n  false) ;;\n  *) echo 'CITIZENAPP_OFFLINE只接受true或false' >&2; exit 1 ;;\nesac\ngradle_network_arg=''\nCITIZENAPP_GRADLE_OFFLINE=\"${CITIZENAPP_GRADLE_OFFLINE:-${CITIZENAPP_OFFLINE:-false}}\"\ncase \"$CITIZENAPP_GRADLE_OFFLINE\" in\n  true) gradle_network_arg='--offline' ;;\n  false) ;;\n  *) echo 'CITIZENAPP_GRADLE_OFFLINE只接受true或false' >&2; exit 1 ;;\nesac\n\n# 离线调用方必须分别提供SDK与聊天SDK的Cargo闭包；产品Build按实际所有者切换，\n# 禁止把两套Cargo Home混用。普通开发者在线Build继续使用自己的标准Cargo环境。\nif [[ \"${CITIZENAPP_OFFLINE:-false}\" == true ]]; then\n  for value in \"${CITIZENAPP_SDK_CARGO_HOME:-}\" \"${CITIZENAPP_CHAT_CARGO_HOME:-}\"; do\n    [[ \"$value\" == \"$DEPENDENCY_WORK_DIR\"/* && -d \"$value\" && ! -L \"$value\" \\\n      && -f \"$value/config.toml\" ]] \\\n      || { echo 'CitizenApp离线Build缺少独立Cargo依赖闭包' >&2; exit 1; }\n  done\nfi\n\n# 仅清理本任务的候选包；不触碰源码、其它工作目录或另一端。\nclean_platform_build_outputs() {\n  case \"$PLATFORM\" in\n    ios) rm -rf \"$BUILD_DIR/ios/iphoneos/Runner.app\" ;;\n    android) rm -f \"$BUILD_DIR/app/outputs/flutter-apk/\"*.apk ;;\n  esac\n  mkdir -p \"$BUILD_DIR\"\n}\n\n# iOS Runner.app完成签名后只覆盖固定 `ios.app.zip`。\nretain_ios_local_artifact() {\n  local app_bundle=\"$1\" staging=\"$CITIZENAPP_WORK_DIR/ios.app.zip\" destination=\"$ARTIFACT_ROOT/ios.app.zip\"\n  rm -f \"$staging\"\n  ditto -c -k --norsrc --noextattr --keepParent \"$app_bundle\" \"$staging\"\n  mkdir -p \"$ARTIFACT_ROOT\"\n  # 同卷固定名称覆盖保证失败时不先删除上一次成功产物。\n  mv -f \"$staging\" \"$destination\"\n}\n\n# Android产品Build只提交已验真的无私钥候选；签名、安装和安装后回读\n# 继续由调用方的原生安全进程唯一负责。\nretain_android_local_artifact() {\n  local apk=\"$1\" staging=\"$CITIZENAPP_WORK_DIR/android.apk.pending\" destination=\"$ARTIFACT_ROOT/android.apk\"\n  rm -f \"$staging\"\n  cp \"$apk\" \"$staging\"\n  chmod 600 \"$staging\"\n  mkdir -p \"$ARTIFACT_ROOT\"\n  # 同卷固定名称覆盖，安全进程只会看到完整普通文件。\n  mv -f \"$staging\" \"$destination\"\n}\n\n# 系统权限弹窗由操作系统渲染；App 唯一能提供的是最终包内的受支持语言和本地化产品名。\n# 只检查源码会漏掉 Xcode variant group 未入 Resources 等问题，Build必须回读最终包。\nverify_ios_release_localization() {\n  local app_bundle=\"$1\" info=\"$1/Info.plist\"\n  local zh_strings=\"$1/zh-Hans.lproj/InfoPlist.strings\"\n  local en_strings=\"$1/en.lproj/InfoPlist.strings\"\n  [[ -f \"$info\" && -f \"$zh_strings\" && -f \"$en_strings\" ]] || {\n    echo \"iOS Release 缺少 Info.plist 或中英文本地化资源：$app_bundle\" >&2\n    return 1\n  }\n  [[ \"$(plutil -extract CFBundleDevelopmentRegion raw -o - \"$info\")\" == zh-Hans ]] || {\n    echo 'iOS Release 默认回落语言必须是 zh-Hans' >&2\n    return 1\n  }\n  plutil -extract CFBundleLocalizations json -o - \"$info\" | python3 -c '\nimport json, sys\nif json.load(sys.stdin) != [\"zh-Hans\", \"en\"]:\n    raise SystemExit(\"iOS Release 支持语言必须严格为 zh-Hans、en\")\n'\n  [[ \"$(plutil -extract CFBundleDisplayName raw -o - \"$zh_strings\")\" == 公民 \\\n    && \"$(plutil -extract CFBundleName raw -o - \"$zh_strings\")\" == 公民 ]] || {\n    echo 'iOS Release 中文产品名必须是“公民”' >&2\n    return 1\n  }\n  [[ \"$(plutil -extract CFBundleDisplayName raw -o - \"$en_strings\")\" == CitizenApp \\\n    && \"$(plutil -extract CFBundleName raw -o - \"$en_strings\")\" == CitizenApp ]] || {\n    echo 'iOS Release 英文产品名必须是 CitizenApp' >&2\n    return 1\n  }\n  echo '    iOS Release 本地化通过：中文=公民，英文=CitizenApp，默认回落=zh-Hans'\n}\n\n# Android 权限正文由系统按手机语言渲染；这里锁定最终 APK 的默认中文和英文限定应用名。\nverify_android_release_localization() {\n  local apk=\"$1\" aapt_bin sdk_home\n  [[ -f \"$apk\" ]] || { echo \"Android Release APK 不存在：$apk\" >&2; return 1; }\n  aapt_bin=\"$(command -v aapt2 || true)\"\n  if [[ -z \"$aapt_bin\" ]]; then\n    # 产品只读取公开工具链环境，不依赖启动它的桌面进程恰好继承ANDROID_HOME。\n    # 与原生库构建保持同一确定性规则：显式 SDK 优先，macOS 默认\n    # SDK 目录兜底，再从已安装 build-tools 中选择最高版本，禁止硬编码具体版本。\n    sdk_home=\"${ANDROID_HOME:-$HOME/Library/Android/sdk}\"\n    aapt_bin=\"$(find \"$sdk_home/build-tools\" -type f -name aapt2 -print 2>/dev/null | sort -V | tail -n 1)\"\n  fi\n  [[ -x \"$aapt_bin\" ]] || { echo '找不到 Android SDK aapt2，无法核验 APK 本地化' >&2; return 1; }\n  \"$aapt_bin\" dump resources \"$apk\" | python3 -c '\nimport re, sys\ntext = sys.stdin.read()\nmatch = re.search(r\"resource 0x[0-9a-f]+ string/app_name\\n(?P<body>(?:      .*\\n)+?)    resource \", text)\nif match is None:\n    raise SystemExit(\"Android Release APK 缺少 string/app_name\")\nbody = match.group(\"body\")\nif \"() \\\"公民\\\"\" not in body or \"(en) \\\"CitizenApp\\\"\" not in body:\n    raise SystemExit(\"Android Release APK 的默认中文或英文应用名不正确\")\n'\n  echo '    Android Release 本地化通过：默认=公民，英文=CitizenApp'\n}\n\nif [[ \"$PLATFORM\" == verify-ios-localization ]]; then\n  verify_ios_release_localization \"${2:?缺少 Runner.app 路径}\"\n  exit 0\nfi\nif [[ \"$PLATFORM\" == verify-android-localization ]]; then\n  verify_android_release_localization \"${2:?缺少 APK 路径}\"\n  exit 0\nfi\n\n\n# 构造 dart-define 参数\nDART_DEFINES=()\necho \"[Build模式] CitizenSDK · 目标平台 $PLATFORM\"\n\n# Flutter只负责在当前缓存根生成产品自己的Android配置和插件清单；真正的Gradle\n# 从产品真实android目录启动，所有可写状态仍由既有环境变量指向本任务缓存。\nbuild_android_release() {\n  local properties flutter_command flutter_sdk android_sdk product_version version_name version_code\n  local flutter_version dart_defines link_target java_home\n  properties=\"$CITIZENAPP_PROJECT_ROOT/android/local.properties\"\n  flutter_sdk=\"${FLUTTER_ROOT:-}\"\n  if [[ -z \"$flutter_sdk\" ]]; then\n    flutter_command=\"$(command -v flutter)\"\n    while [[ -L \"$flutter_command\" ]]; do\n      link_target=\"$(readlink \"$flutter_command\")\"\n      [[ \"$link_target\" == /* ]] || link_target=\"$(cd \"$(dirname \"$flutter_command\")\" && pwd -P)/$link_target\"\n      flutter_command=\"$link_target\"\n    done\n    flutter_sdk=\"$(cd \"$(dirname \"$flutter_command\")/..\" && pwd -P)\"\n  fi\n  [[ \"$flutter_sdk\" == /* && -x \"$flutter_sdk/bin/flutter\" \\\n      && -f \"$flutter_sdk/packages/flutter_tools/gradle/build.gradle.kts\" ]] \\\n    || { echo 'CitizenApp Flutter SDK根目录无效' >&2; exit 1; }\n  android_sdk=\"$ANDROID_SDK_HOME\"\n  # JDK与Android SDK由CitizenApp产品入口传给同一次Gradle调用；不在Worker增加前置检查。\n  java_home=\"$ANDROID_JAVA_HOME\"\n  product_version=\"$(sed -n 's/^version:[[:space:]]*//p' \"$CITIZENAPP_PROJECT_ROOT/pubspec.yaml\" | head -n 1)\"\n  version_name=\"${CITIZENAPP_BUILD_VERSION:?缺少本平台编译版本}\"\n  version_code=\"${product_version##*+}\"\n  if [[ \"${CITIZENAPP_CI_BUILD:-false}\" == true ]]; then version_code=\"${CITIZENAPP_CI_BUILD_NUMBER:?}\"; fi\n  printf 'sdk.dir=%s\\nflutter.sdk=%s\\nflutter.buildMode=release\\nflutter.versionName=%s\\nflutter.versionCode=%s\\n' \\\n    \"$android_sdk\" \"$flutter_sdk\" \"$version_name\" \"$version_code\" >\"$properties\"\n  flutter_version=\"$(flutter --version --machine)\"\n  dart_defines=\"$(printf '%s' \"$flutter_version\" | python3 -c '\nimport base64, json, sys\nvalue = json.load(sys.stdin)\nfields = (\n    (\"FLUTTER_VERSION\", \"frameworkVersion\"),\n    (\"FLUTTER_CHANNEL\", \"channel\"),\n    (\"FLUTTER_GIT_URL\", \"repositoryUrl\"),\n    (\"FLUTTER_FRAMEWORK_REVISION\", \"frameworkRevision\"),\n    (\"FLUTTER_ENGINE_REVISION\", \"engineRevision\"),\n    (\"FLUTTER_DART_VERSION\", \"dartSdkVersion\"),\n)\nprint(\",\".join(base64.b64encode(f\"{name}={value[key]}\".encode()).decode() for name, key in fields))\n')\"\n  (\n    cd \"$CITIZENAPP_PROJECT_ROOT/android\"\n    # Flutter Gradle included-build 的 Kotlin 会默认在工具源码根写 .kotlin/sessions；\n    # 显式定位到本轮工作目录，共享 Flutter 工具原件始终保持只读。\n    ANDROID_HOME=\"$android_sdk\" ANDROID_SDK_ROOT=\"$android_sdk\" JAVA_HOME=\"$java_home\" PATH=\"$java_home/bin:$PATH\" \\\n    CITIZENAPP_FLUTTER_GRADLE_ROOT=\"$flutter_sdk/packages/flutter_tools/gradle\" \\\n    FLUTTER_ROOT=\"$flutter_sdk\" \"$GRADLE_EXECUTABLE\" ${gradle_network_arg:+\"$gradle_network_arg\"} --no-daemon --stacktrace --no-problems-report \\\n      --init-script \"$CITIZENAPP_GRADLE_INIT_SCRIPT\" \\\n      --project-cache-dir \"$BUILD_WORK_DIR/gradle-project\" \\\n      -Pkotlin.project.persistent.dir=\"$CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR/kotlin-project\" \\\n      -Pflutter.sdk=\"$flutter_sdk\" \\\n      -Ptarget-platform=android-arm64 \\\n      -Ptarget=lib/main.dart \\\n      -Pbase-application-name=android.app.Application \\\n      -Pdart-defines=\"$dart_defines\" \\\n      -Pdart-obfuscation=false \\\n      -Ptrack-widget-creation=true \\\n      -Ptree-shake-icons=true \\\n      assembleRelease\n  )\n}\n\n# 这里曾有一句 `pkill -9 -f flutter_tools.snapshot`，用途是清掉上一轮残留的 flutter。\n# 已删除：`-f` 匹配全命令行，而 `flutter_tools.snapshot` 是每一个 flutter 命令的实际执行体，\n# 那一枪不区分产品、不区分平台、也不区分是不是本次运行的——公民钱包正在跑的编译、\n# 乃至你自己在终端里手敲的 flutter，都会一起被 SIGKILL（现象是 `Killed: 9`）。\n# 产品脚本不终止任何既有Flutter进程；进程生命周期由当前调用方管理。\n\n# 本机开发场景直接调用CitizenSDK唯一产品入口生成原生产物；CitizenApp只把SDK产物\n# 目录交给Flutter插件，不复制、不修改也不实现第二份链库。\nCITIZENSDK_DEPENDENCY_WORK_DIR=\"${CITIZENAPP_SDK_DEPENDENCY_WORK_DIR:-$DEPENDENCY_WORK_DIR/citizensdk-native}\"\n[[ \"$CITIZENSDK_DEPENDENCY_WORK_DIR\" == \"$DEPENDENCY_WORK_DIR\"/* ]] \\\n  || { echo 'CitizenSDK依赖目录必须属于CitizenApp依赖工作目录' >&2; exit 1; }\nCITIZENSDK_PRODUCT_WORK_DIR=\"$BUILD_WORK_DIR/citizensdk-work\"\nCITIZENSDK_PRODUCT_OUTPUT_DIR=\"$BUILD_WORK_DIR/citizensdk-output\"\n# SDK原生编译复用本平台受控工作目录；本轮产物仍由SDK公开入口重新核验。\nnode \"$CITIZENSDK_ROOT/scripts/build.mjs\" prepare-environment \\\n  --scope citizensdk --platform \"$([[ \"$PLATFORM\" == ios ]] && printf macOS || printf Android)\" \\\n  --work \"$CITIZENSDK_DEPENDENCY_WORK_DIR\"\nexport CITIZENSDK_ZXING_SOURCE_DIR=\"$CITIZENSDK_DEPENDENCY_WORK_DIR/zxing-cpp-3.1.1\"\nif [[ \"${CITIZENAPP_OFFLINE:-false}\" == true ]]; then\n  export CARGO_HOME=\"$CITIZENAPP_SDK_CARGO_HOME\"\nfi\nif [[ \"$PLATFORM\" == ios ]]; then\n  CITIZENSDK_WORK_DIR=\"$CITIZENSDK_PRODUCT_WORK_DIR\" \\\n    CITIZENSDK_NATIVE_OUTPUT_DIR=\"$CITIZENSDK_PRODUCT_OUTPUT_DIR\" \\\n    node \"$CITIZENSDK_ROOT/scripts/build.mjs\" native apple\n  node \"$VIEW_SCRIPT\" view project-framework \\\n    --source-root \"$APP_ROOT\" --project-root \"$CITIZENAPP_PROJECT_ROOT\" \\\n    --work-root \"$CITIZENAPP_WORK_DIR\" --package-root \"$CITIZENSDK_ROOT\" \\\n    --package-subpath darwin/CitizenSDK.xcframework \\\n    --framework \"$CITIZENSDK_PRODUCT_OUTPUT_DIR/apple/CitizenSDK.xcframework\" >/dev/null\nelse\n  CITIZENSDK_WORK_DIR=\"$CITIZENSDK_PRODUCT_WORK_DIR\" \\\n    CITIZENSDK_NATIVE_OUTPUT_DIR=\"$CITIZENSDK_PRODUCT_OUTPUT_DIR\" \\\n    CITIZENSDK_GRADLE=\"$GRADLE_EXECUTABLE\" \\\n    CITIZENSDK_OFFLINE=\"$CITIZENAPP_GRADLE_OFFLINE\" \\\n    JAVA_HOME=\"$ANDROID_JAVA_HOME\" PATH=\"$ANDROID_JAVA_HOME/bin:$PATH\" \\\n    ANDROID_HOME=\"$ANDROID_SDK_HOME\" ANDROID_SDK_ROOT=\"$ANDROID_SDK_HOME\" \\\n    node \"$CITIZENSDK_ROOT/scripts/build.mjs\" native android\n  export CITIZENSDK_ANDROID_CORE_DIR=\"$CITIZENSDK_PRODUCT_OUTPUT_DIR/android/arm64-v8a\"\nfi\n\n# TataChatSDK仍按聊天产品自有流程构建。\nif [[ \"${CITIZENAPP_OFFLINE:-false}\" == true ]]; then\n  export CARGO_HOME=\"$CITIZENAPP_CHAT_CARGO_HOME\"\nfi\nif [[ \"$PLATFORM\" == ios ]]; then\n  [[ -f \"$TATACHATSDK_ROOT/ios/tatachat_sdk.podspec\" ]] || {\n    echo 'CitizenApp 本端 TataChatSDK iOS 插件配置缺失' >&2\n    exit 1\n  }\n  TATACHATSDK_NATIVE_IOS_DIR=\"$CITIZENAPP_NATIVE_IOS_DIR\" \\\n    TATACHATSDK_WORK_DIR=\"$BUILD_WORK_DIR/tatachatsdk-work\" \\\n    node \"$TATACHATSDK_ROOT/scripts/build.mjs\" native-dependency \"$PLATFORM\"\n  node \"$VIEW_SCRIPT\" view project-framework \\\n    --source-root \"$APP_ROOT\" --project-root \"$CITIZENAPP_PROJECT_ROOT\" \\\n    --work-root \"$CITIZENAPP_WORK_DIR\" --package-root \"$TATACHATSDK_ROOT\" \\\n    --package-subpath ios/TataChatSDK.xcframework \\\n    --framework \"$CITIZENAPP_NATIVE_IOS_DIR/TataChatSDK.xcframework\" >/dev/null\nelse\n  TATACHATSDK_NATIVE_ANDROID_DIR=\"$CITIZENAPP_NATIVE_ANDROID_DIR\" \\\n    TATACHATSDK_WORK_DIR=\"$BUILD_WORK_DIR/tatachatsdk-work\" \\\n    node \"$TATACHATSDK_ROOT/scripts/build.mjs\" native-dependency \"$PLATFORM\"\nfi\n\necho \"==> 清理 ${PLATFORM} 平台构建产物...\"\nclean_platform_build_outputs\necho \"==> 按CitizenApp锁文件准备依赖...\"\nflutter pub get \"${PUB_GET_ARGS[@]}\"\n\n# Build不选择、不安装、不启动设备，只读取当前产品源码并生成产品产物。\n# `--release`只是本机优化配置，不表示或触发正式Release流程。\necho \"==> 编译本机优化安装包...\"\nif [[ \"$PLATFORM\" == ios ]]; then\n  if [[ \"${CITIZENAPP_CI_BUILD:-false}\" == true ]]; then\n    flutter build ios --no-pub --release --no-codesign --build-name=\"${CITIZENAPP_BUILD_VERSION:?}\" --build-number=\"${CITIZENAPP_CI_BUILD_NUMBER:?}\" ${DART_DEFINES[@]+\"${DART_DEFINES[@]}\"}\n  else\n    flutter build ios --no-pub --release --build-name=\"${CITIZENAPP_BUILD_VERSION:?}\" ${DART_DEFINES[@]+\"${DART_DEFINES[@]}\"}\n  fi\n  IOS_APP=\"$BUILD_DIR/ios/iphoneos/Runner.app\"\n  TATACHATSDK_WORK_DIR=\"$BUILD_WORK_DIR/tatachatsdk-work\" node \"$TATACHATSDK_ROOT/scripts/build.mjs\" native-dependency verify-ios-package \"$IOS_APP\"\n  verify_ios_release_localization \"$IOS_APP\"\n  retain_ios_local_artifact \"$IOS_APP\"\n  echo \"\"\n  echo \"==> Build完成：iOS产物已写入CitizenApp产物目录。\"\nelif [[ \"$PLATFORM\" == android ]]; then\n  ANDROID_APK=\"$BUILD_DIR/app/outputs/flutter-apk/app-release.apk\"\n  build_android_release\n  if [[ \"${CITIZENAPP_CI_BUILD:-false}\" == true ]]; then\n    flutter build appbundle --no-pub --release --build-name=\"${CITIZENAPP_BUILD_VERSION:?}\" --build-number=\"${CITIZENAPP_CI_BUILD_NUMBER:?}\"\n  fi\n  [[ -f \"$ANDROID_APK\" ]] || {\n    echo \"Android 本机无私钥 APK 不存在\" >&2\n    exit 1\n  }\n  TATACHATSDK_WORK_DIR=\"$BUILD_WORK_DIR/tatachatsdk-work\" node \"$TATACHATSDK_ROOT/scripts/build.mjs\" native-dependency verify-android-package \"$ANDROID_APK\"\n  verify_android_release_localization \"$ANDROID_APK\"\n  retain_android_local_artifact \"$ANDROID_APK\"\n  echo \"==> Android无私钥候选完成，正在交给原生安全进程完成Build签名。\"\nfi\n","test":"#!/usr/bin/env bash\n# CitizenApp 本机与 CI 唯一 Flutter 测试入口。\n#\n# CitizenApp SDK金标消费锁定CitizenSDK的真实产品Core；两份SDK宿主库\n# 由各自产品入口准备，Isar消费本轮锁定包的宿主库。\nset -euo pipefail\n\nSCRIPT_DIR=\"${CITIZENAPP_SCRIPTS_ROOT:?缺少源码脚本根}\"\nCITIZENAPP_DIR=\"${CITIZENAPP_SOURCE_ROOT:?缺少产品源码根}\"\nFLUTTER_BIN=\"${FLUTTER_BIN:-flutter}\"\nVIEW_SCRIPT=\"$SCRIPT_DIR/build.mjs\"\nFLUTTER_ROOT=''\nANALYSIS_CONFIG=''\nTEST_CONFIG=''\nTEST_CONFIGS_STAGED=false\nCITIZENAPP_TEST_WORK_DIR=\"${CITIZENAPP_TEST_WORK_DIR:-$CITIZENAPP_DIR/target/test}\"\nBUILD_CACHE=\"${CITIZENAPP_TEST_BUILD_DIR:-$CITIZENAPP_TEST_WORK_DIR/work}\"\nDEPENDENCY_CACHE=\"${CITIZENAPP_TEST_DEPENDENCY_DIR:-$CITIZENAPP_TEST_WORK_DIR/dependencies}\"\npython3 - \"$CITIZENAPP_DIR\" \"$CITIZENAPP_TEST_WORK_DIR\" \"$BUILD_CACHE\" \"$DEPENDENCY_CACHE\" <<'CHECK_OUTPUTS'\nfrom pathlib import Path\nimport sys\nsource = Path(sys.argv[1]).resolve()\nfor value in sys.argv[2:]:\n    raw = Path(value)\n    target = raw.resolve()\n    if not raw.is_absolute() or source / 'target' not in target.parents:\n        raise SystemExit(f'CitizenApp测试目录必须是本仓target内绝对路径：{value}')\nCHECK_OUTPUTS\nmkdir -p \"$CITIZENAPP_TEST_WORK_DIR\"\nCITIZENCHAIN_ROOT=\"$(node \"$SCRIPT_DIR/build.mjs\" inputs \"$CITIZENAPP_TEST_WORK_DIR\")\"\nexport CITIZENCHAIN_ROOT\n# Flutter分析、测试、.dart_tool与build全部在源码外工程视图运行；源码文件保持\n# 唯一真源且只读投影，测试不得再向CitizenApp根生成build或临时配置。\nif [[ -n \"${CITIZENAPP_TEST_PROJECT_ROOT:-}\" ]]; then\n  FLUTTER_ROOT=\"$(node \"$VIEW_SCRIPT\" view verify \\\n    --source-root \"$CITIZENAPP_DIR\" --work-root \"$CITIZENAPP_TEST_WORK_DIR\")\"\n  [[ \"$FLUTTER_ROOT\" == \"$CITIZENAPP_TEST_PROJECT_ROOT\" ]] \\\n    || { echo '错误: CI测试视图与本轮工作根不一致' >&2; exit 1; }\nelse\n  FLUTTER_ROOT=\"$(node \"$VIEW_SCRIPT\" view create \\\n    --source-root \"$CITIZENAPP_DIR\" --work-root \"$CITIZENAPP_TEST_WORK_DIR\")\"\nfi\n[[ \"$FLUTTER_ROOT\" == \"$CITIZENAPP_TEST_WORK_DIR/source-view/\"* \\\n  && -f \"$FLUTTER_ROOT/pubspec.yaml\" ]] \\\n  || { echo '错误: CitizenApp测试工程视图无效' >&2; exit 1; }\nexport CARGO_TARGET_DIR=\"${CARGO_TARGET_DIR:-$BUILD_CACHE/cargo-tests}\"\nexport PUB_CACHE=\"${PUB_CACHE:-$DEPENDENCY_CACHE/dart-pub}\"\nexport XDG_CONFIG_HOME=\"${XDG_CONFIG_HOME:-$DEPENDENCY_CACHE/flutter-config}\"\nexport TMPDIR=\"$BUILD_CACHE/tmp\"\nmkdir -p \"$TMPDIR\"\nexport DYLD_LIBRARY_PATH=\"$CARGO_TARGET_DIR/release:$CARGO_TARGET_DIR/debug\"\nexport LD_LIBRARY_PATH=\"$CARGO_TARGET_DIR/release:$CARGO_TARGET_DIR/debug\"\n\nif ! command -v \"$FLUTTER_BIN\" >/dev/null 2>&1; then\n  echo \"错误: 找不到 Flutter: $FLUTTER_BIN\" >&2\n  exit 1\nfi\n\n# Flutter 版本由产品开发环境或 CI 工作流唯一确定；测试脚本只消费调用方\n# 注入的可执行文件，不维护第二份工具版本表。\n\nif [ ! -f \"$FLUTTER_ROOT/.dart_tool/package_config.json\" ]; then\n  if [[ \"${CI:-}\" == true ]]; then\n    echo \"错误: 缺少 .dart_tool/package_config.json；CI必须先执行锁定依赖解析\" >&2\n    exit 1\n  fi\n  PUB_GET_ARGS=(--enforce-lockfile)\n  case \"${CITIZENAPP_OFFLINE:-false}\" in\n    true) PUB_GET_ARGS+=(--offline) ;;\n    false) ;;\n    *) echo '错误: CITIZENAPP_OFFLINE只接受true或false' >&2; exit 1 ;;\n  esac\n  (cd \"$FLUTTER_ROOT\" && \"$FLUTTER_BIN\" pub get \"${PUB_GET_ARGS[@]}\")\nfi\n\n# 设备 Release 构建会先 cargo clean；测试必须从宿主库构建开始一直持锁到最后一个\n# flutter_tester 退出，禁止其它进程在测试中途删除 dylib/so。macOS 用系统 shlock\n# 自动识别死亡 PID，Linux CI 用 util-linux flock，二者都不依赖仓库内状态文件。\nNATIVE_BUILD_LOCK_PATH=\"$CITIZENAPP_TEST_WORK_DIR/citizenapp-native-build.lock\"\nNATIVE_BUILD_LOCK_KIND=\"\"\nacquire_native_build_lock() {\n  case \"$(uname -s)\" in\n    Darwin)\n      while ! shlock -f \"$NATIVE_BUILD_LOCK_PATH\" -p $$; do\n        echo \"等待 CitizenApp 设备原生构建结束...\"\n        sleep 1\n      done\n      NATIVE_BUILD_LOCK_KIND=shlock\n      ;;\n    Linux)\n      exec 9>\"$NATIVE_BUILD_LOCK_PATH\"\n      flock 9\n      NATIVE_BUILD_LOCK_KIND=flock\n      ;;\n    *)\n      echo \"错误: 不支持的原生测试锁平台：$(uname -s)\" >&2\n      return 1\n      ;;\n  esac\n}\nrelease_native_build_lock() {\n  case \"$NATIVE_BUILD_LOCK_KIND\" in\n    shlock)\n      if [[ \"$(cat \"$NATIVE_BUILD_LOCK_PATH\" 2>/dev/null || true)\" == \"$$\" ]]; then\n        rm -f -- \"$NATIVE_BUILD_LOCK_PATH\"\n      fi\n      ;;\n    flock)\n      flock -u 9\n      exec 9>&-\n      ;;\n  esac\n  NATIVE_BUILD_LOCK_KIND=\"\"\n}\n\ncleanup_test_configs() {\n  if [[ \"$TEST_CONFIGS_STAGED\" == true ]]; then\n    rm -f -- \"$ANALYSIS_CONFIG\" \"$TEST_CONFIG\"\n  fi\n  release_native_build_lock\n}\n\ncd \"$FLUTTER_ROOT\"\n# Flutter只从工程根发现这两类配置；源码真源统一放在scripts，执行期间只在本次\n# 源码外工程视图短暂落盘，退出时必定清理。\nANALYSIS_CONFIG=\"$FLUTTER_ROOT/analysis_options.yaml\"\nTEST_CONFIG=\"$FLUTTER_ROOT/dart_test.yaml\"\ntrap cleanup_test_configs EXIT\nif [[ ! -e \"$ANALYSIS_CONFIG\" && ! -L \"$ANALYSIS_CONFIG\"\n  && ! -e \"$TEST_CONFIG\" && ! -L \"$TEST_CONFIG\" ]]; then\n  TEST_CONFIGS_STAGED=true\n  node \"$SCRIPT_DIR/build.mjs\" config analysis > \"$ANALYSIS_CONFIG\"\n  node \"$SCRIPT_DIR/build.mjs\" config test > \"$TEST_CONFIG\"\nelif [[ \"$FLUTTER_ROOT\" == \"$CITIZENAPP_DIR\" || ! -f \"$ANALYSIS_CONFIG\" || -L \"$ANALYSIS_CONFIG\"\n  || ! -f \"$TEST_CONFIG\" || -L \"$TEST_CONFIG\" ]]; then\n  echo '错误: Flutter 工程根存在不受CitizenApp测试入口管理的分析或测试配置' >&2\n  exit 1\nfi\n# CI Runner 保持原生构建锁；本机测试使用独立工作目录，不使用跨端共享锁。\nif [[ \"${CI:-}\" == true ]]; then\n  acquire_native_build_lock\nfi\n# 宿主库只从产品声明与锁定Git输入取得，不编译邻仓或旧聚合仓源码。\nDEPENDENCIES=\"$(node \"$VIEW_SCRIPT\" view dependencies \\\n  --source-root \"$CITIZENAPP_DIR\" --work-root \"$CITIZENAPP_TEST_WORK_DIR\")\"\nTATACHATSDK_ROOT=\"$(printf '%s' \"$DEPENDENCIES\" | node --input-type=module -e 'let text=\"\"; for await (const part of process.stdin) text+=part; const root=JSON.parse(text).tatachat_sdk?.root; if(typeof root!==\"string\") throw Error(\"聊天SDK源码回执缺失\"); process.stdout.write(root);')\"\nCITIZENSDK_ROOT=\"$(printf '%s' \"$DEPENDENCIES\" | node --input-type=module -e 'let text=\"\"; for await (const part of process.stdin) text+=part; const root=JSON.parse(text).citizen_sdk?.root; if(typeof root!==\"string\") throw Error(\"公民SDK源码回执缺失\"); process.stdout.write(root);')\"\nfor sdk_root in \"$TATACHATSDK_ROOT\" \"$CITIZENSDK_ROOT\"; do\n  [[ -f \"$sdk_root/scripts/build.mjs\" && ! -L \"$sdk_root/scripts/build.mjs\" ]] \\\n    || { echo '锁定SDK原生入口无效' >&2; exit 1; }\ndone\n# SDK公开host交付绑定当前App任务，产物在测试结束前由App保有。\nexport PRODUCT_WORK_DIR=\"$CITIZENAPP_TEST_WORK_DIR\"\nexport TATACHATSDK_WORK_DIR=\"$CITIZENAPP_TEST_WORK_DIR/work/tatachatsdk-work\"\nexport TATACHATSDK_NATIVE_HOST_DIR=\"$CITIZENAPP_TEST_WORK_DIR/work/tatachatsdk-host\"\nexport CARGO_TARGET_DIR=\"$CITIZENAPP_TEST_WORK_DIR/work/tatachatsdk-work/cargo\"\nexport TATACHATSDK_TEST_WORK_ROOT=\"$CITIZENAPP_TEST_WORK_DIR\"\nnode \"$TATACHATSDK_ROOT/scripts/build.mjs\" native-dependency host\nexport TATACHATSDK_TEST_NATIVE_LIBRARY=\"$TATACHATSDK_NATIVE_HOST_DIR/libtatachat_sdk.dylib\"\nexport CITIZENSDK_WORK_DIR=\"$BUILD_CACHE/citizensdk-host/work\"\nexport CITIZENSDK_NATIVE_OUTPUT_DIR=\"$BUILD_CACHE/citizensdk-host/output\"\nnode \"$CITIZENSDK_ROOT/scripts/build.mjs\" native abi-host\nCITIZENSDK_TEST_CORE_LIB_PATH=\"$(node \"$SCRIPT_DIR/build.mjs\" native core \"$CITIZENSDK_NATIVE_OUTPUT_DIR\")\"\nISAR_CORE_LIB_PATH=\"$(node \"$SCRIPT_DIR/build.mjs\" native isar \"$FLUTTER_ROOT/.dart_tool/package_config.json\" \"$PUB_CACHE\" \"$CITIZENAPP_DIR/pubspec.lock\")\"\nexport CITIZENSDK_TEST_CORE_LIB_PATH ISAR_CORE_LIB_PATH\n\"$FLUTTER_BIN\" analyze --no-pub --fatal-infos --fatal-warnings\n\"$FLUTTER_BIN\" test --no-pub --concurrency=1 \"$@\"\n","ui-test":"#!/usr/bin/env bash\n# 对真机中已经安装的 CitizenApp Release 做长期黑盒 UI 验收。\n#\n# 安全边界：本脚本只构建和安装独立的 UITestHost/xctrunner，永远不构建、安装、卸载或\n# 清空 `ios.citizenapp`。测试前后会核对正式 App 的版本、bundle 容器、数据容器和全部 Isar\n# 数据库；既有数据库任一消失都拒绝把测试判为成功，正常运行新增数据库或扩大文件允许。\nset -euo pipefail\n\nSCRIPT_DIR=\"${CITIZENAPP_SCRIPTS_ROOT:?缺少源码脚本根}\"\nAPP_ROOT=\"${CITIZENAPP_SOURCE_ROOT:?缺少产品源码根}\"\nSCHEME=\"RunnerUITests\"\nTARGET_BUNDLE_ID=\"ios.citizenapp\"\nTEST_HOST_BUNDLE_ID=\"ios.citizenapp.UITestHost\"\nTEST_RUNNER_BUNDLE_ID=\"ios.citizenapp.UITests.xctrunner\"\nBUILD_ROOT=\"${CITIZENAPP_UI_TEST_WORK_DIR:-$APP_ROOT/target/test/ui}\"\nPROJECT_INPUT=\"$APP_ROOT/ios/project/Runner.pbxproj\"\nDERIVED_DATA=\"$BUILD_ROOT/DerivedData\"\nTEST_ONLY=\"${CITIZENAPP_UI_TEST_ONLY:-}\"\nif [[ -n \"$TEST_ONLY\" && ! \"$TEST_ONLY\" =~ ^testChatE2E(ReadIdentity|Send|VerifyRestart)$ ]]; then\n  echo 'CITIZENAPP_UI_TEST_ONLY 只能选择已登记的双机 XCTest' >&2\n  exit 1\nfi\nRESULT_BUNDLE=\"$BUILD_ROOT/RunnerUITests-${TEST_ONLY:-all}-$(date +%s)-$$.xcresult\"\n\npython3 - \"$APP_ROOT\" \"$BUILD_ROOT\" <<'CHECK_OUTPUTS'\nfrom pathlib import Path\nimport sys\nsource, raw = map(Path, sys.argv[1:])\nsource, target = source.resolve(), raw.resolve()\nif not raw.is_absolute() or source / 'target' not in target.parents:\n    raise SystemExit('CITIZENAPP_UI_TEST_WORK_DIR必须是CitizenApp本仓target内绝对路径')\nCHECK_OUTPUTS\n\n[[ -f \"$PROJECT_INPUT\" && ! -L \"$PROJECT_INPUT\" ]] || {\n  echo \"CitizenApp iOS 工程不存在：$PROJECT_INPUT\" >&2; exit 1\n}\nmkdir -p \"$BUILD_ROOT\"\n# XCTest 通过同一源码外视图消费扁平 scheme，正式 App 本体不参与构建。\nBUILD_ROOT=\"$(cd \"$BUILD_ROOT\" && pwd -P)\"\nPROJECT_ROOT=\"$(node \"$SCRIPT_DIR/build.mjs\" view create --source-root \"$APP_ROOT\" --work-root \"$BUILD_ROOT\")\"\nPROJECT=\"$PROJECT_ROOT/ios/Runner.xcodeproj\"\nexport TMPDIR=\"$BUILD_ROOT/\"\n\ndevice_fields=\"$(python3 - <<'SELECT_DEVICE'\nimport json\nimport subprocess\nimport time\n\nDEVICECTL = [\"/usr/bin/xcrun\", \"devicectl\"]\nATTEMPTS = 8\n\n\ndef developer_mode_enabled(value):\n    if value == \"enabled\":\n        return True\n    if not isinstance(value, dict):\n        return False\n    enabled = value.get(\"enabled\")\n    return isinstance(enabled, dict) and enabled.get(\"mode\") == 1\n\n\ndef command_json(arguments, timeout):\n    try:\n        result = subprocess.run(\n            DEVICECTL + arguments + [\"--quiet\", \"--json-output\", \"-\"],\n            stdout=subprocess.PIPE,\n            stderr=subprocess.DEVNULL,\n            text=True,\n            timeout=timeout,\n            check=False,\n        )\n        if result.returncode != 0:\n            return None\n        value = json.loads(result.stdout)\n        if value.get(\"info\", {}).get(\"outcome\") != \"success\":\n            return None\n        return value\n    except (json.JSONDecodeError, subprocess.TimeoutExpired):\n        return None\n\n\nfor attempt in range(ATTEMPTS):\n    listing = command_json([\"list\", \"devices\"], timeout=15)\n    candidates = []\n    if listing is not None:\n        for item in listing.get(\"result\", {}).get(\"devices\", []):\n            props = item.get(\"properties\", {})\n            hardware = props.get(\"hardware\", {})\n            connection = props.get(\"connection\", {})\n            state = props.get(\"state\", {})\n            identifier = item.get(\"identifier\")\n            udid = hardware.get(\"udid\")\n            if (\n                identifier\n                and udid\n                and hardware.get(\"platform\") == \"iOS\"\n                and hardware.get(\"reality\") == \"physical\"\n                and connection.get(\"pairingState\") == \"paired\"\n                and developer_mode_enabled(state.get(\"developerModeStatus\"))\n            ):\n                candidates.append((identifier, udid))\n\n    reachable = []\n    for identifier, udid in candidates:\n        details = command_json(\n            [\"device\", \"info\", \"details\", \"--device\", identifier],\n            timeout=20,\n        )\n        if details is None:\n            continue\n        result = details.get(\"result\", {})\n        props = result.get(\"properties\", {})\n        hardware = props.get(\"hardware\", {})\n        connection = props.get(\"connection\", {})\n        state = props.get(\"state\", {})\n        if (\n            result.get(\"identifier\") == identifier\n            and hardware.get(\"udid\") == udid\n            and hardware.get(\"platform\") == \"iOS\"\n            and hardware.get(\"reality\") == \"physical\"\n            and connection.get(\"pairingState\") == \"paired\"\n            and state.get(\"bootState\") == \"booted\"\n            and developer_mode_enabled(state.get(\"developerModeStatus\"))\n        ):\n            reachable.append((identifier, udid))\n\n    if len(reachable) > 1:\n        raise SystemExit(\"必须且只能主动探测到一台可用物理 iPhone，当前多于一台\")\n    if len(reachable) == 1:\n        print(reachable[0][0])\n        print(reachable[0][1])\n        break\n    if attempt + 1 < ATTEMPTS:\n        time.sleep(2)\nelse:\n    raise SystemExit(\"主动探测未发现可用物理 iPhone（已配对、开发者模式开启且可读取设备详情）\")\nSELECT_DEVICE\n)\"\nCORE_DEVICE_ID=\"$(sed -n '1p' <<<\"$device_fields\")\"\nHARDWARE_UDID=\"$(sed -n '2p' <<<\"$device_fields\")\"\n[[ -n \"$CORE_DEVICE_ID\" && -n \"$HARDWARE_UDID\" ]] || {\n  echo \"无法解析 iPhone 标识，拒绝测试\" >&2\n  exit 1\n}\n\ninstalled_app_snapshot() {\n  xcrun devicectl device info apps --quiet \\\n    --device \"$CORE_DEVICE_ID\" \\\n    --bundle-id \"$TARGET_BUNDLE_ID\" \\\n    --include-container-paths \\\n    --json-output - |\n    python3 -c '\nimport json, sys\nbundle_id = sys.argv[1]\napps = json.load(sys.stdin).get(\"result\", {}).get(\"apps\", [])\nif len(apps) != 1:\n    raise SystemExit(f\"设备中必须且只能有一个 {bundle_id}，当前：{len(apps)}\")\napp = apps[0]\nif app.get(\"bundleIdentifier\") != bundle_id:\n    raise SystemExit(\"设备返回的 CitizenApp Bundle ID 不一致\")\nfields = {\n    \"bundleIdentifier\": app.get(\"bundleIdentifier\"),\n    \"version\": app.get(\"version\"),\n    \"shortVersion\": app.get(\"shortVersion\"),\n    \"bundleContainerPath\": app.get(\"bundleContainerPath\"),\n    \"dataContainerPath\": app.get(\"dataContainerPath\"),\n}\nif not fields[\"bundleContainerPath\"] or not fields[\"dataContainerPath\"]:\n    raise SystemExit(\"无法读取 CitizenApp 的 bundle/data 容器，拒绝测试\")\nprint(json.dumps(fields, ensure_ascii=False, sort_keys=True, separators=(\",\", \":\")))\n' \"$TARGET_BUNDLE_ID\"\n}\n\ndatabase_snapshot() {\n  xcrun devicectl device info files --quiet \\\n    --device \"$CORE_DEVICE_ID\" \\\n    --domain-type appDataContainer \\\n    --domain-identifier \"$TARGET_BUNDLE_ID\" \\\n    --subdirectory 'Library/Application Support' \\\n    --recurse \\\n    --json-output - |\n    python3 -c '\nimport json, sys\nfiles = json.load(sys.stdin).get(\"result\", {}).get(\"files\", [])\nsnapshot = {}\nfor item in files:\n    relative = item.get(\"relativePath\")\n    if not isinstance(relative, str) or not relative.endswith(\".isar\"):\n        continue\n    resources = item.get(\"resources\", {})\n    size = item.get(\"metadata\", {}).get(\"size\", 0)\n    if (\n        relative in snapshot\n        or resources.get(\"isDirectory\") is not False\n        or resources.get(\"isSymbolicLink\") is not False\n        or resources.get(\"isReadable\") is not True\n        or not isinstance(size, int)\n        or size <= 0\n    ):\n        raise SystemExit(\"CitizenApp Isar 数据库路径、类型或大小无效\")\n    snapshot[relative] = size\nprint(json.dumps(snapshot, ensure_ascii=False, sort_keys=True, separators=(\",\", \":\")))\n'\n}\n\nis_installed() {\n  xcrun devicectl device info apps --quiet \\\n    --device \"$CORE_DEVICE_ID\" --bundle-id \"$1\" --json-output - 2>/dev/null |\n    python3 -c 'import json, sys; print(\"yes\" if json.load(sys.stdin).get(\"result\", {}).get(\"apps\", []) else \"no\")' \\\n    2>/dev/null\n}\n\ncleanup_test_apps() {\n  local bundle_id\n  for bundle_id in \"$TEST_RUNNER_BUNDLE_ID\" \"$TEST_HOST_BUNDLE_ID\"; do\n    if [[ \"$(is_installed \"$bundle_id\" || true)\" == yes ]]; then\n      echo \"[清理] 仅删除隔离测试组件：$bundle_id\"\n      xcrun devicectl device uninstall app --quiet --device \"$CORE_DEVICE_ID\" \"$bundle_id\" || true\n    fi\n  done\n  # 仅卸载本脚本创建的设备测试组件；不触碰正式CitizenApp与其它工作目录。\n}\ntrap cleanup_test_apps EXIT\n\necho \"[设备] 已主动探测唯一物理 iPhone\"\nbefore_snapshot=\"$(installed_app_snapshot)\"\nbefore_databases=\"$(database_snapshot)\"\nbefore_database_count=\"$(python3 -c 'import json,sys; print(len(json.loads(sys.argv[1])))' \"$before_databases\")\"\necho \"[保护] 已确认现有 ${TARGET_BUNDLE_ID}，Isar数据库=${before_database_count}个\"\n\n# iPhone 镜像与 XCTest 都要独占设备图形会话；自动测试期间只关闭镜像窗口，不改变配对。\nosascript -e 'tell application \"iPhone Mirroring\" to quit' >/dev/null 2>&1 || true\n\ndestination=\"platform=iOS,id=$HARDWARE_UDID\"\necho \"[构建] Release 隔离 UI Test Host（不含 CitizenApp target）\"\nxcodebuild build-for-testing \\\n  -project \"$PROJECT\" \\\n  -scheme \"$SCHEME\" \\\n  -configuration Release \\\n  -destination \"$destination\" \\\n  -derivedDataPath \"$DERIVED_DATA\"\n\n# 构建后、执行前审计所有 App 产物。只要混入正式 Bundle ID，就在任何安装发生前停止。\nwhile IFS= read -r plist; do\n  product_bundle_id=\"$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \"$plist\" 2>/dev/null || true)\"\n  [[ \"$product_bundle_id\" != \"$TARGET_BUNDLE_ID\" ]] || {\n    echo \"UI 测试产物错误包含正式 CitizenApp，已在安装前停止：$plist\" >&2\n    exit 1\n  }\ndone < <(find \"$DERIVED_DATA/Build/Products\" -path '*.app/Info.plist' -type f -print)\n\necho \"[测试] 启动设备中现有 CitizenApp Release\"\nset +e\nif [[ -n \"$TEST_ONLY\" ]]; then\n  xcodebuild test-without-building \\\n    -project \"$PROJECT\" \\\n    -scheme \"$SCHEME\" \\\n    -configuration Release \\\n    -destination \"$destination\" \\\n    -derivedDataPath \"$DERIVED_DATA\" \\\n    -only-testing:\"$SCHEME/$SCHEME/$TEST_ONLY\" \\\n    -resultBundlePath \"$RESULT_BUNDLE\"\nelse\n  xcodebuild test-without-building \\\n    -project \"$PROJECT\" \\\n    -scheme \"$SCHEME\" \\\n    -configuration Release \\\n    -destination \"$destination\" \\\n    -derivedDataPath \"$DERIVED_DATA\" \\\n    -resultBundlePath \"$RESULT_BUNDLE\"\nfi\ntest_status=$?\nset -e\n\nafter_snapshot=\"$(installed_app_snapshot)\"\nafter_databases=\"$(database_snapshot)\"\n[[ \"$after_snapshot\" == \"$before_snapshot\" ]] || {\n  echo \"CitizenApp 安装信息或数据容器在 UI 测试后发生变化，拒绝通过\" >&2\n  exit 1\n}\ndatabase_counts=\"$(python3 - \"$before_databases\" \"$after_databases\" <<'CHECK_DATABASES'\nimport json\nimport sys\n\nbefore = json.loads(sys.argv[1])\nafter = json.loads(sys.argv[2])\nmissing = sorted(set(before) - set(after))\nif missing:\n    raise SystemExit(f\"CitizenApp UI测试删除了既有Isar数据库，数量：{len(missing)}\")\nprint(f\"{len(before)} → {len(after)}\")\nCHECK_DATABASES\n)\"\necho \"[保护] CitizenApp容器未变化，既有Isar数据库仍全部存在：${database_counts}个\"\n\nif [[ \"$test_status\" -ne 0 ]]; then\n  echo \"UI 测试失败；结果保存在：$RESULT_BUNDLE\" >&2\n  exit \"$test_status\"\nfi\necho \"[完成] CitizenApp iOS Release 真机 UI 测试通过\"\n","chat-test":"#!/usr/bin/env bash\n# 已安装的两台公民 App 真机黑盒验收：iPhone XCTest + Pixel ADB UI。\n# 不构建、不安装、不清空 App；身份及目标联系人不唯一时不发送。\nset -euo pipefail\n\nSCRIPT_DIR=\"${CITIZENAPP_SCRIPTS_ROOT:?缺少源码脚本根}\"\nAPP_ROOT=\"${CITIZENAPP_SOURCE_ROOT:?缺少产品源码根}\"\nIOS_TEST=\"$SCRIPT_DIR/build.mjs\"\nexport CITIZENAPP_UI_TEST_WORK_DIR=\"${CITIZENAPP_UI_TEST_WORK_DIR:-$APP_ROOT/target/test/chat-e2e}\"\n\npython3 - \"$IOS_TEST\" \"${CITIZENAPP_NODE_BIN:?缺少产品Node入口}\" <<'PY'\nimport os\nimport re\nimport subprocess\nimport sys\nimport time\nimport xml.etree.ElementTree as ET\n\nIOS_TEST = sys.argv[1]\nNODE_BIN = sys.argv[2]\nPACKAGE = 'com.crcfrcn.citizenapp'\nCID_PATTERN = re.compile(r'CN[0-9]{3}-CTZN[0-9]-[0-9]{9}-[0-9]{4}')\nMARKER = 'CITIZEN_E2E_%010d_%06d' % (int(time.time()), os.getpid() % 1000000)\n\n\ndef command(args, *, timeout=30, input_text=None):\n    result = subprocess.run(args, input=input_text, text=True, capture_output=True,\n                            timeout=timeout, check=False)\n    if result.returncode != 0:\n        raise RuntimeError('%s 失败：%s' % (args[0], result.stderr[-500:]))\n    return result.stdout\n\n\ndef ios(stage, *, peer=None):\n    env = os.environ.copy()\n    env['CITIZENAPP_UI_TEST_ONLY'] = stage\n    if peer is not None:\n        env['TEST_RUNNER_CHAT_E2E_PEER_CID'] = peer\n        env['TEST_RUNNER_CHAT_E2E_MARKER'] = MARKER\n    result = subprocess.run([NODE_BIN, IOS_TEST, \"ui-test\"], env=env, text=True, capture_output=True,\n                            timeout=1800, check=False)\n    if result.returncode != 0:\n        # 仅输出测试阶段与尾部诊断，避免把设备 UI 快照写入控制台。\n        lines = [line for line in (result.stdout + '\\n' + result.stderr).splitlines()\n                 if re.search(r'failed|error|cancel|认证|UI 测试失败', line, re.I)]\n        diagnostic = '\\n'.join(lines[-8:])\n        diagnostic = CID_PATTERN.sub('[公民号已隐藏]', diagnostic)\n        raise RuntimeError('iPhone XCTest %s 失败：%s' % (stage, diagnostic))\n    return result.stdout\n\n\ndef android_nodes():\n    for attempt in range(3):\n        try:\n            raw = command(['adb', 'exec-out', 'uiautomator', 'dump', '/dev/tty'], timeout=25)\n            break\n        except RuntimeError as error:\n            if 'no devices/emulators found' not in str(error) or attempt == 2:\n                raise\n            time.sleep(2)\n    start = raw.find('<?xml')\n    end = raw.rfind('</hierarchy>')\n    if start < 0 or end < 0:\n        raise RuntimeError('Pixel 无法读取当前界面层级')\n    root = ET.fromstring(raw[start:end + len('</hierarchy>')])\n    return list(root.iter('node'))\n\n\ndef node_label(node):\n    return (node.get('text') or '') + ' ' + (node.get('content-desc') or '')\n\n\ndef matching(text, *, exact=False):\n    return [node for node in android_nodes() if\n            (node_label(node).strip() == text if exact else text in node_label(node))]\n\n\ndef await_nodes(text, *, exact=False, timeout=60):\n    deadline = time.monotonic() + timeout\n    while time.monotonic() < deadline:\n        found = matching(text, exact=exact)\n        if found:\n            return found\n        time.sleep(2)\n    raise RuntimeError('Pixel 等待界面元素超时：%s' % text)\n\n\ndef tap_node(node):\n    match = re.fullmatch(r'\\[(\\d+),(\\d+)\\]\\[(\\d+),(\\d+)\\]', node.get('bounds', ''))\n    if not match:\n        raise RuntimeError('Pixel 界面目标没有有效边界')\n    left, top, right, bottom = map(int, match.groups())\n    if right <= left or bottom <= top:\n        raise RuntimeError('Pixel 界面目标边界无效')\n    command(['adb', 'shell', 'input', 'tap', str((left + right) // 2),\n             str((top + bottom) // 2)])\n\n\ndef tap_unique(text, *, exact=False, timeout=30):\n    found = await_nodes(text, exact=exact, timeout=timeout)\n    if len(found) != 1:\n        raise RuntimeError('Pixel 界面目标不唯一：%s' % text)\n    tap_node(found[0])\n\n\ndef start_android():\n    command(['adb', 'shell', 'am', 'force-stop', PACKAGE])\n    command(['adb', 'shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity'])\n    await_nodes('聊天', timeout=45)\n\n\ndef android_identity():\n    start_android()\n    tap_unique('我的')\n    tap_unique('注册与查看')\n    await_nodes('公民号', timeout=30)\n    values = sorted(set(match.group(0) for node in android_nodes()\n                        for match in CID_PATTERN.finditer(node_label(node))))\n    if len(values) != 1:\n        raise RuntimeError('Pixel 本机公民号无法唯一读取')\n    command(['adb', 'shell', 'input', 'keyevent', '4'])\n    return values[0]\n\n\ndef open_android_peer(peer):\n    tap_unique('聊天')\n    tap_unique('新建')\n    tap_unique('发私信', exact=True)\n    await_nodes('选择联系人', timeout=30)\n    tap_unique('公民号：' + peer, exact=True, timeout=30)\n    await_nodes('输入消息', timeout=30)\n\n\ndef android_send_text(value):\n    if not re.fullmatch(r'[A-Z0-9_]+', value):\n        raise RuntimeError('Pixel 测试文字必须是无空格 ASCII 标记')\n    tap_unique('输入消息')\n    command(['adb', 'shell', 'input', 'text', value])\n    command(['adb', 'shell', 'input', 'keyevent', '66'])\n    await_nodes(value, exact=True, timeout=25)\n\n\ndef android_send_sticker():\n    tap_unique('表情和贴纸')\n    tap_unique('贴纸', exact=True)\n    nodes = android_nodes()\n    tabs = [node for node in nodes if node.get('text') == '贴纸']\n    if len(tabs) != 1:\n        raise RuntimeError('Pixel 贴纸面板未打开')\n    # SDK 固定五列网格；点击第一枚贴纸，不依赖图像资产的本地化名称。\n    bounds = re.fullmatch(r'\\[(\\d+),(\\d+)\\]\\[(\\d+),(\\d+)\\]', tabs[0].get('bounds', ''))\n    if not bounds:\n        raise RuntimeError('Pixel 贴纸面板边界无效')\n    left, _, right, bottom = map(int, bounds.groups())\n    command(['adb', 'shell', 'input', 'tap', str(left + max(24, (right-left)//10)),\n             str(bottom + 42)])\n    await_nodes('[贴纸]', timeout=30)\n\n\ndef verify_android_after_restart():\n    start_android()\n    open_android_peer(iphone_cid)\n    for value in [MARKER, 'PIXEL_' + MARKER, 'AFTER_RESTART_' + MARKER]:\n        matches = await_nodes(value, exact=True, timeout=60)\n        if len(matches) != 1:\n            raise RuntimeError('Pixel 重启后消息重复或缺失')\n\n\ndevices = command(['adb', 'devices', '-l'])\nif len(re.findall(r'^\\S+\\s+device\\b', devices, re.MULTILINE)) != 1 or 'Pixel_8a' not in devices:\n    raise RuntimeError('必须且只能连接一台 Pixel 8a')\n\niphone_output = ios('testChatE2EReadIdentity')\ncid_matches = re.findall(r'CHAT_E2E_IPHONE_CID=(CN[0-9]{3}-CTZN[0-9]-[0-9]{9}-[0-9]{4})', iphone_output)\nif len(cid_matches) != 1:\n    raise RuntimeError('iPhone XCTest 没有唯一返回本机公民号')\niphone_cid = cid_matches[0]\npixel_cid = android_identity()\nif iphone_cid == pixel_cid:\n    raise RuntimeError('双机必须是不同公民号')\nprint('[身份] 两台不同公民号已由界面读取；不输出实际号码', flush=True)\n\n# 双向通讯录必须各自准确包含对方。匹配失败时不得发送消息。\nopen_android_peer(iphone_cid)\nprint('[前置] Pixel 已打开准确对端私聊', flush=True)\nios('testChatE2ESend', peer=pixel_cid)\nprint('[发送] iPhone 文字与 emoji 已进入真实会话', flush=True)\nawait_nodes(MARKER, exact=True, timeout=90)\nawait_nodes('😀' + MARKER, exact=True, timeout=90)\nandroid_send_text('PIXEL_' + MARKER)\nandroid_send_sticker()\nprint('[回信] Pixel 文字与贴纸已提交', flush=True)\nios('testChatE2EVerifyRestart', peer=pixel_cid)\nverify_android_after_restart()\nprint('[完成] 双机收发、重启与去重全部通过', flush=True)\nPY\n"});
export const CI_SIGNING_STEPS=Object.freeze({"android":"set -euo pipefail\numask 077\nwork=\"$CITIZENAPP_BUILD_TEMP/citizenapp-android-signing\"\npublish=\"build/release\"\nrm -rf \"$work\" \"$publish\"\nmkdir -p \"$work\" \"$publish\"\ntrap 'rm -rf \"$work\"' EXIT\npython3 - \"$work\" <<'PY'\nimport base64, os, pathlib, re, sys\nroot = pathlib.Path(sys.argv[1])\nfields = {}\nfor raw in os.environ.get(\"APP_KEY\", \"\").splitlines():\n    line = raw.strip()\n    if not line or line.startswith(\"#\"):\n        continue\n    name, sep, value = line.partition(\"=\")\n    if not sep or name.strip() in fields or not value.strip():\n        raise SystemExit(\"APP_KEY 行格式无效\")\n    fields[name.strip()] = value.strip()\nif set(fields) - {\"keystore\", \"password\", \"alias\", \"keyPassword\"}:\n    raise SystemExit(\"APP_KEY 包含未登记字段\")\nalias = fields.get(\"alias\", \"upload\")\nif not re.fullmatch(r\"[A-Za-z0-9._-]{1,128}\", alias):\n    raise SystemExit(\"APP_KEY alias 无效\")\ntry:\n    key = base64.b64decode(fields[\"keystore\"], validate=True)\n    password = fields[\"password\"]\nexcept (KeyError, ValueError) as exc:\n    raise SystemExit(\"APP_KEY 缺少有效签名材料\") from exc\nif not 1024 <= len(key) <= 32 * 1024 * 1024:\n    raise SystemExit(\"APP_KEY keystore 大小无效\")\n(root / \"release.keystore\").write_bytes(key)\n(root / \"password\").write_text(password)\n(root / \"key-password\").write_text(fields.get(\"keyPassword\", password))\n(root / \"alias\").write_text(alias)\nPY\nstore_password=\"$(cat \"$work/password\")\"\nkey_password=\"$(cat \"$work/key-password\")\"\nalias=\"$(cat \"$work/alias\")\"\nexport GMB_ANDROID_STORE_PASSWORD=\"$store_password\"\nexport GMB_ANDROID_KEY_PASSWORD=\"$key_password\"\napksigner=\"$ANDROID_HOME/build-tools/36.0.0/apksigner\"\ntest -x \"$apksigner\"\n\"$apksigner\" sign --ks \"$work/release.keystore\" \\\n  --ks-pass env:GMB_ANDROID_STORE_PASSWORD --key-pass env:GMB_ANDROID_KEY_PASSWORD \\\n  --v4-signing-enabled false \\\n  --ks-key-alias \"$alias\" --out \"$publish/citizenapp.apk\" \\\n  build/app/outputs/flutter-apk/app-release.apk\ncp build/app/outputs/bundle/release/app-release.aab \"$publish/citizenapp.aab\"\njarsigner -keystore \"$work/release.keystore\" \\\n  -storepass:env GMB_ANDROID_STORE_PASSWORD -keypass:env GMB_ANDROID_KEY_PASSWORD \\\n  \"$publish/citizenapp.aab\" \"$alias\"\n\"$apksigner\" verify --verbose --print-certs \"$publish/citizenapp.apk\" \\\n  | tee \"$work/apk-verification.txt\"\ngrep -F 'Verified using v2 scheme (APK Signature Scheme v2): true' \"$work/apk-verification.txt\"\n# Android 上传证书按平台规范可以自签名；只验证包完整性，再从三处回读同一证书。\njarsigner -verify \"$publish/citizenapp.aab\"\napk_certificate_sha256=\"$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' \"$work/apk-verification.txt\")\"\nkey_certificate_sha256=\"$(keytool -exportcert -alias \"$alias\" \\\n  -keystore \"$work/release.keystore\" -storepass:env GMB_ANDROID_STORE_PASSWORD -rfc \\\n  | openssl x509 -outform DER | shasum -a 256 | awk '{print $1}')\"\naab_certificate_sha256=\"$(keytool -printcert -jarfile \"$publish/citizenapp.aab\" -rfc \\\n  | openssl x509 -outform DER | shasum -a 256 | awk '{print $1}')\"\n[[ \"$apk_certificate_sha256\" =~ ^[0-9a-f]{64}$ ]]\ntest \"$apk_certificate_sha256\" = \"$key_certificate_sha256\"\ntest \"$apk_certificate_sha256\" = \"$aab_certificate_sha256\"\ntest \"$(apkanalyzer manifest application-id \"$publish/citizenapp.apk\")\" = com.crcfrcn.citizenapp\ntest \"$(apkanalyzer manifest version-code \"$publish/citizenapp.apk\")\" = \"$CITIZENAPP_BUILD_NUMBER\"\ntest \"$(apkanalyzer manifest version-name \"$publish/citizenapp.apk\")\" = \"$CITIZENAPP_BUILD_VERSION\"","ios":"set -euo pipefail\numask 077\nwork=\"$CITIZENAPP_BUILD_TEMP/citizenapp-ios-signing\"\npublish=\"$CITIZENAPP_RELEASE_ROOT\"\nrm -rf \"$work\" \"$publish\"\nmkdir -p \"$work\" \"$publish\"\nkeychain=\"$work/release.keychain-db\"\nkeychain_password=\"$(openssl rand -hex 32)\"\n# 本机钥匙串搜索列表属共享用户状态；先保存，结束时恢复。\noriginal_keychains=()\nwhile IFS= read -r line; do\n  [[ \"$line\" =~ ^[[:space:]]*\\\"([^\\\"]+)\\\"$ ]] || exit 1\n  original_keychains+=(\"${BASH_REMATCH[1]}\")\ndone < <(security list-keychains -d user)\n(( ${#original_keychains[@]} > 0 )) || exit 1\ncleanup() {\n  security list-keychains -d user -s \"${original_keychains[@]}\" >/dev/null 2>&1 || true\n  security delete-keychain \"$keychain\" >/dev/null 2>&1 || true\n  rm -rf \"$work\"\n}\ntrap cleanup EXIT\npython3 - \"$work\" <<'PY'\nimport base64, os, pathlib, re, sys\nroot = pathlib.Path(sys.argv[1])\nfields = {}\nfor raw in os.environ.get(\"IOS_KEY\", \"\").splitlines():\n    line = raw.strip()\n    if not line or line.startswith(\"#\"):\n        continue\n    name, sep, value = line.partition(\"=\")\n    if not sep or name.strip() in fields or not value.strip():\n        raise SystemExit(\"IOS_KEY 行格式无效\")\n    fields[name.strip()] = value.strip()\nif set(fields) != {\"pkcs12\", \"password\", \"certificate_sha1\"}:\n    raise SystemExit(\"IOS_KEY 字段集合无效\")\nif not re.fullmatch(r\"[0-9A-F]{40}\", fields[\"certificate_sha1\"]):\n    raise SystemExit(\"Apple Distribution 证书摘要无效\")\ntry:\n    pkcs12 = base64.b64decode(fields[\"pkcs12\"], validate=True)\n    profile = base64.b64decode(os.environ.get(\"IOS_PROVISIONING_PROFILE\", \"\"), validate=True)\nexcept ValueError as exc:\n    raise SystemExit(\"Apple Distribution 或 provisioning profile Base64 无效\") from exc\nif not 1024 <= len(pkcs12) <= 32 * 1024 * 1024 or not 1024 <= len(profile) <= 1024 * 1024:\n    raise SystemExit(\"Apple Distribution 签名材料大小无效\")\n(root / \"distribution.p12\").write_bytes(pkcs12)\n(root / \"password\").write_text(fields[\"password\"])\n(root / \"certificate-sha1\").write_text(fields[\"certificate_sha1\"])\n(root / \"profile.mobileprovision\").write_bytes(profile)\nPY\nsecurity create-keychain -p \"$keychain_password\" \"$keychain\"\nsecurity set-keychain-settings -lut 21600 \"$keychain\"\nsecurity unlock-keychain -p \"$keychain_password\" \"$keychain\"\n# 中文注释：codesign 查找 identity 依赖用户钥匙串搜索列表；仅传 --keychain\n# 不能保证干净 runner 能从证书继续定位到同钥匙串中的私钥。\nsecurity list-keychains -d user -s \"$keychain\" \"${original_keychains[@]}\"\nsecurity import \"$work/distribution.p12\" -k \"$keychain\" -P \"$(cat \"$work/password\")\" -T /usr/bin/codesign\nsecurity set-key-partition-list -S apple-tool:,apple:,codesign: -s -k \"$keychain_password\" \"$keychain\" >/dev/null\ncertificate_sha1=\"$(cat \"$work/certificate-sha1\")\"\nsecurity find-certificate -a -Z \"$keychain\" | grep -F \"SHA-1 hash: $certificate_sha1\"\nsecurity find-identity -v -p codesigning \"$keychain\" | grep -Fq \"$certificate_sha1\"\n# 中文注释：干净 runner 的钥匙串不保证预装描述文件 CMS 签发链；LibreSSL\n# 直接验证 CMS 密码学签名并解出载荷，再用正式证书摘要锁定唯一配对。\n/usr/bin/openssl smime -verify -inform DER -in \"$work/profile.mobileprovision\" \\\n  -noverify -out \"$work/profile.plist\" >/dev/null\nprofile_certificate_sha1=\"$(\n  plutil -extract DeveloperCertificates.0 raw -o - \"$work/profile.plist\" \\\n    | base64 -D | shasum -a 1 | awk '{print toupper($1)}'\n)\"\ntest \"$profile_certificate_sha1\" = \"$certificate_sha1\"\ntest \"$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' \"$work/profile.plist\")\" = MHYMVRN6FC\ntest \"$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' \"$work/profile.plist\")\" = MHYMVRN6FC.ios.citizenapp\ntest \"$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' \"$work/profile.plist\")\" = false\nplutil -extract Entitlements xml1 -o \"$work/entitlements.plist\" \"$work/profile.plist\"\napp=\"$CITIZENAPP_FLUTTER_ROOT/build/ios/iphoneos/Runner.app\"\ntest \"$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \"$app/Info.plist\")\" = ios.citizenapp\ncp \"$work/profile.mobileprovision\" \"$app/embedded.mobileprovision\"\nfind \"$app\" -type f -name '*.dylib' -print0 | while IFS= read -r -d '' item; do\n  codesign --force --sign \"$certificate_sha1\" --keychain \"$keychain\" --timestamp=none \"$item\"\ndone\nfind \"$app\" -type d \\( -name '*.framework' -o -name '*.appex' \\) -print0 \\\n  | while IFS= read -r -d '' item; do\n      codesign --force --sign \"$certificate_sha1\" --keychain \"$keychain\" --timestamp=none \"$item\"\n    done\ncodesign --force --sign \"$certificate_sha1\" --keychain \"$keychain\" --timestamp=none \\\n  --generate-entitlement-der --entitlements \"$work/entitlements.plist\" \"$app\"\ncodesign --verify --deep --strict \"$app\"\ncodesign -dv --verbose=4 \"$app\" 2> \"$work/codesign.txt\"\ngrep -F 'TeamIdentifier=MHYMVRN6FC' \"$work/codesign.txt\"\nmkdir -p \"$work/package/Payload\"\ncp -R \"$app\" \"$work/package/Payload/Runner.app\"\n(cd \"$work/package\" && ditto -c -k --sequesterRsrc --keepParent Payload \"$publish/citizenapp.ipa\")\nunzip -Z1 \"$publish/citizenapp.ipa\" | grep -Fx 'Payload/Runner.app/Info.plist'"});

async function runShell(command,args,environment=process.env,cwd=root,shell=environment.PRODUCT_BASH_BIN||'/bin/bash') {
 const source=BUILD_SHELL_SOURCES[command];if(!source)fail('Shell入口无效');
 const env={...environment,CITIZENAPP_SOURCE_ROOT:root,CITIZENAPP_SCRIPTS_ROOT:join(root,'scripts'),CITIZENAPP_NODE_BIN:process.execPath};
 return run(shell,['--noprofile','--norc','-e','-o','pipefail','-c',source,'citizenapp-'+command,...args],env,cwd);
}
async function runHelper(argv) {
 const [command,...args]=argv;
 if(Object.hasOwn(BUILD_SHELL_SOURCES,command)){await runShell(command,args);return true;}
 if(command==='view'){await sourceView.runViewCLI(args);return true;}
 if(command==='native'){nativeTests.runNativeCLI(args);return true;}
 if(command==='inputs'){await runTestInputs(args);return true;}
 if(command==='logos'){if(args.length)fail('Logo检查不接受额外参数');await checkLogos();return true;}
 if(command==='config'){if(args.length!==1||!['analysis','test'].includes(args[0]))fail('配置入口参数无效');process.stdout.write(args[0]==='analysis'?ANALYSIS_OPTIONS_SOURCE:DART_TEST_SOURCE);return true;}
 if(command==='generate'){const [kind]=args;if(kind==='divisions')await generateDivisions();else if(kind==='institutions')await institutions.main();else if(kind==='registry')await generateRegistry();else fail('数据生成类型无效');return true;}
 return false;
}

// 本产品在独立编译与调度编译中均清理自己的生成物。
export function cleanBuildPath(path,options={},environment=executions.getStore()?.buildEnvironment||process.env){
 const work=environment.PRODUCT_WORK_DIR||[...Object.keys(contract.platforms).map(platform=>fixedWork('build/'+platform)),fixedWork('test')].find(work=>path?.startsWith(work+sep));if(typeof work!=='string'||typeof path!=='string'||resolve(path)!==path||!path.startsWith(work+sep))fail('编译清理路径越界');
 checkFixedWork(work);let parent=dirname(path);while(!existsSync(parent))parent=dirname(parent);if(realpathSync(parent)!==parent)fail('编译清理父目录经过链接');
 rmSync(path,options);
}
export function cleanShellPaths(args,environment=process.env){
 const paths=args.filter(value=>!value.startsWith('-')),options={recursive:args.some(value=>/^-[^-]*[rR]/u.test(value)),force:args.some(value=>/^-[^-]*f/u.test(value))};if(!paths.length)fail('清理路径缺失');for(const path of paths)cleanBuildPath(resolve(path),options,environment);
}


// GitHub身份校验后复用唯一execute编排；仅正式签名和资产交付与本机安装不同。
function checkedAutomationEnvironment(platform,environment){
 platformContract(platform);const sha=environment.GITHUB_SHA,run=environment.GITHUB_RUN_ID,attempt=environment.GITHUB_RUN_ATTEMPT,number=environment.GITHUB_RUN_NUMBER;
 if(environment.GITHUB_ACTIONS!=='true'||environment.GITHUB_REPOSITORY!=='crcfrcn/'+product
  ||environment.GITHUB_REF!=='refs/heads/main'||environment.GITHUB_EVENT_NAME!=='workflow_dispatch'
  ||environment.GITHUB_WORKFLOW_REF!=='crcfrcn/'+product+'/.github/workflows/'+platform+'.yml@refs/heads/main'||!/^[a-f0-9]{40}$/u.test(sha||'')
  ||[run,attempt,number].some(value=>!/^[1-9][0-9]*$/u.test(value||'')||!Number.isSafeInteger(Number(value))))fail('GitHub移动编译身份无效');
 return {sha,run,attempt,number};
}
export async function ciBuild(platform,environment=process.env){
 const {sha,run,attempt,number}=checkedAutomationEnvironment(platform,environment),token=environment.GH_TOKEN||environment.GITHUB_TOKEN;
 const head=spawnSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'});if(head.status!==0||head.stdout.trim()!==sha)fail('GitHub源码提交不匹配');
 const current=checkedHistoryRun(await automationRequest('actions/runs/'+run,token),platform);
 if(current.head_sha!==sha||String(current.run_attempt)!==attempt||String(current.run_number)!==number||current.status==='completed')fail('GitHub当前Run身份不匹配');
 const plan=await automationVersionPlan(platform,token,{currentRunId:run}),version=checkedBuildVersion(environment.CITIZENAPP_AUTOMATION_VERSION);
 if(plan.version!==version||current.display_title!==buildDisplayName(platform,version))fail('GitHub移动编译候选版本变化');
 const {APP_KEY:_appKey,IOS_KEY:_iosKey,IOS_PROVISIONING_PROFILE:_iosProfile,GH_TOKEN:_ghToken,GITHUB_TOKEN:_githubToken,...buildEnvironment}=environment;
 return withFixedWork('build/'+platform,async work=>execute(platform,work,{},
  {environment:buildEnvironment,delivery:'automation',version,ciEnvironment:environment}),{environment,retain:true});
}
// 正式签名和资产验收是共同编译链的环境交付阶段，版本仍由上述编译计划提供。
async function completeAutomation(platform,work,receipt,env,environment,version){
 const {sha,run,attempt,number}=checkedAutomationEnvironment(platform,environment),workflow=platform+'.yml',buildRoot=env.CITIZENAPP_BUILD_DIR;
  const stage=join(work,'sign-stage'),output=join(stage,'build/release');
  mkdirSync(output,{recursive:true});
  if(platform==='android'){
   const apk=join(work,'android.apk');
   const aab=join(buildRoot,'app/outputs/bundle/release/app-release.aab');
   for(const [source,target] of [[apk,join(stage,'build/app/outputs/flutter-apk/app-release.apk')],
    [aab,join(stage,'build/app/outputs/bundle/release/app-release.aab')]]){
    if(!existsSync(source)||!lstatSync(source).isFile())fail('GitHub Android未签名候选缺失');
    mkdirSync(dirname(target),{recursive:true});copyFileSync(source,target);
   }
   if(!environment.APP_KEY)fail('GitHub Android正式签名材料缺失');
  }else{
   const app=join(buildRoot,'ios/iphoneos/Runner.app');
   if(!existsSync(app)||!lstatSync(app).isDirectory())fail('GitHub iOS未签名候选缺失');
   const plist=spawnSync('/usr/libexec/PlistBuddy',['-c','Print :CFBundleVersion',join(app,'Info.plist')],{encoding:'utf8'});
   if(plist.status!==0||plist.stdout.trim()!==number)fail('GitHub iOS构建编号不匹配');
   const marketing=spawnSync('/usr/libexec/PlistBuddy',['-c','Print :CFBundleShortVersionString',join(app,'Info.plist')],{encoding:'utf8'});if(marketing.status!==0||marketing.stdout.trim()!==version)fail('GitHub iOS产品版本不匹配');
   const destination=join(stage,'build/ios/iphoneos/Runner.app');
   mkdirSync(dirname(destination),{recursive:true});
   const {cpSync}=await import('node:fs');cpSync(app,destination,{recursive:true});
   if(!environment.IOS_KEY||!environment.IOS_PROVISIONING_PROFILE)fail('GitHub iOS正式签名材料缺失');
  }
  const signingEnv={...env,HOME:environment.HOME,PATH:environment.PATH,RUNNER_TEMP:stage,
   APP_KEY:environment.APP_KEY,IOS_KEY:environment.IOS_KEY,IOS_PROVISIONING_PROFILE:environment.IOS_PROVISIONING_PROFILE,
   [product.toUpperCase()+'_BUILD_TEMP']:stage,[product.toUpperCase()+'_FLUTTER_ROOT']:stage,
   [product.toUpperCase()+'_RELEASE_ROOT']:output,[product.toUpperCase()+'_PROJECT_ROOT']:stage,
   [product.toUpperCase()+'_BUILD_NUMBER']:number};
  await runBuildProcess(env.PRODUCT_BASH_BIN||'/bin/bash',['--noprofile','--norc','-e','-o','pipefail','-c',CI_SIGNING_STEPS[platform],'github-mobile-signing'],
   signingEnv,stage,{timeout:1800000});
  const names=platform==='ios'?[product+'.ipa']:[product+'.apk',product+'.aab'];
  const assetsDir=join(work,'release-assets');mkdirSync(assetsDir,{mode:0o700});
  const assets=[];
  for(const stagedName of names){const source=join(output,stagedName),info=lstatSync(source),name=buildDisplayName(platform,version)+stagedName.slice(product.length);
   if(!info.isFile()||info.isSymbolicLink()||!info.size)fail('GitHub正式签名包缺失');
   const destination=join(assetsDir,name);copyFileSync(source,destination);
   assets.push({name,size:info.size,sha256:createHash('sha256').update(readFileSync(destination)).digest('hex')});
  }
  const bundleId='ios.'+product,packageName='com.crcfrcn.'+product;
  const manifestName=buildDisplayName(platform,version)+'.json';
  const manifest={product_id:product,platform,version,github_run_id:Number(run),github_run_attempt:Number(attempt),github_run_number:Number(number),head_sha:sha,bundle_id:bundleId,
   package_name:packageName,sdk_selection:checkedSdkSelection(executions.getStore().sdkSelection),assets:assets.map(value=>({platform:platform==='ios'?'iOS':'Android',asset_name:value.name,asset_sha256:value.sha256}))};
  writeFileSync(join(assetsDir,manifestName),JSON.stringify(manifest)+'\n',{flag:'wx',mode:0o600});
  const manifestInfo=lstatSync(join(assetsDir,manifestName));
  assets.push({name:manifestName,size:manifestInfo.size,sha256:createHash('sha256').update(readFileSync(join(assetsDir,manifestName))).digest('hex')});
  const tag=buildDisplayName(platform,version);
  const proof={schema:1,repository:'crcfrcn/'+product,product_id:product,platform,workflow:'.github/workflows/'+workflow,
   run_id:Number(run),run_attempt:Number(attempt),run_number:Number(number),source_sha:sha,version,tag,assets};
  const notes=join(work,'release-notes.txt');writeFileSync(notes,'<!-- automation:'+JSON.stringify(proof)+' -->\n',{flag:'wx',mode:0o600});
  const plan={schema:1,product_id:product,platform,tag,version,source_sha:sha,assets,directory:assetsDir,notes};
  writeFileSync(join(work,'release-plan.json'),JSON.stringify(plan)+'\n',{flag:'wx',mode:0o600});
  retainCompiledArtifacts(platform,work,version,assets.map(item=>({path:join(assetsDir,item.name),extension:item.name.slice(tag.length)})));
  return plan;
}

export async function ciVerifyRelease(platform,phase,environment=process.env,{fetchImpl=fetch}={}){
 checkedAutomationEnvironment(platform,environment);if(!['draft','published'].includes(phase))fail('GitHub移动Release核验身份无效');
 const work=fixedWork('build/'+platform);checkFixedWork(work);
 const plan=JSON.parse(readFileSync(join(work,'release-plan.json'),'utf8')),token=environment.GH_TOKEN||environment.GITHUB_TOKEN;
 if(!token||plan.product_id!==product||plan.platform!==platform||plan.source_sha!==environment.GITHUB_SHA)fail('GitHub移动Release计划无效');
 const response=await fetchImpl('https://api.github.com/repos/crcfrcn/'+product+'/releases/tags/'+encodeURIComponent(plan.tag),
  {redirect:'error',headers:{Accept:'application/vnd.github+json',Authorization:'Bearer '+token}});
 if(!response.ok)fail('GitHub移动Release回读失败');
 const reference=await fetchImpl('https://api.github.com/repos/crcfrcn/'+product+'/git/ref/tags/'+encodeURIComponent(plan.tag),
  {redirect:'error',headers:{Accept:'application/vnd.github+json',Authorization:'Bearer '+token}});
 if(!reference.ok)fail('GitHub移动Tag回读失败');
 const tag=await reference.json();
 if(tag.ref!=='refs/tags/'+plan.tag||tag.object?.type!=='commit'||tag.object?.sha!==plan.source_sha)fail('GitHub移动Tag来源不符');
 const release=await response.json();
 if(release.tag_name!==plan.tag||release.name!==buildDisplayName(platform,plan.version)||release.target_commitish!==plan.source_sha||release.prerelease!==false
  ||release.draft!==(phase==='draft')||phase==='published'&&!release.published_at
  ||release.body?.trim()!==readFileSync(plan.notes,'utf8').trim()
  ||!Array.isArray(release.assets)||release.assets.length!==plan.assets.length)fail('GitHub移动Release身份不符');
 for(const item of plan.assets){const local=join(plan.directory,item.name);
  if(createHash('sha256').update(readFileSync(local)).digest('hex')!==item.sha256)fail('本轮移动资产字节漂移');
  const rows=release.assets.filter(value=>value.label===item.name);
  if(rows.length!==1||rows[0].state!=='uploaded'||rows[0].size!==item.size||rows[0].digest!=='sha256:'+item.sha256)
   fail('GitHub移动Release资产回读不符');
 }
 return {platform,tag:plan.tag,phase};
}
// HTTP资产上传与正式版验收仍归唯一编译文件；YAML不持有gh脚本或第二套产物规则。
export async function ciRelease(platform,environment=process.env,{fetchImpl=fetch}={}){
 checkedAutomationEnvironment(platform,environment);const work=fixedWork('build/'+platform);checkFixedWork(work);
 const plan=runtimeDocument(join(work,'release-plan.json')),token=environment.GH_TOKEN||environment.GITHUB_TOKEN;
 if(!token||plan.product_id!==product||plan.platform!==platform||plan.source_sha!==environment.GITHUB_SHA||plan.tag!==buildDisplayName(platform,plan.version)||plan.directory!==join(work,'release-assets')||plan.notes!==join(work,'release-notes.txt'))fail('GitHub移动Release计划无效');
 const request=async(path,{method='GET',body,allowMissing=false}={})=>{
  const response=await fetchImpl('https://api.github.com/repos/'+automationRepository+'/'+path,{method,redirect:'error',headers:{Accept:'application/vnd.github+json',Authorization:'Bearer '+token,'Content-Type':'application/json','X-GitHub-Api-Version':'2026-03-10'},...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(30000)});
  if(allowMissing&&response.status===404)return null;if(!response.ok)fail('GitHub移动Release请求失败：HTTP '+response.status);
  if(response.status===204)return null;return response.json();
 };
 const tagPath='git/ref/tags/'+encodeURIComponent(plan.tag),reference=await request(tagPath,{allowMissing:true});
 if(reference){if(reference.ref!=='refs/tags/'+plan.tag||reference.object?.type!=='commit'||reference.object.sha!==plan.source_sha)fail('GitHub移动Tag已属于其它候选');}
 else await request('git/refs',{method:'POST',body:{ref:'refs/tags/'+plan.tag,sha:plan.source_sha}});
 const existing=await request('releases/tags/'+encodeURIComponent(plan.tag),{allowMissing:true});if(existing)fail('GitHub移动Release已存在，须先恢复原任务');
 const release=await request('releases',{method:'POST',body:{tag_name:plan.tag,target_commitish:plan.source_sha,name:plan.tag,body:readFileSync(plan.notes,'utf8'),draft:true,prerelease:false,make_latest:'false'}});
 if(!Number.isSafeInteger(release?.id)||release.id<1||release.tag_name!==plan.tag||release.draft!==true)fail('GitHub移动草稿回执无效');
 const endpoint='https://uploads.github.com/repos/'+automationRepository+'/releases/'+release.id+'/assets';
 if(release.upload_url?.replace(/\{\?name,label\}$/u,'')!==endpoint)fail('GitHub移动资产上传地址越界');
 for(const item of plan.assets){
  const file=join(plan.directory,item.name),info=lstatSync(file);if(!info.isFile()||info.isSymbolicLink()||info.nlink!==1||realpathSync(file)!==file||info.size!==item.size)fail('GitHub移动上传产物身份漂移');
  const extension=item.name.slice(plan.tag.length);if(!['.ipa','.apk','.aab','.json'].includes(extension))fail('GitHub移动资产类型未声明');
  const name=product+'-'+platform+'-v'+plan.version+extension,url=new URL(endpoint);url.searchParams.set('name',name);url.searchParams.set('label',item.name);
  const stream=targetFs.createReadStream(file);
  try{
   const response=await fetchImpl(url.href,{method:'POST',redirect:'error',headers:{Authorization:'Bearer '+token,Accept:'application/vnd.github+json','Content-Type':'application/octet-stream','Content-Length':String(item.size)},body:stream,duplex:'half',signal:AbortSignal.timeout(1800000)});
   if(!response.ok)fail('GitHub移动资产上传失败：HTTP '+response.status);const asset=await response.json();
   if(asset.name!==name||asset.label!==item.name||asset.state!=='uploaded'||asset.size!==item.size||asset.digest!=='sha256:'+item.sha256)fail('GitHub移动资产上传回读不符');
  }finally{if(!stream.closed)await new Promise(resolve=>{stream.once('close',resolve);stream.destroy();});}
 }
 await ciVerifyRelease(platform,'draft',environment,{fetchImpl});
 await request('releases/'+release.id,{method:'PATCH',body:{draft:false}});
 await ciVerifyRelease(platform,'published',environment,{fetchImpl});return {platform,version:plan.version,tag:plan.tag,release_id:release.id};
}
export function ciCachePlan(platform,environment=process.env){
 const {run,attempt}=checkedAutomationEnvironment(platform,environment),identity=incrementalIdentity(platform,automationSdkInputs(environment).sources),prefix=product+'-'+platform+'-incremental-';
 return {identity,path:'target/build/'+platform+'/incremental',prefix,key:prefix+identity+'-r'+run+'-a'+attempt,restore_prefix:prefix+identity+'-'};
}

async function runCLI(){
 if(process.argv[2]==='verify'){
  if(process.argv.length!==4||process.argv[3]!=='node')fail('独立测试只接受verify node');
  const cancellation=new AbortController(),cancel=()=>cancellation.abort();
  for(const name of ['SIGTERM','SIGINT'])process.once(name,cancel);
  try{const report=await verifyNode({signal:cancellation.signal});process.stdout.write(JSON.stringify(report)+'\n');}
  catch(error){
   const report=error.nodeReport||{schema:1,product_id:product,mode:'node',status:'failed',results:[],counts_complete:false,cleanup:{state:'unknown'},reason:error.message};
   process.stdout.write(JSON.stringify(report)+'\n');process.stderr.write(error.message+'\n');process.exitCode=1;
  }finally{for(const name of ['SIGTERM','SIGINT'])process.removeListener(name,cancel);}
  return;
 }
 if(process.argv[2]==='run'&&Object.hasOwn(buildPlatforms,process.argv[3])&&process.argv.length===4)process.argv.splice(2,2,'execute',process.argv[3],'--work',fixedWork('build/'+process.argv[3]));
 if(process.argv[2]==='ci-cache-plan'){
  if(process.argv.length!==4)fail('GitHub增量计划参数无效');const value=ciCachePlan(process.argv[3]);
  if(!process.env.GITHUB_OUTPUT||!isAbsolute(process.env.GITHUB_OUTPUT))fail('GitHub增量输出通道缺失');
  writeFileSync(process.env.GITHUB_OUTPUT,Object.entries(value).map(([key,value])=>key+'='+value).join('\n')+'\n',{flag:'a'});return;
 }
 if(process.argv[2]==='ci-release'){
  if(process.argv.length!==4)fail('GitHub正式包参数无效');process.stdout.write(JSON.stringify(await ciRelease(process.argv[3]))+'\n');return;
 }
 if(process.argv[2]==='automation'){
  const [operation,platform,id]=process.argv.slice(3),token=process.env.GH_TOKEN||process.env.GITHUB_TOKEN;
  if(operation==='plan'&&id===undefined){process.stdout.write(JSON.stringify(await automationVersionPlan(platform,token))+'\n');return;}
  if(operation==='run'&&id===undefined||operation==='resume'&&/^[1-9]\d*$/u.test(id||'')){process.stdout.write(JSON.stringify(await runAutomation(platform,token,{runId:id?Number(id):undefined,accepted:value=>process.stderr.write('Run已接收：'+value.html_url+'\n'),report:value=>process.stderr.write('GitHub：'+value.state+'\n')}))+'\n');return;}
  if(operation==='settle'&&/^[1-9]\d*$/u.test(id||'')){process.stdout.write(JSON.stringify(await settleCompletedAutomation(platform,Number(id),token))+'\n');return;}
  fail('自动化公开入口参数无效');
 }
 if(process.argv[2]==='ci-build'){
  if(process.argv.length!==4)fail('GitHub移动编译参数无效');
  process.stdout.write(JSON.stringify(await ciBuild(process.argv[3]))+'\n');return;
 }
 if(process.argv[2]==='ci-verify-release'){
  if(process.argv.length!==5)fail('GitHub移动Release核验参数无效');
  process.stdout.write(JSON.stringify(await ciVerifyRelease(process.argv[3],process.argv[4]))+'\n');return;
 }
 const [operation,platform,flag,work]=process.argv.slice(2);
 if(operation==='execute'){if(flag!=='--work'||work!==fixedWork('build/'+platform))fail('平台编译现场不符');return withFixedWork('build/'+platform,()=>runCommand(),{environment:process.env});}
 if(['resources','prepare','build'].includes(operation)&&flag==='--work'){
  checkWork(work);
  return withFixedWork(taskScope(work),()=>runCommand(),{environment:process.env});
 }
 return runCommand();
}
async function runCommand(){
 if(await runHelper(process.argv.slice(2)))return;
 const [command,platform,option,work,...extra]=process.argv.slice(2);
 if(command==='clean'){cleanShellPaths(process.argv.slice(3));return;}


 if(command==='describe'){
  if(process.argv.length!==3)fail('编译声明只读入口不接受参数');
  process.stdout.write(JSON.stringify(contract)+'\n');return;
 }
 if(command==='finish'){
  if(platform!=='test'&&!Object.hasOwn(contract.platforms,platform)||option!==undefined)fail('平台收尾入口参数无效');
  finishFixedWork(fixedWork(platform==='test'?'test':'build/'+platform));return;
 }
 if(command==='rsync'){
  await copyFlutterArtifact(process.argv.slice(3));return;
 }

 if(command==='store-identity') {
  if(process.argv.length!==3)fail('商店身份只读入口不接受参数');
  process.stdout.write(JSON.stringify(storeIdentity())+'\n');
 } else if(command==='temporary-root') {
  if(work!==undefined||extra.length)fail('临时入口参数无效');
  const host=process.platform==='darwin'?'macos':process.platform==='win32'?'windows':process.platform==='linux'?(process.arch==='arm64'?'linux-arm':process.arch==='x64'?'linux-amd':undefined):undefined;
  const fallback=option?.endsWith('macos')?option.slice(0,-5)+host:option;
  const chosen=Object.hasOwn(contract.platforms,platform)?platform
   :platform&&option?.endsWith('-'+platform)&&Object.hasOwn(contract.platforms,option)?option
   :Object.hasOwn(contract.platforms,'host-'+platform)?'host-'+platform:!platform?(Object.hasOwn(contract.platforms,fallback)?fallback:option):platform;
  platformContract(chosen);process.stdout.write(temporaryRoot(chosen,'tmp')+'\n');
 } else {

 if(!['requirements','resources','prepare','build','execute'].includes(command)||option!=='--work'||extra.some(x=>x!=='--offline')||extra.length>1||extra.length&&!['resources','execute'].includes(command))fail('固定入口参数无效');
 if(command==='execute'){platformContract(platform);if(work!==fixedWork('build/'+platform))fail('平台编译现场不符');}else checkWork(work);
 if(command==='requirements')process.stdout.write(JSON.stringify(requirements(platform,work))+'\n');
 else{
  const cancellation=new AbortController();for(const name of ['SIGTERM','SIGINT'])process.once(name,()=>cancellation.abort());
  let input='';for await(const chunk of process.stdin){input+=chunk;if(Buffer.byteLength(input)>2*1024*1024)fail('公开输入超限');}
  const request=input?JSON.parse(input):{},options={environment:process.env,signal:cancellation.signal,offline:extra.includes('--offline'),toolRoot:process.env.PRODUCT_TOOL_ROOT};
  let result;
  if(command==='execute'){
   const node=await resourceRuntime.bootstrapNode(work,options);
   if(realpathSync(process.execPath)!==realpathSync(node.path)){
    const environment=Object.fromEntries(['HOME','USER','LOGNAME','LANG','LC_ALL','PRODUCT_WORK_LEASE'].filter(k=>typeof process.env[k]==='string').map(k=>[k,process.env[k]]));
    result=JSON.parse((await runBuildProcess(node.path,[fileURLToPath(import.meta.url),command,platform,option,work,...extra],workEnvironment(environment),root,{capture:true,streamError:true,input:JSON.stringify(request),signal:cancellation.signal})).stdout);
   }else result=await execute(platform,work,request,options);
  }else if(command==='resources')result=await resourceRuntime.resources(platform,work,request,options);
  else result=await executions.run({signal:cancellation.signal},()=>command==='prepare'?prepare(platform,work,request,process.env):build(platform,work,request,process.env));
  process.stdout.write(JSON.stringify(result)+'\n');
 }
}
}


let fixtureWork,removeFixture,writeFixture,copyFixture;
if(inlineTestEntry)inlineTestRegistrations.push(async()=>{
 const {default:fs}=await import('node:fs');
 const {finishFixedWork}=targetRuntime;
fixtureWork=function(){const work=fixedWork('build/'+Object.keys(contract.platforms)[0]);if(fs.existsSync(work))finishFixedWork(work);return checkFixedWork(work,{create:true});}
removeFixture=function(path,options={}){if(path===fixedWork('build/'+Object.keys(contract.platforms)[0])||path===fixedWork('test')){if(fs.existsSync(path))clearFixedWork(path);return;}fs.rmSync(path,options);}

writeFixture=(path,data,options)=>fs.writeFileSync(path,data,options);
copyFixture=(source,destination,...options)=>fs.copyFileSync(source,destination,...options);

});
const inlineTestOwner = {contract,checkWork,productTarget,prepareTargetRoot,temporaryRoot,testRoot,resourceSourceRoot,clearWork,platformContract,lockedSources,requirements,resourceEnvironment,createView,prepare,build,IOS_VERIFIER_SOURCE,readStoreSource,iosStoreBundleID,androidStorePackageName,storeIdentity,androidPackageName,androidUSBSerials,androidInstalledPath,androidCertificate,parseAndroidSigning,iosDeviceCandidates,iosInstalled,iosVersion,runBuildProcess,outputDigest,execute,checkBuildResult,PLATFORM_INPUTS,materializePlatformInputs,ANALYSIS_OPTIONS_SOURCE,DART_TEST_SOURCE,LOGO_ASSETS_SOURCE,TEST_INPUTS_SOURCE,SOURCE_VIEW_SOURCE,BUILD_SHELL_SOURCES,resolveFirstPartyDependencies,copyHostInput,citizenCorePath,isarCorePath,JsonRpc};

// 同文件回归：普通导入和正式命令不注册测试。
if(inlineTestEntry)inlineTestRegistrations.push(async()=>{
 const {test:register}=await import('node:test');
 register('同文件回归组 1',async context=>{
 const pending=[];const test=(...args)=>{const item=context.test(...args);pending.push(item);return item;};
const {BUILD_SHELL_SOURCES}=inlineTestOwner;
// 产品独立入口：真实只读需求、资源身份、路径隔离与锁定归档失败关闭。
const {createHash} = await import("node:crypto");
const {spawnSync} = await import("node:child_process");
const {default: assert} = await import("node:assert/strict");
const {copyFileSync,linkSync,unlinkSync,existsSync,lstatSync,mkdtempSync,readFileSync,readdirSync,realpathSync,rmSync,mkdirSync,symlinkSync,writeFileSync} = await import("node:fs");
const { testRoot: tmpdir } = inlineTestOwner;
const {dirname,join,resolve} = await import("node:path");
const {iosStoreBundleID,androidStorePackageName,readStoreSource,storeIdentity,contract,requirements,resourceEnvironment,checkWork,productTarget,createView} = inlineTestOwner;

const sandbox=fixtureWork;
const root=resolve(import.meta.dirname,'..'),base=root;
const fixture=work=>{
 const platform=Object.keys(contract.platforms).find(value=>value.endsWith('android'))||Object.keys(contract.platforms)[0];
 const own={};for(const value of contract.platforms[platform].locks){const key={npm:'npmCache',pub:'pubCache',cargo:'cargoHome'}[value.ecosystem];if(key){own[key]=join(work,key);mkdirSync(own[key]);}}
 return {schema:1,product_id:contract.product_id,platform,work,offline:true,
 tools:Object.fromEntries(contract.platforms[platform].tools.map(tool=>[tool.id,{version:tool.version,path:process.execPath}])),
 dependencies:{own},archives:{},environment:{}};
};
test('每个平台从自身原始锁只读提出需求；缺失原始Pod锁按源码事实拒绝',async()=>{
 const work=sandbox();try{for(const platform of Object.keys(contract.platforms)){
  const before=readdirSync(work),apple=platform.endsWith('ios')?'ios':platform.endsWith('macos')?'macos':null;
  if(apple&&(apple==='ios'||existsSync(join(base,apple,'Podfile')))&&!existsSync(join(base,apple,'Podfile.lock'))){
   await assert.rejects(async()=>requirements(platform,work),/CocoaPods原始锁缺失/);
  }else{
   const result=await requirements(platform,work);assert.equal(result.product_id,contract.product_id);
   assert.equal(result.platform,platform);assert.equal(result.schema,1);
   assert.ok(result.tools.every(value=>value.id&&value.version));
   assert.ok(result.locks.every(value=>['cargo','pub','npm','cocoapods'].includes(value.ecosystem)));
  }
  assert.deepEqual(readdirSync(work),before);
 }}finally{removeFixture(work,{recursive:true});}
});
test('CitizenSDK归档只由固定来源公开plan交付，坏身份和来源拒绝',()=>{
 const work=sandbox();try{
  const sdk=join(work,'sdk'),scripts=join(sdk,'scripts'),entry=join(scripts,'build.mjs');
  mkdirSync(scripts,{recursive:true});
  const archive={name:'zxing-cpp',version:'3.1.1',url:'https://example.invalid/zxing.tar.gz',
   size:123,sha256:'a'.repeat(64),archive_root:'zxing-cpp-3.1.1'};
  const plan={schema:1,platform:'Android',archives:[archive]};
  const writePlan=value=>writeFixture(entry,
   'if(process.argv.slice(2).join(",")!=="plan,--platform,Android")process.exit(2);process.stdout.write('+JSON.stringify(JSON.stringify(value)+'\n')+');\n');
  writePlan(plan);assert.deepEqual(sdkDependencyPlan(sdk,'Android'),[archive]);
  assert.throws(()=>sdkDependencyPlan(sdk,'foreign'),/平台/);
  writePlan({...plan,schema:2});assert.throws(()=>sdkDependencyPlan(sdk,'Android'),/身份/);
  writePlan({...plan,archives:[archive,archive]});assert.throws(()=>sdkDependencyPlan(sdk,'Android'),/归档/);
  writePlan({...plan,archives:[{...archive,url:'http://example.invalid/zxing.tar.gz'}]});assert.throws(()=>sdkDependencyPlan(sdk,'Android'),/来源/);
  writeFixture(entry,"process.stderr.write('failure');process.exit(1);\n");
  assert.throws(()=>sdkDependencyPlan(sdk,'Android'),/计划失败/);
 }finally{removeFixture(work,{recursive:true});}
});
test('平台、源码内工作根和链接工作根在任何写入前拒绝',async()=>{
 const work=sandbox();try{
  await assert.rejects(async()=>requirements('unknown',work),/平台/);
  assert.throws(()=>checkWork(root),/本产品target/);
  mkdirSync(join(work,'actual'));symlinkSync(join(work,'actual'),join(work,'linked'));
  assert.throws(()=>checkWork(join(work,'linked')),/固定目录/);
 }finally{removeFixture(work,{recursive:true});}
});
test('资源回执隔离产品、平台、工作根，直接交付工具路径且禁止注入',()=>{
 const work=sandbox();try{
  const receipt=fixture(work),platform=receipt.platform;
  assert.throws(()=>resourceEnvironment(platform,work,{...receipt,product_id:'another'}),/身份/);
  assert.throws(()=>resourceEnvironment(platform,work,{...receipt,offline:false}),/身份/);
  assert.throws(()=>resourceEnvironment(platform,work,{...receipt,tools:{}}),/工具/);
  assert.throws(()=>resourceEnvironment(platform,work,{...receipt,environment:{NODE_OPTIONS:'--inspect'}}),/注入/);
  const id=Object.keys(receipt.tools)[0];assert.doesNotThrow(()=>resourceEnvironment(platform,work,{...receipt,tools:{...receipt.tools,[id]:{...receipt.tools[id],version:'informational'}}}));
  const env=resourceEnvironment(platform,work,receipt,{HOME:'/home',TOKEN:'private',INJECTED_CONTEXT:'/private'});
  assert.equal(env.TOKEN,undefined);assert.equal(env.INJECTED_CONTEXT,undefined);assert.equal(env.CARGO_NET_OFFLINE,'true');
  assert.equal(env[contract.product_id.toUpperCase()+'_WORK_DIR'],work);
  const github={GITHUB_ACTIONS:'true',GITHUB_REPOSITORY:'crcfrcn/citizenapp',
    GITHUB_RUN_ID:'39044524886',GITHUB_RUN_ATTEMPT:'2',GITHUB_SHA:'a'.repeat(40)};
  const scheduled=resourceEnvironment(platform,work,receipt,{...github,GH_TOKEN:'fixture',GITHUB_TOKEN:'fixture'});
  for(const [key,value]of Object.entries(github))assert.equal(scheduled[key],value);
  assert.equal(scheduled.GH_TOKEN,undefined);assert.equal(scheduled.GITHUB_TOKEN,undefined);
  const independent=resourceEnvironment(platform,work,receipt,{GITHUB_ACTIONS:'false',GITHUB_RUN_ID:github.GITHUB_RUN_ID});
  assert.equal(independent.GITHUB_ACTIONS,undefined);assert.equal(independent.GITHUB_RUN_ID,undefined);
 }finally{removeFixture(work,{recursive:true});}
});
test('原始锁需要的依赖必须显式交付，不能使用用户默认缓存',()=>{
 const work=sandbox();try{
  const receipt=fixture(work),own=receipt.dependencies.own;
  for(const key of Object.keys(own)){const missing={...own};delete missing[key];
   assert.throws(()=>resourceEnvironment(receipt.platform,work,{...receipt,dependencies:{own:missing}}),/依赖回执/);}
  const key=Object.keys(own)[0];if(key){
   const linked=join(work,'linked');symlinkSync(own[key],linked);
   assert.throws(()=>resourceEnvironment(receipt.platform,work,{...receipt,dependencies:{own:{...own,[key]:linked}}}),/依赖回执/);
  }
 }finally{removeFixture(work,{recursive:true});}
});
test('工程复制在同轮解析包并隔离写入，内部链接重新指向副本',()=>{
 const work=sandbox();try{
  const source=join(work,'input'),output=join(work,'view');mkdirSync(source);
  writeFixture(join(source,'package.json'),'{"name":"input"}');
  writeFixture(join(source,'code.js'),'source');symlinkSync('code.js',join(source,'linked.js'));
  mkdirSync(join(source,'node_modules'));writeFixture(join(source,'node_modules/old'),'generated');
  createView(source,output);writeFixture(join(output,'package.json'),'{"name":"generated"}');
  assert.equal(readFileSync(join(source,'package.json'),'utf8'),'{"name":"input"}');
  assert.equal(realpathSync(join(output,'linked.js')),join(output,'code.js'));
  assert.equal(existsSync(join(output,'node_modules')),false);
  assert.throws(()=>createView(source,output),/已存在/);
 }finally{removeFixture(work,{recursive:true});}
});
test('工程输出的父链接和输入外部链接均拒绝，不能写入第三方目录',()=>{
 const work=sandbox();try{
  const source=join(work,'source'),external=join(work,'external');mkdirSync(source);mkdirSync(external);
  writeFixture(join(source,'code'),'source');symlinkSync(external,join(work,'linked'));
  assert.throws(()=>createView(source,join(work,'linked/view')),/链接/);assert.deepEqual(readdirSync(external),[]);
  symlinkSync('/etc/passwd',join(source,'outside'));
  assert.throws(()=>createView(source,join(work,'bad-view')),/越界/);
 }finally{removeFixture(work,{recursive:true});}
});


// 本产品独立拥有此实现，通过自身公开接口执行。
test('独立命令行从自身声明输出JSON，未知平台失败且不写工作根',async()=>{
 const work=sandbox();try{
  for(const platform of Object.keys(contract.platforms)){
   const before=readdirSync(work),result=spawnSync(process.execPath,[join(root,'scripts/build.mjs'),'requirements',platform,'--work',work],{env:{HOME:work,LANG:'C',LC_ALL:'C',NODE_TEST_CONTEXT:'child-v8',CITIZENAPP_TEST_SESSION:testSession},encoding:'utf8'});
   const apple=platform.endsWith('ios')?'ios':platform.endsWith('macos')?'macos':null;
   if(apple&&(apple==='ios'||existsSync(join(base,apple,'Podfile')))&&!existsSync(join(base,apple,'Podfile.lock'))){assert.notEqual(result.status,0);assert.match(result.stderr,/CocoaPods原始锁缺失/);}
   else{assert.equal(result.status,0,result.stderr);const value=JSON.parse(result.stdout);assert.equal(value.product_id,contract.product_id);assert.equal(value.platform,platform);}
   assert.deepEqual(readdirSync(work),before);
  }
  const invalid=spawnSync(process.execPath,[join(root,'scripts/build.mjs'),'requirements','unknown','--work',work],{env:{HOME:work,NODE_TEST_CONTEXT:'child-v8',CITIZENAPP_TEST_SESSION:testSession},encoding:'utf8'});
  assert.notEqual(invalid.status,0);assert.match(invalid.stderr,/平台/);
 }finally{removeFixture(work,{recursive:true});}
});

// 完整入口控制边界：替身只替换耗时阶段，不调用真实编译或用户安全存储。
test('产品独立execute完成全部自有阶段后才返回唯一结果',async()=>{
 const {execute,outputDigest}=await import('./build.mjs');const work=sandbox(),platform=Object.keys(contract.platforms)[0],declared=contract.platforms[platform],calls=[];
 try{
  const result={schema:1,product_id:contract.product_id,platform,work,completion:declared.completion,run_id:'123456789',files:[]};
  const stages={requirements:async()=>{calls.push('requirements');},resources:async()=>{calls.push('resources');return {};},prepare:async()=>{calls.push('prepare');},build:async()=>{
   calls.push('build');for(const name of declared.files){const path=join(work,name);mkdirSync(dirname(path),{recursive:true});writeFixture(path,'isolated-candidate-fixture');result.files.push({path,sha256:outputDigest(path)});}return result;
  }};
  assert.deepEqual(await execute(platform,work,{run_id:'123456789'},{stages}),result);
  assert.deepEqual(calls,['requirements','resources','prepare','requirements','resources','build']);
  assert.equal(existsSync(work),false, '独立执行结束必须删除平台现场');
  result.files=[]; calls.length=0;
  assert.deepEqual(await execute(platform,work,{run_id:'123456789'},{stages}),result);
  assert.equal(existsSync(work),false, '下一轮结束仍须删除平台现场');
 }finally{removeFixture(work,{recursive:true});}
});
test('失败、取消、并发和伪造终态不能复用工作根或留下成功回执',async()=>{
 const {execute}=await import('./build.mjs'),platform=Object.keys(contract.platforms)[0];
 for(const failure of ['resources','prepare','build','identity','cancel']){
  const work=sandbox(),abort=new AbortController(),calls=[];
  try{
   const stages={requirements:()=>{},resources:async()=>{calls.push('resources');if(failure==='resources')throw Error('fixture failure');return {};},prepare:async()=>{calls.push('prepare');if(failure==='prepare')throw Error('fixture failure');if(failure==='cancel')abort.abort();},build:async()=>{calls.push('build');if(failure==='build')throw Error('fixture failure');return {schema:1,product_id:'forged'};}};
   await assert.rejects(execute(platform,work,{}, {stages,signal:abort.signal}));
   assert.equal(existsSync(join(work,'build-result.json')),false);assert.equal(existsSync(join(work,'.product-build.lock')),false);
   if(['resources','prepare','cancel'].includes(failure))assert.equal(calls.includes('build'),false);
  }finally{removeFixture(work,{recursive:true});}
 }
 const work=sandbox();try{writeFixture(join(work,'.product-build.lock'),'owned');await assert.rejects(execute(platform,work,{}));assert.equal(readFileSync(join(work,'.product-build.lock'),'utf8'),'owned');}finally{rmSync(join(work,'.product-build.lock'),{force:true});removeFixture(work,{recursive:true});}
});

// 真实Node子执行器复用同一领取：子进程自身确已登记，只有父层确认退出后才能清平台根。
test('真实登记子执行器由父层清场，成功和各阶段原始错误均保留',async()=>{
 const {withFixedWork,runBuildProcess}=await import('./build.mjs'),platform=Object.keys(contract.platforms)[0];
 const module=new URL('./build.mjs',import.meta.url).href;
 for(const mode of ['success','resources','prepare','build']){
  const work=sandbox();
  try{
   await withFixedWork('build/'+platform,async owned=>{
    assert.equal(owned,work);
    const code=[
     'import {execute,outputDigest} from '+JSON.stringify(module)+';',
     'import fs from "node:fs";import {join,dirname} from "node:path";',
     'const platform='+JSON.stringify(platform)+',work='+JSON.stringify(work)+',mode='+JSON.stringify(mode)+';',
     'const owner=JSON.parse(fs.readFileSync(join(work,".active.json"),"utf8"));',
     'if(owner.pid===process.pid||!owner.groups.includes(process.pid))throw Error("fixture child not registered");',
     'const stages={requirements:()=>{},resources:async()=>{if(mode==="resources")throw Error("fixture resources failure");return {};},prepare:async()=>{if(mode==="prepare")throw Error("fixture prepare failure");},build:async()=>{',
     'if(mode==="build")throw Error("fixture build failure");',
     'const declared=(await import('+JSON.stringify(module)+')).contract.platforms[platform];',
     'const result={schema:1,product_id:"citizenapp",platform,work,completion:declared.completion,run_id:"123456789",files:[]};',
     'for(const name of declared.files){const path=join(work,name);fs.mkdirSync(dirname(path),{recursive:true});fs.writeFileSync(path,"isolated-child-candidate");result.files.push({path,sha256:outputDigest(path)});}return result;}};',
     'let error=null;try{await execute(platform,work,{run_id:"123456789"},{stages});}catch(value){error=value.message;process.exitCode=7;}',
     'process.stdout.write(JSON.stringify({pid:process.pid,ownerPid:owner.pid,registered:owner.groups.includes(process.pid),error,workExists:fs.existsSync(work),guardExists:fs.existsSync(join(work,".product-build.lock")),resultExists:fs.existsSync(join(work,"build-result.json"))}));',
    ].join('\n');
    const result=await runBuildProcess(process.execPath,['--input-type=module','-e',code],{
     PATH:process.env.PATH,HOME:process.env.HOME,LANG:'C',LC_ALL:'C',
     NODE_TEST_CONTEXT:'child-v8',CITIZENAPP_TEST_SESSION:testSession,
    },root,{capture:true,accepted:[0,7],timeout:15000});
    const value=JSON.parse(result.stdout),owner=JSON.parse(readFileSync(join(work,'.active.json'),'utf8'));
    assert.equal(value.ownerPid,process.pid);assert.notEqual(value.pid,process.pid);
    assert.equal(value.registered,true);assert.ok(owner.groups.includes(value.pid));
    assert.equal(result.code,mode==='success'?0:7);
    assert.equal(value.error,mode==='success'?null:'fixture '+mode+' failure');
    assert.equal(value.workExists,true,'父层仍领取现场，子执行器不能提前删除');
    assert.equal(value.guardExists,false,'已确认本层结束必须释放自己的编译守卫');
    assert.equal(value.resultExists,mode==='success');
    assert.equal(existsSync(work),true);
   },{run_id:'123456789'});
   assert.equal(existsSync(work),false,'真实子进程退出后由父层统一清场');
  }finally{removeFixture(work,{recursive:true});}
 }
});

test('真实登记工具后代仍存活时拒绝清场，取消并确认退出后才收尾',async()=>{
 const {withFixedWork,runBuildProcess,clearWork}=await import('./build.mjs'),platform=Object.keys(contract.platforms)[0],work=sandbox();
 try{
  await withFixedWork('build/'+platform,async owned=>{
   assert.equal(owned,work);const keep=join(work,'keep');writeFixture(keep,'owned');
   const cancellation=new AbortController();
   const child=runBuildProcess(process.execPath,['-e','setInterval(()=>{},1000)'],{
    PATH:process.env.PATH,HOME:process.env.HOME,LANG:'C',LC_ALL:'C',
   },root,{capture:true,signal:cancellation.signal,timeout:15000});
   const stopped=assert.rejects(child,/产品任务已取消/);
   try{
    const owner=JSON.parse(readFileSync(join(work,'.active.json'),'utf8'));
    assert.equal(owner.pid,process.pid);assert.ok(owner.groups.length>0);
    assert.throws(()=>clearWork(work),/工具后代退出未确认/);
    assert.equal(readFileSync(keep,'utf8'),'owned','拒绝清场时原现场必须保留');
   }finally{cancellation.abort();await stopped;}
  });
  assert.equal(existsSync(work),false,'真实后代停止且确认退出后才允许所有者清场');
 }finally{removeFixture(work,{recursive:true});}
});

test('Android多USB、包路径、证书和开发材料异常由产品拒绝',async()=>{
 const {androidUSBSerials,androidInstalledPath,androidCertificate,parseAndroidSigning}=await import('./build.mjs');
 assert.deepEqual(androidUSBSerials('List of devices attached\nA device usb:1\nB device usb:2\nemulator-1 device transport_id:3\n'),['A','B']);
 for(const list of ['List of devices attached\nA offline usb:1\nB device usb:2','List of devices attached\nA device usb:1\nA device usb:2','List of devices attached\nA device usb:1'])assert.throws(()=>androidUSBSerials(list));
 assert.equal(androidInstalledPath({code:1,stdout:'',stderr:''}),null);
 assert.equal(androidInstalledPath({code:0,stdout:'package:/data/app/abc/base.apk\n',stderr:''}),'/data/app/abc/base.apk');
 for(const value of [{code:1,stdout:'',stderr:'device offline'},{code:0,stdout:'package:/data/app/../base.apk',stderr:''},{code:0,stdout:'package:/data/app/a/base.apk\npackage:/data/app/b/base.apk',stderr:''}])assert.throws(()=>androidInstalledPath(value));
 const cert='a'.repeat(64);assert.equal(androidCertificate('Verified using v2 scheme (APK Signature Scheme v2): true\nSigner #1 certificate SHA-256 digest: '+cert),cert);
 assert.throws(()=>androidCertificate('Signer #1 certificate SHA-256 digest: '+cert));assert.throws(()=>parseAndroidSigning(Buffer.from('keystore=bad\npassword=fixture').toString('base64')));
});
test('iOS设备、过滤包标识、bundleVersion与版本比较归产品',async()=>{
 const {iosDeviceCandidates,iosInstalled,iosVersion}=await import('./build.mjs');
 const identifier='12345678-1234-1234-1234-123456789abc',udid='12345678-123456789abcdef0',bundle='fixture.product';
 const device={identifier,properties:{hardware:{reality:'physical',platform:'iOS',udid},connection:{pairingState:'paired'},state:{developerModeStatus:{enabled:{mode:1}}}}};
 assert.deepEqual(iosDeviceCandidates({info:{outcome:'success'},result:{devices:[device]}}),[{identifier,udid}]);
 assert.deepEqual(iosDeviceCandidates({info:{outcome:'success'},result:{devices:[{...device,properties:{...device.properties,hardware:{...device.properties.hardware,reality:'virtual'}}}]}}),[]);
 const readback={info:{outcome:'success'},result:{deviceIdentifier:identifier,matchingBundleIdentifier:bundle,apps:[{bundleIdentifier:bundle,version:'1.2',bundleVersion:'3'}]}};
 assert.deepEqual(iosInstalled(readback,identifier,bundle),{version:'1.2',build:'3'});
 assert.throws(()=>iosInstalled(readback,'wrong-device',bundle));assert.throws(()=>iosInstalled({...readback,result:{...readback.result,apps:[{bundleIdentifier:bundle,version:'1.2',buildVersion:'3'}]}},identifier,bundle));
 assert.deepEqual(iosVersion('1.2'),iosVersion('1.2.0'));assert.throws(()=>iosVersion('1.2-beta'));
});

// 本产品独立拥有此实现，通过自身公开接口执行。
test('本产品iOS签名检查由Apple API执行并拒绝身份漂移',async()=>{
 const {spawnSync}=await import('node:child_process'),{mkdtempSync,rmSync}=await import('node:fs');
 const work=mkdtempSync(join(tmpdir(),'product-ios-signature-'));
 try{
  const swift=process.env.PRODUCT_TEST_SWIFTC,developer=process.env.PRODUCT_TEST_DEVELOPER_DIR;
  const sdk=process.env.PRODUCT_TEST_SDKROOT||process.env.SDKROOT;
  assert.ok(swift&&developer&&sdk,'测试须显式交付本产品锁定Xcode的swiftc、SDK和Developer目录');
  assert.ok(realpathSync(swift).startsWith(realpathSync(developer)+'/'));
  assert.ok(realpathSync(sdk).startsWith(realpathSync(developer)+'/'));
  const source=join(work,'product-ios.swift'),binary=join(work,'product-ios-check');writeFixture(source,IOS_VERIFIER_SOURCE);
  const testEnvironment={...process.env,DEVELOPER_DIR:developer,SDKROOT:sdk};
  const compiler=spawnSync(swift,['-O','-module-cache-path',join(work,'modules'),'-sdk',sdk,'-framework','Security',source,'-o',binary],{encoding:'utf8',env:testEnvironment});
  assert.equal(compiler.status,0,compiler.stderr);
  const app=join(work,'Product.app');mkdirSync(app,{recursive:true});
  const executable=join(app,'Product');copyFileSync('/bin/ls',executable);chmodSync(executable,0o700);
  const bundle=IOS_VERIFIER_SOURCE.match(/static let bundleIdentifier = "([^"]+)"/u)?.[1];assert.ok(bundle);
  const writeInfo=value=>writeFixture(join(app,'Info.plist'),`<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>Product</string><key>CFBundleIdentifier</key><string>${value}</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>1.2</string><key>CFBundleVersion</key><string>7</string></dict></plist>`);
  const sign=value=>spawnSync('/usr/bin/codesign',['--force','--sign','-','--identifier',value,app],{encoding:'utf8',env:testEnvironment});
  const inspect=()=>spawnSync(binary,[],{encoding:'utf8',input:JSON.stringify({operation:'ios.verify',app}),env:testEnvironment});
  writeInfo(bundle);assert.equal(sign(bundle).status,0);
  const accepted=inspect();assert.equal(accepted.status,0,accepted.stderr);const result=JSON.parse(accepted.stdout);
  assert.deepEqual({version:result.version,build:result.build,bundle_id:result.bundle_id},{version:'1.2',build:'7',bundle_id:bundle});
  writeInfo('invalid.other.product');assert.equal(sign('invalid.other.product').status,0);assert.notEqual(inspect().status,0);
  writeInfo(bundle);assert.equal(sign(bundle).status,0);writeFileSync(executable,Buffer.concat([readFileSync(executable),Buffer.from('drift')]));assert.notEqual(inspect().status,0);
  assert.match(IOS_VERIFIER_SOURCE,/SecStaticCodeCheckValidity/u);assert.match(IOS_VERIFIER_SOURCE,/bundleIdentifier/u);
 }finally{rmSync(work,{recursive:true,force:true});}
});

test('产品取消等待工具进程组退出，不提前交付结果',async()=>{
 const {runBuildProcess}=await import('./build.mjs'),work=sandbox(),abort=new AbortController();let polling,deadline;
 try{
  const pidFile=join(work,'descendant.pid');
  const script="const fs=require('node:fs'),{spawn}=require('node:child_process');const child=spawn(process.execPath,['-e','setInterval(()=>{},1000)'],{stdio:'ignore'});fs.writeFileSync(process.argv[1],String(child.pid));setInterval(()=>{},1000);";
  const execution=runBuildProcess(process.execPath,['-e',script,pidFile],process.env,work,{capture:true,signal:abort.signal,timeout:5000});
  polling=setInterval(()=>{if(existsSync(pidFile))abort.abort();},20);deadline=setTimeout(()=>abort.abort(),2000);
  await assert.rejects(execution,/取消.*exit=none，signal=SIGTERM/u);assert.ok(existsSync(pidFile));const pid=Number(readFileSync(pidFile,'utf8'));
  assert.throws(()=>process.kill(pid,0),error=>error.code==='ESRCH');
 }finally{clearInterval(polling);clearTimeout(deadline);removeFixture(work,{recursive:true});}
});

test('工具退出诊断保留退出码、信号与启动错误码，不含调用材料',async()=>{
 const work=sandbox();
 try{
  const call=(file,args,options={})=>runBuildProcess(file,args,process.env,work,{capture:true,timeout:5000,...options});
  assert.equal((await call(process.execPath,['-e','process.exit(0)'])).code,0);
  assert.equal((await call(process.execPath,['-e','process.exit(7)'],{accepted:[7]})).code,7);
  await assert.rejects(call(process.execPath,['-e','process.exit(23)']),error=>{
   assert.match(error.message,/执行失败（exit=23，signal=none，errors=none，process=/u);
   const details=JSON.parse(error.message.split('，process=')[1].slice(0,-1));
   assert.ok(Number.isSafeInteger(details.pid));assert.equal(details.expectedPgid,details.pid);
   const exit=details.timeline.find(event=>event.event==='exit'),close=details.timeline.find(event=>event.event==='close');
   assert.equal(exit.code,23);assert.equal(close.code,23);assert.ok(close.ms>=exit.ms);
   assert.ok(details.timeline.length<=48);assert.ok(details.snapshots.length<=2);
   assert.ok(details.snapshots.every(snapshot=>snapshot.members.length<=32));
   return true;
  });
  await assert.rejects(call(process.execPath,['-e',"process.kill(process.pid,'SIGTERM')"]),/exit=none，signal=SIGTERM/u);
  await assert.rejects(call(join(work,'absent-tool'),['synthetic-argument']),error=>{
   assert.match(error.message,/spawn:ENOENT/u);
   assert.doesNotMatch(error.message,/absent-tool|synthetic-argument|ENOENT:|spawn\s/u);
   return true;
  });
  assert.equal(processErrorCode({code:'EPERM',message:'synthetic detail'}),'EPERM');
  assert.equal(processErrorCode({code:'ERR_INVALID_ARG_TYPE',message:'synthetic detail'}),'ERR_INVALID_ARG_TYPE');
  assert.equal(processErrorCode({code:'synthetic-untrusted-code',message:'synthetic detail'}),'UNKNOWN');
  assert.equal(processErrorCode(null),'UNKNOWN');
 }finally{removeFixture(work,{recursive:true});}
});

test('进程组诊断仅保留数字归属、可证实后代与状态，输出数量受限',()=>{
 const result=processGroupMembers('201 100 201 501 Ss\n202 201 201 501 Z\n203 202 203 501 S\n999 1 999 0 S\ninvalid synthetic detail\n204 1 201 501 S synthetic-argument\n',201);
 assert.deepEqual(result,{members:[
  {pid:201,ppid:100,pgid:201,uid:501,state:'S'},
  {pid:202,ppid:201,pgid:201,uid:501,state:'Z'},
  {pid:203,ppid:202,pgid:203,uid:501,state:'S'},
 ],truncated:false});
 const many=processGroupMembers(Array.from({length:40},(_,n)=>`${n+300} 1 201 501 S`).join('\n'),201);
 assert.equal(many.members.length,32);assert.equal(many.truncated,true);
 assert.deepEqual(processGroupSnapshot(undefined),{status:'notStarted',members:[],truncated:false});
});

// 覆盖独立入口、单/多平台物理边界和源码输入排除，统一测试阶段才执行。
test('本仓target由当前平台声明决定，外部或链接工作根不能越界',()=>{
 for(const platform of Object.keys(contract.platforms)){
  const expected=join(root,'target');
  assert.equal(productTarget(platform),expected);
 }
 assert.throws(()=>productTarget('undeclared-platform'));
 assert.throws(()=>checkWork(join(root,'..','foreign-work')),/target/);
 assert.throws(()=>checkWork(join(root,'target')),/target/);
 const work=sandbox();try{assert.equal(checkWork(work),work);assert.throws(()=>checkWork(join(work,'nested')),/固定目录/);}finally{removeFixture(work,{recursive:true,force:true});}
});

// 本产品独立拥有此实现，通过自身公开接口执行。
const storeProject=(bundle='ios.fixture')=>`{
 objects = {
  P = { isa = PBXProject; targets = (T,); buildConfigurationList = PC; };
  T = { isa = PBXNativeTarget; name = Runner; productType = "com.apple.product-type.application"; buildConfigurationList = TC; };
  PC = { isa = XCConfigurationList; buildConfigurations = (PR,); };
  TC = { isa = XCConfigurationList; buildConfigurations = (TR,); };
  PR = { isa = XCBuildConfiguration; name = Release; buildSettings = { PRODUCT_BUNDLE_IDENTIFIER = ios.project; }; };
  TR = { isa = XCBuildConfiguration; name = Release; buildSettings = { PRODUCT_BUNDLE_IDENTIFIER = "${bundle}"; }; };
 }; rootObject = P;
}`;
test('商店身份解析真实Runner Release覆盖关系并拒绝歧义、重复键和非法标识',()=>{
 assert.equal(iosStoreBundleID(storeProject()),'ios.fixture');
 assert.equal(iosStoreBundleID(storeProject().replace('PRODUCT_BUNDLE_IDENTIFIER = "ios.fixture";','OTHER = "a\\ntext";')),'ios.project');
 for(const value of [storeProject().replace('targets = (T,)','targets = (T,T,)'),storeProject().replace('buildConfigurations = (TR,)','buildConfigurations = (TR,TR,)'),
  storeProject().replace('name = Release;','name = Debug;'),storeProject().replace('rootObject = P;','rootObject = P; rootObject = P;'),
  storeProject('$(BUNDLE_ID)'),storeProject('ios.bad_'),storeProject()+'garbage',storeProject().slice(0,-1),'/* never closed',
  '{a = '+ '('.repeat(66)+'x'+')'.repeat(66)+';}'])assert.throws(()=>iosStoreBundleID(value));
 assert.equal(androidStorePackageName('applicationId = "com.example.fixture"'),'com.example.fixture');
 assert.equal(androidStorePackageName("applicationId 'com.example.fixture'"),'com.example.fixture');
 for(const value of ['', 'applicationId="bad"','applicationId="1.bad"','applicationId="com.example.a";applicationId="com.example.b"'])assert.throws(()=>androidStorePackageName(value));
});
test('商店身份源码有界读取拒绝符号链接、父路径链接、硬链接及越界路径',()=>{
 const work=sandbox();try{
  writeFixture(join(work,'plain'),'plain');assert.equal(readStoreSource(work,'plain').toString(),'plain');
  symlinkSync(join(work,'plain'),join(work,'alias'));assert.throws(()=>readStoreSource(work,'alias'));
  mkdirSync(join(work,'directory'));writeFixture(join(work,'directory/file'),'data');symlinkSync(join(work,'directory'),join(work,'linked'));
  assert.throws(()=>readStoreSource(work,'linked/file'));
  linkSync(join(work,'plain'),join(work,'hard'));assert.throws(()=>readStoreSource(work,'plain'));
  writeFixture(join(work,'empty'),'');writeFixture(join(work,'large'),Buffer.alloc(1_048_577));
  for(const value of ['empty','large','../plain','/plain','directory//file','directory/./file','directory/../plain','bad\\path'])assert.throws(()=>readStoreSource(work,value));
 }finally{removeFixture(work,{recursive:true});}
});
test('公开只读身份回执验真真实配置，无环境回退、不接受参数且不写原始文件',()=>{
 const entry=join(root,'scripts/build.mjs'),before=storeIdentity();
 const invoke=args=>spawnSync(process.execPath,[entry,...args],{encoding:'utf8',env:{HOME:process.env.HOME,LANG:'C',PATH:'',NODE_OPTIONS:'',NODE_PATH:''}});
 const result=invoke(['store-identity']);assert.equal(result.status,0,result.stderr);const receipt=JSON.parse(result.stdout);
 assert.deepEqual(receipt,before);assert.deepEqual(Object.keys(receipt).sort(),['bundle_id','package_name','product_id','schema','source_files']);
 assert.equal(receipt.product_id,contract.product_id);assert.equal(receipt.source_files.length,3);
 for(const file of receipt.source_files)assert.equal(createHash('sha256').update(readStoreSource(root,file.path)).digest('hex'),file.sha256);
 assert.notEqual(invoke(['store-identity','ios']).status,0);assert.deepEqual(storeIdentity(),before);
});
test('公开只读身份命令拒绝缺失或重复原始工程，配置变化由产品回执表达',()=>{
 const work=sandbox();try{
  for(const name of ['scripts','ios/project','android/app'])mkdirSync(join(work,name),{recursive:true});
  copyFixture(join(root,'scripts/build.mjs'),join(work,'scripts/build.mjs'));
  const project=join(work,'ios/project/Runner.pbxproj'),gradle=join(work,'android/app/build.gradle.kts');
  writeFixture(project,storeProject());writeFixture(gradle,'applicationId = "com.example.fixture"');
  const run=()=>spawnSync(process.execPath,[join(work,'scripts/build.mjs'),'store-identity'],{encoding:'utf8',env:{PATH:'',HOME:process.env.HOME,NODE_OPTIONS:'',NODE_PATH:''}});
  const first=run();assert.equal(first.status,0,first.stderr);assert.equal(JSON.parse(first.stdout).bundle_id,'ios.fixture');
  writeFixture(project,storeProject('ios.changed'));const changed=run();assert.equal(changed.status,0,changed.stderr);
  assert.equal(JSON.parse(changed.stdout).bundle_id,'ios.changed');assert.notDeepEqual(JSON.parse(changed.stdout).source_files,JSON.parse(first.stdout).source_files);
  writeFixture(join(work,'ios/Runner.pbxproj'),storeProject());assert.notEqual(run().status,0);rmSync(join(work,'ios/Runner.pbxproj'));
  writeFixture(join(work,'android/app/build.gradle'),'applicationId "com.example.duplicate"');assert.notEqual(run().status,0);
  rmSync(join(work,'android/app/build.gradle'));rmSync(project);assert.notEqual(run().status,0);
 }finally{removeFixture(work,{recursive:true});}
});


// 复制本产品真实入口到自有测试现场；只替换资源供给边界，反向导入和CLI子进程真实执行。
test('合并入口普通导入、只读声明与错误CLI均准确退出',()=>{
 const area=sandbox();
 try{
  const source=join(area,'source'),scripts=join(source,'scripts'),file=join(scripts,'build.mjs');
  const work=join(source,'target','build');mkdirSync(scripts,{recursive:true});mkdirSync(work,{recursive:true});
  copyFixture(join(root,'scripts/build.mjs'),file);
  const options={cwd:source,env:{HOME:area,LANG:'C',PATH:'',NODE_OPTIONS:''},encoding:'utf8',timeout:5000,maxBuffer:1024*1024};
  const imported=spawnSync(process.execPath,['--input-type=module','--eval',
   'import {pathToFileURL} from "node:url";await import(pathToFileURL('+JSON.stringify(file)+'));process.stdout.write("module-ready\\n");'],options);
  assert.equal(imported.status,0,imported.stderr);assert.equal(imported.stdout,'module-ready\n');
  assert.deepEqual(readdirSync(work),[]);
  const described=spawnSync(process.execPath,[file,'describe'],options);
  assert.equal(described.status,0,described.stderr);assert.deepEqual(JSON.parse(described.stdout),contract);
  assert.notEqual(spawnSync(process.execPath,[file,'describe','extra'],options).status,0);
  for(const args of [['resources','unknown','--work',work],['prepare','unknown','--work',work],['finish','foreign']]){
   const result=spawnSync(process.execPath,[file,...args],{...options,input:'{}'});
   assert.equal(result.status,1);assert.equal(result.stdout,'');assert.doesNotMatch(result.stderr,/unsettled top-level await/u);
  }
  assert.deepEqual(readdirSync(work),[]);
 }finally{rmSync(area,{recursive:true,force:true});}
});

test('CitizenApp产品入口唯一构建SDK并按所有者隔离Cargo Home', async () => {
  const product = BUILD_SHELL_SOURCES.run;
  assert.match(product,/cd "\$CITIZENAPP_PROJECT_ROOT\/android"/u);
  assert.doesNotMatch(product,/cd "\$APP_ROOT\/android"/u);
  assert.match(product, /CITIZENAPP_SDK_CARGO_HOME/u);
  assert.match(product, /CITIZENAPP_CHAT_CARGO_HOME/u);
  // prepare-environment 只准备归档输入；Cargo 隔离须在两端原生编译入口前生效。
  assert.ok(product.indexOf('export CARGO_HOME="$CITIZENAPP_SDK_CARGO_HOME"')
    < product.indexOf('"$CITIZENSDK_ROOT/scripts/build.mjs" native apple'));
  assert.ok(product.indexOf('export CARGO_HOME="$CITIZENAPP_SDK_CARGO_HOME"')
    < product.indexOf('"$CITIZENSDK_ROOT/scripts/build.mjs" native android'));
  assert.ok(product.indexOf('export CARGO_HOME="$CITIZENAPP_CHAT_CARGO_HOME"')
    < product.indexOf('"$TATACHATSDK_ROOT/scripts/build.mjs"'));
});


test('本产品Apple Flutter资源只通过自身资源入口交付',()=>{
 const entry=BUILD_SHELL_SOURCES.run;
 const resources=readFileSync(new URL('./build.mjs', import.meta.url),'utf8');
 assert.match(resources,/prepareFlutterTaskTools/u);assert.match(resources,/PRODUCT_WORK_DIR/u);
 assert.doesNotMatch(entry,/prepareFlutterTaskTools|copyFlutterArtifact/u);
});

test('Python与Clang官方命令优先使用已验真回执，重复调用稳定且漂移拒绝',()=>{
 const work=sandbox();try{
  const receipt=fixture(work),developer=join(work,'xcode'),compiler=join(developer,'clang');mkdirSync(developer);copyFixture(process.execPath,compiler);
  const xcodePython=join(developer,'python3');writeFixture(xcodePython,'wrong-xcode-version');
  receipt.environment={DEVELOPER_DIR:developer,CC:compiler,CXX:compiler,PATH:developer};
  const env=resourceEnvironment(receipt.platform,work,receipt),commands=join(work,'build-tools');
  assert.equal(env.LC_ALL,'zh_CN.UTF-8');assert.equal(env.LANG,env.LC_ALL);assert.equal(env.PATH.split(':')[0],commands);assert.equal(realpathSync(join(commands,'python3')),process.execPath);
  assert.equal(realpathSync(join(commands,'cc')),compiler);assert.equal(realpathSync(join(commands,'c++')),compiler);
  const identity=lstatSync(join(commands,'python3')).ino;resourceEnvironment(receipt.platform,work,receipt);assert.equal(lstatSync(join(commands,'python3')).ino,identity);
  unlinkSync(join(commands,'python3'));symlinkSync(compiler,join(commands,'python3'));
  assert.throws(()=>resourceEnvironment(receipt.platform,work,receipt),/入口漂移/);
  assert.equal(readFileSync(xcodePython,'utf8'),'wrong-xcode-version');
 }finally{removeFixture(work,{recursive:true});}
});

test('构建工具投影拒绝父目录链接、悬空入口与Xcode外编译器',()=>{
 for(const failure of ['directory-link','dangling','external-compiler']){
  const work=sandbox();try{
   const receipt=fixture(work),outside=join(work,'outside');mkdirSync(outside);
   if(failure==='directory-link')symlinkSync(outside,join(work,'build-tools'));
   if(failure==='dangling'){mkdirSync(join(work,'build-tools'));symlinkSync(join(work,'absent'),join(work,'build-tools/python3'));}
   if(failure==='external-compiler')receipt.environment={DEVELOPER_DIR:outside,CC:process.execPath};
   assert.throws(()=>resourceEnvironment(receipt.platform,work,receipt),/链接|漂移|越出/);assert.deepEqual(readdirSync(outside),[]);
  }finally{removeFixture(work,{recursive:true});}
 }
});

test('宿主消费输入普通复制隔离写入，重复输出/链接/硬链接/越界均拒绝',async()=>{
 const work=sandbox();try{
  const {copyHostInput}=inlineTestOwner;
  const sourceRoot=join(work,'source'),targetRoot=join(work,'view');mkdirSync(sourceRoot);mkdirSync(targetRoot);const input=join(sourceRoot,'input'),output=join(targetRoot,'input');writeFixture(input,'locked-bytes');copyHostInput(input,output,sourceRoot);
  assert.equal(lstatSync(output).isSymbolicLink(),false);assert.equal(lstatSync(output).nlink,1);writeFixture(output,'task-generator-change');assert.equal(readFileSync(input,'utf8'),'locked-bytes');assert.throws(()=>copyHostInput(input,output,sourceRoot),/EEXIST/);
  const linked=join(sourceRoot,'linked');symlinkSync(input,linked);assert.throws(()=>copyHostInput(linked,join(targetRoot,'linked'),sourceRoot),/独占普通/);
  const hard=join(sourceRoot,'hard');linkSync(input,hard);assert.throws(()=>copyHostInput(hard,join(targetRoot,'hard'),sourceRoot),/独占普通/);unlinkSync(hard);
  assert.throws(()=>copyHostInput(input,join(targetRoot,'outside'),targetRoot),/独占普通/);assert.equal(readFileSync(input,'utf8'),'locked-bytes');
 }finally{removeFixture(work,{recursive:true});}
});

// 完整宿主通道由调用方核验结果并收尾；独立执行仍必须立即清空。


 await Promise.all(pending);
 });
});

// 同文件回归：普通导入和正式命令不注册测试。
if(inlineTestEntry)inlineTestRegistrations.push(async()=>{
 const {test:register}=await import('node:test');
 register('同文件回归组 2',async context=>{
 const pending=[];const test=(...args)=>{const item=context.test(...args);pending.push(item);return item;};
const {spawnSync} = await import("node:child_process");
const {fileURLToPath} = await import("node:url");
const {default: assert} = await import("node:assert/strict");
const {mkdtempSync,mkdirSync,writeFileSync,rmSync,symlinkSync,realpathSync} = await import("node:fs");
const { testRoot: tmpdir } = inlineTestOwner;
const {join} = await import("node:path");
const {citizenCorePath,isarCorePath} = inlineTestOwner;

function fixture() {
  const root=realpathSync(mkdtempSync(join(tmpdir(),'citizenapp-native-contract-')));
  const cache=join(root,'pub-cache'),pkg=join(cache,'hosted/pub.dev/isar_community_flutter_libs-3.3.2');
  const output=join(root,'sdk-output'),config=join(root,'package_config.json'),lock=join(root,'pubspec.lock');
  mkdirSync(join(pkg,'linux'),{recursive:true});mkdirSync(join(pkg,'macos'));
  mkdirSync(join(output,'abi-host'),{recursive:true});
  writeFixture(join(pkg,'pubspec.yaml'),'name: isar_community_flutter_libs\nversion: 3.3.2\n');
  writeFixture(join(pkg,'linux/libisar.so'),'fixture');
  writeFixture(join(pkg,'macos/libisar.dylib'),'fixture');
  writeFixture(join(output,'abi-host/libcitizensdk.so'),'fixture');
  writeFixture(join(output,'abi-host/libcitizensdk.dylib'),'fixture');
  writeFixture(lock,'packages:\n  isar_community_flutter_libs:\n    dependency: "direct main"\n    source: hosted\n    version: "3.3.2"\n');
  const packageEntry={name:'isar_community_flutter_libs',rootUri:'pub-cache/hosted/pub.dev/isar_community_flutter_libs-3.3.2/'};
  const configure=packages=>writeFixture(config,JSON.stringify({configVersion:2,packages}));
  configure([packageEntry]);
  return {root,cache,pkg,output,config,lock,packageEntry,configure,dispose:()=>rmSync(root,{recursive:true,force:true})};
}
test('本轮普通SDK产物和准确锁定Isar包支持Linux与Mac宿主',()=>{
  const f=fixture();try {
    assert.equal(citizenCorePath(f.output,'linux','x64'),join(f.output,'abi-host/libcitizensdk.so'));
    assert.equal(citizenCorePath(f.output,'darwin','arm64'),join(f.output,'abi-host/libcitizensdk.dylib'));
    assert.equal(isarCorePath(f.config,f.cache,f.lock,'linux','x64'),join(f.pkg,'linux/libisar.so'));
    assert.equal(isarCorePath(f.config,f.cache,f.lock,'darwin','arm64'),join(f.pkg,'macos/libisar.dylib'));
  }finally{f.dispose();}
});
test('缺少SDK产物及错误宿主直接失败，不寻找debug目录',()=>{
  const f=fixture();try {
    rmSync(join(f.output,'abi-host/libcitizensdk.so'));
    assert.throws(()=>citizenCorePath(f.output,'linux','x64'),/普通文件/);
    assert.throws(()=>citizenCorePath(f.output,'linux','arm64'),/不受支持/);
    assert.throws(()=>citizenCorePath('relative','linux','x64'),/路径无效/);
  }finally{f.dispose();}
});
test('拒绝重复或缺失Isar包坐标及非文件URI',()=>{
  const f=fixture();try {
    for(const entries of [[],[f.packageEntry,f.packageEntry],[{...f.packageEntry,rootUri:'https://pub.dev/'}]]) {
      f.configure(entries);assert.throws(()=>isarCorePath(f.config,f.cache,f.lock,'linux','x64'),/坐标/);
    }
  }finally{f.dispose();}
});
test('拒绝缓存越界、版本漂移及锁定包缺失',()=>{
  const f=fixture();try {
    f.configure([{...f.packageEntry,rootUri:'sdk-output/'}]);
    assert.throws(()=>isarCorePath(f.config,f.cache,f.lock,'linux','x64'),/越出/);
    f.configure([f.packageEntry]);
    writeFixture(join(f.pkg,'pubspec.yaml'),'name: isar_community_flutter_libs\nversion: 3.3.3\n');
    assert.throws(()=>isarCorePath(f.config,f.cache,f.lock,'linux','x64'),/身份/);
    writeFixture(f.lock,'packages:\n');
    assert.throws(()=>isarCorePath(f.config,f.cache,f.lock,'linux','x64'),/锁定包/);
  }finally{f.dispose();}
});
test('拒绝链接库、链接父目录和未准备的Isar库',()=>{
  const f=fixture();try {
    const core=join(f.output,'abi-host/libcitizensdk.so');rmSync(core);
    symlinkSync(join(f.output,'abi-host/libcitizensdk.dylib'),core);
    assert.throws(()=>citizenCorePath(f.output,'linux','x64'),/普通文件/);
    const isar=join(f.pkg,'linux/libisar.so');rmSync(isar);
    assert.throws(()=>isarCorePath(f.config,f.cache,f.lock,'linux','x64'),/普通文件/);
    symlinkSync(join(f.pkg,'macos/libisar.dylib'),isar);
    assert.throws(()=>isarCorePath(f.config,f.cache,f.lock,'linux','x64'),/普通文件/);
    const alias=join(f.root,'output-alias');symlinkSync(f.output,alias);
    assert.throws(()=>citizenCorePath(alias,'darwin','arm64'),/普通文件/);
  }finally{f.dispose();}
});

test('实际CLI传递本轮库路径并拒绝多余参数',()=>{
  const f=fixture();try {
    const script=fileURLToPath(new URL('./build.mjs', import.meta.url));
    assert.equal(citizenCorePath(f.output),join(f.output,'abi-host/libcitizensdk.dylib'));
    const core=spawnSync(process.execPath,[script,'native','core',f.output],{encoding:'utf8'});
    assert.equal(core.status,0,core.stderr);
    assert.equal(core.stdout,citizenCorePath(f.output));
    const isar=spawnSync(process.execPath,[script,'native','isar',f.config,f.cache,f.lock],{encoding:'utf8'});
    assert.equal(isar.status,0,isar.stderr);
    assert.equal(isar.stdout,isarCorePath(f.config,f.cache,f.lock));
    const invalid=spawnSync(process.execPath,[script,'native','core',f.output,'extra'],{encoding:'utf8'});
    assert.notEqual(invalid.status,0);assert.match(invalid.stderr,/参数无效/);assert.equal(invalid.stdout,'');
  }finally{f.dispose();}
});

 await Promise.all(pending);
 });
});

// 数据生成器原有SCALE自检也放在正式代码之后。
function runInstitutionSelfTest(){
 const {decodeInstitution}=institutions;

    const compactSmall = (length) => {
      if (!Number.isInteger(length) || length < 0 || length >= 64) {
        throw new Error('self-test 只编码单字节 compact');
      }
      return Buffer.from([length << 2]);
    };
    const vec = (value) => {
      const data = Buffer.from(value, 'utf8');
      return Buffer.concat([compactSmall(data.length), data]);
    };
    const rawNone = Buffer.concat([
      vec('测试公权机构'),
      vec('测试机构'),
      vec(''),
      Buffer.from([0]), // 原子 legal_representative=None
      Buffer.from('CAGR', 'ascii'),
      Buffer.from([7, 0, 0, 0]),
    ]);
    const decodedNone = decodeInstitution(
      'HE036-CAGRA-251174662-2026',
      `0x${rawNone.toString('hex')}`,
    );
    const rawSome = Buffer.concat([
      vec('测试公权机构'),
      vec('测试机构'),
      vec(''),
      Buffer.from([1]),
      vec('管'),
      vec('理员'),
      vec('HE000-CTZN0-198805200-2026'),
      Buffer.alloc(32, 9),
      Buffer.from('CAGR', 'ascii'),
      Buffer.from([8, 0, 0, 0]),
    ]);
    const decodedSome = decodeInstitution(
      'HE036-CAGRA-251174662-2026',
      `0x${rawSome.toString('hex')}`,
    );
    if (decodedNone.status !== 'ACTIVE' || decodedNone.created_at_block !== 7
        || decodedNone.institution_code !== 'CAGR'
        || decodedSome.created_at_block !== 8
        || decodedSome.institution_code !== 'CAGR') {
      throw new Error(
        `InstitutionInfo SCALE self-test 失败:${JSON.stringify({ decodedNone, decodedSome })}`,
      );
    }
    process.stdout.write('public institution SCALE self-test ok\n');
    return;

}

// 合并后的Shell与Python桥接必须保持语法及显式源码、执行器归属。
if(inlineTestEntry)inlineTestRegistrations.push(async()=>{
 const {test}=await import('node:test');const {default:assert}=await import('node:assert/strict');
 const {spawnSync}=await import('node:child_process');
 test('同文件Shell语法与聊天UI桥接入口保持',()=>{
  for(const source of Object.values(BUILD_SHELL_SOURCES)){
   const checked=spawnSync(process.env.PRODUCT_BASH_BIN||'/bin/bash',['-n'],{input:source,encoding:'utf8'});
   assert.equal(checked.status,0,checked.stderr);
   assert.match(source,/CITIZENAPP_SCRIPTS_ROOT/u);assert.match(source,/CITIZENAPP_SOURCE_ROOT/u);
  }
  assert.match(BUILD_SHELL_SOURCES['chat-test'],/subprocess[.]run\(\[NODE_BIN, IOS_TEST, "ui-test"\]/u);
 });
 test('扁平原生来源恢复消费路径并保留图标、配置和源码字节',()=>{
  const source=root,destination=join(temporaryRoot(),'layout-platform-'+randomBytes(8).toString('hex'));
  mkdirSync(destination,{mode:0o700});
  try{
   materializePlatformInputs(source,destination);
   const cases=[
    ['ios/source/AppDelegate.swift','ios/Runner/AppDelegate.swift'],
    ['ios/project/Runner.pbxproj','ios/Runner.xcodeproj/project.pbxproj'],
    ['android/app/MainActivity.kt','android/app/src/main/MainActivity.kt'],
    ['android/square/SquareMediaChannel.kt','android/app/src/main/SquareMediaChannel.kt'],
    ['android/square/SquareMp4FastStart.kt','android/app/src/main/SquareMp4FastStart.kt'],
    ['android/square/SquareVideoTranscoder.kt','android/app/src/main/SquareVideoTranscoder.kt'],
    ['ios/square/SquareMediaChannel.swift','ios/Runner/SquareMediaChannel.swift'],
    ['ios/square/SquareVideoTranscoder.swift','ios/Runner/SquareVideoTranscoder.swift'],
    ['assets/logo/icon72.png','android/app/src/main/res/mipmap-hdpi/ic_launcher.png'],
   ];
   for(const [input,output] of cases)assert.deepEqual(readFileSync(join(destination,output)),readFileSync(join(source,input)));
   for(const [output,contents] of Object.entries({...platformInputs(root).ios,...platformInputs(root).android}))assert.equal(readFileSync(join(destination,output),'utf8'),contents,output);
   assert.equal(readFileSync(join(destination,'analysis_options.yaml'),'utf8'),ANALYSIS_OPTIONS_SOURCE);
   assert.equal(readFileSync(join(destination,'dart_test.yaml'),'utf8'),DART_TEST_SOURCE);
  }finally{rmSync(destination,{recursive:true,force:true});}
 });
 test('合并后的字典生成命令只在新资源目录产生完整分片',async()=>{
  const {DatabaseSync}=await import('node:sqlite');
  const work=join(temporaryRoot(),'layout-generator-'+randomBytes(8).toString('hex')),product=join(work,'product');
  mkdirSync(join(product,'scripts'),{recursive:true,mode:0o700});
  try{
   copyFixture(join(root,'scripts/build.mjs'),join(product,'scripts/build.mjs'));
   const database=join(work,'dictionary.sqlite'),db=new DatabaseSync(database);
   try{db.exec("CREATE TABLE metadata(key TEXT,value TEXT);INSERT INTO metadata VALUES('admin_division_version','7');CREATE TABLE provinces(code TEXT,name TEXT,sort_order INTEGER);INSERT INTO provinces VALUES('LN','公开夹具省',1);CREATE TABLE cities(province_code TEXT,code TEXT,name TEXT,sort_order INTEGER);INSERT INTO cities VALUES('LN','001','公开夹具市',1);CREATE TABLE towns(province_code TEXT,city_code TEXT,code TEXT,name TEXT);INSERT INTO towns VALUES('LN','001','001','公开夹具镇');");}finally{db.close();}
   const result=spawnSync(process.execPath,[join(product,'scripts/build.mjs'),'generate','divisions','--db',database],{encoding:'utf8'});
   assert.equal(result.status,0,result.stderr);
   const output=join(product,'assets/divisions'),manifest=JSON.parse(readFileSync(join(output,'manifest.json')));
   assert.equal(manifest.version,'7');assert.equal(manifest.province_count,1);assert.equal(manifest.city_count,1);assert.equal(manifest.town_count,1);
   assert.deepEqual(JSON.parse(readFileSync(join(output,'cities/LN.json'))),[{code:'001',name:'公开夹具市'}]);
   assert.deepEqual(JSON.parse(readFileSync(join(output,'towns/LN.json'))),[{city_code:'001',code:'001',name:'公开夹具镇'}]);
   assert.equal(existsSync(join(product,'assets/admin_divisions')),false);
  }finally{removeFixture(work,{recursive:true,force:true});}
 });
});


// 原生文件名仍由平台要求；独立旧字节摘要保证集中和去重没有改变图标或启动画面。
if(inlineTestEntry)inlineTestRegistrations.push(async()=>{
 const {test}=await import('node:test');const {default:assert}=await import('node:assert/strict');
 const {spawnSync}=await import('node:child_process');
 test('统一Logo来源恢复全部原生图片与目录声明的原字节',()=>{
  const destination=join(temporaryRoot(),'logo-projection-'+randomBytes(8).toString('hex'));
  mkdirSync(destination,{mode:0o700});
  try{
   materializePlatformInputs(root,destination);
   const expected={
   "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": "c8cfdefdbc3b28e2e7d123bc36cd509fb93fc60c9436632afc69265554e81b62",
   "android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png": "7ff1c4ae15d00f6a65a8ce6471054d6e37c5664cc9104f844aa9904882591e63",
   "android/app/src/main/res/mipmap-hdpi/ic_launcher_round.png": "c8cfdefdbc3b28e2e7d123bc36cd509fb93fc60c9436632afc69265554e81b62",
   "android/app/src/main/res/mipmap-hdpi/launch_image.png": "81789009c4dc03a283f610183cf0b462dc7e473dbdbbd6edb4da12a62a4f5177",
   "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": "4c03ec508fdcb94a1a037aa66477d749ff96d2c35e46a3adbe3b27ba64c27632",
   "android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png": "ed7d9b1eabd510ebcae47221ff78381a2ba2d41e5a4990e56d25ebabdad3c65a",
   "android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png": "4c03ec508fdcb94a1a037aa66477d749ff96d2c35e46a3adbe3b27ba64c27632",
   "android/app/src/main/res/mipmap-mdpi/launch_image.png": "1ce729c3a23ac185f6a54397bef5d5c8a317f67b38f66bea1f3393b6dec9da2a",
   "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": "278eb6a62a06c0ef22a50b6c358533f88d5b9fd1e6c93e711e298155908d9bee",
   "android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png": "f8c5bbeb68c77abaa74ffb1f402221f5115bcf4d24ebf7e854490ff34e081e5e",
   "android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.png": "278eb6a62a06c0ef22a50b6c358533f88d5b9fd1e6c93e711e298155908d9bee",
   "android/app/src/main/res/mipmap-xhdpi/launch_image.png": "fff07730b40f242d922c023d21f7db62555acac86365c9fc96276daf0b65c488",
   "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": "f203f0700e86403515c280f2a0c6c933ab1bdb95c63a12f5187de1629ad87b7f",
   "android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png": "57afe78264c3179f166cbae09c47c70f1535e07ac3ba25db319efbd3c8ed8656",
   "android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png": "f203f0700e86403515c280f2a0c6c933ab1bdb95c63a12f5187de1629ad87b7f",
   "android/app/src/main/res/mipmap-xxhdpi/launch_image.png": "06c6b7d208914e36eb4f6fedb62828027534eac81c338a0bf6060872fa61f9d0",
   "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": "092869629be4dd591352237a789f08a21e09c5c28faf66b503e16e9cc7e0f5d6",
   "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png": "6f2b955dfdd30cf4c0613d4c78255be0de43d06281fd0ec57ee6feb10bd1b06d",
   "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png": "092869629be4dd591352237a789f08a21e09c5c28faf66b503e16e9cc7e0f5d6",
   "android/app/src/main/res/mipmap-xxxhdpi/launch_image.png": "34a50a60d559d09fdd1037fad391ad62b242c842f6845f2cb76c57486ef150be",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json": "3b1e214f466ffedff74baa5598ad5c4421130eea6bc8d57b8fe23435e8280ae4",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png": "b79d8b2c3ff321af5bbfed756f843234fb98d4d7c0cf9109b2fbea183b29413d",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png": "186ee5943cba56e68615de3de410d8813b81fa175deb9abcc0d9b8b8cd2a97e0",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png": "b3af1ab701c34e7d35bfc348ef7b4720eee4182b1f2a795bd70cc5d336357541",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png": "fb3628fe0d573ea189dec5fb2354524c0a4f31e0876fee64c0085f6351264f0e",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png": "1200ad5ae52d5b1991116bb323f64dfa3efc4a2d4ffd91a493d57d92386f54a9",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png": "116e7257b5e5cdb81a86704db37b584a8ebee07ab84d424b495d5bb9c36c1a86",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png": "7b226f834d9aedf30c1f07b742a9aa4793c89afaa9f3f953480b764380ad85af",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png": "b3af1ab701c34e7d35bfc348ef7b4720eee4182b1f2a795bd70cc5d336357541",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png": "b2ccd91bc44810cdf5ddc2094e597a49a7eab2a8563593aa8b2e00e85c643d17",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png": "9bde3a24f31c602e5ad759d12ca861525163258d3ef368dc9c0aac71a9bd4bed",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png": "9bde3a24f31c602e5ad759d12ca861525163258d3ef368dc9c0aac71a9bd4bed",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png": "ef6f852849fe7d6ccefa6928548df05e1b20afefa73fa2182e3816bff6a89154",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png": "4b03895eb0e1db9b6cf7ebd467a34383315e68aa8b5b63ed3a5e51f7fe70a138",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png": "31c6e6724a648c4aebdfee9d50a90fb8fbc2e0f5833912967a889893504b8818",
   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png": "07fa68c82a6a71f0dfaa70f7a6b49bcd13cf9c595594ab49f35bda799f0db153",
   "ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/CitizenLaunchLogo.png": "b7ce607af0ecd513fababdda9831aa3056cb99e3fd45234bea7ef4d0de9c88aa",
   "ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/CitizenLaunchLogo@2x.png": "9188e7f70e8a492d2bd3af021f1f2be7688e64d3bebc317d88f2ad1a169c2432",
   "ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/CitizenLaunchLogo@3x.png": "34a50a60d559d09fdd1037fad391ad62b242c842f6845f2cb76c57486ef150be",
   "ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/Contents.json": "1f9acec06f02258e719a8e3d1895b2b06111f2b21063f598d00bf875ffa52fb3"
};
   for(const [name,hash] of Object.entries(expected))assert.equal(createHash('sha256').update(readFileSync(join(destination,name))).digest('hex'),hash,name);
   const catalog=JSON.parse(readFileSync(join(destination,'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json')));
   for(const image of catalog.images){
    const bytes=readFileSync(join(destination,'ios/Runner/Assets.xcassets/AppIcon.appiconset',image.filename));
    const size=Number(image.size.split('x')[0])*Number(image.scale.replace('x',''));
    assert.equal(bytes.readUInt32BE(16),size);assert.equal(bytes.readUInt32BE(20),size);
   }
   for(const density of ['mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi'])assert.deepEqual(readFileSync(join(destination,'android/app/src/main/res/mipmap-'+density+'/ic_launcher.png')),readFileSync(join(destination,'android/app/src/main/res/mipmap-'+density+'/ic_launcher_round.png')));
  }finally{rmSync(destination,{recursive:true,force:true});}
 });
 test('Logo唯一目录拒绝缺失、额外文件、链接及原生重复副本',()=>{
  const work=join(temporaryRoot(),'logo-contract-'+randomBytes(8).toString('hex'));
  mkdirSync(work,{mode:0o700});
  try{
   for(const mode of ['valid','missing','extra','link','platform']){
    const product=join(work,mode);mkdirSync(join(product,'scripts'),{recursive:true,mode:0o700});
    for(const name of ['scripts/build.mjs','ios/platform.mjs','android/platform.mjs',...Object.keys(JSON.parse(LOGO_ASSETS_SOURCE).files)]){
     const destination=join(product,name);mkdirSync(dirname(destination),{recursive:true,mode:0o700});copyFixture(join(root,name),destination);
    }
    const image=join(product,'assets/logo/icon20.png');
    if(mode==='missing')unlinkSync(image);
    if(mode==='extra')copyFixture(image,join(product,'assets/logo/extra.png'));
    if(mode==='link'){unlinkSync(image);symlinkSync(join(root,'assets/logo/icon20.png'),image);}
    if(mode==='platform')copyFixture(image,join(product,'android/residual.png'));
    const result=spawnSync(process.execPath,[join(product,'scripts/build.mjs'),'logos'],{encoding:'utf8'});
    if(mode==='valid')assert.equal(result.status,0,result.stderr);else assert.notEqual(result.status,0,mode);
   }
  }finally{removeFixture(work,{recursive:true,force:true});}
 });
});


// 本产品公开GitHub接口只使用普通参数与返回值；平台流程及终态处理归本仓。
const automationWorkflows=Object.freeze({'ios':'ios.yml','android':'android.yml'});
const automationRepository='crcfrcn/citizenapp';
const automationTransport=new (await import('node:async_hooks')).AsyncLocalStorage();
function automationRoute(route,action){
 const workflow=automationWorkflows[route?.platform];
 if(!workflow||route.repository!=='citizenapp'||route.product!=='citizenapp'
  ||route.workflow!==workflow||route.canonicalId!==`citizenapp.${route.platform}.release`
  )
  throw Error('公民App自动化目标或授权动作不匹配');
 return workflow;
}

async function automationRequest(path,token,{method='GET',body}={}){
 const reads=/^(?:actions\/workflows\/(?:ios\.yml|android\.yml)\/runs\?branch=main&event=workflow_dispatch&per_page=100&page=[1-9]\d*|actions\/runs\/[1-9]\d*(?:\/jobs(?:\?per_page=100&page=[1-9]\d*)?)?|actions\/caches\?per_page=100&page=[1-9]\d*|releases(?:\?per_page=100&page=[1-9]\d*|\/[1-9]\d*)|git\/ref\/tags\/[^/?#]+)$/u;
 const writes=/^actions\/(?:workflows\/(?:ios\.yml|android\.yml)\/dispatches|runs\/[1-9]\d*\/(?:cancel|force-cancel))$/u;
 const deletes=/^(?:actions\/(?:runs|caches)\/[1-9]\d*|releases\/[1-9]\d*|git\/refs\/tags\/[^/?#]+)$/u;
 if(!(method==='GET'&&reads.test(path)||method==='POST'&&writes.test(path)||method==='DELETE'&&deletes.test(path)))
  throw Error('公民App GitHub 请求目标无效');
 const response=await (automationTransport.getStore()?.fetchImpl??fetch)(`https://api.github.com/repos/${automationRepository}/${path}`,{
  method,redirect:'error',credentials:'omit',headers:{Authorization:`Bearer ${token}`,
   Accept:'application/vnd.github+json','Content-Type':'application/json','X-GitHub-Api-Version':'2026-03-10'},
  ...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(30000)});
 if(!response.ok)throw Error(`公民App GitHub 请求失败：HTTP ${response.status}`);
 if(response.status===202||response.status===204)return {};
 if(!response.body)throw Error('公民App GitHub 回执缺失');
 let size=0;const chunks=[];
 for await(const chunk of response.body){size+=chunk.length;if(size>8*1024*1024)throw Error('公民App GitHub 回执超限');chunks.push(chunk);}
 return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(chunks)));
}
async function automationPages(path,field,token){
 const records=[];for(let page=1;page<=10000;page++){const result=await automationRequest(path+(path.includes('?')?'&':'?')+'per_page=100&page='+page,token),values=field?result?.[field]:result;if(!Array.isArray(values)||values.length>100)throw Error('公民App GitHub 分页响应无效');records.push(...values);if(values.length<100)return records;}throw Error('公民App GitHub 分页未结束');
}
function checkedHistoryRun(run,platform){
 if(!Number.isSafeInteger(run?.id)||run.id<1)throw Error('公民App历史Run编号无效');
 return automationCheckedRun(run,{repository:product,product,platform,workflow:automationWorkflows[platform],canonicalId:product+'.'+platform+'.release'},run.id);
}
function runBuildVersion(run,platform){
 const prefix='公民·'+buildPlatforms[platform].title+'·v';if(typeof run.display_title!=='string'||!run.display_title.startsWith(prefix))throw Error('公民App成功Run缺少准确平台版本');
 const version=checkedBuildVersion(run.display_title.slice(prefix.length));if(run.display_title!==buildDisplayName(platform,version))throw Error('公民App Run版本名称不符');return version;
}
export async function automationVersionPlan(platform,token,{currentRunId}={}){
 if(!buildPlatforms[platform]||typeof token!=='string'||!token)throw Error('公民App版本计划参数无效');
 const runs=await automationPages('actions/workflows/'+automationWorkflows[platform]+'/runs?branch=main&event=workflow_dispatch','workflow_runs',token);
 runs.forEach(run=>checkedHistoryRun(run,platform));
 const active=runs.filter(run=>run.status!=='completed'&&String(run.id)!==String(currentRunId));if(active.length)throw Error('公民App本平台自动化仍在运行，禁止重复派发');
 const successes=runs.filter(run=>run.status==='completed'&&run.conclusion==='success'&&String(run.id)!==String(currentRunId)).sort((a,b)=>b.id-a.id);
 const previous=successes[0],lastVersion=previous?runBuildVersion(previous,platform):buildPlatforms[platform].initialVersion;
 const releases=await automationPages('releases',null,token),owned=releases.map(release=>({release,proof:compiledReleaseProof(release,platform)})).filter(value=>value.proof);
 if(previous){
  const matched=owned.filter(value=>value.proof.run_id===previous.id&&value.proof.run_attempt===previous.run_attempt&&!value.release.draft&&!value.release.prerelease);
  if(matched.length!==1)throw Error('公民App成功版本缺少唯一正式版证明');await verifyCompletedRelease(previous,platform,matched[0],token);
 }else for(const value of owned){
  if(value.release.draft||value.release.prerelease||String(value.proof.run_id)===String(currentRunId))continue;
  const owner=checkedHistoryRun(await automationRequest('actions/runs/'+value.proof.run_id,token),platform);
  if(owner.status!=='completed'||owner.conclusion==='success')throw Error('公民App历史成功依据不完整，禁止重置版本');
 }
 const terminal=runs.filter(run=>run.status==='completed'&&String(run.id)!==String(currentRunId)).sort((a,b)=>b.id-a.id)[0];
 return {schema:1,product_id:product,platform,last_version:lastVersion,version:nextBuildVersion(lastVersion),previous_run_id:previous?.id??null,latest_run_id:terminal?.id??null};
}
export function compiledReleaseProof(release,platform){
 if(!release||!Number.isSafeInteger(release.id)||release.id<1||typeof release.body!=='string')return null;
 const match=/^<!-- automation:(\{[^\n]+\}) -->\s*$/u.exec(release.body.trim());if(!match)return null;let proof;try{proof=JSON.parse(match[1]);}catch{return null;}
 if(proof.schema!==1||proof.repository!==automationRepository||proof.product_id!==product||proof.platform!==platform||proof.workflow!=='.github/workflows/'+automationWorkflows[platform]
  ||!Number.isSafeInteger(proof.run_id)||proof.run_id<1||!Number.isSafeInteger(proof.run_attempt)||proof.run_attempt<1||!/^[a-f0-9]{40}$/u.test(proof.source_sha||'')
  ||proof.tag!==release.tag_name||release.tag_name!==buildDisplayName(platform,proof.version)||release.name!==release.tag_name||release.target_commitish!==proof.source_sha)return null;
 return proof;
}
async function deleteOwnedRelease(release,platform,token){
 const fresh=await automationRequest('releases/'+release.id,token),proof=compiledReleaseProof(fresh,platform);
 if(!proof||fresh.tag_name!==release.tag_name)throw Error('公民App正式版清理归属变化');
 const tag=await optionalAutomationRead('git/ref/tags/'+encodeURIComponent(fresh.tag_name),token);
 if(tag){if(tag.ref!=='refs/tags/'+fresh.tag_name||tag.object?.type!=='commit'||tag.object.sha!==proof.source_sha)throw Error('公民App待删除Tag归属变化');await automationRequest('git/refs/tags/'+encodeURIComponent(fresh.tag_name),token,{method:'DELETE'});}
 const confirmed=await automationRequest('releases/'+fresh.id,token);if(JSON.stringify(compiledReleaseProof(confirmed,platform))!==JSON.stringify(proof)||confirmed.tag_name!==fresh.tag_name)throw Error('公民App正式版删除前归属变化');
 await automationRequest('releases/'+fresh.id,token,{method:'DELETE'});
}
async function optionalAutomationRead(path,token){
 try{return await automationRequest(path,token);}catch(error){if(error.message.endsWith('HTTP 404'))return null;throw error;}
}
async function verifyCompletedRelease(run,platform,value,token){
 const {release,proof}=value,version=runBuildVersion(run,platform),title=buildDisplayName(platform,version);
 if(proof.run_id!==run.id||proof.run_attempt!==run.run_attempt||proof.run_number!==run.run_number||proof.source_sha!==run.head_sha||proof.version!==version||release.draft||release.prerelease||!release.published_at||!Array.isArray(proof.assets)||!Array.isArray(release.assets))throw Error('公民App成功Run正式版证明不符');
 const names=(platform==='ios'?['.ipa','.json']:['.apk','.aab','.json']).map(extension=>title+extension);
 if(proof.assets.length!==names.length||release.assets.length!==names.length)throw Error('公民App正式资产集合不符');
 for(const name of names){
  const local=proof.assets.filter(item=>item.name===name),remote=release.assets.filter(item=>item.label===name);
  if(local.length!==1||remote.length!==1||!Number.isSafeInteger(local[0].size)||local[0].size<1||!/^[a-f0-9]{64}$/u.test(local[0].sha256||'')||!Number.isSafeInteger(remote[0].id)||remote[0].id<1||remote[0].state!=='uploaded'||remote[0].size!==local[0].size||remote[0].digest!=='sha256:'+local[0].sha256)throw Error('公民App正式资产回执不符');
 }
 const tag=await automationRequest('git/ref/tags/'+encodeURIComponent(title),token);
 if(tag.ref!=='refs/tags/'+title||tag.object?.type!=='commit'||tag.object.sha!==run.head_sha)throw Error('公民App正式Tag提交不符');
}
// Run外完成入口只按真实终态收敛；控制台观察者和产品独立CLI调用同一实现。
export async function settleCompletedAutomation(platform,runId,token){
 if(!buildPlatforms[platform]||!Number.isSafeInteger(runId)||runId<1)throw Error('公民App终态收尾参数无效');
 const current=checkedHistoryRun(await automationRequest('actions/runs/'+runId,token),platform);
 if(current.status!=='completed')throw Error('公民App Run仍在运行，禁止终态收尾');
 const runs=await automationPages('actions/workflows/'+automationWorkflows[platform]+'/runs?branch=main&event=workflow_dispatch','workflow_runs',token);runs.forEach(run=>checkedHistoryRun(run,platform));
 if(runs.some(run=>run.status!=='completed'))throw Error('公民App本平台仍有活跃Run，终态清理待恢复');
 const completed=runs.filter(run=>run.status==='completed').sort((a,b)=>b.id-a.id||b.run_attempt-a.run_attempt);
 const latest=new Map();for(const run of completed){const state=run.conclusion==='success'?'success':'failed';if(!latest.has(state))latest.set(state,run);}
 const releases=await automationPages('releases',null,token),owned=releases.map(release=>({release,proof:compiledReleaseProof(release,platform)})).filter(value=>value.proof);
 const success=latest.get('success'),failed=latest.get('failed');
 if(current.conclusion==='success'){
  const version=runBuildVersion(current,platform),matches=owned.filter(value=>value.proof.run_id===current.id&&value.proof.run_attempt===current.run_attempt&&!value.release.draft&&!value.release.prerelease);
  if(matches.length!==1||matches[0].proof.version!==version)throw Error('公民App成功Run缺少唯一已验收正式版');
 }
 const keepRelease=success?owned.filter(value=>value.proof.run_id===success.id&&value.proof.run_attempt===success.run_attempt&&!value.release.draft&&!value.release.prerelease):[];
 if(success&&keepRelease.length!==1)throw Error('公民App最新成功Run的正式版不唯一');
 if(success)await verifyCompletedRelease(success,platform,keepRelease[0],token);
 for(const value of owned)if(!keepRelease.some(keep=>keep.release.id===value.release.id)){
  const owner=runs.find(run=>run.id===value.proof.run_id);
  if(!owner||owner.status!=='completed')continue;await deleteOwnedRelease(value.release,platform,token);
 }
 // Release删除后发生中断时，仍凭未删除的真实Run身份收敛同平台孤立Tag。
 const candidates=new Map();
 for(const run of completed){
  let version;try{version=runBuildVersion(run,platform);}catch{continue;}
  const tag=buildDisplayName(platform,version);if(keepRelease.some(value=>value.release.tag_name===tag))continue;
  if(!candidates.has(tag))candidates.set(tag,new Set());candidates.get(tag).add(run.head_sha);
 }
 for(const [name,sources]of candidates){
  const tag=await optionalAutomationRead('git/ref/tags/'+encodeURIComponent(name),token);if(!tag)continue;
  if(tag.ref!=='refs/tags/'+name||tag.object?.type!=='commit'||!sources.has(tag.object.sha))throw Error('公民App待清理Tag归属不符');
  await automationRequest('git/refs/tags/'+encodeURIComponent(name),token,{method:'DELETE'});
 }
 for(const run of completed)if(run.id!==success?.id&&run.id!==failed?.id){
  const fresh=checkedHistoryRun(await automationRequest('actions/runs/'+run.id,token),platform);if(fresh.status!=='completed')throw Error('公民App待清理Run终态变化');await automationRequest('actions/runs/'+run.id,token,{method:'DELETE'});
 }
 const caches=await automationPages('actions/caches','actions_caches',token),cachePrefix='citizenapp-'+platform+'-incremental-';
 const cachePattern=new RegExp('^'+cachePrefix+'[a-f0-9]{64}-r[1-9][0-9]*-a[1-9][0-9]*$','u');
 const cacheRows=caches.filter(cache=>typeof cache.key==='string'&&cachePattern.test(cache.key)&&cache.ref==='refs/heads/main').sort((a,b)=>Date.parse(b.created_at)-Date.parse(a.created_at)||b.id-a.id);
 for(const cache of cacheRows)if(!Number.isSafeInteger(cache.id)||cache.id<1||!Number.isFinite(Date.parse(cache.created_at)))throw Error('公民App缓存身份无效');
 for(const cache of cacheRows.slice(1)){
  const fresh=(await automationPages('actions/caches','actions_caches',token)).filter(value=>value.id===cache.id);
  if(!fresh.length)continue;if(fresh.length!==1||fresh[0].key!==cache.key||fresh[0].ref!==cache.ref||fresh[0].created_at!==cache.created_at)throw Error('公民App缓存删除前归属变化');
  await automationRequest('actions/caches/'+cache.id,token,{method:'DELETE'});
 }
 let mirror={state:'not-required'};
 if(success){
  const version=runBuildVersion(success,platform);
  try{await withFixedWork('build/'+platform,async work=>{
   const previous=rememberedAutomation(work);if(previous&&previous.run_id>success.id)return;
   const record={schema:1,product_id:product,platform,repository:automationRepository,run_id:success.id,run_attempt:success.run_attempt,source_sha:success.head_sha,version};
   const file=join(work,'automation.json'),pending=file+'.pending';writeFileSync(pending,JSON.stringify(record)+'\n',{flag:'wx',mode:0o600});try{renameSync(pending,file);}finally{if(existsSync(pending))unlinkSync(pending);}
  });mirror={state:'synchronized'};}catch(error){mirror={state:'pending',reason:String(error.message).replace(/[\x00-\x1f\x7f]/gu,' ').slice(0,256)};}
 }
 return {platform,run_id:current.id,state:current.conclusion==='success'?'success':'failed',success_run_id:success?.id??null,failed_run_id:failed?.id??null,mirror};
}
function automationCheckedRun(run,route,expected){
 const workflow=automationRoute(route);
 if(!Number.isSafeInteger(run?.id)||run.id!==expected||run.path!==`.github/workflows/${workflow}`
  ||run.event!=='workflow_dispatch'||run.head_branch!=='main'
  ||run.repository?.full_name!==automationRepository||!/^[0-9a-f]{40}$/u.test(run.head_sha||'')
  ||run.html_url!==`https://github.com/${automationRepository}/actions/runs/${expected}`)
  throw Error('公民App GitHub Run 身份不符');
 return run;
}
// 本产品独立拥有此实现，通过自身公开接口执行。
export async function dispatchAutomation(platform,token,{inputs={},accepted}={}){
 const route={repository:'citizenapp',product:'citizenapp',platform,workflow:automationWorkflows[platform],canonicalId:`citizenapp.${platform}.release`};
 const workflow=automationRoute(route);
 if(typeof token!=='string'||!token||!inputs||typeof inputs!=='object'||Array.isArray(inputs))throw Error('公民App派发参数无效');
 if(Object.keys(inputs).some(key=>key!=='version'))throw Error('公民App派发含未声明输入');
 let plan=await automationVersionPlan(platform,token);if(inputs.version!==undefined&&inputs.version!==plan.version)throw Error('公民App派发版本已变化');
 // 先收敛上次真实终态，失败候选Tag/草稿不能拖到新一轮编译结束才暴露冲突。
 if(plan.latest_run_id){
  const settled=await settleCompletedAutomation(platform,plan.latest_run_id,token);if(settled.mirror?.state==='pending')throw Error('公民App上轮成功镜像同步待恢复，尚未派发');
  const fresh=await automationVersionPlan(platform,token);if(fresh.version!==plan.version)throw Error('公民App收尾期间版本已变化');plan=fresh;
 }
 const sdkSelection=await selectReleaseSdkInputs(token);
 const value=await automationRequest(`actions/workflows/${workflow}/dispatches`,token,{method:'POST',body:{ref:'main',inputs:{version:plan.version,sdk_selection:JSON.stringify(sdkSelection)}}});
 if(!Number.isSafeInteger(value.workflow_run_id)||value.workflow_run_id<1
  ||value.html_url!==`https://github.com/${automationRepository}/actions/runs/${value.workflow_run_id}`)
  throw Error('公民App派发未返回准确 Run，禁止再次派发');
 await accepted?.({...value,version:plan.version});
 const run=automationCheckedRun(await automationRequest(`actions/runs/${value.workflow_run_id}`,token),route,value.workflow_run_id);
 if(run.display_title!==buildDisplayName(platform,plan.version))throw Error('公民App派发Run版本回读不符');
 return run;
}
// 独立客户端保持观察到真实终态，再调用相同收尾；只派发不是完整自动化。
export async function runAutomation(platform,token,{runId,inputs={},accepted,report=()=>{},pause=()=>new Promise(resolve=>setTimeout(resolve,5000))}={}){
 let run=runId?checkedHistoryRun(await automationRequest('actions/runs/'+runId,token),platform):await dispatchAutomation(platform,token,{inputs,accepted});
 const source=run.head_sha;let previous='';
 while(true){
  if(run.head_sha!==source)throw Error('公民App观察中的Run提交身份变化');
  const state=run.status==='completed'?run.conclusion:run.status;if(state!==previous){report({run_id:run.id,state});previous=state;}
  if(run.status==='completed'){const result=await settleCompletedAutomation(platform,run.id,token);return {...result,source_sha:source};}
  await pause();run=checkedHistoryRun(await automationRequest('actions/runs/'+run.id,token),platform);
 }
}
// 只读取当前 Run 的 Job 与终态日志，日志和下载均有限额，令牌不进入任务输出。
function automationSafeText(value,token){
 return String(value??'').split(token).join('[已脱敏]').replace(/gh[sopur]_[A-Za-z0-9_]+/gu,'[已脱敏]').slice(0,4000);
}
async function automationJobs(runId,token){
 const jobs=[];
 for(let page=1;page<=50;page++){
  const value=await automationRequest(`actions/runs/${runId}/jobs?per_page=100&page=${page}`,token);
  if(!Array.isArray(value?.jobs))throw Error('GitHub Job 分页响应无效');
  jobs.push(...value.jobs);if(value.jobs.length<100)return jobs;
 }
 throw Error('GitHub Job 页数超限');
}
async function automationLogArchive(bytes){
 if(!Buffer.isBuffer(bytes)||bytes.length>32*1024*1024)throw Error('GitHub 日志归档超限');
 const {inflateRawSync}=await import('node:zlib');let end=-1;
 for(let at=bytes.length-22;at>=Math.max(0,bytes.length-65558);at--){
  if(bytes.readUInt32LE(at)===0x06054b50){end=at;break;}
 }
 if(end<0)throw Error('GitHub 日志 ZIP 结构无效');
 const count=bytes.readUInt16LE(end+10);let offset=bytes.readUInt32LE(end+16),total=0;
 if(count>2000)throw Error('GitHub 日志文件数超限');
 const files=[];
 for(let index=0;index<count;index++){
  if(offset+46>bytes.length||bytes.readUInt32LE(offset)!==0x02014b50)throw Error('GitHub 日志目录损坏');
  const flags=bytes.readUInt16LE(offset+8),method=bytes.readUInt16LE(offset+10),packed=bytes.readUInt32LE(offset+20),size=bytes.readUInt32LE(offset+24);
  const nameLength=bytes.readUInt16LE(offset+28),extra=bytes.readUInt16LE(offset+30),comment=bytes.readUInt16LE(offset+32),local=bytes.readUInt32LE(offset+42);
  const name=bytes.subarray(offset+46,offset+46+nameLength).toString('utf8');offset+=46+nameLength+extra+comment;
  if(flags&1||![0,8].includes(method)||local+30>bytes.length||bytes.readUInt32LE(local)!==0x04034b50)throw Error('GitHub 日志压缩格式无效');
  total+=size;if(size>32*1024*1024||total>128*1024*1024)throw Error('GitHub 解压日志超限');
  const start=local+30+bytes.readUInt16LE(local+26)+bytes.readUInt16LE(local+28);
  if(start+packed>bytes.length)throw Error('GitHub 日志内容越界');
  const data=method===0?bytes.subarray(start,start+packed):inflateRawSync(bytes.subarray(start,start+packed),{maxOutputLength:size});
  if(data.length!==size)throw Error('GitHub 日志大小不一致');
  if(name.endsWith('.txt'))files.push({name,text:data.toString('utf8')});
 }
 return files;
}
async function automationReadLogs(runId,token){
 const response=await (automationTransport.getStore()?.fetchImpl??fetch)(`https://api.github.com/repos/${automationRepository}/actions/runs/${runId}/logs`,{
  redirect:'manual',credentials:'omit',headers:{Authorization:`Bearer ${token}`,Accept:'application/vnd.github+json',
   'X-GitHub-Api-Version':'2026-03-10'},signal:AbortSignal.timeout(30000)});
 if(response.status===404)return [];
 let download=response;
 if(response.status===302){
  const location=new URL(response.headers.get('location'));
  if(location.protocol!=='https:'||location.username||location.password)throw Error('GitHub 日志地址无效');
  download=await (automationTransport.getStore()?.fetchImpl??fetch)(location.href,{redirect:'error',credentials:'omit',signal:AbortSignal.timeout(60000)});
 }
 if(!download.ok||!download.body)throw Error('GitHub 日志读取失败');
 let size=0;const parts=[];
 for await(const part of download.body){size+=part.length;if(size>32*1024*1024)throw Error('GitHub 日志下载超限');parts.push(part);}
 return automationLogArchive(Buffer.concat(parts));
}








// 本产品自动化合成回归：所有网络与授权均由夹具替代，不触发真实流程。
if(inlineTestEntry)inlineTestRegistrations.push(async()=>{
 const {test}=await import('node:test'),{default:assert}=await import('node:assert/strict');
 const platform=Object.keys(automationWorkflows)[0],workflow=automationWorkflows[platform];
 const route={repository:'citizenapp',product:'citizenapp',platform,workflow,canonicalId:`citizenapp.${platform}.release`,title:'测试自动化'};
 const action={id:route.canonicalId,canonicalId:route.canonicalId,platform,productId:'citizenapp',flow:'release',authorizationLevel:2};
 const token='ghs_fixture',sha='a'.repeat(40),runId=123;
 const run=(conclusion='success',status='completed')=>({id:runId,run_number:7,run_attempt:1,
  path:`.github/workflows/${workflow}`,event:'workflow_dispatch',head_branch:'main',head_sha:sha,
  repository:{full_name:automationRepository},status,conclusion,
  html_url:`https://github.com/${automationRepository}/actions/runs/${runId}`});
 const json=value=>Response.json(value),empty=status=>new Response(null,{status});



 test('citizenapp 自动化拒绝错误仓库、平台和提交身份',()=>{
  assert.throws(()=>automationRoute({...route,repository:'other'}),/目标/u);
  assert.throws(()=>automationRoute({...route,platform:'other'}),/目标/u);
  assert.throws(()=>automationCheckedRun({...run(),head_sha:'bad'},route,runId),/身份/u);
  assert.throws(()=>automationCheckedRun({...run(),repository:{full_name:'other/repo'}},route,runId),/身份/u);
 });



});

// 外部调用方使用普通参数和返回值；此公开接口不接收任务宿主。
export const automationClient=Object.freeze({automationWorkflows,automationRepository,automationTransport,automationRoute,automationRequest,automationCheckedRun,dispatchAutomation,automationVersionPlan,settleCompletedAutomation,automationSafeText,automationJobs,automationLogArchive,automationReadLogs});

// 合成回归只在本文件作为测试入口时注册；普通导入不要求调度器、其它仓库或外部服务。
if(process.env.NODE_TEST_CONTEXT&&process.argv.length===2&&process.argv[1]===import.meta.filename)inlineTestRegistrations.push(async()=>{
 const {test}=await import('node:test'),{default:assert}=await import('node:assert/strict');
 const historyRun=(platform,id,conclusion,version)=>({id,run_number:id,run_attempt:1,path:'.github/workflows/'+platform+'.yml',event:'workflow_dispatch',head_branch:'main',head_sha:'a'.repeat(40),repository:{full_name:automationRepository},status:'completed',conclusion,display_title:buildDisplayName(platform,version),html_url:'https://github.com/'+automationRepository+'/actions/runs/'+id});
 function historyRelease(run,platform='ios'){
  const title=run.display_title,assets=(platform==='ios'?['.ipa','.json']:['.apk','.aab','.json']).map((extension,index)=>({name:title+extension,size:10+index,sha256:String(index+1).repeat(64)}));
  const proof={schema:1,repository:automationRepository,product_id:product,platform,workflow:run.path,run_id:run.id,run_attempt:run.run_attempt,run_number:run.run_number,source_sha:run.head_sha,version:runBuildVersion(run,platform),tag:title,assets};
  return {id:run.id+100,name:title,tag_name:title,target_commitish:run.head_sha,body:'<!-- automation:'+JSON.stringify(proof)+' -->',draft:false,prerelease:false,published_at:'2026-10-17T00:00:00Z',assets:assets.map((item,index)=>({id:run.id*10+index,name:'transport-'+index,label:item.name,size:item.size,state:'uploaded',digest:'sha256:'+item.sha256}))};
 }
 function historyFixture(){
  const runs=[historyRun('ios',70,'success','1.0.0'),historyRun('ios',71,'success','1.0.1'),historyRun('ios',72,'failure','1.0.2'),historyRun('ios',73,'cancelled','1.0.2')],mutations=[],tags=new Map();
  const release=run=>{const value=historyRelease(run);tags.set(value.tag_name,{ref:'refs/tags/'+value.tag_name,object:{type:'commit',sha:run.head_sha}});return value;};
  const releases=[release(runs[0]),release(runs[1]),{id:999,name:'other-product',tag_name:'other-product',body:'not ours',draft:false}],identity='c'.repeat(64),cachePrefix='citizenapp-ios-incremental-';
  const caches=[{id:801,key:cachePrefix+identity+'-r70-a1',ref:'refs/heads/main',created_at:'2026-10-17T00:00:00Z'},{id:802,key:cachePrefix+identity+'-r71-a1',ref:'refs/heads/main',created_at:'2026-10-17T01:00:00Z'},{id:803,key:'citizenapp-android-incremental-'+identity+'-r74-a1',ref:'refs/heads/main',created_at:'2026-10-17T02:00:00Z'}];
  let drift=false;
  const fetchImpl=async(url,options={})=>{
   const path=decodeURIComponent(new URL(url).pathname.replace('/repos/'+automationRepository+'/','')),method=options.method||'GET';
   if(method==='DELETE'){
    mutations.push(path);
    if(path.startsWith('releases/')){const index=releases.findIndex(item=>item.id===Number(path.split('/').at(-1)));assert.ok(index>=0);releases.splice(index,1);}
    else if(path.startsWith('actions/runs/')){const index=runs.findIndex(item=>item.id===Number(path.split('/').at(-1)));assert.ok(index>=0);runs.splice(index,1);}
    else if(path.startsWith('actions/caches/')){const index=caches.findIndex(item=>item.id===Number(path.split('/').at(-1)));assert.ok(index>=0);caches.splice(index,1);}
    else if(path.startsWith('git/refs/tags/'))assert.equal(tags.delete(path.slice('git/refs/tags/'.length)),true);
    else assert.fail('未知删除入口');return new Response(null,{status:204});
   }
   assert.equal(method,'GET');
   if(path==='actions/workflows/ios.yml/runs')return Response.json({workflow_runs:runs});
   if(/^actions\/runs\/\d+$/u.test(path)){const run=runs.find(item=>item.id===Number(path.split('/').at(-1)));return run?Response.json(run):new Response(null,{status:404});}
   if(path==='releases')return Response.json(releases);
   if(/^releases\/\d+$/u.test(path)){const item=releases.find(value=>value.id===Number(path.split('/').at(-1)));return Response.json(drift?{...item,target_commitish:'b'.repeat(40)}:item);}
   if(path.startsWith('git/ref/tags/')){const tag=tags.get(path.slice('git/ref/tags/'.length));return tag?Response.json(tag):new Response(null,{status:404});}
   if(path==='actions/caches')return Response.json({actions_caches:caches});assert.fail('未知读取入口：'+path);
  };
  return {runs,releases,caches,tags,mutations,fetchImpl,drift:()=>{drift=true;}};
 }
 test('平台成功版本递增，失败重试不消耗且活跃或异仓事实拒绝',async()=>{
  let rows=[];const fetchImpl=async url=>{
   const path=decodeURIComponent(new URL(url).pathname);
   if(path.endsWith('/runs'))return Response.json({workflow_runs:rows});
   if(path.endsWith('/releases'))return Response.json(rows.filter(run=>run.conclusion==='success').map(run=>historyRelease(run)));
   if(path.includes('/git/ref/tags/'))return Response.json({ref:'refs/tags/'+path.split('/git/ref/tags/')[1],object:{type:'commit',sha:'a'.repeat(40)}});
   assert.fail('版本夹具未知读取：'+path);
  };
  await automationTransport.run({fetchImpl},async()=>{
   assert.equal((await automationVersionPlan('ios','fixture')).version,'1.0.1');
   rows=[historyRun('ios',10,'success','1.0.8'),historyRun('ios',11,'failure','1.0.9')];assert.equal((await automationVersionPlan('ios','fixture')).version,'1.0.9');
   rows[1].status='in_progress';await assert.rejects(automationVersionPlan('ios','fixture'),/仍在运行/);assert.equal((await automationVersionPlan('ios','fixture',{currentRunId:11})).version,'1.0.9');
   rows=[{...historyRun('ios',12,'success','1.0.9'),repository:{full_name:'other/repo'}}];await assert.rejects(automationVersionPlan('ios','fixture'),/身份/);
   rows=[{...historyRun('ios',12,'success','1.0.9'),display_title:'公民·Android·v1.0.9'}];await assert.rejects(automationVersionPlan('ios','fixture'),/准确平台版本/);
  });
 });
 test('真实终态仅留最新成功失败、正式版和缓存，重复收尾不重复计版且不删其它归属',async()=>{
  const f=historyFixture(),work=fixedWork('build/ios');
  try{await automationTransport.run({fetchImpl:f.fetchImpl},async()=>{
   const value=await settleCompletedAutomation('ios',73,'fixture');assert.equal(value.state,'failed');assert.deepEqual(f.runs.map(run=>run.id),[71,73]);assert.deepEqual(f.releases.map(item=>item.id),[171,999]);assert.deepEqual(f.caches.map(item=>item.id),[802,803]);
   assert.equal(rememberedAutomation(work).version,'1.0.1');const count=f.mutations.length;
   await settleCompletedAutomation('ios',73,'fixture');assert.equal(f.mutations.length,count);assert.equal(rememberedAutomation(work).run_id,71);
  });}finally{if(existsSync(work))rmSync(work,{recursive:true});}
 });
 test('活跃Run、正式资产变更、Tag漂移和删除前归属变化均失败关闭',async()=>{
  for(const mode of ['active','asset','tag','drift']){
   const f=historyFixture();if(mode==='active')f.runs.push({...historyRun('ios',74,'failure','1.0.2'),status:'queued'});
   if(mode==='asset')f.releases[1].assets[0].digest='sha256:'+'f'.repeat(64);
   if(mode==='tag')f.tags.get('公民·iOS·v1.0.1').object.sha='b'.repeat(40);if(mode==='drift')f.drift();
   await automationTransport.run({fetchImpl:f.fetchImpl},()=>assert.rejects(settleCompletedAutomation('ios',73,'fixture'),/活跃|资产|Tag|归属/));assert.deepEqual(f.mutations,[]);
  }
 });
 test('成功版本必须有完整正式证明，失败包不占号且遗失历史不重置',async()=>{
  for(const mode of ['missing','duplicate','asset','tag','lost']){
   const f=historyFixture();
   if(mode==='missing')f.releases.splice(1,1);
   if(mode==='duplicate')f.releases.push({...f.releases[1],id:777});
   if(mode==='asset')f.releases[1].assets[0].digest='sha256:'+'f'.repeat(64);
   if(mode==='tag')f.tags.get('公民·iOS·v1.0.1').object.sha='b'.repeat(40);
   if(mode==='lost')f.runs.splice(0,2);
   await automationTransport.run({fetchImpl:f.fetchImpl},()=>assert.rejects(automationVersionPlan('ios','fixture'),/证明|资产|Tag|404|历史/));assert.deepEqual(f.mutations,[]);
  }
  const f=historyFixture();f.runs.splice(0,2);f.releases.splice(0,2);f.runs[0].display_title=buildDisplayName('ios','1.0.1');f.releases.push(historyRelease(f.runs[0]));
  await automationTransport.run({fetchImpl:f.fetchImpl},async()=>assert.equal((await automationVersionPlan('ios','fixture')).version,'1.0.1'));
 });
 test('旧Tag漂移拒绝删除，Tag已删但Release未删允许原事务恢复',async()=>{
  const bad=historyFixture();bad.tags.get('公民·iOS·v1.0.0').object.sha='b'.repeat(40);
  await automationTransport.run({fetchImpl:bad.fetchImpl},()=>assert.rejects(settleCompletedAutomation('ios',73,'fixture'),/Tag.*归属/));assert.deepEqual(bad.mutations,[]);
  const f=historyFixture(),work=fixedWork('build/ios');f.tags.delete('公民·iOS·v1.0.0');
  try{await automationTransport.run({fetchImpl:f.fetchImpl},()=>settleCompletedAutomation('ios',73,'fixture'));assert.deepEqual(f.releases.map(value=>value.id),[171,999]);}finally{if(existsSync(work))rmSync(work,{recursive:true});}
 });
 test('远端收尾不因本机占用丢失，镜像待同步后可恢复且不重复删除',async()=>{
  const f=historyFixture(),work=fixedWork('build/ios');
  try{await automationTransport.run({fetchImpl:f.fetchImpl},async()=>{
   let entered,release;const ready=new Promise(resolve=>{entered=resolve;}),hold=new Promise(resolve=>{release=resolve;});
   const holder=withFixedWork('build/ios',async()=>{entered();await hold;});await ready;
   try{const value=await settleCompletedAutomation('ios',73,'fixture');assert.equal(value.mirror.state,'pending');assert.equal(value.state,'failed');}finally{release();await holder;}
   const count=f.mutations.length,value=await settleCompletedAutomation('ios',73,'fixture');assert.equal(value.mirror.state,'synchronized');assert.equal(f.mutations.length,count);assert.equal(rememberedAutomation(work).run_id,71);
  });}finally{if(existsSync(work))rmSync(work,{recursive:true});}
 });
 test('缓存只清理准确平台坐标并拒绝删除前身份漂移',async()=>{
  for(const drift of [false,true]){
   const f=historyFixture(),work=fixedWork('build/ios');f.caches.push({id:900,key:'citizenapp-ios-incremental-foreign',ref:'refs/heads/main',created_at:'2026-10-18T00:00:00Z'});let reads=0;
   const fetchImpl=async(url,options)=>{if(new URL(url).pathname.endsWith('/actions/caches')){reads++;if(drift&&reads===2)f.caches[0].key='foreign-cache';}return f.fetchImpl(url,options);};
   try{await automationTransport.run({fetchImpl},async()=>{if(drift)await assert.rejects(settleCompletedAutomation('ios',73,'fixture'),/缓存删除前归属/);else await settleCompletedAutomation('ios',73,'fixture');});assert.ok(f.caches.some(value=>value.id===900));if(drift)assert.ok(!f.mutations.includes('actions/caches/801'));}finally{if(existsSync(work))rmSync(work,{recursive:true});}
  }
 });
 // SDK回归只使用合成正式版事实，不读取本机SDK，不访问网络。
 const sdkReleaseFixture=()=>checkedSdkSelection({schema:1,product_id:product,mode:'release',sources:Object.entries(sdkRepositories).map(([name,url],index)=>({name,url,ref:String(index+1).repeat(40),release_id:index+101,tag:'v1.0.0'}))});
 const sdkFixtureResponse=(url,options={})=>{
  const address=new URL(url),source=sdkReleaseFixture().sources.find(item=>address.pathname.startsWith('/repos/'+new URL(item.url).pathname.slice(1,-4)+'/'));
  if(!source)return null;assert.equal(address.protocol,'https:');assert.equal(options.redirect,'error');assert.equal(options.credentials,'omit');
  if(/\/releases\/(?:latest|[1-9]\d*)$/u.test(address.pathname))return Response.json({id:source.release_id,tag_name:source.tag,draft:false,prerelease:false,published_at:'2026-10-17T00:00:00Z',html_url:source.url.slice(0,-4)+'/releases/tag/'+source.tag});
  if(address.pathname.includes('/git/ref/tags/'))return Response.json({ref:'refs/tags/'+source.tag,object:{type:'commit',sha:source.ref}});
  throw Error('未声明SDK合成请求');
 };
 test('链测试Git诊断保留原安全参数、返回值与失败，未知正文不进入日志',()=>{
  const records=[],marker='synthetic-diagnostic-marker',root='/synthetic/input',args=['fetch','--no-tags','--depth=1','origin','a'.repeat(40)];
  const common={environment:{PATH:'/synthetic/bin'},report:record=>records.push(record)};
  const success=runTestInputGit(root,args,{...common,spawnGit:(command,passed,options)=>{
   assert.equal(command,'git');assert.deepEqual(passed,['-c','credential.helper=','-c','core.hooksPath=/dev/null','-c','protocol.file.allow=never','-c','gc.auto=0','-C',root,...args]);
   assert.equal(options.env.GIT_TERMINAL_PROMPT,'0');assert.equal(options.env.GIT_CONFIG_NOSYSTEM,'1');assert.equal(options.env.GIT_CONFIG_GLOBAL,process.platform==='win32'?'NUL':'/dev/null');
   return {status:0,signal:null,stdout:'  original\n',stderr:marker};
  }});assert.equal(success,'original');assert.equal(records[0].step,'fetch');
  for(const [result,code]of [[{error:{cause:{code:'ETIMEDOUT'}},status:null,signal:null},'ETIMEDOUT'],[{status:128,signal:null,stderr:'fatal: Connection timed out '+marker},'ETIMEDOUT'],[{status:128,signal:null,stderr:'SSL certificate problem '+marker},'TLS_CERTIFICATE_ERROR'],[{status:128,signal:null,stderr:marker},'UNKNOWN'],[{status:null,signal:'SIGTERM',stderr:marker},'UNKNOWN']]){
   records.length=0;assert.throws(()=>runTestInputGit(root,args,{...common,spawnGit:()=>result}),/链测试源取得或验真失败/);
   assert.deepEqual(records.at(-1),{step:'fetch',exit_code:result.status,signal:result.signal||'none',code});
   assert.equal(JSON.stringify(records).includes(marker),false);assert.equal(JSON.stringify(records).includes(root),false);
  }
  const failure=Object.assign(Error(marker),{code:'ENOENT'});records.length=0;
  assert.throws(()=>runTestInputGit(root,args,{...common,spawnGit:()=>{throw failure;}}),error=>error===failure);assert.equal(records.at(-1).code,'ENOENT');
  assert.equal(runTestInputGit(root,args,{...common,report:()=>{throw Error(marker);},spawnGit:()=>({status:0,stdout:'ok'})}),'ok');
  assert.equal(testInputGitStep(['rev-parse','--absolute-git-dir']),'verify-gitdir');assert.equal(testInputGitStep([marker]),'unknown');
  assert.equal(testInputGitDiagnostic(args,{status:null,signal:marker,stderr:marker}).signal,'UNKNOWN');
 });
 test('SDK任务锁拒绝错误来源、提交、重复及本机目录，缓存绑定实际提交',()=>{
  const selection=sdkReleaseFixture();assert.deepEqual(checkedSdkSelection(selection),selection);
  for(const change of [value=>value.sources.pop(),value=>value.sources.push(value.sources[0]),value=>value.sources[0].url='http://github.com/crcfrcn/citizensdk.git',value=>value.sources[0].ref='main',value=>value.sources[0].tag='../bad',value=>value.sources[0].release_id=0,value=>value.mode='other']){
   const bad=structuredClone(selection);change(bad);assert.throws(()=>checkedSdkSelection(bad));
  }
  assert.throws(()=>checkedSdkSelection(selection,{mode:'local'}));
  const changed=structuredClone(selection);changed.sources[0].ref='a'.repeat(40);
  assert.notEqual(incrementalIdentity('ios',selection.sources),incrementalIdentity('ios',changed.sources));
  assert.equal(incrementalIdentity('ios',selection.sources),incrementalIdentity('ios',checkedSdkSelection(selection).sources));
 });
 test('本机SDK仅快照已提交HEAD，不读工作树且后续HEAD变化不改本轮锁',async()=>{
  const work=fixedWork('test'),calls=[];let head='a'.repeat(40);
  await withFixedWork('test',async()=>{
   const readGit=async(path,args)=>{
    calls.push(args.join(' '));const source=Object.entries(sdkRepositories).find(([,url])=>basename(new URL(url).pathname,'.git')===basename(path));assert.ok(source);
    if(args[0]==='remote')return source[1];
    if(args.includes('--show-toplevel'))return path;if(args.includes('--absolute-git-dir')||args.includes('--git-common-dir'))return join(path,'.git');
    assert.deepEqual(args,['rev-parse','--verify','HEAD^{commit}']);return head;
   };
   const selected=await selectLocalSdkInputs('/synthetic/git',work,{}, {readGit,inspect:()=>{}});head='b'.repeat(40);
   assert.ok(selected.sources.every(source=>source.ref==='a'.repeat(40)));assert.equal(calls.some(value=>/diff|status|reset|checkout|stash|update-ref/u.test(value)),false);
   const newer=await selectLocalSdkInputs('/synthetic/git',work,{}, {readGit,inspect:()=>{}});assert.ok(newer.sources.every(source=>source.ref===head));
   await assert.rejects(selectLocalSdkInputs('/synthetic/git',work,{}, {readGit:async()=>'/wrong',inspect:()=>{}}),/来源不符/);
   await assert.rejects(selectLocalSdkInputs('/synthetic/git',work,{}, {readGit,inspect:()=>{throw Error('链接拒绝');}}),/链接拒绝/);
   const wrong=structuredClone(selected);wrong.sources[0].local_root='/other';assert.throws(()=>checkedSdkSelection(wrong),/指定正式仓库/);
  });
 });
 test('SDK正式版选择与重试只读固定Release，Tag漂移、预发布、缺失及循环均拒绝',async()=>{
  let requests=[];const transport=async(url,options)=>{requests.push(new URL(url).pathname);return sdkFixtureResponse(url,options);};
  const selected=await automationTransport.run({fetchImpl:transport},()=>selectReleaseSdkInputs('fixture'));
  assert.deepEqual(selected,sdkReleaseFixture());assert.equal(requests.filter(path=>path.endsWith('/latest')).length,2);requests=[];
  assert.deepEqual(await automationTransport.run({fetchImpl:transport},()=>selectReleaseSdkInputs('fixture',{locked:selected})),selected);
  assert.equal(requests.some(path=>path.endsWith('/latest')),false);
  const annotated=async(url,options)=>{
   if(new URL(url).pathname.includes('/git/tags/')){const source=selected.sources.find(item=>url.includes(new URL(item.url).pathname.slice(1,-4)));return Response.json({sha:'c'.repeat(40),object:{type:'commit',sha:source.ref}});}
   const response=sdkFixtureResponse(url,options),value=await response.json();if(value.object)value.object={type:'tag',sha:'c'.repeat(40)};return Response.json(value);
  };
  assert.deepEqual(await automationTransport.run({fetchImpl:annotated},()=>selectReleaseSdkInputs('fixture',{locked:selected})),selected);
  for(const mode of ['missing','prerelease','drift','cycle','wrong-origin']){
   const fetchImpl=async(url,options)=>{
    if(mode==='cycle'&&new URL(url).pathname.includes('/git/tags/'))return Response.json({sha:'a'.repeat(40),object:{type:'tag',sha:'a'.repeat(40)}});
    const response=sdkFixtureResponse(url,options);if(mode==='missing')return new Response(null,{status:404});const value=await response.json();
    if(new URL(url).pathname.includes('/releases/')){if(mode==='prerelease')value.prerelease=true;if(mode==='wrong-origin')value.html_url='https://other.invalid/release';}
    else if(mode==='drift')value.object.sha='f'.repeat(40);
    else if(mode==='cycle')value.object={type:'tag',sha:'a'.repeat(40)};
    return Response.json(value);
   };
   await automationTransport.run({fetchImpl},()=>assert.rejects(selectReleaseSdkInputs('fixture',{locked:selected})));
  }
 });
 test('CI缓存计划独立绑定平台、工具锁与本次Run，错误身份不产生计划',()=>{
  const environment={CITIZENAPP_SDK_RELEASES:JSON.stringify(sdkReleaseFixture()),GITHUB_ACTIONS:'true',GITHUB_REPOSITORY:automationRepository,GITHUB_REF:'refs/heads/main',GITHUB_EVENT_NAME:'workflow_dispatch',GITHUB_WORKFLOW_REF:automationRepository+'/.github/workflows/ios.yml@refs/heads/main',GITHUB_SHA:'a'.repeat(40),GITHUB_RUN_ID:'71',GITHUB_RUN_ATTEMPT:'1',GITHUB_RUN_NUMBER:'7'};
  const first=ciCachePlan('ios',environment),second=ciCachePlan('ios',{...environment,GITHUB_RUN_ID:'72'});assert.equal(first.identity,second.identity);assert.notEqual(first.key,second.key);assert.equal(first.path,'target/build/ios/incremental');
  assert.throws(()=>ciCachePlan('android',environment),/身份/);assert.throws(()=>ciCachePlan('ios',{...environment,GITHUB_SHA:'invalid'}),/身份/);
 });
 test('CI正式资产按准确HTTPS端点上传并回读，错误地址、摘要和中断不发布',async()=>{
  for(const mode of ['success','endpoint','digest','interrupted']){
   const platform='ios',work=fixedWork('build/ios'),version='1.0.1',title=buildDisplayName(platform,version),environment={GITHUB_ACTIONS:'true',GITHUB_REPOSITORY:automationRepository,GITHUB_REF:'refs/heads/main',GITHUB_EVENT_NAME:'workflow_dispatch',GITHUB_WORKFLOW_REF:automationRepository+'/.github/workflows/ios.yml@refs/heads/main',GITHUB_SHA:'a'.repeat(40),GITHUB_RUN_ID:'71',GITHUB_RUN_ATTEMPT:'1',GITHUB_RUN_NUMBER:'7',GH_TOKEN:'fixture'};
   let plan,reference=null,release=null,uploads=0,publishes=0;
   try{
    await withFixedWork('build/ios',async path=>{
     const directory=join(path,'release-assets');mkdirSync(directory);
     const assets=['.ipa','.json'].map(extension=>{const name=title+extension,bytes=Buffer.from('signed-fixture'+extension);writeFileSync(join(directory,name),bytes);return {name,size:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')};});
     const notes=join(path,'release-notes.txt');writeFileSync(notes,'fixture proof\n');plan={schema:1,product_id:product,platform,version,tag:title,source_sha:environment.GITHUB_SHA,assets,directory,notes};writeFileSync(join(path,'release-plan.json'),JSON.stringify(plan));
    },{retain:true});
    const fetchImpl=async(url,options={})=>{
     const endpoint=new URL(url),path=decodeURIComponent(endpoint.pathname.replace('/repos/'+automationRepository+'/','')),method=options.method||'GET';assert.equal(endpoint.protocol,'https:');assert.equal(options.redirect,'error');assert.equal(options.headers.Authorization,'Bearer fixture');
     if(endpoint.hostname==='uploads.github.com'){
      uploads++;assert.equal(path,'releases/123/assets');assert.equal(method,'POST');if(mode==='interrupted')throw Error('fixture upload interrupted');
      const parts=[];for await(const chunk of options.body)parts.push(chunk);const bytes=Buffer.concat(parts),label=endpoint.searchParams.get('label'),asset={id:1000+uploads,name:endpoint.searchParams.get('name'),label,size:bytes.length,state:'uploaded',digest:'sha256:'+createHash('sha256').update(bytes).digest('hex')};
      assert.equal(String(bytes.length),options.headers['Content-Length']);assert.ok(plan.assets.some(item=>item.name===label));if(mode==='digest')asset.digest='sha256:'+'f'.repeat(64);release.assets.push(asset);return Response.json(asset);
     }
     assert.equal(endpoint.hostname,'api.github.com');
     if(path==='git/ref/tags/'+title)return reference?Response.json(reference):new Response(null,{status:404});
     if(path==='git/refs'&&method==='POST'){const body=JSON.parse(options.body);assert.equal(body.sha,environment.GITHUB_SHA);reference={ref:body.ref,object:{type:'commit',sha:body.sha}};return Response.json(reference);}
     if(path==='releases/tags/'+title)return release?Response.json(release):new Response(null,{status:404});
     if(path==='releases'&&method==='POST'){const body=JSON.parse(options.body);assert.equal(body.name,title);assert.equal(body.draft,true);release={...body,id:123,assets:[],upload_url:(mode==='endpoint'?'https://other.invalid/':'https://uploads.github.com/repos/'+automationRepository+'/releases/123/assets')+'{?name,label}'};return Response.json(release);}
     if(path==='releases/123'&&method==='PATCH'){publishes++;assert.deepEqual(JSON.parse(options.body),{draft:false});release.draft=false;release.published_at='2026-10-17T00:00:00Z';return Response.json(release);}
     assert.fail('未登记的CI请求：'+method+' '+path);
    };
    if(mode==='success'){const result=await ciRelease(platform,environment,{fetchImpl});assert.equal(result.tag,title);assert.equal(uploads,2);assert.equal(publishes,1);}
    else{await assert.rejects(ciRelease(platform,environment,{fetchImpl}),/地址|回读|interrupted/);assert.equal(publishes,0);if(mode==='endpoint')assert.equal(uploads,0);}
   }finally{if(existsSync(work))finishFixedWork(work);}
  }
 });
 test('再次派发前清理上次失败候选并复用版本，不先编译或重复派发',async()=>{
  const f=historyFixture(),work=fixedWork('build/ios'),failed=f.runs.at(-1),candidate=historyRelease(failed);f.releases.push(candidate);f.tags.set(candidate.tag_name,{ref:'refs/tags/'+candidate.tag_name,object:{type:'commit',sha:failed.head_sha}});let calls=0;
  const fetchImpl=async(url,options={})=>{
   const sdk=sdkFixtureResponse(url,options);if(sdk)return sdk;
   if(new URL(url).pathname.endsWith('/dispatches')){
    calls++;assert.ok(!f.releases.some(value=>value.id===candidate.id));assert.equal(f.tags.has(candidate.tag_name),false);assert.equal(JSON.parse(options.body).inputs.version,'1.0.2');
    const run={...historyRun('ios',74,'failure','1.0.2'),status:'queued'};f.runs.push(run);return Response.json({workflow_run_id:74,html_url:run.html_url});
   }return f.fetchImpl(url,options);
  };
  try{await automationTransport.run({fetchImpl},async()=>assert.equal((await dispatchAutomation('ios','fixture')).id,74));assert.equal(calls,1);}finally{if(existsSync(work))rmSync(work,{recursive:true});}
 });
 test('独立自动化接口不接收任务宿主，准确派发与错误回执只请求一次',async()=>{
  const api=automationClient,workflows=api.automationWorkflows||api.automationWorkflow;
  const platform=Object.keys(workflows)[0],workflow=workflows[platform],repository=api.automationRepository;
  const dispatch=api.dispatchAutomation||api.dispatchProductAutomation||api.dispatch;
  let dispatches=0,mode='success';
  const run={id:731,run_number:1,run_attempt:1,path:'.github/workflows/'+workflow,event:'workflow_dispatch',head_branch:'main',
   head_sha:'a'.repeat(40),repository:{full_name:repository},status:'completed',conclusion:'success',
   html_url:'https://github.com/'+repository+'/actions/runs/731',display_title:buildDisplayName(platform,'1.0.1')};
  const fetchImpl=async(url,options)=>{
   const sdk=sdkFixtureResponse(url,options);if(sdk)return sdk;
   if(new URL(url).pathname.endsWith('/runs')&&new URL(url).pathname.includes('/workflows/'))return Response.json({workflow_runs:[]});
   if(new URL(url).pathname.endsWith('/releases'))return Response.json([]);
   if(new URL(url).pathname.endsWith('/dispatches')){
    dispatches++;assert.equal(options.method,'POST');const body=JSON.parse(options.body);assert.deepEqual(JSON.parse(body.inputs.sdk_selection),sdkReleaseFixture());assert.deepEqual(Object.keys(body.inputs).sort(),['sdk_selection','version']);
    const versionBody={...body,inputs:{version:body.inputs.version}};assert.deepEqual(versionBody,{ref:'main',inputs:{version:'1.0.1'}});
    return mode==='ambiguous'?new Response(null,{status:204}):Response.json({workflow_run_id:731,html_url:run.html_url});
   }
   assert.ok(new URL(url).pathname.endsWith('/runs/731'));
   return Response.json(mode==='wrong'?{...run,head_sha:'invalid'}:run);
  };
  const invoke=()=>api.automationTransport?api.automationTransport.run({fetchImpl},()=>dispatch(platform,'fixture',{fetchImpl})):dispatch(platform,'fixture',{fetchImpl});
  assert.equal((await invoke()).id,731);assert.equal(dispatches,1);
  for(const failure of ['ambiguous','wrong']){mode=failure;dispatches=0;await assert.rejects(invoke);assert.equal(dispatches,1);}
 });
});

// 此时导出别名、资源闭包和自动化常量均已就绪；普通导入的登记清单始终为空。
for(const registerInlineTests of inlineTestRegistrations)await registerInlineTests();

// 所有模块声明及异步初始化完成后才启动CLI；普通导入和同文件回归不启动命令。
// CLI拒绝必须真实失败，不能留成未完成顶层await或输出成功回执。
if(!inlineTestEntry&&directEntry){
 void runCLI().catch(error=>{console.error(error);process.exitCode=1;});
}
