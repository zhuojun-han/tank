> 定位更新（2026-09-07）：本文件仅保存第 38 版的历史验收成果。当前任务为「网页版新功能开发」，主要职责是在 web-demo 中实现用户提出的新功能和交互修改，并在完成后执行适用验证。历史验收不代表后续新功能需求已完成。目前等待用户提出具体需求，不自行添加功能或重复验收；继续遵守文件所有权和跨任务协调，公共文档由总调度维护。

# 第 38 版 Web 验收记录

日期：2026-09-07。总调度：`01a07bcc-a662-73d1-8a0d-0e8c67f2e3f5`。

## 基线与范围

- web-demo HEAD：`31065fc2f66e9069155ae22e29786870bd37df66`；开始时 web-demo 工作树干净。
- 本地：`http://localhost:3000`，由 `npm run dev -- --host 127.0.0.1` 启动。
- 线上：[公开第 38 版](https://lanjiao-reef-demo.zhuojun-han.chatgpt.site)。用独立无历史数据的浏览器上下文实际点击，不仅检查 HTTP 或脚本文字。
- 浏览器：Windows Microsoft Edge `152.0.4191.66`，Playwright headless；视口 `320×812`、`375×812`、`768×812`、`1280×812`。
- 本轮未修改产品 TS/TSX/CSS 或鱼类文件，未提交、推送或发布。变更前后产品源码相同，没有需要展示的产品修复差异。新增浏览器脚本与证据，修正文档中第 38 版尚待发布及旧目标天数表单的过时描述。

## 实际浏览器结果

同一脚本在本地与公开站点均 PASS，页面 JavaScript 异常列表为空：

| 场景 | 实际结果 |
| --- | --- |
| 初始 PO₄ | 1.4 ml/s、1 min/天，取母液 2.4 ml 定容至 500 ml，每日母液 0.4 ml、泵出 84 ml、约 6 天 |
| 修改每天运行时间至 2 min | 每日泵出 168 ml，取母液显示 1.19 ml，使用实际泵出量计算 |
| PO₄ 流速清空后切 KH | KH 默认配方仍显示 360 ml，不受隐藏错误阻断 |
| KH 温度非法后切 PO₄ | 恢复 PO₄ 有效流速即正常计算，不受隐藏 KH 温度阻断；此前独立时间/流速值保留 |
| KH 档位 | 实际选项恰为 4/6/8/10；4 ml 档 20°C 拒绝、30°C 通过 |
| KH 4 ml、30°C | 每日母液 40 ml，六天取 240 ml；母液每 500 ml 称取 37.503 g NaHCO₃ |
| 空值、负数、零 | 净水量、流速、运行时间的空值/负值/0 均显示错误；温度空值、-1、41 显示错误 |
| 零需求与容量 | PO₄ 上升为 0 显示无需添加；过量需求提示超过 500 ml |
| 单位转换 | 1.4 ml/min、2 min/天显示每日泵出 2.8 ml，取母液 71.429 ml |
| 精简页面 | 没有每瓶使用天数输入；母液说明初始折叠；一次只有所选指标表单 |
| 窄屏及滚动 | 四种视口均无弹窗横向溢出；320 px 字段和配方可读，长说明通过弹窗内部滚动查看 |
| 既有界面烟测 | 首页、检测、趋势、任务导航可切换；PO4 理论计划、KH 理论计划、海盐计算器可打开和关闭 |

净水量对应同一海缸，为共享值；每日变化、流速、单位、每天运行时间按指标隔离。默认六次 84 ml 与 500 ml 之间的差额是此前用户已接受的近似，本轮没有更改该规则。

## 工程验证

- `npm test`：PASS，包含生产构建及 67/67 测试，0 失败/跳过。构建输出客户端 `page-Bl98obBU.js`。
- `npx tsc --noEmit`：PASS，无类型错误输出；生成 `tsconfig.tsbuildinfo` 缓存，未作为源码修改。
- `npm run lint`：最终脚本版本 PASS，0 错误，page.tsx 两条既有 `@next/next/no-img-element` 警告。
- `tests/maintenance-browser.mjs`：本地及线上各 PASS。新增测试不加入默认 npm test，避免向现有项目引入 Playwright 依赖；可通过 `PLAYWRIGHT_MODULE` 指向已安装模块。
- 首次脚本调试遇到 hydration 前点击及 select/nav accessible-name 定位问题，已改为等待 networkidle 和匹配实际标签；最终两次完整运行均通过。另一次误在项目根目录运行 npm test 因无 package.json 失败，随后在 web-demo 正确目录全量通过；不将工具定位错误归为产品缺陷。

## 可复验文件

- 脚本：[maintenance-browser.mjs](../../web-demo/tests/maintenance-browser.mjs)
- 本地示例：[PO₄ 375 px](../../web-demo/artifacts/maintenance-browser/local/po4-375.png)、[KH 320 px](../../web-demo/artifacts/maintenance-browser/local/kh-320.png)
- 线上示例：[PO₄ 320 px](../../web-demo/artifacts/maintenance-browser/published/po4-320.png)、[KH 320 px 说明滚动](../../web-demo/artifacts/maintenance-browser/published/kh-320-instructions.png)、[KH 1280 px](../../web-demo/artifacts/maintenance-browser/published/kh-1280.png)
- 每个 local/published 目录各 12 张截图（四视口 × PO₄/KH/KH说明滚动）；另有脚本调试早期 8 张截图在上级目录，正式证据以上述两个子目录为准。

在 web-demo 目录使用 PowerShell：

```powershell
$env:PLAYWRIGHT_MODULE='C:/Users/zhuojun_han/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'
node tests/maintenance-browser.mjs
$env:BASE_URL='https://lanjiao-reef-demo.zhuojun-han.chatgpt.site'
node tests/maintenance-browser.mjs
```

## 边界与交接

未发现阻断本次范围的产品缺陷。既有功能除上述浏览器烟测外由 67 项工程测试回归，不声称每条旧任务写入/编辑流程均重新做过浏览器点击。未验证真实泵、真实海缸投加、移动端软键盘、Safari/iOS 或真实通知。

公共 README、PROJECT_CONTEXT、CURRENT_STATUS 由总调度独占维护，本任务没有编辑。请总调度将本记录中的已验收范围汇总至公共状态，整理历史“未发布”措辞。本地新增验证文件与 README 更新无需新的站点发布。
