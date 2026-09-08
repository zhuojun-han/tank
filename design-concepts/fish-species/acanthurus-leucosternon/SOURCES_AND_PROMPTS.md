# 粉蓝吊立绘设计记录

## 范围

- 中文水族俗名：粉蓝吊、粉蓝倒吊
- 中文名：白胸刺尾鱼
- 学名：`Acanthurus leucosternon`
- 素材：典型健康成鱼右向侧视 App 立绘一张
- 物种外观依据：用户提供的实物照片与可追溯鱼类资料
- 风格锚点：`app/assets/aquarium/clownfish.png`
- 生成方式：Codex 内置 ImageGen；透明背景使用此前经用户明确允许的本地确定性抠图
- 当前尚未加入网页版或 Flutter App 的内置鱼种目录。

## 物种与外观依据

- 台湾鱼类资料库将“粉蓝倒吊”对应为 `Acanthurus leucosternon`，并描述其为侧扁椭圆体、深蓝黑头、宝蓝体侧、白色喉胸斑、黄色背鳍和浅色黑边尾鳍：
  https://fishdb.sinica.edu.tw/chi/importpic_2013.php?id=180
- 日本国立科学博物馆的安达曼海鱼类资料描述其体高而侧扁、黑头、蓝体、宽白胸带、黄色背鳍和尾柄，以及带黑边的浅色尾鳍：
  https://www.kahaku.go.jp/research/db/zoology/Fishes_of_Andaman_Sea/contents/acanthuridae/02.html
- WoRMS 确认接受学名为 `Acanthurus leucosternon`：
  https://www.marinespecies.org/aphia.php?id=219628&p=taxdetails

用户实物照片保存在 `references/user-reference.png`，只作为物种外形、颜色分区和背鳍轮廓参考，未复制照片中的人手、黑色背景或模糊细节。

## 最终生成约束

保持刺尾鱼属较修长的侧扁椭圆体型、小眼、自然小嘴、连续背鳍、低长臀鳍和带尾柄棘的黄色尾柄；鱼体为粉蓝至宝蓝色，黑脸、白胸，背鳍鲜黄并带黑色次边线和浅蓝外缘，尾鳍为浅蓝白色并带粗黑边及细蓝外缘。以当前小丑鱼确定轻写实动画 3D、湿润细鳞和柔和立体光照，但不复制小丑鱼体型或花纹。完整鱼体朝右，无文字、水印、背景或第二条鱼。

用户要求黄色上背鳍更圆润饱满，因此 V2 将背鳍膜面积增大约四分之一，形成连续凸圆弧线，同时保留黑色次边线、浅蓝外缘和其余鱼体色块。V1 完整保留，当前推荐 V2。

## App 素材与透明度

- `app-ready-v1/acanthurus-leucosternon.png`：第一版透明素材，背鳍较薄，保留用于回退。
- `app-ready-v2/acanthurus-leucosternon.png`（当前推荐候选）
  - `1536 × 1024`
  - 32 位 RGBA PNG
  - 四角 Alpha 均为 `0`
  - 透明像素 `916,972`，半透明抗锯齿像素 `18,847`，不透明像素 `637,045`
  - Alpha 边界框 `(90, 121)–(1440, 893)`，饱满背鳍、尾鳍和腹侧各鳍均未裁切
  - SHA-256 `78D18357DF27B3494B78F7068576103771DDB960D851BDD7CBD6D2F0842A15B7`
- `app-ready-v2/reef-app-preview.png`：V2 合成到当前 App 珊瑚礁背景的视觉检查图，不是透明素材。

ImageGen 原图带烘焙棋盘格，因此复用 `design-concepts/fish-species/pseudanthias-bimaculatus/extract_checkerboard_alpha.py` 生成真实 Alpha，并对边缘做内收、柔化和去白边。最终 PNG 已检查透明像素、半透明边缘和鱼缸合成效果。
