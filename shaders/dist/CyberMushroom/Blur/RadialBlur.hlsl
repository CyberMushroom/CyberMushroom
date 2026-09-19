/* Radial Blur - Blur
 *
 * Blurs outward from a point, or around it. Zoom for a dash or a hit, spin
 * for a dizzy spell or a spinning pickup.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/RadialBlur.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    float  _CenterX;
    float  _CenterY;
    float  _Zoom;
    float  _Spin;
    float  _Hole;
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
    float2 center = float2(_CenterX, _CenterY);

    float2 offset = In.texCoord - center;
    float radius = length(offset);
    float strength = saturate((radius - _Hole) / max(1.0 - _Hole, 1.0e-4));

    float4 sum = float4(0.0, 0.0, 0.0, 0.0);
    float weight = 0.0;

    const int TAPS = 12;

    [unroll]
    for (int i = 0; i < TAPS; i++)
    {
        float t = (float)i / (float)(TAPS - 1) - 0.5;

        float2 scaled = offset * (1.0 + t * _Zoom * strength);
        float2 spun = fusionRotate(scaled, t * _Spin * strength);

        float4 tap = fusionTex(In, saturate(center + spun));
        float w = 1.0 - abs(t);

        sum += float4(tap.rgb * tap.a, tap.a) * w;
        weight += w;
    }

    sum /= weight;
    float4 blurred = float4(sum.rgb / max(sum.a, 1.0e-5), sum.a);

    return lerp(src, blurred, saturate(_Amount));
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
