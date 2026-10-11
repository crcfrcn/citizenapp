#!/usr/bin/env node
// 本仓本目标的完整自动化只由同名Workflow调用；版本与产物均在GitHub生成。
import { createHash } from 'node:crypto';
import { spawnSync, execFileSync } from 'node:child_process';
import { appendFileSync, copyFileSync, createReadStream, existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { basename, dirname, isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const owner = Object.freeze({"product": "citizenapp", "platform": "android", "repository": "crcfrcn/citizenapp", "version_source": {"kind": "pubspec", "path": "pubspec.yaml"}, "required_assets": ["citizenapp-unsigned.apk", "citizenapp-unsigned.aab", "citizenapp-unsigned-android.json"], "asset_locations": ["$GITHUB_WORKSPACE/build/release"], "asset_patterns": ["*.apk", "*.aab", "*.zip", "*.json"], "required_patterns": ["citizenapp-unsigned.apk", "citizenapp-unsigned.aab", "citizenapp-unsigned-android.json"]});
// 本目标独立读取自身正式Release版本；发布流程只消费已完成的公开产物。
export async function citizenAppRelease(release,platform,readTag){
 if(platform!==owner.platform)fail('公民App发布平台无效');
 const prefix=owner.product+'-'+owner.platform+'-v';
 if(typeof release?.tag_name!=='string'||!release.tag_name.startsWith(prefix))return null;
 const mobile=release.tag_name.slice(prefix.length).split('-');
 if(mobile.length!==3||!/^\d+\.\d+\.\d+$/u.test(mobile[0])||!/^r[1-9]\d*$/u.test(mobile[1])||!/^a[1-9]\d*$/u.test(mobile[2]))fail('公民App移动版本Tag错误');
 const id=Number(mobile[1].slice(1)),attempt=Number(mobile[2].slice(1));
 if(!Number.isSafeInteger(id)||!Number.isSafeInteger(attempt))fail('公民App移动发布来源错误');
 const tag=release.tag_name,source=await readTag(tag);
 if(source?.ref!=='refs/tags/'+tag||source.object?.type!=='commit'||!/^[a-f0-9]{40}$/u.test(source.object.sha||''))fail('公民App发布Tag没有唯一源码提交');
 return {version:mobile[0],tag,run_id:id,run_attempt:attempt,source_sha:source.object.sha};
}

const shaPattern = /^[0-9a-f]{40}$/u;
const fail = message => { throw new Error(message); };
const root = fileURLToPath(new URL('../../', import.meta.url));
const workflowPath = `.github/workflows/release-${owner.platform}.yml`;
const prefix = `${owner.product}-${owner.platform}-v`;

export function context(environment = process.env) {
  const number = name => {
    const value = environment[name];
    if (!/^[1-9][0-9]*$/u.test(value || '') || !Number.isSafeInteger(Number(value))) fail('GitHub运行坐标无效');
    return Number(value);
  };
  if (environment.GITHUB_ACTIONS !== 'true' || environment.GITHUB_REPOSITORY !== owner.repository
    || environment.GITHUB_REF !== 'refs/heads/main' || environment.GITHUB_EVENT_NAME !== 'workflow_dispatch'
    || !shaPattern.test(environment.GITHUB_SHA || '')
    || environment.GITHUB_WORKFLOW_REF !== `${owner.repository}/${workflowPath}@refs/heads/main`) fail('所属GitHub运行身份无效');
  return { repository: owner.repository, product_id: owner.product, platform: owner.platform,
    source_sha: environment.GITHUB_SHA, run_id: number('GITHUB_RUN_ID'),
    run_number: number('GITHUB_RUN_NUMBER'), run_attempt: number('GITHUB_RUN_ATTEMPT'), workflow: workflowPath };
}

export async function request(path, { method = 'GET', body, raw = false, size, fetch: send = globalThis.fetch } = {}) {
  const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
  if (!token || /[\s\u0000-\u001f\u007f]/u.test(token)) fail('缺少GitHub任务令牌');
  const url = path.startsWith('https://') ? new URL(path) : new URL(`https://api.github.com/repos/${owner.repository}/${path}`);
  if (!['api.github.com', 'uploads.github.com'].includes(url.hostname) || url.protocol !== 'https:' || url.username || url.password || !url.pathname.startsWith(`/repos/${owner.repository}/`)) fail('GitHub接口地址无效');
  const headers = { Authorization: `Bearer ${token}`, Accept: raw ? 'application/octet-stream' : 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2026-03-10', 'User-Agent': owner.product };
  if (body !== undefined) headers['Content-Type'] = body?.pipe ? 'application/octet-stream' : 'application/json';
  if(body?.pipe){if(!Number.isSafeInteger(size)||size<=0)fail('资产上传长度无效');headers['Content-Length']=String(size);}
  let response = await send(url, { method, headers, redirect: raw ? 'manual' : 'error', signal: AbortSignal.timeout(300_000),
    ...(body === undefined ? {} : { body: body?.pipe ? body : JSON.stringify(body), ...(body?.pipe ? { duplex: 'half' } : {}) }) });
  if(raw&&response.status===302){
    const location=new URL(response.headers.get('location'));
    if(location.protocol!=='https:'||location.username||location.password)fail('正式资产回读地址无效');
    response=await send(location,{method:'GET',redirect:'error',credentials:'omit',signal:AbortSignal.timeout(300_000)});
  }
  if (response.status === 404) return null;
  if (!response.ok) fail(`GitHub接口失败：${response.status}，操作未确认`);
  if (raw) return response;
  return response.status === 204 ? {} : response.json();
}

export async function pages(path, field = null, api = request) {
  const rows = [];
  for (let page = 1; ; page++) {
    const data = await api(`${path}${path.includes('?') ? '&' : '?'}per_page=100&page=${page}`);
    const values = field ? data?.[field] : data;
    if (!Array.isArray(values)) fail('GitHub分页数据无效');
    rows.push(...values);
    if (values.length < 100) return rows;
  }
}

function seedVersion() {
  const source = owner.version_source;
  if (source.kind === 'sequence') return '0.0.0';
  const text = readFileSync(join(root, source.path), 'utf8');
  if (source.kind === 'json') return String(JSON.parse(text).version);
  if (source.kind === 'spec') {
    const matches = [...text.matchAll(/^\s*spec_version:\s*(\d+)\s*,\s*$/gm)];
    if (matches.length !== 1) fail('Runtime版本真源不唯一');
    return matches[0][1];
  }
  if (source.kind === 'cargo') {
    const value = /^\[package\][\s\S]*?^version\s*=\s*"(\d+\.\d+\.\d+)"/mu.exec(text)?.[1];
    if (!value) fail('本仓Cargo版本真源无效');
    return value;
  }
  const value = /^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$/mu.exec(text)?.[1];
  if (!value) fail('本仓软件版本真源无效');
  return value;
}

export function nextVersion(seed, versions, protocol = false, runNumber = 1) {
  if (protocol) {
    if (!/^\d+$/u.test(seed) || versions.some(value => !/^\d+$/u.test(value))) fail('协议版本无效');
    const value = Math.max(Number(seed), ...versions.map(Number)) + (versions.length ? 1 : 0);
    if (!Number.isSafeInteger(value) || value < 1 || value > 0xffffffff) fail('协议版本越界');
    return String(value);
  }
  const parse = value => {
    const match = /^(0|[1-9]\d*)\.(0|[1-9]\d?)\.(0|[1-9]\d?)$/u.exec(value);
    if (!match) fail('软件版本无效');
    const parts=match.slice(1).map(Number);if(parts.some(value=>!Number.isSafeInteger(value)))fail('软件版本越界');return parts;
  };
  const values = [seed, ...versions].map(parse).sort((a,b) => a[0]-b[0] || a[1]-b[1] || a[2]-b[2]);
  let [major, minor, patch] = values.at(-1);
  if (versions.length) { if (++patch > 99) { patch = 0; if (++minor > 99) { minor = 0; major++; } } }
  if(!Number.isSafeInteger(runNumber)||runNumber<1)fail('版本运行序号无效');
  const initial=parse(seed),floor=BigInt(initial[0])*10000n+BigInt(initial[1])*100n+BigInt(initial[2])+BigInt(runNumber-1);
  const historical=BigInt(major)*10000n+BigInt(minor)*100n+BigInt(patch);
  if(floor>historical){major=Number(floor/10000n);minor=Number(floor/100n%100n);patch=Number(floor%100n);}
  if(![major,minor,patch].every(Number.isSafeInteger))fail('软件版本越界');
  return `${major}.${minor}.${patch}`;
}

function output(name, value, file = process.env.GITHUB_OUTPUT) {
  if (!file || /[\r\n]/u.test(String(value))) fail('GitHub步骤输出无效');
  appendFileSync(file, `${name}=${value}\n`);
}

export async function prepare() {
  const identity = context();
  const releases = await pages('releases');
  const versions = [];
  for (const release of releases) {
    if (release.draft || release.prerelease || !String(release.tag_name).startsWith(prefix)) continue;
    const notes = (await citizenAppRelease(release,owner.platform,tag=>request('git/ref/tags/'+encodeURIComponent(tag))));
    if (!notes || notes.platform !== owner.platform) continue;
    const run = await request(`actions/runs/${notes.run_id}`);
    if (run?.status === 'completed' && run.conclusion === 'success' && run.path === workflowPath) versions.push(notes.version);
  }
  const version = nextVersion(seedVersion(), versions, owner.version_source.kind === 'spec', identity.run_number);
  const tag = `${prefix}${version}-r${identity.run_id}-a${identity.run_attempt}`;
  for (const [name,value] of Object.entries({version, tag, source_sha:identity.source_sha,
    run_id:identity.run_id, run_attempt:identity.run_attempt, run_number:identity.run_number})) output(name,value);
}

function runVersion(environment=process.env) {
  const identity = context(environment);
  const version = environment.RELEASE_VERSION;
  const tag = environment.RELEASE_TAG;
  nextVersion(version, [], owner.version_source.kind === 'spec');
  if (tag !== `${prefix}${version}-r${identity.run_id}-a${identity.run_attempt}`) fail('本次版本与Tag不一致');
  return {...identity, version, tag};
}

export function job() {
  const identity = runVersion();
  if (execFileSync('git', ['rev-parse','HEAD'], {cwd:root,encoding:'utf8'}).trim() !== identity.source_sha) fail('检出源码不符');
  const work = join(process.env.RUNNER_TEMP, owner.product, owner.platform, String(identity.run_id), String(identity.run_attempt), process.env.GITHUB_JOB);
  mkdirSync(work,{recursive:true});
  const variables = {RELEASE_WORK:work, RELEASE_ASSETS_DIR:join(work,'assets'),
    CARGO_HOME:join(work,'cargo-home'), CARGO_TARGET_DIR:join(work,'cargo'), PUB_CACHE:join(work,'pub'),
    GRADLE_USER_HOME:join(work,'gradle'), npm_config_cache:join(work,'npm'), XDG_CACHE_HOME:join(work,'cache'),
    TMPDIR:join(work,'tmp'), TMP:join(work,'tmp'), TEMP:join(work,'tmp')};
  for (const path of ['cargo-home','cargo','pub','gradle','npm','cache','tmp','assets']) mkdirSync(join(work,path),{recursive:true});
  for (const [name,value] of Object.entries(variables)) { process.env[name]=value; output(name,value,process.env.GITHUB_ENV); }
}

// 自动化拥有正式Run的公开资产清单；Build只交付未经正式签名的完整包。
function createAutomationManifest(identity=runVersion(),directory=join(root,'build/release')){
 if(!/^\d+\.\d+\.\d+$/u.test(identity?.version||'')||!Number.isSafeInteger(identity.run_number)||identity.run_number<=0
  ||!/^[a-f0-9]{40}$/u.test(identity.source_sha||''))fail('正式资产Run身份无效');
 if(!isAbsolute(directory||'')||!lstatSync(directory,{throwIfNoEntry:false})?.isDirectory()
  ||lstatSync(directory).isSymbolicLink())fail('正式资产目录无效');
 const binaries=["citizenapp-unsigned.apk","citizenapp-unsigned.aab"],assets=binaries.map(name=>{
  const path=join(directory,name);regular(path);
  return {platform:'Android',asset_name:name,asset_sha256:createHash('sha256').update(readFileSync(path)).digest('hex')};
 });
 const name='citizenapp-unsigned-android.json',output=join(directory,name);
 if(readdirSync(directory).sort().join('\0')!==binaries.slice().sort().join('\0'))fail('本次自动化资产集合不完整');
 if(existsSync(output))fail('本次自动化清单已存在');
 const manifest={product_id:'citizenapp',version:identity.version,github_run_number:identity.run_number,
  head_sha:identity.source_sha,bundle_id:'ios.citizenapp',package_name:'com.crcfrcn.citizenapp',assets};
 writeFileSync(output,JSON.stringify(manifest,null,2)+'\n',{flag:'wx',mode:0o600});
 if(readdirSync(directory).sort().join('\0')!==[...binaries,name].sort().join('\0'))fail('本次自动化资产集合不完整');
}

const automationBuildSteps=Object.freeze({"1":{"shell":"bash","source":"test \"$(git rev-parse HEAD)\" = \"$CITIZENAPP_BUILD_SOURCE_SHA\"\npython3 - <<'PY'\nimport os, re\nfrom pathlib import Path\nversion, build = os.environ[\"CITIZENAPP_BUILD_VERSION\"], os.environ[\"CITIZENAPP_BUILD_NUMBER\"]\nif not re.fullmatch(r\"\\d+\\.\\d{1,2}\\.\\d{1,2}\", version) or not re.fullmatch(r\"[1-9]\\d*\", build):\n    raise SystemExit(\"CitizenApp 本次版本输入无效\")\npath = Path(\"pubspec.yaml\")\ntext, count = re.subn(r\"(?m)^version:\\s*\\d+\\.\\d+\\.\\d+\\+\\d+\\s*$\", f\"version: {version}+{build}\", path.read_text(), count=1)\nif count != 1: raise SystemExit(\"CitizenApp pubspec 版本真源无效\")\npath.write_text(text)\nPY"},"2":{"shell":"bash","source":"# 版本只读受控工具登记，不读取产品依赖合同中的副本。\nprintf 'version=3.47.2\n' >> \"$CITIZENAPP_BUILD_OUTPUT\""},"3":{"shell":"bash","source":"# 安装后先验真，再统一准备目标平台缓存与受控修订。\nflutter --version --machine >/dev/null\nplatform=\"android\"\nflutter --version >/dev/null"},"4":{"shell":"bash","source":"sdkmanager \"platforms;android-36\" \"build-tools;37.0.1\" \"platform-tools\" \"cmdline-tools;22.0\" \"ndk;28.2.13676358\" \"cmake;3.31.6\""},"5":{"shell":"bash","source":"set -euo pipefail\nwork=\"$CITIZENAPP_BUILD_TEMP/citizenapp-android-view-$CITIZENAPP_BUILD_ID-$CITIZENAPP_BUILD_ATTEMPT\"\nmkdir -p \"$work\"\nwork=\"$(cd \"$work\" && pwd -P)\"\npython3 - \"$work\" android <<'PYVIEW'\nfrom pathlib import Path\nimport json,os,re,shutil,stat,subprocess,sys\nwork=Path(sys.argv[1]).resolve(strict=True); platform=sys.argv[2]\nsource=Path(os.environ['CITIZENAPP_SOURCE_ROOT']).resolve(strict=True)\nrunner=Path(os.environ['RUNNER_TEMP']).resolve(strict=True)\nif platform not in ('android','ios') or not work.is_relative_to(runner): raise SystemExit('自动化工程归属无效')\nmanifest=(source/'pubspec.yaml').read_text(); locked=(source/'pubspec.lock').read_text()\nif (source/'pubspec_overrides.yaml').exists(): raise SystemExit('源码存在Pub覆盖文件')\ndef block(text,name):\n    lines=text.splitlines(keepends=True)\n    starts=[i for i,line in enumerate(lines) if line==f'  {name}:\\n']\n    if len(starts)!=1: raise SystemExit('第一方依赖登记缺失或重复')\n    a=starts[0];b=next((i for i in range(a+1,len(lines)) if re.fullmatch(r'  [A-Za-z0-9_]+:\\n',lines[i]) or re.fullmatch(r'[A-Za-z_]+:\\n',lines[i])),len(lines))\n    return ''.join(lines[a:b])\ndef field(text,name):\n    found=re.findall(rf'^\\s+{re.escape(name)}:\\s*[\"\\']?([^\"\\'\\s]+)',text,re.M)\n    if len(found)!=1: raise SystemExit('第一方依赖字段无效：'+name)\n    return found[0]\nproject=work/'project'\nif project.exists(): raise SystemExit('自动化工程已存在')\nproject.mkdir()\nfor raw in filter(None,subprocess.check_output(['git','ls-files','-z'],cwd=source).split(b'\\0')):\n    name=raw.decode('utf8')\n    if any(part in ('.','..') for part in Path(name).parts): raise SystemExit('Git源码路径越界')\n    original=source/name;destination=project/name\n    if original.is_symlink() or not original.is_file(): raise SystemExit('Git源码文件类型无效')\n    destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(original,destination)\nfor old,new in (('ios/project/Runner.xcscheme','ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme'),('ios/project/RunnerUITests.xcscheme','ios/Runner.xcodeproj/xcshareddata/xcschemes/RunnerUITests.xcscheme'),('android/gradle-wrapper.properties','android/gradle/wrapper/gradle-wrapper.properties')):\n    origin=project/old;destination=project/new\n    if not origin.is_file() or destination.exists(): raise SystemExit('平台输入缺失或重复')\n    destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(origin,destination)\nif platform=='android':\n    flutter=os.environ.get('FLUTTER_ROOT') or str(Path(shutil.which('flutter')).resolve().parents[1])\n    wrapper=Path(flutter)/'bin/cache/artifacts/gradle_wrapper'\n    for name in ('gradlew','gradlew.bat','gradle/wrapper/gradle-wrapper.jar'):\n        origin=wrapper/name;destination=project/'android'/name\n        if not origin.is_file() or origin.is_symlink() or destination.exists(): raise SystemExit('Flutter Wrapper无效')\n        destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(origin,destination)\n        if name=='gradlew':destination.chmod(destination.stat().st_mode|stat.S_IXUSR)\nviews={}\nfor name,url in (('citizen_sdk','https://github.com/crcfrcn/citizensdk.git'),('tatachat_sdk','https://github.com/tuyutata/tatachatsdk.git')):\n    declared=block(manifest,name);record=block(locked,name);sha=field(declared,'ref')\n    if not re.fullmatch(r'[0-9a-f]{40}',sha) or field(declared,'url')!=url or field(declared,'path')!='.' or any(field(record,key)!=value for key,value in (('ref',sha),('resolved-ref',sha),('url',url),('source','git'))):raise SystemExit('第一方原锁不符')\n    checkout=work/'git-sources'/name;checkout.parent.mkdir(parents=True,exist_ok=True);checkout.mkdir()\n    def git(*args):return subprocess.check_output(['git','-c','credential.helper=','-c','core.hooksPath=/dev/null',*args],cwd=checkout,text=True).strip()\n    git('init','--quiet');git('remote','add','origin',url);git('fetch','--no-tags','--depth=1','origin',sha);git('checkout','--quiet','--detach',sha)\n    if git('rev-parse','HEAD')!=sha or git('remote','get-url','origin')!=url or git('status','--porcelain=v1','--untracked-files=all'):raise SystemExit('第一方检出漂移')\n    view=work/'views'/name;view.parent.mkdir(parents=True,exist_ok=True)\n    entry=checkout/'scripts/build.mjs'\n    if not entry.is_file() or entry.is_symlink():raise SystemExit('固定SDK缺少Build入口')\n    js=\"import {pathToFileURL} from 'node:url';const m=await import(pathToFileURL(process.argv[1]).href);if(typeof m.createFlutterSourceView!=='function')throw Error('固定SDK缺少编译视图接口');await m.createFlutterSourceView(process.argv[2],process.argv[3]);\"\n    subprocess.run(['node','--input-type=module','-e',js,str(entry),str(checkout),str(view)],check=True)\n    views[name]={'source':str(checkout),'view':str(view)}\n(project/'pubspec_overrides.yaml').write_text('dependency_overrides:\\n'+''.join(f'  {name}:\\n    path: {json.dumps(value[\"view\"])}\\n' for name,value in views.items()))\nshutil.copy2(project/'pubspec.lock',work/'lock-before')\n(work/'view.json').write_text(json.dumps({'project':str(project),'sdk_source':views['citizen_sdk']['source'],'sdk_view':views['citizen_sdk']['view']}))\nPYVIEW\nproject=\"$(node -e 'const r=require(process.argv[1]);process.stdout.write(r.project)' \"$work/view.json\")\" \nexport CITIZENAPP_PROJECT_ROOT=\"$project\"\nprintf 'CITIZENAPP_PROJECT_ROOT=%s\\n' \"$project\" >> \"$CITIZENAPP_BUILD_ENVIRONMENT\"\nset -euo pipefail\nnative_root=\"$CITIZENAPP_BUILD_TEMP/citizenapp-citizensdk-$CITIZENAPP_BUILD_ID-$CITIZENAPP_BUILD_ATTEMPT\"\nexport CITIZENSDK_WORK_DIR=\"$native_root/work\"\nexport CITIZENSDK_NATIVE_OUTPUT_DIR=\"$native_root/output\"\nexport CITIZENSDK_GRADLE=\"$CITIZENAPP_PROJECT_ROOT/android/gradlew\"\nmkdir -p \"$native_root/flutter-build\"\ntest ! -e build && test ! -L build\nln -s \"$native_root/flutter-build\" build\nsdk_source=\"$(node -e 'const r=require(process.argv[1]);process.stdout.write(r.sdk_source)' \"$work/view.json\")\"\nnode \"$sdk_source/scripts/build.mjs\" native android\n{\n  printf 'CITIZENSDK_ANDROID_CORE_DIR=%s\n' \"$CITIZENSDK_NATIVE_OUTPUT_DIR/android/arm64-v8a\"\n  printf 'CITIZENSDK_ANDROID_BUILD_DIR=%s\n' \"$native_root/flutter-plugin\"\n  printf 'CITIZENSDK_NATIVE_OUTPUT_DIR=%s\n' \"$CITIZENSDK_NATIVE_OUTPUT_DIR\"\n} >> \"$CITIZENAPP_BUILD_ENVIRONMENT\""},"6":{"shell":"bash","source":"set -euo pipefail\nproject=\"$CITIZENAPP_PROJECT_ROOT\"\nbuild=\"$(cd \"$CITIZENAPP_SOURCE_ROOT/build\" && pwd -P)\"\nln -s \"$build\" \"$project/build\"\nexport CITIZENAPP_PROJECT_ROOT=\"$project\" CITIZENAPP_BUILD_DIR=\"$build\"\n(cd \"$project\" && flutter pub get)\npython3 - \"$CITIZENAPP_BUILD_TEMP/citizenapp-android-view-$CITIZENAPP_BUILD_ID-$CITIZENAPP_BUILD_ATTEMPT/lock-before\" \"$project/pubspec.lock\" <<'PYLOCK'\nfrom pathlib import Path\nimport re,sys\ndef normalized(path):\n    lines=Path(path).read_text().splitlines(keepends=True)\n    for name in ('citizen_sdk','tatachat_sdk'):\n        found=[i for i,line in enumerate(lines) if line==f'  {name}:\\n']\n        if len(found)!=1:raise SystemExit('Pub第一方依赖缺失')\n        a=found[0];b=next((i for i in range(a+1,len(lines)) if re.fullmatch(r'  [A-Za-z0-9_]+:\\n',lines[i]) or re.fullmatch(r'[A-Za-z_]+:\\n',lines[i])),len(lines))\n        lines[a:b]=[f'  {name}:\\n','    视图已验真\\n']\n    return ''.join(lines)\nif normalized(sys.argv[1])!=normalized(sys.argv[2]):raise SystemExit('Pub改变非第一方原锁')\nPYLOCK\n{\n  printf 'CITIZENAPP_PROJECT_ROOT=%s\\n' \"$project\"\n  printf 'CITIZENAPP_BUILD_DIR=%s\\n' \"$build\"\n} >> \"$CITIZENAPP_BUILD_ENVIRONMENT\""},"7":{"shell":"bash","source":"cd \"$CITIZENAPP_PROJECT_ROOT\"\nflutter build apk --release --target-platform android-arm64\nflutter build appbundle --release --target-platform android-arm64"},"8":{"shell":"bash","source":"set -euo pipefail\nverify_archive() {\n  local archive=\"$1\" prefix=\"$2\" entries library path\n  entries=\"$(unzip -Z1 \"$archive\")\"\n  for library in libcitizensdk.so libcitizensdk_jni.so; do\n    path=\"$prefix/arm64-v8a/$library\"\n    test \"$(printf '%s\\n' \"$entries\" | grep -Fxc \"$path\")\" = 1\n    cmp -s <(unzip -p \"$archive\" \"$path\") \\\n      \"$CITIZENSDK_NATIVE_OUTPUT_DIR/android/arm64-v8a/$library\"\n  done\n  ! printf '%s\\n' \"$entries\" | grep -Eq '(^|/)libsmoldot[.]so$'\n}\nverify_archive build/app/outputs/flutter-apk/app-release.apk lib\nverify_archive build/app/outputs/bundle/release/app-release.aab base/lib"},"9":{"shell":"bash","source":"set -euo pipefail\npython3 - \"$CITIZENAPP_SOURCE_ROOT/build/app/outputs/flutter-apk/app-release.apk\" <<'PYVERIFY'\nfrom pathlib import Path\nimport os,re,subprocess,sys\napk=Path(sys.argv[1])\nif not apk.is_file() or apk.is_symlink():raise SystemExit('Android正式APK无效')\nsdk=Path(os.environ['ANDROID_HOME'])\ntools=[p for p in (sdk/'build-tools').glob('*/aapt2') if p.is_file() and os.access(p,os.X_OK)]\nif not tools:raise SystemExit('缺少已安装Android aapt2')\ntool=max(tools,key=lambda p:tuple(int(x) for x in p.parent.name.split('.')))\ntext=subprocess.check_output([str(tool),'dump','resources',str(apk)],text=True)\nmatch=re.search(r'resource 0x[0-9a-f]+ string/app_name\\n(?P<body>(?:      .*\\n)+?)    resource ',text)\nif not match or '() \"公民\"' not in match.group('body') or '(en) \"CitizenApp\"' not in match.group('body'):\n    raise SystemExit('Android最终包中英文产品名无效')\nPYVERIFY"},"10":{"shell":"bash","source":"set -euo pipefail\npublish=\"build/release\"\ntest ! -e \"$publish\"\nmkdir -p \"$publish\"\ncp build/app/outputs/flutter-apk/app-release.apk \"$publish/citizenapp-unsigned.apk\"\ncp build/app/outputs/bundle/release/app-release.aab \"$publish/citizenapp-unsigned.aab\"\ntest -s \"$publish/citizenapp-unsigned.apk\"\ntest -s \"$publish/citizenapp-unsigned.aab\"\nif \"$ANDROID_HOME/build-tools/37.0.1/apksigner\" verify \"$publish/citizenapp-unsigned.apk\" >/dev/null 2>&1; then\n  echo '未签名APK意外包含有效签名' >&2; exit 1\nfi\nif keytool -printcert -jarfile \"$publish/citizenapp-unsigned.aab\" >/dev/null 2>&1; then\n  echo '未签名AAB意外包含有效签名' >&2; exit 1\nfi"}});
// 本平台自动化独立拥有正式编译和未签名组包步骤。
export function step(key,{environment:input=process.env,execute=spawnSync}={}) {
  const identity=runVersion(input);
  if (!/^[1-9][0-9]*$/u.test(String(key))) fail('本目标构建步骤无效');
  if(String(key)==='11'){createAutomationManifest(identity,join(root,'build/release'));return;}
  const environment={...input,CITIZENAPP_SOURCE_ROOT:resolve(root),
    CITIZENAPP_BUILD_SOURCE_SHA:identity.source_sha,CITIZENAPP_BUILD_VERSION:identity.version,
    CITIZENAPP_BUILD_ID:String(identity.run_id),CITIZENAPP_BUILD_ATTEMPT:String(identity.run_attempt),
    CITIZENAPP_BUILD_NUMBER:String(identity.run_number),CITIZENAPP_BUILD_TEMP:input.RUNNER_TEMP,
    CITIZENAPP_BUILD_WORK:input.RELEASE_WORK,CITIZENAPP_BUILD_ENVIRONMENT:input.GITHUB_ENV,
    CITIZENAPP_BUILD_OUTPUT:input.GITHUB_OUTPUT};
  // GitHub授权只归自动化；编译接收产品输入和当前工具、签名材料，不继承GitHub令牌。
  for(const name of Object.keys(environment))if(name.startsWith('GITHUB_')||name.startsWith('ACTIONS_')||name.startsWith('RUNNER_')||['GH_TOKEN','GH_TOKEN_FILE'].includes(name))delete environment[name];
  const source=automationBuildSteps[String(key)]?.source;
  if(typeof source!=='string'||!source)fail('本平台自动化编译步骤未登记');
  const result=execute('bash',['--noprofile','--norc','-e','-o','pipefail','-c',source,'citizenapp-release-step'],
    {cwd:root,env:environment,stdio:'inherit'});
  if(result.error||result.signal||result.status!==0)fail(`本仓构建步骤失败：${key}`);
}

function regular(path) {
  const stat=lstatSync(path);if(!stat.isFile()||stat.isSymbolicLink()||stat.size<=0)fail('正式产物不是非空普通文件');return stat;
}
async function digestFile(path) { const hash=createHash('sha256');for await(const bytes of createReadStream(path))hash.update(bytes);return hash.digest('hex'); }
function assetName(name) { if(!name||name!==basename(name)||/[\u0000-\u001f\u007f]/u.test(name))fail('正式资产文件名无效');return name; }

export async function collect(paths) {
  const identity=runVersion(),destination=process.env.RELEASE_ASSETS_DIR;
  if(!destination||!paths.length)fail('本仓没有完整产物');mkdirSync(destination,{recursive:true});
  const files=[];
  for(const path of paths){const file=resolve(path),stat=regular(file),name=assetName(basename(file));
    if(files.some(row=>row.name===name))fail('正式资产重名');
    const target=join(destination,name);if(file!==target)copyFileSync(file,target);
    files.push({name,size:stat.size,sha256:await digestFile(target)});
  }
  if(owner.required_assets.some(name=>!files.some(row=>row.name===name)))fail('本目标必要产物缺失');
  const metadata={schema:1,...identity,assets:files};
  writeFileSync(join(destination,'automation.json'),JSON.stringify(metadata,null,2)+'\n');
  output('assets',destination);return metadata;
}

export async function collectProduced() {
  const paths=[],seen=new Set();
  const expand=value=>value.replace(/\$\{([A-Z_]+)\}|\$([A-Z_]+)/gu,(_,a,b)=>process.env[a||b]||'');
  for(const location of owner.asset_locations){
    const path=expand(location);if(!path||!existsSync(path))continue;
    const candidates=lstatSync(path).isDirectory()?readdirSync(path).map(name=>join(path,name)):[path];
    for(const candidate of candidates){if(!lstatSync(candidate).isFile()||seen.has(resolve(candidate)))continue;
      const name=basename(candidate);if(!owner.asset_patterns.some(pattern=>new RegExp('^'+pattern.replace(/[.+?^${}()|[\]\\]/gu,'\\$&').replaceAll('*','.*')+'$','u').test(name)))continue;
      seen.add(resolve(candidate));paths.push(candidate);
    }
  }
  if(owner.required_patterns.some(pattern=>!paths.some(path=>new RegExp('^'+pattern.replace(/[.+?^${}()|[\]\\]/gu,'\\$&').replaceAll('*','.*')+'$','u').test(basename(path)))))fail('本目标完整正式资产缺失');
  return collect(paths);
}



function ownedRun(run) {
  // 每个目标只处理自身现行Workflow；文件缺失不能证明历史任务归属。
  return Number.isSafeInteger(run?.id)&&run.id>0&&run.path===workflowPath
    &&run.head_branch==='main'&&run.event==='workflow_dispatch'
    &&(!run.repository||run.repository.full_name===owner.repository);
}

export function cleanupPlan(runs,current,result) {
  if(!['success','failed'].includes(result)||!ownedRun(current)||!Number.isFinite(Date.parse(current.created_at)))fail('清理所属任务身份无效');
  const earlier=run=>Date.parse(run.created_at)<Date.parse(current.created_at)
    ||Date.parse(run.created_at)===Date.parse(current.created_at)&&run.id<current.id;
  return runs.filter(run=>ownedRun(run)&&run.id!==current.id&&run.status==='completed'&&earlier(run)
    &&(run.conclusion==='success'?'success':'failed')===result).sort((a,b)=>a.id-b.id);
}

async function remove(path,api) { await api(path,{method:'DELETE'});const readPath=path.replace(/^git\/refs\//u,'git/ref/');if(await api(readPath)!==null)fail('删除回查仍存在，清理失败'); }
async function removeRunRelease(run,releases,api) {
  for(const release of releases){
    const metadata=(await citizenAppRelease(release,owner.platform,tag=>api('git/ref/tags/'+encodeURIComponent(tag))));
    if(!metadata||metadata.run_id!==run.id)continue;
    if(metadata.source_sha!==run.head_sha)fail('正式Release与所属Run不一致');
    const tag=metadata.tag;
    const again=await api(`actions/runs/${run.id}`);
    if(again&&again.id!==Number(process.env.GITHUB_RUN_ID)
      &&(again.status!=='completed'||again.run_attempt!==run.run_attempt||again.conclusion!==run.conclusion))fail('所属任务已变化，停止清理');
    await remove(`releases/${release.id}`,api);
    const beforeTag=await api(`actions/runs/${run.id}`);
    if(beforeTag&&beforeTag.id!==Number(process.env.GITHUB_RUN_ID)
      &&(beforeTag.status!=='completed'||beforeTag.run_attempt!==run.run_attempt||beforeTag.conclusion!==run.conclusion))fail('所属任务已变化，停止清理');
    await remove(`git/refs/tags/${encodeURIComponent(tag)}`,api);
  }
}
export async function cleanup(result,identity=context(),api=request) {
  const current=await api(`actions/runs/${identity.run_id}`);
  const plan=cleanupPlan(await pages('actions/runs','workflow_runs',api),current,result);
  const releases=await pages('releases',null,api),removed=[];
  for(const row of plan){const run=await api(`actions/runs/${row.id}`);if(!run){removed.push(row.id);continue;}
    if(run.run_attempt!==row.run_attempt||cleanupPlan([run],current,result).length!==1)continue;
    await removeRunRelease(run,releases,api);
    // 失败若只形成Tag也按它的准确Run坐标处理，不能留下同类孤立产物。
    const tags=await api(`git/matching-refs/tags/${prefix}`);
    if(!Array.isArray(tags))fail('所属Tag集合无效');
    for(const reference of tags){
      const tag=String(reference.ref||'').slice('refs/tags/'.length);
      if(!String(reference.ref||'').startsWith('refs/tags/'+prefix)
        ||!new RegExp(`-r${run.id}-a[1-9][0-9]*$`,'u').test(tag)||Number(tag.slice(tag.lastIndexOf('-a')+2))>run.run_attempt)continue;
      if(reference.object?.type!=='commit'||reference.object.sha!==run.head_sha)fail('所属Tag来源已改变，停止清理');
      const again=await api(`actions/runs/${run.id}`);
      if(!again||cleanupPlan([again],current,result).length!==1)fail('所属任务已改变，停止清理');
      await remove(`git/refs/tags/${encodeURIComponent(tag)}`,api);
    }
    for(const asset of await pages(`actions/runs/${run.id}/artifacts`,'artifacts',api)){
      if(!Number.isSafeInteger(asset.id)||asset.id<=0)fail('所属Artifact坐标无效');
      const again=await api(`actions/runs/${run.id}`);if(!again||again.status!=='completed'||again.run_attempt!==run.run_attempt||again.conclusion!==run.conclusion)fail('历史任务已变化，停止清理');
      await remove(`actions/artifacts/${asset.id}`,api);
    }
    const final=await api(`actions/runs/${run.id}`);
    if(final&&(final.run_attempt!==run.run_attempt||cleanupPlan([final],current,result).length!==1))fail('历史任务状态改变，停止清理');
    if(final)await remove(`actions/runs/${run.id}`,api);removed.push(run.id);
  }
  return removed;
}

export function precedingResult(needs) {
  if(!needs||typeof needs!=='object'||Array.isArray(needs)||!Object.keys(needs).length)fail('前置任务结果缺失');
  return Object.values(needs).every(value=>value?.result==='success')?'success':'failed';
}
export async function finish(needs=JSON.parse(process.env.RELEASE_NEEDS||'null'),api=request,identity=context()) {
  const result=precedingResult(needs);
  // 成功自动化只保留未签名资产；旧正式发布在本机新包成功上传前不得清理。
  if(result==='success') {
    if(process.env.GITHUB_STEP_SUMMARY)appendFileSync(process.env.GITHUB_STEP_SUMMARY,'本目标未签名自动化成功；正式签名与发布等待本机确认。\n');
    return;
  }
  const removed=await cleanup('failed',identity,api);
  if(process.env.GITHUB_STEP_SUMMARY)appendFileSync(process.env.GITHUB_STEP_SUMMARY,`本目标失败；已清理同类旧失败Run：${removed.join('、')||'无'}。\n`);
  fail('前置任务未全部成功');
}

const direct=process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url);
const testing=direct&&Boolean(process.env.NODE_TEST_CONTEXT)&&process.argv.length===2;
if(direct&&!testing){
  try{const [command,...args]=process.argv.slice(2);
    if(command==='prepare')await prepare();else if(command==='job')job();else if(command==='step')step(args[0]);
    else if(command==='collect-produced')await collectProduced();else if(command==='finish')await finish();
    else fail('自动化命令无效');
  }catch(error){console.error(error.message);process.exitCode=1;}
}

if(testing){
  const {default:assert}=await import('node:assert/strict');const {default:test}=await import('node:test');

  test('本目标自动化清单校验完整资产和Run字段',async t=>{
    const {mkdtempSync}=await import('node:fs'),{tmpdir}=await import('node:os');
    const directory=mkdtempSync(join(tmpdir(),'citizenapp-android-manifest-'));
    t.after(()=>rmSync(directory,{recursive:true,force:true}));
    const identity={version:'1.2.3',run_number:17,source_sha:'a'.repeat(40)};
    const binaries=["citizenapp-unsigned.apk", "citizenapp-unsigned.aab"];
    for(const name of binaries)writeFileSync(join(directory,name),'unsigned-'+name);
    createAutomationManifest(identity,directory);
    const value=JSON.parse(readFileSync(join(directory,'citizenapp-unsigned-android.json'),'utf8'));
    assert.equal(value.version,'1.2.3');assert.equal(value.github_run_number,17);
    assert.deepEqual(value.assets.map(asset=>asset.asset_name),binaries);
    assert.throws(()=>createAutomationManifest(identity,directory),/集合不完整|已存在/u);
    rmSync(join(directory,'citizenapp-unsigned-android.json'));
    writeFileSync(join(directory,'unexpected'),'foreign');
    assert.throws(()=>createAutomationManifest(identity,directory),/集合不完整/u);
    rmSync(join(directory,'unexpected'));
    assert.throws(()=>createAutomationManifest({...identity,source_sha:'bad'},directory),/Run身份/u);
  });
  test('远端自动化只交付未签名资产，不读取签名材料',()=>{
    const yaml=readFileSync(join(root,workflowPath),'utf8'),steps=yaml.split('\n    - ');
    const unsigned=steps.filter(value=>value.trimEnd().endsWith(' step 10'));
    const manifest=steps.filter(value=>value.trimEnd().endsWith(' step 11'));
    assert.equal(unsigned.length,1);assert.equal(manifest.length,1);
    assert.doesNotMatch(yaml,/secrets\.APP_KEY|^  publish:/mu);
    assert.doesNotMatch(automationBuildSteps['10'].source,/APP_KEY|jarsigner|apksigner sign/u);
  });
  test('自动化按公开编译输入派发并隔离GitHub授权，失败不伪报成功',()=>{
    const input={GITHUB_ACTIONS:'true',GITHUB_REPOSITORY:owner.repository,GITHUB_REF:'refs/heads/main',
      GITHUB_EVENT_NAME:'workflow_dispatch',GITHUB_SHA:'a'.repeat(40),
      GITHUB_WORKFLOW_REF:`${owner.repository}/${workflowPath}@refs/heads/main`,
      GITHUB_RUN_ID:'42',GITHUB_RUN_ATTEMPT:'2',GITHUB_RUN_NUMBER:'17',
      RELEASE_VERSION:'1.2.3',RELEASE_TAG:`${prefix}1.2.3-r42-a2`,
      RUNNER_TEMP:'/synthetic/temporary',RELEASE_WORK:'/synthetic/temporary/work',
      GITHUB_ENV:'/synthetic/temporary/environment',GITHUB_OUTPUT:'/synthetic/temporary/output',GH_TOKEN:'synthetic',ACTIONS_RUNTIME_TOKEN:'synthetic'};
    let calls=0;
    const execute=(command,args,options)=>{calls++;assert.equal(command,'bash');
      assert.deepEqual(args.slice(0,6),['--noprofile','--norc','-e','-o','pipefail','-c']);
      assert.equal(args[6],automationBuildSteps['7'].source);
      assert.equal(args[7],'citizenapp-release-step');
      assert.equal(options.env.CITIZENAPP_BUILD_SOURCE_SHA,input.GITHUB_SHA);
      assert.equal(options.env.CITIZENAPP_BUILD_NUMBER,'17');
      assert.equal(options.env.CITIZENAPP_BUILD_ENVIRONMENT,input.GITHUB_ENV);
      assert.equal(Object.keys(options.env).some(name=>name.startsWith('GITHUB_')||name.startsWith('ACTIONS_')||name==='GH_TOKEN'),false);
      return {status:0};
    };
    step('7',{environment:input,execute});assert.equal(calls,1);
    assert.throws(()=>step('7',{environment:input,execute:()=>({status:1})}),/构建步骤失败/u);
    assert.throws(()=>step('7',{environment:{...input,GITHUB_REF:'refs/heads/foreign'},execute:()=>assert.fail('错误身份不得派发')}),/运行身份/u);
  });
  test('自动化独立拥有本平台编译步骤和资产清单',()=>{
    const source=readFileSync(fileURLToPath(import.meta.url),'utf8');
    const body=source.slice(0,source.indexOf('if(testing){'));
    assert.match(automationBuildSteps['7'].source,/flutter build apk --release/u);
    assert.match(body,/\$sdk_source\/scripts\/build\.mjs/u);
    assert.doesNotMatch(body.replaceAll("checkout/'scripts/build.mjs'",'').replaceAll('$sdk_source/scripts/build.mjs',''),/scripts\/build\.mjs/u);
    assert.match(body,/function createAutomationManifest\(/u);
  });

  test('旧入口不能成为任一现行平台的清理归属证明',()=>{
    const current={id:9,path:workflowPath,head_branch:'main',event:'workflow_dispatch',created_at:'2026-01-02T00:00:00Z'};
    const old={...current,id:1,status:'completed',conclusion:'success',created_at:'2026-01-01T00:00:00Z'};
    for(const path of ['.github/workflows/release.yml',`.github/workflows/${owner.product}-${owner.platform}-ci.yml`,'.github/workflows/deleted.yml'])
      assert.deepEqual(cleanupPlan([{...old,path}],current,'success'),[]);
  });
  test('成功自动化保留旧正式发布，失败只清同目标旧失败',async()=>{
    const current={id:9,path:workflowPath,head_branch:'main',event:'workflow_dispatch',created_at:'2026-01-02T00:00:00Z'};
    const paths=[];
    const api=async path=>{paths.push(path);
      if(path==='actions/runs/9')return current;
      if(path.startsWith('actions/runs?'))return {workflow_runs:[]};
      if(path.startsWith('releases?'))return [];
      throw Error('未声明请求');
    };
    await finish({flow:{result:'success'}},api,{run_id:9});assert.deepEqual(paths,[]);
    await assert.rejects(finish({flow:{result:'failure'}},api,{run_id:9}),/前置任务未全部成功/u);
    assert.ok(paths.includes('actions/runs/9'));
  });
  test('清理旧失败Run同时回收其多个Attempt的准确孤立Tag',async()=>{
    const old={id:2,run_attempt:2,path:workflowPath,head_branch:'main',event:'workflow_dispatch',head_sha:'a'.repeat(40),status:'completed',conclusion:'failure',created_at:'2026-01-01T00:00:00Z'},current={...old,id:9,status:'in_progress',created_at:'2026-01-02T00:00:00Z'};
    const deleted=new Set(),tags=[1,2].map(attempt=>({ref:`refs/tags/${prefix}1.0.0-r2-a${attempt}`,object:{type:'commit',sha:old.head_sha}}));
    const api=async(path,options={})=>{
      if(options.method==='DELETE'){deleted.add(path);return {};}
      if(deleted.has(path)||deleted.has(path.replace('git/ref/','git/refs/')))return null;
      if(path.startsWith('actions/runs?'))return {workflow_runs:[old,current]};
      if(path.startsWith('releases?')||path.includes('/artifacts?'))return path.includes('/artifacts?')?{artifacts:[]}:[];
      if(path.startsWith('git/matching-refs/'))return tags;
      if(path==='actions/runs/2')return old;if(path==='actions/runs/9')return current;
      throw Error('未声明的请求');
    };
    assert.deepEqual(await cleanup('failed',{run_id:9},api),[2]);assert.equal([...deleted].filter(path=>path.startsWith('git/refs/')).length,2);
  });
  test('全部前置成功才成功，其余结论一律失败',()=>{
    assert.equal(precedingResult({prepare:{result:'success'},flow:{result:'success'}}),'success');
    for(const result of ['failure','cancelled','skipped','timed_out',undefined])assert.equal(precedingResult({build:{result}}),'failed');
    assert.throws(()=>precedingResult({}));
  });
  test('当前Run尚在运行也能清理同目标旧结果，保护其它目标和活动任务',()=>{
    const row=(id,conclusion='success',status='completed',path=workflowPath)=>({id,conclusion,status,path,head_branch:'main',event:'workflow_dispatch',created_at:new Date(1700000000000+id*1000).toISOString()});
    const current=row(6,null,'in_progress');const rows=[row(1),row(2,'failure'),row(3,'success','in_progress'),row(4,'success','completed','.github/workflows/release-other.yml'),current,row(7)];
    assert.deepEqual(cleanupPlan(rows,current,'success').map(row=>row.id),[1]);
    assert.deepEqual(cleanupPlan(rows,current,'failed').map(row=>row.id),[2]);
  });
  test('软件版本进位与协议版本边界',()=>{
    assert.equal(nextVersion('1.0.0',['1.99.99']),'2.0.0');assert.equal(nextVersion('9',['9'],true),'10');
    assert.throws(()=>nextVersion(String(0xffffffff),[String(0xffffffff)],true));
  });
  test('历史完整分页不截断超过1000条记录',async()=>{
    const rows=Array.from({length:1005},(_,id)=>({id}));const api=async path=>rows.slice((Number(/page=(\d+)$/u.exec(path)[1])-1)*100,Number(/page=(\d+)$/u.exec(path)[1])*100);
    assert.equal((await pages('releases',null,api)).length,1005);
  });
  test('失败清理只删除所属旧失败产物及Run，成功和活动任务独立保留',async()=>{
    const row=(id,conclusion,status='completed')=>({id,run_attempt:1,conclusion,status,path:workflowPath,head_branch:'main',event:'workflow_dispatch',repository:{full_name:owner.repository},head_sha:'a'.repeat(40),created_at:new Date(1700000000000+id*1000).toISOString()});
    const current=row(10,null,'in_progress'),rows=[row(1,'success'),row(2,'failure'),row(3,null,'in_progress'),current];
    const gone=new Set(),removed=[];
    const api=async(path,options={})=>{
      if(options.method==='DELETE'){removed.push(path);gone.add(path);return {};}
      if(gone.has(path))return null;
      if(path.startsWith('actions/runs?'))return {workflow_runs:rows};
      if(path.startsWith('releases?')||path.startsWith('git/matching-refs/'))return [];
      if(path.startsWith('actions/runs/2/artifacts?'))return {artifacts:[{id:20}]};
      if(path==='actions/artifacts/20')return {id:20};
      const match=/^actions\/runs\/(\d+)$/u.exec(path);if(match)return rows.find(row=>row.id===Number(match[1]))??null;
      throw Error('未声明的模拟接口：'+path);
    };
    assert.deepEqual(await cleanup('failed',{run_id:10},api),[2]);
    assert.deepEqual(removed,['actions/artifacts/20','actions/runs/2']);
  });

  test('GitHub运行序号保证成功历史清理后版本不会回到初始值',()=>{
    assert.equal(nextVersion('1.0.0',[],false,4),'1.0.3');
    assert.equal(nextVersion('1.99.99',[],false,2),'2.0.0');
    assert.equal(nextVersion('1.0.0',['3.0.0'],false,4),'3.0.1');
    assert.throws(()=>nextVersion('1.0.0',[],false,0));
  });

}
