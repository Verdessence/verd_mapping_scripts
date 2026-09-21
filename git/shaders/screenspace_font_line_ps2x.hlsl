//============================================================================
// screenspace_font_line_ps2x.hlsl -- v2: line-bank dialogue renderer.
//
// v1 packed glyphs into constants (12-glyph ceiling). v2 moves the text
// into a baked 512x512 "line bank" texture: each row is one dialogue
// line's rasterized layout (per-column: cell code, x-within-cell, mask),
// prefix sums baked offline by bake_dialogue.py. The shader is now just:
// which column am I -> one read into the bank -> one dependent read into
// the atlas. Arbitrary line length, ~2 tex + ~40 ALU, and the ENTIRE
// game's dialogue ships in one texture. Box selection and the typewriter
// are single material vars driven through the existing antenna/MMC bank.
//
// Samplers: s0 = glyph atlas ($basetexture), s1 = line bank ($texture1).
// Bank texels: R = atlas cell code, G = localU*255, B = 255 where glyph.
//============================================================================

sampler g_FontAtlas : register( s0 );
sampler g_LineBank  : register( s1 );

const float4 g_c0 : register( c0 );   // x aspect, y originX, z originY, w scale
const float4 g_c1 : register( c1 );   // x baseRow, y reveal (global glyph-px cols),
                                      // z numRows (1-3), w (unused)
const float4 g_c2 : register( c2 );   // x rowPitch (glyph px), yzw spare

struct PS_INPUT { float2 uv : TEXCOORD0; };

static const float CANVAS = 1024.0;
static const float LINE_W = 256.0;    // logical cols per line (bank is 2x2
                                      // texel-doubled 512x512: sampling at
                                      // (k+0.5)/256 hits a 4-identical-texel
                                      // corner -> bilinear-proof)
static const float CELL   = 16.0;

float4 main( PS_INPUT i ) : COLOR
{
    float2 p;
    p.x = i.uv.x * CANVAS * g_c0.x;            // aspect-corrected canvas
    p.y = i.uv.y * CANVAS;

    float px = ( p.x - g_c0.y ) / g_c0.w;      // glyph px within a line
    float py = ( p.y - g_c0.z ) / g_c0.w;

    // ROW SELECTION -- no floor, no frac, no divide. With <=3 rows the
    // row index is just "how many row boundaries lie above this pixel":
    // two step() comparisons summed give an exact 0/1/2. The only points
    // where rounding could matter are py == pitch and py == 2*pitch,
    // which sit in the inter-row gaps where nothing is drawn anyway.
    // (The comb proved to be a compile-dependent floor-margin artifact on
    // the Vulkan path; this formulation has no margin to land on.)
    float pitch = g_c2.x;                      // rowPitch, glyph px
    float row = step( pitch, py ) + step( pitch * 2.0, py );
    float ly  = py - row * pitch;              // y within the line

    float inBox = step( 0.0, px ) * step( px, LINE_W - 1.0 )
                * step( 0.0, row ) * step( row, g_c1.z - 0.5 )
                * step( 0.0, ly )  * step( ly, CELL );

    // sample the bank at this column's texel center
    float colIdx = px - frac( px );
    // (k+0.5)/256 on the doubled 512 texture = the shared corner of a
    // 2x2 block of identical texels: point and linear sampling agree
    // byte-for-byte here, whatever the driver decides to do.
    float2 bankUV = float2( ( colIdx + 0.5 ) / LINE_W,
                            ( g_c1.x + row + 0.5 ) / LINE_W );
    float3 t = tex2D( g_LineBank, bankUV ).rgb;

    float code   = t.r * 255.0;
    code = code + 0.5; code = code - frac( code );   // round to exact cell
    float mask   = step( 0.5, t.b );                 // glyph occupies column

    // BANK FORMAT v2: t.g = glyph-px index * 16/255. Decode the index
    // exactly, then add this pixel's sub-glyph-px fraction for full
    // atlas horizontal resolution.
    float localIdx = t.g * ( 255.0 / 16.0 );
    localIdx = localIdx + 0.5; localIdx = localIdx - frac( localIdx );
    float lx = localIdx + frac( px );                // glyph px, continuous

    // typewriter: global column = row*512 + px, revealed if < g_c1.y
    float revealMask = step( row * LINE_W + px, g_c1.y );

    // atlas cell -> dependent read. Cells are 32 atlas texels square
    // (2 texels per glyph px). SNAP both axes to texel centers so no
    // sample ever rides a texel boundary -- point-sample rounding is
    // renderer-dependent (D3D9 vs DXVK) and boundary samples flicker.
    float ut = lx * 2.0; ut = ut - frac( ut );       // texel col 0..31
    float vt = ly * 2.0; vt = vt - frac( vt );
    vt = min( vt, 31.0 );                            // no next-cell bleed
    float ccol = frac( code / CELL ) * CELL;
    float crow = ( code - ccol ) / CELL;
    float2 cellUV = ( float2( ccol, crow )
                    + ( float2( ut, vt ) + 0.5 ) / 32.0 ) / CELL;
    float coverage = tex2D( g_FontAtlas, cellUV ).a;

    float a = coverage * mask * inBox * revealMask;
    return float4( 1.0, 1.0, 1.0, a );
}
