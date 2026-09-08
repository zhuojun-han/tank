export type RecordValues = { low: number; high: number; interpolation?: number | null };
export function readRecordValues(lowText: string, highText: string, interpolationText: string): RecordValues {
  const low = Number(lowText), high = Number(highText);
  if (!lowText.trim() || !highText.trim() || !Number.isFinite(low) || !Number.isFinite(high) || low < 0 || high < low) throw new Error('请输入有效范围：0 ≤ 下限 ≤ 上限。');
  const interpolation = interpolationText.trim() ? Number(interpolationText) : null;
  if (interpolation !== null && (!Number.isFinite(interpolation) || interpolation < low || interpolation > high)) throw new Error('插值必须是范围内的有效数值。');
  return { low, high, interpolation: interpolation ?? (low === high ? low : null) };
}
export function recordPoint(r: RecordValues): number | null {
  if (typeof r.interpolation === 'number' && Number.isFinite(r.interpolation) && r.interpolation >= r.low && r.interpolation <= r.high) return r.interpolation;
  return r.low === r.high && Number.isFinite(r.low) ? r.low : null;
}
