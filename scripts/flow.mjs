#!/usr/bin/env node
const directEntry = process.argv[1] === import.meta.filename && !process.execArgv.some(argument=>/^(?:-e|-p|--eval|--print)(?:=|$)/u.test(argument));
const inlineTestEntry = directEntry && Boolean(process.env.NODE_TEST_CONTEXT) && process.argv.length === 2;
// 本产品完整CI/Release入口；独立执行和宿主调用使用同一候选、派发、验真与清理实现。
import {AsyncLocalStorage} from 'node:async_hooks';
import {createHash} from 'node:crypto';
import {createReadStream,lstatSync,readFileSync,realpathSync,mkdtempSync,rmSync} from 'node:fs';
import {dirname,join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {setTimeout as delay} from 'node:timers/promises';
import {bootstrapNode} from './resources.mjs';
import {runBuildProcess,temporaryRoot} from './build.mjs';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const productID="citizenapp";
const repositoryName="crcfrcn/citizenapp";
const operation=new AsyncLocalStorage();
function sourceFile(relative) {
 if(typeof relative!=='string'||relative.startsWith('/')||relative.split('/').some(x=>!x||x==='.'||x==='..'))throw Error('产品流程源码路径无效');
 const path=join(root,relative),stat=lstatSync(path);
 if(!stat.isFile()||stat.isSymbolicLink()||stat.nlink!==1||realpathSync(path)!==path||stat.size>1024*1024)throw Error('产品流程源码必须为有界规范普通文件');
 return readFileSync(path);
}
function currentDeclaration() {
 const value=JSON.parse(sourceFile('scripts/flows.json'));
 if(value.schema!==1||value.product_id!==productID||value.flow_entry!=='scripts/flow.mjs'
  ||!Array.isArray(value.remote_routes)||value.remote_routes.length>128||!value.platforms)throw Error('产品远端流程声明无效');
 return value;
}
export function remoteContract(flow,platform) {
 if(!['ci','release'].includes(flow)||typeof platform!=='string')throw Error('产品远端流程身份无效');
 const value=currentDeclaration(),identity=productID+'.'+platform+'.'+flow;
 const rows=value.remote_routes.filter(row=>row.canonicalID===identity),row=rows[0];
 if(rows.length!==1||row.repository!==productID||row.productID!==productID||row.flow!==flow||row.platform!==platform
  ||typeof row.expectedTitle!=='string'||row.expectedTitle.length>256||/[\x00-\x1f\x7f]/u.test(row.expectedTitle)
  ||typeof row.recordsFormalRelease!=='boolean')throw Error('产品当前远端路由不唯一或越界');
 workflowDisplayTitle(row.expectedTitle,flow);
 const entry=value.platforms[platform]?.[flow]?.entry;
 if(typeof entry!=='string'||!/^\.github\/workflows\/[a-z][a-z0-9-]*\.yml$/u.test(entry))throw Error('产品Workflow入口无效');
 sourceFile(entry);
 if(flow==='ci') {
  if(row.tagPrefix!==null||row.recordsFormalRelease)throw Error('CI路由不得声明正式版本');
  return {repository:repositoryName,workflow:identity,title:row.expectedTitle};
 }
 const ci=remoteContract('ci',platform),version=value.platforms[platform].release.version_source;
 if(!version||Object.keys(version).sort().join(',')!=='kind,path')throw Error('正式版本真源声明无效');
 return checkedContract({repository:repositoryName,workflow:identity,title:row.expectedTitle,
  ciWorkflow:ci.workflow,ciTitle:ci.title,productId:productID,platform,
  tagPrefix:row.tagPrefix,sourceKind:version.kind,sourcePath:version.path});
}
function workflowFile(identity) {
 const match=/^([a-z][a-z0-9-]*)\.([a-z][a-z0-9-]*)\.(ci|release)$/u.exec(identity);
 if(!match||match[1]!==productID)throw Error('产品Workflow身份越界');
 const value=currentDeclaration(),entry=value.platforms[match[2]]?.[match[3]]?.entry;
 if(typeof entry!=='string'||!/^\.github\/workflows\/[a-z][a-z0-9-]*\.yml$/u.test(entry))throw Error('产品Workflow当前入口无效');
 return entry.slice('.github/workflows/'.length);
}
function workflowDisplayTitle(title,flow=null) {
 const parts=String(title).split(' · '),mode={CI:'ci',Release:'release'}[parts[1]];
 if(parts.length!==3||parts.some(x=>!x||x.trim()!==x)||!mode||flow!==null&&flow!==mode)throw Error('产品Workflow标题无效');
 return `${parts[0]} · ${parts[2]} · ${parts[1]}`;
}
async function boundedBody(response,maximum=16*1024*1024) {
 if(!response.body)return '';
 const reader=response.body.getReader(),chunks=[];let bytes=0;
 for(;;){const item=await reader.read();if(item.done)break;bytes+=item.value.byteLength;
  if(bytes>maximum){await reader.cancel();throw Error('产品远端响应超限');}chunks.push(item.value);}
 return Buffer.concat(chunks.map(chunk=>Buffer.from(chunk)),bytes).toString('utf8');
}
// 令牌仅进入当前仓GitHub HTTPS请求头；重定向、越仓和任何诊断响应均不进入日志。
async function apiRequest(endpoint,{token,method='GET',input='',raw=false,missing=false}={}) {
 const context=operation.getStore()||{};context.signal?.throwIfAborted();
 context.verifySource?.();
 if(typeof endpoint!=='string'||!endpoint.startsWith('repos/'+repositoryName+'/')||/[\x00-\x20\x7f]/u.test(endpoint)
  ||endpoint.includes('..')||!['GET','POST','DELETE'].includes(method))throw Error('产品GitHub请求越界');
 token=token||context.token;
 if(typeof token!=='string'||!token.startsWith('ghs_')||token.length<=4||token.length>2048||/[\s\x00-\x1f\x7f]/u.test(token))throw Error('产品GitHub临时令牌无效');
 const signal=AbortSignal.any([AbortSignal.timeout(30000),...(context.signal?[context.signal]:[])]);
 try {
  const response=await (context.fetchImpl||fetch)('https://api.github.com/'+endpoint,{method,redirect:'manual',signal,
   headers:{Authorization:'Bearer '+token,Accept:raw?'application/vnd.github.raw+json':'application/vnd.github+json',
    'Content-Type':'application/json','X-GitHub-Api-Version':'2026-03-10'},...(input?{body:input}:{})});
  if(response.status===404&&missing){await response.body?.cancel();return null;}
  if(!response.ok){await response.body?.cancel();throw Error('产品GitHub请求失败');}
  return await boundedBody(response);
 } catch { context.signal?.throwIfAborted();throw Error('产品GitHub临时权限操作失败'); }
}
async function githubRequest({token,arguments_:args,input=''}) {
 if(args[0]!=='api')throw Error('产品GitHub操作类型无效');
 let endpoint,method='GET',raw=false;
 for(let i=1;i<args.length;i++){
  if(args[i]==='--method'){method=args[++i];continue;}
  if(args[i]==='-H'){raw||=String(args[++i]).includes('raw+json');continue;}
  if(args[i]==='--input'){if(args[++i]!=='-')throw Error('产品GitHub输入无效');continue;}
  if(endpoint)throw Error('产品GitHub接口参数无效');endpoint=args[i];
 }
 return apiRequest(endpoint,{token,method,input,raw});
}
async function retentionRequest(endpoint,method='GET') {
 const source=await apiRequest(endpoint,{method,missing:true});
 return source===null?null:source?JSON.parse(source):{};
}
async function createWorkflowRun({token,repository,workflow,title,flow,inputs={}}) {
 const contract=remoteContract(flow,workflow.split('.')[1]),context=operation.getStore();
 if(repository!==repositoryName||contract.workflow!==workflow||contract.title!==title)throw Error('产品Workflow与当前声明不一致');
 context?.verifySource?.();
 if(!inputs||Array.isArray(inputs)||Object.hasOwn(inputs,'pipeline')||Object.hasOwn(inputs,'run_title'))throw Error('产品Workflow输入无效');
 const fields={pipeline:workflow,run_title:workflowDisplayTitle(title,flow),...inputs};
 if(Object.keys(fields).length>25||Object.entries(fields).some(([key,value])=>! /^[a-z][a-z0-9_]*$/u.test(key)
  ||typeof value!=='string'||value.length>4096||/[\x00\r\n]/u.test(value)))throw Error('产品Workflow输入越界');
 const text=await apiRequest(`repos/${repository}/actions/workflows/${workflowFile(workflow)}/dispatches`,
  {token,method:'POST',input:JSON.stringify({ref:'main',inputs:fields})});
 let value;try{value=JSON.parse(text);}catch{throw Error('GitHub没有返回有效Run响应');}
 const runId=value.workflow_run_id,url=value.html_url;
 if(!Number.isSafeInteger(runId)||runId<=0||value.run_url!==`https://api.github.com/repos/${repository}/actions/runs/${runId}`
  ||url!==`https://github.com/${repository}/actions/runs/${runId}`)throw Error('GitHub没有返回准确Run ID');
 const remote={repository,workflow,runId,url};if(context)context.remote=remote;return remote;
}
function workflowRunReceipt(remote) {
 return Buffer.from(JSON.stringify({repository:remote.repository,workflow:remote.workflow,run_id:remote.runId,url:remote.url})).toString('base64');
}
// 可选宿主只确认当前Run和候选。没有宿主时仍由本产品自行轮询、验真和清理。
export function createControl(environment=process.env) {
 const value=environment.PRODUCT_CONTROL_FD;
 if(value===undefined)return {hosted:false,closed:false};
 if(value!=='3')throw Error('产品远端控制通道无效');
 const control={hosted:true,closed:false,frames:[],buffer:Buffer.alloc(0),pending:null,error:null};
 const stream=createReadStream(null,{fd:3,autoClose:true});control.stream=stream;
 const reject=message=>{control.error=Error(message);control.pending?.reject(control.error);control.pending=null;};
 stream.on('data',chunk=>{
  control.buffer=Buffer.concat([control.buffer,chunk]);
  for(;;){const newline=control.buffer.indexOf(10);if(newline<0)break;
   if(newline>65536){reject('产品远端控制帧超限');stream.destroy();return;}
   let frame=control.buffer.subarray(0,newline);control.buffer=control.buffer.subarray(newline+1);
   if(frame.at(-1)===13)frame=frame.subarray(0,-1);
   const text=frame.toString('utf8');if(!text||text.includes('\0')||Buffer.byteLength(text)!==frame.length){reject('产品远端控制帧无效');stream.destroy();return;}
   if(control.pending){control.pending.resolve(text);control.pending=null;}else control.frames.push(text);
   if(control.frames.length>8){reject('产品远端控制帧过多');stream.destroy();return;}
  }
  if(control.buffer.length>65536){reject('产品远端控制帧超限');stream.destroy();}
 });
 stream.on('error',()=>reject('产品远端控制管道失败'));
 stream.on('end',()=>{control.eof=true;if(control.pending)reject('产品远端控制管道已关闭');});
 const signal=operation.getStore()?.signal;
 control.abort=()=>{reject('产品任务已取消');stream.destroy();};
 signal?.addEventListener('abort',control.abort,{once:true});control.signal=signal;
 if(signal?.aborted)control.abort();
 return control;
}
function nextControl(control) {
 if(control.error)return Promise.reject(control.error);
 if(control.frames.length)return Promise.resolve(control.frames.shift());
 if(control.closed||control.eof||control.pending)return Promise.reject(Error('产品远端控制状态无效'));
 return new Promise((resolve,reject)=>{control.pending={resolve,reject};});
}
export function closeControl(control) {
 if(control.closed)return;control.closed=true;
 control.signal?.removeEventListener('abort',control.abort);
 control.pending?.reject(Error('产品远端控制管道已关闭'));control.pending=null;control.stream?.destroy();
}
async function waitRemote(remote) {
 const context=operation.getStore()||{};let failures=0;
 for(let n=0;n<4320;n++){
  context.signal?.throwIfAborted();let row;
  try{row=JSON.parse(await apiRequest(`repos/${remote.repository}/actions/runs/${remote.runId}`));failures=0;}
  catch(error){if(context.signal?.aborted||++failures>=3)throw error;await delay(5000,undefined,{signal:context.signal});continue;}
  const contract=remoteContract(remote.workflow.split('.').at(-1),remote.workflow.split('.')[1]);
  if(row.id!==remote.runId||row.html_url!==remote.url||row.head_branch!=='main'||row.event!=='workflow_dispatch'
   ||row.display_title!==workflowDisplayTitle(contract.title)||!String(row.path||'').endsWith('.github/workflows/'+workflowFile(remote.workflow)))throw Error('产品远端Run身份不一致');
  if(row.status==='completed')return row.conclusion==='success'?'success':'failed';
  await delay(5000,undefined,{signal:context.signal});
 }
 throw Error('产品远端任务超时');
}
export async function runCI(contract,environment=process.env,output=process.stdout) {
 const control=createControl(environment);
 try {
  const remote=await createWorkflowRun({...contract,flow:'ci',token:environment.GH_TOKEN});
  output.write('PRODUCT_REMOTE_RUN:'+workflowRunReceipt(remote)+'\n');
  if(control.hosted&&await nextControl(control)!=='PRODUCT_REMOTE_RUN_ACCEPTED:'+remote.runId)throw Error('宿主未确认CI Run绑定');
  const terminal=control.hosted?await nextControl(control):'PRODUCT_REMOTE_RESULT:'+remote.runId+':'+await waitRemote(remote);
  const success=terminal==='PRODUCT_REMOTE_RESULT:'+remote.runId+':success';
  if(!success&&terminal!=='PRODUCT_REMOTE_RESULT:'+remote.runId+':failed')throw Error('产品CI终态无效');
  await pruneGitHubRuns({repository:contract.repository,canonicalId:contract.workflow,currentRunId:remote.runId,result:success?'success':'failed'});
  if(!success)throw Error('CI失败');return remote;
 } finally { closeControl(control); }
}
const semanticPattern = /^(0|[1-9]\d*)\.(0|[1-9]\d{0,1})\.(0|[1-9]\d{0,1})$/u;
const shaPattern = /^[0-9a-f]{40}$/u;

function required(value, message) {
  if (!value) throw new Error(message);
  return value;
}

function parseJSON(value, label) {
  try { return JSON.parse(value); } catch { throw new Error(`${label}返回了无效JSON`); }
}

function parseSemantic(value) {
 try{return parseSemanticVersion(String(value||''));}catch{throw Error('Release软件版本无效');}
}
function nextSemantic(seed,versions) {
 [seed,...versions].forEach(parseSemantic);
 return expectedSemanticCandidate(seed,versions);
}

function checkedContract(value) {
  const keys = [
    'repository', 'workflow', 'title', 'ciWorkflow', 'ciTitle', 'productId',
    'platform', 'tagPrefix', 'sourceKind', 'sourcePath',
  ];
  if (!value || Object.keys(value).sort().join(',') !== keys.sort().join(',')
    || !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/u.test(value.repository)
    || !/^[a-z][a-z0-9-]*\.[a-z][a-z0-9-]*\.release$/u.test(value.workflow)
    || value.ciWorkflow !== value.workflow.replace(/\.release$/u, '.ci')
    || !/^[a-z][a-z0-9-]*$/u.test(value.productId)
    || !/^[a-z][a-z0-9-]*$/u.test(value.platform)
    || !/^[a-z0-9-]+-v$/u.test(value.tagPrefix)
    || !['json', 'pubspec', 'pubspec-package', 'cargo-workspace', 'literal', 'spec'].includes(value.sourceKind)
    || typeof value.sourcePath !== 'string' || value.sourcePath.startsWith('/')
    || value.sourcePath.includes('..') || /[\u0000\r\n]/u.test(value.sourcePath)
    || typeof value.title !== 'string' || typeof value.ciTitle !== 'string'
    || value.title.length < 2 || value.ciTitle.length < 2) {
    throw new Error('Release产品端合同无效');
  }
  if (value.sourceKind === 'literal') parseSemantic(value.sourcePath);
  if (value.sourceKind !== 'literal' && (!value.sourcePath || !/^[A-Za-z0-9_.-]+(?:\/[A-Za-z0-9_.-]+)*$/u.test(value.sourcePath))) {
    throw new Error('Release版本真源路径无效');
  }
  return Object.freeze({ ...value });
}

async function requestJSON(token, argumentsList, label) {
  return parseJSON(await githubRequest({ token, arguments_: argumentsList }), label);
}

async function repositoryFile(contract, sourceSHA, token) {
  return githubRequest({
    token,
    arguments_: [
      'api', '-H', 'Accept: application/vnd.github.raw+json',
      `repos/${contract.repository}/contents/${contract.sourcePath}?ref=${sourceSHA}`,
    ],
  });
}

function sourceVersion(kind, source) {
  if (kind === 'json') {
    const version = parseJSON(source, '版本文件')?.version;
    parseSemantic(version);
    return version;
  }
  if (kind === 'pubspec' || kind === 'pubspec-package') {
    const expression = kind === 'pubspec'
      ? /^version:\s*([^+\s]+)(?:\+\d+)?\s*$/gmu
      : /^version:\s*([^\s]+)\s*$/gmu;
    const matches = [...source.matchAll(expression)];
    if (matches.length !== 1) throw new Error('Release版本真源不唯一');
    parseSemantic(matches[0][1]);
    return matches[0][1];
  }
  if (kind === 'cargo-workspace') {
    // 中文注释：先定位唯一准确表头，再截到下一表头；行末不能充当当前段的结束条件。
    const headers = [...source.matchAll(/^\[workspace\.package\][ \t]*\r?$/gmu)];
    if (headers.length !== 1) throw new Error('Cargo workspace版本真源不唯一');
    const following = source.slice(headers[0].index + headers[0][0].length);
    const nextHeader = following.search(/^\[[^\r\n]+\][ \t]*\r?$/mu);
    const section = nextHeader < 0 ? following : following.slice(0, nextHeader);
    const matches = [...section.matchAll(/^[ \t]*version[ \t]*=[ \t]*"([^"\r\n]+)"[ \t]*\r?$/gmu)];
    if (matches.length !== 1) throw new Error('Cargo workspace版本真源不唯一');
    parseSemantic(matches[0][1]);
    return matches[0][1];
  }
  throw new Error('Release版本真源类型无效');
}

async function releaseVersions(contract, token) {
  const versions = [];
  for (let page = 1; page <= 100; page += 1) {
    const rows = await requestJSON(token, [
      'api', `repos/${contract.repository}/releases?per_page=100&page=${page}`,
    ], 'GitHub Release列表');
    if (!Array.isArray(rows)) throw new Error('GitHub Release列表格式无效');
    for (const release of rows) {
      if (release?.draft === true || release?.prerelease === true) continue;
      const tag = String(release?.tag_name || '');
      if (!tag.startsWith(contract.tagPrefix)) continue;
      const version = tag.slice(contract.tagPrefix.length);
      parseSemantic(version);
      versions.push(version);
    }
    if (rows.length < 100) return versions;
  }
  throw new Error('GitHub Release列表超过安全分页上限');
}

export async function latestSuccessfulCI(contract, token, {
  request = requestJSON, prune = pruneGitHubRuns,
} = {}) {
  const matches = [];
  for (let page = 1; page <= 100; page += 1) {
    const response = await request(token, [
      'api', `repos/${contract.repository}/actions/workflows/${workflowFile(contract.ciWorkflow)}/runs?event=workflow_dispatch&branch=main&status=completed&per_page=100&page=${page}`,
    ], 'GitHub CI列表');
    const rows = response?.workflow_runs;
    if (!Array.isArray(rows) || !Number.isSafeInteger(response.total_count)) {
      throw new Error('GitHub CI列表格式无效');
    }
    for (const row of rows) {
      if (row?.status === 'completed' && row?.conclusion === 'success'
        && row?.event === 'workflow_dispatch' && row?.head_branch === 'main'
        && row?.display_title === workflowDisplayTitle(contract.ciTitle, 'ci')
        && Number.isSafeInteger(row.id) && row.id > 0 && shaPattern.test(String(row.head_sha || ''))
        && String(row.path || '').endsWith(`.github/workflows/${workflowFile(contract.ciWorkflow)}`)) {
        matches.push(row);
      }
    }
    if (rows.length < 100) break;
    if(page===100) throw Error('GitHub成功CI列表超过安全分页上限');
  }
  matches.sort((left, right) => right.id - left.id);
  const row = matches[0];
  if (!row) throw new Error('GitHub上没有该产品端成功CI，禁止启动Release');
  await prune({ repository: contract.repository, canonicalId: contract.ciWorkflow,
    currentRunId: row.id, result: 'success' });
  return Object.freeze({ runId: row.id, sourceSHA: row.head_sha });
}

async function verifyCI(contract, candidate, token) {
  const row = await requestJSON(token, [
    'api', `repos/${contract.repository}/actions/runs/${candidate.ci_run_id}`,
  ], 'GitHub CI');
  if (row?.status !== 'completed' || row?.conclusion !== 'success'
    || row?.event !== 'workflow_dispatch' || row?.head_branch !== 'main'
    || row?.head_sha !== candidate.source_sha
    || row?.display_title !== workflowDisplayTitle(contract.ciTitle, 'ci')
    || !String(row?.path || '').endsWith(`.github/workflows/${workflowFile(contract.ciWorkflow)}`)) {
    throw new Error('Release来源不是同产品端成功CI');
  }
}

function decodeRetry(contract, environment) {
  const encoded = String(environment.PRODUCT_RELEASE_RETRY_CONTEXT || '');
  if (!encoded) return null;
  let value;
  try { value = JSON.parse(Buffer.from(encoded, 'base64').toString('utf8')); }
  catch { throw new Error('Release重试候选编码无效'); }
  const runtime = contract.sourceKind === 'spec';
  if (!value || value.product_id !== contract.productId || value.workflow !== contract.workflow
    || value.software_flow !== 'release'
    || (!runtime && value.platform !== contract.platform)
    || (runtime && Object.hasOwn(value, 'platform'))
    || !shaPattern.test(String(value.source_sha || ''))
    || !Number.isSafeInteger(value.ci_run_id) || value.ci_run_id <= 0
    || !(value.run_id === null || Number.isSafeInteger(value.run_id) && value.run_id > 0)
    || value.version_tag !== contract.tagPrefix
      + (runtime ? value.spec_version : value.software_version)) {
    throw new Error('Release重试候选与当前产品端不一致');
  }
  return value;
}

async function freshCandidate(contract, environment, ci) {
  if (contract.sourceKind === 'spec') {
    const current = Number(environment.PRODUCT_RELEASE_BASE_SPEC_VERSION);
    const specVersion = Number(environment.PRODUCT_RELEASE_SPEC_VERSION);
    if (!Number.isSafeInteger(current) || current < 0 || current >= 0xffff_ffff
      || !Number.isSafeInteger(specVersion) || specVersion !== current + 1) {
      throw new Error('Release规格版本上下文无效');
    }
    const source = await repositoryFile(contract, ci.sourceSHA, environment.GH_TOKEN);
    const versions = [...source.matchAll(/^\s*spec_version:\s*([0-9]+)\s*,\s*$/gmu)];
    if (versions.length !== 1 || ![current, current + 1].includes(Number(versions[0][1]))) {
      throw new Error('成功CI源码Runtime与finalized链版本差值不是0或1');
    }
    return {
      product_id: contract.productId, software_flow: 'release',
      software_version: null, source_sha: ci.sourceSHA, spec_version: specVersion,
      workflow: contract.workflow, ci_run_id: ci.runId, run_id: null,
      version_tag: contract.tagPrefix + specVersion,
    };
  }
  const seed = contract.sourceKind === 'literal'
    ? contract.sourcePath
    : sourceVersion(contract.sourceKind,
      await repositoryFile(contract, ci.sourceSHA, environment.GH_TOKEN));
  const version = nextSemantic(seed, await releaseVersions(contract, environment.GH_TOKEN));
  return {
    product_id: contract.productId, software_flow: 'release',
    software_version: version, source_sha: ci.sourceSHA, spec_version: null,
    workflow: contract.workflow, platform: contract.platform,
    ci_run_id: ci.runId, run_id: null, version_tag: contract.tagPrefix + version,
  };
}

// 每次新启动都先选择同仓库、同产品、同平台的最新成功 CI；持久候选只有
// 与该 CI 的 Run ID 和源码同时一致时才可用于同源重试。
export async function selectReleaseCandidate(contract, environment, {
  findCI = latestSuccessfulCI, createFresh = freshCandidate,
} = {}) {
  const previous = decodeRetry(contract, environment);
  const ci = await findCI(contract, environment.GH_TOKEN);
  if (previous?.ci_run_id === ci.runId && previous.source_sha === ci.sourceSHA) {
    return previous;
  }
  return createFresh(contract, environment, ci);
}

function releaseControlLines(environment) { return createControl(environment); }
function closeReleaseControl(control) { closeControl(control); }
export async function readReleaseControlFrame(control) { return nextControl(control); }

async function persistCandidate(candidate, control, output) {
  const encoded = Buffer.from(JSON.stringify(candidate), 'utf8').toString('base64');
  output.write(`PRODUCT_RELEASE_CANDIDATE:${encoded}\n`);
  if (control.hosted && await readReleaseControlFrame(control, 'Release候选')
    !== 'PRODUCT_RELEASE_CANDIDATE_ACCEPTED') {
    throw new Error('宿主未确认Release候选');
  }
}

async function remoteRun(contract, runId, token) {
  const row = await requestJSON(token, [
    'api', `repos/${contract.repository}/actions/runs/${runId}`,
  ], 'GitHub Release Run');
  if (row?.id !== runId || row?.event !== 'workflow_dispatch'
    || row?.head_branch !== 'main'
    || row?.html_url !== `https://github.com/${contract.repository}/actions/runs/${runId}`
    || row?.display_title !== workflowDisplayTitle(contract.title,'release')
    || !String(row?.path||'').endsWith('.github/workflows/'+workflowFile(contract.workflow))) {
    throw new Error('Release重试Run身份无效');
  }
  return row;
}

async function verifyFormalRelease(contract, candidate, token) {
  const route=currentDeclaration().remote_routes.find(row=>row.canonicalID===contract.workflow);
  if(route?.recordsFormalRelease)return formalReleaseRecord(contract.platform,candidate.version_tag,{candidate});
  const release=await requestJSON(token,['api',`repos/${contract.repository}/releases/tags/${encodeURIComponent(candidate.version_tag)}`],'GitHub正式Release');
  if(release?.tag_name!==candidate.version_tag||release.draft!==false||release.prerelease!==false
    ||!Array.isArray(release.assets)||!release.assets.length||!release.published_at)throw Error('GitHub正式Release未形成完整终态');
  return null;
}

export async function runRelease(input, environment = process.env, output = process.stdout) {
  const contract = checkedContract(input);
  if (contract.repository !== repositoryName || contract.productId !== productID) throw Error('Release产品归属无效');
  const control = releaseControlLines(environment);
  try {
    let candidate = await selectReleaseCandidate(contract, environment);
    await verifyCI(contract, candidate, environment.GH_TOKEN);
    let remote = null;
    if (candidate.run_id !== null) {
      const existing = await remoteRun(contract, candidate.run_id, environment.GH_TOKEN);
      if (existing.status !== 'completed' || existing.conclusion === 'success') {
        remote = Object.freeze({
          repository: contract.repository, workflow: contract.workflow,
          runId: candidate.run_id,
          url: `https://github.com/${contract.repository}/actions/runs/${candidate.run_id}`,
        });
      } else {
        candidate = { ...candidate, run_id: null };
      }
    }
    await persistCandidate(candidate, control, output);
    if (!remote) {
      const inputs = {
        source_sha: candidate.source_sha,
        ci_run_id: String(candidate.ci_run_id),
        version_tag: candidate.version_tag,
      };
      if (candidate.software_version !== null) inputs.software_version = candidate.software_version;
      if (candidate.spec_version !== null) {
        inputs.spec_version = String(candidate.spec_version);
      }
      for (const [name, value] of Object.entries(environment)) {
        if (!name.startsWith('PRODUCT_RELEASE_INPUT_')) continue;
        const inputName = name.slice('PRODUCT_RELEASE_INPUT_'.length).toLowerCase();
        if (!/^[a-z][a-z0-9_]*$/u.test(inputName) || Object.hasOwn(inputs, inputName)
          || typeof value !== 'string' || value.length > 4096 || /[\u0000\r\n]/u.test(value)) {
          throw new Error('Release附加输入无效');
        }
        inputs[inputName] = value;
      }
      remote = await createWorkflowRun({
        token: environment.GH_TOKEN, repository: contract.repository,
        workflow: contract.workflow, title: contract.title, flow: 'release',
        inputs,
      });
      candidate = { ...candidate, run_id: remote.runId };
      await persistCandidate(candidate, control, output);
    }
    output.write(`PRODUCT_REMOTE_RUN:${workflowRunReceipt(remote)}\n`);
    if (control.hosted && await readReleaseControlFrame(control, 'Release Run绑定')
      !== `PRODUCT_REMOTE_RUN_ACCEPTED:${remote.runId}`) {
      throw new Error('宿主未确认Release Run绑定');
    }
    const terminal = control.hosted ? await readReleaseControlFrame(control, 'Release终态')
      : `PRODUCT_REMOTE_RESULT:${remote.runId}:${await waitRemote(remote)}`;
    const success = terminal === `PRODUCT_REMOTE_RESULT:${remote.runId}:success`;
    if (!success && terminal !== `PRODUCT_REMOTE_RESULT:${remote.runId}:failed`) {
      throw new Error('宿主返回了无效Release结果');
    }
    if (success) await verifyFormalRelease(contract, candidate, environment.GH_TOKEN);
    await pruneGitHubRuns({ repository: contract.repository, canonicalId: contract.workflow,
      currentRunId: remote.runId, result: success ? 'success' : 'failed' });
    if (!success) throw new Error('Release失败');
    return Object.freeze({ remote, candidate });
  } finally {
    // 中文注释：成功、失败和准备异常均关闭 fd3，让父任务收到子进程退出并保存终态。
    closeReleaseControl(control);
  }
}

export {
  checkedContract as validateReleaseContract,
  nextSemantic as nextReleaseVersion,
  sourceVersion as releaseSourceVersion,
};

function retentionRoute(repository,identity) {
 if(repository!==repositoryName)throw Error('产品记录保留越仓');
 const pieces=identity.split('.'),contract=remoteContract(pieces[2],pieces[1]);
 if(contract.workflow!==identity)throw Error('产品记录保留身份无效');
 return {canonicalId:identity,flow:pieces[2],title:contract.title};
}
function workflowRunIdentityMatches(value, route) {
  return typeof value === 'string'
    && value === (route.flow ? workflowDisplayTitle(route.title, route.flow) : route.title);
}

// 仅处理由已登记身份识别的终态；文件名不另分保留组，未知标题不猜测归属。
export function githubRetentionRecord(row, repository, canonicalId) {
  const route = retentionRoute(repository, canonicalId);
  if (!route.flow) return null;
  const events = ['workflow_dispatch'];
  const identityMatches = workflowRunIdentityMatches(row.display_title, route);
  if (!identityMatches || row.head_branch !== 'main'
      || !String(row.path || '').endsWith(`.github/workflows/${workflowFile(canonicalId)}`)
      || !events.includes(row.event)) return null;
  if (!Number.isSafeInteger(row.id) || row.id <= 0 || !shaPattern.test(row.head_sha)
      || row.run_attempt !== undefined && (!Number.isSafeInteger(row.run_attempt) || row.run_attempt <= 0)
      || !Number.isFinite(Date.parse(row.created_at))
      || typeof row.status !== 'string' || !row.status) throw new Error('GitHub记录身份无效');
  if (row.status === 'completed' && (typeof row.conclusion !== 'string' || !row.conclusion)) {
    throw new Error('GitHub终态缺少结论');
  }
  return { canonicalId, attempt: row.run_attempt ?? 1, workflow: row.path, sha: row.head_sha, id: String(row.id).padStart(20, '0'), startedAt: new Date(row.created_at).toISOString(),
    active: row.status !== 'completed',
    result: row.status === 'completed' && row.conclusion === 'success' ? 'success' : 'failed' };
}

export async function pruneGitHubRuns({ repository, canonicalId, currentRunId = null,
  result = null, request = retentionRequest }) {
  const route = retentionRoute(repository, canonicalId);
  if (result !== null && !['success', 'failed'].includes(result)) throw new Error('清理结果无效');
  if (currentRunId !== null && (!Number.isSafeInteger(currentRunId) || currentRunId <= 0
      || !['success', 'failed'].includes(result))) throw new Error('当前任务清理身份无效');
  const prefix = `repos/${repository}/actions`;
  if (currentRunId !== null) {
    const current = await request(`${prefix}/runs/${currentRunId}`);
    const record = current && githubRetentionRecord(current, repository, canonicalId);
    if (!record || record.active || record.result !== result) throw new Error('当前GitHub任务未取得匹配终态');
  }
  const rows = [];
  for (let page = 1; ; page++) {
    // GitHub带branch/event等搜索条件只返回最多1000条；必须无筛选完整分页后本地验证身份。
    const response = await request(`${prefix}/runs?per_page=100&page=${page}`);
    if (!response || !Array.isArray(response.workflow_runs) || response.workflow_runs.length > 100) {
      throw new Error('GitHub记录分页无效');
    }
    for (const row of response.workflow_runs) {
      const record = githubRetentionRecord(row, repository, canonicalId);
      if (record && (route.repositoryPush || result === null || record.result === result)) rows.push(record);
    }
    if (response.workflow_runs.length < 100) break;
    if (page >= 1000) throw new Error('GitHub记录超出安全扫描范围，未删除任何记录');
  }
  if (currentRunId !== null && !rows.some(row => Number(row.id) === currentRunId)) {
    throw new Error('GitHub分页尚未包含当前终态，清理未完成');
  }
  const retained = retainedRecords(rows, { state: row => row.result, protected: row => row.active });
  const keep = new Set(retained.map(row => row.id));
  const removed = [];
  for (const row of rows.filter(row => !keep.has(row.id))) {
    const winner = retained.find(value => value.result === row.result && !value.active);
    const runId = Number(row.id), winnerId = Number(winner.id);
    // 每次删除前重新确认胜出记录存在且较新；被重跑的旧Run不是可删除终态。
    const verify = async () => {
      const newest = await request(`${prefix}/runs/${winnerId}`);
      const currentWinner = newest && githubRetentionRecord(newest, repository, canonicalId);
      if (!currentWinner || currentWinner.active || currentWinner.result !== row.result
          || currentWinner.startedAt !== winner.startedAt
          || currentWinner.attempt !== winner.attempt || currentWinner.workflow !== winner.workflow
          || currentWinner.sha !== winner.sha) {
        throw new Error('保留任务状态变化，停止清理');
      }
      const old = await request(`${prefix}/runs/${runId}`);
      if (old === null) return false;
      const checked = githubRetentionRecord(old, repository, canonicalId);
      if (!checked || checked.active || checked.result !== row.result || checked.startedAt !== row.startedAt
          || checked.attempt !== row.attempt || checked.workflow !== row.workflow || checked.sha !== row.sha) {
        throw new Error('旧任务状态变化，停止清理');
      }
      return true;
    };
    if (!await verify()) continue;
    for (;;) {
      const assets = await request(`${prefix}/runs/${runId}/artifacts?per_page=100`);
      if (assets === null) break;
      if (!Number.isSafeInteger(assets.total_count) || !Array.isArray(assets.artifacts)) {
        throw new Error('GitHub任务产物列表无效');
      }
      if (assets.total_count === 0) break;
      if (!assets.artifacts.length) throw new Error('GitHub任务产物分页未前进');
      for (const asset of assets.artifacts) {
        if (!Number.isSafeInteger(asset.id) || asset.id <= 0) throw new Error('GitHub产物编号无效');
        if (!await verify()) break;
        await request(`${prefix}/artifacts/${asset.id}`, 'DELETE');
        if (await request(`${prefix}/artifacts/${asset.id}`) !== null) throw new Error('GitHub产物删除未确认');
      }
    }
    if (!await verify()) continue;
    await request(`${prefix}/runs/${runId}`, 'DELETE');
    if (await request(`${prefix}/runs/${runId}`) !== null) throw new Error('GitHub任务删除未确认');
    removed.push(runId);
  }
  return removed;
}

// 本产品远端记录共用同一选择器；只按完整流程身份保留成功、失败与活动Run。
// 以任务开始顺序而非完成通知顺序选最新，防止旧任务迟到覆盖新任务。
export function retainedRecords(records, {
  key = row => row.canonicalId,
  id = row => String(row.id),
  state = row => row.result,
  order = row => row.startedAt,
  protected: isProtected = row => row.active === true || row.protected === true,
} = {}) {
  const rows = Array.from(records);
  const seen = new Set(), latest = new Map(), keep = new Set();
  for (const row of rows) {
    const identity = key(row), identifier = id(row), result = state(row);
    // 活动任务尚无结论时继续保护，不能因另一任务完成而删除或使其收尾失败。
    const pending = row.active === true && result === null;
    if (typeof identity !== 'string' || !identity || typeof identifier !== 'string'
        || !identifier || (!pending && (typeof result !== 'string' || !result))) {
      throw new Error('记录保留身份或状态无效');
    }
    const unique = JSON.stringify([identity, identifier]);
    if (seen.has(unique)) throw new Error('记录保留输入含重复任务');
    seen.add(unique);
    if (pending || isProtected(row) || !['success', 'failed'].includes(result)) {
      keep.add(row);
      continue;
    }
    const started = order(row);
    if (typeof started !== 'string' || !started) throw new Error('记录缺少稳定任务顺序');
    const group = JSON.stringify([identity, result]);
    const previous = latest.get(group);
    const newerID = previous && (/^\d+$/.test(identifier) && /^\d+$/.test(previous.identifier)
      ? BigInt(identifier) > BigInt(previous.identifier) : identifier > previous.identifier);
    if (!previous || started > previous.started
        || (started === previous.started && newerID)) {
      latest.set(group, { row, started, identifier });
    }
  }
  for (const { row } of latest.values()) keep.add(row);
  return rows.filter(row => keep.has(row));
}



function sourceIdentity(platform,flow) {
 const value=currentDeclaration(),files=['scripts/flows.json','scripts/flow.mjs','scripts/build.mjs','scripts/resources.mjs',value.platforms[platform]?.[flow]?.entry];
 if(flow==='release')files.push(value.platforms[platform]?.ci?.entry);
 return files.map(file=>[file,createHash('sha256').update(sourceFile(file)).digest('hex')]);
}
export async function executeRemote(flow,platform,{environment=process.env,signal,fetchImpl,output=process.stdout}={}) {
 const before=JSON.stringify(sourceIdentity(platform,flow)),contract=remoteContract(flow,platform);
 const context={signal,token:environment.GH_TOKEN,fetchImpl,verifySource:()=>{
  if(JSON.stringify(sourceIdentity(platform,flow))!==before)throw Error('产品流程源码在执行期间改变');
 }};
 return operation.run(context,async()=>{
  const actual={...environment};

  try {
   const result=flow==='ci'?await runCI(contract,actual,output):await runRelease(contract,actual,output);
   context.verifySource();return result;
  } catch(error) {
   // 独立调用取消后只取消本轮已绑定Run；宿主调用的取消由原任务继续负责。
   if(signal?.aborted&&context.remote&&environment.PRODUCT_CONTROL_FD===undefined) {
    await operation.run({...context,signal:undefined},async()=>{
     await apiRequest(`repos/${repositoryName}/actions/runs/${context.remote.runId}/cancel`,{method:'POST'});
     for(let n=0;n<6;n++){
      const row=JSON.parse(await apiRequest(`repos/${repositoryName}/actions/runs/${context.remote.runId}`));
      if(row.id!==context.remote.runId||row.html_url!==context.remote.url)throw Error('产品取消Run回读身份无效');
      if(row.status==='completed')return;
      await delay(5000);
     }
     throw Error('产品取消Run退出未确认');
    });
   }
   throw error;
  }
 });
}

export async function recoverRemote(flow,platform,runId,result,{environment=process.env,signal,fetchImpl}={}) {
 if(!Number.isSafeInteger(runId)||runId<=0||!['success','failed'].includes(result))throw Error('产品恢复任务身份无效');
 const contract=remoteContract(flow,platform),before=JSON.stringify(sourceIdentity(platform,flow));
 const verifySource=()=>{if(JSON.stringify(sourceIdentity(platform,flow))!==before)throw Error('产品恢复期间源码变化');};
 return operation.run({signal,fetchImpl,token:environment.GH_TOKEN,verifySource},async()=>{
  let formal=null;
  if(flow==='release'){
   const candidate=decodeRetry(contract,environment);
   if(!candidate||candidate.run_id!==runId)throw Error('产品恢复Run与正式候选不一致');
   const remote=await remoteRun(contract,runId,environment.GH_TOKEN);
   if(remote.status!=='completed'||(remote.conclusion==='success'?'success':'failed')!==result)throw Error('产品恢复Run终态不一致');
   await verifyCI(contract,candidate,environment.GH_TOKEN);
   if(result==='success'){
    formal=await verifyFormalRelease(contract,candidate,environment.GH_TOKEN);
    if(formal){if(!Number.isSafeInteger(remote.run_number)||remote.run_number<=0)throw Error('产品恢复Run序号无效');formal.run_number=remote.run_number;}
   }
  }
  const removed=await pruneGitHubRuns({repository:contract.repository,canonicalId:contract.workflow,currentRunId:runId,result});
  verifySource();return {removed_run_ids:removed,formal_release:formal};
 });
}

// 软件记录刷新与流程收尾共用本产品保留器；宿主只消费公开记录，不解释产品正式资产。
export function recordSourceContract(platform) {
 const value=currentDeclaration(),route=value.remote_routes.find(row=>row.canonicalID===productID+'.'+platform+'.release');
 remoteContract('release',platform);
 if(!route?.recordsFormalRelease)throw Error('产品平台不提供正式版本记录');
 const policy=value.platforms[platform].release.record_source;
 if(!policy||Object.keys(policy).sort().join(',')!=='asset_names,immutable,kind,marker_prefix,metadata_asset,source_field,version_field'
  ||!['tag','body','manifest'].includes(policy.kind)||typeof policy.immutable!=='boolean'
  ||!Array.isArray(policy.asset_names)||policy.asset_names.length>16||new Set(policy.asset_names).size!==policy.asset_names.length
  ||policy.asset_names.some(name=>typeof name!=='string'||! /^[A-Za-z0-9._-]{1,128}$/u.test(name))
  ||policy.marker_prefix!==null&&! /^[A-Z][A-Z0-9_]{0,31}$/u.test(policy.marker_prefix)
  ||policy.kind==='manifest'&&(! /^[A-Za-z0-9._-]{1,128}$/u.test(policy.metadata_asset)
   ||! /^[a-z][a-z0-9_]{0,63}$/u.test(policy.source_field)||! /^[a-z][a-z0-9_]{0,63}$/u.test(policy.version_field))
  ||policy.kind!=='manifest'&&[policy.metadata_asset,policy.source_field,policy.version_field].some(value=>value!==null)
  ||policy.kind==='body'&&(!policy.marker_prefix||!policy.asset_names.length))throw Error('产品正式记录来源合同无效');
 return policy;
}
function formalMarker(body,name,pattern,{line=false,required=true}={}) {
 if(typeof body!=='string'||Buffer.byteLength(body)>128*1024)throw Error('正式版本正文超限');
 if(!required&&!body.includes(name+':'))return null;
 const matches=[...body.matchAll(new RegExp(name+':('+pattern+')(?=\\s|$)','gu'))];
 if(matches.length!==1||line&&(body.split(/\r?\n/u).filter(value=>value.includes(name+':')).length!==1
  ||!body.split(/\r?\n/u).includes(name+':'+matches[0][1])))throw Error('正式版本正文身份标记无效');
 return matches[0][1];
}
export function validateFormalRecordSource(platform,release,tagSHA,metadata=null) {
 const policy=recordSourceContract(platform),contract=remoteContract('release',platform);
 const tag=release?.tag_name,version=typeof tag==='string'&&tag.startsWith(contract.tagPrefix)?tag.slice(contract.tagPrefix.length):'';
 if(! /^[0-9]+\.[0-9]+\.[0-9]+$/u.test(version)||!shaPattern.test(tagSHA)
  ||release.draft!==false||release.prerelease!==false||policy.immutable&&release.immutable!==true)throw Error('正式版本记录身份无效');
 if(policy.kind==='tag')return tagSHA;
 if(release.name!==contract.title||!Array.isArray(release.assets))throw Error('正式版本记录标题或资产无效');
 if(policy.asset_names.length&&(release.assets.length!==policy.asset_names.length
  ||release.assets.map(asset=>asset.name).sort().join(',')!==[...policy.asset_names].sort().join(',')
  ||release.assets.some(asset=>!Number.isSafeInteger(asset.id)||asset.id<=0||!Number.isSafeInteger(asset.size)||asset.size<=0||asset.state!=='uploaded')))throw Error('正式版本记录资产闭集无效');
 const body=release.body??'';
 if(policy.kind==='body') {
  if(! /^[0-9]+\.[0-9]{1,2}\.[0-9]{1,2}$/u.test(version))throw Error('正式版本记录版本超界');
  for(const suffix of ['CI_RUN_ID','RUN_ID'])formalMarker(body,policy.marker_prefix+'_RELEASE_'+suffix,'[1-9][0-9]*',{line:policy.immutable});
  if(formalMarker(body,policy.marker_prefix+'_RELEASE_SOURCE_SHA','[0-9a-f]{40}',{line:policy.immutable})!==tagSHA)throw Error('正式版本正文与Tag源码不一致');
  return tagSHA;
 }
 if(!metadata||metadata.product_id!==productID||metadata[policy.version_field]!==version
  ||!shaPattern.test(metadata[policy.source_field]))throw Error('正式版本元数据产品、版本或源码无效');
 const source=metadata[policy.source_field];
 if(policy.marker_prefix&&formalMarker(body,policy.marker_prefix+'_RELEASE_SOURCE_SHA','[0-9a-f]{40}',{required:false})!==null
  &&formalMarker(body,policy.marker_prefix+'_RELEASE_SOURCE_SHA','[0-9a-f]{40}')!==source)throw Error('正式版本正文与元数据源码不一致');
 return source;
}
async function formalTagSHA(tag) {
 if(typeof tag!=='string'||! /^[a-z0-9-]+-v[0-9]+\.[0-9]+\.[0-9]+$/u.test(tag))throw Error('正式版本Tag无效');
 const value=JSON.parse(await apiRequest(`repos/${repositoryName}/git/ref/tags/${encodeURIComponent(tag)}`));
 if(value.ref!==`refs/tags/${tag}`)throw Error('正式版本Tag引用不一致');
 let object=value.object;
 if(object?.type==='tag') {
  if(!shaPattern.test(object.sha))throw Error('正式版本注解Tag无效');
  object=JSON.parse(await apiRequest(`repos/${repositoryName}/git/tags/${object.sha}`)).object;
 }
 if(object?.type!=='commit'||!shaPattern.test(object.sha))throw Error('正式版本Tag未绑定准确提交');
 return object.sha;
}
async function formalMetadata(asset) {
 try {
 if(!Number.isSafeInteger(asset?.id)||asset.id<=0||!Number.isSafeInteger(asset.size)||asset.size<=0||asset.size>128*1024||asset.state!=='uploaded')throw Error('正式版本元数据资产无效');
 const context=operation.getStore()||{},signal=AbortSignal.any([AbortSignal.timeout(30000),...(context.signal?[context.signal]:[])]);
 context.verifySource?.();context.signal?.throwIfAborted();
 const fetchImpl=context.fetchImpl||fetch;
 let response=await fetchImpl(`https://api.github.com/repos/${repositoryName}/releases/assets/${asset.id}`,{
  redirect:'manual',signal,headers:{Authorization:'Bearer '+context.token,Accept:'application/octet-stream','X-GitHub-Api-Version':'2026-03-10'}});
 // GitHub仅把准确资产重定向到官方HTTPS原件地址；跨主机绝不继续发送仓库令牌。
 if([302,303].includes(response.status)) {
  const target=new URL(response.headers.get('location'));
  if(target.protocol!=='https:'||target.hostname!=='release-assets.githubusercontent.com'||target.port||target.username||target.password||target.hash)throw Error('正式版本资产跳转越界');
  await response.body?.cancel();response=await fetchImpl(target.href,{redirect:'manual',signal});
 }
 if(!response.ok){await response.body?.cancel();throw Error('正式版本元数据读取失败');}
 const bytes=await boundedBody(response,128*1024);
 if(Buffer.byteLength(bytes)!==asset.size||asset.digest&&asset.digest!=='sha256:'+createHash('sha256').update(bytes).digest('hex'))throw Error('正式版本元数据尺寸或摘要不一致');
 try{return JSON.parse(bytes);}catch{throw Error('正式版本元数据格式无效');}
 }catch{operation.getStore()?.signal?.throwIfAborted();throw Error('正式版本元数据安全读取失败');}
}
export async function formalReleaseRecord(platform,tag,{candidate=null,runNumber=null}={}) {
 const value=currentDeclaration(),route=value.remote_routes.find(row=>row.canonicalID===productID+'.'+platform+'.release'),policy=recordSourceContract(platform);
 const release=JSON.parse(await apiRequest(`repos/${repositoryName}/releases/tags/${encodeURIComponent(tag)}`));
 if(!Number.isSafeInteger(release?.id)||release.id<=0||release.tag_name!==tag||Number.isNaN(Date.parse(release.published_at))
  ||release.html_url!==`https://github.com/${repositoryName}/releases/tag/${tag}`)throw Error('正式版本记录回读身份无效');
 const tagSHA=await formalTagSHA(tag);let metadata=null;
 if(policy.kind==='manifest') {
  const assets=release.assets?.filter(asset=>asset.name===policy.metadata_asset);
  if(!assets||assets.length!==1)throw Error('正式版本元数据资产不唯一');metadata=await formalMetadata(assets[0]);
 }
 const source=validateFormalRecordSource(platform,release,tagSHA,metadata);
 if(candidate&&(candidate.source_sha!==source||candidate.version_tag!==tag||candidate.product_id!==productID||candidate.platform!==platform))throw Error('恢复正式版本与原候选不一致');
 return {record_type:'github-release',repository:repositoryName,run_id:candidate?.run_id??release.id,run_number:runNumber??release.id,
  product_id:productID,product_title:route.productTitle,software_flow:'release',platform,tag,source_sha:source,tag_sha:tagSHA,
  updated_at:release.published_at,state:'success',url:release.html_url};
}
export async function querySoftwareRecords({environment=process.env,signal,fetchImpl}={}) {
 const value=currentDeclaration(),snapshot=JSON.stringify(value),before=sourceFile('scripts/flow.mjs');
 const verifySource=()=>{if(JSON.stringify(currentDeclaration())!==snapshot||!sourceFile('scripts/flow.mjs').equals(before))throw Error('软件记录读取期间产品来源改变');};
 return operation.run({signal,fetchImpl,token:environment.GH_TOKEN,verifySource},async()=>{
  const removed=[],records=[];
  for(const route of value.remote_routes){remoteContract(route.flow,route.platform);removed.push(...await pruneGitHubRuns({repository:repositoryName,canonicalId:route.canonicalID}));}
  const rows=[];
  for(let page=1;;page++) {
   const response=JSON.parse(await apiRequest(`repos/${repositoryName}/actions/runs?per_page=100&page=${page}`));
   if(!Array.isArray(response.workflow_runs)||response.workflow_runs.length>100)throw Error('软件记录Run分页无效');rows.push(...response.workflow_runs);
   if(response.workflow_runs.length<100)break;if(page>=1000)throw Error('软件记录Run超过有界扫描范围');
  }
  for(const route of value.remote_routes)for(const row of rows) {
   const bound=githubRetentionRecord(row,repositoryName,route.canonicalID);if(!bound||bound.active)continue;
   if(!Number.isSafeInteger(row.run_number)||row.run_number<=0||Number.isNaN(Date.parse(row.updated_at))||!shaPattern.test(row.head_sha))throw Error('软件记录Run字段无效');
   records.push({record_type:'workflow',repository:repositoryName,run_id:row.id,run_number:row.run_number,product_id:productID,
    product_title:route.productTitle,software_flow:route.flow,platform:route.platform,tag:row.display_title.match(/[a-z0-9-]+-v[0-9]+\.[0-9]+\.[0-9]+/u)?.[0]??null,
    updated_at:row.updated_at,source_sha:row.head_sha,state:bound.result,url:row.html_url});
  }
  // 不删除正式资产或Tag；选择各平台最新候选后按本仓合同完整回读。
  const releases=[];
  for(let page=1;;page++) {
   const rows=JSON.parse(await apiRequest(`repos/${repositoryName}/releases?per_page=100&page=${page}`));
   if(!Array.isArray(rows)||rows.length>100)throw Error('软件记录Release分页无效');releases.push(...rows);
   if(rows.length<100)break;if(page>=1000)throw Error('软件记录Release超过有界扫描范围');
  }
  const candidates=[];
  for(const release of releases) {
   if(release.draft!==false||release.prerelease!==false)continue;
   const route=value.remote_routes.find(row=>row.recordsFormalRelease&&typeof release.tag_name==='string'&&release.tag_name.startsWith(row.tagPrefix)
    &&/^[0-9]+\.[0-9]+\.[0-9]+$/u.test(release.tag_name.slice(row.tagPrefix.length)));
   if(!route)continue;if(!Number.isSafeInteger(release.id)||release.id<=0||Number.isNaN(Date.parse(release.published_at)))throw Error('正式版本候选字段无效');
   candidates.push({canonicalId:route.canonicalID,id:String(release.id),active:false,result:'success',startedAt:release.published_at,platform:route.platform,tag:release.tag_name});
  }
  for(const candidate of retainedRecords(candidates))records.push(await formalReleaseRecord(candidate.platform,candidate.tag));
  for(const route of value.remote_routes){const matching=rows.map(row=>githubRetentionRecord(row,repositoryName,route.canonicalID)).filter(Boolean);
   if(retainedRecords(matching).length!==matching.length)throw Error('软件记录远端保留未形成唯一回读');}
  verifySource();records.sort((a,b)=>b.updated_at.localeCompare(a.updated_at));
  if(new Set(removed).size!==removed.length||removed.some(id=>records.some(record=>record.record_type==='workflow'&&record.run_id===id)))throw Error('软件记录清理回执不一致');
  const result={records,removed_run_ids:removed};if(Buffer.byteLength(JSON.stringify(result))>1024*1024)throw Error('软件记录结果超过公开回执限制');return result;
 });
}

async function workflowRunnerImplementation() {
const { remoteEnvironment } = await import("./build.mjs");
const { spawnSync } = await import("node:child_process");
const { pathToFileURL } = await import("node:url");

// 本模块锁定 CitizenApp 远端 Job 的仓库、流程、阶段和参数闭集，
// 并按产品声明逐项执行命令，只负责本产品CI和Release执行。
function requireIdentity(identity, environment) {
  const fields = identity && typeof identity === 'object' ? Object.keys(identity).sort() : [];
  if (JSON.stringify(fields) !== JSON.stringify(['job', 'pipeline'])
    || !/^[a-z][a-z0-9.-]+$/u.test(identity.pipeline)
    || !/^[a-z][a-z0-9-]*$/u.test(identity.job)) {
    throw new Error('CitizenApp远程Job身份无效');
  }
  if (!/^citizenapp[.](?:ios|android)[.](?:ci|release)$/u.test(identity.pipeline)
    || environment.GITHUB_REPOSITORY !== 'crcfrcn/citizenapp') {
    throw new Error('CitizenApp远程Job仓库身份无效');
  }
  // 保留GitHub实际身份；错流程和错Job必须先于临时目录、正文及缓存操作拒绝。
  const [, platform, flow] = identity.pipeline.split('.');
  const expectedJob = identity.job === 'check' && flow === 'ci' ? 'stage_1'
    : identity.job === platform ? 'flow' : null;
  if (!expectedJob || environment.GITHUB_ACTIONS !== 'true'
    || environment.GITHUB_EVENT_NAME !== 'workflow_dispatch'
    || environment.GITHUB_WORKFLOW !== identity.pipeline
    || environment.GITHUB_JOB !== expectedJob) {
    throw new Error('CitizenApp远程Job流程阶段身份无效');
  }

}

function runStep(steps, index, environment, run) {
  if (!/^(?:0|[1-9][0-9]*)$/u.test(String(index ?? ''))
    || !Object.hasOwn(steps, String(index))) {
    throw new Error('CitizenApp远程Job阶段无效');
  }
  const step = steps[String(index)];
  if (!step || !['bash', 'pwsh'].includes(step.shell) || typeof step.source !== 'string'
    || step.source.length === 0) throw new Error('CitizenApp远程Job步骤无效');
  const command = step.shell === 'pwsh'
    ? 'pwsh'
    : (process.platform === 'win32' ? 'bash' : '/bin/bash');
  const argumentsList = step.shell === 'pwsh'
    ? ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', step.source]
    : ['--noprofile', '--norc', '-e', '-o', 'pipefail', '-c', step.source];
  const result = run(command, argumentsList, {
    cwd: process.cwd(), env: environment, stdio: 'inherit',
  });
  if (result.error) throw new Error('CitizenApp远程Job阶段无法启动');
  if (result.status !== 0) process.exitCode = Number.isInteger(result.status) ? result.status : 1;
}

async function runWorkflow(identity, steps, commands = {}, {
  argumentsList = process.argv.slice(2), environment = process.env, run = spawnSync,
} = {}) {
  requireIdentity(identity, environment);
  environment=remoteEnvironment(environment);
  const [command, argument, ...extra] = argumentsList;
  if (extra.length > 0) throw new Error('CitizenApp远程Job参数越界');
  if (command === 'workflow-step') return runStep(steps, argument, environment, run);
  if (argument !== undefined || !Object.hasOwn(commands, command ?? '')) {
    throw new Error('CitizenApp远程Job命令无效');
  }
  return commands[command](environment);
}


return {runWorkflow};
}
const workflowRunner = await workflowRunnerImplementation();
export const {runWorkflow} = workflowRunner;
async function ciCacheImplementation() {
const { remoteEnvironment: productRemoteEnvironment } = await import("./build.mjs");
const { createHash } = await import("node:crypto");
const {
  appendFileSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readlinkSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} = await import("node:fs");
const {default: path} = await import("node:path");

// 缓存身份使用固定语义前缀，不把内部实现误当成版本化协议。
const CI_CACHE_SCHEMA = 'ci';

function required(value, label) {
  const normalized = String(value ?? '').trim();
  if (!normalized) throw new Error(`缺少${label}`);
  return normalized;
}

function token(value, label) {
  const normalized = required(value, label).toLowerCase();
  // GitHub 作业名允许下划线；仍禁止路径分隔符、空白和越界长度。
  if (!/^[a-z0-9][a-z0-9._-]{0,63}$/.test(normalized)) {
    throw new Error(`${label}不是安全缓存标识`);
  }
  return normalized;
}

function positiveInteger(value, label) {
  const normalized = required(value, label);
  if (!/^[1-9][0-9]*$/.test(normalized)) throw new Error(`${label}必须是正整数`);
  return normalized;
}

function repositoryIdentity(value) {
  const normalized = required(value, '仓库身份');
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(normalized)) {
    throw new Error('仓库身份必须使用owner/repository');
  }
  return {
    api: normalized,
    key: normalized.toLowerCase().replace('/', '.'),
  };
}

function cacheIdentity(input) {
  const repository = repositoryIdentity(input.repository);
  const toolchain = required(input.toolchainFingerprint, '工具链指纹').toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(toolchain)) throw new Error('工具链指纹必须是SHA-256');
  const identity = Object.freeze({
    repository: repository.api,
    repositoryKey: repository.key,
    product: token(input.product, '产品'),
    platform: token(input.platform, '平台'),
    architecture: token(input.architecture, '架构'),
    component: token(input.component, 'CI组件'),
    runnerOs: token(input.runnerOs, 'Runner系统'),
    runnerArch: token(input.runnerArch, 'Runner架构'),
    toolchainFingerprint: toolchain,
  });
  if (identity.repository !== 'crcfrcn/citizenapp' || identity.product !== 'citizenapp'
    || !['ios', 'android'].includes(identity.platform)
    || !identity.component.startsWith(`citizenapp-ci-${identity.platform}--`)) {
    throw new Error('CitizenApp CI缓存身份越界');
  }
  const logicalKey = [
    CI_CACHE_SCHEMA,
    identity.product,
    identity.platform,
    identity.architecture,
    identity.component,
    identity.runnerOs,
    identity.runnerArch,
  ].join('-');
  const baseKey = `${logicalKey}-${toolchain.slice(0, 16)}`;
  if (baseKey.length > 400) throw new Error('缓存身份超过安全长度');
  return Object.freeze({ ...identity, logicalKey, baseKey });
}

