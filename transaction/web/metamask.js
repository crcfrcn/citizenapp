// MetaMask独立适配：品牌、SDK跳转偏好及链接准入只归本文件。
export const metamask=Object.freeze({
 name:'MetaMask',id:'c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96',
 image:'eebe4a7f-7166-402f-92e0-1f64ca2aa800',enabled:true,href:'metamask://',
 async connect(runtime){
  const {StorageUtil}=await import('@reown/appkit-controllers');
  // 只写当前钱包的非秘密跳转偏好；不清会话、账户、订单或签名数据。
  StorageUtil.setWalletConnectDeepLink({name:metamask.name,href:metamask.href});
  const choice=StorageUtil.getWalletConnectDeepLink();
  if(choice?.name!==metamask.name||choice?.href!==metamask.href)throw Error('钱包唤起配置不可用');
  return runtime.walletConnect(metamask,runtime);
 },
 async connectionUrl(uri){
  const {CoreHelperUtil}=await import('@reown/appkit-controllers');
  return CoreHelperUtil.formatNativeUrl(metamask.href,uri).redirect;
 },
 accepts(value){
  try{
   const url=new URL(value);
   if(url.protocol!==new URL(metamask.href).protocol||url.hostname!=='wc'||!['','/'].includes(url.pathname)||url.username||url.password||url.hash)return false;
   const keys=[...url.searchParams.keys()].sort().join();
   if(keys==='uri')return url.searchParams.get('uri').startsWith('wc:');
   return keys==='requestId,sessionTopic'&&/^[0-9]+$/.test(url.searchParams.get('requestId'))&&/^[a-f0-9]{64}$/.test(url.searchParams.get('sessionTopic'));
  }catch(_){return false;}
 }
});
