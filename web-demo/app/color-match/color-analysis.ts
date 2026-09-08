// Original MVP implementation. Reference methods and limitations:
// docs/coordination/color-match-mvp.md. No third-party code copied.
export type Rect = { x: number; y: number; w: number; h: number };
export type RGB = [number, number, number];
export type Pixels = { width: number; height: number; data: Uint8ClampedArray };
export type Sample = { rgb: RGB; spread: number; rejected: number; count: number };
export type Swatch = { level: number; rect: Rect; sample: Sample };
export const LEVELS = [0, 1, 5, 10, 25, 50, 100];
export const TEMPLATE = [100, 50, 25, 10, 10, 5, 1, 0];
export const NO3_ORIENTATIONS = {
  '0': { label: '正向 · 两行四列', columns: 4, template: TEMPLATE },
  '90': { label: '顺时针旋转90° · 四行两列', columns: 2, template: [10, 100, 5, 50, 1, 25, 0, 10] },
  '180': { label: '倒置180° · 两行四列', columns: 4, template: [0, 1, 5, 10, 10, 25, 50, 100] },
  '270': { label: '逆时针旋转90° · 四行两列', columns: 2, template: [10, 0, 25, 1, 50, 5, 100, 10] },
};
export const SAMPLE_CARD: Rect = { x: 0, y: 0.592, w: 0.705, h: 0.195 };
export const SAMPLE_LIQUID: Rect = { x: 0.439, y: 0.522, w: 0.038, h: 0.058 };

export function validRect(r: Rect) {
  return Object.values(r).every(Number.isFinite) && r.x >= 0 && r.y >= 0 && r.w >= .006 && r.h >= .006 && r.x + r.w <= 1.00001 && r.y + r.h <= 1.00001;
}
const median = (v: number[]) => [...v].sort((a, b) => a - b)[Math.floor(v.length / 2)] ?? 0;
export function sampleRegion(image: Pixels, rect: Rect): Sample {
  if (!validRect(rect)) throw new Error('选区太小或超出照片，请重新框选。');
  const colors: RGB[] = [];
  let total = 0;
  const stride = Math.max(1, Math.floor(Math.sqrt(rect.w * image.width * rect.h * image.height / 1600)));
  for (let y = Math.floor(rect.y * image.height); y < Math.min(image.height, Math.ceil((rect.y + rect.h) * image.height)); y += stride) {
    for (let x = Math.floor(rect.x * image.width); x < Math.min(image.width, Math.ceil((rect.x + rect.w) * image.width)); x += stride) {
      const i = (y * image.width + x) * 4;
      const rgb: RGB = [image.data[i], image.data[i + 1], image.data[i + 2]];
      total++;
      // Reject dark frame/shadow and clipped highlights; not a glare detector.
      if (Math.max(...rgb) < 25 || Math.max(...rgb) > 250 || image.data[i + 3] < 250) continue;
      colors.push(rgb);
    }
  }
  if (colors.length < 16) throw new Error('有效颜色像素不足，请避开黑框、高光和过小选区。');
  const rgb = [0, 1, 2].map(c => median(colors.map(p => p[c]))) as RGB;
  const center = toLab(rgb);
  return { rgb, count: colors.length, rejected: 1 - colors.length / total, spread: median(colors.map(p => distance(toLab(p), center))) };
}

export function toLab(rgb: RGB): RGB {
  const [r, g, b] = rgb.map(v => { const n = v / 255; return n <= .04045 ? n / 12.92 : ((n + .055) / 1.055) ** 2.4; });
  const f = (v: number) => v > .008856 ? Math.cbrt(v) : 7.787 * v + 16 / 116;
  const x = f((r * .4124564 + g * .3575761 + b * .1804375) / .95047);
  const y = f(r * .2126729 + g * .7151522 + b * .072175);
  const z = f((r * .0193339 + g * .119192 + b * .9503041) / 1.08883);
  return [116 * y - 16, 500 * (x - y), 200 * (y - z)];
}
export const distance = (a: RGB, b: RGB) => Math.hypot(...a.map((v, i) => v - b[i]));
export const cssColor = (rgb: RGB) => `rgb(${rgb.map(Math.round).join(',')})`;

