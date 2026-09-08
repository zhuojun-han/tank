"""Reproducible local background removal, explicitly authorized 2026-09-08.
Run using bundled Python; cv2 is loaded from artifacts/fish-python-deps.
No generation or body repaint: RGB source is retained, only alpha/crop/resize change.
"""
from pathlib import Path
import hashlib, json, shutil, sys
import numpy as np
from PIL import Image, ImageDraw, ImageOps
BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
sys.path.insert(0, str(ROOT / 'artifacts/fish-python-deps'))
import cv2
cv2.setNumThreads(1)
cv2.setRNGSeed(20260908)
SPECIES = BASE.name
CONFIG = {
 'foxface': {'raw':'foxface-v1-checkerboard.png', 'protect': [[(985,275),(1094,238),(1115,297),(1182,349),(1250,408),(1458,457),(1386,485),(1244,515),(1160,596),(1090,690),(990,708),(1025,563),(974,381)]]},
 'yellow-tang': {'raw':'yellow-tang-v1.png', 'protect': []},
 'tomato-clownfish': {'raw':'tomato-clownfish-v1.png', 'protect': [[(1138,235),(1198,273),(1169,398),(1177,531),(1202,655),(1141,629),(1099,489),(1105,331)]]},
 'paracanthurus-hepatus': {'raw':'blue-tang-v1-checkerboard.png', 'protect': []},
}[SPECIES]
PARAMS = {'chroma_seed_min':12, 'closing_kernel':3, 'foreground_erosion':3,
          'unknown_dilation':7, 'grabcut_iterations':5, 'maximum_dimensions':[768,480],
          'edge_defringe_erosion_px':1, 'padding_fraction_per_edge':0.04, 'webp_quality':90, 'webp_method':6,
          'foreground_protection_polygons':CONFIG['protect']}
raw = BASE / 'raw' / CONFIG['raw']
a = np.asarray(Image.open(raw).convert('RGB'))
chroma = a.max(2).astype(np.int16)-a.min(2).astype(np.int16)
seed = (chroma > PARAMS['chroma_seed_min']).astype(np.uint8)
seed = cv2.morphologyEx(seed, cv2.MORPH_CLOSE, np.ones((3,3),np.uint8))
count, labels, stats, _ = cv2.connectedComponentsWithStats(seed,8)
seed = (labels == (1+np.argmax(stats[1:,cv2.CC_STAT_AREA]))).astype(np.uint8)
for polygon in CONFIG['protect']:
 cv2.fillPoly(seed,[np.asarray(polygon,np.int32)],1)
# Fill only enclosed gaps (eyes, pale face/band), never an exterior notch.
holes = seed.copy()
cv2.floodFill(holes,None,(0,0),1)
seed |= (holes == 0).astype(np.uint8)
outer = cv2.dilate(seed,np.ones((7,7),np.uint8))
inner = cv2.erode(seed,np.ones((3,3),np.uint8))
mask = np.full(seed.shape, cv2.GC_BGD, dtype=np.uint8)
mask[outer > 0] = cv2.GC_PR_BGD
mask[seed > 0] = cv2.GC_PR_FGD
mask[inner > 0] = cv2.GC_FGD
for polygon in CONFIG['protect']:
 cv2.fillPoly(mask,[np.asarray(polygon,np.int32)],cv2.GC_FGD)
