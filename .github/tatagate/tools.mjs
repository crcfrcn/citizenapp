import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {appendFileSync,chmodSync,lstatSync,mkdirSync,readFileSync,readdirSync,realpathSync,readlinkSync,rmSync,symlinkSync,writeFileSync} from 'node:fs';
import {dirname,isAbsolute,join,resolve} from 'node:path';
const fields={git:'PRODUCT_GIT_BIN',bash:'PRODUCT_BASH_BIN',grep:'PRODUCT_GREP_BIN',sed:'PRODUCT_SED_BIN'};
const fail=reason=>{throw Error('App门禁工具：'+reason);};
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
const keys=(value,expected)=>value&&typeof value==='object'&&!Array.isArray(value)&&Object.keys(value).sort().join('\0')===[...expected].sort().join('\0');
// 入口与祖先均须是真实普通文件；正常门禁没有PATH查找或系统工具回退。
export function exactExecutable(path){if(typeof path!=='string'||!isAbsolute(path)||resolve(path)!==path||/[\x00-\x1f]/u.test(path))fail('缺少规范绝对入口');const s=lstatSync(path);if(!s.isFile()||s.isSymbolicLink()||!s.size||!(s.mode&0o111)||realpathSync(path)!==path)fail('须为真实普通可执行文件');return path;}
function directory(path){if(!isAbsolute(path)||resolve(path)!==path||realpathSync(path)!==path||!lstatSync(path).isDirectory())fail('工作根无效');}
export function toolEnvironment(input=process.env,execute=execFileSync){
 const paths=Object.fromEntries(Object.values(fields).map(field=>[field,exactExecutable(input[field])]));
 const env={...paths,HOME:input.HOME,LANG:'C',LC_ALL:'C',PATH:[...new Set([dirname(process.execPath),...Object.values(paths).map(dirname)])].join(':'),GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:'/dev/null',GIT_TERMINAL_PROMPT:'0'};
 const expected={git:/^git version 2\.54\.0$/u,bash:/^GNU bash, version 5\.3\.20\([1-9][0-9]*\)-release(?:\s|$)/u,grep:/^grep \(GNU grep\) 3\.12$/u,sed:/^sed \(GNU sed\) 4\.10$/u};
 for(const [id,field]of Object.entries(fields)){let first=String(execute(paths[field],['--version'],{env,encoding:'utf8',timeout:20000,maxBuffer:1024**2,stdio:['ignore','pipe','pipe']})).split(/\r?\n/u)[0];if(id==='sed'&&first.startsWith(paths[field]+' (GNU sed)'))first='sed'+first.slice(paths[field].length);if(!expected[id].test(first))fail(id+'版本漂移');}return Object.freeze(env);
}
// 来源闭集来自本仓声明；每项准确官方坐标、版本、补丁次序及完整摘要一起检查。
export function validateToolSources(plan){
 const versions={git:'2.54.0',bash:'5.3.20',grep:'3.12',sed:'4.10',actionlint:'1.7.12'};
 if(!keys(plan,['sources','bootstrap'])||!keys(plan.sources,Object.keys(versions)))fail('来源闭集无效');
 for(const [id,version]of Object.entries(versions)){const r=plan.sources[id],base=id==='bash'?'5.3':version;sourceMirrors(r);
 const coordinates=id==='git'?['https://www.kernel.org/pub/software/scm/git/git-'+version+'.tar.xz','git-'+version]:id==='actionlint'?['https://github.com/rhysd/actionlint/releases/download/v'+version+'/actionlint_'+version+'_linux_amd64.tar.gz','.']:['https://ftp.gnu.org/gnu/'+id+'/'+id+'-'+base+(id==='bash'?'.tar.gz':'.tar.xz'),id+'-'+base];
 if(!keys(r,['version','url','sha256','root','executable','upstream_patches',...(['bash','grep','sed'].includes(id)?['mirrors']:[])])||r.version!==version||JSON.stringify([r.url,r.root])!==JSON.stringify(coordinates)||r.executable!==(id==='actionlint'?'actionlint':'bin/'+id)||!/^[a-f0-9]{64}$/u.test(r.sha256)||!Array.isArray(r.upstream_patches)||r.upstream_patches.length!==(id==='bash'?20:0))fail('官方来源不符：'+id);
 for(const [i,p]of r.upstream_patches.entries())if(!keys(p,['url','sha256','mirrors'])||p.url!=='https://ftp.gnu.org/gnu/bash/bash-5.3-patches/bash53-'+String(i+1).padStart(3,'0')||!/^[a-f0-9]{64}$/u.test(p.sha256))fail('补丁闭包无效');
 for(const p of r.upstream_patches)sourceMirrors(p);}
 const b=plan.bootstrap;if(!keys(b,['platform','architecture','os','commands','packages','artifacts'])||b.platform!=='linux'||b.architecture!=='x64'||b.os!=='24.04'||!Array.isArray(b.commands)||!b.commands.length||!Array.isArray(b.packages)||!b.packages.length||new Set(b.commands.map(r=>r.name)).size!==b.commands.length||new Set(b.packages.map(r=>r.name)).size!==b.packages.length)fail('Bootstrap闭集无效');
 for(const r of b.packages)if(!keys(r,['name','version','source'])||!r.version||r.source!=='https://packages.ubuntu.com/noble/'+r.name.split(':')[0])fail('包来源不符');
 for(const r of b.commands)if(!keys(r,['name','path','package'])||!/^\/usr\/(?:bin|lib\/llvm-18\/bin)\/[a-z0-9_+.-]+$/u.test(r.path)||!b.packages.some(p=>p.name===r.package))fail('命令归属不符');
 if(!Array.isArray(b.artifacts)||b.artifacts.length!==2)fail('curl原件闭包无效');
 for(const [i,r]of b.artifacts.entries())if(!keys(r,['name','version','architecture','url','sha256','size','depends'])||r.name!==['libcurl4-openssl-dev','libcurl4t64'][i]||r.version!=='8.5.0-2ubuntu10.15'||r.architecture!=='amd64'||r.size!==[446114,343472][i]||r.sha256!==['c63393dd39d8bc49580e3e23be3eda63ce62ae4823d95f692c7547b25ade8a31','02f8f39727a43d5a7057cba35cda866be00d929b91ea67ed02dd9d6402fa551c'][i]||r.depends!==["libcurl4t64 (= 8.5.0-2ubuntu10.15)","libbrotli1 (>= 0.6.0), libc6 (>= 2.34), libgssapi-krb5-2 (>= 1.17), libidn2-0 (>= 2.0.0), libldap2 (>= 2.6.2), libnghttp2-14 (>= 1.50.0), libpsl5t64 (>= 0.16.0), librtmp1 (>= 2.3), libssh-4 (>= 0.9.0), libssl3t64 (>= 3.0.0), libzstd1 (>= 1.5.5), zlib1g (>= 1:1.1.4)"][i]||r.url!=='https://archive.ubuntu.com/ubuntu/pool/main/c/curl/'+r.name+'_'+r.version+'_amd64.deb')fail('curl坐标不符');
 return plan;
}
// Depends及Pre-Depends闭合；独立解包的原件不得伪报系统安装状态。
export function packageClosure(rows,roots,compare,staged=[]){
 const map=new Map(rows.map(r=>[r.name,{...r,origin:'installed'}]));if(map.size!==rows.length||new Set(staged.map(r=>r.name)).size!==staged.length)fail('包身份重复');
 for(const r of staged){if(r.origin!=='staged'||Object.hasOwn(r,'status'))fail('原件状态伪造');map.set(r.name,r);}
 const available=r=>r&&(r.origin==='staged'||r.status==='install ok installed');
 // 只从已交付包的官方Provides解析虚拟身份；版本依赖只比较声明的虚拟版本。
 const providers=new Map();
 for(const record of [...map.values()].filter(available).sort((a,b)=>a.name.localeCompare(b.name))){
  const seen=new Set();
  for(const item of (record.provides||'').split(',').map(value=>value.trim()).filter(Boolean)){
   const match=/^([a-z0-9+.-]+)(?:\s*\(=\s*([^()\s]+)\))?$/u.exec(item);
   if(!match||seen.has(match[1]))fail('Ubuntu虚拟包声明无效');seen.add(match[1]);
   const list=providers.get(match[1])||[];list.push({record,version:match[2]});providers.set(match[1],list);
  }
 }
 for(const root of roots){const r=map.get(root.name);if(!available(r)||r.version!==root.version)fail('根包不符：'+root.name);}
 const queue=roots.map(r=>r.name),selected=new Map();while(queue.length){const name=queue.shift();if(selected.has(name))continue;const r=map.get(name);if(!available(r))fail('缺失依赖：'+name);selected.set(name,r);
 for(const clause of [r.depends,r.preDepends].filter(Boolean).join(',').split(',').map(s=>s.trim()).filter(Boolean)){
 let candidate;for(const item of clause.split('|')){const m=/^([a-z0-9+.-]+)(?::(?:amd64|native|any))?(?:\s*\((<<|<=|=|>=|>>)\s*([^()\s]+)\))?$/u.exec(item.trim());if(!m)fail('依赖语法无效');const v=map.get(m[1]);if(available(v)&&(!m[2]||compare(v.version,m[2],m[3]))){candidate=v.name;break;}const provider=(providers.get(m[1])||[]).find(p=>!m[2]||(p.version&&compare(p.version,m[2],m[3])));if(provider){candidate=provider.record.name;break;}}if(!candidate)fail('依赖闭包缺失：'+clause);queue.push(candidate);
 }}return [...selected.values()].sort((a,b)=>a.name.localeCompare(b.name));
}
function snapshot(bootstrap,staged=[]){
 const query=exactExecutable('/usr/bin/dpkg-query'),dpkg=exactExecutable('/usr/bin/dpkg'),env={PATH:'',LANG:'C',LC_ALL:'C'};
 const run=(cmd,args)=>String(execFileSync(cmd,args,{env,encoding:'utf8',timeout:20000,maxBuffer:8*1024**2})).trim();
 const format=['Package','Architecture','Status','Version','Depends','Pre-Depends','Provides'].map(field=>'$'+'{'+field+'}').join('\t')+'\n';
 const rows=run(query,['-W','-f='+format]).split('\n').map(s=>s.split('\t')).filter(r=>['all','amd64'].includes(r[1])).map(([name,architecture,status,version,depends,preDepends,provides])=>({name,architecture,status,version,depends,preDepends,provides}));
 const compare=(a,op,b)=>{try{run(dpkg,['--compare-versions',a,op,b]);return true;}catch(e){if(e.status===1)return false;throw e;}};
 const packages=packageClosure(rows,[...bootstrap.packages,...staged],compare,staged);
 for(const r of packages)if(r.origin==='installed'&&run(dpkg,['--verify',r.name]))fail('包字节漂移：'+r.name);
 const commands=bootstrap.commands.map(r=>{const path=exactExecutable(r.path),owners=run(query,['-S',path]).split('\n');if(!owners.some(v=>v===r.package+': '+path||v===r.package+':amd64: '+path))fail('命令包归属不符：'+r.name);return {...r,sha256:digest(readFileSync(path))};});
 const clang=commands.find(r=>r.name==='clang');if(!/^Ubuntu clang version 18\.1\.3(?:\s|$)/u.test(run(clang.path,['--version'])))fail('编译器版本不符');
 return {commands,packages};
}
export async function fetchOriginal(record, destination, request = fetch) {
  let response;
  if (sourceMirrors(record).length === 3) {
    ({response} = await requestGNUOriginal(record, request));
  } else {
    const origin = new URL(record.url), allowed = new Set([origin.hostname]);
    if (origin.protocol !== 'https:' || origin.username || origin.password || origin.port) fail('官方原件来源必须是规范HTTPS');
    if (origin.hostname === 'github.com') for (const name of ['release-assets.githubusercontent.com','objects.githubusercontent.com']) allowed.add(name);
    if (origin.hostname === 'www.kernel.org') allowed.add('cdn.kernel.org');
    let url = origin;
    for (let i = 0; i < 4; i++) {
      response = await request(url.href, {redirect:'manual', credentials:'omit', signal:AbortSignal.timeout(120000)});
      if ([301,302,303,307,308].includes(response.status)) {
        const location = response.headers.get('location');
        await response.body?.cancel();
        if (!location) fail('官方原件重定向缺少目标');
        const target = new URL(location, url);
        if (target.protocol !== 'https:' || target.username || target.password || target.port || !allowed.has(target.hostname)) fail('官方原件重定向越界');
        url = target; response = null; continue;
      }
      if (!response.ok || response.url && response.url !== url.href) fail('官方原件读取失败');
      break;
    }
    if (!response) fail('官方原件重定向次数超限');
  }
  const chunks = []; let size = 0;
  for await (const chunk of response.body) {
    size += chunk.length; if (size > 128 * 1024 ** 2) fail('官方原件超限'); chunks.push(Buffer.from(chunk));
  }
  const bytes = Buffer.concat(chunks);
  if (!size || record.size && size !== record.size || digest(bytes) !== record.sha256) fail('官方原件摘要或大小不符');
  writeFileSync(destination, bytes, {flag:'wx', mode:0o444});
}


