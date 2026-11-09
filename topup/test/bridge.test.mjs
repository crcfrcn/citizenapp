// 执行真实随包JS；合成SDK端口不连接钱包、不签名或广播资金。
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import vm from 'node:vm';
import {webcrypto} from 'node:crypto';
const work=process.env.WORK;if(!work?.startsWith('/'))throw Error('须由本产品装配隔离工程');
const source=readFileSync(join(work,'project/topup/web/metamask.bundle.js'),'utf8');
const box={Uint8Array,Uint16Array,Uint32Array,ArrayBuffer,DataView,TextEncoder,TextDecoder,URL,URLSearchParams,crypto:webcrypto,Buffer,AbortSignal,setTimeout,clearTimeout,setInterval,clearInterval,atob,btoa,console:{log(){},warn(){},error(){}}};
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
function scenario({session={sessionScopes:{}},connected=grant(base),send=async()=>hash}={}){
 const calls=[],links=[],submitted=[];
 let count=0;
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
    session=await connected;
   },
   async invokeMethod(request){
    calls.push(JSON.parse(JSON.stringify(request)));
    options.mobile.preferredOpenLink(wake);
    return send(request);
   }
  };
 };
 return {wallet,ask,createSdk,calls,links,submitted,get count(){return count;}};
}
const pay=(scenario,options={})=>api.paymentFlow({...scenario,transaction,selection:chosen,...options});

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
test('两币种三网络两套餐使用完整冻结参数',()=>{
 for(const token of ['USDT','USDC'])for(const network of Object.keys(api.chains))for(const package_id of ['pkg_10','pkg_1000']){
  const c=api.selection({token,network,package_id});
  const value={...transaction,chainId:'0x'+Number(api.chains[network].split(':')[1]).toString(16)};
  assert.equal(api.paymentTransaction(value,c).data,data);
  for(const bad of [{...value,data:data.slice(0,-2)},{...value,value:'0x1'},{...value,chainId:'0xffff'},{...value,from:payer}])assert.throws(()=>api.paymentTransaction(bad,c));
 }
 for(const invalid of [{...chosen,network:'fake'},{...chosen,token:'fake'},{...chosen,package_id:'free'}])assert.throws(()=>api.selection(invalid));
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
  assert.deepEqual(messages.filter(message=>message.kind==='wallet_storage').map(message=>message.key),Array(3).fill('mwp/synthetic'));
  for(const kind of ['wallet_link','submitted']){
   const relevant=messages.filter(message=>message.kind===kind);
   assert.equal(relevant.length,1);
   assert.equal(relevant[0].order_id,order_id);
  }
 }finally{delete box.window;delete box.TopupBridge;}
});
