"use client";
import { useMemo } from 'react';
import { historyDate } from './history-date';
import { recordPoint, type RecordValues } from './record-values';
import { useHistoryWindow } from './use-history-window';

type Item = RecordValues & { id: number; date: string };
export function RecordTrend({ records: inputRecords, showRange = false, unit }: { records: Item[]; showRange?: boolean; unit: string }) {
  const { records, year, signature, maximum, points, previous, next } = useMemo(() => {
    const year = inputRecords.reduce((year, r) => Math.max(year, /^\d{4}-/.test(r.date) ? Number(r.date.slice(0, 4)) : 0), new Date().getFullYear());
    const records = [...inputRecords].sort((a, b) => historyDate(a.date, year).time - historyDate(b.date, year).time || a.id - b.id);
    const points = records.map(recordPoint);
    const previous: number[] = [], next: number[] = [];
    let valid = -1;
    for (let i = 0; i < points.length; i++) { previous[i] = valid; if (points[i] !== null) valid = i; }
    valid = -1;
    for (let i = points.length - 1; i >= 0; i--) { next[i] = valid; if (points[i] !== null) valid = i; }
    return {
      records, year, points, previous, next, signature: records.map(r => r.id + ':' + r.date).join(','),
      maximum: records.reduce((max, r, i) => Math.max(max, showRange ? r.high : points[i] ?? 0), .01) * 1.15,
    };
  }, [inputRecords, showRange]);
  const { ref, start, end, virtual, offset, measure, move } = useHistoryWindow(records.length, signature);
  const width = virtual ? 350 : Math.max(350, records.length * 70);
  const x = (i: number) => 35 + i * 70 - (virtual ? offset : 0);
  const y = (v: number) => 140 - v / maximum * 115;
  const segment = (i: number) => previous[i] >= 0 && <line data-testid="interpolation-segment" x1={x(previous[i])} y1={y(points[previous[i]]!)} x2={x(i)} y2={y(points[i]!)} stroke="#16756c" strokeWidth="2" />;
  const continuation = end > 0 ? next[end - 1] : -1;
  const svg = <svg viewBox={'0 0 ' + width + ' 190'} role="img" aria-label={showRange ? '范围与插值趋势' : '插值趋势'} style={{ width: (virtual ? 500 / records.length : Math.max(100, records.length * 20)) + '%', maxWidth: 'none', height: 'auto', display: 'block', ...(virtual ? { position: 'sticky', left: 0 } as const : {}) }}>
    <text x="0" y="15" fontSize="10" fill="#587575">{Number(maximum.toPrecision(3))}</text><text x="8" y="143" fontSize="10" fill="#587575">0</text>
    <path d={'M15 20V140H' + (width - 15)} fill="none" stroke="#cfdddb" />
    {records.slice(start, end).map((r, relative) => {
      const i = start + relative;
      return <g key={r.id} data-record-id={r.id}>
        {showRange && r.low !== r.high && <g data-testid="range-mark" stroke="#a687b2" strokeWidth="3"><title>{r.date + ' 范围 ' + r.low + '–' + r.high + ' ' + unit}</title><path d={'M' + x(i) + ' ' + y(r.low) + 'V' + y(r.high) + 'M' + (x(i) - 5) + ' ' + y(r.low) + 'h10M' + (x(i) - 5) + ' ' + y(r.high) + 'h10'} /><text data-testid="range-high-label" x={x(i) - 8} y={y(r.high) - 5} textAnchor="end" fontSize="9" fill="#89639c" stroke="none">{r.high}</text><text data-testid="range-low-label" x={x(i) - 8} y={y(r.low) + 11} textAnchor="end" fontSize="9" fill="#89639c" stroke="none">{r.low}</text></g>}
        {points[i] !== null && <g><title>{r.date + ' ' + (r.interpolation == null ? '单值' : '插值') + ' ' + points[i] + ' ' + unit}</title>{segment(i)}<circle data-testid="interpolation-point" cx={x(i)} cy={y(points[i]!)} r="4" fill="#16756c" /><text x={x(i) + 7} y={y(points[i]!) - 8} textAnchor="start" fontSize="9" fill="#165e56">{Number(points[i]!.toFixed(3))}</text></g>}
        {points[i] === null && <g data-testid="missing-interpolation"><title>{r.date + ' 未填写插值；范围仍保留，折线连接前后有效值。'}</title><text x={x(i)} y="157" textAnchor="middle" fontSize="9" fill="#946332">未填插值</text></g>}
        <text x={x(i)} y="177" textAnchor="middle" fontSize="10" fill="#587575">{historyDate(r.date, year).label}</text>
      </g>;
    })}
    {virtual && continuation >= end && segment(continuation)}
  </svg>;
  return <div className="record-trend" data-testid={showRange ? 'range-interpolation-trend' : 'interpolation-trend'}>
    <div className="history-bar-controls"><button onClick={() => move(-1)} aria-label="趋势较早5次">← 较早</button><small>每屏约5次 · 左右滑动</small><button onClick={() => move(1)} aria-label="趋势最近5次">最近 →</button></div>
    <div ref={ref} data-testid="line-history-scroll" tabIndex={0} role="region" aria-label="历史折线图，左右滑动" style={{ width: '100%', overflowX: 'auto', overscrollBehaviorX: 'contain' }} onScroll={measure} onKeyDown={e => { if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') { e.preventDefault(); move(e.key === 'ArrowLeft' ? -1 : 1); } }}>
      {virtual ? <div style={{ width: records.length * 20 + '%' }}>{svg}</div> : svg}
    </div>
    <p style={{ fontSize: 12 }}>{showRange ? '紫色竖线：范围 · 绿色点线：插值 / 单值' : '绿色点线：插值 / 单值'}</p>
    {points.some(p => p === null) && <p style={{ fontSize: 12 }}>未填插值时，折线连接前后有效值。</p>}
    {!records.length && <p>暂无记录</p>}
  </div>;
}
