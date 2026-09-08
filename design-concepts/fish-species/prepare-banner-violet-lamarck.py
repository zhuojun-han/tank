"""User-authorized local extraction of three existing sprites; never overwrites raw.

Dependencies: Pillow, NumPy, opencv-python-headless 4.12.0.88.
Run from repository root. Optional local OpenCV install: artifacts/fish-python-deps.
"""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'artifacts/fish-python-deps'))
import cv2
import numpy as np
from PIL import Image, ImageOps, ImageDraw

cv2.setNumThreads(2)
BASE = ROOT / 'design-concepts/fish-species'
ART = ROOT / 'artifacts'


def fill_holes(mask):
    outside = (255 - mask).copy()
    cv2.floodFill(outside, None, (0, 0), 128)
    return np.where(outside == 128, 0, 255).astype(np.uint8)


def banner(rgb):
    # Hand-reviewed silhouette seed, with a narrow uncertain band. White face and
    # long white dorsal streamer must not be classified by gray color alone.
    points = [
        (25,131),(63,129),(128,111),(207,85),(286,62),(370,46),(459,36),
        (548,34),(644,38),(729,49),(810,68),(880,94),(938,128),(996,165),
        (1041,201),(1080,243),(1123,297),(1164,361),(1197,417),(1217,475),
        (1240,534),(1253,569),(1292,615),(1309,655),(1340,680),(1363,691),
        (1368,702),(1353,711),(1361,719),(1350,737),(1320,759),(1286,790),
        (1229,822),(1164,846),(1091,858),(1057,858),(1034,900),(1004,938),
        (962,970),(924,980),(909,977),(876,990),(857,986),(840,966),
        (830,937),(829,901),(845,864),(864,842),(820,841),(781,847),
        (734,856),(680,871),(624,878),(575,878),(529,867),(507,852),
        (499,824),(503,790),(516,752),(548,699),(581,651),
        (546,666),(514,691),(475,719),(459,721),(450,695),(442,644),
        (441,609),(447,569),(462,515),(474,475),(474,453),(486,451),
        (507,464),(540,493),(574,524),(603,543),(617,546),
        (603,513),(594,475),(597,437),(610,398),(639,350),(680,304),
        (717,277),(745,268),(775,268),(804,269),(837,264),(866,255),
        (897,243),(915,230),(918,221),(927,219),(918,208),(921,200),
        (911,193),(899,182),(876,163),(844,143),(807,127),(764,109),
        (722,94),(674,80),(626,69),(577,62),(527,59),(473,60),
        (418,66),(366,74),(311,85),(257,98),(201,114),(148,130),
        (99,140),(62,141),(39,137),
    ]
    hard = np.zeros(rgb.shape[:2], np.uint8)
    cv2.fillPoly(hard, [np.array(points, np.int32)], 255)
    seed = np.full(hard.shape, cv2.GC_BGD, np.uint8)
    expanded = cv2.dilate(hard, np.ones((15,15), np.uint8)) > 0
    seed[expanded] = cv2.GC_PR_BGD
    seed[hard > 0] = cv2.GC_PR_FGD
    seed[cv2.erode(hard, np.ones((13,13), np.uint8)) > 0] = cv2.GC_FGD
    # Keep the narrow dorsal filament anchored as foreground through the model.
    streamer = np.array([(34,132),(65,133),(124,119),(198,97),(279,75),
        (363,58),(452,47),(540,46),(633,51),(716,62),(794,80),
        (862,103),(922,136),(978,177),(1019,218)], np.int32)
    cv2.polylines(seed, [streamer], False, int(cv2.GC_FGD), 2)
    bg, fg = np.zeros((1,65),np.float64), np.zeros((1,65),np.float64)
    cv2.setRNGSeed(17)
    cv2.grabCut(cv2.cvtColor(rgb,cv2.COLOR_RGB2BGR),seed,None,bg,fg,6,cv2.GC_INIT_WITH_MASK)
    mask = np.where((seed==cv2.GC_FGD)|(seed==cv2.GC_PR_FGD),255,0).astype(np.uint8)
    # Neutral white squares can survive GrabCut beside the white dorsal streamer.
    # A hand-traced, smooth silhouette limits that edge without changing RGB.
    vertices=np.array(points,dtype=np.float64)
    curve=[]
    for index in range(len(vertices)):
        p0,p1,p2,p3=(vertices[(index+offset)%len(vertices)] for offset in [-1,0,1,2])
        for t in np.linspace(0,1,12,endpoint=False):
            curve.append(0.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
    smooth=np.zeros((rgb.shape[0]*4,rgb.shape[1]*4),np.uint8)
    cv2.fillPoly(smooth,[np.rint(np.array(curve)*4).astype(np.int32)],255)
    traced=cv2.resize(smooth,(rgb.shape[1],rgb.shape[0]),interpolation=cv2.INTER_AREA)
    mask=cv2.medianBlur(fill_holes(mask),7)
    mask=np.minimum(mask,cv2.dilate(traced,np.ones((3,3),np.uint8)))
    # This narrow neutral streamer is wholly within the inspected source fish.
    # Use its traced matte rather than alternating checker-color decisions.
    yy,xx=np.indices(mask.shape)
    top=np.array([(25,133),(50,132),(100,125),(150,110),(200,95),
        (250,80),(300,66),(350,54),(400,46),(450,40),(500,36),
        (550,34),(600,36),(650,39),(700,45),(750,55),(800,67),
        (850,84),(900,103),(930,117)],float)
    bottom=np.array([(25,133),(50,137),(100,133),(150,121),(200,107),
        (250,93),(300,81),(350,71),(400,64),(450,60),(500,57),
        (550,58),(600,60),(650,65),(700,74),(750,87),(800,106),
        (850,136),(900,176),(930,199)],float)
    # Column profiles were inspected in the source; interpolate just the matte
    # between the visible upper edge and beige lower ridge of the original fin.
    def boundary(points):
        result=np.interp(np.arange(rgb.shape[1]),points[:,0],points[:,1])
        return cv2.GaussianBlur(result.reshape(1,-1),(0,0),1.4).ravel()
    upper,lower=boundary(top),boundary(bottom)
    band=np.minimum(np.clip(yy-upper[None,:]+0.5,0,1),np.clip(lower[None,:]-yy+0.5,0,1))*255
    neutral_streamer=(yy<195)&(xx<910)
    band[:, :25]=0
    mask[neutral_streamer]=band.astype(np.uint8)[neutral_streamer]
    return mask


def violet(rgb):
    # Neutral gray checkerboard is outside-connected; colored fin rays are kept.
    colors = rgb.astype(np.int16)
    chroma = colors.max(axis=2)-colors.min(axis=2)
    mask = np.where(chroma > 14,255,0).astype(np.uint8)
    mask = cv2.morphologyEx(mask,cv2.MORPH_CLOSE,np.ones((3,3),np.uint8))
    mask = fill_holes(mask)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask)
    largest = 1 + np.argmax(stats[1:,cv2.CC_STAT_AREA])
    return np.where(labels==largest,255,0).astype(np.uint8)


