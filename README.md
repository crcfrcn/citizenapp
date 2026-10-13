# CitizenApp

## 编译、自动化与渠道发布

本机编译继续使用 `scripts/build.mjs` 的设备安装流程，在本机签名、验真并回读设备。GitHub 的 `ios.yml`、`android.yml` 分别在自己的 Runner 调用同一产品编译文件，在 Runner 内使用 Actions Secrets 正式签名，再创建并回读本平台 GitHub Release。两端工作目录、任务和结果独立。

GitHub iOS 需要 `IOS_KEY`、`APP_PROFILE`；Android 需要 `APP_KEY`。缺少材料时流程失败，不把未签名包发布为正式版。`scripts/publish.mjs` 只核对已完成的正式 Release；App Store、Google Play 等渠道上传需在渠道和授权配置确定后接入。

公民应用，提供账户、链上资产与公共服务入口，使用 CitizenSDK 连接公民链。

本仓库独立自有代码采用 [MIT](LICENSE) 许可证；第三方代码、依赖及其衍生修改遵循各自原许可证。
