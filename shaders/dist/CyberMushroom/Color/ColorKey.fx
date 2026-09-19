/* Colour Key - Color
 *
 * Makes one colour transparent. For sprite sheets exported without alpha,
 * for punching a window out of a backdrop, and for cutting a hole in
 * anything at runtime.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/ColorKey.fxs by tools/build_shaders.py - edit the
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
float4 _Key;
float  _Tolerance;
float  _Softness;
float  _Despill;

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

    float dist = distance(src.rgb, _Key.rgb);
    float keyed = 1.0 - smoothstep(_Tolerance, _Tolerance + max(_Softness, 1.0e-4), dist);

    /* Push the surviving pixels away from the key colour, toward their own
       brightness, so no fringe of it is left behind. */
    float grey = fusionLuma(src.rgb);
    float3 clean = lerp(src.rgb, float3(grey, grey, grey), saturate(_Despill) * keyed);

    src.rgb = clean;
    src.a *= 1.0 - keyed;
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
