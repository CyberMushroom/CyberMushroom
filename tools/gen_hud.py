#!/usr/bin/env python3
"""Generate Super Paper Mario styled HUD assets on the Game Boy DMG palette.

Every PNG is emitted at 1x for a 160x144 screen, with alpha, ready to import
into Clickteam Fusion. Stdlib only - no Pillow.
"""

import os
import struct
import zlib

OUT_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, "assets", "hud")
)

SCREEN_W, SCREEN_H = 160, 144

EMPTY = "."
PALETTE = {
    "0": (155, 188, 15, 255),  # lightest
    "1": (139, 172, 15, 255),  # light
    "2": (48, 98, 48, 255),    # dark
    "3": (15, 56, 15, 255),    # darkest
    EMPTY: (0, 0, 0, 0),
}

CARD_FILL = "0"
CARD_EDGE = "3"
CARD_BEVEL = "2"
INK = "3"
ICON_FILL = "2"
ICON_GLINT = "0"

# Card geometry: x, y, width, height. Rendered PNGs are 1px wider and taller
# than the body to hold the drop shadow.
HP_CARD = (3, 3, 30, 16)
COIN_CARD = (38, 3, 36, 16)
SCORE_CARD = (115, 3, 42, 16)
PIXL_SLOT = (3, 124, 18, 16)

ICON_AT = (4, 3)
HP_DIGITS_AT = (15, 4)
COIN_DIGITS_AT = (15, 4)
SCORE_DIGITS_AT = (3, 4)

# 1px strokes leave no room inside the counters for a drop shadow, so the
# glyphs are solid ink and lean on the light card face for contrast.
DIGIT_W, DIGIT_H, DIGIT_ADVANCE = 5, 7, 6

DIGIT_ART = {
    "0": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
    "1": ["..X..", ".XX..", "..X..", "..X..", "..X..", "..X..", ".XXX."],
    "2": [".XXX.", "X...X", "....X", "...X.", "..X..", ".X...", "XXXXX"],
    "3": ["XXXX.", "....X", "....X", ".XXX.", "....X", "....X", "XXXX."],
    "4": ["...X.", "..XX.", ".X.X.", "X..X.", "XXXXX", "...X.", "...X."],
    "5": ["XXXXX", "X....", "XXXX.", "....X", "....X", "X...X", ".XXX."],
    "6": ["..XX.", ".X...", "X....", "XXXX.", "X...X", "X...X", ".XXX."],
    "7": ["XXXXX", "....X", "...X.", "..X..", "..X..", "..X..", "..X.."],
    "8": [".XXX.", "X...X", "X...X", ".XXX.", "X...X", "X...X", ".XXX."],
    "9": [".XXX.", "X...X", "X...X", ".XXXX", "....X", "...X.", ".XX.."],
}

HEART_ART = [
    ".XX.XX.",
    "XXXXXXX",
    "XXXXXXX",
    "XXXXXXX",
    ".XXXXX.",
    "..XXX..",
    "...X...",
]

COIN_ART = [
    "..XXX..",
    ".XXXXX.",
    "XXXXXXX",
    "XXXXXXX",
    "XXXXXXX",
    ".XXXXX.",
    "..XXX..",
]

PIXL_ART = [
    "...X...",
    "..XXX..",
    ".XXXXX.",
    "XXXXXXX",
    ".XXXXX.",
    "..XXX..",
    "...X...",
]


def write_png(path, rows):
    """Write 8-bit RGBA rows (list of lists of (r,g,b,a)) as a PNG."""
    height = len(rows)
    width = len(rows[0])
    raw = bytearray()
    for row in rows:
        raw.append(0)  # no per-scanline filtering
        for r, g, b, a in row:
            raw += bytes((r, g, b, a))

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as fh:
        fh.write(png)


