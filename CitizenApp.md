# CitizenApp 技术文档

钱包初始化页顶部使用既有assets/logo/icon180.png公民Logo，保持原56设计单位方形尺寸及圆角；创建按钮下不显示成功去向小字。底部“导入助记词”在左、“导入冷钱包”在右，同排等宽对称显示，两个入口各向中间收一个14设计单位字宽；原设备安全提示、入口启用条件和创建/导入完成回调保持。

正式服务HTTP计时复用HttpsOnlyClient.send和AppLog.http，仅记录经过该客户端的正式API及所属媒体源。CitizenHttp包含固定功能类别、HTTP状态、headers_us、total_us及headers/complete/error/cancelled阶段；通讯录使用contacts类别，未知标签归other，无效数字归none。动态URL、查询、账户、请求头、正文和异常内容不进入门面。Stopwatch测量发送至响应头及原消费者读取正文结束，不预读正文，保留原背压、取消、响应元数据及异常身份/堆栈；正文错误在原流转发处记录，不能误报complete。headers、未消费或取消均不能当成成功。该计时不覆盖绕过客户端的图片、WebView、SDK内部WSS或页面渲染；原网络重试、超时、签名及CitizenFailure合同保持。

双端验收逐项联合当轮HTTP终态、状态及页面业务结果。iOS既有RunnerUITests以CITIZEN_READONLY_SCENE选择推荐、关注、竞选、文章、视频、创作者刷新、本人内容主动刷新、通知列表八类场景；先执行testServiceReadOnlyAction，调度方取得对应HTTP终态后再执行不重启App的testServiceReadOnlyResult。UI事件仅表示动作或页面核验，缓存、按钮可见和等待结束不能代替远端成功。会员、三类关注和充值配置沿用既有业务断言及只读矩阵。通讯录普通进页只读本地，显式关系变更和主动刷新才访问云端、评论详情可能自动标记已读，不混入纯只读验收；聊天空列表不能证明WSS已连接。原设备授权由用户完成，测试不代签、不注册身份、不点击通知项或全部已读，不保存账户截图。延迟报告分开列HTTP响应头、正文完成及页面等待，首轮与后续样本分列，失败或未覆盖项明确保留。

## 当前构建合同

公民App的编译与依赖装配唯一归scripts/build.mjs。本机由塔塔控制台既有塔塔安装器调用compile ios/android，产品直接交付隔离工程中已核验的产物路径，签名、安装和回读归控制台；GitHub由本产品两份既有Workflow调用同一工程装配与App编译入口。scripts/config.mjs按统一五字段声明APP_KEY、IOS_KEY、CITIZENAPP_PROFILE等配置需求，不放任务执行或版本算法。不新增模块，不恢复已删除的平台输入模块。

塔塔自动化每个平台一次执行只有一个控制台观察任务和一个GitHub Run。产品所属.github/workflows/ios.yml与android.yml分别公开workflow_dispatch，版本由Workflow自行计算，无须手填SDK版本或Run；固定Workflow名称为公民·iOS、公民·Android，每次Run、Job、Artifact、Tag、Release使用公民·平台·vX.Y.Z。没有prepare/settle/cancel操作、父子Run、管理Run或递归派发。iOS与Android独立任务、授权、现场和并发组，可以同时执行；同平台重复点击、恢复和取消都不创建新Run。

共用的原生动作授权、Touch ID、密钥权限及签名保护保持，安装功能正文保持。接入始终调用固定公民App仓库和所选平台Workflow；本机同平台活动任务去重、官方已有活动Run续接、派发回执持久化和不明派发不重复POST属于任务管理，保持一个平台一次执行一个任务/Run。恢复只读取已保存原Run，展示官方返回状态和字段；取消直接请求原Run，等待官方真实终态，不另建管理Run。只读5xx有限退避，变更请求不自动重试，官方错误如实报告。

iOS 和 Android 塔塔自动化在各自原步骤调用 `.github/release.mjs` 的 `version`、`release`、`cleanup`。共用的目录和工具准备、工程装配、测试输入和执行、编译调用、附件回执以及本轮现场清理也由该脚本调度。平台参数决定 Workflow 归属、Tag 前缀和正式附件数。签名和商店上传仍归各平台。独立清理 Job 检出本 Run 的源码提交后调用同一脚本。

原Run结束后按平台只保留最新成功与最新失败，活动Run保留；按准确Run编号和Release原回执确认本平台对象归属，实际删除旧正式对象、Run和关联日志/Artifact，再查询官方记录确认删除结果。正式交付是否完整由产品Workflow决定，控制台不另加Release证明或摘要门禁。历史清理只归现有独立cleanup Job，编译Job不重复清理；清理失败如实记为任务失败并保留原Run供显式恢复，但不再作为下一次产品启动的前置条件；新的产品启动按当前官方Run状态继续，结束后再次清理旧同类记录。共用状态接口仅保存本平台返回记录，其它产品及其它平台保持。

所属Workflow在单一Run中依次计算版本、准备官方工具和正式SDK组件、执行既有Node/Flutter完整回归与严格分析、准备签名输入、调用同一build.mjs编译IPA或APK+AAB、核验完整包、上传Artifact、生成正式Tag/Release并逐件下载cmp回读。任一真实依赖、测试、编译、签名或交付失败必须失败。正式Release属于自动化交付。同一 Run 将已验收的 IPA 上传到 App Store Connect，或将已验收的 AAB 上传到 Google Play 临时编辑。商店步骤以本次上传回执为准，上传失败则 Run 失败。TestFlight 分组和 Google Play 内测推出独立处理。Google Play 临时编辑不自动提交，上传回执只证明 Google 接收了本轮 AAB。

自动化平台工程生成在target/build/<Run>-<attempt>/project，本机工程生成在本轮target/build/local-*独立目录：Flutter官方create --empty --no-pub生成普通Android/iOS模板，装配原生工程和唯一assets/logo资源，Gradle与Xcode直接引用隔离工程内已有原生源码和测试，Podfile、Gradle根工程、启动页、主题和桥接头沿用本机现有Flutter的官方模板，不在脚本重复保存正文；产品既有assembleProject只复制本仓原生输入，并应用编译所需插件版本、iOS最低版本、Isar静态库输出及产品资源名称等差异。权限、网络安全和签名请求保持原产品配置。create即使使用--no-pub也会重写工程锁，因此双端在模板命令成功后写回只映射 CitizenSDK 路径的完整派生pubspec.lock，再由既有pub get --enforce-lockfile严格消费；不改源码原锁、依赖版本或校验选项。AppFrameworkInfo.plist保留原锁官方模板，不改写其中不存在的MinimumOSVersion；iOS最低16.0由既有Xcode工程与Podfile声明。Flutter空模板跳过示例测试。宿主入口直接把普通工程的lib/test和各包test中的测试路径交给同版Flutter，保留原位相对导入和开发依赖。正式仓库不恢复平台包装模块，不生成业务数据、不改Flutter/Pub包源码。testing/lib/platform_input.dart直接回读当前本轮工程里的真实平台文件，不解析脚本文本或模块源码；现有业务测试预期保持。

工具使用官方渠道和原锁：Node25.2.1、Flutter3.47.2、Rust1.97.1、Temurin17.0.20.1+1、Gradle9.1.0、AGP9.0.1、KGP2.2.20、NDK28.2.13676358、BuildTools36.0.0、CMake3.31.6和CocoaPods1.17.0。setup-java固定官方v6提交b843ebf9b913146b38da2eaa7aeddf76074ae1ad。显式交付官方运行机Android SDK完整路径；Rust准备iOS真机/模拟器或Android交叉目标。CitizenSDK 的 Git 来源保持在 pubspec.yaml/pubspec.lock，ref统一为main，仓库锁的resolved-ref只记录基线，不再要求人工跟随SDK更新。App 每轮编译开始先固定 CitizenSDK 的来源，本地 chat 随 App 源码进入同轮工程。本机读取 CitizenSDK 本地仓库当前 HEAD 已提交 SHA 与该提交的版本声明，在独立现场冻结源码，调用各SDK既有编译入口；未提交修改不参与。GitHub 从 CitizenSDK 的 Release 列表按最高正式语义版本选择完整包，固定提交、Release ID、生产Run/attempt及产物摘要，再调用各SDK公开consume入口；不以Actions Artifact选版，也不要求SDK提交等于App仓库锁中的历史基线。App 与 SDK 共用 Release 分页、GitHub API 读取和附件下载参数。SDK 仅接收已上传且标签唯一的附件，正式包校验由 SDK 自己执行。准确来源写入本轮sdk-sources.json，并进入本机编译回执及App既有正式发布回执。CitizenSDK 取得组件后不重复编译；GitHub真实读取错误或完整Release缺失直接失败。只在本轮临时工程改写 CitizenSDK 路径与锁；普通工程完成后由官方Pub解析冻结SDK的真实内部依赖，既有锁记录必须保持，仅允许新增由官方package_config指向本轮SDK源码的path包，再以--enforce-lockfile严格消费。内部包清单由SDK声明与Pub解析确定，App不复制清单，不改正式pubspec.lock、不升级第三方；已有缓存优先复用，缺件按产品声明及原锁从官方来源获取。原记录变化直接失败。无可用正式版或真实获取、编译失败直接失败，不回退旧版本、不手填Run、不要求预置交付目录。普通工程视图与原生实现仍归SDK，控制台不参与版本选择。

本机安装与自动化共用发布脚本的正式版本查询。本机复用已有的 gh 登录读取正式 Release 及对应成功 Run，使用原构建号。自动化按已成功版本递增。

本机安装和两端塔塔自动化共用 `scripts/build.mjs` 的 Flutter 准备入口。先查显式 `FLUTTER_ROOT`、本仓 `target/cache/flutter`、系统路径和其它产品已有工具，核对官方 Flutter 3.47.2 固定提交。同版工具直接交官方 `flutter precache` 检查目标平台缓存并补件。只有缺少同版工具才从 Flutter 官方仓取固定版本，核对提交并准备成功后交付缓存。准备失败报告实际工具或校验错误，签名和设备安装继续归塔塔安装器。

iOS所属Workflow在核对原锁Flutter版本后，通过官方precache --ios --macos准备原锁CitizenSDK Apple入口需要的iOS和macOS引擎，工程装配前完成，不改变工具版本。准备失败即停止，不以已有缓存存在代替本轮官方命令的成功结果。

双端宿主测试库从本轮官方.dart_tool/package_config.json读取Isar的rootUri，先按配置文件URI解析并用fileURLToPath转为包根路径，再用path.join拼接macos/libisar.dylib。绝对或相对URI、有无尾斜线及转义目录均保持同一包目录；缺包或缺库直接失败，不猜测缓存位置、不另取版本。

宿主 SDK 夹具及原生测试编译归现有 `lib/test/run.mjs`。宿主测试入口链接同轮 CitizenSDK 的 macOS 组件并交付实际测试库。普通工程直接使用 Flutter 模板生成的分析配置。App测试核对SDK的main来源声明、锁中基线及Flutter实际自动插件登记，不要求Podfile手写SDK podspec或把main改回人工固定SHA。

App 的身份、平台会员订阅、创作者档位、订阅和链上价格由 CitizenSDK 轻节点读取。服务端链上展示输入和旧展示快照读写已移除。根目录 citizen_chain 包统一监听最终区块并更新本地读模型；资源授权只用于云端业务预检。链上展示未知或读取失败时明确呈现未知／失败，不能变成无会员。钱包及公民号读取失败属于操作错误；已有公民号不重复注册。新注册沿用默认人验与 Siteverify。

四个既有Isar生成文件仅在原ignore_for_file声明补experimental_member_use，确认原锁生成器使用的实验性索引API。集合、索引和序列化由当前实体的官方生成结果唯一确定；不排除生成文件、不全局忽略诊断。所属Workflow继续执行既有Node回归、fatal infos/warnings严格分析及完整Flutter测试。

GitHub官方缓存只保存Flutter、Pub、Cargo和Gradle可再生内容，不含签名材料；恢复/保存限时且故障不阻塞实际构建。本轮工程与签名输入按Run/attempt隔离，确认编译进程退出后只清理本轮现场。依赖或App编译成功、失败及取消均在确认本轮编译进程组全部退出后释放活动标记，失败结果继续上报；无法确认退出时保留标记与现场，不因外层Node退出而假定内部后代均已退出。本机编译也只写本轮独立现场，安装器消费结束后由既有compile入口清理。

## 公民服务业务门禁与注册失败收口

钱包目录是 App 最外层门禁：SDK 报 empty 时 `WalletGate` 清空深页栈并显示钱包初始化页，状态未知不得当作无钱包或放行。钱包就绪后，公民服务业务先通过 `CidBusinessGate` 判定当前默认账户的公民号有或没有；读取失败仅表示本次操作失败。本机绑定缺失时用 `FinalizedIdentityResolver` 核对链上事实；确认未注册才显示各页共用的 `IdentityRegisterGuide`，链读取失败不冒充未注册。链上已有公民号而本机绑定缺失时复用 `MyIdService` 的 finalized 收敛入口恢复公开绑定。`SquareSessionProvider` 在门禁返回 ready 前不读取、创建或登记 MLS 设备；注册验证和缴纳注册链费所需请求仍允许在取得公民号前执行。

广场、聊天、通讯录、用户主页、会员、创作者及详情入口使用统一注册引导，只有引导中的注册按钮打开身份选择面板。面板在提交期间保留选择并阻止关闭，空闲时可以主动取消。注册、人验和设备持钥职责统一遵循本文“公民注册与设备认证”合同。

确认余额不足时留在注册面板，显示准确错误及充值/USDT、充值/USDC按钮，由用户主动选择；只向当前选择账户充值，返回后不自动签名。余额读取错误、网络故障和未知链结果不能冒充余额不足、未注册或注册成功。受保护业务继续要求会话、设备和实际请求持钥证明。

## 广场原生源码归属

广场专属原生实现分别位于 `android/square/` 的媒体通道、视频转码、MP4 faststart 三个 Kotlin 文件，以及 `ios/square/` 的媒体通道、视频转码两个 Swift 文件。两端目录均是平台下唯一一层，所有五份文件仍为普通源码，不改变 Kotlin 包名、Swift 模块、方法通道合同或依赖版本。

`MainActivity` 与 `AppDelegate` 继续在应用入口注册广场媒体通道；Android 主 Manifest 的广场通知渠道声明和应用 Gradle 的 Media3 依赖仍归应用配置。构建入口只改五份源码的读取位置，向 Gradle/Xcode 交付的工程内路径与字节不变。两端合并测试文件同时验收广场与非广场合同，继续归应用测试入口，不为目录外观拆出短测试文件。静态装配回归覆盖全部五份移动来源；实际测试与编译结果须由塔塔控制台回读。

## 双端平台输入整合

iOS 与 Android 的受控源码目录只保留一级子目录：`ios/project`、`ios/source`、`ios/square`、`ios/tests`、`android/app` 和 `android/square`。平台工具仍要求分开的 Podfile、Gradle 配置、Storyboard、资源 XML、entitlements 与 scheme；这些输入由所属Workflow在本轮普通工程中直接装配，工具标准模板与本产品必要配置共同交付准确消费路径。正式仓库不保留生成文件，也不保留被替代的短配置目录及二级子目录。

Android 主 Manifest、应用入口和Gradle声明直属 `android/app`，广场专属 Kotlin 源码直属 `android/square`；三个原生测试类分别归 `android/tests`，原测试断言和隔离边界保持。主 Manifest 已声明 `INTERNET`，因此不再生成内容重复的 debug/profile Manifest；普通启动图资源覆盖全部支持的 API，圆形与普通自适应图标分别输出但共用唯一内容。iOS 钱包回跳 `SceneDelegate` 与 `AppDelegate` 同文件，Xcode 项目不再引用单独的场景源文件。四份只含 IDE 警告或预览状态的 workspace 文件不进入产品输入。

平台目录原有 Git 忽略规则合入仓库根 `.gitignore`；Logo 唯一来源仍是 `assets/logo`，集中后的图标目录声明从平台输入还原。构建映射、源视图、静态测试和文档均使用新位置。此目录整理的测试与双端编译结果以随后塔塔控制台记录为准，当前未据此声明编译成功。

## 当前包、源码与测试入口

产品根是App包及Dart workspace管理入口，唯一pubspec.lock集中解析各Dart包。源码目录最深三级；每个保留目录至少两个真实直接子项，不设空壳或兼容转发。

```text
citizenapp/
├── pubspec.yaml、pubspec.lock、CitizenApp.md
├── lib/                 # 启动、App生命周期、组合页；test收纳本App全部测试与测试入口
├── user/             # pubspec.yaml + lib + test：身份、门禁、会员、资料、通知、业务客户端
├── wallet/              # pubspec.yaml + lib + test：core、onboarding、account、history
├── chain/               # pubspec.yaml + lib + test：轻节点业务读取、最终块同步与本地读模型
├── onchain/             # pubspec.yaml + lib + test：普通链上转账与交易入口
├── multisig/            # pubspec.yaml + lib + test：多签资金交易
├── personal/            # pubspec.yaml + lib + test：个人多签账户管理
├── offchain/            # pubspec.yaml + lib + test：清算行与链下交易
├── topup/               # pubspec.yaml + lib + test + web：稳定币充值
├── citizen/             # pubspec.yaml + lib + test：机构、提案、立法、管理员与升级
├── 8964/                # pubspec.yaml + lib + test：广场内容与媒体
├── chat/                # pubspec.yaml + lib + openmls + test：完整聊天业务
├── network/             # pubspec.yaml + lib + test：公共传输、配置与编码
├── scanner/             # pubspec.yaml + lib + test：扫码界面与公开导航端口
├── storage/             # pubspec.yaml + lib + test：数据库实体与基础操作
├── system/              # pubspec.yaml + lib + test：系统保护、主题、推送与更新
├── widgets/             # pubspec.yaml + lib + test：通用组件
├── assets/              # pubspec.yaml + test + 原资源目录：唯一资源包
├── testing/             # pubspec.yaml + lib + test：仅开发依赖的公共测试设施
├── ios/                 # project、source、square、tests及Podfile.lock
├── android/             # app、square及tests
├── scripts/             # 唯一build.mjs与config.mjs
└── .github/             # 仓库声明及双端Workflow
```

每包唯一test收纳该包各类测试、辅助与固定金标，不按类别创建空目录。lib/test/run.mjs读取真实workspace，调用Node回归、严格分析和全部包的Flutter测试；执行报告必须包含每个真实测试文件且无失败、跳过或缺失。lib/test/simulator_test.dart仅在显式设备组输入时调用所属测试的公开main入口，不复制用例，默认宿主运行不重复登记这些用例。Swift及Kotlin测试仍由各自平台tests拥有，设备执行结果单列。

Flutter资源通过citizen_assets包限定键消费，原生图标由本仓assets/logo原件交付。充值HTML、JS及原npm声明/锁属于topup/web，生成bundle只进入本轮工程。平台工程继续由产品唯一scripts/build.mjs装配到工具标准路径，不另建安装器或业务构建入口。

## 图标来源

用户指定的公民币图标 gmb_019473.png 已从 assets/icons 移至 CitizenChain 的 crates/icons，供公民链网络及原生币图标登记使用。本产品源码和 pubspec.yaml 均没有直接引用该文件，移动不引入跨仓运行时资源读取。

## chat 本地包与独立聊天数据库

chat 是 CitizenApp Dart workspace 中的普通本地业务包，唯一包声明为 chat/pubspec.yaml，name 为 chat，publish_to 为 none。聊天源码随 App 当前工作区冻结、编译和交付，不再选择聊天客户端产品的 Git 提交、Release 或安装包。

消息、会话、群组、同步、可靠队列、附件、通话和完整界面归 chat/lib。唯一 ChatRuntime 直接使用现有用户身份、会话、会员与推送服务；不保留宿主 Host、SDK Adapter、运行时继承包装或独立客户端发布体系。私聊和群聊保留各自流程，真正共用的编码、设备扇出和持久化操作只有一份。

聊天数据库唯一在 storage/lib/chat_isar.dart 声明，生成代码为 storage/lib/chat_isar.g.dart，物理文件为 chat.isar。十个集合、实例、事务、操作队列、开库、关闭和擦除均独立；用户库与广场库不承接聊天集合或聊天事务。chat/lib/chat_store.dart 仅承担这一个聊天库的业务读写。底层 Isar Core 由既有启动设施加载，不形成共享业务数据库或共享操作队列。

OpenMLS Rust 源码、原锁和 C ABI 属于 chat/mls；Dart 调用在 chat/lib/mls。Android 与 iOS 的媒体、目录保护源码分别归 android/chat、ios/chat，由 App 注册和编译。二进制为 libmls.so、MLS.framework，随 App 构建，不作为另一款 SDK 发布。Rust 1.97 Apple 构建强制 strip=none，并检查 Mach-O 字符串表八字节对齐；Android ARM64 使用原 NDK 与十六 KB ELF 页面对齐。

Proto 的唯一源为 network/proto，生成类型归 network/lib/protocol；应用认证请求、证明、公开 MLS 身份与错误模型归 network/lib/mls_authentication.dart。用户认证通过读取本机身份和生成受限证明两个定型操作复用同一身份；身份绑定及注销业务使用定型回调，不持有聊天运行时。会员事实与资源结算仍唯一归 user 包。

贴纸 PNG 统一归 citizen_assets 的 assets/stickers，清单只在 chat/lib/compose/sticker_pack.dart。资源键由这一处产生，面板、气泡及资源加载测试读取同一份清单。

聊天只使用当前chat_data与chat_mls目录，直接创建独立chat.isar及MLS状态；没有旧目录扫描、搬移、改名或数据导入分支。数据库、目录保护、关闭和擦除均按当前布局执行。

聊天包与App统一构建、测试和交付，当前源码不维护独立聊天客户端产品。

## 钱包与轻节点

根目录 `chain/` 是 `citizen_chain` workspace 包，源码直接位于 `chain/lib/`，不设 src 层。
公开入口为 `chain/lib/citizen_chain.dart`；`chain_data_service.dart` 负责唯一最终块监听、关注集合与合并同步，
`chain_data_reader.dart` 将同块键去重并以最多256键的批次调用 SDK getStorageBatch；
`chain_data.dart` 提供身份、平台会员、创作者档位／订阅和价格模型，`chain_data_store.dart` 保存只供展示的已验证快照。
既有身份读取器和订阅协议已迁入本包，业务包更新真实引用，不保留旧路径转发。

依赖方向为 App／业务包→citizen_chain→CitizenSDK及citizen_storage；chain 不依赖 user、广场、HTTP服务或页面。
SDK继续唯一拥有P2P、最终性、runtime metadata与存储证明验证；chain不实现第二套轻节点。
同一SDK实例通过 forSdk 取得一个同步器。当前账户常驻，公共头像按可见CID引用计数关注，创作者订阅按目标关注；
已覆盖当前最终块的数据直接复用，读取期间连续最终块只保留最新待处理块。
最终块高度／时间单独变化不写库、不广播业务变化；会员到期和身份日期边界造成的实际状态变化会通知。
后台暂停业务读取，恢复前台直接校准最新最终块，不逐块回放离线事件。

`storage/lib/chain_state.dart` 及其生成文件定义统一UserIsar中的 chain_state 集合，按创世链及默认账户隔离。
缓存包含schema、最终块号／hash、链时间及关注主体，旧server display不导入。恢复缓存仅供陈旧展示，仍需轻节点核验；
缺失键表示无记录，链读取／证明／解码失败保留最后成功状态并标记失败。账户切换使旧代次立即失效，
新账户不等待旧账户未返回的读取；关闭先阻止写回与通知，不以无法取消的SDK读取阻塞SDK停止。
链上数据和链下资料分别组合展示，服务端资源授权、规则及用量不覆盖链上身份或会员。


CitizenApp 提供钱包和轻节点 UI。钱包目录、签名、交易和轻节点能力由 CitizenSDK 提供，CID、广场、会员、通讯录及聊天由 App 的业务包拥有。

SDK返回初始化需求及真实状态；App按该状态显示原页面。任一热或冷账户存在均可进入，只有无钱包时初始化，读取失败不得当成无钱包。热账户热签，冷账户冷签，不能降级或替换。冷导入只接受账户码，不因恢复旧扫码页面而恢复旧的用户码或转账码解析分支。

异常钱包行读取 SDK 的只读诊断。热修复的签名及回验、冷重导的账户与地址一致性由 SDK 核验。改名复用原弹窗，删除按可信的完整目标执行。普通刷新只读现有清理意图，精确记录仍存在或安全清理未完成时保留关联材料。

追加账户的两个入口调用SDK同一钱包事务；添加下一个、指定一个及指定多个账户都只发起一次生物认证。SDK校验本次助记词归属后认证，再派生并保存整批账户；App不解封旧账户、不逐项调用追加、不缓存授权。真机XCTest只操作空表单、填写公开账户序号和在用户完成后核对重启后的下一个序号；不读写助记词、密码或替用户点击确认添加。追加复用原钱包硬件密钥，创建初始化不在追加路径执行。
指定账户序号在所有平台统一使用文本键盘，允许数字和空格，关闭自动纠正与输入建议；空格分隔的多个编号一次交给SDK追加。禁止使用没有空格键的纯数字键盘。
真机测试填写公开编号时点击字段输入区，确认键盘出现后输入，避免将包含帮助文字的语义框误作输入区域；未获得焦点必须明确失败。多个编号必须实际点击系统空格键并核对编号文本，禁止仅用整串注入证明键盘可输入。
面板按SDK稳定错误码显示中文，不直接显示原生金库英文描述；失败保留输入以便用户修正，不误报成功。

### 钱包 UI 与 SDK 接线

创建钱包后显示备份的顺序为：SDK准备、取得受控副本、真实commit成功后显示原弹窗，关闭后释放。原AlertDialog正文、按钮和布局不重写；后台/锁屏、页面退出或SDK目录归属变化清屏并拒绝迟到显示，提交成功后清屏不删除钱包。系统认证尚未显示秘密时的短暂inactive不误报退出。普通签名仍不向App交私钥。

仅有冷账户时，钱包目录仍可进入。应用保留冷账户导入入口，SDK 支持热账户与冷账户共存。

### 钱包与轻节点状态展示

钱包正常态直接返回原列表，只有刷新失败才以原Column承载提示横幅与Expanded列表；原Builder结构不改写为常驻包装层。本地刷新失败保留既有快照、重试和八秒限频轻提示，首次失败仍使用原整页错误态。SDK目录读取及资源归还保持唯一实现。

轻节点顶栏的原Widget、尺寸、颜色、呼吸动画和文案保持。CitizenSdk.getSyncStatus的finalized来自唯一provider的current_verified_finalized_block_number/hash，与历史显示的已验证最终高度同源；best高度不得替代。连接中、可用、失败、恢复、高度持续更新及页面销毁后迟到结果分别回归，不用UI假快照证明真实节点运行通过。

### 钱包页面交互

创建入口在SDK异步校验期间只阻止重复触发，不提前改变原按钮文案、非空密码确认或提交后备份顺序；退出后迟到的成功/失败均不能操作已销毁页面。原始密码只交SDK校验与规范化，不在App复制算法。账户及钱包重命名均等待原弹窗真实退场后归还控制器，不改变原Widget、文案或导航。

钱包“身份钱包”标记只消费现有MyIdService公开结果，沿原isCitizen/votingAccountId条件呈现；不能以本地绑定存在替代公民状态，也不修改身份业务。读取失败清除标记、不阻断原余额刷新；Chat运行态保持惰性，不因读取标记构造。默认账户乐观排序失败只可撤销同一SDK修订内的临时显示，不能用旧失败覆盖等待期间已读取的新修订。

余额失败只按SDK明确事实映射原提示：startFailed为原初始化失败；unavailable/integrity为原链暂不可用；notReady且现行同步事实isSyncing为原正在同步。SDK未提供原因细分的network/timeout以及无法读取同步事实的情况，显示“区块链读取失败，请稍后再试”；不从peer数量或自由文本猜测设备离线/同步超时，不新增SDK接口。余额卡继续取finalized total，已有成功金额时失败保留旧值，没有旧值才显示原点击重试入口。

根实例销毁先停止业务历史监听；其异常单独记录，不能跳过SDK有序停止。运行态SDK仍须stop成功才close，checkpoint失败不强行销毁、不虚报排空；其余初始化和业务不改。

交易页以 _canSubmit 和 _submitBlockedReason 检查轻节点是否就绪。顶栏订阅 SDK 链状态流。转账提交前以报价块的 Runtime 常量核对备注 UTF-8 字节数，准备交易时按当前链尖再次核对非空备注。

钱包页面测试在删除隔离数据库前销毁 Widget 并有界排空原生查询和监听。真实事件清理不依赖 Widget 虚拟时钟。

### 钱包交互与回归合同

交易付款选择逐个展示正常冷热账户，表单持有精确account_id，选择时核对同一目录修订，不再调用setActiveWallet或默认账户变更。余额、记录、确认及SDK交易准备统一消费同一付款账户；SDK签名和交易执行职责不变。钱包详情/冷钱包菜单改名调用renameWallet，账户菜单仍调用renameAccount，保留原编辑/错误交互。异常记录使用 SDK diagnostics 及其受控检查资源，不参与普通签名，也不按空钱包处理。SDK 拒绝旧 v2 记录，不执行空初始化或缓存重建。

钱包列表显示入口面板、空态、冷热卡片、身份徽标和默认标记。卡片消费 SDK 的账户类型、钱包名称和余额快照。冷钱包和热账户分别用对应弹窗调用 renameWallet 和 renameAccount。首次加载失败和刷新失败均提供原位重试，详情和交易列表使用独立组件。

多账户页面的菜单、默认账户标记、冷热账户和加载、重试由 App 的 UI 回归负责，底层安全测试由 SDK 负责。

App的严格SDK测试通道按实际session/requestSequence关联预设错误；冲突、读取失败等原交互测试仍经过SDK生产错误验证，不用未关联异常冒充正确平台响应。夹具不访问设备、金库或真实钱包。
既有HTTP、身份和请求证明回归共用testing/lib内的SDK测试生命周期接线，每用例独立初始化与归还；请求摘要仍来自当前真实Core，原接口/失败/重试/字段断言不变。用户码和扫码导航测试显式提供CitizenSdk Provider；像素/摄像若为UI替身必须逐用例声明，不能冒充真实二维码图像或设备验收。文章详情回归等待实际正文Widget加载，而不是对持续加载动画无限pumpAndSettle。源码边界回归同时要求原UI文件存在并调用SDK、旧钱包/金库/本机签名核心不存在，不能把恢复原页面误判为残留。

原创建页惰性ListView的回归通过真实滚动找到底部按钮。钱包与账户重命名均应保留原showDialog及Widget，并等弹窗真实退场后释放文本控制器；这一要求必须分别验证两个分支，不能以冷钱包分支通过替代账户分支。扫码预览退出时同步发起订阅撤销与SDK关闭并等待全部完成，不能因串行取消监听延后设备关闭。地址按钮测试显式注入同一SDK能力，不恢复App扫码后台。
滚动测试必须明确选择原ListView所属的外层Scrollable，不能把密码输入框自己的滚动节点也当作页面滚动；摄像资源更换回归须等待旧资源排空和新预览接管后的页面帧再检查退出归还，所有关闭/迟到断言仍保留。
生命周期回归按inactive→hidden→paused及对应返回序列发送事件，失败时也恢复测试前台状态；不能使用框架拒绝的paused→resumed跳转。备份及采集测试以有界的真实完成条件等待异步资源归还，不以画面无待处理帧推断业务Future已经完成，也不移除秘密清屏/提交成功/唯一释放断言。

原签名/SCALE/支付/设备绑定金标保留原向量，改经生产Dart SDK接口调用本轮真实Core公开C入口。既有测试支持文件只负责字段、FFI缓冲和资源归还；不复制编码算法、不预填金标。桌面调用方须在本轮CARGO_TARGET_DIR/debug准备与当前SDK源码一致的普通Core库文件；移动虚拟设备金标直接调用测试包内真实Core（iOS进程导出、Android libcitizensdk.so），不读取桌面路径。缺库、缺公开符号或ABI不符均明确失败。QR-only实例不启用链或钱包；UI用例仍显式注入合成事实。原UI生命周期接线在异步完成后检查页面仍存活，不调整原布局或业务文案。

通讯录入口收到签名请求时显示“无法识别二维码”。用户码入口收到其他码时显示“这不是用户码”。图库只领取第一项，退出后丢弃迟到结果，未取得采集资源时不报告手电筒切换成功。

用户码的两个既有入口先取得SDK encodeDocument结果，再进入原UserQrPage；页面只接收已编码文本，原标题、昵称、SS58、复制/保存按钮及底部说明不因协议迁属改变。签名摘要、SCALE字符串/u64及管理员原始载荷接SDK encodePayload。SDK钱包操作读取result取得同次真实状态；胁迫擦除仍用原delete，不换成signAndDelete。

普通冷签与交易冷签共用 QrSignSessionPage。相机和相册直接交付 CitizenQrScanResult，响应的 canonicalText 进入 SDK 非消费预检。失败保留提示和重扫，通过后交原 SDK 会话消费。预览绘制 SDK Texture 并转发页面及前后台生命周期，相册选择归 App，图像和二维码识别归 SDK。

ScannerView统一消费SDK纹理的width/height与剩余rotationDegrees：只旋转一次，不在交易、冷导入或通讯录入口增加Android判断。Android纹理已经应用的相机变换由SDK扣除；方向变化只更新同一采集资源的尺寸/角度。原BoxFit.cover和扫码遮罩保留，回归覆盖零补偿、四向更新、比例及单次打开/关闭。

AppQrImage 绘制 SDK 灰度图。App 不实现二维码编码、纠错、掩码或协议解析。二维码显示保持 240 尺寸和原主题颜色。

