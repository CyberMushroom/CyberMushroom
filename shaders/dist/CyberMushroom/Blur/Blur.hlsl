/* Blur - Blur
 *
 * A round, single-pass blur. Alpha-weighted, so blurring a sprite does not
 * drag dark fringes out of its transparent edges the way a naive blur
 * does.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Blur.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    float  _Radius;
    float  _Quality;
    float  _Amount;
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