function cacheKeys(identity, runId, attempt) {
  const run = positiveInteger(runId, 'GitHub Run ID');
  const runAttempt = positiveInteger(attempt, 'GitHub Run Attempt');
  return Object.freeze({
    successPrefix: `${identity.baseKey}-success-`,
    failurePrefix: `${identity.baseKey}-failure-`,
    successKey: `${identity.baseKey}-success-${run}-${runAttempt}`,
    failureKey: `${identity.baseKey}-failure-${run}-${runAttempt}`,
  });
}

function parseCacheKey(identity, key) {
  const parsed = parseLogicalCacheKey(identity, key);
  return parsed?.toolchain === identity.toolchainFingerprint.slice(0, 16) ? parsed : null;
}

function parseLogicalCacheKey(identity, key) {
  const prefix = `${identity.logicalKey}-`;
  if (!String(key).startsWith(prefix)) return null;
  const remainder = String(key).slice(prefix.length);
  const toolchain = remainder.slice(0, 16);
  if (!/^[0-9a-f]{16}$/.test(toolchain) || remainder[16] !== '-') return null;
  const stateAndRun = remainder.slice(17);
  for (const state of ['success', 'failure']) {
    const statePrefix = `${state}-`;
    if (!stateAndRun.startsWith(statePrefix)) continue;
    const match = stateAndRun.slice(statePrefix.length).match(/^([1-9][0-9]*)-([1-9][0-9]*)$/);
    if (!match) return null;
    return Object.freeze({ toolchain, state, runId: match[1], attempt: match[2] });
  }
  return null;
}

