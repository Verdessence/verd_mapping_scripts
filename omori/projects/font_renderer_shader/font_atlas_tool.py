#!/usr/bin/env python3
"""
font_atlas_tool.py -- everything needed to go from "a font drawn on a grid"
to "an atlas + metrics the Verdessence text shader can consume".

    # 1. make a blank guide to draw a new font into (optional)
    python font_atlas_tool.py guide  --cell 32 --out guide.png

    # 2. clean + left-align a drawn atlas and emit metrics
    python font_atlas_tool.py prep   drawn.png --cell 32 --out ./atlas_out

`prep` produces, in --out:
    font_atlas_clean.png     coverage in RGB *and* A, glyphs flush-left in
                             their cells, guide lines stripped  -> VTF this
    font_atlas_contact.png   every cell labelled with index + char (QA)
    font_metrics.nut         ::FontGlyphs { "A": [cell, advance], ... }
    font_metrics.json        same, for other tooling

WHY LEFT-ALIGN:  the bank stores each glyph's pen-relative x index and the
shader samples the atlas at cell-x = index + frac(px). That assumes the
glyph's ink starts at x=0 of its cell; the advance is measured from the
cell's left edge. Centered glyphs would render with a blank left gap and a
clipped right side. Left-aligning makes atlas and metrics share one origin.

CONVENTIONS (must match the shader/baker):
    - 16 x 16 cells; any cell size in pixels (32 -> 512 atlas, 64 -> 1024)
    - one cell == 16 "glyph px" regardless of pixel size; metrics are in
      glyph px, i.e. pixels / (cell/16)
    - glyph order = --order string, cell 0 first, row-major
    - guide lines are any pixel that is "mostly one hue with low other
      channels" (default red); ink is anything else with alpha > 0
"""
import argparse, json, os, re, sys
from PIL import Image, ImageDraw

DEFAULT_ORDER = ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
                 "!@#$%^&*()_+-=[]{}|;:'\",.<>?/\\`~")
GRID = 16
TRACKING_PX = 2          # pixels of air added to each advance (atlas px)
SPACE_ADV_GLYPHPX = 5

# --------------------------------------------------------------- guide
def cmd_guide(a):
    size = a.cell * GRID
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r, g, b = a.grid_rgb
    for i in range(GRID + 1):
        x = min(i * a.cell, size - 1)
        d.line([(x, 0), (x, size)], fill=(r, g, b, 96))
        d.line([(0, x), (size, x)], fill=(r, g, b, 96))
    order = a.order
    for idx in range(GRID * GRID):
        cy, cx = divmod(idx, GRID)
        ch = order[idx] if idx < len(order) else ""
        # left-edge marker: where the shader will assume ink begins
        d.line([(cx*a.cell + 1, cy*a.cell + 2), (cx*a.cell + 1, (cy+1)*a.cell - 3)],
               fill=(r, g, b, 160))
        if ch:
            d.text((cx*a.cell + 3, cy*a.cell + 1), ch, fill=(r, g, b, 140))
        d.text((cx*a.cell + 3, (cy+1)*a.cell - 11), str(idx), fill=(r, g, b, 90))
    img.save(a.out)
    print(f"wrote {a.out} ({size}x{size}, {a.cell}px cells). Draw glyphs anywhere in a cell;")
    print("prep will left-align them. Keep ink off the guide colour.")

# --------------------------------------------------------------- prep
def is_guide(px, grid_rgb):
    r, g, b, a = px
    if a == 0: return False
    gr, gg, gb = grid_rgb
    # "mostly the guide hue": dominant channel matches, others weak
    dom = max(gr, gg, gb)
    if dom == gr:  return r > 150 and g < 100 and b < 100
    if dom == gg:  return g > 150 and r < 100 and b < 100
    return b > 150 and r < 100 and g < 100

