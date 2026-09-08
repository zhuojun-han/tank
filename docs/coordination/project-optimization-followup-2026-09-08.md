# 项目优化收尾 · 2026-09-08

用户明确“继续优化”后，从 [暂停交接](project-optimization-2026-09-08.md) 恢复。**本批兼容升级、流程修正和验收已完成**，仍有两条工具依赖链作为明确开放项留在下文。上一阶段的代码优化、201 项 App 全量测试及数据升级证据仍保留在原报告，不把它们误写为本次重跑。

## App 和构建流程

- 现有 APK SHA-256 仍为 `91554578F99358778BC6787168BEF11E591B4E76597A841791A93D3820B400BB`，本次没有修改 Dart 产品源码或重建 APK。
- 实际执行数据库生成，22 秒完成；`app_database.g.dart` 前后 SHA-256 均为 `ADF448899CCCFF8C1492A11BF9CCA655EAEEEEFFF8FB18484988BEF4AE84EF87`。新增分页查询没有改变表定义、注解或 schema v10。[生成日志](../../app/build/optimization-generation-2026-09-08.log)。
- 生成器明确报告已移除 `--delete-conflicting-outputs`。App README 与根 CI 已去掉该参数，README 区分查询逻辑与表结构变更，并补充参数化设备截图工具用法。
- 根 CI 在生成前增加 `git ls-files --error-unmatch`：生成文件若未纳入版本控制，检查会直接失败，避免 `git diff` 忽略未跟踪文件而假通过。当前根仓库尚无提交或远程，尚未在线执行 CI；本地以生成前后文件哈希核对。

## 模拟器实际验收

启动原有 `Lanjiao_API_36`，使用已安装的优化版 App；没有重装、清数据或新增测试记录。

1. 原海缸 NO3 趋势稳定显示“0 条记录”和手动添加入口；上一轮截到的是加载过程，没有复现永久加载问题。[空趋势截图](../../artifacts/optimization-device-2026-09-08/resume-trends.png)。
2. 通过界面切换现有 `Audit-20260907` 海缸及 KH 参数：正确显示目标 7–8 dKH、既有 7.2 dKH 点及 1 条历史记录。[有记录趋势截图](../../artifacts/optimization-device-2026-09-08/resume-kh-trend.png)。
3. 恢复原海缸；数据库核对检测记录未变化，当前进程日志未检出 Flutter 未处理异常或 Android 致命异常。[结构化结果](../../artifacts/optimization-device-2026-09-08/resume-verification.json)。

这次验证证明上述页面在当前模拟器能够加载和切换；没有测量 profile 帧率、大量历史数据耗时、真机相机或通知。

## 工作区与 CI 复核

- 两份 GitHub Actions YAML 均通过本地 `js-yaml` 解析；这不等于远程 Ubuntu 构建通过。
- 模拟根 checkout 缺少整个独立 `web-demo/`：根检查退出 0。独立 Web 默认 unit/SSR/E2E 仅依赖本仓文件；读取父级 NO3 清单的审计命令是显式可选项。
- 根忽略规则没有排除素材、样本清单、合同或数据库生成文件。跨仓合同副本一致性在同时检出两仓时由根检查执行，各仓 CI 不冒充跨仓远端联检。
- 根工具本次重新执行 5/5 通过；文档与合同检查 65 份文档、0 failures / 0 notes。Web CI 增加 `contents: read` 权限，与根流程一致。

## 网页依赖处理

升级前 package/lock 与审计保存在 `web-demo/artifacts/security-upgrade-baseline/`，中间通过版本也有检查点。最终固定组合：

| 依赖 | 原版本 | 最终版本 |
| --- | --- | --- |
| Next / eslint-config-next | 16.2.6 | 16.3.4 |
| React / React DOM / React Server DOM Webpack | 19.2.6 | 19.2.8 |
| Vite | 8.0.13 | 8.2.2 |
| Cloudflare Vite 插件 | 1.37.1 | 1.47.0 |
| Wrangler | 4.92.0 | 4.114.0 |
| Workers 类型 | 4.x | 5.20260722.1，与插件 peer 配套 |
| vinext | 0.0.50 | 保持 0.0.50 |

