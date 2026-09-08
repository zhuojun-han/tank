import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { calculateMaintenance, type MaintenanceInput } from '../app/maintenance-dosing.ts';
const contract = JSON.parse(readFileSync(new URL('../../contracts/maintenance-dosing.json', import.meta.url), 'utf8'));
for (const item of contract.cases) {
  test(`shared dosing contract: ${item.id}`, () => {
    const value = { ...contract.defaults, ...item.input };
    const chemical: 'po4' | 'kh' = value.chemical;
    const input: MaintenanceInput = {
      solutionMl: value.volumeMl, waterL: value.waterL,
      po4Rise: chemical === 'po4' ? value.dailyChange : 0,
      khDrop: chemical === 'kh' ? value.dailyChange : 0,
      khStrength: chemical === 'kh' ? value.khStrength : 6,
      khPurity: chemical === 'kh' ? value.khPurity : 100,
      temperature: chemical === 'kh' ? value.temperature : 20,
      po4Flow: chemical === 'po4' ? value.flow : 1.4, khFlow: chemical === 'kh' ? value.flow : 1.4,
      po4Minutes: chemical === 'po4' ? value.minutes : 1, khMinutes: chemical === 'kh' ? value.minutes : 1,
      po4Unit: chemical === 'po4' ? value.unit : 'ml/s', khUnit: chemical === 'kh' ? value.unit : 'ml/s',
    };
    if (item.reject) { assert.throws(() => calculateMaintenance(input)); return; }
    const actual = calculateMaintenance(input)[chemical];
    for (const [key, expected] of Object.entries(item.expected)) {
      const result = actual[key as keyof typeof actual];
      if (typeof expected === 'number') assert.ok(typeof result === 'number' && Math.abs(result - expected) <= contract.absoluteTolerance, `${key}: ${result} != ${expected}`);
      else assert.equal(result, expected);
    }
  });
}