1. 原创建/导入按钮、原菜单顺序、非空密码确认一次、追加模式固定、失败保留输入、备份及返回行为使用原UI断言。
2. 无钱包、仅热、仅冷、冷热混合、目录读取失败、清理未收敛分别验证；不能用mock固定空/热目录替代状态覆盖。
3. 热签、冷签、错误码型留页、错误响应不消费会话、再次扫描、过期、取消、页面销毁、迟到结果及SDK关闭逐项验证。
4. AccountDetail与钱包页各自原警告/展示弹窗不能合并；原“签名并删除”必须接真实SDK受控挑战，不只保留按钮文字。
5. 原扫码框、遮罩、相册/手电筒、前后台、权限拒绝及取消保持；相册/多码选择是App UI，识别与用途判断是SDK。
6. 原wallet_multi_account_ui_test恢复其UI断言与交互脚本，替换旧WalletManager测试接线；不恢复旧核心测试实现。协议和密码学断言归SDK，App测试使用SDK公开结果，不能只断言SDK原生窗口启动。
7. Widget 回归与真机验收分别核对交互和原生能力。

### 钱包交互细节

- 原冷签流程在错误码型时留在扫码页显示“二维码类型不符／继续扫描”；普通签名响应的QrSignException按原“签名响应解析失败／确定”弹窗留在请求页，允许继续扫描。其他异常须按原分支逐项核对，不能统一替换文案。不得使用先退出页面再校验的简化流程替代；码型、期限、请求关联及验签仍由SDK执行，不能恢复旧QrSigner。
- 原请求页保留计时图标、水平12/垂直8的状态栏内边距、二维码渲染失败占位及原两行提示；这些内容不能被同标题的简化页面替代。
- 原追加面板由外部两个入口固定“添加下一个账户／添加指定账户”，面板内不切换；保持键盘避让、输入框、失败留页和按钮行为。编号解析、范围、重复及下一个编号的原子计算属于SDK，不恢复WalletManager或App重复规则。
- 助记词输入最多显示六个末尾未完成单词的候选。词表及验证来自 SDK。选中后补空格并移动光标。
- 原非空钱包密码在创建/导入时只确认一次；追加账户原流程不额外调用该确认弹窗。不得把平台原生界面的额外确认或输入模式切换带回原App。
- 原创建页的热钱包探测、导入失败保留输入、备份弹窗与门禁放行时机逐项核对；冷导入入口不能套用本机热钱包密钥可用性的按钮禁用条件。异步页面销毁和取消必须接SDK实际终态，不以“mounted检查”代替底层取消。
- 原非0号热账户菜单直接删除，不额外弹确认框；账户0整钱包确认使用“签名并删除”，冷钱包确认使用“删除钱包”。删除已提交、部分清理失败与未删除须分别显示真实结果，原待清理提示及重试交互不能被统一“删除未完成”取代。底层清理计划归SDK，不恢复App事务实现。
- 原“签名并删除”会先由账户0签名本机随机挑战并验签，成功后才删除；恢复该文字必须接SDK对应受控授权操作，不能直接调用无挑战的删除。原付款钱包选择、热钱包内部active账户和全局默认账户是不同调用语义，不能因采用统一SDK目录而擅自合并或多弹签名流程。
- 原AccountDetail私钥查看包含独立警告与不可点遮罩关闭的展示框；WalletDetail原件使用另一组文案和默认遮罩关闭，不能统一成新弹窗。警告、文字、布局、关闭路径按各自原件恢复，秘密授权、租约与清退仍由SDK安全合同支撑；历史清理时序的不足须显式核定，不能以原样为由保留秘密泄漏。
- 钱包身份、链上余额、三项操作和账户二维码使用各自展示组件。二维码颜色、尺寸和模块形状由 App 决定，协议与矩阵由 SDK 生成。
- 冷钱包表单接受规范 AccountId 或公民链 SS58 地址。扫码只接受账户码，并将 SDK 返回的 AccountId 填入表单。用户确认后，App 将输入原样提交给 SDK `importColdAccount`。失败时保留输入并在表单内显示错误，成功后返回。

AppTheme 和 AppLayout 统一提供主题与布局。钱包 UI 回归覆盖菜单顺序、短地址、默认标记、失败保留和 iOS 左缘返回。PIN、锁定次数、擦除、推送登记和后台资源处理沿各自安全合同运行。SDK 关闭测试核对实际排空。

扫码页按原件保留240扫描框、-80垂直偏移、原遮罩与角线、相册/手电筒工具栏及各用途提示，格式化差异也不能冒称字节一致。采集/识别/协议改接SDK的必要字节须单列；预览承载、QR矩阵数据接线不能被用来重新设计界面或留下第二识别/编码实现。转账填地址、加联系人、签名和冷导入不是同一个允许集，冷导入仅账户码不改变其他页面原业务入口。多码选择、回前台重开及错误留页与现有SDK安全会话的差异应明确提出，不能静默决定。

iOS 正式包的扫码回归分别从交易页地址栏、我的钱包冷导入页及我的通讯录进入共用扫码页，检查首次进入的扫码框是否持续显示动态摄像画面且无“扫码失败”。交易入口还在同一引擎退出后重进一次，验证纹理正常释放。每项 XCTest 重新启动已签名正式 App；只在内存中下采样无文字的扫码框中心区域，不主动添加截图或记录像素，也不读取钱包、联系人和转账输入。执行时禁止保留自动屏幕采集和诊断附件，结果只取脱敏文字摘要后清理。均匀白色真实场景可能使像素判定偏保守，应结合真实页面和 SDK 结果判断。Flutter 路由按实际语义树定位标题及返回按钮，入口允许标题与副标题合并，不依赖 UIKit 原生导航栏或被撤回的 SDK 窗口。

钱包公开界面 XCTest 分别验证热账户与冷钱包原菜单、重命名弹窗及取消，最后返回主导航；只操作固定公开控件，不读取名称输入框、不保存修改、不创建或导入钱包，也不保存画面。缺少对应钱包或导航不可达必须明确失败，不能跳过后报告该分支通过。

扫码预览失败时只输出采样次数、近白/近黑帧数、是否变化及固定失败提示布尔值，不输出像素。通讯录前置身份闸只观察固定提示，不注册身份；导入冷钱包底部入口按实际合并语义定位，菜单按固定文案覆盖 Flutter 暴露的语义类型。测试未到达扫码页和到达后无动态预览必须分开记录。

实际交易诊断使用独立定向 iOS UI Test 激活设备中已运行的正式 App，保留用户预填表单；测试点击“签名交易”，由 App 表单校验决定能否进入最终确认弹窗，在该弹窗等待用户亲自操作。诊断仅记录固定阶段、相对时间、待确认／已确认／失败计数差、忙碌状态和固定提示类别，不读取表单值、交易标识或画面；发起前必须读到全部计数基线，采样缺失必须明确标记不可读，确认后继续观察十秒。UI 采样时间只能证明界面状态出现的时间上界，不能冒充原生签名或链上阶段耗时。该用例默认跳过，不得纳入无人值守常规测试或替用户点击最终确认。设备测试必须禁留自动屏幕采集和诊断附件，结果仅保留脱敏文字摘要。

诊断包更新后，只读 XCTest 可在显式诊断开关下启动一次正式 App 并启用 SDK 固定阶段日志，等待主导航或准确错误页。后续交易观察仅激活该进程，不能再重启并清掉已经填写的表单；普通验收不启用原生诊断开关。

链状态只读 XCTest 独立启动已安装正式包，在交易顶栏持续采样公开 finalized 高度与连接状态；不读取交易表单、不触发签名、不截图。顶栏不显示 best，禁止从绿色或高度不变单独推断手机内部 best==finalized；须结合 SDK 真实状态来源及同期链头观测说明证据边界。

交易定向XCTest在点击签名后最多等待120秒确认弹窗，以覆盖余额证明查询；导航、基线、确认框或最终观察缺失必须明确测试失败，不能打印诊断后以Passed结束。只有明确的输入校验语句可以标记表单失败，普通收款地址标签不属于错误。用户确认后跟踪失败分类/池拒绝并在新增已确认后继续十秒；观察期间出现失败不能由后来的成功覆盖。测试仍不得点击最终确认，禁止附件与真实值输出。

### wallet 余额唯一所有者

钱包、机构和交易消费同一份 SDK 链上余额快照。链上 free、reserved、total 来自同一个 finalized 块，SDK 负责校验、缓存、并发读取和通知。App 清算模块按账户和 WSS 端点维护零钱包余额，操作卡、零钱包和提现共用状态。提现预检强制查询节点。用户库沿用既有 `balance` 正文，链上快照和清算余额在同一事务入口分别更新。删除回执和整库擦除使相应的清算状态失效，迟到响应不能写回。

页面通过 ChainBalanceScope 订阅需要展示的账户，SDK 先恢复持久快照，再按最新 finalized 区块核对。新区块直接驱动订阅账户的合并批量读取，不依赖流水、转账事件、充值回执或历史补齐。路由被覆盖、Tab 隐藏时释放订阅；SDK 在后台暂停自动查询，回前台核对最新头。读取期间只保留最新目标；相同区块的同账户复用证明。金额不变只推进内存核验块，不通知金额组件或重复写盘。未知显示占位，失败保留成功值并暴露错误；手动重试和交易预检进入同一调度队列，预检始终重新核对最新头。目录修订及删除结果来自 SDK，App 只维护拖拽预览、选择和显示。备份及私钥按 SDK 资源关闭信号清屏，擦除后只清理 App 的身份、聊天和业务记录。

余额真机回归由XCTest独立重启正式App，读取交易可用余额、两次进入钱包选择页、冷钱包卡片及两次详情、默认账户两次详情，并回到交易Tab及重启比较展示值。钱包行使用不含业务值的固定冷热语义标识；先等钱包目录出现，随后立即读取固定余额节点，不轮询金额或等待链查询后再通过。热钱包total在充值列，冷钱包在链上余额区。真实金额仅在内存比较，不进入查询谓词、日志、断言消息或截图；结果只记录固定步骤及布尔值。XCTest跨进程查询本身的耗时不作为产品网络加载时间，选择页与详情使用首次读取结果直接断言；冷钱包金额按实际卡片矩形中的唯一固定余额节点定位，不假设Flutter无障碍父子关系。身份未返回时卡片第一帧及查询次数、持久化边界另由真实数据库与Widget回归验证。

链上余额快照由 CitizenSDK 管理。首帧与恢复合同覆盖冷钱包卡片、交易钱包选择、账户详情、断网快照及主动刷新。缺失单一账户的快照不阻塞其他账户。

### 接入与安全边界

文章编辑器、广场、会员及相关协议、草稿、媒体、资料规则属于 App。

设备业务、用途封装、媒体处理、权限、通知、备份保护和更新验证属于原生宿主。钱包和轻节点通过 SDK 接入。设备会话钥、用途封装钥与钱包授权钥保持准确隔离，不能借迁出重建真实用户钥或改变已存材料身份。原通知文案、预览、隐私遮罩与页面回跳仍属App，iOS后台模糊不等于防止前台截图。旧RunnerUITests对SDK原生窗口的要求不作为恢复金标；真实验收不得依赖正式用户钱包、私有截图或未确认页面的坐标点击。

App不恢复WalletManager、旧sr25519、旧金库、旧轻节点或第二区块链核心，不新增兼容adapter、运行时切换或占位能力。其他App业务及其编解码、存储和流程保留，不按非UI分类迁入SDK。

旧Flutter敏感输入及展示会短暂持有相关内容；必须明确受控取得、退出清屏、取消和禁止日志/明文存储边界，不能继续承诺秘密永不进入Dart或Dart字符串保证物理擦除。签名仍由SDK执行。不得清空真实钱包、改写用户数据或暴露秘密来制造验收条件。

页面和文案由各 App 定义。CitizenApp 复用所属 SDK 的底层实现。

## Android受控工具配置

CitizenApp 已删除独立 hardware-secretvault 插件；钱包设备金库由 CitizenSDK 插件提供。App 普通设备认证只复用本地 chat 保存的同一 MLS 身份，不再拥有原生设备认证桥。
钱包秘密存储由 CitizenSDK 管理。

#### 定位
- 「我的 → 点背景图或资料箭头」按当前账户的本地公民号进入本人主页；不建立远端会话。广场帖子点作者按CID判断本人或他人主页。
- 用户主页寻址主键 = 永久 `cid_number`；当前绑定 `account_id` 只承担签名、授权和
  账户边界解析，主页不展示或复制 AccountId / SS58。`ss58_address` 只用于用户码、钱包、
  转账等明确账户边界
  输入输出；换绑账户不改变主页或公开昵称。`display_name` 是唯一公开昵称真源，`walletName` 只是本机钱包标签，两者不再同步。公开资料字段从未设置时，App 才按 CID 稳定选择内置昵称、头像和背景；用户已经设置图片后，优先显示UserIsar中持久保存的用户图片，读取失败保留已保存数据，缺少图片时显示中性占位，绝不回退内置照片。

##### 本人已发布内容本地副本

- `post` / `SquarePostStore` 是本人已发布内容唯一 Isar 边界，固定归属
  独立 `SocialIsar(citizenapp_social)`，不得访问其它业务数据库；
  `cid_number` 是归属主键，`account_id` 只记录发布时签名账户事实，CID 换绑不迁移。
- 正文、标题、文章图文块和媒体声明只保存在原始 `manifest_bytes` 中，不拆第二套本地正文字段；
  写入与读取均重新验证 SHA-256、当前 schema、账户、分类和内容形态，损坏数据 fail-closed。
- 本地仅接受 Worker 已确认的 `post_state=published`；`published_at` 由 Worker 提供，仓库不读取
  设备时间。图片、视频、封面、文件路径和临时签名 URL 始终不进入本表。
- Worker 确认发布后，`SquarePublishService` 使用发布阶段保留的原始 manifest 和 Worker
  发布锚写入恢复记录；帖子、媒体关联、草稿删除由同一事务提交。本地失败显示发布成功及待收尾告警，
  保留恢复记录，用户从草稿点“恢复”只继续确认或本地收尾，不再自动调度远端回灌。
- `SquarePostSyncService` 仅由明确刷新或写操作后的刷新启动；普通加载和分类切换不回灌本人副本。首次完整分页，后续按
  Worker `(published_at DESC,post_id ASC)` 扫描到上次最新事实即停止；每页原子落盘，
  全部目标页及媒体成功后才更新不含设备时间的检查点；旧本地帖缺媒体时继续全量分页修复。远端内容过期删除不反向删除本地副本。
- 本人主页由上层使用永久 `cid_number` 判定本人边界，普通进入、返回及分类切换只解析本地manifest；不创建Bearer会话、不合并自动拉取的Worker结果。头像、背景和公开昵称读取UserIsar，正文及媒体读取SocialIsar。持久写入成功后按CID通知已挂载页面重读；主动刷新才同步远端。他人主页按用户访问读取公开内容，不读取本人私有帖子库。
- 媒体实际字节由同域 `SquareMediaStore` 独立分块保存，不塞进 manifest 行或使用文件路径
  充当持久化内容。草稿、发布、显式恢复及展示统一复用该入口；图片按槽位读取字节，视频按范围读块。缺失显示“本地尚未保存媒体”，读取/完整性失败显示本地读取失败，不推断远端清理，也不自动改为网络来源。
- 单帖删除和编辑替换旧帖统一走 `SquarePostDeletionCoordinator`：归属只校验会话 CID，
  Worker 删除成功后才删同 CID 本地副本；只有精确 `404/post_not_found` 可视为远端已
  不存在并清理本地残留，权限、会话和网络错误必须保留本地副本。
- 注销挑战与确认均用 finalized 链身份复核 `session.cid_number → 当前 account_id`；
  `account_id` 只完成签名授权，Worker 按 CID 清理其云资料、广场、通讯录、聊天、关系、设备、挑战和会话。链上公开身份、钱包和永久付款核销不由注销删除。服务端硬删除成功后，App 再按 CID 删除全部本人副本和同步
  检查点；某项本地清理失败不阻断其余资料、会话、私信和SDK所属MLS状态清理，也不得把已完成的
  服务端注销误报为可重试失败。
- 注销挑战是钱包账户签名，必须按当前 `account_id` 在“我的钱包”中的 `SignMode`
  分流：Hot 只读联网设备本机私钥，Cold 只生成 `square_account_action` QR_V1 请求
  交给 CitizenWallet；模式缺失、账户不在本机钱包列表或回扫签名者不一致时拒绝。
- 本地 `CitizenProfileCache` 以 `cid_number` 为唯一资料键；注销后的本地资料必须调用
  `clear(cid_number)`。`account_id` 只用于清除该账户的 API Session 与 Chat 本地数据，
  禁止用它删除 CID 资料缓存。

#### Worker接口

请求及响应的唯一服务端合同见 /Users/rhett/citizenserve/CitizenServe.md；App由 /Users/rhett/citizenapp/user/lib/square_api_client.dart消费实际/api路径：

- GET /api/8964/posts/self：本人已发布帖子元数据、链锚和不透明游标。GET /api/8964/posts/{post_id}/manifest：逐帖读取原始 manifest，不读取媒体或增加浏览量。
- GET /api/user/profiles/{cid_number} 提供昵称、签名、图片和关系/内容计数，GET /api/user/cards/{cid_number} 提供最小业务名片。响应不交付当前绑定账户、链上身份认证和会员徽章字段。
- GET /api/8964/posts 与 GET /api/8964/follows：按当前服务端合同传CID、分类、类型和游标；POST /api/8964/follows及DELETE /api/8964/follows/{cid_number}处理关注与取关。
- PUT /api/user/profile 接受 display_name、profile_bio、avatar_hash、banner_hash；POST /api/user/profile/assets申请上传，PUT /api/user/profile/assets/{upload_id}使用原服务端短期能力。属主从真实会话派生，不能由上传正文声明。
- 完整资料媒体使用 /api/user/profiles/{cid_number}/assets/{kind}，每次GET含Range/条件读取和失败重试均现签实际MLS证明。仅 /api/user/cards/{cid_number}/avatar 的名片头像沿普通Bearer会话例外，仍核验当前身份、设备及交付围栏。
- GET /api/membergate 返回 authorization、plans、gate、usage 和 storage_cleanup_notice。authorization 只表示本次服务端资源预检结果，plans 仅含服务端套餐规则及额度。POST /api/membergate/confirm 仅提交 tx_hash、block_hash，校验准确三字段回执。原交易证明保留到确认完成。

#### 前端结构（user/lib/profile）
- `user_profile_page.dart`：`NestedScrollView + SliverAppBar(pinned) + CollapsibleHeader 直接作为 flexibleSpace + bottom:分类TabBar + TabBarView`；本人首屏只读持久资料与媒体，显式刷新复用资料和帖子同步入口。其他用户访问及主动操作仍由单个in-flight Future取得Session；远端帖子请求等待`sessionReady`，本人本地内容不依赖它。展开高度由头图、分类栏及`ProfileHeaderCard.requiredHeight`共同计算；固定区域按真实文字样式测量，不为异步会话预留纵向空间。
- `collapsible_header.dart`：展开阶段由 `ImageFiltered` 对头图单图层渐进虚化（非全屏 `BackdropFilter`）并让资料主体淡出；完全折叠态另有一个固定覆盖“状态栏安全区 + 工具栏”的真实背景层，直接复用同一用户图片或稳定默认照片（本人图片由数据库重建临时展示文件），不参与强模糊、不依赖透明 Material 透出页面。折叠比例的最小高度必须包含 36px 分类栏，确保完全折叠时固定背景不透明度精确达到 1。分类栏继续为白底，返回和三点按钮保持既有深色圆形底衬。
- `profile_header_card.dart`：圆角方形头像（用户图片优先；仅从未设置时显示稳定内置照片；已设置但暂不可读时显示中性占位）+ 身份徽章 + 公开昵称 + 独立“公民号”行 + 签名 + “互关、关注、关注者”三项关系计数 + 右上操作槽。三项统计按内容宽度紧凑连续排列，相邻项固定 18px；极窄大字体时整组保持一行并允许横向查看，不等比缩小、不拆列。互关点击进入互关列表；关注/取关仅在 `is_followed_by=true` 时同步增减互关数量，失败与关注者数量一起回滚。分类栏高 36px，显示“公文{数量}、竞选{数量}、视频{数量}、文章{数量}”，名称 16px/w700，花括号数量 11px/w400/次级色；按复合文字实宽计算左外侧、三段内部、右外侧共五段相等空隙。统计文字到分类文字的实际视觉间距始终为 15px。主页不展示 SS58、AccountId 或地址复制入口；公民号使用页面路由身份真源且不提供复制按钮。资料模型仍保留规范 `account_id`，供签名、授权和用户码使用。
- `profile_action_icons.dart` + `user/lib/creator/creator_subscribe_button.dart`：本人主页显示通用关注/取关入口，隐藏通知、私信和订阅；他人主页操作顺序固定为“可选订阅、通知、私信、关注”。创作者有有效计划才显示一个 34px 高的紧凑“订阅”入口，固定在通知左侧；无计划、加载中或链读失败完全不占位。已订阅的更换档位和取消操作收进二级面板，不能在主页展开成两枚按钮或改变纵向高度。
- `profile_kebab_menu.dart`：`⋮` 用户码（→ `user_qr_page.dart`）/编辑资料(self-only)/注销用户(self-only)；产品不提供举报功能。
- `user_qr_page.dart`：用户主页 `⋮ → 用户码` 与“我的”背景图右上角图标复用同一页，传入当前
  `cid_number + display_name + account_id`，生成严格
  `UserQrPage.userContact` 固定身份码并支持存相册。本人页面标题为“我的用户码”，
  他人主页仍为“用户码”；钱包/账户/聊天入口统一通过
  `openAccountQrPage()`，只有链上身份账户生成 `k=3`，其它账户生成五分钟 `k=4`。
  “我的”背景图图标使用 44px 点击区和紧凑可见图标；纵向位置由“我的”标题的实际行高、
  系统文字倍率和图标内边距共同计算，必须满足“可见二维码顶部 ≥ 标题文字底部”。横向中心
  继续与下方资料卡右箭头对齐。
- `profile_category_tabs.dart` + `profile_posts_list.dart`：公文/竞选/视频/文章四个互斥 Tab；“公文”是产品展示名称，底层仍使用 `posts`、normal + normal + `has_video=false`，包含纯文字和图片动态。视频传 normal + normal + `has_video=true` 并从返回动态派生视频网格，文章传 normal + article，竞选传 campaign。本人Tab始终按页面CID和分类读取本地副本，会话变化不触发远端补查；当前内容在读取失败时保留。主动下拉先调用同步协调器，成功提交后重读本地。其他用户Tab不访问本人私有副本，远端请求等待会话解析完成。内容请求未完成时保留主页头部、分类栏与当前内容区域，仅在顶部显示细进度和“正在读取内容”，禁止用圆形转圈替换当前 Tab。`didUpdateWidget` 统一监听 Session、CID 与过滤契约变化并重置分页；加载代际阻止旧响应覆盖新状态，401 最多刷新一次 Session，空态/失败态可下拉重试。
- 广场发布已合并为**统一发布页** `8964/lib/compose/`（home `_openCompose` 直进，不再底部分流）：
  - `compose_page.dart` 壳：顶栏 取消/草稿/发布（去中间标题）、头像+**类型下拉**（普通 2 项动态/文章、
    认证公民 4 项加竞选动态/竞选文章）、IndexedStack 挂 动态/文章子编辑区、底部会员额度、发布协调
    （按类型取 `collect()` 载荷→门禁→`SquarePublishService.publish`；编辑经 initial* + replace_id 预填）。
  - `document_compose_body.dart` 动态：正文 + 媒体计数 `[＋]`，**图片/视频由第一次选中的类型锁定**
    （先图=图片动态≤9、先视频=视频动态×1），发布页视频预览恒横屏 16:9。
  - `article_compose_body.dart` 文章：**标题+正文计数固定顶部**，下方图文块可滚，`插入`在焦点文本块后
    插入横屏图片块；紧凑首图（计数右侧小加号→小缩略✕），不显示大封面。校验/常量/拍平在
    `article_blocks.dart`（`buildArticleManifest`：内联图追加到首图后、块以 media_index 引用）。
  - 链上仍发 normal/campaign；manifest 标 `content_format=article`+`title`+**`content_blocks`**（文章正文图文块）。
    发布编排与媒体草稿构造分别归 `8964/lib/compose/square_publish_service.dart`、`8964/lib/media/square_media_draft.dart`。
  - 文章详情从 Worker 获取内容块，由 SquarePost.contentBlocks 解码后逐块渲染。列表只展示卡片字段及封面。
  - **草稿箱** `8964/lib/compose/`：正文、文章结构与媒体数据库标识持久化，媒体实际字节属于
    SocialIsar。选中即完整入库，处理/编辑预览使用可再生临时文件；JSON 不保存文件路径。
    列表按更新时间倒序纯读，未发布草稿不按数量淘汰；用户恢复旧文件草稿时逐条验证归属和
    完整性，入库提交后才清理旧文件。发布前保存快照，发布中及恢复中的快照禁止覆盖；发布成功
    由事务删除对应草稿，页面退出不能把已发布草稿重新保存。存在发布恢复记录时冻结正文和
    媒体编辑，主按钮显示“恢复”。草稿读取只使用本地数据库，保留稳定标题与内容区。
- `follows_list_page.dart`：关注、关注者和互关列表；页面标题和列表区域第一帧直接显示，初次读取与翻页只用
  顶部或列表内细进度，不以整页圆形转圈替换正文；按分页并行补公开资料，单个资料失败时显示
  稳定本地昵称和头像，副标题只显示完整公民号。
- `profile_edit_page.dart`：`CitizenProfileEditPage` 公开昵称/签名/头像/背景编辑；保存上传 R2 + `PUT /profile`，不得读取或重命名本机钱包；旧格式读取失败保留原记录，显式安全擦除仍处理原目录。
- `profile_presentation.dart`：唯一展示解析器；公开昵称只接受 `display_name`，优先以 `cid_number` 做 FNV-1a 稳定分桶，从内置词库与 `assets/profiles/` 11 张照片中选择默认昵称、头像和背景。头像与背景使用不同盐值且避免同图；任何钱包名、完整或截断账户都不能成为公开昵称。
- `citizen_profile.dart`、`citizen_profile_api.dart`、`citizen_profile_cache.dart`、`profile_asset_service.dart`；会话协调归 `user/lib/identity/square_session_provider.dart`。
- 私聊入口统一使用 `chat/lib/conversation/chat_navigation.dart` 的 `openDirectChat()`。通讯录、聊天、广场作者、关注/关注者/互关列表全部进入同一个 `UserProfilePage`；联系人只保存公民号和私人备注，不再维护联系人详情或公开资料副本。
- `profile_avatar.dart` 是用户主页、“我的”、通讯录、广场、聊天和关注列表共用的圆角方形头像、用户图片状态和身份徽章唯一 UI 实现，禁止各入口复制一套头像规则。“我的”头部头像与用户主页统一为 80 逻辑像素；由于“我的”头像没有主页的 4 像素边框，调用时用可配置外溢量补偿边框占位，使徽章同样明确超出头像右下边界，而不改变其它入口的默认位置。

#### 广场 feed 卡片（8964/lib/feed；媒体组件归8964/lib/media）
- 六类（图片/视频/文章 × 普通/竞选）共用统一版式；竞选与普通**媒体布局一致**，只靠身份表达区分。
- `square_post_header.dart`（图文/文章卡共用作者头部）：**圆角方形头像（真实图片优先、缺失/失败回落稳定本地照片）+ 右下角扇贝徽章**（复用 `ProfileAvatar`；无有效会员时按竞选红/投票蓝/访客金显示身份小人，有效会员按自由金/民主蓝/薪火红显示白色对勾，布局同主页头像）；昵称后**只有竞选公民**显示红色"竞选"药丸；副标题**只有竞选公民**显示岗位（`post.campaignPosition` 有值时 `岗位 · 时间`，否则只时间）；右上更多按钮 `CrossAxisAlignment.start` 贴上边缘。
- `square_media_grid.dart`（`SquareMediaGrid` + 共享 `SquareMediaTile`）：横竖屏由 `mediaItems.first.isPortrait`（媒体原始pixelWidth/pixelHeight，缺失按横屏兜底）决定。1图/视频=横屏 16:9 / 竖屏 3:4 单块；2图/3图以上=只出前两张、左右各半、**外侧圆角+中缝直角+2px 缝**（容器比例横 2:1、竖 3:2 使左右图为 1:1/3:4），3图以上第二张**右下角 `+N`**（N=总数-2）；视频叠播放键、冷归档态占位。
- `square_post_card.dart`：头部 → 正文/媒体 → `square_post_actions.dart` 互动栏。**竖屏单图/单视频=左媒体（flex2,3:4）+右正文（flex3）**；其余=正文在上、下走 `SquareMediaGrid`。
- `square_article_card.dart`：头部 → **标题(2行截断)+正文(2行截断)在上 → 强制横屏 16:9 首图在下** → 互动栏；首图=`media_items[0]`，方向恒横屏不随原始朝向。home feed 与 profile 文章 Tab 均按 `content_format==article` 分发到此卡。
- 上传计划、详情及 App 媒体模型使用同一 pixel_width 和 pixel_height。上传额度不作为显示尺寸。
- 帖子作者的昵称和头像由 Worker 按作者 CID 读取当前公开资料，App 直接消费响应。

#### 关键行为
- 关注/取关：单击 + 乐观更新（粉丝数±1，失败回滚），**不逐次做钱包账户签名**；session 由当前CID的同一MLS设备身份静默认证后复用，与钱包账户 `Hot/Cold` 模式无关。session 存在的意义是防伪造他人关注（写入完整性），非内容加密。
- 认证勾以链上已确认发布携带的 `cid_number` 为真源（confirm 时写入），不信任 App/Worker 自报。
- 主页资料媒体由当前SquareApiClient生成受保护URL并按实际请求签发凭据；页面先读按CID隔离的本机缓存，对象存在但下载失败保留旧图片或显示中性占位。名片头像与完整资料媒体分别遵循上述会话/MLS合同；广场媒体也必须通过当前身份与会员门禁，不能匿名读取R2。
- 身份页面、我的身份徽章、广场及发布编辑页统一读取本地身份展示快照；普通进入、
  重进、重启与缺缓存均不发起身份查询。发布点击后由 `SquarePublishService` 调用
  `FinalizedIdentityResolver` 完整验真一次；上传与提交链上前只复核本机账户版本，
  并校验发布会话的CID、账户和绑定版本一致，不能拿展示缓存授予发布资格。独立最终状态同步和用户明确交易确认负责链事实更新。
- 本机会员展示不读取服务端资源许可。会员展示、链上价格与创作者档位来自 citizen_chain 的最终块读模型，资源权限由服务端 RPC 隧道独立核验。
- 轻节点连接状态变化不触发身份查询；广场只订阅统一身份快照的本地变更通知。
- 广场首页显示推荐、公民圈、关注、竞选、文章、视频、通知七项分类栏、水印、信息流区域和发布按钮。七项均可长按拖动，松手后事务保存稳定分类名到 UserIsar.setting.square_tab_order；重启后保留已保存顺序，首次及重新进入广场默认显示第一项。首个 feed 等本机顺序读取完成后按默认项加载；互动子 tab 按内容聚合评论和回复通知，并使用独立阅读层级。公民圈通过 `/8964/feed/circle` 读取本人及双向关注作者的已发布内容，本地即时发布结果只合并当前 CID 本人的内容，切换时不沿用其他分类的旧结果。
  未完成时只显示顶部细进度，禁止用全屏身份门或圆形转圈替换页面。信息流 Future
  创建时立即挂只读错误观察器，随后仍由 `FutureBuilder` 接收同一个原始 Future；请求固定
  创建时的分类与加载代际，旧分类迟到结果不得覆盖新状态。Worker 返回 401 时清理当前身份
  Session 并只重试一次，不会把前台错误转换成成功或空列表。发布动作才严格读取真实链上
  默认钱包账户、CID 和 finalized 会员，浏览态缓存不得授予发布权限。发布交易必须
  按该 `account_id` 在“我的钱包”中的 `SignMode` 分流：`Hot` 只调本机私钥，
  `Cold` 只进入 CitizenWallet QR_V1 扫码，模式缺失或账户不匹配直接拒绝。
- 广场二级浏览页面同样先构建稳定页面结构：草稿箱、用户主页当前内容 Tab、关注与粉丝列表
  均在本地或远端数据到达前保留标题、导航和内容区域，只使用顶部或局部细进度。首次读取、
  分页和分类切换不得恢复整页圆形转圈；失败态保留页面并提供返回、下拉或明确重试路径。
- 广场与关注通知红点属于后台软功能：会话建立、拉取和清读任一失败都捕获到 `Object`
  边界并静默降级，不得从 `unawaited` 任务逸出影响浏览；信息流失败仍单独显示
  “广场内容加载失败”。

#### 未注册身份统一引导

- 广场会话在本机无绑定时先核对当前默认账户的 finalized 链事实；确认未注册后 feed 显示 `IdentityRegisterGuide`，不把权限状态写成「广场内容加载失败」。身份未知与服务故障保留独立失败态。
- 发布、订阅等动作不直接弹注册面板；未注册时由所属页显示统一引导，只有引导的「注册」调用 `startCidRegistrationFlow`。注册成功后身份 revision 驱动页面刷新。

#### 公民注册与设备认证

唯一入口startCidRegistrationFlow与showRegisterIdentitySheet保持。点击注册、选择身份并确认后，打开固定Cloudflare默认人验页面。页面只回传本次check_id/token，App向/user/registration/verify提交check_id/turnstile_token，由服务端Siteverify独立核实；只有is_ok:true才能进入原费用检查、钱包签名注册和SDK最终性流程。

公民号注册使用原钱包签名、广播和链上最终性核验。App 保存真实的最终结果并结束注册。首次使用账户服务时，原设备登记请求交付钱包绑定签名和 MLS 设备证明，服务端据此补建缺失的链绑定。

