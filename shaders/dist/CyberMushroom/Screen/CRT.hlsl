/* CRT - Screen
 *
 * A whole tube in one pass: barrel curvature, scanlines, a shadow mask and
 * a vignette, with the area outside the glass blacked out. Everything can
 * be dialled to zero, so you can keep just the parts you want.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/CRT.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    float4 _Bezel;
    float  _Curve;
    float  _Scanlines;
    float  _Period;
    float  _Mask;
    float  _Vignette;
    float  _Brightness;
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
    /* Bow the sampling grid outward from the centre of the screen. */
    float2 centred = In.texCoord - 0.5;
    float2 uv = In.texCoord + centred * dot(centred, centred) * _Curve;

    float2 outside = step(uv, float2(0.0, 0.0)) + step(float2(1.0, 1.0), uv);
    float offGlass = saturate(outside.x + outside.y);

    float4 src = fusionTex(In, saturate(uv));

    float2 pixel = uv / fusionTexel();

    float phase = frac(pixel.y / max(_Period, 1.0));
    float scan = abs(phase - 0.5) * 2.0;
    src.rgb *= 1.0 - (1.0 - scan) * saturate(_Scanlines);

    /* Three-phase stripe mask: each screen column leans toward one primary. */
    float stripe = frac(pixel.x / 3.0);
    float3 mask = float3(step(stripe, 0.334),
                         step(0.334, stripe) * step(stripe, 0.667),
                         step(0.667, stripe));
    src.rgb *= lerp(float3(1.0, 1.0, 1.0), 0.4 + mask * 1.2, saturate(_Mask));

    float2 vig = centred * 2.0;
    src.rgb *= 1.0 - saturate(dot(vig, vig) * 0.5) * saturate(_Vignette);

    src.rgb = saturate(src.rgb * _Brightness);
    src.rgb = lerp(src.rgb, _Bezel.rgb, offGlass);
    src.a = lerp(src.a, 1.0, offGlass);
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
