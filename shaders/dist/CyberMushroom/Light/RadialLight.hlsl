/* Radial Light - Light
 *
 * Turns a plain rectangle into a light: a soft radial pool of colour, or -
 * with Invert on - a sheet of darkness with a hole cut in it. Two objects
 * and this shader give you a whole lighting system without an extension.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/RadialLight.fxs by tools/build_shaders.py - edit the
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
    float  _CenterX;
    float  _CenterY;
    float  _Radius;
    float  _Falloff;
    float  _Intensity;
    float  _Steps;
    bool   _Invert;
    bool   _Square;
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


/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);

    float aspect = fPixelHeight / max(fPixelWidth, 1.0e-6);
    float2 centred = (In.texCoord - float2(_CenterX, _CenterY)) * 2.0;
    centred.x *= _Square ? 1.0 : aspect;

    float light = saturate(1.0 - length(centred) / max(_Radius, 1.0e-4));
    light = pow(light, _Falloff);

    if (_Steps >= 1.0)
    {
        float bands = floor(_Steps);
        light = floor(light * bands + 0.5) / bands;
    }

    light = saturate(light * _Intensity);

    src.rgb = _Color.rgb;
    src.a *= _Invert ? (1.0 - light) : light;
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
