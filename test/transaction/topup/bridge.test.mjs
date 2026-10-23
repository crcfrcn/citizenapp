// 真实随包JS在隔离VM运行；钱包为显式合成端口，不签或广播真实资金。
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {createRequire} from 'node:module';
import {webcrypto} from 'node:crypto';
import {join} from 'node:path';
const work=process.env.WORK;if(!work?.startsWith('/'))throw Error('须先由本产品装配本轮工作工程');
const source=readFileSync(join(work,'project/assets/topup/walletconnect.bundle.js'),'utf8');
const box={Uint8Array,Uint16Array,Uint32Array,ArrayBuffer,DataView,TextEncoder,TextDecoder,URL,URLSearchParams,crypto:webcrypto,Buffer,AbortSignal,setTimeout,clearTimeout,setInterval,clearInterval,atob,btoa,console:{warn(){},error(){},log(){}}};
box.self=box;vm.createContext(box);vm.runInContext(source,box);const api=box.CitizenTopup;
const chains={ethereum:'eip155:1',base:'eip155:8453',bnb:'eip155:56',tron:'tron:0x2b6653dc',solana:'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'};
function session(network){const chain=chains[network],ns=chain.split(':')[0];return {namespaces:{[ns]:{accounts:[chain+':payer'],methods:ns==='eip155'?['personal_sign','eth_sendTransaction']:ns==='tron'?['tron_signMessage','tron_signTransaction']:['solana_signMessage','solana_signTransaction']}}};}
function scenario(network){
 let sent=0,signatures=0;const stages=[];const c={network,chain:chains[network],payer:'payer'};let current=c;
 const wallet={context:async()=>current,signMessage:async()=>{signatures++;return 'signature';},signTransaction:async()=>({raw:'signed'}),request:async()=>{sent++;return 'tx';}};
 const builder={prepare:async()=>({}),freeze:async()=>network==='tron'||network==='solana'?{txid:'tx',wire:'same-signed-bytes'}:{},broadcast:async()=>{sent++;return 'tx';}};
 const ask=async(kind,value)=>{stages.push(kind);if(kind==='connected')return {context:c,message:'CitizenServe Topup v1\n',expiresAt:2000};if(kind==='submitting')assert.equal(sent,0);return null;};
 return {wallet,builder,ask,now:()=>1000,token:network==='solana'||network==='base'?'USDC':'USDT',stages,get sent(){return sent;},get signatures(){return signatures;},change(){current={...c,payer:'changed'};}};
}
test('六币轨按真实namespace与唯一网络识别，多授权不得默认Ethereum',()=>{
 for(const [n,t] of [['ethereum','USDC'],['ethereum','USDT'],['base','USDC'],['bnb','USDT'],['tron','USDT'],['solana','USDC']])assert.equal(api.context(session(n),t).network,n);
 assert.throws(()=>api.context(session('base'),'USDT'));assert.throws(()=>api.context(session('tron'),'USDC'));
 const s=session('ethereum');s.namespaces.eip155.accounts.push(chains.base+':payer');assert.throws(()=>api.context(s,'USDC'));assert.equal(api.context(s,'USDC',chains.base).network,'base');
 delete s.namespaces.eip155.methods;assert.throws(()=>api.context(s,'USDC'));
});
test('三协议同一流程严格按授权、提交前持久化、提交回执顺序',async()=>{
 for(const n of Object.keys(chains)){const s=scenario(n);assert.equal(await api.paymentFlow(s),'tx');assert.equal(s.sent,1);assert.equal(s.signatures,1);assert.deepEqual(s.stages,['connected','authorization','submitting','submitted']);}
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
test('本地HTML只执行随包脚本，不从CDN执行脚本',()=>{
 const html=readFileSync(new URL('../../../assets/topup/walletconnect.html',import.meta.url),'utf8');assert.match(html,/<script src="walletconnect[.]bundle[.]js"><\/script>/);assert.doesNotMatch(html,/<script[^>]+src=["']https?:/);assert.doesNotMatch(source,/WalletConnectEthereumProvider[.]init/);
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
 const calls=[];box.fetch=async(url,options)=>{assert.equal(new URL(url).origin,'https://solana.example.test');const q=JSON.parse(options.body);calls.push(q.method);return {ok:true,json:async()=>({jsonrpc:'2.0',id:1,result:q.method==='getGenesisHash'?'5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d':{value:{blockhash:new web3.PublicKey(new Uint8Array(32).fill(4)).toBase58(),lastValidBlockHeight:100}}})};};
 const builder=await api.defaultBuilder();const p={rpc:'https://solana.example.test',mint,receiver:fixture.config.rails.find(r=>r.network==='solana').recv_address,amount:'15000000',decimals:6};
 const built=await builder.prepare(c,p);assert.equal(built.raw.instructions.length,2);assert.equal(built.raw.instructions[1].data[0],12);assert.equal(built.raw.instructions[1].data[9],6);
 const signed=web3.Transaction.from(Buffer.from(built.raw.serialize({requireAllSignatures:false,verifySignatures:false})));signed.sign(signer);
 const frozen=await builder.freeze(c,built,{transaction:signed.serialize().toString('base64')});assert.equal(frozen.wire,signed.serialize().toString('base64'));await builder.validate(c,frozen);
 signed.instructions[1].data[1]^=1;signed.sign(signer);await assert.rejects(builder.freeze(c,built,{transaction:signed.serialize().toString('base64')}));
 assert.deepEqual(calls,['getGenesisHash','getLatestBlockhash','getGenesisHash']);
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