def cmd_prep(a):
    src = Image.open(a.src).convert("RGBA")
    size = a.cell * GRID
    if src.size != (size, size):
        sys.exit(f"expected {size}x{size} for --cell {a.cell}, got {src.size}")
    sp = src.load()
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0)); op = out.load()
    scale = a.cell / 16.0                       # atlas px per glyph px
    order = a.order
    metrics = {}                                # char -> [cell, advance_glyphpx]

    for idx in range(GRID * GRID):
        cy, cx = divmod(idx, GRID)
        ink = []
        for y in range(a.cell):
            for x in range(a.cell):
                p = sp[cx*a.cell + x, cy*a.cell + y]
                if p[3] > a.alpha_min and not is_guide(p, a.grid_rgb):
                    ink.append((x, y, p[3]))
        if not ink:
            continue
        xmin = min(i[0] for i in ink); xmax = max(i[0] for i in ink)
        for x, y, al in ink:                    # shift flush-left
            op[cx*a.cell + (x - xmin), cy*a.cell + y] = (al, al, al, al)
        inkw_px = xmax - xmin + 1
        adv = max(2, min(16, round((inkw_px + TRACKING_PX) / scale)))
        ch = order[idx] if idx < len(order) else None
        if ch is None:
            print(f"  [warn] cell {idx} has ink but no character in --order")
            continue
        metrics[ch] = [idx, adv]

    emit_outputs(out, metrics, a.cell, a.out, space_adv=SPACE_ADV_GLYPHPX)

def emit_outputs(out, metrics, cell, outdir, space_adv):
    size = cell * GRID
    scale = cell / 16.0
    os.makedirs(outdir, exist_ok=True)
    out.save(f"{outdir}/font_atlas_clean.png")
    a = type("A", (), {"out": outdir, "cell": cell})   # tiny shim for the code below

    # contact sheet
    sheet = Image.new("RGBA", (size, size), (24, 24, 32, 255)); sheet.alpha_composite(out)
    d = ImageDraw.Draw(sheet)
    for ch, (idx, adv) in metrics.items():
        cy, cx = divmod(idx, GRID)
        d.rectangle([cx*a.cell, cy*a.cell, (cx+1)*a.cell-1, (cy+1)*a.cell-1], outline=(60,60,80,255))
        d.text((cx*a.cell+1, (cy+1)*a.cell-11), f"{idx}", fill=(255,80,80,255))
        d.text((cx*a.cell+1, cy*a.cell+1), f"{ch}:{adv}", fill=(120,220,120,255))
        d.line([(cx*a.cell + adv*scale, cy*a.cell), (cx*a.cell + adv*scale, (cy+1)*a.cell-1)],
               fill=(255,200,0,120))            # advance marker
    sheet.save(f"{a.out}/font_atlas_contact.png")

    # metrics
    def sq(s): return s.replace("\\", "\\\\").replace('"', '\\"')
    with open(f"{a.out}/font_metrics.nut", "w", encoding="utf-8") as f:
        f.write("// generated by font_atlas_tool.py -- [atlas cell, advance glyph px]\n")
        f.write("::FontGlyphs <- {\n")
        f.write(",\n".join(f'\t"{sq(ch)}": [{c}, {adv}]' for ch, (c, adv) in
                           sorted(metrics.items(), key=lambda kv: kv[1][0])))
        f.write("\n}\n")
    json.dump({"space_advance_glyphpx": space_adv, "cell_px": a.cell,
               "char_to_cell": {ch: v[0] for ch, v in metrics.items()},
               "cell_advance_glyphpx": {str(v[0]): v[1] for v in metrics.values()}},
              open(f"{a.out}/font_metrics.json", "w"), indent=1)
    print(f"{len(metrics)} glyphs -> {a.out}/  (clean atlas, contact sheet, metrics)")
    print(f"space advance: {space_adv} glyph px  (set SPACE_ADV in bake_dialogue.py to match)")
    print("VTF the clean atlas: BGRA8888, point sample (or bilinear), no mips/LOD, clamp S+T, no sRGB.")

