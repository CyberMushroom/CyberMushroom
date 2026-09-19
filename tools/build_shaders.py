#!/usr/bin/env python3
"""Build Clickteam Fusion effect files from the sources in shaders/src.

Every effect is written once as a .fxs file: a small header of @directives
followed by an HLSL body. This script expands each source into the three files
Fusion actually loads:

    <Name>.xml    effect definition (name, description, parameters, samplers)
    <Name>.fx     Direct3D 9 pixel shader - used by the frame editor *and* by
                  applications whose display mode is Direct3D 9
    <Name>.hlsl   Direct3D 11 source - compile to <Name>.fxc with fxc.exe
                  (tools/compile_dx11.bat) for Direct3D 11 applications

Writing the two HLSL dialects by hand is how shader packs drift; generating
both from one body keeps the DX9 and DX11 versions of an effect identical.

Usage:
    python3 tools/build_shaders.py            # build shaders/dist + reference
    python3 tools/build_shaders.py --check    # build, then compile-test the
                                              # output with glslangValidator
"""

import argparse
import os
import re
import shlex
import sys
import textwrap
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, os.pardir))
SRC_DIR = os.path.join(ROOT, "shaders", "src")
DIST_DIR = os.path.join(ROOT, "shaders", "dist")
PACK_NAME = "CyberMushroom"
REFERENCE = os.path.join(ROOT, "shaders", "REFERENCE.md")

DEFAULT_AUTHOR = "CyberMushroom"
DEFAULT_WEBSITE = "https://github.com/CyberMushroom/CyberMushroom"
DEFAULT_COPYRIGHT = "Copyright (c) CyberMushroom"

# Fusion parameter type -> (xml <type>, xml <property>, hlsl type)
PARAM_TYPES = {
    "float": ("float", "edit", "float"),
    "int": ("int", "edit", "int"),
    "bool": ("bool", "checkbox", "bool"),
    "color": ("int_float4", "color", "float4"),
    "image": ("image", "image", None),
}

# ---------------------------------------------------------------------------
# Shared helper library. A function is copied into a generated shader only when
# that shader (or another helper it pulls in) mentions it by name, so the files
# Fusion parses stay small.
# ---------------------------------------------------------------------------
LIBRARY = {
    "fusionLuma": """
/* Rec.601 luminance - the weighting that matches how the eye reads a sprite. */
float fusionLuma(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}
""",
    "fusionRgb2Hsv": """
float3 fusionRgb2Hsv(float3 c)
{
    float4 k = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, k.wz), float4(c.gb, k.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-6)),
                  d / (q.x + 1.0e-6),
                  q.x);
}
""",
    "fusionHsv2Rgb": """
float3 fusionHsv2Rgb(float3 c)
{
    float3 p = abs(frac(c.xxx + float3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * lerp(float3(1.0, 1.0, 1.0), saturate(p - 1.0), c.y);
}
""",
    "fusionHash": """
/* Cheap deterministic hash - same input always gives the same value, so
   dissolves and noise do not crawl unless you actually move them. */
float fusionHash(float2 p)
{
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}
""",
    "fusionNoise": """
/* Smoothed value noise in [0,1]. */
float fusionNoise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = fusionHash(i);
    float b = fusionHash(i + float2(1.0, 0.0));
    float c = fusionHash(i + float2(0.0, 1.0));
    float d = fusionHash(i + float2(1.0, 1.0));
    return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}
""",
    "fusionBayer4": """
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
""",
    "fusionBayer2": """
/* 2x2 ordered dither threshold in [0,1). */
float fusionBayer2(float2 pixel)
{
    float2 p = floor(fmod(abs(pixel), 2.0));
    float v = (p.y > 0.5) ? ((p.x > 0.5) ? 1.0 : 3.0)
                          : ((p.x > 0.5) ? 2.0 : 0.0);
    return v / 4.0;
}
""",
    "fusionRotate": """
float2 fusionRotate(float2 p, float radiansAngle)
{
    float s, c;
    sincos(radiansAngle, s, c);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}
""",
    "fusionBlend": """
/* Photoshop-style blend of a base colour with a blend colour.
   0 normal      1 add        2 multiply   3 screen     4 overlay
   5 soft light  6 hard light 7 difference 8 lighten    9 darken
   10 colour dodge           11 colour burn            12 exclusion */
float3 fusionBlend(float3 b, float3 s, int mode)
{
    float3 r = s;
    if (mode == 1)  r = b + s;
    if (mode == 2)  r = b * s;
    if (mode == 3)  r = 1.0 - (1.0 - b) * (1.0 - s);
    if (mode == 4)  r = lerp(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(0.5, b));
    if (mode == 5)  r = lerp(2.0 * b * s + b * b * (1.0 - 2.0 * s),
                             sqrt(max(b, 0.0)) * (2.0 * s - 1.0) + 2.0 * b * (1.0 - s),
                             step(0.5, s));
    if (mode == 6)  r = lerp(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(0.5, s));
    if (mode == 7)  r = abs(b - s);
    if (mode == 8)  r = max(b, s);
    if (mode == 9)  r = min(b, s);
    if (mode == 10) r = b / max(1.0 - s, 1.0e-4);
    if (mode == 11) r = 1.0 - (1.0 - b) / max(s, 1.0e-4);
    if (mode == 12) r = b + s - 2.0 * b * s;
    return saturate(r);
}
""",
}


