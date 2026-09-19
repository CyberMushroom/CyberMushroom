/* Wave - Distort
 *
 * Runs a sine wave through the image. Underwater levels, heat shimmer, a
 * wobbling menu, a flag - one shader, four jobs.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Wave.fxs by tools/build_shaders.py - edit the
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
float  _Amplitude;
float  _Frequency;
float  _Speed;
float  _Time;
bool   _Vertical;
bool   _Clip;

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
    float2 texel = fusionTexel();
    float2 uv = In.texCoord;

    float along = _Vertical ? uv.x : uv.y;
    float phase = along * _Frequency * 6.2831853 + _Time * _Speed;
    float offset = sin(phase) * _Amplitude;

    uv += _Vertical ? float2(0.0, offset * texel.y) : float2(offset * texel.x, 0.0);

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
