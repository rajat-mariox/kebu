"""Build square launcher icon sources from the brand logo."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(r"C:\PRojects\kebu")
SRC = ROOT / "logo renders" / "Full logo_verticle layout_light background.png"

CUSTOMER_OUT = ROOT / "KEBU" / "kebu_customer" / "assets" / "logo"
DRIVER_OUT = ROOT / "KEBU" / "kebu_driver" / "assets" / "logo"

CANVAS = 1024
FG_INSET = 0.72  # icon occupies ~72% of canvas (Android adaptive safe zone is 66%)
BG_TOP = (255, 152, 80)     # warm orange
BG_BOTTOM = (255, 78, 96)   # pink-red

def crop_icon(src_path: Path) -> Image.Image:
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size
    # The wordmark "kebu / one" sits in the lower half. The icon (cube character)
    # sits in the upper portion. Crop the top ~52% then auto-trim by alpha.
    upper = img.crop((0, 0, w, int(h * 0.46)))
    bbox = upper.getbbox()
    if bbox is None:
        raise RuntimeError("Empty alpha in upper region")
    return upper.crop(bbox)

def vertical_gradient(size: int, top_rgb, bottom_rgb) -> Image.Image:
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        r = round(top_rgb[0] * (1 - t) + bottom_rgb[0] * t)
        g = round(top_rgb[1] * (1 - t) + bottom_rgb[1] * t)
        b = round(top_rgb[2] * (1 - t) + bottom_rgb[2] * t)
        grad.putpixel((0, y), (r, g, b))
    return grad.resize((size, size))

def fit_centered(canvas_size: int, fg: Image.Image, inset_ratio: float) -> Image.Image:
    out = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    target = int(canvas_size * inset_ratio)
    fw, fh = fg.size
    scale = min(target / fw, target / fh)
    new_w, new_h = int(fw * scale), int(fh * scale)
    resized = fg.resize((new_w, new_h), Image.LANCZOS)
    out.paste(resized, ((canvas_size - new_w) // 2, (canvas_size - new_h) // 2), resized)
    return out

def main():
    icon = crop_icon(SRC)
    print(f"Cropped icon: {icon.size}")

    # Foreground (transparent) — for Android adaptive icon foreground
    foreground = fit_centered(CANVAS, icon, FG_INSET)

    # Solid (orange gradient bg + icon) — for iOS & legacy Android launcher
    bg = vertical_gradient(CANVAS, BG_TOP, BG_BOTTOM).convert("RGBA")
    # Round corners slightly for the source png (iOS/Android both apply their own mask anyway)
    solid = bg.copy()
    solid.alpha_composite(foreground)

    # Background-only (solid orange) — for Android adaptive icon background layer
    background = vertical_gradient(CANVAS, BG_TOP, BG_BOTTOM).convert("RGBA")

    for out_dir in (CUSTOMER_OUT, DRIVER_OUT):
        out_dir.mkdir(parents=True, exist_ok=True)
        solid.save(out_dir / "launcher_icon.png")
        foreground.save(out_dir / "launcher_icon_foreground.png")
        background.save(out_dir / "launcher_icon_background.png")
        print(f"Wrote launcher icon set into {out_dir}")

if __name__ == "__main__":
    main()
