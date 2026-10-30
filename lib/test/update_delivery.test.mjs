import {test} from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync,spawnSync} from 'node:child_process';
import {readFileSync,writeFileSync,readdirSync,statSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';

const root=fileURLToPath(new URL('../../',import.meta.url));
test('Android真实发布证明由真实Dart消费者读取，附件label不依赖规范化文件名',t=>{
    const base=join(root,'target/test');mkdirSync(base,{recursive:true});
    const work=mkdtempSync(join(base,'delivery-'));t.after(()=>rmSync(work,{recursive:true,force:true}));
    const golden=JSON.parse(readFileSync(join(root,'system/test/update_fixture.json'),'utf8'));
    const title='公民·Android·v'+golden.version;
    mkdirSync(join(work,'artifact'));
    for(const suffix of ['apk','aab'])writeFileSync(join(work,'artifact',title+'.'+suffix),'citizenapp-update-fixture');
    writeFileSync(join(work,'chain-source-sha'),golden.chain_test_sha);
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
    assert.deepEqual(JSON.parse(readFileSync(proofPath,'utf8')),golden);
    const receipt=JSON.parse(readFileSync(join(work,'proof.json'),'utf8'));
    assert.deepEqual(receipt.assets.slice(0,2),golden.assets);
    assert.equal(receipt.assets[2].name,title+'.json');
    const source=resolve(process.env.CITIZENAPP_TEST_ROOT||root,'system/lib/update/app_update_manifest.dart');
    const consumer=join(work,'consumer.dart');
    // 直接导入生产解析器，只写跨语言边界断言，不复制解析算法。
    writeFileSync(consumer,`import 'dart:convert';\nimport 'dart:io';\nimport ${JSON.stringify(pathToFileURL(source).href)};\nvoid main(List<String> args) {\n final value=AppUpdateManifest.fromJson(jsonDecode(File(args[0]).readAsStringSync()) as Map<String,dynamic>);\n if(value.version!='1.2.3'||value.versionCode!=9||value.apkSize!=25||value.apkAsset!='公民·Android·v1.2.3.apk'||!value.matchesAndroidPackage('com.crcfrcn.citizenapp')) throw StateError('真实消费者合同不符');\n}\n`);
    assert.ok(process.env.FLUTTER_ROOT,'需要产品现有Flutter工具');
    const result=spawnSync(join(process.env.FLUTTER_ROOT,'bin/cache/dart-sdk/bin/dart'),[consumer,proofPath],{cwd:work,encoding:'utf8'});
    assert.equal(result.status,0,result.stderr);
    assert.throws(()=>execute(()=> 'other.app',readFileSync,writeFileSync,readdirSync,statSync,{env}),/应用标识不匹配/);
    assert.match(workflow,/"\$file#\$\(basename "\$file"\)"/u,'正式上传必须保留原始label');
});
