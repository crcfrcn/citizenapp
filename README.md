# CitizenApp

公民应用，提供账户、链上资产与公共服务入口，使用 CitizenSDK 连接公民链。

本仓库独立自有代码采用 [MIT](LICENSE) 许可证；第三方代码、依赖及其衍生修改遵循各自原许可证。

目录与入口已按三级规则整理，广场保留`lib/8964`。完整目录、脚本职责和本轮验证结果见[CitizenApp.md](CitizenApp.md)。

本机入口为`node scripts/build.mjs run ios`或`run android`；完整分析与测试入口为`node scripts/build.mjs test`。CI检查与编译共用各端`scripts/ci`文件，Release共用`scripts/release`文件；脚本回归置于各MJS正式代码之后。

```sh
node --test .github/tatagate/test.mjs scripts/build.mjs scripts/flow.mjs scripts/resources.mjs scripts/ci/android.mjs scripts/ci/ios.mjs scripts/release/android.mjs scripts/release/ios.mjs test/release_manifest.test.mjs
```

Node回归须交付本仓声明的固定工具与Xcode测试环境；Flutter回归继续使用锁定SDK、本轮真实原生库与链金标。文档验收记录区分目录迁移检查和产品全套功能验收。

Logo图片的唯一文件来源为`assets/logo/`，原生规格只在`target`构建现场装配。`assets/badges`已并入`assets/icons`。运行`node scripts/build.mjs logos`检查唯一来源、摘要和残留副本。

收尾复查已修正Isar维护入口与账户金标镜像路径，全部Node回归216项通过；范围与既有Flutter验收限制见[CitizenApp.md](CitizenApp.md)。
