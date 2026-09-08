"use client";
import { useEffect, useRef } from 'react';
import { recordPoint, recordValueText, type RecordValues } from './record-values';
import './home-history-bars.css';
import { historyDate } from './history-date';
type Item = RecordValues & {id:number;date:string;note:string;parameterId?:string;khTitration?:unknown};
export function HomeHistoryBars({records,unit,name}:{records:Item[];unit:string;name:string}) {
  const scroller = useRef<HTMLDivElement>(null);
  const referenceYear = Math.max(new Date().getFullYear(),...records.map(r=>/^\d{4}-/.test(r.date)?Number(r.date.slice(0,4)):0));
  const sorted = [...records].sort((a,b)=>historyDate(a.date,referenceYear).time-historyDate(b.date,referenceYear).time||a.id-b.id);
  const signature = sorted.map(r=>r.id).join(',');
  useEffect(()=>{const el=scroller.current;if(el)el.scrollLeft=el.scrollWidth;},[signature]);
  const maximum=Math.max(.001,...sorted.map(r=>recordPoint(r)??0))*1.15;
  const move=(direction:number)=>{const el=scroller.current;if(el)el.scrollBy({left:direction*el.clientWidth,behavior:'smooth'});};
  return <div data-testid="home-history-bars"><div className="history-bar-controls"><button aria-label={`${name} 较早5次`} onClick={()=>move(-1)}>← 较早</button><small>插值 / 单值 · {unit}</small><button aria-label={`${name} 最近5次`} onClick={()=>move(1)}>最近 →</button></div><div ref={scroller} className="history-bar-scroll" tabIndex={0} role="region" aria-label={`${name} 历史测试柱状图，左右滑动`} onKeyDown={e=>{if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();move(e.key==='ArrowLeft'?-1:1);}}}>{sorted.map(r=>{const point=recordPoint(r);return <div key={r.id} className="history-bar-slot" data-record-id={r.id} title={`${r.date} · ${point===null?'未填写插值':recordValueText(point,r)+' '+unit} · ${r.note}`}><strong>{point===null?'未填':recordValueText(Number(point.toFixed(3)),r)}</strong><div className="history-bar-track">{point!==null&&<span data-testid="history-value-bar" style={{height:`${point/maximum*100}%`,minHeight:point===0?0:2}}/>}</div><time dateTime={r.date}>{historyDate(r.date,referenceYear).label}</time>{r.note.includes('演示')&&<small>演示</small>}</div>;})}</div>{!sorted.length&&<p>记录第一次检测后显示趋势</p>}{sorted.some(r=>recordPoint(r)===null)&&<p className="history-bar-hint">未填写插值的范围记录保留位置，不生成柱值。</p>}</div>;
}
