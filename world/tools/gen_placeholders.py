#!/usr/bin/env python3
"""Erzeugt die Platzhalter-Grafiken der Welt (nur Standardbibliothek).

Aufruf:  python3 world/tools/gen_placeholders.py
Ausgabe: res://world/art/placeholder/*.png  (Tile-Atlas + Objekt-Sprites, 16x16 Raster)
Deterministisch: gleiche Ausgabe bei jedem Lauf. Die Dateinamen sind stabil, damit
finale Grafik einfach unter gleichem Namen ersetzt werden kann.
"""
import os
import random
import struct
import zlib

OUT = os.path.join(os.path.dirname(__file__), "..", "art", "placeholder")


class Img:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[(0, 0, 0, 0)] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for xx in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.set(xx, yy, c)

    def blit(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                if other.px[y][x][3]:
                    self.set(ox + x, oy + y, other.px[y][x])

    def save(self, name):
        raw = b"".join(b"\x00" + b"".join(bytes(p) for p in row) for row in self.px)

        def chunk(t, d):
            c = struct.pack(">I", len(d)) + t + d
            return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(raw, 9))
        png += chunk(b"IEND", b"")
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, name + ".png"), "wb") as f:
            f.write(png)


def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))), max(0, min(255, int(c[2] * f))), c[3] if len(c) > 3 else 255)


# --- Tile-Atlas: Zeile = Terrain (Reihenfolge = Biome.Terrain), Spalte = Variante --------------
TERRAIN_COLORS = [
    (110, 168, 72),   # 0 MEADOW
    (84, 140, 62),    # 1 DECIDUOUS floor
    (62, 104, 66),    # 2 CONIFER floor
    (98, 128, 70),    # 3 FLOODPLAIN
    (128, 124, 118),  # 4 ROCK
    (206, 190, 138),  # 5 BANK
    (56, 110, 178),   # 6 WATER
    (120, 160, 190),  # 7 FORD
    (98, 82, 66),     # 8 CAVE_FLOOR
    (52, 46, 44),     # 9 CAVE_WALL
]


def make_atlas():
    rows = len(TERRAIN_COLORS) + 1
    img = Img(16 * 4, 16 * rows)
    rng = random.Random(7)
    for r, base in enumerate(TERRAIN_COLORS):
        for v in range(4):
            for y in range(16):
                for x in range(16):
                    f = 0.92 + rng.random() * 0.16
                    img.set(v * 16 + x, r * 16 + y, shade(base + (255,), f))
            # kleine Details je Terrain
            for _ in range(5):
                x, y = rng.randrange(16), rng.randrange(16)
                if r <= 3:
                    img.set(v * 16 + x, r * 16 + y, shade(base + (255,), 1.25))
                elif r == 4 or r == 9:
                    img.set(v * 16 + x, r * 16 + y, shade(base + (255,), 0.75))
                elif r in (6, 7):
                    img.set(v * 16 + x, r * 16 + y, shade(base + (255,), 1.3))
    # Schnee-Overlay (letzte Zeile): weiss, leicht transparent
    for v in range(4):
        for y in range(16):
            for x in range(16):
                a = 215 + int(rng.random() * 30)
                img.set(v * 16 + x, (rows - 1) * 16 + y, (240, 246, 255, a))
    img.save("tiles_atlas")


# --- Objekte -----------------------------------------------------------------------------
def make_tree_deciduous():
    img = Img(64, 80)
    trunk = (96, 66, 42, 255)
    img.rect(29, 52, 6, 20, trunk)
    img.rect(29, 52, 2, 20, shade(trunk, 0.8))
    green = (72, 138, 60, 255)
    for cx, cy, r in [(32, 30, 20), (20, 40, 14), (44, 40, 14), (32, 46, 14), (32, 18, 12)]:
        img.ellipse(cx, cy, r, r * 0.9, green)
    for cx, cy, r in [(26, 24, 6), (40, 34, 5), (24, 42, 4)]:
        img.ellipse(cx, cy, r, r, shade(green, 1.2))
    img.save("tree_deciduous")


def make_stump():
    img = Img(16, 16)
    img.ellipse(8, 11, 5, 3.5, (96, 66, 42, 255))
    img.ellipse(8, 10, 4, 2.5, (180, 140, 90, 255))
    img.save("stump")


def make_bush(name, body, extra=None, dots=None):
    img = Img(16, 16)
    for cx, cy, r in [(6, 10, 5), (11, 10, 5), (8, 7, 5)]:
        img.ellipse(cx, cy, r, r * 0.9, body)
    if dots:
        for x, y in [(5, 9), (9, 6), (11, 11), (7, 12), (12, 8)]:
            img.rect(x, y, 2, 2, dots)
    if extra:
        extra(img)
    img.save(name)


