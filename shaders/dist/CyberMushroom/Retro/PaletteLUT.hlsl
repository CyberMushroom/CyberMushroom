/* Palette Ramp - Retro
 *
 * Re-colours by brightness through a palette strip you supply as an image,
 * instead of the four hard-coded stops Gradient Map gives you. Draw a
 * 1-pixel-tall strip of your palette, drop it in, and the whole game wears
 * it.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/PaletteLUT.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

Texture2D<float4> _Ramp : register(t1);
SamplerState _RampSampler : register(s1);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    float  _Columns;
    float  _Rows;
    float  _Row;
    float  _Offset;
    float  _Contrast;
    float  _Amount;
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

/* The 'Palette Ramp' image parameter. */
float4 fusionImage_Ramp(float2 uv)
{
    return _Ramp.Sample(_RampSampler, uv);
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
