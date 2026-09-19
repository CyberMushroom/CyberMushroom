/* Shockwave - Distort
 *
 * An expanding ring that bends whatever it passes over. The explosion
 * effect: pair it with a white flash and a screen shake and a small hit
 * turns into an event.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Shockwave.fxs by tools/build_shaders.py - edit the
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
float  _CenterX;
float  _CenterY;
float  _Radius;
float  _Width;
float  _Strength;
float  _Highlight;

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
    float aspect = fPixelHeight / max(fPixelWidth, 1.0e-6);

    float2 centred = In.texCoord - float2(_CenterX, _CenterY);
    centred.x *= aspect;

    float dist = length(centred);
    float ring = 1.0 - saturate(abs(dist - _Radius) / max(_Width, 1.0e-4));
    ring *= ring;

    float2 direction = centred / max(dist, 1.0e-5);
    direction.x /= aspect;

    float2 uv = In.texCoord + direction * ring * _Strength * texel;
    float4 src = fusionTex(In, saturate(uv));

    src.rgb = saturate(src.rgb + ring * _Highlight * src.a);
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