# --------------------------------------------------------------- ttf
def cmd_ttf(a):
    """Rasterize a TrueType/OpenType font straight into a left-aligned atlas."""
    from PIL import ImageFont
    if not os.path.isfile(a.font):
        sys.exit(f"font not found: {a.font!r}\n  (check the exact filename -- e.g. "
                 f"'JetBrainsMono-Thin.ttf' -- or pass a full path)")
    cell, size = a.cell, a.cell * GRID
    scale = cell / 16.0
    chars = a.chars

    def fits(px):
        f = ImageFont.truetype(a.font, px)
        asc, desc = f.getmetrics()
        if asc + desc > cell - 2: return None
        for ch in chars:                          # widest ink must fit a cell
            bb = f.getbbox(ch)
            if bb and (bb[2] - bb[0]) > cell - TRACKING_PX: return None
        return f
    if a.size:
        font = fits(a.size) or ImageFont.truetype(a.font, a.size)
        if not fits(a.size): print(f"  [warn] size {a.size} overflows {cell}px cells; glyphs may clip")
    else:                                          # auto: largest size that fits
        font, px = None, cell
        while px > 4 and font is None:
            font = fits(px); px -= 1
        print(f"auto size: {px+1}px")
    asc, desc = font.getmetrics()
    baseline = (cell - (asc + desc)) // 2 + asc   # vertically centred line

    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    metrics = {}
    for idx, ch in enumerate(chars):
        if idx >= GRID * GRID: print("  [warn] more than 256 chars; truncated"); break
        cy, cx = divmod(idx, GRID)
        glyph = Image.new("L", (cell * 2, cell), 0)   # wide scratch, then crop
        ImageDraw.Draw(glyph).text((cell // 2, baseline), ch, font=font, fill=255, anchor="ls")
        bb = glyph.getbbox()
        if not bb: continue                            # no ink (space etc.)
        ink = glyph.crop((bb[0], 0, bb[2], cell))      # flush-left = ink starts at x=0
        w = min(ink.width, cell)
        rgba = Image.merge("RGBA", (ink, ink, ink, ink)).crop((0, 0, w, cell))
        out.paste(rgba, (cx * cell, cy * cell))
        if a.advance == "font":                        # typographic advance, never < ink
            adv_px = max(ink.width + 1, font.getlength(ch))
        else:                                          # ink + tracking (matches drawn-atlas path)
            adv_px = ink.width + TRACKING_PX
        metrics[ch] = [idx, max(2, min(16, round(adv_px / scale)))]

    space_adv = max(2, round(font.getlength(" ") / scale)) if " " not in chars else SPACE_ADV_GLYPHPX
    emit_outputs(out, metrics, cell, a.out, space_adv=space_adv)

# --------------------------------------------------------------- cli
def rgb(s):
    r, g, b = (int(v) for v in s.split(","))
    return (r, g, b)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("guide", help="blank labelled grid to draw a font into")
    g.add_argument("--cell", type=int, default=32)
    g.add_argument("--out", default="font_guide.png")
    g.add_argument("--order", default=DEFAULT_ORDER)
    g.add_argument("--grid-rgb", type=rgb, default=(255, 0, 0))
    g.set_defaults(fn=cmd_guide)
    p = sub.add_parser("prep", help="clean + left-align + metrics")
    p.add_argument("src")
    p.add_argument("--cell", type=int, default=32)
    p.add_argument("--out", default="atlas_out")
    p.add_argument("--order", default=DEFAULT_ORDER)
    p.add_argument("--grid-rgb", type=rgb, default=(255, 0, 0))
    p.add_argument("--alpha-min", type=int, default=8)
    p.set_defaults(fn=cmd_prep)
    t = sub.add_parser("ttf", help="rasterize a .ttf/.otf straight into an atlas + metrics")
    t.add_argument("font", help="path to .ttf / .otf")
    t.add_argument("--chars", default=DEFAULT_ORDER, help="characters, in atlas cell order")
    t.add_argument("--cell", type=int, default=32, help="cell size px (32 -> 512 atlas, 64 -> 1024)")
    t.add_argument("--size", type=int, default=0, help="font px size (default: auto-fit)")
    t.add_argument("--advance", choices=["ink", "font"], default="font",
                   help="'font' = real typographic advances (default); 'ink' = ink width + tracking")
    t.add_argument("--out", default="atlas_out")
    t.set_defaults(fn=cmd_ttf)
    a = ap.parse_args(); a.fn(a)
