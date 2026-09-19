/* Scanlines - Screen
 *
 * Dark lines across the image, the CRT tell. On its own it is the cheapest
 * way to make clean pixel art look like it came out of a tube.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Scanlines.fxs by tools/build_shaders.py - edit the
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
float  _Period;
float  _Duty;
float  _Darkness;
float  _Soft;
float  _Offset;
bool   _Vertical;

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
    float4 src = fusionTex(In, In.texCoord);

    float2 pixel = In.texCoord / fusionTexel();
    float coord = _Vertical ? pixel.x : pixel.y;
    float phase = frac((coord + _Offset) / max(_Period, 1.0));

    float edge = max(_Soft, 1.0e-4) * 0.5;
    float duty = saturate(_Duty);
    float lineMask = smoothstep(duty + edge, duty - edge, phase);

    src.rgb *= 1.0 - lineMask * saturate(_Darkness);
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
