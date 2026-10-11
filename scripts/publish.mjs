#!/usr/bin/env node
// 公民App发布只消费GitHub自动化已完成的公开Run、Release与资产，不创建或派发自动化。
import {createHash} from 'node:crypto';

const product='citizenapp',repository='crcfrcn/citizenapp';
const targets=Object.freeze({
 ios:Object.freeze({workflow:'.github/workflows/release-ios.yml',manifest:'citizenapp-release-ios.json',
  binaries:Object.freeze(['citizenapp.ipa']),display:'iOS'}),
 android:Object.freeze({workflow:'.github/workflows/release-android.yml',manifest:'citizenapp-release-android.json',
  binaries:Object.freeze(['citizenapp.apk','citizenapp.aab']),display:'Android'}),
});
const fail=message=>{throw Error('公民App Publish：'+message);};
const sha=value=>typeof value==='string'&&/^[a-f0-9]{64}$/u.test(value);
const sourceSHA=value=>typeof value==='string'&&/^[a-f0-9]{40}$/u.test(value);
const positive=value=>Number.isSafeInteger(value)&&value>0;
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');

// 产品自行读取完整分页的公开运行与Release，不接受调用方裁剪的成功集合。
async function pages(path,field,request){
 const rows=[];
 for(let page=1;page<=10000;page++){
  const response=await request(path+'?per_page=100&page='+page);
  const values=field?response?.[field]:response;
  if(!Array.isArray(values)||values.length>100)fail('GitHub公开分页无效');
  rows.push(...values);if(values.length<100)return rows;
 }
 fail('GitHub公开分页未结束');
}
export async function preparePublication({platform,request}){
 if(!Object.hasOwn(targets,platform))fail('发布平台无效');
 if(typeof request!=='function')fail('GitHub公开读取能力缺失');
 const runs=await pages('actions/runs','workflow_runs',request),releases=await pages('releases',null,request);
 return verifyPublication({platform,runs,releases,
  readTag:tag=>request('git/ref/tags/'+encodeURIComponent(tag)),
  readAsset:async asset=>(await request(asset.url,{raw:true}))?.body});
}

