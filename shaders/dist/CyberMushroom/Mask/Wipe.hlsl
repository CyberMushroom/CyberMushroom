/* Wipe - Mask
 *
 * A straight-edged wipe at any angle, with an optional coloured leading
 * edge. The workhorse scene transition - put it on a full-screen object
 * and animate Amount.
 *
 * Direct3D 11 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Wipe.fxs by tools/build_shaders.py - edit the
 * source, not this file.
 */


/* --- samplers ------------------------------------------------------ */
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

/* --- parameters ---------------------------------------------------- */
/* The order here has to match the parameter order in the .xml file. */
cbuffer PS_VARIABLES : register(b0)
{
    float4 _EdgeColor;
    float  _Amount;
    float  _Angle;
    float  _Softness;
    float  _Edge;
    bool   _Invert;
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


float2 fusionRotate(float2 p, float radiansAngle)
{
    float s, c;
    sincos(radiansAngle, s, c);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);

    float2 dir = fusionRotate(float2(1.0, 0.0), radians(_Angle));
    dir.y = -dir.y;
    /* Project onto the wipe direction and rescale so Amount 0..1 always
       crosses the whole object, whatever the angle. */
    float reach = abs(dir.x) + abs(dir.y);
    float along = (dot(In.texCoord - 0.5, dir) / reach) + 0.5;

    float amount = saturate(_Invert ? 1.0 - _Amount : _Amount);
    float soft = max(_Softness, 1.0e-4);
    float gone = 1.0 - smoothstep(amount - soft, amount + soft, along);

    float edge = max(_Edge, 1.0e-4);
    float band = saturate((amount + edge - along) / edge) * (1.0 - gone);

    src.rgb = lerp(src.rgb, _EdgeColor.rgb, band * step(0.001, _Edge));
    src.a *= 1.0 - gone;
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
