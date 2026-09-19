/* Drop Shadow - Outline
 *
 * Casts an offset shadow of the sprite behind itself, in one draw and one
 * object. Lifts HUD cards and text off the background - the same trick the
 * score panel in this repo uses, but free.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/DropShadow.fxs by tools/build_shaders.py - edit the
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
    float  _OffsetX;
    float  _OffsetY;
    float  _Opacity;
    float  _Soften;
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


/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float2 texel = fusionTexel();
    float4 src = fusionTex(In, In.texCoord);

    float2 shadowUV = In.texCoord - float2(_OffsetX, _OffsetY) * texel;
    float shadow = fusionTex(In, shadowUV).a;

    if (_Soften > 0.0)
    {
        float2 spread = texel * _Soften;
        shadow += fusionTex(In, shadowUV + float2(spread.x, 0.0)).a;
        shadow += fusionTex(In, shadowUV - float2(spread.x, 0.0)).a;
        shadow += fusionTex(In, shadowUV + float2(0.0, spread.y)).a;
        shadow += fusionTex(In, shadowUV - float2(0.0, spread.y)).a;
        shadow /= 5.0;
    }

    shadow *= saturate(_Opacity);

    /* Composite the sprite over its own shadow. */
    float alpha = src.a + shadow * (1.0 - src.a);
    float3 rgb = (src.rgb * src.a + _Color.rgb * shadow * (1.0 - src.a)) / max(alpha, 1.0e-5);

    return float4(rgb, alpha);
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
