#!/usr/bin/env python3
"""
bake_dialogue.py -- OMORI-font dialogue line bank baker.

Input : font_metrics.nut  (char -> [atlas cell, advance glyph px])
        dialogue script file:
            [box_id]
            LINE ONE TEXT
            line two text
            <blank line between boxes>
Output: dialogue_bank.png       (preview/VTFEdit fallback source)
        dialogue_bank.vtf       (BGRA8888, point-sample, no mips, clamped)
        dialogue_boxes.nut      (::DialogueBoxes table for VScript)
        preview_<box>.png       (offline simulation of the shader output)

Line bank format (512x512, one row per line, 512 glyph-px columns):
    R = atlas cell code        (valid only where B > 0)
    G = x-within-cell * 255    (localU, fraction of the 16-glyph-px cell)
    B = 255 where a glyph occupies this column, 0 in gaps/spaces
    A = 255                    (unused)
"""
import re, sys, json, struct, os

BANK_W, BANK_H = 512, 512   # texture size
LINE_W, LINE_H = 256, 256   # logical: 2x2 texel doubling = bilinear-proof
CELL = 16                 # glyph px per atlas cell
SPACE_ADV = 5
MAX_ROWS_PER_BOX = 3

# ---------------------------------------------------------------- metrics
def load_metrics(path):
    txt = open(path, encoding="utf-8").read()
    glyphs = {}
    for m in re.finditer(r'"((?:\\.|[^"\\])+)"\s*:\s*\[\s*(\d+)\s*,\s*(\d+)\s*\]', txt):
        ch = m.group(1).replace('\\"','"').replace("\\\\","\\")
        glyphs[ch] = (int(m.group(2)), int(m.group(3)))
    return glyphs

# ---------------------------------------------------------------- layout
def rasterize_line(text, glyphs, row_px):
    """Fill one 512-wide row of texels; return (pen_end, breakpoints)."""
    pen = 0
    breaks = []
    for ch in text:
        if ch == " ":
            pen += SPACE_ADV
            breaks.append(("_space", pen))
            continue
        if ch not in glyphs:
            print(f"  [warn] no glyph for {ch!r}, skipped")
            continue
        cell, adv = glyphs[ch]
        if pen + adv > LINE_W:
            raise ValueError(f"line overflows {LINE_W} glyph px: {text!r}")
        for i in range(adv):
            # BANK FORMAT v3: G stores the glyph-px INDEX (i*16); every
            # logical column is written to TWO texels and every line to
            # TWO rows, so samples at the shared corner are bilinear-proof
            # (4 identical contributing texels). Ship with matching shader.
            texel = (cell, i * 16, 255, 255)
            row_px[0][(pen + i)*2]     = texel
            row_px[0][(pen + i)*2 + 1] = texel
            row_px[1][(pen + i)*2]     = texel
            row_px[1][(pen + i)*2 + 1] = texel
        pen += adv
        breaks.append((ch, pen))
    return pen, breaks

# ---------------------------------------------------------------- vtf
VTF_FLAGS = 0x1 | 0x4 | 0x8 | 0x100 | 0x200 | 0x2000  # POINTSAMPLE|CLAMPS|CLAMPT|NOMIP|NOLOD|8BITALPHA
def write_vtf(path, w, h, rgba_rows):
    hdr  = b"VTF\0"
    hdr += struct.pack("<III", 7, 1, 64)              # version 7.1, headerSize 64
    hdr += struct.pack("<HHI", w, h, VTF_FLAGS)
    hdr += struct.pack("<HH", 1, 0)                   # frames, firstFrame
    hdr += b"\0"*4
    hdr += struct.pack("<fff", 0.2, 0.2, 0.2)         # reflectivity
    hdr += b"\0"*4
    hdr += struct.pack("<f", 1.0)                     # bump scale
    hdr += struct.pack("<I", 12)                      # highRes fmt = BGRA8888
    hdr += struct.pack("<B", 1)                       # mip count
    hdr += struct.pack("<I", 0xFFFFFFFF)              # no low-res thumbnail
    hdr += struct.pack("<BB", 0, 0)
    hdr += b"\0" * (64 - len(hdr))
    body = bytearray()
    for row in rgba_rows:
        for (r,g,b,a) in row:
            body += bytes((b,g,r,a))                  # BGRA order
    open(path, "wb").write(hdr + bytes(body))

