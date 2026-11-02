import {metamask} from './metamask.js';
export {createWalletSession} from './metamask.js';

export const chains=Object.freeze({ethereum:'eip155:1',bnb:'eip155:56',base:'eip155:8453'});
const walletTimeout=180000;
export function selection(value){
 if(!value||Object.keys(value).sort().join()!=='network,package_id,token'||!['USDT','USDC'].includes(value.token)||!Object.hasOwn(chains,value.network)||!['pkg_10','pkg_900'].includes(value.package_id))throw Error('付款选择无效');
 return Object.freeze({...value});
}
export function paymentTransaction(value,chosen){
 const expected='0x'+Number(chains[chosen.network].split(':')[1]).toString(16);
 if(!value||Object.keys(value).sort().join()!=='chainId,data,to,value'||value.chainId!==expected||value.value!=='0x0'||!/^0x[0-9a-f]{40}$/.test(value.to)||!/^0xa9059cbb[0-9a-f]{192}$/.test(value.data))throw Error('付款交易与所选网络不一致');
 return Object.freeze({...value});
}
// 真实流程和测试共用此入口；签名保存、交易准备均在首次钱包唤起之前完成。
export async function paymentFlow({ask,selection:value,openWallet,active=()=>true,createSdk,wallet=metamask,storage,timeoutMs=walletTimeout}){
 const chosen=selection(value);
 const prepared=await ask('create_order');
 const transaction=paymentTransaction(prepared.transaction,chosen);
 let opened=false;
 const openOnce=async url=>{
  if(!active())throw Error('本次付款已结束');
  // SDK会为连接和交易各生成唤醒回调；钱包已在前台，后续回调不再启动Activity。
  if(opened)return;
  opened=true;await openWallet(url,transaction);
 };
 if(!active())throw Error('本次付款已结束');
 const receipt=await wallet.pay({transaction,openWallet:openOnce,createSdk,storage,timeoutMs,active});
 if(!active())throw Error('本次付款已结束');
 if(!/^0x[0-9a-f]{64}$/.test(receipt?.txid)||receipt.payer!==undefined&&!/^0x[0-9a-f]{40}$/.test(receipt.payer))throw Error('付款回执缺少有效定位');
 const saved=await ask('submitted',{network:chosen.network,chain:chains[chosen.network],...receipt,transaction});
 if(saved?.submitted!==true)throw Error('付款回执尚未保存');
 return receipt.txid;
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

// 文档和SDK跟随App；桥接序号全局递增，每笔订单以独立operation隔离迟到回执。
let host,pending=new Map(),sequence=0,current;
const ask=(kind,payload={},operation)=>new Promise((resolve,reject)=>{
 if(!host){reject(Error('付款通信已关闭'));return;}
 const id=++sequence,timer=setTimeout(()=>{pending.delete(id);reject(Error('付款回执等待超时'));},walletTimeout);
 pending.set(id,{resolve,reject,timer});window.TopupBridge.postMessage(JSON.stringify({session:host,id,kind,...(operation?{operation}:{}),...payload}));
});
const storage={
 getPersistedChannelConfig:async()=>{const value=await ask('wallet_storage',{key:'channel'});return value?JSON.parse(value):undefined;},
 persistChannelConfig:value=>ask('wallet_storage',{key:'channel',value:JSON.stringify(value)}),
 getCachedAccounts:async()=>{const value=await ask('wallet_storage',{key:'accounts'});return value?JSON.parse(value):[];},
 persistAccounts:value=>ask('wallet_storage',{key:'accounts',value:JSON.stringify(value)}),
 getCachedChainId:async()=>(await ask('wallet_storage',{key:'chain'}))??undefined,
 persistChainId:value=>ask('wallet_storage',{key:'chain',value}),
 terminate:()=>ask('wallet_storage',{key:'channel',value:null})
};
export function cancel(operation){if(current?.operation===operation)current.stopped=true;}
export function close(){current&&(current.stopped=true);host=undefined;for(const item of pending.values()){clearTimeout(item.timer);item.reject(Error('付款通信已关闭'));}pending.clear();metamask.close();}
export async function start(cfg){
 if(current&&!current.stopped||host&&host!==cfg.session)return;
 host=cfg.session;const operation={operation:cfg.operation,stopped:false};current=operation;
 window.CitizenTopup.reply=(session,id,response)=>{
  if(session!==host)return;
  const item=pending.get(id);if(!item)return;pending.delete(id);clearTimeout(item.timer);
  response.ok?item.resolve(response.value):item.reject(Error('付款流程已停止'));
 };
 try{
  await paymentFlow({ask:(kind,payload)=>ask(kind,payload,operation.operation),selection:cfg.selection,storage,
   active:()=>current===operation&&!operation.stopped,openWallet:(url,transaction)=>ask('external_wallet',{url,transaction},operation.operation)});
 }catch(error){
  if(current===operation&&!operation.stopped&&host){const failure=connectFailure(error);window.TopupBridge.postMessage(JSON.stringify({session:host,operation:operation.operation,id:++sequence,kind:'error',stage:'submitted',code:failure.error,rpc_code:failure.rpc_code,detail:failure.detail}));}
 }finally{operation.stopped=true;}
}
