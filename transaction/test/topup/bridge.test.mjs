// 执行真实随包JS；合成SDK端口不连接钱包、不签名或广播资金。
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import vm from 'node:vm';
import {webcrypto} from 'node:crypto';
const work=process.env.WORK;if(!work?.startsWith('/'))throw Error('须由本产品装配隔离工程');
const source=readFileSync(join(work,'project/transaction/web/walletconnect.bundle.js'),'utf8');
const box={Uint8Array,Uint16Array,Uint32Array,ArrayBuffer,DataView,TextEncoder,TextDecoder,URL,URLSearchParams,crypto:webcrypto,Buffer,AbortSignal,setTimeout,clearTimeout,setInterval,clearInterval,atob,btoa,console:{log(){},warn(){},error(){}}};
box.self=box;vm.createContext(box);vm.runInContext(source,box);const api=box.CitizenTopup;
const hash='0x'+'09'.repeat(32),payer='0x'+'03'.repeat(20),asset='0x'+'02'.repeat(20),data='0xa9059cbb'+'00'.repeat(96);
const chosen={token:'USDC',network:'base',package_id:'pkg_10'};
const transaction={to:asset,value:'0x0',chainId:'0x2105',data};
function scenario({signFailure=false,saveFailure=false,receipt={txid:hash,payer},doubleOpen=false}={}){
 const events=[],wallet=api.createWalletSession();let opened=0,initialized=0,terminated=0,submitted=0;
 const ask=async(kind,value)=>{events.push(kind);if(kind==='create_order'){if(signFailure||saveFailure)throw Error('signature or storage rejected');return {transaction};}if(kind==='submitted'){submitted++;assert.equal(value.txid,hash);assert.equal(value.transaction.data,data);return {submitted:true};}};
 const createSdk=options=>{initialized++;events.push('sdk');assert.equal(options.checkInstallationImmediately,false);assert.equal(options.enableAnalytics,false);assert.equal(options.storage.enabled,true);
  return {async connect(){events.push('connect');options.openDeeplink('metamask://connect?channel=synthetic');return receipt.payer===undefined?[]:[receipt.payer];},getProvider(){return {getChainId:()=>transaction.chainId,request:async rpc=>{events.push('sendTransaction');assert.equal(rpc.method,'eth_sendTransaction');assert.deepEqual(JSON.parse(JSON.stringify(rpc.params)),[{...transaction,from:receipt.payer}]);if(doubleOpen)options.openDeeplink('metamask://connect?wake=synthetic');return receipt.txid;}};},async terminate(){terminated++;}};};
 return {events,wallet,ask,createSdk,openWallet:async()=>{opened++;events.push('open');},get counts(){return {opened,initialized,terminated,submitted};}};
}
test('签名保存后在同一钱包会话连接再支付，只唤起一次并保存回执',async()=>{
 const p=scenario();assert.equal(await api.paymentFlow({...p,selection:chosen}),hash);
 assert.deepEqual(p.events,['create_order','sdk','connect','open','sendTransaction','submitted']);assert.deepEqual(p.counts,{opened:1,initialized:1,terminated:0,submitted:1});
});
for(const reason of ['signFailure','saveFailure'])test(reason+'时不初始化SDK、不唤起、不发送付款',async()=>{
 const p=scenario({[reason]:true});await assert.rejects(api.paymentFlow({...p,selection:chosen}));assert.deepEqual(p.counts,{opened:0,initialized:0,terminated:0,submitted:0});
});
test('SDK交易唤醒回调不再打开已在前台的钱包，只提交同一付款回执',async()=>{
 const p=scenario({doubleOpen:true});await api.paymentFlow({...p,selection:chosen});assert.equal(p.counts.opened,1);assert.equal(p.counts.submitted,1);
});
test('连接未交付有效付款账户不能构造或发起交易',async()=>{
 const p=scenario({receipt:{txid:hash}});await assert.rejects(api.paymentFlow({...p,selection:chosen}),/有效账户/);assert.equal(p.counts.submitted,0);assert.ok(!p.events.includes('sendTransaction'));
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
test('钱包无回执在上限后结束通信并保留未知，迟到结果不上传',async()=>{
 const p=scenario(),original=p.createSdk;let finish;
 p.createSdk=options=>{const sdk=original(options);sdk.getProvider=()=>({getChainId:()=>transaction.chainId,request:()=>new Promise(resolve=>{finish=resolve;})});return sdk;};
 await assert.rejects(api.paymentFlow({...p,selection:chosen,timeoutMs:5}),error=>api.connectFailure(error).error==='other');
 assert.deepEqual(p.counts,{opened:1,initialized:1,terminated:1,submitted:0});
 finish(hash);await new Promise(resolve=>setTimeout(resolve,0));assert.equal(p.counts.submitted,0);
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
 for(const token of ['USDT','USDC'])for(const network of Object.keys(api.chains))for(const package_id of ['pkg_10','pkg_900']){
  const c=api.selection({token,network,package_id});const value={...transaction,chainId:'0x'+Number(api.chains[network].split(':')[1]).toString(16)};
  assert.equal(api.paymentTransaction(value,c).data,data);count++;
  for(const bad of [{...value,data:data.slice(0,-2)},{...value,value:'0x1'},{...value,chainId:'0xffff'},{...value,from:payer}])assert.throws(()=>api.paymentTransaction(bad,c));
 }
 assert.equal(count,12);
});
test('未知币种网络套餐及额外字段在签名前拒绝',()=>{
 for(const c of [{...chosen,token:'FAKE'},{...chosen,network:'unknown'},{...chosen,package_id:'free'},{...chosen,extra:true}])assert.throws(()=>api.selection(c));
});
test('网页只是随包通信载体，没有钱包选择器、连接按钮或外部脚本',()=>{
 const html=readFileSync(new URL('../../web/walletconnect.html',import.meta.url),'utf8');
 assert.doesNotMatch(html,/id="wallets"|取消连接|<script[^>]+src=["']https?:/);assert.match(html,/document_ready/);assert.equal(html.split('{{TOPUP_NONCE}}').length,5);
});

test('连续两笔订单复用同一SDK，每单只有一次唤起和一次回执保存',async()=>{
 const p=scenario();await api.paymentFlow({...p,selection:chosen});await api.paymentFlow({...p,selection:chosen});
 assert.deepEqual(p.counts,{opened:2,initialized:1,terminated:0,submitted:2});
});
test('同一SDK不能同时执行两笔订单，防止付款回执串单',async()=>{
 const p=scenario();let finish;
 p.createSdk=options=>({connect:async()=>{options.openDeeplink('metamask://connect?channel=synthetic');return [payer];},getProvider:()=>({getChainId:()=>transaction.chainId,request:()=>new Promise(resolve=>{finish=resolve;})}),terminate:async()=>{}});
 const first=api.paymentFlow({...p,selection:chosen});await new Promise(resolve=>setTimeout(resolve,0));
 await assert.rejects(api.paymentFlow({...p,selection:chosen}),/尚未结束/);
 finish(hash);await first;assert.equal(p.counts.opened,1);assert.equal(p.counts.submitted,1);
});
test('App关闭拒绝在途操作；迟到结果及后续付款不能继续',async()=>{
 const p=scenario();let finish;
 p.createSdk=()=>({connect:()=>new Promise(resolve=>{finish=resolve;}),terminate:async()=>{}});
 const payment=api.paymentFlow({...p,selection:chosen});await new Promise(resolve=>setTimeout(resolve,0));
 p.wallet.close();await assert.rejects(payment,/已结束/);finish([payer]);
 await assert.rejects(api.paymentFlow({...p,selection:chosen}),/尚未结束/);assert.equal(p.counts.submitted,0);
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
 p.createSdk=()=>({connect:()=>new Promise(resolve=>{authorize=resolve;}),getProvider:()=>({getChainId:()=>transaction.chainId,request:async()=>{requests++;return hash;}}),terminate:async()=>{}});
 const payment=api.paymentFlow({...p,selection:chosen,active:()=>active});
 await new Promise(resolve=>setTimeout(resolve,0));active=false;authorize([payer]);
 await assert.rejects(payment,/已结束/);assert.equal(requests,0);assert.equal(p.counts.submitted,0);
});

test('付款网络不同时在同一钱包内先切换，再发送原交易，不二次打开钱包',async()=>{
 const p=scenario(),original=p.createSdk;let switches=0;
 p.createSdk=options=>{const sdk=original(options),provider=sdk.getProvider();sdk.getProvider=()=>({getChainId:()=> '0x1',request:async rpc=>{if(rpc.method==='wallet_switchEthereumChain'){switches++;assert.deepEqual(JSON.parse(JSON.stringify(rpc.params)),[{chainId:transaction.chainId}]);options.openDeeplink('metamask://connect?wake=switch');return null;}return provider.request(rpc);}});return sdk;};
 await api.paymentFlow({...p,selection:chosen});assert.equal(switches,1);assert.equal(p.counts.opened,1);assert.equal(p.counts.submitted,1);
});
test('钱包拒绝切换支付网络，不能继续发起转账',async()=>{
 const p=scenario();let transactions=0;
 p.createSdk=()=>({connect:async()=>[payer],getProvider:()=>({getChainId:()=> '0x1',request:async rpc=>{if(rpc.method==='wallet_switchEthereumChain')throw {code:4001};transactions++;return hash;}}),terminate:async()=>{}});
 await assert.rejects(api.paymentFlow({...p,selection:chosen}),error=>error.code===4001);assert.equal(transactions,0);assert.equal(p.counts.submitted,0);
});
