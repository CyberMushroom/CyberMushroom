/* Dissolve - Mask
 *
 * Eats the image away in random blocks, with a burning edge. Works as a
 * death effect on a sprite and as a scene transition on a layer, and
 * because the blocks are square it stays honest on a pixel grid.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Dissolve.fxs by tools/build_shaders.py - edit the
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
float4 _EdgeColor;
float  _Amount;
float  _Block;
float  _Edge;
float  _Seed;
bool   _Invert;

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
    float4 src = fusionTex(In, In.texCoord);

    float2 block = floor(In.texCoord / fusionTexel() / max(_Block, 1.0));
    float noise = fusionHash(block + _Seed);

    float amount = saturate(_Invert ? 1.0 - _Amount : _Amount);
    float edge = max(_Edge, 1.0e-4);

    /* Blocks vanish once the dissolve front passes their noise value; the
       band just ahead of the front is tinted on the way out. */
    float gone = step(noise, amount);
    float burning = saturate((amount + edge - noise) / edge) * (1.0 - gone);

    src.rgb = lerp(src.rgb, _EdgeColor.rgb, burning * step(0.001, _Edge));
    src.a *= 1.0 - gone;
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
