/* Blend Modes - Blend
 *
 * Thirteen Photoshop blend modes against whatever Fusion has already drawn
 * behind the object. Fusion's built-in ink effects stop at Add and
 * Subtract - this is the rest of them.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/BlendModes.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

Texture2D<float4> S2D_Background : register(t1);
SamplerState S2D_BackgroundSampler : register(s1);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    int    _Mode;
    float  _Opacity;
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

/* Whatever Fusion has already drawn behind the object. Sample it with
   In.bgCoord, not In.texCoord - they are different mappings. */
float4 fusionBg(float2 uv)
{
    return S2D_Background.Sample(S2D_BackgroundSampler, uv);
}


/* Photoshop-style blend of a base colour with a blend colour.
   0 normal      1 add        2 multiply   3 screen     4 overlay
   5 soft light  6 hard light 7 difference 8 lighten    9 darken
   10 colour dodge           11 colour burn            12 exclusion */
float3 fusionBlend(float3 b, float3 s, int mode)
{
    float3 r = s;
    if (mode == 1)  r = b + s;
    if (mode == 2)  r = b * s;
    if (mode == 3)  r = 1.0 - (1.0 - b) * (1.0 - s);
    if (mode == 4)  r = lerp(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(0.5, b));
    if (mode == 5)  r = lerp(2.0 * b * s + b * b * (1.0 - 2.0 * s),
                             sqrt(max(b, 0.0)) * (2.0 * s - 1.0) + 2.0 * b * (1.0 - s),
                             step(0.5, s));
    if (mode == 6)  r = lerp(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(0.5, s));
    if (mode == 7)  r = abs(b - s);
    if (mode == 8)  r = max(b, s);
    if (mode == 9)  r = min(b, s);
    if (mode == 10) r = b / max(1.0 - s, 1.0e-4);
    if (mode == 11) r = 1.0 - (1.0 - b) / max(s, 1.0e-4);
    if (mode == 12) r = b + s - 2.0 * b * s;
    return saturate(r);
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);
    float4 bg = fusionBg(In.bgCoord);

    float3 blended = fusionBlend(bg.rgb, src.rgb, _Mode);

    /* Hand back the finished blend with the sprite's own alpha, so Fusion's
       normal alpha blending lands it on the background unchanged. */
    return float4(blended, src.a * saturate(_Opacity));
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
