# App 备份层

当前 JSON wire format 为 **v10**，支持读取 v1–v9；版本与字段以 [local_backup_service.dart](local_backup_service.dart) 和 [技术设计](../../../../docs/TECHNICAL_DESIGN.md) 为准。

- `LocalBackupService` 导出业务 JSON；v10 包含确认/原始插值及草稿字段。旧范围不补插值；检测照片引用和设备派生通知 ID 在新旧格式读取/写出时清空。
- `CompleteBackupService` 将 JSON 与 SHA-256 清单打包 ZIP。新包仅包含 `database.json` 与 `manifest.json`；历史照片文件参与完整性检查，但不复制到新设备。
- `TestRecordCsvExportService` 按缸导出检测 CSV，含范围和插值，防公式注入；CSV 不用于恢复。

设置页采用权威恢复：完成版本、字段、关联、ZIP 路径/CRC/哈希和容量检查，经用户确认后在同一 SQLite 事务替换 11 张业务表。当前海缸、主题、提醒开关和鱼类档案/压缩立绘可迁移；系统权限不迁移，提交后按本机权限重排提醒。

ZIP 容量检查分三层执行：有界读取压缩文件、在解析条目对象前校验真实目录数量、按实际流式解压输出限制单项/总量。不能信任 ZIP 头部声明尺寸后再一次性解压；链接在解压前拒绝。合法 ZIP64 小包及旧照片备份仍执行原有完整性与恢复验证。

固定日期周期的开始日、默认历史完成边界、逐日状态、稍后与停止随 recurrenceJson 保存并校验；旧空字段保留旧推进语义。原始算法输出与人工编辑分离，恢复失败不得部分覆盖用户数据。

网页补液周期尚未同步 App；其后续实现须明确新增持久化与备份迁移，不能将网页 localStorage 直接导入本层。不得为整理陈旧代码删除历史格式解析、兼容列或相关回归。
