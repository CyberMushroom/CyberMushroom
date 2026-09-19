/* Heat Haze - Distort
 *
 * Soft rising noise that bends the image, the air over a fire or a desert
 * floor. Unlike Wave this has no repeating pattern, so it holds up over a
 * whole screen.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/HeatHaze.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    float  _Strength;
    float  _Scale;
    float  _Speed;
    float  _Time;
    float  _Rise;
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


/* Cheap deterministic hash - same input always gives the same value, so
   dissolves and noise do not crawl unless you actually move them. */
float fusionHash(float2 p)
{
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

/* Smoothed value noise in [0,1]. */
float fusionNoise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = fusionHash(i);
    float b = fusionHash(i + float2(1.0, 0.0));
    float c = fusionHash(i + float2(0.0, 1.0));
    float d = fusionHash(i + float2(1.0, 1.0));
    return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float2 texel = fusionTexel();
    float2 cell = In.texCoord / texel / max(_Scale, 1.0);
    float drift = _Time * _Speed;

    float nx = fusionNoise(cell + float2(0.0, -drift));
    float ny = fusionNoise(cell * 1.7 + float2(drift * 0.6, -drift * 1.3) + 19.0);

    float2 offset = (float2(nx, ny) - 0.5) * 2.0;
    offset.x *= 1.0 - saturate(_Rise);

    return fusionTex(In, saturate(In.texCoord + offset * _Strength * texel));
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