registration.json只保存原SDK链交易检查点和真实最终结果，使用链与账户自然键；切换机构不能绕过同账户未决交易。记录不保存服务端任务、恢复秘密、人验或过期页面能力。原文件锁、原子CAS、读回校验、路径/链接防护和安全擦除保留；不迁移或兼容旧登记协议。未知广播先恢复原SDK交易，不重复签名注册；首次SDK执行前仍须持久保存原检查点。

MLS底层继续使用现有OpenMLS库，身份密钥及生命周期由本地 chat 管理；App不生成另一套登录密钥，不重写密码学或SDK。设备登记独立复用原钱包0x1C授权，正文仅account_id/public_key/issued_at/binding_signature。用途device；设备挑战另携已有issued_at/binding_signature，申请HTTP本身用现有MLS密钥自动签准确请求。设备挑战申请 nonce 在服务端一次性占用，实际设备提交仍使用并消费服务器签发的挑战。不伪造服务器挑战，不额外增加钱包确认或链交易。

常规session/request挑战也必须先附设备持钥证明。缺有效服务器上下文的会话挑战401/invalid_session，或明确device_not_registered，仅允许一次独立设备授权恢复；503和未知错误不触发钱包动作。首次 device 挑战由服务端核对最终链绑定；失败走既有设备登记错误处理。正常会话缓存、代次失效、在途合并、钱包取消后禁止自动重弹及成员权益规则保持。

#### 会员页未注册呈现

会员会话门禁确认当前账户未注册时，显示紧凑注册引导并保留三张会员卡，不显示业务失败横幅，也不补取套餐价格。引导按钮调用唯一注册流程；注册成功后重读当前身份。已注册用户的网络或链故障仍显示明确错误与重试，公开价格读取沿用既有缓存策略。

#### 会话失败状态统一

- `SquareSessionProvider.resolveSession()` 是浏览型页面的单一会话状态入口，明确区分无钱包、
  身份投影同步中、确实未绑定、服务不可用、网络不可用和设备鉴权不可用；需要执行写动作的
  `ensureSession()` / `refreshSession()` 契约保持不变。
- 主页、创作者页和会员页不得再把所有会话异常折叠成 `session == null`。只有本地默认钱包
  账户不存在时显示“请先添加钱包账户”；本机已有 finalized CID 绑定而旧 Worker 返回
  `cid_not_bound` 时显示身份尚未同步或绑定，不否定本地钱包。
- 会员公开价格即使会话不可用也独立读取；详情页头部单独显示金额，底部按钮只显示动作或
  不可用原因，禁止再产生“请先添加钱包账户xxxx元/月”一类拼接文案。
- 新 Worker 使用 `identity_projection_pending` 与 `identity_projection_unavailable` 区分投影
  落后和服务故障；只有服务端证明投影已追平 finalized 后，`cid_not_bound` 才代表确实未绑定。

#### 文章编辑器与 Flutter 3.44

- 移动端Flutter工具版本与官方来源由本产品既有Workflow声明。文章正文使用的 `flutter_quill` 固定为
  `11.5.1`；该版本实现 Flutter 3.44 新增的 `TextInputClient.onFocusReceived`，保证编辑器
  相关页面和测试能在统一工具链中加载。
- 禁止通过回退 Flutter、跳过编辑器测试或在 pub cache 临时补丁规避接口不一致；依赖版本与
  `pubspec.lock` 必须作为同一候选提交进入 CI。

---

#### 1. 定位

广场是 CitizenApp 的独立业务域，拥有自己的 `SocialIsar`。帖子、草稿、媒体字节及其
关联按 CID 持久保存；文件仅承载可再生的处理输入，草稿打开时只按本地内容索引生成预览文件。它不得
把帖子、草稿、媒体、同步检查点或文件清理事实放进其它数据库，也不得因广场队列挂起
而阻塞 App、钱包、聊天或 UserIsar。

草稿按(cid_number,draft_id)唯一定位，列表只查询本机当前CID。只有明确点击发布才进入既有身份验真、上传、签名、交易广播及确认流程。

草稿箱接收CID、类型或仓库变化时立即撤下旧列表并重读；加载、删除和清理回执均绑定发起时的范围。编辑器监听本机身份修订：CID变化时把原快照保存回原CID，切换到新CID的独立编辑对象；已打开的草稿箱随本地身份更新。每份保存固定CID、draftId、类型及仓库，迟到身份读取、保存和发布回执不修改新编辑对象。同CID刷新保留当前内容，退出及后台保存继续使用缓存的最后快照。已提交发布的恢复事实仍沿原流程处理。

素材在正常选择/保存时持久写入本地字节库，草稿记录只引用内容哈希；当前草稿打开不回填路径格式或导入旧记录。原草稿损坏时保留记录并报错，不加入兼容或迁移分支。文件清理继续受CID、引用检查及本机安全擦除生命周期约束。

| 文件 | 职责 |
| --- | --- |
| `citizenapp_user.isar` | 27个集合：公共目录、用户资料、身份、设置、关注、余额、流水、多签与提案 |
| `citizenapp_social.isar` | 广场10个集合 |
| `chat.isar` | chat聊天10个集合 |
| `public-state.sqlite3` | CitizenSDK公共链状态与执行历史 |
| `secure-state.sqlite3` | CitizenSDK钱包安全记录与加密材料 |

统一用户库只由UserIsar打开、排队和关闭，Social与Chat保持各自独立生命周期。安装采用卸载后全新安装，不读取旧库、不迁移或增加存储版本标记。iOS和Android平台安全存储仍由所属SDK负责。

#### 2. SocialIsar

- 文件名：`citizenapp_social`
- 源码：`citizenapp/storage/lib/social_isar.dart`
- 生命周期：`active → closing → closed`
- 独立资源：数据库文件、schema、打开任务、generation、串行操作队列和关闭终态
- 同域重入：SocialIsar 回调内再次进入 SocialIsar 立即抛错，禁止形成同域自锁
- 跨域规则：回调内只允许 SocialIsar 读写；网络、平台、文件和跨域读取必须在回调外

当前 schema 的 10 个 collection：

1. `post`：本人已发布内容的规范 manifest 与不可变发布锚。
2. `draft`：类型化草稿事实；媒体和文章块仅以规范有序 JSON 保存。
3. `cursor`：完整回灌成功后的远端最新事实。
4. `cleanup`：明确删除、旧文件入库或发布收尾后的可重试文件清理事实。
5. `media`：媒体类型、内容类型、完整长度、整体哈希及完成标记。
6. `chunk`：最多 1 MiB 的实际字节、连续分块序号及块哈希。
7. `link`：草稿、发布恢复或帖子中的媒体顺序与主媒体/缩略图/封面关联。
8. `publish`：按 CID/草稿隔离的发布阶段、原始 manifest、不可变发布标识及确认事实，不保存会话凭据。
9. `erase`：按CID/post_id保存pending/confirmed删除意图；确认事实保留，防止迟到同步重新保存已删除帖子。

10. `reply`：按CID/帖子保存真实评论分页缓存与待发送操作；失败重试复用原操作ID，已删除正文清空。

点赞由服务端保存，SocialIsar 不维护点赞集合。

##### 2.1 媒体数据库

- 唯一业务入口：`8964/lib/media/square_media_store.dart`；图片、视频、封面均以字节
  分块存入数据库，不将 URL、应用缓存或外部文件当成已持久保存的媒体。
- 描述唯一键为 `(cid_number, body_hash)`；分块唯一键为
  `(cid_number, body_hash, part_index)`。内容槽位使用真实内容、顺序及用途字段，
  沿原事务查询和筛选，不持久化拼接键。三个集合均按用户归属隔离。
  引用查询同时匹配内容类型、内容标识与 CID，不允许跨用户读取、写入、关联或删除。
- `begin` 创建不可变描述；`writeChunk` 每块单独写事务，长度严格匹配对应块，乱序到达
  可保存，重复块必须字节相同。输入缓冲区先复制，调用方后续修改不能改变落盘数据。
- `finish` 逐块验证数量、长度、连续性、块哈希与完整 SHA-256；通过后才标记完成。
  中断或校验失败保留未完成状态，可显式续写或删除；不因重进页面自动重试或清理。
- `get/listByCid` 只读描述，不加载媒体字节。`readRange` 只允许完成媒体，单次最多
  1 MiB，可跨块；负数、越界、缺块与块哈希不符明确失败。EOF 允许零长度读取。
  大视频按需分段消费，完整校验不拼接整个文件。
- `attach` 只接收同 CID 的完成媒体，同一槽位的不同媒体禁止隐式覆盖；`detach` 同时
  匹配媒体标识，迟到请求不能移除新关联。删除引用不删除媒体；`deleteUnused` 在同一
  事务内确认无引用后删除描述和全部分块，仍被其它草稿或帖子引用时拒绝删除。
- 同 CID 的媒体操作跨入口实例串行，防止校验期间删除重建或关联竞态；不同 CID 独立。
  分块完整性计算位于数据库操作回调之外，数据库事务不等待网络、平台或文件 I/O。
- SocialIsar 显式关闭 `relaxedDurability`；写入完成必须遵循数据库持久提交语义，不能以
  尚未持久落盘的成功返回作为后续清理媒体来源的依据。
- 草稿、发布、远端恢复及媒体展示复用同一分块库。缺少媒体字节的帖子不得标为完整。
- 新增 `8964/test/square_media_store_test.dart` 覆盖重开数据库、断点恢复、跨块与尾块、
  幂等、描述冲突、块损坏/缺失/额外、整体哈希错误、非法范围、按 CID 隔离、引用保护及并发。

##### 2.2 草稿与发布持久化

广场发布使用一个本地发布记录及一份原始manifest。钱包签名后继续由现有CitizenSDK轻节点广播；App按当前账户和调用摘要观察已签交易记录，再独立启动上传。两路均完成后服务端核验同一笔最终交易。上传失败只补传原帖子缺失的对象；结果未知时保留发布记录。最终成功才公开，最终执行失败由服务端精确清理。只传了部分媒体也可交付原交易最终失败证明，恢复沿已保存的原区块和交易定位。本人帖子分页返回定位，App逐篇读原始manifest并验哈希，媒体已存在时复用本地文件。

- `SquareMediaStore.saveFile/saveStream` 在数据库事务外读取来源，固定分块入库并验证长度及
  完整 SHA-256。`SquareUploadService` 将成品图片、视频、缩略图/封面全部保存后才申请上传。
  发布恢复记录与媒体引用在上传前提交；每项媒体必须有完整的主媒体及缩略图或封面引用，且主媒体与 manifest 声明匹配。
- 恢复行以 `(cid_number, draft_id)` 唯一；`prepared → submitting → finalized → confirmed`
  只允许顺序前进。进入交易前先持久保存 submitting，取得链结果后保存 block_hash 和
  transaction_hash；远端确认后保存分类、链高度和服务端创建时间。
- 恢复沿原帖子、原交易与原始媒体继续。submitting 结果未知时保留原件，不重复签名或广播。
  上传失败只补传缺件，finalized 恢复重试服务端确认，confirmed 只执行本地收尾。
  数据损坏或归属不一致明确拒绝。

- `SquarePostStore.save(post, draft_id: ...)` 在同一事务核对发布事实和媒体后，保存正文及
  帖子引用、移除发布引用及草稿引用、删除对应草稿和恢复记录，同时登记临时文件清理事实。
  引用转移先于回收，仍被其它内容使用的字节保留；任一失败整笔事务回滚。
- 远端确认后的本地失败属于“已发布、待恢复”，不能引导重复扣费或重发。发布服务必须
  await本地收尾以捕获异步失败。恢复记录仍存在时禁止覆盖/删除该草稿；发布页暂停自动保存，
  并在成功返回后清除快照，阻止退出回调复活草稿。删除事务返回实际完成的布尔结果后才广播本地通知。
- SocialIsar使用上游`maxSizeMiB`参数统一设置4096 MiB（4 GiB）映射上限，保留
  当前3 GiB单视频历史安全读取合同。容量或空间耗尽明确失败，保留已提交内容；
  不自动淘汰内容。iOS映射及当前会员视频成品边界须通过最终真实验收，不以配置修改代替证据。
##### 2.3 显式同步与跨进程恢复

- 本人内容同步要求显式刷新。同 CID 和绑定版本的请求跨实例合并，身份或页面代次失效则停止。
- 逐帖获取原始 manifest 后校验 SHA-256 和 CID。详情用于核对各媒体的类型、MIME、长度及摘要。媒体通过受会话门禁的 HTTPS 读取，已完成的本地媒体直接复用。
- 正文和媒体关联按页原子保存，媒体下载与校验在事务外执行。未取得原件或校验失败时保留已有副本，不推进检查点。
- 删除先持久保存 pending 意图。远端完成或确认准确的 post_not_found 后转为 confirmed，再原子删除正文、关联与无引用媒体。删除记录阻止迟到页面写回原帖。
- 新帖替换旧帖时，按原帖子定位继续未完成删除。交易恢复仅核对同一发布事实。

#### 3. 帖子副本

- `SquarePostStore` 只访问 SocialIsar。
- `cid_number` 是归属主键；`account_id` 只记录发布时签名账户事实。
- 原始 manifest 字节、SHA-256、发布回执、链区块和 Worker `published_at` 逐字段保存。
- 同一 `post_id` 只允许完全相同的不可变发布事实幂等重放。
- 读取磁盘行时重新执行完整性校验；损坏数据 fail-closed，不降级为空白内容。
- 同步检查点是 SocialIsar 类型化实体，不使用通用 KV 或自定义 key 前缀。

#### 4. 草稿与临时文件清理

- `SquareComposeDraftStore.list()` 使用 SocialIsar 纯读；不进入写事务，不删除损坏行，
  不删除媒体。损坏行明确报错并原样保留。
- 草稿不设数量淘汰；明确删除时，草稿、引用及无引用媒体在同一事务处理，并写入
  `cleanup`，事务外再清理处理文件。发布成功使用同一个清理事实入口。
- 文件删除失败时草稿事实已经删除，但清理行保留 `try_count/last_error`；UI 显示
  “本地媒体仍待清理”及“重试清理”，不得伪报全部完成。
- `ComposeDraftMedia` 使用独立文件操作队列、generation 和关闭终态；AppLock 进入终态后
  拒绝新写，晚到 copy 必须清除自己创建的目录。
- 新处理文件只在系统临时目录的 `square_media_work/` 中产生，可从数据库再生；
  普通读取不导入或转换旧文件。CID 和草稿标识均编码为单一路径段，持久媒体只归SocialIsar。

##### 4.1 文章编辑器布局边界

- 标题区域的首图按钮、正文顶部的“添加图文框”按钮和正文段落媒体按钮必须使用同一个
  响应式内容右边界；Pixel 8a 的约 1040 物理像素只用于验收，不得写成固定坐标。
- 正文段落媒体按钮到编辑框右边和下边的视觉距离相同；其点击动作、媒体限制和草稿协议不变。
- 标题与正文计数器保持各自 16 逻辑像素水平内容边距，二者上方分隔线使用更小的 8 逻辑像素
  水平边距，使横线两端都超过计数器范围。
- 标题仍最多两行；向上滚动只隐藏标题、首图和分隔线，正文 `x/30000` 与标题 `x/50`
  计数器保持显示，向下滚动再恢复标题区域。

#### 5. 数据处置边界

- SocialIsar 不保留旧共享存储格式的兼容分支；生产与真机数据不得假定为空。
- 如需改变现有数据结构，必须先导出、核对并按唯一目标 schema 显式迁移，禁止静默丢弃。
- 生产正常启动和读取不扫描、不读取、不复制、不删除旧广场行或旧 key。
- 直接打开目标 SocialIsar；混合 schema 只允许作为中性测试夹具。
- 既有 AppLock 是用户明确安全操作/安全终态，逐域删除 SocialIsar 和
  `square_drafts/` 与 `square_media_work/`，不属于普通启动或 schema 切换。

#### 6. 自动化验收

- Social 隔离测试覆盖：Social 队列永久挂起时 User/Chat 仍可读写；同域重入快速失败；
  永久挂起不阻止终态关闭；关闭 Social 不删除 User/Chat 事实。
- 草稿测试覆盖：类型化往返、纯读取、损坏行/媒体原样保留、文件失败计划保留和重试。
- Social/User/Chat 隔离、Chat/User/AppLock 综合隔离均由现行广场目录测试覆盖。

#### 8. 广场手机本地媒体成品

- 服务端资源规则以 plans 条目的 member_level、plan、limits、resources、daily_limits 和顶层 usage 为准。规则不包含链上价格。实际授权档位由 authorization.plan 给出，读取失败不能构造放行或零用量。
- 媒体额度与成品规格唯一来自CitizenServe的membergate/limits.rs，经现有会员接口plan/limits/resources/daily_limits交付。SquareMediaPolicy只映射本次响应，不按会员名称推导码率、尺寸、质量或默认值。缺规格拒绝发布。
- 图片统一在手机生成WebP主图及缩略图；主图上限400/800/1200 KiB，最长边1280/1600/1920，初始质量65/72/78。缩略图360px/80 KiB、初始质量65；视频封面540px/120 KiB、初始质量70。按比例缩放，不放大小图，归一方向并移除EXIF。
- 视频仍为单份HEVC Main 8-bit/SDR/hvc1/MP4、最高30fps、2秒关键帧、AAC-LC 48kHz和faststart。三档480p/720p/1080p，音视频目标平均码率450000/800000/1200000bit/s、峰值675000/1200000/1800000，音频64000/96000/128000；文件上限12/200/1800 MiB，时长180/1800/10800秒。压缩由手机完成，服务端验证成品与额度，不承担转码。
- 会员页保留自由、民主、薪火三档卡片与服务端权益规则、用量。当前订阅、三档价格和订阅动作由统一轻节点读模型驱动；付费有效期使用同块 Timestamp.Now 判断。页面不读取旧 display 持久快照，也不接收通知回填的链上会员状态。
- 历史已保存媒体的安全读取顶与新上传规格独立；调小上传上限不重压、不删除历史内容，不将旧内容按新上传档位拒绝读取。
- Android 使用 Media3 Transformer 与系统 MediaCodec，只接受 API 29+ 的硬件 HEVC
  编码器和解码器；iOS 使用 AVFoundation/VideoToolbox，并以“只允许硬件”的
  `VTCompressionSession` 探针确认编码能力。任一端缺硬件能力、源视频为 HDR/Dolby
  Vision、成品参数越界或原生复核结果与文件不一致时均失败关闭，禁止 H.264 或软件编码回退。
- 主媒体、缩略图/封面和临时目录组成一个 `SquareProcessedMediaBatch`。prepare 失败、上传
  成功、上传失败或用户在本地处理阶段取消时都必须清理临时批次；成品已存数据库的字节不随
  临时目录删除。处理输入从草稿数据库生成，原始数据库媒体不会被转码结果原地覆盖。
  发布页只在 `processingMedia` 阶段允许“停止”，进入云端或链上阶段后不得用该按钮取消。
- 缩略图、封面、主媒体和 manifest 全部使用唯一 `r2_put` 契约。Worker
  签名时绑定精确字节数、内容类型、不可变缓存头和 SHA-256，complete 阶段从
  R2 HEAD 回读整对象 checksum、元数据与大小后才保存就绪状态。

本地规则、批次、上传和发布契约由 `8964/test` 持续验收；正式双端安装、
硬件 HEVC 与真机媒体行为必须以当次签名 Release 真机回读为准，不得复用历史编译
或历史设备结果冒充当前验收。

#### 9. R2 交付、弱网与生命周期

- 服务端按绑定持有原始 manifest、资料媒体和帖子媒体。App 使用 Worker 返回的准确预签名 URL 向最终对象键 PUT。媒体对象的发布可见性由 Worker 核验。
- 列表只显示图片缩略图或视频封面。本人已持久保存的媒体从本地读取，他人内容通过受保护 HTTPS 读取。详情视频按需初始化 HEVC 解码，退出后释放播放器和受保护临时文件。
- 上传中断保留同一帖子和交易定位。原件已落盘时只续签缺失对象，重试不重复发交易。
- 远端到期、注销和会员宽限回收由 CitizenServe 管理。App 按回执处理本地状态，未知结果不推定云端已删除。

### citizenapp 管理员更换模块技术文档

最新更新：2026-07-19。

#### 模块定位

`citizenapp` 是 Flutter 客户端，不区分传统前端 / 后端，不新建 `backend/`。个人多签管理员更换作为一级业务模块放在：

```text
<本仓根>/citizen/lib/administrators/
```

边界：

- 不新建 `citizenapp/backend/`。
- 需要从统一提案入口跳转时，只在入口处引用 `citizen/lib/administrators/admin_set_change_page.dart`。

#### 目录结构

```text
citizenapp/citizen/lib/administrators/
├── admin_account.dart
├── admin_account_card.dart
├── admin_account_codec.dart
├── admin_account_service.dart
├── admin_account_storage_codec.dart
├── admin_accounts_scan_service.dart
├── admin_activation_service.dart
├── admin_set_change_action_bar.dart
├── admin_set_change_call_codec.dart
├── admin_set_change_confirm_page.dart
├── admin_set_change_page.dart
├── admin_set_change_result.dart
├── admin_set_change_service.dart
├── admin_set_diff_card.dart
├── admin_set_editor.dart
├── admin_set_validation.dart
└── institution_admin_service.dart
```

测试目录：

```text
citizenapp/citizen/test/administrators/
├── admins_change_codec_test.dart
└── institution_admin_service_test.dart
```

#### 业务流程

1. 只有 `PMUL` 个人多签显示“换管理员”入口并进入 `AdminsChangePage`。
2. 调用方构造 `personalAccount` 类型的 `AdminAccountIdentity`，由 `AdminAccountService` 读取 `PersonalAdmins::AdminAccounts`。
3. 机构账户页面读取 `PublicAdmins / PrivateAdmins::AdminAccounts` 中的人员集合，并通过 `InstitutionAdminService` 左连接 entity 岗位任职；没有岗位的管理员仍保留在人员列表中，不进入机构管理员集合编辑流程。
4. 用户编辑个人多签完整管理员集合；每项字段固定为 `account_id + family_name + given_name`，账户是唯一授权和去重字段，姓、名只用于展示。
5. `AdminSetValidation` 做端上前置校验，同时校验目标阈值。
6. `PersonalAdminsChangeCallCodec` 固定构造 `PersonalAdmins.propose_admin_set_change` call data。
7. `AdminsChangeService` 只编码管理员更换 RuntimeCall，通过
   `CitizenSdk` 完成冷热签名、提交与最终执行核验。

#### 主体身份与查询门面

`<本仓根>/citizen/lib/administrators/admin_account.dart` 定义 `AdminAccountIdentity`；`AdminAccountIdentityType` 包含两种主体，调用方通过对应工厂或 `fromInstitution` 显式构造：

- `institution`：固定治理、公权、私权及非法人机构统一使用机构主体，以 `cid_number` 标识。公权 `kind=0`，私权 `kind=1`；非法人机构须显式传入所属法人的 `kind=0` 或 `kind=1`。
- `personalAccount`：个人多签主体，以 `account_id` 标识，个人多签码（PMUL），`kind=2`。

`<本仓根>/citizen/lib/administrators/institution_admin_service.dart` 是查询门面，但不接收模糊字符串身份；所有 `fetchAdmins / fetchThreshold / isAdmin / clearCache` 调用都必须传 `AdminAccountIdentity`。按单一字符串混用个人、机构、治理主体的入口不存在。

非法人机构码（`SFGT/SFGP/UNIN`）不是私权同义词。调用方必须从 CID 注册归属或链上 `AdminAccount.kind` 显式传入 `kind=0`（公权）或 `kind=1`（私权）；不得只凭机构码自动归入 `PrivateAdmins`。`OrganizationManage.propose_create_institution` 当前只直接创建公权法人或私权法人机构账户，裸非法人创建会被端上和链端拒绝。

#### 管理员更换载荷与阈值

个人多签管理员更换载荷固定为：

```text
[pallet][call][institution_code:[u8;4]][account_id:32][admins:Compact<Vec<Admin>>][new_threshold:u32_le]

Admin = [account_id:AccountId32][family_name:Compact<Vec<u8>>][given_name:Compact<Vec<u8>>]
```

规则：

- 只允许 PMUL 个人多签走 `PersonalAdmins(29).propose_admin_set_change(0)`；codec 和 service 对其它 `AdminAccountKind` 关闭失败。
- 公权、私权、非法人及固定治理机构的管理员人员集合独立于岗位任职；CitizenApp 当前不构造对应管理员集合变更调用。
- `new_threshold` 是载荷必填字段，端上和链端按同一字节结构构造、解析和签名。
- `family_name / given_name` 各自为 1..=128 UTF-8 字节；新增时留空分别规范为“管理”、“员”，不从联系人备注或合并姓名拆分生成。
- 个人多签显示动态阈值输入框，端上前置校验：`threshold * 2 > admins_len && threshold <= admins_len`。
- 个人多签动态阈值由 `InternalVote.ActivePersonalThresholds[personal_account]` 保存；机构阈值按 CID 读取 `PublicManage/PrivateManage.InstitutionGovernanceThresholds[cid_number]`，不属于本页面。
- QR_V1 只携带 `b.a + b.d`；扫码端从 `b.d` 解码出的展示字段必须与冷钱包 decoder 逐项一致：`institution_code / subject / admins / new_threshold`。

#### 管理员激活

管理员激活服务位于 `<本仓根>/citizen/lib/administrators/admin_activation_service.dart`。机构管理员列表和提案上下文只引用该服务，不再从 `lib/institution/` 承载激活逻辑。

激活记录使用 `activated_institution_admins`，只保存
`cid_number / institution_code / kind / account_id / activated_at_ms`；查询、去重和清理统一按
`cid_number + account_id` 精确匹配，不读取旧账户主键记录。

激活 QR 与 node 桌面端统一使用 QR_V1 `a=5 activate_account_id`；payload 前缀为
`GMB || 0x18`，机构主体字段固定为 `cid_number`，扫码端解码展示字段为
`institution_code / cid_number / account_id`。

#### 管理员与岗位展示

- `AdminAccountService` 的人员与完整状态共用同一整键读取、同一人员缓存及finalized块；仅展示人员不等待治理阈值，完整状态及isAdmin门禁必须继续读取同块阈值，失败不授权。清缓存后的旧读取不能回填。对公权、私权机构和个人多签统一解码四字段 `Vec<Admin>`；旧纯账户、旧三字段、合并姓名或尾部多余字节一律拒绝。
- 机构详情的管理员名册、当前钱包角色/激活、余额和提案独立加载；名册仅有一个写入入口，首次加载/失败不显示0人，完整成功的空集合才显示0。失败保留旧名单，重新进入沿唯一入口重读；不增加管理员或岗位刷新、重试按钮，旧请求不得覆盖新结果。权限重查或失败时撤销旧操作状态，人员展示不授予业务权限。
- `InstitutionAdminService` 将管理员人员真源与 entity 岗位任职做左连接；人员与任职的 `account_id` 统一为小写 `0x` 加64位十六进制。岗位展示只依赖人员名册，不等待治理阈值；岗位目录、任职的全部分页与批取固定到同一个 finalized 块。管理员可以没有岗位，同一管理员也可展示多个岗位；完整权限入口仍要求阈值读取成功。
- 岗位读取失败保留人员，内部保留资料未核实事实；共用人员卡不显示“岗位信息暂不可用”、刷新或重试控件，也不把失败显示为“暂无岗位”。只有完整读取后的空任职集合才显示“岗位：暂无岗位”；未核实的旧任职不展示。非法主体及人员读取失败不伪造空集合。
- 机构管理员列表和公开机构管理员列表统一使用 `<本仓根>/citizen/lib/institution/institution_assignment_card.dart`；姓名只在 UI 中按中文顺序合并显示，同时展示账户、岗位、任期、来源和余额。
- 个人多签仍由独立 `AdminAccount` 布局和个人管理员集合页面处理；`PersonalAdmins.propose_admin_set_change` 是 CitizenApp 唯一保留的管理员集合变更调用，公权/私权机构不得从客户端直接改写管理员集合。

#### 管理员标识与解码

- 管理员查询、激活和页面跳转使用 AdminAccountIdentity。机构管理员按 cid_number 寻址，个人多签按 personal_account 寻址。
- 机构提案保留 adminSubjectInstitutionCode，转账、管理员更换与投票按机构账户码匹配。更换成功后只清理对应主体的缓存。
- 公权管理员存储按 account_id、cid_number、family_name、given_name 解码。账户匹配只比较规范 account_id。
- OrgType.multisig 显示“多签账户”，个人多签或机构账户由管理员主体类型区分。

### Governance 治理模块技术文档（区块链规范版）

> 机构分类唯一真源 = CID 机构码（institution_code），见 [[ADR-025]]。

> 当前目录归属：机构模块按机构管理与交易业务分工——
> ① 机构身份/账户/管理员**只读**链访问 + ADR-028 统一机构模型 = `citizen/lib/institution/`(服务为 `InstitutionChainService`,storage 前缀经 `InstitutionPalletRouter` 路由 PublicManage(30)/PrivateManage(31),取代 OrganizationManage);
> ② 多签转账(公私个共用)= `multisig/lib/`;
> ③ 机构(公权+私权)创建/关闭已收归 onchina 塔塔控制台 + 冷钱包,citizenapp 不再发起;个人多签管理留 `personal/lib/`。

#### 1. 模块目标

`citizen/lib/` 负责 CitizenApp 底部“公民”Tab 及链上治理能力，覆盖：

- 提案（proposal）发起
- 投票（vote）提交
- 提案状态跟踪与结果展示

说明：

- 本文档定义的是“链上字段/格式/标准/流程”。
- 当前 App 已接入 runtime 升级、转账等主要治理路径，本文同时作为现有实现与后续扩展的对齐基线。

当前治理实现位于`citizen/lib/`：`governance`负责治理入口，`institution`负责机构模型与链访问，`proposal`负责统一提案入口及内部投票，`legislation`负责法律阅读与立法投票，`administrators`和`runtime`分别承载管理员变更与运行时升级。个人多签账户、通用多签与普通交易入口分别归`personal/lib/`、`multisig/lib/`与`onchain/lib/`。完整当前目录见本文开头的三级目录清单。

机构管理能力归`citizen/lib/institution/`，个人多签管理归`personal/lib/`，公私个共用多签转账归`multisig/lib/`。统一发起提案入口仍在`citizen/lib/proposal/`，按`ProposalSubject + ProposalCapabilityRegistry`判断展示能力。

治理页本地状态边界：

- 治理机构、提案、管理员列表等链上信息不能因为本机钱包库短暂 busy 而整页“加载失败”。
- `ProposalContextResolver` 读取本地钱包失败时返回空管理员钱包列表，并保留链上机构/提案内容展示。
- 机构详情页单独读取冷钱包管理员匹配关系；该读取失败只影响“当前用户是否管理员”的本地提示，不影响机构余额、管理员名单和提案列表。
- 所有治理模块读写 Isar 必须走 `UserIsar.instance.read()` / `UserIsar.instance.writeTxn()`，不得直接取 `UserIsar.instance.db()`。
- 治理列表和详情页的展示数据分三层：本地静态机构常量、本机 Isar 持久化展示快照、链上 runtime 真值。页面首屏只能依赖前两层；链上读取放到后台 TTL 刷新、下拉刷新、返回刷新或提交前复核。
- `ProposalLocalStore` 保存提案列表摘要和机构详情页索引；公民-提案列表的可见范围由默认公共机构码和当前钱包订阅机构实时过滤，不使用全局治理索引。`ProposalDetailLocalStore` 保存转账提案、多签管理提案、Runtime 升级提案详情快照；两者都只服务展示，不得作为投票/执行/提交前校验的最终真相。
- `AdminAccountService` 只保存机构 `admins` 人员名册和本地签名钱包匹配短缓存，不产生业务权限。提交投票前，机构内部/联合提案必须重新读取 VotePlan、每个 `RoleSubject` 的 `VoterSnapshot`、提案状态和对应完整票据投票记录；个人多签才读取 `AdminSnapshot`。
- 合格选民投票记录必须批量读取：机构内部投票走 `InternalVoteQueryService.fetchTicketVotesBatch()`，联合投票走 `RuntimeUpgradeService.fetchJointTicketVotesBatch()`；个人多签才走账户票查询。

##### 2.1 关键约束（必须遵守）

- `votingengine` 的 `create_internal_proposal`、`create_joint_proposal` 和 `internal_vote` 外部调用被禁用，直接调用会返回 `NoPermission`。
- 联合提案必须由业务治理 pallet 通过 `JointVoteEngine` trait 发起。
- 内部投票必须由业务治理 pallet 通过 `InternalVoteEngine` trait 转发。

##### 2.2 可直接由交易发起的投票引擎入口

- `JointVote::cast_admin(proposal_id, actor_cid_number, approve)`（稳定 call/storage 旧名；资格来自岗位有效选民快照）
- `cast_referendum(proposal_id, approve)`

##### 3.1 基础类型

| 字段 | 链上类型 | App 传输规范 |
| --- | --- | --- |
| `account` | `AccountId32` | SS58 地址字符串（当前链 `ss58 = 2027`） |
| `institution` | `[u8; 48]` | `0x` + 96 hex（机构 pallet id） |
| `proposal_id` | `u64` | 全局单调主键(双层 ID v1)。展示号 `(year, seq_in_year)` 通过 `votingengine::ProposalDisplayId[id]` 反查表持有,App 渲染为 `2026000123` 风格(年份 + 6 位补零序号),与主键解耦 |
| `approve` | `bool` | `true/false` |

##### 3.2 枚举与编码

- `institution_code`（CID 机构码，`[u8;4]`）：分类经谓词派生——`is_fixed_governance_code`（固定治理档：NRC/PRC/PRB/FRG/NJD）、`is_personal_code`（`PMUL` 个人多签）、`is_institution_code`（公权或私权法人机构账户码；链上不再区分公权/私权）。
- proposal kind：`0 = internal`，`1 = joint`。
- stage：`0 = internal`，`1 = joint`，`2 = citizen`。
- status：`0 = voting`，`1 = passed`，`2 = rejected`。

##### 3.3 时效与阈值

