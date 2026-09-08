# 东非金剪刀（Ecsenius midas）立绘记录

## 本次范围

- 交付一张可供 Flutter App 使用的单鱼透明 PNG，以及一张放入当前鱼缸背景的比例预览图。
- 本次只保存为设计候选，未加入 App 鱼种目录，也未覆盖现有资源。

## 鱼种确认

- 用户参考图中的“东非金剪刀”按中文水族名录对应 `Ecsenius midas`，常见中文名还包括金剪刀、黄金鳚、金黄异齿鳚。
- 水族名录：https://aquaml.com/s/Ecsenius_midas.html
- FishBase 物种页：https://www.fishbase.se/Fieldguide/FieldGuideSummary.php?c_code=036&genusname=Ecsenius&speciesname=midas
- 日本国立科学博物馆安达曼海鱼类资料：https://www.kahaku.go.jp/research/db/zoology/Fishes_of_Andaman_Sea/contents/blenniidae/11.html
- NCBI Taxonomy：https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=152540

关键形态依据：细长鳚形身体、圆钝头部、连续低背鳍、金黄至金橙体色、蓝圈小眼，以及成鱼明显内凹且上下叶延长的剪刀状尾鳍。

## 输入参考

- `references/user-reference.png`：用户提供的东非金剪刀参考，主要用于黄色/橙色、偏绿腹侧和剪刀尾方向。
- `references/ecsenius-midas-real-reference.jpg`：真实个体的侧面形态参考；来源为 Upscale Aquatics 商品图，仅用于识别身体、头部、眼睛、连续背鳍和尾鳍结构。
- `app/assets/aquarium/clownfish.png`：只作为项目既有轻写实动画渲染风格参考，不复制小丑鱼的体型、花纹或鳍结构。

## 生成与处理摘要

内置 ImageGen 生成一条头朝右、完整侧面的成鱼。首版躯干过高、过椭圆；第二版又矫正过度，变得过长、近似鳗形，两版均保留为回退文件但不再作为成品。第三版按用户原图重新约束为总长约为躯干高度 5.5 倍的紧凑细长比例，保持中段近似平行、向尾柄逐渐收细的轮廓，并采用小头、小眼、自然小嘴、低背鳍与紧凑剪刀尾。画面要求单鱼、1536×1024、四周留白，并排除鱼缸、文字、Logo、水印、阴影和其他动物。

生成图仍带有烘焙棋盘格，因此使用项目内已经验证过的 `extract_checkerboard_alpha.py` 做本地透明化处理，原始生成图保留在 `raw/`，方便回退。

## 交付文件

- `app-ready-v1/ecsenius-midas.png`
  - 1536×1024
  - 32-bit RGBA PNG
  - 真透明背景；四角 Alpha 均为 0
  - 非透明包围框：`(159, 352, 1345, 677)`
  - Alpha 像素：透明 1,347,906；半透明 15,012；不透明 209,946
  - SHA-256：`72cca4e92268c38fd3cb28df2791aef69d27e7d153bf31672c08cfa77e9ca7b0`
- `app-ready-v1/reef-app-preview.png`
  - 1536×1024 RGB PNG
  - SHA-256：`b5c120c9730e15c9fbdf3beda63da4bc0d37d3cb1c5e4858d7b2c88683359c13`

## 当前状态

设计候选已完成并通过尺寸、模式、Alpha 与预览合成检查。尚未加入 App；用户确认后再接入鱼种选择和游动系统。
