# 紫吊立绘设计记录

## 范围

- 中文水族俗名：紫吊
- 中文名：紫高鳍刺尾鱼
- 学名：`Zebrasoma xanthurum`
- 素材：典型健康成鱼右向侧视 App 立绘一张
- 物种外观依据：用户提供的参考图与可追溯鱼类资料
- 风格锚点：`app/assets/aquarium/clownfish.png`
- 生成方式：Codex 内置 ImageGen；透明背景使用此前经用户明确允许的本地确定性抠图
- 当前尚未加入网页版或 Flutter App 的内置鱼种目录。

## 物种与外观依据

- Smithsonian Tropical Research Institute 的鱼类资料描述其为强侧扁圆盘体、突出长吻、高背鳍和臀鳍；头体为深蓝色、具有细灰暗条纹与头部密集斑点，尾鳍明黄：
  https://biogeodb.stri.si.edu/caribbean/en/thefishes/species/5693
- USGS 记录其体形深、背鳍和臀鳍较高、吻突出，体色为浓蓝色、带深色细条纹和头部斑点，尾鳍亮黄：
  https://nas.er.usgs.gov/queries/factsheet.aspx?speciesid=2305

用户参考图保存在 `references/user-reference.png`，其白色贴纸描边、灰色背景和水印不属于鱼体特征，未复制到最终素材。

## 最终生成约束

保持高而强侧扁的帆吊属圆盘体型、陡峭头部、突出长吻、小眼与自然小嘴；深钴蓝至紫色鱼体和高背臀鳍带大量细密深色横纹，头部保留密集小斑点，尾鳍为明亮纯黄色。以当前小丑鱼确定小眼、自然表情、轻写实动画 3D、湿润细鳞和柔和立体光照，但不复制小丑鱼体型或花纹。完整鱼体朝右，无白色外描边、文字、水印、背景或第二条鱼。

## App 素材与透明度

- `app-ready-v1/zebrasoma-xanthurum.png`
  - `1536 × 1024`
  - 32 位 RGBA PNG
  - 四角 Alpha 均为 `0`
  - 透明像素 `928,475`，半透明抗锯齿像素 `18,015`，不透明像素 `626,374`
  - Alpha 边界框 `(160, 65)–(1374, 948)`，黄尾及高背臀鳍均未裁切
  - SHA-256 `0EF6E9E332AEED10E51181AD0FE775BC3F581444E4093D1F70FE4418FE03457B`
- `app-ready-v1/reef-app-preview.png`：合成到当前 App 珊瑚礁背景的视觉检查图，不是透明素材。

ImageGen 原图带烘焙棋盘格，因此复用 `design-concepts/fish-species/pseudanthias-bimaculatus/extract_checkerboard_alpha.py` 生成真实 Alpha，并对边缘做内收、柔化和去白边。最终 PNG 已检查透明像素、半透明边缘和鱼缸合成效果。