- 单阶段投票时长：`VOTING_DURATION_BLOCKS`（当前为 30 天对应区块数）。
- 内部投票通过阈值：
  - NRC：`13`（硬编码）
  - PRC：`6`（硬编码）
  - PRB：`6`（硬编码）
  - 公权/私权机构：链上 `PublicManage/PrivateManage::InstitutionGovernanceThresholds[cid_number]` 读取
  - 个人多签：链上 `internal-vote::ActivePersonalThresholds[personal_account]` 动态读取
- 联合投票权重：
  - NRC：`19`
  - 每个 PRC：`1`
  - 每个 PRB：`1`
  - 总票权：`105`
- 联合机构阈值（不是岗位阈值）：
  - NRC：`13`
  - PRC：`6`
  - PRB：`6`
- 联合投票阶段中，`VotePlan` 对应岗位的有效选民直接上链投票：
  - 某机构赞成票达到该机构阈值时，链上自动形成该机构 `yes`
  - 若该机构剩余岗位快照选民已不足以让赞成票达到阈值，链上自动形成该机构 `no`
- 联合投票 `yes >= 105` 立即通过；任一机构形成 `no` 时立即转入联合公投；否则超时后进入联合公投阶段。
- 联合公投通过规则：`yes * 100 > eligible_total * 50`（严格大于 50%）。

#### 4. 提案字段规范（按业务类型）

| 业务类型 | 提案入口 | 必填字段 | 发起权限 | 投票入口 |
| --- | --- | --- | --- | --- |
| 决议发行 | `propose_issuance` | `actor_cid_number, proposer_role_code, reason, total_amount, allocations[]` | NRC/43 PRC `COMMITTEE_MEMBER` 岗位有效任职人 | 联合+公民 |
| 协议升级 | `propose_runtime_upgrade` | `actor_cid_number, actor_role_code, reason, code, new_pow_params` | NRC/43 PRC `COMMITTEE_MEMBER` 岗位有效任职人 | 联合+公民 |
| 个人多签管理员集合变更 | `propose_admin_set_change` | `institution_code=PMUL, personal_account, admins[], new_threshold` | 个人多签当前管理员 | 内部 |
| 决议销毁 | `propose_destroy` | `actor_cid_number, proposer_role_code, institution_account, amount` | 目标 CID 中拥有 `res-dst/0 Propose` 的岗位有效任职人 | 内部 |
| GRANDPA 紧急恢复 | `propose_emergency_grandpa_key_recovery` | `actor_cid_number, actor_role_code, new_public_key, proof_nonce, proof_expires_at, new_public_key_signature` | 目标 NRC/PRC 委员岗位有效任职人 | 仅目标机构内部 |
| GRANDPA 正常更换 | `schedule_grandpa_key_rotation` | `actor_cid_number, actor_role_code, new_public_key, proof_nonce, proof_expires_at, old_public_key_signature, new_public_key_signature` | 目标 NRC/PRC 委员岗位有效任职人 | 不投票 |
| 省储行业务治理(已下线) | ~~`propose_institution_rate / propose_verify_key / propose_sweep_to_main / propose_relay_submitters`~~ | Step 2b-iv-b 随老省储行清算 pallet 一起从 runtime 删除 | — | — |
| 清算行费率治理(新) | `propose_l2_fee_rate(call_index 40)` / `set_max_l2_fee_rate(call_index 41, Root)` | `bank, new_rate_bp` | 清算行管理员 / Root | — |

##### 4.1 联合提案投票引擎字段标准

业务模块和客户端都不接收人口快照材料，也不提交独立 `PopulationScope` 参数。联合公投固定全国作用域；立法特别案由业务模块从 actor CID 推导国家/省/市作用域。投票引擎从 citizen-identity 读取一致的 `PopulationData` 后按 proposal_id 生成快照。

