/* Refract - Blend
 *
 * Bends the background as it passes through the object, using the object's
 * own shading as the lens. Draw a bubble, a bottle, a heat pocket or a
 * pane of glass, apply this, and the world behind it warps.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Refract.fxs by tools/build_shaders.py - edit the
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
    float4 _Tint;
    float  _Strength;
    float  _Zoom;
    float  _TintAmount;
    float  _Keep;
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

/* Whatever Fusion has already drawn behind the object. Sample it with
   In.bgCoord, not In.texCoord - they are different mappings. */
float4 fusionBg(float2 uv)
{
    return S2D_Background.Sample(S2D_BackgroundSampler, uv);
}


/* Rec.601 luminance - the weighting that matches how the eye reads a sprite. */
float fusionLuma(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float2 texel = fusionTexel();
    float4 src = fusionTex(In, In.texCoord);

    /* The slope of the sprite's brightness stands in for a surface normal:
       flat areas pass light straight through, slopes bend it. */
    float left = fusionLuma(fusionTex(In, In.texCoord - float2(texel.x, 0.0)).rgb);
    float right = fusionLuma(fusionTex(In, In.texCoord + float2(texel.x, 0.0)).rgb);
    float up = fusionLuma(fusionTex(In, In.texCoord - float2(0.0, texel.y)).rgb);
    float down = fusionLuma(fusionTex(In, In.texCoord + float2(0.0, texel.y)).rgb);

    float2 slope = float2(right - left, down - up);
    float2 uv = In.bgCoord + slope * _Strength * texel;
    uv = (uv - 0.5) / max(1.0 + _Zoom, 0.01) + 0.5;

    float4 bg = fusionBg(saturate(uv));
    bg.rgb = lerp(bg.rgb, _Tint.rgb * fusionLuma(bg.rgb) * 2.0, saturate(_TintAmount));

    float3 rgb = lerp(saturate(bg.rgb), src.rgb, saturate(_Keep));
    return float4(rgb, src.a);
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
