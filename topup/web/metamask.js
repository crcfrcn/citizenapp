// SDK连接由App复用；每个已签订单独立等待自己的RPC结果。
export function createWalletSession({openLink}){
 let sdkPromise,closed=false;
 const requests=new Set();
 let connecting;
 const deliverLink=url=>{
  const request=[...requests].reverse().find(item=>item.active()&&item.openable);
  if(!request)return;
  // MWP先经Relay发请求。一个订单只交付一次系统唤起，首次授权后的付款沿同一会话送达。
  request.openable=false;
  request.opened=true;
  void openLink(url,request.orderId).catch(()=>{});
 };
 const getSdk=({createSdk,storage,networks})=>{
  if(sdkPromise)return sdkPromise;
  const create=createSdk??(options=>import('@metamask/connect-multichain')
   .then(({createMultichainClient})=>createMultichainClient(options)));
  return sdkPromise=Promise.resolve(create({
   dapp:{name:'CitizenApp',url:'https://www.crcfrcn.com'},
   api:{supportedNetworks:networks},
   ui:{headless:true},analytics:{enabled:false},storage,
   mobile:{useDeeplink:true,preferredOpenLink:deliverLink}
  })).then(sdk=>{
   // 在无SDK弹窗的环境也只交付官方生成的配对链接。
   sdk.on('display_uri',deliverLink);
   return sdk;
  }).catch(error=>{sdkPromise=undefined;throw error;});
 };
 return {
  async pay({orderId,scope,transaction,createSdk,storage,networks,timeoutMs,active=()=>true,onPhase=()=>{},onDispatch=()=>{},onLateReceipt=async()=>{},onLateFailure=async()=>{}}){
   if(closed)throw Error('付款通信已关闭');
   let reject,timer;
   const failed=new Promise((_,fail)=>{reject=fail;});
   const request={reject,orderId,openable:false,opened:false,expired:false,active:()=>!closed&&!request.expired&&requests.has(request)&&active()};
   requests.add(request);
   const phase=state=>{if(request.active())try{onPhase(state);}catch{}};
   try{
    const unresolved=new Promise((_,fail)=>{timer=setTimeout(()=>{request.expired=true;fail(Error('付款钱包结果待核实'));},timeoutMs);});
    const payment=(async()=>{
     const sdk=await getSdk({createSdk,storage,networks});
     if(!request.active())throw Error('本次付款已结束');
     let payer=await authorizedAccount(sdk,scope);
     if(!request.active())throw Error('本次付款已结束');
     if(!payer){
      if(sdk.status==='pending')throw Error('付款钱包结果待核实');
      if(!connecting){
       request.openable=true;
       phase('connect_requested');
       connecting=Promise.resolve(sdk.connect(Object.values(chains),[])).finally(()=>{connecting=undefined;});
      }
      try{
       await connecting;
      }catch(error){
       if(error?.code==='REQUEST_EXPIRED')phase('connect_expired');
       throw error;
      }
      phase('connect_resolved');
      if(!request.active())throw Error('本次付款已结束');
      payer=await authorizedAccount(sdk,scope);
      if(!payer)throw Error('付款钱包未授权所选网络');
      phase('connect_ready');
     }else{
      phase('session_reused');
     }
     if(!request.active())throw Error('本次付款已结束');
     request.openable=!request.opened;
     phase('transaction_requested');
     try{
      onDispatch();
      const result=await sdk.invokeMethod({
       scope,
       request:{method:'eth_sendTransaction',params:[{...transaction,from:payer}]}
      });
      if(typeof result!=='string'||!/^0x[0-9a-f]{64}$/i.test(result))throw Error('付款回执缺少有效定位');
      return {txid:result.toLowerCase(),payer};
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

// 只取所选链当前会话中有权发交易的CAIP-10账户。
async function authorizedAccount(sdk,scope){
 const session=await sdk.provider.getSession();
 const grant=session?.sessionScopes?.[scope];
 if(!grant?.methods?.includes('eth_sendTransaction'))return undefined;
 const account=grant.accounts?.find(value=>
  typeof value==='string'&&value.startsWith(scope+':')&&
  /^0x[0-9a-f]{40}$/i.test(value.slice(scope.length+1)));
 return account?.slice(scope.length+1).toLowerCase();
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
export async function paymentFlow({ask,orderId,networks,selection:value,transaction:prepared,onPhase,onDispatch,onLateFailure,active=()=>true,createSdk,wallet=metamask,storage,timeoutMs=walletTimeout}){
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
 const receipt=await wallet.pay({orderId,scope:chains[chosen.network],networks,transaction,onPhase,onDispatch,createSdk,storage,timeoutMs,active,onLateReceipt:receive,onLateFailure});
 return receive(receipt);
}
export function connectFailure(error){
 const code=error?.rpcCode??error?.code;
 const known=[4001,4200,4900,4901,4902,-32601,-32602,-32603,-32000,-32001,-32002,-32003,-32004,-32005,-32006];
 // 只交付固定RPC码及精确匹配的SDK原因，绝不发送异常正文或会话信息。
 const detail=error?.message==='付款钱包结果待核实'?'wallet_timeout':
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
const metamask=createWalletSession({openLink:(url,orderId)=>ask('wallet_link',{url},orderId)});
const adapter={
 platform:'web',
 get:key=>ask('wallet_storage',{key:'mwp/'+key}),
 set:(key,value)=>ask('wallet_storage',{key:'mwp/'+key,value}),
 delete:key=>ask('wallet_storage',{key:'mwp/'+key,value:null})
};
const storage={
 adapter,
 async getAnonId(){
  const existing=await adapter.get('anonId');
  if(existing)return existing;
  const id=globalThis.crypto.randomUUID();
  await adapter.set('anonId',id);
  return id;
 },
 setAnonId:value=>adapter.set('anonId',value),
 removeAnonId:()=>adapter.delete('anonId'),
 getExtensionId:()=>adapter.get('extensionId'),
 setExtensionId:value=>adapter.set('extensionId',value),
 removeExtensionId:()=>adapter.delete('extensionId'),
 getTransportType:()=>adapter.get('transport'),
 setTransportType:value=>adapter.set('transport',value),
 removeTransportType:()=>adapter.delete('transport'),
 getDebug:()=>adapter.get('DEBUG')
};
export function cancel(orderId){const payment=payments.get(orderId);if(payment)payment.cancelled=true;}
export function cancelPending(orderId){
 const payment=payments.get(orderId);
 if(!payment||payment.sent)return false;
 payment.cancelled=true;
 return true;
}
export function close(){for(const payment of payments.values())payment.cancelled=true;host=undefined;for(const item of pending.values()){clearTimeout(item.timer);item.reject(Error('付款通信已关闭'));}pending.clear();metamask.close();}
export function start(cfg,{wallet=metamask,createSdk}={}){
 if(!/^top_[0-9a-f]{32}$/.test(cfg.order_id))return Promise.reject(Error('充值订单身份无效'));
 if(host&&host!==cfg.session)return Promise.reject(Error('付款通信会话不匹配'));
 const existing=payments.get(cfg.order_id);if(existing)return existing.promise;
 host=cfg.session;const payment={cancelled:false,sent:false,promise:undefined};payments.set(cfg.order_id,payment);
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
   await paymentFlow({ask:(kind,payload)=>ask(kind,payload,cfg.order_id),orderId:cfg.order_id,networks:cfg.networks,selection:cfg.selection,transaction:cfg.transaction,storage,wallet,createSdk,
    active:()=>!payment.cancelled&&host===cfg.session,onDispatch:()=>{payment.sent=true;},onLateFailure:report,onPhase:state=>{
     if(host===cfg.session&&!payment.cancelled)window.TopupBridge.postMessage(JSON.stringify({session:host,order_id:cfg.order_id,id:++sequence,kind:'phase',state}));
    }});
  }catch(error){
   report(error);
  }
 })();
 return payment.promise;
}
