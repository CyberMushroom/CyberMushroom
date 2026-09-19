/* Bloom - Screen
 *
 * Bright pixels bleed light into their neighbours. One pass, two rings of
 * taps - not a film-grade bloom, but it costs one draw and it makes lamps,
 * coins and explosions feel hot.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Bloom.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    float4 _Color;
    float  _Threshold;
    float  _Intensity;
    float  _Radius;
    float  _Tint;
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

float2 fusionRotate(float2 p, float radiansAngle)
{
    float s, c;
    sincos(radiansAngle, s, c);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);
    float2 texel = fusionTexel();

    float3 glow = float3(0.0, 0.0, 0.0);
    const int TAPS = 6;

    [unroll]
    for (int i = 0; i < TAPS; i++)
    {
        float angle = (6.2831853 / (float)TAPS) * (float)i;
        float2 dir;
        sincos(angle, dir.y, dir.x);

        /* Two rings: the inner one keeps the glow attached to the source,
           the outer one gives it reach. */
        float3 near = fusionTex(In, In.texCoord + dir * texel * _Radius * 0.5).rgb;
        float3 far = fusionTex(In, In.texCoord + fusionRotate(dir, 0.5236) * texel * _Radius).rgb;

        glow += max(near - _Threshold, float3(0.0, 0.0, 0.0));
        glow += max(far - _Threshold, float3(0.0, 0.0, 0.0)) * 0.6;
    }

    glow /= (float)TAPS * 1.6;
    glow = lerp(glow, _Color.rgb * fusionLuma(glow), saturate(_Tint));

    src.rgb = saturate(src.rgb + glow * _Intensity);
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