- `PopulationScope`：全国、省、市、镇四级内部作用域；人口数据由 `citizen-identity` 唯一提供，提案快照由投票引擎保存。
```

##### 4.2 决议发行 allocations 约束

- `allocations` 不能为空。
- 每个 `recipient` 必须唯一，`amount > 0`。
- 分配接收者集合必须与链上 `AllowedRecipients` 完整一致（不能缺项、不能多项）。
- `sum(allocations.amount) == total_amount`。

##### 4.3 GRANDPA 密钥更换约束

- 正常更换只允许目标机构单个委员按 `CID + 岗位码 + account_id` 发起，不投票；
  旧、新 GRANDPA 私钥必须签署同一份链、机构、岗位、账户、set、nonce 和有效期证明。
- 旧私钥丢失或不可签名时走紧急恢复，只允许目标机构自己的委员内部投票；
  NRC 为本机构 `13/19`，每个 PRC 为本机构 `6/9`，不是联合投票。
- `new_public_key` 不能全 0，必须是合法且非 small-order 的 32 字节 Ed25519 公钥。
- `new_public_key` 不得与当前公钥相同，不得与已使用或待处理公钥冲突。
- 两条路径都延迟生效；节点必须在 finalized 状态确认新 authority 已生效且旧 authority
  已移除后，才能自动删除旧私钥。

##### 4.4 清算行(L2)费率治理(当前,替代原省储行治理)

Step 2b-iv-b 删除了原省储行 `propose_institution_rate / propose_verify_key /
propose_sweep_to_main / propose_relay_submitters` 四项治理 Call。新清算行体系
下的等价机制:

- `propose_l2_fee_rate(actor_cid_number, institution_account, new_rate_bp)`(call_index 40):
  - `institution_account` 必须是 `actor_cid_number` 下的清算行主账户；主账户仅为费率配置对象
  - 签名者必须属于 `AdminAccounts[actor_cid_number].admins`（`CidAccountQuery::is_institution_admin`）
  - `new_rate_bp` 范围 `[1, min(MaxL2FeeRateBp, 10)]`(默认上限 10 bp = 0.1%)
  - 成功后写 `L2FeeRateProposed[bank] = (rate, now + 1680 块)`（按六分钟平均目标换算的 7 天制度区块数）
  - `on_initialize` 每块扫描,到期后自动搬到 `L2FeeRateBp[bank]` 并发 `L2FeeRateActivated` 事件
- `set_max_l2_fee_rate(new_max)`(call_index 41,Root Origin):
  - 调整全局费率上限 `MaxL2FeeRateBp`,范围 `[1, 10]` bp
  - Step 2b 起将改为由联合投票回调(免费调用)
- `propose_verify_key` / `propose_sweep_to_main` / `propose_relay_submitters`
  在清算行体系下均无等价 Call。验签密钥由清算行多签管理员的 sr25519 私钥本地持有
  (offchain_keystore),不再走链上提案;手续费划转(sweep)仍由
  `multisig-transfer` pallet 的 `propose_sweep_to_main(call_index 5)` 治理。

##### 5.1 内部投票（业务 pallet）

内部投票业务入口统一字段：

- `proposal_id: u64`
- `approve: bool`

统一函数：

- `InternalVote::cast(proposal_id, approve)`

说明：

- `admins-change` / `resolution-destro` / `grandpakey-change` 等业务 pallet 不再保留各自的 `vote_*` 投票入口。
- `multisig-transfer` 的转账、安全基金和划转提案也统一走 `InternalVote::cast`。
- ~~`vote_institution_rate` / `vote_verify_key` / `vote_relay_submitters`~~(Step 2b-iv-b 已下线,随老省储行 pallet 一起从 runtime 删除)

##### 5.2 联合机构投票（投票引擎）

`joint_vote` 字段：

- `proposal_id: u64`
- `institution: [u8;48]`
- `approve: bool`

权限要求：

- 必须由“当前联邦注册局机构管理员个人钱包”直接提交，不能跨机构代投。
- 同一管理员对同一 `proposal_id + institution` 只能投一次。
- 链上按机构当前管理员门限自动结算机构结果，不再需要额外 `approvals proof` 或机构多签提交。

##### 5.3 联合公投（联合投票第二阶段）

`cast_referendum` 字段：

- `proposal_id: u64`
- `approve: bool`

防重放要求：

- 同一 `proposal_id + account` 只能投一次。
- 投票资格由 runtime 从链上公民身份按人口作用域读取。

##### 6.1 提案发起流程（App 侧）

1. 选择业务类型并收集业务字段。
2. App 只做签名钱包和岗位码的输入完整性校验；业务发起权限最终由 runtime 按 `CID + 岗位码 + BusinessActionId + Propose` 校验，管理员登录/激活态不能替代岗位权限。
3. 组装链上业务调用字段并签名提交；联合公投和立法特别案的人口作用域由 runtime
   固定或按 actor CID 推导，投票引擎在建案事务内读取人口数据并创建快照，App 不发送作用域或独立快照交易。
4. 记录 `proposal_id` 与业务类型映射，订阅状态事件。

##### 6.2 投票流程（App 侧）

1. 根据提案类型匹配投票入口（内部/联合/选举/立法）。
2. 采集投票字段并做本地格式校验；机构联合/内部投票只允许提案创建时冻结的岗位有效选民钱包上链，个人多签内部投票使用独立管理员快照。
3. App 编码 opaque RuntimeCall 后调用 CitizenSDK
   `prepareTransaction → executePreparedTransaction`；nonce、era、签名、extrinsic、提交和观察全部由
   SDK 完成，App 不得缓存、自增、预占或回滚 nonce。
4. 投票是否成功必须由 runtime 投票引擎 storage 确认：
  - 内部投票读取 `InternalVote::InternalVotesByTicket(proposal_id, ticket)`。
  - 联合投票读取 `JointVote::JointVotesByTicket(proposal_id, institution_ticket)`。
  - 联合公投读取 `JointVote::ReferendumVotesByAccount(proposal_id, account)`。
5. SDK 返回 `finalizedSuccess` 只代表 Runtime execution 成功；内部投票和联合投票仍必须按完整票据
   回读对应 runtime 投票 storage，`tx_hash` 不能单独代表“已投票”。
6. 监听事件刷新状态：
  - `InternalVoteCast / JointInstitutionTicketVoteCast / JointInstitutionVoteFinalized / ReferendumVoteCast`
  - `ProposalAdvancedToReferendum`
  - `ProposalFinalized`

投票确认规则：

- 提交投票时，服务层等待 CitizenSDK 的 finalized execution 成功，再按本次
  `CID + 岗位码 + 钱包` 完整票据回读 runtime 投票 storage；个人多签按个人账户票据回读。
- 只有 runtime 已记录完全相同的票据，页面才把该票据显示为已投票；不得以账户级状态覆盖同一 `account_id` 的其他岗位票据。
- SDK 返回 `poolRejected/finalizedFailed` 或抛出错误时，本次提交直接失败；不得由 App 根据超时、
  tx_hash 或本地状态伪造链上投票结果。
- 服务层完成入块和 runtime 投票记录确认后，底部按钮停止 `submitting` 转圈；详情页立即更新该票据，`_load()` 只后台刷新展示状态，不得把 tx_hash 当作投票成功。
- 联合投票读取 `JointVote` storage 时，机构参数必须使用统一 `AccountId` 编码；citizenapp 只能调用 `institutionIdentityToPalletId()`，不得在页面内手写 cid `[u8;48]` 编码。

###### 6.2.1 协议升级提案在 App 里的联合投票实现

- `RuntimeUpgradeDetailPage` 从机构页进入时必须带上：
  - `institution`
  - `adminWallets`
- 页面必须读取提案冻结的 VotePlan，并逐个读取 `VotingEngine::VoterSnapshot[(proposal_id, RoleSubject)]`；再以本机已导入签名钱包构造 CID + 岗位码 + 钱包票据。不得按钱包去重，也不得用当前 `AdminAccounts` 或当前岗位任职回算历史提案资格。
- 联合投票按钮只在以下条件全部满足时启用：
  - 提案仍处于 `joint` 阶段且状态为 `voting`
  - 当前机构尚未投票
- 当前用户已导入至少一个仍未投票的本机构岗位快照选民钱包
- App 使用所选岗位快照选民钱包提交 `JointVote::cast_admin(proposal_id, actor_cid_number, approve)`；稳定 call 名不表示 admins 获得授权。
- 页面会读取：
  - `JointInstitutionTallies` 展示本机构当前赞成/反对岗位选民票数
  - `JointVotesByInstitution` 展示本机构是否已经形成最终机构结果
  - `JointVotesByTicket` 判断当前导入钱包的具体岗位票据是否已投票
- 页面展示的联合投票阈值不再写死 `3`，而是显示链上的联合权重阈值 `105`。
- 页面还会单独展示“本机构岗位快照选民投票进度 / 本机构阈值”，避免把联合权重阈值、机构阈值和不存在的岗位阈值混淆。

##### 6.3 超时与补偿

- 投票引擎在 `on_initialize` 自动做到期结算（支持分桶分批）。
- 业务 pallet 允许在部分场景手动执行或重试（如执行失败补偿）。
- App 端必须支持”最终状态后停止轮询”，避免重复提交。

##### 6.4 统一数据存储与自动清理

投票引擎统一存储所有提案数据（投票数据 + 业务数据），统一清理。业务模块不存储任何提案数据，不实现任何清理逻辑。

**统一存储：**

| Storage | 说明 | 写入方 |
| --- | --- | --- |
| `Proposals` | 提案基本信息（状态、起止区块） | 投票引擎 |
| `ProposalData` | 提案摘要层（序列化的 BoundedVec\<u8\>，默认上限 100KB） | 业务模块通过 `store_proposal_data()` |
| `ProposalObjectMeta` / `ProposalObject` | 提案对象层（大对象，例如 runtime wasm，默认上限 10MB） | 业务模块通过 `store_proposal_object()` |
| `ProposalMeta` | 辅助元数据（创建时间、通过时间） | 业务模块通过 `store_proposal_meta()` |
| `InternalTallies` / `JointInstitutionTallies` / `JointTallies` / `ReferendumTallies` | 投票计数 | 投票引擎 |
| `InternalVotesByTicket` / `JointVotesByTicket` / `JointVotesByInstitution` / `ReferendumVotesByAccount` | 个人/岗位票据及公投记录 | 投票引擎 |
| `ActiveProposalsBySubject` | 每机构活跃提案列表（上限由 runtime 配置，当前生产值 10） | 投票引擎 |

**自动清理策略（统一清理路径）：**
- 提案完成（通过/拒绝/过期）时注册延迟清理：`schedule_cleanup(proposal_id, current_block)`
- 清理时间 = 完成时区块 + **90 天**区块数
- 如果目标区块的队列已满（50 个），自动顺延到下一个区块，保证不丢失
- 每区块 `on_initialize` 检查 `CleanupQueue[当前区块]`，到期后触发清理
- 每区块最多触发 **5 个**提案进入清理流程，未处理完的保留在队列中，下个区块继续
- 实际数据删除委托给 `PendingProposalCleanups` 分块状态机，保证大量投票记录（如联合公投上万条）能分多个区块完成
- 清理状态机阶段：`AdminSnapshots → VoterSnapshots → InstitutionTicketCounts → TrackData → ProposalObject → FinalCleanup`；`TrackData` 只分派到提案实际使用的投票引擎清理其票据账本。
- 提案结束（通过/拒绝/过期）时，活跃提案名额在 `set_status_and_emit` 中**立即释放**，不依赖业务模块

##### 6.5 App 侧链路失败展示约束

- 治理列表、机构详情、提案详情读取链上数据时，如果轻节点未初始化、未同步完成或链路降级，必须显示“加载失败 / 轻节点不可用”。
- 不允许把轻节点读取失败降级成“暂无提案”“暂无管理员”“机构不存在”这类空态。
- 提案相关页面可继续把“链上 key 确实不存在”解释为空数据，但必须与“轻节点不可用”严格区分。
- `on_initialize` weight 使用预估最大值（`cleanup_limit` 次读写），确保不超出声明的 weight

**清理范围（全部）：**

| Storage | 说明 |
| --- | --- |
| `Proposals` | 提案基本信息 |
| `ProposalData` | 业务摘要（转账、销毁、runtime 升级等提案类型） |
| `ProposalObjectMeta` / `ProposalObject` | 业务大对象（如 runtime wasm） |
| `ProposalMeta` | 辅助元数据 |
| `InternalTallies` / `JointInstitutionTallies` / `JointTallies` / `ReferendumTallies` | 投票计数 |
| `InternalVotesByTicket` / `JointVotesByTicket` / `JointVotesByInstitution` / `ReferendumVotesByAccount` | 投票记录 |
| `PendingProposalCleanups` | 分块清理游标 |
| `ActiveProposalsBySubject`（兜底移除） | 活跃提案列表 |

**查询时效：**
- 90 天内：可查完整投票细节和业务详情
- 90 天后：仅可通过区块中的交易记录和事件查询
- 永久：区块中的交易记录和事件不受影响

**业务模块改造：**
- 所有模块的本地提案动作、创建块、通过块、单机构活跃提案等旧 Storage 已删除
- 所有 `cancel_stale_*` extrinsic 已删除
- 所有 `cleanup_inactive_proposal` 函数已删除
- `resolution-issuance` 和 `runtime-upgrade` 的独立 ID 体系（`NextProposalId`、`GovToJointVote`、`JointVoteToGov`）已删除，直接使用投票引擎 proposal_id

关键文件：
- `votingengine/src/cleanup.rs`（清理逻辑）
- `votingengine/src/limit.rs`（活跃提案限制）
- `votingengine/src/lib.rs`（ProposalData/ProposalObject/ProposalMeta/CleanupQueue Storage + 公共接口）

##### 6.4.1 协议升级提案的摘要 / 对象分层

- `runtime-upgrade` 现在只把 `proposer + reason + code_hash` 编进 `ProposalData`
- 原始 wasm 不再塞进摘要层，而是统一进入 `ProposalObject(kind=runtime_wasm)`
- App 列表与详情页默认只读取摘要层，不主动拉取大对象
- App 展示协议升级提案真实结果时，只读取 `VotingEngine::Proposals.status`。

##### 7.1 管理员身份检测流程

1. 用户打开机构详情页，App 先展示本地固定机构信息，再后台并行加载管理员列表和当前钱包信息。
2. 机构读取 `PublicAdmins / PrivateAdmins::AdminAccounts[cid_number]` 管理员人员集合；公权、私权每项统一为 `account_id + cid_number + family_name + given_name`。个人多签独立按 `personal_account_id` 读取相同四字段 SCALE 结构的 `PersonalAdmins`，但不复用机构岗位规则。
3. 机构 Storage key 格式：`twox_128(pallet_name) + twox_128("AdminAccounts") + blake2_128(cid_number) + SCALE(cid_number)`。
4. 机构管理员值按 pallet 严格解码为 `institution_code + Vec<Admin>`；storage key 中 CID 是机构 CID，value 内每项 `cid_number` 是管理员公民 CID 引用。两类记录均不含状态、`kind`、岗位、来源或创建时间。
5. App 再从对应 entity 的 `InstitutionRoles` 与 `InstitutionRoleAssignments` 读取岗位和有效任职，以管理员人员集合为左侧做联合展示；没有岗位的管理员不丢失。
6. 阈值不来自 `AdminAccounts`；公权/私权机构均从对应 entity 的 `InstitutionGovernanceThresholds[cid_number]` 读取，与管理员钱包数独立。
7. 当前钱包属于机构 `admins` 只能被识别为可激活的机构签名人员；业务发起和投票授权必须继续读取完整岗位任职、岗位业务权限或提案岗位快照，姓名不参与授权。
8. 投票执行返回或下拉刷新时清除对应账户短缓存并重新读取 finalized 状态。

##### 7.1.1 个人多签管理员更换协议

- 目录边界：`citizen/lib/administrators/` 只承接个人多签管理员集合变更；机构创建、注销和个人多签生命周期仍归各自 entity 业务。
- 主体规则：只接受 `PersonalAccount + PMUL`；公权、私权、固定治理和非法人机构一律拒绝进入该流程。
- call data：`[PersonalAdmins pallet][propose_admin_set_change call][institution_code=PMUL][account_id:32][admins:Compact<Vec<Admin>>][new_threshold:u32_le]`，每个 `Admin` 按 `account_id + family_name + given_name` 编码。
- 个人多签动态阈值校验为 `threshold * 2 > admins_len && threshold <= admins_len`。
- QR_V1 仍只携带 `b.a + b.d`；CitizenApp 产生三字段 call data，CitizenWallet 已按 `account_id + family_name + given_name` 严格解码并在确认页合并显示姓名。旧纯账户与旧合并姓名布局均拒签，同一次更换只产生一次最终交易签名。
- 机构岗位或任职变化由具体业务模块形成治理结果后写入 entity，且只能引用既有管理员；岗位不得派生机构 `admins`。CitizenApp 当前不提供机构管理员集合直接变更入口。
- `institution_info_test.dart` 必须同时断言 `PMUL` 允许 `adminsChange`，且固定治理、公权、私权和非法人机构均不允许该能力，防止旧机构管理员直改入口回归。

##### 7.2 机构详情页结构

机构详情页（`InstitutionDetailPage`）自上而下包含以下区域：

0. **机构账户信息卡**：UI 以“身份CID号”展示 `cid_number`，主账户、制度账户类型和内部门槛均为本地固定数据，进入页面立即显示；主账户余额是链上 finalized 动态数据，独立后台读取并只更新余额字段。
1. **顶部机构卡片**：左侧机构图标 + 中间机构类型标签与管理员/阈值信息。
   - 机构类型、阈值来自本地制度常量。
   - 管理员人数来自链上对应管理员 pallet 的 `AdminAccounts`，读取中或读取失败时只更新副标题，不阻塞页面。
   - 已激活机构签名钱包：可进入提案类型页面并填写岗位码；是否能发起由 runtime 岗位授权最终裁决。
   - 未激活机构签名钱包：可查看入口，但提交按钮禁用并提示先激活签名钱包；不得表述为“激活管理员即有权限”。
2. **机构签名人员标识**：只说明当前钱包属于 `admins` 人员名册，不承诺任何业务权限；岗位和业务权限必须独立展示/校验。
3. **管理员列表入口**：所有用户可见，点击进入管理员列表页。
4. **投票事件列表**：所有用户可见，显示“本机构内部提案 + 所有机构都可见的联合投票提案”，按 ID 倒序展示。协议升级等联合投票提案必须在所有机构入口可见，不能只挂在国家储委会单一列表下。

##### 7.2.1 机构详情页数据来源与刷新边界

| 数据 | 来源 | 刷新方式 | 首屏策略 |
| --- | --- | --- | --- |
| 机构全称/简称、类型、身份 ID | 本地静态注册表 | 随 App 版本更新 | 立即显示 |
| 主账户、费用账户、安全基金账户、永久质押账户 | 本地静态注册表 | 随 App 版本更新 | 立即显示 |
| 治理机构内部门槛 | 本地制度常量 | 随 App 版本更新 | 立即显示 |
| 管理员列表和管理员人数 | 链上对应管理员 pallet 的 `AdminAccounts` | 后台读取，30 秒内存短缓存，下拉刷新强制更新 | 显示“读取中/读取失败”副标题 |
| 当前用户管理员身份 | 本地钱包 + 本地激活记录 + 链上管理员列表 | 后台读取，激活/返回/下拉刷新后更新 | 显示身份确认中，不挡住页面 |
| 主账户余额 | finalized 链上账户余额 | 读取 SDK 持久快照，下拉刷新强制更新 | 余额字段显示“读取中” |
| 机构可见提案列表 | 链上机构提案索引 + 年度联合提案索引 | 后台读取，短缓存，下拉刷新/提案详情返回后强制更新 | 提案区局部加载 |
| 更多制度账户余额 | finalized 链上账户余额 | 用户展开后按需读取 | 不进入首屏请求 |

机构目录快照的 `custom_account_names` 表示主账户、费用账户之外的附加账户名称，不等于
“允许用户新建的普通自定义账户名”。`institutionAccountIdRows()` 必须把每个附加名称交给
`deriveInstitutionAccountIdByName()` 统一路由：七个链上保留名分别使用其固定协议
`op_tag`，其余非空名称才回落 `OP_NAME`。联邦安全局的“联邦公民安全基金”固定使用
`OP_FCSF(0x08) + FSC cid_number`，不得按普通命名账户追加名称派生；余额继续从该正确
AccountId 的 finalized `System.Account` 按需读取。

治理机构详情页不得使用单个 `_loading` 等待全部链上请求。管理员、余额、提案任一读取失败时，只能影响对应区域；固定本地数据必须始终可见。余额缓存只允许写入 finalized 读取结果，不得把 best 视图余额写入同一展示缓存。

##### 7.2.2 提案列表本地持久化读库

治理机构详情页和公民-提案的提案列表使用 `ProposalLocalStore` 保存展示摘要；机构详情页继续使用机构索引，公民-提案按当前钱包可见范围重新过滤：

| 本地持久化内容 | 存储位置 | 用途 |
| --- | --- | --- |
| `LocalProposalSummary` | UserIsar `summary` | 提案卡片首屏展示摘要 |
| 单机构提案 ID 索引 | UserIsar `list` | 治理机构详情页提案列表 |

本地摘要包含 `proposal_id / displayId / kind / stage / status / internalCode /
institutionBytes / subjectCidNumbers / full_name / title / subtitle / iconKind /
updated_at`。这些字段只用于列表展示和首屏恢复，不作为链上真相。

链上同步规则：

- 治理机构详情页先读本地机构索引和摘要；本地为空、索引超过 5 分钟、用户下拉刷新、发起/查看提案返回时，再读取当前年提案缓存并按 `subject_cid_numbers` 包含本机构 CID 过滤。
- 公民-提案从当前年提案缓存中过滤可见提案：默认机构码固定为 `NRC/NLG/NSN/NRP/NED/NJD/NSP/PRS`，订阅范围按当前热钱包订阅公权机构的 CID 精确命中 `subject_cid_numbers`；省储委会、省储行不在默认集合内，只有订阅对应机构时才展示。
- 新区块订阅只做节流检查，当前最短 60 秒刷新一次公民-提案可见 ID 列表；不得每个新区块都全量重算，也不得按订阅机构码放大到同类所有机构。
- 提案详情点击时，如果当前只有本地摘要，才按单个 `proposal_id` 读取链上详情并回写本地摘要。
- `ProposalData` 和展示摘要创建后变化很少，优先持久化复用；`status`、红点、投票记录、票数进度等动态字段按短 TTL 或用户操作触发链上刷新。

硬边界：

- 本地持久化读库只服务列表展示，不允许替代 runtime storage。
- 投票按钮可用性、是否已投票、提交前状态校验、执行状态判断，仍必须读取链上 `VotingEngine / InternalVote / JointVote / 各管理员 pallet` 相关 storage。

##### 7.2.3 公民提案列表

公民页面的"提案"子 tab 展示当前钱包可见的统一提案流，按提案 ID 倒序（新的在上）。默认机构码为 `NRC/NLG/NSN/NRP/NED/NJD/NSP/PRS`；其它公权机构只在当前钱包订阅对应机构时进入列表。

**四层优化架构**：

| 层 | 说明 | 文件 |
| --- | --- | --- |
| 新区块通知 | 消费 `CitizenSdkFinalizedBlockChanged`，对提案索引检查做 60 秒节流 | `citizen/lib/proposal/proposal_tab.dart` |
| 本地持久化读库 | `LocalProposalSummary` + 机构索引持久化，App 重启后可复用摘要；公民-提案可见范围实时过滤 | `citizen/lib/proposal/proposal_local_store.dart` |
| 本地内存缓存 | ProposalMeta / TransferProposalInfo / RuntimeUpgradeProposalInfo 缓存，避免同一会话重复 RPC | `citizen/lib/proposal/proposal_cache.dart` |
| 批量查询 | `state_queryStorageAt` 一次 RPC 查多个 key，减少网络往返 | `chain_rpc.dart::fetchStorageBatch` |
| 分页加载 | 首屏 10 个，ScrollController 滚动触底加载更多 | `citizen/lib/proposal/proposal_tab.dart` |

**数据流**：读取当前钱包订阅机构 CID → 从当前年提案缓存中过滤默认机构码和 `subject_cid_numbers` 命中的提案 → 首屏 10 条批量查询详情和上下文 → 写回本地摘要和内存缓存 → 新区块后台节流检查，有新提案再插入顶部。

**提案类型识别**：
- 内部提案：按转账等内部提案数据结构解码。
- 联合提案：按 `meta.kind == 1` 单独走联合提案解码链路，协议升级提案进入 `runtime_upgrade_detail_page.dart`。
- 未接入专用详情页的联合提案，列表仍需可见，至少保留通用联合提案卡片。

**投票权判断**：
- 遍历用户所有钱包 → 比对每个机构提案 VotePlan 中各岗位的 `VoterSnapshot` 并保留每张岗位票据；个人多签才比对 `AdminSnapshot`
- 钱包属于对应快照、尚未投票且状态为投票中 → 提案卡片显示红点
- 进入详情页后：有投票权显示投票按钮，无投票权不显示

**红点通知**：
- 提案卡片右上角：该提案需要用户投票 → 红点
- 底部"公民"tab 图标：汇总待投票数 → 带数字红点

**投票权类型（分阶段实现）**：

| 类型 | 判断依据 | 状态 |
| --- | --- | --- |
| 机构岗位投票 | 钱包属于 NRC/PRC 委员或 PRB 董事岗位有效选民快照 | ✅ 已实现 |
| 联合公投 | 钱包具备链上投票资格 | ⏭️ 后期 |
| 机构联合投票 | 钱包属于当前机构的岗位有效选民快照，且尚未对本机构投票 | ✅ 已实现 |

关键文件：`citizen/lib/proposal/proposal_tab.dart`

##### 7.3 权限控制规则

| 用户身份 | 可访问页面/功能 |
| --- | --- |
| `admins` 名册成员且具有目标岗位权限 | 机构详情页、管理员列表、投票事件列表、提案类型页面；runtime 允许发起/投票 |
| `admins` 名册成员但无目标岗位权限 | 可浏览和激活签名钱包，runtime 拒绝目标业务发起/投票 |
| 非 `admins` 成员 | 机构详情页、管理员列表、投票事件列表 |

核心原则：`admins` 只限定机构人员和可任职范围，不授予业务权限；机构提案必须由完整 `CID + 岗位码` 对应的有效任职人发起，机构投票必须命中提案创建时岗位快照。

##### 7.3.1 活跃提案数量限制

每个机构（`AccountId`）同时最多允许 runtime 配置数量的活跃提案（当前生产值为 **10**），不区分业务提案类型，由投票引擎（`votingengine::limit`，原 `active_proposal_limit`）统一管控。

- 创建提案时：`try_add_active_proposal()` 检查并添加
- 提案完成时：`remove_active_proposal()` 在 `set_status_and_emit` 中立即释放（提案通过/拒绝/过期时）
- App 端发起提案前异步查询活跃数，达上限弹窗提示"提案数量已达上限"

关键文件：`votingengine/src/limit.rs`

##### 7.4 提案类型页面

提案类型页面（`ProposalTypesPage`）根据机构类型条件展示可发起的提案：

**通用提案（所有机构类型）：**
- 转账：从机构多签账户发起转账
- 决议销毁：提议销毁机构持有的资产

**国家储委会专属提案（仅 NRC）：**
- 决议发行：发起公民币发行决议，需联合投票，未全票通过或超时进入联合公投
- 验证密钥：更换 GRANDPA 共识验证密钥
- 协议升级：协议升级提案详情展示与投票入口，提案发起只在 node 管理端

提交成功后，提案类型页应把创建结果向上冒泡到机构详情页，触发列表刷新，避免“链上已创建但机构页仍停留旧状态”。

##### 7.5 多签转账边界

多签转账不属于 governance/proposal 的实现范围。CitizenApp 端创建、详情、投票、
列表适配、余额提示、缓存和页面跳转统一由
`CitizenApp.md`
管理。

governance 侧只允许保留通用提案列表、机构详情页挂载点、投票上下文和
`InternalVote::cast` 共享能力；不得在 governance 文档或代码中重新描述
`MultisigTransfer::propose_*` 的字段、页面、service 或投票实现。

###### 7.5.1 转出资金账户（mainAccount / accounts）

`InstitutionInfo` 对治理机构使用 `InstitutionAccounts` 表达制度账户：
- `mainAccount`：主账户，转账提案的默认转出账户
- `feeAccount`：费用账户
- `safetyFundAccount`：安全基金账户，仅国家储委会显示
- `stakeAccount`：永久质押账户，仅省储行显示

个人多签和机构账户可通过 `InstitutionInfo` 传入账户，但业务侧统一读取
`InstitutionInfo.mainAccount`。治理机构不得再用其他字段表达主账户。
页面调用 CitizenSDK 转为 SS58 地址，负责缩略显示和复制。

治理机构列表页（`citizen/lib/governance/governance_tab.dart`）只负责本机展示顺序：
页面不重复显示“治理机构”标题；顶部固定一行两列等宽、等高卡片，左侧入口显示
《公民链白皮书》，标题固定单行且空间不足时等比缩小，不得换行或截断；入口使用缩小后的
书本图标和标题，右侧国家储委会把机构图标放在卡片内部左侧，视觉结构参照
立法 Tab 的国家立法院卡片。目录读取未完成时，白皮书首帧直接显示，国家储委会位置保留
同尺寸占位卡片，并只在顶部显示细进度与“正在读取治理机构”；读取失败保留分组结构和
重试入口，不得恢复整页圆形转圈。白皮书详情页标题继续显示“公民链白皮书”。省储委会
默认展开，省储行默认收起，标题行最右侧用线性右箭头/下箭头控制。两个分类共用唯一展开
状态，同时最多展开一个分类；打开任一分类时自动收起另一分类。顶部白皮书、国家储委会双卡
以及两个分类标题固定不随滚动，唯一纵向滚动区只承载当前展开分类的 43 张卡片；默认展开
省储委会时，省储行标题固定在省储委会卡片滚动区下方；两个分类都收起时，省储行标题必须
回到省储委会标题正下方，不得停留在页面底部。
治理、立法子 Tab 的首行卡片统一使用 64 设计像素高度与 16 逻辑像素顶部间距，两页必须共用
`AppLayout` 令牌；立法加载线仅在顶部覆盖显示，不能改变首行卡片坐标。
省储委会分组标题图案使用 `assets/icons/government-line.svg`；省储行分组标题图案使用
`assets/icons/bank.svg`；顶部国家储委会以外的机构卡片内部不显示全称/简称左侧图标，只显示
机构简称和右箭头。
用户长按省储委会或省储行卡片拖拽时，只能在所属分组内排序；排序以
`SharedPreferences` 保存 `cid_number` 列表到本机，不写链、不跨设备同步。
本页不得再按管理员机构优先做 `_sorted()` 自动排序；管理员身份只影响卡片高亮，
不改变展示顺序。

公权与立法浏览页遵守同一首帧边界：公权首页先显示固定省份导航，城市机构列表先显示市名
标题，立法页先显示宪法/国家机构卡与省份导航，法律列表和阅读器先显示标题及内容壳。本地
目录、法律快照或 finalized 链读取期间只更新顶部细进度；未加载机构卡保持禁用，读取失败
提供局部重试。上述浏览壳不参与管理员、投票、付款或立法权限判断。

治理机构详情页的账户信息区直接展示身份 ID 和主账户；主账户 finalized 余额后台读取并仅更新余额
字段。更多制度账户不再进入二级页面，而是在当前账户信息卡内点击箭头展开。展开项按机构
实际存在的 `feeAccount / safetyFundAccount / stakeAccount` 懒加载 finalized 链上余额，分别显示
费用账户、安全基金账户和永久质押账户。

公民提案页的合法空索引保持成功空态；首次链读失败显示局部错误和重试，刷新或翻页失败保留已有列表及待投票数。下拉和错误重试共用原强制刷新入口，清理既有年缓存再查询；首批、翻页和后台索引绑定请求代次，迟到成功或失败不得覆盖新刷新。原只读依赖可注入，组件回归显式配置后沿同一首批、刷新和事件路径验证，不能用首帧测试跳过链读代替业务验证。

法律阅读器优先展示本机完整快照，本机读取异常仍可继续 finalized 链查询。缺失法律、默认可读版本或目标正文分别给出明确错误；刷新失败保留有效正文并提供重试。用户选择历史版本立即作废旧后台请求，失败重试保持目标版本；晚到结果不得切回旧版本或覆盖新选择。生效、待生效和不可修改条款语义保持，展示缓存不参与业务授权。

治理机构详情页的提案列表先读取 `ProposalLocalStore` 中的机构索引和摘要；链上刷新成功后
回写本地摘要与机构索引。该列表展示的本地摘要允许短暂落后链上状态，但点击提案详情、投票、
执行和提交前校验必须重新读取链上详情和投票状态。

##### 7.6 管理员列表页面

管理员列表页面（`AdminListPage`）展示：
- 机构简称与类型标签
- 管理员总数与通过阈值
- 每位管理员的完整 SS58 地址（format 2027），当前用户标记"我"
- 地址一键复制功能

##### 7.6 机构标识编码

`institution_data.dart` 统一输出 D/ADR-015 `AccountId32`：内置治理机构为 `0x01 + cid_number UTF-8 + 右零填充`；个人多签为 `0x03 + AccountId32 + 15B 零填充`；注册机构账户为 `0x05 + AccountId32 + 15B 零填充`。`0x02 注册机构归属关系` 只保留给同一 CID 机构下多账户归属/检索，不作为转账支出主体。

##### 7.7 关键文件

| 文件 | 说明 |
| --- | --- |
| `citizen/lib/citizen_tab_page.dart` | 公民 Tab 二级导航入口（投票 / 治理 / 机构） |
| `citizen/lib/proposal/proposal_tab.dart` | 投票二级页，全局治理提案列表与待投票红点 |
| `CitizenSdk.events` | SDK 已验证 finalized block 事件；App 不建立节点重连器 |
| `citizen/lib/institution/institution_info.dart + citizen/lib/institution/governance_registry.dart` | 治理机构静态注册表 + `findInstitutionByCidNumber` 反查 + `formatProposalId` 格式化 |
| `citizen/lib/institution/governance_registry.generated.dart` | 从 runtime primitives 生成的治理机构身份 ID 与制度账户 |
| `citizen/lib/reserved_account_names.dart + account_derivation.dart` | 七个机构保留账户名与名称到协议 `op_tag` 的统一派生路由 |
| `citizen/lib/institution/institution_accounts.dart` | 统一构造固定治理账户、协议附加账户和普通命名账户的展示行 |
| `citizen/lib/administrators/institution_admin_service.dart` | 机构管理员只读门面：联合读取 admins 钱包集合与 entity 岗位任职 |
| `citizen/lib/institution/institution_detail_page.dart` | 统一机构详情页（管理员检测 + 账户信息内联展开 + 条件 UI + 投票事件列表） |
| `citizen/lib/proposal/proposal_context.dart` | 用户与提案关系解析（管理员 / 公民 / 查看者） |
| `citizen/lib/proposal/proposal_models.dart` | 多提案共用模型（ProposalMeta / ProposalWithDetail 等） |
| `citizen/lib/proposal/internal_vote_service.dart` | 多提案共用内部投票提交服务 |
| `citizen/lib/proposal/proposal_vote_widgets.dart` | 多提案共用投票 UI 组件 |
| `citizen/lib/proposal/institution_manage_detail_page.dart` | 跨个人/机构的多签管理提案详情页 |
| `citizen/lib/proposal/proposal_entry_page.dart` | 统一提案类型选择页 |
| `citizen/lib/runtime/runtime_upgrade_page.dart` | 协议升级说明页（不发起提案、不选择 WASM、不获取人口快照） |
| `citizen/lib/runtime/runtime_upgrade_detail_page.dart` | 协议升级提案详情页（联合投票/联合公投进度） |
| `citizen/lib/runtime/runtime_upgrade_service.dart` | 协议升级提案链上交互服务 |
| `citizen/lib/institution/institution_admin_list_page.dart` | 机构管理员列表页：按钱包聚合岗位、任期、来源和余额 |
| `citizen/lib/institution/` | 当前机构只读身份、账户、岗位与详情；机构创建、关闭不由本端发起 |
| `personal/lib/` | 个人多签层（个人列表、详情、发现、创建、关闭、管理员激活、提案历史、PersonalAdmins 链上编解码） |
| `CitizenSdk` | 类型化 finalized 链读取，不开放任意 RPC |
| `lib/main.dart` | App 壳、应用锁与底部导航；不再内联公民 Tab 业务页面 |

##### 8.1 概述

`organization-manage` 负责 CID 注册机构多签，`personal-manage` 负责个人多签。两者都复用投票引擎的内部投票机制，与固定治理档使用同一套投票、存储、清理基础设施。

##### 8.2 机构类型

注册个人账户使用个人多签码（PMUL，`is_personal_code`）；注册机构账户使用机构账户码（`is_institution_code`，公权或私权法人），与固定治理档机构码（`is_fixed_governance_code`，NRC/PRC/PRB/FRG/NJD）并列。

个人多签主体是 32 字节 `personal_account`；机构主体是最大 32 字节的 CID。两者使用不同枚举分支，禁止把机构账户地址填入 CID 分支或以账户回落机构身份。

##### 8.3 动态阈值与管理员

| 项目 | 固定治理机构 | 普通注册机构 / 个人多签 |
| --- | --- | --- |
| 管理员来源 | `public-admins::AdminAccounts[cid_number]` | 机构为 `public/private-admins::AdminAccounts[cid_number]`；个人为 `personal-admins::AdminAccounts[personal_account]` |
| 阈值来源 | 机构 entity 的制度阈值，建案时由投票引擎冻结提案快照 | 机构为 `PublicManage/PrivateManage.InstitutionGovernanceThresholds[cid_number]`；个人为 `ActivePersonalThresholds[personal_account]` |
| 管理员存储类型 | 统一四字段 `Admin` | 公权、私权机构与个人多签使用同一 SCALE 字段顺序，按 pallet 和业务规则分流 |

投票引擎通过岗位任职提供方生成机构有效投票人快照，并从 entity 读取机构治理阈值；只有个人多签阈值继续由 `internal-vote` 保存和读取。

##### 8.4 Extrinsic

| Extrinsic | call_index | 说明 | 投票 |
| --- | --- | --- | --- |
| `OrganizationManage::propose_create_institution(..., institution_code, ...)` | 17.5 | 发起 CID 机构多签账户创建提案；机构账户管理员 institution_code 必须为机构账户码（`is_institution_code`） | 投票引擎 |
| `OrganizationManage::propose_close(account, beneficiary)` | 17.1 | 发起机构多签账户关闭提案 | 投票引擎 |
| `PersonalManage::propose_create(account_name, admins, regular_threshold, amount)` | 7.0 | 发起个人多签账户创建提案；普通阈值用户输入且必须过半，注册阈值固定全员同意 | 投票引擎 |
| `PersonalManage::propose_close(account, beneficiary)` | 7.1 | 发起个人多签账户关闭提案 | 投票引擎 |
| `PersonalAdmins::propose_admin_set_change(institution_code, account, admins, new_threshold)` | 29.0 | 发起个人多签管理员集合变更提案 | 投票引擎 |
| `InternalVote::cast(proposal_id, approve)` | 20.0 | 创建、关闭、转账等内部投票统一入口 | 统一投票入口 |

##### 8.5 创建流程（Pending → Active）

1. 链上资金预留要求发起钱包余额覆盖 `初始资金 + 创建手续费 + ED`。
   个人多签页面从 SDK 报价绑定的同一 best 块读取 `PersonalManage.MinCreateAmount`，
   独立检查最低入金，再按报价检查发起钱包余额覆盖 `初始资金 + 操作费 + 执行费 + ED`。
2. 管理员调用对应创建入口 → 写入机构或个人 pending storage + 投票引擎创建提案
3. App 不能把 tx_hash 当创建成功；必须等待交易入块，并在同一区块确认
   `PersonalAdmins.PersonalAccountProposed` 或
   `OrganizationManage.InstitutionCreateProposed` 后，才写本地记录。
4. 本地提案编号必须使用事件中的 `proposal_id`，不得预测
   `VotingEngine.NextProposalId`。
5. 发起人已自动记一票赞成，其他管理员调用 `InternalVote::cast` 补票
6. 创建投票全员同意后自动执行：`Currency::transfer` 转入资金 + 对应账户状态改为 Active
7. 投票超时/否决 → 清理 pending storage

##### 8.6 关闭流程

1. 管理员调用 `propose_close` → 投票引擎创建提案
2. 发起人已自动记一票赞成，其他管理员调用 `InternalVote::cast` 补票
3. 注销投票全员同意后自动执行：扣链上手续费，把剩余 free 余额转入用户提供的收款地址，并删除对应个人/机构多签当前状态
4. 链上历史事件和历史提案不删除；CitizenApp 本地继续在统一账户列表展示已注销账户，状态显示“已注销”，不显示余额；用户在详情页点击右上角“删除”后才清理本机数据。
5. Active 状态的个人/机构多签详情页右上角菜单只显示“关闭个人多签”或“关闭机构多签”文本项，不带删除图标；Closed 状态才显示“删除”并保留删除图标。

##### 8.7 多签转账接入边界

多签账户管理目录只负责账户注册、创建、关闭、状态展示和管理员管理。
发起转账、转账详情、投票进度、余额提示、列表适配与详情跳转均由
`multisig/lib/` 实现。

`citizen/lib/institution/` 不实现多签转账逻辑；账户详情页如需展示转账入口，
只允许挂载 `multisig/lib/multisig_transfer_entry.dart` 提供的入口组件。

##### 8.8 手机端入口分流

广场使用独立底部 Tab。个人多签从交易 Tab 进入。

- 交易 Tab 在链上支付表单上方显示一行双入口：左侧“扫码支付”，右侧“多签账户”。
- “扫码支付”保持现有扫码支付流程，不显示右箭头。
- “多签账户”进入 `personal/lib/personal_account_list_page.dart`，顶部标题为“多签账户”。
- 个人多签账户列表只读取 `account` 和 `PersonalAccountLocalState`，不读取或展示机构账户。
- 个人多签 discovery 只扫描 `PersonalAdmins.AdminAccounts`，并按 `kind=Personal`、`institution_code=PMUL`、本机管理员钱包过滤。
- 机构(公权/私权)注册、创建、关闭由 OnChina 注册局塔塔控制台 + 冷钱包处理；CitizenApp 不再提供机构多签注册、发现或列表展示入口。
- 个人多签详情页必须 local-first：读取 `account`、`PersonalAccountLocalState` 和 `personal_account_detail:*`。这些都是本机持久化储存，不是内存缓存。
- 详情页本机快照显示名称、地址、本地状态、管理员和阈值；余额单独订阅 SDK 唯一快照，状态更新不写余额。
- 详情状态 TTL 只决定状态读取；余额展示没有 TTL，主动刷新及提交前通过 wallet 刷新，不重复拉管理员/阈值。
- 详情页进入时不得用全屏转圈等待 `fetchPersonalAccount()`；自动刷新必须复用 `fetchPersonalAccountsBatch([account])`，并受 TTL 控制。
- 详情页不展示“同步中”类 UI。下拉刷新、转账提案创建返回、投票返回、关闭返回才忽略 TTL 精准刷新当前账户；链上失败只保留本机已储存数据，不写成 Closed。
- Active 账户 60 分钟内不自动重复查链；Pending / Closed 账户 10 分钟内不自动重复查链；下拉刷新才忽略 TTL 强制刷新。
- 自动 discovery 只允许首次进入“多签账户”列表或本机钱包 AccountId 集合变化时触发；不做每日自动扫描，也不增加单独扫描按钮。
- 下拉刷新先强制刷新已知个人多签账户状态，再强制执行个人多签 discovery。
- 创建、关闭、投票、删除返回时只刷新相关个人多签账户或本地记录，不重新扫描全部个人多签。
- 个人多签状态刷新由 `PersonalManageService.fetchPersonalAccountsBatch()` 分阶段批量读取 `PersonalAccounts / PersonalAdmins::AdminAccounts / ActivePersonalThresholds`；Pending 阈值按提案 ID 单独读取，不作账户回落。
- 批量路径对同一 finalized block 调用 `CitizenSdk.getStorageBatch()`，
  列表页不得逐个账户循环调用详情查询。
- 个人多签账户列表右上角加号直接进入 `personal_account_create_page.dart`，不再弹出个人/机构选择。

发起转账提案不删除，
入口由 `multisig/lib/multisig_transfer_entry.dart` 提供，
具体页面和链上构造仍归 `multisig/lib/`。

CitizenApp 个人多签使用 runtime 的 `personal-admins` 合同。
个人创建、关闭、管理员更换、管理员激活、待创建提案反查、提案历史、PersonalAdmins call data、
PersonalAdmins ProposalData 解码、`PersonalAdmins::PersonalAccounts` storage codec
统一放入 `personal/lib/`；机构账户能力归入 `citizen/lib/institution/` 和 `citizen/lib/administrators/`。
个人/机构共用的提案详情与上下文归 `citizen/lib/proposal/`，账户与机构模型归 `citizen/lib/institution/`，链上管理员读取归 `citizen/lib/administrators/`。

个人与机构多签创建交易消费 SDK 交付的已验证事件，按本次执行索引核对业务字段。
先解析 `System.ExtrinsicFailed` 的 runtime 模块错误，再确认对应成功事件。
因此余额不足、管理员主体残留、机构账户索引占用等链上拒绝会显示真实
`PersonalAdmins / PublicAdmins / PrivateAdmins / OrganizationManage` 错误，不再落到“未找到成功事件”的泛化提示。

##### 8.9 关键文件

| 文件 | 说明 |
| --- | --- |
| `8964/lib/feed/square_tab_page.dart` | 底部广场 Tab 当前入口页 |
| `citizen/lib/proposal/proposal_tab.dart` | 公民 Tab 内“提案”统一列表页：默认公共机构 + 当前钱包订阅公权机构 |
| `onchain/lib/onchain_payment_page.dart` | 交易 Tab 的付款面板、链状态、多签账户入口及导航选择端口 |
| `personal/lib/personal_account_list_page.dart` | 个人多签账户列表页 |
| `citizen/lib/proposal/institution_manage_detail_page.dart` | 个人/机构多签管理提案共用投票详情页；业务解码委托对应 manage 服务 |
| `personal/lib/personal_account_create_page.dart` | 个人多签创建表单 |
| `personal/lib/personal_account_close_page.dart` | 个人多签关闭表单 |
| `personal/lib/personal_admin_list_page.dart` | 个人多签管理员激活列表 |
| `personal/lib/personal_manage_account_info_page.dart` | 个人多签账户详情页 |
| `personal/lib/personal_manage_discovery_service.dart` | 个人多签反向索引发现服务 |
| `personal/lib/personal_manage_service.dart` | PersonalAdmins 个人多签链上交互服务 |
| `personal/lib/personal_manage_storage_codec.dart` | PersonalAdmins storage key 与 SCALE 解码 |
| `personal/lib/personal_proposal_history_service.dart` | 个人多签提案历史聚合与 Isar 持久化 |
| `storage/lib/user_isar.dart` | UserIsar 类型化保存多签本地状态、发现状态和最近链上同步时间 |
| `CitizenSdk.getStorageBatch` | 在同一已验证 finalized block 批量读取 storage |
| `organization-manage/src/lib.rs` | CID 注册机构多签登记、创建、关闭业务逻辑 |
| `personal-admins/src/lib.rs` | 个人多签创建、关闭、管理员更换业务逻辑 |
| `multisig-transfer/src/lib.rs` | 机构账户转账复用现有提案/投票/执行流程 |
| `votingengine/internal-vote/src/lib.rs` | 投票引擎（支持个人多签码 PMUL（`is_personal_code`）/ 机构账户码（`is_institution_code`）动态主体） |
| `votingengine/src/traits.rs` | `InternalVoteEngine` 语义化接口 |
| `runtime/src/configs.rs` | `RuntimeInternalAdminProvider`（个人多签快照、机构人员名册边界）+ `RuntimeInstitutionRoleProvider`（机构岗位有效任职快照） |

#### 9. 源码对齐基线

- `citizen/lib/institution/institution_info.dart + citizen/lib/institution/governance_registry.dart`
- `citizen/lib/administrators/institution_admin_service.dart`
- `citizen/lib/institution/institution_detail_page.dart`
- `citizen/lib/proposal/proposal_entry_page.dart`
- `citizen/lib/institution/institution_admin_list_page.dart`
- `citizen/lib/proposal/institution_manage_detail_page.dart`
- `onchain/lib/onchain_payment_page.dart`
- `personal/lib/personal_account_list_page.dart`
- `personal/lib/personal_account_create_page.dart`
- `personal/lib/personal_account_close_page.dart`
- `personal/lib/personal_admin_list_page.dart`
- `personal/lib/personal_manage_account_info_page.dart`
- `personal/lib/personal_manage_discovery_service.dart`
- `personal/lib/personal_manage_service.dart`
- `personal/lib/personal_manage_storage_codec.dart`
- `personal/lib/personal_proposal_history_service.dart`
- `CitizenSdk` 公开类型化读取合同
- `citizenchain/runtime/transaction/multisig-transfer/src/lib.rs`
- `citizenchain/runtime/private/organization-manage/src/lib.rs`
- `citizenchain/runtime/admins/personal-admins/src/lib.rs`
- `citizenchain/runtime/votingengine/src/lib.rs`
- `citizenchain/runtime/votingengine/src/internal_vote.rs`
- `citizenchain/runtime/votingengine/src/joint_vote.rs`
- `citizenchain/runtime/votingengine/joint-vote/src/jointreferendum.rs`
- `citizenchain/runtime/votingengine/src/cleanup.rs`
- `citizenchain/runtime/votingengine/src/limit.rs`
- `citizenchain/runtime/issuance/resolution-issuance/src/lib.rs`
- `citizenchain/runtime/governance/runtime-upgrade/src/lib.rs`
- `citizenchain/runtime/admins/public-admins/src/lib.rs`
- `citizenchain/runtime/admins/private-admins/src/lib.rs`
- `citizenchain/runtime/governance/resolution-destro/src/lib.rs`
- `citizenchain/runtime/governance/grandpakey-change/src/lib.rs`
- `citizenchain/runtime/transaction/offchain-transaction/src/lib.rs`
- `citizenchain/runtime/src/configs/mod.rs`
- `primitives/src/count_const.rs`

#### 1. 模块定位

`citizenapp/personal/lib/` 是 citizenapp 端个人多签主业务目录，对齐 runtime `citizenchain/runtime/admins/personal-admins/`。

本目录只处理个人多签，不承载机构多签、机构 CID 账户、多签转账业务。

##### 负责

- 个人多签创建页面：`personal_account_create_page.dart`
- 个人多签关闭页面：`personal_account_close_page.dart`
- 个人多签列表展示：`personal_account_list_page.dart`
- 个人多签账户详情页：`personal_manage_account_info_page.dart`
- 个人多签反向索引发现服务：`personal_manage_discovery_service.dart`
- 个人多签管理员激活列表：`personal_admin_list_page.dart`
- 待激活创建提案反查：`personal_pending_create_lookup.dart`
- 个人提案历史聚合与 Isar 持久化：`personal_proposal_history_service.dart`
- 详情页提案列表组件：`personal_proposal_list_section.dart`
- `PersonalAdmins` call data、ProposalData 解码和链上查询：`personal_manage_service.dart`
- `PersonalAdmins` storage key 与 SCALE 解码：`personal_manage_storage_codec.dart`
- `PersonalAdmins` 提案详情模型：`personal_manage_models.dart`

##### 不负责

- 机构身份/账户查询(只读)由 `citizenapp/citizen/lib/institution/` 处理;机构创建/关闭已收归 onchina 塔塔控制台+冷钱包。
- 多签转账:唯一实现目录 `citizenapp/multisig/lib/`。
- Isar schema 定义：仍在 `citizenapp/storage/lib/`，本模块只使用既有实体。
- Isar 读写队列：由 `citizenapp/storage/lib/user_isar.dart` 的 UserIsar 统一提供，
  本模块不得直接打开 DB 实例。
- 通用投票、签名、RPC：仍使用 `citizen/lib/proposal/`、`scanner/lib/` 与 CitizenSDK 公开接口等共用能力。
- 个人/机构多签管理提案投票详情页由 `multisig` 包的提案聚合和各管理模块解码服务共同支撑；本模块只提供 `PersonalAdmins` 解码服务。

#### 3. 链上契约

个人多签交易载荷：

- `PersonalManage::propose_create`：pallet `7`，call `0`，字段顺序固定为
  `account_name / admins / regular_threshold / amount`。
- `PersonalManage::propose_close`：pallet `7`，call `1`。
- call `2` 永久留洞；拒绝、超时与执行失败清理由链上投票引擎自动完成，CitizenApp
  不构造人工清理交易。
- `PersonalAdmins::propose_admin_set_change`：pallet `29`，call `0`，字段顺序固定为
  `institution_code / account_id / admins / new_threshold`，`institution_code` 必须为 `PMUL`。
- 上述两个 call 中 `admins` 每项的 SCALE 顺序统一为
  `account_id / family_name / given_name`；账户是唯一授权、去重和钱包匹配字段，姓、名不参与授权。
- `regular_threshold` 为用户输入的普通提案阈值，App 侧校验范围为
  `floor(admins_len / 2) + 1 ..= admins_len`；注册提案通过阈值固定为全员同意。

PersonalAdmins ProposalData：

- `MODULE_TAG = b"per-mgmt"`。
- `ACTION_CREATE = 0`：`account + proposer + amount + fee`。
- `ACTION_CLOSE = 1`：`account + beneficiary + proposer`。

PersonalAdmins storage：

- `PersonalManage::PersonalAccounts` 保存 `creator / account_name / created_at / status`。
- 管理员真源是 `PersonalAdmins::AdminAccounts`，AdminAccountKind 使用 `PersonalMultisig`。
- 普通业务动态阈值真源是 `InternalVote.ActivePersonalThresholds[personal_account]`；创建/注销生命周期阈值由投票引擎按提案管理员快照写成全员同意。
- 详情页和管理员列表不得从 `PersonalAdmins::AdminAccounts` 后续字段解阈值；该 storage
  的管理员列表后面是 `creator / created_at / updated_at / status`，错位读取会出现
  类似 `1478971204/2` 的异常阈值显示。
- CitizenApp 本地详情快照仅保存三字段管理员 JSON 对象；旧字符串数组、空姓名、重复账户或泛化字段不兼容读取。

个人多签创建提交规则：

- 扫码只从用户码取得管理员的 `ss58_address` 并派生 `account_id`；姓、名在 CitizenApp 分开输入，留空时分别落为“管理”、“员”，不拆分联系人备注或其它合并姓名。
- 创建和管理员更换都只调用一次最终交易签名；姓、名编辑、周期确认或设备变更不引入额外签名。
- 创建前必须校验发起钱包 free 余额覆盖 `amount + fee + ED`。
- `fee` 使用链上 `onchain_transaction::calculate_onchain_fee` 同口径：
  `max(amount * 0.1%, 0.10 元)`；`ED` 当前为 `1.11 元`。
- `personal_manage_service.dart` 必须等待 CitizenSDK `finalizedSuccess`，并从 SDK 返回的准确最终块
  `System.Events` 确认 `PersonalAdmins.PersonalAccountProposed(event_index=0)`；tx_hash 本身
  不代表创建提案成功。
- 如果 SDK 返回 `finalizedFailed`，必须优先显示真实模块错误，例如
  `PersonalAdmins.InsufficientAmount` 或 `PublicAdmins.InstitutionAlreadyExists`，
  不能只提示“未找到 PersonalAccountProposed 事件”。
- 本地 `account` 和 `action` 只能在确认事件后写入，
  `proposal_id` 必须来自链上事件，不允许预测 `VotingEngine.NextProposalId`。

#### 3.1 citizenapp 本地注销显示规则

- 个人多签列表入口在交易 Tab 的“多签账户”，页面标题显示“多签账户”。
- 个人多签列表只展示 `account`，不读取、发现、同步或展示任何机构账户。
- 已注销个人多签账户继续留在账户列表，状态显示“已注销”，不显示金额。
- 详情页链上明确查不到 `PersonalAdmins::PersonalAccounts` 时，写入本机
  `PersonalAccountLocalState.statusClosed`，页面状态显示“已注销”。
- 已注销详情页不显示余额，不再从创建提案快照显示旧入金金额，也不显示“未找到”。
- Active 详情页右上角三点菜单显示纯文本“关闭个人多签”，不显示删除图标，避免把关闭提案误解为本机删除。
- 已注销详情页右上角三点菜单显示按钮“删除”；确认后删除
  `account`、该账户全部 `action` 和本地状态键。
- 链路异常不把网络失败写成已注销；详情页首屏不得因链上异常显示全屏加载失败。
- 链上注销成功后 runtime 会清空多签账户余额并删除个人多签当前状态；同一 `account_id` +
  同一账户名再次创建仍派生同一地址，但会作为全新的当前账户注册。
- 链上 votingengine 90 天终态提案清理保持不变，citizenapp 不修改链上清理周期。
- 发起创建/注销提案后，runtime 投票引擎会在同一事务自动给发起人记一票赞成；citizenapp 本地提案记录初始 `yes_count = 1`，不再显示发起人还需要第二次投票。
- 若旧版本已写入“本地 create 提案仍为 voting，但链上 Proposals[id] 不存在”的记录，
  该记录视为未上链幽灵数据，列表同步时删除本地多签和提案快照，不显示为“已注销/未知提案”。
- 个人多签历史、待激活创建提案反查、反向索引发现和本地状态更新全部通过
  `UserIsar.instance.read()` / `UserIsar.instance.writeTxn()` 进入统一队列，避免与钱包创建/导入、余额刷新和钱包交易流水同步抢 MDBX 锁。
- 统一多签列表首屏只读本机 `account` 和 `PersonalAccountLocalState`，
  不等待 `PersonalAdmins::PersonalAccounts`、`PersonalAdmins::AdminAccounts` 或 discovery 链上读取。
- `group` 只保存个人多签状态、管理员、阈值和详情同步时间；余额只由 SDK 快照管理，列表状态更新不能另存余额。
- 进入详情先读本地详情及 SDK 余额，不为余额重查管理员/阈值。主动刷新通过 SDK 更新 finalized 快照，失败保留最近成功值。
- 详情页不显示“同步中”类 UI；TTL 到期时静默刷新，用户下拉刷新、转账/投票/关闭
  返回时才强制刷新当前个人多签。链上失败保留本机快照，不覆盖为已注销。
- Active 个人多签 60 分钟内不自动重复查链；Pending / Closed 个人多签
  10 分钟内不自动重复查链；用户下拉刷新才强制忽略 TTL。
- 自动 discovery 只在首次进入“多签账户”列表或本机钱包 AccountId 集合变化时触发；
  下拉刷新才强制执行全量 discovery。
- discovery 只扫描 `PersonalAdmins.AdminAccounts`，并按 `kind=Personal`、`institution_code=PMUL`、本机管理员钱包过滤。
- 个人多签列表状态刷新使用 `PersonalManageService.fetchPersonalAccountsBatch()`：
  先批量读取 `PersonalAccounts` 与 `PersonalAdmins::AdminAccounts`，再按解码出的
  `personal_account` 批量读取 `InternalVote.ActivePersonalThresholds`。Pending 阈值按
  `proposal_id` 存于 `PendingPersonalThresholds`，不得伪造账户 key 或作为活动阈值回落源。
- 列表页从个人多签详情、创建、关闭、投票返回时只刷新相关账户或本地记录，不重新扫描全部多签。

#### 3.2 创建 / 注销阈值 UI

- 新增个人多签页面提供“普通提案阈值”输入框。
- “阈值规则”右侧浅色文案显示“注册须全员同意”。
- 注销个人多签页面“阈值规则”右侧浅色文案显示“注销须全员同意”。
- 扫码添加管理员使用 `assets/icons/scan-line.svg`，不使用二维码图标；入口固定显示在
  “管理员列表（x/64）”标题行最右侧，不再使用占据列表纵向空间的独立文字按钮。
- 注销个人多签页“受益人地址”的扫码按钮在**输入框内**（`suffixIcon`），复用全仓唯一的
  `scanner/lib/address_scan_button.dart`；原先框外独立 `IconButton` 的写法已删除。
  该页不得再就地写 `QrScanPage(mode: QrScanMode.transfer)`。
- 账户列表右上角加号直接进入 `personal_account_create_page.dart`，不再弹出个人/机构选择。

#### 4. 与 citizen/institution 目录关系

`citizenapp/citizen/lib/institution/` 不承载 `PersonalAdmins` 主业务。它保留:

- 机构管理 InstitutionChainService(只读)与机构 storage codec(按机构码路由 PublicManage/PrivateManage)。
- `AdminInstitutionCodec` 等跨个人/机构都需要读取的底层 Subject 解码能力。

个人账户列表、详情、反向索引发现、创建、关闭、管理员激活和提案历史均不得回流到 `citizen/institution`。
个人多签列表入口只允许通过交易 Tab 的 `personal/lib/personal_account_list_page.dart` 呈现。
`AdminInstitutionCodec` 只属于底层 Subject 解码能力，不承载 `PersonalAdmins` 主业务。

#### 5. 测试

个人多签测试集中在：

- `citizenapp/personal/test/personal_manage_service_test.dart`
- `citizenapp/personal/test/personal_manage_storage_codec_test.dart`
- `citizenapp/personal/test/personal_account_create_page_test.dart`
- `citizenapp/personal/test/personal_account_entry_test.dart`
- `citizenapp/personal/test/personal_pending_create_lookup_test.dart`
- `citizenapp/personal/test/personal_proposal_history_service_test.dart`

个人账户业务测试归本仓既有Flutter用例，现行自动化统一执行，开发机不通过编译脚本启动测试。

管理员专项测试覆盖 storage 和 call 的逐字节解码、旧布局拒绝、重复账户拒绝和无岗位管理员保留。

### CitizenApp QR 技术说明

账户标识、通用QR_V1编码、解析、会话和签名合同以本产品锁定CitizenSDK的公开接口及其根技术文档为准。CitizenApp只调用CitizenQr、CitizenQrContent、CitizenSigning及CitizenSdk，不在本文登记短键、码型、签名字节算法或第二份协议。

#### 产品使用边界

- 签名请求及响应只通过SDK公开会话生成、验真和消费；CitizenApp提供业务payload与审阅内容，不解析通用信封或自行验签。链交易使用CitizenSdk，不通过通用payload签名绕开交易流程。
- 用户码只为链上CID与当前账户双向绑定成立的身份生成；“我的”和用户主页共用用户码页面。生成用户码须核验绑定；通讯录导入只读取码内 CID 并在本机按 CID 去重。
- 账户码由钱包账户详情与聊天收付款入口调用SDK生成；未注册账户及其他钱包账户可使用账户码。当前收款码生成仍属待实现，不以账户码代替已实现收款业务。
- 通讯录用途只接纳用户码；转账及分派用途按SDK公开用途允许关系消费用户码、账户码和收款码。用途不符、SDK拒绝或裸SS58输入不得触发第二解析入口。
- 公开昵称仅由产品资料接口取得。账户地址仅用于页面展示和边界输入输出，账户授权与关系仍使用SDK给出的规范账户标识。
- CitizenApp不处理管理员扫码登录；该业务入口归OnChina与CitizenWallet。

二维码展示使用本产品AppQrImage消费SDK图像能力并完整绘制，禁止中心挖空或覆盖控件；用户码保存入口位于AppBar。账户码复用wallet/lib/account/wallet_qr_dialog.dart弹窗，顺序为名称、二维码、居中地址、等宽关闭与复制按钮。页面布局不因协议归位改变。

#### 实际公开接口与产品入口

通用接口由 CitizenSDK 的 lib/api/citizen_qr.dart、lib/api/citizen_sdk.dart、lib/api/citizen_transactions.dart 和 lib/account_codec.dart 承载。账户文本和 SS58 调用 SDK 公开接口，钱包与二维码共用同一 Core 编解码。账户字段和区块哈希、交易哈希、文件摘要各按其字段语义校验。账户码调用 encodeAccountId，用户码通过 CitizenQrContent.userContact 与 encodeDocument 生成。相机和相册直接交付 CitizenQrScanResult，原始文本入口单次调用 parseForPurpose。

scanner/lib/scanner_view.dart 把 SDK 结果原样交给扫码页面。冷钱包表单从结果读取规范 AccountId，个人账户从用户码读取管理员账户，签名分派将同一 CitizenQrDocument 交给业务服务。scanner/lib/qr_sign_session_page.dart 承载请求展示和响应回扫。

个人多签创建、管理员更换及机构链交易继续由App构造所属业务review_payload，管理员字段顺序固定为account_id + family_name + given_name；姓名仅用于确认展示，不构成授权。同一次业务操作只发起一个请求并消费一个响应。

#### 集成验收职责

App 回归覆盖 SDK 结果原样转发、扫码入口的码型分派和拒绝、冷钱包填表和确认导入、管理员用户码及签名响应预检。SDK 回归覆盖通用字段往返、会话期限、验签与单次消费。宿主回归与设备相机及相册验收分别记录。

## CitizenSDK 链、交易与历史

CitizenApp 只打开一个 CitizenSdkModules.full session。安全擦除门禁通过后只启动一次 SDK 轻节点，关闭时先停止交易业务投影，再依次执行 CitizenSdk.stop 和 close。

- 交易 Tab 顶部 Widget 树、位置、尺寸、颜色、文案和呼吸灯不变，只读 CitizenChainSyncStatus.isUsable 与 finalized.number。
- 业务模块直接调用 CitizenSdk 的 block、runtime context、storage、keys page、Runtime API、System.Events、nonce 和手续费能力；余额统一经同一SDK会话读取。
- 业务模块自己保留 storage key、RuntimeCall 编码、SCALE 解码和业务错误，禁止把广场、投票、立法、提案或治理塞入 SDK。
- App 确认表单冻结账户、备注及整数分。签名、提交、外部会话清理和终态沿用 SDK。转账页用准备标识订阅 SDK 已签记录，将表单字段接入同一流水状态投影。
- 转账失败按已进入的准备、执行、冷签消费步骤显示一条中文原因。SDK `code/stage/method` 保持原样供内部定位，诊断仅记录固定步骤和枚举；不得把准备阶段写成已发送或已提交，也不得在弹窗或日志拼接原始异常描述、账户及交易载荷。
- 非有限金额及换算为分时溢出的金额在表单与服务入口均明确拒绝，不进入手续费计算或 SDK 准备。
- SDK history 保存 execution、hash、区块和通用状态。CitizenApp 的 entry 补充目的账户、申请金额、备注和已验证业务事件。以 execution_id、call_hash、tx_hash 关联。报价仅在确认框展示，未关联已验证事件时余额变化待核实。既有无事件锚的本机费用按预估展示。
- 被动收入由唯一 WalletTransactionHistoryService 调用 SDK 已验证 finalized 历史读取能力逐块恢复；不建立第二节点或 JSON-RPC 连接。启动、返回前台、finalized 通知与两处页面主动刷新共用在途任务，离线不阻塞页面读取本地记录。
- 同一 entry 表中的既有记录按 account_id 隔离展示，查询、分页、单条读取和计数不得因 source 或缺少 SDK execution 字段隐藏收付款记录。SDK 状态更新仍要求 local_submit 来源以及非空 execution_id、call_hash 同时匹配；恢复可见性不授予旧记录新的状态更新权限。
- 历史范围为钱包导入本机之后。没有持久进度时，以 SDK 账户 created_at 与已验证区块 Timestamp.Now 二分定位首个不早于导入时间的块；边界定位只读早期块时间，不投影导入前交易。该方案重建时间边界，不宣称恢复已删除的旧游标；本机与链上时钟偏差可能影响边界附近记录。时间、证明或区块读取失败必须重试，不以创世或当前高度静默替代起点。
- cursor 绑定 account_id、created_at 和 genesis_hash，保存 start_block 与 cursor_block；初值为起点减一。每轮最多处理32块，每块业务记录与参与账户的进度同事务提交；中途失败保留最后成功块，下一轮从失败块继续。后台、停止、钱包变更或擦除使旧读取代次失效，关闭等待已登记消费者退出。
- 钱包流水使用 SDK 的准确 finalized 事件、交易哈希及实扣。SDK 按本金事件索引交付转账与备注，按付款账户交付每条 FeePaid。App 按账户及交易将实扣附到第一条关联本金，额外独立收费保留事件身份。已验证失败执行可以有费用而没有本金入账。
- 业务事件按账户、准确区块哈希和事件索引幂等；与本机普通转账仅通过完整 SCALE extrinsic 的 Blake2-256 哈希及业务内容准确关联，同时保留 SDK 独占的交易终态。相同账户、对方和金额不能单独作为合并依据；同一 extrinsic 的多个独立事件仍分别保留。
- 钱包详情最近记录与交易记录列表共用 LocalTxStore 和 TxAutoRefreshMixin；写库通知自动重载，空列表也允许下拉刷新。仅最新块影响账户时通知 wallet 的余额唯一入口，历史补齐不按每个旧块重复查询当前余额。
- 流水以 BigInt 整数分显示千分位和两位小数。详情区分等待打包、最佳链已打包、最终链确认和执行失败。ED 单独作为账户最低余额。
- SDK 负责严格事件编解码及金标。App 定向用例使用 SDK 公开事件结构覆盖被动到账、实扣、失败进度、恢复和幂等。

## CitizenApp 业务签名边界

CitizenApp 只构造业务 payload、domain、challenge 和审阅内容。热签、冷签分流、sr25519 和通用 QR_V1 全部调用 CitizenSdk 的签名与二维码方法。链交易禁止调用通用 payload 签名绕开 CitizenSdk。

`user/lib/identity/citizen_identity_sign_service.dart`、`citizen_occupy_sign_service.dart` 与 `square_action_sign_service.dart` 分别处理身份确认、注册局占号与换绑、广场账户动作；二维码封装与校验消费 CitizenSDK 的公开接口。宿主不恢复独立 QR codec，不实现链交易签名或保存钱包秘密。

#### 模块边界

`citizenapp/multisig/lib/` 是 CitizenApp 端多签转账唯一实现目录。

- `multisig_transfer_page.dart`：创建多签转账提案。
- `multisig_transfer_detail_page.dart`：展示多签转账详情、投票状态和投票操作。
- `multisig_transfer_service.dart`：构造 `MultisigTransfer::propose_*` call data，读取转账提案详情。
- `multisig_transfer_models.dart`：多签转账、 安全基金转账、手续费划转提案模型。
- `multisig_transfer_balance_guard.dart`：机构提案检查 actor CID 费用账户，个人提案和实际投票检查签名者钱包。
- `multisig_transfer_entry.dart`：多签转账入口卡片和页面跳转。
- `multisig_transfer_proposal_adapter.dart`：给机构页、投票页和账户页使用的列表展示、详情跳转、缓存清理和数据源适配。

提案通用元数据、上下文、缓存、前端提案能力注册表和内部投票共享能力放在 `citizenapp/citizen/lib/proposal/`。多签转账业务详情通过 `ProposalWithDetail.businessDetails` 的不透明键值挂载，键名由本模块定义。

`citizenapp/citizen/lib/institution/`(机构管理只读)不实现多签转账按钮和跳转；多签账户详情页只允许挂载 `multisig-transfer` 提供的 `MultisigTransferEntryCard`，入口自身逻辑在 `multisig-transfer` 内部。

治理入口与内部、立法投票适配文件分别位于 `citizenapp/citizen/lib/governance/`、`citizenapp/citizen/lib/proposal/` 和 `citizenapp/citizen/lib/legislation/`；这些原调用方仍只允许调用 `MultisigTransferProposalAdapter` / `MultisigTransferProposalFeed`，不得直接判断 `TransferProposalInfo`、`SafetyFundProposalInfo`、`SweepProposalInfo`，也不得直接打开 `MultisigTransferDetailPage`。

#### 费用规则

- 发起机构多签转账提案：actor CID 的费用账户支付 0.1 元，管理员钱包只签名。
- 发起个人多签转账提案：签名者支付 0.1 元。
- 多签转账实际投票：投票管理员钱包支付 1 元。
- 具体资金账户：执行阶段检查转账本金；机构实际执行手续费改由费用账户支付的规则在统一执行期费用步骤落实。

页面不得把机构提案费用显示为管理员付款：机构费用账户不足提示“机构费用账户余额不足”；个人提案或实际投票签名者不足才提示“管理员钱包余额不足”。两类普通支出预检都包含“支付后保留 ED”。

#### 岗位字段与 SCALE 契约

- 机构普通转账、安全基金转账和费用账户划转页面必须显示独立“提案发起岗位码”输入，UTF-8 长度限制 1..64 字节；岗位码不能从当前管理员身份推断。
- NRC/PRC 固定委员业务可预填 `COMMITTEE_MEMBER`，PRB 费用划转可预填 `DIRECTOR`；普通注册机构没有固定默认值，必须由用户明确输入本机构已授权岗位码。
- 个人多签不显示岗位字段，并严格编码 `actor_cid_number=None + proposer_role_code=None`；机构普通转账严格编码两个 `Some`，不保留单边 Some 或旧载荷兼容。
- 业务模块固定使用内部投票引擎，页面和签名载荷均不得传入“选择投票引擎”参数。

#### 投票进度

详情页优先读取：

- 机构提案：按 VotePlan 中每个完整 `RoleSubject` 读取 `VotingEngine::VoterSnapshot`
- 个人多签提案：`VotingEngine::AdminSnapshot[(proposal_id, PersonalAccount)]`
- `InternalVote::InternalThresholdSnapshot`
- `InternalVote::InternalTallies`
- `InternalVote::InternalVotesByTicket`

进度条使用提案创建时的阈值快照，避免管理员变更后旧提案进度显示错误。

#### 交易状态

发起多签转账提案的成功判定：

- CitizenSDK 返回的 tx_hash 不代表提案创建成功。
- CitizenApp 必须等待 SDK finalized execution 成功，并读取 SDK 返回的准确最终块 `System.Events`。
- 只有同一区块存在匹配本次发起人、机构主账户、收款人和金额的 `MultisigTransfer::TransferProposed` 事件，才允许提示“提案创建成功”并写入本地个人多签提案历史。
- 如果交易已入块但没有 `TransferProposed`，视为提案创建失败，不写本地历史。

三类提案统一标准（2026-06-09 静默失败整改）：

- 安全基金转账（`propose_safety_fund_transfer`）与手续费划转（`propose_sweep_to_main`）与普通转账
  提案完全同标准：CitizenSDK finalized execution 成功 → 读同一最终块 `System.Events` 核对
  `SafetyFundTransferProposed` / `SweepToMainProposed` 事件 → 返回事件中的 `proposal_id`。
- 事件核对共用 `_confirmProposalEvent` + `_findProposalIdInEvents` 单一扫描骨架，事件字段解码各自实现（字段顺序必须与 runtime Event enum 严格一致；事件变体序号按声明顺序：TransferProposed=0、SafetyFundTransferProposed=3、SweepToMainProposed=6）。
- 提案类业务成功必须拿到 proposal_id，交易提交统一由 CitizenSDK
  `prepareTransaction → executePreparedTransaction` 完成；CitizenApp 只在 SDK 给出 finalized
  execution 后读取同一最终块的业务事件或 storage。普通钱包余额转账也走同一 SDK 交易合同，
  不存在 submit-only、App 后台 watch 或 App 自建 extrinsic builder。
- 错误处理铁律：提交/解码/查询失败一律留痕（debugPrint）或上抛，禁止裸 `catch (_) {}` 吞错；链上余额刷新失败而展示缓存时，UI 必须标注“可能已过期”。

投票提交和确认：

- 投票展示状态读取 `InternalVote::InternalVotesByTicket(proposal_id, ticket)`；机构ticket包含CID、岗位码和canonical票据账户，不用当前签名人推定历史票据主键。
- `InternalVoteService.submit()` 等待CitizenSDK finalized execution成功，按执行块metadata、同一extrinsicIndex及完整业务字段确认唯一InternalVoteCast事件，并核对提案所属机构。
- CitizenApp 不读取、不缓存、不预占、不回滚交易 nonce；CitizenSDK 在准备交易时读取并绑定。
- 新成功流程不再写本地 pending；确认成功后只清理旧残留 pending，并立即把该管理员显示为已投票。
- SDK `poolRejected/finalizedFailed` 直接返回失败；SDK 未给出终态时 App 不猜测失败，也不维护账户级
  pending 状态机。
- SDK `finalizedSuccess` 后仍须匹配本次投票事件，不能用同块其他交易或仅有交易哈希代替确认。
- 服务层完成 SDK finalized execution 和 runtime 投票记录确认后，按钮 `submitting` 结束；详情页
  `_load(showSpinner: false)` 只负责后台同步最新展示状态。

### 链下扫码支付与清算确认

链下扫码支付、清算行目录、绑定、充值、提现和所属RPC统一归`offchain/lib/`，测试归`offchain/test/`。交易Tab只负责编排入口，钱包页只挂载所属功能页面，不维护第二份清算协议、存储或金标。

设置页用同一个规范 AccountId 读取 finalized `OffchainTransaction.UserBank`、签名并定位本地快照。进入确认页前重新读取链上绑定。无链上绑定时调用 `bind_clearing_bank`，目标与当前机构不同时调用 `switch_bank`。两条调用均向 CitizenSDK 交付目标机构 CID 的 UTF-8 字节，由同块 Runtime metadata 编码。最终成功后才写入本地展示快照。写入失败保留交易确认和哈希，提示缓存未更新，并回到设置页重读链上状态。清除快照不影响链上绑定。

零钱包从同一 finalized 块读取 `UserBank` 及对应的 `ClearingBankNodes`。仅链上无绑定才提示未绑定，读失败或节点声明不可用时停止操作。快照仅补充匹配 CID 的展示名称，节点地址始终来自链。充值、提现在签名前再次核对绑定和节点；目标变更时更新展示并要求重新确认。

扫码流程从商户码取得收款账户及收款方清算行CID，精确读取finalized `ClearingBankNodes`取得WSS端点。付款页重新确认机构声明；付款方绑定清算行由`offchain_queryUserBank`返回CID，手续费使用收款方清算行费率。CID不是机构主账户SS58或固定32字节账户。

`NodePaymentIntent`按链端`runtime/transaction/offchain/src/batch_item.rs`字段顺序编码：tx_id(32)、payer(32)、payer_bank_cid(Vec<u8>)、recipient(32)、recipient_bank_cid(Vec<u8>)、amount(u128 LE)、fee(u128 LE)、nonce(u64 LE)、expires_at(u32 LE)。两份CID均为1..32个UTF-8字节，向量采用最短Compact长度前缀，整体变长，不存在固定204字节断言。金额及手续费以分为单位；expires_at只按块高判断，当前取最新块高加100，不换算成确定墙钟有效期。

付款签名原文经`CitizenSdk.encodePayload`及`kOpSignL3Pay`构造，由SDK公开签名入口完成。当前只支持本机热账户；32字节摘要不足以让独立冷钱包审阅完整付款事实，不能据此开放冷签。跨语言固定金标唯一保存在各自所有者测试中：本端为`offchain/test/payment_intent_golden_test.dart`，链端为`runtime/transaction/offchain/tests/cases.rs`。技术文档不另存摘要常量或第二份金标。

付款页状态为loading、ready、submitting、unverified、error。发送前准备或签名失败进入error；开始调用`offchain_submitPayment`后，不论响应丢失、远端失败、回执损坏或收到格式正确的回执，均不得推定付款未发生而自动重发。本笔本地tx_id保持不变，RPC回执必须匹配该标识；目前统一进入“付款结果未核实，请勿重复付款”，保留该笔标识供核对。

完整ACK签名原文由链端`node/offchain/src/rpc.rs`定义：`OP_SIGN_L2_ACK`覆盖SCALE(bank_cid)、SCALE(intent)、payer_sig及accepted_at LE。当前公开清算行节点声明没有可信ACK签名身份，登记审计账户不能替代签名授权，因此App尚未宣称ACK已验签或支付已受理。后续须先由所属产品明确公开签名身份与权限合同，再复用SDK公开签名原语验签；不得在App复制密码学实现。

清算 ACK 的签名账户、岗位、授权范围、核验区块及换绑撤权由链端合同定义。App 保留原交易绑定，无法核实的结果保持待核实。

付款受理、最终清算上链和收款余额分别核验。清算支付不写入链上转账 LocalTxStore 或 SDK execution history。

交易与充值历史展示继续读取统一用户库中的本机记录，按真实账户归属查询；CID切换导致当前绑定账户变化时，历史页清空旧窗口、切换监听并独立读取新账户。旧首页、分页、窗口刷新、主动同步及去抖回调的结果不能混入新账户。普通打开、浏览和详情不主动建立网络请求；主动刷新仍调用既有交易同步，交易提交与必要验款沿原流程执行。

同一账户串行读取本机窗口，读取期间的多次库变更合并为一次后续刷新；充值完整变更回执直接应用到列表，并叠加到在途查询结果，不为同一回执重新读取订单。

## onchain / 链上交易

链上支付页的位置、表单、文案、确认弹窗、余额卡和交易列表属于 CitizenApp，布局保持不变。

- OnchainPaymentService 用同一份 Runtime metadata 读取 OnchainTransaction.MaxTransferRemarkLen，并委托 SDK 编码 transfer_with_remark。准备回执的 Runtime 版本有变时释放句柄，由页面重新预检。EVM 地址解析和链上费用由 SDK 提供。
- OnchainPaymentService 验证 App 表单并直接调用 CitizenSdk.prepareTransaction。
- 页面直接执行 executePreparedTransaction；冷账户展示 SDK 生成的 QR_V1 并把扫描原文交回 consumePreparedTransactionQrResponse。
- SDK 返回 finalizedSuccess、finalizedFailed 或 poolRejected 后，App 才投影展示状态。不以 tx_hash、超时、nonce 或页面生命周期猜测成败。
- 业务历史保存金额、备注、对方账户和收发方向；SDK execution history 是交易状态真源。

#### 1. 模块目标

`citizenapp_user.isar` 是 CitizenApp 统一用户业务库，同时承载公共目录及钱包业务缓存。
`lib/user.dart` 负责“我的 / 用户”页面，`user/lib/contacts/` 负责通讯录；“我的”只是 UI 入口，
不是数据库。当前覆盖：

- 用户背景图上传与更换
- 用户头像上传与更换
- 按 `cid_number` 读取、缓存和编辑公开昵称
- 用户码生成与展示
- 通讯录扫码导入、联系人与私人备注逐条云端备份和跨设备读取
- 电子护照入口展示

#### 2. 文件结构

- `storage/lib/user_isar.dart`
  - `UserIsar(citizenapp_user)` 唯一 schema 清单、独立操作队列与关闭终态
- `storage/lib/user_isar.g.dart`
  - User 域 Isar 生成物

- `lib/user.dart`
  - “我的”页 `MyTab`
- `user/lib/contacts/contact_service.dart`
  - 联系人与备注、按属主 CID 隔离的 Isar 缓存及普通云端记录接口
- `user/lib/contacts/contact_book_page.dart`
  - 通讯录页面、搜索、同步状态和单条联系人卡片

相关协作模块：

- `wallet/lib/account/wallet_page.dart`
  - 管理热钱包档案和当前默认账户
  - `walletName` 只作为本机钱包标签，不读写公开昵称
- `user/lib/identity/`
  - 电子护照本地展示及主动 finalized 身份验真服务
  - `identity_badge_snapshot_store.dart` 是身份卡片和徽章的唯一持久展示存储；账户定位当前完整快照，CID定位徽章
  - “我的”页面只提供入口和头像认证角标，不承载电子护照设置流程

##### 3.1 CID 公开资料与媒体持久化

公开资料唯一模型是按永久 `cid_number` 寻址的 `CitizenProfile`：昵称、签名、
`avatar_key`、`banner_key` 和 `profile_at` 由公开资料接口返回；
`profile` 按CID保存完整资料JSON；`media`在同一
UserIsar中独立保存图片实际字节、用途、对象位置、资料版本和完整性摘要；类型和长度按字节读取，不另存副本。图片的绝对路径不入库，
临时展示文件由数据库重建；身份仍复用`identity`及唯一展示存储。

展示规则：

- 当前用户身份唯一取自链上闭环解析出的 `cid_number`；当前绑定 `account_id` 只负责
  签名、鉴权和付款。通讯录只存 `account_id`，`ss58Address` 在使用时派生；
  用户主页、通讯录卡片和通讯录搜索暂不展示或检索账户地址；账户地址只在用户码、钱包、
  转账及绑定核验等明确账户边界使用。
- 公开昵称唯一真源是按 `cid_number` 寻址的 `CitizenProfile.display_name`
  （接口字段 `display_name`）。
- `walletName` 是本机钱包标签，只在钱包列表、详情和账户选择场景展示，不能作为
  公开昵称、缓存或回退值。
- `display_name` 缺失时，由 `ProfilePresentation` 优先按 `cid_number` 稳定选择
  本地默认昵称；无 CID 的纯访客才按当前身份账户稳定兜底。禁止回退为完整或截断账户。

设计说明：

- 用户修改公开昵称只走 `PUT /api/user/profile`，成功后写
  `CitizenProfileCache`；不得调用 `CitizenSdkWallet.renameAccount`。
- 钱包账户改名只调用 `CitizenSdkWallet.renameAccount`；不得创建资料会话、请求
  Cloudflare 或触发广场身份刷新。
- “我的”、本人主页、本人帖子详情与资料编辑页的普通读取只查本地，不创建远端会话。主动刷新调用refreshProfile及本人帖子同步；保存、删除等写操作继续在操作时建立会话并执行必要验真。此边界不取消其他用户公开内容的访问请求。
- 公开头像和背景上传Cloudflare R2；PUT前由prepareUpdate将请求和本次选图字节存入edit，按CID唯一。成功响应经confirmUpdate保存后，finishUpdate在同一事务提交资料/图片并删除恢复行，随后广播CID revision。
  重启后confirmed只做本地收尾；pending先读远端并逐字段核对，已成功则本地收尾。远端内容不同必须由用户明确选择继续保存上次修改才再次PUT，失败保留请求及原件。
- 只有 `avatar_key` / `banner_key` 从未设置时，才从
  `assets/profiles/` 按永久 CID 稳定选择内置头像和背景。用户一旦设置，网络或本机
  文件暂不可用时只显示中性占位并保留上一张用户图，禁止退回内置随机图。

##### 3.1.1 资料图片保存、完整性及来源保全

- 头像上限512KiB，背景上限1536KiB，均可单条原子保存；识别PNG/JPEG/WebP文件头，
  完整字节复制后在事务外计算SHA-256。文件头检测只确定内容类型，不替代图片解码验收。
- 媒体按(cid_number, media_role)自然键定位，用途只接受avatar/banner。
  同一profile_at版本的object_key、body_hash与media_bytes必须一致，冲突拒绝；
  资料JSON不重复保存索引CID，较旧profile_at不能覆盖已保存的新资料。
- 完整资料图片对象键 `i/<CID>/<avatar|banner>/<SHA-256>` 由同一入口解析。
  用途决定读取大小上限，内容哈希与当前会话、地址、用途、资料版本共同区分解码缓存。
- UserIsar关闭relaxedDurability，数据库提交成功后才通知常驻页面重读。查询、写入与删除
  强制CID，哈希、网络、平台通道和文件I/O均在数据库回调之外。普通身份读取仍只供展示，
  使用现有IdentityBadgeSnapshotStore，不新增身份副本或将展示状态用作操作授权。
- 现有路径型图片组件使用可再生临时文件，文件不存在或损坏时从校验后的数据库字节原子重建。
  普通读取只消费当前数据库字节，不导入或删除旧文件，不增加旧结构桥接。
- refresh是明确的远端下载入口，仅接受HTTPS，拒绝重定向，流式限制长度；已有准确版本时
  复用数据库。失败保留已有图片，不将本地缺失表述为远端删除。页面端自动调用收拢尚待后续步骤。

##### 3.2 用户码

用户码生成、扫码准入与展示边界统一按本篇“CitizenApp QR 技术说明”执行；字段与编码引用CitizenSDK公开接口，不另建UserContactBody协议模型。

##### 3.3 通讯录 UserContact

联系人按属主CID和联系人CID定位，contact_remark和updated_at逐条备份到私有R2。联系人关系不保存钱包账户。公开昵称、头像、认证和会员状态使用已有公开资料缓存，不进入联系人备份。

##### 4.1 UserIsar 唯一结构

- 数据库名：`citizenapp_user`
- 生命周期：`active → closing → closed`
- 操作边界：独立打开任务、generation 和队列；同域回调重入立即失败
- 事务约束：回调内只做 UserIsar 查询/原子写，不等待钱包、密码学、网络、
  平台通道、文件或其它数据库

当前UserIsar保留27个集合。逐列清单与职责统一见本文“第一方存储与字段收敛”，这里不再维护第二份列定义；identity只保存账户/CID索引、完整身份data和updated_at，media使用自然归属及当前资料版本，edit使用state/request/response，notice保存通知状态、待提交已读意图及当前已获取列表和分页快照。

会员、创作者及管理员激活的App业务记录分别保存在统一UserIsar的member、creator和admin集合；链上授权真源仍由SDK读取和核验。

不建立通用 `UserKv`，不保存钱包排序/活动钱包、PIN、设备锁或明文密钥。

“我的 → 设置”在安全分组与关于分组之间同行展示“首页设置 / 广场|聊天 / Switch”。
右侧复用设备锁和应用锁相同的 Switch，开关自身尺寸不缩小；卡片与“我的”主页的“设置”
入口统一使用 `AppLayout.serviceEntryHeight`，不同屏幕倍率下保持相同行高。写入 UserIsar
成功后才更新显示，失败保留原值并
允许重试。该偏好只决定重新构造主界面时的初始 Tab；未触发主界面重建的普通
后台恢复保持用户离开前的页面。

##### 4.2 通讯录

本机contact是唯一联系人集合，按owner_cid与cid_number唯一定位，保存contact_remark、updated_at及仅本机的pending/change_version。新增和真实修改标记put；删除标记delete并立即隐藏，云端成功后物理删除。不保存永久删除历史；运行阶段和错误只在内存显示。

云端每个联系人一个私有R2对象。PUT /api/user/contacts/{cid}按CID逐条保存联系人备注，DELETE同路径空正文删除；GET /api/user/contacts按cursor分页读取全部。只有本机真实变化才自动发送；同一记录多设备修改由最后成功云写入决定。下拉先完成待发操作再读完整清单，新设备也沿用下拉同步。没有变化的联系人不上传，不逐人刷新名片或头像。

##### 4.3 电子护照

电子护照状态归属 `user/lib/identity/myid_service.dart`，用户模块不直接读写电子护照状态。
`MyIdState.status` 使用既有 `MyIdStatus` 枚举，仅表达页面展示状态；字段与值集由实际 `MyIdStatus` 定义。已知访客为 `null`，缺快照与读取失败按既有状态区分；页面状态不作为操作授权。
电子护照页始终展示“匿名访客”“公民 · 投票身份”“公民 · 竞选身份”三张卡。当前身份卡排在首位并唯一标记“当前身份”；只有当前投票或竞选身份卡展示真实值，非当前公民卡只展示字段名称，不展示占位值、示例值或当前用户数据。匿名访客卡固定显示“没有公民身份信息”。
仅主动刷新或实际身份授权时，由账户顺序第一项的默认账户反查永久 CID（热、冷账户同权），校验
`CidRegistry` Active 与 CID↔账户双向绑定，再读取 `CitizenIdentity::VotingIdentityByCid`：
投票账户、公民身份 CID 号、居住选区、身份状态、投票身份有效期。默认账户无 CID 时就是
该账户的访客状态，禁止扫描其它账户。竞选身份在此基础上读取
`CandidateIdentityByCid`，增加公民姓、名、性别、出生日期和出生地。
成功验真保存完整原始身份快照；普通进入只读取该快照，状态由已保存的 `citizen_status` 和有效期窗口派生。缺快照显示未知并提示主动刷新，不自动查链；已有本地绑定时直接显示其公民号。
主动刷新失败保留原成功身份及卡片内容，另行显示失败提示；不得把失败当成未注册。展示数据不作为操作授权。
三张身份卡显示真实值时，字段名称按文字自身宽度占位，值在名称右侧保留 6px 紧凑间距后立即开始；不得恢复固定名称列造成的大片空白。字段值保持左对齐，公民号完整单行、窄屏等比缩小的规则不变。
用户主页头像右下角认证图标使用 `IdentityBadgeSnapshotStore` 的
`visitor/voting/candidate` 展示快照；账户定位当前完整身份，CID定位对应徽章，换绑由同一存储事务维护。
“我的”、身份页和广场只订阅成功快照的本地变化；轻节点 operational 不触发身份查询。
快照仅供展示，发布等实际授权必须重新完成一次 finalized 验真。

##### 5.1 用户主页

页面元素：背景图、头像、公开昵称、用户码图标、右箭头、钱包/身份入口；
“我的”头部头像与公开用户主页统一为 80 逻辑像素，右下角身份/会员徽章必须超出头像边界显示；
“个人服务”固定按“创作者 → 通讯录 → 会员｜订阅”排列，随后是设置入口。

进入创作者页只传永久cid_number提示，身份由本机门禁核对；档位来自根目录citizen_chain。用户主动刷新先分页取得本人已登记订阅CID集合，再由轻节点在一个最终块读取这些订阅，计算有效人数和预计月收入。只统计已登记集合，不宣称全链发现或已结算收入。统计保存于Creator现有本地行；失败保留最后成功内容。通知不回填统计，身份/账户代次检查继续生效。

“我的”页钱包/身份两行入口的 411×914 设计高度为 70px，个人服务单行入口的设计高度为
64px；实际高度统一乘以全 App 视口倍率，辅助字号只允许按真实行高增加必要高度。通讯录卡
的昵称、备注和公民号行框必须显式指定，卡片不显示个性签名；标准操作图标的设计尺寸为 24px，禁止平台
默认字体度量改变卡片高度。

##### 5.2 用户资料页 `ProfileEditPage`

自上而下：
1. 用户码（当前默认账户不存在时显示占位提示）
2. 用户头像行（左侧头像 + 右箭头，点击换头像）
3. 公开昵称行（显示 `display_name`，点击编辑后只更新公开资料）

##### 5.3 公开昵称与钱包名边界

- 用户资料页改公开昵称 → `CitizenProfileApi.updateProfile(display_name)` → 更新资料缓存。
- 钱包详情页调用`CitizenSdkWallet.renameWallet()`并携带当前目录修订；热钱包名称与账户名称独立，冷钱包使用单账户标签而不重复存储。编辑成功更新修订，失败由原身份卡回滚展示；公开昵称不随钱包改名变化。
- 切换身份账户后按新 CID 读取公开资料；钱包改名广播因账户不变而被“我的”和广场
  页面直接忽略。

##### 5.4 电子护照入口

1. “我的”页面点击电子护照入口
2. 跳转 `user/lib/identity/myid_page.dart`
3. `MyIdService.getState()` 只取默认账户的本地快照；已有本地绑定可直接显示公民号，
   缺完整数据不自动查链，完全未知显示“身份尚未获取，请下拉刷新”。`refreshState()`
   仅供主动刷新，调用统一finalized解析器读取CID双向绑定及投票/竞选身份。
4. 访客身份按“匿名访客 → 投票身份 → 竞选身份”排序；投票身份和竞选身份分别把对应当前卡移到首位
5. 当前公民卡展示真实字段值，非当前公民卡只展示字段名称；竞选身份的非当前投票卡不得重复展示投票身份值
6. 页面不得提供选择钱包、更换钱包、钱包二维码或扫码签名入口

电子护照详情页普通进入只读取持久化，与“我的”首页及广场身份展示共用数据。
主动刷新、真实发布及其它已定义的身份授权操作才进入验真；同账户与钱包/身份版本的在途请求合并，
完成结果仅供该次操作使用，不跨后续操作充当授权。链读失败保留已有展示且阻止本次授权，不能伪装成未注册。
查询中切换账户或身份版本必须拒绝旧结果；已验证未注册与未知分开保存/呈现。
成功验真统一写入展示快照并通知页面；通知只触发本地读取，不连带重复查询链、会员或公开资料。
注册/自助换绑完成后使用已核验的finalized绑定更新同一快照；打开换绑目标列表只读本地账户。
详情有效期按既有UTC+8规则从保存的日期派生，不因跨日额外联网。

##### 5.5 通讯录

- 属主只取CurrentUserContext的当前默认身份CID，不接受付款钱包覆盖；未注册沿用注册引导。
- 普通进页、返回或身份revision重读只读取本机联系人、状态、公开资料与头像缓存，不握手或云端同步。
- 点扫码直接打开相机。只接纳用户码并在本机按CID去重，新增落盘后才逐条备份，重复扫码不联网。
- 备注只允许汉字和英文字母、可空、最多40字。实际保存或清空时标记同条联系人待同步；相同内容不建立会话或请求云端。
- 排序：备注中文取拼音首字母、英文忽略大小写；无备注取公民号首个数字。数字0–9在前、字母A–Z在后，同键按完整拼音和公民号稳定排序，不按公开昵称或时间。
- 同步失败重试只补发待发记录。下拉执行完整同步：先逐条提交待发增删改，再分页拉取云端全部联系人与备注。未变联系人不上传；下载完整成功后才对齐本地清单，保留下载期间新产生的本地变更。失败不自动重读或覆盖本地。网络恢复和前台准备只补发待发项。
- 联系人卡片的头像、公开昵称、私人备注、公民号、徽章和搜索范围保持；菜单仍为转账、私信、修改备注、删除联系人，删除项保持危险红色。
- 联系人页和聊天选人复用同一服务与排序；只回传联系人CID，不改付款账户。付款确认前仍由链上支付服务核验CID当前finalized绑定。私信仅以CID寻址，普通点击仍进入唯一UserProfilePage。

#### 6. 依赖

- `image_picker`、`isar_community`；二维码与钱包能力分别由实际锁定SDK提供
- 协作：`CitizenSdkWallet`、`user/lib/identity/myid_page.dart`

#### 7. 未注册身份统一引导

- 通讯录、社交主页、会员与广场详情在确认未注册时显示 `IdentityRegisterGuide`；扫码、订阅等动作返回所属页面，不越过引导直接打开面板。
- 注册身份底部面板 `showRegisterIdentitySheet` 全仓唯一；身份页右上「注册」与各页引导按钮共用真人验证、余额检查、链上注册和设备激活流程。提交期间不允许关闭面板，失败留在面板并保留所选账户。

#### 8. 通讯录未注册引导

通讯录属主 = CID,**没有 CID 就不该读通讯录**:

- `ContactBookPage._load()` 先判身份缓存,未注册 → 置 `_unregistered` 并**直接 return**,
  `getContacts()` **一次都不调**;整页显示 `IdentityRegisterGuide`。
- 为什么必须短路:`getContacts()` 第一步 `_requireIdentityOwner()` 对未注册身份**必抛**
  `WalletAuthException('请先注册 CID 身份')`,页面 catch 后 `_contacts` 保持空,渲染会落到
  `_EmptyContacts` —— 把「你没注册」显示成「你没有联系人」,与广场当初把权限态伪装成
  「加载失败」是同一类错误。
- 链读异常**不吞**:`resolve` 抛错走原有故障路径,绝不把「没读到链」冒充成「没注册」。
- 测试钉死:未注册 → 引导 + `getContactsCalls == 0`;已注册 → 正常列表且计数 > 0。

#### 9. CID finalized 后页面就地收敛

- 首次占号完成 finalized 身份闭环且 Cloudflare 用户投影确认后，服务层递增统一身份
  revision 并使 `CurrentUserContext` 按钱包 revision 重读；占号不改变 `account_id` 也必须
  广播，因为当前默认账户的 `cid_number` 已从空推进为有效值。
- “我的”、广场、聊天、身份、通讯录、创作者和会员等已挂载页面监听对应 revision，并以
  `account_id + cid_number` 或完整身份重新判定；创作者页还按 CID 监听独立
  `MembershipRevision`。通讯录/创作者加载使用代际保护，旧的“未注册”或旧 CID 异步结果
  不得覆盖新状态。
- 当前用户上下文的并发合并只允许复用同一钱包 revision 请求；revision 变化后仍在运行的
  旧请求不得回写当前缓存。普通页面重读只访问本地绑定和 Cloudflare，不启动链读取。

#### 10. UserIsar 数据域边界

- UserIsar统一承载27个集合，包括资料图片、修改恢复及钱包业务缓存；
  两库以及 App/Social/Chat 各自拥有独立文件、实例、打开任务、生命周期和操作队列。
- 资料媒体按准确 CID、用途和版本寻址，不扫描旧通用用户键。

#### 11. 公开资料、用户图片与会员首帧

- `profile` 是按CID持久保存的唯一公开资料记录；MyTab、本人主页、
  资料编辑、发布和聊天头像不再维护固定行或本机路径第二真源。
- 头像与背景严格区分两种状态：字段从未设置时，按 CID 稳定显示内置照片；字段已经设置时，
  优先显示数据库保存的用户图片。显式刷新失败保留上一张用户图片；没有可用本地图片时显示
  中性占位，禁止退回内置照片。
- 用户选图上传成功后，本机图片字节与公开资料完成同一CID的数据库事务提交，再广播资料
  revision；已挂载的 MyTab 和本人主页据此就地刷新，不依赖退出页面或重启 App。
- 身份、会员与订阅的链上展示统一由轻节点提供；旧服务端展示输入已移除，按链、账户、CID及最终区块隔离的本地读模型已接入。未知时显示尚未就绪或读取失败，资源授权只供服务端业务预检。
- 用户主动注销仅删除对应CID的资料和媒体行、旧文件及临时展示目录。AppLock先关闭并
  擦除UserIsar，再删除旧`user/profile_media`与临时`profile_media_work`；媒体清理入口不得
  为擦除重新打开数据库。代次检查阻止迟到下载或展示文件写入复活已清理数据。

## wallet

CitizenApp承载历史钱包页面、卡片、导航、创建/导入/备份/追加/私钥显示及交互，使用CitizenWalletState与CitizenWalletStateAccount接入SDK唯一底层。任一热／冷账户满足钱包存在条件，无钱包时显示App原初始化页面；SDK不提供初始化或敏感钱包窗口。18词和冷导入入口属于已确认增量。冷钱包导入扫码只允许账户码，不接受用户码、转账码；其他业务二维码入口不受影响。

CitizenApp 不保存助记词、私钥、wallet profile、加密秘密信封或 Vault 引用，不实现 sr25519、钱包派生、默认账户权限或冷热签分流。账户排序、默认账户、冷公钥导入、改名和删除直接调用 CitizenSdkWallet。

CitizenApp 冷账户交易仍展示唯一 QR_V1 请求，由 CitizenWallet 扫码签名后回扫响应。旧钱包数据不迁移不兼容，用户重新输入助记词或公钥建立 SDK 账户。



## 产品介绍与开源许可

根目录 `README.md` 仅提供本产品简明介绍，不承载技术方案、任务记录或验收结论。独立自有代码采用根 `LICENSE` 的MIT；上游代码、衍生修改、依赖及组合分发遵循各自原许可、版权、例外与附加要求。

本机MLS设备登记的钱包授权在签署成功后、任何网络请求和Turnstile展示前持久保存，并读回核验。登记断网、超过原窗口或回执丢失后复用已存钱包授权，每次提交使用同一MLS身份的新鲜device挑战。完全相同已登记行可不重复Turnstile；未落库或更新收到turnstile_required后获取新token，再用新鲜MLS挑战提交。授权损坏或当前MLS公钥变化失败关闭，不重新请求钱包认证。服务故障和迟到身份快照不能冒充无钱包或未注册。

iOS正常入口黑盒回归先核对App自己的12/18/24词创建页；模拟器无硬件保护时创建与热导入必须禁用，冷导入空地址必须失败并可返回。之后仅在模拟器通过正常冷导入表单保存公开开发账户Bob的CitizenChain地址（SS58前缀2027），拒绝系统通知提示并从首次身份引导页返回，再检查五主导航切换与进程重启。测试不输入助记词、密码或私钥，不交易，不改生产安全保护；公开冷账户的正常页面证据不等同硬件热钱包或生产账户业务验收。正常App和其账户数据在测试结束后保留。

虚拟设备广场几何回归使用设备实际安全区比较发布入口下/右边距，身份栏按既有50逻辑像素基准经AppLayout缩放后断言；一像素/半像素容差和圆弧、对齐、入口位置断言保持。

已注册公开地址通过正常表单导入虚拟设备后，身份登记仍可能要求公民钱包二维码持钥证明。测试须核对该边界并取消，不能伪造认证成功；已认证身份下的实际主页、通讯录与会员业务验收只有在用户完成签名后才能记为通过。公开测试地址从本轮生成的xctestrun环境输入，不写入产品源码或文档。清理仅作用于用例明确指定的开发冷账户。

Android虚拟设备可以通过既有Emulator将电脑摄像头映射到webcam0；配置的前后摄像头须以Android运行时实际暴露设备和连续帧验真，不能只凭配置键判定可用。指纹模拟录入需要系统锁屏凭据，凭据由用户本人设置。iOS模拟生物识别事件不提供Secure Enclave，既定CitizenSDK模拟器保险库保持unsupported；虚拟摄像头或生物识别交互不能解除正式热钱包硬件保护要求，也不能替代真机验收。

虚拟设备公开冷账户替换验收仅接受调用方指定的新、旧公开地址：旧地址完整匹配且仅一条本轮冷账户时才允许移除其本机观察记录，未知地址立即终止操作。导入后通过正常 App 重启并完整核对钱包详情地址，不以导入提示代替持久化成功；不得把公开地址导入计为持钥认证成功。

公开冷账户替换用例返回列表后须重新定位菜单按钮并确认菜单实际打开，禁止复用详情前的旧坐标推断删除菜单已出现。

全部用户可见错误、弹窗、输入提示、操作反馈及认证文案须跟随设备系统语言：中文系统显示中文，英文系统显示英文，并响应系统语言变化。业务错误按结构化类别和操作语义本地化，禁止直接向用户显示SDK、平台或服务原始异常；底层安全判定及协议标识保持原合同。App与所消费SDK各自在所有者源码维护本地化，不能以内嵌SDK文案副本代替所有者修改。

Android Emulator 和 Xcode Simulator 使用公开地址导入的冷账户作为测试输入。保持现有SDK硬件保险库和逐次强认证要求，禁止为了模拟器通过而改用软件金库、跳过硬件校验或提供安全降级开关。热钱包创建、助记词导入及真实硬件保护成功路径由用户在符合要求的真机验收；模拟器继续承担冷账户与其余可执行软件回归。

入账记录黑盒验收从交易入口和钱包详情分别进入同一账户历史，均须实际出现收入记录；钱包卡片定位分别识别热账户操作按钮和唯一冷钱包菜单，冷账户验收不得依赖热账户存在。测试只读取公开收入与确认状态，不点击菜单修改账户、不签名或发送交易。

模拟器现有冷账户的 CID 注册准备可通过既有 iOS 黑盒测试 testPrepareCurrentColdAccountCidRegistration 进入统一公民注册面板；测试停在确认前，注册确认、外部签名及签名响应由用户亲自完成，不替换账户、不保存签名二维码。

冷账户自助占号由 SDK 以 CitizenIdentity call5 生成完整交易请求；钱包登记并严格解码0x0a05。最终成功仍需用户签名、finalized绑定回读与重启身份恢复。

## 非钱包附件MLS边界

公民宿主的非钱包网络秘密统一由chat同一CID本设备MLS身份及协议内部状态承担。宿主二维码公开路由只接受联系与转账；冷签响应只通过CitizenSDK的externalSignature识别与同一会话签名预检。宿主不接收账户数据秘密，扫码页不消费签名或提交交易。媒体文件使用 chat 独立附件 MLS 组，不由公民生成、接收或保存文件用途钥。界面只消费 chat 经过普通聊天 MLS 验证的控制描述和系统保护缓存路径，保留现有媒体选择、压缩、权益、大小上限和展示行为。

文件组仅包含当前聊天获准精确设备叶子，控制消息固定原聊天epoch和名册；上传后身份或成员变化，该动作明确失败，不能静默扩大收件人。接收按真实MLS发送者、块序号、组和附件绑定及完整摘要验证；网络失败只影响该附件，普通消息和邮箱确认继续运行。恢复只使用原协议结果及已持久文件，缺失或损坏的已消费状态明确失败，不调用钱包恢复或重新推进接收链。

附件缓存与临时工作文件由 chat 自有系统保护域承载；App自己的系统保护记录和数据库继续由App负责。

非钱包客户端直接依赖已删除cryptography与flutter_secure_storage；chat/mls 负责 MLS 协议，App记录由自有系统保护目录承载。钱包上游的ristretto255、sr25519、ss58及substrate_bip39仍按原锁传递依赖cryptography，不能将其作为新增设备或数据用途钥实现。原生Pod锁仅移除已停用的flutter_secure_storage_darwin；其他锁定版本保持。

### 产品独立资源与编译入口

Release合同核验正式锁定SDK公开QR方法的准确返回类型、参数顺序及参数类型，不依赖Dart格式化的单行排列；保持禁止宿主第二QR实现及私有SDK导入的断言。

历史已保存媒体的本机安全读取顶也统一1024进制：图片4 MiB、视频3 GiB；双端原生参数防护沿同一含义使用整数字节，封面参数技术顶512 KiB。它们只保护本机解码和历史内容读取，不替代服务端下发的新上传成品规格或会员额度。

### 服务端字段与恢复记录

业务HTTP与启动清单直接消费is_ok/error_code；官方JSON-RPC仍沿其error。资料使用profile_bio，评论使用cid_number/created_at/reply_text/reply_state，通知使用notice_rev/notice_seq/notice_kind/is_cancelled；Dart成员使用profileBio、authorCid、createdAt、replyText、replyState、noticeRev。充值付款意图外层为is_ok/order_id/intent_token/sign_message/intent_data，订单使用order_state/exception_reason。网络入口只接受所属API当前字段。

注册 HTTP 使用既有人验接口。本机记录保存原链交易检查点和最终结果。首次设备挑战使用已有钱包授权和 MLS 证明。充值恢复字段属于独立付款合同，不与注册数据混用。

认证HTTP直接签署token_purpose、nonce_id、expires_at及真实方法/目标/正文；request绑定当前session_hash。chat/mls拥有证明编码，服务端独立验签。资料与通知缓存正文不重复自然索引CID，评论恢复不转换旧分页或待发字段；校验失败撤销操作入口。


详情直接读取既有post索引与manifest正文，清单schema/作者/类型须与索引一致；不接受旧内联正文，也不重编码清单计算链哈希。上传完成删除无上游、无消费者的storageState要求，上传就绪由 Serve 的 R2 发布控制记录判定。发布确认校验响应中的区块、交易和内容摘要。读取失败时保留原 finalized 恢复记录。

本地附件许可按原附件元数据稳定摘要复用一份预留，重试仍独立检查设备帧；未完成不是不存在，不重复占新建次数。存量采样在请求发起时记录本地代次，在途写入不覆盖原基线，成功或未知变更使存量失效，迟到旧采样不得恢复资格；不再把成功成本盲加到快照。缺回执的5xx或未知聊天失败保留已发送日消耗，部分回执只结算其准确窗口，明确未扣量及幂等零扣量可结算；同身份换会话后的真实回执也能结算原未知许可，旧令牌仍不得发送。App 媒体选择入口只消费当前会员单文件上限，不再固定512MiB；系统流式复制和最终媒体检查仍保留。

## 第一方存储与字段收敛

App第一方使用统一用户库27个集合与广场库10个集合，共37个集合。Dart类型、成员遵循官方风格；物理表列名由Isar官方@Name及原生成器确定。id是统一物理主键名称；索引只组合真实字段，不保存派生拼接标识。当前事实、不可变历史、CAS检查点和完整性依据按实际职责区分；不能因当前同值删除独立历史事实。

以下为完整物理列清单；集合所属数据库限定同名单词的作用域。每行只保存该行职责所需事实，结构直接以四份实体及官方生成结果为准。

| 数据库·表 | 物理列 | 职责 |
|---|---|---|
| user.catalog | id, province_codes  | 省份顺序 |
| user.entity | id, cid_number, full_name, short_name, cid_state, province_code, city_code, town_code, org_code, parent_cid, is_legal, family_name, given_name, legal_cid, legal_account, account_count, account_names  | 机构目录展示事实；省级版本另归province |
| user.province | id, province_code, data_version  | 单省目录版本 |
| user.region | id, province_code, city_code, town_code, region_name  | 行政区自然三级编码及名称 |
| user.sync | id, data_kind, global_version, province_data  | 静态目录版本及省份状态 |
| user.contact | id, owner_cid, cid_number, contact_remark, updated_at, pending, change_version | 逐联系人本机记录 |
| user.edit | id, cid_number, state, request, response, content_hash, avatar_bytes, banner_bytes  | 一次资料修改的完整请求、回执、摘要与图片字节 |
| user.follow | id, cid_number, peer_cid  | 自然关注关系 |
| user.identity | id, cid_number, account_id, data, updated_at  | 账户/CID展示及真实采样时间；级别不重复持久化 |
| user.media | id, cid_number, media_role, object_key, profile_at, body_hash, media_bytes  | 资料版本下的唯一图片字节及完整性依据 |
| user.notice | id, cid_number, data, pending, list_data | 通知状态、待发已读及已获取列表缓存 |
| user.profile | id, cid_number, data  | 公开资料；正文不重复索引CID |
| user.setting | id, guide_seen, chat_home, council_order, bank_order, square_tab_order  | 用户本机偏好 |
| social.chunk | id, cid_number, body_hash, part_index, part_bytes, part_hash  | 摘要下的有序字节分块及范围读取哈希 |
| social.cleanup | id, cid_number, draft_id, cleanup_kind, created_at, try_count, last_error  | 草稿删除后独立文件清理事实与重试状态 |
| social.cursor | id, cid_number, post_id, published_at  | 本人发布内容完整回灌的远端检查点 |
| social.draft | id, cid_number, draft_id, post_type, post_title, post_text, media_data, section_data, updated_at  | 可编辑草稿和原有有序媒体/文章结构 |
| social.erase | id, cid_number, post_id, state  | 用户删除事实，防止迟到同步复活 |
| social.link | id, cid_number, body_hash, content_id, content_kind, media_index, media_role  | 内容槽位到唯一媒体摘要的自然关联 |
| social.media | id, cid_number, media_kind, content_type, byte_size, body_hash, is_complete  | 按CID/内容摘要保存一次不可变描述 |
| social.post | id, post_id, cid_number, account_id, post_category, post_type, manifest_bytes, content_hash, receipt_id, chain_block, published_at, state  | 发布时索引和不可变原始manifest |
| social.publish | id, cid_number, draft_id, account_id, post_id, post_type, content_hash, receipt_id, upload_id, manifest_bytes, state, replace_id, block_hash, tx_hash, post_category, chain_block, published_at  | 一次发布的跨阶段恢复事实 |
| social.reply | id, cid_number, post_id, page_data, pending  | 浏览者与帖子下的分页及待发意图 |
| user.account | id, account_id, account_name, creator_account, added_at, is_found, admin_accounts  | 用户本机多签账户及发现事实 |
| user.action | id, account_id, proposal_id, kind, state, yes_count, no_count, created_at, final_at, data  | 个人多签提案历史与投票事实 |
| user.admin | id, data  | 本机激活的机构管理员集合 |
| user.balance | id, account_id, data  | 账户余额快照；正文不重复账户、派生总额或闲置时间 |
| user.creator | id, cid_number, data  | 创作者展示，正文不重复索引CID |
| user.cursor | id, account_id, created_at, genesis_hash, start_block, cursor_block  | 账户导入、链及整块流水进度 |
| user.entry | id, account_id, kind, amount_delta, transfer_amount, fee_amount, from_address, to_address, tx_note, state, entry_source, tx_hash, execution_id, call_hash, block_number, block_hash, event_index, extrinsic_index, created_at, confirmed_at, fail_reason  | 实际提交/事件及本金、费用、SDK执行状态 |
| user.group | id, account_id, state, synced_at, data  | 本机多签生命周期和独立链详情快照 |
| user.law | id, state_key, state_hex  | SDK读取的原始链存储键与十六进制值 |
| user.list | id, cid_number, proposal_ids, synced_at  | 机构提案索引与同步时间 |
| user.member | id, cid_number, kind, data  | 仅尚未完成的创作者关系登记目标和最低最终高度 |
| user.proposal | id, kind, proposal_id, data  | 自然类型/ID下的唯一详情快照 |
| user.scan | id, wallet_hash  | 钱包目录反向发现边界 |
| user.summary | id, proposal_id, data  | 提案列表展示摘要；正文不重复索引ID |

region、follow、draft、cleanup、proposal、contact与member使用真实自然字段定位。媒体关联沿Isar最多三列复合索引的官方约束，复用内容三元索引及同事务内序号/用途筛选，重复槽位失败关闭。广场媒体全链路只使用bodyHash，删除同值media_id；描述、分块和槽位关联不再维护第二套标识。原CID串行、写事务、迟到解绑、失败重试、字节哈希及完成验证保持。

Member仅保留registration待办：creator CID→最低最终高度，登记完成删除目标；没有平台/档位确认、交易证明历史或订阅镜像。CreatorSubscribe只在首次订阅后发PUT关系登记，失败只重试幂等登记，不重签链交易；取消和换档不发云端确认。平台订阅、取消、换档和档位编辑以原轻节点finalized结果完成。

身份局部徽章只保存级别，完整验真只保存原布局与bind_rev；级别由布局得出，局部写入不能覆盖完整事实。公开绑定以同一受保护数组保存，CID仅在每份绑定出现一次；读取与CAS复用同一严格解码，重复CID与旧对象索引拒绝。余额只持久化区块、free_fen/reserved_fen，总额以整数分相加，进入存储前仍校验SDK的finalized与总额一致性。

entry以账户/准确tx_hash或账户/block_hash/event_index在原事务定位；SDK execution_id、call_hash和真实来源仍约束状态推进，事件不能替SDK宣布终态。对方地址只由真实收发双方和账户ID计算，净额包含手续费，不能据正负猜测。原整块事务和游标回滚保持。

媒体成品与自有通道使用body_hash/pixel_width/pixel_height/video_secs/keyframe_secs/file_limit；平台API原名保持。每媒体主文件与预览是两个独立上传目标，按media_index/object_role定位，共用原PUT与重试入口。目标不回抄请求大小/类型，仍校验实际长度、HTTPS、时效、方法、headers与当前会话。本人回灌只消费Serve posts数组及manifest_bytes_base64url，网络与存储共用SquarePostStore.validate；媒体使用body_hash/preview_url，不要求不存在的状态或类型字段。原manifest字节不重编码。

资料图片准备使用upload_kind/content_type/byte_size/content_hash，授权读取http_method；请求摘要不再回抄为返回模型字段。PUT 保留真实 MIME 头并核对授权原对象键；资料更新只传图片哈希。资料图片由字节识别类型和长度，临时文件可再生；显式安全擦除覆盖原媒体目录，普通读取不迁移或清理旧结构。

通知只持有真实事件、未读状态和notice_rev；scope仍为cidNumber/accountId/bindRev及原generation。独立已读进度、持久意图、同版本补存和推送端点apns_env保持。ResourceUsage归现有Proto，MLS请求证明归App自有chat/mls和CitizenServe公开合同。

MLS认证证明统一归chat/mls原生Serde：user_id/device_id/public_key/account_id/bind_rev/service_origin/nonce_id/expires_at/http_method/request_target/body_hash/token_purpose/signature，request额外包含session_hash。Dart严格核对唯一字段集、身份和实际请求上下文；应用域为CitizenRequestV2。


## 关注、评论、创作者与订单合同

关注目标在请求、列表、模型及自然关系中使用peer_cid/peerCid；列表缺失目标或时间非法必须失败，不能形成空身份。评论的唯一幂等操作标识为op_id/opId，待发送恢复与重试使用同一原值；正文、回复目标及操作ID都由实际HTTP字节参加认证。

创作者档位只由轻节点读取，属主由自然CID持有。保留tier_id、tier_name、month_fen、quarter_fen、year_fen，未开通周期为null；金额为正整数分。概览只在本机保存已登记订阅人数、预计月收入及最终块号/hash，金额按大整数分计算；不使用远端版本回填。

充值订单只由TopupProgress表示pending、paid、completed；验款成功并保存才是已支付，发币请求和完成结果由App根层处理，页面关闭不能取消已支付后的请求。

第一方区块事实统一block_hash/blockHash，覆盖帖子、发布恢复、登记及钱包流水；自有发布证明使用tx_hash/txHash。SDK和官方链接口的原成员由所属产品拥有，不借改名改变其协议。物理表列清单保持39表227列；旧真实数据的升级处置不在普通读取路径中执行。

### 广场目录与通知、评论、点赞

`8964/lib/`按feed、post、compose、draft、article、media、comment、like八个目录归属。feed负责广场入口、分类顺序和通知列表；post拥有通用内容模型/卡片/详情/存储/同步及浏览者互动状态；文章编辑和阅读归article，草稿归draft。互动子tab页面归feed，禁止为单个文件另建目录；原系统推送与会员快照状态继续由system/notifications负责，网络与数据库结构仍在network、storage。

三级角标以服务端事件的square_read、notice_read、read_at分别计算，互不级联。广场实际显示清广场层，互动子tab取得并显示快照后清通知层，内容详情显示后按读取上界清该内容评论层。清读意图携带scope、内容ID和through，先在UserIsar.Notice.pending落盘，失败保留原范围重试；旧请求和旧CID不能修改新账号状态。互动页同时核对底部活动tab、当前路由和前后台状态；后台或隐藏页面不请求通知列表、不清读；无可展示快照时读取失败不清读；重新可见后只在列表已失效时补刷；没有定时轮询。square_unread不再等于following_unread与interaction_unread之和。

广场层清读在途的新事件保留补清意图，前一请求结束后只在页面实际可见时按新through补清；隐藏时保留角标，返回后再消费。任务按通知身份与代次隔离，新账号不等待旧账号HTTP，旧任务不能释放或覆盖新账号任务。通知列表只由feed中的页面加载，三级阅读统一使用明确scope的read入口。

通知列表优先使用现有Notice.list_data，缓存只保存当前已加载的逐帖显示字段、响应notice_rev、interaction_sequence、through及next_cursor，按自然索引CID、account_id和bind_rev隔离。关闭重开、切回子tab及前台恢复命中有效列表时不发列表GET。无缓存、明确刷新或相关新事件才拉列表；列表上界读 list_through，续页只传原字符串游标，失败保留已有列表。缓存不保存会话凭据，不授予业务许可，也不增加云端正文副本。

已读意图按明确scope、内容ID、选择集合和through规范化；相同在途意图共用请求，重复持久意图只重放一次，同一事件窗口内已确认意图不再POST；云端已确认但本机保存失败时，重复意图只补本机保存。队列与列表都必须匹配当前绑定；旧绑定待发项不能改归当前身份。父层和通知层的已读回执更新计数但不使逐帖列表失效，内容层已读及新互动仍会更新列表。会员、创作者状态、云端通知、跨设备已读和推送继续使用原合同；没有周期轮询或迁移分支。

通知页面每条内容一行，已读记录保留，最后一条有效通知被撤销则移除。列表版本只取对应响应的notice_rev，不能借全局更新或清读回执冒充列表版本；新事件保留补刷意图；同一在途列表刷新共用请求，翻页期间的完整刷新保持独立。CID/绑定代次切换立即失效旧请求并允许新账号加载，不以两个账号版本数字相等跳过请求。通知入口以through固定收到的评论范围，置顶评论按 created_at 和评论 ID 升序分页，普通评论保持原排列并去重。评论对话从reply_to寻找根评论，仅显示该根的所有参与者与后代；删除保留位置。两处评论入口共用每CID/内容的写操作围栏与原op_id重试记录。

点赞以每CID/内容唯一关系保存。PUT确保已赞、DELETE确保未赞，回执返回绝对数量；不增加评论通知。详情正文下方、评论上方显示点赞总数和单行头像，更多页分页显示全部点赞用户。互动状态按当前浏览者CID隔离，旧读取不得覆盖较新的点赞或阅读操作，也不写入正文manifest。

重复点击当前内容子tab重新加载，重复点击互动子tab刷新通知列表。公民圈的本人/互关筛选，以及setting.square_tab_order的稳定标识和持久化逻辑保持原契约。

### 钱包门禁失败诊断

钱包门禁仅在失败分支输出CitizenWallet固定行：method固定getWalletState，code/stage取SDK公开枚举，reason只对SDK当前静态错误文本及错误码作精确白名单匹配。schema_version、schema_objects、schema_definition分别表示本次SDK实际返回的数据库版本、对象集合、结构不匹配；记录摘要、类型、身份、顺序和状态校验各有独立原因。未知异常、带附加内容或错误码不符的文本统一归other，不输出异常原文、账户、路径、记录字节或密钥。

原错误提示与重试规则保留；门禁错误页增加查看诊断，展示本次安全失败行并调用SDK已有readDiagnostics读取闭集记录。查看不会重读钱包或发起初始化、修复、迁移和清除。日志出口使用现有AppLog，不开启自由文本诊断或新增日志文件；SDK公开接口、数据库结构、钱包读写及安装器实现保持原样。Android验收通过塔塔安装器同签名覆盖安装后，核对设备实际失败行及门禁诊断内容。

SDK宿主边界的固定错误单独归sqlite_operation、sqlite_job、host_wallet_load、host_secret_load和wallet_revision；无细分原因的FFI错误归native_unspecified。这些只证明实际命中的边界，不推断其下层数据库结构或密文损坏。

SDK补传同次job实际产生的固定内部原因时，App按同一白名单展示；若SDK仍只返回sqlite_operation，App不将此通用分支等同于schema_definition或record_digest。宿主错误码和阶段、未知文本脱敏及原钱包读取行为保持。

## 本机编译资源与版本来源

本机安装只准备对应平台编译产物，跳过 Dart 宿主测试目录和 macOS 宿主 MLS。本机compile读取本平台最新成功正式Release的产品版本及对应构建号；首次没有正式记录时才使用pubspec.yaml初始值。控制台任务号不作为产品版本输入。CitizenSDK 在编译开始固定本机当前 HEAD 已保存提交并调用其公开构建入口；chat 直接使用 App 本轮源码与 chat/mls 原锁，不解析外部聊天产品来源；Pub与npm按原锁装配。npm使用缓存优先模式，本机默认使用本仓target/cache/npm，调用方显式缓存配置优先，缺件按锁获取。塔塔自动化沿用其缓存环境。随后正常build由Flutter按Release刷新原生插件注册；不使用build --no-pub跳过该步骤。Git仅放行本地file与正式源码HTTPS，Cargo沿原锁和已声明的来源执行。塔塔自动化继续使用所属Workflow提供的Run构建号和正式SDK选择。

## 包与测试归属重构

根App只拥有启动、导航、跨包装配与lib/test测试。user、wallet、onchain、multisig、personal、offchain、topup、citizen、8964、chat、network、scanner、storage、system、widgets分别拥有pubspec.yaml、lib和唯一test。assets拥有资源声明与资源test；testing提供仅供开发依赖的公共SDK测试桥与隔离设施。Dart包使用官方workspace统一解析和根锁，不复制依赖库存。iOS与Android分别使用既有平台工程声明，各自拥有唯一tests；Android原三个真实测试类分文件归位。充值HTML、JS和npm原锁属于topup/web，生成bundle只写临时工程。

通过塔塔控制台分别执行静态与适用回归，未执行的原生或真机场景不得计为通过。

根App另外拥有我的组合页、首次权限及全App擦除编排；用户通知与认证业务客户端归user。个人多签本地快照与业务写入由personal拥有，原数据库实体与生成序列化不变。network公共传输直接消费SDK公开链地址格式，不反向引用治理。

测试唯一发现入口为lib/test/run.mjs，读取真实workspace包清单，遍历各包唯一test并逐件核对Flutter执行报告；根App脚本、发现器及交易桥接Node测试各运行一次。原生tests仍分别归平台，设备执行结果单列。

scanner只负责采集、QR界面与结果，联系人导入由user提供回调，扫码后跨业务跳转通过ScanDispatch公开端口交给根App。原异常类型归system唯一实现，原文案、状态和签名流程保持。

用户页面的私聊与联系人转账动作经UserNavigation公开回调交给根App，用户包不导入聊天页面或链上支付页面；聊天实现直接使用本地 chat 的会话页面。

编译与测试通过build.mjs的packageRoots读取同一workspace声明。冻结 CitizenSDK 后，mapSdkSource同步映射根与所有实际消费者的SDK来源，不能只改根声明而让成员继续使用Git来源；其它上游版本和锁保持。

钱包、治理和交易页面通过WalletNavigation、GovernanceNavigation、TransactionNavigation公开工厂在根App的lib/navigation.dart组合。原Navigator调用、门禁、参数和结果处理保留，工厂只构造原有页面，不存业务状态。链上交易包的TransactionNavigation与TransactionTabPage统一归onchain/lib/onchain_payment_page.dart，不设独立导航或Tab转发文件；前者仍只定义钱包/联系人选择回调，后者只编排原OnchainPaymentPanel及个人多签入口。金额、余额、手续费以整数分传递。公民 SDK 负责金额解析、展示与费用计算；App 从 SDK 读取链上费用快照和 ED，按清算协议取得费率后调用 SDK 计算清算手续费。App 保留单位、币种、表单和付款账户提示，system/lib/amount_format.dart 只处理 Flutter 编辑状态与光标。

流水列表项与页面分离为wallet/history的record_tile、record_format和原history页面；钱包只消费公开列表组件，详情页继续由根App工厂构造。原格式化算法与整数金额不变。

根App推送装配合同测试归lib/test/app_push_contract_test.dart；它读取实际App组合源码lib/app.dart和系统平台原件，系统包测试不承担根App接线断言。

### MetaMask付款适配

MetaMask适配接口为pay({transaction,openWallet})，由metamask.js调用官方SDK付款协议。公共调度只接收已签名落库订单的完整付款请求，并限制一次外部唤起；适配文件不持有订单存储，建单和已支付门禁由原生App执行。

付款固定使用MetaMask；会话与交易处理统一按下文“当前EVM充值界面与付款接入”执行，有效会话跨订单复用，首次连接后在钱包内继续付款，实际只打开钱包一次。付款前先签名建单并保存完整交易。
付款请求固定目标链与完整交易，不额外请求消息签名。未知结果不代表付款未发生；不重播原签名，不自动重签重付。日志只接受固定付款阶段、错误类别、白名单RPC码及SDK提前结束/超时/无有效回执分类，不输出链接、会话或异常正文。

## 治理提交与执行块确认

治理业务参数在SDK准备交易前校验，机构CID与岗位码必须成对且长度合法，空岗位不得降为个人票据。投票确认绑定SDK成功finalized执行块，使用完整票据与严格SCALE bool；真实缺失与损坏编码分别返回缺失或抛错，不轮询不可变块，也不追随新链头。

立法确认消费 SDK 已按同块 metadata 验证的事件，按本次执行索引、提案、签署人、岗位和赞成/反对方向匹配；行政签署没有独立账本，终态清理也不替代本次事件。代表票、会签和终审的存储若仍存在，方向必须一致。LegislationMeta沿链端executive/override_signers/needs_guard/guard岗位主体布局，旧CID二字段布局删除。广场、身份、会员、清算及治理业务复用 SDK 冷签完成入口，取消与异常统一回收原执行。广场按准备标识观察本次已签记录，原发布恢复与上传顺序仍由 App 持有。测试及金标归所属包的 test。

多签提案同样按执行块完整metadata、extrinsicIndex及完整业务字段确认事件，删除原扫描字节实现；转账备注也必须匹配。联合投票以SDK原执行块metadata及extrinsicIndex核对唯一JointInstitutionTicketVoteCast事件、提案、机构CID、当前签名人、岗位和方向；查询展示仍按canonical票据键。清算RPC只接受WSS及当前snake_case响应，nonce、费率和ACK缺失或损坏抛错，不生成默认成功数据；每次响应须匹配JSON-RPC版本及ID，所有已建立连接的成功、错误和超时出口关闭连接。公共SDK生命周期替身仅在testing既有公开设施中提供，测试必须显式注入结果。

## 资产协议与解码边界

资产编号仅为u32；发行机构身份唯一来自actor_cid_number，execution_account_id为AccountId32，只承担执行，不能用于替代机构、管理员或权限寻址。元数据唯一存储为OnchainIssuance.AssetMetas[asset_id]，value依次为CID、执行账户、AssetClass、decimals和AssetState；AssetIssued事件依次为asset_id、CID及执行账户。CID按UTF-8字节计1..32，精度0..18，状态ForceClosed额外携带u32 close_block，全部解码完整消费输入并拒绝未知枚举、非最短Compact、截断、畸形UTF-8和尾随字节。

AssetClass.Pegged为保留协议位，可解码不代表允许发行。当前链端调用过滤及FeeRoute拒绝OnchainIssuance公开调用；App只有查询接口、协议模型和未持久化的提案数据类，没有实际资产查询实现、页面或Isar schema。提案主键仍是投票引擎全局u64，展示年份/序号是独立元数据。固定SCALE金标唯一归citizen/test/asset/asset_vectors.json，正常、边界和损坏输入由该包两个资产测试文件负责。

### 原生、端到端与性能测试入口

各原生包继续唯一拥有 `ios/tests/`、`android/tests/`，不另建测试框架。`scripts/config.mjs` 的 `testSuites` 是设备用例闭集，`describeAction({flow:'test',platform,inputs})` 与本机 `lib/test/run.mjs` 使用同一声明。外部调度必须显式交付 `inputs.work` 与字符串映射 `inputs.environment`，描述器不继承控制台环境。默认 `host` 执行所有包的 Node、严格分析和 Flutter 测试，并通过现有OpenMLS编译入口准备宿主库；调用方显式交付既有FLUTTER_ROOT和SDK公开CITIZENSDK_TEST_LIBRARY测试库。同版Dart直接启动官方Flutter工具快照，macOS预载只传入Flutter测试进程，避免系统shell丢失SDK真实符号；原生设备用例不混入宿主通过数。

调用方交付独占 `WORK` 和由既有 `assembleProject` 装配的 `WORK/project`。`node lib/test/run.mjs compile ios --scope ui|unit|all` 编译 Release XCTest；ui使用模拟器SDK且只依赖已有隔离宿主，unit/all使用真机SDK只编译完整 Runner，要求已准备原锁 Pods及Flutter Release引擎，不连接设备。测试编译禁用签名并维持原锁约束。`node lib/test/run.mjs compile android` 先由Flutter官方config-only Release流程刷新插件登记，再使用显式已安装 `GRADLE_BIN` 编译Release androidTest Kotlin/Java类，不生成或签署APK。产物只能写本轮普通工程；调用方须提供已安装工具，依赖按原锁获取。工具或原锁依赖实际准备失败时停止。

设备验收单列：`native|e2e|performance ios --device <id> --artifact <已编译.xctestrun>`；Android对应 `--device <id> --component <已安装测试包/runner>`。运行入口不编译或签名；Android要求已安装测试组件。iOS test-without-building仍会由Xcode部署测试runner及所选测试宿主，因此执行时须另具对应隔离设备和测试宿主安装授权。iOS按每个 `-only-testing` 坐标选择，Android按精确class#method选择，禁止整类执行历史注册、发送或付款用例。两个设备结果分别核对实际用例、唯一结束和运行器终态；失败、跳过、零用例及漏跑均不通过。

端到端闭集覆盖启动门禁/重启（Android为Activity重建）、已有交易付款源选择及返回空表单、扫码返回、创作者页读取与聊天前后台界面恢复。付款源选择不是SDK默认身份切换；聊天界面恢复不是服务端重连或消息送达证明。真实服务、默认身份认证、注册、消息和交易留在独立隔离设备验收中。测试不创建账户、输入金额或提交业务。

性能测试记录真实启动、创作者页、已有至少20账户的长列表滚动、原生硬件HEVC媒体转码及内存。Android每项5次采样，记录目标进程PSS与纳秒耗时；媒体要求显式 `--fixture <缓存内合成.mp4>`，不自动读取用户媒体。iOS使用XCTest指标，媒体由现有原生写入器生成合成视频，页面内存明确指向被测App。缺既有数据/硬件能力按跳过报告，不能通过；缺指标也失败。只保留既有创作者首帧1秒要求，其余采样 `assessment:unassessed`，待固定设备建立基线后再判性能达标。

编译、宿主回归与隔离设备验收分别记录结果；不能以编译通过代替设备验收。

测试入口取消后终止本轮子进程组，等待退出才释放现场；宿主组拒绝设备参数，重复开始或结束事件不能形成通过。

设备标识与Android媒体夹具名在调用工具前校验；夹具只接受缓存内合成MP4的文件名，不能作为adb shell表达式。合成视频准备超时/失败清理本测试文件；准备超时不是性能阈值。

编译输入未准备标记为 `not_ready`，工具实际执行失败标记为 `failed`；两者均不是编译通过。聊天恢复须等真实列表“新建”结构出现，再核对读取/错误状态；列表采样只观察可见语义。

Android页面匹配遵循锁定Flutter官方Accessibility桥：普通控件读contentDescription，输入框读text/hintText，Tab提示按官方逗号合并边界匹配；列表只收集与窗口相交的实际语义节点，并按公开账户序号去重。空交易表单通过实际编辑控件空值核对，不依赖旧Android缺失的hintText。

## 复审后的确认边界

内部及联合投票提交保留SDK完整finalized执行，以同块metadata解码并核对同一交易索引、提案、实际签名人、岗位与方向的唯一事件；内部机构票另核对提案所属CID。当前钱包换绑后不能充当历史票据canonical存储主键，查询接口仍按原票据主键读取展示状态。iOS完整原生测试编译消费CocoaPods workspace，独立UI宿主消费project；只编译不签名安装或启动设备。夹具通过Pub实际包配置定位所属包test目录，支持仓库根与包目录运行。文章字体在Quill消费侧使用citizen_assets包限定名称，持久内容协议值保持kaiti/jinglei。创作者既定1秒从点击前至内容就绪以单调时钟断言，等待条件迟到成立不能视为按时完成。

交易页钱包按钮向辅助技术提供当前本地付款账户序号；双端测试点选后核对该值及空表单，防止只验证选择页关闭。清算付款发送前失败与发送后结果未知分开呈现；ACK的tx_id须绑定本次intent。当前公开清算行声明只有登记审计账户，未声明可信ACK签名身份，因此格式正确的ACK也仅显示“付款结果未核实”，不宣称已受理、不提供自动重发。完整验签待所属上游公开身份合同确定后实施。

Android运行器只接受唯一成功终态，终态后的矛盾/重复状态及未结束状态帧立即失败。iOS性能场景逐轮核对声明的启动或时钟/峰值内存指标、单位和有效采样，缺项不能算采样完成；设备基线与性能达标仍独立验收。

iOS原生锁包含Flutter已声明的integration_test0.0.1；第一方Podspec与本轮选定SDK一致，其余Pods沿原版本。完整测试编译要求Pods/Manifest.lock与交付Podfile.lock相同；部署模式的依赖准备成功后再消费workspace，不用一次自动更新锁的安装冒充原锁验收。system测试显式开发依赖既有citizen_testing夹具设施，不新增第三方依赖。

根App测试唯一归lib/test，包含Dart场景及Node统一入口；产品根禁止test目录或同名文件。测试发现只对根App读取lib/test，其余workspace包继续读取各自test，原生仍读取ios/tests和android/tests。Flutter官方空模板不生成根test示例；宿主入口按同一workspace声明把WORK/project/lib/test及各包test的测试文件路径显式传给Flutter。双端Workflow、测试描述器和设备软件入口均使用lib/test新路径。

正式源码的测试发现拒绝根test目录或文件；普通工程的发现必须显式使用assembled模式，根App读取工具test，其余包读取原test，不做路径回退。开发依赖和@visibleForTesting检查沿官方语义在普通工程执行；不新增测试包、不排除诊断、不把测试依赖移入生产依赖。模拟器软件组的正式源为lib/test/simulator_test.dart，工具临时入口为WORK/project/test/simulator_test.dart。

Android原生测试编译前先执行enforce-lockfile，再用Flutter官方config-only Release准备普通工程插件登记，并核对交付锁全部非空记录保持不变（只允许Pub规范化空行），保持integration_test为开发依赖；不手工改GeneratedPluginRegistrant、插件清单或Pub缓存，也不把开发插件加入生产Release类路径。该入口要求调用方已交付已安装工具及平台引擎；不签署或安装APK。

CitizenSDK 2.0接口直接通过同一个CitizenSdk调用，旧chain/wallet/signing分组对象删除；Android使用FlutterFragmentActivity并显式登记CitizenSdkPlugin系统资源。SDK直接依赖保留main声明，原锁记录已通过SDK自身鹿鹿及完整自动化的基线；自动化使用该SDK最新正式Release的完整包，App调用SDK公开consume执行消费验证。

注册交易检查点在CitizenIdentityTransaction真实编排中记录prepared/executing/执行终态和广播前取消，SDK直接调用同一CitizenSdk；原_RegistrationTransactions SDK接口装饰器删除，持久化顺序不再通过假SDK实现。

UserIsar吸收原公共目录、用户及钱包业务实体，唯一物理文件为citizenapp_user.isar；原AppIsar、WalletIsar及其生成物已删除。

原version集合改为sync。物理列主键统一id；正文data、状态state、种类kind、请求request、响应response、待处理pending。协议正文、自然键、唯一索引、不可变历史及授权校验保持各自语义。SDK文件及内部协调文件统一使用新名，安装采用卸载重装，无旧名回退与迁移分支。

### 目录分片失败与精确存储合同

机构目录导入同时检查清单count、全库实存数量及现有province成功记录；只有分片所属省、版本、数量和自然键合法且完成对账后，才写入该省成功记录与同步游标。行政区在对单省执行任何增删前必须完整读取并解析省、市、镇分片，空数组表示合法空数据，缺失或损坏分片则失败并保留该省原记录及游标。全局完成标记仅在最终实存数量与清单相符后写入。恢复原版本资源后可重试；旧实现误推进的游标利用现有计数或省级成功记录重新对账，不增加数据库、版本后缀或迁移标记。

独立创建的默认目录仓储共享同一进行中的机构导入任务；失败后清除进行中状态，页面现有重试入口可再次导入。统一用户库27表、广场10表和聊天10表的表名、主键及物理列名由所属存储测试逐字面量断言。钱包页面退出必须等待统一用户库的实际I/O及watcher取消完成，不把帧稳定当成原生操作结束。

Android本地及自动化构建共用scripts/build.mjs；Release APK生成后、复制交付前，使用既有Android SDK的apkanalyzer检查实际DEX类kotlin.Unit及其INSTANCE字段。该检查与SDK已有精确keep规则配合，缺类、缺字段或检查工具失败都会终止交付，不扩大保留整个Kotlin包。

### 充值弹窗与链图标

选择套餐内网络后显示钱包底部弹窗；点击可用品牌先保存本地订单，再连接和唤起对应钱包。弹窗内保留同次会话与nonce；关闭不恢复原单。处理结束关闭付款及套餐弹窗，返回原账户详情；不会自动跳结果页。
Base名称统一显示Base/贝斯链。两档固定价格为10 USDC或10 USDT购买10,000公民币、1000 USDC或1000 USDT购买1,000,000公民币；package_id为pkg_10、pkg_1000，展示保留实际币种名称。链币映射、不可用与重复点击门禁保持原合同。

业务读取服务通过可选的精确类型函数接收其实际使用的链读取能力；正常调用继续从传入CitizenSdk取得同一方法。测试提供明确的只读数据函数，SDK协议、签名和资源生命周期仍使用真实Core；不恢复CitizenChain等已删除SDK接口，不允许未配置能力默认为成功。

交易编排单元测试仅在App服务边界提供其实际使用的prepare、execute、consume、cancel函数及SDK公开结果DTO，验证call data、先后顺序、finalized确认和错误传播；不创建SDK私有句柄，不伪造签名，不声明真实上链。生产默认仍直接调用原CitizenSdk同名方法。未提供的读取或动作在真正调用时立即报错，不能默认为空数据或成功；组合查询服务转交同一组已注入读取函数。机构详情和提案页读取本机账户目录同样接收明确的只读函数，生产默认沿用当前SDK会话；角色成功与失败、页面重入、迟到结果和权限撤销使用同一业务加载路径验证。

身份换绑及签名确认的业务编排可按明确的payloadSigner函数接收外部签名结果；正常路径仍调用原SDK签名及QR流程。SDK私有签名资源由真实会话创建，App不构造或模仿这些资源。MLS登记无论签名结果来源，都由CitizenSdk.verify校验账户、消息与签名，业务回调不能授予虚假授权。扫码组件的测试只控制SDK所有者夹具的物理相机打开、排空、权限及预览事件，识别文档使用Core原JSON；不实现SDK扫码器。

账户详情的WalletActionCard由冷热入口共用：左侧USDT/USDC两项直接复用既有圆形SVG，标签为充值/USDT及充值/USDC，充值区不再显示链上账户余额，金额仅在顶部链上余额区显示；两条竖线统一40设计单位，居于48高图标槽中轴且比图标更短，原三列宽度定位不变。冷热详情共用冷钱包的全宽纯色头部、平面操作区及完整圆角交易记录卡；零钱包仍使用原绑定、余额与内部提现。WalletNavigation.topup改为带context/accountId/token的异步弹窗意图，旧提现工厂因无调用移除，提现页面保留供零钱包使用。充值源码与测试统一使用topup_sheet命名，不增加目录、依赖或构建入口。付款处理结束关闭唯一充值弹窗回原账户；仅本地已支付不触发公民链余额刷新。原单未知仅保留本机，新点击创建新单，不恢复重付。

钱包列表的WalletActions只声明页面实际需要的类型化读取和动作函数，不实现SDK接口。WalletSnapshot仅包含公开目录及本次归还函数，SDK默认路径继续持有并归还真实CitizenWalletInspection；App测试只交付自己的输入事实及租约，不虚报SDK私有句柄。默认账户切换的外部签名提示仍由原UI负责，生产会话的消费与取消仍由SDK完成；删除前的精确清理目标、安全擦除确认和失败后事实回读保持原顺序。根关闭同样允许明确的动作/生命周期读取输入，缺省仍先停止唯一SDK并完成其检查点合同，再关闭会话，停止失败不得绕过。

零钱包图标与USDT/USDC入口同为48设计单位，使用主题实色圆底与白色钱包图形；三项图标顶端和中轴一致，文字及余额不参与分隔线的垂直居中计算。两线共用同一40高度实现，不保留不同高度参数。统一布局的交易记录卡四角以同款空外框像素为基准回归，显示内容不覆盖边框。

冷热详情共用既有wallet_identity_card.dart中的WalletDetailBody唯一展示布局：名称及铅笔/完整地址复制/账户二维码与顶部链上余额在同一全宽纯色面板，操作区仅USDT充值、USDC充值和零钱包，只有零钱包自身余额留在操作区；交易记录间距/圆角/入口使用同一实现。WalletIdentityCard.name仅是显示输入，onNameChanged由所有者保存：热账户调用SDK.renameAccount(accountId,name)并核对返回账户名称，冷钱包继续renameWallet(expectedRevision,walletIndex,name)。编辑中防重复提交，空/不变名称不保存，失败回滚，SDK目录和本机名称为唯一真源；不修改默认账户、钱包总名或公开昵称。充值到账通过onTopupPaid回到所属页面刷新顶部余额、零钱包与记录，操作卡不再保留链上金额状态和专用加载接口。没有新增文件、目录、依赖或持久字段。

### 会员三卡、互动入口与身份同步展示

会员卡和详情展示不依赖服务可用性；卡片沿原七行的顺序、图标、间距和排版更新主要权益，详情展开完整功能、单篇/单文件规格、两类空间和四项每日额度。无缓存、断网、503或缺档时使用内置的三档介绍；当前套餐或真实缓存优先，响应缺项仍显示待获取。原配色、徽章、宣传语、尺寸、卡片层叠/滑动/点击切换、详情跳转、价格显示条件及订阅/换档/取消交互保持原样。介绍只归membership_detail_page.dart中的membershipBenefits，卡片复用同一文案，不生成业务套餐、当前用量、价格或资格。价格沿已有真实链读取及缓存展示，动作仍要求当前会话和完整订阅事实。未注册引导与三卡共存。广场互动子tab使用讨论气泡图标；其通知协议、顺序标识及未读计数仍消费原接口。

身份页只在当前账户完整公开同步成功后接收类型化结果并清除旧错误；本地快照和绑定过程广播只更新展示，不能将失败改为成功。结果交付继续核对账户、钱包代次、绑定修订及页面请求代次，切换或迟到结果不覆盖当前页。错误跟随产生它的账户，切换后不带入上个账户的错误；此举不表示新账户已完成同步。不增加授权、设备登记或网络轮询。

## 通用本机签名交付

产品编译回执TATA_COMPILE通过signing数组交付待签名目标；path为产物内相对路径，主App为“.”，entitlements为产品权限plist路径或null。Apple产品明确列出嵌套代码及主App，Android交付空数组。产品拥有清单与权限，编译及依赖、资源、验收流程不导入控制台实现。控制台按相对路径嵌套深度从内到外签名，不扫描或推定产品结构，不以产品名称选择权限；描述文件授权值及本次身份覆盖对应请求键，产品独有功能权限完整保留。最终签名与安装仍归通用安装器；独立产品入口保持可执行。

### 通讯录同步与安全诊断

聊天初始化将本地身份及 KeyPackage 准备与认证、连接、发布分开。网络等待在绑定文件屏障外执行，返回后重新核对绑定、失效代次及 token 一致性。

通讯录通过既有设备鉴权和请求证明保护的逐条接口备份到私有R2，与聊天群同步独立。账户快照和备注进入请求；派生地址和本地待发标记不进入请求。日志不记录CID、账户、备注、URL或原始异常正文。所有异步回执重核属主，旧回执不得清除较新的本地修改。

通用关注使用CID关系，任意用户均可关注/取关自己。本人识别不再禁用关注；一次操作完成前不重复提交。操作成功后复用现有refreshProfile读取完整关系和三个计数并写入原缓存，不在客户端手算计数。写入失败恢复原关系；写入已成功而资料回读失败则保留成功关系并提示主动刷新，不伪造或清零计数。

扫码设备错误只归扫码页自己的ScaffoldMessenger，同一提示显示或等待结束期间不重复入队；已接收码和退出时只清本页设备错误，不清调用页的成功通知。相机错误回调不覆盖已接收码的业务处理结果，图库/码型错误沿原业务提示。ScannerView结果、错误、预览及异步启停均校验当前采集代次；同资源旧生命周期操作的失败不得污染新操作。钱包导入/保存、页面视觉与交互保持原合同，旧摄像头错误不能被解释成钱包导入失败。

### 公民App同平台版本与商店更新

iOS、Android独立发行，软件版号由本平台最新成功正式Release确定下一候选补丁版，失败不增加正式版号；正式Flutter构建名称、安装包、Release和商店上传使用同一版号，系统构建号仅用于平台安装识别。本机安装沿用最新成功正式版本及对应构建号，无成功正式记录时使用pubspec初始值。设置页始终先读取设备真实安装版本；商店查询失败不改写本机版本。

Android通过Google官方app-update2.1.0查询当前设备可用更新，点击更新只打开本包Google Play商品页。iOS依据Info.plist公开AppStoreId6800953222及StoreKit真实地区，读取Apple公开上架商品版本，点击打开对应App Store商品页。准备提交、商店草稿、GitHub交付完成均不视为当前设备已可安装新版。已移除App内GitHub APK下载、摘要校验、未知应用安装权限、更新FileProvider及直接安装通道；GitHub正式产物证明仍服务于自动化归档和商店上传，不作为手机侧载入口。不改动应用商店审核/上架设置，不改变公民钱包。

服务端公共链共享额度由chain_rpc_budget_exceeded固定分类，会员与广场沿用原会话状态机展示“公共链查询次数已达服务端限额，请稍后重试”；通讯录失败标签优先使用已分类安全原因，无原因保留原通用提示，原本机联系人和待发操作不清除。诊断仅记录闭集码，不展示服务原始正文。额度失败不作为设备未登记，不自动重登记或换钥；会员三张静态卡、完整详情和原交互保持。设备登记复用原幂等/单飞/有效会话和设备证明，不新增客户端登记流程；服务端原有效身份缓存内可完成0次RPC登记，过期由原核验路径刷新。

用户主页个性签名在公民号下按完整内容自动换行，不设两行上限或省略号；ProfileHeaderCard以相同样式、宽度与文字缩放测量全部签名行，父页复用原动态高度；资料超出手机可见高度时，原折叠头部先随页面滚动完超屏部分，再沿用原淡出/折叠，读到末尾前保持资料可见且避开底部安全区；普通高度位移为0，不增加展开按钮或独立滚动区。昵称/公民号/统计的原单行规则与字号、间距、菜单和会员页面交互保持。签名编辑沿用服务端现有160个UTF-16代码单元上限（Dart String.length），普通中文/英文160、普通非BMP表情80；计数实时更新，超限保留完整输入并提示，在准备新保存请求、建立会话与上传前本地拒绝，恢复请求提交前也校验。删除该输入的默认可见字符限长器，使用原生输入框与只读计数/校验，不截断表情、组合字符、粘贴或输入法组合区；已确认的资料更新继续原本机收尾流程。服务端、数据库、昵称长度合同、依赖和SDK不变。

### 充值本地订单交易记录
充值订单、付款证据和交易简要/详情统一使用citizenapp_user既有entry，不新增表列。沿用service_origin、order_id、order_data；order_data保存原payment、wallet_id、account_signature、payer、txid、wire、proof、recovery_token、check_count、check_at、request_at和receipt，不再生成服务端意图或消息授权。state仅为待支付/已支付/已完成；未确认公民币到账amount_delta保持0。
TopupStore保存与更新在一个用户库事务内完成一次定位查询和原子提交；无变化不写、不发变更。事务成功后向所属账户交付同一entry快照，完整交易列表、冷热账户最近记录、详情及充值弹窗直接更新内存；普通流水watcher排除充值类型，避免同笔订单变化再查一次库。首次列表读取本地数据，详情直接使用列表快照；这些展示及删除操作不初始化钱包、不访问服务端或链。充值不使用保护JSON文件，Dart、iOS、Android保护记录白名单均只保留各自现行身份/锁/登记记录。
已有公民币到账关联仅按准确交易哈希、目标和金额匹配SDK已验证事件，不按金额或备注猜测。新本地付款不会虚构公民币哈希或到账。删除仅删除本机记录，迟到更新不重新插入。损坏明细仍可按准确身份删除。

### 充值信息签名、原付款绑定与三状态

业务订单仅pending（待支付）、paid（已支付）、completed（已完成）。点击链之前只选择套餐；点击链后先内存准备冻结充值信息及随机恢复凭据，由页面指定的公民账户走现有signCitizenPayload/SDK beginSigning，热账户热签、冷账户QR冷签，显式CitizenSigningTransform.raw()、opaqueAction=权威topup动作18。签名失败/取消/离页不保存订单或恢复凭据、不连接MetaMask。成功后才派生短order_id并以实际Unix毫秒正式保存待支付订单，然后连接并唤起MetaMask。连接、构造、广播只是本次流程和事实字段，不另作订单业务状态；取消/失败/付款未知均保存现有fail_reason；明确取消和失败在交易记录显示“取消支付”“支付失败”，未知仍为待支付并注明待核实，不自动续付。

授权消费CitizenServe.md公开16字段合同：13行UTF8/LF原文末尾LF，首行CitizenServe Topup，其后service_origin、chain_genesis_hash、account_id、package_id、token、network、asset、recv_address、pay_amount、coin_fen、config_hash、recovery_hash。签前不含order_id/created_at/payer_address/payment_txid。recovery_hash为恢复凭据文本SHA256；公民签名是原始64B sr25519/substrate签名，不预hash，不套用其他动作。H=SHA256(原文UTF8字节||原始签名字节)，签后order_id=top_加H小写hex前32位。短ID仅定位，真实付款必须绑定完整32B H；不增加order_hash/sign_text请求字段。account_signature为0x加128小写hex，随原单保存并在已支付后请求发币。

套餐面额和各币轨精度由 App 决定，报价生成和配置校验共用 SDK 的整数最小单位换算。SDK 编码 ERC-20 transfer 的标准 68 字节，App 交付完整 32 字节 H，冻结后的付款输入共 100 字节。附加数据可能增加费用，由钱包确认。

App 按原订单选择 RPC、交付完整绑定和按秒向下取整的订单时间下限。SDK 一轮通过六次 RPC 核对交易成功、完整输入、区块归属、最终高度和唯一 Transfer 日志，复查区块后返回链上事实。App 用原订单和这些事实生成现有 TopupProof。

App根层在外部付款回执保存后立即验款1轮，未验真则按20、40、80、160、320、640、1280、2560、5120、10240秒的间隔再验10轮，总计最多11轮。每轮先在原entry.order_data持久消费check_count并预约check_at，失败返回后更新下一check_at，从返回时刻完整等待对应退避时长；每次更新只在同一事务定位一次，不为页面显示另查库，回前台不重置预算；系统暂停期间按绝对到期时间恢复，销毁付款页不停止App验款。任一轮金额、资产、付款人、收款、最终成功和完整H均相符，即保存已支付/证据/一次请求占位，并由App独立客户端立即POST一次/api/topup/confirm。11轮都未通过记录payment_failed并停止，不发送发币请求、不重签重付，不增加第四种订单状态。网页广播回执仅submitted=true，不能自报paid。充值模块不读公民链，付款验真前不访问公民服务端；用户库物理表列、公开16字段、SDK Core与原Dart依赖锁不变；钱包JS声明及锁使用获准的官方依赖。

付款后受理公钥固化，完整结果按服务端12行原文调用CitizenSdk.verify纯验签，付款块核实/GMB最终性由服务端完成。付款地址未取得时本地详情显示“付款人尚未确认”，不再使用连接钱包阶段文案。只有最终成功签名结果使App订单完成；异常保持已支付并记录原因，不新增人工/失败等业务状态。接收器位于CitizenApp最外层，独立于CID/会员/主Tab，初始事件共享查看且导航只消费一次。先结果落库再ACK精确修订；回前台续排未结束付款验证，并对已支付未完成单一次恢复，不再confirm，不触发服务端复验或发币，不用SSE或服务端定时轮询。原行快照直接更新列表，准确SDK到账事件同事务关联，保留原主键、不重复收入。根关闭立即停接收/断HTTP，保持SDK原停止/checkpoint顺序，之后等待充值收尾。

充值固定使用MetaMask，保留EVM100B付款绑定并精确核验真实input。不支持所选链或交易签名时停止，不静默换链或剥离绑定。

### 当前EVM充值界面与付款接入

钱包/账户详情的USDT、USDC入口各自固定币种，复用同一个两行弹窗。顶部增加与身份更换面板同款36×4主题灰色圆角横杠，位于“使用 [MetaMask真实图标] MetaMask 钱包支付”正上方，官方SVG随包绘制，不请求远程图片；弹窗最小高度320，短屏可滚动；第一行“充值金额”显示10,000.00 元/1,000,000.00 元默认前者，选中勾号与金额同为绿色，按钮行右下显示付款金额，随选中套餐显示10.00美元/1000.00美元，不再显示公民币标志或文字。第二行“支付网络”以太坊/币安/贝斯恢复圆形外框，图标下显示中英文名称，默认全部不选。没有钱包选择行或额外付款按钮。注册余额不足面板提供两个明确币种入口，复用该弹窗。点击链即冻结当前套餐与链并发起公民账户签名，当前弹窗只显示本次点击的处理状态，关闭后不占用其他订单。签名失败不建单、不启动外部钱包；成功后签名原文、原始签名与完整付款请求在同一次本地保存中建立待支付订单。签名建单归当前点击的调用方，成功落库后才交付连接宿主；不存在跨订单占用或等待其他订单结束的准入。

资产共六轨：USDC/USDT各Ethereum、Base、BNB。BNB USDC为0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d、18位；Base USDT为0xfde4c96c8593536e31f229ea8f37b2ada2699bb2、6位。配置指纹为固定21行，原文13行、发币请求16字段、完整100B付款input及H绑定保持。

公民 App 每笔订单只打开一次 MetaMask。已签订单才交给根层持有的随包 WebView，原生桥校验随包文档、本次会话与消息序号。付款客户端使用 MetaMask Connect Multichain 1.2.0 的 MWP 会话。SDK 首次申请以太坊、BNB Chain 和 Base 的授权，从对应链的授权范围读取付款账户。收到授权后继续处理原单，无需等待 App 回前台。已有有效授权的订单直接付款。付款按原单链调用一次 `invokeMethod`，交付 `eth_sendTransaction`、已授权账户和原始 100 字节付款数据。

SDK 回调的配对链接或已有会话链接只交付一次。原生桥按在途订单校验 `metamask://connect/mwp` 目标及参数，配对链接使用 `p` 与 `c=1`，会话唤起使用 `id`。钱包会话使用官方存储适配接口与应用专用命名空间，iOS 由本机 Keychain 保护，Android 由 Keystore 密钥加密后写入应用私有区。SDK 决定会话恢复与有效性。

