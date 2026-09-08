# 双斑宝石海金鱼立绘设计记录

## 范围

- 物种：双斑宝石海金鱼 / Two-spot basslet / `Pseudanthias bimaculatus`
- 素材：成年公鱼、成年母鱼各一张右向侧视 App 素材
- 风格锚点：`app/assets/aquarium/clownfish.png`
- 生成方式：Codex 内置 ImageGen
- 当前尚未写入网页版或 Flutter App 的内置鱼种目录。

## 物种依据

- FishBase 物种页确认学名、体型（侧扁纺锤形）、鳍条信息，并列出公鱼与母鱼照片：
  https://www.fishbase.se/summary/Pseudanthias-bimaculatus
- *Coastal Fishes of the Western Indian Ocean, Volume 3* 描述：公鱼背侧黄橙、腹侧薰衣草色，面颊有黄橙色条纹，黄色背鳍前部有猩红斑；母鱼配色相近但腹鳍偏白，背鳍没有该猩红斑：
  https://saiab.ac.za/wp-content/uploads/2022/11/1._wiof_volume_3_text.pdf

## 生成约束

两张图都以当前小丑鱼为渲染风格参考，而不是物种造型参考：小眼、自然嘴型、轻写实动画 3D、湿润细鳞、柔和自然光、完整右向侧视鱼体。鱼体保持海金鱼属较修长、侧扁的比例，不复制小丑鱼的白带和黑边。

公鱼提示重点：黄橙色背侧与头部、薰衣草至洋红色腹侧、面颊黄橙条纹、黄色背鳍前部的有机猩红斑、粉红鳍和红色远端边缘。

母鱼提示重点：玫瑰粉至珊瑚色鱼体、背侧柔和黄橙、黄色尾鳍和鳍缘、穿过眼部的细黄线、偏白腹鳍、背鳍不得出现公鱼的猩红斑。

## App 素材与透明度状态

本轮以用户提供的雌雄实物对照图作为物种外观依据，重新生成公、母鱼鱼体；ImageGen 仍把透明网格烘焙进 RGB 像素。用户随后明确允许直接抠图，因此使用项目内的确定性脚本 `extract_checkerboard_alpha.py` 删除近白中性棋盘格、保留最大鱼体连通区域、生成真实 Alpha，并对边缘做一像素内收、柔化和颜色去白边。

最终文件位于 `app-ready-v1/`：

- `pseudanthias-bimaculatus-male.png`：`1536 × 1024`、32 位 ARGB、四角 Alpha `0`，SHA-256 `49D444EAEA7759F10EBFC6A27679A3484521A55B34D266B6E873479EBA04EE7D`
- `pseudanthias-bimaculatus-female.png`：`1536 × 1024`、32 位 ARGB、四角 Alpha `0`，SHA-256 `1FD36A81427536C439E825595EF572D8BFC61B60E35FF3EDF39DE15A600F7510`
- `reef-app-preview.png`：把两张透明立绘合成到当前 App 珊瑚礁背景上的视觉检查图，不是透明素材。

两张立绘尺寸、PNG 解码、真实透明像素和半透明抗锯齿像素已经检查；珊瑚礁背景合成图中未见棋盘格或整块底色。它们符合当前 Flutter `Image.asset`/`Image.memory` 可读取的 PNG 格式，但尚未加入 App 的物种选择和数据模型。
