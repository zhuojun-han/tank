# Web 开缸日期与运行时长

2026-09-08。用户要求以鱼缸运行时长替换“几条鱼在游动”，并在海缸管理选择开缸时间。本批只修改 Web；App 待同步项为 [WEB-009](app-sync-backlog.md#web-009-开缸日期与运行时长)。

## 交付

- 首页标题显示运行天数，点击进入当前缸编辑；鱼只编辑和库存摘要保留。
- 设置中的海缸管理支持列表、新增和编辑，开缸日期可清空。具体显示与日期语义只维护于 [产品规格](../MVP_SPEC.md#首页检测趋势与设置) 和 [数据合同](../TECHNICAL_DESIGN.md#网页数据)。
- 新建与切换海缸共用检测状态清理，关闭 [隔离核查](tank-isolation-audit-2026-09-08.md) 中的 Web 旧复核结果问题。App 排队确认日期缺陷不在本批修复。
- 旧体积栏曾允许自由文本；本批保留未改的原字符串，避免只设日期也被新数值校验阻断。用户实际修改体积或新增时仍校验。

## 本地验证

在 `web-demo/`，使用 Node 24.19.0 和已安装 Edge，独立浏览器 context，不读写用户浏览器存档：

| 检查 | 实际结果 |
| --- | --- |
| `npm run typecheck` / `npm run lint` | 通过；最后的体积兼容改动又完成 TypeScript 与该组件 ESLint，新增测试 ESLint 通过 |
| `npm run test:unit` | 162 项通过，含旧档兼容、非法日期、闰日/夏令时及未来日期边界 |
| `npm run build` / `npm run test:ssr` | 生产构建和 2 项 SSR 通过；体积兼容修复后再次构建通过 |
| `npm run test:e2e` | 原有 19 个脚本通过；新增的旧体积回归在修复前产物上失败，正确暴露兼容问题 |
| `npm run test:e2e -- --grep tank-age-browser` | 修复重建后通过；5 组场景覆盖日期增改清空/取消/未来拒绝、旧体积、两缸隔离、刷新、午夜与恢复刷新、新建清除旧检测草稿 |

浏览器各场景无页面异常。3000 开发预览已实际加载新界面；390px 手机宽度与 1280px 桌面截图检查，未出现横向溢出，弹窗和鱼只入口正常。截图日期仅在隔离测试中设置，未替用户填写开缸日期。

日志位于忽略目录 `web-demo/artifacts/tank-age-*.log`，视觉证据为同目录 `tank-age-mobile-{card,form,manager}.png` 及 `tank-age-desktop-card.png`。尚未进行 App 日期实现、迁移、备份或设备验收；本地预览不表示公开网站已部署。

## 云端验证

功能提交 `be1a6f9` 已推送至 `main`。[Web checks](https://github.com/zhuojun-han/tank/actions/runs/34224282842) 完整通过：TypeScript、ESLint、162 项单元测试、生产构建、2 项 SSR、20 个浏览器回归；此结果覆盖体积兼容修复后的同一提交。[Workspace checks](https://github.com/zhuojun-han/tank/actions/runs/34224282763) 也通过。未触发或声称本批 App 构建。
