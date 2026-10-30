import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {mapSdkSource} from '../../scripts/build.mjs';

test('SDK路径同时映射根与所有真实消费者，不修改其它依赖',t=>{
 const root=mkdtempSync(join(tmpdir(),'citizen-workspace-'));t.after(()=>rmSync(root,{recursive:true,force:true}));
 const sdk='  citizen_sdk:\n    git:\n      url: https://github.com/crcfrcn/citizensdk.git\n      ref: main\n';
 writeFileSync(join(root,'pubspec.yaml'),'workspace:\n  - account\n  - assets\ndependencies:\n'+sdk+'  http: 1.6.0\n');
 for(const member of ['account','assets'])mkdirSync(join(root,member));
 writeFileSync(join(root,'account/pubspec.yaml'),'dependencies:\n'+sdk+'  http: 1.6.0\n');
 writeFileSync(join(root,'assets/pubspec.yaml'),'dependencies:\n  flutter:\n    sdk: flutter\n');
 assert.equal(mapSdkSource(root,'citizen_sdk','/fixture/current-sdk'),2);
 for(const member of ['', 'account']){const text=readFileSync(join(root,member,'pubspec.yaml'),'utf8');assert.match(text,/path: \/fixture\/current-sdk/);assert.doesNotMatch(text,/git:/);assert.match(text,/http: 1.6.0/);}
 assert.doesNotMatch(readFileSync(join(root,'assets/pubspec.yaml'),'utf8'),/citizen_sdk/);
 assert.throws(()=>mapSdkSource(root,'missing_sdk','/fixture/no'),/没有声明SDK/);
});
