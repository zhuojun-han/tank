export const BUILTIN_FISH_SPECIES = [
  {
    id: "clownfish",
    name: "小丑鱼",
    note: "已选定 A1 轻写实立绘",
    artworkPath: "/fish-species/clownfish.webp",
  },
  {
    id: "pseudanthias-bimaculatus-male",
    name: "双斑宝石海金鱼（公）",
    note: "公鱼 · 红紫与金黄斑纹",
    artworkPath: "/fish-species/pseudanthias-bimaculatus-male.webp",
  },
  {
    id: "pseudanthias-bimaculatus-female",
    name: "双斑宝石海金鱼（母）",
    note: "母鱼 · 金黄与粉橙体色",
    artworkPath: "/fish-species/pseudanthias-bimaculatus-female.webp",
  },
  {
    id: "pseudanthias-squamipinnis-male",
    name: "蓝眼海金鱼（公）",
    note: "公鱼 · 延长背鳍棘",
    artworkPath: "/fish-species/pseudanthias-squamipinnis-male.webp",
  },
  {
    id: "odontanthias-borbonius",
    name: "深水樱花宝石",
    note: "又称发霉鱼",
    artworkPath: "/fish-species/odontanthias-borbonius.webp",
  },
  {
    id: "centropyge-loriculus",
    name: "火焰仙",
    note: "橙红鱼体与黑色竖纹",
    artworkPath: "/fish-species/centropyge-loriculus.webp",
  },
  {
    id: "zebrasoma-xanthurum",
    name: "紫吊",
    note: "紫蓝鱼体与黄色尾鳍",
    artworkPath: "/fish-species/zebrasoma-xanthurum.webp",
  },
  {
    id: "acanthurus-leucosternon",
    name: "粉蓝吊",
    note: "采用圆润饱满背鳍版本",
    artworkPath: "/fish-species/acanthurus-leucosternon.webp",
  },
  {
    id: "ecsenius-midas",
    name: "东非金剪刀",
    note: "金橙细长体型与剪刀尾",
    artworkPath: "/fish-species/ecsenius-midas.webp",
  },
] as const;

export type BuiltinFishId = (typeof BUILTIN_FISH_SPECIES)[number]["id"];

export type FishArtwork =
  | { source: "builtin"; id: BuiltinFishId }
  | { source: "custom"; dataUrl: string };

export type FishStockItem = {
  id: string;
  tankId: number;
  species: string;
  quantity: number;
  introducedOn: string;
  artwork: FishArtwork;
};

export const MAX_ANIMATED_FISH = 24;
export const MAX_FISH_QUANTITY = 999;
export const MAX_FISH_ARTWORK_INPUT_BYTES = 8 * 1024 * 1024;
export const MAX_FISH_ARTWORK_DATA_URL_LENGTH = 450_000;

export const clownfishArtwork: FishArtwork = {
  source: "builtin",
  id: "clownfish",
};

export function isBuiltinFishId(value: unknown): value is BuiltinFishId {
  return typeof value === "string" && BUILTIN_FISH_SPECIES.some((species) => species.id === value);
}

export function builtinFishArtwork(id: BuiltinFishId): FishArtwork {
  return { source: "builtin", id };
}

export function builtinFishSpecies(id: BuiltinFishId) {
  return BUILTIN_FISH_SPECIES.find((species) => species.id === id) ?? BUILTIN_FISH_SPECIES[0];
}

export const defaultFishStock: FishStockItem[] = [
  {
    id: "demo-clownfish-main",
    tankId: 1,
    species: "小丑鱼",
    quantity: 2,
    introducedOn: "2026-08-15",
    artwork: clownfishArtwork,
  },
  {
    id: "demo-clownfish-small",
    tankId: 2,
    species: "小丑鱼",
    quantity: 1,
    introducedOn: "2026-08-20",
    artwork: clownfishArtwork,
  },
];

function isDateKey(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00`);
  return !Number.isNaN(parsed.getTime());
}

export function isFishArtworkDataUrl(value: unknown): value is string {
  return typeof value === "string" &&
    value.length <= MAX_FISH_ARTWORK_DATA_URL_LENGTH &&
    /^data:image\/(?:png|jpeg|webp);base64,[a-z0-9+/=]+$/i.test(value);
}

function normalizeArtwork(value: unknown): FishArtwork {
  if (value && typeof value === "object") {
    const artwork = value as Partial<FishArtwork> & { dataUrl?: unknown; id?: unknown };
    if (artwork.source === "custom" && isFishArtworkDataUrl(artwork.dataUrl)) {
      return { source: "custom", dataUrl: artwork.dataUrl };
    }
    if (artwork.source === "builtin" && isBuiltinFishId(artwork.id)) {
      return builtinFishArtwork(artwork.id);
    }
  }
  return clownfishArtwork;
}

export function normalizeFishStock(
  value: unknown,
  fallback: FishStockItem[] = defaultFishStock,
): FishStockItem[] {
  if (!Array.isArray(value)) return fallback.map((item) => ({ ...item }));

  return value.flatMap((candidate, index) => {
    if (!candidate || typeof candidate !== "object") return [];
    const item = candidate as Partial<FishStockItem>;
    const tankId = Number(item.tankId);
    const quantity = Math.floor(Number(item.quantity));
    const species = String(item.species ?? "").trim();
    const introducedOn = String(item.introducedOn ?? "");
    if (
      !Number.isFinite(tankId) ||
      tankId <= 0 ||
      !species ||
      !Number.isFinite(quantity) ||
      quantity < 1 ||
      !isDateKey(introducedOn)
    ) {
      return [];
    }
    return [{
      id: String(item.id || `fish-${tankId}-${index}`),
      tankId,
      species: species.slice(0, 24),
      quantity: Math.min(quantity, MAX_FISH_QUANTITY),
      introducedOn,
      artwork: normalizeArtwork(item.artwork),
    }];
  });
}

export function fishCount(items: FishStockItem[]) {
  return items.reduce((total, item) => total + item.quantity, 0);
}

export function animatedFish(items: FishStockItem[]) {
  const swimmers: { key: string; species: string; artwork: FishArtwork }[] = [];
  for (const item of items) {
    const count = Math.min(item.quantity, MAX_ANIMATED_FISH - swimmers.length);
    for (let index = 0; index < count; index++) {
      swimmers.push({ key: `${item.id}-${index}`, species: item.species, artwork: item.artwork });
    }
    if (swimmers.length === MAX_ANIMATED_FISH) break;
  }
  return swimmers;
}
