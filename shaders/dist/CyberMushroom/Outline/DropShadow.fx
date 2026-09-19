/* Drop Shadow - Outline
 *
 * Casts an offset shadow of the sprite behind itself, in one draw and one
 * object. Lifts HUD cards and text off the background - the same trick the
 * score panel in this repo uses, but free.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/DropShadow.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
sampler2D S2D_Image : register(s0) = sampler_state
{
    MinFilter = Point;
    MagFilter = Point;
    AddressU = Clamp;
    AddressV = Clamp;
};

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
float  _OffsetX;
float  _OffsetY;
float  _Opacity;
float  _Soften;

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
    float2 texel = fusionTexel();
    float4 src = fusionTex(In, In.texCoord);

    float2 shadowUV = In.texCoord - float2(_OffsetX, _OffsetY) * texel;
    float shadow = fusionTex(In, shadowUV).a;

    if (_Soften > 0.0)
    {
        float2 spread = texel * _Soften;
        shadow += fusionTex(In, shadowUV + float2(spread.x, 0.0)).a;
        shadow += fusionTex(In, shadowUV - float2(spread.x, 0.0)).a;
        shadow += fusionTex(In, shadowUV + float2(0.0, spread.y)).a;
        shadow += fusionTex(In, shadowUV - float2(0.0, spread.y)).a;
        shadow /= 5.0;
    }

    shadow *= saturate(_Opacity);

    /* Composite the sprite over its own shadow. */
    float alpha = src.a + shadow * (1.0 - src.a);
    float3 rgb = (src.rgb * src.a + _Color.rgb * shadow * (1.0 - src.a)) / max(alpha, 1.0e-5);

    return float4(rgb, alpha);
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
