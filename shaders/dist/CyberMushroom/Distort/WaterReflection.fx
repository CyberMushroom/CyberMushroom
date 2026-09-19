/* Water Reflection - Distort
 *
 * Flips the image, ripples it and fades it out with depth. Put a copy of
 * your scenery below the waterline, apply this, and it reflects.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/WaterReflection.fxs by tools/build_shaders.py - edit the
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
float  _Amplitude;
float  _Frequency;
float  _Speed;
float  _Time;
float  _Tint;
float  _Fade;
bool   _Flip;

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
    float2 uv = In.texCoord;

    /* depth is 0 at the waterline and 1 at the far edge of the reflection. */
    float depth = _Flip ? uv.y : 1.0 - uv.y;
    if (_Flip)
    {
        uv.y = 1.0 - uv.y;
    }

    float phase = uv.y * _Frequency * 6.2831853 + _Time * _Speed;
    uv.x += sin(phase) * _Amplitude * texel.x * (0.3 + depth);

    float4 src = fusionTex(In, saturate(uv));
    src.rgb = lerp(src.rgb, _Color.rgb, saturate(_Tint));
    src.a *= 1.0 - saturate(_Fade) * depth;
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
