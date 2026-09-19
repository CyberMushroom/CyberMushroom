/* Glitch - Screen
 *
 * Torn horizontal bands, an RGB split and dropped lines. The corruption
 * effect - good for damage, bad connections, and anything that should feel
 * like the game itself is breaking.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Glitch.fxs by tools/build_shaders.py - edit the
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
float  _Bands;
float  _Shift;
float  _Split;
float  _Drop;

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

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float2 texel = fusionTexel();
    float time = floor(_Time * 12.0);

    /* One random number per band per frame drives the whole thing, so a band
       either tears, drops or stays put - it never half-does both. */
    float band = floor(In.texCoord.y * max(_Bands, 1.0));
    float roll = fusionHash(float2(band, time));
    float active = step(1.0 - saturate(_Amount), roll);

    float direction = (fusionHash(float2(band, time + 7.0)) - 0.5) * 2.0;
    float2 uv = In.texCoord;
    uv.x += direction * _Shift * texel.x * active;

    float2 split = float2(_Split * texel.x * active * saturate(_Amount), 0.0);
    float4 src = fusionTex(In, uv);
    src.r = fusionTex(In, uv + split).r;
    src.b = fusionTex(In, uv - split).b;

    float dropped = step(1.0 - saturate(_Drop * _Amount), fusionHash(float2(band, time + 23.0)));
    src.rgb *= 1.0 - dropped;

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
