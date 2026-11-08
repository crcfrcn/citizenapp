import {execFileSync, spawnSync} from 'node:child_process';
import {accessSync, appendFileSync, constants, copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

const platforms = {ios:{label:'iOS', attachments:2}, android:{label:'Android', attachments:3}};
const repository = (environment,path,repo=environment.GITHUB_REPOSITORY) => 'repos/' + repo + '/' + path;
const check = (condition,message) => { if (!condition) throw Error(message); };
const number = value => Number.isSafeInteger(value) && value > 0;
const json = file => JSON.parse(readFileSync(file,'utf8'));
const writeJson = (file,value) => writeFileSync(file,JSON.stringify(value,null,2)+'\n');
const envLine = (environment,key,value) => appendFileSync(environment.GITHUB_ENV,key+'='+value+'\n');
const pathLine = (environment,path) => appendFileSync(environment.GITHUB_PATH,path+'\n');
const gh = (environment,args,execute=execFileSync) => execute('gh',args,{env:environment,encoding:'utf8',maxBuffer:16*1024*1024});
export const api = (environment,path,repo,execute) =>
    JSON.parse(gh(environment,['api',repository(environment,path,repo)],execute));
const pages = (environment,path,key) => JSON.parse(gh(environment,['api','--paginate','--slurp',repository(environment,path)]))
    .flatMap(page=>key ? page[key] : page);
const remove = (environment,path) => gh(environment,['api','--method','DELETE',repository(environment,path)]);
const tagPath = tag => 'git/ref/tags/' + encodeURIComponent(tag);
const isCommit = (tag,sha) => tag.object?.type==='commit' && tag.object.sha===sha;
const prefix = platform => '公民·'+platforms[platform].label+'·v';

export async function readReleases(read,product) {
    const releases=[];
    for(let page=1;;page++){
        const rows=await read('releases?per_page=100&page='+page);
        check(Array.isArray(rows),product+'正式Release列表无效');
        releases.push(...rows);
        if(rows.length<100) return releases;
    }
}

export function releaseDownloadArgs({tag,repo,assets,label,output,uploaded=false}) {
    const matches=(assets??[]).filter(asset=>asset.label===label && (!uploaded || asset.state==='uploaded'));
    check(matches.length===1,'正式Release附件缺失或重复：'+label);
    return ['release','download',tag,'--repo',repo,'--pattern',matches[0].name,'--output',output];
}

export async function readVersion(platform,installed,environment=process.env,{read,readInitial}={}) {
    const tagPrefix=prefix(platform);
    const valid = value => typeof value === 'string' && /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/u.test(value);
    const fits = value => value.split('.').every(part => BigInt(part) < 2n ** 64n);
    if (installed) {
      const local = {...environment,PATH:[environment.PATH,'/opt/homebrew/bin','/usr/local/bin'].filter(Boolean).join(':'),
        GH_HOST:'github.com',GH_PROMPT_DISABLED:'1',GH_NO_UPDATE_NOTIFIER:'1',GH_DEBUG:''};
      read ??= path => api(local,path,'crcfrcn/citizenapp',
        (command,args,options)=>execFileSync(command,args,{...options,timeout:30000}));
    } else {
      read ??= path => api(environment,path);
    }
    const releases = await readReleases(read,'公民');
    const candidates = releases.filter(row => row.draft === false && row.prerelease === false
      && typeof row.tag_name === 'string' && row.tag_name.startsWith(tagPrefix))
      .sort((a,b) => String(b.published_at).localeCompare(String(a.published_at)) || b.id-a.id);
    let selected;
    for (const release of candidates) {
      let proof;
      try { proof = JSON.parse(release.body); } catch { continue; }
      if (proof?.product_id !== 'citizenapp' || proof.platform !== platform) continue;
      if (proof.schema !== 1 || !valid(proof.version) || release.tag_name !== tagPrefix + proof.version
          || (!installed && !fits(proof.version))
          || (installed && (!Number.isSafeInteger(proof.version_code) || proof.version_code <= 0))
          || !Number.isSafeInteger(proof.run_id) || proof.run_id <= 0) throw Error('公民正式版本记录无效');
      const run = await read('actions/runs/' + proof.run_id);
      if (run.status !== 'completed' || run.conclusion !== 'success') continue;
      if (run.path !== '.github/workflows/' + platform + '.yml' || run.head_branch !== 'main' || run.event !== 'workflow_dispatch'
          || run.head_sha !== proof.source_sha || run.run_attempt !== proof.run_attempt) throw Error('公民版本与成功Run不符');
      selected = proof;
      break;
    }
    const initial = () => /^version:\s*([^+\s]+)(?:\+(\d+))?/mu.exec(readInitial?.() ?? readFileSync(join(process.cwd(),'pubspec.yaml'),'utf8'));
    if (installed) {
      const base = selected ? [selected.version,String(selected.version_code)] : initial().slice(1);
      return {version:base[0], buildNumber:base[1] || '1'};
    } else {
      let version = selected?.version || initial()[1];
      if (selected) {
        const parts = version.split('.');
        parts[2] = String(BigInt(parts[2]) + 1n);
        version = parts.join('.');
      }
      if (!valid(version) || !fits(version)) throw Error('公民本轮版本无效');
      return version;
    }
}

function release(platform,environment) {
    const {WORK:work,GITHUB_SHA:sha,GITHUB_RUN_ID:runID,GITHUB_REPOSITORY:repo,CITIZENAPP_VERSION:version}=environment;
    const name=prefix(platform)+version, tag=tagPath(name);
    const matches=pages(environment,'releases?per_page=100').filter(item=>item.tag_name===name);
    check(matches.length<=1,'同名Release重复');
    if(matches.length){
        const proof=JSON.parse(matches[0].body);
        check(proof.product_id==='citizenapp' && proof.platform===platform && proof.version===version,'旧Release归属不符');
        const run=api(environment,'actions/runs/'+proof.run_id+'/attempts/'+proof.run_attempt);
        check(run.status==='completed' && run.conclusion!=='success' && run.head_sha===proof.source_sha
            && run.path==='.github/workflows/'+platform+'.yml','旧Release的Run归属或终态不符');
        check(isCommit(api(environment,tag),proof.source_sha),'旧Tag归属不符');
        gh(environment,['release','delete',name,'--repo',repo,'--yes','--cleanup-tag']);
    }
    // 未登记的同名Tag不覆盖，失败仅撤销本轮创建的对象。
    let created=false;
    try {
        const tagReceipt=gh(environment,['api','-X','POST',repository(environment,'git/refs'),'-f','ref=refs/tags/'+name,'-f','sha='+sha]);
        created=true;
        writeFileSync(join(work,'tag.json'),tagReceipt);
        const directory=join(work,'artifact'), files=readdirSync(directory).sort();
        gh(environment,['release','create',name,...files.map(file=>join(directory,file)+'#'+file),'--repo',repo,
            '--verify-tag','--target',sha,'--title',name,'--notes-file',join(work,'proof.json'),'--draft']);
        const receipt=gh(environment,['release','view',name,'--repo',repo,'--json','assets']);
        writeFileSync(join(work,'assets.json'),receipt);
        const {assets}=JSON.parse(receipt), readback=join(work,'readback');
        mkdirSync(readback);
        for(const file of files){
            gh(environment,releaseDownloadArgs({tag:name,repo,assets,label:file,output:join(readback,file)}));
            execFileSync('cmp',[join(directory,file),join(readback,file)],{env:environment});
        }
        gh(environment,['release','edit',name,'--repo',repo,'--draft=false','--prerelease=false','--latest=false']);
        const final=api(environment,'releases/tags/'+encodeURIComponent(name));
        check(final.draft===false && final.prerelease===false && final.published_at!=null && final.name===name
            && final.tag_name===name && final.target_commitish===sha && final.assets.length===platforms[platform].attachments,'正式Release回读不符');
        check(isCommit(api(environment,tag),sha),'正式Tag回读不符');
    } catch (error) {
        try {
            const owned=pages(environment,'releases?per_page=100').filter(item=>{
                if(item.tag_name!==name || item.target_commitish!==sha)return false;
                try { return JSON.parse(item.body)?.run_id===Number(runID); } catch { return false; }
            });
            if(owned.length===1 && number(owned[0].id)) remove(environment,'releases/'+owned[0].id);
        } catch { console.error('本次Release查询或撤销未完成'); }
        if(created){
            try {
                check(isCommit(api(environment,tag),sha),'本次Tag归属未确认');
                remove(environment,tag.replace('git/ref/','git/refs/'));
            } catch { console.error('本次Tag归属或撤销状态未确认'); }
        }
        throw error;
    }
}

// TATA.md 第 28 条：同平台保留最近成功和失败各一条，活动 Run 不清理。
function cleanup(platform,environment) {
    const current=Number(environment.GITHUB_RUN_ID), platformPrefix=prefix(platform);
    const gone=path=>{
        const result=spawnSync('gh',['api','--method','GET','--include','--silent',repository(environment,path)],
            {env:environment,encoding:'utf8',maxBuffer:16*1024*1024});
        const status=/^HTTP\/[0-9.]+[ \t]+([0-9]{3})(?:[ \t]|$)/m.exec([result.stdout,result.stderr].filter(Boolean).join('\n'))?.[1];
        check(result.status>0 && status==='404','无法确认对象已删除：'+path);
    };
    const list=(path,key)=>pages(environment,path,key);
    const runs=list('actions/workflows/'+platform+'.yml/runs?branch=main&per_page=100','workflow_runs');
    const keep=new Set([current,...runs.filter(run=>run.status!=='completed').map(run=>run.id)]);
    const latest=new Map();
    for(const run of runs.filter(run=>run.status==='completed'||run.id===current)){
        const result=run.id===current?environment.RESULT:run.conclusion==='success'?'success':'failure';
        const previous=latest.get(result);
        if(!previous || run.run_number>previous.run_number || (run.run_number===previous.run_number && run.id>previous.id)) latest.set(result,run);
    }
    for(const run of latest.values()) keep.add(run.id);
    const releases=()=>list('releases?per_page=100').filter(item=>item.tag_name.startsWith(platformPrefix));
    for(const item of releases()){
        const proof=JSON.parse(item.body);
        check(proof.product_id==='citizenapp' && proof.platform===platform && number(proof.run_id)
            && number(proof.run_attempt) && /^[a-f0-9]{40}$/u.test(proof.source_sha)
            && /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/u.test(proof.version)
            && item.tag_name===platformPrefix+proof.version && item.target_commitish===proof.source_sha,'历史Release回执归属不符');
        const old=runs.find(run=>run.id===proof.run_id);
        if(old) check(old.head_sha===proof.source_sha && old.run_attempt>=proof.run_attempt,'历史Run来源不符');
        else gone('actions/runs/'+proof.run_id);
        if(keep.has(proof.run_id)) continue;
        const tag=tagPath(item.tag_name);
        let ref;
        try { ref=api(environment,tag); } catch { gone(tag); }
        if(ref){
            check(isCommit(ref,proof.source_sha),'历史Tag归属不符');
            remove(environment,tag.replace('git/ref/','git/refs/'));
            gone(tag);
        }
        remove(environment,'releases/'+item.id);
        gone('releases/'+item.id);
    }
    const caches=()=>list('actions/caches?per_page=100','actions_caches');
    const stale=new Set(caches().filter(cache=>cache.ref==='refs/heads/main' && cache.key.startsWith('citizenapp-'+platform+'-'))
        .flatMap(cache=>{
            const owner=/-([1-9]\d*)-[1-9]\d*$/u.exec(cache.key);
            return owner && !keep.has(Number(owner[1])) ? [cache.id] : [];
        }));
    for(const id of stale) remove(environment,'actions/caches/'+id);
    check(caches().every(cache=>!stale.has(cache.id)),'旧缓存未清理');
    const obsolete=new Set(runs.filter(run=>run.status==='completed' && !keep.has(run.id)).map(run=>run.id));
    for(const id of obsolete){
        // 以 Run 专属列表记录附件归属，避免删除后仓库列表中的 workflow_run 为空。
        const attachments=list('actions/runs/'+id+'/artifacts?per_page=100','artifacts').map(artifact=>artifact.id);
        check(attachments.every(number),'旧附件编号无效');
        gh(environment,['run','delete',String(id),'--repo',environment.GITHUB_REPOSITORY]);
        gone('actions/runs/'+id);
        gone('actions/runs/'+id+'/logs');
        for(const attachment of attachments) gone('actions/artifacts/'+attachment);
    }
    check(list('actions/artifacts?per_page=100','artifacts').every(artifact=>!obsolete.has(artifact.workflow_run?.id)),'旧附件未清理');
    // 无回执的孤立Tag不从Run显示名猜归属。
    const protectedTags=new Set(releases().map(item=>{
        check(keep.has(JSON.parse(item.body).run_id),'仍有未清理的Release');
        return item.tag_name;
    }));
    check(list('git/matching-refs/tags/'+encodeURIComponent(platformPrefix)+'?per_page=100')
        .every(tag=>protectedTags.has(tag.ref.replace(/^refs\/tags\//u,''))),'存在无回执的Tag');
    console.log('本平台历史清理完成，保留Run：'+JSON.stringify([...keep].sort((a,b)=>a-b)));
}

const run = (file,args,environment,cwd) => execFileSync(file,args,{env:environment,cwd,stdio:'inherit'});
const workPath = environment => join(environment.GITHUB_WORKSPACE,'target/build',
    environment.GITHUB_RUN_ID+'-'+environment.GITHUB_RUN_ATTEMPT);

function prepare(platform,environment) {
    const work=workPath(environment), android=platform==='android';
    mkdirSync(work,{recursive:true});
    mkdirSync(join(environment.GITHUB_WORKSPACE,'target/cache'),{recursive:true});
    envLine(environment,'WORK',work);
    run(process.execPath,['scripts/build.mjs','prepare-flutter',platform],environment);
    run('rustup',['toolchain','install','1.97.1','--profile','minimal'],environment);
    run('rustup',['target','add','--toolchain','1.97.1',...(android?['aarch64-linux-android']:
        ['aarch64-apple-ios','aarch64-apple-ios-sim'])],environment);
    if(!android){
        const gems=join(work,'gems');
        run('gem',['install','cocoapods','-v','1.17.0','--no-document','--install-dir',gems],environment);
        envLine(environment,'GEM_HOME',gems);
        pathLine(environment,join(gems,'bin'));
    }
    const sdk=join(environment.HOME,'Library/Android/sdk'), sdkmanager=join(sdk,'cmdline-tools/latest/bin/sdkmanager');
    accessSync(sdkmanager,constants.X_OK);
    envLine(environment,'ANDROID_HOME',sdk);
    const packages=['cmake;3.31.6'];
    if(android){
        pathLine(environment,join(sdk,'cmdline-tools/latest/bin'));
        pathLine(environment,join(sdk,'platform-tools'));
        packages.unshift('platforms;android-34','platforms;android-35','platforms;android-36','build-tools;36.0.0','ndk;28.2.13676358');
    }
    run(sdkmanager,['--sdk_root='+sdk,...packages],{...environment,ANDROID_HOME:sdk});
    if(android) for(const key of ['ANDROID_NDK_HOME','ANDROID_NDK_ROOT']) envLine(environment,key,join(sdk,'ndk/28.2.13676358'));
    pathLine(environment,join(sdk,'cmake/3.31.6/bin'));
    const esbuild=json('topup/web/package.json').citizenapp.tools.esbuild;
    run('npm',['install','--prefix',join(work,'tools'),'--ignore-scripts','--no-audit','--no-fund','esbuild@'+esbuild],{...environment,ANDROID_HOME:sdk});
    envLine(environment,'ESBUILD_BIN',join(work,'tools/node_modules/.bin/esbuild'));
}

export function prepareIsar(environment) {
    const config=pathToFileURL(join(environment.WORK,'project/.dart_tool/package_config.json'));
    const entry=json(config).packages.find(item=>item.name==='isar_community_flutter_libs');
    check(entry,'原锁缺少Isar');
    const library=join(environment.WORK,'libisar.dylib');
    copyFileSync(join(fileURLToPath(new URL(entry.rootUri,config)),'macos/libisar.dylib'),library);
    envLine(environment,'ISAR_CORE_LIB_PATH',library);
}

function testInputs(environment) {
    prepareIsar(environment);
    const chain=join(environment.WORK,'chain');
    run('git',['clone','--filter=blob:none','--sparse','--depth=1','https://github.com/crcfrcn/citizenchain.git',chain],environment);
    run('git',['-C',chain,'sparse-checkout','set','runtime/primitives/tests/fixtures'],environment);
    writeFileSync(join(environment.WORK,'chain-source-sha'),execFileSync('git',['-C',chain,'rev-parse','HEAD'],{env:environment}));
    envLine(environment,'CITIZENCHAIN_ROOT',chain);
}

function manifest(platform,environment) {
    const work=environment.WORK, directory=join(work,'artifact'), title=prefix(platform)+environment.CITIZENAPP_VERSION;
    const identity={};
    if(platform==='android'){
        identity.package_name=execFileSync('apkanalyzer',['manifest','application-id',join(directory,title+'.apk')],
            {encoding:'utf8',env:environment}).trim();
        check(identity.package_name==='com.crcfrcn.citizenapp','APK应用标识不匹配');
    }
    const asset=name=>{
        const file=join(directory,name);
        return {name,size:statSync(file).size,sha256:execFileSync('shasum',['-a','256',file],{encoding:'utf8',env:environment}).split(' ')[0]};
    };
    const proof={
        schema:1,product_id:'citizenapp',platform,...identity,
        version:environment.CITIZENAPP_VERSION,version_code:Number(environment.GITHUB_RUN_NUMBER),
        source_sha:environment.GITHUB_SHA,run_id:Number(environment.GITHUB_RUN_ID),run_attempt:Number(environment.GITHUB_RUN_ATTEMPT),
        chain_test_sha:readFileSync(join(work,'chain-source-sha'),'utf8').trim(),
        sdk_sources:json(join(work,'sdk-sources.json')),assets:readdirSync(directory).sort().map(asset)
    };
    const name=title+'.json';
    writeJson(join(directory,name),proof);
    proof.assets.push(asset(name));
    writeJson(join(work,'proof.json'),proof);
}

function cleanupWork(environment) {
    const work=environment.WORK;
    if(!work) return;
    check(work===workPath(environment),'编译现场路径不符');
    check(!existsSync(join(work,'build-active.json')),'编译进程退出未确认，保留现场');
    const signing=join(work,'signing'), keychains=join(signing,'keychains');
    if(existsSync(keychains)){
        // security 输出带引号的路径，沿用签名步骤使用的 shlex。
        run('python3',['-c',`import pathlib, shlex, subprocess, sys
paths = shlex.split(pathlib.Path(sys.argv[1]).read_text())
subprocess.run(['security', 'list-keychains', '-d', 'user', '-s', *paths], check=True)`,keychains],environment);
    }
    const keychain=join(signing,'release.keychain-db'), profile=join(signing,'installed-profile');
    if(existsSync(keychain)) run('security',['delete-keychain',keychain],environment);
    if(existsSync(profile)) rmSync(readFileSync(profile,'utf8'),{force:true});
    rmSync(work,{recursive:true});
}

async function main([step,platform],environment) {
    check(Object.hasOwn(platforms,platform),'未知公民发布平台：'+(platform||''));
    environment={...environment,PLATFORM:platform};
    switch(step){
        case 'version': appendFileSync(environment.GITHUB_OUTPUT,'version='+await readVersion(platform,false,environment)+'\n'); break;
        case 'installed': console.log(JSON.stringify(await readVersion(platform,true,environment))); break;
        case 'prepare': prepare(platform,environment); break;
        case 'assemble': await (await import('../scripts/build.mjs')).assembleProject(environment); break;
        case 'test-inputs': testInputs(environment); break;
        case 'test': run(process.execPath,['lib/test/run.mjs'],{...environment,CITIZENAPP_TEST_ROOT:join(environment.WORK,'project')}); break;
        case 'compile': run(process.execPath,['scripts/build.mjs',platform],environment); break;
        case 'manifest': manifest(platform,environment); break;
        case 'release': release(platform,environment); break;
        case 'cleanup-work': cleanupWork(environment); break;
        case 'cleanup': cleanup(platform,environment); break;
        default: throw Error('未知公民发布步骤：'+(step||''));
    }
}

if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)){
    // 装配模块会导入本文件的 Release 辅助函数，入口先完成模块求值再等待命令结果。
    main(process.argv.slice(2),process.env).catch(error=>{
        console.error(error.message);
        process.exitCode=1;
    });
}
