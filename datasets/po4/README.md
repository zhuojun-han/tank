# PO4 样本清单

`manifest.json` 统一保存 5 张测试照片的 SHA-256、人工范围、框选区域和标签修正记录。编号 1 的文件名仍为原始人工标注，实际范围以 `manualLabel` 及 `labelCorrection` 为准。

所有样本仍为 `unassigned`，不具备最终精度评估资格。坐标为按 EXIF 方向显示后的归一化值；`columns` 表示原始样本的色卡排布，用于审查已知素材，并不改变产品中用户需旋转照片至正方向的要求。

从项目根执行 `node tools/audit-datasets.mjs`。此命令只证明清单和素材完整、规则一致，不证明比色精度。
