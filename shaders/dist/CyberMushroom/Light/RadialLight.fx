/* Radial Light - Light
 *
 * Turns a plain rectangle into a light: a soft radial pool of colour, or -
 * with Invert on - a sheet of darkness with a hole cut in it. Two objects
 * and this shader give you a whole lighting system without an extension.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/RadialLight.fxs by tools/build_shaders.py - edit the
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
float4 _Color;
float  _CenterX;
float  _CenterY;
float  _Radius;
float  _Falloff;
float  _Intensity;
float  _Steps;
bool   _Invert;
bool   _Square;

/* --- texture access ------------------------------------------------ */
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

    float aspect = fPixelHeight / max(fPixelWidth, 1.0e-6);
    float2 centred = (In.texCoord - float2(_CenterX, _CenterY)) * 2.0;
    centred.x *= _Square ? 1.0 : aspect;

    float light = saturate(1.0 - length(centred) / max(_Radius, 1.0e-4));
    light = pow(light, _Falloff);

    if (_Steps >= 1.0)
    {
        float bands = floor(_Steps);
        light = floor(light * bands + 0.5) / bands;
    }

    light = saturate(light * _Intensity);

    src.rgb = _Color.rgb;
    src.a *= _Invert ? (1.0 - light) : light;
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