function inventory(root,at=root){const files=[];for(const name of readdirSync(at).sort()){const path=join(at,name),s=lstatSync(path),key=path.slice(root.length+1);if(s.isDirectory()&&!s.isSymbolicLink())files.push(...inventory(root,path));else if(s.isFile()&&!s.isSymbolicLink())files.push({path:key,sha256:digest(readFileSync(path)),mode:s.mode&0o777});else if(s.isSymbolicLink()){if(!realpathSync(path).startsWith(root+'/'))fail('对象链接越界');files.push({path:key,target:readlinkSync(path)});}else fail('对象特殊文件');}return files;}
// 数据段在解包前检查真实tar头、重复条目、特殊类型及链接越界。
export function validateTar(bytes){
 if(!Buffer.isBuffer(bytes)||bytes.length<1024||bytes.length%512)fail('tar长度无效');let offset=0;const names=new Set();
 while(offset<bytes.length){const h=bytes.subarray(offset,offset+512);if(h.every(v=>v===0)){if(!bytes.subarray(offset).every(v=>v===0))fail('tar尾部无效');return;}
 const str=(a,b)=>h.subarray(a,b).toString('utf8').split('\0')[0],num=(a,b)=>{const v=str(a,b).trim();if(!/^[0-7]+$/u.test(v))fail('tar数字无效');return parseInt(v,8);};
 if([...h].reduce((n,v,i)=>n+(i>=148&&i<156?32:v),0)!==num(148,156))fail('tar头校验不符');
 const type=str(156,157)||'0',raw=(str(257,263)==='ustar'&&str(345,500)?str(345,500)+'/':'')+str(0,100),name=raw==='./'&&type==='5'?'.':raw.replace(/^\.\//u,'').replace(/\/$/u,'');
 if(!['0','1','2','5'].includes(type)||isAbsolute(name)||/[\x00-\x1f]/u.test(name)||name!=='.'&&name.split('/').some(p=>!p||p==='.'||p==='..')||name==='.'&&type!=='5')fail('tar路径或类型无效');
 if(type!=='5'&&names.has(name))fail('tar条目重复');names.add(name);
 if(['1','2'].includes(type)){const link=str(157,257),target=resolve('/payload',type==='2'?dirname(name):'.',link);if(!link||isAbsolute(link)||!target.startsWith('/payload/'))fail('tar链接越界');}
 offset+=512+Math.ceil(num(124,136)/512)*512;if(offset>bytes.length)fail('tar正文缺失');}fail('tar未终结');
}
function protect(root){for(const name of readdirSync(root)){const path=join(root,name),s=lstatSync(path);if(s.isDirectory()&&!s.isSymbolicLink())protect(path);else if(!s.isSymbolicLink())chmodSync(path,s.mode&0o111?0o555:0o444);}chmodSync(root,0o555);}

// 首次准备仅属于准确App push作业；已验证系统包只用于准备，正常门禁使用正式产物。
export async function prepareRunnerTools(work,{bootstrap=false,environment=process.env,request=fetch}={}){
 if(!bootstrap||process.platform!=='linux'||process.arch!=='x64'||environment.GITHUB_ACTIONS!=='true'||environment.GITHUB_REPOSITORY!=='crcfrcn/citizenapp'||environment.GITHUB_EVENT_NAME!=='push'||environment.GITHUB_REF!=='refs/heads/main'||environment.GITHUB_WORKFLOW!=='tatagate'||environment.GITHUB_JOB!=='gate')fail('首次准备身份无效');
 const os=readFileSync('/etc/os-release','utf8');if(!/^ID=ubuntu$/mu.test(os)||!/^VERSION_ID="24\.04"$/mu.test(os))fail('宿主不是Ubuntu24.04');
 directory(work);directory(environment.RUNNER_TEMP);if(work!==join(environment.RUNNER_TEMP,'citizenapp-tools')||readdirSync(work).length)fail('准备根须为Runner固定独占空目录');
 const plan=validateToolSources(JSON.parse(readFileSync(new URL('contracts.json',import.meta.url),'utf8')).tool_sources),inputs=plan.bootstrap,sources=plan.sources;
 const before=snapshot(inputs),paths=Object.fromEntries(before.commands.map(r=>[r.name,r.path]));
 mkdirSync(join(work,'objects'));const bin=join(work,'bootstrap-bin');mkdirSync(bin);
 for(const r of before.commands)symlinkSync(r.path,join(bin,r.name));symlinkSync(paths.bash,join(bin,'sh'));
 const env={HOME:work,TMPDIR:work,PATH:bin,LANG:'C',LC_ALL:'C',SHELL:paths.bash,CONFIG_SHELL:paths.bash,CC:paths.clang+' --gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/13',CXX:paths.clang+' --driver-mode=g++ --gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/13',AR:paths.ar,AS:paths.as,LD:paths.ld,NM:paths.nm,RANLIB:paths.ranlib,STRIP:paths.strip,MAKE:paths.make,CFLAGS:'-O2',CXXFLAGS:'-O2',CONFIG_SITE:'',PKG_CONFIG:'false',PKG_CONFIG_LIBDIR:'',MAKEINFO:'true',HELP2MAN:'true'};
 const run=(cmd,args,cwd=work,extra={})=>execFileSync(cmd,args,{cwd,env,encoding:'utf8',timeout:3600000,maxBuffer:16*1024**2,stdio:['ignore','pipe','pipe'],...extra});
 const curl=join(work,'objects','curl'),payload=join(curl,'payload');mkdirSync(curl);mkdirSync(payload);const staged=[];
 for(const r of inputs.artifacts){
 const file=join(curl,r.name+'.deb');await fetchOriginal(r,file,request);
 const format=['Package','Version','Architecture','Depends','Pre-Depends'].map(field=>'$'+'{'+field+'}').join('\t')+'\n';
 const control=String(run(paths['dpkg-deb'],['--show','--showformat='+format,file])).replace(/\r?\n$/u,'');if(control!==[r.name,r.version,r.architecture,r.depends,''].join('\t'))fail('curl控制字段不符');
 validateTar(run(paths['dpkg-deb'],['--fsys-tarfile',file],work,{encoding:null,maxBuffer:32*1024**2}));
 run(paths['dpkg-deb'],['--extract',file,payload]);staged.push({name:r.name,version:r.version,depends:r.depends,preDepends:'',origin:'staged'});}
 const curlFiles=inventory(payload),verified=snapshot(inputs,staged);
 for(const file of [join(payload,'usr/include/x86_64-linux-gnu/curl/curl.h'),join(payload,'usr/lib/x86_64-linux-gnu/libcurl.so.4.8.0')])if(!lstatSync(file).isFile()||realpathSync(file)!==file)fail('curl开发输入缺失');
 const flags=['CURL_CFLAGS=-I'+join(payload,'usr/include/x86_64-linux-gnu'),'CURL_LDFLAGS=-L'+join(payload,'usr/lib/x86_64-linux-gnu')+' -Wl,-rpath,'+join(payload,'usr/lib/x86_64-linux-gnu')+' -lcurl','CURL_CONFIG='+paths.false];
 const delivered={},objects=[];
 for(const id of ['bash','grep','sed','git','actionlint']){
 const source=sources[id],object=join(work,'objects',id);mkdirSync(object);objects.push([object,source]);const archive=join(object,'source.archive');await fetchOriginal(source,archive,request);
 const listing=String(run(paths.tar,['-tf',archive])).trim().split('\n');if(listing.some(name=>isAbsolute(name)||name.split('/').includes('..')))fail('发行归档路径越界');
 if(id==='actionlint'){if(listing.filter(name=>name==='actionlint').length!==1)fail('检查器归档入口不唯一');run(paths.tar,['-xkf',archive,'--no-same-owner','--no-same-permissions','-C',object,'actionlint']);
 delivered.TATAGATE_ACTIONLINT=exactExecutable(join(object,'actionlint'));if(String(run(delivered.TATAGATE_ACTIONLINT,['-version'])).split(/\r?\n/u)[0]!=='1.7.12')fail('检查器版本不符');continue;}
 if(!listing.length||listing.some(name=>name!==source.root&&!name.startsWith(source.root+'/')))fail('发行源码根不符');
 const unpack=join(object,'unpack');mkdirSync(unpack);run(paths.tar,['-xkf',archive,'--no-same-owner','--no-same-permissions','-C',unpack]);const src=join(unpack,source.root);directory(src);inventory(src);
 for(const [i,p]of source.upstream_patches.entries()){const file=join(object,'bash53-'+String(i+1).padStart(3,'0'));await fetchOriginal(p,file,request);run(paths.patch,['--batch','--forward','--fuzz=0','-p0','-i',file],src);}
 const target=join(object,'payload');
 if(id==='git')run(paths.make,['-j2','CC='+env.CC,'AR='+paths.ar,'NO_GETTEXT=YesPlease','NO_TCLTK=YesPlease','NO_PERL=YesPlease','NO_PYTHON=YesPlease','NO_INSTALL_HARDLINKS=YesPlease','SHELL_PATH='+delivered.PRODUCT_BASH_BIN,'SHELL='+delivered.PRODUCT_BASH_BIN,...flags,'prefix='+target,'install'],src);
 else{const args=['--prefix='+target,'--disable-nls'];if(id==='bash')args.push('--without-bash-malloc');if(id==='grep')args.push('--disable-perl-regexp');run(env.CONFIG_SHELL,[join(src,'configure'),...args],src);run(paths.make,['-j2','SHELL='+env.CONFIG_SHELL],src);run(paths.make,['install','SHELL='+env.CONFIG_SHELL],src);}
 delivered[fields[id]]=exactExecutable(join(target,source.executable));
 if(id==='bash'){env.SHELL=delivered.PRODUCT_BASH_BIN;env.CONFIG_SHELL=delivered.PRODUCT_BASH_BIN;env.PATH=dirname(delivered.PRODUCT_BASH_BIN)+':'+bin;}
 if(id==='grep')for(const name of ['egrep','fgrep']){const path=join(target,'bin',name),s=lstatSync(path,{throwIfNoEntry:false});if(s){if(!s.isFile()||s.isSymbolicLink())fail('grep别名无效');rmSync(path);}}
 }
 if(JSON.stringify(snapshot(inputs,staged))!==JSON.stringify(verified)||JSON.stringify(inventory(payload))!==JSON.stringify(curlFiles))fail('构建输入发生变化');
 // 先保护，再记录最终模式和全部字节；回读期间不接受源码、补丁或产物变化。
 for(const [object,source]of [...objects,[curl,{artifacts:inputs.artifacts}]]){
 protect(object);chmodSync(object,0o755);const files=inventory(object),receipt=JSON.stringify({source,bootstrap:verified,files},null,2)+'\n';
 writeFileSync(join(object,'receipt.json'),receipt,{flag:'wx',mode:0o444});chmodSync(object,0o555);
 if(readFileSync(join(object,'receipt.json'),'utf8')!==receipt||JSON.stringify(inventory(object).filter(r=>r.path!=='receipt.json'))!==JSON.stringify(files))fail('对象完整回执不符');
 }
 const result=toolEnvironment({...environment,...delivered});rmSync(bin,{recursive:true});return {...result,TATAGATE_ACTIONLINT:delivered.TATAGATE_ACTIONLINT};
}
// 官方模块主入口只在直接执行时准备Runner；被检查器导入不得产生执行副作用。
if(import.meta.main){
 try{
 if(process.version!=='v25.2.1'||process.argv.length!==5||process.argv[2]!=='prepare-runner'||process.argv[3]!=='--bootstrap')fail('准备参数无效');
 const output=await prepareRunnerTools(process.argv[4],{bootstrap:true}),file=process.env.GITHUB_ENV;
 if(!file||realpathSync(file)!==file||!lstatSync(file).isFile()||lstatSync(file).isSymbolicLink())fail('Runner环境文件无效');
 const body=[...Object.values(fields),'TATAGATE_ACTIONLINT'].map(field=>field+'='+output[field]).join('\n')+'\nPRODUCT_NODE_BIN='+exactExecutable(process.execPath)+'\n';appendFileSync(file,body);process.stdout.write('App门禁正式工具准备完成\n');
 }catch(error){process.stderr.write(error.message+'\n');process.exitCode=1;}
}

// GNU原件仅使用规范来源与两份固定镜像；相同文件路径、顺序和摘要不得漂移。
export function sourceMirrors(record) {
  const selected = /^https:\/\/ftp\.gnu\.org\/gnu\/(?:bash\/bash-5\.3\.tar\.gz|grep\/grep-3\.12\.tar\.xz|sed\/sed-4\.10\.tar\.xz|bash\/bash-5\.3-patches\/bash53-(?:00[1-9]|01[0-9]|020))$/u.test(record?.url);
  if (!selected) {
    if (Object.hasOwn(record ?? {}, 'mirrors')) fail('未登记原件不能增加镜像');
    return [record.url];
  }
  const suffix = record.url.slice('https://ftp.gnu.org/gnu/'.length);
  const expected = ['https://mirrors.ocf.berkeley.edu/gnu/', 'https://mirror.csclub.uwaterloo.ca/gnu/'].map(base => base + suffix);
  if (!Array.isArray(record.mirrors) || JSON.stringify(record.mirrors) !== JSON.stringify(expected)
    || !/^[a-f0-9]{64}$/u.test(record.sha256)) fail('GNU镜像坐标、顺序或摘要无效');
  return [record.url, ...record.mirrors];
}

// 只在连接暂时失败或明确可重试的HTTP状态时换站；证书、越界和摘要失败仍立即终止。
export async function requestGNUOriginal(record, request = fetch, {signal, headers} = {}) {
  const addresses = sourceMirrors(record), allowed = new Set(addresses);
  if (addresses.length !== 3) fail('GNU获取缺少固定镜像闭集');
  const retryCodes = new Set(['UND_ERR_CONNECT_TIMEOUT','UND_ERR_HEADERS_TIMEOUT','UND_ERR_SOCKET',
    'ETIMEDOUT','ECONNRESET','ECONNREFUSED','ENOTFOUND','EAI_AGAIN']);
  for (const [index, address] of addresses.entries()) {
    let url = address;
    for (let count = 0; count < 4; count++) {
      signal?.throwIfAborted();
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(new DOMException('GNU响应头等待超时', 'TimeoutError')), 12000);
      const combined = AbortSignal.any([controller.signal, AbortSignal.timeout(120000), ...(signal ? [signal] : [])]);
      let response;
      try {
        response = await request(url, {redirect:'manual', credentials:'omit', signal:combined, ...(headers ? {headers} : {})});
      } catch (error) {
        signal?.throwIfAborted();
        if (index < addresses.length - 1 && (controller.signal.aborted || retryCodes.has(error?.cause?.code ?? error?.code))) break;
        throw error;
      } finally { clearTimeout(timer); }
      if (response.url && response.url !== url) fail('GNU响应来源漂移');
      if ([301,302,303,307,308].includes(response.status)) {
        const location = response.headers.get('location');
        await response.body?.cancel();
        if (!location) fail('GNU跳转缺少目标');
        const target = new URL(location, url).href;
        if (!allowed.has(target)) fail('GNU跳转越出登记坐标');
        if (count === 3) fail('GNU跳转次数超限');
        url = target; continue;
      }
      if ([404,408,429].includes(response.status) || response.status >= 500 && response.status <= 599) {
        await response.body?.cancel();
        if (index < addresses.length - 1) break;
        fail('GNU所有固定入口均不可用');
      }
      if (!response.ok || !response.body) { await response.body?.cancel(); fail('GNU原件响应失败'); }
      return {response, url};
    }
  }
  fail('GNU原件获取失败');
}
