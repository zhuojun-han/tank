# 最新源码同步与旧交付归档清理 · 2026-09-20

本次将实际 D 盘项目的最新 WebView、保留的纯 Flutter 页面、共用网页、测试和规范一起提交。源代码提交 [1542203ee6d7860be076ed71113ed8c965ebd4c8](https://github.com/zhuojun-han/tank/commit/1542203ee6d7860be076ed71113ed8c965ebd4c8) 已推送 main，并通过远程 refs 核实。

## 本次验证

根结构、文档、合同与样本检查通过；根工具测试 5/5，Web 类型检查、lint、单元测试 169/169 通过。提交前清理 5 个文件的末尾多余空行，修正文档被断开的 nextDate/null 字段及空白；git diff --check 通过。未下载、重建 APK、运行浏览器或模拟器回归；没有用旧设备结果证明本次真机验收。现有 CI 会由推送触发，运行结论以 GitHub Actions 为准。

## 旧交付与保留范围

源码推送确认后，删除 web-demo/outputs 内 19 个旧 site TAR/TAR.GZ 网页交付归档，合计 72,995,998 字节（约 73 MB）。逐包检查只含旧构建产物与部署元数据；本轮不改变线上站点，不删除业务备份、历史验证证据、素材或旧 Flutter 源码。此前已删除的历史 WebView APK 不重复计入。

保留两份本地安装包，清理前后大小及 SHA-256 相同：

| 安装包 | 大小 | SHA-256 |
|---|---:|---|
| artifacts/fish-multiselect-2026-09-12/lanjiao-webview.apk（最新 WebView） | 232,091,447 B | 77b3414b447312b811b9aeb8e923e18e1ad84f1f2d8b840f8bb96f3d0339633e |
| artifacts/webview-migration-2026-09-12/legacy-app-debug.apk（最新纯 Flutter，9/9 UI 交付） | 201,805,663 B | 5820cbac54ccd4ccfbc81a8c9925c974204965a983f2e458a93724171c5f2d23 |

GitHub 提交包含源码、锁文件、资源、测试与文档。上述 APK、本地业务备份/验证产物、依赖安装和机器配置沿用忽略规则保存在本地；本次没有新建 GitHub Release 或上传安装包。当前 WebView 构建顺序见 App/Web README，现有 Flutter CI 只构建旧入口，不代表新版 WebView 平台验收完成。