class Param(object):
    def __init__(self, kind, var, name, default, desc, minimum, maximum, prop, preview):
        self.kind = kind
        self.var = var
        self.name = name
        self.default = default
        self.desc = desc
        self.min = minimum
        self.max = maximum
        self.prop = prop
        self.preview = preview

    @property
    def is_image(self):
        return self.kind == "image"

    @property
    def is_color(self):
        return self.kind == "color"


class Effect(object):
    def __init__(self, path):
        self.path = path
        self.base = os.path.splitext(os.path.basename(path))[0]
        self.name = self.base
        self.category = "Misc"
        self.description = ""
        self.usage = ""
        self.notes = []
        self.target = "ps_2_0"
        self.background = False
        self.author = DEFAULT_AUTHOR
        self.website = DEFAULT_WEBSITE
        self.copyright = DEFAULT_COPYRIGHT
        self.samplers = []          # (index, filter, addressU, addressV)
        self.params = []
        self.body = ""

    # -- parameters in the order Fusion stores them -------------------------
    @property
    def ordered_params(self):
        """float4s first, then scalars.

        Fusion lays the DX11 constant buffer out from the XML parameter list.
        Keeping every float4 ahead of the scalars means packed layout and HLSL
        16-byte-alignment rules agree, so a colour can never land at a
        different offset than the one the runtime writes to.
        """
        colors = [p for p in self.params if p.is_color]
        rest = [p for p in self.params if not p.is_color and not p.is_image]
        images = [p for p in self.params if p.is_image]
        return colors + rest + images

    @property
    def image_params(self):
        return [p for p in self.params if p.is_image]

    def sampler_index(self, param):
        first = 2 if self.background else 1
        return first + self.image_params.index(param)


def parse_source(path):
    fx = Effect(path)
    lines = open(path, "r").read().split("\n")
    body_start = 0
    last_key = None

    for i, raw in enumerate(lines):
        line = raw.strip()
        if line == "":
            if last_key is not None:
                last_key = None
            continue
        if not line.startswith("//"):
            body_start = i
            break
        comment = line[2:].strip()
        if comment.startswith("@"):
            key, _, value = comment[1:].partition(" ")
            key = key.lower()
            value = value.strip()
            apply_directive(fx, key, value, path)
            last_key = key
        elif last_key in ("name", "description", "usage", "note"):
            # continuation line for the previous directive
            apply_directive(fx, "continue:" + last_key, comment, path)
    else:
        body_start = len(lines)

    fx.body = "\n".join(lines[body_start:]).strip("\n")
    if "fusion_main" not in fx.body:
        raise SystemExit("%s: body must define float4 fusion_main(in PS_INPUT In)" % path)
    return fx


