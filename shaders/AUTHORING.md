# Writing Fusion effects

Two halves: how Clickteam Fusion's effect format works, and how this pack's
build script wraps it. If you only want to add an effect, skip to
[Adding an effect](#adding-an-effect).

---

## What Fusion loads

An effect is a set of files that share a base name, sitting in a folder under
Fusion's `Effects` directory. Subfolders become groups in the effect picker.

| File | Who reads it | Required |
| --- | --- | --- |
| `Name.xml` | Everything. Declares the name, the parameters and the samplers. | Yes |
| `Name.fx` | The Direct3D 9 runtime **and the frame editor**, always. | Yes |
| `Name.hlsl` | Nothing at runtime - it is the source you compile from. | No |
| `Name.fxc` | The Direct3D 11 runtime. Compiled from the `.hlsl` with `fxc.exe`. | For D3D11 |
| `Name.premultiplied.fxc` | The Direct3D 11 runtime, when the application has premultiplied alpha on. | For D3D11 |

The frame editor renders through Direct3D 9 whatever the application's display
mode is, so an effect without a working `.fx` shows nothing while you are
building the frame even if the `.fxc` is perfect.

Fusion also supports GLSL variants for the mobile exporters (`.fxmo`, `.fxao`)
and WGSL for the newer web runtime (`.fxwg`). This pack does not ship them; the
Windows exporters are covered.

---

## The .xml file

```xml
<effect>
  <name>Hit Flash</name>
  <description>Shown as a tooltip in the effect picker.</description>
  <author>You</author>
  <copyright>Copyright (c) You</copyright>
  <website>https://example.com</website>
  <BackgroundTexture>1</BackgroundTexture>

  <parameter>
    <name>Flash Colour</name>
    <variable>_Color</variable>
    <description>Shown under the parameter in the properties panel.</description>
    <type>int_float4</type>
    <property>color</property>
    <value>16777215</value>
  </parameter>

  <sampler>
    <index>0</index>
    <filter>point</filter>
    <addressU>clamp</addressU>
    <addressV>clamp</addressV>
  </sampler>
</effect>
```

`<name>` is what Fusion shows, `<variable>` is the HLSL identifier the value
lands in. (`<code>` is accepted as a synonym for `<variable>`; image parameters
are usually given both.)

| `<type>` | `<property>` | HLSL type | `<value>` |
| --- | --- | --- | --- |
| `float` | `edit`, `slider`, `spin` | `float` | `1.0` |
| `int` | `edit`, `slider`, `spin` | `int` | `3` |
| `bool` | `checkbox` | `bool` | `0` or `1` |
| `int_float4` | `color` | `float4` | a decimal colour, see below |
| `image` | `image` | a texture, not a constant | filename of a default image |

`<min>` and `<max>` bound the editor's control. `<preview_value>` is used for
the thumbnail in the picker only.

**Colours are stored the Windows way: `0xBBGGRR`, as a decimal.** So red is
`255`, blue is `16711680`, and the DMG lightest green (155, 188, 15) is
`155 + 188*256 + 15*65536` = `1031323`. In the shader it arrives as a normal
`float4` with `.r`, `.g` and `.b` the right way round. Its `.a` is not
meaningful - use a separate float parameter for opacity.

`<sampler>` configures a texture unit rather than declaring one: index 0 is the
object's own image, index 1 is the background texture when
`<BackgroundTexture>` is set (otherwise it is the first image parameter), and
image parameters take the indices after that. `point` filtering is what you want
for pixel art; `linear` for anything you are sampling smoothly, such as a mask.

---

## The .fx file (Direct3D 9)

```hlsl
sampler2D S2D_Image : register(s0);
sampler2D S2D_Background : register(s1);   /* only with <BackgroundTexture> */

struct PS_INPUT
{
    float4 Tint     : COLOR0;      /* semi-transparency and RGB coefficient */
    float2 texCoord : TEXCOORD0;   /* the object's own image */
    float2 bgCoord  : TEXCOORD1;   /* the background - a different mapping */
};

float fPixelWidth;    /* 1 / texture width  - Fusion fills these in */
float fPixelHeight;   /* 1 / texture height */

float4 _Color;        /* one global per <parameter>, matched by name */

float4 ps_main(in PS_INPUT In) : COLOR0
{
    return tex2D(S2D_Image, In.texCoord) * In.Tint;
}

technique tech_main
{
    pass P0
    {
        VertexShader = NULL;
        PixelShader  = compile ps_2_0 ps_main();
    }
}
```

The entry point must be `ps_main` and the technique `tech_main`. Compile targets
from `ps_1_1` to `ps_3_0` all work; `ps_2_0` runs anywhere, and `ps_3_0` is the
one to pick when you need loops, many texture reads or long arithmetic.

**Multiply by `In.Tint`.** That is where the object's semi-transparency and its
RGB coefficient arrive. An effect that ignores it will not fade out with the
object.

**Sample the background with `In.bgCoord`, not `In.texCoord`.** They are
different mappings and mixing them up produces an effect that looks right only
when the object happens to fill the screen.

---

## The .hlsl file (Direct3D 11)

Same maths, different wrapper:

```hlsl
Texture2D<float4> S2D_Image : register(t0);
SamplerState S2D_ImageSampler : register(s0);

cbuffer PS_VARIABLES : register(b0)
{
    float4 _Color;     /* in the same order as the .xml parameters */
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

float4 ps_main(in PS_INPUT In) : SV_TARGET { ... }
float4 ps_main_pm(in PS_INPUT In) : SV_TARGET { ... }
```

Three things differ and all three bite:

1. **The constant buffer order has to match the XML parameter order.** Fusion
   works out where each value goes from the parameter list, so a mismatch does
   not error - it quietly writes your radius into your colour.

2. **Packing.** HLSL will not let a `float4` straddle a 16-byte boundary, so
   three floats followed by a `float4` leaves a 4-byte hole. This pack sidesteps
   the question by emitting every `float4` parameter first, where packed and
   aligned layouts agree. If you hand-write a shader, do the same.

3. **Two entry points.** `ps_main` for straight alpha, `ps_main_pm` for
   premultiplied. In the premultiplied build you divide the sampled colour by
   its alpha before any colour maths and multiply the result back at the end.

Image parameters are *not* in the constant buffer - they are `Texture2D`s bound
to their sampler index.

Compile with:

```
fxc /nologo /T ps_4_0 /E ps_main    /Fo Name.fxc               Name.hlsl
fxc /nologo /T ps_4_0 /E ps_main_pm /Fo Name.premultiplied.fxc Name.hlsl
```

`tools\compile_dx11.bat` does this for the whole pack.

---

## This pack's source format

One `.fxs` file per effect in `shaders/src/`: a header of `@directives` in `//`
comments, then the HLSL body. `tools/build_shaders.py` expands it into the
`.xml`, `.fx` and `.hlsl`.

```hlsl
// @name        Hit Flash
// @category    Color
// @target      ps_2_0
// @background  no
// @description What it does. Wraps onto following comment lines.
// @usage       How to drive it from events. Also wraps.
// @note        A warning worth printing in the reference. Repeatable.
// @sampler     0 point clamp clamp
// @param type=color var=_Color  name="Flash Colour" default=16777215 desc="..."
// @param type=float var=_Amount name="Amount" default=1.0 min=0 max=1 desc="..."

float4 fusion_main(in PS_INPUT In)
{
    float4 src = fusionTex(In, In.texCoord);
    src.rgb = lerp(src.rgb, _Color.rgb, saturate(_Amount));
    return src;
}
```

`@param` fields are all `key=value`, quoted when they contain spaces:
`type` (`float`, `int`, `bool`, `color`, `image`), `var`, `name`, `default`,
`min`, `max`, `prop`, `preview`, `desc`.

The body defines `float4 fusion_main(in PS_INPUT In)` and can declare helper
functions above it. Available to it:

| | |
| --- | --- |
| `fusionTex(In, uv)` | The object's pixel, tinted, demultiplied where it needs to be. |
| `fusionBg(uv)` | The background pixel. Needs `@background yes`. |
| `fusionImage_Name(uv)` | An `image` parameter called `_Name`. |
| `fusionTexel()` | `float2(fPixelWidth, fPixelHeight)` - one texel as a UV step. |
| `fusionLuma`, `fusionRgb2Hsv`, `fusionHsv2Rgb` | Colour helpers. |
| `fusionHash`, `fusionNoise` | Deterministic noise. |
| `fusionBayer2`, `fusionBayer4` | Ordered dither thresholds. |
| `fusionRotate(p, radians)` | 2D rotation. |
| `fusionBlend(base, blend, mode)` | The thirteen blend modes. |

Helpers are only copied into a generated shader if it mentions them, so the
files Fusion parses stay small.

---

## Adding an effect

1. Write `shaders/src/YourEffect.fxs`.
2. `python3 tools/build_shaders.py --check`.
3. Copy `shaders/dist/CyberMushroom` over the one in Fusion's `Effects` folder
   and restart Fusion.
4. For Direct3D 11, run `tools\compile_dx11.bat` first.

`--check` compiles every generated shader with `glslangValidator`
(`apt-get install glslang-tools`). It will not catch a `ps_2_0` instruction
limit, but it catches everything else before you restart Fusion.

### Things that will cost you an afternoon

- **`line` is a reserved word in HLSL.** So are `sample`, `linear`, `point`,
  `vector` and `matrix`. `float line = ...` fails with a parse error that points
  at the next line.
- **Scalar literal swizzles.** `0.0.xxx` compiles on modern compilers and is
  risky on the older one Fusion uses for `.fx`. Write `float3(0.0, 0.0, 0.0)`.
- **`ps_2_0` is small**: 64 arithmetic and 32 texture instructions. Anything
  with a loop of taps - blur, outline, glow - should declare
  `@target ps_3_0`.
- **Loop bounds must be constants.** A parameter cannot be the tap count. Use a
  constant bound and weight the taps by the parameter instead, which is what
  `Blur` does with its Quality setting.
- **Unused parameters get optimised away**, and then Fusion cannot find them to
  set them. Every parameter you declare should be read by the body.