function compareCache(left, right) {
  for (const field of ['runId', 'attempt', 'id']) {
    const difference = BigInt(left[field]) - BigInt(right[field]);
    if (difference !== 0n) return difference > 0n ? 1 : -1;
  }
  return 0;
}

function recognizedCaches(identity, caches, ref, currentToolchainOnly = false) {
  const rows = [];
  for (const cache of caches) {
    if (ref && cache.ref !== ref) continue;
    const parsed = parseLogicalCacheKey(identity, cache.key);
    if (!parsed || !/^[1-9][0-9]*$/.test(String(cache.id ?? ''))) continue;
    if (currentToolchainOnly
        && parsed.toolchain !== identity.toolchainFingerprint.slice(0, 16)) continue;
    rows.push({ ...cache, ...parsed, id: String(cache.id) });
  }
  return rows;
}

function selectLatestCache(identity, caches, state = 'success', ref = '') {
  if (!['success', 'failure'].includes(state)) throw new Error('缓存状态无效');
  const rows = recognizedCaches(identity, caches, ref, true)
    .filter((cache) => cache.state === state);
  rows.sort(compareCache);
  return rows.at(-1) ?? null;
}

function planCachePrune(identity, caches, ref = '') {
  const rows = recognizedCaches(identity, caches, ref);
  const retained = new Set();
  for (const state of ['success', 'failure']) {
    const candidates = rows.filter((cache) => cache.state === state).sort(compareCache);
    const latest = candidates.at(-1);
    if (latest) retained.add(latest.id);
  }
  return Object.freeze({
    retain: rows.filter((cache) => retained.has(cache.id)),
    remove: rows.filter((cache) => !retained.has(cache.id)),
  });
}

