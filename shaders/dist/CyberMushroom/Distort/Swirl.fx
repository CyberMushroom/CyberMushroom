/* Swirl - Distort
 *
 * Twists the image around a point, hardest in the middle and fading to
 * nothing at the edge of its radius. Portals, whirlpools, drains, and a
 * very good "sucked into the pipe" transition.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Swirl.fxs by tools/build_shaders.py - edit the
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
float  _Angle;
float  _Radius;
bool   _Clip;

/* --- texture access ------------------------------------------------ */
/* The object's own pixel, with Fusion's tint (semi-transparency and
   RGB coefficient) already applied. */
float4 fusionTex(in PS_INPUT In, float2 uv)
{
    return tex2D(S2D_Image, uv) * In.Tint;
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
    float aspect = fPixelHeight / max(fPixelWidth, 1.0e-6);
    float2 center = float2(_CenterX, _CenterY);

    float2 centred = In.texCoord - center;
    centred.x *= aspect;

    /* Squared falloff, so the middle spins hard and the rim stays still
       instead of shearing against the untwisted pixels around it. */
    float fade = saturate(1.0 - length(centred) / max(_Radius, 0.01));
    centred = fusionRotate(centred, radians(_Angle) * fade * fade);

    centred.x /= aspect;
    float2 uv = center + centred;

    float4 src = fusionTex(In, saturate(uv));
    if (_Clip)
    {
        float2 inside = step(float2(0.0, 0.0), uv) * step(uv, float2(1.0, 1.0));
        src *= inside.x * inside.y;
    }
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
