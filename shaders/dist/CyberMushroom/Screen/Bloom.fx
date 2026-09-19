/* Bloom - Screen
 *
 * Bright pixels bleed light into their neighbours. One pass, two rings of
 * taps - not a film-grade bloom, but it costs one draw and it makes lamps,
 * coins and explosions feel hot.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Bloom.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
sampler2D S2D_Image : register(s0);

struct PS_INPUT
{
    float4 Tint     : COLOR0;
    float2 texCoord : TEXCOORD0;
    float2 bgCoord  : TEXCOORD1;
};

/* --- parameters ---------------------------------------------------- */
/* Fusion fills these two in for you: one texel of the object's
   texture, in texture coordinates. */
float fPixelWidth;
float fPixelHeight;
float4 _Color;
float  _Threshold;
float  _Intensity;
float  _Radius;
float  _Tint;

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
    return tex2D(S2D_Image, uv) * In.Tint;
}


/* Rec.601 luminance - the weighting that matches how the eye reads a sprite. */
float fusionLuma(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
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
    float4 src = fusionTex(In, In.texCoord);
    float2 texel = fusionTexel();

    float3 glow = float3(0.0, 0.0, 0.0);
    const int TAPS = 6;

    [unroll]
    for (int i = 0; i < TAPS; i++)
    {
        float angle = (6.2831853 / (float)TAPS) * (float)i;
        float2 dir;
        sincos(angle, dir.y, dir.x);

        /* Two rings: the inner one keeps the glow attached to the source,
           the outer one gives it reach. */
        float3 near = fusionTex(In, In.texCoord + dir * texel * _Radius * 0.5).rgb;
        float3 far = fusionTex(In, In.texCoord + fusionRotate(dir, 0.5236) * texel * _Radius).rgb;

        glow += max(near - _Threshold, float3(0.0, 0.0, 0.0));
        glow += max(far - _Threshold, float3(0.0, 0.0, 0.0)) * 0.6;
    }

    glow /= (float)TAPS * 1.6;
    glow = lerp(glow, _Color.rgb * fusionLuma(glow), saturate(_Tint));

    src.rgb = saturate(src.rgb + glow * _Intensity);
    return src;
}

/* --- entry point --------------------------------------------------- */
float4 ps_main(in PS_INPUT In) : COLOR0
{
    return fusion_main(In);
}

technique tech_main
{
    pass P0
    {
        VertexShader = NULL;
        PixelShader  = compile ps_3_0 ps_main();
    }
}
