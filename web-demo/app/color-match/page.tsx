"use client";

import { useEffect, useEffectEvent, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { compareColors, cssColor, TEMPLATE, LEVELS, pickSwatches, SAMPLE_CARD, SAMPLE_LIQUID, sampleRegion, validRect, type Pixels, type Rect, type Swatch } from './color-analysis';
import './styles.css';
import { PO4_LEVELS, PO4_UPRIGHT, PO4_SAMPLES } from '../po4-color-match/samples';
import { ResultSummary } from './result-summary';
import { checkImageDimensions, fitImageDimensions, inspectImageFile, loadImageElement, releaseImage } from '../image-input';
import { isNativeApp } from '../native-bridge';
import { useNativeDraft } from '../native-drafts';
import { cacheNativePhoto, isNativePhotoDraft, removeNativePhoto, type NativePhotoDraft } from './native-photo-draft';
import type { EntityId } from '../entity-id';

export type PhotoReview = { parameterId?: "no3" | "po4"; low: number; high: number; interpolation: number | null; source: string; algorithmVersion: string };
export default function ColorMatchPage() { return <ColorMatchPanel onReview={review => {
  const state = JSON.parse(localStorage.getItem('reef-demo-state-v10') ?? '{}');
  sessionStorage.setItem('reef-photo-review', JSON.stringify({ review, tankId: state.tankId ?? null }));
  // eslint-disable-next-line @next/next/no-location-assign-relative-destination -- The session handoff must load the home page and its tank state together.
  window.location.assign('/');
}} />; }
export function ColorMatchPanel({ onReview, onClose, parameterId = "no3", tankId }: { tankId?: EntityId; parameterId?: "no3" | "po4"; onReview?: (review: PhotoReview) => void | Promise<void>; onClose?: () => void }) {
  const native = isNativeApp();
  const po4 = parameterId === 'po4';
  const example = po4 ? '/po4/3.jpg' : '/no3-sample.jpg';
  const initialCard = po4 ? PO4_SAMPLES[2].card : SAMPLE_CARD;
  const initialLiquid = po4 ? PO4_SAMPLES[2].liquid : SAMPLE_LIQUID;
  const template = po4 ? PO4_UPRIGHT : TEMPLATE;
  const [src, setSrc] = useState(native ? '' : example);
  const [displaySrc, setDisplaySrc] = useState(native ? '' : example);
  const [rotation, setRotation] = useState(0);
  const [imageVersion, setImageVersion] = useState(0);
  const [pixels, setPixels] = useState<Pixels>();
  const [card, setCard] = useState<Rect>(initialCard);
  const [liquid, setLiquid] = useState<Rect>(initialLiquid);
  const [swatches, setSwatches] = useState<Swatch[]>([]);
  const [mode, setMode] = useState(native ? 'card' : 'liquid');
  const [draft, setDraft] = useState<Rect>();
  const [error, setError] = useState('');
  const [result, setResult] = useState<ReturnType<typeof compareColors>>();
  const resultLiquidColor = useMemo(() => result && pixels
    ? cssColor(sampleRegion(pixels, liquid).rgb) : undefined, [result, pixels, liquid]);
  const [sampleName, setSampleName] = useState(native ? '' : '你提供的同框示例');
  const [busy, setBusy] = useState(!native);
  const [liquidReady, setLiquidReady] = useState(!native);
  const [cardReady, setCardReady] = useState(!native);
  const [nativePhoto, setNativePhoto] = useState<{ photoToken: string; photoUrl: string } | null>(null);
  const [leaving, setLeaving] = useState(false);
  const leavePending = useRef(false);
  const pendingRestore = useRef<NativePhotoDraft | null>(null);
  const photoUpload = useRef<AbortController | null>(null);
  const retainedDraft = useMemo<NativePhotoDraft | null>(() => nativePhoto && typeof tankId === 'string' ? {
    tankId, parameterId, ...nativePhoto, rotation, card, liquid, cardReady, liquidReady,
    swatchRects: swatches.map(swatch => swatch.rect), compared: Boolean(result), mode, sourceName: sampleName.slice(0, 512),
  } : null, [nativePhoto, tankId, parameterId, rotation, card, liquid, cardReady, liquidReady, swatches, result, mode, sampleName]);
  const savedDraft = useNativeDraft<NativePhotoDraft>({ section: 'photo', value: retainedDraft, enabled: native, suspendWrites: busy,
    restore: candidate => {
      if (!isNativePhotoDraft(candidate)) throw new Error('上次照片草稿无法读取，请重新选择照片。');
      if (candidate.tankId !== tankId || candidate.parameterId !== parameterId) {
        void removeNativePhoto(candidate).catch(() => {});
        return;
      }
      pendingRestore.current = candidate;
      setNativePhoto({ photoToken: candidate.photoToken, photoUrl: candidate.photoUrl });
      setRotation(candidate.rotation); setCard(candidate.card); setLiquid(candidate.liquid);
      setCardReady(candidate.cardReady); setLiquidReady(candidate.liquidReady); setMode(candidate.mode); setSampleName(candidate.sourceName);
      setSrc(candidate.photoUrl); setBusy(true);
    },
  });
  const start = useRef<{ x: number; y: number } | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const cameraRef = useRef<HTMLInputElement>(null);
  const uploadVersion = useRef(0);
  useEffect(() => () => { uploadVersion.current++; photoUpload.current?.abort(); }, []);
  useEffect(() => {
    if (!src) return;
    const controller = new AbortController();
    let img: HTMLImageElement | undefined;
    const canvas = document.createElement('canvas');
    void (async () => {
      try {
        img = await loadImageElement(src, controller.signal);
        controller.signal.throwIfAborted();
        checkImageDimensions(img.naturalWidth, img.naturalHeight);
        const { width: w, height: h } = fitImageDimensions(img.naturalWidth, img.naturalHeight, 1600);
        canvas.width = rotation % 180 ? h : w; canvas.height = rotation % 180 ? w : h;
        const ctx = canvas.getContext('2d', { willReadFrequently: true });
        if (!ctx) throw new Error('浏览器无法读取图片像素。');
        ctx.translate(canvas.width / 2, canvas.height / 2);
        ctx.rotate(rotation * Math.PI / 180);
        ctx.drawImage(img, -w / 2, -h / 2, w, h);
        const nextPixels = ctx.getImageData(0, 0, canvas.width, canvas.height);
        releaseImage(img); img = undefined;
        const blob = await new Promise<Blob>((resolve, reject) => canvas.toBlob(value => value ? resolve(value) : reject(new Error('图片处理失败，请重试。')), 'image/png'));
        controller.signal.throwIfAborted();
        setDisplaySrc(URL.createObjectURL(blob));
        setPixels(nextPixels);
        const restored = pendingRestore.current;
        if (restored) {
          pendingRestore.current = null;
          if (restored.swatchRects.length === 8) {
            const nextSwatches = pickSwatches(nextPixels, restored.card, template, 4)
              .map((swatch, index) => ({ ...swatch, rect: restored.swatchRects[index], sample: sampleRegion(nextPixels, restored.swatchRects[index]) }));
            setSwatches(nextSwatches);
            if (restored.compared && restored.liquidReady) setResult(compareColors(sampleRegion(nextPixels, restored.liquid), nextSwatches, po4 ? PO4_LEVELS : LEVELS, po4 ? .25 : 10));
          }
        }
      } catch (reason) {
        if (!controller.signal.aborted) {
          setPixels(undefined);
          setError(reason instanceof Error ? reason.message : '图片处理失败，请重试。');
        }
      } finally {
        if (img) releaseImage(img);
        canvas.width = 0; canvas.height = 0;
        if (!controller.signal.aborted) setBusy(false);
      }
    })();
    return () => { controller.abort(); };
  }, [src, rotation, imageVersion, template, po4]);
  useEffect(() => () => {if(src.startsWith('blob:')) URL.revokeObjectURL(src);}, [src]);
  useEffect(() => () => {if(displaySrc.startsWith('blob:')) URL.revokeObjectURL(displaySrc);}, [displaySrc]);
  const invalidate = () => { setResult(undefined); setError(''); };
  const position = (e: React.PointerEvent<HTMLDivElement>) => {
    const r = e.currentTarget.getBoundingClientRect();
    return { x: Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)), y: Math.max(0, Math.min(1, (e.clientY - r.top) / r.height)) };
  };
  const makeRect = (p: { x: number; y: number }): Rect => ({ x: Math.min(start.current!.x, p.x), y: Math.min(start.current!.y, p.y), w: Math.abs(start.current!.x - p.x), h: Math.abs(start.current!.y - p.y) });
  function finish(e: React.PointerEvent<HTMLDivElement>) {
    if (!start.current) return;
    const rect = makeRect(position(e)); start.current = null; setDraft(undefined);
    if (!validRect(rect)) { setError('请拖出一个有效矩形，不要只点一下。'); return; }
    invalidate();
    if (mode === 'liquid') { setLiquid(rect); setLiquidReady(true); }
    else if (mode === 'card') { setCard(rect); setCardReady(true); setSwatches([]); }
    else if (pixels) {
      try { const sample = sampleRegion(pixels, rect); setSwatches(old => old.map((s, i) => i === Number(mode) ? { ...s, rect, sample } : s)); }
      catch (e) { setError(String(e)); }
    }
  }
  function extract() {
    invalidate(); setSwatches([]);
    try { if (pixels) setSwatches(pickSwatches(pixels, card, template, 4)); }
    catch (e) { setError(String(e)); }
  }
  function compare() {
    setError(''); setResult(undefined);
    try { if (pixels) setResult(compareColors(sampleRegion(pixels, liquid), swatches, po4 ? PO4_LEVELS : LEVELS, po4 ? .25 : 10)); }
    catch (e) { setError(String(e)); }
  }
  function loadExample() {
    if (native) return;
    setPixels(undefined); setBusy(true); setImageVersion(value => value + 1);
    invalidate(); setRotation(0); setSwatches([]); setCard(initialCard); setLiquid(initialLiquid);
    setLiquidReady(true); setCardReady(true); setSrc(example); setSampleName('你提供的同框示例'); setMode('liquid');
  }
  function rotate(delta: number) {
    invalidate(); setSwatches([]); setPixels(undefined); setBusy(true);
    setCardReady(false); setLiquidReady(false); setMode('card'); setDraft(undefined); start.current=null;
    setRotation(value=>(value+delta+360)%360);
  }
  async function selectPhoto(file: File) {
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type) || file.size <= 0 || file.size > 15 * 1024 * 1024) { setError('请选择 15 MB 以内的 JPG、PNG 或 WebP 图片。'); return; }
    const version = ++uploadVersion.current;
    photoUpload.current?.abort();
    const upload = new AbortController(); photoUpload.current = upload;
    invalidate(); setBusy(true);
    try {
      await inspectImageFile(file);
      if (version !== uploadVersion.current) return;
      let nextSrc: string;
      if (native) {
        if (typeof tankId !== 'string') throw new Error('请先选择海缸，再拍照检测。');
        const photo = await cacheNativePhoto(file, tankId, upload.signal);
        if (version !== uploadVersion.current) { await removeNativePhoto({ tankId, photoToken: photo.photoToken }); return; }
        setNativePhoto(photo); nextSrc = photo.photoUrl;
      } else nextSrc = URL.createObjectURL(file);
      pendingRestore.current = null;
      setRotation(0); setSwatches([]); setPixels(undefined); setDisplaySrc(''); setLiquidReady(false); setCardReady(false); setMode('card'); setSampleName(file.name); setSrc(nextSrc);
    } catch (reason) {
      if (version === uploadVersion.current) {
        setError(reason instanceof Error ? reason.message : '图片无法读取。');
        setBusy(false);
      }
    }
  }
  function onPhotoInput(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (file) void selectPhoto(file);
  }
  async function leave(action: () => void | Promise<void>) {
    if (leavePending.current) return;
    leavePending.current = true;
    setLeaving(true);
    try {
      photoUpload.current?.abort();
      await savedDraft.clear();
      if (nativePhoto && typeof tankId === 'string') await removeNativePhoto({ tankId, photoToken: nativePhoto.photoToken });
      await action();
    } catch (caught) { leavePending.current = false; setError(caught instanceof Error ? caught.message : '暂时无法关闭，请重试。'); setLeaving(false); }
  }
  const back = useEffectEvent(() => { if (onClose) void leave(onClose); });
  useEffect(() => {
    window.addEventListener('lanjiao:photo-back', back);
    return () => window.removeEventListener('lanjiao:photo-back', back);
  }, []);
  const box = (rect: Rect, label: string, className: string) => <span key={label} className={`cm-box ${className}`} style={{ left: `${rect.x * 100}%`, top: `${rect.y * 100}%`, width: `${rect.w * 100}%`, height: `${rect.h * 100}%` }}><b>{label}</b></span>;
  return <main className="cm">
    <header>{onClose ? <button disabled={leaving} onClick={() => void leave(onClose)}>不记录，返回检测</button> : <Link href="/">← 返回海缸助手</Link>}<span className="cm-pill">{po4 ? "PO₄" : "NO₃"}</span></header>
    <section className="cm-intro"><h1>拍照比色</h1><p>选照片 → 框选 → 比较 → 确认记录</p></section>
    <div className="cm-layout"><section className="cm-panel">
      <div className="cm-actions">{!native && <button disabled={busy} onClick={loadExample}>使用你的示例照片</button>}{native && <button disabled={busy || leaving || !savedDraft.ready} onClick={() => cameraRef.current?.click()}>拍照</button>}<button disabled={busy || leaving || !savedDraft.ready} onClick={() => fileRef.current?.click()}>{native ? '从相册选择' : '选择照片 / 拍照'}</button></div>
      <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp" hidden disabled={busy || leaving || !savedDraft.ready} onChange={onPhotoInput} />
      {native && <input ref={cameraRef} type="file" accept="image/jpeg,image/png,image/webp" capture="environment" hidden disabled={busy || leaving || !savedDraft.ready} onChange={onPhotoInput} />}

      {src && <><div className="cm-actions"><button disabled={busy || !pixels} onClick={()=>rotate(-90)}>↶ 逆时针90°</button><button disabled={busy || !pixels} onClick={()=>rotate(90)}>↷ 顺时针90°</button></div>
      <p className="cm-hint">色卡文字朝上、两行四列。旋转后需重新框选。</p>
      <label className="cm-mode">拖动照片时调整<select value={mode} onChange={e => setMode(e.target.value)}><option value="liquid">① 测试液区域</option><option value="card">② 全部八个色块区域</option>{swatches.map((s, i) => <option key={i} value={i}>色块 {i + 1} · {s.level} mg/L</option>)}</select></label>
      </>}
      {displaySrc ? <div className="cm-photo" aria-label="照片框选区域" onPointerDown={e => { if (!pixels) return; e.currentTarget.setPointerCapture(e.pointerId); start.current = position(e); setDraft(undefined); }} onPointerMove={e => { if (start.current) setDraft(makeRect(position(e))); }} onPointerUp={finish} onPointerCancel={() => { start.current = null; setDraft(undefined); }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={displaySrc} data-rotation={rotation} alt="待比色的测试液和益尔色卡" draggable={false} />
        {cardReady && box(card, '色卡', 'card')}{liquidReady && box(liquid, '测试液', 'liquid')}
        {swatches.map((s, i) => box(s.rect, `${s.level} · ${i + 1}`, 'swatch'))}{draft && box(draft, '选区', 'draft')}
      </div> : <p className="cm-hint" role="status">{busy ? '正在读取照片…' : '拍下测试液和色卡，或从相册选择照片。'}</p>}
      {src && <p className="cm-hint">框住全部8个色块；液体选均匀处，避开反光和瓶壁。</p>}
    </section><aside>
      <section className="cm-panel"><h2>检查取色</h2>
        <button className="cm-primary" disabled={!pixels || !cardReady || busy} onClick={extract}>按模板自动取色</button>
        {swatches.length > 0 && <><div className="cm-swatches">{swatches.map((s, i) => <button key={i} className={mode === String(i) ? 'selected' : ''} onClick={() => setMode(String(i))}><span style={{ background: cssColor(s.sample.rgb) }} /><strong>{s.level}</strong><small>调整 #{i + 1}</small></button>)}</div><p className="cm-hint">点色块可重新框选。</p></>}
      </section>
      <section className="cm-panel"><h2>比色结果</h2><button className="cm-primary" disabled={busy || !pixels || !liquidReady || swatches.length !== 8} onClick={compare}>比较颜色并给出范围</button>
        {error && <p role="alert" className="cm-error">{error}</p>}
        {savedDraft.error && <p role="alert" className="cm-error">草稿暂未保留：{savedDraft.error}</p>}
        {result && <div aria-live="polite" data-testid="comparison-result"><ResultSummary result={result} decimals={0} /><details className="cm-diagnostics"><summary>查看取色详情</summary>{resultLiquidColor && <p className="cm-liquid-color"><i style={{ background: resultLiquidColor }} />本次测试液取色</p>}<h3>与测试液的颜色差异</h3><ol className="cm-rank">{result.ranked.map(r => <li key={r.level}><i style={{ background: cssColor(r.rgb) }} /><span>{r.level} mg/L</span><small>色差 {r.delta.toFixed(1)}</small></li>)}</ol></details></div>}
        {onReview && result?.range && <button className="cm-primary" disabled={leaving} onClick={() => void leave(() => onReview({ parameterId, low: result.range![0], high: result.range![1], interpolation: result.interpolatedValue === null ? null : Number(result.interpolatedValue.toFixed(3)), source: sampleName, algorithmVersion: po4 ? 'po4-web-test-3' : 'eal-no3-mvp-4' }))}>修改结果并选择是否记录</button>}
        {onClose && <button disabled={leaving} onClick={() => void leave(onClose)}>本次不记录</button>}
      </section>

    </aside></div>
  </main>;
}
