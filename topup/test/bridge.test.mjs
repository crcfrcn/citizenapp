// 执行真实随包JS；合成SDK端口不连接钱包、不签名或广播资金。
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {EventEmitter} from 'node:events';
import vm from 'node:vm';
import {webcrypto} from 'node:crypto';
const work=process.env.WORK;if(!work?.startsWith('/'))throw Error('须由本产品装配隔离工程');
const source=readFileSync(join(work,'project/topup/web/metamask.bundle.js'),'utf8');
const box={Uint8Array,Uint16Array,Uint32Array,ArrayBuffer,DataView,TextEncoder,TextDecoder,URL,URLSearchParams,crypto:webcrypto,Buffer,AbortSignal,setTimeout:(...args)=>setTimeout(...args),clearTimeout:(...args)=>clearTimeout(...args),setInterval,clearInterval,atob,btoa,console:{log(){},warn(){},error(){}}};
box.self=box;vm.createContext(box);vm.runInContext(source,box);const api=box.CitizenTopup;
const hash='0x'+'09'.repeat(32),payer='0x'+'03'.repeat(20),asset='0x'+'02'.repeat(20),data='0xa9059cbb'+'00'.repeat(96);
const chosen={token:'USDC',network:'base',package_id:'pkg_10'};
const transaction={to:asset,value:'0x0',chainId:'0x2105',data};
const pair='metamask://connect/mwp?p=AA&c=1';
const wake='metamask://connect/mwp?id=00000000-0000-4000-8000-000000000001';
const base=api.chains.base;
const grant=(scope,account=payer)=>({
 sessionScopes:{[scope]:{methods:['eth_sendTransaction'],accounts:[scope+':'+account]}}
});
const tick=()=>new Promise(resolve=>setTimeout(resolve,0));
function deferred(){
 let resolve,reject;
 const promise=new Promise((yes,no)=>{resolve=yes;reject=no;});
 return {promise,resolve,reject};
}
function scenario({session={sessionScopes:{}},connected=grant(base),send=async()=>hash,stored=new Map(),disconnect=async()=>{}}={}){
 const calls=[],links=[],submitted=[];
 let count=0;
 const storage={adapter:{
  get:async key=>stored.get(key)??null,
  set:async(key,value)=>{stored.set(key,value);},
  delete:async key=>{stored.delete(key);}
 }};
 const wallet=api.createWalletSession({openLink:async url=>{links.push(url);}});
 const ask=async(kind,value)=>{
  assert.equal(kind,'submitted');
  submitted.push(value);
  return {submitted:true};
 };
 const createSdk=options=>{
  count++;
  assert.equal(options.analytics.enabled,false);
  let display;
  return {
   on(event,handler){assert.equal(event,'display_uri');display=handler;},
   provider:{getSession:async()=>session},
   async connect(scopes,accounts){
    calls.push('connect');
    assert.deepEqual(JSON.parse(JSON.stringify(scopes)),Object.values(api.chains));
    assert.equal(accounts.length,0);
    display(pair);
    options.mobile.preferredOpenLink(pair);
     session=await(typeof connected==='function'?connected():connected);
   },
   async disconnect(){calls.push('disconnect');await disconnect(options);session={sessionScopes:{}};},
    async invokeMethod(request){
    calls.push(JSON.parse(JSON.stringify(request)));
    options.mobile.preferredOpenLink(wake);
    return send(request);
   }
  };
 };
 return {wallet,ask,createSdk,storage,stored,calls,links,submitted,get count(){return count;}};
}
const pay=(scenario,options={})=>api.paymentFlow({...scenario,transaction,selection:chosen,...options});