function pathImplementation(runnerOs) {
  return runnerOs === 'windows' ? path.win32 : path.posix;
}

function cachePathPlan(identity, runnerTemp, entries) {
  const pathApi = pathImplementation(identity.runnerOs);
  const temp = required(runnerTemp, 'Runner临时目录');
  if (!pathApi.isAbsolute(temp)) throw new Error('Runner临时目录必须是绝对路径');
  const names = String(entries ?? '')
    .split(/[\n,]/)
    .map((entry) => entry.trim())
    .filter(Boolean);
  if (names.length === 0) throw new Error('至少需要一个成功缓存路径');
  if (new Set(names).size !== names.length) throw new Error('成功缓存路径不能重复');
  for (const name of names) {
    if (!/^[a-z0-9][a-z0-9._-]*(\/[a-z0-9][a-z0-9._-]*)*$/.test(name)) {
      throw new Error(`缓存相对路径无效：${name}`);
    }
  }
  const digest = createHash('sha256').update(identity.baseKey).digest('hex').slice(0, 20);
  const rootName = `${identity.product}-${identity.platform}-${identity.component}-${digest}`;
  const root = pathApi.resolve(temp, 'ci-cache', rootName);
  const expectedParent = pathApi.resolve(temp, 'ci-cache');
  const relative = pathApi.relative(expectedParent, root);
  if (!relative || relative.startsWith('..') || pathApi.isAbsolute(relative)) {
    throw new Error('缓存根目录逃出Runner临时目录');
  }
  return Object.freeze({
    root,
    successPaths: names.map((name) => pathApi.join(root, ...name.split('/'))),
    failurePath: pathApi.join(root, 'failure-diagnostic'),
  });
}

function relativeEntries(value, label) {
  const entries = String(value ?? '').split(/[\n,]/).map((entry) => entry.trim()).filter(Boolean);
  for (const entry of entries) {
    if (!/^[A-Za-z0-9][A-Za-z0-9._-]*(\/[A-Za-z0-9][A-Za-z0-9._-]*)*$/.test(entry)) {
      throw new Error(`${label}相对路径无效：${entry}`);
    }
  }
  return entries;
}

function resolvedChild(pathApi, parent, relative, label) {
  const target = pathApi.resolve(parent, ...relative.split('/'));
  const child = pathApi.relative(parent, target);
  if (!child || child.startsWith('..') || pathApi.isAbsolute(child)) {
    throw new Error(`${label}逃出允许根`);
  }
  return target;
}

function wireCacheLinks(identity, runnerTemp, entries, workspace, links) {
  const pathApi = pathImplementation(identity.runnerOs);
  const plan = cachePathPlan(identity, runnerTemp, entries);
  const workspaceRoot = required(workspace, 'GitHub工作区');
  if (!pathApi.isAbsolute(workspaceRoot)) throw new Error('GitHub工作区必须是绝对路径');
  const rows = String(links ?? '').split(/\n/).map((entry) => entry.trim()).filter(Boolean);
  for (const row of rows) {
    const separator = row.indexOf('=');
    if (separator <= 0) throw new Error(`缓存目录链接无效：${row}`);
    const sourceRelative = row.slice(0, separator);
    const cacheRelative = row.slice(separator + 1);
    relativeEntries(sourceRelative, '工作区生成目录');
    relativeEntries(cacheRelative, '受控缓存目录');
    const source = resolvedChild(pathApi, workspaceRoot, sourceRelative, '工作区生成目录');
    const target = resolvedChild(pathApi, plan.root, cacheRelative, '受控缓存目录');
    mkdirSync(pathApi.dirname(source), { recursive: true });
    mkdirSync(target, { recursive: true });
    if (existsSync(source)) {
      const status = lstatSync(source);
      if (status.isSymbolicLink()) {
        const linked = pathApi.resolve(pathApi.dirname(source), readlinkSync(source));
        if (linked === target) continue;
      }
      throw new Error(`工作区生成目录已存在且不是准确缓存链接：${sourceRelative}`);
    }
    symlinkSync(target, source, identity.runnerOs === 'windows' ? 'junction' : 'dir');
  }
  return plan;
}

