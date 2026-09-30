# GitHub 仓库公开与 MIT 开源许可

日期：2026-09-30。

## 用户授权与实际结果

用户要求将本项目 GitHub 仓库开源，并明确选择 MIT 许可证。

- 仓库：[zhuojun-han/tank](https://github.com/zhuojun-han/tank)，默认分支 `main`。
- 操作前 GitHub API 返回 `visibility: private`、`private: true`，现有登录具有仓库管理权限。
- 已上传 [LICENSE](../../LICENSE) 和 [README 许可说明](../../README.md#开源许可)，提交为 `558b558`。
- GitHub 仓库设置仅将 `visibility` 改为 `public`。操作后使用不带登录凭据的请求回读，确认 `visibility: public`、`private: false`。
- 不带登录凭据访问许可接口成功，GitHub 识别为 `MIT`；远端许可正文与本地文件一致。

MIT 授权范围为本项目原创代码及随附文档。第三方依赖沿用各自许可证；图像素材、原始照片、试剂色卡及设计参考图不纳入本项目 MIT 授权，复用须另行确认原权利人的许可。现有素材来源、样本和历史证据均保留。

## 公开前检查

远端仅有 `main` 分支、无 tag，与本地 `9d0922c9d6c18e998959b824b26862722ff40e44` 一致，工作树起初干净。

对公开前本地可达的 28 次提交、1,573 个 Git 对象中的 835 个文本文件版本，检查常见 GitHub/OpenAI/Google/Slack token、AWS access key、私钥头、URL 凭据及长字面密钥，未发现匹配项；候选敏感文件路径无匹配，也没有因超过 5 MiB 而跳过的非图片文件。这是有限模式检查，不代表完整安全审计；图像内容及元数据、GitHub Actions 历史日志和产物未逐项审查。

根忽略规则已排除本地数据库、常见环境变量文件和签名私钥等；本次没有删除文件、重写提交历史或改动应用功能。

## 验证与边界

- 许可与 README 更新后运行 `node tools/check-project.mjs`：通过，检查 98 个文档、8 张 NO3 与 5 张 PO4 样本的完整性。仅保留归档记录引用的旧本地 APK 不存在这一提示，不属于失败。
- 完成本记录与当前状态快照后再次运行工作区检查：通过，共 99 个文档，样本结果及归档提示不变。
- `git diff --check`：通过。
- MIT 标准正文依据 [GitHub 许可模板](https://api.github.com/licenses/mit)，版权行使用 `2026 zhuojun-han`。
- 仓库匿名访问、GitHub MIT 识别及远端许可正文一致性已实际验证。
- 本次未修改业务源码，未重建 APK、运行 App/Web 功能回归或进行商店发布；设备、算法精度与既有发布开放项仍见 [当前状态](../CURRENT_STATUS.md)。
