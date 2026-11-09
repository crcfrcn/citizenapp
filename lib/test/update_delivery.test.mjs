import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync,existsSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=fileURLToPath(new URL('../../',import.meta.url));

function storeStep(platform,name) {
    const workflow=readFileSync(join(root,'.github/workflows',platform+'.yml'),'utf8');
    const step=workflow.split('      - name: '+name+'\n')[1];
    assert.ok(step,'缺少商店上传步骤');
    const block=step.split('\n      - ')[0].split('        run: |\n')[1];
    return block.split('\n').map(line=>line.slice(10)).join('\n');
}

test('iOS 上传已验收 IPA，以 altool 退出状态为准',t=>{
    const script=storeStep('ios','上传正式IPA到App Store Connect');
    const base=join(root,'target/test');mkdirSync(base,{recursive:true});
    const work=mkdtempSync(join(base,'apple-upload-'));t.after(()=>rmSync(work,{recursive:true,force:true}));
    mkdirSync(join(work,'signing'));mkdirSync(join(work,'artifact'));
    const ipa=join(work,'artifact/公民·iOS·v7.8.9.ipa'),calls=join(work,'calls.json');
    writeFileSync(ipa,'fixture IPA');
    writeFileSync(join(work,'xcrun'),'#!'+process.execPath+'\n'+
        'require("node:fs").writeFileSync(process.env.APPLE_CALLS,JSON.stringify(process.argv.slice(2)));process.exit(Number(process.env.FIXTURE_STATUS));\n',{mode:0o700});
    for(const status of [0,7]){
        const env={...process.env,PATH:work+':'+process.env.PATH,WORK:work,CITIZENAPP_VERSION:'7.8.9',
            APPSTORE_KEYID:'fixture',APPSTORE_ISSUERID:'fixture',APPSTORE_PRIVATEKEY:'fixture',
            APPLE_CALLS:calls,FIXTURE_STATUS:String(status)};
        const result=spawnSync('/bin/bash',['-c',script],{env,encoding:'utf8'});
        assert.equal(result.status,status,result.stderr);
        assert.deepEqual(JSON.parse(readFileSync(calls,'utf8')),['altool','--upload-package',ipa,
            '--api-key','fixture','--api-issuer','fixture','--output-format','json']);
        assert.equal(existsSync(join(work,'signing/appstore')),false);
    }
});

test('Google Play 上传本轮 AAB，只使用本次上传回执',async()=>{
    const script=storeStep('android','上传正式AAB到Google Play');
    const source=script.split('\n').slice(1,-1).filter(line=>!line.startsWith('import ')).join('\n');
    const AsyncFunction=Object.getPrototypeOf(async function(){}).constructor;
    const step=new AsyncFunction('process','fetch','readFile','console','createHash',source);
    const env={GOOGLE_PLAY_ACCESS_TOKEN:'fixture',CITIZENAPP_VERSION:'7.8.9',GITHUB_RUN_NUMBER:'77',WORK:'/fixture'};
    const prefix='/androidpublisher/v3/applications/com.crcfrcn.citizenapp/edits';
    const bundle=Buffer.from('fixture bundle'),digest=createHash('sha256').update(bundle).digest('hex');
    for(const mode of ['success','edit','upload','digest','version']){
        const calls=[];
        const run=()=>step({env},async(value,options)=>{
            const url=new URL(value);
            assert.equal(url.origin,'https://androidpublisher.googleapis.com');
            assert.equal(options.method,'POST');
            calls.push(url.pathname);
            if(url.pathname===prefix){
                assert.equal(options.body,'{}');
                return mode==='edit'?new Response(null,{status:403}):Response.json({id:'1'});
            }
            assert.equal(url.pathname,'/upload'+prefix+'/1/bundles');
            assert.equal(url.search,'?uploadType=media');
            assert.deepEqual(options.body,bundle);
            return mode==='upload'?new Response(null,{status:503}):Response.json({
                versionCode:mode==='version'?76:77,sha256:mode==='digest'?'0'.repeat(64):digest});
        },async file=>{
            assert.equal(file,'/fixture/artifact/公民·Android·v7.8.9.aab');
            return bundle;
        },{log(){}},createHash);
        if(mode==='success')await run();
        else await assert.rejects(run(),{edit:/HTTP 403/,upload:/HTTP 503/,digest:/回执.*不符/,version:/回执.*不符/}[mode]);
        assert.deepEqual(calls,mode==='edit'?[prefix]:[prefix,'/upload'+prefix+'/1/bundles']);
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
