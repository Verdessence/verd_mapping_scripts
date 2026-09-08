# Dialogue Text Renderer — Postmortem

**Engine:** Counter-Strike: Source 64-bit (TF2-branch), stock, tested on D3D9 and `-vulkan` (DXVK-Native)
**Scope:** custom proportional-font dialogue rendering via `screenspace_general`, VScript-driven
**Period:** ~5 weeks of iteration (this was actually 1-3 days but i got distracted and delayed this by 2 weeks)
**Outcome:** shipped architecture — arbitrary-length authored dialogue, proportional OMORI handwriting font, typewriter reveal, per-player screen-locked display of shared text, 16 server entities total, renderer-agnostic.

---

## 1. The original question

> Can `screenspace_general` on the TF2 branch — 16 float constants, HLSL SM2, no dynamic branching, no dynamic indexing — render proportional (variable-width) text?

Yes. The proof took one evening of shader work and five weeks of everything around it.

---

## 2. Final architecture

```
dialogue.txt ──► bake_dialogue.py ──► dialogue_bank.vtf   (512x512 "line bank": one line per
   (authored)      (offline)      └──► dialogue_boxes.nut   logical row, 2x2 texel-doubled)
                                                    │
font_atlas_16x16.vtf (glyph coverage, 16x16 cells)  │
                                                    ▼
                          screenspace_font_line.vmt + screenspace_font_line_ps20b.vcs
                                                    │
        ┌───────────────────────────────────────────┴──────────────────────────┐
        │ ANTENNA (data path)                      │ DISPLAY (per player)      │
        │ prop_dynamic text_quad.mdl, scale 0.01,  │ SetScriptOverlayMaterial  │
        │ bounds inflated so it always renders.    │ on every player.          │
        │ material_modify_control x7 as children;  │ Overlay binds NULL to the │
        │ MaterialModify proxy writes the SHARED   │ proxy but reads the same  │
        │ IMaterial's vars each frame.             │ IMaterial vars: same-frame│
        └──────────────────────────────────────────┴───────────────────────────┘
                                   ▲
              dialogue_text.nut: DlgInit / ShowBox / TypeBox / HideBox
```

**Per pixel, the shader does:** screen uv → glyph-px coords → row (step-count) → one read of the line bank (cell code, glyph-px index, mask) → one dependent read into the atlas → coverage × mask × box gate × reveal gate → alpha.

**Constants in use:** `c0` = aspect / origin X / origin Y / scale; `c1` = base line / reveal cursor / row count / (unused); `c2.x` = row pitch. Everything else is free.

---

## 3. Design principles that survived contact

1. **Sequential work goes offline; the shader only answers "which region contains me."** Layout, prefix sums, kerning-free advances, box allocation — all baked. The shader never iterates.
2. **Dependent texture reads are SM2's only dynamic indexing.** The atlas is a 256-entry lookup table; the line bank is a 65k-entry one.
3. **Encode data so the GPU cannot misread it, instead of configuring the GPU and hoping.** Data textures are read linear (`$linearread_texture1 1`), texel-doubled so point and bilinear sampling agree byte-for-byte, and never depend on sampler flags being honored.
4. **Never put a value on a rounding boundary by construction.** Half-glyph-px sample points, floor/frac on quotients, and integer-boundary comparisons all became renderer-dependent artifacts. Prefer `step()` counts over `floor()`, reciprocals passed in over divides, and continuous coordinates over snapping.
5. **Never remove a known-good state while standing on an unverified one.** Keep baked defaults in the VMT that render something visible; they are the control group for every experiment.
6. **Know your reload rules.** VMT → `mat_reloadallmaterials`. VTF → `mat_reloadalltextures`. `.nut` → re-`IncludeScript`. `.vcs`, `mat_antialias`, filtering, aniso → full restart. `custom/` outranks loose `materials/`.

---

## 4. Issue log (chronological)

Each entry: **symptom → root cause → fix → lesson.**

### Phase A — getting anything on screen


