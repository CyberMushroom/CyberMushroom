/* Refract - Blend
 *
 * Bends the background as it passes through the object, using the object's
 * own shading as the lens. Draw a bubble, a bottle, a heat pocket or a
 * pane of glass, apply this, and the world behind it warps.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Refract.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
sampler2D S2D_Image : register(s0) = sampler_state
{
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};
sampler2D S2D_Background : register(s1) = sampler_state
{
    MinFilter = Linear;
    MagFilter = Linear;
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
float4 _Tint;
float  _Strength;
float  _Zoom;
float  _TintAmount;
float  _Keep;

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

/* Whatever Fusion has already drawn behind the object. Sample it with
   In.bgCoord, not In.texCoord - they are different mappings. */
float4 fusionBg(float2 uv)
{
    return tex2D(S2D_Background, uv);
}


/* Rec.601 luminance - the weighting that matches how the eye reads a sprite. */
float fusionLuma(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float2 texel = fusionTexel();
    float4 src = fusionTex(In, In.texCoord);

    /* The slope of the sprite's brightness stands in for a surface normal:
       flat areas pass light straight through, slopes bend it. */
    float left = fusionLuma(fusionTex(In, In.texCoord - float2(texel.x, 0.0)).rgb);
    float right = fusionLuma(fusionTex(In, In.texCoord + float2(texel.x, 0.0)).rgb);
    float up = fusionLuma(fusionTex(In, In.texCoord - float2(0.0, texel.y)).rgb);
    float down = fusionLuma(fusionTex(In, In.texCoord + float2(0.0, texel.y)).rgb);

    float2 slope = float2(right - left, down - up);
    float2 uv = In.bgCoord + slope * _Strength * texel;
    uv = (uv - 0.5) / max(1.0 + _Zoom, 0.01) + 0.5;

    float4 bg = fusionBg(saturate(uv));
    bg.rgb = lerp(bg.rgb, _Tint.rgb * fusionLuma(bg.rgb) * 2.0, saturate(_TintAmount));

    float3 rgb = lerp(saturate(bg.rgb), src.rgb, saturate(_Keep));
    return float4(rgb, src.a);
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
