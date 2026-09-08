# 深水樱花宝石（发霉鱼）立绘设计记录

## 范围

- 中文水族俗名：深水樱花宝石、发霉鱼、樱花宝石
- 正式中文名：黄斑牙花鮨（台湾鱼类资料库作黄斑齿花鮨）
- 学名：`Odontanthias borbonius`
- 素材：典型健康成鱼右向侧视 App 立绘；本轮不刻意强化公母差异
- 风格锚点：`app/assets/aquarium/clownfish.png`
- 生成方式：Codex 内置 ImageGen；透明背景使用此前经用户明确允许的本地确定性抠图
- 当前尚未加入网页版或 Flutter App 的内置鱼种目录。

## 物种与外观依据

- 水族名录将“深水樱花宝石”“发霉鱼”对应为 `Odontanthias borbonius`：
  https://aquaml.com/s/Odontanthias.html
- 台湾鱼类资料库确认学名、中文名和形态：体延长而高、吻短而略钝圆、尾鳍深内凹，橘红体侧具黄褐色大斑、各鳍偏黄：
  https://fishdb.sinica.edu.tw/chi/species.php?gen=Odontanthias&spe=borbonius
- Fishes of Australia 记录粉红至红色体色、体侧 9–11 块大型褐色或黄色斑，以及从吻端经眼下至胸鳍基部的亮黄色宽带：
  https://fishesofaustralia.net.au/Home/species/5363
- 物种侧视参考图：Fishes of Australia / CSIRO：
  https://fishesofaustralia.net.au/Images/Image/OdontanthiasBorboniusCSIRO.jpg
- 新鲜水族体色参考图：Violet Aquarium：
  https://www.violetaquarium.com/cdn/shop/files/borbonius_anthias_5e7646a8-5ef3-4d19-8a14-16b6d3b34d63.png?v=1706404050&width=1445

参考照片只用于确认物种外形、色彩与斑纹，不作为 App 最终素材直接发布。

## 最终生成约束

以实物图确定较高而短的椭圆鱼体、短钝吻、自然小嘴、深叉燕尾、连续高背鳍，以及暖珊瑚粉体色上的不规则金黄大斑和黄色鳍；以当前小丑鱼确定轻写实动画 3D、湿润细鳞、柔和立体光照和干净轮廓。完整鱼体朝右，四周保留安全边距，无文字、水印、珊瑚、阴影、第二条鱼或小丑鱼条纹。

用户随后补充实物照片，要求以照片中的背鳍和身形为准。V2 因此缩减 V1 过高、过密的三角形背鳍：前半段改为间距较大的细长硬棘，后段为较低的透明软鳍，并保留两根向尾部拖曳的丝状鳍条；同时将腹部和整体轮廓收窄，使鱼体更接近照片中的紧凑椭圆比例。用户照片只作为外形参考，不复制其中的蓝紫色水族灯色偏和背景。

## App 素材与透明度

- `app-ready-v1/odontanthias-borbonius.png`
  - `1536 × 1024`
  - 32 位 RGBA PNG
  - 四角 Alpha 均为 `0`
  - 透明像素 `1,085,195`，半透明抗锯齿像素 `27,867`，不透明像素 `459,802`
  - Alpha 边界框 `(105, 124)–(1366, 894)`，鱼体及鳍均未裁切
  - SHA-256 `F027257D68938A8180CE5CCCC29C55FE4A77677DAF1726C9E2207B04CE16AB4D`
- `app-ready-v1/reef-app-preview.png`：合成到当前 App 珊瑚礁背景的视觉检查图，不是透明素材。
- `app-ready-v2/odontanthias-borbonius.png`（当前推荐候选）
  - `1536 × 1024`
  - 32 位 RGBA PNG
  - 四角 Alpha 均为 `0`
  - 透明像素 `1,156,639`，半透明抗锯齿像素 `30,275`，不透明像素 `385,950`
  - Alpha 边界框 `(125, 146)–(1362, 886)`，两根背鳍拖丝、鱼体及其余鳍均未裁切
  - SHA-256 `2752033B252B0C82468802EBE5B54A58B97580D692B198CA00E68CBC3D6A2C2C`
- `app-ready-v2/reef-app-preview.png`：V2 合成到当前 App 珊瑚礁背景的视觉检查图，不是透明素材。

ImageGen 原图带烘焙棋盘格，因此复用 `design-concepts/fish-species/pseudanthias-bimaculatus/extract_checkerboard_alpha.py` 删除与边界连通的近白中性背景、保留鱼体连通区域、生成真实 Alpha，并对边缘做内收、柔化和去白边。最终 PNG 已检查真实透明像素、半透明边缘和珊瑚礁背景合成效果。
