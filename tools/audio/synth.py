#!/usr/bin/env python3
"""Synthesises every Hueometry sound: effects, jungle ambience and music.

Run it (bin/audio) after changing it, and commit what it writes to
qml/Hueometry/sounds/. Everything is made here from sine waves and noise with
fixed random seeds, so the sounds are this project's own work (CC BY-SA 4.0,
see ASSETS.md) and the script regenerates them.

Effects are 16-bit WAV (Qt's SoundEffect plays only WAV); ambience and music
are Ogg Vorbis loops, encoded with ffmpeg.

Instruments: a modal marimba and kalimba (decaying inharmonic partials with a
mallet click), an FM bell, a soft pad of detuned harmonics, a shaker, a log
drum, and a convolution reverb from a synthetic decaying-noise impulse.
"""

import os
import subprocess
import sys
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "qml", "Hueometry", "sounds")

# C major pentatonic from C5: the six orb colours each have a note.
NOTE = {"C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.00, "A4": 440.00,
        "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.00,
        "C6": 1046.50, "D6": 1174.66, "E6": 1318.51, "G3": 196.00, "A3": 220.00,
        "C3": 130.81, "E3": 164.81, "D3": 146.83, "F4": 349.23, "B4": 493.88}
ORB_NOTES = ["C5", "D5", "E5", "G5", "A5", "C6"]


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env_ad(n, attack, decay_rate):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t * decay_rate)


# Instruments
# -----------

def marimba(f, dur=1.2, bright=1.0, rng=None):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for ratio, amp, decay in [(1.0, 1.0, 5.5), (3.99, 0.32 * bright, 13.0), (10.65, 0.10 * bright, 28.0)]:
        out += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * decay)
    out *= np.clip(t / 0.002, 0, 1)
    # the mallet: a short click of filtered noise
    rng = rng or np.random.default_rng(1)
    click = rng.standard_normal(len(t)) * np.exp(-t * 400) * 0.25
    out += lowpass(click, 4000)
    return out


def kalimba(f, dur=1.6, rng=None):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for ratio, amp, decay in [(1.0, 1.0, 3.2), (5.4, 0.18, 9.0), (8.9, 0.07, 16.0)]:
        out += amp * np.sin(2 * np.pi * f * ratio * t + 0.3 * np.sin(2 * np.pi * 5 * t)) * np.exp(-t * decay)
    out *= np.clip(t / 0.003, 0, 1)
    return out


def bell(f, dur=1.5, index=2.5):
    t = t_axis(dur)
    mod = index * np.exp(-t * 4) * np.sin(2 * np.pi * f * 3.5 * t)
    return np.sin(2 * np.pi * f * t + mod) * np.exp(-t * 3.0) * np.clip(t / 0.002, 0, 1)


def pad(freqs, dur, rng, attack=1.2, release=1.5):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f in freqs:
        for detune in (-0.004, 0.0, 0.0045):
            ff = f * (1 + detune)
            phase = rng.uniform(0, 2 * np.pi)
            for k in range(1, 7):  # a soft saw: few harmonics, falling fast
                out += (0.55 ** (k - 1)) / k * np.sin(2 * np.pi * ff * k * t + phase * k)
    out /= max(1, len(freqs) * 3)
    env = np.minimum(np.clip(t / attack, 0, 1), np.clip((dur - t) / release, 0, 1))
    return out * env


def shaker(dur, rng):
    t = t_axis(dur)
    noise = bandpass(rng.standard_normal(len(t)), 5000, 11000)
    return noise * np.exp(-t * 35) * np.clip(t / 0.004, 0, 1)


def log_drum(f, dur=0.6):
    t = t_axis(dur)
    sweep = f * (1 + 0.35 * np.exp(-t * 30))
    phase = 2 * np.pi * np.cumsum(sweep) / SR
    return np.sin(phase) * np.exp(-t * 7) * np.clip(t / 0.002, 0, 1)


def whoosh(dur, rng, f_from, f_to):
    n = int(SR * dur)
    noise = rng.standard_normal(n)
    out = np.zeros(n)
    steps = 8
    for s in range(steps):
        lo = s * n // steps
        hi = (s + 1) * n // steps
        f = f_from + (f_to - f_from) * (s + 0.5) / steps
        seg = bandpass(noise, f * 0.6, f * 1.6)[lo:hi]
        out[lo:hi] = seg
    t = np.arange(n) / SR
    return out * np.sin(np.pi * t / dur) ** 2