def apply_directive(fx, key, value, path):
    cont = key.startswith("continue:")
    if cont:
        key = key.split(":", 1)[1]

    if key == "name":
        fx.name = (fx.name + " " + value).strip() if cont else value
    elif key == "category":
        fx.category = value
    elif key in ("description", "desc"):
        fx.description = (fx.description + " " + value).strip() if cont else value
    elif key == "usage":
        fx.usage = (fx.usage + " " + value).strip() if cont else value
    elif key == "note":
        if cont and fx.notes:
            fx.notes[-1] = fx.notes[-1] + " " + value
        else:
            fx.notes.append(value)
    elif key == "target":
        fx.target = value
    elif key == "background":
        fx.background = value.lower() in ("1", "yes", "true", "on")
    elif key == "author":
        fx.author = value
    elif key == "website":
        fx.website = value
    elif key == "copyright":
        fx.copyright = value
    elif key == "sampler":
        bits = value.split()
        if len(bits) != 4:
            raise SystemExit("%s: @sampler needs 'index filter addressU addressV'" % path)
        fx.samplers.append((int(bits[0]), bits[1], bits[2], bits[3]))
    elif key == "param":
        fx.params.append(parse_param(value, path))
    else:
        raise SystemExit("%s: unknown directive @%s" % (path, key))


def parse_param(value, path):
    fields = {}
    for token in shlex.split(value):
        if "=" not in token:
            raise SystemExit("%s: @param fields must be key=value, got %r" % (path, token))
        k, _, v = token.partition("=")
        fields[k.lower()] = v

    kind = fields.get("type")
    if kind not in PARAM_TYPES:
        raise SystemExit("%s: @param type must be one of %s" % (path, ", ".join(PARAM_TYPES)))
    var = fields.get("var")
    if not var:
        raise SystemExit("%s: @param needs var=" % path)

    return Param(
        kind=kind,
        var=var,
        name=fields.get("name", var.lstrip("_").replace("_", " ")),
        default=fields.get("default", "0"),
        desc=fields.get("desc", ""),
        minimum=fields.get("min"),
        maximum=fields.get("max"),
        prop=fields.get("prop", PARAM_TYPES[kind][1]),
        preview=fields.get("preview"),
    )


# ---------------------------------------------------------------------------
# helper library selection
# ---------------------------------------------------------------------------
def collect_library(body):
    chosen = []
    pending = True
    text = body
    while pending:
        pending = False
        for fname, source in LIBRARY.items():
            if fname in chosen:
                continue
            if re.search(r"\b%s\b" % re.escape(fname), text):
                chosen.append(fname)
                text += source
                pending = True
    order = list(LIBRARY.keys())
    chosen.sort(key=order.index)
    return "".join(LIBRARY[f] for f in chosen)


# ---------------------------------------------------------------------------
# emitters
# ---------------------------------------------------------------------------
def banner(fx, runtime):
    description = "\n".join(
        " * " + line
        for line in textwrap.wrap(fx.description or "No description.", 72)
    )
    return (
        "/* %s - %s\n"
        " *\n"
        "%s\n"
        " *\n"
        " * %s effect for Clickteam Fusion 2.5.\n"
        " * Generated from shaders/src/%s by tools/build_shaders.py - edit the\n"
        " * source, not this file.\n"
        " */\n" % (
            fx.name,
            fx.category,
            description,
            runtime,
            os.path.basename(fx.path),
        )
    )


