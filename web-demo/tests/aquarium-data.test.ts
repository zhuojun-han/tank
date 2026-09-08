import assert from "node:assert/strict";
import { access } from "node:fs/promises";
import test from "node:test";

import {
  animatedFish,
  builtinFishArtwork,
  BUILTIN_FISH_SPECIES,
  clownfishArtwork,
  fishCount,
  isFishArtworkDataUrl,
  MAX_ANIMATED_FISH,
  normalizeFishStock,
} from "../app/aquarium-data.ts";

test("normalizes valid per-tank fish records and rejects malformed entries", () => {
  const normalized = normalizeFishStock([
    { id: "a", tankId: 1, species: "  小丑鱼  ", quantity: 2.9, introducedOn: "2026-08-15" },
    { id: "b", tankId: 2, species: "蓝魔", quantity: 3, introducedOn: "2026-08-16" },
    { id: "bad-name", tankId: 1, species: "", quantity: 1, introducedOn: "2026-08-15" },
    { id: "bad-date", tankId: 1, species: "黄尾蓝魔", quantity: 1, introducedOn: "not-a-date" },
  ], []);

  assert.deepEqual(normalized, [
    { id: "a", tankId: 1, species: "小丑鱼", quantity: 2, introducedOn: "2026-08-15", artwork: clownfishArtwork },
    { id: "b", tankId: 2, species: "蓝魔", quantity: 3, introducedOn: "2026-08-16", artwork: clownfishArtwork },
  ]);
  assert.equal(fishCount(normalized.filter((item) => item.tankId === 1)), 2);
  assert.equal(fishCount(normalized.filter((item) => item.tankId === 2)), 3);
});

test("offers every approved built-in fish with its own artwork", async () => {
  assert.deepEqual(
    BUILTIN_FISH_SPECIES.map((species) => species.name),
    [
      "小丑鱼",
      "双斑宝石海金鱼（公）",
      "双斑宝石海金鱼（母）",
      "蓝眼海金鱼（公）",
      "深水樱花宝石",
      "火焰仙",
      "紫吊",
      "粉蓝吊",
      "东非金剪刀",
    ],
  );
  assert.equal(new Set(BUILTIN_FISH_SPECIES.map((species) => species.artworkPath)).size, 9);
  await Promise.all(BUILTIN_FISH_SPECIES.map((species) =>
    access(new URL(`../public${species.artworkPath}`, import.meta.url))
  ));
  assert.deepEqual(builtinFishArtwork("ecsenius-midas"), {
    source: "builtin",
    id: "ecsenius-midas",
  });
});

test("preserves a recognized built-in artwork through storage normalization", () => {
  const stock = normalizeFishStock([{
    id: "purple-tang",
    tankId: 1,
    species: "紫吊",
    quantity: 2,
    introducedOn: "2026-09-02",
    artwork: builtinFishArtwork("zebrasoma-xanthurum"),
  }], []);

  assert.deepEqual(stock[0].artwork, builtinFishArtwork("zebrasoma-xanthurum"));
});

test("keeps exact stock quantity while bounding animated fish", () => {
  const stock = normalizeFishStock([
    { id: "school", tankId: 1, species: "小丑鱼", quantity: 40, introducedOn: "2026-08-15" },
  ], []);

  assert.equal(fishCount(stock), 40);
  assert.equal(animatedFish(stock).length, MAX_ANIMATED_FISH);
  assert.equal(animatedFish(stock)[0].species, "小丑鱼");
  assert.deepEqual(animatedFish(stock)[0].artwork, clownfishArtwork);
});

test("keeps validated custom artwork and rejects unsafe data URLs", () => {
  const dataUrl = "data:image/webp;base64,AAAA";
  const stock = normalizeFishStock([{
    id: "custom",
    tankId: 1,
    species: "蓝吊",
    quantity: 1,
    introducedOn: "2026-08-30",
    artwork: { source: "custom", dataUrl },
  }, {
    id: "unsafe",
    tankId: 1,
    species: "旧档案",
    quantity: 1,
    introducedOn: "2026-08-30",
    artwork: { source: "custom", dataUrl: "data:image/svg+xml,<svg onload=alert(1)>" },
  }], []);

  assert.deepEqual(stock[0].artwork, { source: "custom", dataUrl });
  assert.deepEqual(stock[1].artwork, clownfishArtwork);
  assert.equal(isFishArtworkDataUrl(dataUrl), true);
  assert.equal(isFishArtworkDataUrl("data:text/html;base64,AAAA"), false);
});

test("does not invent fish when migrating older storage", () => {
  const migrated = normalizeFishStock(undefined, []);

  assert.deepEqual(migrated, []);
  assert.equal(normalizeFishStock(undefined).every((item) => item.species === "小丑鱼"), true);
  assert.equal(normalizeFishStock(undefined).every((item) => item.artwork.source === "builtin"), true);
});
