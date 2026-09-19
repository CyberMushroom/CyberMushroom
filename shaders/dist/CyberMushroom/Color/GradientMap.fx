/* Gradient Map - Color
 *
 * Throws away the hue and re-colours the sprite by brightness across four
 * stops. This is how you get a whole scene onto one palette in a single
 * pass: the defaults are already the DMG greens, darkest to lightest.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/GradientMap.fxs by tools/build_shaders.py - edit the
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
float4 _Stop0;
float4 _Stop1;
float4 _Stop2;
float4 _Stop3;
float  _Offset;
float  _Contrast;
float  _Amount;

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

    float luma = fusionLuma(src.rgb);
    luma = saturate((luma - 0.5) * _Contrast + 0.5 + _Offset);

    float t = luma * 3.0;
    float3 ramp = lerp(_Stop0.rgb, _Stop1.rgb, saturate(t));
    ramp = lerp(ramp, _Stop2.rgb, saturate(t - 1.0));
    ramp = lerp(ramp, _Stop3.rgb, saturate(t - 2.0));

    src.rgb = lerp(src.rgb, ramp, saturate(_Amount));
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
