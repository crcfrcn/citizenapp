import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {createHash,generateKeyPairSync,sign} from 'node:crypto';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=fileURLToPath(new URL('../../',import.meta.url));

function storeStep(platform,name) {
    const workflow=readFileSync(join(root,'.github/workflows',platform+'.yml'),'utf8');
    const step=workflow.split('      - name: '+name+'\n')[1];
    const block=/node --input-type=module <<'NODE'\n([\s\S]*?)\n {10}NODE/u.exec(step);
    assert.ok(block,'缺少商店交付步骤');
    const body=block[1].split('\n').map(line=>line.slice(10)).filter(line=>!line.startsWith('import ')).join('\n');
    const AsyncFunction=Object.getPrototypeOf(async function(){}).constructor;
    return new AsyncFunction('process','fetch','pause','sign','readFile','console','execFileSync','createHash',body);
}

test('TestFlight 只确认本轮构建在公民内部组可测试',async()=>{
    const step=storeStep('ios','上传正式IPA并回查TestFlight内部测试');
    const group='c4a947eb-db0b-45ee-ad1d-6d306d77b968';
    const {privateKey}=generateKeyPairSync('ec',{namedCurve:'prime256v1'});
    const env={APPSTORE_KEYID:'fixture',APPSTORE_ISSUERID:'fixture',
        APPSTORE_PRIVATEKEY:privateKey.export({type:'pkcs8',format:'pem'}),CITIZENAPP_VERSION:'7.8.9',GITHUB_RUN_NUMBER:'77',WORK:'/fixture'};
    for(const mode of ['already','assign','external','otherAuto','old','pending','denied']){
        const writes=[], uploads=[];
        const run=()=>step({env},async(value,options)=>{
            const url=new URL(value);
            assert.equal(url.origin,'https://api.appstoreconnect.apple.com');
            assert.match(options.headers.Authorization,/^Bearer [^.]+\.[^.]+\.[^.]+$/u);
            let result;
            if(url.pathname==='/v1/apps/6800953222')result={data:{attributes:{bundleId:'ios.citizenapp'}}};
            else if(url.pathname==='/v1/apps/6800953222/betaGroups')result={data:[
                {id:group,attributes:{isInternalGroup:mode!=='external',hasAccessToAllBuilds:mode==='already'}},
                {id:'other',attributes:{isInternalGroup:true,hasAccessToAllBuilds:mode==='otherAuto'}}
            ]};
            else if(url.pathname==='/v1/builds'){
                assert.equal(url.searchParams.get('filter[app]'),'6800953222');
                assert.equal(url.searchParams.get('filter[version]'),'77');
                result={data:[{id:'current',attributes:{version:mode==='old'?'76':'77',processingState:'VALID',expired:false},
                    relationships:{preReleaseVersion:{data:{id:'prerelease'}}}}],
                    included:[{id:'prerelease',type:'preReleaseVersions',attributes:{version:'7.8.9',platform:'IOS'}}]};
            } else if(url.pathname==='/v1/builds/current/buildBetaDetail'){
                result={data:{attributes:{internalBuildState:mode==='already'||writes.length?'IN_BETA_TESTING':'READY_FOR_BETA_TESTING'}}};
            } else {
                assert.equal(url.pathname,'/v1/betaGroups/'+group+'/relationships/builds');
                if(options.method==='POST'){
                    writes.push(JSON.parse(options.body));
                    return new Response(null,{status:mode==='denied'?403:204});
                }
                result={data:mode==='already'||(mode==='assign'&&writes.length)?[{id:'current',type:'builds'}]:[]};
            }
            return Response.json(result);
        },async()=>{},sign,null,{log(){}},(command,args)=>uploads.push([command,...args.slice(0,3)]));
        if(mode==='already'||mode==='assign')await run();
        else await assert.rejects(run(),{external:/内部组归属不符/,otherAuto:/其他内部组可能自动接收/,denied:/HTTP 403/}[mode]??/回查超时/);
        assert.deepEqual(uploads,['external','otherAuto'].includes(mode)?[]:
            [['xcrun','altool','--upload-package','/fixture/artifact/公民·iOS·v7.8.9.ipa']]);
        assert.deepEqual(writes,['assign','pending','denied'].includes(mode)?[{data:[{type:'builds',id:'current'}]}]:[],mode);
    }
});