def emit_xml(fx):
    out = ['<?xml version="1.0" encoding="utf-8"?>', "<effect>"]
    out.append("  <name>%s</name>" % escape(fx.name))
    out.append("  <description>%s</description>" % escape(fx.description))
    out.append("  <author>%s</author>" % escape(fx.author))
    out.append("  <copyright>%s</copyright>" % escape(fx.copyright))
    out.append("  <website>%s</website>" % escape(fx.website))
    if fx.background:
        out.append("  <BackgroundTexture>1</BackgroundTexture>")

    for p in fx.ordered_params:
        xml_type, default_prop, _ = PARAM_TYPES[p.kind]
        out.append("")
        out.append("  <parameter>")
        out.append("    <name>%s</name>" % escape(p.name))
        out.append("    <variable>%s</variable>" % escape(p.var))
        if p.is_image:
            # Fusion's image parameters are read through <code> as well.
            out.append("    <code>%s</code>" % escape(p.var))
        if p.desc:
            out.append("    <description>%s</description>" % escape(p.desc))
        out.append("    <type>%s</type>" % xml_type)
        out.append("    <property>%s</property>" % escape(p.prop or default_prop))
        if not p.is_image:
            out.append("    <value>%s</value>" % escape(p.default))
            if p.preview is not None:
                out.append("    <preview_value>%s</preview_value>" % escape(p.preview))
            if p.min is not None:
                out.append("    <min>%s</min>" % escape(p.min))
            if p.max is not None:
                out.append("    <max>%s</max>" % escape(p.max))
        out.append("  </parameter>")

    for index, filt, au, av in fx.samplers:
        out.append("")
        out.append("  <sampler>")
        out.append("    <index>%d</index>" % index)
        out.append("    <filter>%s</filter>" % filt)
        out.append("    <addressU>%s</addressU>" % au)
        out.append("    <addressV>%s</addressV>" % av)
        out.append("  </sampler>")

    out.append("</effect>")
    return "\n".join(out) + "\n"


def sampler_state_dx9(fx, index):
    for i, filt, au, av in fx.samplers:
        if i != index:
            continue
        f = "Point" if filt.lower() == "point" else "Linear"
        return (
            " = sampler_state\n"
            "{\n"
            "    MinFilter = %s;\n"
            "    MagFilter = %s;\n"
            "    AddressU = %s;\n"
            "    AddressV = %s;\n"
            "}" % (f, f, au.capitalize(), av.capitalize())
        )
    return ""


def emit_fx(fx):
    out = [banner(fx, "Direct3D 9"), ""]
    out.append("/* --- samplers ------------------------------------------------------ */")
    out.append("sampler2D S2D_Image : register(s0)%s;" % sampler_state_dx9(fx, 0))
    if fx.background:
        out.append("sampler2D S2D_Background : register(s1)%s;" % sampler_state_dx9(fx, 1))
    for p in fx.image_params:
        idx = fx.sampler_index(p)
        out.append("sampler2D %s : register(s%d)%s;" % (p.var, idx, sampler_state_dx9(fx, idx)))
    out.append("")
    out.append("struct PS_INPUT")
    out.append("{")
    out.append("    float4 Tint     : COLOR0;")
    out.append("    float2 texCoord : TEXCOORD0;")
    out.append("    float2 bgCoord  : TEXCOORD1;")
    out.append("};")
    out.append("")
    out.append("/* --- parameters ---------------------------------------------------- */")
    out.append("/* Fusion fills these two in for you: one texel of the object's")
    out.append("   texture, in texture coordinates. */")
    out.append("float fPixelWidth;")
    out.append("float fPixelHeight;")
    for p in fx.ordered_params:
        if p.is_image:
            continue
        _, _, hlsl_type = PARAM_TYPES[p.kind]
        out.append("%-6s %s;" % (hlsl_type, p.var))
    out.append("")
    out.append(prelude(fx, dx11=False))
    out.append(collect_library(fx.body))
    out.append("/* --- effect -------------------------------------------------------- */")
    out.append(fx.body)
    out.append("")
    out.append("/* --- entry point --------------------------------------------------- */")
    out.append("float4 ps_main(in PS_INPUT In) : COLOR0")
    out.append("{")
    out.append("    return fusion_main(In);")
    out.append("}")
    out.append("")
    out.append("technique tech_main")
    out.append("{")
    out.append("    pass P0")
    out.append("    {")
    out.append("        VertexShader = NULL;")
    out.append("        PixelShader  = compile %s ps_main();" % fx.target)
    out.append("    }")
    out.append("}")
    return "\n".join(out) + "\n"


