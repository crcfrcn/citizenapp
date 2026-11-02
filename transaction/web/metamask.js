// SDK连接由App复用；每个已签订单独立等待自己的RPC结果。
export function createWalletSession(){
 let sdkPromise,client,closed=false;
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
    const channel=client?.getChannelId?.();
    if(channel&&new URL(url).searchParams.get('channelId')!==channel)return;
    // 交易已由SDK通过加密Relay发送；链接只唤醒同一钱包频道，不重放其中的交易。
    const separator=url.indexOf('?');
    const wake=separator<0?url:url.slice(0,separator+1)+url.slice(separator+1).split('&').filter(value=>!value.startsWith('rpc=')).join('&');
    for(const request of requests){
     if(!request.active())continue;
     const launch=Promise.resolve().then(()=>request.active()?request.openWallet(wake):undefined);
     request.pending.push(launch);void launch.catch(request.reject);
    }
   }
  })).then(sdk=>{client=sdk;return sdk;}).catch(error=>{sdkPromise=undefined;throw error;});
 };
 return {
  async pay({transaction,openWallet,createSdk,storage,timeoutMs,active=()=>true}){
   if(closed)throw Error('付款通信已关闭');
   let reject,timer;
   const failed=new Promise((_,fail)=>{reject=fail;});
   const request={openWallet,pending:[],reject,active:()=>!closed&&requests.has(request)&&active()};
   requests.add(request);
   try{
    const unresolved=new Promise((_,fail)=>{timer=setTimeout(()=>fail(Error('付款钱包结果待核实')),timeoutMs);});
    const payment=(async()=>{
     const sdk=await getSdk({createSdk,storage});
     if(!request.active())throw Error('本次付款已结束');
     const accounts=await sdk.connect();
     if(!request.active())throw Error('本次付款已结束');
     const payer=accounts?.[0]?.toLowerCase();
     if(!/^0x[0-9a-f]{40}$/.test(payer))throw Error('付款钱包未返回有效账户');
     const provider=sdk.getProvider();
     if(provider.getChainId()!==transaction.chainId)await provider.request({method:'wallet_switchEthereumChain',params:[{chainId:transaction.chainId}]});
     if(!request.active())throw Error('本次付款已结束');
     return {txid:await provider.request({method:'eth_sendTransaction',params:[{...transaction,from:payer}]}),payer};
    })();
    const receipt=await Promise.race([payment,failed,unresolved]);
    await Promise.race([Promise.all(request.pending),failed]);
    return receipt;
   }finally{
    clearTimeout(timer);requests.delete(request);
    // 本单结束只撤销自己的回调，不终止其他订单使用的连接。
   }
  },
  close(){closed=true;for(const request of requests)request.reject(Error('本次付款已结束'));requests.clear();}
 };
}
export const metamask=createWalletSession();
