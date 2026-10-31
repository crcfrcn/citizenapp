import {PACKAGE_VERSION} from '@reown/appkit/constants';
import {metamask} from './metamask.js';
import {imtoken} from './imtoken.js';
import {trust} from './trust.js';
import {binance} from './binance.js';
import {okx} from './okx.js';
import {coinbase} from './coinbase.js';

// 三协议付款只走一次冻结流程；所有阶段须等App原子落盘回执，不存或请求钱包私钥。
export const chains={ethereum:'eip155:1',base:'eip155:8453',bnb:'eip155:56',tron:'tron:0x2b6653dc',solana:'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'};
const pairs={USDC:['ethereum','base','solana'],USDT:['ethereum','tron','bnb']};
const required={eip155:['personal_sign','eth_sendTransaction'],tron:['tron_signMessage','tron_signTransaction'],solana:['solana_signMessage','solana_signTransaction']};
const walletTimeout=180000;
const normalize=(n,a)=>n==='tron'||n==='solana'?a:a.toLowerCase();

// 品牌只在各自文件定义，登记顺序唯一；禁用与未适配的钱包均不能初始化SDK。
export const wallets=Object.freeze([metamask,imtoken,trust,binance,okx,coinbase]);
function enabledWallet(id){
 const wallet=wallets.find(item=>item.id===id);
 if(!wallet?.enabled||typeof wallet.connect!=='function'||typeof wallet.connectionUrl!=='function'||typeof wallet.accepts!=='function')throw Error('该钱包暂未开放');
 return wallet;
}
// 原生来源核验通过后立即显示，不等待SDK、目录或Relay；重复点击只产生一次选择。
export function pickWallet(document,projectId){
 const grid=document.getElementById('wallets');
 const imageParams=new URLSearchParams({projectId,st:'appkit',sv:'html-core-'+PACKAGE_VERSION});
 return new Promise(resolve=>{
  let selected=false;
  for(const wallet of wallets){
   const button=document.createElement('button');button.type='button';button.className='wallet';
   button.disabled=!wallet.enabled;button.setAttribute('aria-disabled',String(!wallet.enabled));
   const icon=document.createElement('img');icon.src='https://api.web3modal.org/getWalletImage/'+wallet.image+'?'+imageParams.toString();icon.alt='';icon.width=64;icon.height=64;
   const label=document.createElement('span');label.textContent=wallet.name;
   button.append(icon,label);
   if(!wallet.enabled){const state=document.createElement('small');state.textContent='暂未开放';button.append(state);}
   button.addEventListener('click',()=>{
    if(selected||!wallet.enabled)return;
    enabledWallet(wallet.id);selected=true;
    for(const item of grid.children)item.disabled=true;
    grid.hidden=true;document.getElementById('spinner').hidden=false;
    document.getElementById('title').textContent='正在连接 '+wallet.name;
    document.getElementById('sub').textContent='请在钱包中确认连接';
    resolve(wallet.id);
   });
   grid.append(button);
  }
 });
}
// 已选适配进入共用UniversalProvider；AppKit保留公开连接监听，以headless关闭其选择UI。
export async function connectWallet(provider,chosen,options,createAppKit,report=()=>{},trace,links={}){
 const adapter=enabledWallet(links.walletId);
 const {ConnectionController}=await import('@reown/appkit-controllers');
 const observed=observeConnection(provider,ConnectionController,report);
 let modal,unsubscribe,removeCancel,timer;let connecting=true,called=false,launched=false;
 let rejectLaunch;
 const launchFailure=new Promise((_,reject)=>{rejectLaunch=reject;});
 const display=uri=>{
  if(launched||!connecting||typeof uri!=='string'||!uri)return;
  launched=true;
  // 只打开用户选中的品牌，等待原生明确回执；URI始终只留在内存和原桥接中。
  void Promise.resolve().then(()=>{if(connecting)return adapter.connectionUrl(uri).then(url=>links.openWallet?.(url));})
   .catch(()=>rejectLaunch(Error('无法打开所选钱包')));
 };
 try{
  const ids=[adapter.id];
  modal=createAppKit({...options,disableAppend:true,includeWalletIds:ids,featuredWalletIds:ids,
   allWallets:'HIDE',customWallets:[],enableEIP6963:false,enableWalletGuide:false,
   features:{...options.features,headless:true,email:false,socials:false,connectMethodsOrder:['wallet'],connectorTypeOrder:['featured']}});
  await modal.open({view:'Connect'});
  let cancel;
  const closed=new Promise((_,reject)=>{
   cancel=()=>{if(!connecting)return;connecting=false;trace?.settle('modal_closed');reject(Error('钱包连接已取消'));};
   let opened=true;unsubscribe=modal.subscribeState(state=>{if(opened&&!state.open)cancel();opened=state.open;});
  });
  removeCancel=links.subscribeCancel?.(cancel);
  provider.on('display_uri',display);
  observed.connect();trace?.event('connect');called=true;
  const connection=provider.connect(proposal(chosen));
  // 原Promise参与竞赛，观察不包装、不吞掉原拒绝；失败与取消不会改投其他钱包。
  if(trace)void connection.then(()=>trace.settle('provider_resolved'),error=>trace.settle('provider_rejected',error));
  const expired=new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('钱包连接等待超时')),links.timeout??walletTimeout);});
  return await Promise.race([connection,closed,launchFailure,expired]);
 }catch(error){trace?.settle(called?'provider_rejected':'modal_open_failed',error);throw error;}
 finally{clearTimeout(timer);connecting=false;observed.end();provider.removeListener('display_uri',display);removeCancel?.();unsubscribe?.();await modal?.close();}
}
// 一个文档只绑定一个已选钱包。SDK后续window.open与首次连接共用原生桥接；
// 请求有独立结束条件，旧回执和其它品牌链接不能唤起钱包或推进下一步。
export function walletBridge(adapter,openWallet,host=window,{timeout=walletTimeout}={}){
 if(enabledWallet(adapter?.id)!==adapter)throw Error('该钱包暂未开放');
 let active=true,pending;const cancelHandlers=new Set();
 const launch=async url=>{
  if(!active||!adapter.accepts(url))throw Error('钱包链接与所选钱包不一致');
  const parsed=new URL(url);
  if(parsed.searchParams.has('requestId')&&(!pending||parsed.searchParams.get('sessionTopic')!==pending.topic))throw Error('本次付款已结束');
  const state=pending,operation=Promise.resolve().then(()=>openWallet(url));
  state?.opens.push(operation);
  try{return await operation;}catch(_){const error=Error('无法打开所选钱包');if(pending===state)state?.reject(error);throw error;}
 };
 // 回执失败交给当前请求的竞赛处理，不让window.open的void接口丢掉失败或自由输出异常。
 host.open=url=>{const state=pending;void launch(url).catch(error=>{if(pending===state)state?.reject(error);});return null;};
 return {
  open:launch,
  async request(provider,request){
   if(!active||pending)throw Error('本次付款已结束');
   let reject,removeFocus=()=>{};
   const failed=new Promise((_,failure)=>{reject=failure;});
   const state={topic:request.topic,opens:[],reject};pending=state;
   const timer=setTimeout(()=>reject(Error('钱包请求等待超时')),timeout);
   try{
    const document=host.document;
    const foreground=()=>document?.visibilityState!=='hidden'&&document?.hasFocus?.()!==false;
    if(!foreground()){
     const ready=new Promise(resolve=>{
      const resume=()=>{if(foreground())resolve();};
      host.addEventListener('focus',resume);document.addEventListener('visibilitychange',resume);
      removeFocus=()=>{host.removeEventListener('focus',resume);document.removeEventListener('visibilitychange',resume);};
     });
     await Promise.race([ready,failed]);removeFocus();
    }
    if(!active)throw Error('本次付款已结束');
    const response=await Promise.race([Promise.resolve().then(()=>provider.client.request(request)),failed]);
    await Promise.race([Promise.all(state.opens),failed]);
    if(!active)throw Error('本次付款已结束');
    return response;
   }finally{clearTimeout(timer);removeFocus();if(pending===state)pending=undefined;}
  },
  subscribeCancel(callback){cancelHandlers.add(callback);return()=>cancelHandlers.delete(callback);},
  close(){if(!active)return;active=false;pending?.reject(Error('本次付款已结束'));for(const cancel of cancelHandlers)cancel();cancelHandlers.clear();}
 };
}
// 只读观察已锁SDK的公开产生/接收边界；URI仅在闭包中比较，出口只接收固定布尔快照。
// 不等待ready、不setUri、不重试；观察失败不得替换原连接结果，旧URI不算本轮接收。
export function observeConnection(provider,controller,report){
 let listening=false,connecting=false,emitted=false,matched=false,complete=true,baseline=false,uri,unsubscribe,ended=false;
 const snapshot=stage=>{
  let providerUri=false,modalUri=false;
  try{providerUri=typeof provider.uri==='string'&&provider.uri.length>0;modalUri=typeof controller.state.wcUri==='string'&&controller.state.wcUri.length>0;matched ||= emitted&&controller.state.wcUri===uri;}catch(_){complete=false;}
  try{report({stage,listening,connecting,emitted,provider_uri:providerUri,modal_uri:modalUri,matched,baseline,complete});}catch(_){complete=false;}
 };
 const display=value=>{if(ended)return;if(typeof value!=='string'||!value){complete=false;return;}uri=value;emitted=true;snapshot('uri');};
 try{
  baseline=Boolean(provider.uri)||Boolean(controller.state.wcUri);
  provider.on('display_uri',display);
  unsubscribe=controller.subscribeKey('wcUri',()=>{if(!ended)snapshot('modal');});
  listening=true;
 }catch(_){complete=false;}
 snapshot('start');
 return {
  connect(){connecting=true;snapshot('connect');},
  end(){if(ended)return;snapshot('end');ended=true;try{provider.removeListener('display_uri',display);}catch(_){}try{unsubscribe?.();}catch(_){}uri=undefined;}
 };
}
// 已锁SDK公开logger的参数仅在内存精确分类，未知值不转发、不序列化。
export function connectFailure(value){
 try{
  const read=key=>value&&typeof value==='object'?Object.getOwnPropertyDescriptor(value,key)?.value:undefined;
  const message=typeof value==='string'?value:read('message');
  const relayReasons=new Map([
   ['Unauthorized: origin not allowed','origin_denied'],
   ['Authorization error: Unauthorized: invalid key','invalid_key'],
   ['Authorization error: Project ID is missing','project_missing'],
   ['Unauthorized','relay_unauthorized'],
  ]);
  const messages=new Map([
   ['No internet connection detected. Please restart your network and try again.','offline'],
   ['Connection interrupted while trying to connect','socket_interrupted'],
   ['Connection interrupted while trying to subscribe','subscribe_interrupted'],
   ['Connection already closed','socket_closed'],['WebSocket connection is missing or invalid','socket_missing'],
   ['无法打开所选钱包','wallet_open_failed'],['钱包唤起配置不可用','wallet_open_failed'],
   ['钱包连接等待超时','connect_timeout'],['钱包请求等待超时','request_timeout'],['本次付款已结束','cancelled'],
   ['钱包连接已取消','user_closed'],['钱包链接与所选钱包不一致','wallet_mismatch'],
   ['Proposal expired','proposal_expired'],['Sign Client not initialized','client_missing'],
   ['Failed to publish payload','publish_failed'],['Failed to Publish Payload','publish_failed'],
   ['Unexpected server response: 401','http_401'],['Unexpected server response: 403','http_403'],
   ['Unexpected server response: 429','http_429'],['Unexpected server response: 503','http_503'],
  ]);
  for(const [reason,category]of relayReasons){messages.set(reason,category);messages.set(`WebSocket connection closed abnormally with code: 3000 (${reason})`,category);}
  for(const host of ['relay.walletconnect.org','relay.walletconnect.com']){
   messages.set('Socket stalled when trying to connect to wss://'+host,'socket_stalled');
   messages.set('WebSocket connection failed for host: '+host,'socket_failed');
  }
  const allowed=new Set([0,401,403,429,503,4001,1000,1001,1006,1008,1011,1013,3000,-32600,-32601,-32602,-32603]);
  const code=read('code');
  const knownClose=[...relayReasons.keys()].some(reason=>message===`WebSocket connection closed abnormally with code: 3000 (${reason})`);
  return {error:code===4001?'user_rejected':messages.get(message)??(value instanceof TypeError?'type':'other'),code:knownClose?'3000':allowed.has(code)?String(code):'none'};
 }catch(_){return {error:'other',code:'none'};}
}
export function connectTrace(report){
 let relay,topic,ended=false,complete=true,pairing=false,subscribed=false,published=false,attempts=0,stalls=0,winner='pending',lastError='none',lastCode='none';
 const removers=[],publishIds=new Set();
 const event=(name,failure)=>{
  if(ended)return;
  if(failure){const safe=connectFailure(failure);lastError=safe.error;lastCode=safe.code;}
  let connected=false,connecting=false;
  try{connected=relay?.connected===true;connecting=relay?.connecting===true;}catch(_){complete=false;}
  try{report({stage:'trace',event:name,winner,error:lastError,code:lastCode,pairing,subscribed,published,relay_connected:connected,relay_connecting:connecting,attempts,stalls,complete});}catch(_){complete=false;}
 };
 const log=(...args)=>{
  if(ended)return;
  for(const value of args){
   // 本锁版本以wc_proposeSession/pairingTopic发提案；回执params会被覆盖，只在内存关联原请求ID。
   try{
    const request=value&&typeof value==='object'&&value.type==='message'&&value.direction==='outgoing'?value.request:undefined;
    if(topic&&request?.method==='wc_proposeSession'&&request.params?.pairingTopic===topic&&['string','number'].includes(typeof request.id))publishIds.add(String(request.id));
   }catch(_){complete=false;}
   if(typeof value==='string'){
    let attempt=false;
    for(const host of ['relay.walletconnect.org','relay.walletconnect.com'])for(let i=1;i<=5;i++)if(value===`Connecting to wss://${host}, attempt: ${i}...`){attempts=Math.min(20,attempts+1);event('attempt');attempt=true;}
    if(attempt)continue;
   }
   const safe=connectFailure(value);
   if(safe.error!=='other'||safe.code!=='none'){if(safe.error==='socket_stalled')stalls=Math.min(20,stalls+1);event('sdk_error',value);}
  }
 };
 const logger={level:'trace',child:()=>logger,bindings:()=>({}),setBindings(){},isLevelEnabled:()=>true,trace:log,debug:log,info:log,warn:log,error:log,fatal:log,silent(){}};
 const listen=(target,name,handler)=>{target.on(name,handler);removers.push(()=>target.off(name,handler));};
 const sockets=new WeakSet();
 const wireSocket=()=>{
  const socket=relay?.provider?.connection;
  if(!socket||sockets.has(socket))return;
  sockets.add(socket);
  listen(socket,'close',value=>event('socket_close',{code:value?.code,message:value?.reason}));
 };
 return {
  logger,event,
  bind(provider){
   try{
    const core=provider.client.core;relay=core.relayer;
    // pairing_create位于formatUri之后、持久化/订阅之前；topic仅关联本次回执。
    listen(core.pairing.events,'pairing_create',value=>{if(ended)return;topic=value.topic;pairing=true;event('pairing');});
    listen(relay,'relayer_connect',()=>{wireSocket();event('relay_open');});
    listen(relay,'relayer_disconnect',()=>event('relay_closed'));
    listen(relay,'relayer_error',error=>event('relay_error',error));
    listen(relay.subscriber,'subscription_created',value=>{if(value.topic===topic){subscribed=true;event('subscribed');}});
    listen(relay,'relayer_publish',value=>{if(['string','number'].includes(typeof value.id)&&publishIds.has(String(value.id))){published=true;event('published');}});
    wireSocket();
   }catch(_){complete=false;}
   event('ready');
  },
  settle(result,error){if(ended||winner!=='pending')return;winner=result;if(result==='modal_closed')lastError='user_closed';event(result,error);},
  end(){if(ended)return;event('end');ended=true;for(const remove of removers){try{remove();}catch(_){}}publishIds.clear();topic=undefined;}
 };
}
// 选择来自App的一次明确点击，不能从会话默认链补齐缺失字段。
export function selection(value){
 if(!value||typeof value!=='object'||Object.keys(value).sort().join()!=='network,package_id,token'||!pairs[value.token]?.includes(value.network)||!['pkg_10','pkg_900'].includes(value.package_id))throw Error('付款选择无效');
 return Object.freeze({token:value.token,package_id:value.package_id,network:value.network});
}
export function proposal(value){
 const chosen=selection(value),chain=chains[chosen.network],ns=chain.split(':')[0];
 // UniversalProvider 2.23.10公开connect参数使用optionalNamespaces；返回后强制核对必要授权。
 const optionalNamespaces={[ns]:{chains:[chain],methods:[...required[ns]],events:ns==='eip155'?['chainChanged','accountsChanged']:[]}};
 return {optionalNamespaces};
}
export function context(session,value,active){
 const chosen=selection(value),chain=chains[chosen.network],ns=chain.split(':')[0],info=session?.namespaces?.[ns];
 if(!required[ns].every(method=>info?.methods?.includes(method))||active&&active!==chain)throw Error('钱包未确认所选网络');
 const candidates=[];
 for(const account of info.accounts??[]){const parts=account.split(':');if(parts.length===3&&parts.slice(0,2).join(':')===chain)candidates.push({network:chosen.network,chain,payer:normalize(chosen.network,parts[2])});}
 const unique=[...new Map(candidates.map(c=>[c.payer,c])).values()];
 if(unique.length!==1||!unique[0].payer)throw Error('请在钱包中确认所选链的唯一付款账户');
 return unique[0];
}
// 使用WalletConnect认证会话；会话授权列表不当作钱包全局当前链，所有请求都明确指向目标链。
export async function bindSession(provider,value,send=request=>provider.client.request(request)){
 const chosen=selection(value),chain=chains[chosen.network],ns=chain.split(':')[0],topic=provider.session?.topic;
 if(!topic)throw Error('钱包未连接');
 let active,invalidated=false,bound=false;const removers=[];
 const listen=(name,callback)=>{provider.client.on(name,callback);removers.push(()=>provider.client.removeListener(name,callback));};
 const current=()=>provider.client.session.get(topic);
 listen('session_event',event=>{
  if(event.topic!==topic)return;
  if(event.params.event.name==='chainChanged'){
   const id=event.params.event.data;active=typeof id==='string'&&id.includes(':')?id:'eip155:'+Number(id);
   if(bound&&active!==chain)invalidated=true;
  }else if(event.params.event.name==='accountsChanged'&&bound)invalidated=true;
 });
 for(const name of ['session_update','session_delete','session_expire'])listen(name,event=>{if(event.topic===topic&&(bound||name!=='session_update'))invalidated=true;});
 const read=()=>{if(invalidated)throw Error('付款账户、网络或会话已变化');const c=context(current(),chosen,active);bound=true;return c;};
 read();
 return {
  context:read,
  close(){invalidated=true;for(const remove of removers.splice(0))remove();},
  request:async(c,method,params)=>{
   unchanged(c,read());if(!current().namespaces[ns]?.methods?.includes(method))throw Error('钱包未授权付款方法');
   if(method==='eth_sendTransaction'&&(!params?.[0]||params[0].chainId!=='0x'+Number(chain.split(':')[1]).toString(16)||normalize(chosen.network,params[0].from)!==c.payer))throw Error('付款交易网络或账户不一致');
   return send({topic,chainId:chain,request:{method,params}});
  }
 };
}
function unchanged(expected,current){if(expected.network!==current.network||expected.chain!==current.chain||expected.payer!==current.payer)throw Error('付款账户或网络已变化，未继续付款');}
const unexpired=(p,now)=>{if(!Number.isSafeInteger(p.expiresAt)||now()>=p.expiresAt)throw Error('付款意图已过期，未发起转账');};
/// 流程是唯一实现；测试注入的wallet/builder遵循同一公开方法，不绕过阶段落盘。
export async function paymentFlow({wallet,builder,ask,selection:value,now=Date.now,progress=()=>{}}){
 progress('account');const chosen=selection(value),original=await wallet.context();
 if(original.network!==chosen.network||original.chain!==chains[chosen.network])throw Error('钱包网络与所选网络不一致');
 progress('intent');const p=await ask('connected',{...original,token:chosen.token,package_id:chosen.package_id});
 const returned=selection(p.selection);if(JSON.stringify(returned)!==JSON.stringify(chosen))throw Error('付款选择已变化');
 unchanged(original,p.context);unexpired(p,now);
 if(typeof p.message!=='string'||!p.message.startsWith('CitizenServe Topup v1\n'))throw Error('付款授权无效');
 unchanged(original,await wallet.context());unexpired(p,now);
 progress('authorization');const signature=p.signature??await wallet.signMessage(original,p.message);
 unchanged(original,await wallet.context());unexpired(p,now);
 await ask('authorization',{...original,signature});
 progress('transaction');const transaction=await builder.prepare(original,p);
 unchanged(original,await wallet.context());unexpired(p,now);
 // EVM由钱包签名并广播；Tron/Solana先取得原字节，持久化后才广播。
 const signed=await wallet.signTransaction(original,transaction);
 unchanged(original,await wallet.context());unexpired(p,now);
 const frozen=await builder.freeze(original,transaction,signed);
 progress('submitting');await ask('submitting',{...original,...frozen});
 unexpired(p,now);unchanged(original,await wallet.context());
 const txid=await builder.broadcast(original,frozen,wallet);
 if(frozen.txid&&txid!==frozen.txid)throw Error('广播回执与原交易不一致，请核实原订单');
 progress('submitted');await ask('submitted',{...original,txid});progress('complete');return txid;
}

