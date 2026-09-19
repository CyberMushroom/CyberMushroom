/* Heat Haze - Distort
 *
 * Soft rising noise that bends the image, the air over a fire or a desert
 * floor. Unlike Wave this has no repeating pattern, so it holds up over a
 * whole screen.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/HeatHaze.fxs by tools/build_shaders.py - edit the
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
float  _Strength;
float  _Scale;
float  _Speed;
float  _Time;
float  _Rise;

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


/* Cheap deterministic hash - same input always gives the same value, so
   dissolves and noise do not crawl unless you actually move them. */
float fusionHash(float2 p)
{
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

/* Smoothed value noise in [0,1]. */
float fusionNoise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = fusionHash(i);
    float b = fusionHash(i + float2(1.0, 0.0));
    float c = fusionHash(i + float2(0.0, 1.0));
    float d = fusionHash(i + float2(1.0, 1.0));
    return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float2 texel = fusionTexel();
    float2 cell = In.texCoord / texel / max(_Scale, 1.0);
    float drift = _Time * _Speed;

    float nx = fusionNoise(cell + float2(0.0, -drift));
    float ny = fusionNoise(cell * 1.7 + float2(drift * 0.6, -drift * 1.3) + 19.0);

    float2 offset = (float2(nx, ny) - 0.5) * 2.0;
    offset.x *= 1.0 - saturate(_Rise);

    return fusionTex(In, saturate(In.texCoord + offset * _Strength * texel));
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
        PixelShader  = compile ps_2_0 ps_main();
    }
}