def make_sticks():
    img = Img(16, 16)
    c = (120, 84, 50, 255)
    for i in range(10):
        img.set(3 + i, 12 - i // 2, c)
        img.set(3 + i, 13 - i // 2, shade(c, 0.8))
    for i in range(8):
        img.set(4 + i, 5 + i // 2, shade(c, 1.15))
    img.set(11, 9, c)
    img.save("branch_bush")
    img2 = Img(16, 16)
    img2.set(7, 13, c)
    img2.set(8, 13, c)
    img2.save("branch_bush_empty")


def make_stone():
    img = Img(16, 16)
    img.ellipse(8, 11, 5.5, 4, (140, 138, 132, 255))
    img.ellipse(7, 10, 3, 2, (170, 168, 160, 255))
    img.save("stone_node")
    img2 = Img(16, 16)
    img2.set(7, 13, (120, 118, 112, 255))
    img2.set(8, 13, (120, 118, 112, 255))
    img2.save("stone_node_empty")


def make_flint():
    img = Img(16, 16)
    img.ellipse(8, 11, 6, 4.5, (110, 108, 104, 255))
    for (x, y) in [(5, 9), (8, 8), (10, 10), (7, 12)]:
        img.rect(x, y, 2, 2, (58, 62, 74, 255))
    img.set(6, 9, (150, 160, 180, 255))
    img.set(9, 8, (150, 160, 180, 255))
    img.save("flint_deposit")
    img2 = Img(16, 16)
    img2.ellipse(8, 12, 4, 2.5, (100, 98, 94, 255))
    img2.save("flint_deposit_empty")


def make_clay():
    img = Img(16, 16)
    img.ellipse(8, 11, 6.5, 4, (176, 112, 76, 255))
    img.ellipse(7, 10, 3.5, 2, (200, 136, 96, 255))
    img.save("clay_deposit")
    img2 = Img(16, 16)
    img2.ellipse(8, 12, 5, 2.5, (150, 100, 70, 255))
    img2.save("clay_deposit_empty")


def make_nettle():
    img = Img(16, 16)
    g = (52, 130, 52, 255)
    for x in (4, 7, 10, 12):
        for y in range(6 + x % 3, 14):
            img.set(x, y, g)
            if y % 3 == 0:
                img.set(x + 1, y, shade(g, 1.3))
    img.save("nettle")
    img2 = Img(16, 16)
    img2.rect(6, 12, 2, 2, (90, 110, 60, 255))
    img2.save("nettle_empty")


def make_berry():
    make_bush("berry_bush", (52, 112, 52, 255), dots=(190, 40, 60, 255))
    make_bush("berry_bush_bare", (84, 96, 56, 255))
    img = Img(16, 16)
    img.rect(6, 12, 3, 2, (90, 90, 60, 255))
    img.save("berry_bush_empty")


def make_mushroom():
    img = Img(16, 16)
    for x, y in [(5, 11), (10, 10), (8, 13)]:
        img.rect(x, y, 2, 3, (232, 224, 200, 255))
        img.ellipse(x + 1, y, 3, 2, (168, 96, 60, 255))
    img.save("mushroom")
    Img(16, 16).save("mushroom_empty")


def make_grain():
    img = Img(16, 16)
    stem = (170, 160, 80, 255)
    for x in (4, 6, 8, 10, 12):
        for y in range(5 + x % 3, 14):
            img.set(x, y, stem)
        img.rect(x - 1, 3 + x % 3, 2, 3, (214, 190, 90, 255))
    img.save("wild_grain")
    img2 = Img(16, 16)
    for x in (5, 8, 11):
        for y in range(11, 14):
            img2.set(x, y, (140, 150, 80, 255))
    img2.save("wild_grain_empty")


def make_malachite():
    img = Img(16, 16)
    img.ellipse(8, 11, 6, 4.5, (110, 108, 104, 255))
    for (x, y) in [(5, 9), (8, 8), (10, 10), (7, 11)]:
        img.rect(x, y, 2, 2, (40, 178, 130, 255))
    img.set(6, 9, (150, 240, 200, 255))
    img.save("malachite_deposit")
    img2 = Img(16, 16)
    img2.ellipse(8, 12, 4, 2.5, (100, 98, 94, 255))
    img2.save("malachite_deposit_empty")


def make_amber():
    img = Img(16, 16)
    img.ellipse(8, 11, 3, 2.5, (232, 160, 40, 255))
    img.set(7, 10, (255, 230, 150, 255))
    img.set(3, 6, (255, 255, 220, 255))
    img.set(12, 5, (255, 255, 220, 255))
    img.set(12, 12, (255, 255, 220, 255))
    img.save("amber_find")


def make_drink():
    img = Img(16, 16)
    img.ellipse(8, 11, 6, 3, (120, 170, 220, 160))
    img.save("drink_spot")


def make_field():
    for name, soil, stage in [
        ("field_untilled", (120, 104, 70, 255), 0),
        ("field_tilled", (86, 60, 40, 255), 0),
        ("field_stage1", (86, 60, 40, 255), 1),
        ("field_stage2", (86, 60, 40, 255), 2),
        ("field_ripe", (86, 60, 40, 255), 3),
    ]:
        img = Img(16, 16)
        img.rect(0, 0, 16, 16, soil)
        if name != "field_untilled":
            for y in (3, 8, 13):
                img.rect(0, y, 16, 1, shade(soil, 0.7))
        if stage:
            for x in (3, 8, 13):
                h = 2 + stage * 3
                for y in range(13 - h, 13):
                    img.set(x, y, (110, 170, 70, 255) if stage < 3 else (170, 160, 80, 255))
                if stage == 3:
                    img.rect(x - 1, 13 - h - 1, 2, 3, (214, 190, 90, 255))
        img.save(name)


def make_glitter():
    img = Img(4, 4)
    img.rect(1, 0, 2, 4, (255, 240, 170, 255))
    img.rect(0, 1, 4, 2, (255, 240, 170, 255))
    img.save("glitter")


if __name__ == "__main__":
    make_atlas()
    make_tree_deciduous()
    make_stump()
    make_sticks()
    make_stone()
    make_flint()
    make_clay()
    make_nettle()
    make_berry()
    make_mushroom()
    make_grain()
    make_malachite()
    make_amber()
    make_drink()
    make_field()
    make_glitter()
    print("Platzhalter geschrieben nach", os.path.normpath(OUT))
