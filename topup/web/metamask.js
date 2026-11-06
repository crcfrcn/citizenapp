// SDK连接由App复用；每个已签订单独立等待自己的RPC结果。
export function createWalletSession({openLink}){
 let sdkPromise,closed=false;
 const requests=new Set();
 const getSdk=({createSdk,storage})=>{
  if(sdkPromise)return sdkPromise;
  for(const key of ['.sdk-comm','providerType','.MMSDK_cached_address','.MMSDK_cached_chainId'])globalThis.localStorage?.removeItem(key);
  return sdkPromise=Promise.resolve((createSdk??(options=>import('@metamask/sdk').then(({MetaMaskSDK})=>new MetaMaskSDK(options))))({
   dappMetadata:{name:'CitizenApp',url:'https://www.crcfrcn.com',scheme:'citizenapp://topup'},
   checkInstallationImmediately:false,checkInstallationOnAllCalls:false,
   extensionOnly:false,preferDesktop:false,headless:true,useDeeplink:true,
   enableAnalytics:false,injectProvider:false,shouldShimWeb3:false,
   storage:{enabled:true,storageManager:storage},logging:{developerMode:false,sdk:false},
   openDeeplink:url=>{
    // SDK链接属于共享连接传输，每次原样交付一次；不按在途订单广播或裁剪RPC。
    if(closed||![...requests].some(request=>request.active()))return;
    void Promise.resolve().then(()=>{
     if(!closed&&[...requests].some(request=>request.active()))return openLink(url);
    }).catch(()=>{}); // 启动失败不证明交易失败；等待SDK真实结果或原超时。
   }
  })).catch(error=>{sdkPromise=undefined;throw error;});
 };
 return {
  async pay({transaction,createSdk,storage,timeoutMs,active=()=>true,onPhase=()=>{},onLateReceipt=async()=>{},onLateFailure=async()=>{}}){
   if(closed)throw Error('付款通信已关闭');
   let reject,timer;
   const failed=new Promise((_,fail)=>{reject=fail;});
   const request={reject,expired:false,active:()=>!closed&&!request.expired&&requests.has(request)&&active()};
   requests.add(request);
   const phase=state=>{if(request.active())try{onPhase(state);}catch{}};
   try{
    const unresolved=new Promise((_,fail)=>{timer=setTimeout(()=>{request.expired=true;fail(Error('付款钱包结果待核实'));},timeoutMs);});
    const payment=(async()=>{
     const sdk=await getSdk({createSdk,storage});
     if(!request.active())throw Error('本次付款已结束');
     phase('connect_requested');
     const accounts=await sdk.connect();
     if(!request.active())throw Error('本次付款已结束');
     const payer=accounts?.[0]?.toLowerCase();
     if(!/^0x[0-9a-f]{40}$/.test(payer))throw Error('付款钱包未返回有效账户');
     phase('connect_ready');
     const provider=sdk.getProvider();
     // 不信任缓存网络；钱包在同一批次内切网后继续付款，App不等待中间回执续发。
     phase('transaction_requested');
     try{
      const result=await provider.request({method:'metamask_batch',params:[
       {method:'wallet_switchEthereumChain',params:[{chainId:transaction.chainId}]},
       {method:'eth_sendTransaction',params:[{...transaction,from:payer}]}
      ]});
      if(!Array.isArray(result)||result.length!==2||result[0]!==null||!/^0x[0-9a-f]{64}$/.test(result[1]))throw Error('付款回执缺少有效定位');
      return {txid:result[1],payer};
     }
     finally{phase('result_received');}
    })().then(async receipt=>{
     // 超时只结束界面等待；原付款已发出的结果仍交给原签订单，绝不补发交易。
     if(request.expired&&!closed&&active())await onLateReceipt(receipt);
     return receipt;
    },async error=>{
     if(request.expired&&!closed&&active())await onLateFailure(error);
     throw error;
    });
    const receipt=await Promise.race([payment,failed,unresolved]);
    return receipt;
   }finally{
    clearTimeout(timer);requests.delete(request);
    // 界面等待结束只停止本单的新唤起，原请求回执仍可收取，不终止共享连接。
   }
  },
  close(){closed=true;for(const request of requests)request.reject(Error('本次付款已结束'));requests.clear();}
 };
}

