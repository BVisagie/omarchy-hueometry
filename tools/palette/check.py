#!/usr/bin/env python3
"""Checks the six orb colours stay distinguishable.

For normal vision and for simulated protanopia, deuteranopia and tritanopia
(Machado, Oliveira and Fernandes 2009, severity 1.0), every pair of base
colours must differ by at least MIN_DELTA in CIELAB (CIE76). Symbols mode is
the backup for anyone this still fails.
"""
import itertools
import re
import sys
from pathlib import Path

MIN_DELTA = {"normal": 30.0, "protanopia": 12.0, "deuteranopia": 12.0, "tritanopia": 12.0}

MACHADO = {
    "normal": [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
    "protanopia": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
    "deuteranopia": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
    "tritanopia": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lab(rgb_lin):
    r, g, b = (min(1.0, max(0.0, v)) for v in rgb_lin)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 216 / 24389 else (24389 / 27 * t + 16) / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def main():
    src = (Path(__file__).parent / "../../qml/Hueometry/js/palette.mjs").read_text()
    names = re.findall(r'name: "(\w+)", base: "#([0-9A-Fa-f]{6})"', src)
    if len(names) != 6:
        sys.exit(f"palette check: expected 6 colours, found {len(names)}")
    worst = {}
    ok = True
    for vision, m in MACHADO.items():
        labs = {}
        for name, hexa in names:
            lin = [to_linear(int(hexa[i:i + 2], 16) / 255) for i in (0, 2, 4)]
            sim = [sum(m[r][c] * lin[c] for c in range(3)) for r in range(3)]
            labs[name] = lab(sim)
        pairs = [(a, b, sum((p - q) ** 2 for p, q in zip(labs[a], labs[b])) ** 0.5) for a, b in itertools.combinations(labs, 2)]
        a, b, d = min(pairs, key=lambda p: p[2])
        worst[vision] = (a, b, d)
        flag = "ok" if d >= MIN_DELTA[vision] else "TOO CLOSE"
        ok &= d >= MIN_DELTA[vision]
        print(f"{vision:13} closest pair {a}/{b}: {d:5.1f} (needs {MIN_DELTA[vision]:.0f}) {flag}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