| # | Symptom                                                | Root cause                                                                                                                                                                    | Fix                                                                                                              | Lesson                                                                                                                |
| - | ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| 1 | `Couldn't load pixel shader screenspace_font_poc_ps2x` | Engine loads compiled`.vcs`, never HLSL; `_ps2x` is a *source* naming convention.                                                                                             | Compile via ficool2's`sdk_screenspace_shaders` toolchain.                                                        | Three names: source`_ps2x.hlsl`, compiled `_ps20b.vcs`, VMT string.                                                   |
| 2 | `Couldn't load pixel shader ..._ps20bd`                | Engine rewrites`$pixshader` names; writing `_ps20b` yourself triggers a second mangle.                                                                                        | VMT references`_ps20`; engine appends `b`. (Verified in `screenspace_general.cpp`.)                              | Read the engine source when an error message contains characters you didn't type.                                     |
| 3 | Fullscreen magenta ✓ then solid white box             | Atlas VTF not loading → opaque error texture → coverage=1 everywhere.                                                                                                       | Convert PNG → VTF, correct path.                                                                                | A solid silhouette means geometry works and the texture doesn't.                                                      |
| 4 | Atlas "blank" in preview                               | White ink on transparent bg looks empty in viewers; also baked red gridlines, custom glyph order (A–Z, a–z, 0–9, shift-row punctuation), centered not left-aligned glyphs. | Programmatic atlas cleaner: strip grid, left-align, mirror coverage into RGB+A; contact sheet for mapping audit. | Inspect assets with code, not eyeballs.                                                                               |
| 5 | Red-everywhere channel debug (coverage=1)              | Stale flattened VTF in`cstrike/custom/` shadowing the new one.                                                                                                                | Delete stale file.                                                                                               | **The stale-file bug.** Struck four times total (VTF ×2, `.nut`, VMT default). Bake timestamps into generated files. |

### Phase B — dynamic text


| #  | Symptom                            | Root cause                                                                                                                             | Fix                                                                                   | Lesson                                                                                                                                          |
| -- | ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| 6  | 12-glyph ceiling                   | 16 fp32 constants; proportional packing = 1 glyph/float.                                                                               | Line-bank texture (v2).                                                               | Constants are for*dynamic* scalars, textures are for *bulk* data.                                                                               |
| 7  | MMC changes nothing on the overlay | `CMaterialModifyProxy::OnBind` returns immediately when bound with NULL; screen overlays always bind NULL. Architecturally impossible. | Antenna entity (see §2). Also retro-explained an older animated-VTF`$frame` failure. | Proxies need a rendered entity. Material vars are global state on the IMaterial — the writer and the reader don't have to be the same surface. |
| 8  | `expected IDENTIFIER` at `base`    | `base` is a Squirrel reserved word.                                                                                                    | Field renamed`row0`.                                                                  | Know the host language's keyword list.                                                                                                          |
| 9  | `the index '$c1_x' does not exist` | API called before init / v1 & v2 files sharing global names, stale`::TextCtl`.                                                         | `Dlg*` namespace, liveness guards, publish-on-success init.                           | Guard every public entry point; namespace every module.                                                                                         |
| 10 | 64-player / entity-count concern   | Misframed: shared dialogue needs one antenna, not one per player.                                                                      | Antenna + per-player overlay. 16 edicts total.                                        | Separate the*content* (global) from the *display surface* (per player).                                                                         |

### Phase C — the line-1 "comb" (four wrong theories, one right one)