# ---------------------------------------------------------------- main
def main(metrics_path, script_path, outdir):
    glyphs = load_metrics(metrics_path)
    print(f"metrics: {len(glyphs)} glyphs")

    bank = [[(0,0,0,255)]*BANK_W for _ in range(BANK_H)]
    boxes, next_row = {}, 1          # logical line 0 reserved: keeps text off the
    cur_id, cur_lines = None, []     # v=0 clamp border (renderer quirks)

    def flush():
        nonlocal next_row
        if cur_id is None: return
        if len(cur_lines) > MAX_ROWS_PER_BOX:
            raise ValueError(f"box {cur_id}: >{MAX_ROWS_PER_BOX} lines")
        base = next_row
        steps, gcol_off = [], 0
        for li, line in enumerate(cur_lines):
            L = base + li
            row_px = (bank[L*2], bank[L*2 + 1])
            pen, breaks = rasterize_line(line, glyphs, row_px)
            for ch, p in breaks:
                if ch != "_space":
                    steps.append(gcol_off + p)        # reveal breakpoint after this glyph
            gcol_off += LINE_W                        # next line offsets by 256 global cols
        boxes[cur_id] = { "base": base, "rows": len(cur_lines),
                          "steps": steps, "total": gcol_off }
        next_row += len(cur_lines)

    for raw in open(script_path, encoding="utf-8").read().splitlines() + [""]:
        line = raw.rstrip("\n")
        if line.startswith("[") and line.endswith("]"):
            flush(); cur_id, cur_lines = line[1:-1], []
        elif line.strip() == "":
            flush(); cur_id, cur_lines = None, []
        elif cur_id is not None:
            cur_lines.append(line)
        elif line.strip():
            print(f"  [WARN] orphaned line (no [box] header active, DISCARDED): {line!r}")
    if next_row * 2 >= BANK_H: raise ValueError("line bank full (>256 logical lines)")
    print(f"baked {len(boxes)} boxes into {next_row} rows")

    os.makedirs(outdir, exist_ok=True)
    from PIL import Image
    img = Image.new("RGBA",(BANK_W,BANK_H))
    img.putdata([px for row in bank for px in row])
    img.save(f"{outdir}/dialogue_bank.png")
    write_vtf(f"{outdir}/dialogue_bank.vtf", BANK_W, BANK_H, bank)

    with open(f"{outdir}/dialogue_boxes.nut","w") as f:
        import datetime
        stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        f.write("// generated by bake_dialogue.py -- do not hand-edit\n")
        f.write(f'printl("[dlg] boxes table loaded: baked {stamp}, {len(boxes)} boxes, row0-reserved");\n')
        f.write("::DialogueBoxes <- {\n")
        for bid, b in boxes.items():
            steps = ",".join(str(s) for s in b["steps"])
            f.write(f'\t"{bid}": {{ row0 = {b["base"]}, rows = {b["rows"]}, '
                    f'total = {b["total"]}, steps = [{steps}] }},\n')
        f.write("}\n")
    print("wrote dialogue_bank.png / .vtf / dialogue_boxes.nut")
    return bank, boxes

# ------------------------------------------------- shader simulator (QA)
def preview(bank, boxes, box_id, atlas_path, outdir, scale=4, pitch=20):
    """Pixel-faithful simulation of the v2 shader for one box."""
    from PIL import Image
    atlas = Image.open(atlas_path).convert("RGBA")
    b = boxes[box_id]
    W, Hrows = LINE_W*scale//2, b["rows"]
    img = Image.new("RGBA", (W, Hrows*pitch*scale//2), (20,16,28,255))
    ap = atlas.load(); ip = img.load()
    for oy in range(img.height):
        py = oy * 2.0 / scale                       # glyph px (2:1 like 512-canvas math)
        row = int(py // pitch); ly = py - row*pitch
        if row >= b["rows"] or ly >= CELL: continue
        for ox in range(img.width):
            px = ox * 2.0 / scale
            t = bank[(b["base"]+row)*2][int(px)*2]
            if t[2] < 128: continue
            code = t[0]
            local_idx = int(round(t[1] / 16.0))
            lx = local_idx + (px - int(px))
            ut, vt = int(lx * 2), int(ly * 2)          # texel-center snap
            col, arow = code % 16, code // 16
            au = int((col + (ut + 0.5) / 32.0) / 16 * atlas.width)
            av = int((arow + (vt + 0.5) / 32.0) / 16 * atlas.height)
            cov = ap[min(au,atlas.width-1), min(av,atlas.height-1)][3]
            if cov > 10:
                c = ip[ox,oy]
                ip[ox,oy] = (255,255,255, 255) if cov > 128 else \
                            (c[0]+ (255-c[0])*cov//255, c[1]+(255-c[1])*cov//255, c[2]+(255-c[2])*cov//255, 255)
    img.save(f"{outdir}/preview_{box_id}.png")
    print(f"wrote preview_{box_id}.png")

if __name__ == "__main__":
    bank, boxes = main(sys.argv[1], sys.argv[2], sys.argv[3])
    if len(sys.argv) > 4:                            # optional: atlas for previews
        for bid in boxes: preview(bank, boxes, bid, sys.argv[4], sys.argv[3])