cv2.grabCut(a,mask,None,np.zeros((1,65),np.float64),np.zeros((1,65),np.float64),5,cv2.GC_INIT_WITH_MASK)
foreground = ((mask==cv2.GC_FGD)|(mask==cv2.GC_PR_FGD)).astype(np.uint8)
# Retain the connected fish; remove isolated checker/water fragments.
_, labels, stats, _ = cv2.connectedComponentsWithStats(foreground,8)
foreground = (labels==(1+np.argmax(stats[1:,cv2.CC_STAT_AREA]))).astype(np.uint8)
holes=foreground.copy();cv2.floodFill(holes,None,(0,0),1);foreground|=(holes==0).astype(np.uint8)
# Remove one source-pixel of baked checker contamination; no RGB repaint.
foreground=cv2.erode(foreground,np.ones((3,3),np.uint8))
rgba=np.dstack([a,foreground*255])
master=Image.fromarray(rgba,'RGBA')
OUT=BASE/'app-ready-v1';OUT.mkdir(exist_ok=True)
master.save(OUT/(SPECIES+'-full-resolution.png'))
box=master.getbbox();assert box is not None
crop=master.crop(box)
padx=max(1,round(crop.width*.04));pady=max(1,round(crop.height*.04))
canvas=Image.new('RGBA',(crop.width+2*padx,crop.height+2*pady));canvas.paste(crop,(padx,pady))
canvas.thumbnail((768,480),Image.Resampling.LANCZOS)
canvas.save(OUT/(SPECIES+'.png'))
webp=OUT/(SPECIES+'.webp');canvas.save(webp,format='WEBP',quality=90,method=6,exact=True)
for folder in [ROOT/'web-demo/public/fish-species',ROOT/'app/assets/aquarium']:
 folder.mkdir(parents=True,exist_ok=True);shutil.copyfile(webp,folder/(SPECIES+'.webp'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
alpha=np.asarray(canvas)[:,:,3]
decoded=Image.open(webp).convert('RGBA')
assert decoded.size==canvas.size and np.array_equal(np.asarray(decoded)[:,:,3],alpha)
assert (alpha==0).any() and (alpha==255).any() and ((alpha>0)&(alpha<255)).any()
assert not (alpha[0].any() or alpha[-1].any() or alpha[:,0].any() or alpha[:,-1].any())
assert sha(webp)==sha(ROOT/'web-demo/public/fish-species'/(SPECIES+'.webp'))==sha(ROOT/'app/assets/aquarium'/(SPECIES+'.webp'))
metrics={'species':SPECIES,'source':str(raw.relative_to(ROOT)).replace('\\','/'),'source_sha256':sha(raw),'source_size':list(master.size),
 'source_mode':'RGB','source_alpha_bbox':list(box),'output_size':list(canvas.size),'output_alpha_bbox':list(canvas.getbbox()),
 'transparent_pixels':int((alpha==0).sum()),'opaque_pixels':int((alpha==255).sum()),'partial_alpha_pixels':int(((alpha>0)&(alpha<255)).sum()),
 'webp_bytes':webp.stat().st_size,'webp_sha256':sha(webp),'png_sha256':sha(OUT/(SPECIES+'.png')),'app_web_identical':True,'parameters':PARAMS,
 'validation_note':'Geometry/alpha checks passed; visual contact must also be inspected. Preserves source RGB within mask; opaque checkerboard removal is not recovery of physically true fin translucency.'}
(OUT/'metrics.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
ART=ROOT/'artifacts/fish-cutout-review';ART.mkdir(exist_ok=True,parents=True)
contact=Image.new('RGB',(1536,370),'white');draw=ImageDraw.Draw(contact)
reef=Image.open(ROOT/'web-demo/public/aquarium/reef-tank-natural.webp').convert('RGBA')
for i,(label,bg) in enumerate([('DARK',(15,29,35,255)),('LIGHT',(248,242,231,255)),('REEF',None)]):
 tile=ImageOps.fit(reef,(512,340)) if bg is None else Image.new('RGBA',(512,340),bg)
 fish=Image.open(webp).convert('RGBA');fish.thumbnail((490,306),Image.Resampling.LANCZOS)
 tile.alpha_composite(fish,((512-fish.width)//2,(340-fish.height)//2))
 contact.paste(tile.convert('RGB'),(i*512,30));draw.text((i*512+12,9),SPECIES+' / '+label,fill='black')
contact.save(ART/(SPECIES+'-contact.png'))
print(json.dumps(metrics,ensure_ascii=False))
