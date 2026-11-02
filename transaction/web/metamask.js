// App持有一个SDK；订单只持有本次付款，结束订单不撤销有效连接。
export function createWalletSession(){
 let sdkPromise,attempt,closed=false;
 const getSdk=({createSdk,storage})=>{
  if(sdkPromise)return sdkPromise;
  // 清除被替代SDK默认网页缓存；只处理已核实的四个上游键，不清空其他网页数据。
  for(const key of ['.sdk-comm','providerType','.MMSDK_cached_address','.MMSDK_cached_chainId'])globalThis.localStorage?.removeItem(key);
  return sdkPromise=Promise.resolve((createSdk??(options=>import('@metamask/sdk').then(({MetaMaskSDK})=>new MetaMaskSDK(options))))({
  dappMetadata:{name:'CitizenApp',url:'https://www.crcfrcn.com',scheme:'citizenapp://topup'},
  checkInstallationImmediately:false,checkInstallationOnAllCalls:false,
  extensionOnly:false,preferDesktop:false,headless:true,useDeeplink:true,
  enableAnalytics:false,injectProvider:false,shouldShimWeb3:false,
  storage:{enabled:true,storageManager:storage},
  logging:{developerMode:false,sdk:false},
  openDeeplink:url=>{
   const current=attempt;
   if(!current)return;
   const launch=Promise.resolve().then(()=>{if(attempt!==current)throw Error('本次付款已结束');return current.openWallet(url);});
   current.pending.push(launch);void launch.catch(current.reject);
  }
 })).catch(error=>{sdkPromise=undefined;throw error;});
 };
 return {
  async pay({transaction,openWallet,createSdk,storage,timeoutMs,active=()=>true}){
   if(closed||attempt)throw Error('付款通信尚未结束');
   let reject,timer,timedOut=false;
   const failed=new Promise((_,fail)=>{reject=fail;});
   const current={openWallet,pending:[],reject};attempt=current;
   try{
    const sdk=await getSdk({createSdk,storage});
    const unresolved=new Promise((_,fail)=>{timer=setTimeout(()=>{timedOut=true;fail(Error('付款钱包结果待核实'));},timeoutMs);});
    // 首次链接只建立官方会话；授权后通过加密通道发送原交易，避免明文初始RPC被钱包按密文解码。
    const payment=(async()=>{
     const accounts=await sdk.connect();
     if(closed||attempt!==current||!active())throw Error('本次付款已结束');
     const payer=accounts?.[0]?.toLowerCase();
     if(!/^0x[0-9a-f]{40}$/.test(payer))throw Error('付款钱包未返回有效账户');
     const provider=sdk.getProvider();
     if(provider.getChainId()!==transaction.chainId)await provider.request({method:'wallet_switchEthereumChain',params:[{chainId:transaction.chainId}]});
     if(closed||attempt!==current||!active())throw Error('本次付款已结束');
     const txid=await provider.request({method:'eth_sendTransaction',params:[{...transaction,from:payer}]});
     return {txid,payer};
    })();
    const receipt=await Promise.race([payment,failed,unresolved]);
    await Promise.race([Promise.all(current.pending),failed]);
    return receipt;
   }finally{
    clearTimeout(timer);if(attempt===current)attempt=undefined;
    // 未结束的RPC不能借给下一单；只有超时失效才丢弃该会话，不补发付款。
    if(timedOut){const previous=sdkPromise;sdkPromise=undefined;try{await(await previous)?.terminate();}catch(_){} }
   }
  },
  close(){closed=true;attempt?.reject(Error('本次付款已结束'));attempt=undefined;}
 };
}
export const metamask=createWalletSession();
