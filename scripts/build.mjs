#!/usr/bin/env node
const directEntry = process.argv[1] === import.meta.filename && !process.execArgv.some(argument=>/^(?:-e|-p|--eval|--print)(?:=|$)/u.test(argument));
const inlineTestEntry = directEntry && Boolean(process.env.NODE_TEST_CONTEXT) && process.argv.length === 2;
// 本产品独立拥有资源需求、工程准备与编译；公开回执仅提供验真资源，不提供执行命令。
import {spawn} from 'node:child_process';
import {checkFixedWork,clearFixedWork,fixedWork,withFixedWork,taskScope,trackWorkProcess,workEnvironment} from './target.mjs';
import {AsyncLocalStorage} from 'node:async_hooks';
import {Socket} from 'node:net';
import {rmSync,constants,fstatSync,readSync,chmodSync,closeSync,openSync,renameSync,readlinkSync,unlinkSync,copyFileSync,existsSync,lstatSync,mkdirSync,readFileSync,readdirSync,realpathSync,symlinkSync,writeFileSync} from 'node:fs';
import {dirname,isAbsolute,join,parse,relative,resolve,sep} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash,randomBytes} from 'node:crypto';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
export const contract=JSON.parse(readFileSync(join(root,'scripts/flows.json'),'utf8'));
const product=contract.product_id, prefix=product.toUpperCase();
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
 platformContract(platform);const expected=fixedWork(scope==='test'?'test':'build');
 if(suppliedInput!=null&&suppliedInput!==expected)fail('临时工作根必须是本产品固定目录');
 return checkFixedWork(expected,{create:true});
}
// 测试继承当前平台现场；独立执行没有任务身份时才选产品首个平台。
export const testRoot=platform=>{
 const workflow=String(process.env.GITHUB_WORKFLOW||'').split('.');
 const local=process.env.TMPDIR?relative(join(root,'target'),resolve(process.env.TMPDIR)).split(sep)[0]:undefined;
 const inherited=workflow[0]===product&&Object.hasOwn(contract.platforms,workflow[1])?workflow[1]
  :Object.hasOwn(contract.platforms,local)?local:undefined;
 return temporaryRoot(platform||inherited||Object.keys(contract.platforms)[0],'test');
};
// 远端Runner基础设施仍归GitHub；本产品步骤的可写临时目录归准确平台流程target。
export function remoteEnvironment(environment=process.env) {
 const [id,platform,flow,...extra]=String(environment.GITHUB_WORKFLOW||'').split('.');
 if(id!==product||extra.length||!Object.hasOwn(contract.platforms,platform)||!['ci','release'].includes(flow))fail('远端临时目录缺少准确产品平台流程身份');
 prepareTargetRoot();
 const temporary=temporaryRoot(platform,flow,null);
 return {...environment,RUNNER_TEMP:temporary,TMPDIR:temporary,TMP:temporary,TEMP:temporary};
}

// 展开来源根由本产品指定，调用者不识别任何产品来源名称。
export function resourceSourceRoot(name,work){checkWork(work);if(!/^[a-z][a-z0-9_]*$/u.test(name))fail('来源名称无效');return join(work,'git-sources',name);}
// 清理只针对当前执行拥有的工作根；工具全部退出后删除并回读，固定根本身保留。
export function clearWork(work) { return clearFixedWork(work); }

export function platformContract(platform) {
 if(!Object.hasOwn(contract.platforms,platform))fail('平台未声明');
 return contract.platforms[platform];
}
const nativePlatform=platform=>platform.endsWith('android')?'Android':platform.includes('linux-arm')?'LinuxARM':platform.includes('linux-amd')?'LinuxAMD':platform.endsWith('windows')?'Windows':'macOS';
const osPlatform=platform=>platform.includes('linux-')?'linux':platform.replace(/^(?:host|client)-/u,'');

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
 const locks=declared.locks.map(value=>({...value})),sources=lockedSources(),archives=[];
 for(const source of sources) {
  const packageRoot=join(work,'git-sources',source.name);
  if(existsSync(packageRoot)) {
   const path=source.name==='citizen_sdk'?'Cargo.lock':'native/Cargo.lock';
   locks.push({ecosystem:'cargo',path,source_package:source.name});
   if(source.name==='citizen_sdk') {
    const lock=JSON.parse(readFileSync(join(packageRoot,'scripts/dependencies.lock.json'),'utf8'));
    const p=nativePlatform(platform);
    const entries=[['zxing-cpp',lock.environment['zxing-cpp']],...((p==='LinuxARM'||p==='LinuxAMD')?Object.entries(lock.native.sources):p==='Windows'?[['sqlite',lock.native.sources.sqlite]]:[])];
    for(const [name,value]of entries)archives.push({ecosystem:'native',name,...value,group:'sdk-native'});
   }
  }
 }
 // Apple依赖方式由本产品源码决定；有Podfile就必须有原始锁，纯SwiftPM无需CocoaPods。
 const apple=platform.endsWith('ios')?'ios':platform.endsWith('macos')?'macos':null;
 if(apple){const base=root,pod=join(base,apple,'Podfile'),lock=join(base,apple,'Podfile.lock');
  if(existsSync(pod)){if(!existsSync(lock))fail('CocoaPods原始锁缺失：'+relative(root,lock));locks.push({ecosystem:'cocoapods',path:relative(root,lock)});}
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
  ...receipt.environment,TMPDIR:join(work,'tmp')+sep,TMP:join(work,'tmp'),TEMP:join(work,'tmp'),XDG_CACHE_HOME:join(work,'cache'),XDG_CONFIG_HOME:join(work,'config'),
  CARGO_TARGET_DIR:join(work,'work/cargo-target'),CARGO_NET_OFFLINE:'true',CARGO_INCREMENTAL:'1',
  npm_config_offline:'true',npm_config_audit:'false',npm_config_fund:'false'};
 const allowedEnvironment=new Set(['PRODUCT_WORK_DIR','PRODUCT_BASH_BIN','PRODUCT_RSYNC_BIN','PATH','DEVELOPER_DIR','SDKROOT','DART_EXECUTABLE','XCODEBUILD','CODESIGN','SECURITY','XCRUN','XCODE_SELECT','CC','CXX','SWIFT','OTOOL','INSTALL_NAME_TOOL','LIPO','MAKE','AR','RANLIB','NM','STRIP','LLVM_NM','LD','LDCXX','CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER','ANDROID_HOME','ANDROID_SDK_ROOT','ANDROID_NDK_HOME','ANDROID_USER_HOME','ANDROID_EMULATOR_HOME','GRADLE_INIT_SCRIPT','GRADLE_USER_HOME']);
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

 return completeBuild(platform,work,receipt,env);
}

// 产品自有Security.framework验真器源码，只在本轮工作目录编译。
export const IOS_VERIFIER_SOURCE=[
 "import Foundation",
 "import Security",
 "import CryptoKit",
 "import Darwin",
 "struct SecurityFailure: Error { let message: String }",
 "enum ProductFileIdentity {",
 " static func identity(_ url: URL, directory: Bool) throws -> [UInt64] {",
 "  guard url.path == url.standardizedFileURL.path, url.path == url.resolvingSymlinksInPath().path else { throw SecurityFailure(message: \"产品路径经过链接\") }",
 "  var info = stat()",
 "  guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == (directory ? S_IFDIR : S_IFREG), directory || info.st_nlink == 1 else { throw SecurityFailure(message: \"产品路径类型或链接无效\") }",
 "  return [UInt64(info.st_dev),UInt64(info.st_ino)]",
 " }",
 "}",
 "enum ProductIOSContract {",
 "    static func iosReleaseSettings(_ project: [String: Any]) throws -> [String: Any] {",
 "        guard let objects = project[\"objects\"] as? [String: [String: Any]],",
 "              let rootID = project[\"rootObject\"] as? String, let root = objects[rootID],",
 "              let targets = root[\"targets\"] as? [String] else { throw SecurityFailure(message: \"iOS 工程结构无效\") }",
 "        func settings(_ object: [String: Any]) throws -> [String: Any] {",
 "            guard let listID = object[\"buildConfigurationList\"] as? String,",
 "                  let ids = objects[listID]?[\"buildConfigurations\"] as? [String] else {",
 "                throw SecurityFailure(message: \"iOS 工程缺少 Release 配置\")",
 "            }",
 "            let release = ids.compactMap { objects[$0] }.filter { $0[\"name\"] as? String == \"Release\" }",
 "            guard release.count == 1, let values = release[0][\"buildSettings\"] as? [String: Any] else {",
 "                throw SecurityFailure(message: \"iOS 工程 Release 配置不唯一\")",
 "            }",
 "            return values",
 "        }",
 "        let applications = targets.compactMap { objects[$0] }.filter {",
 "            $0[\"name\"] as? String == \"Runner\" && $0[\"productType\"] as? String == \"com.apple.product-type.application\"",
 "        }",
 "        guard applications.count == 1 else { throw SecurityFailure(message: \"iOS Runner 产品目标缺失或不唯一\") }",
 "        return try settings(root).merging(settings(applications[0])) { _, target in target }",
 "    }",
 "",
 "    static func iosVersion(_ value: String) throws -> [UInt64] {",
 "        guard value.range(of: \"^[0-9]+(?:\\\\.[0-9]+){0,2}$\", options: .regularExpression) != nil else {",
 "            throw SecurityFailure(message: \"iOS 应用版本格式无效\")",
 "        }",
 "        let parts = value.split(separator: \".\").compactMap { UInt64($0) }",
 "        guard parts.count == value.split(separator: \".\").count else { throw SecurityFailure(message: \"iOS 应用版本超出范围\") }",
 "        return parts + Array(repeating: 0, count: 3 - parts.count)",
 "    }",
 "",
 "    static func iosEntitlements(profile: [String: Any], team: String, bundleID: String,",
 "                                device: String, requested: [String: Any], now: Date) throws -> [String: Any] {",
 "        guard profile[\"TeamIdentifier\"] as? [String] == [team],",
 "              let prefixes = profile[\"ApplicationIdentifierPrefix\"] as? [String], prefixes.count == 1,",
 "              prefixes[0].range(of: \"^[A-Z0-9]{10}$\", options: .regularExpression) != nil,",
 "              let expiry = profile[\"ExpirationDate\"] as? Date, expiry > now,",
 "              let creation = profile[\"CreationDate\"] as? Date, creation <= now,",
 "              (profile[\"Platform\"] as? [String])?.contains(\"iOS\") == true,",
 "              (profile[\"ProvisionedDevices\"] as? [String])?.contains(device) == true,",
 "              let allowed = profile[\"Entitlements\"] as? [String: Any] else {",
 "            throw SecurityFailure(message: \"iOS profile 的团队、期限、平台或设备不匹配\")",
 "        }",
 "        let prefix = prefixes[0] + \".\"",
 "        let applicationID = prefix + bundleID",
 "        func resolve(_ value: Any) throws -> Any {",
 "            if let string = value as? String {",
 "                if string == \"$(APS_ENVIRONMENT)\",",
 "                   let aps = allowed[\"aps-environment\"] as? String,",
 "                   [\"development\", \"production\"].contains(aps) { return aps }",
 "                let resolved = string.replacingOccurrences(of: \"$(AppIdentifierPrefix)\", with: prefix)",
 "                    .replacingOccurrences(of: \"$(TeamIdentifierPrefix)\", with: team + \".\")",
 "                    .replacingOccurrences(of: \"$(PRODUCT_BUNDLE_IDENTIFIER)\", with: bundleID)",
 "                guard !resolved.contains(\"$(\"), !resolved.contains(\"${\") else {",
 "                    throw SecurityFailure(message: \"iOS entitlement 存在未解析的工程变量\")",
 "                }",
 "                return resolved",
 "            }",
 "            if let array = value as? [Any] { return try array.map(resolve) }",
 "            if let object = value as? [String: Any] { return try object.mapValues(resolve) }",
 "            return value",
 "        }",
 "        var entitlements = try requested.mapValues(resolve)",
 "        for (key, value) in [\"application-identifier\": applicationID, \"com.apple.developer.team-identifier\": team] {",
 "            if let existing = entitlements[key] {",
 "                guard let existing = existing as? String, existing == value else {",
 "                    throw SecurityFailure(message: \"iOS entitlement 产品身份不一致或类型无效\")",
 "                }",
 "            }",
 "            entitlements[key] = value",
 "        }",
 "        guard entitlements[\"get-task-allow\"] as? Bool != true else {",
 "            throw SecurityFailure(message: \"iOS Release 候选禁止调试权限\")",
 "        }",
 "        // Local device installation uses the profile's own signing class. An",
 "        // Apple Development profile requires this grant; distribution profiles",
 "        // keep it false. Product entitlements still cannot request it directly.",
 "        entitlements[\"get-task-allow\"] = allowed[\"get-task-allow\"] as? Bool == true",
 "        func permits(_ permitted: Any, _ actual: Any) -> Bool {",
 "            if let pattern = permitted as? String, let value = actual as? String {",
 "                if pattern.hasSuffix(\"*\"), !pattern.dropLast().contains(\"*\") { return value.hasPrefix(String(pattern.dropLast())) }",
 "                return pattern == value",
 "            }",
 "            if let permittedArray = permitted as? [Any], let actualArray = actual as? [Any] {",
 "                return actualArray.allSatisfy { entry in permittedArray.contains { permits($0, entry) } }",
 "            }",
 "            if let permittedObject = permitted as? [String: Any], let actualObject = actual as? [String: Any] {",
 "                return actualObject.allSatisfy { key, value in permittedObject[key].map { permits($0, value) } ?? false }",
 "            }",
 "            if let a = actual as? NSNumber, let p = permitted as? NSNumber,",
 "               CFGetTypeID(a) == CFBooleanGetTypeID(), CFGetTypeID(p) == CFBooleanGetTypeID() {",
 "                return !a.boolValue || p.boolValue",
 "            }",
 "            return (permitted as? NSObject)?.isEqual(actual) == true",
 "        }",
 "        // Profile 是授权上限，不将未请求的能力整份授予应用。",
 "        for (key, value) in entitlements {",
 "            guard let permitted = allowed[key], permits(permitted, value) else {",
 "                throw SecurityFailure(message: \"iOS profile 未授权工程请求的 entitlement\")",
 "            }",
 "        }",
 "        return entitlements",
 "    }",
 "",
 "    static func iosSignedEntitlementsMatch(_ actual: [String: Any], expected: [String: Any]) -> Bool {",
 "        var normalized = actual",
 "        // Security.framework synthesizes these aliases even when codesign receives",
 "        // only the canonical entitlement. Accept exact duplicates only; all other",
 "        // extra capabilities or value drift remain fatal.",
 "        for (aliasKey, canonicalKey) in [",
 "            (\"com.apple.application-identifier\", \"application-identifier\"),",
 "            (\"com.apple.developer.aps-environment\", \"aps-environment\"),",
 "        ] {",
 "            if let alias = normalized.removeValue(forKey: aliasKey) {",
 "                guard let canonical = normalized[canonicalKey],",
 "                      NSDictionary(object: alias, forKey: \"value\" as NSString)",
 "                        .isEqual(to: [\"value\": canonical]) else { return false }",
 "            }",
 "        }",
 "        return NSDictionary(dictionary: normalized).isEqual(to: expected)",
 "    }",
 "}",
 "",
 "struct ProductVerifier {",
 " private let fileManager = FileManager.default",
 "    private func appleRoots() throws -> [SecCertificate] {",
 "        // 仅从只读系统根钥匙串取 Apple 根，不接受用户添加的同名根证书。",
 "        var keychain: SecKeychain?",
 "        guard SecKeychainOpen(\"/System/Library/Keychains/SystemRootCertificates.keychain\", &keychain) == errSecSuccess, let keychain else {",
 "            throw SecurityFailure(message: \"无法读取 Apple 系统信任根\")",
 "        }",
 "        var result: CFTypeRef?",
 "        let query: [String: Any] = [kSecClass as String: kSecClassCertificate,",
 "            kSecMatchSearchList as String: [keychain], kSecMatchLimit as String: kSecMatchLimitAll,",
 "            kSecReturnRef as String: true]",
 "        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let certificates = result as? [SecCertificate] else {",
 "            throw SecurityFailure(message: \"Apple 系统信任根不可用\")",
 "        }",
 "        let roots = certificates.filter {",
 "            [\"Apple Root CA\", \"Apple Root CA - G2\", \"Apple Root CA - G3\"].contains(SecCertificateCopySubjectSummary($0) as String? ?? \"\")",
 "        }",
 "        guard !roots.isEmpty else { throw SecurityFailure(message: \"缺少 Apple 系统信任根\") }",
 "        return roots",
 "    }",
 "",
 "    private func decodeIOSProfile(_ data: Data, roots: [SecCertificate]) throws -> [String: Any] {",
 "        guard !data.isEmpty, data.count <= 16 * 1024 * 1024 else { throw SecurityFailure(message: \"iOS profile 大小无效\") }",
 "        var decoder: CMSDecoder?",
 "        guard CMSDecoderCreate(&decoder) == errSecSuccess, let decoder else { throw SecurityFailure(message: \"无法创建 CMS 验证器\") }",
 "        let updated = data.withUnsafeBytes { CMSDecoderUpdateMessage(decoder, $0.baseAddress!, $0.count) }",
 "        var count = 0",
 "        guard updated == errSecSuccess, CMSDecoderFinalizeMessage(decoder) == errSecSuccess,",
 "              CMSDecoderGetNumSigners(decoder, &count) == errSecSuccess, count == 1 else {",
 "            throw SecurityFailure(message: \"iOS profile CMS 签名结构无效\")",
 "        }",
 "        var status = CMSSignerStatus(rawValue: 0)!",
 "        var trust: SecTrust?",
 "        var result: OSStatus = errSecSuccess",
 "        guard CMSDecoderCopySignerStatus(decoder, 0, SecPolicyCreateBasicX509(), false, &status, &trust, &result) == errSecSuccess,",
 "              status == .valid, let trust,",
 "              SecTrustSetAnchorCertificates(trust, roots as CFArray) == errSecSuccess,",
 "              SecTrustSetAnchorCertificatesOnly(trust, true) == errSecSuccess,",
 "              SecTrustSetNetworkFetchAllowed(trust, false) == errSecSuccess,",
 "              SecTrustEvaluateWithError(trust, nil),",
 "              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], chain.count == 3,",
 "              SecCertificateCopySubjectSummary(chain[0]) as String? == \"Apple iPhone OS Provisioning Profile Signing\",",
 "              SecCertificateCopySubjectSummary(chain[1]) as String? == \"Apple iPhone Certification Authority\" else {",
 "            throw SecurityFailure(message: \"iOS profile 不是有效的 Apple 签名授权\")",
 "        }",
 "        var content: CFData?",
 "        guard CMSDecoderCopyContent(decoder, &content) == errSecSuccess, let content,",
 "              let profile = try PropertyListSerialization.propertyList(from: content as Data, format: nil) as? [String: Any] else {",
 "            throw SecurityFailure(message: \"iOS profile 内容无效\")",
 "        }",
 "        return profile",
 "    }",
 "",
 "    private func iosTree(_ app: URL) throws -> [URL] {",
 "        _ = try ProductFileIdentity.identity(app, directory: true)",
 "        var enumerationFailed = false",
 "        guard let enumerator = fileManager.enumerator(at: app, includingPropertiesForKeys: [.isDirectoryKey], errorHandler: { _, _ in",
 "            enumerationFailed = true",
 "            return false",
 "        }) else {",
 "            throw SecurityFailure(message: \"无法读取 iOS 应用内容\")",
 "        }",
 "        var urls: [URL] = []",
 "        for case let url as URL in enumerator {",
 "            let directory = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true",
 "            _ = try ProductFileIdentity.identity(url, directory: directory)",
 "            urls.append(url)",
 "            guard urls.count <= 100_000 else { throw SecurityFailure(message: \"iOS 应用内容数量异常\") }",
 "        }",
 "        guard !enumerationFailed else { throw SecurityFailure(message: \"iOS 应用目录枚举失败，禁止使用不完整内容\") }",
 "        return urls.sorted { $0.path < $1.path }",
 "    }",
 "",
 "    private func iosTreeDigest(_ app: URL) throws -> String {",
 "        var hash = SHA256()",
 "        for url in try iosTree(app) {",
 "            hash.update(data: Data(url.path.dropFirst(app.path.count).utf8))",
 "            hash.update(data: Data([0]))",
 "            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {",
 "                hash.update(data: try Data(contentsOf: url, options: .mappedIfSafe))",
 "            }",
 "        }",
 "        return hash.finalize().map { String(format: \"%02x\", $0) }.joined()",
 "    }",
 "",
 "    private func iosInfo(_ app: URL, bundleID: String) throws -> (version: String, build: String) {",
 "        let url = app.appendingPathComponent(\"Info.plist\")",
 "        _ = try ProductFileIdentity.identity(url, directory: false)",
 "        guard let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any],",
 "              info[\"CFBundleIdentifier\"] as? String == bundleID,",
 "              info[\"CFBundlePackageType\"] as? String == \"APPL\",",
 "              (info[\"CFBundleSupportedPlatforms\"] as? [String])?.contains(\"iPhoneOS\") == true,",
 "              let executable = info[\"CFBundleExecutable\"] as? String, !executable.isEmpty,",
 "              !executable.contains(\"/\"), executable != \".\", executable != \"..\",",
 "              let version = info[\"CFBundleShortVersionString\"] as? String,",
 "              let build = info[\"CFBundleVersion\"] as? String else {",
 "            throw SecurityFailure(message: \"iOS 候选产品、平台或版本身份无效\")",
 "        }",
 "        _ = try ProductFileIdentity.identity(app.appendingPathComponent(executable), directory: false)",
 "        _ = try ProductIOSContract.iosVersion(version)",
 "        _ = try ProductIOSContract.iosVersion(build)",
 "        return (version, build)",
 "    }",
 "",
 "    private func iosCodeInformation(_ url: URL) throws -> [String: Any] {",
 "        var code: SecStaticCode?",
 "        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,",
 "              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures), nil) == errSecSuccess else {",
 "            throw SecurityFailure(message: \"iOS 签名严格验证失败\")",
 "        }",
 "        var information: CFDictionary?",
 "        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,",
 "              let information = information as? [String: Any] else {",
 "            throw SecurityFailure(message: \"iOS 签名信息无法读取\")",
 "        }",
 "        return information",
 "    }",
 "",
 "    private func validateIOSCode(_ url: URL, team: String, certificate: Data,",
 "                                 entitlements: [String: Any]? = nil) throws {",
 "        let information = try iosCodeInformation(url)",
 "        guard",
 "              information[kSecCodeInfoTeamIdentifier as String] as? String == team,",
 "              let certificates = information[kSecCodeInfoCertificates as String] as? [SecCertificate], let leaf = certificates.first,",
 "              SecCertificateCopyData(leaf) as Data == certificate else {",
 "            throw SecurityFailure(message: \"iOS 产品签名团队或证书不一致\")",
 "        }",
 "        if let entitlements {",
 "            guard let actual = information[kSecCodeInfoEntitlementsDict as String] as? [String: Any],",
 "                  ProductIOSContract.iosSignedEntitlementsMatch(actual, expected: entitlements) else {",
 "                throw SecurityFailure(message: \"iOS 产品签名 entitlement 与工程授权不一致\")",
 "            }",
 "        }",
 "    }",
 "",
 "    /// 产品Build已经完成签名；产品验证内嵌profile、证书链与实际代码签名，不读取签名私钥。",
 "    private func iosProductSigning(_ app: URL, team: String, bundleID: String, device: String,",
 "                                   requested: [String: Any]) throws -> (certificate: Data, entitlements: [String: Any]) {",
 "        let roots = try appleRoots()",
 "        let profileURL = app.appendingPathComponent(\"embedded.mobileprovision\")",
 "        _ = try ProductFileIdentity.identity(profileURL, directory: false)",
 "        let profileData = try Data(contentsOf: profileURL)",
 "        let profile = try decodeIOSProfile(profileData, roots: roots)",
 "        let entitlements = try ProductIOSContract.iosEntitlements(",
 "            profile: profile, team: team, bundleID: bundleID, device: device,",
 "            requested: requested, now: Date())",
 "        let information = try iosCodeInformation(app)",
 "        guard information[kSecCodeInfoTeamIdentifier as String] as? String == team,",
 "              let certificates = information[kSecCodeInfoCertificates as String] as? [SecCertificate],",
 "              let leaf = certificates.first,",
 "              let allowed = profile[\"DeveloperCertificates\"] as? [Data],",
 "              allowed.contains(SecCertificateCopyData(leaf) as Data),",
 "              let actual = information[kSecCodeInfoEntitlementsDict as String] as? [String: Any],",
 "              ProductIOSContract.iosSignedEntitlementsMatch(actual, expected: entitlements) else {",
 "            throw SecurityFailure(message: \"iOS 产品签名与内嵌 profile 不一致\")",
 "        }",
 "        var trust: SecTrust?",
 "        guard let policy = SecPolicyCreateWithProperties(kSecPolicyAppleCodeSigning, nil),",
 "              SecTrustCreateWithCertificates(certificates as CFArray, policy, &trust) == errSecSuccess,",
 "              let trust,",
 "              SecTrustSetAnchorCertificates(trust, roots as CFArray) == errSecSuccess,",
 "              SecTrustSetAnchorCertificatesOnly(trust, true) == errSecSuccess,",
 "              SecTrustSetNetworkFetchAllowed(trust, false) == errSecSuccess,",
 "              SecTrustEvaluateWithError(trust, nil) else {",
 "            throw SecurityFailure(message: \"iOS 产品签名证书链无效\")",
 "        }",
 "        return (SecCertificateCopyData(leaf) as Data, entitlements)",
 "    }",
 "",
 "",
 " func verify(app: URL, project: URL, device: String) throws -> [String: Any] {",
 "  _ = try ProductFileIdentity.identity(project, directory: false)",
 "  guard let objects = try PropertyListSerialization.propertyList(from: Data(contentsOf: project), format: nil) as? [String: Any] else { throw SecurityFailure(message: \"产品工程无效\") }",
 "  let settings = try ProductIOSContract.iosReleaseSettings(objects)",
 "  guard let bundle = settings[\"PRODUCT_BUNDLE_IDENTIFIER\"] as? String, let team = settings[\"DEVELOPMENT_TEAM\"] as? String,",
 "        bundle.range(of: \"^[A-Za-z0-9-]+(?:\\\\.[A-Za-z0-9-]+)+$\", options: .regularExpression) != nil,",
 "        team.range(of: \"^[A-Z0-9]{10}$\", options: .regularExpression) != nil else { throw SecurityFailure(message: \"产品签名身份无效\") }",
 "  var requested: [String: Any] = [:]",
 "  if let path = settings[\"CODE_SIGN_ENTITLEMENTS\"] as? String, !path.isEmpty {",
 "   guard !path.hasPrefix(\"/\"), !path.split(separator: \"/\").contains(\"..\"), !path.contains(\"$\") else { throw SecurityFailure(message: \"产品entitlement路径无效\") }",
 "   let base = project.pathExtension == \"pbxproj\" && project.deletingLastPathComponent().pathExtension == \"xcodeproj\" ? project.deletingLastPathComponent().deletingLastPathComponent() : project.deletingLastPathComponent()",
 "   let url = base.appendingPathComponent(path); _ = try ProductFileIdentity.identity(url, directory: false)",
 "   guard let values = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any] else { throw SecurityFailure(message: \"产品entitlement无效\") }; requested = values",
 "  }",
 "  let version = try iosInfo(app, bundleID: bundle), tree = try iosTree(app)",
 "  guard !tree.contains(where: { [\"appex\",\"app\",\"xpc\"].contains($0.pathExtension) }) else { throw SecurityFailure(message: \"嵌套应用缺少独立签名声明\") }",
 "  let signing = try iosProductSigning(app, team: team, bundleID: bundle, device: device, requested: requested)",
 "  for code in tree.filter({ [\"framework\",\"dylib\"].contains($0.pathExtension) }) { try validateIOSCode(code, team: team, certificate: signing.certificate) }",
 "  try validateIOSCode(app, team: team, certificate: signing.certificate, entitlements: signing.entitlements)",
 "  guard try iosInfo(app, bundleID: bundle) == version else { throw SecurityFailure(message: \"产品版本漂移\") }",
 "  return [\"version\":version.version,\"build\":version.build,\"bundle_id\":bundle,\"team\":team,\"sha256\":try iosTreeDigest(app)]",
 " }",
 "}",
 "// 独立执行使用产品自己的安全存储；调用方可用专用宿主通道提供等价开发材料能力。",
 "func development(_ product: String, value: Data?) throws -> Data? {",
 " let service = product + \" Development\", account = \"development:DEV_KEY\"",
 " let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account]",
 " func read() throws -> Data? { var output: CFTypeRef?; let status = SecItemCopyMatching(query.merging([kSecReturnData as String:true]) {_,v in v} as CFDictionary,&output)",
 "  if status == errSecItemNotFound { return nil }; guard status == errSecSuccess, let data = output as? Data else { throw SecurityFailure(message: \"产品开发材料读取失败\") }; return data }",
 " if let current = try read() { return current }",
 " guard let value else { return nil }",
 " let status = SecItemAdd(query.merging([kSecValueData as String:value,kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly]) {_,v in v} as CFDictionary,nil)",
 " guard status == errSecSuccess || status == errSecDuplicateItem else { throw SecurityFailure(message: \"产品开发材料存储失败\") }",
 " guard let stored = try read() else { throw SecurityFailure(message: \"产品开发材料写后回读缺失\") }; return stored",
 "}",
 "do {",
 " let bytes = FileHandle.standardInput.readDataToEndOfFile()",
 " guard bytes.count <= 128 * 1024, let request = try JSONSerialization.jsonObject(with: bytes) as? [String:Any], let operation = request[\"operation\"] as? String else { throw SecurityFailure(message: \"产品安全输入无效\") }",
 " let result: Any",
 " if operation == \"ios.verify\", let app = request[\"app\"] as? String, let project = request[\"project\"] as? String, let device = request[\"device\"] as? String {",
 "  result = try ProductVerifier().verify(app: URL(fileURLWithPath:app),project:URL(fileURLWithPath:project),device:device)",
 " } else if [\"development.read\",\"development.create\"].contains(operation), let product = request[\"product_id\"] as? String, product.range(of:\"^[a-z][a-z0-9-]*$\",options:.regularExpression) != nil {",
 "  var value = (request[\"value\"] as? String).flatMap { Data(base64Encoded:$0) }; defer { if var bytes = value { bytes.resetBytes(in:0..<bytes.count) }; value = nil }",
 "  guard operation != \"development.create\" || value != nil else { throw SecurityFailure(message:\"开发材料缺失\") }",
 "  var stored = try development(product,value:value); defer { if var bytes = stored { bytes.resetBytes(in:0..<bytes.count) }; stored = nil }",
 "  result = [\"value\":stored?.base64EncodedString() as Any? ?? NSNull()]",
 " } else { throw SecurityFailure(message:\"产品安全操作未声明\") }",
 " FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:result))",
 "} catch {",
 " // 不输出Security错误上下文、请求或材料；调用方只取得失败事实。",
 " FileHandle.standardError.write(Data(\"产品安全验真失败\\n\".utf8)); exit(1)",
 "}"
].join('\n');

