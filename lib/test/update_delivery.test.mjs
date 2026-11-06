import {test} from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,readdirSync,statSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=fileURLToPath(new URL('../../',import.meta.url));
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
    const step=workflow.split('      - name: 生成本轮正式附件说明\n')[1];
    const match=/<<'JS'\n([\s\S]*?)\n\s+JS/u.exec(step);assert.ok(match);
    const body=match[1].split('\n').map(line=>line.slice(10)).filter(line=>!line.startsWith('import ')).join('\n');
    const execute=new Function('execFileSync','readFileSync','writeFileSync','readdirSync','statSync','process',body);
    const env={WORK:work,PLATFORM:'android',CITIZENAPP_VERSION:golden.version,GITHUB_RUN_NUMBER:String(golden.version_code),
        GITHUB_SHA:golden.source_sha,GITHUB_RUN_ID:String(golden.run_id),GITHUB_RUN_ATTEMPT:String(golden.run_attempt)};
    const calls=[];
    execute((command,args,options)=>{
        if(command==='apkanalyzer'){
            calls.push(args);assert.deepEqual(args,['manifest','application-id',join(work,'artifact',title+'.apk')]);
            return golden.package_name+'\n';
        }
        assert.equal(command,'shasum');return execFileSync(command,args,options);
    },readFileSync,writeFileSync,readdirSync,statSync,{env});
    assert.equal(calls.length,1);
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
