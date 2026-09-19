/* Glow - Outline
 *
 * A soft halo around the sprite's silhouette, drawn behind it. Unlike
 * Bloom this does not care how bright the sprite is - a pitch black sprite
 * still glows - so it works for magic, pickups and selection states.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Glow.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    float4 _Color;
    float  _Radius;
    float  _Strength;
    float  _Falloff;
};

cbuffer PS_PIXELSIZE : register(b1)
{
    float fPixelWidth;
    float fPixelHeight;
};

struct PS_INPUT
{
    float4 Tint     : COLOR0;
    float2 texCoord : TEXCOORD0;
    float2 bgCoord  : TEXCOORD1;
    float4 Position : SV_POSITION;
};

/* Set by the two entry points below: the premultiplied-alpha build has
   to undo the multiply before any colour maths and redo it after. */
static bool FUSION_PREMULTIPLIED = false;

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
    float4 c = S2D_Image.Sample(S2D_ImageSampler, uv) * In.Tint;
    if (FUSION_PREMULTIPLIED && c.a > 0.0)
    {
        c.rgb /= c.a;
    }
    return c;
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

/* --- entry points -------------------------------------------------- */
float4 ps_main(in PS_INPUT In) : SV_TARGET
{
    FUSION_PREMULTIPLIED = false;
    return fusion_main(In);
}

float4 ps_main_pm(in PS_INPUT In) : SV_TARGET
{
    FUSION_PREMULTIPLIED = true;
    float4 result = fusion_main(In);
    result.rgb *= result.a;
    return result;
}