def export(id, raw, method):
    source = BASE/id/'raw'/raw
    im = Image.open(source).convert('RGBA')
    rgba = np.array(im)
    if method == 'alpha':
        # Discard only nearly invisible outside residue; preserve existing matte.
        rgba[:,:,3][rgba[:,:,3] <= 3] = 0
    else:
        hard = banner(rgba[:,:,:3]) if method == 'banner' else violet(rgba[:,:,:3])
        # A subpixel edge preserves fine fin rays without a broad glow.
        rgba[:,:,3] = cv2.GaussianBlur(hard,(3,3),0.45)
    rgba[rgba[:,:,3]==0,:3] = 0
    alpha = rgba[:,:,3]
    assert np.count_nonzero(alpha>200)>100_000
    assert np.count_nonzero(alpha==0)>100_000
    clean = Image.fromarray(rgba)
    cropped = clean.crop(clean.getbbox())
    margin = max(12,round(max(cropped.size)*0.04))
    final = ImageOps.expand(cropped,border=margin,fill=(0,0,0,0))
    dest = BASE/id/'app-ready-v1'
    dest.mkdir(exist_ok=True)
    png = dest/f'{id}.png'
    final.save(png,optimize=True)
    runtime = final.copy()
    runtime.thumbnail((768,480),Image.Resampling.LANCZOS)
    web = ROOT/f'web-demo/public/fish-species/{id}.webp'
    runtime.save(web,'WEBP',quality=90,method=6)
    (ROOT/f'app/assets/aquarium/{id}.webp').write_bytes(web.read_bytes())
    panels=[]
    for color in ['#172930','#f3f6f1','#147e9b']:
        bg=Image.new('RGBA',(780,500),color)
        preview=runtime.copy();preview.thumbnail((748,468),Image.Resampling.LANCZOS)
        bg.alpha_composite(preview,((780-preview.width)//2,(500-preview.height)//2))
        panels.append(bg)
    reef=ImageOps.fit(Image.open(ROOT/'web-demo/public/aquarium/reef-tank-natural.webp'),(780,500)).convert('RGBA')
    preview=runtime.copy();preview.thumbnail((530,350),Image.Resampling.LANCZOS)
    reef.alpha_composite(preview,((780-preview.width)//2,(500-preview.height)//2))
    panels.append(reef)
    contact=Image.new('RGB',(1560,1000))
    for n,panel in enumerate(panels):contact.paste(panel,(n%2*780,n//2*500))
    contact.save(ART/f'fish-{id}-processed-preview.png')
    output=Image.open(web).convert('RGBA'); a=np.array(output)[:,:,3]
    result={'id':id,'source':source.relative_to(ROOT).as_posix(),'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'png':png.relative_to(ROOT).as_posix(),'method':method,'runtimeSize':output.size,'runtimeBytes':web.stat().st_size,
        'webpSha256':hashlib.sha256(web.read_bytes()).hexdigest(),
        'alpha':{'zero':int((a==0).sum()),'partial':int(((a>0)&(a<255)).sum()),'opaque':int((a==255).sum())}}
    return result


if __name__=='__main__':
    results=[export('bannerfish','bannerfish-v1.png','banner'),
             export('violet-anthias','violet-v1.png','chroma'),
             export('lamarck','lamarck-v1.png','alpha')]
    (ART/'fish-root-processing.json').write_text(json.dumps(results,indent=2),encoding='utf8')
    print(json.dumps(results,indent=2))
