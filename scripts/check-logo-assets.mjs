#!/usr/bin/env node
// 检查本产品受控Logo清单；派生算法与唯一母版仍归CitizenChain。
import {createHash} from 'node:crypto';
import {lstatSync, readFileSync} from 'node:fs';
import {dirname, join, resolve, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)), '..');
const manifest=JSON.parse(readFileSync(join(root,'scripts/logo-assets.json'),'utf8'));
if(manifest.schema!==1||manifest.product!=='citizenapp'
 ||manifest.source?.repository!=='crcfrcn/citizenchain'
 ||manifest.source?.path!=='node/resources/icons/logo.png'
 ||!/^[a-f0-9]{64}$/.test(manifest.source?.sha256||'')
 ||Object.keys(manifest.files||{}).length<30) throw Error('公民Logo来源清单无效');
for(const [relative,hash] of Object.entries(manifest.files)) {
 if(!/^(ios\/Runner\/Assets\.xcassets\/(?:AppIcon\.appiconset|CitizenLaunchLogo\.imageset)\/|android\/app\/src\/main\/res\/(?:mipmap-[^/]+\/|values\/colors\.xml$))/.test(relative)
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
}
process.stdout.write('公民Logo派生物清单检查通过\n');