// 本机签名只消费本仓公开声明与同一成功自动化的未签名产物；签名材料由调用方瞬时交付。
const signedProofs=new WeakSet();
const localSigningSteps=Object.freeze({"android":"set -euo pipefail\numask 077\nwork=\"$CITIZENAPP_BUILD_TEMP/citizenapp-android-signing\"\npublish=\"build/release\"\nrm -rf \"$work\" \"$publish\"\nmkdir -p \"$work\" \"$publish\"\ntrap 'rm -rf \"$work\"' EXIT\npython3 - \"$work\" <<'PY'\nimport base64, os, pathlib, re, sys\nroot = pathlib.Path(sys.argv[1])\nfields = {}\nfor raw in os.environ.get(\"APP_KEY\", \"\").splitlines():\n    line = raw.strip()\n    if not line or line.startswith(\"#\"):\n        continue\n    name, sep, value = line.partition(\"=\")\n    if not sep or name.strip() in fields or not value.strip():\n        raise SystemExit(\"APP_KEY 行格式无效\")\n    fields[name.strip()] = value.strip()\nif set(fields) - {\"keystore\", \"password\", \"alias\", \"keyPassword\"}:\n    raise SystemExit(\"APP_KEY 包含未登记字段\")\nalias = fields.get(\"alias\", \"upload\")\nif not re.fullmatch(r\"[A-Za-z0-9._-]{1,128}\", alias):\n    raise SystemExit(\"APP_KEY alias 无效\")\ntry:\n    key = base64.b64decode(fields[\"keystore\"], validate=True)\n    password = fields[\"password\"]\nexcept (KeyError, ValueError) as exc:\n    raise SystemExit(\"APP_KEY 缺少有效签名材料\") from exc\nif not 1024 <= len(key) <= 32 * 1024 * 1024:\n    raise SystemExit(\"APP_KEY keystore 大小无效\")\n(root / \"release.keystore\").write_bytes(key)\n(root / \"password\").write_text(password)\n(root / \"key-password\").write_text(fields.get(\"keyPassword\", password))\n(root / \"alias\").write_text(alias)\nPY\nstore_password=\"$(cat \"$work/password\")\"\nkey_password=\"$(cat \"$work/key-password\")\"\nalias=\"$(cat \"$work/alias\")\"\nexport GMB_ANDROID_STORE_PASSWORD=\"$store_password\"\nexport GMB_ANDROID_KEY_PASSWORD=\"$key_password\"\napksigner=\"$ANDROID_HOME/build-tools/37.0.1/apksigner\"\ntest -x \"$apksigner\"\n\"$apksigner\" sign --ks \"$work/release.keystore\" \\\n  --ks-pass env:GMB_ANDROID_STORE_PASSWORD --key-pass env:GMB_ANDROID_KEY_PASSWORD \\\n  --v4-signing-enabled false \\\n  --ks-key-alias \"$alias\" --out \"$publish/citizenapp.apk\" \\\n  build/app/outputs/flutter-apk/app-release.apk\ncp build/app/outputs/bundle/release/app-release.aab \"$publish/citizenapp.aab\"\njarsigner -keystore \"$work/release.keystore\" \\\n  -storepass:env GMB_ANDROID_STORE_PASSWORD -keypass:env GMB_ANDROID_KEY_PASSWORD \\\n  \"$publish/citizenapp.aab\" \"$alias\"\n\"$apksigner\" verify --verbose --print-certs \"$publish/citizenapp.apk\" \\\n  | tee \"$work/apk-verification.txt\"\ngrep -F 'Verified using v2 scheme (APK Signature Scheme v2): true' \"$work/apk-verification.txt\"\n# Android 上传证书按平台规范可以自签名；只验证包完整性，再从三处回读同一证书。\njarsigner -verify \"$publish/citizenapp.aab\"\napk_certificate_sha256=\"$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' \"$work/apk-verification.txt\")\"\nkey_certificate_sha256=\"$(keytool -exportcert -alias \"$alias\" \\\n  -keystore \"$work/release.keystore\" -storepass:env GMB_ANDROID_STORE_PASSWORD -rfc \\\n  | openssl x509 -outform DER | shasum -a 256 | awk '{print $1}')\"\naab_certificate_sha256=\"$(keytool -printcert -jarfile \"$publish/citizenapp.aab\" -rfc \\\n  | openssl x509 -outform DER | shasum -a 256 | awk '{print $1}')\"\n[[ \"$apk_certificate_sha256\" =~ ^[0-9a-f]{64}$ ]]\ntest \"$apk_certificate_sha256\" = \"$key_certificate_sha256\"\ntest \"$apk_certificate_sha256\" = \"$aab_certificate_sha256\"\ntest \"$(apkanalyzer manifest application-id \"$publish/citizenapp.apk\")\" = com.crcfrcn.citizenapp\ntest \"$(apkanalyzer manifest version-code \"$publish/citizenapp.apk\")\" = \"$CITIZENAPP_BUILD_NUMBER\"","ios":"set -euo pipefail\numask 077\nwork=\"$CITIZENAPP_BUILD_TEMP/citizenapp-ios-signing\"\npublish=\"$CITIZENAPP_RELEASE_ROOT\"\nrm -rf \"$work\" \"$publish\"\nmkdir -p \"$work\" \"$publish\"\nkeychain=\"$work/release.keychain-db\"\nkeychain_password=\"$(openssl rand -hex 32)\"\n# 本机钥匙串搜索列表属共享用户状态；先保存，结束时恢复。\noriginal_keychains=()\nwhile IFS= read -r line; do\n  [[ \"$line\" =~ ^[[:space:]]*\\\"([^\\\"]+)\\\"$ ]] || exit 1\n  original_keychains+=(\"${BASH_REMATCH[1]}\")\ndone < <(security list-keychains -d user)\n(( ${#original_keychains[@]} > 0 )) || exit 1\ncleanup() {\n  security list-keychains -d user -s \"${original_keychains[@]}\" >/dev/null 2>&1 || true\n  security delete-keychain \"$keychain\" >/dev/null 2>&1 || true\n  rm -rf \"$work\"\n}\ntrap cleanup EXIT\npython3 - \"$work\" <<'PY'\nimport base64, os, pathlib, re, sys\nroot = pathlib.Path(sys.argv[1])\nfields = {}\nfor raw in os.environ.get(\"IOS_KEY\", \"\").splitlines():\n    line = raw.strip()\n    if not line or line.startswith(\"#\"):\n        continue\n    name, sep, value = line.partition(\"=\")\n    if not sep or name.strip() in fields or not value.strip():\n        raise SystemExit(\"IOS_KEY 行格式无效\")\n    fields[name.strip()] = value.strip()\nif set(fields) != {\"pkcs12\", \"password\", \"certificate_sha1\"}:\n    raise SystemExit(\"IOS_KEY 字段集合无效\")\nif not re.fullmatch(r\"[0-9A-F]{40}\", fields[\"certificate_sha1\"]):\n    raise SystemExit(\"Apple Distribution 证书摘要无效\")\ntry:\n    pkcs12 = base64.b64decode(fields[\"pkcs12\"], validate=True)\n    profile = base64.b64decode(os.environ.get(\"IOS_PROVISIONING_PROFILE\", \"\"), validate=True)\nexcept ValueError as exc:\n    raise SystemExit(\"Apple Distribution 或 provisioning profile Base64 无效\") from exc\nif not 1024 <= len(pkcs12) <= 32 * 1024 * 1024 or not 1024 <= len(profile) <= 1024 * 1024:\n    raise SystemExit(\"Apple Distribution 签名材料大小无效\")\n(root / \"distribution.p12\").write_bytes(pkcs12)\n(root / \"password\").write_text(fields[\"password\"])\n(root / \"certificate-sha1\").write_text(fields[\"certificate_sha1\"])\n(root / \"profile.mobileprovision\").write_bytes(profile)\nPY\nsecurity create-keychain -p \"$keychain_password\" \"$keychain\"\nsecurity set-keychain-settings -lut 21600 \"$keychain\"\nsecurity unlock-keychain -p \"$keychain_password\" \"$keychain\"\n# 中文注释：codesign 查找 identity 依赖用户钥匙串搜索列表；仅传 --keychain\n# 不能保证干净 runner 能从证书继续定位到同钥匙串中的私钥。\nsecurity list-keychains -d user -s \"$keychain\" \"${original_keychains[@]}\"\nsecurity import \"$work/distribution.p12\" -k \"$keychain\" -P \"$(cat \"$work/password\")\" -T /usr/bin/codesign\nsecurity set-key-partition-list -S apple-tool:,apple:,codesign: -s -k \"$keychain_password\" \"$keychain\" >/dev/null\ncertificate_sha1=\"$(cat \"$work/certificate-sha1\")\"\nsecurity find-certificate -a -Z \"$keychain\" | grep -F \"SHA-1 hash: $certificate_sha1\"\nsecurity find-identity -v -p codesigning \"$keychain\" | grep -Fq \"$certificate_sha1\"\n# 中文注释：干净 runner 的钥匙串不保证预装描述文件 CMS 签发链；LibreSSL\n# 直接验证 CMS 密码学签名并解出载荷，再用正式证书摘要锁定唯一配对。\n/usr/bin/openssl smime -verify -inform DER -in \"$work/profile.mobileprovision\" \\\n  -noverify -out \"$work/profile.plist\" >/dev/null\nprofile_certificate_sha1=\"$(\n  plutil -extract DeveloperCertificates.0 raw -o - \"$work/profile.plist\" \\\n    | base64 -D | shasum -a 1 | awk '{print toupper($1)}'\n)\"\ntest \"$profile_certificate_sha1\" = \"$certificate_sha1\"\ntest \"$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' \"$work/profile.plist\")\" = MHYMVRN6FC\ntest \"$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' \"$work/profile.plist\")\" = MHYMVRN6FC.ios.citizenapp\ntest \"$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' \"$work/profile.plist\")\" = false\nplutil -extract Entitlements xml1 -o \"$work/entitlements.plist\" \"$work/profile.plist\"\napp=\"$CITIZENAPP_FLUTTER_ROOT/build/ios/iphoneos/Runner.app\"\ntest \"$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \"$app/Info.plist\")\" = ios.citizenapp\ncp \"$work/profile.mobileprovision\" \"$app/embedded.mobileprovision\"\nfind \"$app\" -type f -name '*.dylib' -print0 | while IFS= read -r -d '' item; do\n  codesign --force --sign \"$certificate_sha1\" --keychain \"$keychain\" --timestamp=none \"$item\"\ndone\nfind \"$app\" -type d \\( -name '*.framework' -o -name '*.appex' \\) -print0 \\\n  | while IFS= read -r -d '' item; do\n      codesign --force --sign \"$certificate_sha1\" --keychain \"$keychain\" --timestamp=none \"$item\"\n    done\ncodesign --force --sign \"$certificate_sha1\" --keychain \"$keychain\" --timestamp=none \\\n  --generate-entitlement-der --entitlements \"$work/entitlements.plist\" \"$app\"\ncodesign --verify --deep --strict \"$app\"\ncodesign -dv --verbose=4 \"$app\" 2> \"$work/codesign.txt\"\ngrep -F 'TeamIdentifier=MHYMVRN6FC' \"$work/codesign.txt\"\nmkdir -p \"$work/package/Payload\"\ncp -R \"$app\" \"$work/package/Payload/Runner.app\"\n(cd \"$work/package\" && ditto -c -k --sequesterRsrc --keepParent Payload \"$publish/citizenapp.ipa\")\nunzip -Z1 \"$publish/citizenapp.ipa\" | grep -Fx 'Payload/Runner.app/Info.plist'"});
const localBundleID="ios.citizenapp",localPackageName="com.crcfrcn.citizenapp",localProfileName="APP_PROFILE";
function localNames(platform) {
 if(platform==='android')return [product+'-unsigned.apk',product+'-unsigned.aab'];
 if(platform==='ios')return [product+'-unsigned-ios.zip'];
 throw Error('本产品未声明的签名平台');
}
export function testFiles(){return ['scripts/publish.mjs','.github/workflows/release-android.mjs','.github/workflows/release-ios.mjs'];}
export async function testTools(){return [];}
export function unsignedArtifactNames(platform) {return ['automation.json',product+'-unsigned-'+platform+'.json',...localNames(platform)];}
function localSignedNames(platform) {if(platform==='android')return [product+'.apk',product+'.aab'];if(platform==='ios')return [product+'.ipa'];throw Error('本产品未声明的签名平台');}
// 长驻控制台按准确源码摘要重读本产品公开声明，避免保存和签名消费不同修订。
async function localSource(name){
 const {lstat,realpath,readFile}=await import('node:fs/promises'),{fileURLToPath,pathToFileURL}=await import('node:url');
 const path=fileURLToPath(new URL(name,import.meta.url)),stat=await lstat(path);
 if(!stat.isFile()||stat.isSymbolicLink()||stat.size>4*1024*1024||await realpath(path)!==path)
   throw Error('本产品公开声明源无效');
 const digest=createHash('sha256').update(await readFile(path)).digest('hex');
 return import(pathToFileURL(path).href+'?revision='+digest);
}
export async function signingTools(platform) {
 const {contract}=await localSource('./build.mjs');const tools=contract.platforms?.[platform]?.tools;
 const required=platform==='android'?['java','android','android-sdk']:platform==='ios'?['xcode']:null;
 if(!required||!Array.isArray(tools))throw Error('本产品签名工具声明缺失');
 const result=required.map(id=>tools.find(item=>item.id===id));
 if(result.some(item=>!item||typeof item.version!=='string'||!item.version))throw Error('本产品签名工具版本无效');
 return result.map(({id,version})=>({id,version}));
}
export async function signingConfiguration(platform) {
 const kind=platform==='android'?'android-signing':platform==='ios'?'ios-signing':null;
 if(!kind)throw Error('本产品未声明的签名平台');
 const {describeConfiguration}=await localSource('./config.mjs');
 const items=describeConfiguration().configuration.items.filter(item=>item.kind===kind);
 const expected=platform==='android'?['APP_KEY']:['IOS_KEY',localProfileName];
 if(items.length!==expected.length||items.some(item=>item.environment!=='release'||item.accessLevel!=='protected')
   ||items.map(item=>item.name).sort().join('\0')!==expected.sort().join('\0'))throw Error('产品签名配置需求与真实消费者不一致');
 return items.map(item=>({environment:item.environment,name:item.name}));
}
// 本机签名工具异步运行并等进程组退出，避免阻塞其它产品的控制台任务。
async function localCommand(command,args,{cwd,env,capture=false,timeout=1800000}={}) {
 const {spawn}=await import('node:child_process');
 return new Promise((resolve,reject)=>{
   let child;try{child=spawn(command,args,{cwd,env,detached:true,stdio:['ignore',capture?'pipe':'ignore','ignore']});}
   catch{reject(Error('本机签名工具无法启动'));return;}
   const parts=[];let size=0,failed=false,settled=false;
   const stop=()=>{if(!child.pid)return;try{process.kill(-child.pid,'SIGTERM');}catch{child.kill();}};
   const timer=setTimeout(()=>{failed=true;stop();},timeout);
   if(capture&&child.stdout)child.stdout.on('data',part=>{size+=part.length;if(size>16*1024*1024){failed=true;stop();}else parts.push(part);});
   child.once('error',()=>{if(settled)return;settled=true;clearTimeout(timer);reject(Error('本机签名工具无法启动'));});
   child.once('close',(code,signal)=>{if(settled)return;settled=true;clearTimeout(timer);
     if(failed||code!==0||signal)reject(Error('本机签名工具失败或超时'));
     else resolve({output:capture?Buffer.concat(parts).toString('utf8'):''});
   });
 });
}
async function localDigest(path) {
 const {createReadStream}=await import('node:fs');const hash=createHash('sha256');
 for await(const part of createReadStream(path))hash.update(part);
 return hash.digest('hex');
}
function localRegular(fs,path,limit) {
 const stat=fs.lstatSync(path);
 if(!stat.isFile()||stat.isSymbolicLink()||stat.nlink!==1||stat.size<1||stat.size>limit||fs.realpathSync(path)!==path)
   throw Error('本机发布资产不是准确有界普通文件');
 return stat;
}
export async function verifyUnsigned(platform,directory,run) {
 const fs=await import('node:fs'),path=await import('node:path');
 const names=localNames(platform),manifestName=product+'-unsigned-'+platform+'.json';
 if(typeof directory!=='string'||!path.isAbsolute(directory)||fs.realpathSync(directory)!==directory
   ||!fs.lstatSync(directory).isDirectory()||fs.readdirSync(directory).sort().join('\0')!==['automation.json',manifestName,...names].sort().join('\0'))
   throw Error('未签名资产目录不属于准确闭集');
 if(!Number.isSafeInteger(run?.id)||run.id<1||!Number.isSafeInteger(run?.run_attempt)||run.run_attempt<1
   ||!Number.isSafeInteger(run?.run_number)||run.run_number<1||run.status!=='completed'||run.conclusion!=='success'
   ||run.head_branch!=='main'||run.event!=='workflow_dispatch'||run.repository?.full_name!==repository
   ||String(run.path||'').split('@')[0]!=='.github/workflows/release-'+platform+'.yml'
   ||!/^[a-f0-9]{40}$/u.test(run.head_sha||''))throw Error('未签名资产没有同一成功自动化身份');
 const metadata=JSON.parse(fs.readFileSync(path.join(directory,'automation.json'),'utf8'));
 const manifest=JSON.parse(fs.readFileSync(path.join(directory,manifestName),'utf8'));
 const version=metadata.version,tag=`${product}-${platform}-v${version}-r${run.id}-a${run.run_attempt}`;
 if(metadata.schema!==1||metadata.repository!==repository||metadata.product_id!==product||metadata.platform!==platform
   ||metadata.run_id!==run.id||metadata.run_attempt!==run.run_attempt||metadata.run_number!==run.run_number
   ||metadata.source_sha!==run.head_sha||metadata.workflow!=='.github/workflows/release-'+platform+'.yml'
   ||metadata.tag!==tag||!/^[0-9]+\.[0-9]+\.[0-9]+$/u.test(version||'')
   ||manifest.product_id!==product||manifest.version!==version||manifest.github_run_number!==run.run_number
   ||manifest.head_sha!==run.head_sha||manifest.bundle_id!==localBundleID||manifest.package_name!==localPackageName
   ||!Array.isArray(metadata.assets)||metadata.assets.length!==names.length+1
   ||!Array.isArray(manifest.assets)||manifest.assets.length!==names.length)throw Error('未签名资产清单与成功自动化不一致');
 for(const name of [...names,manifestName]){
   const row=metadata.assets.find(item=>item?.name===name);
   if(!row||metadata.assets.filter(item=>item?.name===name).length!==1||!/^[a-f0-9]{64}$/u.test(row.sha256||''))throw Error('未签名资产摘要声明无效');
   const file=path.join(directory,name),stat=localRegular(fs,file,2*1024**3);
   if(stat.size!==row.size||await localDigest(file)!==row.sha256)throw Error('未签名资产字节不符');
   if(name!==manifestName){const proof=manifest.assets.find(item=>item?.asset_name===name);
     if(!proof||manifest.assets.filter(item=>item?.asset_name===name).length!==1
       ||proof.platform!==(platform==='ios'?'iOS':'Android')||proof.asset_sha256!==row.sha256)throw Error('未签名产物声明不一致');}
 }
 return {product_id:product,platform,version,tag,run_id:run.id,run_attempt:run.run_attempt,
   run_number:run.run_number,source_sha:run.head_sha,bundle_id:localBundleID,package_name:localPackageName,
   unsigned_assets:metadata.assets.filter(item=>names.includes(item.name))};
}
export async function signUnsigned(platform,directory,run,material,workRoot,{environment:tools=process.env}={}) {
 const fs=await import('node:fs'),path=await import('node:path');
 const proof=await verifyUnsigned(platform,directory,run),refs=await signingConfiguration(platform);
 if(!material||typeof material!=='object'||refs.some(ref=>{
   const value=material[ref.environment+':'+ref.name];return !Buffer.isBuffer(value)||value.length<1||value.length>32*1024*1024;
 }))throw Error('本次产品签名材料缺失或超限');
 if(typeof workRoot!=='string'||!path.isAbsolute(workRoot)||fs.realpathSync(workRoot)!==workRoot
   ||!fs.lstatSync(workRoot).isDirectory())throw Error('本机签名现场无效');
 const stage=fs.mkdtempSync(path.join(workRoot,'sign-'));
 try{
   if(platform==='android'){
     const apk=path.join(stage,'build/app/outputs/flutter-apk'),aab=path.join(stage,'build/app/outputs/bundle/release');
     fs.mkdirSync(apk,{recursive:true,mode:0o700});fs.mkdirSync(aab,{recursive:true,mode:0o700});
     fs.copyFileSync(path.join(directory,product+'-unsigned.apk'),path.join(apk,'app-release.apk'));
     fs.copyFileSync(path.join(directory,product+'-unsigned.aab'),path.join(aab,'app-release.aab'));
   } else {
     const archive=path.join(directory,product+'-unsigned-ios.zip');
     const listing=await localCommand('/usr/bin/unzip',['-Z1',archive],{capture:true,timeout:300000});
     const entries=listing.output.trim().split('\n');
     if(entries.length<2||entries.length>20000||new Set(entries).size!==entries.length
       ||entries.some(name=>name!=='__MACOSX/'&&!name.startsWith('Runner.app/')&&!name.startsWith('__MACOSX/Runner.app/'))
       ||entries.some(name=>{const parts=name.endsWith('/')?name.slice(0,-1).split('/'):name.split('/');return parts.some(part=>part==='..'||part==='.'||part==='');}))throw Error('iOS未签名包包含越界路径');
     const listingDetails=await localCommand('/usr/bin/bsdtar',['-tvf',archive],{capture:true,timeout:300000});
     if(listingDetails.output.split('\n').filter(Boolean).some(line=>!['-','d'].includes(line[0])))
       throw Error('iOS未签名包包含链接或特殊文件');
     const ios=path.join(stage,'build/ios/iphoneos');fs.mkdirSync(ios,{recursive:true,mode:0o700});
     await localCommand('/usr/bin/ditto',['-x','-k',archive,ios],{timeout:300000});
     const app=path.join(ios,'Runner.app');if(!fs.lstatSync(app).isDirectory()||fs.realpathSync(app)!==app)throw Error('iOS应用目录无效');
     const stack=[ios];let inspected=0;while(stack.length){const current=stack.pop();for(const item of fs.readdirSync(current,{withFileTypes:true})){
       const candidate=path.join(current,item.name),resolved=fs.realpathSync(candidate);
       if(++inspected>50000||!resolved.startsWith(ios+'/')&&resolved!==ios||item.isSymbolicLink())throw Error('iOS未签名包提取越界');
       if(item.isDirectory())stack.push(candidate);
     }}

   }
   for(const item of proof.unsigned_assets){const copied=platform==='android'
     ?path.join(stage,item.name.endsWith('.apk')?'build/app/outputs/flutter-apk/app-release.apk':'build/app/outputs/bundle/release/app-release.aab')
     :path.join(directory,item.name);
     if(await localDigest(copied)!==item.sha256)throw Error('签名前未签名资产发生变化');}
   const env={PATH:tools.PATH||'/usr/bin:/bin',HOME:tools.HOME||process.env.HOME,ANDROID_HOME:tools.ANDROID_HOME,
     JAVA_HOME:tools.JAVA_HOME,RUNNER_TEMP:stage,CITIZENAPP_BUILD_TEMP:stage,
     CITIZENAPP_FLUTTER_ROOT:stage,CITIZENAPP_RELEASE_ROOT:path.join(stage,'build/release'),
     CITIZENAPP_BUILD_NUMBER:String(proof.run_number),CITIZENWALLET_BUILD_NUMBER:String(proof.run_number),CITIZENWALLET_PROJECT_ROOT:stage};
   if(platform==='android')env.APP_KEY=material['release:APP_KEY'].toString('utf8');
   else {env.IOS_KEY=material['release:IOS_KEY'].toString('utf8');env.IOS_PROVISIONING_PROFILE=material['release:'+localProfileName].toString('utf8');}
   await localCommand('bash',['--noprofile','--norc','-e','-o','pipefail','-c',localSigningSteps[platform],'local-mobile-signing'],
     {cwd:stage,env,timeout:1800000});
   delete env.APP_KEY;delete env.IOS_KEY;delete env.IOS_PROVISIONING_PROFILE;
   const output=path.join(stage,'build/release'),names=localSignedNames(platform);
   if(fs.readdirSync(output).sort().join('\0')!==names.slice().sort().join('\0'))throw Error('正式签名产物集合无效');
   const destination=path.join(workRoot,'signed');fs.mkdirSync(destination,{mode:0o700});
   const assets=[];
   for(const name of names){const source=path.join(output,name),stat=localRegular(fs,source,2*1024**3);
     const target=path.join(destination,name);fs.copyFileSync(source,target);
     assets.push({platform:platform==='ios'?'iOS':'Android',asset_name:name,asset_sha256:await localDigest(target),size:stat.size});}
   const manifestName=product+'-release-'+platform+'.json';
   const manifest={product_id:product,version:proof.version,github_run_number:proof.run_number,head_sha:proof.source_sha,
     bundle_id:localBundleID,package_name:localPackageName,
     assets:assets.map(({platform,asset_name,asset_sha256})=>({platform,asset_name,asset_sha256}))};
   fs.writeFileSync(path.join(destination,manifestName),JSON.stringify(manifest,null,2)+'\n',{flag:'wx',mode:0o600});
   const signedProof={...proof,directory:destination,assets:assets.map(({asset_name,size,asset_sha256})=>({name:asset_name,size,sha256:asset_sha256}))};
   signedProofs.add(signedProof);return signedProof;
 } finally {fs.rmSync(stage,{recursive:true,force:true});}
}

