import { compareColors } from './color-analysis';
export function ResultSummary({ result, decimals }: { result: ReturnType<typeof compareColors>; decimals: number }) {
  const items = [
    { key: 'nearest' as const, title: '最近色档', value: result.nearestLevel === null ? null : `颜色更接近 ${result.nearestLevel} mg/L 档` },
    { key: 'range' as const, title: '候选范围', value: result.range ? `${result.range[0]}–${result.range[1]} mg/L` : null },
    { key: 'interpolation' as const, title: '插值参考值', value: result.interpolatedValue === null ? null : `约 ${result.interpolatedValue.toFixed(decimals)} mg/L` },
  ];
  return <div className="cm-result">{items.map(item => <section key={item.key} data-testid={`judgment-${item.key}`}><h3>{item.title}{result.judgments[item.key].status === 'rejected' ? ' · 暂无法给出' : ''}</h3>{item.value !== null && <p><strong>{item.value}</strong></p>}{result.judgments[item.key].reasons.slice(0, 1).map(reason => <p className="cm-error" key={reason}>{reason}</p>)}</section>)}<p>仅供参考</p></div>;
}
