"""Extract the existing four colorful fish drawings without redrawing their bodies.

Run with the bundled Python and OpenCV installed in artifacts/fish-python-deps.
The original raw files are read-only inputs. Parameters and hashes are recorded.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "artifacts/fish-python-deps"))
import cv2  # noqa: E402

FISH = ("blueface", "emperor", "golden-towel", "saddleback")
PARAMETERS = {
    "chroma_seed_min": 22,
    "dark_seed_max": 110,
    "seed_close_kernel": 3,
    "foreground_erode_kernel": 5,
    "background_safety_dilate_kernel": 61,
    "grabcut_iterations": 5,
    "edge_feather_sigma": 0.6,
    "edge_color_bleed_sigma": 1.5,
    "transparent_margin_fraction_per_side": 0.04,
    "runtime_bounds": [768, 480],
    "webp_quality": 90,
    "webp_method": 6,
    "random_seed": 1729,
}


def largest_filled_component(mask: np.ndarray) -> np.ndarray:
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
    if count < 2:
        raise ValueError("No foreground component")
    component = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    largest = (labels == component).astype(np.uint8)
    contours, _ = cv2.findContours(largest, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    result = np.zeros_like(largest)
    cv2.drawContours(result, contours, -1, 1, cv2.FILLED)
    return result


def extract(rgb: np.ndarray) -> tuple[Image.Image, dict]:
    chroma = rgb.max(axis=2).astype(np.int16) - rgb.min(axis=2)
    colorful = ((chroma > PARAMETERS["chroma_seed_min"]) |
                (rgb.min(axis=2) < PARAMETERS["dark_seed_max"])).astype(np.uint8)
    colorful = cv2.morphologyEx(colorful, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    seed = largest_filled_component(colorful)
    labels = np.full(seed.shape, cv2.GC_PR_BGD, np.uint8)
    labels[seed > 0] = cv2.GC_PR_FGD
    sure_fg = cv2.erode(seed, np.ones((5, 5), np.uint8))
    safety = cv2.dilate(seed, np.ones((61, 61), np.uint8))
    labels[safety == 0] = cv2.GC_BGD
    labels[sure_fg > 0] = cv2.GC_FGD
    labels[:2, :] = labels[-2:, :] = cv2.GC_BGD
    labels[:, :2] = labels[:, -2:] = cv2.GC_BGD
    cv2.setRNGSeed(PARAMETERS["random_seed"])
    cv2.grabCut(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), labels, None,
                np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64),
                PARAMETERS["grabcut_iterations"], cv2.GC_INIT_WITH_MASK)
    hard = largest_filled_component(np.isin(labels, [cv2.GC_FGD, cv2.GC_PR_FGD]))
    foreground = int(hard.sum())
    if foreground < rgb.shape[0] * rgb.shape[1] * 0.1:
        raise ValueError("Suspiciously small fish mask")
    alpha = cv2.GaussianBlur(hard.astype(np.float32) * 255, (0, 0), PARAMETERS["edge_feather_sigma"])
    alpha = np.clip(np.rint(alpha), 0, 255).astype(np.uint8)

    # Extend nearby fish colors into the feather, removing the grey checker matte
    # at the boundary. Opaque interior pixels retain their original RGB exactly.
    weight = cv2.erode(hard, np.ones((3, 3), np.uint8)).astype(np.float32)
    denominator = cv2.GaussianBlur(weight, (0, 0), PARAMETERS["edge_color_bleed_sigma"])
    output = rgb.astype(np.float32).copy()
    edge = (alpha > 0) & (alpha < 250) & (denominator > 0.005)
    for channel in range(3):
        nearby = cv2.GaussianBlur(rgb[:, :, channel].astype(np.float32) * weight,
                                  (0, 0), PARAMETERS["edge_color_bleed_sigma"])
        output[:, :, channel][edge] = nearby[edge] / denominator[edge]
    output[alpha == 0] = 0
    image = Image.fromarray(np.dstack([np.clip(np.rint(output), 0, 255).astype(np.uint8), alpha]))
    return image, {"seed_pixels": int(seed.sum()), "foreground_pixels": foreground,
                   "source_foreground_bbox": image.getchannel("A").getbbox()}


def runtime_image(source: Image.Image) -> Image.Image:
    bounds = source.getchannel("A").getbbox()
    fish = source.crop(bounds)
    width, height = fish.size
    margin_x = max(1, round(width * PARAMETERS["transparent_margin_fraction_per_side"]))
    margin_y = max(1, round(height * PARAMETERS["transparent_margin_fraction_per_side"]))
    padded = Image.new("RGBA", (width + 2 * margin_x, height + 2 * margin_y))
    padded.alpha_composite(fish, (margin_x, margin_y))
    padded.thumbnail(tuple(PARAMETERS["runtime_bounds"]), Image.Resampling.LANCZOS)
    return padded


def preview(sprite: Image.Image, destination: Path) -> None:
    cell_w, cell_h = 768, 520
    result = Image.new("RGB", (cell_w * 3, cell_h))
    reef = ImageOps.fit(Image.open(ROOT / "web-demo/public/aquarium/reef-tank-natural.webp").convert("RGBA"),
                        (cell_w, 480), Image.Resampling.LANCZOS)
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
    for index, (name, background) in enumerate([
        ("DARK", Image.new("RGBA", (cell_w, 480), (16, 27, 35, 255))),
        ("LIGHT", Image.new("RGBA", (cell_w, 480), (244, 244, 244, 255))),
        ("REEF", reef),
    ]):
        background.alpha_composite(sprite, ((cell_w - sprite.width) // 2, (480 - sprite.height) // 2))
        result.paste(background.convert("RGB"), (index * cell_w, 40))
        ImageDraw.Draw(result).text((index * cell_w + 12, 10), name, fill="white", font=font)
    result.save(destination, optimize=True)


def process(fish_id: str) -> dict:
    base = ROOT / "design-concepts/fish-species" / fish_id
    raw = base / "raw" / f"{fish_id}-v1.png"
    original_bytes = raw.read_bytes()
    original = Image.open(raw).convert("RGB")
    rgba, segmentation = extract(np.asarray(original))
    destination = base / "app-ready-v1"
    destination.mkdir(exist_ok=True)
    transparent = destination / f"{fish_id}-transparent.png"
    rgba.save(transparent, optimize=True)
    sprite = runtime_image(rgba)
    sprite.save(destination / f"{fish_id}.png", optimize=True)
    webp = destination / f"{fish_id}.webp"
    sprite.save(webp, format="WEBP", quality=90, method=6, exact=True)
    preview(sprite, destination / "preview.png")
    web = ROOT / "web-demo/public/fish-species" / f"{fish_id}.webp"
    app = ROOT / "app/assets/aquarium" / f"{fish_id}.webp"
    shutil.copyfile(webp, web)
    shutil.copyfile(webp, app)
    alpha = np.asarray(sprite.getchannel("A"))
    report = {"id": fish_id, "source": raw.relative_to(ROOT).as_posix(),
              "source_sha256": hashlib.sha256(original_bytes).hexdigest(),
              "source_size": list(original.size), "parameters": PARAMETERS,
              "versions": {"opencv": cv2.__version__, "numpy": np.__version__, "pillow": Image.__version__},
              **segmentation, "runtime_size": list(sprite.size),
              "alpha": {"transparent": int((alpha == 0).sum()), "partial": int(((alpha > 0) & (alpha < 255)).sum()),
                         "opaque": int((alpha == 255).sum()), "bbox": sprite.getchannel("A").getbbox()},
              "webp_bytes": webp.stat().st_size, "webp_sha256": hashlib.sha256(webp.read_bytes()).hexdigest(),
              "two_runtime_files_identical": web.read_bytes() == app.read_bytes(),
              "original_unchanged": original_bytes == raw.read_bytes(),
              "transparent_png": transparent.relative_to(ROOT).as_posix()}
    (destination / "processing-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if k not in ("parameters", "versions")}), flush=True)
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("fish", nargs="*")
    args = parser.parse_args()
    fish_ids = args.fish or FISH
    if any(fish not in FISH for fish in fish_ids):
        parser.error("Supported fish: " + ", ".join(FISH))
    cv2.setNumThreads(2)
    reports = [process(fish) for fish in fish_ids]
    (ROOT / "artifacts/fish-assets-four-colorful.json").write_text(json.dumps(reports, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
