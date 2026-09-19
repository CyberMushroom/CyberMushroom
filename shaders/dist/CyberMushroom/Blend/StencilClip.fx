/* Stencil Clip - Blend
 *
 * Shows the object only where the background behind it is a particular
 * colour. Paint a mask colour into your level art and sprites will only
 * draw inside it - water that only fills the pool, light that only lands
 * on the floor, a reflection that stops at the edge of the puddle.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/StencilClip.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
sampler2D S2D_Image : register(s0);
sampler2D S2D_Background : register(s1);

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
bool   _Invert;

/* --- texture access ------------------------------------------------ */
/* The object's own pixel, with Fusion's tint (semi-transparency and
   RGB coefficient) already applied. */
float4 fusionTex(in PS_INPUT In, float2 uv)
{
    return tex2D(S2D_Image, uv) * In.Tint;
}

/* Whatever Fusion has already drawn behind the object. Sample it with
   In.bgCoord, not In.texCoord - they are different mappings. */
float4 fusionBg(float2 uv)
{
    return tex2D(S2D_Background, uv);
}


/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);
    float4 bg = fusionBg(In.bgCoord);

    float dist = distance(bg.rgb, _Key.rgb);
    float inside = 1.0 - smoothstep(_Tolerance, _Tolerance + max(_Softness, 1.0e-4), dist);

    src.a *= _Invert ? (1.0 - inside) : inside;
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