用户在 MetaMask 确认或取消付款后手动切回公民 App。合法交易哈希绑定原单落库后启动链上验款；明确拒绝记为取消，结果未到时继续等待原请求。原订单收尾关闭充值弹层，露出原账户详情。Android 在签名建单后等待短时前台服务就绪才交付 MWP 请求。服务随结果、唤起失败、取消或系统时限释放。iOS 打开钱包前按订单申请有限的后台执行时间，待结果处理结束或系统到期释放。双端 USB 验收观察实际回前台、原账户详情及原单的付款回执或取消记录。

付款JS入口唯一为topup/web/metamask.js，本地模板为metamask.html，构建与资产声明唯一使用metamask.bundle.js；旧入口已合并删除，不保留别名或兼容路径。iOS原生测试选择清单直接列出现有充值回跳和固定阶段测试，实际运行前仍须构建对应测试产物。

链接启动错误等待 SDK 结果或原超时。钱包无回执时沿用 App 等待上限，保留待核实订单。弹窗关闭时由 JS 判断付款是否已交付 SDK，未交付则停止，已交付则由根层接收原单迟到哈希。后续真实结果仍只归原签订单，已发请求不重复付款。诊断只记录固定阶段和错误分类，钱包原生授权、风险提示与交易确认由 MetaMask 控制。

