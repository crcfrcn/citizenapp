// 三协议付款只走一次冻结流程；所有阶段须等App原子落盘回执，不存或请求钱包私钥。
export const chains={ethereum:'eip155:1',base:'eip155:8453',bnb:'eip155:56',tron:'tron:0x2b6653dc',solana:'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'};
const pairs={USDC:['ethereum','base','solana'],USDT:['ethereum','tron','bnb']};
const required={eip155:['personal_sign','eth_sendTransaction'],tron:['tron_signMessage','tron_signTransaction'],solana:['solana_signMessage','solana_signTransaction']};
const normalize=(n,a)=>n==='tron'||n==='solana'?a:a.toLowerCase();
export function context(session,token,active){
 if(!pairs[token])throw Error('不支持的币种');
 const candidates=[];
 for(const [namespace,info] of Object.entries(session.namespaces??{})){
  if(!required[namespace]?.every(method=>info.methods?.includes(method)))continue;
  for(const account of info.accounts??[]){const parts=account.split(':');if(parts.length!==3)continue;const chain=parts.slice(0,2).join(':');const network=Object.keys(chains).find(n=>chains[n]===chain);if(network&&pairs[token].includes(network)&&(!active||active===chain))candidates.push({network,chain,payer:normalize(network,parts[2])});}
 }
 const unique=[...new Map(candidates.map(c=>[c.chain+':'+c.payer,c])).values()];
 if(unique.length!==1)throw Error('请在付款钱包中确认一个受支持的账户和网络后重连');
 return unique[0];
}
function unchanged(expected,current){if(expected.network!==current.network||expected.chain!==current.chain||expected.payer!==current.payer)throw Error('付款账户或网络已变化，未继续付款');}
const unexpired=(p,now)=>{if(!Number.isSafeInteger(p.expiresAt)||now()>=p.expiresAt)throw Error('付款意图已过期，未发起转账');};
/// 流程是唯一实现；测试注入的wallet/builder遵循同一公开方法，不绕过阶段落盘。
export async function paymentFlow({wallet,builder,ask,token,now=Date.now}){
 const original=await wallet.context(token);const p=await ask('connected',original);
 unchanged(original,p.context);unexpired(p,now);
 if(typeof p.message!=='string'||!p.message.startsWith('CitizenServe Topup v1\n'))throw Error('付款授权无效');
 const signature=p.signature??await wallet.signMessage(original,p.message);
 unchanged(original,await wallet.context(token));unexpired(p,now);
 await ask('authorization',{...original,signature});
 const transaction=await builder.prepare(original,p);
 unchanged(original,await wallet.context(token));unexpired(p,now);
 // EVM由钱包签名并广播；Tron/Solana先取得原字节，持久化后才广播。
 const signed=await wallet.signTransaction(original,transaction);
 unchanged(original,await wallet.context(token));unexpired(p,now);
 const frozen=await builder.freeze(original,transaction,signed);
 await ask('submitting',{...original,...frozen});
 unexpired(p,now);unchanged(original,await wallet.context(token));
 const txid=await builder.broadcast(original,frozen,wallet);
 if(frozen.txid&&txid!==frozen.txid)throw Error('广播回执与原交易不一致，请核实原订单');
 await ask('submitted',{...original,txid});return txid;
}

// 用户明确继续时仅广播保护记录中的原签名字节，不连接钱包、不重签或重建交易。
export async function replayFlow({builder,ask,replay,now=Date.now}){
 const c=replay.context;
 if(!['tron','solana'].includes(c?.network)||chains[c.network]!==c.chain||!replay.txid||!replay.wire)throw Error('缺少原签名交易');
 unexpired(replay,now);await builder.validate(c,replay);
 await ask('replay',{...c,wire:replay.wire,txid:replay.txid});unexpired(replay,now);
 const txid=await builder.broadcast(c,replay);
 if(txid!==replay.txid)throw Error('广播回执与原交易不一致');
 await ask('submitted',{...c,txid});return txid;
}