// 正式上传只在本机签名成功且调用方完成最终确认后执行，资产和GitHub写入均按本产品验真。
async function localPublishRequest(token,path,{method='GET',body,size,send=fetch}={}) {
 const address=path.startsWith('https://')?new URL(path):new URL('https://api.github.com/repos/'+repository+'/'+path);
 if(!['api.github.com','uploads.github.com'].includes(address.hostname)||address.protocol!=='https:'
   ||address.username||address.password||address.hash||!address.pathname.startsWith('/repos/'+repository+'/'))
   throw Error('本产品GitHub发布地址无效');
 const response=await send(address.href,{method,redirect:'error',credentials:'omit',
   headers:{Authorization:'Bearer '+token,Accept:'application/vnd.github+json',
     'Content-Type':size?'application/octet-stream':'application/json',...(size?{'Content-Length':String(size)}:{}),'X-GitHub-Api-Version':'2026-03-10','User-Agent':product},
   ...(body===undefined?{}:{body:size?body:JSON.stringify(body)}),...(size?{duplex:'half'}:{}),signal:AbortSignal.timeout(180000)});
 if(response.status===404&&method==='GET')return null;
 if(!response.ok)throw Error('本产品GitHub发布请求失败：HTTP '+response.status);
 if(response.status===204)return {};
 if(!response.body)throw Error('本产品GitHub发布回执缺失');
 let count=0;const parts=[];for await(const part of response.body){count+=part.length;if(count>8*1024*1024)throw Error('本产品GitHub发布回执超限');parts.push(part);}
 try{return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(parts)));}
 catch{throw Error('本产品GitHub发布回执格式无效');}
}
async function localReadbackAsset(token,asset,expected,send) {
 const api='https://api.github.com/repos/'+repository+'/releases/assets/'+asset.id;
 if(asset.url!==api)throw Error('正式资产回读地址不一致');
 const options={method:'GET',redirect:'manual',credentials:'omit',headers:{Authorization:'Bearer '+token,
   Accept:'application/octet-stream','X-GitHub-Api-Version':'2026-03-10','User-Agent':product},signal:AbortSignal.timeout(180000)};
 let response=await send(api,options);
 if(response.status===302){const location=new URL(response.headers.get('location'));
   if(location.protocol!=='https:'||location.username||location.password||location.hash
     ||!/(?:^|\.)githubusercontent\.com$/u.test(location.hostname))throw Error('正式资产下载地址无效');
   await response.body?.cancel();response=await send(location.href,{method:'GET',redirect:'error',credentials:'omit',signal:AbortSignal.timeout(180000)});
 }
 if(!response.ok||!response.body)throw Error('正式资产回读失败');
 let count=0;const hash=createHash('sha256');for await(const part of response.body){count+=part.length;
   if(count>expected.size)throw Error('正式资产回读超过声明大小');hash.update(part);}
 if(count!==expected.size||hash.digest('hex')!==expected.sha256)throw Error('正式资产回读字节不一致');
}
export async function publishSigned(proof,token,{send=fetch,expiresAt}={}) {
 const fs=await import('node:fs'),path=await import('node:path');
 if(typeof token!=='string'||!/^ghs_[^\s\x00-\x1f\x7f]{1,2044}$/u.test(token)
   ||!Number.isSafeInteger(expiresAt)||expiresAt<=Date.now()/1000)throw Error('本产品正式发布短期授权无效');
 if(!proof||typeof proof!=='object'||!signedProofs.has(proof))throw Error('正式发布缺少本次本机签名验真回执');
 const platform=proof.platform,names=localSignedNames(platform),manifestName=product+'-release-'+platform+'.json';
 if(proof.product_id!==product||proof.tag!==`${product}-${platform}-v${proof.version}-r${proof.run_id}-a${proof.run_attempt}`
   ||!/^[0-9]+\.[0-9]+\.[0-9]+$/u.test(proof.version||'')||!/^[a-f0-9]{40}$/u.test(proof.source_sha||'')
   ||!Number.isSafeInteger(proof.run_id)||proof.run_id<1||!Number.isSafeInteger(proof.run_attempt)||proof.run_attempt<1
   ||typeof proof.directory!=='string'||!path.isAbsolute(proof.directory)
   ||fs.realpathSync(proof.directory)!==proof.directory||!fs.lstatSync(proof.directory).isDirectory()
   ||fs.readdirSync(proof.directory).sort().join('\0')!==[...names,manifestName].sort().join('\0'))
   throw Error('本产品正式发布候选身份或资产闭集无效');
 const manifest=JSON.parse(fs.readFileSync(path.join(proof.directory,manifestName),'utf8'));
 if(manifest.product_id!==product||manifest.version!==proof.version||manifest.github_run_number!==proof.run_number
   ||manifest.head_sha!==proof.source_sha||manifest.bundle_id!==localBundleID||manifest.package_name!==localPackageName
   ||!Array.isArray(manifest.assets)||manifest.assets.length!==names.length)throw Error('正式产物清单身份不一致');
 const rows=[];for(const name of [...names,manifestName]){
   const file=path.join(proof.directory,name),stat=localRegular(fs,file,2*1024**3);
   const digest=await localDigest(file),expected=proof.assets?.find(item=>item.name===name);
   if(name!==manifestName&&(!expected||expected.size!==stat.size||expected.sha256!==digest
      ||manifest.assets.filter(item=>item?.asset_name===name&&item.asset_sha256===digest).length!==1))
     throw Error('正式签名产物在上传前变化');
   rows.push({name,size:stat.size,sha256:digest,path:file});
 }
 const request=(target,options={})=>localPublishRequest(token,target,{...options,send});
 const run=await request('actions/runs/'+proof.run_id);
 if(run?.id!==proof.run_id||run.run_attempt!==proof.run_attempt||run.run_number!==proof.run_number
   ||run.head_sha!==proof.source_sha||run.status!=='completed'||run.conclusion!=='success'
   ||run.event!=='workflow_dispatch'||run.head_branch!=='main'||run.repository?.full_name!==repository
   ||String(run.path||'').split('@')[0]!=='.github/workflows/release-'+platform+'.yml')
   throw Error('正式发布前成功自动化身份变化');
 const recent=await request('actions/workflows/release-'+platform+'.yml/runs?branch=main&event=workflow_dispatch&status=completed&per_page=100&page=1');
 if(!Array.isArray(recent?.workflow_runs)||recent.workflow_runs.filter(value=>value?.conclusion==='success').sort((a,b)=>b.id-a.id)[0]?.id!==proof.run_id)
   throw Error('正式发布候选已被更新的成功自动化取代');
 if(await request('git/ref/tags/'+encodeURIComponent(proof.tag))!==null)throw Error('本次正式发布Tag已经存在');
 let createdTag=false,release=null;
 try{
   const reference=await request('git/refs',{method:'POST',body:{ref:'refs/tags/'+proof.tag,sha:proof.source_sha}});
   if(reference?.ref!=='refs/tags/'+proof.tag||reference.object?.sha!==proof.source_sha)throw Error('正式Tag创建未确认');
   createdTag=true;
   release=await request('releases',{method:'POST',body:{tag_name:proof.tag,target_commitish:proof.source_sha,
     name:`${product} · ${platform} · ${proof.version}`,draft:false,prerelease:false,make_latest:'false',
     body:`${product} · ${platform} · ${proof.version}\nSource: ${proof.source_sha}\nRun: ${proof.run_id} / ${proof.run_attempt}`}});
   if(!Number.isSafeInteger(release?.id)||release.id<1||typeof release.upload_url!=='string')throw Error('正式Release创建未确认');
   const uploaded=[];
   for(const item of rows){const url=new URL(release.upload_url.replace(/\{.*$/u,''));url.searchParams.set('name',item.name);
     const asset=await request(url.href,{method:'POST',body:fs.createReadStream(item.path),size:item.size});
     if(!Number.isSafeInteger(asset?.id)||asset.name!==item.name||asset.size!==item.size||asset.state!=='uploaded')
       throw Error('正式资产上传未确认');
     await localReadbackAsset(token,asset,item,send);uploaded.push(asset);
   }
   const current=await request('releases/'+release.id);
   if(current?.tag_name!==proof.tag||current.target_commitish!==proof.source_sha||current.draft||current.prerelease
     ||!Array.isArray(current.assets)||current.assets.length!==rows.length)throw Error('正式Release回查身份不一致');
   for(const item of rows){const asset=current.assets.find(value=>value.name===item.name);
     if(!asset||asset.size!==item.size||asset.state!=='uploaded'||asset.digest!=='sha256:'+item.sha256)
       throw Error('正式Release资产证明不一致');}
 }catch(error){
   const failures=[];
   if(release?.id)try{await request('releases/'+release.id,{method:'DELETE'});}catch(rollback){failures.push(rollback)}
   if(createdTag)try{await request('git/refs/tags/'+encodeURIComponent(proof.tag),{method:'DELETE'});}catch(rollback){failures.push(rollback)}
   if(failures.length)throw new AggregateError([error,...failures],'正式发布失败且撤销未全部确认');
   throw error;
 }
 // 仅新正式包逐件回读成功后清理同目标旧成功；清理失败保留新Release并报告准确坐标。
 try{const module=await import(new URL('../.github/workflows/release-'+platform+'.mjs',import.meta.url));
   await module.cleanup('success',{run_id:proof.run_id},request);
 }catch{throw Error('新正式Release已创建并验真，旧成功记录清理失败：'+proof.tag);}
 return {product_id:product,platform,tag:proof.tag,release_id:release.id,source_sha:proof.source_sha,run_id:proof.run_id};
}

// 发布候选必须来自本平台唯一保留的成功自动化；其它平台和未完成运行不参与选择。
async function verifyPublication({platform,runs,releases,readTag,readAsset}){
 const target=targets[platform];
 if(!target)fail('发布平台无效');
 if(!Array.isArray(runs)||!Array.isArray(releases)||typeof readTag!=='function'||typeof readAsset!=='function')
  fail('公开自动化输入无效');
 const owned=runs.filter(run=>run?.path===target.workflow&&run.head_branch==='main'
  &&run.event==='workflow_dispatch'&&run.repository?.full_name===repository);
 const success=owned.filter(run=>run.status==='completed'&&run.conclusion==='success');
 if(success.length!==1)fail('缺少唯一保留的成功自动化');
 const run=success[0];
 if(!positive(run.id)||!positive(run.run_attempt)||!positive(run.run_number)
  ||!sourceSHA(run.head_sha)||!Number.isFinite(Date.parse(run.created_at)))fail('成功自动化身份无效');
 const prefix=product+'-'+platform+'-v',suffix='-r'+run.id+'-a'+run.run_attempt;
 const matched=releases.filter(release=>typeof release?.tag_name==='string'
  &&release.tag_name.startsWith(prefix)&&release.tag_name.endsWith(suffix));
 if(matched.length!==1)fail('成功自动化缺少唯一正式Release');
 const release=matched[0],version=release.tag_name.slice(prefix.length,-suffix.length);
 if(!positive(release.id)||!/^\d+\.\d+\.\d+$/u.test(version)
  ||release.draft||release.prerelease||release.target_commitish!==run.head_sha
  ||!Array.isArray(release.assets))fail('正式Release身份无效');
 const tag=await readTag(release.tag_name);
 if(tag?.ref!=='refs/tags/'+release.tag_name||tag.object?.type!=='commit'
  ||tag.object.sha!==run.head_sha)fail('正式Tag与成功自动化提交不一致');
 const needed=[target.manifest,...target.binaries],assets=new Map();
 for(const name of needed){
  const found=release.assets.filter(asset=>asset?.name===name);
  if(found.length!==1)fail('正式资产缺失或重复：'+name);
  const asset=found[0];
  if(!positive(asset.id)||!positive(asset.size)||asset.state!=='uploaded'
    ||typeof asset.digest!=='string'||!asset.digest.startsWith('sha256:')
    ||!sha(asset.digest.slice(7)))fail('正式资产证明无效：'+name);
  let endpoint;try{endpoint=new URL(asset.url);}catch{fail('正式资产地址无效：'+name);}
  if(endpoint.protocol!=='https:'||endpoint.username||endpoint.password||endpoint.hash)
   fail('正式资产地址不是无凭据HTTPS：'+name);
  assets.set(name,asset);
 }
 const load=async(asset,{limit=asset.size,buffer=false}={})=>{
  const stream=await readAsset(asset);
  if(!stream||typeof stream[Symbol.asyncIterator]!=='function')fail('正式资产读取通道无效');
  const hash=createHash('sha256'),parts=[];let size=0;
  for await(const chunk of stream){
   if(!Buffer.isBuffer(chunk)&&!(chunk instanceof Uint8Array))fail('正式资产字节无效');
   size+=chunk.length;if(size>asset.size||size>limit)fail('正式资产超过声明大小');
   hash.update(chunk);if(buffer)parts.push(Buffer.from(chunk));
  }
  if(size!==asset.size||hash.digest('hex')!==asset.digest.slice(7))fail('正式资产回读与Release证明不一致');
  return buffer?Buffer.concat(parts):null;
 };
 const metadata=assets.get(target.manifest);
 const raw=await load(metadata,{limit:1024*1024,buffer:true});
 let manifest;try{manifest=JSON.parse(raw.toString('utf8'));}catch{fail('正式产物清单不是JSON');}
 if(manifest?.product_id!==product||manifest.version!==version
  ||manifest.github_run_number!==run.run_number||manifest.head_sha!==run.head_sha
  ||manifest.bundle_id!=='ios.citizenapp'||manifest.package_name!=='com.crcfrcn.citizenapp'
  ||!Array.isArray(manifest.assets)||manifest.assets.length!==target.binaries.length)
  fail('正式产物清单身份无效');
 const records=[];
 for(const name of target.binaries){
  const rows=manifest.assets.filter(value=>value?.asset_name===name);
  const asset=assets.get(name);
  if(rows.length!==1||rows[0].platform!==target.display||rows[0].asset_sha256!==asset.digest.slice(7))
   fail('正式产物清单与资产不一致');
  await load(asset);
  records.push({asset_id:asset.id,name,size:asset.size,sha256:asset.digest.slice(7)});
 }
 return {schema:1,product_id:product,platform,version,tag:release.tag_name,
  run_id:run.id,run_attempt:run.run_attempt,source_sha:run.head_sha,release_id:release.id,assets:records};
}

// 同文件回归只用合成GitHub公开回执与字节，不创建Tag、Release或商店交易。
if (process.env.NODE_TEST_CONTEXT&&process.argv.length===2&&process.argv[1]===import.meta.filename){
 const {test}=await import('node:test'),{default:assert}=await import('node:assert/strict');
 const {Readable}=await import('node:stream');
 const fixture=(platform='ios')=>{
  const target=targets[platform],head='a'.repeat(40),run={id:42,run_attempt:2,run_number:17,
   path:target.workflow,head_branch:'main',event:'workflow_dispatch',repository:{full_name:repository},
   status:'completed',conclusion:'success',head_sha:head,created_at:'2026-10-10T00:00:00Z'};
  const binaries=target.binaries.map((name,index)=>({name,body:Buffer.from('signed-'+name+'-'+index)}));
  const manifest={product_id:product,version:'1.2.3',github_run_number:17,head_sha:head,
   bundle_id:'ios.citizenapp',package_name:'com.crcfrcn.citizenapp',
   assets:binaries.map(value=>({platform:target.display,asset_name:value.name,asset_sha256:digest(value.body)}))};
  const all=[{name:target.manifest,body:Buffer.from(JSON.stringify(manifest))},...binaries];
  const assets=all.map((value,index)=>({id:index+1,name:value.name,size:value.body.length,
   state:'uploaded',digest:'sha256:'+digest(value.body),url:'https://api.example.invalid/assets/'+(index+1)}));
  const release={id:7,tag_name:product+'-'+platform+'-v1.2.3-r42-a2',target_commitish:head,
   draft:false,prerelease:false,assets};
  const body=new Map(all.map(value=>[value.name,value.body]));
  return {platform,runs:[run],releases:[release],readTag:async()=>({ref:'refs/tags/'+release.tag_name,
   object:{type:'commit',sha:head}}),readAsset:async asset=>Readable.from([body.get(asset.name)]),body};
 };
 test('只消费唯一成功自动化的正式产物并核对完整字节',async()=>{
  const input=fixture('ios'),result=await verifyPublication(input);
  assert.deepEqual({platform:result.platform,tag:result.tag,run_id:result.run_id,release_id:result.release_id,
   assets:result.assets.map(value=>value.name)},
   {platform:'ios',tag:input.releases[0].tag_name,run_id:42,release_id:7,assets:['citizenapp.ipa']});
  const android=await verifyPublication(fixture('android'));
  assert.deepEqual(android.assets.map(value=>value.name),['citizenapp.apk','citizenapp.aab']);
 });
 test('失败、重复、跨平台与漂移的自动化产物不能发布',async()=>{
  const base=fixture();
  await assert.rejects(verifyPublication({...base,runs:[]}),/唯一保留/);
  await assert.rejects(verifyPublication({...base,runs:[...base.runs,{...base.runs[0],id:43}]}),/唯一保留/);
  await assert.rejects(verifyPublication({...base,runs:[{...base.runs[0],path:targets.android.workflow}]}),/唯一保留/);
  await assert.rejects(verifyPublication({...base,releases:[{...base.releases[0],target_commitish:'b'.repeat(40)}]}),/身份/);
  await assert.rejects(verifyPublication({...base,readTag:async()=>null}),/Tag/);
  await assert.rejects(verifyPublication({...base,releases:[{...base.releases[0],assets:[]}]}),/资产/);
  await assert.rejects(verifyPublication({...base,releases:[{...base.releases[0],assets:base.releases[0].assets.map((asset,index)=>index?asset:{...asset,url:'http://api.example.invalid/asset'})}]}),/HTTPS/);
  await assert.rejects(verifyPublication({...base,readAsset:async()=>Readable.from([Buffer.from('changed')])}),/回读/);
  await assert.rejects(verifyPublication({...base,platform:'windows'}),/平台/);
 });
 test('公开发布入口自行读取完整分页且只发出读取请求',async()=>{
  const input=fixture(),calls=[];
  const request=async(path,options={})=>{
   assert.equal(options.method,undefined);calls.push(path);
   if(path.startsWith('actions/runs?'))return {workflow_runs:input.runs};
   if(path.startsWith('releases?'))return input.releases;
   if(path.startsWith('git/ref/tags/'))return input.readTag();
   const asset=input.releases[0].assets.find(value=>value.url===path);
   if(asset)return {body:await input.readAsset(asset)};
   throw Error('意外公开读取路径');
  };
  const result=await preparePublication({platform:'ios',request});
  assert.equal(result.release_id,7);assert.equal(result.assets[0].name,'citizenapp.ipa');
  assert.equal(calls.filter(path=>path.startsWith('actions/runs?')).length,1);
  assert.equal(calls.filter(path=>path.startsWith('releases?')).length,1);
  await assert.rejects(preparePublication({platform:'ios',request:async()=>({workflow_runs:'invalid'})}),/分页/);
 });
 test('产品签名需求与成功自动化未签名资产精确闭合',async()=>{
  const fs=await import('node:fs'),os=await import('node:os'),path=await import('node:path');
  for(const platform of ['android','ios']){
   const names=localNames(platform),refs=await signingConfiguration(platform);
   assert.equal(refs.length,platform==='android'?1:2);
   // macOS临时根可能含系统链接；夹具先取得真实目录，正式入口仍拒绝非规范路径。
   const directory=fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(),product+'-unsigned-fixture-')));
   try{
    const run={id:42,run_attempt:2,run_number:17,status:'completed',conclusion:'success',head_branch:'main',
      event:'workflow_dispatch',repository:{full_name:repository},head_sha:'a'.repeat(40),
      path:'.github/workflows/release-'+platform+'.yml'};
    const version='1.2.3',manifestName=product+'-unsigned-'+platform+'.json';
    const assets=[];
    for(const name of names){const bytes=Buffer.from('unsigned-'+name);fs.writeFileSync(path.join(directory,name),bytes);
      assets.push({name,size:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')});}
    const manifest={product_id:product,version,github_run_number:17,head_sha:run.head_sha,
      bundle_id:localBundleID,package_name:localPackageName,
      assets:assets.map(value=>({platform:platform==='ios'?'iOS':'Android',asset_name:value.name,asset_sha256:value.sha256}))};
    const manifestBytes=Buffer.from(JSON.stringify(manifest));fs.writeFileSync(path.join(directory,manifestName),manifestBytes);
    assets.push({name:manifestName,size:manifestBytes.length,sha256:createHash('sha256').update(manifestBytes).digest('hex')});
    const metadata={schema:1,repository,product_id:product,platform,source_sha:run.head_sha,run_id:42,
      run_number:17,run_attempt:2,workflow:run.path,version,tag:`${product}-${platform}-v${version}-r42-a2`,assets};
    fs.writeFileSync(path.join(directory,'automation.json'),JSON.stringify(metadata));
    assert.equal((await verifyUnsigned(platform,directory,run)).run_id,42);
    await assert.rejects(verifyUnsigned(platform,directory+'/.',run),/目录/u);
    fs.writeFileSync(path.join(directory,'unexpected'), 'extra');
    await assert.rejects(verifyUnsigned(platform,directory,run),/闭集/u);
    fs.rmSync(path.join(directory,'unexpected'));
    fs.writeFileSync(path.join(directory,names[0]),'tampered');
    await assert.rejects(verifyUnsigned(platform,directory,run),/字节不符/u);
   }finally{fs.rmSync(directory,{recursive:true,force:true});}
  }
  assert.deepEqual(testFiles(),['scripts/publish.mjs','.github/workflows/release-android.mjs','.github/workflows/release-ios.mjs']);
  assert.deepEqual(await testTools(),[]);
  for(const platform of ['ios','android'])assert.deepEqual((await localSource('./build.mjs')).contract.platforms[platform].tools.find(item=>item.id==='perl'),{id:'perl',version:'5.42.3'});
  const {vendorVolumeMatches}=await localSource('./build.mjs');
  const record={imageDev:1,imageIno:2,mountDev:3},identity={imageDev:1,imageIno:2,imageNlink:1,mountDev:3,parentDev:1};
  assert.equal(vendorVolumeMatches(record,identity),true);
  for(const changed of [{imageIno:9},{imageNlink:2},{mountDev:4},{parentDev:3}])assert.equal(vendorVolumeMatches(record,{...identity,...changed}),false);
  assert.equal(vendorVolumeMatches({...record,mountDev:null},identity),false);

  const buildSource=fs.readFileSync(new URL('./build.mjs',import.meta.url),'utf8');
  assert.match(buildSource,/sources:name==='own'\?owner\.lockedSources\(\):options\.sources/u);
  assert.match(buildSource,/sdk=\['citizen_sdk','tatachat_sdk'\]\.includes\(name\)/u);
  assert.match(buildSource,/cargoVendor:join\(work,'dependencies\/citizen_sdk\/cargo-vendor\/packages',name\)/u);
  assert.match(buildSource,/Android资源工程不属于当前任务/u);
  assert.match(buildSource,/xattr:'XATTR'/u);
  assert.match(buildSource,/xattr: '\/usr\/bin\/xattr'/u);
  assert.doesNotMatch(buildSource,/const projects=\[\];async function find/u);
  await assert.rejects(signingConfiguration('windows'),/平台/u);
  assert.deepEqual((await signingTools('android')).map(item=>item.id),['java','android','android-sdk']);
  assert.deepEqual((await signingTools('ios')).map(item=>item.id),['xcode']);
  for(const platform of ['android','ios'])await localCommand('bash',['-n','-c',localSigningSteps[platform]]);
  assert.equal((await localCommand('/usr/bin/printf',['ok'],{capture:true})).output,'ok');
  await assert.rejects(localCommand('/usr/bin/false',[]),/失败/u);
 });
 test('本机签名回执绑定正式上传，远端回读逐件验真',async()=>{
  const fs=await import('node:fs'),os=await import('node:os'),path=await import('node:path');
  const directory=fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(),product+'-signed-fixture-')));
  try{
   const platform='ios',name=product+'.ipa',manifestName=product+'-release-ios.json';
   const bytes=Buffer.from('signed-fixture'),digest=createHash('sha256').update(bytes).digest('hex');
   fs.writeFileSync(path.join(directory,name),bytes);
   const source='a'.repeat(40),tag=product+'-ios-v1.2.3-r42-a2';
   const manifest={product_id:product,version:'1.2.3',github_run_number:17,head_sha:source,
     bundle_id:localBundleID,package_name:localPackageName,
     assets:[{platform:'iOS',asset_name:name,asset_sha256:digest}]};
   fs.writeFileSync(path.join(directory,manifestName),JSON.stringify(manifest));
   const proof={product_id:product,platform,version:'1.2.3',tag,run_id:42,run_attempt:2,run_number:17,
     source_sha:source,directory,assets:[{name,size:bytes.length,sha256:digest}]};
   const token='ghs_synthetic',expiresAt=Math.floor(Date.now()/1000)+300;
   await assert.rejects(publishSigned(proof,token,{expiresAt,send:()=>assert.fail('未签名回执不得联网')}),/回执/u);
   signedProofs.add(proof);
   const api='https://api.github.com/repos/'+repository+'/',uploaded=new Map(),calls=[];let newer=false;
   const run={id:42,run_attempt:2,run_number:17,head_sha:source,status:'completed',conclusion:'success',
     event:'workflow_dispatch',head_branch:'main',repository:{full_name:repository},
     path:'.github/workflows/release-ios.yml',created_at:'2026-10-11T00:00:00Z'};
   const response=(value,status=200,headers={})=>new Response(value===null?null:JSON.stringify(value),{status,headers});
   const send=async(url,options)=>{const address=new URL(url),target=address.href;calls.push(options.method+' '+target);
     if(target.startsWith(api+'actions/workflows/release-ios.yml/runs?'))return response({workflow_runs:newer?[{...run,id:43},run]:[run]});
     if(target===api+'actions/runs/42')return response(run);
     if(target.startsWith(api+'actions/runs?'))return response({workflow_runs:[run]});
     if(target.startsWith(api+'releases?'))return response([]);
     if(target===api+'git/ref/tags/'+encodeURIComponent(tag))return response({message:'missing'},404);
     if(target===api+'git/refs'&&options.method==='POST')return response({ref:'refs/tags/'+tag,object:{sha:source}});
     if(target===api+'releases'&&options.method==='POST')return response({id:7,upload_url:'https://uploads.github.com/repos/'+repository+'/releases/7/assets{?name,label}'});
     if(address.hostname==='uploads.github.com'){
       const item=address.searchParams.get('name'),size=Number(options.headers['Content-Length']);
       assert.equal(size,fs.statSync(path.join(directory,item)).size);
       const asset={id:uploaded.size+1,name:item,size,state:'uploaded',url:api+'releases/assets/'+(uploaded.size+1),
         digest:'sha256:'+createHash('sha256').update(fs.readFileSync(path.join(directory,item))).digest('hex')};
       uploaded.set(asset.id,asset);return response(asset);
     }
     const asset=/releases\/assets\/(\d+)$/u.exec(address.pathname);
     if(asset&&address.hostname==='api.github.com')return new Response(null,{status:302,
       headers:{location:'https://release-assets.githubusercontent.com/fixture/'+asset[1]}});
     if(address.hostname==='release-assets.githubusercontent.com'){
       const item=uploaded.get(Number(address.pathname.split('/').at(-1)));
       return new Response(fs.readFileSync(path.join(directory,item.name)),{status:200});
     }
     if(target===api+'releases/7')return response({tag_name:tag,target_commitish:source,draft:false,prerelease:false,
       assets:[...uploaded.values()]});
     throw Error('意外模拟发布请求：'+target);
   };
   const properDirectory=proof.directory;proof.directory+='/.';
   await assert.rejects(publishSigned(proof,token,{send,expiresAt}),/身份或资产闭集/u);
   proof.directory=properDirectory;
   const result=await publishSigned(proof,token,{send,expiresAt});
   assert.equal(result.release_id,7);assert.equal(uploaded.size,2);
   assert.equal(calls.filter(value=>value.includes('uploads.github.com')).length,2);
   newer=true;await assert.rejects(publishSigned(proof,token,{send,expiresAt}),/取代/u);newer=false;
   fs.writeFileSync(path.join(directory,name),'tampered');
   await assert.rejects(publishSigned(proof,token,{send,expiresAt}),/变化/u);
  }finally{fs.rmSync(directory,{recursive:true,force:true});}
 });
}
