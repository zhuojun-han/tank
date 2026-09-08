# 网页新功能：重复计划仅计算预览

日期：2026-09-07。对应总调度 App 待同步项：WEB-001。

## 已实现（仅本地网页版，未发布）

PO4 氯化镧和碳酸氢钠补 KH 的同缸、同药剂、开始日及以后存在旧计划时，确认框现在有三个选项：

- **仅计算，不覆盖原计划**：展示本次完整配方、用量及天数，可展开“本次计算的全部每日安排（未加入日历）”。顶部明确提示“仅计算预览 · 未加入日历，原计划和处理记录保持不变”。不会调用任务编排函数，也不显示“已加入日历”或查看新任务的按钮。
- **覆盖并创建新计划**：保留既有行为，仅替换开始日及以后的同缸同药剂任务；更早记录、其他海缸和其他药剂保留。
- **取消，保留原计划**：返回原表单，输入保留，不修改任务。

计算校验仍在冲突检查之前执行。没有冲突时继续沿用计算成功后自动生成条件任务的原行为。KH 保持补 KH 计算，不新增降低 KH 算法。预览结果只在当前会话显示，关闭并刷新不保存新计划。

## 文件与实现边界

- `web-demo/app/page.tsx`：UI 计划添加可选 `previewOnly` 标记；`previewChemicalReplacement()` 只更新计算结果。结果卡区分预览和已加入日历，并在预览提供完整每日安排。冲突操作按单列显示，适配窄屏。
- `web-demo/tests/chemical-preview-browser.mjs`：新增真实浏览器回归。
- `web-demo/tests/rendered-html.test.mjs`：两条旧“系统已预排”文字断言更新为适合预览/已编排两种模式的“分日安排仅供复测后判断”；其余回归保持。
- `web-demo/README.md`：说明新选项和未发布状态；保留上轮验收时已有的文档修改。
- `web-demo/artifacts/chemical-preview/`：12 张正式截图、浏览器日志、全量测试日志和 lint 日志。

本轮基于 HEAD `31065fc2f66e9069155ae22e29786870bd37df66` 的工作树开发。开始时已有上轮 README、验收脚本、截图和类型缓存，均保留。未修改鱼类文件、App、公共文档或 App 待同步清单；未提交、推送或发布。

## 验证结果

- `npm test`：最终 67/67 PASS，含生产构建，0 失败/跳过。首次运行两条旧文案断言失败，更新预览兼容文案断言后全量通过。[日志](../../web-demo/artifacts/chemical-preview/npm-test.log)
- `npx tsc --noEmit`：PASS，无类型错误。
- `npm run lint`：0 错误，page.tsx 809/810 两条既有 img 性能警告。[日志](../../web-demo/artifacts/chemical-preview/lint.log)
- Windows Edge `152.0.4191.66` + Playwright，实际访问本地开发服务器，PO4 与 KH 两组流程均 PASS，未出现页面 JavaScript 异常。[日志](../../web-demo/artifacts/chemical-preview/browser.log)
- 两组均先真实创建 4 天计划，再以其真实结构补入完成、跳过、开始日前历史、另一海缸和另一药剂的控制记录。无效输入、取消、仅计算、关闭并刷新后都对 localStorage 的完整 tasks 数组进行深比较，确认所有字段与历史完全相同。预览完整展开 4 天安排；随后覆盖成 3 天的新计划，核验控制记录仍完全相同，且新计划 ID 不属于旧计划。
- 实际 320×812 和 375×812 截图检查：三按钮完整可见，预览与每日安排可滚动阅读，无结果表单横向溢出。截图关闭 CSS 动画，避免截取入场动画中间帧。

## 本地检查入口

[打开本地预览](http://localhost:3000)（开发服务器已保留运行）。设置 → PO4 氯化镧理论计划或碳酸氢钠补 KH 理论计划。有重复计划时直接查看三选项；全新浏览器可先计算一次，再关闭、重新进入并计算以触发冲突。

可复验输入：PO4 当前 `0.43`、目标 `0.03`、净水 `200 L`、日降幅 `0.1`；KH 当前 `6`、目标 `8`，其余默认。各得到 4 天结果。

- [PO4 三选项 · 320 px](../../web-demo/artifacts/chemical-preview/lanthanum-conflict-320.png)
- [PO4 仅计算结果 · 375 px](../../web-demo/artifacts/chemical-preview/lanthanum-preview-375.png)
- [PO4 每日安排 · 320 px](../../web-demo/artifacts/chemical-preview/lanthanum-daily-320.png)
- [KH 三选项 · 320 px](../../web-demo/artifacts/chemical-preview/alkalinity-conflict-320.png)
- [KH 仅计算结果 · 375 px](../../web-demo/artifacts/chemical-preview/alkalinity-preview-375.png)
- [KH 每日安排 · 320 px](../../web-demo/artifacts/chemical-preview/alkalinity-daily-320.png)

重跑浏览器脚本（web-demo 目录，先启动 `npm run dev -- --host 127.0.0.1`）：

```powershell
$env:PLAYWRIGHT_MODULE='C:/Users/zhuojun_han/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'
node tests/chemical-preview-browser.mjs
```

## 交接

等待用户检查网页版；只有用户确认网页版完成并明确要求改 App 后，才同步 WEB-001。当前公开站点仍为第 38 版，不包含本轮选项。未验证 Safari、移动端软键盘或真实投加；本轮是交互和任务保留功能，不改变化学计算公式。