export const chains=Object.freeze({ethereum:'eip155:1',bnb:'eip155:56',base:'eip155:8453'});
const walletTimeout=180000;
export function selection(value){
 if(!value||Object.keys(value).sort().join()!=='network,package_id,token'||!['USDT','USDC'].includes(value.token)||!Object.hasOwn(chains,value.network)||!['pkg_10','pkg_1000'].includes(value.package_id))throw Error('付款选择无效');
 return Object.freeze({...value});
}
export function paymentTransaction(value,chosen){
 const expected='0x'+Number(chains[chosen.network].split(':')[1]).toString(16);
 if(!value||Object.keys(value).sort().join()!=='chainId,data,to,value'||value.chainId!==expected||value.value!=='0x0'||!/^0x[0-9a-f]{40}$/.test(value.to)||!/^0xa9059cbb[0-9a-f]{192}$/.test(value.data))throw Error('付款交易与所选网络不一致');
 return Object.freeze({...value});
}
// 调用方已签名保存订单；本层只执行其冻结交易并交付该订单回执。
export async function paymentFlow({ask,selection:value,transaction:prepared,onPhase,onLateFailure,active=()=>true,createSdk,wallet=metamask,storage,timeoutMs=walletTimeout}){
 const chosen=selection(value);
 const transaction=paymentTransaction(prepared,chosen);
 if(!active())throw Error('本次付款已结束');
 const receive=async receipt=>{
  if(!active())throw Error('本次付款已结束');
  if(!/^0x[0-9a-f]{64}$/.test(receipt?.txid)||receipt.payer!==undefined&&!/^0x[0-9a-f]{40}$/.test(receipt.payer))throw Error('付款回执缺少有效定位');
  const saved=await ask('submitted',{network:chosen.network,chain:chains[chosen.network],...receipt,transaction});
  if(saved?.submitted!==true)throw Error('付款回执尚未保存');
  return receipt.txid;
 };
 const receipt=await wallet.pay({transaction,onPhase,createSdk,storage,timeoutMs,active,onLateReceipt:receive,onLateFailure});
 return receive(receipt);
}
export function connectFailure(error){
 const code=error?.rpcCode??error?.code;
 const known=[4001,4200,4900,4901,4902,-32601,-32602,-32603,-32000,-32001,-32002,-32003,-32004,-32005,-32006];
 // 只交付固定RPC码及精确匹配的SDK原因，绝不发送异常正文或会话信息。
 const detail=error?.message==='Max message count reached without result'?'sdk_update_limit':
  error?.message==='付款钱包结果待核实'?'wallet_timeout':
  error?.message==='付款回执缺少有效定位'?'receipt_invalid':null;
 const outcome=error==='rejected'||code===4001?'user_rejected':[-32601,-32602,4200,4902].includes(code)?'payment_failed':'other';
 return {error:outcome,rpc_code:known.includes(code)?code:null,detail};
}

// 通信会话仅负责来源校验；每个实际签后order_id拥有自己的等待和取消。
let host,sequence=0;
const pending=new Map(),payments=new Map();
const ask=(kind,payload={},orderId)=>new Promise((resolve,reject)=>{
 if(!host){reject(Error('付款通信已关闭'));return;}
 const id=++sequence,timer=setTimeout(()=>{pending.delete(id);reject(Error('付款回执等待超时'));},walletTimeout);
 pending.set(id,{resolve,reject,timer});window.TopupBridge.postMessage(JSON.stringify({session:host,id,kind,...(orderId?{order_id:orderId}:{}),...payload}));
});
const metamask=createWalletSession({openLink:url=>ask('wallet_link',{url})});
const storage={
 getPersistedChannelConfig:async()=>{const value=await ask('wallet_storage',{key:'channel'});return value?JSON.parse(value):undefined;},
 persistChannelConfig:value=>ask('wallet_storage',{key:'channel',value:JSON.stringify(value)}),
 getCachedAccounts:async()=>{const value=await ask('wallet_storage',{key:'accounts'});return value?JSON.parse(value):[];},
 persistAccounts:value=>ask('wallet_storage',{key:'accounts',value:JSON.stringify(value)}),
 getCachedChainId:async()=>(await ask('wallet_storage',{key:'chain'}))??undefined,
 persistChainId:value=>ask('wallet_storage',{key:'chain',value}),
 terminate:()=>ask('wallet_storage',{key:'channel',value:null})
};
export function cancel(orderId){const payment=payments.get(orderId);if(payment)payment.cancelled=true;}
export function close(){for(const payment of payments.values())payment.cancelled=true;host=undefined;for(const item of pending.values()){clearTimeout(item.timer);item.reject(Error('付款通信已关闭'));}pending.clear();metamask.close();}
export function start(cfg,{wallet=metamask,createSdk}={}){
 if(!/^top_[0-9a-f]{32}$/.test(cfg.order_id))return Promise.reject(Error('充值订单身份无效'));
 if(host&&host!==cfg.session)return Promise.reject(Error('付款通信会话不匹配'));
 const existing=payments.get(cfg.order_id);if(existing)return existing.promise;
 host=cfg.session;const payment={cancelled:false,promise:undefined};payments.set(cfg.order_id,payment);
 window.CitizenTopup.reply=(session,id,response)=>{
  if(session!==host)return;
  const item=pending.get(id);if(!item)return;pending.delete(id);clearTimeout(item.timer);
  response.ok?item.resolve(response.value):item.reject(Error('付款流程已停止'));
 };
 const report=error=>{
  if(!payment.cancelled&&host===cfg.session){const failure=connectFailure(error);window.TopupBridge.postMessage(JSON.stringify({session:host,order_id:cfg.order_id,id:++sequence,kind:'error',stage:'submitted',code:failure.error,rpc_code:failure.rpc_code,detail:failure.detail}));}
 };
 payment.promise=(async()=>{
  try{
   await paymentFlow({ask:(kind,payload)=>ask(kind,payload,cfg.order_id),selection:cfg.selection,transaction:cfg.transaction,storage,wallet,createSdk,
    active:()=>!payment.cancelled&&host===cfg.session,onLateFailure:report,onPhase:state=>{
     if(host===cfg.session&&!payment.cancelled)window.TopupBridge.postMessage(JSON.stringify({session:host,order_id:cfg.order_id,id:++sequence,kind:'phase',state}));
    }});
  }catch(error){
   report(error);
  }
 })();
 return payment.promise;
}
