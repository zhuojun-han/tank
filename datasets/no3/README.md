# NO3 样本数据清单

`manifest_v1.json` 是当前益尔 NO3 样本的唯一清单：schemaVersion 1、revision 2，包含原同框示例及用户新增的 7 张编号照片。图片保存在 `resource/NO3/`，以相对路径和 SHA-256 校验关联；人工范围和框选几何统一保存在清单内。

## 分割规则

- `batchId` 表示一份独立测试液批次；同一批次的所有照片必须进入同一个 split。
- `tuning` 只用于开发与阈值选择，`validation` 只用于算法冻结后的最终评估，`unassigned` 不参与指标。
- 重复拍摄同一管液体不能被当作独立样本，也不能跨调参与验证集。
- 缺少试剂批号、色卡版本、设备、光照或有效区域标注时，字段保留 `null`，不得猜测补齐。

## 当前限制

当前共 8 张图片，独立液体批次、试剂批次、设备和光照等信息尚未确认，全部为 `unassigned`、`eligibleForFinalEvaluation: false`。`unknown-batch` 仅是未知值占位，不代表不同编号是独立样本，不能用于宣称准确率或确定置信度阈值。

`regions.card` / `regions.liquid` 使用图片按 EXIF 方向显示后的归一化坐标，取自已有人工几何标注，不是按浓度结果拟合。数值标签来自用户文件名；后续修正应记录来源并保留原值，不能静默改名或覆盖。

从项目根执行 `node tools/audit-datasets.mjs` 检查路径、哈希、标签、框选、批次隔离和新增图片是否遗漏。App 的 `tool/audit_no3_dataset.dart` 另校验实际解码尺寸。文件完整性通过不等于估值准确性通过。
