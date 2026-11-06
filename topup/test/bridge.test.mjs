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
function scenario({receipt={txid:hash,payer},doubleOpen=false}={}){
 const events=[];let opened=0,initialized=0,terminated=0,submitted=0;
 const wallet=api.createWalletSession({openLink:url=>port.openLink(url)});
 const ask=async(kind,value)=>{events.push(kind);if(kind==='submitted'){submitted++;assert.equal(value.txid,hash);assert.equal(value.transaction.data,data);return {submitted:true};}};
 const createSdk=options=>{initialized++;events.push('sdk');assert.equal(options.checkInstallationImmediately,false);assert.equal(options.enableAnalytics,false);assert.equal(options.storage.enabled,true);
  return {async connect(){events.push('connect');options.openDeeplink('metamask://connect?channel=synthetic');return receipt.payer===undefined?[]:[receipt.payer];},getProvider(){return {getChainId:()=>{throw Error('禁止用缓存网络决定付款');},request:async rpc=>{events.push('paymentBatch');assert.equal(rpc.method,'metamask_batch');assert.deepEqual(JSON.parse(JSON.stringify(rpc.params)),[{method:'wallet_switchEthereumChain',params:[{chainId:transaction.chainId}]},{method:'eth_sendTransaction',params:[{...transaction,from:receipt.payer}]}]);if(doubleOpen)options.openDeeplink('metamask://connect?wake=synthetic');return [null,receipt.txid];}};},async terminate(){terminated++;}};};
 const port={events,wallet,transaction,ask,createSdk,openLink:async()=>{opened++;events.push('open');},get counts(){return {opened,initialized,terminated,submitted};}};return port;
}
test('签名保存后在同一钱包会话连接再支付，SDK单个链接交付并保存回执',async()=>{
 const p=scenario();assert.equal(await api.paymentFlow({...p,selection:chosen}),hash);
 assert.deepEqual(p.events,['sdk','connect','open','paymentBatch','submitted']);assert.deepEqual(p.counts,{opened:1,initialized:1,terminated:0,submitted:1});
});
test('未交付完整冻结交易时不初始化SDK或唤起钱包',async()=>{
 const p=scenario();await assert.rejects(api.paymentFlow({...p,selection:chosen,transaction:undefined}));
 assert.deepEqual(p.counts,{opened:0,initialized:0,terminated:0,submitted:0});
});
test('SDK连接和交易链接均交付一次，只请求一次交易并保存同一回执',async()=>{
 const p=scenario({doubleOpen:true});await api.paymentFlow({...p,selection:chosen});assert.equal(p.counts.opened,2);assert.equal(p.counts.submitted,1);
});
test('连接未交付有效付款账户不能构造或发起交易',async()=>{
 const p=scenario({receipt:{txid:hash}});await assert.rejects(api.paymentFlow({...p,selection:chosen}),/有效账户/);assert.equal(p.counts.submitted,0);assert.ok(!p.events.includes('paymentBatch'));
});
test('只有回跳、空回执、非法哈希不能自报付款成功',async()=>{
 for(const txid of [undefined,'','0x01']){
  const p=scenario({receipt:{txid,payer}});await assert.rejects(api.paymentFlow({...p,selection:chosen}),/有效定位/);assert.equal(p.counts.submitted,0);
 }
});
test('原生保存广播回执失败必须传播，不能返回成功',async()=>{
 const p=scenario(),original=p.ask;p.ask=async(kind,value)=>kind==='submitted'?{submitted:false}:original(kind,value);
 await assert.rejects(api.paymentFlow({...p,selection:chosen}),/尚未保存/);
});
test('钱包拒绝只结束本单，不撤销有效授权，也不发送广播回执',async()=>{
 const p=scenario(),rejected={code:4001};p.createSdk=()=>({connect:async()=>{throw rejected;},terminate:async()=>{}});
 await assert.rejects(api.paymentFlow({...p,selection:chosen}),error=>error===rejected);assert.equal(api.connectFailure(rejected).error,'user_rejected');assert.equal(p.counts.submitted,0);
});
test('SDK官方rejected事件按取消返回，明确未执行的RPC失败与未知错误分开',async()=>{
 for(const [error,expected] of [['rejected','user_rejected'],[{code:4001},'user_rejected'],[{code:4200},'payment_failed'],[{code:-32601},'payment_failed'],[{code:-32602},'payment_failed'],[{code:4902},'payment_failed'],[{code:4900},'other'],[{code:-32603},'other']]){
  const p=scenario();p.createSdk=()=>({connect:async()=>{throw error;},terminate:async()=>{}});
  await assert.rejects(api.paymentFlow({...p,selection:chosen}),actual=>actual===error);
  assert.equal(api.connectFailure(error).error,expected);assert.equal(p.counts.submitted,0);
 }
});
test('超时只结束界面等待，原付款迟到哈希仍保存且不补发交易',async()=>{
 const p=scenario(),original=p.createSdk;let finish;
 p.createSdk=options=>{const sdk=original(options);sdk.getProvider=()=>({request:()=>new Promise(resolve=>{finish=resolve;})});return sdk;};
 await assert.rejects(api.paymentFlow({...p,selection:chosen,timeoutMs:5}),error=>api.connectFailure(error).error==='other');
 assert.deepEqual(p.counts,{opened:1,initialized:1,terminated:0,submitted:0});
 finish([null,hash]);await new Promise(resolve=>setTimeout(resolve,0));assert.equal(p.counts.submitted,1);
 assert.equal(p.counts.initialized,1);
});
test('故障诊断只返回固定RPC码和SDK分类，不传异常正文',()=>{
 assert.equal(api.connectFailure({code:-32602}).rpc_code,-32602);
 assert.equal(api.connectFailure(Error('Max message count reached without result')).detail,'sdk_update_limit');
 assert.equal(api.connectFailure(Error('付款钱包结果待核实')).detail,'wallet_timeout');
 assert.equal(api.connectFailure(Error('付款回执缺少有效定位')).detail,'receipt_invalid');
 const privateResult=api.connectFailure({code:'synthetic-private',message:'synthetic-private'});
 assert.equal(privateResult.rpc_code,null);assert.equal(privateResult.detail,null);assert.doesNotMatch(JSON.stringify(privateResult),/synthetic-private/);
});
test('取消后不再唤起钱包，不把后续结果交给原生',async()=>{
 const p=scenario();await assert.rejects(api.paymentFlow({...p,selection:chosen,active:()=>false}),/已结束/);assert.equal(p.counts.initialized,0);assert.equal(p.counts.submitted,0);
});
test('两币种三网络两套餐只接受准确链号及完整100字节绑定',()=>{
 let count=0;
 for(const token of ['USDT','USDC'])for(const network of Object.keys(api.chains))for(const package_id of ['pkg_10','pkg_1000']){
  const c=api.selection({token,network,package_id});const value={...transaction,chainId:'0x'+Number(api.chains[network].split(':')[1]).toString(16)};
  assert.equal(api.paymentTransaction(value,c).data,data);count++;
  for(const bad of [{...value,data:data.slice(0,-2)},{...value,value:'0x1'},{...value,chainId:'0xffff'},{...value,from:payer}])assert.throws(()=>api.paymentTransaction(bad,c));
 }
 assert.equal(count,12);
});
test('未知币种网络套餐及额外字段在付款RPC前拒绝',()=>{
 for(const c of [{...chosen,token:'FAKE'},{...chosen,network:'unknown'},{...chosen,package_id:'free'},{...chosen,extra:true}])assert.throws(()=>api.selection(c));
});
test('网页只是随包通信载体，没有钱包选择器、连接按钮或外部脚本',()=>{
 const html=readFileSync(new URL('../web/metamask.html',import.meta.url),'utf8');
 assert.doesNotMatch(html,/id="wallets"|取消连接|<script[^>]+src=["']https?:/);assert.match(html,/document_ready/);assert.equal(html.split('{{TOPUP_NONCE}}').length,5);
});

test('连续两笔订单复用同一SDK，各自保存一次回执',async()=>{
 const p=scenario();await api.paymentFlow({...p,selection:chosen});await api.paymentFlow({...p,selection:chosen});
 assert.deepEqual(p.counts,{opened:2,initialized:1,terminated:0,submitted:2});
});
test('旧单授权不返回，新单仍可完成，晚到旧回执不会更新新单',async()=>{
 const links=[],wallet=api.createWalletSession({openLink:url=>links.push(url)}),first=scenario(),second=scenario();
 const nextHash='0x'+'08'.repeat(32),nextTransaction={...transaction,data:'0xa9059cbb'+'01'.repeat(96)};
 let authorize,connects=0;const results=[];
 const createSdk=options=>({connect:()=>{options.openDeeplink('metamask://connect?channel=synthetic');connects++;return connects===1?new Promise(resolve=>{authorize=resolve;}):Promise.resolve([payer]);},getProvider:()=>({request:async rpc=>[null,rpc.params[1].params[0].data===nextTransaction.data?nextHash:hash]})});
 const ask=label=>async(kind,value)=>{assert.equal(kind,'submitted');results.push([label,value.txid]);return {submitted:true};};
 const old=api.paymentFlow({...first,wallet,createSdk,ask:ask('old'),selection:chosen});
 await new Promise(resolve=>setTimeout(resolve,0));
 assert.equal(await api.paymentFlow({...second,wallet,createSdk,ask:ask('new'),selection:chosen,transaction:nextTransaction}),nextHash);
 assert.deepEqual(results,[['new',nextHash]]);authorize([payer]);assert.equal(await old,hash);
 assert.deepEqual(results,[['new',nextHash],['old',hash]]);assert.equal(links.length,2);assert.equal(first.counts.opened,0);assert.equal(second.counts.opened,0);
});
test('App关闭拒绝在途操作；迟到结果及后续付款不能继续',async()=>{
 const p=scenario();let finish;
 p.createSdk=()=>({connect:()=>new Promise(resolve=>{finish=resolve;}),terminate:async()=>{}});
 const payment=api.paymentFlow({...p,selection:chosen});await new Promise(resolve=>setTimeout(resolve,0));
 p.wallet.close();await assert.rejects(payment,/已结束/);finish([payer]);
 await assert.rejects(api.paymentFlow({...p,selection:chosen}),/已关闭/);assert.equal(p.counts.submitted,0);
});
test('SDK收到原生提供的存储接口，不启用网页默认存储',async()=>{
 const p=scenario(),storage={getPersistedChannelConfig:async()=>undefined};const original=p.createSdk;
 p.createSdk=options=>{assert.equal(options.storage.storageManager,storage);return original(options);};
 await api.paymentFlow({...p,selection:chosen,storage});
});

test('首次初始化删除被替代SDK网页缓存，只保留原生受保护会话',async()=>{
 const values=new Map([['.sdk-comm','synthetic-old-session'],['providerType','sdk'],['.MMSDK_cached_address','synthetic-old-account'],['.MMSDK_cached_chainId','0x1'],['unrelated','keep']]);
 box.localStorage={removeItem:key=>values.delete(key)};
 try {const p=scenario();await api.paymentFlow({...p,selection:chosen});assert.deepEqual([...values],[['unrelated','keep']]);}
 finally {delete box.localStorage;}
});

test('授权晚到时订单已删除或App已关闭，不再发起付款交易',async()=>{
 const p=scenario();let authorize,requests=0,active=true;
 p.createSdk=()=>({connect:()=>new Promise(resolve=>{authorize=resolve;}),getProvider:()=>({request:async()=>{requests++;return [null,hash];}}),terminate:async()=>{}});
 const payment=api.paymentFlow({...p,selection:chosen,active:()=>active});
 await new Promise(resolve=>setTimeout(resolve,0));active=false;authorize([payer]);
 await assert.rejects(payment,/已结束/);assert.equal(requests,0);assert.equal(p.counts.submitted,0);
});

test('不读取缓存网络，切网与完整原交易只交付一个钱包批次',async()=>{
 const p=scenario({doubleOpen:true});
 await api.paymentFlow({...p,selection:chosen});
 assert.equal(p.events.filter(event=>event==='paymentBatch').length,1);
 assert.equal(p.counts.opened,2);assert.equal(p.counts.submitted,1);
});
test('钱包批次被拒绝时不补发单独转账，也不提交付款回执',async()=>{
 const p=scenario(),methods=[];
 p.createSdk=()=>({connect:async()=>[payer],getProvider:()=>({request:async rpc=>{methods.push(rpc.method);throw {code:4001};}})});
 await assert.rejects(api.paymentFlow({...p,selection:chosen}),error=>error.code===4001);assert.deepEqual(methods,['metamask_batch']);assert.equal(p.counts.submitted,0);
});

test('SDK原链接含加密RPC和特殊编码逐字节交付，不删除或重新编码',async()=>{
 const p=scenario();let url;
 p.createSdk=options=>({connect:async()=>{options.openDeeplink('metamask://connect?channelId=synthetic&originatorInfo=abc+def=&rpc=opaque%2B+/==&v=2');return [payer];},getProvider:()=>({request:async()=>[null,hash]})});
 p.openLink=async value=>{url=value;};await api.paymentFlow({...p,selection:chosen});
 assert.equal(url,'metamask://connect?channelId=synthetic&originatorInfo=abc+def=&rpc=opaque%2B+/==&v=2');
});

test('真实桥接按签后order_id处理：旧付款不返回，新付款完成且重复同单不再支付',async()=>{
 box.window=box;
 const session='synthetic-document-session',oldId='top_'+'01'.repeat(16),newId='top_'+'02'.repeat(16);
 const nextHash='0x'+'08'.repeat(32),nextTransaction={...transaction,data:'0xa9059cbb'+'02'.repeat(96)};
 const messages=[];let finishOld,calls=0;
 box.TopupBridge={postMessage:raw=>{const message=JSON.parse(raw);messages.push(message);queueMicrotask(()=>api.reply(session,message.id,{ok:true,value:message.kind==='submitted'?{submitted:true}:null}));}};
 const createSdk=options=>({connect:async()=>{options.openDeeplink('metamask://connect?channelId=synthetic');return [payer];},getProvider:()=>({request:async rpc=>{calls++;options.openDeeplink('metamask://connect?rpc=synthetic');return rpc.params[1].params[0].data===transaction.data?await new Promise(resolve=>{finishOld=resolve;}):[null,nextHash];}})});
 const cfg=id=>({session,order_id:id,selection:chosen,transaction:id===oldId?transaction:nextTransaction});
 const old=api.start(cfg(oldId),{createSdk});await new Promise(resolve=>setTimeout(resolve,0));
 await api.start(cfg(newId),{createSdk});
 assert.deepEqual(messages.filter(m=>m.kind==='submitted').map(m=>[m.order_id,m.txid]),[[newId,nextHash]]);
 await api.start(cfg(newId),{createSdk});assert.equal(calls,2);
 finishOld([null,hash]);await old;
 assert.deepEqual(messages.filter(m=>m.kind==='submitted').map(m=>[m.order_id,m.txid]),[[newId,nextHash],[oldId,hash]]);
 const links=messages.filter(m=>m.kind==='wallet_link');assert.equal(links.length,4);
 assert.ok(links.every(m=>!Object.hasOwn(m,'order_id')&&!Object.hasOwn(m,'transaction')));
 for(const id of [oldId,newId])assert.deepEqual(messages.filter(m=>m.kind==='phase'&&m.order_id===id).map(m=>m.state),['connect_requested','connect_ready','transaction_requested','result_received']);
 assert.ok(messages.every(m=>m.kind!=='create_order'&&!Object.hasOwn(m,'operation')));
 delete box.window;delete box.TopupBridge;
});


test('链接启动失败不代表链上付款失败，不补发交易或污染其他订单',async()=>{
 const p=scenario({doubleOpen:true}),next=scenario();let failedLinks=0;
 p.openLink=async()=>{failedLinks++;throw Error('synthetic-private');};
 const results=await Promise.all([api.paymentFlow({...p,selection:chosen}),api.paymentFlow({...next,wallet:p.wallet,createSdk:p.createSdk,selection:chosen})]);
 assert.deepEqual(results,[hash,hash]);assert.equal(failedLinks,4);
 assert.equal(p.events.filter(e=>e==='paymentBatch').length,2);assert.equal(p.counts.submitted,1);assert.equal(next.counts.submitted,1);
});
test('诊断只有固定阶段，不接收付款资料，诊断异常不改变付款结果',async()=>{
 const p=scenario(),phases=[];
 assert.equal(await api.paymentFlow({...p,selection:chosen,onPhase:(...args)=>{assert.equal(args.length,1);phases.push(args[0]);throw Error('synthetic-private');}}),hash);
 assert.deepEqual(phases,['connect_requested','connect_ready','transaction_requested','result_received']);
});
test('SDK明确拒绝付款也交付真实结果阶段，未返回结果的超时不伪造结果阶段',async()=>{
 for(const unresolved of [false,true]){
  const p=scenario(),phases=[];p.createSdk=()=>({connect:async()=>[payer],getProvider:()=>({request:()=>unresolved?new Promise(()=>{}):Promise.reject({code:4001})})});
  await assert.rejects(api.paymentFlow({...p,selection:chosen,timeoutMs:5,onPhase:state=>phases.push(state)}));
  assert.deepEqual(phases,unresolved?['connect_requested','connect_ready','transaction_requested']:['connect_requested','connect_ready','transaction_requested','result_received']);assert.equal(p.counts.submitted,0);
 }
});

test('连接未返回时只有请求阶段，不能提前切链、付款或保存回执',async()=>{
 const p=scenario(),phases=[];let transactions=0;
 p.createSdk=()=>({connect:()=>new Promise(()=>{}),getProvider:()=>({request:async()=>{transactions++;return [null,hash];}})});
 await assert.rejects(api.paymentFlow({...p,selection:chosen,timeoutMs:5,onPhase:state=>phases.push(state)}));
 assert.deepEqual(phases,['connect_requested']);assert.equal(transactions,0);assert.equal(p.counts.submitted,0);
});

test('批次等待与批次拒绝分别可观察，客户端不会续发第二个RPC',async()=>{
 for(const pending of [true,false]){
  const p=scenario(),phases=[],methods=[];
  p.createSdk=()=>({connect:async()=>[payer],getProvider:()=>({request:rpc=>{methods.push(rpc.method);return pending?new Promise(()=>{}):Promise.reject({code:4001});}})});
  await assert.rejects(api.paymentFlow({...p,selection:chosen,timeoutMs:5,onPhase:state=>phases.push(state)}));
  assert.deepEqual(phases,pending?['connect_requested','connect_ready','transaction_requested']:['connect_requested','connect_ready','transaction_requested','result_received']);assert.deepEqual(methods,['metamask_batch']);assert.equal(p.counts.submitted,0);
 }
});

test('授权超时后迟到授权不能再启动付款批次',async()=>{
 const p=scenario();let authorize,requests=0;
 p.createSdk=()=>({connect:()=>new Promise(resolve=>{authorize=resolve;}),getProvider:()=>({request:async()=>{requests++;return [null,hash];}})});
 await assert.rejects(api.paymentFlow({...p,selection:chosen,timeoutMs:5}));
 authorize([payer]);await new Promise(resolve=>setTimeout(resolve,0));
 assert.equal(requests,0);assert.equal(p.counts.submitted,0);
});
test('只接受两项批次的切网null和合法交易哈希，不把其它结果当付款',async()=>{
 for(const result of [[null],[null,hash,hash],['0x1',hash],[null,'0x01'],hash,{result:[null,hash]}]){
  const p=scenario();p.createSdk=()=>({connect:async()=>[payer],getProvider:()=>({request:async()=>result})});
  await assert.rejects(api.paymentFlow({...p,selection:chosen}),/有效定位/);assert.equal(p.counts.submitted,0);
 }
});
test('超时后原钱包明确拒绝仍交付原请求的取消结果',async()=>{
 const p=scenario(),late=[];let reject;
 p.createSdk=()=>({connect:async()=>[payer],getProvider:()=>({request:()=>new Promise((_,fail)=>{reject=fail;})})});
 await assert.rejects(api.paymentFlow({...p,selection:chosen,timeoutMs:5,onLateFailure:error=>late.push(api.connectFailure(error).error)}));
 reject({code:4001});await new Promise(resolve=>setTimeout(resolve,0));
 assert.deepEqual(late,['user_rejected']);assert.equal(p.counts.submitted,0);
});
test('超时后订单已删除或宿主关闭，迟到哈希不能重建订单',async()=>{
 for(const closed of [false,true]){
  const p=scenario();let finish,active=true;
  p.createSdk=()=>({connect:async()=>[payer],getProvider:()=>({request:()=>new Promise(resolve=>{finish=resolve;})})});
  await assert.rejects(api.paymentFlow({...p,selection:chosen,timeoutMs:5,active:()=>active}));
  if(closed)p.wallet.close();else active=false;
  finish([null,hash]);await new Promise(resolve=>setTimeout(resolve,0));
  assert.equal(p.counts.submitted,0);
 }
});
test('真实桥接超时后仍按原单提交迟到哈希，新订单独立完成且不重付旧单',async()=>{
 box.window=box;
 const session='synthetic-document-session',oldId='top_'+'11'.repeat(16),newId='top_'+'12'.repeat(16);
 const nextHash='0x'+'08'.repeat(32),nextTransaction={...transaction,data:'0xa9059cbb'+'03'.repeat(96)};
 const messages=[];let finishOld,calls=0;
 const real=api.createWalletSession({openLink:async()=>{}}),wallet={pay:options=>real.pay({...options,timeoutMs:5})};
 const createSdk=()=>({connect:async()=>[payer],getProvider:()=>({request:async rpc=>{calls++;return rpc.params[1].params[0].data===transaction.data?await new Promise(resolve=>{finishOld=resolve;}):[null,nextHash];}})});
 box.TopupBridge={postMessage:raw=>{const message=JSON.parse(raw);messages.push(message);queueMicrotask(()=>api.reply(session,message.id,{ok:true,value:message.kind==='submitted'?{submitted:true}:null}));}};
 try{
  const cfg=(order_id,transaction)=>({session,order_id,selection:chosen,transaction});
  await api.start(cfg(oldId,transaction),{wallet,createSdk});
  assert.equal(messages.find(m=>m.kind==='error'&&m.order_id===oldId).detail,'wallet_timeout');
  await api.start(cfg(newId,nextTransaction),{wallet,createSdk});
  finishOld([null,hash]);await new Promise(resolve=>setTimeout(resolve,0));
  assert.deepEqual(messages.filter(m=>m.kind==='submitted').map(m=>[m.order_id,m.txid]),[[newId,nextHash],[oldId,hash]]);
  await api.start(cfg(oldId,transaction),{wallet,createSdk});assert.equal(calls,2);
 }finally{delete box.window;delete box.TopupBridge;real.close();}
});
