/* Alpha Mask - Mask
 *
 * Cuts the object out using a second image you supply. Anything you can
 * draw, you can mask with: torn paper edges, a spotlight, a window in a
 * wall, a hand-drawn transition.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/AlphaMask.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

Texture2D<float4> _Mask : register(t1);
SamplerState _MaskSampler : register(s1);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    float  _OffsetX;
    float  _OffsetY;
    float  _ScaleX;
    float  _ScaleY;
    int    _Channel;
    float  _Contrast;
    bool   _Invert;
    bool   _Tile;
};

cbuffer PS_PIXELSIZE : register(b1)
{
    float fPixelWidth;
    float fPixelHeight;
};

struct PS_INPUT
{
    float4 Tint     : COLOR0;
    float2 texCoord : TEXCOORD0;
    float2 bgCoord  : TEXCOORD1;
    float4 Position : SV_POSITION;
};

/* Set by the two entry points below: the premultiplied-alpha build has
   to undo the multiply before any colour maths and redo it after. */
static bool FUSION_PREMULTIPLIED = false;

/* --- texture access ------------------------------------------------ */
/* The object's own pixel, with Fusion's tint (semi-transparency and
   RGB coefficient) already applied. */
float4 fusionTex(in PS_INPUT In, float2 uv)
{
    float4 c = S2D_Image.Sample(S2D_ImageSampler, uv) * In.Tint;
    if (FUSION_PREMULTIPLIED && c.a > 0.0)
    {
        c.rgb /= c.a;
    }
    return c;
}

/* The 'Mask Image' image parameter. */
float4 fusionImage_Mask(float2 uv)
{
    return _Mask.Sample(_MaskSampler, uv);
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

/* --- entry points -------------------------------------------------- */
float4 ps_main(in PS_INPUT In) : SV_TARGET
{
    FUSION_PREMULTIPLIED = false;
    return fusion_main(In);
}

float4 ps_main_pm(in PS_INPUT In) : SV_TARGET
{
    FUSION_PREMULTIPLIED = true;
    float4 result = fusion_main(In);
    result.rgb *= result.a;
    return result;
}
