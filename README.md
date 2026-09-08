# 澜礁海缸水质助手

面向海水缸的本地水质记录、NO3/PO4 拍照辅助比色、趋势和日常维护工具。`web-demo/` 用于先实现用户的新功能；`app/` 是 Flutter Android/iOS 客户端。两端分别保存数据，功能同步不等于云端数据同步。

GitHub 目标仓库为 [zhuojun-han/tank](https://github.com/zhuojun-han/tank)。App、Web、文档与样本统一由项目根仓库管理，目录约定见 [技术设计](docs/TECHNICAL_DESIGN.md)。

## 开始工作

协作规则见 [AGENTS.md](AGENTS.md)，当前版本、开放项和最近验证见 [当前状态](docs/CURRENT_STATUS.md)。本页提供模块索引；历史报告不作为现行命令或待办。

| 内容 | 权威入口 |
| --- | --- |
| 产品定位、架构与用户决策 | [项目背景](docs/PROJECT_CONTEXT.md) |
| 页面与任务行为 | [产品规格](docs/MVP_SPEC.md) |
| 数据、时间、迁移与备份 | [技术设计](docs/TECHNICAL_DESIGN.md) |
| 拍照输出、拒绝与样本验证 | [拍照估算规范](docs/IMAGE_ESTIMATION.md) |
| 稳定滴定与续配 | [滴定配方](docs/MAINTENANCE_DOSING_CALCULATOR.md) |
| 理论计算与建议来源 | [PO4](docs/LANTHANUM_CHLORIDE_CALCULATOR.md)、[KH](docs/SODIUM_BICARBONATE_KH_CALCULATOR.md)、[海盐](docs/SALINITY_CALCULATOR.md)、[维护建议](docs/ADVICE_RULES.md) |
| 修改范围与验证要求 | [开发与验收](docs/DEVELOPMENT_PLAN.md) |
| 网页 → App 差异与授权 | [同步清单](docs/coordination/app-sync-backlog.md) |
| 数据处理与发布限制 | [隐私](docs/PRIVACY.md)、[已知限制](docs/KNOWN_LIMITATIONS.md)、[发布检查](docs/RELEASE_CHECKLIST.md) |

## 运行

- 网页：在 `web-demo/` 按 [Web README](web-demo/README.md) 安装依赖、启动和验证。
- App：在 `app/` 按 [App README](app/README.md) 运行 Flutter；Windows 环境处理也在该处维护。
- 整理前的文档和逐批实证保存在 [归档索引](docs/archive/2026-09-08-before-workflow-cleanup/INDEX.md) 与 `docs/coordination/`；不删除旧用户决策、数据兼容要求或验证证据。
