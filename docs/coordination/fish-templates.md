# 首页鱼缸立绘与模板盘点

## 当前目录补充（2026-09-08）

用户已授权新生成的 11 种鱼同时加入 Web/App，并明确同意本地 Python 透明化处理；连同原 9 种共 20 项。新增为蓝吊、黄狐狸、拉马克、番茄小丑、关刀、皇后、马鞍、金毛巾、蓝面、紫罗兰、黄金吊。原 ID、原稿、已有库存保留；新增只扩充可选目录，不给用户自动放鱼。

本批源 PNG、处理脚本、运行路径、尺寸和 SHA-256 统一见 [素材清单](../../design-concepts/fish-species/added-fish-2026-09-08.json)，两端使用相同 WebP。授权、界面精简与验收见 [本批工作记录](fish-catalog-and-app-copy-2026-09-08.md)。下面保留 2026-09-07 盘点实证；其中“暂不设计/尚未接入”等是当时范围，不再阻止本次明确授权的接入。

## 2026-09-07 历史盘点

更新时间：2026-09-07。负责人：鱼模板任务；总调度任务：`01a07bcc-a662-73d1-8a0d-0e8c67f2e3f5`。

## 用户意图与本轮范围

- 用户已明确本次要“设计首页鱼缸里鱼的立绘”。不是新增养护参数或水质建议模板。
- 用户后续明确：暂时不开始设计；后续设计必须与先前选中的立绘风格保持一致，立绘须能直接用于网站。当前无需继续追问鱼种，等待用户发起具体设计。
- 本轮仅盘点与运行只读定向验证，仅写本文件；没有生成、替换或接入新素材，没有修改生产代码或发布。
- README、PROJECT_CONTEXT、CURRENT_STATUS 的汇总由总调度独占维护。未来代码或素材修改须先向总调度报告具体路径并协调归属。

## 已有 9 个内置选项

名称与 ID 来自 [Web 目录](../../web-demo/app/aquarium-data.ts) 和 [Flutter 目录及数据模型](../../app/lib/features/aquarium/domain/fish_stock.dart)。双斑宝石公母是两个独立选项，不应合并已有档案。

| 名称 | Web ID／素材文件名主体 | Flutter artworkKind | 设计源位置（design-concepts 下） |
| --- | --- | --- | --- |
| 小丑鱼 | clownfish | builtinClownfish | clownfish-style-study/shortlist/selected-clownfish-A1-production.png |
| 双斑宝石海金鱼（公） | pseudanthias-bimaculatus-male | builtinBimaculatusMale | fish-species/pseudanthias-bimaculatus/app-ready-v1/pseudanthias-bimaculatus-male.png |
| 双斑宝石海金鱼（母） | pseudanthias-bimaculatus-female | builtinBimaculatusFemale | fish-species/pseudanthias-bimaculatus/app-ready-v1/pseudanthias-bimaculatus-female.png |
| 蓝眼海金鱼（公） | pseudanthias-squamipinnis-male | builtinSquamipinnisMale | fish-species/pseudanthias-squamipinnis/app-ready-v1/pseudanthias-squamipinnis-male.png |
| 深水樱花宝石 | odontanthias-borbonius | builtinBorbonius | fish-species/odontanthias-borbonius/app-ready-v2/odontanthias-borbonius.png |
| 火焰仙 | centropyge-loriculus | builtinFlameAngelfish | fish-species/centropyge-loriculus/app-ready-v1/centropyge-loriculus.png |
| 紫吊 | zebrasoma-xanthurum | builtinPurpleTang | fish-species/zebrasoma-xanthurum/app-ready-v1/zebrasoma-xanthurum.png |
| 粉蓝吊 | acanthurus-leucosternon | builtinPowderBlueTang | fish-species/acanthurus-leucosternon/app-ready-v2/acanthurus-leucosternon.png |
| 东非金剪刀 | ecsenius-midas | builtinMidasBlenny | fish-species/ecsenius-midas/app-ready-v1/ecsenius-midas.png |

