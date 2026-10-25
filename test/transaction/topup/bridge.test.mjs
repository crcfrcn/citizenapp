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
const source=readFileSync(join(work,'project/assets/topup/walletconnect.bundle.js'),'utf8');
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
 const html=readFileSync(new URL('../../../assets/topup/walletconnect.html',import.meta.url),'utf8');
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

const require=createRequire(join(work,'project/assets/topup/package.json'));
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
 const {TronWeb}=require('tronweb');const p={rpc:'https://tron.example.test',asset:fixture.native.tron.intent.asset,receiver:fixture.native.tron.intent.recv_address,amount:'15000000'};
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
test('真实会话适配器准确请求所选CAIP-2链，切链拒绝时没有付款调用',async()=>{
 const f=providerFixture('bnb',{switching:true}),channel=await api.bindSession(f.provider,choose('USDT','bnb'));
 assert.equal(f.calls.length,1);assert.equal(f.calls[0].chainId,chains.bnb);assert.equal(f.calls[0].request.params[0].chainId,'0x38');
 const c=channel.context();
 await assert.rejects(channel.request(c,'eth_sendTransaction',[{from:'payer',chainId:'0x1'}]));assert.equal(f.calls.length,1);
 assert.equal(await channel.request(c,'eth_sendTransaction',[{from:'payer',chainId:'0x38'}]),'tx');assert.equal(f.calls[1].chainId,chains.bnb);
 const rejected=providerFixture('base',{switching:true,refused:true});await assert.rejects(api.bindSession(rejected.provider,choose('USDC','base')));assert.equal(rejected.calls.length,1);assert.equal(rejected.calls[0].request.method,'wallet_switchEthereumChain');
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
 box.fetch=async()=>{httpCalls++;throw Error('不允许WebView HTTP');};box.window=box;
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
});


