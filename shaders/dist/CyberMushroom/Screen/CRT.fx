/* CRT - Screen
 *
 * A whole tube in one pass: barrel curvature, scanlines, a shadow mask and
 * a vignette, with the area outside the glass blacked out. Everything can
 * be dialled to zero, so you can keep just the parts you want.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/CRT.fxs by tools/build_shaders.py - edit the
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
float4 _Bezel;
float  _Curve;
float  _Scanlines;
float  _Period;
float  _Mask;
float  _Vignette;
float  _Brightness;

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


/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    /* Bow the sampling grid outward from the centre of the screen. */
    float2 centred = In.texCoord - 0.5;
    float2 uv = In.texCoord + centred * dot(centred, centred) * _Curve;

    float2 outside = step(uv, float2(0.0, 0.0)) + step(float2(1.0, 1.0), uv);
    float offGlass = saturate(outside.x + outside.y);

    float4 src = fusionTex(In, saturate(uv));

    float2 pixel = uv / fusionTexel();

    float phase = frac(pixel.y / max(_Period, 1.0));
    float scan = abs(phase - 0.5) * 2.0;
    src.rgb *= 1.0 - (1.0 - scan) * saturate(_Scanlines);

    /* Three-phase stripe mask: each screen column leans toward one primary. */
    float stripe = frac(pixel.x / 3.0);
    float3 mask = float3(step(stripe, 0.334),
                         step(0.334, stripe) * step(stripe, 0.667),
                         step(0.667, stripe));
    src.rgb *= lerp(float3(1.0, 1.0, 1.0), 0.4 + mask * 1.2, saturate(_Mask));

    float2 vig = centred * 2.0;
    src.rgb *= 1.0 - saturate(dot(vig, vig) * 0.5) * saturate(_Vignette);

    src.rgb = saturate(src.rgb * _Brightness);
    src.rgb = lerp(src.rgb, _Bezel.rgb, offGlass);
    src.a = lerp(src.a, 1.0, offGlass);
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
