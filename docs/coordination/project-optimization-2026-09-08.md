# 项目优化交接 · 2026-09-08

本文件保留当时的**暂停快照**。用户随后明确“继续优化”，恢复后的新增处理和实际结果见 [优化收尾](project-optimization-followup-2026-09-08.md) 与 [当前状态](../CURRENT_STATUS.md)；下方暂停点不再单独代表当前未完成事项。

## 授权与保留约束

- 用户已授权根据全局审计进行技术、工作流和文档优化；暂停期间不继续改代码、升级依赖或运行长期任务。
- 新的每日平衡补液周期仍只在网页，登记 **WEB-005**；必须等用户确认并明确要求同步本项后再改 App。此前 App 优化属于本次授权的技术修复。
- 保留现有用户修改、全部记录、任务逐日历史和旧迁移；没有发布、推送或清除用户数据。
- 根目录本次才初始化本地 Git，暂无提交或远程；独立 `web-demo/.git` 保留。不要用根目录全部 untracked 推断这些都是本轮新建文件，也不要把本地 CI 配置写成已在线执行。

## 已完成实现

| 范围 | 结果 |
| --- | --- |
| 文档 | 20 份原文归档并记录哈希；README、项目背景、状态和模块规范分工；规范 ID 不复用，WEB-004 保留 PO4、补液为 WEB-005。详见 [文档整理记录](project-workflow-cleanup-2026-09-08.md)。 |
| 根工程 | 新增 `.gitignore`、`project-workspace.json`、根检查和样本审计；根/App 与独立 Web 仓库边界明确；Flutter CI 从配置读取 SDK 固定版本，增加数据/合同/生成代码/构建检查。没有执行远程 CI。 |
| 网页存储 | 整体校验和已知旧版迁移；异常 JSON、未知版本、不完整核心存档保留原字符串并阻止自动覆盖；不会给损坏用户存档补入演示检测记录。配额失败/禁止保存时不再提前提示成功，可恢复后重试。 |
| 网页结构 | 倒计时从根状态分离；移除未调用的认证、D1/Drizzle 示例及相关依赖、旧六天近似字段。保留 Sites/Cloudflare/vinext 实际链路。 |
| 网页验证 | 单元测试免构建；完整检查只构建一次再跑 SSR 和浏览器测试。旧脚本分类、2 个过时脚本归档。修复 Windows 生产预览资源 404，使用本地 Worker+资源预览，检查可正常退出。 |
| App 刷新 | 维护时钟按分钟及更早到期边界刷新，暂停取消计时、恢复立即刷新；首页日期独立监听，避免每秒重建首页和鱼动画状态。 |
| App 历史 | 首页按参数只取最新记录；列表数据库每批 10 条；图表读取可见窗口及两端有效点，跨空插值连线，切换海缸/参数隔离旧异步结果。 |
| App 数据 | 11 张表在同一读事务导出备份；恢复 API 明确 Merge/Replace；数据库及备份仍为 v10。删除未调用旧估值器、旧照片处理类、占位页和六天字段。设备工具支持显式 SDK/ADB/序号/输出。 |
| 共同合同 | `contracts/maintenance-dosing.json` 为稳定配方的 10 个参考样例；Dart 直接读取，Web 独立仓库保留副本，根检查校验一致。 |
| 样本 | NO3 清单覆盖原始图和编号 1–7 共 8 张，PO4 为 5 张；真实文件 SHA-256、尺寸、人工标签与取色区域登记。PO4 编号 1 人工纠正标签保留。不能把哈希完整性当作精度验证。 |

## 已实际完成的验证

