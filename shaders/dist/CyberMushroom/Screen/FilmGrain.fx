/* Film Grain - Screen
 *
 * Per-pixel noise over the picture. Breaks up flat areas, hides banding
 * left by a small palette, and gives a still screen something to do.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/FilmGrain.fxs by tools/build_shaders.py - edit the
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
float  _Amount;
float  _Time;
float  _Scale;
bool   _Shadows;
bool   _Colour;

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

/* Cheap deterministic hash - same input always gives the same value, so
   dissolves and noise do not crawl unless you actually move them. */
float fusionHash(float2 p)
{
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);

    float2 pixel = floor(In.texCoord / fusionTexel() / max(_Scale, 1.0));
    float2 seed = pixel + frac(_Time) * 137.0;

    float mono = fusionHash(seed);
    float3 noise = float3(mono, mono, mono);
    if (_Colour)
    {
        noise = float3(fusionHash(seed),
                       fusionHash(seed + 17.13),
                       fusionHash(seed + 41.71));
    }
    noise -= 0.5;

    float weight = _Shadows ? (1.0 - fusionLuma(src.rgb)) : 1.0;
    src.rgb = saturate(src.rgb + noise * _Amount * weight);
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
        PixelShader  = compile ps_2_0 ps_main();
    }
}