| #  | Symptom                                                                                       | Root cause                                                                                                                                                                                                                                                     | Fix                                                                                                                | Lesson                                                                                                                                                      |
| -- | --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 11 | All text garbled, layout intact                                                               | Line bank read through sRGB→linear decode on`-vulkan`: mask (255) survives, codes crushed, localU warped.                                                                                                                                                     | `$linearread_texture1 1`.                                                                                          | Data textures must be read linear. Layout-intact garble = value corruption, not geometry.                                                                   |
| 12 | Line 1 combed (scanlines missing), lines 2–3 fine                                            | *Theory 1 (wrong):* bank row 0 clamp-border quirk.                                                                                                                                                                                                             | Row-0 reserve (harmless, kept).                                                                                    | Row reserve fixed nothing; the c1_x VMT default hid that by shifting content.                                                                               |
| 13 | "Line 3 disappeared"                                                                          | VMT default`$c1_x 0` now pointed at the reserved blank row.                                                                                                                                                                                                    | `$c1_x 1`.                                                                                                         | Changing a convention means auditing every baked constant.                                                                                                  |
| 14 | Comb persists                                                                                 | *Theory 2 (wrong):* ghost second overlay.                                                                                                                                                                                                                      | —                                                                                                                 | Two overlay slots are independent;`r_screenoverlay ""` test was valid and negative.                                                                         |
| 15 | Comb persists; quad view "noisy"                                                              | *Theory 3 (partly wrong):* bank samples on bilinear knife-edge.                                                                                                                                                                                                | v2→v3: glyph-px index encoding + 2×2 texel doubling (bilinear-proof).**Kept: real hardening.**                   | Even wrong theories can yield correct hardening.                                                                                                            |
| 16 | Comb persists in RGB mask channel                                                             | *Theory 4 (wrong):* half-pixel convention in DXVK / custom backend.                                                                                                                                                                                            | Checker probe: identical on both backends.                                                                         | `-vulkan` = Valve's DXVK-Native, not custom. Build a probe that can't lie.                                                                                  |
| 17 | Comb persists                                                                                 | *Theory 5 (wrong):* anisotropic filtering.                                                                                                                                                                                                                     | Trilinear +`mat_forceaniso 1` + restart: no change.                                                                | `mat_antialias`/aniso/filtering need restarts; `mat_filtertextures` appears inert on vk.                                                                    |
| 18 | **Comb vanishes at pitch 32, returns at 20; different pitches comb under different compiles** | **`row = floor(py/pitch)` via `x - frac(x)` was landing on a rounding margin; outcome depended on instruction ordering per compile and on DXVK's translation.** Pitch only affects `row` for the first band (`ly = py` there) — the deduction that nailed it. | **`row = step(pitch,py) + step(2*pitch,py)`** — no floor, no frac, no divide. Clean at 20/24/32 on both backends. | **The tell was there from day one: v1 had no division and never combed.** Renderer-dependent + immune to texture fixes ⇒ suspect arithmetic, not sampling. |

---

## 5. What was learned about the engine (verified, not guessed)

- `screenspace_general` uploads `$c0_x..$c3_w` every draw (`DYNAMIC_STATE`), and c4–c7 carry bound-texture pixel sizes (free resolution/aspect source via `_rt_FullFrameFB`).
- `$pixshader` ending in `_ps20` is auto-upgraded to `_ps20b`.
- `CMaterialModifyProxy` only fires for materials rendered by an entity; it walks that entity's move-children for `material_modify_control`s whose `materialName` resolves to the same `IMaterial`. Un-fired MMCs are inert.
- Two overlay slots (`r_screenoverlay`, `SetScriptOverlayMaterial`) stack.
- `$alpha_blend`, `$copyalpha`, `$linearread_*`, `$linearwrite`, `$x360appchooser`, `$softwareskin`, `$translucent` all real and load-bearing; `$ignorez` ignored on models.
- Material vars persist for the game session (across map/round changes).
- `-vulkan` on 64-bit CSS/TF2 = DXVK-Native reported as `shaderapivk`; behaves differently from D3D9 on sRGB texture reads and on floor/frac rounding margins.

---

## 6. Open items / roadmap

1. **Resolution independence** — replace hardcoded `$c0_x` aspect with c6 texel-size from `_rt_FullFrameFB` in `$texture2`; test 1080p and ultrawide.
2. **Lifecycle** — `DlgInit` on round start, `DlgReset` on round end, overlay on `player_spawn` for late joiners; precache `text_quad.mdl`.
3. **Known sensitivity** — one `floor` remains (atlas texel snap `vt`). If a future scale/resolution combs, switch atlas sampling to continuous coords + bilinear.
4. **FX** — text color (`c2.yzw`), SDF dialogue box in-shader, shaky/wavy text via `CurrentTime` proxy, typewriter blips + skip, portraits via `$texture3`.
5. **Content** — per-map dialogue scripts, sequence scripting, advance-permission logic (designated player).
6. **Back pocket** — `_rt_Camera` brush-encoding for arbitrary runtime text; v1 constants shader for player names.

---

## 7. One-paragraph version

We proved proportional text is feasible in SM2 `screenspace_general` in a night, then spent five weeks discovering that every layer between a shader and a player's screen — toolchain naming, texture flags, filesystem precedence, proxy binding rules, sRGB reads, sampler behavior, and finally floating-point rounding under two renderers — has opinions. The shipping design routes dialogue through a baked line-bank texture, drives it with seven material vars via an always-rendered antenna prop, and displays it per player as a screen overlay. The bug that cost the most time was a `floor()` of a divide. The habit that saved the most time was keeping a visible known-good state as a control group. The test that broke the case open was one the author ran on their own initiative: comparing renderers.
