/* Chromatic Aberration - Screen
 *
 * Splits the red and blue channels apart, the way a cheap lens or a
 * composite cable does. A pinch of it sells "screen", a lot of it sells
 * "something is wrong with the machine".
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/ChromaticAberration.fxs by tools/build_shaders.py - edit the
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
float  _Strength;
float  _Angle;
bool   _Radial;
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


float2 fusionRotate(float2 p, float radiansAngle)
{
    float s, c;
    sincos(radiansAngle, s, c);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float2 texel = fusionTexel();
    float2 centred = (In.texCoord - 0.5) * 2.0;

    float2 direction = fusionRotate(float2(1.0, 0.0), radians(_Angle));
    direction.y = -direction.y;
    float2 radial = centred * pow(saturate(length(centred)), max(_Falloff, 0.0));
    float2 offset = (_Radial ? radial : direction) * _Strength * texel;

    float4 src = fusionTex(In, In.texCoord);
    float r = fusionTex(In, In.texCoord + offset).r;
    float b = fusionTex(In, In.texCoord - offset).b;

    return float4(r, src.g, b, src.a);
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
