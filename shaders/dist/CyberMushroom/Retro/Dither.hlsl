/* Dither - Retro
 *
 * Ordered (Bayer) dithering with an adjustable number of levels. Where
 * Posterize bands, this one trades banding for a woven pattern, the way an
 * artist fakes a gradient with two colours.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Dither.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    float  _Levels;
    float  _Amount;
    float  _Scale;
    bool   _Coarse;
    bool   _Luma;
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
/* One texel of the object's texture, as a texture-coordinate step. */
float2 fusionTexel()
{
    return max(float2(fPixelWidth, fPixelHeight), 1.0e-6);
}

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


/* Rec.601 luminance - the weighting that matches how the eye reads a sprite. */
float fusionLuma(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

/* 4x4 ordered dither threshold in [0,1), indexed by screen-space pixel. */
float fusionBayer4(float2 pixel)
{
    float2 p = floor(fmod(abs(pixel), 4.0));
    float4 row0 = float4( 0.0,  8.0,  2.0, 10.0);
    float4 row1 = float4(12.0,  4.0, 14.0,  6.0);
    float4 row2 = float4( 3.0, 11.0,  1.0,  9.0);
    float4 row3 = float4(15.0,  7.0, 13.0,  5.0);
    float4 row = row0;
    row = (p.y > 0.5) ? row1 : row;
    row = (p.y > 1.5) ? row2 : row;
    row = (p.y > 2.5) ? row3 : row;
    float v = row.x;
    v = (p.x > 0.5) ? row.y : v;
    v = (p.x > 1.5) ? row.z : v;
    v = (p.x > 2.5) ? row.w : v;
    return v / 16.0;
}

/* 2x2 ordered dither threshold in [0,1). */
float fusionBayer2(float2 pixel)
{
    float2 p = floor(fmod(abs(pixel), 2.0));
    float v = (p.y > 0.5) ? ((p.x > 0.5) ? 1.0 : 3.0)
                          : ((p.x > 0.5) ? 2.0 : 0.0);
    return v / 4.0;
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);

    float steps = max(2.0, floor(_Levels)) - 1.0;
    float2 pixel = In.texCoord / fusionTexel() / max(_Scale, 1.0);
    float threshold = (_Coarse ? fusionBayer2(pixel) : fusionBayer4(pixel)) - 0.5;
    float offset = threshold * _Amount / steps;

    float3 perChannel = floor(saturate(src.rgb + offset) * steps + 0.5) / steps;

    float luma = fusionLuma(src.rgb);
    float stepped = floor(saturate(luma + offset) * steps + 0.5) / steps;
    float3 lumaOnly = src.rgb * (stepped / max(luma, 1.0e-4));

    src.rgb = saturate(_Luma ? lumaOnly : perChannel);
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