const https=value=>{const u=new URL(value);if(u.protocol!=='https:'||u.username||u.password||u.hash||u.search)throw Error('付款节点配置无效');return u.href;};
async function rpc(url,method,params){
 const response=await fetch(https(url),{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:1,method,params}),redirect:'error',signal:AbortSignal.timeout(15000)});
 if(!response.ok)throw Error('付款节点暂不可用');const value=await response.json();if(value.jsonrpc!=='2.0'||value.id!==1||value.error||!Object.hasOwn(value,'result'))throw Error('付款节点响应无效');return value.result;
}
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
export async function buildSolana(payer,p,web3,spl){
 const url=https(p.rpc);
 if(await rpc(url,'getGenesisHash',[])!=='5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d')throw Error('付款节点不是Solana主网');
 const latest=await rpc(url,'getLatestBlockhash',[{commitment:'finalized'}]);
 const owner=new web3.PublicKey(payer),mint=new web3.PublicKey(p.mint),recipient=new web3.PublicKey(p.receiver);
 const source=await spl.getAssociatedTokenAddress(mint,owner),destination=await spl.getAssociatedTokenAddress(mint,recipient);
 const tx=new web3.Transaction({feePayer:owner,blockhash:latest.value.blockhash,lastValidBlockHeight:latest.value.lastValidBlockHeight});
 tx.add(spl.createAssociatedTokenAccountIdempotentInstruction(owner,destination,recipient,mint));
 tx.add(spl.createTransferCheckedInstruction(source,mint,destination,owner,BigInt(p.amount),p.decimals));
 return tx;
}
export async function defaultBuilder(){
 const [{Buffer},{default:bs58}]=await Promise.all([import('buffer'),import('bs58')]);
 return {
  async prepare(c,p){
   if(c.network==='tron'){const {TronWeb}=await import('tronweb');return {raw:await buildTron(c.payer,p,TronWeb),rpc:p.rpc};}
   if(c.network==='solana'){const [web3,spl]=await Promise.all([import('@solana/web3.js'),import('@solana/spl-token')]);const raw=await buildSolana(c.payer,p,web3,spl);return {raw,web3,rpc:p.rpc};}
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
    if(!tx.verifySignatures()||tx.feePayer.toBase58()!==c.payer||bs58.encode(tx.signature)!==f.txid||await rpc(f.rpc,'getGenesisHash',[])!=='5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d')throw Error('原Solana交易无效');
   }
  },
  async broadcast(c,f,wallet){
   if(c.network==='tron'){
    const {TronWeb}=await import('tronweb');const result=await tronClient(TronWeb,f.rpc).trx.sendRawTransaction(JSON.parse(f.wire));if(!result.result||result.txid!==f.txid)throw Error('付款广播回执待核实');return result.txid;
   }
   if(c.network==='solana')return await rpc(f.rpc,'sendTransaction',[f.wire,{encoding:'base64',skipPreflight:false,preflightCommitment:'confirmed',maxRetries:3}]);
   return await wallet.request(c,'eth_sendTransaction',[f.transaction]);
  }
 };
}
async function connectedWallet(cfg){
 const [{default:UniversalProvider},{createAppKit},{defineChain,mainnet,base,bsc,solana},{default:bs58}]=await Promise.all([import('@walletconnect/universal-provider'),import('@reown/appkit'),import('@reown/appkit/networks'),import('bs58')]);
 const provider=await UniversalProvider.init({projectId:cfg.projectId,logger:'silent',metadata:{name:'CitizenApp',description:'链上充值购买公民币',url:'https://www.crcfrcn.com',icons:[],redirect:{native:'citizenapp://walletconnect'}}});
 const tron=defineChain({id:'0x2b6653dc',caipNetworkId:chains.tron,chainNamespace:'tron',name:'Tron',nativeCurrency:{name:'TRX',symbol:'TRX',decimals:6},rpcUrls:{default:{http:cfg.tronRpc?[cfg.tronRpc]:[]}}});
 const networks=cfg.token==='USDC'?[mainnet,base,solana]:[mainnet,bsc,tron];
 const modal=createAppKit({projectId:cfg.projectId,networks,manualWCControl:true,universalProvider:provider,allWallets:'SHOW',enableAnalytics:false,enableNetworkSwitch:false,features:{analytics:false,swaps:false,onramp:false,send:false,receive:false}});
 let active;
 // 只接受钱包认证session_event；AppKit自己的默认网络变化不能伪装成钱包当前链。
 provider.client.on('session_event',event=>{if(event.topic===provider.session?.topic&&event.params.event.name==='chainChanged'){const id=event.params.event.data;active=typeof id==='string'&&id.includes(':')?id:'eip155:'+Number(id);}});
 const namespaces={};
 for(const n of pairs[cfg.token]){const chain=chains[n],ns=chain.split(':')[0];namespaces[ns]??={chains:[],methods:required[ns],events:ns==='eip155'?['chainChanged','accountsChanged']:[]};namespaces[ns].chains.push(chain);}
 await modal.open({view:'Connect'});
 let unsubscribe;let connecting=true;
 try{
  const closed=new Promise((_,reject)=>{let opened=true;unsubscribe=modal.subscribeState(s=>{if(opened&&!s.open&&connecting)reject(Error('钱包连接已取消'));opened=s.open;});});
  await Promise.race([provider.connect({optionalNamespaces:namespaces}),closed]);connecting=false;
 }finally{unsubscribe?.();await modal.close();}
 const request=async(c,method,params)=>provider.client.request({topic:provider.session.topic,chainId:c.chain,request:{method,params}});
 return {
  context:async token=>context(provider.session,token,active),request,
  async signMessage(c,message){
   if(c.network==='tron'){const r=await request(c,'tron_signMessage',{address:c.payer,message});const sig=r.signature;if(typeof sig!=='string')throw Error('付款授权无效');const {TronWeb}=await import('tronweb');if(await tronClient(TronWeb,cfg.tronRpc).trx.verifyMessageV2(message,sig)!==c.payer)throw Error('付款授权无效');return sig.startsWith('0x')?sig:'0x'+sig;}
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
  const builder=await defaultBuilder();
  if(cfg.replay)await replayFlow({builder,ask,replay:cfg.replay});
  else { const wallet=await connectedWallet(cfg);await paymentFlow({wallet,builder,ask,token:cfg.token}); }
 }catch(_){window.TopupBridge.postMessage(JSON.stringify({session:cfg.session,id:++sequence,kind:'error'}));}
}
