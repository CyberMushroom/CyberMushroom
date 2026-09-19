/* Posterize - Color
 *
 * Snaps every channel to a fixed number of steps. Four levels is roughly
 * what an 8-bit console gave you; two is a woodcut. Pair it with Dither if
 * the banding gets ugly.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Posterize.fxs by tools/build_shaders.py - edit the
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
float  _Levels;
float  _Amount;
bool   _Luma;

/* --- texture access ------------------------------------------------ */
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

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);
    float steps = max(2.0, floor(_Levels)) - 1.0;

    float3 banded = floor(saturate(src.rgb) * steps + 0.5) / steps;

    float luma = fusionLuma(src.rgb);
    float stepped = floor(saturate(luma) * steps + 0.5) / steps;
    float3 lumaBanded = src.rgb * (stepped / max(luma, 1.0e-4));

    src.rgb = lerp(src.rgb, saturate(_Luma ? lumaBanded : banded), saturate(_Amount));
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