针对性刷新了 Babel、brace-expansion、browserslist、fast-uri、fflate、js-yaml 的兼容传递版本；没有用 `--force` 或 `--legacy-peer-deps` 绕过兼容检查。实际 Worker 包含 RSC，即使包管理将其列为开发依赖也必须处理；本次更新依据包含 [React 官方安全公告](https://github.com/react/react/security/advisories/GHSA-wx67-qw84-cm4g)。全部版本、锁哈希、原始审计、官方来源和尝试过程见 [结构化依赖报告](../../web-demo/artifacts/security-upgrade-summary.json)。

最终组合的 `BROWSER_CHANNEL=msedge npm run check` 正常退出 0：**96 单元、2 SSR、12 E2E**，类型、lint 和生产构建通过。[完整检查日志](../../web-demo/artifacts/security-cloudflare-final-check.log)。新 lint 对整页照片交接提出两处导航提示，已就 sessionStorage/状态重新载入行为添加局部说明，最终 lint 0 诊断。

最后修正 Vite 配置的本地模块导入扩展名，消除未来原生配置加载器不支持的旧写法；仅这一行配置修改后又验证类型与构建。[最后配置验证](../../web-demo/artifacts/security-config-final-validation.log)。没有把之前 E2E 的执行时间写成这一行修改后的重跑。

## 剩余依赖与实际使用路径

`npm audit --omit=dev` 从 **4 个 high 包节点变为 0**；完整 `npm audit` 仍为 **3 high + 3 moderate，共 6 个包节点**，归于以下两条依赖链。节点数量不是产品可利用漏洞的数量，不报告“全面无风险”。

| 依赖链 | 已核对的触发范围 | 保留原因和后续处理 |
| --- | --- | --- |
| vinext → image-size 2.0.2 | 开发/构建解析静态导入图片及 metadata 图片；恶意 ICNS/JXL/HEIF 内容可能使解析停滞。NO3/PO4 用户照片目前走浏览器 Image/canvas，没有查到上传至此库的路径。 | npm 修复建议要求 vinext 1.0.0-beta.9；本批未迁移到框架预发布版。后续单独验证替换解析器或稳定框架升级。来源：[ICNS 公告](https://github.com/advisories/GHSA-w3rx-r6r6-pgpr)、[JXL/HEIF 公告](https://github.com/advisories/GHSA-5p2g-fcmc-qvqq)。 |
| Cloudflare/Wrangler → Miniflare 4 → undici 7.28.0 | 本地构建/预览 HTTP 工具；风险涉及可选重试/缓存拦截器、特殊 blob 请求体和 cookie 字段处理，不能假定所有可选路径都不可达。 | Miniflare 精确锁定此版本；npm 推荐的最新父包使用 Miniflare 5 alpha，本批保留已验证的稳定工具代际。后续需对携带 undici ≥7.29.0 的兼容组合或受控 override 单独验证。官方公告清单见结构化报告。 |

最后一次构建的 20 个 JS 产物经检查，未发现 image-size/sharp/undici/ws/esbuild 模块标记或 image-size 解析器特征；Worker 图片优化走 Cloudflare Images。这是源码与产物检查结论，不是攻击测试，也不能证明所有工具路径无风险。

本地网页已重新启动，`http://localhost:3000/` 返回 200；独立 Edge 上下文从首页进入“趋势详情”，图表可见、无 pageerror。[本地交互结果](../../web-demo/artifacts/optimization-resume-web-verification.json)。验证未读取或修改用户浏览器的存档。

默认 Playwright Chromium 未安装时，依照 Web README 使用已安装的 Edge；本地服务地址使用实际公布的 localhost，配置热重启后不假定等同于 127.0.0.1。远程 CI 与公开发布仍未执行。

## 保留范围

新补液周期 **WEB-005** 仍只在网页，等待用户确认并明确要求同步 App。本轮没有网站发布、应用商店发布、Git 提交或推送；PARITY-004、独立真实样本验证、真机与 iOS 等既有开放项继续由 [当前状态](../CURRENT_STATUS.md) 和 [同步清单](app-sync-backlog.md) 维护。
