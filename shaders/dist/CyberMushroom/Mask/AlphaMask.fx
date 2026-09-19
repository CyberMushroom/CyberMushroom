/* Alpha Mask - Mask
 *
 * Cuts the object out using a second image you supply. Anything you can
 * draw, you can mask with: torn paper edges, a spotlight, a window in a
 * wall, a hand-drawn transition.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/AlphaMask.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
sampler2D S2D_Image : register(s0);
sampler2D _Mask : register(s1) = sampler_state
{
    MinFilter = Linear;
    MagFilter = Linear;
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
float  _OffsetX;
float  _OffsetY;
float  _ScaleX;
float  _ScaleY;
int    _Channel;
float  _Contrast;
bool   _Invert;
bool   _Tile;

/* --- texture access ------------------------------------------------ */
/* The object's own pixel, with Fusion's tint (semi-transparency and
   RGB coefficient) already applied. */
float4 fusionTex(in PS_INPUT In, float2 uv)
{
    return tex2D(S2D_Image, uv) * In.Tint;
}

/* The 'Mask Image' image parameter. */
float4 fusionImage_Mask(float2 uv)
{
    return tex2D(_Mask, uv);
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

    float2 uv = In.texCoord * float2(max(_ScaleX, 0.01), max(_ScaleY, 0.01)) + float2(_OffsetX, _OffsetY);
    uv = _Tile ? frac(uv + 1000.0) : saturate(uv);

    float4 mask = fusionImage_Mask(uv);

    float value = mask.a;
    if (_Channel == 1) value = fusionLuma(mask.rgb);
    if (_Channel == 2) value = mask.r;
    if (_Channel == 3) value = mask.g;
    if (_Channel == 4) value = mask.b;

    value = saturate((value - 0.5) * max(_Contrast, 0.0) + 0.5);
    src.a *= _Invert ? (1.0 - value) : value;
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
