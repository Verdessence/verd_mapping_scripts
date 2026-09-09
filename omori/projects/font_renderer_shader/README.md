# Font Renderer Shader
> [!CAUTION]
> This project was 99% vibe coded by Claude Fable 5/5.1.

Proportional text display shader with a few effects

## Configuration
> [!NOTE]
> Relevant only to [dialogue_text.nut](dialogue_text.nut).

### `DlgInit(pos)`
> [!WARNING]
> Do not write pos value as `x, y, z`, as the command interprets it as three different parameters rather than a vector3. Write `Vector(x, y, z)` instead.
Spawns the antenna quad and `material_modify_control` entities to apply the overlay to every player. Can run once as this is reinitialized on round restart.

```
pos (vector3)   // World position on screen.
                // Looking to position your text? check the VMT's $c0_y/z/w values.
```

### `ShowBox(id)`
```
id (string) // ID string text to display in dialogue_boxes.nut on global func ::DialogueBoxes
```

### `TypeBox(id, fl_cps, opts = {})`
Typewriter effect
```
id (string)     // ID string text to display in dialogue_boxes.nut on global func ::DialogueBoxes
fl_cps (float)  // Characters per second
opts (table)
    blip (string|null)      // Sound directory for sound per glyph, defaults to "verdessence/omori/sfx/omori_sys-text.wav" to which you don't have lol lmao
    blipEvery = 1 (int)     // Play on every nth glyph
    pitch = 100 (int)       // Ditto
    pitchJitter = 6 (int)   // Random pitch per blip
```

### Other
```
HideBox()       // Hides currently displayed dialogue
SkipTyping()    // Overrides Typewriter to instantly display rest of text
DlgReset()      // Kills antennas, MMCs, and clears overlays. Already done by OnGameEvent_round_end
```

## Initialization
### 1. Font
Generate your following font tilesheet for the shader and the vmt to read the glyphs and actually display it with [font_atlas_tool.py](font_atlas_tool.py).<br>
For reference, here's an example command for your terminal `cmd.exe`, `pwsh.exe` (you guys are liberals)
```bash
python font_atlas_tool.py ttf [.ttf file directory] -cell 32 --out ./atlas_out
```
By then, you'll be provided:
- two `font_atlas` PNGs, disregard `_contact` as it is a reference file.
- font_metrics.nut, this is the atlas cell and glyph pixel size for each character.
- font_metrics.json, reference file for `font_metrics.nut`, useless

In this case, the font_atlas file is saved as `materials/dev/font_atlas_16x16.vtf`.

### 2. Dialogue
Generate your text in a `dialogue.txt` file, this is where you will write your dialogue.
```
[id]
line1
line2
line3
```
Max 3 lines per box, ~40 charaters per line (256 glyph px), blank line between boxes.

Run
```bash
python bake_dialogue.py [metrics .nut path dir] [dialogue.txt path dir] [output] [font_atlas_clean.png path dir]
```
and move any generated files to whereever, I just keep them in scripts for now.<br>
By then, you'll be provided:
- dialogue_bank, The line bank containing all of the dialogue in the map, where each row is a line of rasterized layout, that is which glyph is specified at which column.
- dialogue_boxes.nut, box ID -> row in the dialogue_bank, row count, and per-glyph reveal breakpoints for the typewriter to go through.

### 3. In-game
Just run these commands as an example:
```
::DlgInit(Vector(480, 288, 48))
::TypeBox("id", 15)
```
append `script` (`script ::DlgInit...`) if you want to do this in console, though you have to run "script IncludeScript(\`dialogue_text.nut path dir, ignoring scripts/vscripts\`)" first.

## Prerequisite
Almost everything referenced in Initialization should be fulfilled, though here's some that weren't mentioned:
| Prerequisite | Description |
|---|---|
| `screenspace_font_line_ps2x.hlsl` OR `screenspace_font_line_ps20b.vcs` | The shader. Duh! |
| `screenspace_font_line.vmt` | The VMT.... Duh.... Put it in /materials/effects/shaders |
| `text_quad.mdl` | The antenna model for the MMC to manipulate, currently it's referenced in `verd/omori/`, so edit the .qc to your preferred directory |

## Reload rules
| Changed | Do |
|---|---|
| `.vmt` | `mat_reloadallmaterials` |
| `.vtf` | `mat_reloadalltextures` |
| `.nut` | re-`IncludeScript` |
| `.vcs` | restart the game |


## Limitations and Considerations
- Text is **global** to every player. You can show it to certain people, but you can't have per-player content, because the material vars are shared. If I would add per-player text display content, you would then be limited to have 12 characters max (4 constants reserved + 12 constants for glyphs).
- As stated earlier, Max 3 lines per box, ~40 charaters per line (256 glyph px), blank line between boxes.
- No kerning overlaps for people who want cursive fonts, this will make you lose your overhang.
- Tested only in 16:9, other resolutions unknown
- Tested majorly in DXVK `-vulkan` on windows at 1440p. I am a linux user, so I gotta make sure nothing happens in vulkan. Also, fuck directx

## Technical stuff
> [!WARNING]
> This section is written by Claude Fable 5.1, I do not know what the fuck is going on.

### General Function
Every screen pixel independently does: screen uv → glyph-pixel coordinates → which of the box's 3 rows it's in (`step()` count, no floor) → one read into the line bank at that row/column (gives atlas cell + x-within-glyph + mask) → one dependent read into the atlas → `coverage * mask * inBox * reveal` as alpha. There are no loops and nothing per-character in the shader; all the sequential stuff (layout, proportional advances, reveal breakpoints) is baked offline by `bake_dialogue.py`. The typewriter is one material var (`$c1_y`) moving through baked breakpoints; box selection is one var (`$c1_x`).
 
### Why the antenna prop exists
`material_modify_control` only works through the `MaterialModify` proxy, and the proxy is only run when an **entity** renders the material — it walks that entity's parented children for MMCs. Screen overlays are drawn with no entity (`OnBind` gets NULL and returns), so an overlay can *never* receive MMC data. But material vars live on the shared material, so a tiny always-rendered prop using the same material acts as the writer, and every player's overlay reads the result the same frame. Scale 0.01 + inflated bounds keeps it rendered and invisible.
 
### Why not constants
16 floats = 12 proportional glyphs per material per frame. The line bank moves the text into a texture (one read), leaving the constants for position/scale/box/reveal.
 
### Data textures on `-vulkan`
The bank is read with `$linearread_texture1 1` (otherwise DXVK sRGB-decodes it and every code is wrong) and is written 2×2 texel-doubled so point and bilinear sampling return identical bytes. Row selection uses `step()` counts instead of `floor(py/pitch)` because the floor landed on a rounding margin that DXVK resolves differently per compile. Full story in [postmortem document](font_postmortem.md).
