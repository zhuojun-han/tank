# Web CI 预览退出修复 · 2026-09-08

## 故障证据

- 用户截图对应 [失败运行 34205902274](https://github.com/zhuojun-han/tank/actions/runs/34205902274)，提交 `1c0f6b0`。类型、lint、142 项单元测试、构建、2 项 SSR 已通过；浏览器阶段首项通过，随后 15 项失败。
- 日志显示 Wrangler 在第二项流程期间输出空白错误并退出。第二项等待页面超时，后续 14 项均为 `ERR_CONNECTION_REFUSED`，属于预览服务退出后的连带失败。原运行没有上传 Wrangler 文件日志，具体底层触发原因无法追溯。
- 仅增加诊断的提交 `4bbea76` 在 [运行 34207177772](https://github.com/zhuojun-han/tank/actions/runs/34207177772) 完整通过，说明原故障是间歇性的；不能把这一轮通过当作根因已修复。

## 修改与依据

- Cloudflare 官方 [Wrangler 4.129.1 发布说明](https://github.com/cloudflare/workers-sdk/releases/tag/wrangler@4.129.1) 包含单次代理请求异常导致服务退出、空白报错与后续连接失败的修复。该症状与本项目日志相符；没有证据认定原运行一定发生 workerd 崩溃。
- 提交 `07e1915` 将 Wrangler、Cloudflare Vite 插件、Workers 类型精确锁为 `4.129.1` / `1.54.5` / `5.20260907.1`，采用官方配套的 Miniflare `5.20260907.0-alpha`，避免新旧工具混配。项目未直接使用 Miniflare 构造接口；已核对插件配置接口与构建输出兼容。
- 在 `vite.config.ts` 固定原 Worker 兼容日期 `2026-07-23`，新产物保留 `nodejs_compat`、`index.js` 和 `../client` 静态资源路径。
- CI 透出服务日志，失败时上传 `artifacts/preview-logs/`；预览入口记录所启动的 Wrangler 包装进程退出信息。该信息不能覆盖上游内部进程的全部信号。
- 浏览器回归仍为 16 项、单 worker、零测试重试；未删除流程或放宽断言。App、页面业务、计算规则、用户数据与同步清单均未改动。

## 实际验证

- Windows / Node 24.19.0：类型、lint、142 项单元测试、一次生产构建、2 项 SSR 均通过。
- 同一产物使用独立本地预览和 Edge 完成全部 16 项浏览器流程（2.0 分钟）；测试自行释放预览进程，独立浏览器存储未修改用户存档。
- [修复提交的云端完整检查](https://github.com/zhuojun-han/tank/actions/runs/34208362526)：`07e1915` 在 Ubuntu / Node 24.20.0 / Chromium 上从 `npm ci`、浏览器安装到完整 `npm run check` 全部通过，142 项单元测试、2 项 SSR、16 项浏览器流程（2.5 分钟），零测试重试。同提交的 [Workspace checks](https://github.com/zhuojun-han/tank/actions/runs/34208362522) 也通过。
- `npm ls` 确认各 Cloudflare 工具均去重且无旧版本副本。完整 `npm audit` 从 6 个包节点降至 2 个 high 节点，剩余 `vinext → image-size`；`npm audit --omit=dev` 为 0。审计数字不代表全部运行路径无风险，剩余路径见 [此前依赖审计](project-optimization-followup-2026-09-08.md#剩余依赖与实际使用路径)。
- 本地开发服务因 Windows 文件锁短暂重启后恢复，已用独立浏览器验证首页与设置入口，无页面异常。未发布公开网站，未执行 App、真机或 iOS 验证。

原始日志和升级前后审计保存在本地忽略目录 `artifacts/web-ci-*`；云端记录以上述运行链接及提交为准。
