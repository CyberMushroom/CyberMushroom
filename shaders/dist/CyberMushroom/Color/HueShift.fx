/* Hue Shift - Color
 *
 * Rotates the hue of every pixel, with saturation and value on the side.
 * One sprite sheet, a dozen palettes: recolour enemies, pickups and player
 * variants at runtime instead of drawing them twice.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/HueShift.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
sampler2D S2D_Image : register(s0);

struct PS_INPUT
{
    float4 Tint     : COLOR0;
    float2 texCoord : TEXCOORD0;
    float2 bgCoord  : TEXCOORD1;
};

/* --- parameters ---------------------------------------------------- */
/* Fusion fills these two in for you: one texel of the object's
   texture, in texture coordinates. */
float fPixelWidth;
float fPixelHeight;
float  _Hue;
float  _Saturation;
float  _Value;
float  _Amount;

/* --- texture access ------------------------------------------------ */
/* The object's own pixel, with Fusion's tint (semi-transparency and
   RGB coefficient) already applied. */
float4 fusionTex(in PS_INPUT In, float2 uv)
{
    return tex2D(S2D_Image, uv) * In.Tint;
}


float3 fusionRgb2Hsv(float3 c)
{
    float4 k = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, k.wz), float4(c.gb, k.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-6)),
                  d / (q.x + 1.0e-6),
                  q.x);
}

float3 fusionHsv2Rgb(float3 c)
{
    float3 p = abs(frac(c.xxx + float3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * lerp(float3(1.0, 1.0, 1.0), saturate(p - 1.0), c.y);
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);

    float3 hsv = fusionRgb2Hsv(src.rgb);
    hsv.x = frac(hsv.x + _Hue + 1.0);
    hsv.y = saturate(hsv.y * _Saturation);
    hsv.z = saturate(hsv.z * _Value);

    src.rgb = lerp(src.rgb, fusionHsv2Rgb(hsv), saturate(_Amount));
    return src;
}

/* --- entry point --------------------------------------------------- */
float4 ps_main(in PS_INPUT In) : COLOR0
{
    return fusion_main(In);
}

technique tech_main
{
    pass P0
    {
        VertexShader = NULL;
        PixelShader  = compile ps_2_0 ps_main();
    }
}