export function pickSwatches(image: Pixels, card: Rect, template = TEMPLATE, columns = 4): Swatch[] {
  if (!validRect(card) || card.w < .15 || card.h < .08) throw new Error('请框选完整的色块区域，选区目前太小。');
  const rows = template.length / columns;
  return template.map((level, i) => {
    const col = i % columns, row = Math.floor(i / columns);
    const base = { x: card.x + card.w * ((col + .5) / columns), y: card.y + card.h * ((row + .5) / rows) };
    let best: Swatch | undefined;
    let bestScore = Infinity;
    for (const dx of [-.025, 0, .025]) for (const dy of [-.03, 0, .03]) {
      const rect = { x: base.x + card.w * (dx - .26 / columns), y: base.y + card.h * (dy - .2 / rows), w: card.w * .52 / columns, h: card.h * .4 / rows };
      try {
        const sample = sampleRegion(image, rect);
        const score = sample.spread + sample.rejected * 30 + (Math.abs(dx) + Math.abs(dy)) * 8;
        if (score < bestScore) { best = { level, rect, sample }; bestScore = score; }
      } catch { /* candidate outside image or invalid; try remaining centers */ }
    }
    if (!best) throw new Error(`${level} mg/L 色块无法取色，请调整色卡区域。`);
    return best;
  });
}

export function compareColors(liquid: Sample, swatches: Swatch[], levels = LEVELS, repeatedLevel = 10) {
  const ranked = levels.map(level => {
    const entries = swatches.filter(s => s.level === level);
    if (!entries.length) throw new Error('色卡档位不完整，请重新取色。');
    const rgb = [0, 1, 2].map(c => entries.reduce((n, s) => n + s.sample.rgb[c], 0) / entries.length) as RGB;
    return { level, rgb, delta: distance(toLab(liquid.rgb), toLab(rgb)) };
  }).sort((a, b) => a.delta - b.delta);
  const warnings: string[] = [];
  if (liquid.spread > 12 || liquid.rejected > .25) warnings.push('液体区域颜色不均或有效像素不足，请避开反光与瓶壁。');
  if (swatches.some(s => s.sample.spread > 12 || s.sample.rejected > .25)) warnings.push('部分色卡取色框可能包含遮挡或边缘，请逐个检查。');
  const tens = swatches.filter(s => s.level === repeatedLevel);
  if (tens.length === 2 && distance(toLab(tens[0].sample.rgb), toLab(tens[1].sample.rgb)) > 15) warnings.push(`色卡两处 ${repeatedLevel} mg/L 颜色差异较大，可能存在阴影、遮挡或区域错位。`);
  const [a, b] = ranked;
  const nearestReasons = [...warnings];
  if (a.delta > 30) nearestReasons.push('测试液与最近色档色差过大。');
  if (Math.abs(a.delta - b.delta) <= 1e-6) nearestReasons.push('两档同样接近，无法确定唯一最近档。');
  const rangeReasons = [...warnings];
  if (a.delta > 30 || b.delta > 38) rangeReasons.push('测试液与候选色档色差过大。');
  if (Math.abs(levels.indexOf(a.level) - levels.indexOf(b.level)) !== 1) rangeReasons.push('相近色档不相邻，请调整取色框。');
  // A pair is a candidate bracket only if the liquid projects between their Lab endpoints.
  const l = toLab(liquid.rgb), p = toLab(a.rgb), q = toLab(b.rgb);
  const vector = q.map((v, i) => v - p[i]);
  const denominator = vector.reduce((s, v) => s + v * v, 0);
  const t = denominator > .01 ? vector.reduce((s, v, i) => s + v * (l[i] - p[i]), 0) / denominator : -1;
  const interpolationReasons = rangeReasons.length ? ['候选范围无法确定，暂不能计算插值。'] : [];
  if (rangeReasons.length === 0 && denominator <= .01) interpolationReasons.push('候选两档颜色无法区分，不能插值。');
  else if (rangeReasons.length === 0 && (t < 0 || t > 1)) interpolationReasons.push('颜色超出两档之间，暂不能计算插值。');
  const judge = (reasons: string[]) => ({ status: reasons.length ? 'rejected' as const : 'available' as const, reasons });
  return {
    ranked, warnings: [...new Set([...nearestReasons, ...rangeReasons, ...interpolationReasons])],
    judgments: { nearest: judge(nearestReasons), range: judge(rangeReasons), interpolation: judge(interpolationReasons) },
    range: rangeReasons.length === 0 ? [Math.min(a.level, b.level), Math.max(a.level, b.level)] : null,
    nearestLevel: nearestReasons.length === 0 ? a.level : null,
    interpolatedValue: interpolationReasons.length === 0 ? a.level + t * (b.level - a.level) : null,
    interpolationMethod: 'lab-segment-linear-uncalibrated',
  };
}
