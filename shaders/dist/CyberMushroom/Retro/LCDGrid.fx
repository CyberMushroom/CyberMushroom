/* LCD Grid - Retro
 *
 * The handheld screen itself: a dot-matrix grid with a gap between cells
 * and a tinted backlight. Sits on top of a finished frame and makes it
 * look like it is being read off a panel rather than drawn on one.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/LCDGrid.fxs by tools/build_shaders.py - edit the
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
float4 _Backlight;
float  _Cell;
float  _Gap;
float  _Darkness;
float  _Tint;

/* --- texture access ------------------------------------------------ */
/* One texel of the object's texture, as a texture-coordinate step. */
float2 fusionTexel()
{
    return max(float2(fPixelWidth, fPixelHeight), 1.0e-6);
}

/* The object's own pixel, with Fusion's tint (semi-transparency and
   RGB coefficient) already applied. */
float4 fusionTex(in PS_INPUT In, float2 uv)
{
    return tex2D(S2D_Image, uv) * In.Tint;
}


/* Rec.601 luminance - the weighting that matches how the eye reads a sprite. */
float fusionLuma(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);

    float2 pixel = In.texCoord / fusionTexel();
    float2 cell = abs(frac(pixel / max(_Cell, 1.0)) - 0.5) * 2.0;
    float grid = max(cell.x, cell.y);
    float gap = smoothstep(1.0 - saturate(_Gap), 1.0, grid);

    src.rgb *= 1.0 - gap * saturate(_Darkness);
    src.rgb = lerp(src.rgb, saturate(_Backlight.rgb * fusionLuma(src.rgb) * 2.0), saturate(_Tint));
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