function sanitizeCacheFinals(identity, runnerTemp, entries, finals) {
  const pathApi = pathImplementation(identity.runnerOs);
  const plan = cachePathPlan(identity, runnerTemp, entries);
  for (const relative of relativeEntries(finals, '最终候选')) {
    rmSync(resolvedChild(pathApi, plan.root, relative, '最终候选'), {
      recursive: true,
      force: true,
    });
  }
}

function identityFromEnvironment(environment) {
  return cacheIdentity({
    repository: environment.GITHUB_REPOSITORY,
    product: environment.CI_CACHE_PRODUCT,
    platform: environment.CI_CACHE_PLATFORM,
    architecture: environment.CI_CACHE_ARCHITECTURE,
    component: environment.CI_CACHE_COMPONENT,
    runnerOs: environment.RUNNER_OS,
    runnerArch: environment.RUNNER_ARCH,
    toolchainFingerprint: environment.CI_CACHE_TOOLCHAIN_FINGERPRINT,
  });
}

function githubHeaders(tokenValue) {
  return {
    Accept: 'application/vnd.github+json',
    Authorization: `Bearer ${required(tokenValue, 'GitHub Actions令牌')}`,
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'ci-cache',
  };
}

async function githubRequest(url, tokenValue, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: { ...githubHeaders(tokenValue), ...(options.headers ?? {}) },
  });
  if (!response.ok) throw new Error(`GitHub缓存API失败：${response.status}`);
  if (response.status === 204) return null;
  return response.json();
}

async function listRepositoryCaches(repository, tokenValue) {
  const caches = [];
  for (let page = 1; ; page += 1) {
    const endpoint = `https://api.github.com/repos/${repository}/actions/caches?per_page=100&page=${page}`;
    const result = await githubRequest(endpoint, tokenValue);
    const rows = Array.isArray(result?.actions_caches) ? result.actions_caches : [];
    caches.push(...rows);
    if (rows.length < 100) break;
  }
  return caches;
}

async function deleteRepositoryCache(repository, cacheId, tokenValue) {
  await githubRequest(
    `https://api.github.com/repos/${repository}/actions/caches/${cacheId}`,
    tokenValue,
    { method: 'DELETE' },
  );
}

function output(name, value, environment) {
  const target = environment.GITHUB_OUTPUT;
  if (!target) return;
  const text = String(value);
  if (text.includes('\n')) {
    const delimiter = `CI_CACHE_${name.toUpperCase()}_EOF`;
    if (text.includes(delimiter)) throw new Error('GitHub多行输出包含保留分隔符');
    appendFileSync(target, `${name}<<${delimiter}\n${text}\n${delimiter}\n`);
  } else {
    appendFileSync(target, `${name}=${text}\n`);
  }
}

function persistEnvironment(name, value, environment) {
  const target = environment.GITHUB_ENV;
  if (!target) return;
  const text = String(value ?? '');
  if (text.includes('\n')) {
    const delimiter = `CI_CACHE_ENV_${name}_EOF`;
    if (text.includes(delimiter)) throw new Error('GitHub环境变量包含保留分隔符');
    appendFileSync(target, `${name}<<${delimiter}\n${text}\n${delimiter}\n`);
  } else {
    appendFileSync(target, `${name}=${text}\n`);
  }
}

// 缓存命令使用调用方本次环境核验四个既有CI Job，错误身份先于网络和文件操作拒绝。
function requireExactRemoteJobEnvironment(environment) {
  const platform=environment.CI_CACHE_PLATFORM,job=environment.GITHUB_JOB;
  const component='citizenapp-ci-'+platform+'--'+(job==='stage_1'?'check':platform);
  if(environment.GITHUB_ACTIONS!=='true'||environment.GITHUB_REPOSITORY!=='crcfrcn/citizenapp'
    ||environment.GITHUB_EVENT_NAME!=='workflow_dispatch'||!['ios','android'].includes(platform)
    ||environment.GITHUB_WORKFLOW!=='citizenapp.'+platform+'.ci'||!['stage_1','flow'].includes(job)
    ||environment.CI_CACHE_PRODUCT!=='citizenapp'||environment.CI_CACHE_WORKFLOW!=='citizenapp-'+platform
    ||environment.CI_CACHE_COMPONENT!==component||environment.CI_CACHE_JOB!==component) {
    throw new Error('CitizenApp CI缓存远端Job身份无效');
  }
}

function commandContext(environment) {
  environment = productRemoteEnvironment(environment);
  requireExactRemoteJobEnvironment(environment);
  const identity = identityFromEnvironment(environment);
  const keys = cacheKeys(identity, environment.GITHUB_RUN_ID, environment.GITHUB_RUN_ATTEMPT);
  const paths = cachePathPlan(identity, environment.RUNNER_TEMP, environment.CI_CACHE_PATHS);
  const ref = required(environment.GITHUB_REF, 'GitHub Ref');
  const tokenValue = environment.GH_TOKEN || environment.GITHUB_TOKEN;
  return { identity, keys, paths, ref, tokenValue };
}

async function prepare(environment) {
  environment = productRemoteEnvironment(environment);
  const context = commandContext(environment);
  const caches = await listRepositoryCaches(context.identity.repository, context.tokenValue);
  const latest = selectLatestCache(context.identity, caches, 'success', context.ref);
  for (const directory of [...context.paths.successPaths, context.paths.failurePath]) {
    mkdirSync(directory, { recursive: true });
  }
  const restoreKey = latest?.key ?? `${context.keys.successPrefix}none`;
  output('cache_root', context.paths.root, environment);
  output('success_paths', context.paths.successPaths.join('\n'), environment);
  output('failure_paths', context.paths.failurePath, environment);
  output('restore_key', restoreKey, environment);
  output('success_key', context.keys.successKey, environment);
  output('failure_key', context.keys.failureKey, environment);
  for (const name of [
    'CI_CACHE_PRODUCT', 'CI_CACHE_PLATFORM', 'CI_CACHE_ARCHITECTURE',
    'CI_CACHE_COMPONENT', 'CI_CACHE_TOOLCHAIN_FINGERPRINT', 'CI_CACHE_PATHS',
    'CI_CACHE_LINKS', 'CI_CACHE_FINALS', 'CI_CACHE_WORKFLOW', 'CI_CACHE_JOB',
  ]) persistEnvironment(name, environment[name] ?? '', environment);
  persistEnvironment('CI_INCREMENTAL_ROOT', context.paths.root, environment);
  const pathByName = new Map(
    relativeEntries(environment.CI_CACHE_PATHS, '成功缓存').map(
      (name, index) => [name, context.paths.successPaths[index]],
    ),
  );
  const environmentPaths = {
    'cargo-home': 'CARGO_HOME',
    'cargo-target': 'CARGO_TARGET_DIR',
    'dart-pub': 'PUB_CACHE',
    gradle: 'GRADLE_USER_HOME',
    cocoapods: 'CP_HOME_DIR',
    npm: 'npm_config_cache',
    xdg: 'XDG_CACHE_HOME',
  };
  for (const [cacheName, environmentName] of Object.entries(environmentPaths)) {
    if (pathByName.has(cacheName)) persistEnvironment(environmentName, pathByName.get(cacheName), environment);
  }
  if (pathByName.has('cargo-target')) persistEnvironment('CARGO_INCREMENTAL', '1', environment);
  if (pathByName.has('cargo-home') && environment.GITHUB_PATH) {
    appendFileSync(environment.GITHUB_PATH, `${path.join(pathByName.get('cargo-home'), 'bin')}\n`);
  }
  if (!environment.GITHUB_OUTPUT) {
    process.stdout.write(`${JSON.stringify({
      cacheRoot: context.paths.root,
      restoreKey,
      successKey: context.keys.successKey,
      failureKey: context.keys.failureKey,
    })}\n`);
  }
}

function wire(environment) {
  const context = commandContext(environment);
  wireCacheLinks(
    context.identity,
    environment.RUNNER_TEMP,
    environment.CI_CACHE_PATHS,
    environment.GITHUB_WORKSPACE,
    environment.CI_CACHE_LINKS,
  );
}

function sanitize(environment) {
  const context = commandContext(environment);
  sanitizeCacheFinals(
    context.identity,
    environment.RUNNER_TEMP,
    environment.CI_CACHE_PATHS,
    environment.CI_CACHE_FINALS,
  );
}

function writeTerminalRecord(environment) {
  const context = commandContext(environment);
  const state = token(environment.CI_CACHE_TERMINAL_STATE, '终态');
  if (!['success', 'failure'].includes(state)) throw new Error('终态只能是success或failure');
  const sourceSha = required(environment.GITHUB_SHA, 'GitHub源码SHA').toLowerCase();
  if (!/^[0-9a-f]{40}$/.test(sourceSha)) throw new Error('GitHub源码SHA无效');
  const directory = state === 'success' ? context.paths.successPaths[0] : context.paths.failurePath;
  mkdirSync(directory, { recursive: true });
  const record = {
    schema: CI_CACHE_SCHEMA,
    state,
    repository: context.identity.repository,
    product: context.identity.product,
    platform: context.identity.platform,
    architecture: context.identity.architecture,
    component: context.identity.component,
    runner_os: context.identity.runnerOs,
    runner_arch: context.identity.runnerArch,
    source_sha: sourceSha,
    run_id: positiveInteger(environment.GITHUB_RUN_ID, 'GitHub Run ID'),
    run_attempt: positiveInteger(environment.GITHUB_RUN_ATTEMPT, 'GitHub Run Attempt'),
    workflow: token(environment.CI_CACHE_WORKFLOW, 'Workflow'),
    job: token(environment.CI_CACHE_JOB, 'Job'),
  };
  const receipt = path.join(directory, `${state}.json`);
  // 成功目录可能来自上一份成功缓存；新成功只替换旧成功回执，不累积代次文件。
  rmSync(receipt, { force: true });
  writeFileSync(
    receipt,
    `${JSON.stringify(record, null, 2)}\n`,
    { flag: 'wx' },
  );
}

async function prune(environment) {
  environment = productRemoteEnvironment(environment);
  const context = commandContext(environment);
  const state = token(environment.CI_CACHE_TERMINAL_STATE, '终态');
  if (!['success', 'failure'].includes(state)) throw new Error('终态只能是success或failure');
  const currentKey = state === 'success' ? context.keys.successKey : context.keys.failureKey;
  const caches = await listRepositoryCaches(context.identity.repository, context.tokenValue);
  const currentExists = caches.some(
    (cache) => cache.key === currentKey && cache.ref === context.ref,
  );
  if (!currentExists) throw new Error('新缓存槽尚未确认存在，拒绝删除历史缓存');
  const plan = planCachePrune(context.identity, caches, context.ref);
  for (const cache of plan.remove) {
    await deleteRepositoryCache(context.identity.repository, cache.id, context.tokenValue);
  }
  process.stdout.write(
    `CI缓存收口完成：保留${plan.retain.length}个，删除${plan.remove.length}个\n`,
  );
}


// 四个CitizenApp CI Job只共享这一份缓存实现；平台步骤与身份仍留在各自Job文件。
const cacheCommands = Object.freeze({
  prepare,
  wire,
  sanitize,
  record: writeTerminalRecord,
  prune,
});

return {CI_CACHE_SCHEMA,cacheIdentity,cacheKeys,parseCacheKey,parseLogicalCacheKey,selectLatestCache,planCachePrune,cachePathPlan,wireCacheLinks,sanitizeCacheFinals,cacheCommands};
}
const ciCache = await ciCacheImplementation();
export const {CI_CACHE_SCHEMA,cacheIdentity,cacheKeys,parseCacheKey,parseLogicalCacheKey,selectLatestCache,planCachePrune,cachePathPlan,wireCacheLinks,sanitizeCacheFinals,cacheCommands} = ciCache;
async function releaseVersionImplementation() {

const { execFileSync } = await import("node:child_process");
const { readFileSync } = await import("node:fs");
const { pathToFileURL } = await import("node:url");

// 本脚本依据 pubspec 版本种子、正式 Release Tag 和同端成功 CI 元数据，
// 计算唯一候选版本并拒绝来源、提交或工作流身份不一致的 Release。
const semanticVersionPattern = /^(0|[1-9]\d*)\.(0|[1-9]\d?)\.(0|[1-9]\d?)$/;
const tagPrefixPattern = /^[a-z0-9][a-z0-9-]*-v$/;
const sourceSHAPattern = /^[0-9a-f]{40}$/;

function parseSemanticVersion(value) {
  const match = semanticVersionPattern.exec(String(value));
  if (!match) throw new Error(`软件版本必须形如 a.b.c 且 b、c 不超过 99：${value}`);
  return match.slice(1).map(Number);
}

function compareSemanticVersions(left, right) {
  const a = parseSemanticVersion(left);
  const b = parseSemanticVersion(right);
  for (let index = 0; index < 3; index += 1) {
    if (a[index] !== b[index]) return a[index] - b[index];
  }
  return 0;
}

function nextSemanticVersion(value) {
  let [major, minor, patch] = parseSemanticVersion(value);
  patch += 1;
  if (patch > 99) {
    patch = 0;
    minor += 1;
  }
  if (minor > 99) {
    minor = 0;
    major += 1;
  }
  return `${major}.${minor}.${patch}`;
}

function expectedSemanticCandidate(seed, successfulVersions) {
  parseSemanticVersion(seed);
  const normalized = [...new Set(successfulVersions.map((value) => {
    parseSemanticVersion(value);
    return value;
  }))].sort(compareSemanticVersions);
  return normalized.length === 0 ? seed : nextSemanticVersion(normalized.at(-1));
}

function parseArguments(argv) {
  const [command, ...rest] = argv;
  if (!command) throw new Error('缺少版本命令');
  const values = {};
  for (let index = 0; index < rest.length; index += 2) {
    const key = rest[index];
    const value = rest[index + 1];
    if (!key?.startsWith('--') || value === undefined) throw new Error(`参数格式无效：${key ?? ''}`);
    const name = key.slice(2);
    if (Object.hasOwn(values, name)) throw new Error(`参数重复：${key}`);
    values[name] = value;
  }
  return { command, values };
}

function requireExactKeys(values, required, optional = []) {
  const allowed = new Set([...required, ...optional]);
  for (const key of Object.keys(values)) {
    if (!allowed.has(key)) throw new Error(`不支持的参数：--${key}`);
  }
  for (const key of required) {
    if (!Object.hasOwn(values, key) || values[key] === '') throw new Error(`缺少参数：--${key}`);
  }
}

function ghJSON(path) {
  const output = execFileSync('gh', ['api', path], {
    encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
  });
  try {
    return JSON.parse(output);
  } catch {
    throw new Error(`GitHub API 返回了无效 JSON：${path}`);
  }
}

function readSeed(path) {
  const text = readFileSync(path, 'utf8');
  const matches = [...text.matchAll(/^version:\s*([^+\s]+)(?:\+\d+)?\s*$/gm)];
  if (matches.length !== 1) throw new Error(`pubspec 软件版本真源不唯一：${path}`);
  parseSemanticVersion(matches[0][1]);
  return matches[0][1];
}

function publishedSemanticVersions(prefix) {
  if (!tagPrefixPattern.test(prefix)) throw new Error('Tag 前缀无效');
  const escaped = prefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(`^${escaped}(${semanticVersionPattern.source.slice(1, -1)})$`);
  const versions = [];
  for (let page = 1; page <= 100; page += 1) {
    const releases = ghJSON(`repos/{owner}/{repo}/releases?per_page=100&page=${page}`);
    if (!Array.isArray(releases)) throw new Error('GitHub Release 列表格式无效');
    for (const release of releases) {
      if (release?.draft === true || release?.prerelease === true) continue;
      const tag = String(release?.tag_name || '');
      if (!tag.startsWith(prefix)) continue;
      const match = pattern.exec(tag);
      if (!match) throw new Error(`同前缀正式 Release Tag 不符合统一版本契约：${tag}`);
      parseSemanticVersion(match[1]);
      versions.push(match[1]);
    }
    if (releases.length < 100) return versions;
  }
  throw new Error('GitHub Release 列表超过安全分页上限');
}

function validateIdentity(values) {
  if (values['product-id'] !== 'citizenapp') throw new Error('product_id 无效');
  if (!['ios', 'android'].includes(values.target)) throw new Error('target 无效');
  if (values.workflow !== `citizenapp.${values.target}.ci`) throw new Error('workflow 无效');
  if (values.prefix !== `citizenapp-${values.target}-v`) throw new Error('Tag 前缀无效');
  if (!sourceSHAPattern.test(values['source-sha'])) throw new Error('source_sha 无效');
  if (!/^[1-9]\d*$/.test(values['ci-run-id'])) throw new Error('ci_run_id 无效');
}

function verifySuccessfulCIRun(values) {
  validateIdentity(values);
  const expectedTitle = values.target === 'ios' ? '公民 · iOS · CI' : '公民 · Android · CI';
  const run = ghJSON(`repos/{owner}/{repo}/actions/runs/${values['ci-run-id']}`);
  if (run.status !== 'completed' || run.conclusion !== 'success'
    || run.event !== 'workflow_dispatch' || run.head_branch !== 'main'
    || run.head_sha !== values['source-sha']
    || String(run.display_title || '') !== expectedTitle
    || String(run.path || '') !== `.github/workflows/citizenapp-${values.target}-ci.yml`) {
    throw new Error('Release 来源不是同产品、同端、同 workflow 的成功 CI');
  }
  const head = execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
  if (head !== values['source-sha']) throw new Error(`checkout 与 source_sha 不一致：${head}`);
}

function printNextSemanticRelease(values) {
  requireExactKeys(values, ['prefix', 'seed']);
  const candidate = expectedSemanticCandidate(
    values.seed,
    publishedSemanticVersions(values.prefix),
  );
  process.stdout.write(`${candidate}\n`);
}

function verifyReleaseSource(values) {
  requireExactKeys(values, [
    'version-tag', 'source-sha', 'ci-run-id', 'prefix', 'product-id', 'target', 'workflow',
  ]);
  if (!tagPrefixPattern.test(values.prefix)
    || !values['version-tag'].startsWith(values.prefix)
    || !/^[a-z0-9][a-z0-9.-]*$/.test(values['version-tag'])) {
    throw new Error('Release 版本 Tag 身份无效');
  }
  verifySuccessfulCIRun(values);
  const suffix = values['version-tag'].slice(values.prefix.length);
  parseSemanticVersion(suffix);
  const expected = expectedSemanticCandidate(
    readSeed('pubspec.yaml'),
    publishedSemanticVersions(values.prefix),
  );
  if (suffix !== expected) {
    throw new Error(`Release 版本不是正式 Release 真源的下一版本：期望 ${expected}，收到 ${suffix}`);
  }
  process.stdout.write(`Release 已锁定成功 CI：${values['ci-run-id']} · ${values['source-sha']}\n`);
}

function main(argv) {
  const { command, values } = parseArguments(argv);
  if (command === 'next-semantic-release') return printNextSemanticRelease(values);
  if (command === 'verify-release-source') return verifyReleaseSource(values);
  throw new Error(`不支持的版本命令：${command}`);
}

return {parseSemanticVersion,compareSemanticVersions,nextSemanticVersion,expectedSemanticCandidate,main};
}
const releaseVersion = await releaseVersionImplementation();
export const {parseSemanticVersion,compareSemanticVersions,nextSemanticVersion,expectedSemanticCandidate} = releaseVersion;

