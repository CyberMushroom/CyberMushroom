/* Glitch - Screen
 *
 * Torn horizontal bands, an RGB split and dropped lines. The corruption
 * effect - good for damage, bad connections, and anything that should feel
 * like the game itself is breaking.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Glitch.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    float  _Amount;
    float  _Time;
    float  _Bands;
    float  _Shift;
    float  _Split;
    float  _Drop;
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


/* Cheap deterministic hash - same input always gives the same value, so
   dissolves and noise do not crawl unless you actually move them. */
float fusionHash(float2 p)
{
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float2 texel = fusionTexel();
    float time = floor(_Time * 12.0);

    /* One random number per band per frame drives the whole thing, so a band
       either tears, drops or stays put - it never half-does both. */
    float band = floor(In.texCoord.y * max(_Bands, 1.0));
    float roll = fusionHash(float2(band, time));
    float active = step(1.0 - saturate(_Amount), roll);

    float direction = (fusionHash(float2(band, time + 7.0)) - 0.5) * 2.0;
    float2 uv = In.texCoord;
    uv.x += direction * _Shift * texel.x * active;

    float2 split = float2(_Split * texel.x * active * saturate(_Amount), 0.0);
    float4 src = fusionTex(In, uv);
    src.r = fusionTex(In, uv + split).r;
    src.b = fusionTex(In, uv - split).b;

    float dropped = step(1.0 - saturate(_Drop * _Amount), fusionHash(float2(band, time + 23.0)));
    src.rgb *= 1.0 - dropped;

    return src;
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
