# CyberMushroom shader pack

44 pixel shaders for **Clickteam Fusion 2.5**, built for a 160x144 DMG-palette
game but useful in any 2D Fusion project. Everything is generated from one
source per effect, so the Direct3D 9 and Direct3D 11 versions of an effect can
never drift apart.

- **[REFERENCE.md](REFERENCE.md)** - every effect, every parameter, defaults and
  ranges.
- **[AUTHORING.md](AUTHORING.md)** - how Fusion's effect format actually works,
  and how to add your own effect to the pack.

---

## Install

1. Build the pack (the output is committed, so you can skip this):

   ```
   python tools/build_shaders.py
   ```

2. In Fusion, open the **Tools** menu and pick **Windows Explorer**. That opens
   the folder Fusion is installed in.

3. Copy `shaders/dist/CyberMushroom` into the `Effects` folder there, so you end
   up with `...\Clickteam Fusion 2.5\Effects\CyberMushroom\`.

4. Restart Fusion. The effects appear under **CyberMushroom** in the effect
   picker, grouped by the subfolder names.

5. In **Application properties -> Runtime options**, set **Display mode** to
   **Direct3D 9** or **Direct3D 11**. Effects do nothing in Standard mode.

### If your application uses Direct3D 11

The Direct3D 11 runtime loads compiled `.fxc` files, not the `.hlsl` source.
On Windows, with the Windows SDK installed, run:

```
tools\compile_dx11.bat
```

That compiles every `.hlsl` into `<Name>.fxc` and `<Name>.premultiplied.fxc`
next to it. Copy the folder into `Effects` afterwards.

Direct3D 9 applications do not need this step, and **the Fusion frame editor
always previews through Direct3D 9** - so the `.fx` files are what you see while
you are building the frame, whatever the application's display mode is.

---

## Using an effect

**On an object:** select it, open its properties, go to the **Display** tab (the
paintbrush) and set **Effect**. Its parameters show up right underneath.

**On a whole layer or frame:** layer properties and frame properties have the
same Effect setting. This is where the screen effects belong - CRT, Scanlines,
DMG Palette, Bloom, Vignette.

**Changing a parameter while the game runs:** use the **Set effect parameter**
action on the object (Layer and Frame objects have their own versions). The
parameter name in the action list is the name in
[REFERENCE.md](REFERENCE.md) - `Amount`, `Radius`, and so on.

A hit flash, in three events:

```
* Player collides with Enemy
    Player : Set alterable value A to 1.0

* Always
    Player : Set alterable value A to Max(0.0, Value A( "Player" ) - 0.15)
    Player : Set effect parameter "Amount" to Value A( "Player" )
```

Keeping the value in an alterable and pushing it into the effect every tick is
the pattern for all of these - it gives you something you can read back, ease,
and test against.

Anything with a **Time** parameter needs driving, or it sits still:

```
* Always
    Water : Set effect parameter "Time" to Timer / 1000.0
```

---

## Five things that will catch you out

1. **An object's effect can only see that object's image.** Outline, Glow, Blur,
   Drop Shadow and Motion Blur all need to draw *outside* the sprite, and there
   is nowhere to draw. Leave a few pixels of transparent padding around the art
   in the image editor, or put the effect on the layer instead.

2. **Background effects need a background.** The effects marked "uses
   background" in [REFERENCE.md](REFERENCE.md) read what Fusion has already
   drawn behind the object. Put them on a layer above the thing they should
   read, never on the bottom layer.

3. **Sizes are in texels, not screen pixels.** `fPixelWidth` and `fPixelHeight`
   describe the object's own image, so a Thickness of 1 on an object scaled to
   200% draws a two-screen-pixel outline. For screen effects, use a layer or an
   unscaled full-frame object.

4. **One effect per object.** To stack them, either put the effects on different
   layers, or stack invisible full-screen objects, or write a combined effect -
   `CRT` is four effects in one pass for exactly this reason.

5. **Premultiplied alpha.** If your application has it switched on, Direct3D 11
   uses the `.premultiplied.fxc` build; `compile_dx11.bat` produces both, so
   either setting works. Direct3D 9 is unaffected.

---

## What is in the pack

### Color
Tint, Hit Flash, Adjust (brightness/contrast/saturation/gamma), Hue Shift,
Grayscale, Invert, Posterize, Colour Replace, Colour Key, Gradient Map,
Threshold.

The everyday palette work. **Gradient Map** already defaults to the four DMG
greens, so it recolours anything onto this project's palette in one pass.

### Retro
DMG Palette, Dither, Pixelate, LCD Grid, Palette Ramp.

**DMG Palette** is the one to reach for: it crushes a whole frame down to four
tones with optional ordered dithering. **Palette Ramp** does the same thing from
a palette strip you draw yourself, so you can swap palettes at runtime by
animating one parameter.

### Screen
Scanlines, CRT, Vignette, Chromatic Aberration, Film Grain, Glitch, Bloom.

Post-processing for a layer or the frame. **CRT** bundles curvature, scanlines,
a shadow mask and a vignette into a single pass.

### Distort
Wave, Shockwave, Swirl, Heat Haze, Water Reflection, UV Transform.

**UV Transform** is the quiet workhorse - scroll, scale and rotate the image
inside a static object, which gives you parallax skies, conveyor belts and
flowing lava without moving anything.

### Outline
Outline, Silhouette, Drop Shadow, Glow.

### Mask
Dissolve, Wipe, Iris Wipe, Alpha Mask.

Scene transitions. Put a full-screen object on the top layer and animate
`Amount`, or `Radius` for the iris.

### Light
Radial Light.

Turns a plain rectangle into a light pool, or - with **Invert** on - into a
sheet of darkness with a hole in it. Two objects and you have lighting.

### Blur
Blur, Motion Blur, Radial Blur.

All three are alpha-weighted, so blurring a sprite does not drag dark fringes
out of its transparent edges.

### Blend
Blend Modes, Refract, Stencil Clip.

**Blend Modes** gives you the thirteen Photoshop modes Fusion's ink effects stop
short of. **Stencil Clip** only draws where the background is a particular
colour, which is a cheap way to make water fill only the pool.

---

## Recipes

**The whole game on the DMG palette.** Add a top layer, put a full-frame
Backdrop on it, apply **DMG Palette**, set Dither to about 0.6. Everything
underneath lands on four tones, including sprites you never touched.

**Getting hit.** **Hit Flash** on the player with Amount driven down from 1, plus
**Chromatic Aberration** on the frame spiked to 4 for two frames.

**A level transition.** Full-screen object in your darkest green on the top
layer with **Iris Wipe**, Reverse on, Radius animated from 1.5 to 0, Centre X/Y
following the player.

**A torch.** Full-frame rectangle in the darkest green, **Radial Light** with
Invert on, Banding at 4 so the falloff steps instead of smoothly fading, Centre
X/Y following the player.

**Water.** Copy the scenery under the waterline, apply **Water Reflection**,
animate Time. Add **Stencil Clip** on a second copy if it should stop at the
edge of the pool.

---

## Changing an effect

Edit the source in `shaders/src/<Name>.fxs`, then:

```
python3 tools/build_shaders.py --check
```

`--check` compiles every generated shader with `glslangValidator`
(`apt-get install glslang-tools`) before you ever open Fusion, which catches
typos and HLSL reserved words in seconds rather than after a restart.

Do not edit anything in `shaders/dist/` - it is overwritten on every build.
[AUTHORING.md](AUTHORING.md) explains the source format.

---

This pack is part of the CyberMushroom project. There is no licence file in this
repository yet; add one before sharing the pack on its own.