# Filters (in the frequency domain: whole-signal and fast)
# ---------------------------------------------------------

def spectrum_filter(x, gain):
    n = len(x)
    size = 1 << (n - 1).bit_length()
    X = np.fft.rfft(x, size)
    freqs = np.fft.rfftfreq(size, 1 / SR)
    return np.fft.irfft(X * gain(freqs), size)[:n]


# fourth-order Butterworth magnitudes: 24 dB per octave
def lowpass(x, cutoff):
    return spectrum_filter(x, lambda f: 1 / np.sqrt(1 + (f / cutoff) ** 8))


def highpass(x, cutoff):
    return spectrum_filter(x, lambda f: 1 / np.sqrt(1 + (cutoff / np.maximum(f, 1)) ** 8))


def bandpass(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def pink(n, rng):
    x = rng.standard_normal(n)
    return spectrum_filter(x, lambda f: 1 / np.sqrt(np.maximum(f, 20)))


def reverb(x, seconds=1.8, wet=0.28, rng=None, bright=6000):
    rng = rng or np.random.default_rng(7)
    m = int(SR * seconds)
    t = np.arange(m) / SR
    ir = lowpass(rng.standard_normal(m), bright) * np.exp(-t * 6.9 / seconds)
    ir[0] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    n = len(x) + m
    size = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]
    dry = np.concatenate([x, np.zeros(m)])
    return dry * (1 - wet) + y * wet


def fit(x, n):
    """x cut or padded with silence to n samples."""
    return x[:n] if len(x) >= n else np.concatenate([x, np.zeros(n - len(x))])


# Output
# ------

def peak_normalise(x, peak_db=-3.0):
    p = np.max(np.abs(x))
    return x if p == 0 else x * (10 ** (peak_db / 20) / p)


def rms_normalise(x, rms_db):
    r = np.sqrt(np.mean(x ** 2))
    y = x * (10 ** (rms_db / 20) / max(r, 1e-9))
    p = np.max(np.abs(y))
    return y if p < 0.95 else y * (0.95 / p)


def fade_tail(x, ms=30):
    n = min(len(x), int(SR * ms / 1000))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def write_wav(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(path, x, quality=3):
    tmp = path + ".tmp.wav"
    write_wav(tmp, x)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis",
                    "-q:a", str(quality), path], check=True)
    os.remove(tmp)


def seamless(x, crossfade):
    """A loop of len(x) - crossfade samples: the tail fades into the head."""
    n = int(SR * crossfade)
    body = x[:-n].copy()
    ramp = np.linspace(0, 1, n)
    body[:n] = body[:n] * ramp + x[-n:] * (1 - ramp)
    return body


# Effects
# -------