class Canvas:
    def __init__(self, w, h, fill=EMPTY):
        self.w = w
        self.h = h
        self.px = [[fill] * w for _ in range(h)]

    def set(self, x, y, shade):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = shade

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return EMPTY

    def blit_art(self, art, ox, oy, shade):
        for y, line in enumerate(art):
            for x, ch in enumerate(line):
                if ch != EMPTY:
                    self.set(ox + x, oy + y, shade)

    def blit(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                shade = other.px[y][x]
                if shade != EMPTY:
                    self.set(ox + x, oy + y, shade)

    def scaled(self, factor):
        out = Canvas(self.w * factor, self.h * factor)
        for y in range(self.h):
            for x in range(self.w):
                shade = self.px[y][x]
                for dy in range(factor):
                    for dx in range(factor):
                        out.set(x * factor + dx, y * factor + dy, shade)
        return out

    def save(self, name):
        rows = [[PALETTE[shade] for shade in row] for row in self.px]
        write_png(os.path.join(OUT_DIR, name), rows)
        return name


def add_outline(canvas, shade=CARD_EDGE):
    """Surround every filled pixel with an 8-neighbour outline."""
    filled = [
        (x, y)
        for y in range(canvas.h)
        for x in range(canvas.w)
        if canvas.px[y][x] != EMPTY
    ]
    for x, y in filled:
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if canvas.get(x + dx, y + dy) == EMPTY:
                    canvas.set(x + dx, y + dy, shade)


def in_round_rect(x, y, w, h, r):
    if not (0 <= x < w and 0 <= y < h):
        return False
    if r <= 0:
        return True
    dx = min(x, w - 1 - x)
    dy = min(y, h - 1 - y)
    if dx < r and dy < r:
        return (r - dx) + (r - dy) <= r
    return True


def make_card(w, h, radius=2, shadow=True):
    """A floating paper card: dark outline, light face, bevel, drop shadow."""
    canvas = Canvas(w + 1 if shadow else w, h + 1 if shadow else h)
    if shadow:
        for y in range(h):
            for x in range(w):
                if in_round_rect(x, y, w, h, radius):
                    canvas.set(x + 1, y + 1, CARD_BEVEL)

    body = {}
    for y in range(h):
        for x in range(w):
            if not in_round_rect(x, y, w, h, radius):
                continue
            neighbours_inside = all(
                in_round_rect(x + dx, y + dy, w, h, radius)
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
            )
            body[(x, y)] = CARD_FILL if neighbours_inside else CARD_EDGE

    # Paper thickness: shade the face where it meets the bottom/right edge.
    for (x, y), shade in list(body.items()):
        if shade != CARD_FILL:
            continue
        if body.get((x, y + 1)) == CARD_EDGE or body.get((x + 1, y)) == CARD_EDGE:
            body[(x, y)] = CARD_BEVEL

    for (x, y), shade in body.items():
        canvas.set(x, y, shade)
    return canvas


def make_icon(art, glints=()):
    canvas = Canvas(len(art[0]) + 2, len(art) + 2)
    canvas.blit_art(art, 1, 1, ICON_FILL)
    for x, y in glints:
        canvas.set(x, y, ICON_GLINT)
    add_outline(canvas)
    return canvas


def make_digit(ch):
    # Cells carry their own trailing spacer column: Fusion's Counter object
    # butts digit images together with no gap of its own.
    canvas = Canvas(DIGIT_ADVANCE, DIGIT_H)
    canvas.blit_art(DIGIT_ART[ch], 0, 0, INK)
    return canvas


def blit_number(canvas, text, x, y):
    for i, ch in enumerate(text):
        canvas.blit(make_digit(ch), x + i * DIGIT_ADVANCE, y)


def make_mockup_background():
    canvas = Canvas(SCREEN_W, SCREEN_H)
    horizon = 96
    for y in range(SCREEN_H):
        for x in range(SCREEN_W):
            if y < horizon:
                canvas.set(x, y, "0" if (x + y) % 2 == 0 else "1")
            elif y == horizon:
                canvas.set(x, y, "3")
            else:
                canvas.set(x, y, "2" if (x + y) % 4 else "3")
    return canvas


def main():
    os.makedirs(os.path.join(OUT_DIR, "digits"), exist_ok=True)
    written = []

    # Specular glints only. A ring-shaped coin reads as another zero next to
    # the digits, so the coin stays a solid disc.
    heart = make_icon(HEART_ART, glints=((2, 2), (3, 2)))
    coin = make_icon(COIN_ART, glints=((3, 2), (2, 3)))
    pixl = make_icon(PIXL_ART, glints=((4, 2), (3, 3)))

    written.append(heart.save("icon_heart.png"))
    written.append(coin.save("icon_coin.png"))
    written.append(pixl.save("icon_pixl.png"))

    # Cards with their fixed icon baked in; digits stay separate so a Fusion
    # Counter object can be layered on top.
    hp_card = make_card(HP_CARD[2], HP_CARD[3])
    hp_card.blit(heart, *ICON_AT)
    written.append(hp_card.save("card_hp.png"))

    coin_card = make_card(COIN_CARD[2], COIN_CARD[3])
    coin_card.blit(coin, *ICON_AT)
    written.append(coin_card.save("card_coin.png"))

    written.append(make_card(SCORE_CARD[2], SCORE_CARD[3]).save("card_score.png"))
    written.append(make_card(PIXL_SLOT[2], PIXL_SLOT[3]).save("slot_pixl.png"))

    strip = Canvas(DIGIT_ADVANCE * 10, DIGIT_H)
    for i, ch in enumerate("0123456789"):
        glyph = make_digit(ch)
        strip.blit(glyph, i * DIGIT_ADVANCE, 0)
        written.append(glyph.save(os.path.join("digits", "digit_%s.png" % ch)))
    written.append(strip.save(os.path.join("digits", "font_digits_strip.png")))

    screen = make_mockup_background()
    for card, name, digits, anchor in (
        (hp_card, "hp", "10", HP_DIGITS_AT),
        (coin_card, "coin", "024", COIN_DIGITS_AT),
        (make_card(SCORE_CARD[2], SCORE_CARD[3]), "score", "012500", SCORE_DIGITS_AT),
    ):
        origin = {"hp": HP_CARD, "coin": COIN_CARD, "score": SCORE_CARD}[name]
        screen.blit(card, origin[0], origin[1])
        blit_number(screen, digits, origin[0] + anchor[0], origin[1] + anchor[1])

    slot = make_card(PIXL_SLOT[2], PIXL_SLOT[3])
    slot.blit(pixl, (PIXL_SLOT[2] - pixl.w) // 2, (PIXL_SLOT[3] - pixl.h) // 2)
    screen.blit(slot, PIXL_SLOT[0], PIXL_SLOT[1])

    written.append(screen.save("hud_mockup.png"))
    written.append(screen.scaled(4).save("hud_mockup_x4.png"))

    for name in written:
        print("wrote assets/hud/%s" % name)


if __name__ == "__main__":
    main()