// 包标识来自本产品唯一原始Android配置，不从调用方登记或另一端推导。
// 商店身份属于本产品：只读原始Release工程，不依赖控制台、发布声明或外部工具。
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
 const names=['scripts/flows.json','scripts/build.mjs',
  choose(['project/Runner.pbxproj','Runner.pbxproj'].map(name=>relative(root,join(source,'ios',name)))),
  choose(['build.gradle.kts','build.gradle'].map(name=>relative(root,join(source,'android/app',name))))];
 const data=names.map(name=>readStoreSource(root,name)),sha=data=>createHash('sha256').update(data).digest('hex');
 const declared=JSON.parse(data[0]);
 if(declared.schema!==1||declared.product_id!==product||declared.entry!=='scripts/build.mjs')fail('商店身份公开入口不一致');
 const receipt={schema:1,product_id:product,bundle_id:iosStoreBundleID(data[2].toString('utf8')),package_name:androidStorePackageName(data[3].toString('utf8')),
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
 await run(env.SWIFT,['-O','-module-cache-path',join(work,'cache/swift'),'-framework','Security','-framework','CryptoKit',source,'-o',binary],env,work);
 const digest=outputDigest(binary);
 const verify=async request=>{if(outputDigest(binary)!==digest)fail('产品安全验真器发生变化');return JSON.parse((await runBuildProcess(binary,[],env,work,{capture:true,input:JSON.stringify(request),timeout:300000})).stdout);};
 if(state)state.verifier=verify;return verify;
}
async function developmentMaterial(work,env,value) {
 const operation=value===undefined?'development.read':'development.create',host=await productHost();
 if(host)return host(operation,value);
 const verifier=await nativeVerifier(work,env);return (await verifier({operation,product_id:product,...(value===undefined?{}:{value})})).value;
}
export function parseAndroidSigning(encoded) {
 if(typeof encoded!=='string'||encoded.length>128*1024)fail('开发签名材料无效');const bytes=Buffer.from(encoded,'base64');
 try{const fields={};for(const raw of bytes.toString('utf8').split(/\r?\n/u)){const line=raw.trim();if(!line||line.startsWith('#'))continue;const at=line.indexOf('='),key=line.slice(0,at).trim(),value=line.slice(at+1).trim();if(at<1||!['keystore','password','alias','keyPassword'].includes(key)||Object.hasOwn(fields,key)||!value)fail('开发签名字段无效');fields[key]=value;}
  const keystore=Buffer.from(fields.keystore||'','base64');if(keystore.length<1024||keystore.length>64*1024||!fields.password||Buffer.byteLength(fields.password)>1024||Buffer.byteLength(fields.keyPassword||fields.password)>1024||!/^[A-Za-z0-9._-]{1,128}$/u.test(fields.alias||'development')){keystore.fill(0);fail('开发签名材料缺失');}
  return {keystore,password:fields.password,alias:fields.alias||'development',keyPassword:fields.keyPassword||fields.password};
 }finally{bytes.fill(0);}
}
async function completeAndroid(platform,work,receipt,env) {
 const packageName=androidPackageName(),sdk=env.ANDROID_HOME;
 const definitions=(await import('./resources.mjs')).resourceDeclarations().android;
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
 const version=await inspect(candidate),unsigned=await runBuildProcess(signer,['verify','--print-certs',candidate],env,work,{capture:true,accepted:[0,1],timeout:300000});
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
  const result=await call(adb,[...target,'install','-r',signed]);if(!result.stdout.split(/\r?\n/u).includes('Success'))fail('Android安装失败');
  await readback(target,index);
 };
 const readback=async(target,index)=>{
  const result=await runBuildProcess(adb,[...target,'shell','pm','path',packageName],env,work,{capture:true,accepted:[0,1],timeout:300000}),path=androidInstalledPath(result);
  if(!path)fail('Android安装后包缺失');const file=join(work,'installed-after-'+index+'.apk');
  if(existsSync(file))fail('Android回读路径已存在');await call(adb,[...target,'pull',path,file]);
  if(realpathSync(file)!==file||JSON.stringify(await inspect(file,certificate))!==JSON.stringify(version))fail('Android安装后产品、证书或版本不一致');
 };
 await saveMobileArtifact(platform,work,signed);
 if(outputDigest(signed)!==digest)fail('Android安装前签名产物改变');
 const first=await runBuildProcess(adb,['-d','install','-r',signed],env,work,{capture:true,accepted:[0,1],timeout:300000});
 if(first.code===0&&first.stdout.split(/\r?\n/u).includes('Success'))await readback(['-d'],0);
 else{
  if(first.code!==1||!first.stderr.includes('more than one device'))fail('ADB直接USB安装失败');
  const serials=androidUSBSerials((await call(adb,['devices','-l'])).stdout);let failures=0;
  for(let i=0;i<serials.length;i++){executions.getStore()?.signal?.throwIfAborted();try{await install(['-s',serials[i]],i);}catch{executions.getStore()?.signal?.throwIfAborted();failures++;}}
  if(failures)fail('Android USB安装或回读失败'+failures+'/'+serials.length+'，已尝试全部设备');
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
 const signal=executions.getStore()?.signal,helper=await nativeVerifier(work,env),projectCandidates=['project/Runner.pbxproj'].map(n=>join(root,'ios',n)).filter(existsSync);
 if(projectCandidates.length!==1)fail('iOS原始工程不唯一');const project=projectCandidates[0],archive=join(work,'ios.app.zip'),archiveDigest=outputDigest(archive),directory=join(work,'ios-product');
 await (await import('./resources.mjs')).extractArchive(archive,directory,{signal,maxBytes:2*1024**3});
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
   if(reachable.length>1)fail('多台可用iOS真机无法确定安装设备');if(reachable.length===1)return reachable[0];
   if(attempt<7)await pauseBuild(2000,signal);
  }fail('iOS真机等待就绪超时');
 };
 const device=await findDevice(),prepared=await helper({operation:'ios.verify',app,project,device:device.udid});
 const before=iosInstalled(await deviceCall(['device','info','apps','--device',device.identifier,'--include-all-apps','--bundle-id',prepared.bundle_id]),device.identifier,prepared.bundle_id);
 const less=(a,b)=>{for(let i=0;i<3;i++){if(a[i]<b[i])return true;if(a[i]>b[i])return false;}return false;};
 if(before&&(less(iosVersion(prepared.version),iosVersion(before.version))||!less(iosVersion(prepared.version),iosVersion(before.version))&&!less(iosVersion(before.version),iosVersion(prepared.version))&&less(iosVersion(prepared.build),iosVersion(before.build))))fail('iOS禁止降级安装');
 const refreshed=await findDevice();if(JSON.stringify(refreshed)!==JSON.stringify(device)||JSON.stringify(await helper({operation:'ios.verify',app,project,device:device.udid}))!==JSON.stringify(prepared))fail('iOS安装前设备或签名产物漂移');
 if(outputDigest(archive)!==archiveDigest)fail('iOS归档输入漂移');
 await saveMobileArtifact(platform,work,archive);
 await deviceCall(['device','install','app','--device',device.identifier,app]);
 const after=iosInstalled(await deviceCall(['device','info','apps','--device',device.identifier,'--include-all-apps','--bundle-id',prepared.bundle_id]),device.identifier,prepared.bundle_id);
 if(!after||after.version!==prepared.version||after.build!==prepared.build)fail('iOS安装后产品或版本回读不一致');
 if(outputDigest(archive)!==archiveDigest||JSON.stringify(await helper({operation:'ios.verify',app,project,device:device.udid}))!==JSON.stringify(prepared))fail('iOS安装期间签名产物漂移');
 process.stderr.write('本机移动产物已签名验真；设备安装及产品身份、版本回读通过\n');
}
function pauseBuild(ms,signal){signal?.throwIfAborted();return new Promise((resolve,reject)=>{const abort=()=>{clearTimeout(timer);reject(Error('产品任务已取消'));};const timer=setTimeout(()=>{signal?.removeEventListener('abort',abort);resolve();},ms);signal?.addEventListener('abort',abort,{once:true});if(signal?.aborted)abort();});}
async function saveMobileArtifact(platform,work,path) {
 const declared=platformContract(platform);if(declared.files.length!==1)fail('移动候选登记不唯一');
 const publicPath=join(work,declared.files[0]);
 if(path!==publicPath){unlinkSync(publicPath);copyFileSync(path,publicPath);}
 const host=await productHost();
 if(host)await host('artifact',[{path:publicPath,sha256:outputDigest(publicPath)}]);
}
async function completeMobile(platform,work,receipt,env) {
 executions.getStore()?.signal?.throwIfAborted();if(platform.endsWith('android'))await completeAndroid(platform,work,receipt,env);else await completeIOS(platform,work,receipt,env);
}

