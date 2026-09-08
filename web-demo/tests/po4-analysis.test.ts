import assert from 'node:assert/strict';
import test from 'node:test';
import { compareColors, pickSwatches, type Swatch } from '../app/color-match/color-analysis.ts';
const levels=[0,.03,.1,.25,.5,1,3];
test('PO4 uses its own decimal levels and rejects missing patches',()=>{
 const patches:Swatch[]=levels.map((level,i)=>({level,rect:{x:0,y:0,w:.1,h:.1},sample:{rgb:[30+i*30,30+i*30,30+i*30],spread:0,rejected:0,count:100}}));
 const result=compareColors({rgb:[105,105,105],spread:0,rejected:0,count:100},patches,levels,.25);
 assert.deepEqual(result.range,[.1,.25]);assert.ok(result.interpolatedValue!>.1&&result.interpolatedValue!<.25);
 assert.throws(()=>compareColors(patches[0].sample,patches.slice(1),levels,.25));
 patches.push({...patches[3],sample:{...patches[3].sample,rgb:[250,30,30]}});
 assert.equal(compareColors(patches[2].sample,patches,levels,.25).range,null);
});
test('both PO4 orientations map eight patches with duplicate 0.25',()=>{
 const data=new Uint8ClampedArray(400*400*4);for(let i=0;i<data.length;i+=4)data.set([80,100,150,255],i);
 for(const [columns,template] of [[2,[0,3,.03,1,.1,.5,.25,.25]],[4,[3,1,.5,.25,0,.03,.1,.25]]] as const){
  const swatches=pickSwatches({width:400,height:400,data},{x:.1,y:.1,w:.8,h:.8},[...template],columns);
  assert.deepEqual(swatches.map(s=>s.level),[...template]);assert.equal(swatches.filter(s=>s.level===.25).length,2);
 }
});
