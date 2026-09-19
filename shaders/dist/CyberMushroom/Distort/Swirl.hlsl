/* Swirl - Distort
 *
 * Twists the image around a point, hardest in the middle and fading to
 * nothing at the edge of its radius. Portals, whirlpools, drains, and a
 * very good "sucked into the pipe" transition.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Swirl.fxs by tools/build_shaders.py - edit the
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
    float  _Angle;
    float  _Radius;
    bool   _Clip;
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
    float aspect = fPixelHeight / max(fPixelWidth, 1.0e-6);
    float2 center = float2(_CenterX, _CenterY);

    float2 centred = In.texCoord - center;
    centred.x *= aspect;

    /* Squared falloff, so the middle spins hard and the rim stays still
       instead of shearing against the untwisted pixels around it. */
    float fade = saturate(1.0 - length(centred) / max(_Radius, 0.01));
    centred = fusionRotate(centred, radians(_Angle) * fade * fade);

    centred.x /= aspect;
    float2 uv = center + centred;

    float4 src = fusionTex(In, saturate(uv));
    if (_Clip)
    {
        float2 inside = step(float2(0.0, 0.0), uv) * step(uv, float2(1.0, 1.0));
        src *= inside.x * inside.y;
    }
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