// 仅在独占测试目录暴露已装配SDK的MWP类；执行真实request/handleMessage，不复制上游实现。
async function mwpFixture(t){
 const modules=join(work,'project/topup/web/node_modules');
 // 放在原包的临时子目录，Node沿上游嵌套node_modules解析各自原锁版本。
 const directory=mkdtempSync(join(modules,'@metamask/connect-multichain/dist/browser/es/mwp-'));
 t.after(()=>rmSync(directory,{recursive:true,force:true}));
 const file=join(directory,'mwp.mjs');
 writeFileSync(file,readFileSync(join(modules,'@metamask/connect-multichain/dist/browser/es/connect-multichain.mjs'),'utf8')+'\ninit_mwp(); export {MWPTransport};\n');
 const {MWPTransport}=await import(pathToFileURL(file).href);
 const client=new EventEmitter(),sent=[],values=new Map();client.state='CONNECTED';
 client.sendRequest=async message=>{sent.push(message);};
 const transport=new MWPTransport(client,{get:async key=>values.get(key)??null,set:async(key,value)=>{values.set(key,value);},delete:async key=>{values.delete(key);}});
 const p=scenario({session:grant(base),send:request=>transport.request({method:'wallet_invokeMethod',params:request}).then(response=>response.result)});
 return {...p,transport,client,sent,respond:(result,error)=>client.emit('message',{name:'metamask-multichain-provider',data:{id:sent[0].data.id,jsonrpc:'2.0',...error?{error}:{result}}})};
}
const settle=async()=>{for(let index=0;index<30;index++)await Promise.resolve();};

test('真实MWP付款超过60秒仍接收哈希并只发送一次',async t=>{
 const p=await mwpFixture(t);t.mock.timers.enable({apis:['setTimeout']});
 const result=pay(p);await settle();assert.equal(p.sent.length,1);
 t.mock.timers.tick(60001);await settle();assert.equal(p.transport.pendingRequests.size,1);
 p.respond(hash);assert.equal(await result,hash);
 assert.equal(p.submitted.length,1);assert.equal(p.transport.pendingRequests.size,0);assert.equal(p.sent.length,1);
});
test('真实MWP付款超过180秒后迟到哈希仍归原订单，重复回执不重复交付',async t=>{
 const p=await mwpFixture(t);t.mock.timers.enable({apis:['setTimeout']});
 const result=pay(p,{orderId:'top_'+'01'.repeat(16)});const expired=assert.rejects(result,/待核实/);
 await settle();t.mock.timers.tick(180001);await expired;
 assert.equal(p.transport.pendingRequests.size,1);assert.equal(p.submitted.length,0);
 p.respond(hash);await settle();assert.equal(p.submitted.length,1);
 p.respond(hash);await settle();assert.equal(p.submitted.length,1);
 assert.equal(p.transport.pendingRequests.size,0);assert.equal(p.sent.length,1);
});
test('真实MWP付款超过60秒后的钱包拒绝仍返回原错误并清理请求',async t=>{
 const p=await mwpFixture(t);t.mock.timers.enable({apis:['setTimeout']});
 const result=pay(p);const rejected=assert.rejects(result,error=>error.code===4001);
 await settle();t.mock.timers.tick(60001);await settle();
 p.respond(undefined,{code:4001,message:'User rejected'});await rejected;
 assert.equal(p.transport.pendingRequests.size,0);assert.equal(p.submitted.length,0);assert.equal(p.sent.length,1);
});
test('真实MWP授权、查询、签消息及其它请求仍在原60秒超时',async t=>{
 const p=await mwpFixture(t);t.mock.timers.enable({apis:['setTimeout']});
 for(const request of [{method:'wallet_createSession',params:{}},{method:'eth_blockNumber'},
  {method:'wallet_invokeMethod',params:{scope:base,request:{method:'personal_sign',params:[]}}},
  {method:'wallet_invokeMethod',params:{} }]){
  const result=p.transport.request(request);const expired=assert.rejects(result,/timed out|timeout/i);
  await settle();t.mock.timers.tick(60001);await expired;assert.equal(p.transport.pendingRequests.size,0);
 }
});

