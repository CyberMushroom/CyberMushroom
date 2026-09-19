/* UV Transform - Distort
 *
 * Scrolls, scales and rotates the image inside the object without moving
 * the object. This is how you get endless parallax skies, conveyor belts,
 * flowing lava and spinning gears out of one static Active object.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/UVTransform.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    float  _ScrollX;
    float  _ScrollY;
    float  _ScaleX;
    float  _ScaleY;
    float  _Angle;
    float  _PivotX;
    float  _PivotY;
    int    _Wrap;
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
    float2 pivot = float2(_PivotX, _PivotY);

    float2 uv = In.texCoord - pivot;
    uv = fusionRotate(uv, radians(_Angle));
    uv *= float2(max(_ScaleX, 0.01), max(_ScaleY, 0.01));
    uv += pivot + float2(_ScrollX, _ScrollY);

    float2 inside = step(float2(0.0, 0.0), uv) * step(uv, float2(1.0, 1.0));
    float2 sampleUV = (_Wrap == 0) ? frac(uv + 1000.0) : saturate(uv);

    float4 src = fusionTex(In, sampleUV);
    if (_Wrap == 2)
    {
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
