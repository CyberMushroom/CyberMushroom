/* Wipe - Mask
 *
 * A straight-edged wipe at any angle, with an optional coloured leading
 * edge. The workhorse scene transition - put it on a full-screen object
 * and animate Amount.
 *
 * Direct3D 9 effect for Clickteam Fusion 2.5.
 * Generated from shaders/src/Wipe.fxs by tools/build_shaders.py - edit the
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
float4 _EdgeColor;
float  _Amount;
float  _Angle;
float  _Softness;
float  _Edge;
bool   _Invert;

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