def effects():
    rng = np.random.default_rng(11)
    out = {}
    for i in range(3):  # lift: a light wooden tick that rises
        f = NOTE["G5"] * (1 + 0.03 * i)
        tone = marimba(f, 0.35, 0.6, rng)
        air = fit(whoosh(0.16, rng, 1500, 3800), len(tone))
        out[f"lift-{i + 1}"] = fade_tail(reverb(0.7 * tone + 0.25 * air, 0.5, 0.15, rng))
    for c, name in enumerate(ORB_NOTES):  # place: the colour's note on stone
        tone = marimba(NOTE[name], 0.9, 1.0, rng)
        knock = log_drum(NOTE[name] / 4, 0.25)
        out[f"place-{c}"] = fade_tail(reverb(0.8 * tone + 0.25 * fit(knock, len(tone)), 0.9, 0.2, rng))
    out["drop"] = fade_tail(reverb(marimba(NOTE["D5"], 0.4, 0.5, rng), 0.5, 0.15, rng))
    # refuse: a soft, low, muffled tok: kind, never a buzzer
    tok = lowpass(marimba(NOTE["A3"], 0.35, 0.3, rng), 900)
    out["refuse"] = fade_tail(reverb(0.9 * tok, 0.4, 0.12, rng))
    # undo: a quick swish backwards
    swish = whoosh(0.22, rng, 3500, 900)
    tick = fit(np.concatenate([np.zeros(int(SR * 0.12)), marimba(NOTE["E5"], 0.25, 0.4, rng)]), len(swish))
    out["undo"] = fade_tail(reverb(0.6 * swish + 0.3 * tick, 0.5, 0.15, rng))
    # restart: three notes stepping down
    seq = np.zeros(int(SR * 0.9))
    for k, name in enumerate(["G5", "E5", "C5"]):
        note = kalimba(NOTE[name], 0.5, rng)
        at = int(SR * 0.09 * k)
        seq[at:at + len(note)] += note[: len(seq) - at]
    out["restart"] = fade_tail(reverb(seq, 0.9, 0.2, rng))
    # hint: a little sparkle of bells
    spark = np.zeros(int(SR * 1.4))
    for k, name in enumerate(["E6", "G5", "C6", "D6"]):
        b = bell(NOTE[name], 0.9) * (0.6 - 0.08 * k)
        at = int(SR * 0.07 * k)
        spark[at:at + len(b)] += b[: len(spark) - at]
    out["hint"] = fade_tail(reverb(spark, 1.4, 0.3, rng))
    # select: a soft wooden click for menus
    out["select"] = fade_tail(reverb(0.7 * marimba(NOTE["C6"], 0.18, 0.4, rng), 0.3, 0.1, rng))
    # solved: a rising marimba arpeggio, shaker and a warm chord
    dur = 3.2
    fan = np.zeros(int(SR * dur))
    for k, name in enumerate(["C5", "E5", "G5", "C6", "E6"]):
        m = marimba(NOTE[name], 1.6, 1.0, rng)
        at = int(SR * 0.11 * k)
        fan[at:at + len(m)] += m[: len(fan) - at] * (0.75 + 0.05 * k)
    for k in range(6):
        s = shaker(0.2, rng) * 0.25
        at = int(SR * (0.05 + 0.11 * k))
        fan[at:at + len(s)] += s[: len(fan) - at]
    chord = pad([NOTE["C4"], NOTE["E4"], NOTE["G4"], NOTE["C5"]], dur, rng, attack=0.4, release=1.6) * 0.5
    fan += fit(chord, len(fan))
    out["solved"] = fade_tail(reverb(fan, 2.2, 0.32, rng), 200)
    for k in list(out):
        out[k] = peak_normalise(out[k], -4.0 if k != "solved" else -2.5)
    out["refuse"] *= 0.55
    out["select"] *= 0.5
    return out


# Ambience
# --------

def bird(rng, kind):
    if kind == 0:  # a two-note whistle
        dur = 0.45
        t = t_axis(dur)
        f = np.where(t < 0.2, 2600, 2100) * (1 + 0.02 * np.sin(2 * np.pi * 30 * t))
    elif kind == 1:  # a quick rising trill
        dur = 0.6
        t = t_axis(dur)
        f = 3000 + 1500 * t / dur + 300 * np.sin(2 * np.pi * 22 * t)
    else:  # a falling chirp
        dur = 0.25
        t = t_axis(dur)
        f = 4800 - 2400 * t / dur
    phase = 2 * np.pi * np.cumsum(f) / SR
    env = np.sin(np.pi * t / dur) ** 1.5
    if kind == 1:
        env *= 0.6 + 0.4 * (np.sin(2 * np.pi * 22 * t) > 0)
    return np.sin(phase) * env


def scatter(base, rng, make, rate, gain, lo=0.0):
    n = len(base)
    t = 0.0
    total = n / SR
    while True:
        t += rng.exponential(1 / rate)
        if t > total - 1.5:
            break
        s = make(rng) * gain * rng.uniform(0.4, 1.0)
        at = int(t * SR)
        base[at:at + len(s)] += s[: n - at]
    return base