Web 消费路径统一为 `web-demo/public/fish-species/<ID>.webp`；Flutter 为 `app/assets/aquarium/<ID>.webp`，仅小丑鱼使用 `clownfish.png`。上述 8 对 WebP 逐字节相同。设计源与运行 WebP 尺寸/编码不同；源版本依据设计记录和目录说明定位，本轮未重建转换流程来证明每张 WebP 的精确源 PNG。

## 已选风格与可复用设计方案

- [A1 选择记录](../../design-concepts/clownfish-style-study/shortlist/SELECTION.md)：小眼、自然嘴型、圆润紧凑、轻写实动画 3D。App 小丑鱼 PNG 与 shortlist 的 production PNG 逐字节一致；已实际打开查看。
- App 自然珊瑚礁背景与 `shortlist/selected-aquarium-background-natural-reef.png` 逐字节一致。保持当前背景作为候选立绘的实际展示参照。
- 各鱼种 `SOURCES_AND_PROMPTS.md` 保存参考来源和生成约束：完整朝右单鱼侧视、四周为鳍尾留白、无文字/水印/场景；只继承 A1 的渲染质感，鱼身、颜色与鳍尾按对应鱼种参考。
- 粉蓝吊 V2 是圆润饱满背鳍方向；深水樱花宝石 V2 收窄鱼身、调整背鳍并保留拖丝；东非金剪刀 app-ready-v1 来自修正体型后的第三版生成。更早版本仍保留，不能因文件名或排序而自动替换现用方向。
- [小丑鱼第二轮研究](../../design-concepts/clownfish-style-study/light-semi-realistic-round2/ROUND2_NOTES.md) 是候选研究，不是已选新版本；误认 A1 与 R1–R4 不自动采用。
- 后续得到具体鱼种后，可复用提示结构：目标鱼种/参考角色 → A1 渲染风格 → 单鱼朝右全身侧视 → 透明背景与鳍尾安全边距 → 排除文字、背景及其他鱼。使用 imagegen 生成候选，并单独检查形态、透明边缘、实际鱼缸显示比例；本轮尚未生成。

### 后续网站直接使用的交付要求（用户已明确用途）

- 延续已选 A1 及现有鱼种的轻写实动画风格；不能改成大眼夸张笑脸、玩具质感或自动采用未选候选。
- 交付完整单鱼朝右侧视、真实 Alpha 透明背景，无烘焙棋盘格、整块底色、文字、水印或珊瑚背景，鳍尾完整且四周留安全边距。
- 网页运行素材以现有目录使用的透明 WebP 为目标，保留透明 PNG 源稿供后续处理；按现有素材尺寸级别控制体积，避免过大透明画布使鱼在网站上显示过小。具体缩放值依鱼种外形和实测决定，不强制拉伸成同一比例。
- 验证可解码、真实透明/非透明区域、半透明边缘、源稿与输出对应关系，并在当前珊瑚礁背景和网站鱼缸显示尺寸上检查轮廓、白边、比例与左右翻转。仅有设计预览图或 Alpha 通道不算网站成品。
- “可直接用于网站”作为素材交付要求；用户本轮没有要求立即生成、修改目录或发布。未来接入路径沿用 `web-demo/public/fish-species/` 与 `web-demo/app/aquarium-data.ts`，实际写入前与总调度协调文件归属。

## 数据和编辑能力对应

