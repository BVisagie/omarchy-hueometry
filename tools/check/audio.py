#!/usr/bin/env python3
"""Checks the shipped sounds: every file the game plays is there, in the
format its player needs, of a sensible length, credited in ASSETS.md, and
mixed as tools/audio/synth.py intends: each effect at its loudness target
with a click-free start, loops at theirs, nothing over -1 dBTP.
(numpy and ffmpeg output can differ between machines, so this checks the
files rather than regenerating and comparing them.)"""
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/audio"))
import loudness  # noqa: E402
from synth import EFFECT_LUFS, LOOP_LUFS, TRUE_PEAK_MAX  # noqa: E402
SOUNDS = ROOT / "qml/Hueometry/sounds"
EFFECTS = {**{f"lift-{i}": (0.2, 1.5) for i in (1, 2, 3)}, **{f"place-{i}": (0.4, 2.5) for i in range(6)},
           "drop": (0.2, 1.5), "refuse": (0.2, 1.5), "undo": (0.2, 1.5), "restart": (0.4, 2.5),
           "hint": (0.6, 3.0), "select": (0.1, 1.0), "solved": (2.0, 7.0)}
LOOPS = ["ambience-forest", "ambience-river", "ambience-temple", "music-menu", "music-play"]


def samples(p):
    if p.suffix == ".wav":
        with wave.open(str(p)) as w:
            return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(p), "-f", "f32le", "-ac", "1", "-ar", "44100", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def mix(bad):
    for name, target in EFFECT_LUFS.items():
        p = SOUNDS / f"{name}.wav"
        if not p.exists():
            continue
        x = samples(p)
        level = loudness.momentary_max(x)
        if abs(level - target) > 0.5:
            bad.append(f"{p.name}: {level:.1f} LUFS, expected {target:.1f}")
        if abs(x[0]) > 2 / 32768:
            bad.append(f"{p.name}: starts on a non-zero sample (a click)")
    for name, target in LOOP_LUFS.items():
        p = SOUNDS / f"{name}.ogg"
        if not p.exists():
            continue
        level = loudness.integrated(samples(p))
        if abs(level - target) > 1.0:
            bad.append(f"{p.name}: {level:.1f} LUFS, expected {target:.1f}")
    for p in sorted(SOUNDS.iterdir()):
        peak = loudness.true_peak(samples(p))
        if peak > TRUE_PEAK_MAX + 0.1:
            bad.append(f"{p.name}: true peak {peak:.1f} dBTP, over {TRUE_PEAK_MAX}")


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
    mix(bad)
    for b in bad:
        print(b, file=sys.stderr)
    if not bad:
        print(f"sounds: {len(EFFECTS)} effects and {len(LOOPS)} loops present, credited and at their levels")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
