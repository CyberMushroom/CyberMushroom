/* Vignette - Screen
 *
 * Darkens the edges so the eye goes to the middle. Subtle at 0.3, a torch-
 * lit cave at 0.9.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Vignette.fxs by tools/build_shaders.py - edit the
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
float  _Radius;
float  _Softness;
float  _Amount;
float  _Roundness;

/* --- texture access ------------------------------------------------ */
/* The object's own pixel, with Fusion's tint (semi-transparency and
   RGB coefficient) already applied. */
float4 fusionTex(in PS_INPUT In, float2 uv)
{
    return tex2D(S2D_Image, uv) * In.Tint;
}


/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);

    float2 centred = (In.texCoord - 0.5) * 2.0;
    /* fPixelWidth/fPixelHeight give the texture's shape, which is what lets
       the vignette follow a wide frame instead of always being a circle. */
    float aspect = fPixelHeight / max(fPixelWidth, 1.0e-6);
    centred.x *= lerp(1.0, aspect, saturate(_Roundness));

    float dist = length(centred);
    float shade = smoothstep(_Radius, _Radius + max(_Softness, 0.01), dist);

    src.rgb = lerp(src.rgb, _Color.rgb, shade * saturate(_Amount));
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
