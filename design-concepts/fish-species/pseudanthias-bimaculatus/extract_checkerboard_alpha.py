from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps


def _nearest_foreground_seed(mask: np.ndarray) -> tuple[int, int]:
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        raise ValueError("No foreground pixels were detected")
    center_x = (mask.shape[1] - 1) / 2
    center_y = (mask.shape[0] - 1) / 2
    index = np.argmin((xs - center_x) ** 2 + (ys - center_y) ** 2)
    return int(xs[index]), int(ys[index])


def extract_checkerboard_alpha(source: Path, destination: Path) -> None:
    source_image = Image.open(source).convert("RGB")
    rgb = np.asarray(source_image, dtype=np.uint8)
    minimum = rgb.min(axis=2)
    chroma = rgb.max(axis=2) - minimum

    # The generated checkerboard is near-white and nearly neutral. Flooding only
    # that color family from the border keeps enclosed pale highlights on the fish.
    background_candidate = (minimum >= 238) & (chroma <= 8)
    flood_values = np.where(background_candidate, 0, 255).astype(np.uint8)
    flood_map = Image.fromarray(np.repeat(flood_values[:, :, None], 3, axis=2), mode="RGB")
    width, height = source_image.size
    border_seeds = (
        [(x, 0) for x in range(width)]
        + [(x, height - 1) for x in range(width)]
        + [(0, y) for y in range(height)]
        + [(width - 1, y) for y in range(height)]
    )
    for seed in border_seeds:
        if flood_map.getpixel(seed) == (0, 0, 0):
            ImageDraw.floodfill(flood_map, seed, (128, 128, 128), thresh=0)

    outside = np.asarray(flood_map)[:, :, 0] == 128
    foreground = ~outside

    # Retain only the connected fish component nearest the canvas center.
    component_values = np.where(foreground, 255, 0).astype(np.uint8)
    component_map = Image.fromarray(
        np.repeat(component_values[:, :, None], 3, axis=2), mode="RGB"
    )
    seed = _nearest_foreground_seed(foreground)
    ImageDraw.floodfill(component_map, seed, (128, 128, 128), thresh=0)
    fish_component = np.asarray(component_map)[:, :, 0] == 128

    foreground_pixels = int(fish_component.sum())
    minimum_expected_pixels = int(width * height * 0.05)
    if foreground_pixels < minimum_expected_pixels:
        raise ValueError(
            f"Foreground extraction was too small for {source.name}: "
            f"{foreground_pixels} pixels"
        )

    # Pull the mask one pixel inward before feathering to suppress the baked
    # white checkerboard fringe while preserving thin fin rays.
    hard_alpha = Image.fromarray(
        np.where(fish_component, 255, 0).astype(np.uint8), mode="L"
    )
    alpha_image = hard_alpha.filter(ImageFilter.MinFilter(3)).filter(
        ImageFilter.GaussianBlur(0.85)
    )
    alpha = np.asarray(alpha_image, dtype=np.uint8)
    if int(np.count_nonzero(alpha)) < minimum_expected_pixels:
        raise ValueError(f"Alpha mask was too small for {source.name}")

    # Bleed nearby opaque fish color into semitransparent edge pixels. This avoids
    # a pale fringe when the sprite is drawn over the blue reef background.
    opaque = (alpha >= 245).astype(np.float32)
    opaque_image = Image.fromarray((opaque * 255).astype(np.uint8), mode="L")
    denominator = np.asarray(
        opaque_image.filter(ImageFilter.GaussianBlur(2.0)), dtype=np.float32
    ) / 255.0
    output_rgb = rgb.astype(np.float32)
    edge = (alpha > 0) & (alpha < 250) & (denominator > 0.01)
    edge_weight = np.clip(1.0 - alpha.astype(np.float32) / 255.0, 0.0, 1.0)
    for channel in range(3):
        weighted = Image.fromarray(
            np.clip(rgb[:, :, channel].astype(np.float32) * opaque, 0, 255).astype(
                np.uint8
            ),
            mode="L",
        ).filter(ImageFilter.GaussianBlur(2.0))
        nearby_color = np.asarray(weighted, dtype=np.float32) / np.maximum(
            denominator, 0.01
        )
        output_rgb[:, :, channel][edge] = (
            output_rgb[:, :, channel][edge] * (1.0 - edge_weight[edge])
            + nearby_color[edge] * edge_weight[edge]
        )

    output_rgb[alpha == 0] = 0
    rgba = np.dstack((np.clip(output_rgb, 0, 255).astype(np.uint8), alpha))
    destination.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(destination, format="PNG", optimize=True)


def create_reef_preview(
    background_path: Path,
    male_path: Path,
    female_path: Path,
    destination: Path,
) -> None:
    canvas = ImageOps.fit(
        Image.open(background_path).convert("RGB"),
        (1536, 1024),
        method=Image.Resampling.LANCZOS,
    ).convert("RGBA")

    male = Image.open(male_path).convert("RGBA")
    female = Image.open(female_path).convert("RGBA")
    male.thumbnail((650, 430), Image.Resampling.LANCZOS)
    female.thumbnail((540, 360), Image.Resampling.LANCZOS)

    canvas.alpha_composite(male, (120, 245))
    canvas.alpha_composite(female, (815, 520))
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(destination, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--male-source", type=Path, required=True)
    parser.add_argument("--female-source", type=Path, required=True)
    parser.add_argument("--background", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    male_output = args.output_dir / "pseudanthias-bimaculatus-male.png"
    female_output = args.output_dir / "pseudanthias-bimaculatus-female.png"
    extract_checkerboard_alpha(args.male_source, male_output)
    extract_checkerboard_alpha(args.female_source, female_output)
    create_reef_preview(
        args.background,
        male_output,
        female_output,
        args.output_dir / "reef-app-preview.png",
    )


if __name__ == "__main__":
    main()
