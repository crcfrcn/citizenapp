// 真实随包JS在隔离VM运行；钱包为显式合成端口，不签或广播真实资金。
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {createRequire} from 'node:module';
import {webcrypto} from 'node:crypto';
import {EventEmitter} from 'node:events';
import {join} from 'node:path';
const work=process.env.WORK;if(!work?.startsWith('/'))throw Error('须先由本产品装配本轮工作工程');
const source=readFileSync(join(work,'project/transaction/web/walletconnect.bundle.js'),'utf8');
const box={Uint8Array,Uint16Array,Uint32Array,ArrayBuffer,DataView,TextEncoder,TextDecoder,URL,URLSearchParams,crypto:webcrypto,Buffer,AbortSignal,setTimeout,clearTimeout,setInterval,clearInterval,atob,btoa,console:{warn(){},error(){},log(){}}};
box.self=box;vm.createContext(box);vm.runInContext(source,box);const api=box.CitizenTopup;
const chains={ethereum:'eip155:1',base:'eip155:8453',bnb:'eip155:56',tron:'tron:0x2b6653dc',solana:'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'};
function session(network){const chain=chains[network],ns=chain.split(':')[0];return {namespaces:{[ns]:{accounts:[chain+':payer'],methods:ns==='eip155'?['personal_sign','eth_sendTransaction']:ns==='tron'?['tron_signMessage','tron_signTransaction']:['solana_signMessage','solana_signTransaction']}}};}
function scenario(network,token=network==='solana'||network==='base'?'USDC':'USDT',package_id='pkg_15'){
 let sent=0,signatures=0;const stages=[];const c={network,chain:chains[network],payer:'payer'};let current=c;
 const wallet={context:async()=>current,signMessage:async()=>{signatures++;return 'signature';},signTransaction:async()=>({raw:'signed'}),request:async()=>{sent++;return 'tx';}};
 const builder={prepare:async()=>({}),freeze:async()=>network==='tron'||network==='solana'?{txid:'tx',wire:'same-signed-bytes'}:{},broadcast:async()=>{sent++;return 'tx';}};
 const chosen={token,network,package_id};
 const ask=async(kind,value)=>{stages.push(kind);if(kind==='connected')return {context:c,selection:chosen,message:'CitizenServe Topup v1\n',expiresAt:2000};if(kind==='submitting')assert.equal(sent,0);return null;};
 return {wallet,builder,ask,now:()=>1000,selection:chosen,stages,get sent(){return sent;},get signatures(){return signatures;},change(){current={...c,payer:'changed'};}};
}
const choose=(token,network,package_id='pkg_15')=>({token,network,package_id});
function tracePorts(){
 const relay=new EventEmitter();relay.connected=false;relay.connecting=true;relay.subscriber=new EventEmitter();relay.provider={connection:new EventEmitter()};
 const pairing=new EventEmitter(),provider=new EventEmitter();provider.client={core:{relayer:relay,pairing:{events:pairing}}};return {relay,pairing,provider};
}
test('内部URI创建、Relay订阅和发布按本次topic关联，秘密与未知异常不进入出口',()=>{
 const p=tracePorts(),rows=[],trace=api.connectTrace(row=>rows.push(row));trace.logger.debug('unrelated setup');trace.logger.trace({type:'message',direction:'outgoing'});trace.bind(p.provider);trace.event('connect');
 p.pairing.emit('pairing_create',{topic:'synthetic-private-topic'});p.relay.subscriber.emit('subscription_created',{topic:'synthetic-other-topic'});assert.equal(rows.at(-1).subscribed,false);
 p.relay.subscriber.emit('subscription_created',{topic:'synthetic-private-topic'});
 trace.logger.trace({type:'message',direction:'outgoing',request:{id:12,method:'wc_proposeSession',params:{pairingTopic:'synthetic-private-topic'}}});
 p.relay.emit('relayer_publish',{id:13,params:{ttl:300}});assert.equal(rows.at(-1).published,false);
 p.relay.emit('relayer_publish',{id:12,params:{ttl:300}});
 trace.logger.warn({},'synthetic-private-jwt');trace.logger.warn({},'Socket stalled when trying to connect to wss://relay.walletconnect.org');trace.settle('provider_rejected',new Error('synthetic-private-error'));trace.end();
 assert.equal(rows.at(-1).pairing,true);assert.equal(rows.at(-1).subscribed,true);assert.equal(rows.at(-1).published,true);assert.equal(rows.at(-1).winner,'provider_rejected');assert.equal(rows.at(-1).complete,true);assert.equal(rows.at(-1).stalls,1);assert.ok(!JSON.stringify(rows).includes('synthetic-'));assert.equal(p.pairing.listenerCount('pairing_create'),0);
});
test('固定错误精确分类，数值码限定白名单，不读取getter或转成字符串',()=>{
 assert.equal(api.connectFailure(new Error('WebSocket connection closed abnormally with code: 3000 (Unauthorized: origin not allowed)')).error,'origin_denied');
 assert.equal(api.connectFailure(new Error('WebSocket connection closed abnormally with code: 3000 (Unauthorized: origin not allowed)')).code,'3000');
 assert.equal(api.connectFailure(new Error('Unexpected server response: 403')).error,'http_403');
 assert.equal(api.connectFailure(new Error('Unexpected server response: 403 synthetic-private')).error,'other');
 assert.equal(api.connectFailure({code:403,message:'synthetic-private'}).code,'403');assert.equal(api.connectFailure({code:987654}).code,'none');
 assert.equal(api.connectFailure({get message(){throw Error('unreadable');},toString(){throw Error('unreadable');}}).error,'other');
});
test('公开WebSocket关闭事件只输出固定原因和关闭码，不泄漏未知reason',()=>{
 const p=tracePorts(),rows=[],trace=api.connectTrace(row=>rows.push(row));trace.bind(p.provider);
 p.relay.provider.connection.emit('close',{code:3000,reason:'Unauthorized: origin not allowed'});assert.equal(rows.at(-1).event,'socket_close');assert.equal(rows.at(-1).error,'origin_denied');assert.equal(rows.at(-1).code,'3000');
 p.relay.provider.connection.emit('close',{code:3000,reason:'synthetic-private-jwt'});assert.equal(rows.at(-1).error,'other');assert.ok(!JSON.stringify(rows).includes('synthetic-private'));trace.end();assert.equal(p.relay.provider.connection.listenerCount('close'),0);
});
// 合成值只在内存参与比较；测试出口必须与真实闭集快照具有相同字段。
function observationPorts(){
 const listeners=new Map(),rows=[];let callback;
 const provider={on:(name,fn)=>listeners.set(name,fn),removeListener:(name,fn)=>{assert.equal(listeners.get(name),fn);listeners.delete(name);}};
 const controller={state:{},subscribeKey(key,fn){assert.equal(key,'wcUri');callback=fn;return()=>{callback=undefined;};}};
 return {provider,controller,rows,emit(value){provider.uri=value;listeners.get('display_uri')?.(value);},receive(value){controller.state.wcUri=value;callback?.();},get active(){return listeners.size+(callback?1:0);}};
}
test('URI未生成、生成未接收、正确接收和旧URI分别有完整闭集证据',()=>{
 for(const mode of ['none','producer','received','stale']){
  const p=observationPorts();if(mode==='stale')p.controller.state.wcUri='synthetic-previous';
  const observer=api.observeConnection(p.provider,p.controller,row=>p.rows.push(row));
  assert.equal(p.active,2);observer.connect();
  if(mode!=='none')p.emit('synthetic-current');
  if(mode==='received')p.receive('synthetic-current');
  observer.end();observer.end();const end=p.rows.at(-1);
  assert.equal(end.stage,'end');assert.equal(end.listening,true);assert.equal(end.connecting,true);assert.equal(end.complete,true);
  assert.equal(end.emitted,mode!=='none');assert.equal(end.provider_uri,mode!=='none');assert.equal(end.matched,mode==='received');assert.equal(end.baseline,mode==='stale');assert.equal(p.active,0);
  assert.deepEqual(Object.keys(end).sort(),['stage','listening','connecting','emitted','provider_uri','modal_uri','matched','baseline','complete'].sort());
  assert.ok(Object.values(end).every(value=>typeof value==='boolean'||['start','connect','uri','modal','end'].includes(value)));
  assert.ok(!JSON.stringify(p.rows).includes('synthetic-'));
 }
});
test('先收到弹窗变化也会在产生事件核对本轮URI；后续清空不会抹掉已接收事实',()=>{
 const p=observationPorts(),observer=api.observeConnection(p.provider,p.controller,row=>p.rows.push(row));observer.connect();p.receive('synthetic-current');p.emit('synthetic-current');p.receive(undefined);observer.end();
 assert.equal(p.rows.at(-1).matched,true);assert.equal(p.rows.at(-1).modal_uri,false);assert.equal(p.active,0);
});
test('监听或出口失败只标记证据不完整，不替换原业务结果',()=>{
 for(const mode of ['listener','report','payload']){
  const p=observationPorts();if(mode==='listener')p.controller.subscribeKey=()=>{throw Error('synthetic observer failure');};let calls=0;
  const observer=api.observeConnection(p.provider,p.controller,row=>{if(mode==='report'&&calls++===0)throw Error('synthetic outlet failure');p.rows.push(row);});observer.connect();if(mode==='payload')p.emit({unexpected:true});observer.end();
  assert.equal(p.rows.at(-1).complete,false);assert.equal(p.active,0);
 }
});
test('六币轨由明确选择定位，多授权只使用所选链，缺失选择不得猜链',()=>{
 for(const [n,t] of [['ethereum','USDC'],['ethereum','USDT'],['base','USDC'],['bnb','USDT'],['tron','USDT'],['solana','USDC']])assert.equal(api.context(session(n),choose(t,n)).network,n);
 assert.throws(()=>api.context(session('base'),choose('USDT','base')));assert.throws(()=>api.context(session('tron'),choose('USDC','tron')));
 const s=session('ethereum');s.namespaces.eip155.accounts.push(chains.base+':payer');assert.equal(api.context(s,choose('USDC','base')).network,'base');
 assert.throws(()=>api.context(s,{token:'USDC',package_id:'pkg_15'}));assert.throws(()=>api.context(s,choose('USDC','base'),chains.ethereum));
 s.namespaces.eip155.accounts.push(chains.base+':other');assert.throws(()=>api.context(s,choose('USDC','base')));
 delete s.namespaces.eip155.methods;assert.throws(()=>api.context(s,choose('USDC','ethereum')));
});
test('UniversalProvider公开连接参数只有所选主网与必要方法',()=>{
 for(const [token,network] of [['USDC','ethereum'],['USDC','base'],['USDC','solana'],['USDT','ethereum'],['USDT','tron'],['USDT','bnb']]){
  const p=api.proposal(choose(token,network)),ns=chains[network].split(':')[0];
  assert.equal(Object.keys(p.optionalNamespaces).length,1);assert.equal(p.optionalNamespaces[ns].chains.length,1);assert.equal(p.optionalNamespaces[ns].chains[0],chains[network]);assert.equal(p.requiredNamespaces,undefined);
  assert.ok(p.optionalNamespaces[ns].methods.includes(ns==='eip155'?'eth_sendTransaction':ns==='tron'?'tron_signTransaction':'solana_signTransaction'));
 }
});
test('三协议同一流程严格按授权、提交前持久化、提交回执顺序',async()=>{
 for(const [n,t] of [['ethereum','USDC'],['ethereum','USDT'],['base','USDC'],['bnb','USDT'],['tron','USDT'],['solana','USDC']])for(const pkg of ['pkg_15','pkg_1400']){const s=scenario(n,t,pkg);assert.equal(await api.paymentFlow(s),'tx');assert.equal(s.sent,1);assert.equal(s.signatures,1);assert.deepEqual(s.stages,['connected','authorization','submitting','submitted']);}
});
test('意图/授权/提交前落盘任一步失败均零付款，未知广播不重签重付',async()=>{
 for(const fail of ['connected','authorization','submitting']){const s=scenario('base'),original=s.ask;s.ask=async(k,v)=>{if(k===fail)throw Error('synthetic storage failure');return original(k,v);};await assert.rejects(api.paymentFlow(s));assert.equal(s.sent,0);}
 const s=scenario('base');let attempts=0;s.builder.broadcast=async()=>{attempts++;throw Error('unknown');};await assert.rejects(api.paymentFlow(s));assert.equal(attempts,1);assert.equal(s.signatures,1);
});
test('签名后账户/网络变化、意图过期与回执冲突均停止',async()=>{
 const s=scenario('base');s.wallet.signMessage=async()=>{s.change();return 'sig';};await assert.rejects(api.paymentFlow(s));assert.equal(s.sent,0);
 const expired=scenario('tron');expired.now=()=>3000;await assert.rejects(api.paymentFlow(expired));assert.equal(expired.sent,0);
 const conflict=scenario('solana');conflict.builder.broadcast=async()=> 'other';await assert.rejects(api.paymentFlow(conflict));assert.equal(conflict.stages.includes('submitted'),false);
});
test('HTTPS来源文档只执行本次nonce允许的随包脚本，不从网站加载JS',()=>{
 const html=readFileSync(new URL('../../../transaction/web/walletconnect.html',import.meta.url),'utf8');
 assert.equal(html.split('{{TOPUP_NONCE}}').length,5);assert.equal(html.split('{{TOPUP_SCRIPT}}').length,2);
 assert.match(html,/<script nonce="{{TOPUP_NONCE}}" src="data:application\/javascript;base64,{{TOPUP_SCRIPT}}"><\/script>/);
 const csp=html.match(/content="(default-src[^"]+)"/)[1];
 assert.match(csp,/script-src 'nonce-{{TOPUP_NONCE}}';/);
 assert.doesNotMatch(csp,/script-src[^;]*(?:'self'|unsafe-inline|unsafe-eval|https:|data:)/);
 assert.doesNotMatch(html,/<script[^>]+src=["']https?:/);assert.doesNotMatch(html,/<script src="walletconnect[.]bundle[.]js"/);
 assert.match(html,/kind: 'document_ready'/);assert.match(html,/ready: typeof window[.]CitizenTopup[?][.]start === 'function'/);
 assert.doesNotMatch(source,/WalletConnectEthereumProvider[.]init/);
});

test('原字节续播只走原交易，过期、落盘拒绝和冲突回执停止',async()=>{
 const s=scenario('tron');s.builder.validate=async()=>{};
 const replay={context:{network:'tron',chain:chains.tron,payer:'payer'},txid:'tx',wire:'same-signed-bytes',expiresAt:2000};
 assert.equal(await api.replayFlow({...s,replay}),'tx');assert.equal(s.signatures,0);assert.equal(s.sent,1);assert.deepEqual(s.stages,['replay','submitted']);
 const expired=scenario('tron');expired.builder.validate=async()=>{};await assert.rejects(api.replayFlow({...expired,replay,now:()=>3000}));assert.equal(expired.sent,0);
 const fail=scenario('solana');fail.builder.validate=async()=>{};fail.ask=async()=>{throw Error('storage');};await assert.rejects(api.replayFlow({...fail,replay:{...replay,context:{network:'solana',chain:chains.solana,payer:'payer'}}}));assert.equal(fail.sent,0);
});

const require=createRequire(join(work,'project/transaction/web/package.json'));
const fixture=JSON.parse(readFileSync(new URL('./contract.json',import.meta.url),'utf8'));
test('实际Solana库构造ATA与TransferChecked，冻结验签拒绝改收款消息',async()=>{
 const web3=require('@solana/web3.js');
 // 公开合成测试种子只在进程内生成签名，不是任何环境账户。
 const signer=web3.Keypair.fromSeed(new Uint8Array(32).fill(3));
 const c={network:'solana',chain:chains.solana,payer:signer.publicKey.toBase58()};
 const mint=fixture.config.rails.find(r=>r.network==='solana').asset;
 const calls=[];let expectedWire,expectedTx;
 box.fetch=async()=>{throw Error('Solana不得从WebView直接发HTTP');};
 const builder=await api.defaultBuilder(async(context,method,params)=>{
  assert.equal(context.network,'solana');assert.equal(context.payer,c.payer);calls.push(method);
  if(method==='sendTransaction'){assert.equal(params[0],expectedWire);assert.equal(params[1].skipPreflight,false);return expectedTx;}
  return method==='getGenesisHash'?'5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d':{value:{blockhash:new web3.PublicKey(new Uint8Array(32).fill(4)).toBase58(),lastValidBlockHeight:100}};
 });const p={rpc:'https://api.mainnet.solana.com',mint,receiver:fixture.config.rails.find(r=>r.network==='solana').recv_address,amount:'15000000',decimals:6};
 const built=await builder.prepare(c,p);assert.equal(built.raw.instructions.length,2);assert.equal(built.raw.instructions[1].data[0],12);assert.equal(built.raw.instructions[1].data[9],6);
 const signed=web3.Transaction.from(Buffer.from(built.raw.serialize({requireAllSignatures:false,verifySignatures:false})));signed.sign(signer);
 const frozen=await builder.freeze(c,built,{transaction:signed.serialize().toString('base64')});assert.equal(frozen.wire,signed.serialize().toString('base64'));await builder.validate(c,frozen);expectedWire=frozen.wire;expectedTx=frozen.txid;assert.equal(await builder.broadcast(c,frozen),frozen.txid);
 signed.instructions[1].data[1]^=1;signed.sign(signer);await assert.rejects(builder.freeze(c,built,{transaction:signed.serialize().toString('base64')}));
 assert.deepEqual(calls,['getGenesisHash','getLatestBlockhash','getGenesisHash','sendTransaction']);
});
test('实际Tron库构造整数合约付款与原签名冻结，改raw_data或签名拒绝',async()=>{
 const {TronWeb}=require('tronweb');const p={rpc:'https://tron.example.test',asset:fixture.native.tron.intent_data.asset,receiver:fixture.native.tron.intent_data.recv_address,amount:'15000000'};
 const web=new TronWeb({fullHost:p.rpc});const publicVector='01'.padStart(64,'0');const payer=TronWeb.address.fromPrivateKey(publicVector);
 class LocalTron extends TronWeb {constructor(){super({fullHost:p.rpc});this.trx={getBlock:async()=>({blockID:'00000000000000001ebf88508a03865c71d452e25f4d51194196a1d22b6653dc'})};this.transactionBuilder={triggerSmartContract:async(asset,selector,options,parameters,owner)=>{
  assert.equal(asset,p.asset);assert.equal(selector,'transfer(address,uint256)');assert.equal(options.callValue,0);assert.equal(parameters[1].value,p.amount);assert.equal(owner,payer);
  return web.transactionBuilder.triggerSmartContract(asset,selector,{...options,txLocal:true,blockHeader:{ref_block_bytes:'0001',ref_block_hash:'00'.repeat(8),timestamp:1000000,expiration:1060000}},parameters,owner);
 }};}}
 const raw=await api.buildTron(payer,p,LocalTron);const signed=await web.trx.sign(raw,publicVector);const c={network:'tron',chain:chains.tron,payer};const builder=await api.defaultBuilder();
 const frozen=await builder.freeze(c,{raw,rpc:p.rpc},signed);assert.equal(frozen.txid,signed.txID);assert.equal(frozen.wire,JSON.stringify(signed));
 const wrong=structuredClone(signed);wrong.raw_data.fee_limit++;await assert.rejects(builder.freeze(c,{raw,rpc:p.rpc},wrong));
 const wrongSignature=structuredClone(signed);wrongSignature.signature=['00'.repeat(65)];await assert.rejects(builder.freeze(c,{raw,rpc:p.rpc},wrongSignature));
});

test('Tron公开Provider只接受HTTPS付款API，重定向不得交给SDK跟随',async()=>{
 const {TronWeb}=require('tronweb');let calls=0;
 box.fetch=async(url,options)=>{calls++;assert.equal(url,'https://tron.example.test/wallet/getblockbynum');assert.equal(options.redirect,'error');return {ok:true,json:async()=>({blockID:'mainnet'})};};
 const web=api.tronClient(TronWeb,'https://tron.example.test');assert.equal((await web.trx.getBlock(0)).blockID,'mainnet');assert.equal(calls,1);
 await assert.rejects(web.fullNode.request('https://other.example.test',{},'post'));assert.equal(calls,1);assert.throws(()=>api.tronClient(TronWeb,'http://tron.example.test'));
 box.fetch=async()=>{throw Error('synthetic redirect rejected');};await assert.rejects(web.trx.getBlock(0));
});

test('EVM付款显式绑定实际chainId、资产与整数calldata，不包含原生币金额',async()=>{
 const builder=await api.defaultBuilder();for(const network of ['ethereum','base','bnb']){
  const p={asset:'0x'+'11'.repeat(20),data:'0xa9059cbb'+'00'.repeat(64)},c={network,chain:chains[network],payer:'0x'+'22'.repeat(20)};
  const tx=await builder.prepare(c,p);assert.equal(tx.raw.chainId,'0x'+Number(chains[network].split(':')[1]).toString(16));assert.equal(tx.raw.value,'0x0');assert.equal(tx.raw.data,p.data);assert.equal(tx.raw.to,p.asset);
 }
});

function providerFixture(network,{switching=false,refused=false}={}){
 const original=session(network);original.topic='test-topic';const events=new Map(),calls=[];
 if(switching)original.namespaces.eip155.methods.push('wallet_switchEthereumChain');
 const provider={session:original,client:{session:{get:topic=>{assert.equal(topic,original.topic);return original;}},on:(name,handler)=>events.set(name,handler),request:async request=>{calls.push(request);if(request.request.method==='wallet_switchEthereumChain'){if(refused)throw Error('user rejected');return null;}return 'tx';}}};
 return {provider,events,calls,emit:(name,data)=>events.get(name)?.({topic:original.topic,...data})};
}
test('已批准目标链直接使用，不因支持切链而多发请求；交易链错仍拒绝',async()=>{
 const f=providerFixture('bnb',{switching:true}),channel=await api.bindSession(f.provider,choose('USDT','bnb'));
 assert.equal(f.calls.length,0);const c=channel.context();
 await assert.rejects(channel.request(c,'eth_sendTransaction',[{from:'payer',chainId:'0x1'}]));assert.equal(f.calls.length,0);
 assert.equal(await channel.request(c,'eth_sendTransaction',[{from:'payer',chainId:'0x38'}]),'tx');assert.equal(f.calls[0].chainId,chains.bnb);
 const refused=providerFixture('base',{switching:true,refused:true});await api.bindSession(refused.provider,choose('USDC','base'));assert.equal(refused.calls.length,0);
 assert.ok(!api.proposal(choose('USDC','base')).optionalNamespaces.eip155.methods.includes('wallet_switchEthereumChain'));
});
test('账户变化、切到别链、会话更新或撤销后不能继续付款，也不默认选其他链',async()=>{
 for(const [name,data] of [['session_event',{params:{event:{name:'accountsChanged',data:['changed']}}}],['session_event',{params:{event:{name:'chainChanged',data:'0x1'}}}],['session_update',{}],['session_delete',{}],['session_expire',{}]]){
  const f=providerFixture('base'),channel=await api.bindSession(f.provider,choose('USDC','base'));const c=channel.context();f.emit(name,data);
  assert.throws(()=>channel.context());await assert.rejects(channel.request(c,'eth_sendTransaction',[{from:'payer',chainId:'0x2105'}]));assert.equal(f.calls.length,0);
 }
});
test('不支持切链方法的钱包仍只能按批准的目标链请求，其他会话事件不污染本次付款',async()=>{
 const f=providerFixture('base'),channel=await api.bindSession(f.provider,choose('USDC','base'));assert.equal(f.calls.length,0);
 f.events.get('session_delete')({topic:'unrelated'});const c=channel.context();
 await channel.request(c,'eth_sendTransaction',[{from:'payer',chainId:'0x2105'}]);assert.equal(f.calls[0].chainId,chains.base);
});
test('付款选择或报价元组被更换时在签名和广播前停止',async()=>{
 const wrong=scenario('base');wrong.selection=choose('USDC','ethereum');await assert.rejects(api.paymentFlow(wrong));assert.equal(wrong.signatures,0);assert.equal(wrong.sent,0);
 const changed=scenario('base'),ask=changed.ask;changed.ask=async(k,v)=>{const p=await ask(k,v);return k==='connected'?{...p,selection:choose('USDC','base','pkg_1400')}:p;};await assert.rejects(api.paymentFlow(changed));assert.equal(changed.signatures,0);assert.equal(changed.sent,0);
 const delayed=scenario('base'),original=delayed.ask;delayed.ask=async(k,v)=>{const p=await original(k,v);if(k==='connected')delayed.change();return p;};await assert.rejects(api.paymentFlow(delayed));assert.equal(delayed.signatures,0);assert.equal(delayed.sent,0);
});

test('锁定UniversalProvider真实connect转交给SignClient的网络和方法仍准确',async()=>{
 const {UniversalProvider}=require('@walletconnect/universal-provider');
 for(const [token,network] of [['USDC','ethereum'],['USDC','base'],['USDC','solana'],['USDT','ethereum'],['USDT','tron'],['USDT','bnb']]){
  const provider=new UniversalProvider({projectId:'synthetic-project',logger:'silent'});let captured;
  provider.client={pairing:{getAll:()=>[]},connect:async options=>{captured=options;return {approval:async()=>{throw Error('synthetic approval boundary');}};}};
  await assert.rejects(provider.connect(JSON.parse(JSON.stringify(api.proposal(choose(token,network))))),/synthetic approval boundary/);
  const ns=chains[network].split(':')[0];assert.equal(Object.keys(captured.optionalNamespaces).length,1);assert.equal(captured.optionalNamespaces[ns].chains.length,1);assert.equal(captured.optionalNamespaces[ns].chains[0],chains[network]);
  for(const method of session(network).namespaces[ns].methods)assert.ok(captured.optionalNamespaces[ns].methods.includes(method));
  assert.ok(!captured.requiredNamespaces||Object.keys(captured.requiredNamespaces).length===0);
 }
});


test('实际start经原生桥接恢复Solana原字节，跨域fetch零调用且广播在原单核准之后',async()=>{
 const web3=require('@solana/web3.js'),signer=web3.Keypair.fromSeed(new Uint8Array(32).fill(8));
 const rail=fixture.config.rails.find(r=>r.network==='solana');
 const genesis='5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d';
 const builder=await api.defaultBuilder(async()=>({}));
 const raw=await api.buildSolana(signer.publicKey.toBase58(),{mint:rail.asset,receiver:rail.recv_address,amount:'15000000',decimals:6},web3,require('@solana/spl-token'),async method=>method==='getGenesisHash'?genesis:{value:{blockhash:new web3.PublicKey(new Uint8Array(32).fill(7)).toBase58(),lastValidBlockHeight:100}});
 raw.sign(signer);const c={network:'solana',chain:chains.solana,payer:signer.publicKey.toBase58()};
 const frozen=await builder.freeze(c,{raw,web3,rpc:'https://api.mainnet.solana.com'},{transaction:raw.serialize().toString('base64')});
 const cfg={session:'synthetic-session',selection:choose('USDC','solana'),replay:{...frozen,context:c,expiresAt:Date.now()+60000}};
 const stages=[];let approved=false,httpCalls=0;
 box.document=pickerDocument();box.fetch=async()=>{httpCalls++;throw Error('不允许WebView HTTP');};box.window=box;
 box.TopupBridge={postMessage(encoded){const m=JSON.parse(encoded);stages.push(m.kind+(m.method?':'+m.method:''));assert.equal(m.session,cfg.session);assert.equal(m.payer,c.payer);
  let value=null;
  if(m.kind==='solana_rpc'){
   assert.equal(m.url,undefined);assert.equal(m.method==='getGenesisHash'||m.method==='sendTransaction',true);
   if(m.method==='getGenesisHash')value=genesis;
   else{assert.equal(approved,true);assert.equal(m.params[0],frozen.wire);value=frozen.txid;}
  }else if(m.kind==='replay'){assert.equal(m.wire,frozen.wire);approved=true;}
  else if(m.kind==='submitted')assert.equal(m.txid,frozen.txid);
  else assert.fail('未知桥接请求 '+m.kind);
  api.reply(cfg.session,m.id,{ok:true,value});
 }};
 await api.start(cfg);
 assert.deepEqual(stages,['solana_rpc:getGenesisHash','replay','solana_rpc:sendTransaction','submitted']);assert.equal(httpCalls,0);
 assert.equal(box.document.getElementById('title').textContent,'正在核实原付款');assert.equal(box.document.getElementById('wallets').children.length,0);delete box.document;
});


// 选择页不依赖SDK或网络；合成DOM保留禁用按钮事件以验证绕过HTML禁用后的入口围栏。
function pickerDocument(){
 class Element{
  children=[];handlers=new Map();hidden=false;disabled=false;attributes=new Map();
  append(...items){this.children.push(...items);}
  setAttribute(key,value){this.attributes.set(key,value);}
  addEventListener(name,fn){this.handlers.set(name,fn);}
  removeEventListener(name,fn){if(this.handlers.get(name)===fn)this.handlers.delete(name);}
  click(){this.handlers.get('click')?.();}
 }
 const nodes=new Map(['wallets','spinner','title','sub','cancel'].map(id=>[id,new Element()]));
 return {getElementById:id=>nodes.get(id),createElement:()=>new Element()};
}
function assertPicker(options){
 const ids=Array.from(api.wallets,w=>w.id);
 assert.equal(ids.length,6);assert.equal(new Set(ids).size,6);for(const id of ids)assert.match(id,/^[a-f0-9]{64}$/);
 assert.deepEqual(Array.from(api.wallets,w=>w.name),['MetaMask','imToken','Trust Wallet','Binance Wallet','OKX Wallet','Coinbase Wallet']);
 assert.deepEqual(Array.from(api.wallets,w=>w.enabled),[true,false,false,false,false,false]);
 assert.ok(Object.isFrozen(api.wallets));for(const wallet of api.wallets)assert.ok(Object.isFrozen(wallet));
 assert.deepEqual(Array.from(options.includeWalletIds),[ids[0]]);assert.deepEqual(Array.from(options.featuredWalletIds),[ids[0]]);
 assert.equal(options.allWallets,'HIDE');assert.equal(options.disableAppend,true);assert.equal(options.features.headless,true);
 assert.equal(options.customWallets.length,0);assert.equal(options.enableEIP6963,false);assert.equal(options.enableWalletGuide,false);
 assert.equal(options.features.email,false);assert.equal(options.features.socials,false);
}
function connectMetaMask(provider,chosen,options,createAppKit,report,trace,links={}){
 return api.connectWallet(provider,chosen,options,createAppKit,report,trace,{walletId:api.wallets[0].id,...links});
}
function modalPort(){return {open:async()=>{},subscribeState:()=>()=>{},close:async()=>{}};}
test('六宫格顺序、禁用标记和伪造点击围栏；重复MetaMask点击只选择一次',async()=>{
 const document=pickerDocument();let selected=0;
 const pending=api.pickWallet(document,'synthetic-project').then(id=>{selected++;return id;});
 const grid=document.getElementById('wallets');assert.equal(grid.children.length,6);
 assert.deepEqual(grid.children.map(b=>b.children[1].textContent),['MetaMask','imToken','Trust Wallet','Binance Wallet','OKX Wallet','Coinbase Wallet']);
 for(const button of grid.children.slice(1)){assert.equal(button.disabled,true);assert.equal(button.attributes.get('aria-disabled'),'true');assert.equal(button.children[2].textContent,'暂未开放');button.click();}
 await Promise.resolve();assert.equal(selected,0);assert.equal(grid.hidden,false);
 grid.children[0].click();grid.children[0].click();assert.equal(await pending,api.wallets[0].id);assert.equal(selected,1);
 assert.equal(grid.hidden,true);assert.equal(document.getElementById('spinner').hidden,false);assert.ok(grid.children.every(b=>b.disabled));
 for(const button of grid.children){const src=new URL(button.children[0].src);assert.equal(src.hostname,'api.web3modal.org');assert.equal(src.searchParams.get('projectId'),'synthetic-project');assert.equal(src.searchParams.get('st'),'appkit');assert.equal(src.searchParams.get('sv'),'html-core-'+require('@reown/appkit/constants').PACKAGE_VERSION);}
 const html=readFileSync(new URL('../../../transaction/web/walletconnect.html',import.meta.url),'utf8');
 assert.match(html,/grid-template-columns: repeat\(3, minmax\(0, 1fr\)\)/);assert.match(html,/\[hidden\] \{ display: none !important/);
 assert.ok(!html.includes('w3m-modal'));assert.match(html,/id="spinner" hidden/);
});
test('真实start先显示六项且仅启动一次，五个禁用点击零桥接零网络',async()=>{
 let posts=0,network=0;const isolated={...box,document:pickerDocument(),TopupBridge:{postMessage(){posts++;}},fetch:async()=>{network++;throw Error('选择前不能联网');}};
 isolated.self=isolated;isolated.window=isolated;vm.createContext(isolated);vm.runInContext(source,isolated);
 const first=isolated.CitizenTopup.start({projectId:'synthetic-project'});await isolated.CitizenTopup.start({projectId:'synthetic-project'});
 const grid=isolated.document.getElementById('wallets');assert.equal(grid.children.length,6);
 for(const button of grid.children.slice(1))button.click();await Promise.resolve();
 assert.equal(posts,0);assert.equal(network,0);assert.equal(grid.hidden,false);
 isolated.CitizenTopup.cancel();grid.children[0].click();await first;assert.equal(posts,0);assert.equal(network,0);
});
test('未知或缺失钱包ID在SDK入口即拒绝，零创建零连接零唤起',async()=>{
 let created=0,connected=0,opened=0;
 for(const id of ['outside-wallet',undefined]){
  await assert.rejects(api.connectWallet({connect(){connected++;}},choose('USDC','ethereum'),{},()=>{created++;},()=>{},undefined,{walletId:id,openWallet(){opened++;}}),/暂未开放/);
 }
 assert.equal(created,0);assert.equal(connected,0);assert.equal(opened,0);
});
test('原Promise成功、拒绝与取消有独立证据，保留原结果和异常',async()=>{
 for(const mode of ['resolved','rejected','closed']){
  const p=tracePorts(),rows=[],failure=new Error('Connection already closed');let rejectLate;
  const trace=api.connectTrace(row=>rows.push(row));trace.bind(p.provider);
  p.provider.connect=()=>mode==='resolved'?Promise.resolve('synthetic-result'):mode==='rejected'?Promise.reject(failure):new Promise((_,reject)=>{rejectLate=reject;});
  const modal={open:async()=>{},subscribeState(callback){if(mode==='closed')queueMicrotask(()=>callback({open:false}));return()=>{};},close:async()=>{}};
  const pending=connectMetaMask(p.provider,choose('USDC','ethereum'),{},()=>modal,()=>{},trace);
  if(mode==='resolved')assert.equal(await pending,'synthetic-result');
  else await assert.rejects(pending,error=>mode==='rejected'?error===failure:error.message==='钱包连接已取消');
  assert.equal(rows.at(-1).winner,mode==='closed'?'modal_closed':'provider_'+mode);
  if(mode==='resolved'){trace.event('authorization');assert.equal(rows.at(-1).event,'authorization');}
  trace.end();assert.equal(rows.at(-1).event,'end');assert.equal(rows.at(-1).complete,true);
  const count=rows.length;if(rejectLate){rejectLate(failure);await Promise.resolve();assert.equal(rows.length,count);}
  assert.equal(p.provider.listenerCount('display_uri'),0);
 }
});
test('真实连接先监听再open和connect，出口故障不改变结果且不等待ready',async()=>{
 for(const broken of [false,true]){
  const provider=new EventEmitter(),order=[],rows=[];
  provider.connect=async()=>{order.push('connect');provider.uri='synthetic-current';provider.emit('display_uri',provider.uri);return 'synthetic-result';};
  const result=await connectMetaMask(provider,choose('USDC','ethereum'),{},()=>({
   async open(){assert.equal(provider.listenerCount('display_uri'),1);order.push('open');},subscribeState:()=>()=>{},async close(){order.push('close');},ready(){throw Error('取证不能增加ready等待');}
  }),row=>{if(broken)throw Error('synthetic outlet failure');rows.push(row);});
  assert.equal(result,'synthetic-result');assert.deepEqual(order,['open','connect','close']);assert.equal(provider.listenerCount('display_uri'),0);
  if(!broken){assert.equal(rows[0].listening,true);assert.equal(rows.at(-1).complete,true);assert.equal(rows.at(-1).emitted,true);assert.equal(rows.at(-1).stage,'end');assert.ok(!JSON.stringify(rows).includes('synthetic-'));}
 }
});
test('无界面AppKit只登记MetaMask，复用原提案且不读取或清除业务存储',async()=>{
 const provider=new EventEmitter();let closed=0,unsubscribed=0,connected=0;
 provider.connect=async proposal=>{connected++;assert.equal(Object.keys(proposal.optionalNamespaces).join(),'eip155');assert.equal(proposal.optionalNamespaces.eip155.chains[0],chains.base);return 'synthetic-session-result';};
 // 选择页与连接入口均不访问存储；原SDK自行管理协议会话。
 box.localStorage={getItem(){throw Error('不能读取选择历史');},removeItem(){throw Error('不能清理业务数据');}};
 try{
  const result=await connectMetaMask(provider,choose('USDC','base'),{features:{analytics:false}},options=>{
   assertPicker(options);assert.equal(options.features.analytics,false);
   return {open:async()=>{},subscribeState:()=>()=>{unsubscribed++;},close:async()=>{closed++;}};
  });
  assert.equal(result,'synthetic-session-result');assert.equal(connected,1);assert.equal(closed,1);assert.equal(unsubscribed,1);
 }finally{delete box.localStorage;}
});
test('专属链接用原SDK格式化，仅唤起一次MetaMask；失败不改投其他钱包',async()=>{
 for(const fail of [false,true]){
  const provider=new EventEmitter(),launched=[];let resolveConnection;
  provider.connect=()=>{queueMicrotask(()=>{provider.emit('display_uri','wc:synthetic-only');provider.emit('display_uri','wc:synthetic-duplicate');});return new Promise(resolve=>{resolveConnection=resolve;});};
  const pending=connectMetaMask(provider,choose('USDC','ethereum'),{},()=>modalPort(),()=>{},undefined,{
   walletId:api.wallets[0].id,async openWallet(url){launched.push(url);if(fail)throw Error('synthetic launcher failure');resolveConnection('connected');}
  });
  if(fail)await assert.rejects(pending,/无法打开所选钱包/);else assert.equal(await pending,'connected');
  assert.deepEqual(launched,['metamask://wc?uri=wc%3Asynthetic-only']);assert.equal(provider.listenerCount('display_uri'),0);
 }
});
test('取消按钮和SDK初始化失败均收尾，不连接其他钱包或请求签名付款',async()=>{
 for(const failure of ['cancel','setup']){
  const provider=new EventEmitter();let closed=0,unsubscribed=0,connections=0,removeCancel=0,callback;
  provider.connect=()=>{connections++;queueMicrotask(()=>callback());return new Promise(()=>{});};
  const modal={open:async()=>{if(failure==='setup')throw Error('synthetic setup failure');},subscribeState(fn){modal.notify=fn;return()=>{unsubscribed++;};},close:async()=>{closed++;modal.notify?.({open:false});}};
  const pending=connectMetaMask(provider,choose('USDT','tron'),{},()=>modal,()=>{},undefined,{subscribeCancel(fn){callback=fn;return()=>{removeCancel++;};}});
  await assert.rejects(pending,failure==='cancel'?/钱包连接已取消/:/synthetic setup failure/);
  assert.equal(connections,failure==='cancel'?1:0);assert.equal(closed,1);assert.equal(unsubscribed,failure==='cancel'?1:0);assert.equal(removeCancel,failure==='cancel'?1:0);assert.equal(provider.listenerCount('display_uri'),0);
 }
});

function storagePort(){
 const values=new Map([['topup.json','synthetic-original-order'],['@appkit/connections','synthetic-session']]);
 return {values,getItem:key=>values.get(key)??null,setItem:(key,value)=>values.set(key,value),removeItem:key=>values.delete(key)};
}
test('六品牌文件互不导入，共用入口不含品牌scheme；禁用品牌没有假连接',()=>{
 for(const [index,name]of ['metamask','imtoken','trust','binance','okx','coinbase'].entries()){
  const text=readFileSync(new URL('../../../transaction/web/'+name+'.js',import.meta.url),'utf8');
  assert.ok(!/from ['"]\.\//.test(text));assert.equal(api.wallets[index].enabled,index===0);
  if(index>0){assert.equal(api.wallets[index].connect,undefined);assert.equal(api.wallets[index].accepts,undefined);}
 }
 const text=readFileSync(new URL('../../../transaction/web/walletconnect.js',import.meta.url),'utf8');assert.ok(!text.includes('metamask://'));
});
test('MetaMask写当前SDK跳转偏好后才进公共工厂，保留原单及会话；写入失败关闭',async()=>{
 const storage=storagePort(),previous={window:box.window,localStorage:box.localStorage};box.window=box;box.localStorage=storage;let connected=0;
 try{
  const result=await api.wallets[0].connect({walletConnect(adapter,runtime){connected++;assert.equal(adapter,api.wallets[0]);assert.equal(typeof runtime.walletConnect,'function');return 'connected';}});
  assert.equal(result,'connected');assert.equal(connected,1);assert.deepEqual(JSON.parse(storage.getItem('WALLETCONNECT_DEEPLINK_CHOICE')),{name:'MetaMask',href:'metamask://'});
  assert.equal(storage.getItem('topup.json'),'synthetic-original-order');assert.equal(storage.getItem('@appkit/connections'),'synthetic-session');
  storage.setItem=()=>{};storage.values.delete('WALLETCONNECT_DEEPLINK_CHOICE');await assert.rejects(api.wallets[0].connect({walletConnect(){connected++;}}),/唤起配置不可用/);assert.equal(connected,1);
 }finally{if(previous.window===undefined)delete box.window;else box.window=previous.window;if(previous.localStorage===undefined)delete box.localStorage;else box.localStorage=previous.localStorage;}
});
function bridgeHost(){
 const events=new Map(),documentEvents=new Map();let foreground=true;
 return {document:{visibilityState:'visible',hasFocus:()=>foreground,addEventListener:(name,callback)=>documentEvents.set(name,callback),removeEventListener:name=>documentEvents.delete(name)},
  addEventListener:(name,callback)=>events.set(name,callback),removeEventListener:name=>events.delete(name),
  background(){foreground=false;this.document.visibilityState='hidden';},resume(){foreground=true;this.document.visibilityState='visible';events.get('focus')?.();documentEvents.get('visibilitychange')?.();},
  get listeners(){return events.size+documentEvents.size;}};
}
const requestTopic='a'.repeat(64),requestLink='metamask://wc?requestId=123&sessionTopic='+requestTopic;
test('同钱包连接、授权与付款沿同一SDK window.open桥接，每次都等待原生回执',async()=>{
 const host=bridgeHost(),opened=[];let release;
 const bridge=api.walletBridge(api.wallets[0],url=>{opened.push(url);return new Promise(resolve=>{release=resolve;});},host);
 const initial=bridge.open('metamask://wc?uri=wc%3Asynthetic-pairing');await Promise.resolve();release();await initial;
 for(const method of ['personal_sign','eth_sendTransaction']){
  let done=false;const provider={client:{request:async()=>{host.open(requestLink);return 'response';}}};
  const result=bridge.request(provider,{topic:requestTopic,request:{method}}).then(value=>{done=true;return value;});
  await new Promise(resolve=>setTimeout(resolve,5));assert.equal(done,false);release();assert.equal(await result,'response');
 }
 bridge.close();assert.equal(opened.length,3);await assert.rejects(bridge.open(requestLink));host.open(requestLink);await Promise.resolve();assert.equal(opened.length,3);
});
test('错误品牌、错误会话链接及唤起失败均停止原请求，零兜底',async()=>{
 for(const url of ['trust://wc?uri=wc%3Atest','wc:synthetic','https://example.test/','metamask://wc?requestId=123&sessionTopic='+'b'.repeat(64),requestLink]){
  const host=bridgeHost();let launched=0;const bridge=api.walletBridge(api.wallets[0],async()=>{launched++;throw Error('synthetic native failure');},host);
  const provider={client:{request(){host.open(url);return new Promise(()=>{});}}};
  await assert.rejects(bridge.request(provider,{topic:requestTopic}),url===requestLink?/无法打开所选钱包/:/不一致|已结束/);bridge.close();assert.equal(launched,url===requestLink?1:0);
 }
 for(const adapter of api.wallets.slice(1))assert.throws(()=>api.walletBridge(adapter,()=>{}),/暂未开放/);
});
test('回前台才请求，拒绝、超时、取消与迟到结果均不污染下一轮',async()=>{
 const host=bridgeHost();host.background();let requests=0;
 const bridge=api.walletBridge(api.wallets[0],async()=>{},host,{timeout:30});
 const first=bridge.request({client:{request:async()=>{requests++;return 'ready';}}},{topic:requestTopic});await Promise.resolve();assert.equal(requests,0);assert.equal(host.listeners,2);host.resume();assert.equal(await first,'ready');assert.equal(host.listeners,0);
 const declined={code:4001};await assert.rejects(bridge.request({client:{request:async()=>{throw declined;}}},{topic:requestTopic}),error=>error===declined);assert.equal(api.connectFailure(declined).error,'user_rejected');
 let late;await assert.rejects(bridge.request({client:{request:()=>new Promise(resolve=>{late=resolve;})}},{topic:requestTopic}),/等待超时/);bridge.close();late('late');await Promise.resolve();host.open(requestLink);assert.equal(host.listeners,0);
 const host2=bridgeHost();host2.background();const cancelled=api.walletBridge(api.wallets[0],async()=>{},host2,{timeout:50});const pending=cancelled.request({client:{request(){assert.fail('取消后不能请求');}}},{topic:requestTopic});cancelled.close();await assert.rejects(pending,/已结束/);assert.equal(host2.listeners,0);
});
test('连接等待超时、会话监听收尾及错误阶段不泄漏异常正文',async()=>{
 const provider=new EventEmitter();provider.connect=()=>new Promise(()=>{});
 await assert.rejects(connectMetaMask(provider,choose('USDC','ethereum'),{},()=>modalPort(),()=>{},undefined,{timeout:5}),/连接等待超时/);assert.equal(provider.listenerCount('display_uri'),0);
 const events=new Map(),removed=[];const s=session('ethereum');s.topic='synthetic-session';const p={session:s,client:{session:{get:()=>s},on:(name,callback)=>events.set(name,callback),removeListener(name,callback){assert.equal(events.get(name),callback);events.delete(name);removed.push(name);},request:async()=>null}};
 const channel=await api.bindSession(p,choose('USDC','ethereum'));assert.equal(events.size,4);channel.close();assert.equal(events.size,0);assert.equal(removed.length,4);assert.throws(()=>channel.context(),/已变化/);
 for(const [message,code]of [['无法打开所选钱包','wallet_open_failed'],['钱包请求等待超时','request_timeout'],['钱包连接等待超时','connect_timeout']])assert.equal(api.connectFailure(Error(message)).error,code);
});

test('原锁浏览器SDK读取实际跳转偏好并经window.open唤起所选钱包，等待原生回执',async()=>{
 const host=bridgeHost(),storage=storagePort(),opened=[];let bridge,result;
 const previous={window:box.window,localStorage:box.localStorage};box.window=box;box.localStorage=storage;
 try{
  await api.wallets[0].connect({walletConnect:async()=>null});
  const browser={...box,RangeError,window:host,document:host.document,localStorage:storage,navigator:{userAgent:'Mozilla/5.0 (Linux; Android 14)'}};browser.self=browser;host.navigator=browser.navigator;
  vm.createContext(browser);
  try{vm.runInContext(readFileSync(join(work,'project/transaction/web/node_modules/@walletconnect/utils/dist/index.umd.js'),'utf8'),browser,{filename:'walletconnect-utils.umd.js',displayErrors:false});}catch(error){throw Error('原锁浏览器SDK加载失败：'+error.message);}
  const utils=browser['@walletconnect/utils'];assert.equal(utils.getEnvironment(),'browser');
  let release;bridge=api.walletBridge(api.wallets[0],url=>{opened.push(url);return new Promise(resolve=>{release=resolve;});},host,{timeout:100});
  const choice=await utils.getDeepLink({getItem(){assert.fail('浏览器应读取选择偏好');}},'WALLETCONNECT_DEEPLINK_CHOICE');assert.equal(JSON.parse(choice).href,'metamask://');
  const provider={client:{request:async()=>{await utils.handleDeeplinkRedirect({id:123,topic:requestTopic,wcDeepLink:choice});return 'sdk-response';}}};
  let done=false;result=bridge.request(provider,{topic:requestTopic}).then(value=>{done=true;return value;});await new Promise(resolve=>setTimeout(resolve,5));assert.deepEqual(opened,[requestLink]);assert.equal(done,false);release();assert.equal(await result,'sdk-response');bridge.close();
 }finally{bridge?.close();await result?.catch(()=>{});if(previous.window===undefined)delete box.window;else box.window=previous.window;if(previous.localStorage===undefined)delete box.localStorage;else box.localStorage=previous.localStorage;}
});

test('退出文档取消正在连接的钱包，已关闭桥接的迟到SDK链接不再唤起',async()=>{
 const host=bridgeHost();let launched=0;const bridge=api.walletBridge(api.wallets[0],async()=>{launched++;},host);
 const provider=new EventEmitter();provider.connect=()=>new Promise(()=>{});
 const pending=connectMetaMask(provider,choose('USDC','ethereum'),{},()=>modalPort(),()=>{},undefined,{subscribeCancel:bridge.subscribeCancel,openWallet:bridge.open});
 // 让公开连接入口注册取消订阅后，模拟原生dispose发出同一次取消。
 await new Promise(resolve=>setTimeout(resolve,5));bridge.close();await assert.rejects(pending,/钱包连接已取消/);
 provider.emit('display_uri','wc:synthetic-late');host.open(requestLink);await Promise.resolve();assert.equal(launched,0);assert.equal(provider.listenerCount('display_uri'),0);
});

for(const adapter of api.wallets.slice(1)){
 test(adapter.name+'独立门禁：未接入时零SDK创建、连接和唤起',async()=>{
  let created=0,connected=0,opened=0;assert.equal(adapter.enabled,false);assert.equal(adapter.connect,undefined);
  await assert.rejects(api.connectWallet({connect(){connected++;}},choose('USDC','ethereum'),{},()=>{created++;},()=>{},undefined,{walletId:adapter.id,openWallet(){opened++;}}),/暂未开放/);
  assert.throws(()=>api.walletBridge(adapter,()=>{opened++;}),/暂未开放/);
  assert.equal(created,0);assert.equal(connected,0);assert.equal(opened,0);
 });
}
