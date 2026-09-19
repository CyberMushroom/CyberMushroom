/* Blur - Blur
 *
 * A round, single-pass blur. Alpha-weighted, so blurring a sprite does not
 * drag dark fringes out of its transparent edges the way a naive blur
 * does.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Blur.fxs by tools/build_shaders.py - edit the
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
float  _Radius;
float  _Quality;
float  _Amount;

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

    float rings = clamp(floor(_Quality), 1.0, 3.0);

    float4 sum = float4(src.rgb * src.a, src.a);
    float weight = 1.0;

    const int DIRECTIONS = 8;
    const int MAX_RINGS = 3;

    [unroll]
    for (int r = 1; r <= MAX_RINGS; r++)
    {
        float spread = (float)r / rings;
        /* Rings past the chosen quality are sampled but weighted to nothing,
           which keeps the loop free of branches the old compilers dislike. */
        float active = step((float)r, rings);

        [unroll]
        for (int i = 0; i < DIRECTIONS; i++)
        {
            /* Offset every ring by half a step so the taps spiral instead of
               lining up into spokes. */
            float angle = (6.2831853 / (float)DIRECTIONS) * ((float)i + (float)r * 0.5);
            float2 dir;
            sincos(angle, dir.y, dir.x);

            float4 tap = fusionTex(In, In.texCoord + dir * texel * _Radius * spread);
            float w = (1.0 - spread * 0.5) * active;

            /* Weighting colour by alpha keeps transparent pixels from
               contributing their (arbitrary) colour to the average. */
            sum += float4(tap.rgb * tap.a, tap.a) * w;
            weight += w;
        }
    }

    sum /= weight;
    float4 blurred = float4(sum.rgb / max(sum.a, 1.0e-5), sum.a);

    return lerp(src, blurred, saturate(_Amount));
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
