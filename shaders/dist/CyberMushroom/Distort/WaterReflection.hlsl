/* Water Reflection - Distort
 *
 * Flips the image, ripples it and fades it out with depth. Put a copy of
 * your scenery below the waterline, apply this, and it reflects.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/WaterReflection.fxs by tools/build_shaders.py - edit the
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
    float  _Amplitude;
    float  _Frequency;
    float  _Speed;
    float  _Time;
    float  _Tint;
    float  _Fade;
    bool   _Flip;
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
    float2 uv = In.texCoord;

    /* depth is 0 at the waterline and 1 at the far edge of the reflection. */
    float depth = _Flip ? uv.y : 1.0 - uv.y;
    if (_Flip)
    {
        uv.y = 1.0 - uv.y;
    }

    float phase = uv.y * _Frequency * 6.2831853 + _Time * _Speed;
    uv.x += sin(phase) * _Amplitude * texel.x * (0.3 + depth);

    float4 src = fusionTex(In, saturate(uv));
    src.rgb = lerp(src.rgb, _Color.rgb, saturate(_Tint));
    src.a *= 1.0 - saturate(_Fade) * depth;
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
