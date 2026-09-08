# 澜礁 Web

网页用于先实现用户新功能，提供本地拍照辅助比色、记录/趋势、鱼缸、任务与维护计算。相机/通知/备份的移动平台验收由 Flutter 独立完成。网页数据在浏览器 localStorage，功能同步不自动迁移数据。

## 环境和运行

Node.js `>=22.13.0`；依赖以 `package.json` 与 `package-lock.json` 为准。从项目根进入 `web-demo/`，在本目录执行：

```powershell
npm ci
npm run dev
```

开发地址由终端给出。生产产物的本地预览执行：

```powershell
npm run build
npm start
```

`npm start` 使用 `tools/preview.mjs` 通过本地 Wrangler 运行 Worker 与静态资源，默认端口 3000；不会发布到远端。此入口避开当前 Windows 下 vinext Node 预览静态资源路径分隔符问题，保持与 Sites 产物一致。

## 验证入口

| 命令 | 范围与前提 |
| --- | --- |
| `npm run test:unit` | 纯业务单元测试，不构建、不启动网页 |
| `npm run typecheck` | TypeScript 检查 |
| `npm run lint` | ESLint 检查 |
| `npm run test:ssr` | 对现有生产构建执行服务端响应检查，先构建一次 |
| `npm run test:e2e` | Playwright 页面流程，默认启动本地生产预览 3100，先构建一次 |
| `npm run check` / `npm test` | 类型 → lint → 单元 → 一次 build → SSR → E2E |
| `npm run test:dataset:no3` | 单独的 NO3 素材流程审计，读取根 datasets/resource；不属于默认 Web check |

完整检查不要先单独 build 再 `npm test`；check 已构建一次。首次运行 Playwright 可执行 `npx playwright install chromium`；Linux CI 安装浏览器及系统依赖使用 `npx playwright install --with-deps chromium`。

E2E 默认 Chromium、Asia/Shanghai；`BROWSER_CHANNEL=msedge` 可使用本机 Edge，`TEST_TIMEZONE` 可指定时区。设置 `BASE_URL` 时连接指定已运行服务，不另起服务器；测试需使用独立浏览器存储，不能把样例写入用户正在使用的真实存档。

生产预览及浏览器检查应一起确认 JS/CSS/图片可加载；SSR 返回 200 不能证明浏览器交互正常。当前验收结果统一见 [项目状态](../docs/CURRENT_STATUS.md)，不在此复制测试数。

依赖变更同时运行 `npm audit --omit=dev` 与 `npm audit`，并核对实际 Worker 产物。`devDependencies` 中的 React 服务端组件也会进入运行产物，不能把生产依赖审计为 0 当作所有运行路径均无风险。升级前保留锁文件，按具体 advisory 选择兼容修复；不使用 `--force` 或 `--legacy-peer-deps` 掩盖冲突。

## 数据、两端与发布

- 产品数据保存在 `reef-demo-state-v10`，兼容旧状态；用户图片由浏览器端压缩，照片比较不上传视觉服务。演示历史有明确标记，不自动迁入 App。
- NO3/PO4 共用旋转/框选/取色和复核流程，具体输出、插值显示与拒绝规则见 [拍照规范](../docs/IMAGE_ESTIMATION.md)。
- 每日平衡补液周期已在网页实现，App 对应差异见 [同步清单](../docs/coordination/app-sync-backlog.md)；计算与残液规则见 [滴定规范](../docs/MAINTENANCE_DOSING_CALCULATOR.md)。
- 网页提醒仅网页打开时生效，不宣称系统后台通知；localStorage 不是 App JSON/ZIP 备份。
- Web 是根仓库的普通子目录，CI 统一从根 `.github/workflows/` 运行；与 App 的共享合同直接读取根 `contracts/`。具体约定见 [技术设计](../docs/TECHNICAL_DESIGN.md)。
- 公开版本与本地工作树分开记录；生产预览、构建和测试不会自动发布网站。整体工作流见 [开发与验收](../docs/DEVELOPMENT_PLAN.md)。