def emit_hlsl(fx):
    out = [banner(fx, "Direct3D 11"), ""]
    out.append("/* --- samplers ------------------------------------------------------ */")
    out.append("Texture2D<float4> S2D_Image : register(t0);")
    out.append("SamplerState S2D_ImageSampler : register(s0);")
    if fx.background:
        out.append("")
        out.append("Texture2D<float4> S2D_Background : register(t1);")
        out.append("SamplerState S2D_BackgroundSampler : register(s1);")
    for p in fx.image_params:
        idx = fx.sampler_index(p)
        out.append("")
        out.append("Texture2D<float4> %s : register(t%d);" % (p.var, idx))
        out.append("SamplerState %sSampler : register(s%d);" % (p.var, idx))
    out.append("")
    out.append("/* --- parameters ---------------------------------------------------- */")
    out.append("/* The order here has to match the parameter order in the .xml file. */")
    scalars = [p for p in fx.ordered_params if not p.is_image]
    if scalars:
        out.append("cbuffer PS_VARIABLES : register(b0)")
        out.append("{")
        for p in scalars:
            _, _, hlsl_type = PARAM_TYPES[p.kind]
            out.append("    %-6s %s;" % (hlsl_type, p.var))
        out.append("};")
        out.append("")
    out.append("cbuffer PS_PIXELSIZE : register(b1)")
    out.append("{")
    out.append("    float fPixelWidth;")
    out.append("    float fPixelHeight;")
    out.append("};")
    out.append("")
    out.append("struct PS_INPUT")
    out.append("{")
    out.append("    float4 Tint     : COLOR0;")
    out.append("    float2 texCoord : TEXCOORD0;")
    out.append("    float2 bgCoord  : TEXCOORD1;")
    out.append("    float4 Position : SV_POSITION;")
    out.append("};")
    out.append("")
    out.append("/* Set by the two entry points below: the premultiplied-alpha build has")
    out.append("   to undo the multiply before any colour maths and redo it after. */")
    out.append("static bool FUSION_PREMULTIPLIED = false;")
    out.append("")
    out.append(prelude(fx, dx11=True))
    out.append(collect_library(fx.body))
    out.append("/* --- effect -------------------------------------------------------- */")
    out.append(fx.body)
    out.append("")
    out.append("/* --- entry points -------------------------------------------------- */")
    out.append("float4 ps_main(in PS_INPUT In) : SV_TARGET")
    out.append("{")
    out.append("    FUSION_PREMULTIPLIED = false;")
    out.append("    return fusion_main(In);")
    out.append("}")
    out.append("")
    out.append("float4 ps_main_pm(in PS_INPUT In) : SV_TARGET")
    out.append("{")
    out.append("    FUSION_PREMULTIPLIED = true;")
    out.append("    float4 result = fusion_main(In);")
    out.append("    result.rgb *= result.a;")
    out.append("    return result;")
    out.append("}")
    return "\n".join(out) + "\n"


