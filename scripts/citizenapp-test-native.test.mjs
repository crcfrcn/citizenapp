import {test} from 'node:test';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,rmSync,symlinkSync,realpathSync} from 'node:fs';
import { testRoot as tmpdir } from './build.mjs';
import {join} from 'node:path';
import {citizenCorePath,isarCorePath} from './citizenapp-test-native.mjs';

function fixture() {
  const root=realpathSync(mkdtempSync(join(tmpdir(),'citizenapp-native-contract-')));
  const cache=join(root,'pub-cache'),pkg=join(cache,'hosted/pub.dev/isar_community_flutter_libs-3.3.2');
  const output=join(root,'sdk-output'),config=join(root,'package_config.json'),lock=join(root,'pubspec.lock');
  mkdirSync(join(pkg,'linux'),{recursive:true});mkdirSync(join(pkg,'macos'));
  mkdirSync(join(output,'abi-host'),{recursive:true});
  writeFileSync(join(pkg,'pubspec.yaml'),'name: isar_community_flutter_libs\nversion: 3.3.2\n');
  writeFileSync(join(pkg,'linux/libisar.so'),'fixture');
  writeFileSync(join(pkg,'macos/libisar.dylib'),'fixture');
  writeFileSync(join(output,'abi-host/libcitizensdk.so'),'fixture');
  writeFileSync(join(output,'abi-host/libcitizensdk.dylib'),'fixture');
  writeFileSync(lock,'packages:\n  isar_community_flutter_libs:\n    dependency: "direct main"\n    source: hosted\n    version: "3.3.2"\n');
  const packageEntry={name:'isar_community_flutter_libs',rootUri:'pub-cache/hosted/pub.dev/isar_community_flutter_libs-3.3.2/'};
  const configure=packages=>writeFileSync(config,JSON.stringify({configVersion:2,packages}));
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
    writeFileSync(join(f.pkg,'pubspec.yaml'),'name: isar_community_flutter_libs\nversion: 3.3.3\n');
    assert.throws(()=>isarCorePath(f.config,f.cache,f.lock,'linux','x64'),/身份/);
    writeFileSync(f.lock,'packages:\n');
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
    const script=fileURLToPath(new URL('./citizenapp-test-native.mjs',import.meta.url));
    const core=spawnSync(process.execPath,[script,'core',f.output],{encoding:'utf8'});
    assert.equal(core.status,0,core.stderr);
    assert.equal(core.stdout,citizenCorePath(f.output));
    const isar=spawnSync(process.execPath,[script,'isar',f.config,f.cache,f.lock],{encoding:'utf8'});
    assert.equal(isar.status,0,isar.stderr);
    assert.equal(isar.stdout,isarCorePath(f.config,f.cache,f.lock));
    const invalid=spawnSync(process.execPath,[script,'core',f.output,'extra'],{encoding:'utf8'});
    assert.notEqual(invalid.status,0);assert.match(invalid.stderr,/参数无效/);assert.equal(invalid.stdout,'');
  }finally{f.dispose();}
});