| 检查 | 结果与证据 |
| --- | --- |
| 根工具 | `node --test tools/tests/*.test.mjs`：5/5；新增本交接后 `node tools/check-project.mjs`：64 份文档，0 failures、0 notes。 |
| 文档归档 | 343 个相对链接无缺失，20 份归档哈希匹配；这是文档整理完成时的数量，新增文档会增加计数。 |
| Web 完整检查 | `npm run check` 正常退出 0：类型、lint、96 项单元、生产构建、2 项 SSR、12 项浏览器流程通过。含存档损坏/配额失败、续配取消与历史保留。日志：[project-optimization-check.log](../../web-demo/artifacts/project-optimization-check.log)。 |
| Web 旧档交叉复核 | 从 Web Git 历史抽取 30 个真实版本结构，覆盖 v4–v10，通过 loader 内存检查；不是用户真实存档完整验收。复核发现的核心缺字段/虚假保存成功两项已修复并回归。 |
| NO3 实图审计 | 8 张按根清单读取，哈希匹配；结果：[results.json](../../web-demo/artifacts/no3-audit/results.json)。编号 3 仍输出 1–5，人工标签为 5–10，属于保留的算法限制，本轮未调阈值迎合标签。 |
| App 全量 | [201/201 测试通过](../../app/build/optimization-tests-2026-09-08.log)。随后最后改动另跑 [维护边界 14/14](../../app/build/optimization-clock-final-2026-09-08.log)、[历史与路由 20/20](../../app/build/optimization-history-final-2026-09-08.log)，未把早先全量结果说成最后改动后的重跑。 |
| App 静态/构建 | 最终静态分析 0 诊断；[最终 Android debug 构建成功](../../app/build/optimization-android-build-2026-09-08.log)。已知 JBR native-access、flutter_timezone KGP 提示保留。 |
| App 模拟器 | 已在现有 `Lanjiao_API_36` / `emulator-5554` 执行保留数据 `install -r` 并启动；实际前台为 `com.lanjiao.lanjiao_water_quality/.MainActivity`。首页、任务页截图已查看；趋势截图截在加载状态，尚未补做稳定画面的设备确认。 |
| 数据保留 | 安装前后 11 张表全部逐行相同：3 缸、1 条检测、5 任务、7 事件等；启动日志无筛选到的 Flutter/Android 未处理异常。[安装核对](../../artifacts/optimization-device-2026-09-08/verification.json)。原始快照和日志同目录。 |
| 独立 App 代码复核 | 分页游标与排序、删游标后续页、跨空点、切换参数异步隔离、旧记录编辑通知、暂停恢复计时均未发现明确问题；未进行真实大量数据耗时或极端时钟跳变测量。 |

最终 APK：`app-debug.apk`（当时构建路径；重建产物已清理，见[清理记录](repository-cleanup-2026-09-19.md)），201568822 字节；SHA-256：`91554578F99358778BC6787168BEF11E591B4E76597A841791A93D3820B400BB`。

## 暂停点与续做顺序

1. **从已通过依赖基线继续**：暂停时根核对 package.json 和 package-lock.json，Next 与 eslint-config-next 均为 `16.2.6`，vinext `0.0.50`；没有安装推荐升级版本。Web 完整回归在这组依赖通过。依赖复核子任务已中止，进程检查未发现本轮 npm 安装、完整检查或 Playwright 测试仍在运行；用户原开发服务保留。
2. **处理已发现依赖报告**：`npm audit --omit=dev` 报告 4 个 high 包节点（nanoid/next/postcss/sharp），[原始报告](../../web-demo/artifacts/production-dependency-audit.json)。npm 建议 Next 16.3.4；需读官方 advisory 并核对 vinext/Worker 使用路径和兼容性，不能把包计数直接写成 4 个可利用产品漏洞。若继续升级，先保留当前 package/lock 基线，再做针对性变更及完整回归；暂停前尚未完成这一项。
3. 补看模拟器趋势页加载后的稳定界面并确认页面日志；无需添加演示数据或重复覆盖安装。设备使用 UTC，截图的 9 月 7 日对应当前上海 9 月 8 日凌晨，未修改设备时间。
4. 核实本轮数据库生成相关声明：查询方法修改不一定需要生成；如果实际改了表/生成注解，再顺序生成核对。根 CI 的生成检查尚未在远程运行。不得并行启动 Flutter/Gradle 构建争用同一工作区。
5. 依赖处理完成后更新本报告和 CURRENT_STATUS 为最终结果，运行根文档/合同检查，再交付；只因出现新改动或失败重复相关验证。

未测边界：真机相机/系统通知、iOS、独立样本浓度精度、profile 帧率和大数据查询耗时。PARITY-004 目标保留差异继续待复核；WEB-005 继续待用户批准 App 同步。

## 本地运行与续接入口

- Web 命令见 [Web README](../../web-demo/README.md)；使用隔离浏览器测试上下文，不覆盖用户 localhost:3000 的存档。
- Windows Flutter/JBR 环境见 [App README](../../app/README.md)；SDK 为 `D:/DevTools/flutter`，现有 junction 为 `D:/DevWorkspaces/lanjiao-app-workspace`。构建命令依 README，不从旧日志复制无效路径。
- 模拟器由本轮启动并保留运行，未清数据；用户原 Web 开发服务未主动停止。
- 暂停不创建自动继续或定时任务；等待用户下次明确继续。
