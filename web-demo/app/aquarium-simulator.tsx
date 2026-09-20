"use client";
import { type EntityId } from "./entity-id.ts";

import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type ChangeEvent,
  type CSSProperties,
  type FormEvent,
} from "react";

import {
  animatedFish,
  builtinFishArtwork,
  builtinFishSpecies,
  BUILTIN_FISH_SPECIES,
  fishCount,
  MAX_ANIMATED_FISH,
  MAX_FISH_QUANTITY,
  type BuiltinFishId,
  type FishArtwork,
  type FishStockItem,
} from "./aquarium-data";
import { prepareFishArtwork } from "./aquarium-artwork";
import { isNativeApp } from "./native-bridge";
import { isAppVisible, observeAppVisibility } from "./app-visibility";
import {
  createFishMotion,
  fishFacing,
  fishPitchDegrees,
  stepFishMotion,
  type FishDirection,
  type FishMotionState,
} from "./aquarium-motion";

type AquariumSimulatorProps = {
  tankName: string;
  stock: FishStockItem[];
  runningDays: number | null;
  onOpen: () => void;
  onManageTank: () => void;
};

type FishManagerSheetProps = {
  tankId: EntityId;
  tankName: string;
  stock: FishStockItem[];
  onClose: () => void;
  onSave: (items: FishStockItem[]) => void | Promise<void>;
};

