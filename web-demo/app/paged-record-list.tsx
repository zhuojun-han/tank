"use client";
import { useState, type ReactNode } from 'react';
export function PagedRecordList<T>({items,renderItem}:{items:T[];renderItem:(item:T)=>ReactNode}) {
  const [expanded,setExpanded]=useState(true);
  const [limit,setLimit]=useState(10);
  const more=limit<items.length;
  const loadMore=()=>setLimit(value=>Math.min(value+10,items.length));
  return <section className="paged-records" style={{marginTop:20}}>
    <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',gap:12,padding:'12px 0'}}><div><h2 style={{margin:0,fontSize:18}}>检测记录</h2><small data-testid="record-page-count">已加载 {Math.min(limit,items.length)} / 共 {items.length} 条</small></div><button className="target-chip" aria-label={expanded?'收起检测记录':'展开检测记录'} aria-expanded={expanded} onClick={()=>{setExpanded(!expanded);setLimit(10);}}>{expanded?'收起 ⌃':'展开 ⌄'}</button></div>
    {expanded&&<div data-testid="record-scroll" role="region" aria-label="检测记录，向下滑动加载更多" tabIndex={0} style={{maxHeight:480,overflowY:'auto',overscrollBehaviorY:'contain',scrollbarGutter:'stable',paddingRight:4}} onScroll={event=>{const el=event.currentTarget;if(more && el.scrollTop>0 && el.scrollHeight-el.scrollTop-el.clientHeight<40)loadMore();}}>
      <div className="record-list">{items.slice(0,limit).map(renderItem)}</div>
      {!items.length?<p>暂无检测记录</p>:more?<div data-testid="record-load-more" style={{padding:16,textAlign:'center'}}><button onClick={loadMore}>向下滑动或点击加载10条</button></div>:<p style={{textAlign:'center',fontSize:12}}>已显示全部记录</p>}
    </div>}
  </section>;
}