def prelude(fx, dx11):
    lines = ["/* --- texture access ------------------------------------------------ */"]
    if "fusionTexel" in fx.body:
        lines.append("/* One texel of the object's texture, as a texture-coordinate step. */")
        lines.append("float2 fusionTexel()")
        lines.append("{")
        lines.append("    return max(float2(fPixelWidth, fPixelHeight), 1.0e-6);")
        lines.append("}")
        lines.append("")
    lines.append("/* The object's own pixel, with Fusion's tint (semi-transparency and")
    lines.append("   RGB coefficient) already applied. */")
    lines.append("float4 fusionTex(in PS_INPUT In, float2 uv)")
    lines.append("{")
    if dx11:
        lines.append("    float4 c = S2D_Image.Sample(S2D_ImageSampler, uv) * In.Tint;")
        lines.append("    if (FUSION_PREMULTIPLIED && c.a > 0.0)")
        lines.append("    {")
        lines.append("        c.rgb /= c.a;")
        lines.append("    }")
        lines.append("    return c;")
    else:
        lines.append("    return tex2D(S2D_Image, uv) * In.Tint;")
    lines.append("}")
    if fx.background:
        lines.append("")
        lines.append("/* Whatever Fusion has already drawn behind the object. Sample it with")
        lines.append("   In.bgCoord, not In.texCoord - they are different mappings. */")
        lines.append("float4 fusionBg(float2 uv)")
        lines.append("{")
        if dx11:
            lines.append("    return S2D_Background.Sample(S2D_BackgroundSampler, uv);")
        else:
            lines.append("    return tex2D(S2D_Background, uv);")
        lines.append("}")
    for p in fx.image_params:
        accessor = "fusionImage_" + p.var.lstrip("_")
        lines.append("")
        lines.append("/* The '%s' image parameter. */" % p.name)
        lines.append("float4 %s(float2 uv)" % accessor)
        lines.append("{")
        if dx11:
            lines.append("    return %s.Sample(%sSampler, uv);" % (p.var, p.var))
        else:
            lines.append("    return tex2D(%s, uv);" % p.var)
        lines.append("}")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# reference documentation
# ---------------------------------------------------------------------------
def colorref_to_rgb(value):
    try:
        n = int(value, 0)
    except (TypeError, ValueError):
        return None
    return (n & 0xFF, (n >> 8) & 0xFF, (n >> 16) & 0xFF)


def emit_reference(effects):
    by_category = {}
    for fx in effects:
        by_category.setdefault(fx.category, []).append(fx)

    out = ["# Effect reference", ""]
    out.append("Generated by `tools/build_shaders.py` - do not edit by hand.")
    out.append("")
    out.append("%d effects. Parameter names are the ones Fusion shows in the object's"
               % len(effects))
    out.append("effect properties and in the **Set effect parameter** action.")
    out.append("")
    out.append("| Effect | Category | Uses background | DX9 target |")
    out.append("| --- | --- | --- | --- |")
    for fx in sorted(effects, key=lambda e: (e.category, e.name)):
        out.append("| [%s](#%s) | %s | %s | `%s` |" % (
            fx.name, anchor(fx.name), fx.category,
            "yes" if fx.background else "no", fx.target))
    out.append("")

    for category in sorted(by_category):
        out.append("## %s" % category)
        out.append("")
        for fx in sorted(by_category[category], key=lambda e: e.name):
            out.append("### %s" % fx.name)
            out.append("")
            out.append("`%s/%s/%s.*`" % (PACK_NAME, fx.category, fx.base))
            out.append("")
            if fx.description:
                out.append(fx.description)
                out.append("")
            if fx.background:
                out.append("Needs the background texture: put the object on a layer with"
                           " something behind it, or the effect has nothing to read.")
                out.append("")
            if fx.params:
                out.append("| Parameter | Type | Default | Range | What it does |")
                out.append("| --- | --- | --- | --- | --- |")
                for p in fx.params:
                    rng = ""
                    if p.min is not None or p.max is not None:
                        rng = "%s .. %s" % (p.min if p.min is not None else "-",
                                            p.max if p.max is not None else "-")
                    default = p.default
                    if p.is_color:
                        rgb = colorref_to_rgb(p.default)
                        if rgb:
                            default = "%s (RGB %d, %d, %d)" % ((p.default,) + rgb)
                    if p.is_image:
                        default = "-"
                    out.append("| %s | %s | %s | %s | %s |" % (
                        p.name, p.kind, default, rng, p.desc))
                out.append("")
            else:
                out.append("No parameters.")
                out.append("")
            if fx.usage:
                out.append("**How to drive it:** %s" % fx.usage)
                out.append("")
            for note in fx.notes:
                out.append("> %s" % note)
                out.append("")
    return "\n".join(out) + "\n"