test('首连授权直接续付，配对与后续唤起只打开钱包一次',async()=>{
 const p=scenario();
 const phases=[];
 assert.equal(await pay(p,{onPhase:value=>phases.push(value)}),hash);
 assert.deepEqual(p.links,[pair]);
 assert.deepEqual(p.calls,['connect',{
  scope:base,request:{method:'eth_sendTransaction',params:[{...transaction,from:payer}]}
 }]);
 assert.equal(p.submitted[0].transaction.data,data);
 assert.deepEqual(phases,['connect_requested','connect_resolved','connect_ready','transaction_requested','result_received']);
});
test('已恢复授权的会话只唤起付款，连续两单复用客户端',async()=>{
 const p=scenario({session:grant(base)});
 const phases=[];
 await pay(p,{onPhase:value=>phases.push(value)});
 await pay(p);
 assert.equal(p.count,1);
 assert.equal(p.calls.length,2);
 assert.deepEqual(p.links,[wake,wake]);
 assert.equal(p.submitted.length,2);
 assert.deepEqual(phases,['session_reused','transaction_requested','result_received']);
});
test('不同链使用各自授权账户和冻结交易',async()=>{
 for(const [network,scope] of Object.entries(api.chains)){
  const chosenTransaction={...transaction,chainId:'0x'+Number(scope.split(':')[1]).toString(16)};
  const p=scenario({session:grant(scope)});
  await pay(p,{selection:{...chosen,network},transaction:chosenTransaction});
  assert.deepEqual(p.calls,[{
   scope,request:{method:'eth_sendTransaction',params:[{...chosenTransaction,from:payer}]}
  }]);
 }
});
test('所选链缺少权限须授权，钱包未授权仍不能付款',async()=>{
 const p=scenario({session:grant('eip155:1'),connected:grant('eip155:1')});
 await assert.rejects(pay(p),/未授权所选网络/);
 assert.deepEqual(p.calls,['connect']);
 assert.equal(p.submitted.length,0);
});
test('读取会话失败不能触发重新授权或付款',async()=>{
 const p=scenario(), original=p.createSdk;
 p.createSdk=options=>({...original(options),provider:{getSession:async()=>{throw Error('读取失败');}}});
 await assert.rejects(pay(p),/读取失败/);
 assert.deepEqual(p.calls,[]);
 assert.deepEqual(p.links,[]);
});
test('钱包超时后迟到授权不能续付',async()=>{
 const authorized=deferred();
 const p=scenario({connected:authorized.promise});
 await assert.rejects(pay(p,{timeoutMs:10}),/待核实/);
 authorized.resolve(grant(base));
 await tick();
 assert.deepEqual(p.calls,['connect']);
 assert.equal(p.submitted.length,0);
});
test('付款超时后接收同一单的迟到哈希，期间新单仍可付款',async()=>{
 const first=deferred();
 const nextHash='0x'+'08'.repeat(32);
 let sent=0;
 const p=scenario({session:grant(base),send:()=>++sent===1?first.promise:Promise.resolve(nextHash)});
 await assert.rejects(pay(p,{timeoutMs:10}),/待核实/);
 assert.equal(await pay(p),nextHash);
 first.resolve(hash);
 await tick();
 assert.deepEqual(p.submitted.map(receipt=>receipt.txid),[nextHash,hash]);
 assert.equal(sent,2);
});
test('已关闭通信时迟到授权不触发付款',async()=>{
 const authorized=deferred();
 const p=scenario({connected:authorized.promise});
 const result=pay(p);
 await tick();
 p.wallet.close();
 await assert.rejects(result,/已结束/);
 authorized.resolve(grant(base));
 await tick();
 assert.deepEqual(p.calls,['connect']);
});
test('明确拒绝按取消处理，未提供合法哈希不能提交',async()=>{
 const rejected={rpcCode:4001,code:53};
 const p=scenario({session:grant(base),send:async()=>{throw rejected;}});
 await assert.rejects(pay(p),error=>error===rejected);
 assert.equal(api.connectFailure(rejected).error,'user_rejected');
 assert.equal(p.submitted.length,0);
 for(const result of [undefined,null,'0x01',[null,hash],{result:hash}]){
  const invalid=scenario({session:grant(base),send:async()=>result});
  await assert.rejects(pay(invalid),/有效定位/);
  assert.equal(invalid.submitted.length,0);
 }
});
test('SDK 握手过期有单独观察阶段，原错误仍向上交付且不发付款',async()=>{
 const expired=Object.assign(new Error('synthetic'),{code:'REQUEST_EXPIRED'});
 const connect=deferred();
 const p=scenario({connected:connect.promise});
 const phases=[];
 const result=pay(p,{onPhase:value=>phases.push(value)});
 await tick();
 connect.reject(expired);
 await assert.rejects(result,error=>error===expired);
 assert.deepEqual(phases,['connect_requested','connect_expired']);
 assert.deepEqual(p.calls,['connect']);
 assert.equal(p.submitted.length,0);
});
test('原单保存失败不能返回付款成功',async()=>{
 const p=scenario();
 await assert.rejects(pay(p,{ask:async()=>({submitted:false})}),/尚未保存/);
});
test('只记录固定错误码和固定分类',()=>{
 assert.equal(api.connectFailure({code:-32602}).rpc_code,-32602);
 assert.equal(api.connectFailure(Error('付款钱包结果待核实')).detail,'wallet_timeout');
 assert.doesNotMatch(JSON.stringify(api.connectFailure(Error('synthetic-private'))),/synthetic-private/);
});
test('两币种三网络动态整数金额使用完整冻结参数',()=>{
 for(const token of ['USDT','USDC'])for(const network of Object.keys(api.chains))for(const package_id of ['pkg_1','pkg_2','pkg_10','pkg_1000']){
  const c=api.selection({token,network,package_id});
  const value={...transaction,chainId:'0x'+Number(api.chains[network].split(':')[1]).toString(16)};
  assert.equal(api.paymentTransaction(value,c).data,data);
  for(const bad of [{...value,data:data.slice(0,-2)},{...value,value:'0x1'},{...value,chainId:'0xffff'},{...value,from:payer}])assert.throws(()=>api.paymentTransaction(bad,c));
 }
 for(const invalid of [{...chosen,network:'fake'},{...chosen,token:'fake'},{...chosen,package_id:'free'},{...chosen,package_id:'pkg_0'},{...chosen,package_id:'pkg_01'},{...chosen,package_id:'pkg_184467440737096'}])assert.throws(()=>api.selection(invalid));
});
test('网页只加载随包脚本',()=>{
 const html=readFileSync(new URL('../web/metamask.html',import.meta.url),'utf8');
 assert.doesNotMatch(html,/id="wallets"|取消连接|<script[^>]+src=["']https?:/);
 assert.match(html,/document_ready/);
 assert.equal(html.split('{{TOPUP_NONCE}}').length,5);
});
test('实际桥接消息绑定原订单，存储使用原生 MWP 命名空间',async()=>{
 box.window=box;
 const session='synthetic-document-session';
 const order_id='top_'+'01'.repeat(16);
 const messages=[];
 box.TopupBridge={postMessage:raw=>{
  const message=JSON.parse(raw);
  messages.push(message);
  queueMicrotask(()=>api.reply(session,message.id,{
   ok:true,value:message.kind==='submitted'?{submitted:true}:null
  }));
 }};
 let calls=0;
 const createSdk=async options=>{
  assert.equal(options.storage.adapter.platform,'web');
  await options.storage.adapter.set('synthetic','fixture');
  await options.storage.adapter.get('synthetic');
  await options.storage.adapter.delete('synthetic');
  return {
   on(){},
   provider:{getSession:async()=>grant(base)},
   async invokeMethod(){
    calls++;
    options.mobile.preferredOpenLink(wake);
    return hash;
   }
  };
 };
 const config={session,order_id,selection:chosen,transaction};
 try {
  await api.start(config,{createSdk});
  await api.start(config,{createSdk});
  assert.equal(calls,1);
  assert.deepEqual(messages.filter(message=>message.kind==='wallet_storage').map(message=>message.key),[...Array(3).fill('mwp/synthetic'),'mwp/reauthorize']);
  for(const kind of ['wallet_link','submitted']){
   const relevant=messages.filter(message=>message.kind===kind);
   assert.equal(relevant.length,1);
   assert.equal(relevant[0].order_id,order_id);
  }
 }finally{delete box.window;delete box.TopupBridge;}
});

test('4100保留钱包码、原单不重发；下一单公开断开后沿原连接真实授权',async()=>{
 const rejected={code:53,rpcCode:4100};
 let sent=0;
 const p=scenario({session:grant(base),send:async()=>{if(++sent===1)throw rejected;return hash;}});
 await assert.rejects(pay(p),error=>error===rejected);
 assert.deepEqual(JSON.parse(JSON.stringify(api.connectFailure(rejected))),{error:'wallet_unauthorized',rpc_code:4100,detail:null});
 await tick();
 assert.equal(p.stored.get('reauthorize'),'1');
 assert.equal(sent,1);
 assert.equal(p.calls.filter(v=>v==='disconnect').length,1);
 assert.equal(await pay(p),hash);
 assert.equal(p.count,1);
 assert.equal(sent,2);
 assert.equal(p.stored.has('reauthorize'),false);
 assert.equal(p.calls.filter(v=>v==='connect').length,1);
 assert.deepEqual(p.links,[wake,pair]);
});
test('重启仍持有标记：不接受旧缓存，重新授权取消后继续保留标记',async()=>{
 const stored=new Map([['reauthorize','1']]);
 const connected=Promise.reject({code:53,rpcCode:4001});connected.catch(()=>{});
 const p=scenario({stored,session:grant(base),connected});
 await assert.rejects(pay(p),error=>error.rpcCode===4001);
 assert.deepEqual(p.calls,['disconnect','connect']);
 assert.equal(stored.get('reauthorize'),'1');
 const fresh=scenario({stored,session:grant(base)});
 assert.equal(await pay(fresh),hash);
 assert.deepEqual(fresh.calls.slice(0,2),['disconnect','connect']);
 assert.equal(stored.has('reauthorize'),false);
});
test('未知错误和明确取消不清授权、不强制重连',async()=>{
 for(const error of [{code:53,rpcCode:4001},{code:53,rpcCode:-32603},Error('synthetic-private')]){
  const p=scenario({session:grant(base),send:async()=>{throw error;}});
  await assert.rejects(pay(p),e=>e===error);
  await tick();
  assert.equal(p.stored.size,0);
  assert.equal(p.calls.length,1);
 }
 assert.equal(api.connectFailure({rpcCode:'4100'}).error,'other');
});
test('授权失效清理等待真实SDK请求结束，不抢占其他单的迟到哈希',async()=>{
 const first=deferred();
 let sent=0;
 const p=scenario({session:grant(base),send:async()=>{sent++;if(sent===1)return first.promise;if(sent===2)throw{rpcCode:4100,code:53};return hash;}});
 const original=pay(p,{timeoutMs:10});
 await assert.rejects(original,/待核实/);
 await assert.rejects(pay(p),error=>error.rpcCode===4100);
 const next=pay(p);
 await tick();
 assert.equal(sent,2);
 assert.equal(p.calls.includes('disconnect'),false);
 first.resolve('0x'+'08'.repeat(32));
 assert.equal(await next,hash);
 await tick();
 assert.deepEqual(p.submitted.map(v=>v.txid),['0x'+'08'.repeat(32),hash]);
 assert.equal(p.calls.filter(v=>v==='disconnect').length,1);
 assert.equal(p.calls.filter(v=>v==='connect').length,1);
});
test('公开断开内部未等待的存储删除完成前不能开始新授权',async()=>{
 const removed=deferred();
 const stored=new Map([['reauthorize','1'],['cache_wallet_getSession','old']]);
 const p=scenario({stored,session:grant(base),disconnect:async options=>{
  void options.storage.adapter.delete('cache_wallet_getSession');
 }});
 const original=p.storage.adapter.delete;
 p.storage.adapter.delete=async key=>{
  if(key==='cache_wallet_getSession')await removed.promise;
  await original(key);
 };
 const result=pay(p);
 await tick();
 assert.deepEqual(p.calls,['disconnect']);
 removed.resolve();
 assert.equal(await result,hash);
 assert.equal(stored.has('cache_wallet_getSession'),false);
 assert.equal(stored.has('reauthorize'),false);
});
test('标记写入失败仍保留原始4100，后续存储不可用时禁止付款',async()=>{
 const error={code:53,rpcCode:4100};
 const p=scenario({session:grant(base),send:async()=>{throw error;}});
 p.storage.adapter.set=async()=>{throw Error('synthetic-storage');};
 await assert.rejects(pay(p),e=>e===error);
 await tick();
 await assert.rejects(pay(p),/保存不可用/);
 assert.equal(p.calls.filter(v=>typeof v==='object').length,1);
});
test('重新授权缺少所选链、方法或合法账户时保留标记，下一次重新清理',async()=>{
 for(const invalid of [grant('eip155:1'),{sessionScopes:{[base]:{methods:[],accounts:[base+':'+payer]}}},grant(base,'invalid')]){
  let attempts=0;
  const p=scenario({stored:new Map([['reauthorize','1']]),session:grant(base),connected:()=>++attempts===1?invalid:grant(base)});
  await assert.rejects(pay(p),/未授权所选网络/);
  assert.equal(p.stored.get('reauthorize'),'1');
  assert.equal(p.submitted.length,0);
  assert.equal(await pay(p),hash);
  assert.equal(p.calls.filter(v=>v==='disconnect').length,2);
  assert.equal(p.stored.has('reauthorize'),false);
 }
});
test('重新授权中的并发新单只共享一次授权，各单只付款一次',async()=>{
 const consent=deferred();
 const p=scenario({stored:new Map([['reauthorize','1']]),session:grant(base),connected:consent.promise});
 const first=pay(p),second=pay(p);
 await tick();
 assert.deepEqual(p.calls,['disconnect','connect']);
 assert.equal(p.submitted.length,0);
 consent.resolve(grant(base));
 assert.deepEqual(await Promise.all([first,second]),[hash,hash]);
 assert.equal(p.calls.filter(v=>typeof v==='object').length,2);
 assert.equal(p.links.length,2);
});
test('公开断开失败不付款，下次用户操作可重试清理',async()=>{
 let attempts=0;
 const p=scenario({stored:new Map([['reauthorize','1']]),session:grant(base),disconnect:async()=>{if(++attempts===1)throw Error('synthetic-disconnect');}});
 await assert.rejects(pay(p),/synthetic-disconnect/);
 assert.equal(p.stored.get('reauthorize'),'1');
 assert.equal(p.submitted.length,0);
 assert.equal(await pay(p),hash);
 assert.equal(attempts,2);
});
test('连接阶段4100也保留原始码与标记，不发起付款',async()=>{
 const error={code:53,rpcCode:4100};
 const connected=Promise.reject(error);connected.catch(()=>{});
 const p=scenario({connected});
 await assert.rejects(pay(p),value=>value===error);
 await tick();
 assert.deepEqual(p.calls,['connect','disconnect']);
 assert.equal(p.stored.get('reauthorize'),'1');
 assert.equal(p.submitted.length,0);
});
