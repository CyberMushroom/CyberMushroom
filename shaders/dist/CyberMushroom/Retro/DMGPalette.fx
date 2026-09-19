/* DMG Palette - Retro
 *
 * Crushes anything you point it at down to four tones - the original Game
 * Boy screen, by default the same 155/188/15 greens the HUD assets in this
 * repo are drawn on. Optional ordered dithering buys back the gradients
 * four colours cannot hold.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/DMGPalette.fxs by tools/build_shaders.py - edit the
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
float4 _Shade0;
float4 _Shade1;
float4 _Shade2;
float4 _Shade3;
float  _Brightness;
float  _Contrast;
float  _Dither;
bool   _Coarse;
float  _Amount;

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


/* Rec.601 luminance - the weighting that matches how the eye reads a sprite. */
float fusionLuma(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

/* 4x4 ordered dither threshold in [0,1), indexed by screen-space pixel. */
float fusionBayer4(float2 pixel)
{
    float2 p = floor(fmod(abs(pixel), 4.0));
    float4 row0 = float4( 0.0,  8.0,  2.0, 10.0);
    float4 row1 = float4(12.0,  4.0, 14.0,  6.0);
    float4 row2 = float4( 3.0, 11.0,  1.0,  9.0);
    float4 row3 = float4(15.0,  7.0, 13.0,  5.0);
    float4 row = row0;
    row = (p.y > 0.5) ? row1 : row;
    row = (p.y > 1.5) ? row2 : row;
    row = (p.y > 2.5) ? row3 : row;
    float v = row.x;
    v = (p.x > 0.5) ? row.y : v;
    v = (p.x > 1.5) ? row.z : v;
    v = (p.x > 2.5) ? row.w : v;
    return v / 16.0;
}

/* 2x2 ordered dither threshold in [0,1). */
float fusionBayer2(float2 pixel)
{
    float2 p = floor(fmod(abs(pixel), 2.0));
    float v = (p.y > 0.5) ? ((p.x > 0.5) ? 1.0 : 3.0)
                          : ((p.x > 0.5) ? 2.0 : 0.0);
    return v / 4.0;
}

/* --- effect -------------------------------------------------------- */
float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);

    float luma = fusionLuma(src.rgb);
    luma = (luma - 0.5) * _Contrast + 0.5 + _Brightness;

    /* Four tones means three steps, so the dither offset is at most half a
       step either way - any more and it stops reading as shading. */
    float2 pixel = In.texCoord / fusionTexel();
    float threshold = _Coarse ? fusionBayer2(pixel) : fusionBayer4(pixel);
    luma = saturate(luma + (threshold - 0.5) * _Dither / 3.0);

    float index = floor(luma * 3.0 + 0.5);
    float3 tone = _Shade0.rgb;
    tone = (index > 0.5) ? _Shade1.rgb : tone;
    tone = (index > 1.5) ? _Shade2.rgb : tone;
    tone = (index > 2.5) ? _Shade3.rgb : tone;

    src.rgb = lerp(src.rgb, tone, saturate(_Amount));
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
