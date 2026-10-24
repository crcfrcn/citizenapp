// 三协议付款只走一次冻结流程；所有阶段须等App原子落盘回执，不存或请求钱包私钥。
export const chains={ethereum:'eip155:1',base:'eip155:8453',bnb:'eip155:56',tron:'tron:0x2b6653dc',solana:'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'};
const pairs={USDC:['ethereum','base','solana'],USDT:['ethereum','tron','bnb']};
const required={eip155:['personal_sign','eth_sendTransaction'],tron:['tron_signMessage','tron_signTransaction'],solana:['solana_signMessage','solana_signTransaction']};
const normalize=(n,a)=>n==='tron'||n==='solana'?a:a.toLowerCase();

// 钱包选择总名单固定15个；同一品牌只登记一个官方目录ID，前六项顺序不能变化。
export const wallets=Object.freeze([
 Object.freeze({name:"MetaMask",id:"c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96"}),
 Object.freeze({name:"Trust Wallet",id:"4622a2b2d6af1c9844944291e5e7351a6aa24cd7b23099efac1b2fd875da31a0"}),
 Object.freeze({name:"OKX Wallet",id:"971e689d0a5be527bac79629b4ee9b925e82208e5168b733496a09c0faed0709"}),
 Object.freeze({name:"Binance Wallet",id:"8a0ee50d1f22f6651afcae7eb4253e52a3310b90af5daef78a8c4929a9bb99d4"}),
 Object.freeze({name:"Bitget Wallet",id:"38f5d18bd8522c244bdd70cb4a68e0e718865155811c043f052fb9f1c51de662"}),
 Object.freeze({name:"TokenPocket",id:"20459438007b75f4f4acb98bf29aa3b800550309646d375da5fd4aac6c2a2c66"}),
 Object.freeze({name:"imToken",id:"ef333840daf915aafdc4a004525502d6d49d77bd9c65e0642dbaefb3c2893bef"}),
 Object.freeze({name:"SafePal",id:"0b415a746fb9ee99cce155c2ceca0c6f6061b1dbca2d722b3ba16381d0562150"}),
 Object.freeze({name:"OneKey",id:"1aedbcfc1f31aade56ca34c38b0a1607b41cccfa3de93c946ef3b4ba2dfab11c"}),
 Object.freeze({name:"Ledger Wallet",id:"19177a98252e07ddfc9af2083ba8e07ef627cb6103467ffebb3f8f4205fd7927"}),
 Object.freeze({name:"Trezor Suite",id:"6b0182d679b72eb2733dec38d9dee70551cc16a6ce5e7a7f4155ffb6f493c521"}),
 Object.freeze({name:"Rabby",id:"18388be9ac2d02726dbac9777c96efaac06d744b2f6d580fccdd4127a6d01fd1"}),
 Object.freeze({name:"Rainbow",id:"1ae92b26df02f0abca6304df07debccd18262fdf5fe82daa81593582dac9a369"}),
 Object.freeze({name:"Zerion",id:"ecc4036f814562b41a5268adc86270fba1365471402006302e70169465b7ac18"}),
 Object.freeze({name:"Gem Wallet",id:"dcb5cd7bb4a8849288f8b43dea7bf20d7b7e2b096b630964f9ca5bf808531edd"}),
]);