- 内置目录字段：Web 为 `id/name/note/artworkPath`，Flutter 为 `kind/name/note/asset`。当前没有养护百科、水质阈值、价格或体长模板。
- 每缸鱼类档案保存 `id/tankId/species/quantity/introducedOn` 及立绘引用。数量上限 999，动画最多 24 条，名称最长 24 字符。数量和入缸日期是用户库存数据，不宜固化为鱼种默认事实。
- Web 立绘存储为 builtin ID 或自定义 Data URL；Flutter 使用 enum 名称及分离的 MIME/Base64。Web tankId 是 number，App 是 string，两端不可直接互换 JSON。
- [Web 图片处理](../../web-demo/app/aquarium-artwork.ts) 将上传图放入固定 88:50 画布；[App 图片处理](../../app/lib/features/aquarium/data/fish_artwork_processor.dart) 保留原比例缩放。输入均限 8 MiB；Web 450,000 字符限额含 Data URL 前缀，App 限额仅计 Base64。不能仅据上传格式相同宣称视觉完全一致。
- Web 管理器允许修改已有名称，并对自定义立绘或名称不是“小丑鱼”的档案提供换图；Flutter 当前已有条目提供数量、日期、删除，自定义条目可换图，未见已有名称编辑入口。属于现状差异，不在本轮修改。
- Flutter codec 还限制总条目 200、自定义 Base64 总长度 20 MiB，并严格校验日期；Web normalize 会截断数量/名称且日期只检查可解析性。若以后扩展模板字段，应明确迁移及旧版未知枚举策略。
- App 按海缸事务更新 `appPreferences.fishStockJson`，保留其他缸档案；鱼数据进入本地完整备份。Web 使用浏览器存储。

## 本轮素材验证

对两端引用资源作存在性、解码与哈希核对；Web 9 张图片均有真实透明像素和非空鱼体，并含半透明像素。双斑宝石公母哈希不同，没有出现旧抠图失败时同哈希的空图情况。

| Web 素材 ID | 尺寸 | 完全透明像素 | 半透明像素 | 完全不透明像素 |
| --- | --- | ---: | ---: | ---: |
| clownfish | 707 × 480 | 193820 | 144680 | 860 |
| pseudanthias-bimaculatus-male | 768 × 380 | 164826 | 8424 | 118590 |
| pseudanthias-bimaculatus-female | 768 × 342 | 133855 | 8197 | 120604 |
| pseudanthias-squamipinnis-male | 698 × 480 | 222197 | 9120 | 103723 |
| odontanthias-borbonius | 765 × 480 | 228704 | 12977 | 125519 |
| centropyge-loriculus | 743 × 480 | 158911 | 9269 | 188460 |
| zebrasoma-xanthurum | 642 × 480 | 152549 | 7025 | 148586 |
| acanthurus-leucosternon | 768 × 464 | 172828 | 7988 | 175536 |
| ecsenius-midas | 768 × 251 | 111010 | 7245 | 74513 |

小丑鱼的非透明区域以半透明像素为主，单靠 Alpha 存在不能认定边缘或整体不透明度合格；后续立绘设计应在实际背景上复查。当前统计不等于全部素材的合成视觉验收。

在 `web-demo` 执行 `node --experimental-strip-types --test tests/aquarium-data.test.ts tests/aquarium-motion.test.ts`：12 项通过，0 失败，覆盖 9 项目录、内置引用恢复、自定义数据校验、旧数据不虚构鱼、数量/渲染上限、运动边界和换向。本轮未运行 Flutter 测试、完整构建、线上核验、浏览器点击或真机验收。

## 交给总调度的缺口与待确认项

1. 用户已明确暂不设计，后续保持已选风格且素材须可直接用于网站；具体鱼种等用户发起设计时再确定，不能擅自扩展或重做整套鱼。
2. 设计来源文档中“尚未接入 App/Web”、shortlist 中“网页尚未替换”是历史快照，与当前源码和较新的主文档不一致；不能据此重复接入。可由后续文档整理任务标明历史日期。
3. 未找到独立的统一素材清单，将源版本、输出哈希、转换参数和用户选择记录串联；目前需跨设计文档与两端目录核对。
4. 新候选落盘路径及任何运行素材/代码变动必须先与总调度协调；本任务当前只拥有本文件。
