#!/usr/bin/env python3
"""Checks the shipped sounds: every file the game plays is there, in the
format its player needs, of a sensible length, and credited in ASSETS.md.
(numpy and ffmpeg output can differ between machines, so this checks the
files rather than regenerating and comparing them.)"""
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOUNDS = ROOT / "qml/Hueometry/sounds"
EFFECTS = {**{f"lift-{i}": (0.2, 1.5) for i in (1, 2, 3)}, **{f"place-{i}": (0.4, 2.5) for i in range(6)},
           "drop": (0.2, 1.5), "refuse": (0.2, 1.5), "undo": (0.2, 1.5), "restart": (0.4, 2.5),
           "hint": (0.6, 3.0), "select": (0.1, 1.0), "solved": (2.0, 7.0)}
LOOPS = ["ambience-forest", "ambience-river", "ambience-temple", "music-menu", "music-play"]


def main():
    bad = []
    credits = (ROOT / "ASSETS.md").read_text()
    for name, (lo, hi) in EFFECTS.items():
        p = SOUNDS / f"{name}.wav"
        try:
            with wave.open(str(p)) as w:
                if (w.getnchannels(), w.getsampwidth(), w.getframerate()) != (1, 2, 44100):
                    bad.append(f"{p.name}: not 16-bit mono 44.1 kHz")
                d = w.getnframes() / w.getframerate()
                if not lo <= d <= hi:
                    bad.append(f"{p.name}: {d:.2f} s, expected {lo}-{hi} s")
        except (FileNotFoundError, wave.Error) as e:
            bad.append(f"{p.name}: {e}")
    for name in LOOPS:
        p = SOUNDS / f"{name}.ogg"
        if not p.exists() or p.stat().st_size < 50_000 or p.read_bytes()[:4] != b"OggS":
            bad.append(f"{p.name}: missing or not an Ogg file")
    for p in SOUNDS.iterdir():
        if p.name not in credits:
            bad.append(f"{p.name}: not credited in ASSETS.md")
    for b in bad:
        print(b, file=sys.stderr)
    if not bad:
        print(f"sounds: {len(EFFECTS)} effects and {len(LOOPS)} loops present and credited")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
