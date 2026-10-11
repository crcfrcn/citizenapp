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