钱包有交易哈希但未返回付款地址时，App从同一轮真实交易RPC确定付款人，并核对完整input、真实Transfer事件与最终区块；成功轮仍准确6条RPC，不增加一次地址查询。验款成功才在同一事务保存真实付款人、已支付证据和唯一发币请求占位。此前确认的11轮退避、后台调度、一次发币请求及结果验签/ACK保持，SDK Core和服务端公开合同不变。

onchain、multisig、personal、offchain、topup 是独立 workspace 包。钱包流水归 wallet/lib/history。充值 HTML、JS 与 npm 锁归 topup/web，bundle 由构建入口在隔离工程生成。

钱包模块归属：core提供WalletNavigation、WalletGate与WalletOnchainBalanceCard，余额直接使用SDK；onboarding承载创建、导入及助记词/密码输入；account承载原钱包账户页面、追加账户、操作/身份卡和账户码；history提供业务流水的存储、同步、列表与详情。现有文件整体归位，不拆类、不改UI与交互，不保留旧根路径转发。数据库实体与用户数据继续由storage原件拥有。


## chat当前实现

chat 是 App 普通本地包。HTTP 路径为 /api/chat，实时连接使用 /api/chat/realtime 和 WebSocket 子协议 chat。MLS 实现归 chat/mls；Android为libmls.so，iOS为MLS.framework，C接口为mls_*。应用认证域为CitizenRequestV2。聊天数据库保持独立，直接使用当前目录布局；目录保护、关闭和擦除按本域生命周期执行。

## 直接请求证明与按需链读取

SquareApiClient不申请普通MLS挑战。每个真实设备/会话/业务请求安全随机生成32字节nonce和30秒期限，由chat/mls签署真实方法、含查询的目标、正文摘要及token_purpose；业务request另绑定实际会话令牌SHA256。标签为MLS 1.0 CitizenRequestV2，没有另一套认证域或回退。服务端验签/鉴权后条件创建已用nonce；注销钱包意图和只读恢复挑战独立保留。

ChainDataReader按关注范围取键：普通头像不取CreatorPlans；只有创作者消费者取档位和本人对应订阅；只有会员价格消费者取三档PlatformPrice。未请求的tiers为null，pricesLoaded明确覆盖状态，不能把未知当无记录。统一快照schema为2，仍按创世链和账户隔离，contentKey排除仅高度/时间变化，实际业务不变不写库。

普通聊天、通讯录、浏览和构造服务不前置GET会员，不恢复会员交易。附件提示复用唯一ChainDataService快照及会话响应下发的静态计划；用户明确附件动作只刷新同一轻节点读模型，不发会员预检HTTP。真实资源许可、额度、撤销和最新链鉴权由服务端独立RPC决定；未知本机用量不伪造0。