function localDateKey() {
  const now = new Date();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${now.getFullYear()}-${month}-${day}`;
}

function introducedLabel(value: string) {
  const date = new Date(`${value}T00:00:00`);
  if (!value || Number.isNaN(date.getTime())) return "日期待填写";
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "short",
    day: "numeric",
  }).format(date);
}

function CustomArtworkImage({ src }: { src: string }) {
  // The image is a user-selected, locally compressed data URL and cannot use a build-time image loader.
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={src} alt="" />;
}

function BuiltinArtworkImage({ id }: { id: BuiltinFishId }) {
  const species = builtinFishSpecies(id);
  // Built-in transparent WebP sprites live in public/fish-species and are selected dynamically.
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={species.artworkPath} alt="" />;
}

function FishArtworkView({
  artwork,
  alt = "",
}: {
  artwork: FishArtwork;
  alt?: string;
}) {
  return <span
    className={`fish-artwork ${artwork.source === "custom" ? "custom-artwork" : "builtin-artwork"}`}
    role={alt ? "img" : undefined}
    aria-label={alt || undefined}
    aria-hidden={alt ? undefined : true}
  >
    {artwork.source === "custom"
      ? <CustomArtworkImage src={artwork.dataUrl} />
      : <BuiltinArtworkImage id={artwork.id} />}
  </span>;
}

export function AquariumSimulator({ tankName, stock, runningDays, onOpen, onManageTank }: AquariumSimulatorProps) {
  const count = fishCount(stock);
  const swimmers = useMemo(() => animatedFish(stock), [stock]);
  const waterRef = useRef<HTMLSpanElement | null>(null);
  const fishElements = useRef(new Map<string, HTMLElement>());
  const fishMotion = useRef(new Map<string, FishMotionState>());
  const fishDirections = useRef(new Map<string, FishDirection>());
  const summary = stock.length
    ? stock.map((item) => `${item.species} × ${item.quantity}`).join("、")
    : "还没有鱼，点击鱼缸添加";

  useEffect(() => {
    const water = waterRef.current;
    if (!water) return;
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
    const rect = water.getBoundingClientRect();
    let inView = rect.bottom > 0 && rect.top < window.innerHeight && rect.right > 0 && rect.left < window.innerWidth;

    let frame = 0;
    let previousTime = performance.now();
    let bounds = { width: water.clientWidth, height: water.clientHeight };
    const activeKeys = new Set(swimmers.map((fish) => fish.key));
    for (const key of fishMotion.current.keys()) {
      if (!activeKeys.has(key)) {
        fishMotion.current.delete(key);
        fishDirections.current.delete(key);
      }
    }

    const updateBounds = () => {
      bounds = { width: water.clientWidth, height: water.clientHeight };
    };
    const resizeObserver = typeof ResizeObserver === "undefined"
      ? null
      : new ResizeObserver(updateBounds);
    resizeObserver?.observe(water);
    window.addEventListener("resize", updateBounds);

    const tick = (time: number) => {
      frame = 0;
      const delta = (time - previousTime) / 1000;
      previousTime = time;

      swimmers.forEach((fish, index) => {
        const element = fishElements.current.get(fish.key);
        if (!element) return;
        const fishWidth = 38 + (index % 4) * 5;
        const motion = fishMotion.current.get(fish.key) ?? createFishMotion(
          fish.key,
          bounds,
          fishWidth,
        );
        stepFishMotion(motion, delta, bounds, fishWidth);
        fishMotion.current.set(fish.key, motion);

        const previousDirection = fishDirections.current.get(fish.key) ?? motion.direction;
        const facing = fishFacing(motion.vx, previousDirection);
        fishDirections.current.set(fish.key, facing);
        element.dataset.facing = facing > 0 ? "right" : "left";
        element.style.left = "0";
        element.style.top = "0";
        element.style.transform = `translate3d(${motion.x - fishWidth / 2}px, ${motion.y - fishWidth * 25 / 88}px, 0) rotate(${fishPitchDegrees(motion.vx, motion.vy)}deg)`;
      });

      frame = window.requestAnimationFrame(tick);
    };

    const refreshAnimation = () => {
      const visible = inView && isAppVisible() && !reducedMotion.matches;
      water.querySelectorAll<HTMLElement>(".aquarium-bubble").forEach(bubble => {
        bubble.style.animationPlayState = visible ? "running" : "paused";
      });
      if (!visible || !swimmers.length) {
        window.cancelAnimationFrame(frame);
        frame = 0;
      } else if (!frame) {
        previousTime = performance.now();
        frame = window.requestAnimationFrame(tick);
      }
    };
    const stopObserving = observeAppVisibility(refreshAnimation);
    const intersectionObserver = typeof IntersectionObserver === "undefined" ? null
      : new IntersectionObserver(entries => {
        inView = entries.some(entry => entry.isIntersecting);
        refreshAnimation();
      });
    intersectionObserver?.observe(water);
    reducedMotion.addEventListener("change", refreshAnimation);
    refreshAnimation();
    return () => {
      window.cancelAnimationFrame(frame);
      resizeObserver?.disconnect();
      intersectionObserver?.disconnect();
      stopObserving();
      reducedMotion.removeEventListener("change", refreshAnimation);
      window.removeEventListener("resize", updateBounds);
    };
  }, [swimmers]);

  return <section className="aquarium-card" aria-label={`${tankName} 的鱼缸`}>
    <div className="aquarium-heading">
      <button type="button" className="aquarium-runtime" data-testid="tank-running-days" onClick={onManageTank}>
        <small>鱼缸运行时长</small><strong>{runningDays === null ? "设置开缸日期" : `已运行 ${runningDays} 天`}</strong>
      </button>
      <button type="button" className="aquarium-edit" onClick={onOpen} aria-label={`编辑 ${tankName} 的鱼类档案；${summary}`}>编辑鱼只 ›</button>
    </div>
    <button className="aquarium-scene" type="button" onClick={onOpen} aria-label={`查看 ${tankName} 的鱼只`}>
    <span className="aquarium-water" aria-hidden="true" ref={waterRef}>
      <i className="aquarium-bubble bubble-one" />
      <i className="aquarium-bubble bubble-two" />
      <i className="aquarium-bubble bubble-three" />
      {swimmers.map((fish, index) => {
        const style = {
          "--fish-top": `${12 + ((index * 23) % 58)}%`,
          "--fish-left": `${12 + ((index * 31) % 70)}%`,
          "--fish-size": `${38 + (index % 4) * 5}px`,
        } as CSSProperties;
        return <i
          className="aquarium-fish"
          data-facing={index % 2 ? "left" : "right"}
          style={style}
          key={fish.key}
          ref={(node) => {
            if (node) fishElements.current.set(fish.key, node);
            else fishElements.current.delete(fish.key);
          }}
        ><FishArtworkView artwork={fish.artwork} /></i>;
      })}
    </span>
    <span className="aquarium-summary">
      <span>{summary}</span>
      {count > MAX_ANIMATED_FISH && <small>动画最多展示 {MAX_ANIMATED_FISH} 条，档案数量已全部保存</small>}
    </span>
    </button>
  </section>;
}

export function FishManagerSheet({
  tankId,
  tankName,
  stock,
  onClose,
  onSave,
}: FishManagerSheetProps) {
  const [draft, setDraft] = useState(() => stock.map((item) => ({ ...item })));
  const [addMode, setAddMode] = useState<"builtin" | "custom">("builtin");
  const [selectedBuiltinIds, setSelectedBuiltinIds] = useState<BuiltinFishId[]>([]);
  const [newSpecies, setNewSpecies] = useState("");
  const [newQuantity, setNewQuantity] = useState(1);
  const [newDate, setNewDate] = useState(localDateKey);
  const [newArtworkDataUrl, setNewArtworkDataUrl] = useState("");
  const [processingArtworkId, setProcessingArtworkId] = useState<EntityId>("");
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const [addedFeedback, setAddedFeedback] = useState("");
  useEffect(() => {
    if (!addedFeedback) return;
    const timeout = window.setTimeout(() => setAddedFeedback(""), 3000);
    return () => window.clearTimeout(timeout);
  }, [addedFeedback]);
  const savePending = useRef(false);
  const artworkRequest = useRef<AbortController | null>(null);
  useEffect(() => () => artworkRequest.current?.abort(), []);

  function updateItem(id: EntityId, patch: Partial<FishStockItem>) {
    setDraft((items) => items.map((item) => item.id === id ? { ...item, ...patch } : item));
  }

  async function readArtwork(
    event: ChangeEvent<HTMLInputElement>,
    destination: EntityId,
  ) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    artworkRequest.current?.abort();
    const controller = new AbortController();
    artworkRequest.current = controller;
    setProcessingArtworkId(destination);
    setError("");
    try {
      const dataUrl = await prepareFishArtwork(file, controller.signal);
      if (controller.signal.aborted || artworkRequest.current !== controller) return;
      if (destination === "new") {
        setNewArtworkDataUrl(dataUrl);
      } else {
        updateItem(destination, { artwork: { source: "custom", dataUrl } });
      }
    } catch (reason) {
      if (!controller.signal.aborted && artworkRequest.current === controller) {
        setError(reason instanceof Error ? reason.message : "立绘处理失败，请换一张图片。");
      }
    } finally {
      if (!controller.signal.aborted && artworkRequest.current === controller) {
        artworkRequest.current = null;
        setProcessingArtworkId("");
      }
    }
  }

  function addSpecies() {
    setAddedFeedback("");
    const additions: { species: string; artwork: FishArtwork }[] = addMode === "builtin"
      ? BUILTIN_FISH_SPECIES.filter(item => selectedBuiltinIds.includes(item.id)).map(item => ({ species: item.name, artwork: builtinFishArtwork(item.id) }))
      : [{ species: newSpecies.trim(), artwork: { source: "custom", dataUrl: newArtworkDataUrl } }];
    if (!additions.length || additions.some(item => !item.species)) {
      setError(addMode === "builtin" ? "请先选择鱼种。" : "请填写鱼的品种。");
      return;
    }
    if (additions.some(item => draft.some(existing => existing.species.toLowerCase() === item.species.toLowerCase()))) {
      setError("所选鱼种已在列表中，请直接修改数量或取消该鱼种后再加入。");
      return;
    }
    if (!Number.isInteger(newQuantity) || newQuantity < 1 || newQuantity > MAX_FISH_QUANTITY) {
      setError(`数量必须在 1–${MAX_FISH_QUANTITY} 之间。`);
      return;
    }
    if (!newDate) {
      setError("请选择入缸日期。");
      return;
    }
    if (addMode === "custom" && !newArtworkDataUrl) {
      setError("请为自定义鱼种上传立绘。");
      return;
    }
    setDraft((items) => [...items, ...additions.map(({ species, artwork }, index) => ({
      id: isNativeApp() ? crypto.randomUUID() : `fish-${tankId}-${Date.now()}-${items.length + index}`,
      tankId,
      species: species.slice(0, 24),
      quantity: newQuantity,
      introducedOn: newDate,
      artwork,
    }))]);
    setNewSpecies("");
    setNewQuantity(1);
    setNewDate(localDateKey());
    setNewArtworkDataUrl("");
    setError("");
    setSelectedBuiltinIds([]);
    setAddedFeedback(`✓ 已加入 ${additions.length} 种鱼，保存后生效`);
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (savePending.current || processingArtworkId) return;
    const normalized = draft.map((item) => ({
      ...item,
      species: item.species.trim().slice(0, 24),
      quantity: Math.floor(Number(item.quantity)),
    }));
    if (normalized.some((item) => !item.species || item.quantity < 1 || item.quantity > MAX_FISH_QUANTITY || !item.introducedOn)) {
      setError(`请检查品种、入缸日期和 1–${MAX_FISH_QUANTITY} 的数量。`);
      return;
    }
    const names = normalized.map((item) => item.species.toLowerCase());
    if (new Set(names).size !== names.length) {
      setError("同一品种只保留一条档案，请合并数量。");
      return;
    }
    savePending.current = true;
    setSaving(true);
    setError("");
    try { await onSave(normalized); }
    catch (caught) { setError(caught instanceof Error ? caught.message : "暂时无法保存，请重试。"); }
    finally { savePending.current = false; setSaving(false); }
  }

  return <form className="sheet fish-manager-sheet" onSubmit={submit} onMouseDown={(event) => event.stopPropagation()}>
    <div className="sheet-handle" />
    <div className="section-head"><div><p className="eyebrow">{tankName}</p><h2>鱼类档案</h2></div><button aria-label="关闭" type="button" className="icon-button close-button" disabled={saving} onClick={onClose}>×</button></div>
    <fieldset disabled={saving} style={{ border: 0, padding: 0, margin: 0, minWidth: 0 }}>
    <p className="form-hint">选择鱼种、数量和入缸日期；也可添加自定义鱼种。</p>
    <div className="fish-stock-editor">
      {draft.map((item) => <article key={item.id}>
        <div className="fish-stock-title"><span className="fish-stock-icon"><FishArtworkView artwork={item.artwork} alt={`${item.species}立绘`} /></span><strong>{item.species || "未命名品种"}</strong><button type="button" onClick={() => setDraft((items) => items.filter((entry) => entry.id !== item.id))}>删除</button></div>
        <label className="field">鱼的品种<input value={item.species} maxLength={24} required onChange={(event) => updateItem(item.id, { species: event.target.value })} /></label>
        <div className="field-row"><label>数量<input type="number" min="1" max={MAX_FISH_QUANTITY} required value={item.quantity} onChange={(event) => updateItem(item.id, { quantity: Number(event.target.value) })} /></label><label>入缸日期<input type="date" required value={item.introducedOn} onChange={(event) => updateItem(item.id, { introducedOn: event.target.value })} /></label></div>
        {(item.artwork.source === "custom" || item.species !== "小丑鱼") && <label className="replace-artwork">{processingArtworkId === item.id ? "正在处理立绘…" : "更换该鱼种立绘"}<input type="file" accept="image/png,image/jpeg,image/webp" disabled={Boolean(processingArtworkId)} onChange={(event) => void readArtwork(event, item.id)} /></label>}
        <small className="introduced-label">入缸：{introducedLabel(item.introducedOn)}</small>
      </article>)}
      {!draft.length && <div className="fish-stock-empty">当前还没有鱼类档案，可在下方添加。</div>}
    </div>
    <section className="add-fish-species">
      <strong>添加鱼的品种</strong>
      <div className="fish-add-mode" role="tablist" aria-label="鱼种来源"><button type="button" role="tab" aria-selected={addMode === "builtin"} className={addMode === "builtin" ? "active" : ""} onClick={() => { setAddMode("builtin"); setError(""); }}>选择内置鱼种</button><button type="button" role="tab" aria-selected={addMode === "custom"} className={addMode === "custom" ? "active" : ""} onClick={() => { setAddMode("custom"); setError(""); }}>添加其他鱼种</button></div>
      {addMode === "builtin" ? <div className="fish-species-catalog">
        {BUILTIN_FISH_SPECIES.map((species) => <button key={species.id} type="button" className={selectedBuiltinIds.includes(species.id) ? "selected" : ""} aria-pressed={selectedBuiltinIds.includes(species.id)} onClick={() => { setSelectedBuiltinIds(ids => ids.includes(species.id) ? ids.filter(id => id !== species.id) : [...ids, species.id]); setAddedFeedback(""); setError(""); }}><span><FishArtworkView artwork={builtinFishArtwork(species.id)} alt={`${species.name}立绘`} /></span><div><strong>{species.name}</strong><small>{species.note}</small></div><b>{selectedBuiltinIds.includes(species.id) ? "已选择 ✓" : "选择"}</b></button>)}
      </div> : <div className="custom-fish-builder">
        <label className="field">鱼种名称<input value={newSpecies} maxLength={24} placeholder="例如：蓝吊" onChange={(event) => setNewSpecies(event.target.value)} /></label>
        <label className={`artwork-upload ${newArtworkDataUrl ? "has-preview" : ""}`}>
          {newArtworkDataUrl ? <FishArtworkView artwork={{ source: "custom", dataUrl: newArtworkDataUrl }} alt="自定义鱼种立绘预览" /> : <span className="artwork-placeholder">＋</span>}
          <span><strong>{processingArtworkId === "new" ? "正在压缩立绘…" : newArtworkDataUrl ? "重新选择立绘" : "上传鱼的立绘"}</strong><small>PNG、JPG 或 WebP，原图不超过 8 MB；鱼头朝右、透明背景效果最好</small></span>
          <input type="file" accept="image/png,image/jpeg,image/webp" disabled={Boolean(processingArtworkId)} onChange={(event) => void readArtwork(event, "new")} />
        </label>
      </div>}
      <div className="field-row"><label>{addMode === "builtin" ? "每种数量" : "数量"}<input type="number" min="1" max={MAX_FISH_QUANTITY} value={newQuantity} onChange={(event) => setNewQuantity(Number(event.target.value))} /></label><label>入缸日期<input type="date" value={newDate} onChange={(event) => setNewDate(event.target.value)} /></label></div>
      <button className={`soft-button wide fish-add-button${addedFeedback ? " is-added" : ""}`} type="button" disabled={Boolean(processingArtworkId)} onClick={addSpecies}><span aria-live="polite">{addedFeedback || (addMode === "builtin" && selectedBuiltinIds.length ? `＋ 加入 ${selectedBuiltinIds.length} 种鱼` : "＋ 加入鱼类档案")}</span></button>
    </section>
    {error && <p className="calculation-error" role="alert">{error}</p>}
    <button className="primary-button wide" type="submit" disabled={saving || Boolean(processingArtworkId)}>{saving ? "保存中…" : "保存鱼类档案"}</button>
    </fieldset>
  </form>;
}
