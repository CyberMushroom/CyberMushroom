/* Motion Blur - Blur
 *
 * Smears the image along a line. Point it the way the object is travelling
 * and a fast sprite reads as fast instead of teleporting between frames.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/MotionBlur.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
sampler2D S2D_Image : register(s0) = sampler_state
{
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

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
float  _Distance;
float  _Angle;
bool   _Trail;
float  _Amount;

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

    float2 dir = fusionRotate(float2(1.0, 0.0), radians(_Angle));
    dir.y = -dir.y;

    float4 sum = float4(0.0, 0.0, 0.0, 0.0);
    float weight = 0.0;

    const int TAPS = 12;

    [unroll]
    for (int i = 0; i < TAPS; i++)
    {
        float t = (float)i / (float)(TAPS - 1);
        float offset = _Trail ? -t : (t - 0.5) * 2.0;

        float4 tap = fusionTex(In, In.texCoord + dir * offset * _Distance * texel);
        /* Taps nearest the object count most, so the head of the streak stays
           solid and the tail fades. */
        float w = _Trail ? (1.0 - t * 0.85) : 1.0;

        sum += float4(tap.rgb * tap.a, tap.a) * w;
        weight += w;
    }

    sum /= weight;
    float4 blurred = float4(sum.rgb / max(sum.a, 1.0e-5), sum.a);

    return lerp(src, blurred, saturate(_Amount));
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