test('Google Play 只回查本轮已推出的内部构建并核对摘要',async()=>{
    const step=storeStep('android','等待并回查本轮 Google Play 内部测试');
    const env={GOOGLE_PLAY_ACCESS_TOKEN:'fixture',CITIZENAPP_VERSION:'7.8.9',GITHUB_RUN_NUMBER:'77',WORK:'/fixture'};
    const prefix='/androidpublisher/v3/applications/com.crcfrcn.citizenapp';
    const bundle=Buffer.from('fixture bundle'), digest=createHash('sha256').update(bundle).digest('hex');
    for(const mode of ['published','halted','draft','inReview','old','denied','wrongTrack','digest']){
        const calls=[];
        const run=()=>step({env},async(value,options)=>{
            const url=new URL(value);
            assert.equal(url.origin,'https://androidpublisher.googleapis.com');
            assert.equal(url.search,'');
            const route=url.pathname.slice(prefix.length);
            assert.equal(url.pathname,prefix+route);
            calls.push(options.method+' '+route);
            if(route==='/edits'&&options.method==='POST'){
                assert.equal(options.body,'{}');
                if(mode==='denied')return new Response(null,{status:403});
                return Response.json({id:'1'});
            }
            if(route==='/edits/1/tracks/internal'&&options.method==='GET')return Response.json({
                track:mode==='wrongTrack'?'production':'internal',
                releases:mode==='inReview'?[]:[{name:'公民·Android·v7.8.9',versionCodes:[mode==='old'?'76':'77'],
                    status:['halted','draft'].includes(mode)?mode:'completed'}]});
            if(route==='/edits/1/bundles'&&options.method==='GET')return Response.json({bundles:[
                {versionCode:77,sha256:mode==='digest'?'0'.repeat(64):digest}]});
            if(route==='/edits/1'&&options.method==='DELETE')return new Response(null,{status:204});
            assert.fail('出现未声明的 Google Play 请求');
        },async()=>{},null,async file=>{
            assert.equal(file,'/fixture/artifact/公民·Android·v7.8.9.aab');
            return bundle;
        },{log(){}},null,createHash);
        if(mode==='published')await run();
        else await assert.rejects(run(),{denied:/HTTP 403/,wrongTrack:/不是内部轨道/,digest:/摘要不符/}[mode]??/回查超时/);
        if(['published','digest'].includes(mode))assert.deepEqual(calls,[
            'POST /edits','GET /edits/1/tracks/internal','GET /edits/1/bundles','DELETE /edits/1']);
        else if(mode==='denied')assert.deepEqual(calls,['POST /edits']);
        else assert.deepEqual(calls,Array.from({length:mode==='wrongTrack'?1:120},
            ()=>['POST /edits','GET /edits/1/tracks/internal','DELETE /edits/1']).flat());
    }
});

test('Android自动化仍记录正式产物版本，手机更新不消费安装包下载证明',t=>{
    const base=join(root,'target/test');mkdirSync(base,{recursive:true});
    const work=mkdtempSync(join(base,'delivery-'));t.after(()=>rmSync(work,{recursive:true,force:true}));
    const golden={schema:1,product_id:'citizenapp',platform:'android',package_name:'com.crcfrcn.citizenapp',
        version:'7.8.9',version_code:77,source_sha:'a'.repeat(40),run_id:7,run_attempt:1,chain_test_sha:'b'.repeat(40)};
    const title='公民·Android·v'+golden.version;
    mkdirSync(join(work,'artifact'));
    for(const suffix of ['apk','aab'])writeFileSync(join(work,'artifact',title+'.'+suffix),'citizenapp-update-fixture');
    writeFileSync(join(work,'chain-source-sha'),golden.chain_test_sha);
    const sdkSources={citizen_sdk:{source:'release',software_version:'2.0.7',git_commit_sha:'c'.repeat(40)}};
    writeFileSync(join(work,'sdk-sources.json'),JSON.stringify(sdkSources));
    const workflow=readFileSync(join(root,'.github/workflows/android.yml'),'utf8');
    assert.ok(workflow.includes('run: node .github/release.mjs manifest android'));
    const bin=join(work,'bin'), calls=join(work,'apkanalyzer.json');
    mkdirSync(bin);
    writeFileSync(join(bin,'apkanalyzer'),'#!'+process.execPath+'\n'
        +'require("node:fs").writeFileSync(process.env.APK_CALLS,JSON.stringify(process.argv.slice(2)));'
        +'console.log("com.crcfrcn.citizenapp");\n',{mode:0o700});
    const env={...process.env,PATH:bin+':'+process.env.PATH,APK_CALLS:calls,WORK:work,
        CITIZENAPP_VERSION:golden.version,GITHUB_RUN_NUMBER:String(golden.version_code),
        GITHUB_SHA:golden.source_sha,GITHUB_RUN_ID:String(golden.run_id),GITHUB_RUN_ATTEMPT:String(golden.run_attempt)};
    const result=spawnSync(process.execPath,[join(root,'.github/release.mjs'),'manifest','android'],{env,encoding:'utf8'});
    assert.equal(result.status,0,result.stderr);
    assert.deepEqual(JSON.parse(readFileSync(calls,'utf8')),['manifest','application-id',join(work,'artifact',title+'.apk')]);
    const proofPath=join(work,'artifact',title+'.json');
    const published=JSON.parse(readFileSync(proofPath,'utf8'));
    for(const [key,value]of Object.entries(golden))assert.deepEqual(published[key],value);
    assert.deepEqual(published.sdk_sources,sdkSources);
    assert.equal(published.assets.length,2);
    const receipt=JSON.parse(readFileSync(join(work,'proof.json'),'utf8'));
    assert.deepEqual(receipt.assets.slice(0,2),published.assets);
    assert.equal(receipt.assets[2].name,title+'.json');
    const service=readFileSync(join(root,'system/lib/update/app_update_service.dart'),'utf8');
    assert.ok(!service.includes('api.github.com')&&!service.includes('downloadUpdate'));
    assert.ok(service.includes('checkStoreUpdate')&&service.includes('itunes.apple.com'));
});
