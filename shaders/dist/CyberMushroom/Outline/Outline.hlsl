/* Outline - Outline
 *
 * Draws a border around the sprite's silhouette. The single most useful
 * effect in a 2D game: it lifts a character off a busy background, marks a
 * selected unit, and flashes an interactable.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Outline.fxs by tools/build_shaders.py - edit the
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
    float  _Thickness;
    float  _Alpha;
    float  _Threshold;
    bool   _Diagonal;
    bool   _Inside;
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
float fusionSpriteAlpha(in PS_INPUT In, float2 uv)
{
    return step(_Threshold, fusionTex(In, uv).a);
}

float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);
    float2 texel = fusionTexel();

    float here = step(_Threshold, src.a);
    float widest = 0.0;
    float narrowest = 1.0;

    const int DIRECTIONS = 8;

    [unroll]
    for (int i = 0; i < DIRECTIONS; i++)
    {
        float angle = (6.2831853 / (float)DIRECTIONS) * (float)i;
        float2 dir;
        sincos(angle, dir.y, dir.x);

        /* Every other direction is a diagonal; in 4-way mode they contribute
           nothing rather than being branched around. */
        bool diagonal = (i == 1 || i == 3 || i == 5 || i == 7);
        float active = (diagonal && !_Diagonal) ? 0.0 : 1.0;

        /* Two samples per direction, so a thick outline stays solid instead
           of breaking into dots at the corners. */
        float outer = fusionSpriteAlpha(In, In.texCoord + dir * texel * _Thickness);
        float inner = fusionSpriteAlpha(In, In.texCoord + dir * texel * _Thickness * 0.5);

        widest = max(widest, max(outer, inner) * active);
        narrowest = min(narrowest, lerp(1.0, min(outer, inner), active));
    }

    float ring = _Inside ? (here * (1.0 - narrowest)) : ((1.0 - here) * widest);
    ring *= saturate(_Alpha);

    src.rgb = lerp(src.rgb, _Color.rgb, ring);
    src.a = max(src.a, ring);
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
