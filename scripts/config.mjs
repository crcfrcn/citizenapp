import {fileURLToPath} from 'node:url';
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
 if(flow==='test'){
  const {work,environment={},...selection}=inputs;
  if(typeof work!=='string'||!work.startsWith('/'))throw Error('须交付独占绝对WORK');
  if(!environment||typeof environment!=='object'||Array.isArray(environment)||Object.values(environment).some(value=>typeof value!=='string'))throw Error('测试环境必须为显式字符串输入');
  return {command:process.execPath,args:[fileURLToPath(new URL('../lib/test/run.mjs',import.meta.url)),...testArguments(platform,selection)],
   cwd:fileURLToPath(new URL('../',import.meta.url)),env:{...environment,WORK:work}};
 }
 const workflow=workflows[platform];
 if(flow==='release'&&workflow)return {repository:"crcfrcn/citizenapp",workflow,ref:'main',inputs};
 throw Error('本产品未声明该流程：'+flow+'·'+platform);
}

// 用例坐标只在此声明；设备入口永不执行整类中未列明的历史业务操作。
const iosNative = [
 'NativeRangeUsesBoundedLengthAndExactTail','NativeResourceLoaderReadsValidatedVideo',
 'PackageInfoUsesInstalledBundleVersion','WalletConnectCallbackMatchesOnlyOwnedSchemeAndHost',
 'PackageInfoRejectsMalformedVersionTypes','SquareVideoRequestAcceptsOnlyCanonicalEnvelope',
 'SquareMediaCapabilitiesAlwaysContainFailClosedFlags','ApnsEnvironmentUsesEmbeddedProvisioningProfile',
 'ApnsEnvironmentUsesProductionOnlyForStoreReceiptWithoutProfile',
 'StorageChannelRegistersBackgroundQueueAndRejectsInvalidArgumentsThere',
 'NativeRecordLockWaitLeavesMainThreadResponsiveAndCommitsAfterRelease',
 'SystemProtectedFilesReadBackProtectionAndPermissions','SystemProtectionRejectsLinksAndForeignDatabaseDirectory',
 'NativeRecordCasSerializesConcurrentWritersAndRejectsStaleSnapshots',
 'RegistrationRecordCasProtectsAndRejectsUnknownOrStaleNames',
].map(name=>'RunnerTests/RunnerTests/test'+name);
const androidCase=(owner,names)=>names.map(name=>'com.crcfrcn.citizenapp.'+owner+'#'+name);
export const testSuites=Object.freeze({
 ios:Object.freeze({
  native:Object.freeze(iosNative),
  e2e:Object.freeze(['StartupGateSurvivesRelaunch','TradeWalletSelectionReturnsToEmptyForm',
   'ScannerReturnsToEmptyForm','ChatResumesWithoutSending','CreatorPageDisplaysImmediatelyFromMyTab']
   .map(name=>'RunnerUITests/RunnerUITests/test'+name)),
  performance:Object.freeze(['Launch','CreatorEntry','WalletScroll'].map(name=>'RunnerUITests/RunnerUITests/testPerformance'+name)
   .concat('RunnerTests/RunnerTests/testPerformanceMediaTranscode')),
 }),
 android:Object.freeze({
  native:Object.freeze([
   ...androidCase('MlsTransportSecurityInstrumentedTest',['applicationPolicyRejectsCleartextForPublicAndLocalHosts']),
   ...androidCase('RegistrationRecordSecurityInstrumentedTest',['nativeRecordWhitelistSeparatesMainAndAuxiliaryFiles','productionCasRejectsStaleWritesLinksAndTraversal']),
   ...androidCase('SquareMediaChannelInstrumentedTest',['rangeSourceBoundsEveryReadAndStopsAfterClose','rangeSourceRejectsShortBlocksAndHonorsSeek','requestAcceptsOnlyThePublishedCodecEnvelope','capabilitiesAlwaysReportBothFailClosedFlags','fastStartMovesMoovAndPatchesChunkOffset']),
  ]),
  e2e:Object.freeze(androidCase('AppFlowInstrumentedTest',['startupGateSurvivesRelaunch','tradeWalletSelectionReturnsToEmptyForm','scannerReturnsToEmptyForm','creatorEntryDisplaysImmediately','chatResumesWithoutSending'])),
  performance:Object.freeze(androidCase('PerformanceInstrumentedTest',['launch','creatorEntry','walletScroll','mediaTranscode'])),
 }),
});

// 对应XCTest原始测量名称及单位；每个场景的必需指标集中声明，缺项不能算采样成功。
const clockMetric=Object.freeze({name:'Clock Monotonic Time',units:Object.freeze(['ns','s'])});
const memoryMetric=Object.freeze({name:'Memory Peak Physical',units:Object.freeze(['kB'])});
export const performanceMetrics=Object.freeze({
 'RunnerUITests/testPerformanceLaunch':Object.freeze([{name:'App Launch Duration (',units:Object.freeze(['ns','s'])}]),
 'RunnerUITests/testPerformanceCreatorEntry':Object.freeze([clockMetric,memoryMetric]),
 'RunnerUITests/testPerformanceWalletScroll':Object.freeze([clockMetric,memoryMetric]),
 'RunnerTests/testPerformanceMediaTranscode':Object.freeze([clockMetric,memoryMetric]),
});

// 本机调度只声明测试输入；WORK、设备与已准备产物由调用者显式交付。
export function testArguments(platform,inputs={}){
 const suite=inputs.suite||'host';
 if(!['host','compile','native','e2e','performance'].includes(suite))throw Error('未知测试组');
 if(suite==='host'){if(Object.keys(inputs).some(key=>key!=='suite'))throw Error('宿主组不接受设备输入');return ['host'];}
 if(!testSuites[platform])throw Error('未知测试平台');
 const args=[suite,platform];
 const allowed=suite==='compile'?['scope']:platform==='ios'?['device','artifact']:['device','component','fixture'];
 if(Object.keys(inputs).some(key=>key!=='suite'&&!allowed.includes(key)))throw Error('未声明测试输入');
 for(const key of allowed)if(inputs[key]!==undefined){
  if(typeof inputs[key]!=='string'||!inputs[key]||/[\r\n\0]/.test(inputs[key]))throw Error('无效测试输入：'+key);
  args.push('--'+key,inputs[key]);
 }
 return args;
}