def ambience(name, seconds=42):
    rng = np.random.default_rng({"forest": 21, "river": 22, "temple": 23}[name])
    n = int(SR * (seconds + 3))
    t = np.arange(n) / SR
    # wind in the leaves: pink noise, banded, swelling slowly
    wind = bandpass(pink(n, rng), 150, 900)
    wind /= np.std(wind)
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / 11.0 + 1.0) * np.sin(2 * np.pi * t / 7.3)
    mix = 0.22 * wind * swell
    if name in ("forest", "river"):
        # insects: a faint high shimmer, pulsing
        ins = bandpass(rng.standard_normal(n), 4200, 5600)
        ins /= np.std(ins)
        mix += 0.03 * ins * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * t)) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 9))
        birds = scatter(np.zeros(n), rng, lambda r: bird(r, int(r.integers(0, 3))), 0.5, 0.6)
        mix += reverb(birds, 1.2, 0.35, rng)[:n]
    if name == "river":
        water = bandpass(pink(n, rng), 120, 2200)
        water /= np.std(water)
        mix += 0.35 * water * (0.85 + 0.15 * np.sin(2 * np.pi * t / 5.1))

        def bubble(r):
            d = r.uniform(0.03, 0.08)
            tt = t_axis(d)
            f = r.uniform(600, 1400) * (1 + 2.5 * tt / d)
            return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / d)
        mix += scatter(np.zeros(n), rng, bubble, 6.0, 0.05)
    if name == "temple":
        # a deep hush, a low drone and slow water drips in stone
        drone = fit(pad([NOTE["C3"], NOTE["G3"]], seconds + 3, rng, attack=4, release=4) * 0.35, n)
        mix = 0.5 * mix + drone

        def drip(r):
            return bell(r.uniform(1400, 2200), 0.5, 1.2) * 0.6
        mix += reverb(scatter(np.zeros(n), rng, drip, 0.25, 0.25), 3.0, 0.6, rng)[:n]
    return rms_normalise(seamless(mix, 3), -27)


# Music
# -----

def music(name):
    rng = np.random.default_rng({"menu": 31, "play": 32}[name])
    bpm = 84 if name == "menu" else 72
    beat = 60 / bpm
    bars = 16
    total = bars * 4 * beat
    n = int(SR * (total + 4))
    out = np.zeros(n)
    # chords: I - vi - IV - V in C, gently
    chords = [["C4", "E4", "G4"], ["A3", "C4", "E4"], ["F4", "A4", "C5"], ["G3", "B4", "D4"]]
    for bar in range(bars):
        chord = chords[bar % 4]
        p = pad([NOTE[c] for c in chord], 4 * beat + 1.5, rng, attack=0.8, release=1.2) * 0.32
        at = int(SR * bar * 4 * beat)
        out[at:at + len(p)] += p[: n - at]
        # a log drum on beat 1, softly
        d = log_drum(NOTE["C3"] if bar % 2 == 0 else NOTE["G3"] / 2, 0.6) * 0.25
        out[at:at + len(d)] += d[: n - at]
    # a pentatonic melody, mostly stepwise, on kalimba (menu) or marimba (play)
    scale = ["C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6"]
    step = 0.5 if name == "menu" else 1.0
    pos = 2
    k = 0.0
    while k < bars * 4 - 1:
        if rng.random() < (0.72 if name == "menu" else 0.5):
            note = NOTE[scale[pos]]
            inst = kalimba(note, 1.4, rng) if name == "menu" else marimba(note, 1.4, 0.7, rng)
            at = int(SR * k * beat)
            out[at:at + len(inst)] += inst[: n - at] * (0.42 if name == "menu" else 0.36)
        pos = int(np.clip(pos + rng.choice([-2, -1, -1, 0, 1, 1, 2]), 0, len(scale) - 1))
        k += step * (2 if rng.random() < 0.25 else 1)
    if name == "menu":
        for b in range(bars * 4):
            if b % 2 == 1:
                s = shaker(0.15, rng) * 0.04
                at = int(SR * b * beat)
                out[at:at + len(s)] += s[: n - at]
    out = reverb(out, 2.4, 0.3, rng)[:n]
    return rms_normalise(seamless(out[: int(SR * (total + 2))], 2), -21)


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for name, x in effects().items():
        path = os.path.join(OUT, f"{name}.wav")
        write_wav(path, x)
        made.append(path)
    for name in ("forest", "river", "temple"):
        path = os.path.join(OUT, f"ambience-{name}.ogg")
        write_ogg(path, ambience(name), 2)
        made.append(path)
    for name in ("menu", "play"):
        path = os.path.join(OUT, f"music-{name}.ogg")
        write_ogg(path, music(name), 3)
        made.append(path)
    for p in made:
        print(os.path.relpath(p), os.path.getsize(p))


if __name__ == "__main__":
    sys.exit(main())
