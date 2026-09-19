/* Chromatic Aberration - Screen
 *
 * Splits the red and blue channels apart, the way a cheap lens or a
 * composite cable does. A pinch of it sells "screen", a lot of it sells
 * "something is wrong with the machine".
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/ChromaticAberration.fxs by tools/build_shaders.py - edit the
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
    float  _Angle;
    bool   _Radial;
    float  _Falloff;
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


float2 fusionRotate(float2 p, float radiansAngle)
{
    float s, c;
    sincos(radiansAngle, s, c);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float2 texel = fusionTexel();
    float2 centred = (In.texCoord - 0.5) * 2.0;

    float2 direction = fusionRotate(float2(1.0, 0.0), radians(_Angle));
    direction.y = -direction.y;
    float2 radial = centred * pow(saturate(length(centred)), max(_Falloff, 0.0));
    float2 offset = (_Radial ? radial : direction) * _Strength * texel;

    float4 src = fusionTex(In, In.texCoord);
    float r = fusionTex(In, In.texCoord + offset).r;
    float b = fusionTex(In, In.texCoord - offset).b;

    return float4(r, src.g, b, src.a);
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
