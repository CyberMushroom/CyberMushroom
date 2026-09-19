/* Iris Wipe - Mask
 *
 * The shape closing in around the hero at the end of a level. Circle,
 * diamond or square, centred anywhere, opening or closing.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/IrisWipe.fxs by tools/build_shaders.py - edit the
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
    float  _Radius;
    float  _Softness;
    int    _Shape;
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

    float dist = length(centred);
    if (_Shape == 1) dist = abs(centred.x) + abs(centred.y);
    if (_Shape == 2) dist = max(abs(centred.x), abs(centred.y));

    float soft = max(_Softness, 1.0e-4);
    float outside = smoothstep(_Radius - soft, _Radius + soft, dist);

    src.a *= _Invert ? (1.0 - outside) : outside;
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
