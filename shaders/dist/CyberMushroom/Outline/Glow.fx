/* Glow - Outline
 *
 * A soft halo around the sprite's silhouette, drawn behind it. Unlike
 * Bloom this does not care how bright the sprite is - a pitch black sprite
 * still glows - so it works for magic, pickups and selection states.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Glow.fxs by tools/build_shaders.py - edit the
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
float  _Radius;
float  _Strength;
float  _Falloff;

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
    float4 src = fusionTex(In, In.texCoord);
    float2 texel = fusionTexel();

    float glow = 0.0;
    const int DIRECTIONS = 8;
    const int RINGS = 3;

    [unroll]
    for (int i = 0; i < DIRECTIONS; i++)
    {
        float angle = (6.2831853 / (float)DIRECTIONS) * ((float)i + 0.5);
        float2 dir;
        sincos(angle, dir.y, dir.x);

        [unroll]
        for (int r = 1; r <= RINGS; r++)
        {
            float spread = (float)r / (float)RINGS;
            float weight = pow(1.0 - spread, _Falloff);
            glow = max(glow, fusionTex(In, In.texCoord + dir * texel * _Radius * spread).a * weight);
        }
    }

    glow = saturate(glow * _Strength);

    /* The halo sits behind the sprite, so the sprite's own pixels win. */
    float alpha = src.a + glow * (1.0 - src.a);
    float3 rgb = (src.rgb * src.a + _Color.rgb * glow * (1.0 - src.a)) / max(alpha, 1.0e-5);

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
        PixelShader  = compile ps_3_0 ps_main();
    }
}