if(!inlineTestEntry&&directEntry&&process.argv[2]==='version') {
try { releaseVersion.main(process.argv.slice(3)); } catch(error) {console.error(error.message);process.exitCode=1;}
}
if(!inlineTestEntry&&directEntry&&process.argv[2]!=='version') {
 const [command,flow,platform,...extra]=process.argv.slice(2);
 const recovering=command==='recover',records=command==='records';
 if(records?(flow!==undefined||platform!==undefined||extra.length):command!=='run'&&!recovering||!recovering&&extra.length||recovering&&(extra.length!==4||extra[0]!=='--run-id'||extra[2]!=='--result'||! /^[1-9][0-9]*$/u.test(extra[1])||!['success','failed'].includes(extra[3])))throw Error('产品远端固定入口参数无效');
 if(records)currentDeclaration();else remoteContract(flow,platform);
 const work=realpathSync(mkdtempSync(join(temporaryRoot(records?Object.keys(currentDeclaration().platforms)[0]:platform,records?'tmp':flow),productID+'-'+(records?'records':flow)+'-'))),cancellation=new AbortController();let unconfirmed=false;
 for(const event of ['SIGTERM','SIGINT'])process.once(event,()=>cancellation.abort());
 try {
  const names=['HOME','USER','LOGNAME','LANG','LC_ALL','PRODUCT_TOOL_ROOT','PRODUCT_DEPENDENCY_ROOT','PRODUCT_CONTROL_FD','PRODUCT_RELEASE_RETRY_CONTEXT','GH_TOKEN',
   'PRODUCT_CHAIN_URL','PRODUCT_CHAIN_ACCESS_CLIENT_ID','PRODUCT_CHAIN_ACCESS_CLIENT_SECRET','PRODUCT_CHAIN_GENESIS_HASH'];
  const environment=Object.fromEntries(names.filter(key=>typeof process.env[key]==='string').map(key=>[key,process.env[key]]));
  if(records)delete environment.PRODUCT_CONTROL_FD;
  const options={signal:cancellation.signal,environment};const node=await bootstrapNode(work,options);
  const digest=path=>createHash('sha256').update(readFileSync(path)).digest('hex');
  if(digest(node.path)!==digest(process.execPath)) {
   const args=records?[command]:[command,flow,platform,...extra];
   const response=await runBuildProcess(node.path,[fileURLToPath(import.meta.url),...args],environment,root,
    {signal:cancellation.signal,passHost:environment.PRODUCT_CONTROL_FD==='3',capture:recovering||records,streamError:recovering||records,timeout:21600000});
   if(recovering||records)process.stdout.write(response.stdout);
  }else if(records)process.stdout.write(JSON.stringify(await querySoftwareRecords({environment,signal:cancellation.signal}))+'\n');
  else if(recovering)process.stdout.write(JSON.stringify(await recoverRemote(flow,platform,Number(extra[1]),extra[3],{environment,signal:cancellation.signal})));
  else await executeRemote(flow,platform,{environment,signal:cancellation.signal});
 }catch(error){unconfirmed=String(error.message).includes('退出未确认');process.stderr.write(String(error.message)+'\n');process.exitCode=1;}
 finally{if(!unconfirmed)rmSync(work,{recursive:true});}
}

const inlineTestOwner = {remoteContract,createControl,closeControl,runCI,latestSuccessfulCI,selectReleaseCandidate,readReleaseControlFrame,runRelease,githubRetentionRecord,pruneGitHubRuns,retainedRecords,executeRemote,recoverRemote,recordSourceContract,validateFormalRecordSource,formalReleaseRecord,querySoftwareRecords,validateReleaseContract:checkedContract,nextReleaseVersion:nextSemantic,releaseSourceVersion:sourceVersion,runWorkflow,CI_CACHE_SCHEMA,cacheIdentity,cacheKeys,parseCacheKey,parseLogicalCacheKey,selectLatestCache,planCachePrune,cachePathPlan,wireCacheLinks,sanitizeCacheFinals,cacheCommands,parseSemanticVersion,compareSemanticVersions,nextSemanticVersion,expectedSemanticCandidate};