// 复用原AppKit弹窗；推荐、搜索及全部列表共用同一名单，不另建钱包连接实现。
export async function connectWallet(provider,chosen,options,createAppKit){
 const {SafeLocalStorage,SafeLocalStorageKeys}=await import('@reown/appkit-common');
 // 只移除本选择器的最近钱包展示偏好，防止历史品牌插入或把已选钱包挪到前面。
 // 不清空localStorage，不接触WalletConnect会话、账户、充值原单或签名记录。
 const clearRecent=()=>{
  SafeLocalStorage.removeItem(SafeLocalStorageKeys.RECENT_WALLETS);
  SafeLocalStorage.removeItem(SafeLocalStorageKeys.RECENT_WALLET);
 };
 clearRecent();
 const ids=wallets.map(wallet=>wallet.id);
 const modal=createAppKit({...options,includeWalletIds:[...ids],featuredWalletIds:[...ids],
  allWallets:'SHOW',customWallets:[],enableEIP6963:false,enableWalletGuide:false,
  features:{...options.features,email:false,socials:false,connectMethodsOrder:['wallet'],connectorTypeOrder:['featured']}});
 let unsubscribe;let connecting=true;
 try{
  await modal.open({view:'Connect'});
  const closed=new Promise((_,reject)=>{let opened=true;unsubscribe=modal.subscribeState(state=>{if(opened&&!state.open&&connecting)reject(Error('钱包连接已取消'));opened=state.open;});});
  const result=await Promise.race([provider.connect(proposal(chosen)),closed]);connecting=false;return result;
 }finally{unsubscribe?.();await modal.close();clearRecent();}
}
// 选择来自App的一次明确点击，不能从会话默认链补齐缺失字段。
export function selection(value){
 if(!value||typeof value!=='object'||Object.keys(value).sort().join()!=='network,package_id,token'||!pairs[value.token]?.includes(value.network)||!['pkg_15','pkg_1400'].includes(value.package_id))throw Error('付款选择无效');
 return Object.freeze({token:value.token,package_id:value.package_id,network:value.network});
}
export function proposal(value){
 const chosen=selection(value),chain=chains[chosen.network],ns=chain.split(':')[0];
 // UniversalProvider 2.23.10公开connect参数使用optionalNamespaces；返回后强制核对必要授权。
 const optionalNamespaces={[ns]:{chains:[chain],methods:[...required[ns],...(ns==='eip155'?['wallet_switchEthereumChain']:[])],events:ns==='eip155'?['chainChanged','accountsChanged']:[]}};
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
export async function bindSession(provider,value){
 const chosen=selection(value),chain=chains[chosen.network],ns=chain.split(':')[0],topic=provider.session?.topic;
 if(!topic)throw Error('钱包未连接');
 let active,invalidated=false,bound=false;
 const current=()=>provider.client.session.get(topic);
 provider.client.on('session_event',event=>{
  if(event.topic!==topic)return;
  if(event.params.event.name==='chainChanged'){
   const id=event.params.event.data;active=typeof id==='string'&&id.includes(':')?id:'eip155:'+Number(id);
   if(bound&&active!==chain)invalidated=true;
  }else if(event.params.event.name==='accountsChanged'&&bound)invalidated=true;
 });
 for(const name of ['session_update','session_delete','session_expire'])provider.client.on(name,event=>{if(event.topic===topic&&(bound||name!=='session_update'))invalidated=true;});
 if(ns==='eip155'&&current().namespaces[ns]?.methods?.includes('wallet_switchEthereumChain')){
  const result=await provider.client.request({topic,chainId:chain,request:{method:'wallet_switchEthereumChain',params:[{chainId:'0x'+Number(chain.split(':')[1]).toString(16)}]}});
  if(result!==null)throw Error('钱包未确认切换网络');
 }
 const read=()=>{if(invalidated)throw Error('付款账户、网络或会话已变化');const c=context(current(),chosen,active);bound=true;return c;};
 read();
 return {
  context:read,
  request:async(c,method,params)=>{
   unchanged(c,read());if(!current().namespaces[ns]?.methods?.includes(method))throw Error('钱包未授权付款方法');
   if(method==='eth_sendTransaction'&&(!params?.[0]||params[0].chainId!=='0x'+Number(chain.split(':')[1]).toString(16)||normalize(chosen.network,params[0].from)!==c.payer))throw Error('付款交易网络或账户不一致');
   return provider.client.request({topic,chainId:chain,request:{method,params}});
  }
 };
}
function unchanged(expected,current){if(expected.network!==current.network||expected.chain!==current.chain||expected.payer!==current.payer)throw Error('付款账户或网络已变化，未继续付款');}
const unexpired=(p,now)=>{if(!Number.isSafeInteger(p.expiresAt)||now()>=p.expiresAt)throw Error('付款意图已过期，未发起转账');};
/// 流程是唯一实现；测试注入的wallet/builder遵循同一公开方法，不绕过阶段落盘。
export async function paymentFlow({wallet,builder,ask,selection:value,now=Date.now}){
 const chosen=selection(value),original=await wallet.context();
 if(original.network!==chosen.network||original.chain!==chains[chosen.network])throw Error('钱包网络与所选网络不一致');
 const p=await ask('connected',{...original,token:chosen.token,package_id:chosen.package_id});
 const returned=selection(p.selection);if(JSON.stringify(returned)!==JSON.stringify(chosen))throw Error('付款选择已变化');
 unchanged(original,p.context);unexpired(p,now);
 if(typeof p.message!=='string'||!p.message.startsWith('CitizenServe Topup v1\n'))throw Error('付款授权无效');
 unchanged(original,await wallet.context());unexpired(p,now);
 const signature=p.signature??await wallet.signMessage(original,p.message);
 unchanged(original,await wallet.context());unexpired(p,now);
 await ask('authorization',{...original,signature});
 const transaction=await builder.prepare(original,p);
 unchanged(original,await wallet.context());unexpired(p,now);
 // EVM由钱包签名并广播；Tron/Solana先取得原字节，持久化后才广播。
 const signed=await wallet.signTransaction(original,transaction);
 unchanged(original,await wallet.context());unexpired(p,now);
 const frozen=await builder.freeze(original,transaction,signed);
 await ask('submitting',{...original,...frozen});
 unexpired(p,now);unchanged(original,await wallet.context());
 const txid=await builder.broadcast(original,frozen,wallet);
 if(frozen.txid&&txid!==frozen.txid)throw Error('广播回执与原交易不一致，请核实原订单');
 await ask('submitted',{...original,txid});return txid;
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
async function connectedWallet(cfg){
 const [{default:UniversalProvider},{createAppKit},{defineChain,mainnet,base,bsc,solana},{default:bs58}]=await Promise.all([import('@walletconnect/universal-provider'),import('@reown/appkit'),import('@reown/appkit/networks'),import('bs58')]);
 const provider=await UniversalProvider.init({projectId:cfg.projectId,logger:'silent',metadata:{name:'CitizenApp',description:'链上充值购买公民币',url:'https://www.crcfrcn.com',icons:[],redirect:{native:'citizenapp://walletconnect'}}});
 // 本次用户已选择新付款；结束本模块原连接，避免SDK把旧批准链带入新连接请求。
 if(provider.session)await provider.disconnect();
 const tron=defineChain({id:'0x2b6653dc',caipNetworkId:chains.tron,chainNamespace:'tron',name:'Tron',nativeCurrency:{name:'TRX',symbol:'TRX',decimals:6},rpcUrls:{default:{http:[cfg.rpc]}}});
 const chosen=selection(cfg.selection),network={ethereum:mainnet,base,bnb:bsc,tron,solana}[chosen.network];
 const networks=[{...network,rpcUrls:{default:{http:[cfg.rpc]}}}];
 await connectWallet(provider,chosen,{projectId:cfg.projectId,networks,manualWCControl:true,universalProvider:provider,enableAnalytics:false,enableNetworkSwitch:false,features:{analytics:false,swaps:false,onramp:false,send:false,receive:false}},createAppKit);
 const channel=await bindSession(provider,chosen),request=channel.request;
 return {
  context:channel.context,request,
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
}
let started=false;
export async function start(cfg){
 if(started)return;started=true;
 const pending=new Map();let sequence=0;
 const ask=(kind,payload)=>new Promise((resolve,reject)=>{const id=++sequence;const timer=setTimeout(()=>{pending.delete(id);reject(Error('付款回执待核实，请返回原订单'));},180000);pending.set(id,{resolve,reject,timer});window.TopupBridge.postMessage(JSON.stringify({session:cfg.session,id,kind,...payload}));});
 window.CitizenTopup.reply=(session,id,response)=>{if(session!==cfg.session)return;const p=pending.get(id);if(!p)return;pending.delete(id);clearTimeout(p.timer);response.ok?p.resolve(response.value):p.reject(Error(response.error??'付款流程已停止'));};
 window.open=(url)=>{if(typeof url==='string')void ask('external_wallet',{url}).catch(()=>{});return null;};
 try{
  const builder=await defaultBuilder((c,method,params)=>ask('solana_rpc',{...c,method,params}));
  if(cfg.replay)await replayFlow({builder,ask,replay:cfg.replay,selection:cfg.selection});
  else { const wallet=await connectedWallet(cfg);await paymentFlow({wallet,builder,ask,selection:cfg.selection}); }
 }catch(_){window.TopupBridge.postMessage(JSON.stringify({session:cfg.session,id:++sequence,kind:'error'}));}
}
