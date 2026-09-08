import assert from 'node:assert/strict';
import test from 'node:test';
import { compareColors, LEVELS, NO3_ORIENTATIONS, TEMPLATE, pickSwatches, sampleRegion, toLab, type RGB, type Sample, type Swatch } from '../app/color-match/color-analysis.ts';
const sample = (rgb: RGB): Sample => ({ rgb, spread: 0, rejected: 0, count: 100 });
const ramp = (): Swatch[] => LEVELS.map((level, i) => ({ level, rect: { x: 0, y: 0, w: .1, h: .1 }, sample: sample([30 + i * 30, 30 + i * 30, 30 + i * 30]) }));
test('sRGB black and white have expected Lab endpoints', () => {
  assert.deepEqual(toLab([0, 0, 0]), [0, 0, 0]);
  const white = toLab([255, 255, 255]);
  assert.ok(Math.abs(white[0] - 100) < .001 && Math.abs(white[1]) < .001 && Math.abs(white[2]) < .001);
});
test('candidate bracket comes from supplied pixels, not a fixed sample label', () => {
  assert.deepEqual(compareColors(sample([105, 105, 105]), ramp()).range, [5, 10]);
  assert.deepEqual(compareColors(sample([165, 165, 165]), ramp()).range, [25, 50]);
});
test('interpolation stays in bracket and follows either nearest-endpoint direction', () => {
  for (const value of [95, 115]) {
    const result = compareColors(sample([value, value, value]), ramp());
    assert.deepEqual(result.range, [5, 10]);
    assert.equal(result.nearestLevel, value === 95 ? 5 : 10);
    assert.ok(result.interpolatedValue! > 5 && result.interpolatedValue! < 10);
    assert.ok(value === 95 ? result.interpolatedValue! < 7.5 : result.interpolatedValue! > 7.5);
  }
  const endpoint = compareColors(sample([120, 120, 120]), ramp());
  assert.equal(endpoint.nearestLevel, 10);
  assert.equal(endpoint.interpolatedValue, 10);
});
test('rejected comparisons never expose an interpolation or nearest-level recommendation', () => {
  for (const liquid of [{ ...sample([105, 105, 105]), spread: 15 }, { ...sample([105, 105, 105]), rejected: .5 }]) {
    const result = compareColors(liquid, ramp());
    assert.equal(result.range, null);
    assert.equal(result.interpolatedValue, null);
    assert.equal(result.nearestLevel, null);
  }
});
test('nonadjacent levels reject range while outside projection rejects only interpolation', () => {
  const swatches = ramp(); [swatches[2].level, swatches[6].level] = [swatches[6].level, swatches[2].level];
  assert.equal(compareColors(sample([105, 105, 105]), swatches).range, null);
  const outside = compareColors(sample([240, 240, 240]), ramp());
  assert.deepEqual(outside.range, [50, 100]);
  assert.equal(outside.nearestLevel, 100);
  assert.equal(outside.interpolatedValue, null);
  assert.equal(outside.judgments.interpolation.status, 'rejected');
  const nonadjacent = compareColors(sample([105, 105, 105]), swatches);
  assert.notEqual(nonadjacent.nearestLevel, null);
  assert.equal(nonadjacent.interpolatedValue, null);
});
test('uneven liquid, damaged swatches and duplicate 10 disagreement reject output', () => {
  assert.equal(compareColors({ ...sample([105, 105, 105]), spread: 15 }, ramp()).range, null);
  const bad = ramp(); bad[0].sample.rejected = .5;
  assert.equal(compareColors(sample([105, 105, 105]), bad).range, null);
  const duplicate = ramp(); duplicate.push({ ...duplicate[3], sample: sample([200, 30, 50]) });
  assert.equal(compareColors(sample([105, 105, 105]), duplicate).range, null);
});
test('sampling ignores clipped pixels and rejects empty/out-of-bounds areas', () => {
  const data = new Uint8ClampedArray(20 * 20 * 4);
  for (let i = 0; i < data.length; i += 4) data.set(i < 40 ? [255, 255, 255, 255] : [120, 50, 80, 255], i);
  const image = { width: 20, height: 20, data };
  assert.deepEqual(sampleRegion(image, { x: 0, y: 0, w: 1, h: 1 }).rgb, [120, 50, 80]);
  assert.throws(() => sampleRegion(image, { x: .9, y: 0, w: .2, h: 1 }));
  assert.throws(() => sampleRegion({ ...image, data: new Uint8ClampedArray(data.length) }, { x: 0, y: 0, w: 1, h: 1 }));
});
test('template produces eight bounded samples including the two 10 patches', () => {
  const data = new Uint8ClampedArray(100 * 100 * 4);
  for (let i = 0; i < data.length; i += 4) data.set([110, 50, 80, 255], i);
  const swatches = pickSwatches({ width: 100, height: 100, data }, { x: .1, y: .1, w: .8, h: .8 });
  assert.equal(swatches.length, 8); assert.equal(swatches.filter(s => s.level === 10).length, 2);
  assert.throws(() => compareColors(sample([110, 50, 80]), swatches.filter(s => s.level !== 0)));
});

test('indistinguishable adjacent colors refuse nearest and interpolation but retain candidate pair', () => {
  const swatches = ramp(); swatches[3].sample = sample([...swatches[2].sample.rgb]);
  const result = compareColors(sample([90,90,90]), swatches);
  assert.equal(result.nearestLevel, null);
  assert.deepEqual(result.range, [5,10]);
  assert.equal(result.interpolatedValue, null);
  assert.match(result.judgments.interpolation.reasons.join(''), /无法区分/);
});

test('NO3 four orientations map rotated image cells to their original levels', () => {
  for (const [angle, layout] of Object.entries(NO3_ORIENTATIONS)) {
    const quarter = Number(angle) / 90;
    const cols = quarter % 2 ? 2 : 4, rows = 8 / cols;
    const width = cols * 100, height = rows * 100;
    const data = new Uint8ClampedArray(width * height * 4);
    TEMPLATE.forEach((level, i) => {
      const x=i%4, y=Math.floor(i/4);
      const [rx,ry] = quarter===0 ? [x,y] : quarter===1 ? [1-y,x] : quarter===2 ? [3-x,1-y] : [y,3-x];
      for(let py=ry*100;py<(ry+1)*100;py++)for(let px=rx*100;px<(rx+1)*100;px++)data.set([40+level,80,100,255],(py*width+px)*4);
    });
    const swatches=pickSwatches({width,height,data},{x:0,y:0,w:1,h:1},layout.template,layout.columns);
    assert.equal(swatches.length,8);
    for(const swatch of swatches)assert.deepEqual(swatch.sample.rgb,[40+swatch.level,80,100]);
  }
});

test('range rejection explains interpolation dependency without piling on projection failures', () => {
  const swatches = ramp();
  [swatches[2].level, swatches[6].level] = [swatches[6].level, swatches[2].level];
  const result = compareColors(sample([105,105,105]), swatches);
  assert.equal(result.range,null);
  assert.equal(result.interpolatedValue,null);
  assert.deepEqual(result.judgments.interpolation.reasons,['候选范围无法确定，暂不能计算插值。']);
  assert.notEqual(result.nearestLevel,null);
});
