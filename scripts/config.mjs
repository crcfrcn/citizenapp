// 本产品配置需求的公开入口；只登记名称、类型和规则，不保存配置值。
export const manifest=Object.freeze({
  "schema": 1,
  "product_id": "citizenapp",
  "configuration": {
    "id": "citizenapp",
    "kind": "mobile",
    "title": "公民配置",
    "items": [
      {
        "environment": "release",
        "name": "APP_KEY",
        "title": "APP_KEY",
        "description": "Android 正式应用签名密钥的本机加密备份",
        "revealable": true,
        "accessLevel": "protected",
        "kind": "android-signing",
        "sharedId": "mobile-signing:APP_KEY"
      },
      {
        "environment": "release",
        "name": "IOS_KEY",
        "title": "IOS_KEY",
        "description": "iOS 正式签名证书的本机加密备份",
        "revealable": true,
        "accessLevel": "protected",
        "kind": "ios-signing",
        "sharedId": "mobile-signing:IOS_KEY"
      },
      {
        "environment": "release",
        "name": "APP_PROFILE",
        "title": "APP_PROFILE",
        "description": "公民 iOS 正式描述文件的本机加密备份",
        "revealable": true,
        "accessLevel": "protected",
        "kind": "ios-signing"
      }
    ]
  }
});
export function describeConfiguration(){return JSON.parse(JSON.stringify(manifest));}

// 本仓流程的公开入口声明；调用方只交付标准传输能力，不拥有产品规则或任务宿主。
export async function describeAction({flow,platform}){
 const targets={ios:{name:'iOS',workflow:'ios.yml'},android:{name:'Android',workflow:'android.yml'}},target=targets[platform];
 if(flow!=='release'||!target)throw Error('本产品尚未声明该流程入口：'+flow+'·'+platform);
 return {repository:'crcfrcn/citizenapp',launch:async({read,dispatch})=>{
  const rows=[];
  for(let page=1;;page++){const data=await read('actions/workflows/'+target.workflow+'/runs?branch=main&event=workflow_dispatch&per_page=100&page='+page);rows.push(...data.workflow_runs);if(data.workflow_runs.length<100)break;}
  const latest=rows.filter(run=>run.status==='completed'&&run.conclusion==='success').sort((a,b)=>Date.parse(b.updated_at)-Date.parse(a.updated_at)||b.id-a.id)[0];
  const {readFile}=await import('node:fs/promises');let version;
  if(latest){const prefix='公民·'+target.name+'·v';if(!latest.display_title.startsWith(prefix))throw Error('本产品最新成功Run没有准确版本');const parts=latest.display_title.slice(prefix.length).split('.');parts[2]=String(BigInt(parts[2])+1n);version=parts.join('.');}
  else version=/^version:\s*(\S+)/mu.exec(await readFile(new URL('../pubspec.yaml',import.meta.url),'utf8'))[1].split('+')[0];
  const receipt=await dispatch({workflow:target.workflow,ref:'main',inputs:{version}});return {runID:receipt.workflow_run_id};
 }};
}