// 使用真实随包入口及原锁SDK的目录/列表模型；外部I/O只返回合成钱包目录。
function pickerStorage(){
 const values=new Map([
  ['@appkit/recent_wallets',JSON.stringify([{id:'outside-wallet',name:'Outside Wallet'}])],
  ['@appkit/recent_wallet',JSON.stringify({id:'outside-wallet',name:'Outside Wallet'})],
  ['@appkit/connections','synthetic-session'],['topup.json','synthetic-original-order'],['other-setting','keep']
 ]);
 const removed=[];
 return {values,removed,getItem:key=>values.get(key)??null,setItem:(key,value)=>values.set(key,value),removeItem(key){removed.push(key);values.delete(key);}};
}
function pickerGlobals(storage){
 const previous={window:box.window,localStorage:box.localStorage};box.window=box;box.localStorage=storage;
 return ()=>{if(previous.window===undefined)delete box.window;else box.window=previous.window;if(previous.localStorage===undefined)delete box.localStorage;else box.localStorage=previous.localStorage;};
}
function assertPicker(options){
 const ids=Array.from(api.wallets,w=>w.id);
 assert.equal(ids.length,15);assert.equal(new Set(ids).size,15);for(const id of ids)assert.match(id,/^[a-f0-9]{64}$/);
 assert.deepEqual(Array.from(api.wallets.slice(0,6),w=>w.name),['MetaMask','Trust Wallet','OKX Wallet','Binance Wallet','Bitget Wallet','TokenPocket']);
 assert.equal(api.wallets.filter(w=>w.name==='OKX Wallet').length,1);assert.ok(Object.isFrozen(api.wallets));for(const wallet of api.wallets)assert.ok(Object.isFrozen(wallet));
 assert.deepEqual(Array.from(options.includeWalletIds),ids);assert.deepEqual(Array.from(options.featuredWalletIds),ids);
 assert.equal(options.allWallets,'SHOW');assert.equal(options.customWallets.length,0);assert.equal(options.enableEIP6963,false);assert.equal(options.enableWalletGuide,false);
 assert.equal(options.features.email,false);assert.equal(options.features.socials,false);assert.deepEqual(Array.from(options.features.connectMethodsOrder),['wallet']);assert.deepEqual(Array.from(options.features.connectorTypeOrder),['featured']);
}
test('原Promise成功、拒绝与弹窗先关闭有独立证据，保留原结果和异常',async()=>{
 for(const mode of ['resolved','rejected','closed']){
  const storage=pickerStorage(),restore=pickerGlobals(storage),p=tracePorts(),rows=[],failure=new Error('Connection already closed');let rejectLate;
  const trace=api.connectTrace(row=>rows.push(row));trace.bind(p.provider);
  p.provider.connect=()=>mode==='resolved'?Promise.resolve('synthetic-result'):mode==='rejected'?Promise.reject(failure):new Promise((_,reject)=>{rejectLate=reject;});
  const modal={open:async()=>{},subscribeState(callback){if(mode==='closed')queueMicrotask(()=>callback({open:false}));return()=>{};},close:async()=>{}};
  try{
   const pending=api.connectWallet(p.provider,choose('USDC','ethereum'),{},()=>modal,()=>{},trace);
   if(mode==='resolved')assert.equal(await pending,'synthetic-result');
   else await assert.rejects(pending,error=>mode==='rejected'?error===failure:error.message==='钱包连接已取消');
   assert.equal(rows.at(-1).winner,mode==='closed'?'modal_closed':'provider_'+mode);assert.equal(rows.at(-1).event,'end');assert.equal(rows.at(-1).complete,true);
   const count=rows.length;if(rejectLate){rejectLate(failure);await Promise.resolve();assert.equal(rows.length,count);}
  }finally{restore();}
 }
});
test('真实连接入口先注册观察再open和connect，出口故障不改变结果且不等待ready',async()=>{
 for(const broken of [false,true]){
  const storage=pickerStorage(),restore=pickerGlobals(storage),order=[],rows=[];let listener;
  const provider={
   on(name,fn){assert.equal(name,'display_uri');listener=fn;order.push('listen');},
   removeListener(name,fn){assert.equal(name,'display_uri');assert.equal(fn,listener);listener=undefined;order.push('remove');},
   async connect(){assert.equal(typeof listener,'function');order.push('connect');this.uri='synthetic-current';listener(this.uri);return 'synthetic-result';}
  };
  try{
   const result=await api.connectWallet(provider,choose('USDC','ethereum'),{},()=>({
    async open(){order.push('open');},subscribeState:()=>()=>{},async close(){order.push('close');},ready(){throw Error('取证不能增加ready等待');}
   }),row=>{if(broken)throw Error('synthetic outlet failure');rows.push(row);});
   assert.equal(result,'synthetic-result');assert.deepEqual(order,['listen','open','connect','remove','close']);assert.equal(listener,undefined);
   if(!broken){assert.equal(rows[0].listening,true);assert.equal(rows.at(-1).complete,true);assert.equal(rows.at(-1).emitted,true);assert.equal(rows.at(-1).stage,'end');assert.ok(!JSON.stringify(rows).includes('synthetic-'));}
  }finally{restore();}
 }
});
test('15钱包真实选择入口固定顺序，只清选择器历史而保留原单和会话',async()=>{
 const storage=pickerStorage(),restore=pickerGlobals(storage);let captured,closed=0,unsubscribed=0,connected=0;
 try{
  const provider={connect:async proposal=>{connected++;assert.equal(Object.keys(proposal.optionalNamespaces).join(),'eip155');assert.equal(proposal.optionalNamespaces.eip155.chains[0],chains.base);storage.setItem('@appkit/recent_wallets','synthetic-success-preference');return 'synthetic-session-result';}};
  const result=await api.connectWallet(provider,choose('USDC','base'),{features:{analytics:false},includeWalletIds:['outside-wallet'],featuredWalletIds:['outside-wallet'],customWallets:[{id:'outside-wallet'}]},options=>{
   captured=options;assertPicker(options);assert.equal(storage.getItem('@appkit/recent_wallets'),null);assert.equal(storage.getItem('@appkit/recent_wallet'),null);
   return {open:async()=>{},subscribeState:()=>()=>{unsubscribed++;},close:async()=>{closed++;}};
  });
  assert.equal(result,'synthetic-session-result');assert.equal(connected,1);assert.equal(closed,1);assert.equal(unsubscribed,1);assert.equal(captured.features.analytics,false);
  assert.deepEqual([...new Set(storage.removed)].sort(),['@appkit/recent_wallet','@appkit/recent_wallets']);
  assert.equal(storage.getItem('@appkit/recent_wallets'),null);assert.equal(storage.getItem('@appkit/connections'),'synthetic-session');assert.equal(storage.getItem('topup.json'),'synthetic-original-order');assert.equal(storage.getItem('other-setting'),'keep');
 }finally{restore();}
});
test('真实AppKit目录请求覆盖推荐、全部和搜索，历史条目不改变前六顺序',async()=>{
 const controllers=require('@reown/appkit-controllers');
 const {ApiController,OptionsController,ConnectorController,ConnectorUtil}=controllers;
 const storage=pickerStorage(),restoreBox=pickerGlobals(storage),saved=new Map();
 for(const key of ['window','navigator','localStorage','fetch'])saved.set(key,Object.getOwnPropertyDescriptor(globalThis,key));
 const directory=Array.from(api.wallets,w=>({...w,mobile_link:'synthetic://',chains:['eip155:1','eip155:8453','eip155:56']}));directory.push({name:'Outside Wallet',id:'outside-wallet',mobile_link:'outside://',chains:['eip155:8453']});
 const requests=[];
 try{
  Object.defineProperty(globalThis,'navigator',{configurable:true,value:{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)'}});
  Object.defineProperty(globalThis,'window',{configurable:true,value:{navigator:globalThis.navigator,location:{href:'file:///synthetic/walletconnect.html'}}});
  Object.defineProperty(globalThis,'localStorage',{configurable:true,value:storage});
  globalThis.fetch=async input=>{
   const url=new URL(typeof input==='string'?input:input.url??input.href);assert.equal(url.pathname,'/getWallets');requests.push(url);
   const include=(url.searchParams.get('include')??'').split(',');assert.deepEqual(include,directory.slice(0,15).map(w=>w.id));
   const exclude=(url.searchParams.get('exclude')??'').split(','),search=(url.searchParams.get('search')??'').toLowerCase();
   const data=directory.filter(w=>include.includes(w.id)&&!exclude.includes(w.id)&&w.name.toLowerCase().includes(search));
   return new Response(JSON.stringify({count:data.length,data:[...data].reverse()}),{status:200,headers:{'content-type':'application/json'}});
  };
  await api.connectWallet({connect:async()=>null},choose('USDC','base'),{features:{}},options=>{
   assertPicker(options);
   return {async open(){
    OptionsController.setOptions({projectId:'synthetic-project',sdkVersion:'html-core-1.8.19',sdkType:'appkit',isUniversalProvider:true,...JSON.parse(JSON.stringify(options))});
    ApiController.state.featured=[];ApiController.state.recommended=[];ApiController.state.wallets=[];ApiController.state.search=[];
    ConnectorController.state.connectors=[{id:'walletConnect',name:'WalletConnect',type:'WALLET_CONNECT',chain:'eip155'}];
    await ApiController.fetchFeaturedWallets();
    const items=ConnectorUtil.connectorList();assert.equal(items.length,15);assert.ok(items.every(item=>item.kind==='wallet'));assert.deepEqual(items.map(item=>item.wallet.id),directory.slice(0,15).map(w=>w.id));
    await ApiController.fetchRecommendedWallets();assert.equal(ApiController.state.recommended.length,0);
    await ApiController.fetchWalletsByPage({page:1});assert.ok(ApiController.state.wallets.every(w=>options.includeWalletIds.includes(w.id)));
    await ApiController.searchWallet({search:'Wallet'});assert.ok(ApiController.state.search.length>0);assert.ok(ApiController.state.search.every(w=>options.includeWalletIds.includes(w.id)));assert.ok(!ApiController.state.search.some(w=>w.id==='outside-wallet'));
    assert.equal(requests.length,4);
   },subscribeState:()=>()=>{},close:async()=>{}};
  });
 }finally{
  for(const [key,descriptor]of saved){if(descriptor)Object.defineProperty(globalThis,key,descriptor);else delete globalThis[key];}
  restoreBox();
 }
});
test('钱包选择取消和目录失败沿原流程停止，关闭后不请求签名或付款',async()=>{
 for(const failure of ['cancel','directory']){
  const storage=pickerStorage(),restore=pickerGlobals(storage);let closed=0,unsubscribed=0,connections=0;
  try{
   const pending=api.connectWallet({connect:async()=>{connections++;return new Promise(()=>{});}},choose('USDT','tron'),{features:{}},options=>({
    open:async()=>{assertPicker(options);if(failure==='directory')throw Error('synthetic directory failure');},
    subscribeState(callback){queueMicrotask(()=>callback({open:false}));return()=>{unsubscribed++;};},close:async()=>{closed++;}
   }));
   await assert.rejects(pending,failure==='cancel'?/钱包连接已取消/:/synthetic directory failure/);
   assert.equal(connections,failure==='cancel'?1:0);assert.equal(closed,1);assert.equal(unsubscribed,failure==='cancel'?1:0);assert.equal(storage.getItem('topup.json'),'synthetic-original-order');
  }finally{restore();}
 }
});
test('无法清除历史展示偏好时不打开选择器或发起连接',async()=>{
 const storage=pickerStorage();storage.removeItem=()=>{throw Error('synthetic cache failure');};const restore=pickerGlobals(storage);let opened=0,connected=0;
 try{
  await assert.rejects(api.connectWallet({connect:async()=>{connected++;}},choose('USDC','solana'),{},()=>{opened++;}),/synthetic cache failure/);
  assert.equal(opened,0);assert.equal(connected,0);assert.equal(storage.getItem('topup.json'),'synthetic-original-order');
 }finally{restore();}
});