// 用户明确继续时仅广播保护记录中的原签名字节，不连接钱包、不重签或重建交易。
export async function replayFlow({builder,ask,replay,selection:value,now=Date.now}){
 const chosen=selection(value),c=replay.context;
 if(c?.network!==chosen.network)throw Error('原交易网络与所选网络不一致');
 if(!['tron','solana'].includes(c?.network)||chains[c.network]!==c.chain||!replay.txid||!replay.wire)throw Error('缺少原签名交易');
 unexpired(replay,now);await builder.validate(c,replay);
 await ask('replay',{...c,wire:replay.wire,txid:replay.txid});unexpired(replay,now);
 const txid=await builder.broadcast(c,replay);
 if(txid!==replay.txid)throw Error('广播回执与原交易不一致');
 await ask('submitted',{...c,txid});return txid;
}

const https=value=>{const u=new URL(value);if(u.protocol!=='https:'||u.username||u.password||u.hash||u.search)throw Error('付款节点配置无效');return u.href;};
export async function buildTron(payer,p,TronWeb){
 const web=tronClient(TronWeb,p.rpc);
 const genesis=await web.trx.getBlock(0);
 if(genesis.blockID!=='00000000000000001ebf88508a03865c71d452e25f4d51194196a1d22b6653dc')throw Error('付款节点不是Tron主网');
 const result=await web.transactionBuilder.triggerSmartContract(p.asset,'transfer(address,uint256)',{feeLimit:100000000,callValue:0},[{type:'address',value:p.receiver},{type:'uint256',value:p.amount}],payer);
 if(!result.result?.result||!result.transaction?.txID)throw Error('未能构造Tron付款');return result.transaction;
}
// SDK负责协议构造；公开HTTP Provider仅收紧传输，禁止重定向降级或越出付款API。
export function tronClient(TronWeb,url){
 const base=https(url).replace(/\/$/,'');
 const web=new TronWeb({fullHost:base});
 class HttpsProvider extends web.providers.HttpProvider {
  async request(path,payload={},method='get'){
   if(method.toLowerCase()!=='post'||!['wallet/getblockbynum','wallet/triggersmartcontract','wallet/broadcasttransaction'].includes(path))throw Error('未允许的付款节点请求');
   const response=await fetch(base+'/'+path,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(payload),redirect:'error',signal:AbortSignal.timeout(15000)});
   if(!response.ok)throw Error('付款节点暂不可用');return response.json();
  }
 }
 const node=new HttpsProvider(base);web.setFullNode(node);web.setSolidityNode(node);web.setEventServer(node);return web;
}
export async function buildSolana(payer,p,web3,spl,request){
 if(await request('getGenesisHash',[])!=='5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d')throw Error('付款节点不是Solana主网');
 const latest=await request('getLatestBlockhash',[{commitment:'finalized'}]);
 const owner=new web3.PublicKey(payer),mint=new web3.PublicKey(p.mint),recipient=new web3.PublicKey(p.receiver);
 const source=await spl.getAssociatedTokenAddress(mint,owner),destination=await spl.getAssociatedTokenAddress(mint,recipient);
 const tx=new web3.Transaction({feePayer:owner,blockhash:latest.value.blockhash,lastValidBlockHeight:latest.value.lastValidBlockHeight});
 tx.add(spl.createAssociatedTokenAccountIdempotentInstruction(owner,destination,recipient,mint));
 tx.add(spl.createTransferCheckedInstruction(source,mint,destination,owner,BigInt(p.amount),p.decimals));
 return tx;
}
export async function defaultBuilder(solanaRpc){
 const [{Buffer},{default:bs58}]=await Promise.all([import('buffer'),import('bs58')]);
 return {
  async prepare(c,p){
   if(c.network==='tron'){const {TronWeb}=await import('tronweb');return {raw:await buildTron(c.payer,p,TronWeb),rpc:p.rpc};}
   if(c.network==='solana'){const [web3,spl]=await Promise.all([import('@solana/web3.js'),import('@solana/spl-token')]);const raw=await buildSolana(c.payer,p,web3,spl,(method,params)=>solanaRpc(c,method,params));return {raw,web3,rpc:p.rpc};}
   if(!/^0xa9059cbb[0-9a-f]{128}$/.test(p.data))throw Error('付款数据无效');return {raw:{from:c.payer,to:p.asset,data:p.data,value:'0x0',chainId:'0x'+Number(c.chain.split(':')[1]).toString(16)}};
  },
  async freeze(c,tx,signed){
   if(c.network==='tron'){
    const {TronWeb}=await import('tronweb');
    if(signed?.raw_data_hex!==tx.raw.raw_data_hex||signed?.txID!==tx.raw.txID||JSON.stringify(signed.raw_data)!==JSON.stringify(tx.raw.raw_data)||!Array.isArray(signed.signature)||signed.signature.length!==1||tronClient(TronWeb,tx.rpc).trx.ecRecover(signed)!==c.payer)throw Error('钱包修改了原付款交易');
    return {txid:signed.txID,wire:JSON.stringify(signed),rpc:tx.rpc};
   }
   if(c.network==='solana'){
    const bytes=Buffer.from(signed.transaction??'', 'base64');
    // 标准钱包也可只返回签名；只装回原消息，不能接受变化后的转账。
    let restored;
    if(bytes.length)restored=tx.web3.Transaction.from(bytes);
    else {restored=tx.raw;restored.addSignature(new tx.web3.PublicKey(c.payer),Buffer.from(bs58.decode(signed.signature)));}
    if(!Buffer.from(restored.serializeMessage()).equals(Buffer.from(tx.raw.serializeMessage()))||!restored.verifySignatures())throw Error('钱包修改了原付款交易');
    return {txid:bs58.encode(restored.signature),wire:Buffer.from(restored.serialize()).toString('base64'),rpc:tx.rpc};
   }
   return {transaction:tx.raw};
  },
  async validate(c,f){
   if(c.network==='tron'){
    const {TronWeb}=await import('tronweb');const web=tronClient(TronWeb,f.rpc),tx=JSON.parse(f.wire);
    if(tx.txID!==f.txid||web.trx.ecRecover(tx)!==c.payer||(await web.trx.getBlock(0)).blockID!=='00000000000000001ebf88508a03865c71d452e25f4d51194196a1d22b6653dc')throw Error('原Tron交易无效');
   }else{
    const web3=await import('@solana/web3.js'),tx=web3.Transaction.from(Buffer.from(f.wire,'base64'));
    if(!tx.verifySignatures()||tx.feePayer.toBase58()!==c.payer||bs58.encode(tx.signature)!==f.txid||await solanaRpc(c,'getGenesisHash',[])!=='5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d')throw Error('原Solana交易无效');
   }
  },
  async broadcast(c,f,wallet){
   if(c.network==='tron'){
    const {TronWeb}=await import('tronweb');const result=await tronClient(TronWeb,f.rpc).trx.sendRawTransaction(JSON.parse(f.wire));if(!result.result||result.txid!==f.txid)throw Error('付款广播回执待核实');return result.txid;
   }
   if(c.network==='solana')return await solanaRpc(c,'sendTransaction',[f.wire,{encoding:'base64',skipPreflight:false,preflightCommitment:'confirmed',maxRetries:3}]);
   return await wallet.request(c,'eth_sendTransaction',[f.transaction]);
  }
 };
}
async function walletConnect(adapter,{cfg,report,bridge,progress}){
 const walletId=adapter.id,openWallet=bridge.open;
 const trace=connectTrace(report);
 try{
 const [{default:UniversalProvider},{createAppKit},{defineChain,mainnet,base,bsc,solana},{default:bs58}]=await Promise.all([import('@walletconnect/universal-provider'),import('@reown/appkit'),import('@reown/appkit/networks'),import('bs58')]);
 const provider=await UniversalProvider.init({projectId:cfg.projectId,logger:trace.logger,metadata:{name:'CitizenApp',description:'链上充值购买公民币',url:'https://www.crcfrcn.com',icons:[],redirect:{native:'citizenapp://walletconnect'}}});
 trace.bind(provider);
 // 本次用户已选择新付款；结束本模块原连接，避免SDK把旧批准链带入新连接请求。
 if(provider.session)await provider.disconnect();
 const tron=defineChain({id:'0x2b6653dc',caipNetworkId:chains.tron,chainNamespace:'tron',name:'Tron',nativeCurrency:{name:'TRX',symbol:'TRX',decimals:6},rpcUrls:{default:{http:[cfg.rpc]}}});
 const chosen=selection(cfg.selection),network={ethereum:mainnet,base,bnb:bsc,tron,solana}[chosen.network];
 const networks=[{...network,rpcUrls:{default:{http:[cfg.rpc]}}}];
 await connectWallet(provider,chosen,{projectId:cfg.projectId,networks,manualWCControl:true,universalProvider:provider,enableAnalytics:false,enableNetworkSwitch:false,features:{analytics:false,swaps:false,onramp:false,send:false,receive:false}},createAppKit,report,trace,{walletId,openWallet,subscribeCancel(callback){
  const remove=bridge.subscribeCancel(callback);
  const cancel=document.getElementById('cancel');cancel.hidden=false;cancel.addEventListener('click',callback);
  return()=>{remove();cancel.removeEventListener('click',callback);cancel.hidden=true;};
 }});
 progress('account');trace.event('account');
 const channel=await bindSession(provider,chosen,request=>bridge.request(provider,request)),request=channel.request;
 return {
  context:channel.context,request,
  observe(stage,error){trace.event(stage,error);},
  close(){channel.close();trace.end();},
  async signMessage(c,message){
   if(c.network==='tron'){const r=await request(c,'tron_signMessage',{address:c.payer,message});const sig=r.signature;if(typeof sig!=='string')throw Error('付款授权无效');const {TronWeb}=await import('tronweb');if(await tronClient(TronWeb,cfg.rpc).trx.verifyMessageV2(message,sig)!==c.payer)throw Error('付款授权无效');return sig.startsWith('0x')?sig:'0x'+sig;}
   if(c.network==='solana'){const r=await request(c,'solana_signMessage',{pubkey:c.payer,message:bs58.encode(new TextEncoder().encode(message))});return r.signature;}
   const bytes=new TextEncoder().encode(message);return request(c,'personal_sign',['0x'+Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join(''),c.payer]);
  },
  async signTransaction(c,tx){
   if(c.network==='tron'){
    const version=provider.session.sessionProperties?.tron_method_version;
    if(version&&version!=='v1')throw Error('钱包Tron签名协议不支持');
    const transaction=version==='v1'?tx.raw:{transaction:tx.raw};
    const result=await request(c,'tron_signTransaction',{address:c.payer,transaction});return result?.result??result;
   }
   if(c.network==='solana')return request(c,'solana_signTransaction',{pubkey:c.payer,transaction:tx.raw.serialize({requireAllSignatures:false,verifySignatures:false}).toString('base64')});
   return null;
  }
 };
 }catch(error){trace.settle('setup_rejected',error);trace.end();throw error;}
}
let started=false,stop=()=>{};
export function cancel(){stop();}
export async function start(cfg){
 if(started)return;started=true;
 const pending=new Map();let sequence=0,stopped=false;
 const report=observation=>window.TopupBridge.postMessage(JSON.stringify({session:cfg.session,id:++sequence,kind:observation.stage==='trace'?'connection_trace':'connection_observation',observation}));
 const ask=(kind,payload)=>new Promise((resolve,reject)=>{if(stopped){reject(Error('本次付款已结束'));return;}const id=++sequence;const timer=setTimeout(()=>{pending.delete(id);reject(Error('付款回执待核实，请返回原订单'));},walletTimeout);pending.set(id,{resolve,reject,timer});window.TopupBridge.postMessage(JSON.stringify({session:cfg.session,id,kind,...payload}));});
 window.CitizenTopup.reply=(session,id,response)=>{if(stopped||session!==cfg.session)return;const p=pending.get(id);if(!p)return;pending.delete(id);clearTimeout(p.timer);response.ok?p.resolve(response.value):p.reject(Error(response.error??'付款流程已停止'));};
 let wallet,bridge,stage='connection';
 stop=()=>{if(stopped)return;stopped=true;bridge?.close();wallet?.close();for(const item of pending.values()){clearTimeout(item.timer);item.reject(Error('本次付款已结束'));}pending.clear();};
 const labels={connection:'正在连接钱包',account:'正在核对钱包账户',intent:'正在准备充值订单',authorization:'请在钱包中确认授权',transaction:'正在准备付款交易',submitting:'正在保存付款记录',submitted:'正在核实付款回执',complete:'付款已提交'};
 const progress=value=>{stage=value;wallet?.observe(value);document.getElementById('title').textContent=labels[value];};
 try{
  if(cfg.replay){document.getElementById('spinner').hidden=false;document.getElementById('title').textContent='正在核实原付款';document.getElementById('sub').textContent='请稍候，不会重新选择钱包或签名';stage='submitted';}
  const walletId=cfg.replay?null:await pickWallet(document,cfg.projectId);
  if(stopped)return;
  const builder=await defaultBuilder((c,method,params)=>ask('solana_rpc',{...c,method,params}));
  if(cfg.replay)await replayFlow({builder,ask,replay:cfg.replay,selection:cfg.selection});
  else {
   const adapter=enabledWallet(walletId);bridge=walletBridge(adapter,url=>ask('external_wallet',{url}));
   wallet=await adapter.connect({cfg,report,bridge,progress,walletConnect});
   await paymentFlow({wallet,builder,ask,selection:cfg.selection,progress});
  }
 }catch(error){
  if(stopped)return;
  const code=connectFailure(error).error;wallet?.observe('failure',error);
  document.getElementById('spinner').hidden=true;document.getElementById('title').textContent='本次付款已停止';
  document.getElementById('sub').textContent='请返回充值页面核实本次订单';
  window.TopupBridge.postMessage(JSON.stringify({session:cfg.session,id:++sequence,kind:'error',stage,code}));
 }finally{stop();}
}