// 同文件回归：普通导入和正式命令不注册测试。
if(inlineTestEntry){
 const {test:register}=await import('node:test');
 register('同文件回归组 1',async context=>{
 const pending=[];const test=(...args)=>{const item=context.test(...args);pending.push(item);return item;};
// 本产品远端正常、失败、身份、候选与控制边界；全部远端数据用真实Response夹具注入。
const {default: assert} = await import("node:assert/strict");
const {readFileSync} = await import("node:fs");
const {dirname,resolve,join} = await import("node:path");
const {fileURLToPath} = await import("node:url");
const {spawn} = await import("node:child_process");
const {remoteContract,executeRemote,nextReleaseVersion,releaseSourceVersion,latestSuccessfulCI,selectReleaseCandidate,githubRetentionRecord,recoverRemote,recordSourceContract,validateFormalRecordSource,querySoftwareRecords} = inlineTestOwner;
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const declaration=JSON.parse(readFileSync(join(root,'scripts/flows.json'),'utf8'));
const routes=declaration.remote_routes;
const token='ghs_'+ 'fixture'.repeat(6),sourceSHA='a'.repeat(40),runID=420;
const title=contract=>{const p=contract.title.split(' · ');return p[0]+' · '+p[2]+' · '+p[1];};
const row=contract=>({id:runID,status:'completed',conclusion:'success',event:'workflow_dispatch',head_branch:'main',
 head_sha:sourceSHA,display_title:title(contract),created_at:'2026-10-06T00:00:00Z',
 path:declaration.platforms[contract.workflow.split('.')[1]][contract.workflow.split('.')[2]].entry,
 html_url:`https://github.com/${contract.repository}/actions/runs/${runID}`});
const output=()=>{const chunks=[];return {chunks,write:value=>chunks.push(String(value))};};
test('全部当前路由属于本产品、平台及固定流程，缺失和错误身份拒绝',()=>{
 for(const route of routes){const contract=remoteContract(route.flow,route.platform);assert.equal(contract.workflow,route.canonicalID);assert.equal(contract.title,route.expectedTitle);}
 for(const args of [['publish',routes[0].platform],['ci','unregistered'],['release','../escape']])assert.throws(()=>remoteContract(...args));
});
test('版本递增与唯一源码格式保持原有规则',()=>{
 assert.equal(nextReleaseVersion('1.0.0',[]),'1.0.0');assert.equal(nextReleaseVersion('1.0.0',['1.0.99']),'1.1.0');
 assert.equal(nextReleaseVersion('1.0.0',['1.99.99']),'2.0.0');assert.throws(()=>nextReleaseVersion('bad',[]));
 assert.equal(releaseSourceVersion('json','{"version":"1.2.3"}'),'1.2.3');
 assert.equal(releaseSourceVersion('pubspec','version: 1.2.3+4\n'),'1.2.3');
 assert.equal(releaseSourceVersion('cargo-workspace','[workspace]\nversion="9.9.9"\n[workspace.package]\nversion = "1.2.3"\n'),'1.2.3');
 for(const source of ['[workspace]\nversion="1.0.0"\n','[workspace.package]\nversion = "1.0.0"\nversion = "1.0.1"\n'])assert.throws(()=>releaseSourceVersion('cargo-workspace',source));
});
for(const route of routes.filter(value=>value.flow==='ci'))test(route.canonicalID+'独立运行自行派发、跟踪和清理，不依赖宿主',async()=>{
 const contract=remoteContract('ci',route.platform),valid=row(contract),requests=[],log=output();
 await executeRemote('ci',route.platform,{environment:{GH_TOKEN:token},output:log,fetchImpl:async(url,options)=>{
  requests.push({url,options});assert.ok(url.startsWith('https://api.github.com/repos/'+contract.repository+'/'));
  assert.equal(options.redirect,'manual');assert.equal(options.headers.Authorization,'Bearer '+token);
  if(url.endsWith('/dispatches')){assert.deepEqual(JSON.parse(options.body),{ref:'main',inputs:{pipeline:route.canonicalID,run_title:title(contract)}});
   return Response.json({workflow_run_id:runID,run_url:`https://api.github.com/repos/${contract.repository}/actions/runs/${runID}`,html_url:valid.html_url});}
  if(url.endsWith('/actions/runs/'+runID))return Response.json(valid);
  if(url.includes('/actions/runs?'))return Response.json({workflow_runs:[valid]});
  throw Error('夹具不接受其它接口');
 }});
 assert.equal(requests.filter(x=>x.url.endsWith('/dispatches')).length,1);assert.equal(requests.some(x=>x.options.method==='DELETE'),false);
 assert.match(log.chunks.join(''),/^PRODUCT_REMOTE_RUN:/u);assert.ok(!log.chunks.join('').includes(token));
});
test('派发失败、响应错仓及取消不能冒充成功',async()=>{
 const route=routes.find(x=>x.flow==='ci');
 for(const response of [new Response('denied',{status:403}),Response.json({workflow_run_id:1,run_url:'https://api.github.com/repos/other/product/actions/runs/1',html_url:'https://github.com/other/product/actions/runs/1'})]){
  const log=output();await assert.rejects(executeRemote('ci',route.platform,{environment:{GH_TOKEN:token},output:log,fetchImpl:async()=>response}));assert.equal(log.chunks.length,0);
 }
 const abort=new AbortController();abort.abort();let calls=0;
 await assert.rejects(executeRemote('ci',route.platform,{environment:{GH_TOKEN:token},signal:abort.signal,fetchImpl:async()=>{calls++;throw Error('不应请求');}}));assert.equal(calls,0);
});
test('成功CI选择保持同产品同平台，错标题、失败和错Workflow不能入选',async()=>{
 const route=routes.find(x=>x.flow==='release'),contract=remoteContract('release',route.platform),valid=row(remoteContract('ci',route.platform));let cleared;
 const selected=await latestSuccessfulCI(contract,token,{request:async()=>({total_count:4,workflow_runs:[valid,{...valid,id:runID+1,display_title:'其它产品 · Web · CI'},{...valid,id:runID+2,conclusion:'failure'},{...valid,id:runID+3,path:'.github/workflows/wrong.yml'}]}),prune:async value=>{cleared=value;}});
 assert.deepEqual(selected,{runId:runID,sourceSHA});assert.equal(cleared.canonicalId,contract.ciWorkflow);
 await assert.rejects(latestSuccessfulCI(contract,token,{request:async()=>({total_count:0,workflow_runs:[]}),prune:async()=>assert.fail('无成功CI不得清理')}));
});
test('重试只复用同成功CI源码与Run；新CI重新生成候选',async()=>{
 const route=routes.find(x=>x.flow==='release'),contract=remoteContract('release',route.platform),runtime=contract.sourceKind==='spec',version=runtime?2:'1.0.17';
 const previous={product_id:declaration.product_id,workflow:contract.workflow,software_flow:'release',ci_run_id:90,source_sha:sourceSHA,run_id:91,software_version:runtime?null:version,spec_version:runtime?version:null,version_tag:contract.tagPrefix+version,...runtime?{}:{platform:route.platform}};
 const environment={PRODUCT_RELEASE_RETRY_CONTEXT:Buffer.from(JSON.stringify(previous)).toString('base64')};let calls=0;
 const dependencies={findCI:async()=>({runId:90,sourceSHA}),createFresh:async(_contract,_environment,ci)=>{calls++;return {...previous,ci_run_id:ci.runId,run_id:null};}};
 assert.deepEqual(await selectReleaseCandidate(contract,environment,dependencies),previous);assert.equal(calls,0);
 assert.equal((await selectReleaseCandidate(contract,environment,{...dependencies,findCI:async()=>({runId:100,sourceSHA})})).run_id,null);assert.equal(calls,1);
 await assert.rejects(selectReleaseCandidate(contract,{PRODUCT_RELEASE_RETRY_CONTEXT:'!'},dependencies));
});
test('记录清理拒绝别仓并保护非同身份与活动Run',()=>{
 const route=routes.find(x=>x.flow==='ci'),contract=remoteContract('ci',route.platform),valid=row(contract);
 assert.equal(githubRetentionRecord({...valid,status:'in_progress',conclusion:null},contract.repository,contract.workflow).active,true);
 assert.equal(githubRetentionRecord({...valid,display_title:'其它产品 · Web · CI'},contract.repository,contract.workflow),null);
 assert.throws(()=>githubRetentionRecord(valid,'other/product',contract.workflow));
});
async function controlFrames(input,count=1){
 const moduleURL=new URL('./flow.mjs', import.meta.url).href;
 const source=`import {createControl,readReleaseControlFrame,closeControl} from ${JSON.stringify(moduleURL)};const control=createControl({PRODUCT_CONTROL_FD:'3'});try{const frames=[];for(let n=0;n<${count};n++)frames.push(await readReleaseControlFrame(control));process.stdout.write(JSON.stringify({frames}));}catch(error){process.stdout.write(JSON.stringify({error:error.message}));}finally{closeControl(control);}`;
 const child=spawn(process.execPath,['--input-type=module','-e',source],{stdio:['ignore','pipe','pipe','pipe']});let text='',error='';
 child.stdout.setEncoding('utf8').on('data',chunk=>text+=chunk);child.stderr.setEncoding('utf8').on('data',chunk=>error+=chunk);child.stdio[3].on('error',()=>{});
 const finished=new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',code=>code===0?resolve():reject(Error(error)));});
 const timer=setTimeout(()=>child.kill('SIGKILL'),5000);try{child.stdio[3].end(input);await finished;return JSON.parse(text);}finally{clearTimeout(timer);}
}
test('真实控制管道按序读取有界帧且异常关闭后进程退出',async()=>{
 assert.deepEqual(await controlFrames('accepted\nresult\n',2),{frames:['accepted','result']});
 for(const input of ['', '\n','invalid\0frame\n','a'.repeat(65537)+'\n'])assert.ok((await controlFrames(input)).error);
 assert.equal((await controlFrames('a'.repeat(65536)+'\n')).frames[0].length,65536);
});

for(const route of routes.filter(value=>value.flow==='release'))test(route.canonicalID+'独立Release候选、成功CI和正式版本都由产品验真',async()=>{
 const contract=remoteContract('release',route.platform);
 if(contract.sourceKind==='spec')return;
 const ci=remoteContract('ci',route.platform),validCI=row(ci),releaseRow={...row(contract),id:runID+1,html_url:`https://github.com/${contract.repository}/actions/runs/${runID+1}`};
 const log=output(),requests=[];let inputs;
 const source=contract.sourceKind==='pubspec'||contract.sourceKind==='pubspec-package'?'version: 1.0.0\n':contract.sourceKind==='cargo-workspace'?'[workspace.package]\nversion = "1.0.0"\n':'{"version":"1.0.0"}';
 await executeRemote('release',route.platform,{environment:{GH_TOKEN:token},output:log,fetchImpl:async(url,options)=>{
  requests.push({url,options});
  if(url.includes('/actions/workflows/')&&url.includes('/runs?'))return Response.json({total_count:1,workflow_runs:[validCI]});
  if(url.includes('/actions/runs?'))return Response.json({workflow_runs:inputs?[validCI,releaseRow]:[validCI]});
  if(url.endsWith('/actions/runs/'+runID))return Response.json(validCI);
  if(url.includes('/contents/'))return new Response(source);
  if(url.includes('/releases?'))return Response.json([]);
  if(url.endsWith('/dispatches')){
   inputs=JSON.parse(options.body).inputs;assert.equal(inputs.pipeline,route.canonicalID);assert.equal(inputs.source_sha,sourceSHA);assert.equal(inputs.ci_run_id,String(runID));assert.equal(inputs.version_tag,contract.tagPrefix+'1.0.0');
   return Response.json({workflow_run_id:runID+1,run_url:`https://api.github.com/repos/${contract.repository}/actions/runs/${runID+1}`,html_url:releaseRow.html_url});
  }
  if(url.endsWith('/actions/runs/'+(runID+1)))return Response.json(releaseRow);
  if(url.includes('/releases/tags/'))return Response.json(formalRecordFixture(route).release);
  if(url.includes('/git/ref/tags/'))return Response.json({ref:'refs/tags/'+inputs.version_tag,object:{type:'commit',sha:sourceSHA}});
  if(url.endsWith('/releases/assets/501'))return new Response(JSON.stringify(formalRecordFixture(route).metadata));
  throw Error('夹具拒绝其它接口');
 }});
 assert.equal(requests.filter(x=>x.url.endsWith('/dispatches')).length,1);
 const markers=log.chunks.filter(x=>x.startsWith('PRODUCT_RELEASE_CANDIDATE:'));assert.equal(markers.length,2);
 const final=JSON.parse(Buffer.from(markers[1].slice('PRODUCT_RELEASE_CANDIDATE:'.length).trim(),'base64').toString('utf8'));
 assert.equal(final.run_id,runID+1);assert.equal(final.ci_run_id,runID);assert.equal(final.source_sha,sourceSHA);
});


function formalRecordFixture(route) {
 const policy=recordSourceContract(route.platform),contract=remoteContract('release',route.platform),tag=contract.tagPrefix+'1.0.0';
 const metadata=policy.kind==='manifest'?{product_id:declaration.product_id,[policy.version_field]:'1.0.0',[policy.source_field]:sourceSHA}:null;
 const body=policy.marker_prefix?[policy.marker_prefix+'_RELEASE_CI_RUN_ID:41',policy.marker_prefix+'_RELEASE_RUN_ID:42',policy.marker_prefix+'_RELEASE_SOURCE_SHA:'+sourceSHA].join('\n'):'';
 const assets=policy.kind==='manifest'?[{id:501,name:policy.metadata_asset,size:Buffer.byteLength(JSON.stringify(metadata)),state:'uploaded'}]:policy.asset_names.map((name,i)=>({id:501+i,name,size:5,state:'uploaded'}));
 const release={id:401,name:contract.title,tag_name:tag,draft:false,prerelease:false,immutable:policy.immutable,assets,body,
  published_at:'2026-10-06T12:00:00Z',html_url:'https://github.com/'+contract.repository+'/releases/tag/'+tag};
 return {policy,release,metadata,tag,contract};
}
for(const route of routes.filter(row=>row.recordsFormalRelease))test(route.canonicalID+'正式记录验真归产品并拒绝错源/错资产/重复标记',()=>{
 const {policy,release,metadata}=formalRecordFixture(route);
 assert.equal(validateFormalRecordSource(route.platform,release,sourceSHA,metadata),sourceSHA);
 assert.throws(()=>validateFormalRecordSource(route.platform,{...release,draft:true},sourceSHA,metadata));
 // 错归属仍使用当前正式版本，只改变产品前缀并真实断言拒绝。
 assert.throws(()=>validateFormalRecordSource(route.platform,{...release,tag_name:'foreign-'+release.tag_name},sourceSHA,metadata));
 assert.throws(()=>validateFormalRecordSource(route.platform,release,'bad',metadata));
 if(policy.kind==='manifest') {
  assert.throws(()=>validateFormalRecordSource(route.platform,release,sourceSHA,{...metadata,product_id:'foreign'}));
  assert.throws(()=>validateFormalRecordSource(route.platform,release,sourceSHA,{...metadata,[policy.version_field]:'1.0.1'}));
 }
 if(policy.kind==='body') {
  assert.throws(()=>validateFormalRecordSource(route.platform,{...release,assets:[]},sourceSHA));
  assert.throws(()=>validateFormalRecordSource(route.platform,{...release,body:release.body+'\n'+policy.marker_prefix+'_RELEASE_SOURCE_SHA:'+sourceSHA},sourceSHA));
  assert.throws(()=>validateFormalRecordSource(route.platform,{...release,body:release.body.replace(sourceSHA,'b'.repeat(40))},sourceSHA));
 }
 if(policy.immutable)assert.throws(()=>validateFormalRecordSource(route.platform,{...release,immutable:false},sourceSHA));
});
test('软件记录独立刷新保持同仓、固定公开回执与真实保留器，不删除正式资产',async()=>{
 const requested=[],repository=remoteContract(routes[0].flow,routes[0].platform).repository;
 const receipt=await querySoftwareRecords({environment:{GH_TOKEN:token},fetchImpl:async(url,options)=>{
  requested.push({url,options});assert.equal(options.headers.Authorization,'Bearer '+token);assert.equal(options.method,'GET');
  if(url.includes('/actions/runs?'))return Response.json({workflow_runs:[]});
  if(url.includes('/releases?'))return Response.json([]);
  throw Error('夹具不允许其它操作');
 }});
 assert.deepEqual(receipt,{records:[],removed_run_ids:[]});assert.ok(requested.every(row=>row.url.startsWith('https://api.github.com/repos/'+repository+'/')));
 assert.equal(JSON.stringify(receipt).includes(token),false);
});
test('软件记录读取最新版正式资产，元数据重定向不会转发仓库令牌',async()=>{
 const route=routes.find(row=>row.recordsFormalRelease);if(!route)return;
 const {policy,release,metadata,tag,contract}=formalRecordFixture(route);const requests=[];
 const receipt=await querySoftwareRecords({environment:{GH_TOKEN:token},fetchImpl:async(url,options)=>{
  requests.push({url,options});
  if(url.startsWith('https://release-assets.githubusercontent.com/')){assert.equal(options.headers,undefined);return new Response(JSON.stringify(metadata));}
  assert.ok(url.startsWith('https://api.github.com/repos/'+contract.repository+'/'));assert.equal(options.headers.Authorization,'Bearer '+token);
  if(url.includes('/actions/runs?'))return Response.json({workflow_runs:[]});
  if(url.includes('/releases?'))return Response.json([release]);
  if(url.includes('/releases/tags/'))return Response.json(release);
  if(url.includes('/git/ref/tags/'))return Response.json({ref:'refs/tags/'+tag,object:{type:'commit',sha:sourceSHA}});
  if(url.endsWith('/releases/assets/501'))return new Response(null,{status:302,headers:{location:'https://release-assets.githubusercontent.com/fixture/manifest'}});
  throw Error('夹具不接受其它接口');
 }});
 assert.equal(receipt.records.length,1);assert.equal(receipt.records[0].source_sha,sourceSHA);assert.equal(receipt.records[0].tag_sha,sourceSHA);
 assert.equal(receipt.records[0].repository,contract.repository);assert.deepEqual(receipt.removed_run_ids,[]);
 assert.equal(requests.some(row=>row.url.includes('release-assets.githubusercontent.com')),policy.kind==='manifest');
});
test('软件记录错误接口、超限结果与取消失败，不泄露远端诊断或令牌',async()=>{
 for(const fetchImpl of [async()=>{throw Error(token);},async()=>Response.json({workflow_runs:Array(101).fill({})}),async()=>Response.json({workflow_runs:[]},{status:500})]) {
  await assert.rejects(querySoftwareRecords({environment:{GH_TOKEN:token},fetchImpl}),error=>!error.message.includes(token));
 }
 const cancellation=new AbortController();cancellation.abort(Error('准确任务取消'));
 await assert.rejects(querySoftwareRecords({environment:{GH_TOKEN:token},signal:cancellation.signal,fetchImpl:async()=>{throw Error('不能开始网络操作');}}),/准确任务取消/u);
});

for(const route of routes.filter(row=>row.flow==='release'&&row.recordsFormalRelease))test(route.canonicalID+'恢复同一Run并返回产品完整验真回执，不重新派发',async()=>{
 const {release,metadata,tag,contract}=formalRecordFixture(route),ci=remoteContract('ci',route.platform);
 const candidate={product_id:declaration.product_id,platform:route.platform,software_flow:'release',software_version:'1.0.0',
  source_sha:sourceSHA,spec_version:null,workflow:contract.workflow,ci_run_id:runID,run_id:runID+1,version_tag:tag};
 const releaseRun={...row(contract),id:runID+1,run_number:12,html_url:'https://github.com/'+contract.repository+'/actions/runs/'+(runID+1)};
 const requests=[];
 const fetchImpl=async(url,options)=>{
  requests.push({url,options});assert.equal(options.method??'GET','GET');
  if(url.endsWith('/actions/runs/'+(runID+1)))return Response.json(releaseRun);
  if(url.endsWith('/actions/runs/'+runID))return Response.json(row(ci));
  if(url.includes('/actions/runs?'))return Response.json({workflow_runs:[row(ci),releaseRun]});
  if(url.includes('/releases/tags/'))return Response.json(release);
  if(url.includes('/git/ref/tags/'))return Response.json({ref:'refs/tags/'+tag,object:{type:'commit',sha:sourceSHA}});
  if(url.endsWith('/releases/assets/501'))return new Response(JSON.stringify(metadata));
  throw Error('恢复夹具不能派发或执行其它操作');
 };
 const environment={GH_TOKEN:token,PRODUCT_RELEASE_RETRY_CONTEXT:Buffer.from(JSON.stringify(candidate)).toString('base64')};
 const receipt=await recoverRemote('release',route.platform,runID+1,'success',{environment,fetchImpl});
 assert.deepEqual(receipt.removed_run_ids,[]);assert.equal(receipt.formal_release.run_id,runID+1);assert.equal(receipt.formal_release.run_number,12);
 assert.equal(receipt.formal_release.source_sha,sourceSHA);assert.equal(receipt.formal_release.tag,tag);
 releaseRun.conclusion='failure';await assert.rejects(recoverRemote('release',route.platform,runID+1,'success',{environment,fetchImpl}),/终态不一致/u);
 releaseRun.conclusion='success';candidate.source_sha='b'.repeat(40);environment.PRODUCT_RELEASE_RETRY_CONTEXT=Buffer.from(JSON.stringify(candidate)).toString('base64');
 await assert.rejects(recoverRemote('release',route.platform,runID+1,'success',{environment,fetchImpl}),/成功CI/u);
});

// 公开Workflow和Job的真实文件只由所属产品本仓检查，不依赖其它仓检出。
test('本仓声明、实际Workflow与准确主Job写权限闭合', async () => {
 const { readdirSync, lstatSync } = await import('node:fs');
 const expected=['tatagate.yml',...routes.map(route=>route.canonicalID.replaceAll('.','-')+'.yml')].sort();
 assert.deepEqual(readdirSync(join(root,'.github/workflows')).sort(),expected);
 assert.equal(declaration.product_id,"citizenapp");
 assert.equal(declaration.entry,'scripts/build.mjs');
 for(const route of routes){
  const entry=declaration.platforms[route.platform]?.[route.flow]?.entry;
  assert.equal(entry,'.github/workflows/'+route.canonicalID.replaceAll('.','-')+'.yml');
  const file=join(root,entry),info=lstatSync(file);assert.ok(info.isFile()&&!info.isSymbolicLink());
  const source=readFileSync(file,'utf8');
  assert.ok(Buffer.byteLength(source)<500000,route.canonicalID);
  assert.ok(source.includes('name: '+route.canonicalID));
  assert.ok(source.includes('allowed=new Set(["'+route.canonicalID+'"])'));
  assert.match(source,/^  flow:$/mu);
  if(route.flow==='release'){
   const main=source.match(/^  flow:\n([\s\S]*?)(?=^  [A-Za-z_][\w-]*:|$(?![\s\S]))/mu);
   assert.ok(main,route.canonicalID);assert.match(main[1],/^      contents: write$/mu,route.canonicalID);
  }
 }
});
test('本仓远端作业只有同平台合并入口且保留末尾回归',async()=>{
 const {readdirSync}=await import('node:fs');
 for(const kind of ['ci','release']){
  assert.deepEqual(readdirSync(join(root,'scripts',kind)).sort(),['android.mjs','ios.mjs']);
  for(const platform of ['android','ios']){
   const source=readFileSync(join(root,'scripts',kind,platform+'.mjs'),'utf8');
   assert.match(source,/if\(inlineTestEntry\)/u);assert.match(source,/test\(/u);
  }
 }
});

 await Promise.all(pending);
 });
}

// 同文件回归：普通导入和正式命令不注册测试。
if(inlineTestEntry){
 const {test:register}=await import('node:test');
 register('同文件回归组 2',async context=>{
 const pending=[];const test=(...args)=>{const item=context.test(...args);pending.push(item);return item;};
const {default: assert} = await import("node:assert/strict");
const {
  cacheIdentity, cacheKeys, cachePathPlan, parseCacheKey, planCachePrune,
} = inlineTestOwner;

const identity = cacheIdentity({
  repository: 'crcfrcn/citizenapp', product: 'citizenapp', platform: 'ios',
  architecture: 'arm64', component: 'citizenapp-ci-ios--ios',
  runnerOs: 'macos', runnerArch: 'arm64', toolchainFingerprint: 'a'.repeat(64),
});

// 合成检出证明测试不能创建固定根，入口初始化后根的身份及既有内容保持。
test('固定target根只由工作区入口准备，测试仅创建子目录',async()=>{
 const fs=await import('node:fs'),{join}=await import('node:path'),build=await import('./build.mjs');
 const area=fs.mkdtempSync(join(build.testRoot(),'fixed-target-owner-'));
 try{
  const scripts=join(area,'scripts');fs.mkdirSync(scripts);
  fs.copyFileSync(new URL('./build.mjs', import.meta.url),join(scripts,'build.mjs'));
  fs.copyFileSync(new URL('./flows.json', import.meta.url),join(scripts,'flows.json'));
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
    import('node:fs'), import('node:path'), import('node:child_process'), import('./build.mjs'),
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
        new URL('./build.mjs', import.meta.url).href,platform,path,kind,destination], {encoding:'utf8'});
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
  const {runWorkflow}=inlineTestOwner,{cacheCommands}=inlineTestOwner;
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
  const {testRoot:tmpdir}=await import('./build.mjs'),{join}=await import('node:path');
  const {sanitizeCacheFinals,wireCacheLinks}=inlineTestOwner;
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

 await Promise.all(pending);
 });
}

// 同文件回归：普通导入和正式命令不注册测试。
if(inlineTestEntry){
 const {test:register}=await import('node:test');
 register('同文件回归组 3',async context=>{
 const pending=[];const test=(...args)=>{const item=context.test(...args);pending.push(item);return item;};
const {BUILD_SHELL_SOURCES} = await import("./build.mjs");
const {default: assert} = await import("node:assert/strict");
const { execFileSync, spawnSync } = await import("node:child_process");
const { readFileSync, writeFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, realpathSync, rmSync, symlinkSync } = await import("node:fs");
const { join } = await import("node:path");
const { testRoot: tmpdir } = await import("./build.mjs");
const { fileURLToPath, pathToFileURL } = await import("node:url");
const { createHash } = await import("node:crypto");
const { gradleRecipes, revisedSource, revisionPlan } = await import("./resources.mjs");
const { jobIdentity: android, workflowSteps: androidSteps } = await import("./ci/android.mjs");
const { checkJobIdentity: androidCheck, checkWorkflowSteps: androidCheckSteps } = await import("./ci/android.mjs");
const { jobIdentity: ios, workflowSteps: iosSteps } = await import("./ci/ios.mjs");
const { checkJobIdentity: iosCheck, checkWorkflowSteps: iosCheckSteps } = await import("./ci/ios.mjs");
const { runWorkflow } = inlineTestOwner;

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
    argumentsList: ['workflow-step', '999'], environment: { GITHUB_REPOSITORY: 'crcfrcn/citizenapp',
      GITHUB_ACTIONS: 'true', GITHUB_EVENT_NAME: 'workflow_dispatch', GITHUB_WORKFLOW: ios.pipeline, GITHUB_JOB: 'flow' },
  }), /阶段无效/u);
  await assert.rejects(runWorkflow(ios, iosSteps, {}, {
    argumentsList: ['workflow-step', '0'], environment: { GITHUB_REPOSITORY: 'crcfrcn/citizenchain' },
  }), /仓库身份/u);
});

