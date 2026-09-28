#!/usr/bin/env python3
"""Builds the README images and GIFs from rendered frames.

1. Render the frames (from the example directory):
       flutter test tool/capture_media_test.dart
2. Assemble them (from the repository root):
       python tool/build_media.py

Requires Pillow. Frames are read from screenshots/frames/<scene>/ and the
results are written to screenshots/.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
FRAMES = ROOT / "screenshots" / "frames"
OUT = ROOT / "screenshots"


def _frames(scene: str) -> tuple[list[Path], list[int]]:
    directory = FRAMES / scene
    files = sorted(directory.glob("*.png"))
    durations_file = directory / "durations.txt"
    if durations_file.exists():
        durations = [int(x) for x in durations_file.read_text().split()]
    else:
        durations = [100] * len(files)
    if len(durations) != len(files):
        raise SystemExit(f"{scene}: {len(files)} frames, {len(durations)} durations")
    return files, durations


def _resize(image: Image.Image, width: int) -> Image.Image:
    height = round(image.height * width / image.width)
    return image.resize((width, height), Image.LANCZOS)


def build_gif(scene: str, width: int, colors: int = 192, name: str | None = None) -> None:
    files, durations = _frames(scene)
    frames: list[Image.Image] = []
    times: list[int] = []
    previous = None
    for file, duration in zip(files, durations):
        image = _resize(Image.open(file).convert("RGB"), width)
        # Merge frames identical to the previous one into a longer frame.
        if previous is not None and ImageChops.difference(image, previous).getbbox() is None:
            times[-1] += duration
            continue
        frames.append(image)
        times.append(duration)
        previous = image
    times[-1] += 1200  # rest on the last frame before looping

    # One palette for the whole animation, sampled across it, so colours do not
    # shift from frame to frame. No dithering: flat UI compresses far better.
    step = max(1, len(frames) // 16)
    sample = frames[::step]
    strip = Image.new("RGB", (width, frames[0].height * len(sample)))
    for i, frame in enumerate(sample):
        strip.paste(frame, (0, i * frames[0].height))
    palette = strip.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    quantized = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]

    target = OUT / f"{name or scene}.gif"
    quantized[0].save(
        target,
        save_all=True,
        append_images=quantized[1:],
        duration=times,
        loop=0,
        optimize=True,
        disposal=1,
    )
    print(f"{target.name}: {len(quantized)} frames, {target.stat().st_size / 1e6:.2f} MB")


def build_still(scene: str, width: int, name: str) -> None:
    files, _ = _frames(scene)
    image = _resize(Image.open(files[-1]).convert("RGB"), width)
    target = OUT / f"{name}.png"
    image.save(target, optimize=True)
    print(f"{target.name}: {image.width}x{image.height}, {target.stat().st_size / 1e6:.2f} MB")


def _rounded(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius, fill=255)
    result = image.convert("RGBA")
    result.putalpha(mask)
    return result


def build_hero(scenes: list[str], name: str) -> None:
    phones = [Image.open(_frames(scene)[0][-1]).convert("RGB") for scene in scenes]
    phones = [_rounded(_resize(p, 360), 34) for p in phones]
    gap, margin = 48, 64
    width = margin * 2 + sum(p.width for p in phones) + gap * (len(phones) - 1)
    height = margin * 2 + max(p.height for p in phones)

    # Soft indigo backdrop, drawn as a vertical gradient.
    top, bottom = (238, 240, 255), (226, 222, 250)
    canvas = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(canvas)
    for y in range(height):
        t = y / (height - 1)
        draw.line(
            [(0, y), (width, y)],
            fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)),
        )

    x = margin
    for phone in phones:
        y = (height - phone.height) // 2
        shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            (x, y + 14, x + phone.width, y + phone.height + 14), 34, fill=(40, 30, 90, 70)
        )
        shadow = shadow.filter(ImageFilter.GaussianBlur(18))
        canvas.paste(shadow, (0, 0), shadow)
        canvas.paste(phone, (x, y), phone)
        x += phone.width + gap

    target = OUT / f"{name}.png"
    canvas.save(target, optimize=True)
    print(f"{target.name}: {canvas.width}x{canvas.height}, {target.stat().st_size / 1e6:.2f} MB")


def main() -> None:
    OUT.mkdir(exist_ok=True)
    build_hero(["still_catalog_phone", "still_board_phone", "still_playground_phone"], "hero")
    build_still("still_comparison", 1290, "gridview-vs-mosaicgrid")
    build_still("still_catalog_desktop", 1600, "catalog-desktop")
    build_still("still_board_desktop", 1600, "board-desktop")
    build_still("still_playground_desktop", 1600, "playground-desktop")
    build_gif("catalog", 340)
    build_gif("board", 340)
    build_gif("adaptive", 820)
    build_gif("playground", 820)


if __name__ == "__main__":
    main()
