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
        "name": "APP_KEY",
        "description": "安卓应用正式签名材料",
        "accessLevel": "protected",
        "kind": "android-signing",
        "format": "不适用"
      },
      {
        "name": "IOS_KEY",
        "description": "苹果移动应用正式签名证书",
        "accessLevel": "protected",
        "kind": "ios-signing",
        "format": "不适用"
      },
      {
        "name": "CITIZENAPP_PROFILE",
        "description": "公民应用描述文件",
        "accessLevel": "protected",
        "kind": "ios-signing",
        "format": "ios_profile:ios.citizenapp"
      },
      {
        "name": "APPSTORE_PRIVATEKEY",
        "description": "苹果商店接口私钥",
        "accessLevel": "protected",
        "kind": "不适用",
        "format": "不适用"
      },
      {
        "name": "APPSTORE_KEYID",
        "description": "苹果商店接口密钥编号",
        "accessLevel": "protected",
        "kind": "不适用",
        "format": "不适用"
      },
      {
        "name": "APPSTORE_ISSUERID",
        "description": "苹果商店接口签发者编号",
        "accessLevel": "protected",
        "kind": "不适用",
        "format": "不适用"
      },
      {
        "name": "PLAY_SERVICEACCOUNT",
        "description": "谷歌商店服务账号凭据",
        "accessLevel": "protected",
        "kind": "不适用",
        "format": "不适用"
      }
    ]
  }
});
export function describeConfiguration(){return JSON.parse(JSON.stringify(manifest));}

// 本产品Workflow坐标声明。
export const workflows=Object.freeze({"ios":"ios.yml","android":"android.yml"});

// 只返回声明数据；派发与观察归通用调用方，版本及交付归本仓YAML。
export function describeAction({flow,platform,inputs={}}){
 const workflow=workflows[platform];
 if(flow==='release'&&workflow)return {repository:"crcfrcn/citizenapp",workflow,ref:'main',inputs};
 throw Error('本产品未声明该流程：'+flow+'·'+platform);
}