test('CitizenApp CI Workflow只引用六层内的唯一扁平文件', () => {
  for (const [platform, names] of [['android', ['android.mjs']], ['ios', ['ios.mjs']]]) {
    const workflow = readFileSync(new URL(`../.github/workflows/citizenapp-${platform}-ci.yml`, import.meta.url), 'utf8');
    for (const name of names) assert.match(workflow, new RegExp(`scripts/ci/${name.replace('.', '[.]')}`, 'u'));
    assert.doesNotMatch(workflow, /scripts\/ci\/(?:android|ios)\//u);
  }
  for (const source of ['./ci/android.mjs', './ci/ios.mjs']
    .map(path => readFileSync(new URL(path, import.meta.url), 'utf8'))) {
    assert.doesNotMatch(source, /function cacheIdentity|function runExactWorkflowStep/u);
  }
});


test('CitizenApp消费视图实际绑定SDK标准入口且CI重用不丢失Pub状态', () => {
  const source = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/u, '');
  const work = realpathSync(mkdtempSync(join(tmpdir(), 'citizenapp-view-')));
  const sdk = join(work, 'git-sources/citizen_sdk');
  const script = join(source, 'scripts/build.mjs');
  const flutter = join(work, 'flutter');
  for (const name of ['gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar']) {
    const path = join(flutter, 'bin/cache/artifacts/gradle_wrapper', name);
    mkdirSync(join(path, '..'), { recursive: true });
    writeFileSync(path, 'synthetic wrapper ' + name);
  }
  const run = command => spawnSync(process.execPath, [script, 'view', command,
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
    assert.match(steps['8'].source, /build\.mjs.*view.*create/u);
    assert.match(steps['8'].source, /CITIZENAPP_TEST_PROJECT_ROOT/u);
    assert.match(steps['9'].source, /build\.mjs test/u);
  }
  assert.match(androidSteps['8'].source, /create-android/u);
  assert.match(androidSteps['9'].source, /project="\$CITIZENAPP_PROJECT_ROOT"/u);
  assert.match(androidSteps['10'].source, /cd "\$CITIZENAPP_PROJECT_ROOT"/u);
  const runner = BUILD_SHELL_SOURCES.test;
  assert.match(runner, /"\$VIEW_SCRIPT" view verify/u);
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
  const source = join(fixture, 'source'), work = join(source, 'target/work');
  const script = fileURLToPath(new URL('./build.mjs', import.meta.url));
  mkdirSync(join(source, 'ios/project'), { recursive: true });
  mkdirSync(join(source, 'android'));
  seedFixtureDependency(source, work);
  const run = output => spawnSync(process.execPath, [script, 'view', 'create', '--source-root', source,
    '--work-root', output], { encoding: 'utf8' });
  try {
    assert.match(run(work).stderr, /平台输入缺少/u);
    for (const name of ['Runner', 'RunnerUITests']) writeFileSync(join(source, `ios/project/${name}.xcscheme`), '<Scheme/>');
    for (const name of ['gradle-wrapper.properties']) writeFileSync(join(source, 'android', name), 'fixture');
    assert.equal(run(work).status, 0);
    const unavailableGit = spawnSync(process.execPath, [script, 'view', 'dependencies',
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
    assert.match(run(join(source, 'output')).stderr, /产品工作根必须在本仓target内/u);
    const legacy = join(source, 'ios/Runner.xcodeproj/xcshareddata/xcschemes');
    mkdirSync(legacy, { recursive: true });
    writeFileSync(join(legacy, 'Runner.xcscheme'), '<Scheme/>');
    assert.match(run(work).stderr, /平台入口重复/u);
  } finally { rmSync(fixture, { recursive: true }); }
});


// 金标入口实际验真链快照；夹具只提供合成Git提交和无业务含义JSON，不读取正式仓或网络。
test('公民链金标输入拒绝主分支、脏输入和错误来源', async () => {
  const { mkdtempSync, realpathSync, mkdirSync, writeFileSync, rmSync } = await import('node:fs');
  const { join } = await import('node:path'); const { testRoot: tmpdir } = await import('./build.mjs');
  const { spawnSync } = await import('node:child_process');
  const base = realpathSync(mkdtempSync(join(tmpdir(), 'app-chain-input-')));
  const chain = join(base, 'chain'), work = join(base, 'work'); mkdirSync(chain); mkdirSync(work);
  const git = args => {
    const result = spawnSync('git', ['-c', 'core.hooksPath=/dev/null', '-C', chain, ...args], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr); return result.stdout.trim();
  };
  const run = value => spawnSync(process.execPath, [new URL('./build.mjs', import.meta.url).pathname, 'inputs', value], {
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
      writeFileSync(join(source,'scripts/build.mjs'),`
import{appendFileSync}from'node:fs';const command=process.argv[3];
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
  writeFileSync(join(root,'scripts/resources.mjs'),"import{appendFileSync}from'node:fs';\n" +
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

// 实际执行摘要和上下文变换，覆盖原始/已修订输入、破坏、链接、路径及整批拒绝。
test('Flutter CI修订核验完整前后摘要且未知输入不形成写入计划', () => {
  const root=realpathSync(mkdtempSync(join(tmpdir(),'app-ci-flutter-')));
  const hash=value=>createHash('sha256').update(value).digest('hex');
  const original='// upstream\nold\nlast\n',result='// upstream\nnew\nextra\nlast\n';
  const recipe={path:'packages/flutter_tools/gradle/fixture.kt',beforeSha256:hash(original),afterSha256:hash(result),
    hunks:[{start:1,beforeCount:1,beforeSha256:hash('old'),after:['new','extra']}]};
  try {
    assert.equal(revisedSource(original,recipe),result);
    assert.equal(revisedSource(result,recipe),result);
    assert.throws(()=>revisedSource(original+'damage',recipe),/原始摘要/);
    assert.throws(()=>revisedSource(original,{...recipe,hunks:[{...recipe.hunks[0],beforeSha256:hash('unknown')}]}),/上下文/);
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
    symlinkSync(join(root,second.path),file);
    assert.throws(()=>revisionPlan(root,[recipe]),/普通文件/);
    assert.equal(gradleRecipes.length,6);
    assert.equal(new Set(gradleRecipes.map(x=>x.path)).size,6);
    const plugin=gradleRecipes.find(x=>x.path.endsWith('/FlutterPlugin.kt'));
    const revised=plugin.hunks.flatMap(x=>x.after).join('\n');
    assert.match(revised,/androidComponents|components\.onVariants/);
    assert.doesNotMatch(revised,/as AbstractAppExtension|android\.applicationVariants/);
  } finally {rmSync(root,{recursive:true,force:true});}
});

// 解析实际YAML引用并执行终态分支，拒绝越界阶段及无状态的无条件record。
test('App双端CI所有YAML阶段可执行且缓存终态与候选上传顺序准确', () => {
  for(const [platform,steps] of [['android',androidSteps],['ios',iosSteps]]) {
    const yaml=readFileSync(new URL('../.github/workflows/citizenapp-'+platform+'-ci.yml',import.meta.url),'utf8');
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

// 真实唯一执行器覆盖两个CI检查、两个CI编译及两个Release；拒绝路径不执行正文。
test('六个远端Job保留实际身份且在错误环境下拒绝执行正文', async () => {
  for (const [identity] of [...jobs, [{pipeline:'citizenapp.android.release',job:'android'}],
    [{pipeline:'citizenapp.ios.release',job:'ios'}]]) {
    const expectedJob=identity.job==='check'?'stage_1':'flow';
    const environment={GITHUB_REPOSITORY:'crcfrcn/citizenapp',GITHUB_ACTIONS:'true',
      GITHUB_EVENT_NAME:'workflow_dispatch',GITHUB_WORKFLOW:identity.pipeline,GITHUB_JOB:expectedJob};
    let calls=0;
    const execute=env=>runWorkflow(identity, {'0':{shell:'bash',source:'true'}}, {}, {
      argumentsList:['workflow-step','0'],environment:env,run:(_command,_args,options)=>{
        calls++;assert.equal(options.env.GITHUB_WORKFLOW,identity.pipeline);
        assert.equal(options.env.GITHUB_JOB,expectedJob);return {status:0};
      },
    });
    await execute(environment);assert.equal(calls,1);
    for(const change of [{GITHUB_ACTIONS:'false'},{GITHUB_EVENT_NAME:'push'},
      {GITHUB_WORKFLOW:'citizenapp.android.release.other'},{GITHUB_WORKFLOW:undefined},
      {GITHUB_JOB:expectedJob==='flow'?'stage_1':'flow'},{GITHUB_JOB:undefined},
      {GITHUB_REPOSITORY:'crcfrcn/citizenchain'}]) {
      await assert.rejects(execute({...environment,...change}),/身份/u);
      assert.equal(calls,1);
    }
    await assert.rejects(runWorkflow({...identity,job:'unknown'}, {}, {}, {
      argumentsList:['workflow-step','0'],environment,run:()=>{calls++;return {status:0};}
    }),/身份/u);assert.equal(calls,1);
  }
});

 await Promise.all(pending);
 });
}

// 同文件回归：普通导入和正式命令不注册测试。
if(inlineTestEntry){
 const {test:register}=await import('node:test');
 register('同文件回归组 4',async context=>{
 const pending=[];const test=(...args)=>{const item=context.test(...args);pending.push(item);return item;};
const {default: assert} = await import("node:assert/strict");
const { spawnSync } = await import("node:child_process");
const { readFileSync } = await import("node:fs");
const { toolEnvironment } = await import("./resources.mjs");
const { jobIdentity: android, workflowSteps: androidSteps } = await import("./release/android.mjs");
const { jobIdentity: ios, workflowSteps: iosSteps } = await import("./release/ios.mjs");

test('CitizenApp两个Release Job保留准确身份且共用唯一版本实现', () => {
  assert.deepEqual([android, ios].map(value => `${value.pipeline}:${value.job}`).sort(), [
    'citizenapp.android.release:android', 'citizenapp.ios.release:ios',
  ]);
  // 所属仓一次验真四份正式工具，Shell语法校验只使用交付的GNU Bash及封闭环境。
  const environment = toolEnvironment();
  for (const steps of [androidSteps, iosSteps]) {
    assert.ok(Object.values(steps).some(step => step.source.includes('scripts/flow.mjs version')));
    for (const step of Object.values(steps)) {
      const result = spawnSync(environment.PRODUCT_BASH_BIN, ['--noprofile', '--norc', '-n'], {
        input: step.source, env: environment, encoding: 'utf8', timeout: 20_000,
      });
      assert.equal(result.error, undefined);
      assert.equal(result.signal, null);
      assert.equal(result.status, 0, result.stderr);
    }
  }
});

test('CitizenApp Release Workflow只引用两个扁平平台Job', () => {
  for (const platform of ['android', 'ios']) {
    const workflow = readFileSync(new URL(`../.github/workflows/citizenapp-${platform}-release.yml`, import.meta.url), 'utf8');
    assert.match(workflow, new RegExp(`scripts/release/${platform}[.]mjs`, 'u'));
    assert.doesNotMatch(workflow, /scripts\/release\/(?:android|ios)\//u);
  }
  const sources = ['./release/android.mjs', './release/ios.mjs'].map(path => readFileSync(new URL(path, import.meta.url), 'utf8'));
  for (const source of sources) assert.doesNotMatch(source, /github-release|function runExactWorkflowStep/u);
});


test('Android Release的Pub、Gradle与产物回读消费同一轮目录', () => {
  assert.match(androidSteps['6'].source, /create-android/u);
  assert.match(androidSteps['7'].source, /project="\$CITIZENAPP_PROJECT_ROOT"/u);
  assert.match(androidSteps['7'].source, /CITIZENAPP_PROJECT_ROOT/u);
  assert.match(androidSteps['7'].source, /CITIZENAPP_BUILD_DIR/u);
  assert.match(androidSteps['7'].source, /ln -s "\$build" "\$project\/build"/u);
  assert.match(androidSteps['8'].source, /^cd "\$CITIZENAPP_PROJECT_ROOT"/u);
  assert.match(androidSteps['9'].source, /verify_archive build\/app\/outputs/u);
  assert.match(iosSteps['5'].source, /build\.mjs.*view/u);
});

// 准确入口缺失或漂移必须在执行Release脚本正文前失败，不借用系统PATH。
test('Release合同Shell拒绝缺失相对路径与错误Bash版本', () => {
  for (const path of [undefined, '', 'bash', './bash', process.execPath]) {
    assert.throws(() => toolEnvironment({ ...process.env, PRODUCT_BASH_BIN: path }), /产品门禁资源/u);
  }
});

// 用真实交付的GNU Bash执行语法失败分支，确保坏正文无法记为成功。
test('Release合同Shell的无效正文由真实GNU Bash拒绝', () => {
  const environment = toolEnvironment();
  const result = spawnSync(environment.PRODUCT_BASH_BIN, ['--noprofile', '--norc', '-n'], {
    input: 'if then\n', env: environment, encoding: 'utf8', timeout: 20_000,
  });
  assert.equal(result.error, undefined);
  assert.equal(result.signal, null);
  assert.equal(result.status, 2);
  assert.match(result.stderr, /syntax error/u);
});

 await Promise.all(pending);
 });
}

// 同文件回归：普通导入和正式命令不注册测试。
if(inlineTestEntry){
 const {test:register}=await import('node:test');
 register('同文件回归组 5',async context=>{
 const pending=[];const test=(...args)=>{const item=context.test(...args);pending.push(item);return item;};
const {default: assert} = await import("node:assert/strict");
const {
  compareSemanticVersions, expectedSemanticCandidate, nextSemanticVersion, parseSemanticVersion,
} = inlineTestOwner;

test('CitizenApp两端Release共用唯一语义版本实现', () => {
  assert.deepEqual(parseSemanticVersion('1.2.3'), [1, 2, 3]);
  assert.equal(compareSemanticVersions('1.2.3', '1.2.4'), -1);
  assert.equal(nextSemanticVersion('1.99.99'), '2.0.0');
  assert.equal(expectedSemanticCandidate('1.0.0', ['1.0.0', '1.0.2']), '1.0.3');
  assert.throws(() => parseSemanticVersion('1.100.0'), /软件版本/u);
});

// 两端真实版本CLI从所属Workflow根读取种子；GitHub与Git仅在合成子进程交付固定事实。
test('Release来源验真读取本仓pubspec并拒绝错来源、错版本与缺少原文', async () => {
  const fs = await import('node:fs'), {join} = await import('node:path');
  const {spawnSync} = await import('node:child_process'), build = await import('./build.mjs');
  const area = fs.mkdtempSync(join(build.testRoot(), 'release-source-root-'));
  try {
    const project = join(area, 'project'); fs.mkdirSync(project);
    const source = join(project, 'pubspec.yaml'), sha = 'a'.repeat(40);
    const script = new URL('./flow.mjs', import.meta.url).pathname, preload = join(area, 'facts.mjs');

    fs.writeFileSync(preload, `import cp from 'node:child_process';
import {syncBuiltinESMExports} from 'node:module';
cp.execFileSync=(command,args)=>{
 if(command==='git'&&args.join(' ')==='rev-parse HEAD')return process.env.FIXTURE_SHA;
 if(command==='gh'&&args[0]==='api'){
  if(args[1].includes('/actions/runs/'))return JSON.stringify({status:'completed',conclusion:'success',event:'workflow_dispatch',head_branch:'main',head_sha:process.env.FIXTURE_SHA,display_title:process.env.FIXTURE_TITLE,path:process.env.FIXTURE_WORKFLOW});
  if(args[1].includes('/releases?'))return '[]';
 }
 throw Error('合成事实拒绝未登记子进程');
};syncBuiltinESMExports();
`);
    for (const platform of ['android', 'ios']) {
      const invoke = (version = '1.0.0', sourceSHA = sha) => spawnSync(process.execPath, [
        '--import', preload, script, 'version', 'verify-release-source', '--ci-run-id', '1',
        '--version-tag', `citizenapp-${platform}-v${version}`, '--source-sha', sourceSHA,
        '--prefix', `citizenapp-${platform}-v`, '--product-id', 'citizenapp',
        '--target', platform, '--workflow', `citizenapp.${platform}.ci`,
      ], {cwd: project, env: {...process.env, FIXTURE_SHA: sha,
        FIXTURE_TITLE: `公民 · ${platform === 'ios' ? 'iOS' : 'Android'} · CI`,
        FIXTURE_WORKFLOW: `.github/workflows/citizenapp-${platform}-ci.yml`},
        encoding: 'utf8', timeout: 10000});
      const original = 'version: 1.0.0+1\n'; fs.writeFileSync(source, original);
      const success = invoke(); assert.equal(success.status, 0, success.stderr);
      assert.match(success.stdout, /Release 已锁定成功 CI/u);
      const wrongSource = invoke('1.0.0', 'b'.repeat(40));
      assert.equal(wrongSource.status, 1); assert.match(wrongSource.stderr, /成功 CI/u);
      const wrongVersion = invoke('1.0.1');
      assert.equal(wrongVersion.status, 1); assert.match(wrongVersion.stderr, /下一版本/u);
      assert.equal(fs.readFileSync(source, 'utf8'), original);
      fs.unlinkSync(source);
      const missing = invoke(); assert.equal(missing.status, 1);
      assert.match(missing.stderr, /ENOENT.*pubspec[.]yaml/u);
      assert.equal(fs.existsSync(source), false);
    }
  } finally {fs.rmSync(area, {recursive: true, force: true});}
});

 await Promise.all(pending);
 });
}
