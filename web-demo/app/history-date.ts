// Legacy records omit the year. The reference year is used only for ordering;
// the original saved date is retained and displayed in the record details.
export function historyDate(value: string, referenceYear: number) {
  const legacy = value.match(/^(\d{1,2})月(\d{1,2})日(?:\s+(\d{1,2}):(\d{1,2}))?$/);
  if (legacy) {
    const [,m,d,h='0',min='0']=legacy;
    return {label:`${m.padStart(2,'0')}-${d.padStart(2,'0')}`,time:new Date(referenceYear,Number(m)-1,Number(d),Number(h),Number(min)).getTime()};
  }
  const timestamp=Date.parse(value);
  if (!Number.isFinite(timestamp)) return {label:'日期待确认',time:0};
  const date=new Date(timestamp);
  return {label:`${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`,time:timestamp};
}

export function recordDateLabel(value:string) {
  const legacy=value.match(/^(\d{1,2})月(\d{1,2})日/);
  if(legacy)return `${legacy[1]}月${legacy[2]}日`;
  const date=new Date(value);
  if(!Number.isFinite(date.getTime()))return '日期待确认';
  return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
}
