/* Iris Wipe - Mask
 *
 * The shape closing in around the hero at the end of a level. Circle,
 * diamond or square, centred anywhere, opening or closing.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/IrisWipe.fxs by tools/build_shaders.py - edit the
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
float  _Radius;
float  _Softness;
int    _Shape;
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

    float dist = length(centred);
    if (_Shape == 1) dist = abs(centred.x) + abs(centred.y);
    if (_Shape == 2) dist = max(abs(centred.x), abs(centred.y));

    float soft = max(_Softness, 1.0e-4);
    float outside = smoothstep(_Radius - soft, _Radius + soft, dist);

    src.a *= _Invert ? (1.0 - outside) : outside;
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
