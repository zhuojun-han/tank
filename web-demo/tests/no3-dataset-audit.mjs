import { launchBrowser } from './browser-support.mjs';
import {fileURLToPath} from 'node:url';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {sampleRegion,pickSwatches,compareColors} from '../app/color-match/color-analysis.ts';
const manifestUrl=new URL('../../datasets/no3/manifest_v1.json',import.meta.url);
const manifest=JSON.parse(await readFile(manifestUrl,'utf8'));
const annotations=manifest.samples;
for(const sample of annotations){
  if(!sample.regions?.card||!sample.regions?.liquid)throw new Error(`Missing regions: ${sample.id}`);
  const digest=createHash('sha256').update(await readFile(new URL(sample.imagePath,manifestUrl))).digest('hex');
  if(digest!==sample.sha256)throw new Error(`Dataset checksum mismatch: ${sample.id}`);
}
const out=new URL('../artifacts/no3-audit/',import.meta.url);await mkdir(out,{recursive:true});
const browser=await launchBrowser();
const results=[];
try{
 const page=await browser.newPage({viewport:{width:1100,height:950}});
 await page.route('http://audit.local/**',async route=>{const index=Number(new URL(route.request().url()).pathname.slice(1));if(Number.isInteger(index)&&annotations[index])await route.fulfill({path:fileURLToPath(new URL(annotations[index].imagePath,manifestUrl)),contentType:'image/jpeg'});else await route.fulfill({contentType:'text/html',body:'<canvas id="image"></canvas>'});});
 await page.goto('http://audit.local/index');
 for(let index=0;index<annotations.length;index++){
  const sample=annotations[index],name=sample.id;const {card,liquid}=sample.regions;
  const data=await page.evaluate(async index=>{const img=new Image();img.src=`http://audit.local/${index}`;await img.decode();const scale=Math.min(1,1600/Math.max(img.width,img.height));const canvas=document.querySelector('canvas');canvas.width=Math.round(img.width*scale);canvas.height=Math.round(img.height*scale);canvas.style.width='1000px';canvas.style.height='auto';const ctx=canvas.getContext('2d',{willReadFrequently:true});ctx.drawImage(img,0,0,canvas.width,canvas.height);const pixels=ctx.getImageData(0,0,canvas.width,canvas.height).data;let binary='';for(let i=0;i<pixels.length;i+=32768)binary+=String.fromCharCode(...pixels.subarray(i,i+32768));return{width:canvas.width,height:canvas.height,rgba:btoa(binary)};},index);
  const pixels={width:data.width,height:data.height,data:new Uint8ClampedArray(Buffer.from(data.rgba,'base64'))};
  const swatches=pickSwatches(pixels,card),liquidSample=sampleRegion(pixels,liquid),result=compareColors(liquidSample,swatches);
  const sensitivity=[[-.25,0],[.25,0],[0,-.25],[0,.25]].map(([dx,dy])=>{const region={...liquid,x:liquid.x+dx*liquid.w,y:liquid.y+dy*liquid.h};try{const s=compareColors(sampleRegion(pixels,region),swatches);return{region,range:s.range,interpolation:s.interpolatedValue,warnings:s.warnings};}catch(e){return{region,error:String(e)};}});
  const label=`${sample.label.minimum}-${sample.label.maximum}`;
  const sha256=createHash('sha256').update(await readFile(new URL(sample.imagePath,manifestUrl))).digest('hex');
  const record={name,sha256,manualLabel:label,annotationMethod:'manual geometry; no threshold tuning',card,liquid,swatches,liquidSample,result,sensitivity};results.push(record);
  await writeFile(new URL(`${index+1}-analysis.json`,out),JSON.stringify(record,null,2));
  await page.evaluate(({card,liquid,swatches})=>{const canvas=document.querySelector('canvas'),ctx=canvas.getContext('2d');ctx.lineWidth=3;ctx.font='20px sans-serif';for(const [r,text,color] of [[card,'CARD','#ffee00'],[liquid,'LIQUID','#00ffff'],...swatches.map((s,i)=>[s.rect,`${s.level} #${i+1}`,'#ffffff'])]){ctx.strokeStyle=color;ctx.fillStyle=color;ctx.strokeRect(r.x*canvas.width,r.y*canvas.height,r.w*canvas.width,r.h*canvas.height);ctx.fillText(text,r.x*canvas.width,r.y*canvas.height-5);}}, {card,liquid,swatches});
  await page.locator('canvas').screenshot({path:fileURLToPath(new URL(`${index+1}-regions.png`,out))});
  console.log(name,JSON.stringify({label,range:result.range,point:result.interpolatedValue,nearest:result.ranked[0].level,warnings:result.warnings,sensitivity:sensitivity.map(s=>s.range??null)}));
 }
 await writeFile(new URL('results.json',out),JSON.stringify(results,null,2));
}finally{await browser.close();}
