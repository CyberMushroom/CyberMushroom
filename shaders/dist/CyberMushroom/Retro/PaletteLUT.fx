/* Palette Ramp - Retro
 *
 * Re-colours by brightness through a palette strip you supply as an image,
 * instead of the four hard-coded stops Gradient Map gives you. Draw a
 * 1-pixel-tall strip of your palette, drop it in, and the whole game wears
 * it.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/PaletteLUT.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
sampler2D S2D_Image : register(s0);
sampler2D _Ramp : register(s1) = sampler_state
{
    MinFilter = Point;
    MagFilter = Point;
    AddressU = Clamp;
    AddressV = Clamp;
};

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
float  _Columns;
float  _Rows;
float  _Row;
float  _Offset;
float  _Contrast;
float  _Amount;

/* --- texture access ------------------------------------------------ */
/* The object's own pixel, with Fusion's tint (semi-transparency and
   RGB coefficient) already applied. */
float4 fusionTex(in PS_INPUT In, float2 uv)
{
    return tex2D(S2D_Image, uv) * In.Tint;
}

/* The 'Palette Ramp' image parameter. */
float4 fusionImage_Ramp(float2 uv)
{
    return tex2D(_Ramp, uv);
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

    float luma = fusionLuma(src.rgb);
    luma = saturate((luma - 0.5) * _Contrast + 0.5 + _Offset);

    /* Land on the middle of a palette cell, not on the seam between two. */
    float columns = max(_Columns, 2.0);
    float rows = max(_Rows, 1.0);
    float u = (floor(luma * (columns - 1.0) + 0.5) + 0.5) / columns;
    float v = (floor(clamp(_Row, 0.0, rows - 1.0)) + 0.5) / rows;

    float3 mapped = fusionImage_Ramp(float2(u, v)).rgb;
    src.rgb = lerp(src.rgb, mapped, saturate(_Amount));
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