// 每次调用拥有自己的取消和进程集合，导入API并发也不能共享执行状态。
const executions=new AsyncLocalStorage();
export async function runBuildProcess(file,args,env,cwd=root,{capture=false,input,accepted=[0],timeout=7200000,signal=executions.getStore()?.signal,passHost=false,streamError=false}={}) {
 signal?.throwIfAborted();
 return new Promise((ok,reject)=>{
  const child=spawn(file,args,{cwd,env:workEnvironment(env),detached:true,stdio:['pipe','pipe','pipe',...(passHost?[3]:[])]});
  trackWorkProcess(child.pid);
  let stdout=[],stderr=[],bytes=0,reason,settled=false;
  const stop=()=>{try{process.kill(-child.pid,'SIGTERM');}catch(error){if(error.code!=='ESRCH')reason='无法取消产品工具进程组';}};
  let killer;
  const terminate=()=>{stop();clearTimeout(killer);killer=setTimeout(()=>{try{process.kill(-child.pid,'SIGKILL');}catch{}},1500);};
  const forced=setTimeout(()=>{reason='产品工具超时';terminate();},timeout);forced.unref();
  const abort=()=>{reason='产品任务已取消';terminate();};
  signal?.addEventListener('abort',abort,{once:true});
  const consume=(chunk,out)=>{bytes+=chunk.length;if(bytes>16*1024*1024){reason='产品工具输出超限';terminate();return;}out.push(chunk);if(!capture)process.stderr.write(chunk);};
  child.stdout.on('data',chunk=>consume(chunk,stdout));child.stderr.on('data',chunk=>{if(capture&&streamError)process.stderr.write(chunk);else consume(chunk,stderr);});
  child.stdin.on('error',()=>{reason='产品工具输入失败';stop();});
  child.once('error',()=>{reason='产品工具无法启动';});
  child.once('close',async(code,termination)=>{
   clearTimeout(forced);clearTimeout(killer);
   // 主进程close不代表后代退出；未退出的同组工具必须停止并确认，之后才能清理材料。
   const alive=()=>{if(!child.pid)return false;try{process.kill(-child.pid,0);return true;}catch(error){return error.code!=='ESRCH';}};
   if(alive()){reason??='产品工具退出后仍有后代';stop();for(let n=0;n<15&&alive();n++)await new Promise(r=>setTimeout(r,100));if(alive())try{process.kill(-child.pid,'SIGKILL');}catch{};for(let n=0;n<15&&alive();n++)await new Promise(r=>setTimeout(r,100));}
   if(alive()){reason='产品工具后代退出未确认，保留工作目录';const state=executions.getStore();if(state)state.unconfirmed=true;}
   signal?.removeEventListener('abort',abort);clearTimeout(killer);
   if(signal?.aborted)reason='产品任务已取消';
   if(settled)return;settled=true;
   if(reason||termination||!accepted.includes(code))reject(Error(reason||'产品工具执行失败'));
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
// 摘要只读执行源码；所属根技术文档及target等运行数据不改变编译身份。
function sourceDigest() {
 const hash=createHash('sha256'),rootData=new Set(['cache','target','rely','tools','tasks','TATA.md','MAP.md','CODEX.md','CLAUDE.md','README.md','CitizenApp.md']);
 const generated=new Set(['.git','node_modules','.dart_tool','.gradle','.symlinks','Pods','build','target','ephemeral','.cache','.DS_Store']);
 function visit(path){for(const name of readdirSync(path).sort()){
  if(generated.has(name)||path===root&&rootData.has(name))continue;
  const file=join(path,name),info=lstatSync(file);hash.update(relative(root,file)+'\n');
  if(info.isDirectory())visit(file);else if(info.isFile()){hash.update(String(Boolean(info.mode&0o111)));hash.update(readFileSync(file));}
  else if(info.isSymbolicLink()){const real=realpathSync(file);if(!inside(root,real))fail('产品源码链接越界');hash.update(readlinkSync(file));}
  else fail('产品源码特殊输入未声明');
 }}visit(root);return hash.digest('hex');
}

// 宿主完整Build先由调用方消费回执、安装并收尾；独立执行由本产品清空现场。
export async function execute(platform,work,request={},options={}) {
 checkWork(work);
 return withFixedWork(taskScope(work),()=>executeTask(platform,work,request,options),{environment:options.environment||process.env,retain:request.resource_mode==='provided'||(options.environment||process.env).PRODUCT_HOST_FD==='3'});
}
async function executeTask(platform,work,request={},options={}) {
 checkWork(work);platformContract(platform);
 if(!inside(productTarget(platform),work)||work===productTarget(platform))fail('执行工作根与当前产品平台不一致');
 options.signal?.throwIfAborted();
 if(!request||typeof request!=='object'||Array.isArray(request)||Object.keys(request).some(k=>!['schema','product_id','platform','work','run_id','program_digest'].includes(k))
  ||request.schema!==undefined&&request.schema!==1||request.run_id!==undefined&&!/^[1-9][0-9]{8}$/u.test(request.run_id)||request.program_digest!==undefined&&!/^[a-f0-9]{64}$/u.test(request.program_digest)
  ||request.product_id!==undefined&&request.product_id!==product||request.platform!==undefined&&request.platform!==platform||request.work!==undefined&&request.work!==work)fail('公开Build请求身份或字段无效');
 chmodSync(work,0o700);
 const lock=join(work,'.product-build.lock'),resultFile=join(work,'build-result.json');
 if(existsSync(resultFile))fail('本轮完整Build已有结果，禁止复用旧终态');
 const handle=openSync(lock,'wx',0o600);closeSync(handle);
 const cancellation=new AbortController(),abort=()=>cancellation.abort();options.signal?.addEventListener('abort',abort,{once:true});if(options.signal?.aborted)abort();
 const state={signal:cancellation.signal,cancellation,host:options.host,unconfirmed:false,finished:false};
 try{return await executions.run(state,async()=>{
  const initial=sourceDigest(),stages=options.stages||{requirements,resources:(...args)=>import('./resources.mjs').then(m=>m.resources(...args)),prepare,build};
  const unchanged=()=>{state.signal.throwIfAborted();if(sourceDigest()!==initial)fail('产品源码或锁在执行期间改变');};
  const resourcesOptions={signal:state.signal,offline:Boolean(options.offline),environment:options.environment||process.env};
  await stages.requirements(platform,work);unchanged();
  let receipt=await stages.resources(platform,work,request,resourcesOptions);unchanged();
  await stages.prepare(platform,work,receipt,resourcesOptions.environment);unchanged();
  await stages.requirements(platform,work);
  receipt=await stages.resources(platform,work,receipt,resourcesOptions);unchanged();
  const result=await stages.build(platform,work,receipt,resourcesOptions.environment);unchanged();
  checkBuildResult(result,platform,work,request.run_id);
  writeFileSync(resultFile,JSON.stringify(result)+'\n',{flag:'wx',mode:0o600});return result;
 });}catch(error){if(String(error?.message).includes('退出未确认'))state.unconfirmed=true;throw error;}finally{state.finished=true;state.socket?.destroy();options.signal?.removeEventListener('abort',abort);if(!state.unconfirmed){unlinkSync(lock);if(request.resource_mode!=='provided'&&(options.environment||process.env).PRODUCT_HOST_FD!=='3')clearWork(work);}}
}
export function checkBuildResult(value,platform,work,runId) {
 const declared=platformContract(platform);
 if(!value||Object.keys(value).sort().join(',')!==(runId?'completion,files,platform,product_id,run_id,schema,work':'completion,files,platform,product_id,schema,work')
  ||value.schema!==1||value.product_id!==product||value.platform!==platform||value.work!==work||value.completion!==declared.completion
  ||runId&&value.run_id!==runId||!Array.isArray(value.files)||value.files.length!==declared.files.length)fail('完整Build结果身份或完成方式无效');
 for(let n=0;n<value.files.length;n++){const entry=value.files[n],file=join(work,declared.files[n]);
  if(Object.keys(entry).sort().join(',')!=='path,sha256'||entry.path!==file||!inside(work,file)||realpathSync(file)!==file||!/^[a-f0-9]{64}$/u.test(entry.sha256)||outputDigest(file)!==entry.sha256)fail('完整Build产物摘要或边界无效');}
 return value;
}
async function completeBuild(platform,work,receipt,env) {
 const declared=platformContract(platform);
 if(declared.completion==='device-install')await completeMobile(platform,work,receipt,env);
 if(declared.completion==='macos-artifact')for(const name of declared.files)await run(env.CODESIGN,['--verify','--deep','--strict',join(work,name)],env);
 const result={schema:1,product_id:product,platform,work,completion:declared.completion,
  files:declared.files.map(name=>{const path=join(work,name);if(!inside(work,path)||realpathSync(path)!==path)fail('Build候选越界');return {path,sha256:outputDigest(path)};})};
 if(receipt.run_id)result.run_id=receipt.run_id;return checkBuildResult(result,platform,work,receipt.run_id);
}

// 全双工宿主通道只传开发签名材料，不与stdout结果、stderr日志或资源回执混用。
async function productHost() {
 const supplied=executions.getStore()?.host;if(supplied)return supplied;
 if(process.env.PRODUCT_HOST_FD===undefined)return null;
 if(process.env.PRODUCT_HOST_FD!=='3')fail('宿主通道描述符无效');
 const socket=new Socket({fd:3,readable:true,writable:true}),pending=new Map();let buffer='',sequence=0;
 socket.on('data',chunk=>{buffer+=chunk.toString('utf8');if(Buffer.byteLength(buffer)>128*1024){socket.destroy();return;}
  let end;while((end=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,end);buffer=buffer.slice(end+1);try{const reply=JSON.parse(line),entry=pending.get(reply.id);if(!entry)throw Error();pending.delete(reply.id);clearTimeout(entry.timer);if(reply.ok!==true)entry.reject(Error('开发签名材料宿主操作失败'));else entry.resolve(reply.value);}catch{socket.destroy();}}});
 const close=()=>{const state=executions.getStore();if(state&&!state.finished)state.cancellation?.abort();for(const entry of pending.values()){clearTimeout(entry.timer);entry.reject(Error('产品宿主通道中断'));}pending.clear();};socket.on('error',close);socket.on('close',close);socket.unref();
 const host=(operation,value)=>new Promise((resolve,reject)=>{if(!['development.read','development.create','artifact'].includes(operation))return reject(Error('宿主能力未授权'));
  const id=String(++sequence),timer=setTimeout(()=>{pending.delete(id);reject(Error('开发材料操作超时'));socket.destroy();},30000);
  pending.set(id,{resolve,reject,timer});socket.write(JSON.stringify({id,operation,...(value===undefined?{}:operation==='artifact'?{files:value}:{value})})+'\n');});
 executions.getStore().host=host;executions.getStore().socket=socket;return host;
}
// 模块先完成初始化，资源模块才能反向导入本文件的唯一校验；异步CLI在独立Promise中执行。

// 原生消费路径只在target恢复；Logo统一读取assets/logo，同内容只保留一个来源。
export const PLATFORM_INPUTS=Object.freeze([["android/app/tests/MlsTransportSecurityInstrumentedTest.kt","android/app/src/androidTest/MlsTransportSecurityInstrumentedTest.kt"],["android/app/tests/RegistrationRecordSecurityInstrumentedTest.kt","android/app/src/androidTest/RegistrationRecordSecurityInstrumentedTest.kt"],["android/app/tests/SquareMediaChannelInstrumentedTest.kt","android/app/src/androidTest/SquareMediaChannelInstrumentedTest.kt"],["android/app/source/debug_manifest.xml","android/app/src/debug_manifest.xml"],["android/app/source/AndroidManifest.xml","android/app/src/main/AndroidManifest.xml"],["android/app/source/MainActivity.kt","android/app/src/main/MainActivity.kt"],["android/app/source/SquareMediaChannel.kt","android/app/src/main/SquareMediaChannel.kt"],["android/app/source/SquareMp4FastStart.kt","android/app/src/main/SquareMp4FastStart.kt"],["android/app/source/SquareVideoTranscoder.kt","android/app/src/main/SquareVideoTranscoder.kt"],["android/resources/drawable-v21_launch_background.xml","android/app/src/main/res/drawable-v21_launch_background.xml"],["android/resources/drawable_launch_background.xml","android/app/src/main/res/drawable_launch_background.xml"],["android/resources/mipmap_anydpi_v26_ic_launcher.xml","android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"],["android/resources/mipmap_anydpi_v26_ic_launcher_round.xml","android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml"],["assets/logo/icon72.png","android/app/src/main/res/mipmap-hdpi/ic_launcher.png"],["assets/logo/foreground162.png","android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png"],["assets/logo/icon72.png","android/app/src/main/res/mipmap-hdpi/ic_launcher_round.png"],["assets/logo/launch180.png","android/app/src/main/res/mipmap-hdpi/launch_image.png"],["assets/logo/icon48.png","android/app/src/main/res/mipmap-mdpi/ic_launcher.png"],["assets/logo/foreground108.png","android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png"],["assets/logo/icon48.png","android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png"],["assets/logo/launch120.png","android/app/src/main/res/mipmap-mdpi/launch_image.png"],["assets/logo/icon96.png","android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"],["assets/logo/foreground216.png","android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png"],["assets/logo/icon96.png","android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.png"],["assets/logo/launch240.png","android/app/src/main/res/mipmap-xhdpi/launch_image.png"],["assets/logo/icon144.png","android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"],["assets/logo/foreground324.png","android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png"],["assets/logo/icon144.png","android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png"],["assets/logo/launch360.png","android/app/src/main/res/mipmap-xxhdpi/launch_image.png"],["assets/logo/icon192.png","android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"],["assets/logo/foreground432.png","android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png"],["assets/logo/icon192.png","android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png"],["assets/logo/launch480.png","android/app/src/main/res/mipmap-xxxhdpi/launch_image.png"],["android/resources/values-en_strings.xml","android/app/src/main/res/values-en_strings.xml"],["android/resources/values-night_styles.xml","android/app/src/main/res/values-night_styles.xml"],["android/resources/values_colors.xml","android/app/src/main/res/values/colors.xml"],["android/resources/values_strings.xml","android/app/src/main/res/values/strings.xml"],["android/resources/values_styles.xml","android/app/src/main/res/values/styles.xml"],["android/resources/xml_network_security_config.xml","android/app/src/main/res/xml/network_security_config.xml"],["android/resources/xml_update_file_paths.xml","android/app/src/main/res/xml/update_file_paths.xml"],["android/app/source/profile_manifest.xml","android/app/src/profile_manifest.xml"],["ios/config/AppFrameworkInfo.plist","ios/Flutter/AppFrameworkInfo.plist"],["ios/config/Debug.xcconfig","ios/Flutter/Debug.xcconfig"],["ios/config/Release.xcconfig","ios/Flutter/Release.xcconfig"],["ios/project/Runner.pbxproj","ios/Runner.xcodeproj/project.pbxproj"],["ios/project/project.xcworkspacedata","ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata"],["ios/project/ProjectWorkspaceChecks.plist","ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist"],["ios/project/ProjectWorkspaceSettings.xcsettings","ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings"],["ios/project/Runner.xcscheme","ios/Runner.xcscheme"],["ios/project/Runner.xcworkspacedata","ios/Runner.xcworkspace/contents.xcworkspacedata"],["ios/project/RunnerWorkspaceChecks.plist","ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist"],["ios/project/RunnerWorkspaceSettings.xcsettings","ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings"],["ios/source/AppDelegate.swift","ios/Runner/AppDelegate.swift"],["ios/resources/icons.json","ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"],["assets/logo/icon1024.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"],["assets/logo/icon20.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png"],["assets/logo/icon40.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png"],["assets/logo/icon60.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png"],["assets/logo/icon29.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png"],["assets/logo/icon58.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png"],["assets/logo/icon87.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png"],["assets/logo/icon40.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png"],["assets/logo/icon80.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png"],["assets/logo/icon120.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png"],["assets/logo/icon120.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png"],["assets/logo/icon180.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png"],["assets/logo/icon76.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png"],["assets/logo/icon152.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png"],["assets/logo/icon167.png","ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png"],["assets/logo/launch160.png","ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/CitizenLaunchLogo.png"],["assets/logo/launch320.png","ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/CitizenLaunchLogo@2x.png"],["assets/logo/launch480.png","ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/CitizenLaunchLogo@3x.png"],["ios/resources/launch.json","ios/Runner/Assets.xcassets/CitizenLaunchLogo.imageset/Contents.json"],["ios/resources/CitizenLaunchScreen.storyboard","ios/Runner/Base.lproj/CitizenLaunchScreen.storyboard"],["ios/resources/Main.storyboard","ios/Runner/Base.lproj/Main.storyboard"],["ios/source/Info.plist","ios/Runner/Info.plist"],["ios/source/InfoPlist.xcstrings","ios/Runner/InfoPlist.xcstrings"],["ios/source/Runner-Bridging-Header.h","ios/Runner/Runner-Bridging-Header.h"],["ios/source/Runner.entitlements","ios/Runner/Runner.entitlements"],["ios/source/SceneDelegate.swift","ios/Runner/SceneDelegate.swift"],["ios/source/SquareMediaChannel.swift","ios/Runner/SquareMediaChannel.swift"],["ios/source/SquareVideoTranscoder.swift","ios/Runner/SquareVideoTranscoder.swift"],["ios/source/SystemProtectedDataChannel.swift","ios/Runner/SystemProtectedDataChannel.swift"],["ios/tests/RunnerTests.swift","ios/RunnerTests.swift"],["ios/tests/RunnerUITests.swift","ios/RunnerUITests.swift"],["ios/project/RunnerUITests.xcscheme","ios/RunnerUITests.xcscheme"]]);
export function materializePlatformInputs(source,destination) {
 for(const [inputName,outputName] of PLATFORM_INPUTS) {
  const input=join(source,inputName);if(!existsSync(input))continue;
  const output=join(destination,outputName);mkdirSync(dirname(output),{recursive:true,mode:0o700});
  copyHostInput(input,output,source);
 }
 writeFileSync(join(destination,'analysis_options.yaml'),ANALYSIS_OPTIONS_SOURCE);
 writeFileSync(join(destination,'dart_test.yaml'),DART_TEST_SOURCE);
}
export const ANALYSIS_OPTIONS_SOURCE = "include: package:flutter_lints/flutter.yaml\n\nanalyzer:\n  exclude:\n    - \"**/*.g.dart\"\n    # 工程视图内的锁定SDK与生成缓存归target，不扫描其独立测试。\n    - \"target/**\"\n\nlinter:\n  rules:\n    prefer_const_constructors: true\n    use_build_context_synchronously: true\n";
export const DART_TEST_SOURCE = "# CitizenApp 测试配置。\n# Isar(isar_community / MDBX)是进程级 native;跨文件隔离由 test/support/isar_test_env.dart\n# 的唯一临时目录保证,此处再钉死串行执行 + 合理超时作保险(默认并发会让多 isolate 抢\n# 同一 native 层、更慢且易 flaky)。\nconcurrency: 1\ntimeout: 90s\n";
export const LOGO_ASSETS_SOURCE = "{\n  \"schema\": 1,\n  \"product\": \"citizenapp\",\n  \"source\": {\n    \"repository\": \"crcfrcn/citizenchain\",\n    \"path\": \"icons/logo.png\",\n    \"sha256\": \"81e11c03b8b2c2702d745870424660239308c1b2d1caf91cfb1b688367fe8a53\"\n  },\n  \"files\": {\n    \"android/resources/values_colors.xml\": \"d0384216cbc00e635a975599f270af729cd9fa860bacf62d121680f585561bd3\",\n    \"assets/logo/foreground108.png\": \"ed7d9b1eabd510ebcae47221ff78381a2ba2d41e5a4990e56d25ebabdad3c65a\",\n    \"assets/logo/foreground162.png\": \"7ff1c4ae15d00f6a65a8ce6471054d6e37c5664cc9104f844aa9904882591e63\",\n    \"assets/logo/foreground216.png\": \"f8c5bbeb68c77abaa74ffb1f402221f5115bcf4d24ebf7e854490ff34e081e5e\",\n    \"assets/logo/foreground324.png\": \"57afe78264c3179f166cbae09c47c70f1535e07ac3ba25db319efbd3c8ed8656\",\n    \"assets/logo/foreground432.png\": \"6f2b955dfdd30cf4c0613d4c78255be0de43d06281fd0ec57ee6feb10bd1b06d\",\n    \"assets/logo/icon1024.png\": \"b79d8b2c3ff321af5bbfed756f843234fb98d4d7c0cf9109b2fbea183b29413d\",\n    \"assets/logo/icon120.png\": \"9bde3a24f31c602e5ad759d12ca861525163258d3ef368dc9c0aac71a9bd4bed\",\n    \"assets/logo/icon152.png\": \"31c6e6724a648c4aebdfee9d50a90fb8fbc2e0f5833912967a889893504b8818\",\n    \"assets/logo/icon167.png\": \"07fa68c82a6a71f0dfaa70f7a6b49bcd13cf9c595594ab49f35bda799f0db153\",\n    \"assets/logo/icon180.png\": \"ef6f852849fe7d6ccefa6928548df05e1b20afefa73fa2182e3816bff6a89154\",\n    \"assets/logo/icon20.png\": \"186ee5943cba56e68615de3de410d8813b81fa175deb9abcc0d9b8b8cd2a97e0\",\n    \"assets/logo/icon29.png\": \"1200ad5ae52d5b1991116bb323f64dfa3efc4a2d4ffd91a493d57d92386f54a9\",\n    \"assets/logo/icon40.png\": \"b3af1ab701c34e7d35bfc348ef7b4720eee4182b1f2a795bd70cc5d336357541\",\n    \"assets/logo/icon58.png\": \"116e7257b5e5cdb81a86704db37b584a8ebee07ab84d424b495d5bb9c36c1a86\",\n    \"assets/logo/icon60.png\": \"fb3628fe0d573ea189dec5fb2354524c0a4f31e0876fee64c0085f6351264f0e\",\n    \"assets/logo/icon76.png\": \"4b03895eb0e1db9b6cf7ebd467a34383315e68aa8b5b63ed3a5e51f7fe70a138\",\n    \"assets/logo/icon80.png\": \"b2ccd91bc44810cdf5ddc2094e597a49a7eab2a8563593aa8b2e00e85c643d17\",\n    \"assets/logo/icon87.png\": \"7b226f834d9aedf30c1f07b742a9aa4793c89afaa9f3f953480b764380ad85af\",\n    \"assets/logo/launch120.png\": \"1ce729c3a23ac185f6a54397bef5d5c8a317f67b38f66bea1f3393b6dec9da2a\",\n    \"assets/logo/icon144.png\": \"f203f0700e86403515c280f2a0c6c933ab1bdb95c63a12f5187de1629ad87b7f\",\n    \"assets/logo/launch160.png\": \"b7ce607af0ecd513fababdda9831aa3056cb99e3fd45234bea7ef4d0de9c88aa\",\n    \"assets/logo/launch180.png\": \"81789009c4dc03a283f610183cf0b462dc7e473dbdbbd6edb4da12a62a4f5177\",\n    \"assets/logo/icon192.png\": \"092869629be4dd591352237a789f08a21e09c5c28faf66b503e16e9cc7e0f5d6\",\n    \"assets/logo/launch240.png\": \"fff07730b40f242d922c023d21f7db62555acac86365c9fc96276daf0b65c488\",\n    \"assets/logo/launch320.png\": \"9188e7f70e8a492d2bd3af021f1f2be7688e64d3bebc317d88f2ad1a169c2432\",\n    \"assets/logo/launch360.png\": \"06c6b7d208914e36eb4f6fedb62828027534eac81c338a0bf6060872fa61f9d0\",\n    \"assets/logo/icon48.png\": \"4c03ec508fdcb94a1a037aa66477d749ff96d2c35e46a3adbe3b27ba64c27632\",\n    \"assets/logo/launch480.png\": \"34a50a60d559d09fdd1037fad391ad62b242c842f6845f2cb76c57486ef150be\",\n    \"assets/logo/icon72.png\": \"c8cfdefdbc3b28e2e7d123bc36cd509fb93fc60c9436632afc69265554e81b62\",\n    \"assets/logo/icon96.png\": \"278eb6a62a06c0ef22a50b6c358533f88d5b9fd1e6c93e711e298155908d9bee\",\n    \"assets/logo/mark256.png\": \"f097de9e416019941ec61635ed5bcf7119000a0ad1e9f7c24359110088446d64\",\n    \"ios/resources/icons.json\": \"3b1e214f466ffedff74baa5598ad5c4421130eea6bc8d57b8fe23435e8280ae4\",\n    \"ios/resources/launch.json\": \"1f9acec06f02258e719a8e3d1895b2b06111f2b21063f598d00bf875ffa52fb3\"\n  }\n}\n";
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

// 第一方依赖只来自宿主声明和锁中的准确公开Git提交；不读取邻仓、不接受override。
// Git检出和标准Flutter消费视图均属于本次工作根，宿主源码声明和锁保持原字节。
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
    const sha = dependencyField(declared, 'ref');
    if (!/^    git:\s*$/m.test(declared) || !/^[0-9a-f]{40}$/.test(sha)
      || dependencyField(declared, 'url') !== url || dependencyField(declared, 'path') !== '.'
      || dependencyField(locked, 'source') !== 'git' || dependencyField(locked, 'url') !== url
      || dependencyField(locked, 'path') !== '.' || dependencyField(locked, 'ref') !== sha
      || dependencyField(locked, 'resolved-ref') !== sha
      || dependencyField(locked, 'version') !== '1.0.0') fail('第一方声明、锁和唯一Git来源不一致：' + name);
    const parent = join(work, 'git-sources'); mkdirSync(parent, { recursive: true, mode: 0o700 });
    verifyGitDirectory(parent);
    const root = join(parent, name);
    if (!existsSync(root)) {
      mkdirSync(root, { mode: 0o700 });
      const owned = lstatSync(root);
      try {
        sourceGit(root, ['init', '--quiet']);
        sourceGit(root, ['remote', 'add', 'origin', url]);
        sourceGit(root, ['fetch', '--no-tags', '--depth=1', 'origin', sha]);
        sourceGit(root, ['checkout', '--quiet', '--detach', sha]);
      } catch {
        const now = lstatSync(root, { throwIfNoEntry: false });
        if (now?.isDirectory() && !now.isSymbolicLink() && now.dev === owned.dev && now.ino === owned.ino) rmSync(root, { recursive: true });
        fail('第一方固定Git提交取得失败；未使用邻仓或重试：' + name);
      }
    }
    verifyGitDirectory(root); verifyGitDirectory(join(root, '.git'));
    if (resolve(sourceGit(root, ['rev-parse', '--show-toplevel'])) !== root
      || resolve(sourceGit(root, ['rev-parse', '--absolute-git-dir'])) !== join(root, '.git')
      || resolve(root, sourceGit(root, ['rev-parse', '--git-common-dir'])) !== join(root, '.git')
      || sourceGit(root, ['rev-parse', '--abbrev-ref', 'HEAD']) !== 'HEAD'
      || sourceGit(root, ['rev-parse', 'HEAD']) !== sha || sourceGit(root, ['remote', 'get-url', 'origin']) !== url
      || sourceGit(root, ['status', '--porcelain=v1', '--untracked-files=all']) !== ''
      || !new RegExp('^name:\\s*' + name + '\\s*$', 'm').test(readFileSync(join(root, 'pubspec.yaml'), 'utf8'))) {
      fail('第一方Git检出身份或源码已变：' + name);
    }
    result[name] = { root, url, sha };
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
      + JSON.stringify(target) + '\n      relative: false\n    source: path\n    version: "1.0.0"\n');
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

// 只对已声明的本地聊天包调用其公开装配接口，宿主不复制插件包路径。
async function chatSourceViewApi(packageRoot) {
  const manifest = readFileSync(join(packageRoot, 'pubspec.yaml'), 'utf8');
  if (!/^name: tatachat_sdk\r?$/mu.test(manifest)) return null;
  const entry = join(packageRoot, 'scripts/release.mjs');
  if (!lstatSync(entry).isFile() || lstatSync(entry).isSymbolicLink()) fail('聊天SDK装配入口必须是普通文件');
  return import(pathToFileURL(entry).href);
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
    rmSync(viewRoot, { recursive: true });
  }
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
    if (/^name: citizen_sdk\r?$/mu.test(readFileSync(join(sourceDirectory, "pubspec.yaml"), "utf8"))) {
      // SDK独自拥有Flutter入口布局；宿主不复制包名/路径映射合同。
      const api = await import(pathToFileURL(join(sourceDirectory, "scripts/release.mjs")).href);
      api.createFlutterSourceView(sourceDirectory, destinationRoot);
      return;
    }
    const chat = await chatSourceViewApi(sourceDirectory);
    if (chat) {
      await chat.createFlutterSourceView(sourceDirectory, destinationRoot);
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
        ['ios/project/RunnerUITests.xcscheme', 'ios/Runner.xcodeproj/xcshareddata/xcschemes/RunnerUITests.xcscheme'],
        ['android/gradle-wrapper.properties', 'android/gradle/wrapper/gradle-wrapper.properties'],
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
  return mappedPath(sourceRoot);
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
    const api = await import(pathToFileURL(join(item.root, 'scripts/release.mjs')).href);
    await api.assertFlutterSourceView(item.root, view);
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
  if (/^name: citizen_sdk\r?$/mu.test(readFileSync(join(packageRoot, "pubspec.yaml"), "utf8"))) {
    const api = await import(pathToFileURL(join(packageRoot, "scripts/release.mjs")).href);
    api.assertFlutterSourceView(packageRoot, packageView);
  } else {
    const chat = await chatSourceViewApi(packageRoot);
    if (chat) await chat.assertFlutterSourceView(packageRoot, packageView);
    else if (!manifestInfo?.isSymbolicLink() || realpathSync(manifest) !== join(packageRoot, 'pubspec.yaml')) {
      fail('SDK视图与源码根绑定无效');
    }
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
async function runTestInputs(argv) {
// App金标读取链所有者已保存的不可变Git快照；不复制金标，不猜测邻仓。
const { spawnSync } = await import("node:child_process");
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
function git(root, args) {
  const result = spawnSync('git', ['-c', 'credential.helper=', '-c', 'core.hooksPath=/dev/null',
    '-c', 'protocol.file.allow=never', '-c', 'gc.auto=0', '-C', root, ...args], {
    encoding: 'utf8', env: { ...process.env, GIT_TERMINAL_PROMPT: '0',
      GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: process.platform === 'win32' ? 'NUL' : '/dev/null' },
  });
  if (result.error || result.status !== 0) fail('链测试源取得或验真失败');
  return result.stdout.trim();
}
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
 if(!/^(?:assets\/logo\/(?:icon|foreground|launch|mark)[1-9][0-9]*[.]png|ios\/resources\/(?:icons|launch)[.]json|android\/resources\/values_colors[.]xml)$/.test(relative)
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
for(const platform of ['android','ios'])rejectPlatformCopies(join(root,platform,'resources'));
process.stdout.write('公民Logo派生物清单检查通过\n');

}
export const BUILD_SHELL_SOURCES=Object.freeze({"run":"#!/usr/bin/env bash\n# 在调用方指定的源码外工作根生成本机优化安装包；本脚本不启动、不安装产品。\n#\n# 用法：node scripts/build.mjs run <ios|android>\n# 只读包检查：node scripts/build.mjs run <verify-ios-localization|verify-android-localization> <产物路径>\n# Isar 生成后补齐职责注释：node scripts/build.mjs run normalize-isar-comments\n#\n# 目标平台是必填参数，不做任何自动探测：探测总要在失败时选一个回落，\n# 而回落的那一端会被当成用户想编的那一端——「以为编了 iOS、实际编的 Android」\n# 就是这么来的。任意调用方都必须显式传入且只能构建这一端。\n#\n# 调用方可提供本仓target内的独立缓存目录；默认使用target/build/<平台>。\n# 公民链轻节点、交易和链存储全部由 CitizenSDK Flutter plugin 提供。\nset -euo pipefail\nSCRIPT_DIR=\"${CITIZENAPP_SCRIPTS_ROOT:?缺少源码脚本根}\"\n# 消解 scripts/..，确保直接产品源码身份使用唯一真实路径。\nAPP_ROOT=\"${CITIZENAPP_SOURCE_ROOT:?缺少产品源码根}\"\nREPO_ROOT=\"$APP_ROOT\"\n# 只补齐两份既定生成文件的职责说明；全部输入通过检查后才允许写入。\nif [[ \"${1:-}\" == normalize-isar-comments ]]; then\n  [[ \"$#\" == 1 ]] || { echo 'Isar 注释规范化不接受额外参数' >&2; exit 1; }\n  node - \"$APP_ROOT\" <<'NORMALIZE_ISAR_COMMENTS'\nconst { lstatSync, readFileSync, writeFileSync } = require('node:fs');\nconst { join } = require('node:path');\nconst root = process.argv[2];\nfor (const path of [root, join(root, 'lib'), join(root, 'lib/storage')]) {\n  if (!lstatSync(path).isDirectory() || lstatSync(path).isSymbolicLink()) {\n    throw new Error('Isar 输入目录必须为真实目录');\n  }\n}\nconst entries = [\n  ['user_isar', '// 由 user_isar.dart 生成用户域集合、序列化与查询；身份展示缓存不得作为授权真源。'],\n  ['wallet_isar', '// 由 wallet_isar.dart 生成钱包域集合、序列化与查询；余额展示快照不得作为链上授权真源。'],\n];\nconst header = '// GENERATED CODE - DO NOT MODIFY BY HAND\\n';\nconst updates = entries.map(([name, comment]) => {\n  const path = join(root, 'lib/storage', `${name}.g.dart`);\n  if (!lstatSync(path).isFile() || lstatSync(path).isSymbolicLink()) {\n    throw new Error(`Isar 生成文件必须为普通文件：${name}`);\n  }\n  const original = readFileSync(path, 'utf8');\n  const normalized = `${header}${comment}\\n`;\n  const body = original.startsWith(normalized) ? original.slice(normalized.length)\n    : original.startsWith(header) ? original.slice(header.length) : null;\n  if (body === null || !body.startsWith(`\\npart of '${name}.dart';\\n`)) {\n    throw new Error(`Isar 生成头或所属源文件不匹配：${name}`);\n  }\n  return { path, original, next: normalized + body };\n});\nfor (const { path, original, next } of updates) {\n  if (original !== next) writeFileSync(path, next);\n}\nprocess.stdout.write('Isar 两份生成文件职责注释已规范化，生成正文保持不变\\n');\nNORMALIZE_ISAR_COMMENTS\n  exit 0\nfi\nCITIZENSDK_ROOT=''\nTATACHATSDK_ROOT=''\nVIEW_SCRIPT=\"$SCRIPT_DIR/build.mjs\"\nPLATFORM=\"${1:?缺少目标平台，用法：$0 <ios|android>}\"\n[[ \"$PLATFORM\" == ios || \"$PLATFORM\" == android \\\n  || \"$PLATFORM\" == verify-ios-localization || \"$PLATFORM\" == verify-android-localization ]] \\\n  || { echo \"目标平台或检查模式不合法：$PLATFORM\" >&2; exit 1; }\nif [[ \"$PLATFORM\" == ios || \"$PLATFORM\" == android ]]; then\n  CITIZENAPP_WORK_DIR=\"${CITIZENAPP_WORK_DIR:-$APP_ROOT/target/build/$PLATFORM}\"\n  # macOS 的 /tmp、/var 可能是系统链接；先创建再读取物理路径，使默认直接开发路径\n  # 与工程视图的“规范绝对路径、无链接祖先”安全合同一致。\n  mkdir -p \"$CITIZENAPP_WORK_DIR\"\n  CITIZENAPP_WORK_DIR=\"$(cd \"$CITIZENAPP_WORK_DIR\" && pwd -P)\"\n  dependency_sources=\"$(node \"$VIEW_SCRIPT\" view dependencies --source-root \"$APP_ROOT\" --work-root \"$CITIZENAPP_WORK_DIR\")\"\n  CITIZENSDK_ROOT=\"$(printf '%s' \"$dependency_sources\" | node -e 'let s=\"\";process.stdin.on(\"data\",c=>s+=c);process.stdin.on(\"end\",()=>process.stdout.write(JSON.parse(s).citizen_sdk.root));')\"\n  TATACHATSDK_ROOT=\"$(printf '%s' \"$dependency_sources\" | node -e 'let s=\"\";process.stdin.on(\"data\",c=>s+=c);process.stdin.on(\"end\",()=>process.stdout.write(JSON.parse(s).tatachat_sdk.root));')\"\n  # 源码根只用于读取输入和调用原生脚本；Flutter可写状态始终进入调用方工作目录。\n  [[ \"$APP_ROOT\" == \"$REPO_ROOT\" ]] || {\n    echo \"citizenapp本机Build源码身份无效：$APP_ROOT\" >&2\n    exit 1\n  }\n  if [[ -z \"${CITIZENAPP_PROJECT_ROOT:-}\" ]]; then\n    CITIZENAPP_PROJECT_ROOT=\"$(node \"$VIEW_SCRIPT\" view create \\\n      --source-root \"$APP_ROOT\" --work-root \"$CITIZENAPP_WORK_DIR\")\"\n  fi\n  [[ -d \"$CITIZENAPP_PROJECT_ROOT\" && -f \"$CITIZENAPP_PROJECT_ROOT/pubspec.yaml\" ]] \\\n    || { echo 'CitizenApp Flutter 产品目录无效' >&2; exit 1; }\n  export CITIZENAPP_PROJECT_ROOT\n  cd \"$CITIZENAPP_PROJECT_ROOT\"\n  BUILD_WORK_DIR=\"${CITIZENAPP_BUILD_WORK_DIR:-$CITIZENAPP_WORK_DIR/work}\"\n  DEPENDENCY_WORK_DIR=\"${CITIZENAPP_DEPENDENCY_DIR:-$CITIZENAPP_WORK_DIR/dependencies}\"\n  BUILD_DIR=\"${CITIZENAPP_BUILD_DIR:-$BUILD_WORK_DIR/flutter}\"\n  ARTIFACT_ROOT=\"${CITIZENAPP_ARTIFACT_DIR:-$CITIZENAPP_WORK_DIR}\"\n  python3 - \"$APP_ROOT\" \"$CITIZENAPP_WORK_DIR\" \"$BUILD_WORK_DIR\" \"$DEPENDENCY_WORK_DIR\" \"$BUILD_DIR\" \"$ARTIFACT_ROOT\" <<'CHECK_OUTPUTS'\nfrom pathlib import Path\nimport sys\nsource = Path(sys.argv[1]).resolve()\nfor value in sys.argv[2:]:\n    raw = Path(value)\n    target = raw.resolve()\n    if not raw.is_absolute() or source / 'target' not in target.parents:\n        raise SystemExit(f'CitizenApp可写目录必须是本仓target内绝对路径：{value}')\nCHECK_OUTPUTS\n  export CITIZENAPP_BUILD_DIR=\"$BUILD_DIR\"\n  export CITIZENAPP_NATIVE_ANDROID_DIR=\"${CITIZENAPP_NATIVE_ANDROID_DIR:-$BUILD_WORK_DIR/native/android}\"\n  export CITIZENAPP_NATIVE_IOS_DIR=\"${CITIZENAPP_NATIVE_IOS_DIR:-$BUILD_WORK_DIR/native/ios}\"\n  export CARGO_TARGET_DIR=\"${CARGO_TARGET_DIR:-$BUILD_WORK_DIR/cargo}\"\n  export XDG_CONFIG_HOME=\"${XDG_CONFIG_HOME:-$DEPENDENCY_WORK_DIR/flutter-config}\"\n  export PUB_CACHE=\"${PUB_CACHE:-$DEPENDENCY_WORK_DIR/pub}\"\n  export GRADLE_USER_HOME=\"$DEPENDENCY_WORK_DIR/gradle\"\n  # 只有 Android 使用 Gradle；iOS 工程不装配 Wrapper，也不依赖 Android 工具。\n  if [[ \"$PLATFORM\" == android ]]; then\n    GRADLE_EXECUTABLE=\"${CITIZENAPP_GRADLE:-$CITIZENAPP_PROJECT_ROOT/android/gradlew}\"\n    [[ \"$GRADLE_EXECUTABLE\" == /* && -f \"$GRADLE_EXECUTABLE\" && ! -L \"$GRADLE_EXECUTABLE\"\n        && -x \"$GRADLE_EXECUTABLE\" ]] \\\n      || { echo 'CitizenApp Gradle执行器必须是绝对普通可执行文件' >&2; exit 1; }\n  fi\n  export CP_HOME_DIR=\"$DEPENDENCY_WORK_DIR/cocoapods\"\n  export TMPDIR=\"$CITIZENAPP_WORK_DIR/tmp/\"\n  export FLUTTER_SUPPRESS_ANALYTICS=true COCOAPODS_DISABLE_STATS=true\n  CITIZENAPP_GRADLE_INIT_SCRIPT=\"${CITIZENAPP_GRADLE_INIT_SCRIPT:-$CITIZENAPP_WORK_DIR/gradle.init.gradle}\"\n  CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR=\"${CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR:-$BUILD_WORK_DIR/flutter-gradle-plugin}\"\n  export CITIZENAPP_GRADLE_INIT_SCRIPT CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR\n  mkdir -p \"$XDG_CONFIG_HOME\" \"$TMPDIR\" \"$CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR\"\n  printf '%s\\n' \\\n    'gradle.beforeSettings { settings ->' \\\n    '    def source = System.getenv(\"CITIZENAPP_FLUTTER_GRADLE_ROOT\")' \\\n    '    if (source && settings.settingsDir.canonicalPath == new File(source).canonicalPath) {' \\\n    '        settings.pluginManagement.repositories {' \\\n    '            clear()' \\\n    '            mavenCentral()' \\\n    '            google()' \\\n    '            gradlePluginPortal()' \\\n    '        }' \\\n    '    }' \\\n    '}' \\\n    'gradle.beforeProject { project ->' \\\n    '    def source = System.getenv(\"CITIZENAPP_FLUTTER_GRADLE_ROOT\")' \\\n    '    def output = System.getenv(\"CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR\")' \\\n    '    if (source && output && project.rootDir.canonicalPath == new File(source).canonicalPath) {' \\\n    '        def suffix = project.path == \":\" ? \"root\" : project.path.substring(1).replace(\":\", \"/\")' \\\n    '        project.layout.buildDirectory.set(new File(output, suffix))' \\\n    '    }' \\\n    '}' >\"$CITIZENAPP_GRADLE_INIT_SCRIPT\"\n  # Flutter只接受相对产品根的build-dir配置；把源码外绝对目录换算为相对路径，\n  # 不能写死为产品源码下的cache/build，也不能在产品根生成build。\n  FLUTTER_BUILD_RELATIVE=\"$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' \"$BUILD_DIR\" \"$CITIZENAPP_PROJECT_ROOT\")\"\n  flutter config --build-dir=\"$FLUTTER_BUILD_RELATIVE\" >/dev/null\nfi\n\n# Android的SDK原生Gradle与最终App Gradle必须使用同一个产品JDK。\n# 直接开发可显式传JAVA_HOME；macOS本机默认使用Android Studio自带JBR。\nANDROID_JAVA_HOME=''\nANDROID_SDK_HOME=''\nif [[ \"$PLATFORM\" == android ]]; then\n  if [[ -n \"${ANDROID_HOME:-}\" && -n \"${ANDROID_SDK_ROOT:-}\" \\\n    && \"$ANDROID_HOME\" != \"$ANDROID_SDK_ROOT\" ]]; then\n    echo 'CitizenApp Android的ANDROID_HOME与ANDROID_SDK_ROOT必须一致' >&2\n    exit 1\n  fi\n  ANDROID_SDK_HOME=\"${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}\"\n  ANDROID_JAVA_HOME=\"${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}\"\n  [[ \"$ANDROID_SDK_HOME\" == /* && -d \"$ANDROID_SDK_HOME\" \\\n    && -d \"$ANDROID_SDK_HOME/ndk/28.2.13676358\" ]] \\\n    || { echo 'CitizenApp Android缺少带固定NDK的产品SDK目录' >&2; exit 1; }\n  [[ \"$ANDROID_JAVA_HOME\" == /* && -x \"$ANDROID_JAVA_HOME/bin/java\" ]] \\\n    || { echo 'CitizenApp Android缺少可执行产品JDK' >&2; exit 1; }\nfi\n\nPUB_GET_ARGS=(--enforce-lockfile)\ncase \"${CITIZENAPP_OFFLINE:-false}\" in\n  true) PUB_GET_ARGS+=(--offline); export CARGO_NET_OFFLINE=true ;;\n  false) ;;\n  *) echo 'CITIZENAPP_OFFLINE只接受true或false' >&2; exit 1 ;;\nesac\ngradle_network_arg=''\nCITIZENAPP_GRADLE_OFFLINE=\"${CITIZENAPP_GRADLE_OFFLINE:-${CITIZENAPP_OFFLINE:-false}}\"\ncase \"$CITIZENAPP_GRADLE_OFFLINE\" in\n  true) gradle_network_arg='--offline' ;;\n  false) ;;\n  *) echo 'CITIZENAPP_GRADLE_OFFLINE只接受true或false' >&2; exit 1 ;;\nesac\n\n# 离线调用方必须分别提供SDK与聊天SDK的Cargo闭包；产品Build按实际所有者切换，\n# 禁止把两套Cargo Home混用。普通开发者在线Build继续使用自己的标准Cargo环境。\nif [[ \"${CITIZENAPP_OFFLINE:-false}\" == true ]]; then\n  for value in \"${CITIZENAPP_SDK_CARGO_HOME:-}\" \"${CITIZENAPP_CHAT_CARGO_HOME:-}\"; do\n    [[ \"$value\" == \"$DEPENDENCY_WORK_DIR\"/* && -d \"$value\" && ! -L \"$value\" \\\n      && -f \"$value/config.toml\" ]] \\\n      || { echo 'CitizenApp离线Build缺少独立Cargo依赖闭包' >&2; exit 1; }\n  done\nfi\n\n# 仅清理本任务的候选包；不触碰源码、其它工作目录或另一端。\nclean_platform_build_outputs() {\n  case \"$PLATFORM\" in\n    ios) rm -rf \"$BUILD_DIR/ios/iphoneos/Runner.app\" ;;\n    android) rm -f \"$BUILD_DIR/app/outputs/flutter-apk/\"*.apk ;;\n  esac\n  mkdir -p \"$BUILD_DIR\"\n}\n\n# iOS Runner.app完成签名后只覆盖固定 `ios.app.zip`。\nretain_ios_local_artifact() {\n  local app_bundle=\"$1\" staging=\"$CITIZENAPP_WORK_DIR/ios.app.zip\" destination=\"$ARTIFACT_ROOT/ios.app.zip\"\n  rm -f \"$staging\"\n  ditto -c -k --sequesterRsrc --keepParent \"$app_bundle\" \"$staging\"\n  mkdir -p \"$ARTIFACT_ROOT\"\n  # 同卷固定名称覆盖保证失败时不先删除上一次成功产物。\n  mv -f \"$staging\" \"$destination\"\n}\n\n# Android产品Build只提交已验真的无私钥候选；签名、安装和安装后回读\n# 继续由调用方的原生安全进程唯一负责。\nretain_android_local_artifact() {\n  local apk=\"$1\" staging=\"$CITIZENAPP_WORK_DIR/android.apk.pending\" destination=\"$ARTIFACT_ROOT/android.apk\"\n  rm -f \"$staging\"\n  cp \"$apk\" \"$staging\"\n  chmod 600 \"$staging\"\n  mkdir -p \"$ARTIFACT_ROOT\"\n  # 同卷固定名称覆盖，安全进程只会看到完整普通文件。\n  mv -f \"$staging\" \"$destination\"\n}\n\n# 系统权限弹窗由操作系统渲染；App 唯一能提供的是最终包内的受支持语言和本地化产品名。\n# 只检查源码会漏掉 Xcode variant group 未入 Resources 等问题，Build必须回读最终包。\nverify_ios_release_localization() {\n  local app_bundle=\"$1\" info=\"$1/Info.plist\"\n  local zh_strings=\"$1/zh-Hans.lproj/InfoPlist.strings\"\n  local en_strings=\"$1/en.lproj/InfoPlist.strings\"\n  [[ -f \"$info\" && -f \"$zh_strings\" && -f \"$en_strings\" ]] || {\n    echo \"iOS Release 缺少 Info.plist 或中英文本地化资源：$app_bundle\" >&2\n    return 1\n  }\n  [[ \"$(plutil -extract CFBundleDevelopmentRegion raw -o - \"$info\")\" == zh-Hans ]] || {\n    echo 'iOS Release 默认回落语言必须是 zh-Hans' >&2\n    return 1\n  }\n  plutil -extract CFBundleLocalizations json -o - \"$info\" | python3 -c '\nimport json, sys\nif json.load(sys.stdin) != [\"zh-Hans\", \"en\"]:\n    raise SystemExit(\"iOS Release 支持语言必须严格为 zh-Hans、en\")\n'\n  [[ \"$(plutil -extract CFBundleDisplayName raw -o - \"$zh_strings\")\" == 公民 \\\n    && \"$(plutil -extract CFBundleName raw -o - \"$zh_strings\")\" == 公民 ]] || {\n    echo 'iOS Release 中文产品名必须是“公民”' >&2\n    return 1\n  }\n  [[ \"$(plutil -extract CFBundleDisplayName raw -o - \"$en_strings\")\" == CitizenApp \\\n    && \"$(plutil -extract CFBundleName raw -o - \"$en_strings\")\" == CitizenApp ]] || {\n    echo 'iOS Release 英文产品名必须是 CitizenApp' >&2\n    return 1\n  }\n  echo '    iOS Release 本地化通过：中文=公民，英文=CitizenApp，默认回落=zh-Hans'\n}\n\n# Android 权限正文由系统按手机语言渲染；这里锁定最终 APK 的默认中文和英文限定应用名。\nverify_android_release_localization() {\n  local apk=\"$1\" aapt_bin sdk_home\n  [[ -f \"$apk\" ]] || { echo \"Android Release APK 不存在：$apk\" >&2; return 1; }\n  aapt_bin=\"$(command -v aapt2 || true)\"\n  if [[ -z \"$aapt_bin\" ]]; then\n    # 产品只读取公开工具链环境，不依赖启动它的桌面进程恰好继承ANDROID_HOME。\n    # 与原生库构建保持同一确定性规则：显式 SDK 优先，macOS 默认\n    # SDK 目录兜底，再从已安装 build-tools 中选择最高版本，禁止硬编码具体版本。\n    sdk_home=\"${ANDROID_HOME:-$HOME/Library/Android/sdk}\"\n    aapt_bin=\"$(find \"$sdk_home/build-tools\" -type f -name aapt2 -print 2>/dev/null | sort -V | tail -n 1)\"\n  fi\n  [[ -x \"$aapt_bin\" ]] || { echo '找不到 Android SDK aapt2，无法核验 APK 本地化' >&2; return 1; }\n  \"$aapt_bin\" dump resources \"$apk\" | python3 -c '\nimport re, sys\ntext = sys.stdin.read()\nmatch = re.search(r\"resource 0x[0-9a-f]+ string/app_name\\n(?P<body>(?:      .*\\n)+?)    resource \", text)\nif match is None:\n    raise SystemExit(\"Android Release APK 缺少 string/app_name\")\nbody = match.group(\"body\")\nif \"() \\\"公民\\\"\" not in body or \"(en) \\\"CitizenApp\\\"\" not in body:\n    raise SystemExit(\"Android Release APK 的默认中文或英文应用名不正确\")\n'\n  echo '    Android Release 本地化通过：默认=公民，英文=CitizenApp'\n}\n\nif [[ \"$PLATFORM\" == verify-ios-localization ]]; then\n  verify_ios_release_localization \"${2:?缺少 Runner.app 路径}\"\n  exit 0\nfi\nif [[ \"$PLATFORM\" == verify-android-localization ]]; then\n  verify_android_release_localization \"${2:?缺少 APK 路径}\"\n  exit 0\nfi\n\n\n# 构造 dart-define 参数\nDART_DEFINES=()\necho \"[Build模式] CitizenSDK · 目标平台 $PLATFORM\"\n\n# Flutter只负责在当前缓存根生成产品自己的Android配置和插件清单；真正的Gradle\n# 从产品真实android目录启动，所有可写状态仍由既有环境变量指向本任务缓存。\nbuild_android_release() {\n  local properties flutter_command flutter_sdk android_sdk product_version version_name version_code\n  local flutter_version dart_defines link_target java_home\n  properties=\"$CITIZENAPP_PROJECT_ROOT/android/local.properties\"\n  flutter_sdk=\"${FLUTTER_ROOT:-}\"\n  if [[ -z \"$flutter_sdk\" ]]; then\n    flutter_command=\"$(command -v flutter)\"\n    while [[ -L \"$flutter_command\" ]]; do\n      link_target=\"$(readlink \"$flutter_command\")\"\n      [[ \"$link_target\" == /* ]] || link_target=\"$(cd \"$(dirname \"$flutter_command\")\" && pwd -P)/$link_target\"\n      flutter_command=\"$link_target\"\n    done\n    flutter_sdk=\"$(cd \"$(dirname \"$flutter_command\")/..\" && pwd -P)\"\n  fi\n  [[ \"$flutter_sdk\" == /* && -x \"$flutter_sdk/bin/flutter\" \\\n      && -f \"$flutter_sdk/packages/flutter_tools/gradle/build.gradle.kts\" ]] \\\n    || { echo 'CitizenApp Flutter SDK根目录无效' >&2; exit 1; }\n  android_sdk=\"$ANDROID_SDK_HOME\"\n  # JDK与Android SDK由CitizenApp产品入口传给同一次Gradle调用；不在Worker增加前置检查。\n  java_home=\"$ANDROID_JAVA_HOME\"\n  product_version=\"$(sed -n 's/^version:[[:space:]]*//p' \"$CITIZENAPP_PROJECT_ROOT/pubspec.yaml\" | head -n 1)\"\n  version_name=\"${product_version%%+*}\"\n  version_code=\"${product_version##*+}\"\n  printf 'sdk.dir=%s\\nflutter.sdk=%s\\nflutter.buildMode=release\\nflutter.versionName=%s\\nflutter.versionCode=%s\\n' \\\n    \"$android_sdk\" \"$flutter_sdk\" \"$version_name\" \"$version_code\" >\"$properties\"\n  flutter_version=\"$(flutter --version --machine)\"\n  dart_defines=\"$(printf '%s' \"$flutter_version\" | python3 -c '\nimport base64, json, sys\nvalue = json.load(sys.stdin)\nfields = (\n    (\"FLUTTER_VERSION\", \"frameworkVersion\"),\n    (\"FLUTTER_CHANNEL\", \"channel\"),\n    (\"FLUTTER_GIT_URL\", \"repositoryUrl\"),\n    (\"FLUTTER_FRAMEWORK_REVISION\", \"frameworkRevision\"),\n    (\"FLUTTER_ENGINE_REVISION\", \"engineRevision\"),\n    (\"FLUTTER_DART_VERSION\", \"dartSdkVersion\"),\n)\nprint(\",\".join(base64.b64encode(f\"{name}={value[key]}\".encode()).decode() for name, key in fields))\n')\"\n  (\n    cd \"$APP_ROOT/android\"\n    # Flutter Gradle included-build 的 Kotlin 会默认在工具源码根写 .kotlin/sessions；\n    # 显式定位到本轮工作目录，共享 Flutter 工具原件始终保持只读。\n    ANDROID_HOME=\"$android_sdk\" ANDROID_SDK_ROOT=\"$android_sdk\" JAVA_HOME=\"$java_home\" PATH=\"$java_home/bin:$PATH\" \\\n    CITIZENAPP_FLUTTER_GRADLE_ROOT=\"$flutter_sdk/packages/flutter_tools/gradle\" \\\n    FLUTTER_ROOT=\"$flutter_sdk\" \"$GRADLE_EXECUTABLE\" ${gradle_network_arg:+\"$gradle_network_arg\"} --no-daemon --stacktrace --no-problems-report \\\n      --init-script \"$CITIZENAPP_GRADLE_INIT_SCRIPT\" \\\n      --project-cache-dir \"$BUILD_WORK_DIR/gradle-project\" \\\n      -Pkotlin.project.persistent.dir=\"$CITIZENAPP_FLUTTER_GRADLE_BUILD_DIR/kotlin-project\" \\\n      -Pflutter.sdk=\"$flutter_sdk\" \\\n      -Ptarget-platform=android-arm64 \\\n      -Ptarget=lib/main.dart \\\n      -Pbase-application-name=android.app.Application \\\n      -Pdart-defines=\"$dart_defines\" \\\n      -Pdart-obfuscation=false \\\n      -Ptrack-widget-creation=true \\\n      -Ptree-shake-icons=true \\\n      assembleRelease\n  )\n}\n\n# 这里曾有一句 `pkill -9 -f flutter_tools.snapshot`，用途是清掉上一轮残留的 flutter。\n# 已删除：`-f` 匹配全命令行，而 `flutter_tools.snapshot` 是每一个 flutter 命令的实际执行体，\n# 那一枪不区分产品、不区分平台、也不区分是不是本次运行的——公民钱包正在跑的编译、\n# 乃至你自己在终端里手敲的 flutter，都会一起被 SIGKILL（现象是 `Killed: 9`）。\n# 产品脚本不终止任何既有Flutter进程；进程生命周期由当前调用方管理。\n\n# 本机开发场景直接调用CitizenSDK唯一产品入口生成原生产物；CitizenApp只把SDK产物\n# 目录交给Flutter插件，不复制、不修改也不实现第二份链库。\nCITIZENSDK_DEPENDENCY_WORK_DIR=\"${CITIZENAPP_SDK_DEPENDENCY_WORK_DIR:-$DEPENDENCY_WORK_DIR/citizensdk-native}\"\n[[ \"$CITIZENSDK_DEPENDENCY_WORK_DIR\" == \"$DEPENDENCY_WORK_DIR\"/* ]] \\\n  || { echo 'CitizenSDK依赖目录必须属于CitizenApp依赖工作目录' >&2; exit 1; }\nCITIZENSDK_PRODUCT_WORK_DIR=\"$BUILD_WORK_DIR/citizensdk-work\"\nCITIZENSDK_PRODUCT_OUTPUT_DIR=\"$BUILD_WORK_DIR/citizensdk-output\"\nrm -rf \"$CITIZENSDK_PRODUCT_WORK_DIR\" \"$CITIZENSDK_PRODUCT_OUTPUT_DIR\"\nnode \"$CITIZENSDK_ROOT/scripts/dependencies.mjs\" prepare-environment \\\n  --scope citizensdk --platform \"$([[ \"$PLATFORM\" == ios ]] && printf macOS || printf Android)\" \\\n  --work \"$CITIZENSDK_DEPENDENCY_WORK_DIR\"\nexport CITIZENSDK_ZXING_SOURCE_DIR=\"$CITIZENSDK_DEPENDENCY_WORK_DIR/zxing-cpp-3.1.1\"\nif [[ \"${CITIZENAPP_OFFLINE:-false}\" == true ]]; then\n  export CARGO_HOME=\"$CITIZENAPP_SDK_CARGO_HOME\"\nfi\nif [[ \"$PLATFORM\" == ios ]]; then\n  CITIZENSDK_WORK_DIR=\"$CITIZENSDK_PRODUCT_WORK_DIR\" \\\n    CITIZENSDK_NATIVE_OUTPUT_DIR=\"$CITIZENSDK_PRODUCT_OUTPUT_DIR\" \\\n    \"$CITIZENSDK_ROOT/scripts/build-native.sh\" apple\n  node \"$VIEW_SCRIPT\" view project-framework \\\n    --source-root \"$APP_ROOT\" --project-root \"$CITIZENAPP_PROJECT_ROOT\" \\\n    --work-root \"$CITIZENAPP_WORK_DIR\" --package-root \"$CITIZENSDK_ROOT\" \\\n    --package-subpath darwin/CitizenSDK.xcframework \\\n    --framework \"$CITIZENSDK_PRODUCT_OUTPUT_DIR/apple/CitizenSDK.xcframework\" >/dev/null\nelse\n  CITIZENSDK_WORK_DIR=\"$CITIZENSDK_PRODUCT_WORK_DIR\" \\\n    CITIZENSDK_NATIVE_OUTPUT_DIR=\"$CITIZENSDK_PRODUCT_OUTPUT_DIR\" \\\n    CITIZENSDK_GRADLE=\"$GRADLE_EXECUTABLE\" \\\n    CITIZENSDK_OFFLINE=\"$CITIZENAPP_GRADLE_OFFLINE\" \\\n    JAVA_HOME=\"$ANDROID_JAVA_HOME\" PATH=\"$ANDROID_JAVA_HOME/bin:$PATH\" \\\n    ANDROID_HOME=\"$ANDROID_SDK_HOME\" ANDROID_SDK_ROOT=\"$ANDROID_SDK_HOME\" \\\n    \"$CITIZENSDK_ROOT/scripts/build-native.sh\" android\n  export CITIZENSDK_ANDROID_CORE_DIR=\"$CITIZENSDK_PRODUCT_OUTPUT_DIR/android/arm64-v8a\"\nfi\n\n# TataChatSDK仍按聊天产品自有流程构建。\nif [[ \"${CITIZENAPP_OFFLINE:-false}\" == true ]]; then\n  export CARGO_HOME=\"$CITIZENAPP_CHAT_CARGO_HOME\"\nfi\nif [[ \"$PLATFORM\" == ios ]]; then\n  [[ -f \"$TATACHATSDK_ROOT/ios/tatachat_sdk.podspec\" ]] || {\n    echo 'CitizenApp 本端 TataChatSDK iOS 插件配置缺失' >&2\n    exit 1\n  }\n  TATACHATSDK_NATIVE_IOS_DIR=\"$CITIZENAPP_NATIVE_IOS_DIR\" \\\n    TATACHATSDK_WORK_DIR=\"$BUILD_WORK_DIR/tatachatsdk-work\" \\\n    \"$TATACHATSDK_ROOT/scripts/build-native.sh\" \"$PLATFORM\"\n  node \"$VIEW_SCRIPT\" view project-framework \\\n    --source-root \"$APP_ROOT\" --project-root \"$CITIZENAPP_PROJECT_ROOT\" \\\n    --work-root \"$CITIZENAPP_WORK_DIR\" --package-root \"$TATACHATSDK_ROOT\" \\\n    --package-subpath ios/TataChatSDK.xcframework \\\n    --framework \"$CITIZENAPP_NATIVE_IOS_DIR/TataChatSDK.xcframework\" >/dev/null\nelse\n  TATACHATSDK_NATIVE_ANDROID_DIR=\"$CITIZENAPP_NATIVE_ANDROID_DIR\" \\\n    TATACHATSDK_WORK_DIR=\"$BUILD_WORK_DIR/tatachatsdk-work\" \\\n    \"$TATACHATSDK_ROOT/scripts/build-native.sh\" \"$PLATFORM\"\nfi\n\necho \"==> 清理 ${PLATFORM} 平台构建产物...\"\nclean_platform_build_outputs\necho \"==> 按CitizenApp锁文件准备依赖...\"\nflutter pub get \"${PUB_GET_ARGS[@]}\"\n\n# Build不选择、不安装、不启动设备，只读取当前产品源码并生成产品产物。\n# `--release`只是本机优化配置，不表示或触发正式Release流程。\necho \"==> 编译本机优化安装包...\"\nif [[ \"$PLATFORM\" == ios ]]; then\n  flutter build ios --no-pub --release ${DART_DEFINES[@]+\"${DART_DEFINES[@]}\"}\n  IOS_APP=\"$BUILD_DIR/ios/iphoneos/Runner.app\"\n  \"$TATACHATSDK_ROOT/scripts/build-native.sh\" verify-ios-package \"$IOS_APP\"\n  verify_ios_release_localization \"$IOS_APP\"\n  retain_ios_local_artifact \"$IOS_APP\"\n  echo \"\"\n  echo \"==> Build完成：iOS产物已写入CitizenApp产物目录。\"\nelif [[ \"$PLATFORM\" == android ]]; then\n  ANDROID_APK=\"$BUILD_DIR/app/outputs/flutter-apk/app-release.apk\"\n  build_android_release\n  [[ -f \"$ANDROID_APK\" ]] || {\n    echo \"Android 本机无私钥 APK 不存在\" >&2\n    exit 1\n  }\n  \"$TATACHATSDK_ROOT/scripts/build-native.sh\" verify-android-package \"$ANDROID_APK\"\n  verify_android_release_localization \"$ANDROID_APK\"\n  retain_android_local_artifact \"$ANDROID_APK\"\n  echo \"==> Android无私钥候选完成，正在交给原生安全进程完成Build签名。\"\nfi\n","test":"#!/usr/bin/env bash\n# CitizenApp 本机与 CI 唯一 Flutter 测试入口。\n#\n# CitizenApp SDK金标消费锁定CitizenSDK的真实产品Core；两份SDK宿主库\n# 由各自产品入口准备，Isar消费本轮锁定包的宿主库。\nset -euo pipefail\n\nSCRIPT_DIR=\"${CITIZENAPP_SCRIPTS_ROOT:?缺少源码脚本根}\"\nCITIZENAPP_DIR=\"${CITIZENAPP_SOURCE_ROOT:?缺少产品源码根}\"\nFLUTTER_BIN=\"${FLUTTER_BIN:-flutter}\"\nVIEW_SCRIPT=\"$SCRIPT_DIR/build.mjs\"\nFLUTTER_ROOT=''\nANALYSIS_CONFIG=''\nTEST_CONFIG=''\nTEST_CONFIGS_STAGED=false\nCITIZENAPP_TEST_WORK_DIR=\"${CITIZENAPP_TEST_WORK_DIR:-$CITIZENAPP_DIR/target/test}\"\nBUILD_CACHE=\"${CITIZENAPP_TEST_BUILD_DIR:-$CITIZENAPP_TEST_WORK_DIR/work}\"\nDEPENDENCY_CACHE=\"${CITIZENAPP_TEST_DEPENDENCY_DIR:-$CITIZENAPP_TEST_WORK_DIR/dependencies}\"\npython3 - \"$CITIZENAPP_DIR\" \"$CITIZENAPP_TEST_WORK_DIR\" \"$BUILD_CACHE\" \"$DEPENDENCY_CACHE\" <<'CHECK_OUTPUTS'\nfrom pathlib import Path\nimport sys\nsource = Path(sys.argv[1]).resolve()\nfor value in sys.argv[2:]:\n    raw = Path(value)\n    target = raw.resolve()\n    if not raw.is_absolute() or source / 'target' not in target.parents:\n        raise SystemExit(f'CitizenApp测试目录必须是本仓target内绝对路径：{value}')\nCHECK_OUTPUTS\nmkdir -p \"$CITIZENAPP_TEST_WORK_DIR\"\nCITIZENCHAIN_ROOT=\"$(node \"$SCRIPT_DIR/build.mjs\" inputs \"$CITIZENAPP_TEST_WORK_DIR\")\"\nexport CITIZENCHAIN_ROOT\n# Flutter分析、测试、.dart_tool与build全部在源码外工程视图运行；源码文件保持\n# 唯一真源且只读投影，测试不得再向CitizenApp根生成build或临时配置。\nif [[ -n \"${CITIZENAPP_TEST_PROJECT_ROOT:-}\" ]]; then\n  FLUTTER_ROOT=\"$(node \"$VIEW_SCRIPT\" view verify \\\n    --source-root \"$CITIZENAPP_DIR\" --work-root \"$CITIZENAPP_TEST_WORK_DIR\")\"\n  [[ \"$FLUTTER_ROOT\" == \"$CITIZENAPP_TEST_PROJECT_ROOT\" ]] \\\n    || { echo '错误: CI测试视图与本轮工作根不一致' >&2; exit 1; }\nelse\n  FLUTTER_ROOT=\"$(node \"$VIEW_SCRIPT\" view create \\\n    --source-root \"$CITIZENAPP_DIR\" --work-root \"$CITIZENAPP_TEST_WORK_DIR\")\"\nfi\n[[ \"$FLUTTER_ROOT\" == \"$CITIZENAPP_TEST_WORK_DIR/source-view/\"* \\\n  && -f \"$FLUTTER_ROOT/pubspec.yaml\" ]] \\\n  || { echo '错误: CitizenApp测试工程视图无效' >&2; exit 1; }\nexport CARGO_TARGET_DIR=\"${CARGO_TARGET_DIR:-$BUILD_CACHE/cargo-tests}\"\nexport PUB_CACHE=\"${PUB_CACHE:-$DEPENDENCY_CACHE/dart-pub}\"\nexport XDG_CONFIG_HOME=\"${XDG_CONFIG_HOME:-$DEPENDENCY_CACHE/flutter-config}\"\nexport TMPDIR=\"$BUILD_CACHE/tmp\"\nmkdir -p \"$TMPDIR\"\nexport DYLD_LIBRARY_PATH=\"$CARGO_TARGET_DIR/release:$CARGO_TARGET_DIR/debug\"\nexport LD_LIBRARY_PATH=\"$CARGO_TARGET_DIR/release:$CARGO_TARGET_DIR/debug\"\n\nif ! command -v \"$FLUTTER_BIN\" >/dev/null 2>&1; then\n  echo \"错误: 找不到 Flutter: $FLUTTER_BIN\" >&2\n  exit 1\nfi\n\n# Flutter 版本由产品开发环境或 CI 工作流唯一确定；测试脚本只消费调用方\n# 注入的可执行文件，不维护第二份工具版本表。\n\nif [ ! -f \"$FLUTTER_ROOT/.dart_tool/package_config.json\" ]; then\n  if [[ \"${CI:-}\" == true ]]; then\n    echo \"错误: 缺少 .dart_tool/package_config.json；CI必须先执行锁定依赖解析\" >&2\n    exit 1\n  fi\n  PUB_GET_ARGS=(--enforce-lockfile)\n  case \"${CITIZENAPP_OFFLINE:-false}\" in\n    true) PUB_GET_ARGS+=(--offline) ;;\n    false) ;;\n    *) echo '错误: CITIZENAPP_OFFLINE只接受true或false' >&2; exit 1 ;;\n  esac\n  (cd \"$FLUTTER_ROOT\" && \"$FLUTTER_BIN\" pub get \"${PUB_GET_ARGS[@]}\")\nfi\n\n# 设备 Release 构建会先 cargo clean；测试必须从宿主库构建开始一直持锁到最后一个\n# flutter_tester 退出，禁止其它进程在测试中途删除 dylib/so。macOS 用系统 shlock\n# 自动识别死亡 PID，Linux CI 用 util-linux flock，二者都不依赖仓库内状态文件。\nNATIVE_BUILD_LOCK_PATH=\"$CITIZENAPP_TEST_WORK_DIR/citizenapp-native-build.lock\"\nNATIVE_BUILD_LOCK_KIND=\"\"\nacquire_native_build_lock() {\n  case \"$(uname -s)\" in\n    Darwin)\n      while ! shlock -f \"$NATIVE_BUILD_LOCK_PATH\" -p $$; do\n        echo \"等待 CitizenApp 设备原生构建结束...\"\n        sleep 1\n      done\n      NATIVE_BUILD_LOCK_KIND=shlock\n      ;;\n    Linux)\n      exec 9>\"$NATIVE_BUILD_LOCK_PATH\"\n      flock 9\n      NATIVE_BUILD_LOCK_KIND=flock\n      ;;\n    *)\n      echo \"错误: 不支持的原生测试锁平台：$(uname -s)\" >&2\n      return 1\n      ;;\n  esac\n}\nrelease_native_build_lock() {\n  case \"$NATIVE_BUILD_LOCK_KIND\" in\n    shlock)\n      if [[ \"$(cat \"$NATIVE_BUILD_LOCK_PATH\" 2>/dev/null || true)\" == \"$$\" ]]; then\n        rm -f -- \"$NATIVE_BUILD_LOCK_PATH\"\n      fi\n      ;;\n    flock)\n      flock -u 9\n      exec 9>&-\n      ;;\n  esac\n  NATIVE_BUILD_LOCK_KIND=\"\"\n}\n\ncleanup_test_configs() {\n  if [[ \"$TEST_CONFIGS_STAGED\" == true ]]; then\n    rm -f -- \"$ANALYSIS_CONFIG\" \"$TEST_CONFIG\"\n  fi\n  release_native_build_lock\n}\n\ncd \"$FLUTTER_ROOT\"\n# Flutter只从工程根发现这两类配置；源码真源统一放在scripts，执行期间只在本次\n# 源码外工程视图短暂落盘，退出时必定清理。\nANALYSIS_CONFIG=\"$FLUTTER_ROOT/analysis_options.yaml\"\nTEST_CONFIG=\"$FLUTTER_ROOT/dart_test.yaml\"\ntrap cleanup_test_configs EXIT\nif [[ ! -e \"$ANALYSIS_CONFIG\" && ! -L \"$ANALYSIS_CONFIG\"\n  && ! -e \"$TEST_CONFIG\" && ! -L \"$TEST_CONFIG\" ]]; then\n  TEST_CONFIGS_STAGED=true\n  node \"$SCRIPT_DIR/build.mjs\" config analysis > \"$ANALYSIS_CONFIG\"\n  node \"$SCRIPT_DIR/build.mjs\" config test > \"$TEST_CONFIG\"\nelif [[ \"$FLUTTER_ROOT\" == \"$CITIZENAPP_DIR\" || ! -f \"$ANALYSIS_CONFIG\" || -L \"$ANALYSIS_CONFIG\"\n  || ! -f \"$TEST_CONFIG\" || -L \"$TEST_CONFIG\" ]]; then\n  echo '错误: Flutter 工程根存在不受CitizenApp测试入口管理的分析或测试配置' >&2\n  exit 1\nfi\n# CI Runner 保持原生构建锁；本机测试使用独立工作目录，不使用跨端共享锁。\nif [[ \"${CI:-}\" == true ]]; then\n  acquire_native_build_lock\nfi\n# 宿主库只从产品声明与锁定Git输入取得，不编译邻仓或旧聚合仓源码。\nDEPENDENCIES=\"$(node \"$VIEW_SCRIPT\" view dependencies \\\n  --source-root \"$CITIZENAPP_DIR\" --work-root \"$CITIZENAPP_TEST_WORK_DIR\")\"\nTATACHATSDK_ROOT=\"$(printf '%s' \"$DEPENDENCIES\" | node --input-type=module -e 'let text=\"\"; for await (const part of process.stdin) text+=part; const root=JSON.parse(text).tatachat_sdk?.root; if(typeof root!==\"string\") throw Error(\"聊天SDK源码回执缺失\"); process.stdout.write(root);')\"\nCITIZENSDK_ROOT=\"$(printf '%s' \"$DEPENDENCIES\" | node --input-type=module -e 'let text=\"\"; for await (const part of process.stdin) text+=part; const root=JSON.parse(text).citizen_sdk?.root; if(typeof root!==\"string\") throw Error(\"公民SDK源码回执缺失\"); process.stdout.write(root);')\"\nfor sdk_root in \"$TATACHATSDK_ROOT\" \"$CITIZENSDK_ROOT\"; do\n  [[ -x \"$sdk_root/scripts/build-native.sh\" && ! -L \"$sdk_root/scripts/build-native.sh\" ]] \\\n    || { echo '锁定SDK原生入口无效' >&2; exit 1; }\ndone\n\"$TATACHATSDK_ROOT/scripts/build-native.sh\" host\nexport CITIZENSDK_WORK_DIR=\"$BUILD_CACHE/citizensdk-host/work\"\nexport CITIZENSDK_NATIVE_OUTPUT_DIR=\"$BUILD_CACHE/citizensdk-host/output\"\n\"$CITIZENSDK_ROOT/scripts/build-native.sh\" abi-host\nCITIZENSDK_TEST_CORE_LIB_PATH=\"$(node \"$SCRIPT_DIR/build.mjs\" native core \"$CITIZENSDK_NATIVE_OUTPUT_DIR\")\"\nISAR_CORE_LIB_PATH=\"$(node \"$SCRIPT_DIR/build.mjs\" native isar \"$FLUTTER_ROOT/.dart_tool/package_config.json\" \"$PUB_CACHE\" \"$CITIZENAPP_DIR/pubspec.lock\")\"\nexport CITIZENSDK_TEST_CORE_LIB_PATH ISAR_CORE_LIB_PATH\n\"$FLUTTER_BIN\" analyze --no-pub\n\"$FLUTTER_BIN\" test --no-pub --concurrency=1 \"$@\"\n","ui-test":"#!/usr/bin/env bash\n# 对真机中已经安装的 CitizenApp Release 做长期黑盒 UI 验收。\n#\n# 安全边界：本脚本只构建和安装独立的 UITestHost/xctrunner，永远不构建、安装、卸载或\n# 清空 `ios.citizenapp`。测试前后会核对正式 App 的版本、bundle 容器、数据容器和全部 Isar\n# 数据库；既有数据库任一消失都拒绝把测试判为成功，正常运行新增数据库或扩大文件允许。\nset -euo pipefail\n\nSCRIPT_DIR=\"${CITIZENAPP_SCRIPTS_ROOT:?缺少源码脚本根}\"\nAPP_ROOT=\"${CITIZENAPP_SOURCE_ROOT:?缺少产品源码根}\"\nSCHEME=\"RunnerUITests\"\nTARGET_BUNDLE_ID=\"ios.citizenapp\"\nTEST_HOST_BUNDLE_ID=\"ios.citizenapp.UITestHost\"\nTEST_RUNNER_BUNDLE_ID=\"ios.citizenapp.UITests.xctrunner\"\nBUILD_ROOT=\"${CITIZENAPP_UI_TEST_WORK_DIR:-$APP_ROOT/target/test/ui}\"\nPROJECT_INPUT=\"$APP_ROOT/ios/project/Runner.pbxproj\"\nDERIVED_DATA=\"$BUILD_ROOT/DerivedData\"\nTEST_ONLY=\"${CITIZENAPP_UI_TEST_ONLY:-}\"\nif [[ -n \"$TEST_ONLY\" && ! \"$TEST_ONLY\" =~ ^testChatE2E(ReadIdentity|Send|VerifyRestart)$ ]]; then\n  echo 'CITIZENAPP_UI_TEST_ONLY 只能选择已登记的双机 XCTest' >&2\n  exit 1\nfi\nRESULT_BUNDLE=\"$BUILD_ROOT/RunnerUITests-${TEST_ONLY:-all}-$(date +%s)-$$.xcresult\"\n\npython3 - \"$APP_ROOT\" \"$BUILD_ROOT\" <<'CHECK_OUTPUTS'\nfrom pathlib import Path\nimport sys\nsource, raw = map(Path, sys.argv[1:])\nsource, target = source.resolve(), raw.resolve()\nif not raw.is_absolute() or source / 'target' not in target.parents:\n    raise SystemExit('CITIZENAPP_UI_TEST_WORK_DIR必须是CitizenApp本仓target内绝对路径')\nCHECK_OUTPUTS\n\n[[ -f \"$PROJECT_INPUT\" && ! -L \"$PROJECT_INPUT\" ]] || {\n  echo \"CitizenApp iOS 工程不存在：$PROJECT_INPUT\" >&2; exit 1\n}\nmkdir -p \"$BUILD_ROOT\"\n# XCTest 通过同一源码外视图消费扁平 scheme，正式 App 本体不参与构建。\nBUILD_ROOT=\"$(cd \"$BUILD_ROOT\" && pwd -P)\"\nPROJECT_ROOT=\"$(node \"$SCRIPT_DIR/build.mjs\" view create --source-root \"$APP_ROOT\" --work-root \"$BUILD_ROOT\")\"\nPROJECT=\"$PROJECT_ROOT/ios/Runner.xcodeproj\"\nexport TMPDIR=\"$BUILD_ROOT/\"\n\ndevice_fields=\"$(python3 - <<'SELECT_DEVICE'\nimport json\nimport subprocess\nimport time\n\nDEVICECTL = [\"/usr/bin/xcrun\", \"devicectl\"]\nATTEMPTS = 8\n\n\ndef developer_mode_enabled(value):\n    if value == \"enabled\":\n        return True\n    if not isinstance(value, dict):\n        return False\n    enabled = value.get(\"enabled\")\n    return isinstance(enabled, dict) and enabled.get(\"mode\") == 1\n\n\ndef command_json(arguments, timeout):\n    try:\n        result = subprocess.run(\n            DEVICECTL + arguments + [\"--quiet\", \"--json-output\", \"-\"],\n            stdout=subprocess.PIPE,\n            stderr=subprocess.DEVNULL,\n            text=True,\n            timeout=timeout,\n            check=False,\n        )\n        if result.returncode != 0:\n            return None\n        value = json.loads(result.stdout)\n        if value.get(\"info\", {}).get(\"outcome\") != \"success\":\n            return None\n        return value\n    except (json.JSONDecodeError, subprocess.TimeoutExpired):\n        return None\n\n\nfor attempt in range(ATTEMPTS):\n    listing = command_json([\"list\", \"devices\"], timeout=15)\n    candidates = []\n    if listing is not None:\n        for item in listing.get(\"result\", {}).get(\"devices\", []):\n            props = item.get(\"properties\", {})\n            hardware = props.get(\"hardware\", {})\n            connection = props.get(\"connection\", {})\n            state = props.get(\"state\", {})\n            identifier = item.get(\"identifier\")\n            udid = hardware.get(\"udid\")\n            if (\n                identifier\n                and udid\n                and hardware.get(\"platform\") == \"iOS\"\n                and hardware.get(\"reality\") == \"physical\"\n                and connection.get(\"pairingState\") == \"paired\"\n                and developer_mode_enabled(state.get(\"developerModeStatus\"))\n            ):\n                candidates.append((identifier, udid))\n\n    reachable = []\n    for identifier, udid in candidates:\n        details = command_json(\n            [\"device\", \"info\", \"details\", \"--device\", identifier],\n            timeout=20,\n        )\n        if details is None:\n            continue\n        result = details.get(\"result\", {})\n        props = result.get(\"properties\", {})\n        hardware = props.get(\"hardware\", {})\n        connection = props.get(\"connection\", {})\n        state = props.get(\"state\", {})\n        if (\n            result.get(\"identifier\") == identifier\n            and hardware.get(\"udid\") == udid\n            and hardware.get(\"platform\") == \"iOS\"\n            and hardware.get(\"reality\") == \"physical\"\n            and connection.get(\"pairingState\") == \"paired\"\n            and state.get(\"bootState\") == \"booted\"\n            and developer_mode_enabled(state.get(\"developerModeStatus\"))\n        ):\n            reachable.append((identifier, udid))\n\n    if len(reachable) > 1:\n        raise SystemExit(\"必须且只能主动探测到一台可用物理 iPhone，当前多于一台\")\n    if len(reachable) == 1:\n        print(reachable[0][0])\n        print(reachable[0][1])\n        break\n    if attempt + 1 < ATTEMPTS:\n        time.sleep(2)\nelse:\n    raise SystemExit(\"主动探测未发现可用物理 iPhone（已配对、开发者模式开启且可读取设备详情）\")\nSELECT_DEVICE\n)\"\nCORE_DEVICE_ID=\"$(sed -n '1p' <<<\"$device_fields\")\"\nHARDWARE_UDID=\"$(sed -n '2p' <<<\"$device_fields\")\"\n[[ -n \"$CORE_DEVICE_ID\" && -n \"$HARDWARE_UDID\" ]] || {\n  echo \"无法解析 iPhone 标识，拒绝测试\" >&2\n  exit 1\n}\n\ninstalled_app_snapshot() {\n  xcrun devicectl device info apps --quiet \\\n    --device \"$CORE_DEVICE_ID\" \\\n    --bundle-id \"$TARGET_BUNDLE_ID\" \\\n    --include-container-paths \\\n    --json-output - |\n    python3 -c '\nimport json, sys\nbundle_id = sys.argv[1]\napps = json.load(sys.stdin).get(\"result\", {}).get(\"apps\", [])\nif len(apps) != 1:\n    raise SystemExit(f\"设备中必须且只能有一个 {bundle_id}，当前：{len(apps)}\")\napp = apps[0]\nif app.get(\"bundleIdentifier\") != bundle_id:\n    raise SystemExit(\"设备返回的 CitizenApp Bundle ID 不一致\")\nfields = {\n    \"bundleIdentifier\": app.get(\"bundleIdentifier\"),\n    \"version\": app.get(\"version\"),\n    \"shortVersion\": app.get(\"shortVersion\"),\n    \"bundleContainerPath\": app.get(\"bundleContainerPath\"),\n    \"dataContainerPath\": app.get(\"dataContainerPath\"),\n}\nif not fields[\"bundleContainerPath\"] or not fields[\"dataContainerPath\"]:\n    raise SystemExit(\"无法读取 CitizenApp 的 bundle/data 容器，拒绝测试\")\nprint(json.dumps(fields, ensure_ascii=False, sort_keys=True, separators=(\",\", \":\")))\n' \"$TARGET_BUNDLE_ID\"\n}\n\ndatabase_snapshot() {\n  xcrun devicectl device info files --quiet \\\n    --device \"$CORE_DEVICE_ID\" \\\n    --domain-type appDataContainer \\\n    --domain-identifier \"$TARGET_BUNDLE_ID\" \\\n    --subdirectory 'Library/Application Support' \\\n    --recurse \\\n    --json-output - |\n    python3 -c '\nimport json, sys\nfiles = json.load(sys.stdin).get(\"result\", {}).get(\"files\", [])\nsnapshot = {}\nfor item in files:\n    relative = item.get(\"relativePath\")\n    if not isinstance(relative, str) or not relative.endswith(\".isar\"):\n        continue\n    resources = item.get(\"resources\", {})\n    size = item.get(\"metadata\", {}).get(\"size\", 0)\n    if (\n        relative in snapshot\n        or resources.get(\"isDirectory\") is not False\n        or resources.get(\"isSymbolicLink\") is not False\n        or resources.get(\"isReadable\") is not True\n        or not isinstance(size, int)\n        or size <= 0\n    ):\n        raise SystemExit(\"CitizenApp Isar 数据库路径、类型或大小无效\")\n    snapshot[relative] = size\nprint(json.dumps(snapshot, ensure_ascii=False, sort_keys=True, separators=(\",\", \":\")))\n'\n}\n\nis_installed() {\n  xcrun devicectl device info apps --quiet \\\n    --device \"$CORE_DEVICE_ID\" --bundle-id \"$1\" --json-output - 2>/dev/null |\n    python3 -c 'import json, sys; print(\"yes\" if json.load(sys.stdin).get(\"result\", {}).get(\"apps\", []) else \"no\")' \\\n    2>/dev/null\n}\n\ncleanup_test_apps() {\n  local bundle_id\n  for bundle_id in \"$TEST_RUNNER_BUNDLE_ID\" \"$TEST_HOST_BUNDLE_ID\"; do\n    if [[ \"$(is_installed \"$bundle_id\" || true)\" == yes ]]; then\n      echo \"[清理] 仅删除隔离测试组件：$bundle_id\"\n      xcrun devicectl device uninstall app --quiet --device \"$CORE_DEVICE_ID\" \"$bundle_id\" || true\n    fi\n  done\n  # 仅卸载本脚本创建的设备测试组件；不触碰正式CitizenApp与其它工作目录。\n}\ntrap cleanup_test_apps EXIT\n\necho \"[设备] 已主动探测唯一物理 iPhone\"\nbefore_snapshot=\"$(installed_app_snapshot)\"\nbefore_databases=\"$(database_snapshot)\"\nbefore_database_count=\"$(python3 -c 'import json,sys; print(len(json.loads(sys.argv[1])))' \"$before_databases\")\"\necho \"[保护] 已确认现有 ${TARGET_BUNDLE_ID}，Isar数据库=${before_database_count}个\"\n\n# iPhone 镜像与 XCTest 都要独占设备图形会话；自动测试期间只关闭镜像窗口，不改变配对。\nosascript -e 'tell application \"iPhone Mirroring\" to quit' >/dev/null 2>&1 || true\n\ndestination=\"platform=iOS,id=$HARDWARE_UDID\"\necho \"[构建] Release 隔离 UI Test Host（不含 CitizenApp target）\"\nxcodebuild build-for-testing \\\n  -project \"$PROJECT\" \\\n  -scheme \"$SCHEME\" \\\n  -configuration Release \\\n  -destination \"$destination\" \\\n  -derivedDataPath \"$DERIVED_DATA\"\n\n# 构建后、执行前审计所有 App 产物。只要混入正式 Bundle ID，就在任何安装发生前停止。\nwhile IFS= read -r plist; do\n  product_bundle_id=\"$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \"$plist\" 2>/dev/null || true)\"\n  [[ \"$product_bundle_id\" != \"$TARGET_BUNDLE_ID\" ]] || {\n    echo \"UI 测试产物错误包含正式 CitizenApp，已在安装前停止：$plist\" >&2\n    exit 1\n  }\ndone < <(find \"$DERIVED_DATA/Build/Products\" -path '*.app/Info.plist' -type f -print)\n\necho \"[测试] 启动设备中现有 CitizenApp Release\"\nset +e\nif [[ -n \"$TEST_ONLY\" ]]; then\n  xcodebuild test-without-building \\\n    -project \"$PROJECT\" \\\n    -scheme \"$SCHEME\" \\\n    -configuration Release \\\n    -destination \"$destination\" \\\n    -derivedDataPath \"$DERIVED_DATA\" \\\n    -only-testing:\"$SCHEME/$SCHEME/$TEST_ONLY\" \\\n    -resultBundlePath \"$RESULT_BUNDLE\"\nelse\n  xcodebuild test-without-building \\\n    -project \"$PROJECT\" \\\n    -scheme \"$SCHEME\" \\\n    -configuration Release \\\n    -destination \"$destination\" \\\n    -derivedDataPath \"$DERIVED_DATA\" \\\n    -resultBundlePath \"$RESULT_BUNDLE\"\nfi\ntest_status=$?\nset -e\n\nafter_snapshot=\"$(installed_app_snapshot)\"\nafter_databases=\"$(database_snapshot)\"\n[[ \"$after_snapshot\" == \"$before_snapshot\" ]] || {\n  echo \"CitizenApp 安装信息或数据容器在 UI 测试后发生变化，拒绝通过\" >&2\n  exit 1\n}\ndatabase_counts=\"$(python3 - \"$before_databases\" \"$after_databases\" <<'CHECK_DATABASES'\nimport json\nimport sys\n\nbefore = json.loads(sys.argv[1])\nafter = json.loads(sys.argv[2])\nmissing = sorted(set(before) - set(after))\nif missing:\n    raise SystemExit(f\"CitizenApp UI测试删除了既有Isar数据库，数量：{len(missing)}\")\nprint(f\"{len(before)} → {len(after)}\")\nCHECK_DATABASES\n)\"\necho \"[保护] CitizenApp容器未变化，既有Isar数据库仍全部存在：${database_counts}个\"\n\nif [[ \"$test_status\" -ne 0 ]]; then\n  echo \"UI 测试失败；结果保存在：$RESULT_BUNDLE\" >&2\n  exit \"$test_status\"\nfi\necho \"[完成] CitizenApp iOS Release 真机 UI 测试通过\"\n","chat-test":"#!/usr/bin/env bash\n# 已安装的两台公民 App 真机黑盒验收：iPhone XCTest + Pixel ADB UI。\n# 不构建、不安装、不清空 App；身份及目标联系人不唯一时不发送。\nset -euo pipefail\n\nSCRIPT_DIR=\"${CITIZENAPP_SCRIPTS_ROOT:?缺少源码脚本根}\"\nAPP_ROOT=\"${CITIZENAPP_SOURCE_ROOT:?缺少产品源码根}\"\nIOS_TEST=\"$SCRIPT_DIR/build.mjs\"\nexport CITIZENAPP_UI_TEST_WORK_DIR=\"${CITIZENAPP_UI_TEST_WORK_DIR:-$APP_ROOT/target/test/chat-e2e}\"\n\npython3 - \"$IOS_TEST\" \"${CITIZENAPP_NODE_BIN:?缺少产品Node入口}\" <<'PY'\nimport os\nimport re\nimport subprocess\nimport sys\nimport time\nimport xml.etree.ElementTree as ET\n\nIOS_TEST = sys.argv[1]\nNODE_BIN = sys.argv[2]\nPACKAGE = 'com.crcfrcn.citizenapp'\nCID_PATTERN = re.compile(r'CN[0-9]{3}-CTZN[0-9]-[0-9]{9}-[0-9]{4}')\nMARKER = 'CITIZEN_E2E_%010d_%06d' % (int(time.time()), os.getpid() % 1000000)\n\n\ndef command(args, *, timeout=30, input_text=None):\n    result = subprocess.run(args, input=input_text, text=True, capture_output=True,\n                            timeout=timeout, check=False)\n    if result.returncode != 0:\n        raise RuntimeError('%s 失败：%s' % (args[0], result.stderr[-500:]))\n    return result.stdout\n\n\ndef ios(stage, *, peer=None):\n    env = os.environ.copy()\n    env['CITIZENAPP_UI_TEST_ONLY'] = stage\n    if peer is not None:\n        env['TEST_RUNNER_CHAT_E2E_PEER_CID'] = peer\n        env['TEST_RUNNER_CHAT_E2E_MARKER'] = MARKER\n    result = subprocess.run([NODE_BIN, IOS_TEST, \"ui-test\"], env=env, text=True, capture_output=True,\n                            timeout=1800, check=False)\n    if result.returncode != 0:\n        # 仅输出测试阶段与尾部诊断，避免把设备 UI 快照写入控制台。\n        lines = [line for line in (result.stdout + '\\n' + result.stderr).splitlines()\n                 if re.search(r'failed|error|cancel|认证|UI 测试失败', line, re.I)]\n        diagnostic = '\\n'.join(lines[-8:])\n        diagnostic = CID_PATTERN.sub('[公民号已隐藏]', diagnostic)\n        raise RuntimeError('iPhone XCTest %s 失败：%s' % (stage, diagnostic))\n    return result.stdout\n\n\ndef android_nodes():\n    for attempt in range(3):\n        try:\n            raw = command(['adb', 'exec-out', 'uiautomator', 'dump', '/dev/tty'], timeout=25)\n            break\n        except RuntimeError as error:\n            if 'no devices/emulators found' not in str(error) or attempt == 2:\n                raise\n            time.sleep(2)\n    start = raw.find('<?xml')\n    end = raw.rfind('</hierarchy>')\n    if start < 0 or end < 0:\n        raise RuntimeError('Pixel 无法读取当前界面层级')\n    root = ET.fromstring(raw[start:end + len('</hierarchy>')])\n    return list(root.iter('node'))\n\n\ndef node_label(node):\n    return (node.get('text') or '') + ' ' + (node.get('content-desc') or '')\n\n\ndef matching(text, *, exact=False):\n    return [node for node in android_nodes() if\n            (node_label(node).strip() == text if exact else text in node_label(node))]\n\n\ndef await_nodes(text, *, exact=False, timeout=60):\n    deadline = time.monotonic() + timeout\n    while time.monotonic() < deadline:\n        found = matching(text, exact=exact)\n        if found:\n            return found\n        time.sleep(2)\n    raise RuntimeError('Pixel 等待界面元素超时：%s' % text)\n\n\ndef tap_node(node):\n    match = re.fullmatch(r'\\[(\\d+),(\\d+)\\]\\[(\\d+),(\\d+)\\]', node.get('bounds', ''))\n    if not match:\n        raise RuntimeError('Pixel 界面目标没有有效边界')\n    left, top, right, bottom = map(int, match.groups())\n    if right <= left or bottom <= top:\n        raise RuntimeError('Pixel 界面目标边界无效')\n    command(['adb', 'shell', 'input', 'tap', str((left + right) // 2),\n             str((top + bottom) // 2)])\n\n\ndef tap_unique(text, *, exact=False, timeout=30):\n    found = await_nodes(text, exact=exact, timeout=timeout)\n    if len(found) != 1:\n        raise RuntimeError('Pixel 界面目标不唯一：%s' % text)\n    tap_node(found[0])\n\n\ndef start_android():\n    command(['adb', 'shell', 'am', 'force-stop', PACKAGE])\n    command(['adb', 'shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity'])\n    await_nodes('聊天', timeout=45)\n\n\ndef android_identity():\n    start_android()\n    tap_unique('我的')\n    tap_unique('注册与查看')\n    await_nodes('公民号', timeout=30)\n    values = sorted(set(match.group(0) for node in android_nodes()\n                        for match in CID_PATTERN.finditer(node_label(node))))\n    if len(values) != 1:\n        raise RuntimeError('Pixel 本机公民号无法唯一读取')\n    command(['adb', 'shell', 'input', 'keyevent', '4'])\n    return values[0]\n\n\ndef open_android_peer(peer):\n    tap_unique('聊天')\n    tap_unique('新建')\n    tap_unique('发私信', exact=True)\n    await_nodes('选择联系人', timeout=30)\n    tap_unique('公民号：' + peer, exact=True, timeout=30)\n    await_nodes('输入消息', timeout=30)\n\n\ndef android_send_text(value):\n    if not re.fullmatch(r'[A-Z0-9_]+', value):\n        raise RuntimeError('Pixel 测试文字必须是无空格 ASCII 标记')\n    tap_unique('输入消息')\n    command(['adb', 'shell', 'input', 'text', value])\n    command(['adb', 'shell', 'input', 'keyevent', '66'])\n    await_nodes(value, exact=True, timeout=25)\n\n\ndef android_send_sticker():\n    tap_unique('表情和贴纸')\n    tap_unique('贴纸', exact=True)\n    nodes = android_nodes()\n    tabs = [node for node in nodes if node.get('text') == '贴纸']\n    if len(tabs) != 1:\n        raise RuntimeError('Pixel 贴纸面板未打开')\n    # SDK 固定五列网格；点击第一枚贴纸，不依赖图像资产的本地化名称。\n    bounds = re.fullmatch(r'\\[(\\d+),(\\d+)\\]\\[(\\d+),(\\d+)\\]', tabs[0].get('bounds', ''))\n    if not bounds:\n        raise RuntimeError('Pixel 贴纸面板边界无效')\n    left, _, right, bottom = map(int, bounds.groups())\n    command(['adb', 'shell', 'input', 'tap', str(left + max(24, (right-left)//10)),\n             str(bottom + 42)])\n    await_nodes('[贴纸]', timeout=30)\n\n\ndef verify_android_after_restart():\n    start_android()\n    open_android_peer(iphone_cid)\n    for value in [MARKER, 'PIXEL_' + MARKER, 'AFTER_RESTART_' + MARKER]:\n        matches = await_nodes(value, exact=True, timeout=60)\n        if len(matches) != 1:\n            raise RuntimeError('Pixel 重启后消息重复或缺失')\n\n\ndevices = command(['adb', 'devices', '-l'])\nif len(re.findall(r'^\\S+\\s+device\\b', devices, re.MULTILINE)) != 1 or 'Pixel_8a' not in devices:\n    raise RuntimeError('必须且只能连接一台 Pixel 8a')\n\niphone_output = ios('testChatE2EReadIdentity')\ncid_matches = re.findall(r'CHAT_E2E_IPHONE_CID=(CN[0-9]{3}-CTZN[0-9]-[0-9]{9}-[0-9]{4})', iphone_output)\nif len(cid_matches) != 1:\n    raise RuntimeError('iPhone XCTest 没有唯一返回本机公民号')\niphone_cid = cid_matches[0]\npixel_cid = android_identity()\nif iphone_cid == pixel_cid:\n    raise RuntimeError('双机必须是不同公民号')\nprint('[身份] 两台不同公民号已由界面读取；不输出实际号码', flush=True)\n\n# 双向通讯录必须各自准确包含对方。匹配失败时不得发送消息。\nopen_android_peer(iphone_cid)\nprint('[前置] Pixel 已打开准确对端私聊', flush=True)\nios('testChatE2ESend', peer=pixel_cid)\nprint('[发送] iPhone 文字与 emoji 已进入真实会话', flush=True)\nawait_nodes(MARKER, exact=True, timeout=90)\nawait_nodes('😀' + MARKER, exact=True, timeout=90)\nandroid_send_text('PIXEL_' + MARKER)\nandroid_send_sticker()\nprint('[回信] Pixel 文字与贴纸已提交', flush=True)\nios('testChatE2EVerifyRestart', peer=pixel_cid)\nverify_android_after_restart()\nprint('[完成] 双机收发、重启与去重全部通过', flush=True)\nPY\n"});
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
async function runCLI(){
 const [operation,,flag,work]=process.argv.slice(2);
 if(['execute','resources','prepare','build'].includes(operation)&&flag==='--work'){
  checkWork(work);
  return withFixedWork(taskScope(work),()=>runCommand(),{environment:process.env,retain:process.env.PRODUCT_HOST_FD==='3'||process.env.PRODUCT_RESOURCE_FD==='4'});
 }
 return runCommand();
}
async function runCommand(){
 if(await runHelper(process.argv.slice(2)))return;
 const [command,platform,option,work,...extra]=process.argv.slice(2);
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
 checkWork(work);
 if(command==='requirements')process.stdout.write(JSON.stringify(requirements(platform,work))+'\n');
 else{
  const cancellation=new AbortController();for(const name of ['SIGTERM','SIGINT'])process.once(name,()=>cancellation.abort());
  let input='';for await(const chunk of process.stdin){input+=chunk;if(Buffer.byteLength(input)>2*1024*1024)fail('公开输入超限');}
  const request=input?JSON.parse(input):{},options={environment:process.env,signal:cancellation.signal,offline:extra.includes('--offline')};
  let result;
  if(command==='execute'){
   const {bootstrapNode}=await import('./resources.mjs');const node=await bootstrapNode(work,options);
   if(realpathSync(process.execPath)!==realpathSync(node.path)){
    const environment=Object.fromEntries(['HOME','USER','LOGNAME','LANG','LC_ALL','PRODUCT_TOOL_ROOT','PRODUCT_DEPENDENCY_ROOT','PRODUCT_HOST_FD','PRODUCT_WORK_LEASE'].filter(k=>typeof process.env[k]==='string').map(k=>[k,process.env[k]]));
    result=JSON.parse((await runBuildProcess(node.path,[fileURLToPath(import.meta.url),command,platform,option,work,...extra],workEnvironment(environment),root,{capture:true,streamError:true,input:JSON.stringify(request),signal:cancellation.signal,passHost:environment.PRODUCT_HOST_FD==='3'})).stdout);
   }else result=await execute(platform,work,request,options);
  }else if(command==='resources')result=await (await import('./resources.mjs')).resources(platform,work,request,options);
  else result=await executions.run({signal:cancellation.signal},()=>command==='prepare'?prepare(platform,work,request,process.env):build(platform,work,request,process.env));
  process.stdout.write(JSON.stringify(result)+'\n');
 }
}
}

// CLI拒绝必须真实失败，不能留成未完成顶层await或输出成功回执。
if(!inlineTestEntry&&directEntry){
 void runCLI().catch(error=>{console.error(error);process.exitCode=1;});
}

let fixtureWork,removeFixture,writeFixture,copyFixture;
if(inlineTestEntry){
 const {default:fs}=await import('node:fs');
 const {finishFixedWork}=await import('./target.mjs');
fixtureWork=function(){const work=checkFixedWork(fixedWork('build'),{create:true});finishFixedWork(work);return work;}
removeFixture=function(path,options={}){if(path===fixedWork('build')||path===fixedWork('test')){if(fs.existsSync(path))clearFixedWork(path);return;}fs.rmSync(path,options);}

writeFixture=function(path,data,options){
 fs.writeFileSync(path,data,options);
 if(String(path).endsWith('/scripts/build.mjs')&&String(data).includes("from './target.mjs'")){
  for(const name of ['target.mjs'])fs.copyFileSync(join(import.meta.dirname,name),join(dirname(path),name));
 }
}

copyFixture=function(source,destination,...options){
 fs.copyFileSync(source,destination,...options);
 if(String(destination).endsWith('/scripts/build.mjs'))for(const name of ['target.mjs'])fs.copyFileSync(join(import.meta.dirname,name),join(dirname(destination),name));
}

}
const inlineTestOwner = {contract,checkWork,productTarget,prepareTargetRoot,temporaryRoot,testRoot,remoteEnvironment,resourceSourceRoot,clearWork,platformContract,lockedSources,requirements,resourceEnvironment,createView,prepare,build,IOS_VERIFIER_SOURCE,readStoreSource,iosStoreBundleID,androidStorePackageName,storeIdentity,androidPackageName,androidUSBSerials,androidInstalledPath,androidCertificate,parseAndroidSigning,iosDeviceCandidates,iosInstalled,iosVersion,runBuildProcess,outputDigest,execute,checkBuildResult,PLATFORM_INPUTS,materializePlatformInputs,ANALYSIS_OPTIONS_SOURCE,DART_TEST_SOURCE,LOGO_ASSETS_SOURCE,TEST_INPUTS_SOURCE,SOURCE_VIEW_SOURCE,BUILD_SHELL_SOURCES,resolveFirstPartyDependencies,copyHostInput,citizenCorePath,isarCorePath,JsonRpc};

// 同文件回归：普通导入和正式命令不注册测试。
if(inlineTestEntry){
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
  if(apple&&existsSync(join(base,apple,'Podfile'))&&!existsSync(join(base,apple,'Podfile.lock'))){
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


// 真实命令行只读自身入口；清除私有环境与工具搜索路径，不能从控制台补齐执行条件。
test('独立命令行从自身声明输出JSON，未知平台失败且不写工作根',async()=>{
 const work=sandbox();try{
  for(const platform of Object.keys(contract.platforms)){
   const before=readdirSync(work),result=spawnSync(process.execPath,[join(root,'scripts/build.mjs'),'requirements',platform,'--work',work],{env:{HOME:work,LANG:'C',LC_ALL:'C'},encoding:'utf8'});
   const apple=platform.endsWith('ios')?'ios':platform.endsWith('macos')?'macos':null;
   if(apple&&existsSync(join(base,apple,'Podfile'))&&!existsSync(join(base,apple,'Podfile.lock'))){assert.notEqual(result.status,0);assert.match(result.stderr,/CocoaPods原始锁缺失/);}
   else{assert.equal(result.status,0,result.stderr);const value=JSON.parse(result.stdout);assert.equal(value.product_id,contract.product_id);assert.equal(value.platform,platform);}
   assert.deepEqual(readdirSync(work),before);
  }
  const invalid=spawnSync(process.execPath,[join(root,'scripts/build.mjs'),'requirements','unknown','--work',work],{env:{HOME:work},encoding:'utf8'});
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
  assert.deepEqual(readdirSync(work),[], '独立执行结束必须彻底清空现场');
  result.files=[]; calls.length=0;
  assert.deepEqual(await execute(platform,work,{run_id:'123456789'},{stages}),result);
  assert.deepEqual(readdirSync(work),[], '下一轮结束仍须清空现场');
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

// 原控制台profile/entitlement用例迁到产品Swift验真器；最终统一验收交付已验真的Xcode环境。
const iosContractFixture=[
 "import XCTest",
 "final class ProductIOSContractTests: XCTestCase {",
 "    @objc func testProductIOSReleaseSettingsRequireUniqueRunnerAndRelease() throws {",
 "        // 工程级设置允许被唯一 Runner Release 覆盖；Debug 或其它目标不能成为签名配置来源。",
 "        let objects: [String: [String: Any]] = [",
 "            \"project\": [\"targets\": [\"runner\"], \"buildConfigurationList\": \"project-list\"],",
 "            \"runner\": [\"name\": \"Runner\", \"productType\": \"com.apple.product-type.application\", \"buildConfigurationList\": \"runner-list\"],",
 "            \"project-list\": [\"buildConfigurations\": [\"project-release\"]],",
 "            \"runner-list\": [\"buildConfigurations\": [\"runner-debug\", \"runner-release\"]],",
 "            \"project-release\": [\"name\": \"Release\", \"buildSettings\": [\"DEVELOPMENT_TEAM\": \"PROJECT001\", \"SDKROOT\": \"iphoneos\"]],",
 "            \"runner-release\": [\"name\": \"Release\", \"buildSettings\": [\"DEVELOPMENT_TEAM\": \"RUNNER0001\", \"PRODUCT_BUNDLE_IDENTIFIER\": \"com.example.local\"]],",
 "            \"runner-debug\": [\"name\": \"Debug\", \"buildSettings\": [\"DEVELOPMENT_TEAM\": \"DEBUG00001\"]],",
 "        ]",
 "        let values = try ProductIOSContract.iosReleaseSettings([\"rootObject\": \"project\", \"objects\": objects])",
 "        XCTAssertEqual(values[\"DEVELOPMENT_TEAM\"] as? String, \"RUNNER0001\")",
 "        XCTAssertEqual(values[\"PRODUCT_BUNDLE_IDENTIFIER\"] as? String, \"com.example.local\")",
 "        XCTAssertEqual(values[\"SDKROOT\"] as? String, \"iphoneos\")",
 "        var missingRunner = objects",
 "        missingRunner[\"project\"]?[\"targets\"] = [String]()",
 "        XCTAssertThrowsError(try ProductIOSContract.iosReleaseSettings([\"rootObject\": \"project\", \"objects\": missingRunner]))",
 "        for list in [\"project-list\", \"runner-list\"] {",
 "            var missingRelease = objects",
 "            missingRelease[list]?[\"buildConfigurations\"] = [String]()",
 "            XCTAssertThrowsError(try ProductIOSContract.iosReleaseSettings([\"rootObject\": \"project\", \"objects\": missingRelease]))",
 "            var duplicateRelease = objects",
 "            duplicateRelease[\"extra-release\"] = [\"name\": \"Release\", \"buildSettings\": [:] as [String: Any]]",
 "            duplicateRelease[list]?[\"buildConfigurations\"] = [list == \"project-list\" ? \"project-release\" : \"runner-release\", \"extra-release\"]",
 "            XCTAssertThrowsError(try ProductIOSContract.iosReleaseSettings([\"rootObject\": \"project\", \"objects\": duplicateRelease]))",
 "        }",
 "        var duplicateRunner = objects",
 "        duplicateRunner[\"runner-two\"] = objects[\"runner\"]",
 "        duplicateRunner[\"project\"]?[\"targets\"] = [\"runner\", \"runner-two\"]",
 "        XCTAssertThrowsError(try ProductIOSContract.iosReleaseSettings([\"rootObject\": \"project\", \"objects\": duplicateRunner]))",
 "    }",
 "",
 "    private func localIOSProfile() -> [String: Any] {",
 "        [\"TeamIdentifier\": [\"TEAMTEST01\"], \"ApplicationIdentifierPrefix\": [\"TEAMTEST01\"],",
 "         \"CreationDate\": Date(timeIntervalSince1970: 1), \"ExpirationDate\": Date(timeIntervalSince1970: 1000),",
 "         \"Platform\": [\"iOS\"], \"ProvisionedDevices\": [\"device-one\"],",
 "         \"Entitlements\": [\"application-identifier\": \"TEAMTEST01.com.example.*\",",
 "             \"com.apple.developer.team-identifier\": \"TEAMTEST01\", \"get-task-allow\": true,",
 "             \"keychain-access-groups\": [\"TEAMTEST01.*\"], \"aps-environment\": \"development\"]]",
 "    }",
 "",
 "    @objc func testProductIOSProfileOnlyGrantsRequestedCapabilities() throws {",
 "        let values = try ProductIOSContract.iosEntitlements(profile: localIOSProfile(), team: \"TEAMTEST01\",",
 "            bundleID: \"com.example.local\", device: \"device-one\", requested: [:], now: Date(timeIntervalSince1970: 100))",
 "        XCTAssertNil(values[\"aps-environment\"])",
 "        XCTAssertEqual(values[\"application-identifier\"] as? String, \"TEAMTEST01.com.example.local\")",
 "        XCTAssertEqual(values[\"get-task-allow\"] as? Bool, true)",
 "        XCTAssertNil(values[\"keychain-access-groups\"])",
 "        let requested: [String: Any] = [",
 "            \"keychain-access-groups\": [\"$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)\"],",
 "            \"aps-environment\": \"$(APS_ENVIRONMENT)\"]",
 "        let requestedValues = try ProductIOSContract.iosEntitlements(profile: localIOSProfile(), team: \"TEAMTEST01\",",
 "            bundleID: \"com.example.local\", device: \"device-one\", requested: requested, now: Date(timeIntervalSince1970: 100))",
 "        XCTAssertEqual(requestedValues[\"keychain-access-groups\"] as? [String], [\"TEAMTEST01.com.example.local\"])",
 "        XCTAssertEqual(requestedValues[\"aps-environment\"] as? String, \"development\")",
 "        var distribution = localIOSProfile()",
 "        var distributionEntitlements = try XCTUnwrap(distribution[\"Entitlements\"] as? [String: Any])",
 "        distributionEntitlements[\"get-task-allow\"] = false",
 "        distribution[\"Entitlements\"] = distributionEntitlements",
 "        let distributionValues = try ProductIOSContract.iosEntitlements(profile: distribution, team: \"TEAMTEST01\",",
 "            bundleID: \"com.example.local\", device: \"device-one\", requested: [:], now: Date(timeIntervalSince1970: 100))",
 "        XCTAssertEqual(distributionValues[\"get-task-allow\"] as? Bool, false)",
 "    }",
 "",
 "    @objc func testProductIOSSignedEntitlementsAcceptOnlyExactSecurityFrameworkAliases() {",
 "        let expected: [String: Any] = [\"application-identifier\": \"TEAMTEST01.com.example.local\",",
 "            \"aps-environment\": \"development\",",
 "            \"com.apple.developer.team-identifier\": \"TEAMTEST01\", \"get-task-allow\": false]",
 "        var actual = expected",
 "        actual[\"com.apple.application-identifier\"] = \"TEAMTEST01.com.example.local\"",
 "        actual[\"com.apple.developer.aps-environment\"] = \"development\"",
 "        XCTAssertTrue(ProductIOSContract.iosSignedEntitlementsMatch(actual, expected: expected))",
 "        actual[\"com.apple.application-identifier\"] = \"TEAMTEST01.com.other\"",
 "        XCTAssertFalse(ProductIOSContract.iosSignedEntitlementsMatch(actual, expected: expected))",
 "        actual = expected",
 "        actual[\"com.apple.developer.aps-environment\"] = \"production\"",
 "        XCTAssertFalse(ProductIOSContract.iosSignedEntitlementsMatch(actual, expected: expected))",
 "        actual = expected",
 "        actual[\"unexpected-capability\"] = true",
 "        XCTAssertFalse(ProductIOSContract.iosSignedEntitlementsMatch(actual, expected: expected))",
 "    }",
 "",
 "    @objc func testProductIOSProfileRejectsWrongIdentityDeviceExpiryAndPermissions() throws {",
 "        for (key, value) in [(\"TeamIdentifier\", [\"OTHERTEAM1\"] as Any), (\"ProvisionedDevices\", [\"other-device\"] as Any),",
 "                             (\"ExpirationDate\", Date(timeIntervalSince1970: 99) as Any), (\"CreationDate\", Date(timeIntervalSince1970: 101) as Any),",
 "                             (\"Platform\", [\"macOS\"] as Any)] {",
 "            var profile = localIOSProfile()",
 "            profile[key] = value",
 "            XCTAssertThrowsError(try ProductIOSContract.iosEntitlements(profile: profile, team: \"TEAMTEST01\",",
 "                bundleID: \"com.example.local\", device: \"device-one\", requested: [:], now: Date(timeIntervalSince1970: 100)))",
 "        }",
 "        for requested: [String: Any] in [[\"get-task-allow\": true], [\"not-authorized\": true],",
 "            [\"application-identifier\": \"TEAMTEST01.com.other.app\"], [\"application-identifier\": 7],",
 "            [\"com.apple.developer.team-identifier\": [\"TEAMTEST01\"]], [\"keychain-access-groups\": [\"OTHERTEAM1.app\"]]] {",
 "            XCTAssertThrowsError(try ProductIOSContract.iosEntitlements(profile: localIOSProfile(), team: \"TEAMTEST01\",",
 "                bundleID: \"com.example.local\", device: \"device-one\", requested: requested, now: Date(timeIntervalSince1970: 100)))",
 "        }",
 "    }",
 "",
 "    @objc func testProductIOSProfileRejectsUnknownEntitlementVariables() throws {",
 "        XCTAssertThrowsError(try ProductIOSContract.iosEntitlements(",
 "            profile: localIOSProfile(), team: \"TEAMTEST01\", bundleID: \"com.example.local\",",
 "            device: \"device-one\", requested: [\"aps-environment\": \"$(UNKNOWN_ENVIRONMENT)\"],",
 "            now: Date(timeIntervalSince1970: 100)))",
 "    }",
 "",
 "}",
].join('\n');
test('产品Security验真器拒绝错误Release配置、profile授权和entitlement变量',async()=>{
 const {IOS_VERIFIER_SOURCE}=await import('./build.mjs'),work=sandbox();
 try{
  const swift=process.env.PRODUCT_TEST_SWIFT,developer=process.env.PRODUCT_TEST_DEVELOPER_DIR;
  assert.ok(swift&&developer,'统一验收须显式交付产品锁定Xcode的PRODUCT_TEST_SWIFT和PRODUCT_TEST_DEVELOPER_DIR');
  // 官方swift入口是包内链接；核验规范目标属于同一Xcode并具执行权限。
  const actualSwift=realpathSync(swift);assert.ok(actualSwift.startsWith(realpathSync(developer)+'/'));
  assert.ok(swift.startsWith(developer+'/'));assert.ok(lstatSync(actualSwift).isFile()&&(lstatSync(actualSwift).mode&0o111));
  const main=IOS_VERIFIER_SOURCE.indexOf('\ndo {\n let bytes = FileHandle.standardInput');assert.ok(main>0);
  const source=join(work,'ios-contract.swift'),bundle=join(work,'IOSVerifierTests.xctest'),binary=join(bundle,'Contents/MacOS/IOSVerifierTests'),frameworks=join(developer,'Platforms/MacOSX.platform/Developer/Library/Frameworks');
  mkdirSync(join(bundle,'Contents/MacOS'),{recursive:true});
  writeFixture(join(bundle,'Contents/Info.plist'),'<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>IOSVerifierTests</string><key>CFBundleIdentifier</key><string>test.product.ios-verifier</string><key>CFBundlePackageType</key><string>BNDL</string></dict></plist>');
  writeFixture(source,IOS_VERIFIER_SOURCE.slice(0,main)+'\n'+iosContractFixture);
  const compiler=join(developer,'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc');
  assert.ok(realpathSync(compiler).startsWith(realpathSync(developer)+'/'));
  const compiled=spawnSync(compiler,['-sdk',join(developer,'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'),'-target',(process.arch==='arm64'?'arm64':'x86_64')+'-apple-macosx14.0','-emit-library','-module-name','IOSVerifierTests','-module-cache-path',join(work,'module-cache'),'-F',frameworks,'-I',join(developer,'Platforms/MacOSX.platform/Developer/usr/lib'),'-L',join(developer,'Platforms/MacOSX.platform/Developer/usr/lib'),'-Xlinker','-rpath','-Xlinker',join(developer,'Platforms/MacOSX.platform/Developer/usr/lib'),'-framework','Security','-framework','CryptoKit','-framework','XCTest','-Xlinker','-rpath','-Xlinker',frameworks,source,'-o',binary],{encoding:'utf8',env:process.env});
  assert.equal(compiled.status,0,compiled.stderr);
  // Apple XCTest由同一登记Xcode的正式runner加载真实测试Bundle，不能使用其它平台的XCTMain。
  const runner=join(developer,'usr/bin/xctest');assert.ok(realpathSync(runner).startsWith(realpathSync(developer)+'/'));
  const trusted=spawnSync('/usr/bin/codesign',['--verify','--strict','--all-architectures',runner],{encoding:'utf8',env:process.env});assert.equal(trusted.status,0,trusted.stderr);
  const checked=spawnSync(runner,[bundle],{encoding:'utf8',env:process.env,timeout:60000});assert.equal(checked.status,0,checked.stdout+checked.stderr);
  assert.match(checked.stdout+checked.stderr,/Executed 5 tests, with 0 failures/u);
 }finally{removeFixture(work,{recursive:true});}
});

test('产品取消等待工具进程组退出，不提前交付结果',async()=>{
 const {runBuildProcess}=await import('./build.mjs'),work=sandbox(),abort=new AbortController();let polling,deadline;
 try{
  const pidFile=join(work,'descendant.pid');
  const script="const fs=require('node:fs'),{spawn}=require('node:child_process');const child=spawn(process.execPath,['-e','setInterval(()=>{},1000)'],{stdio:'ignore'});fs.writeFileSync(process.argv[1],String(child.pid));setInterval(()=>{},1000);";
  const execution=runBuildProcess(process.execPath,['-e',script,pidFile],process.env,work,{capture:true,signal:abort.signal,timeout:5000});
  polling=setInterval(()=>{if(existsSync(pidFile))abort.abort();},20);deadline=setTimeout(()=>abort.abort(),2000);
  await assert.rejects(execution,/取消/);assert.ok(existsSync(pidFile));const pid=Number(readFileSync(pidFile,'utf8'));
  assert.throws(()=>process.kill(pid,0),error=>error.code==='ESRCH');
 }finally{clearInterval(polling);clearTimeout(deadline);removeFixture(work,{recursive:true});}
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

// 只读身份命令在空PATH、无控制台环境下工作，来源仍为本产品原始工程。
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
 assert.equal(receipt.product_id,contract.product_id);assert.equal(receipt.source_files.length,4);
 for(const file of receipt.source_files)assert.equal(createHash('sha256').update(readStoreSource(root,file.path)).digest('hex'),file.sha256);
 assert.notEqual(invoke(['store-identity','ios']).status,0);assert.deepEqual(storeIdentity(),before);
});
test('公开只读身份命令拒绝缺失或重复原始工程，配置变化由产品回执表达',()=>{
 const work=sandbox();try{
  for(const name of ['scripts','ios/project','android/app'])mkdirSync(join(work,name),{recursive:true});
  copyFixture(join(root,'scripts/build.mjs'),join(work,'scripts/build.mjs'));
  writeFixture(join(work,'scripts/flows.json'),JSON.stringify({schema:1,product_id:contract.product_id,entry:'scripts/build.mjs',platforms:{ios:{}}}));
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
test('CLI异步资源可反向导入唯一校验，正常参数和离线失败均准确收口',()=>{
 const area=sandbox();
 try{
  const source=join(area,'source'),scripts=join(source,'scripts'),file=join(scripts,'build.mjs');
  const platform=Object.keys(contract.platforms)[0];
  const work=join(source,'target','build');
  mkdirSync(scripts,{recursive:true});mkdirSync(work,{recursive:true});
  writeFixture(file,readFileSync(join(root,'scripts/build.mjs')));
  for(const name of ['target.mjs'])writeFixture(join(scripts,name),readFileSync(join(root,'scripts',name)));
  writeFixture(join(scripts,'flows.json'),JSON.stringify(contract));
  const provider=[
   "import {writeFileSync} from 'node:fs';",
   "import {join} from 'node:path';",
   "const refuse = false;",
   "export async function bootstrapNode(work,options){",
   " const owner=await import('./build.mjs');owner.checkWork(work);",
   " writeFileSync(join(work,'bootstrap.json'),JSON.stringify({offline:options.offline,work}));",
   " if(refuse&&options.offline)throw Error('合成离线缺少锁定资源');",
   " return {path:process.execPath};",
   "}",
   "export async function resources(platform,work,request,options){",
   " const owner=await import('./build.mjs');owner.checkWork(work);owner.platformContract(platform);",
   " if(refuse&&options.offline)throw Error('合成离线缺少锁定资源');",
   " return {schema:1,product_id:owner.contract.product_id,platform,work,offline:options.offline,request};",
   "}",
  ].join('\n');
  writeFixture(join(scripts,'resources.mjs'),provider);
  const env={HOME:area,LANG:'C',PATH:''},marker=join(work,'bootstrap.json');
  const options={cwd:source,env,input:'{}',encoding:'utf8',timeout:5000,maxBuffer:1024*1024};
  const check=(result,status)=>{
   assert.equal(result.error,undefined);assert.equal(result.signal,null);assert.equal(result.status,status);
   assert.doesNotMatch(result.stderr,/unsettled top-level await/u);
  };
  // 普通模块导入不启动CLI；结果来自当前入口完整正文，不截取/重写其控制结构。
  const imported=spawnSync(process.execPath,['--input-type=module','--eval',
   "import {pathToFileURL} from 'node:url';await import(pathToFileURL("+JSON.stringify(file)+"));process.stdout.write('module-ready\\n');"],options);
  check(imported,0);assert.equal(imported.stdout,'module-ready\n');assert.deepEqual(readdirSync(work),[]);
  const input=JSON.stringify({schema:1,product_id:contract.product_id,platform,work});
  for(const offline of [false,true]){
   const result=spawnSync(process.execPath,[file,'resources',platform,'--work',work,...(offline?['--offline']:[])],{...options,input});
   check(result,0);
   assert.deepEqual(JSON.parse(result.stdout),{schema:1,product_id:contract.product_id,platform,work,offline,request:JSON.parse(input)});
  }
  // execute先真实完成反向导入和Node选择，再由原请求校验拒绝，不能以假Build成功代替。
  const invalid=spawnSync(process.execPath,[file,'execute',platform,'--work',work,'--offline'],{...options,input:'{"schema":99}'});
  check(invalid,1);assert.equal(invalid.stdout,'');assert.match(invalid.stderr,/公开Build请求身份或字段无效/u);
  assert.equal(existsSync(marker),false,'失败的真实入口必须清除引导材料');
  for(const extra of [['--offline','--offline'],['--unknown']]){
   const result=spawnSync(process.execPath,[file,'execute',platform,'--work',work,...extra],options);
   check(result,1);assert.equal(result.stdout,'');assert.match(result.stderr,/固定入口参数无效/u);assert.equal(existsSync(marker),false);
  }
  const malformed=spawnSync(process.execPath,[file,'resources',platform,'--work',work],{...options,input:'{'});
  check(malformed,1);assert.equal(malformed.stdout,'');assert.match(malformed.stderr,/SyntaxError/u);
  const unknown=spawnSync(process.execPath,[file,'resources','unknown','--work',work],options);
  check(unknown,1);assert.match(unknown.stderr,/平台未声明/u);
  writeFixture(join(scripts,'resources.mjs'),provider.replace('const refuse = false;','const refuse = true;'));
  for(const command of ['execute','resources']){
   const result=spawnSync(process.execPath,[file,command,platform,'--work',work,'--offline'],options);
   check(result,1);assert.equal(result.stdout,'');assert.match(result.stderr,/合成离线缺少锁定资源/u);
  }
  assert.equal(existsSync(join(work,'.product-build.lock')),false);
  assert.equal(existsSync(join(work,'build-result.json')),false);
 }finally{rmSync(area,{recursive:true,force:true});}
});

// 独立入口的真实SDK调用由本产品检查。
test('CitizenApp产品入口唯一构建SDK并按所有者隔离Cargo Home', async () => {
  const product = BUILD_SHELL_SOURCES.run;
  assert.match(product, /CITIZENAPP_SDK_CARGO_HOME/u);
  assert.match(product, /CITIZENAPP_CHAT_CARGO_HOME/u);
  assert.ok(product.indexOf('export CARGO_HOME="$CITIZENAPP_SDK_CARGO_HOME"')
    < product.indexOf('"$CITIZENSDK_ROOT/scripts/build-native.sh"'));
  assert.ok(product.indexOf('export CARGO_HOME="$CITIZENAPP_CHAT_CARGO_HOME"')
    < product.indexOf('"$TATACHATSDK_ROOT/scripts/build-native.sh"'));
});


test('本产品Apple Flutter资源只通过自身资源入口交付',()=>{
 const entry=BUILD_SHELL_SOURCES.run;
 const resources=readFileSync(new URL('./resources.mjs', import.meta.url),'utf8');
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
test('宿主完整Build在调用方消费前保留成功或失败现场，独立入口仍清空',async()=>{
 const {execute,outputDigest,clearWork}=await import('./build.mjs'),platform=Object.keys(contract.platforms)[0],declared=contract.platforms[platform];
 for(const [host,failure] of [['3',false],['3',true],['4',false],[undefined,false]]){
  const work=sandbox();try{
   let result;
   const stages={requirements:()=>{},resources:async()=>({}),prepare:async()=>{writeFixture(join(work,'partial'),'本轮现场');if(failure)throw Error('宿主失败夹具');},build:async()=>{
    result={schema:1,product_id:contract.product_id,platform,work,completion:declared.completion,run_id:'123456789',files:declared.files.map(name=>{const path=join(work,name);mkdirSync(dirname(path),{recursive:true});writeFixture(path,'当前产物');return {path,sha256:outputDigest(path)};})};return result;
   }};
   const pending=execute(platform,work,{run_id:'123456789'},{stages,environment:host?{PRODUCT_HOST_FD:host}:{}});
   if(failure)await assert.rejects(pending,/宿主失败夹具/);else assert.deepEqual(await pending,result);
   assert.equal(existsSync(join(work,'.product-build.lock')),false);
   if(host==='3'){
    assert.equal(existsSync(join(work,'partial')),true);
    if(!failure){assert.equal(existsSync(join(work,'build-result.json')),true);for(const file of result.files)assert.equal(outputDigest(file.path),file.sha256);}
    clearWork(work);
   }
   assert.deepEqual(readdirSync(work),[]);
  }finally{removeFixture(work,{recursive:true,force:true});}
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
}

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
if(inlineTestEntry){
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
 test('三级原生来源恢复消费路径并保留图标、配置和源码字节',()=>{
  const source=root,destination=join(temporaryRoot(),'layout-platform-'+randomBytes(8).toString('hex'));
  mkdirSync(destination,{mode:0o700});
  try{
   materializePlatformInputs(source,destination);
   const cases=[
    ['ios/source/AppDelegate.swift','ios/Runner/AppDelegate.swift'],
    ['ios/project/Runner.pbxproj','ios/Runner.xcodeproj/project.pbxproj'],
    ['ios/resources/icons.json','ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json'],
    ['android/app/source/MainActivity.kt','android/app/src/main/MainActivity.kt'],
    ['assets/logo/icon72.png','android/app/src/main/res/mipmap-hdpi/ic_launcher.png'],
   ];
   for(const [input,output] of cases)assert.deepEqual(readFileSync(join(destination,output)),readFileSync(join(source,input)));
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
   copyFixture(join(root,'scripts/flows.json'),join(product,'scripts/flows.json'));
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
}


// 原生文件名仍由平台要求；独立旧字节摘要保证集中和去重没有改变图标或启动画面。
if(inlineTestEntry){
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
    for(const name of ['scripts/build.mjs','scripts/flows.json',...Object.keys(JSON.parse(LOGO_ASSETS_SOURCE).files)]){
     const destination=join(product,name);mkdirSync(dirname(destination),{recursive:true,mode:0o700});copyFixture(join(root,name),destination);
    }
    const image=join(product,'assets/logo/icon20.png');
    if(mode==='missing')unlinkSync(image);
    if(mode==='extra')copyFixture(image,join(product,'assets/logo/extra.png'));
    if(mode==='link'){unlinkSync(image);symlinkSync(join(root,'assets/logo/icon20.png'),image);}
    if(mode==='platform')copyFixture(image,join(product,'android/resources/residual.png'));
    const result=spawnSync(process.execPath,[join(product,'scripts/build.mjs'),'logos'],{encoding:'utf8'});
    if(mode==='valid')assert.equal(result.status,0,result.stderr);else assert.notEqual(result.status,0,mode);
   }
  }finally{removeFixture(work,{recursive:true,force:true});}
 });
}