def anchor(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


# ---------------------------------------------------------------------------
# glslangValidator check
# ---------------------------------------------------------------------------
def dx9_to_checkable(text):
    """Rewrite a DX9 .fx into something a DX11 front end will parse.

    Only the wrapper differs between the two files, so compiling this catches
    typos in the shared body; it does not check ps_2_0 instruction limits.
    """
    text = re.sub(
        r"sampler2D\s+(\w+)\s*:\s*register\(s(\d+)\)(\s*=\s*sampler_state\s*\{[^}]*\})?;",
        lambda m: "Texture2D<float4> %s : register(t%s);\nSamplerState %sSampler : register(s%s);"
                  % (m.group(1), m.group(2), m.group(1), m.group(2)),
        text,
    )
    text = re.sub(r"tex2D\(\s*(\w+)\s*,", lambda m: "%s.Sample(%sSampler," % (m.group(1), m.group(1)), text)
    text = re.sub(r"technique\s+tech_main\s*\{.*", "", text, flags=re.S)
    text = text.replace(": COLOR0\n{\n    return fusion_main(In);", ": SV_TARGET\n{\n    return fusion_main(In);")
    return text


def run_check(built):
    import shutil
    import subprocess
    import tempfile

    tool = shutil.which("glslangValidator")
    if not tool:
        print("glslangValidator not found - skipping the compile check.")
        print("Install it with:  apt-get install glslang-tools")
        return 0

    failures = 0
    tmp = tempfile.mkdtemp(prefix="fusionfx")
    for fx, paths in built:
        jobs = [("DX11 ps_main", paths["hlsl"], "ps_main", None),
                ("DX11 ps_main_pm", paths["hlsl"], "ps_main_pm", None),
                ("DX9", paths["fx"], "ps_main", dx9_to_checkable)]
        for label, path, entry, transform in jobs:
            source = open(path).read()
            if transform:
                source = transform(source)
                path = os.path.join(tmp, fx.base + ".check.hlsl")
                open(path, "w").write(source)
            result = subprocess.run(
                [tool, "-D", "-V", "-S", "frag", "-e", entry, "-o", os.devnull, path],
                capture_output=True, text=True)
            if result.returncode != 0:
                failures += 1
                print("FAIL %s [%s]" % (fx.name, label))
                print(result.stdout.strip() or result.stderr.strip())
    if failures:
        print("\n%d compile failure(s)." % failures)
    else:
        print("All %d effects compile (%d shader builds)." % (len(built), len(built) * 3))
    return 1 if failures else 0


# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true",
                    help="compile-test the generated shaders with glslangValidator")
    args = ap.parse_args()

    if not os.path.isdir(SRC_DIR):
        raise SystemExit("no sources in %s" % SRC_DIR)

    sources = sorted(
        os.path.join(dirpath, f)
        for dirpath, _, files in os.walk(SRC_DIR)
        for f in files if f.endswith(".fxs")
    )
    if not sources:
        raise SystemExit("no .fxs sources found in %s" % SRC_DIR)

    effects = [parse_source(p) for p in sources]

    seen = {}
    for fx in effects:
        if fx.name in seen:
            raise SystemExit("two effects are both called %r (%s, %s)"
                             % (fx.name, seen[fx.name], fx.path))
        seen[fx.name] = fx.path

    built = []
    for fx in effects:
        out_dir = os.path.join(DIST_DIR, PACK_NAME, fx.category)
        os.makedirs(out_dir, exist_ok=True)
        paths = {
            "xml": os.path.join(out_dir, fx.base + ".xml"),
            "fx": os.path.join(out_dir, fx.base + ".fx"),
            "hlsl": os.path.join(out_dir, fx.base + ".hlsl"),
        }
        open(paths["xml"], "w").write(emit_xml(fx))
        open(paths["fx"], "w").write(emit_fx(fx))
        open(paths["hlsl"], "w").write(emit_hlsl(fx))
        built.append((fx, paths))

    open(REFERENCE, "w").write(emit_reference(effects))

    print("Built %d effects into %s" % (len(effects), os.path.join(DIST_DIR, PACK_NAME)))
    print("Wrote %s" % os.path.relpath(REFERENCE, ROOT))

    if args.check:
        return run_check(built)
    return 0


if __name__ == "__main__":
    sys.exit(main())
