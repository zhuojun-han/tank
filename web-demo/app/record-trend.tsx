"use client";
import { useEffect, useRef } from 'react';
import { historyDate } from './history-date';
import { recordPoint, type RecordValues } from './record-values';
type Item = RecordValues & { id: number; date: string };
function previousPointIndices(points: (number | null)[]) {
  const indices: number[] = [];
  let previous = -1;
  for (let i = 0; i < points.length; i++) {
    indices.push(previous);
    if (points[i] !== null) previous = i;
  }
  return indices;
}
export function RecordTrend({ records: inputRecords, showRange = false, unit }: { records: Item[]; showRange?: boolean; unit: string }) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const year = Math.max(new Date().getFullYear(), ...inputRecords.map(r=>/^\d{4}-/.test(r.date)?Number(r.date.slice(0,4)):0));
  const records = [...inputRecords].sort((a,b)=>historyDate(a.date,year).time-historyDate(b.date,year).time||a.id-b.id);
  const signature = records.map(r=>`${r.id}:${r.date}`).join(',');
  useEffect(()=>{const el=scrollRef.current;if(el)el.scrollLeft=el.scrollWidth;},[signature]);
  const move = (direction:number) => {const el=scrollRef.current;if(el)el.scrollBy({left:direction*el.clientWidth,behavior:'smooth'});};
  const maximum = Math.max(.01, ...records.map(r => showRange ? r.high : recordPoint(r) ?? 0)) * 1.15;
  const width = Math.max(350, records.length * 70);
  const x = (i: number) => 35 + i * 70;
  const y = (v: number) => 140 - v / maximum * 115;
  const points = records.map(recordPoint);
  const previousValid = previousPointIndices(points);
  return <div className="record-trend" data-testid={showRange ? 'range-interpolation-trend' : 'interpolation-trend'}>
    <div className="history-bar-controls"><button onClick={()=>move(-1)} aria-label="趋势较早5次">← 较早</button><small>每屏约5次 · 左右滑动</small><button onClick={()=>move(1)} aria-label="趋势最近5次">最近 →</button></div>
    <div ref={scrollRef} data-testid="line-history-scroll" tabIndex={0} role="region" aria-label="历史折线图，左右滑动" style={{width:'100%',overflowX:'auto',overscrollBehaviorX:'contain'}} onKeyDown={e=>{if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();move(e.key==='ArrowLeft'?-1:1);}}}>
    <svg viewBox={`0 0 ${width} 190`} role="img" aria-label={showRange ? '范围与插值趋势' : '插值趋势'} style={{ width: `${Math.max(100,records.length*20)}%`, maxWidth:'none', height:'auto', display:'block' }}>
      <text x="0" y="15" fontSize="10" fill="#587575">{Number(maximum.toPrecision(3))}</text><text x="8" y="143" fontSize="10" fill="#587575">0</text>
      <path d={`M15 20V140H${width-15}`} fill="none" stroke="#cfdddb" />
      {records.map((r, i) => <g key={r.id}>
        {showRange && r.low !== r.high && <g data-testid="range-mark" stroke="#a687b2" strokeWidth="3"><title>{`${r.date} 范围 ${r.low}–${r.high} ${unit}`}</title><path d={`M${x(i)} ${y(r.low)}V${y(r.high)}M${x(i)-5} ${y(r.low)}h10M${x(i)-5} ${y(r.high)}h10`} /><text data-testid="range-high-label" x={x(i)-8} y={y(r.high)-5} textAnchor="end" fontSize="9" fill="#89639c" stroke="none">{r.high}</text><text data-testid="range-low-label" x={x(i)-8} y={y(r.low)+11} textAnchor="end" fontSize="9" fill="#89639c" stroke="none">{r.low}</text></g>}
        {points[i] !== null && <g><title>{`${r.date} ${r.interpolation == null ? '单值' : '插值'} ${points[i]} ${unit}`}</title>{previousValid[i] >= 0 && <line data-testid="interpolation-segment" x1={x(previousValid[i])} y1={y(points[previousValid[i]]!)} x2={x(i)} y2={y(points[i]!)} stroke="#16756c" strokeWidth="2" />}<circle data-testid="interpolation-point" cx={x(i)} cy={y(points[i]!)} r="4" fill="#16756c" /><text x={x(i)+7} y={y(points[i]!)-8} textAnchor="start" fontSize="9" fill="#165e56">{Number(points[i]!.toFixed(3))}</text></g>}
        {points[i] === null && <g data-testid="missing-interpolation"><title>{`${r.date} 未填写插值；范围仍保留，折线连接前后有效值。`}</title><text x={x(i)} y="157" textAnchor="middle" fontSize="9" fill="#946332">未填插值</text></g>}
        <text x={x(i)} y="177" textAnchor="middle" fontSize="10" fill="#587575">{historyDate(r.date,year).label}</text>
      </g>)}
    </svg></div>
    <p style={{ fontSize: 12 }}>{showRange ? '紫色竖线：范围 · 绿色点线：插值 / 单值' : '绿色点线：插值 / 单值'}</p>
    {points.some(p => p === null) && <p style={{ fontSize: 12 }}>未填插值时，折线连接前后有效值。</p>}
    {!records.length && <p>暂无记录</p>}
  </div>;
}
