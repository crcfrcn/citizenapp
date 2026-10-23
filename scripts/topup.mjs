// 只把产品锁定的支付源码构建到本轮工作工程，不写源码生成物或下载工具。
import {spawn,execFileSync} from 'node:child_process';
import {readFileSync,realpathSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
export async function prepareTopup(project,{environment=process.env,run:execute}={}){
 const directory=join(project,'assets/topup');
 const declaration=JSON.parse(readFileSync(join(directory,'package.json'),'utf8'));
 if(process.versions.node!==declaration.engines.node)throw Error('充值Node版本与产品声明不一致');
 if(!environment.WORK||resolve(project)!==join(realpathSync(environment.WORK),'project'))throw Error('充值只能构建到本轮工作工程');
 const esbuild=environment.ESBUILD_BIN||'esbuild';
 if(execFileSync(esbuild,['--version'],{env:environment,encoding:'utf8'}).trim()!==declaration.citizenapp.tools.esbuild)throw Error('充值esbuild版本与声明不一致');
 const run=execute||((command,args,cwd,env)=>new Promise((ok,fail)=>{
  const child=spawn(command,args,{cwd,env,stdio:'inherit'});child.once('error',fail);child.once('close',code=>code===0?ok():fail(Error('充值构建失败')));
 }));
 // npm只准备库依赖；禁用安装脚本，不运行二进制工具下载器。工具由公开声明单独交付。
 const env={...environment,npm_config_ignore_scripts:'true'};
 await run('npm',['ci','--ignore-scripts','--no-audit','--no-fund'],directory,env);
 await run(esbuild,['walletconnect.js','--bundle','--format=iife','--global-name=CitizenTopup','--platform=browser','--target=safari15,chrome100','--minify','--outfile=walletconnect.bundle.js','--define:process.env.NODE_ENV="production"'],directory,env);
 return join(directory,'walletconnect.bundle.js');
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{await prepareTopup(process.argv[2]);}catch(error){console.error(error.message);process.exitCode=1;}
}
