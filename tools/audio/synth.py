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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loudness  # noqa: E402  (shared with tools/check/audio.py)

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
    """Writes 16-bit PCM: x is mono (n,) or stereo (2, n)."""
    x = np.asarray(x)
    channels = 1 if x.ndim == 1 else x.shape[0]
    frames = x if x.ndim == 1 else x.T.reshape(-1)
    data = (np.clip(frames, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
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

# How loud each effect is, as its loudest 400 ms (K-weighted LUFS): the mix
# lives here, not in SoundBank.qml, which plays every effect at full level.
# tools/check/audio.py checks the shipped files against this table.
EFFECT_LUFS = {
    "solved": -14.5, "hint": -16.0, "restart": -16.5,
    **{f"place-{c}": -17.5 for c in range(6)}, **{f"lift-{i}": -17.5 for i in (1, 2, 3)},
    "drop": -18.0, "undo": -18.5, "refuse": -19.5, "select": -25.5,
    **{f"complete-{c}": -21.0 for c in range(6)},
}
TRUE_PEAK_MAX = -1.0
# the loops' integrated loudness (LUFS)
LOOP_LUFS = {"music-menu": -21.0, "music-forest": -21.0, "music-river": -21.0, "music-temple": -21.0,
             "ambience-forest": -27.0, "ambience-river": -27.0, "ambience-temple": -27.0}


def fade_head(x, ms=0.5):
    """A raised-cosine fade-in so no effect starts on a click; short enough
    to keep a mallet's attack crisp."""
    n = max(1, int(SR * ms / 1000))
    x = x.copy()
    x[:n] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(n) / n)
    return x


def brighten(x, db=2.0, lo=5000.0, hi=9000.0):
    """A gentle shelf above about 7 kHz, so effects are not dull."""
    def gain(f):
        t = np.clip((f - lo) / (hi - lo), 0, 1)
        return 1 + (10 ** (db / 20) - 1) * (t * t * (3 - 2 * t))
    return spectrum_filter(x, gain)


def to_level(x, lufs):
    """Scales an effect to its loudest-moment target, never past the true
    peak limit (a quieter result then fails the check, loudly)."""
    x = x * 10 ** ((lufs - loudness.momentary_max(x)) / 20)
    over = loudness.true_peak(x) - (TRUE_PEAK_MAX - 0.1)  # headroom for 16-bit and Vorbis
    return x * 10 ** (-over / 20) if over > 0 else x


def to_integrated(x, lufs):
    """Scales a loop to its integrated loudness, never past the true peak
    limit."""
    x = x * 10 ** ((lufs - loudness.integrated(x)) / 20)
    over = loudness.true_peak(x) - (TRUE_PEAK_MAX - 0.1)  # headroom for 16-bit and Vorbis
    return x * 10 ** (-over / 20) if over > 0 else x


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
    # complete: a pillar full of one colour rings that colour's note softly
    # on a bell, the octave above following
    for c, name in enumerate(ORB_NOTES):
        ring = np.zeros(int(SR * 1.6))
        for k, mult in enumerate((1, 2)):
            b = bell(NOTE[name] * mult, 1.3, 1.4) * (0.7 if k == 0 else 0.4)
            at = int(SR * 0.08 * k)
            ring[at:at + len(b)] += b[: len(ring) - at]
        out[f"complete-{c}"] = fade_tail(reverb(ring, 1.2, 0.3, rng), 120)
    for k in list(out):
        out[k] = to_level(fade_head(brighten(out[k])), EFFECT_LUFS[k])
    return out


# Stereo
# ------
# Music and ambience are stereo, shape (2, n); effects stay mono.

def pan(x, p):
    """Constant-power pan of a mono signal: p from -1 (left) to 1 (right)."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)])


def place(out, x, at, p=0.0):
    """Adds a mono sound into a stereo buffer at sample `at`, panned."""
    st = pan(x, p)
    end = min(out.shape[1], at + st.shape[1])
    if at < end:
        out[:, at:end] += st[:, : end - at]


def stereo_reverb(x, seconds=2.0, wet=0.3, rng=None, bright=6000):
    """Reverb with a different decaying-noise response per side, so the
    room sounds wide; keeps the dry signal where it was panned."""
    rng = rng or np.random.default_rng(7)
    m = int(SR * seconds)
    t = np.arange(m) / SR
    n = x.shape[1] + m
    size = 1 << (n - 1).bit_length()
    mid = np.fft.rfft(x.sum(axis=0) * 0.5, size)
    out = np.zeros((2, n))
    for side in range(2):
        ir = lowpass(rng.standard_normal(m), bright) * np.exp(-t * 6.9 / seconds)
        ir[0] = 0
        ir /= np.sqrt(np.sum(ir ** 2))
        wetside = np.fft.irfft(mid * np.fft.rfft(ir, size), size)[:n]
        dry = np.concatenate([x[side], np.zeros(m)])
        out[side] = dry * (1 - wet) + wetside * wet
    return out


def seamless_stereo(x, crossfade):
    return np.stack([seamless(x[0], crossfade), seamless(x[1], crossfade)])


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# Ambience
# --------
# A stereo bed per family (wind, water, drone), looped; birds, frogs and
# drips are separate short sounds the game scatters at random while you
# play (SoundBank.qml), so the soundscape never repeats.

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


def frog(rng):
    """A soft, low double croak."""
    out = np.zeros(int(SR * 0.55))
    for k in range(2):
        d = 0.16
        t = t_axis(d)
        f = 210 + 40 * np.sin(np.pi * t / d)
        buzz = np.sign(np.sin(2 * np.pi * 38 * t)) * 0.5 + 0.5
        c = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.6 + 0.4 * buzz) * np.sin(np.pi * t / d) ** 2
        at = int(SR * 0.22 * k)
        out[at:at + len(c)] += lowpass(c, 1800)
    return out


def plop(rng):
    """A small fish or pebble in water."""
    d = 0.12
    t = t_axis(d)
    f = 700 * (1 + 3.0 * t / d)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / d)


def drip(rng, pitch):
    return bell(pitch, 0.6, 1.2) * 0.7


# the scattered critters: file name -> how it is made
CRITTERS = {
    "critter-bird-1": lambda r: bird(r, 0),
    "critter-bird-2": lambda r: bird(r, 1),
    "critter-bird-3": lambda r: bird(r, 2),
    "critter-frog": frog,
    "critter-plop": plop,
    # A6 and D7: in tune with every theme's scale
    "critter-drip-1": lambda r: drip(r, 1760),
    "critter-drip-2": lambda r: drip(r, 2349.3),
}
CRITTER_LUFS = -25.0


def trim_tail(x, db=-60):
    """Cuts the silence after the last sample louder than `db` below the
    peak, with a short fade."""
    loud = np.nonzero(np.abs(x) > np.max(np.abs(x)) * 10 ** (db / 20))[0]
    return fade_tail(x[: loud[-1] + 1], 40) if len(loud) else x


def critters():
    rng = np.random.default_rng(41)
    out = {}
    for name, make in CRITTERS.items():
        x = make(rng)
        room = 2.4 if "drip" in name else 1.2
        x = reverb(np.concatenate([x, np.zeros(int(SR * 0.2))]), room, 0.35 if "drip" not in name else 0.55, rng)
        out[name] = to_level(fade_head(trim_tail(x)), CRITTER_LUFS)
    return out


def ambience(name, seconds=48):
    rng = np.random.default_rng({"forest": 21, "river": 22, "temple": 23}[name])
    n = int(SR * (seconds + 3))
    t = np.arange(n) / SR
    mix = np.zeros((2, n))

    def wide(make):
        """Two sides that share half their noise: wide, not hollow."""
        common = make()
        return [np.sqrt(0.5) * common + np.sqrt(0.5) * make() for _ in range(2)]

    # wind in the leaves, swelling slowly, a little differently per side
    for side, w in enumerate(wide(lambda: pink(n, rng))):
        wind = bandpass(w, 150, 900)
        wind /= np.std(wind)
        swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / (11.0 + 2 * side) + 1.0 + side) * np.sin(2 * np.pi * t / 7.3)
        mix[side] += 0.22 * wind * swell
    if name == "forest":
        # insects: a faint high shimmer, pulsing, a little wider than the wind
        for side, w in enumerate(wide(lambda: rng.standard_normal(n))):
            ins = bandpass(w, 4200, 5600)
            ins /= np.std(ins)
            mix[side] += 0.025 * ins * (0.5 + 0.5 * np.sin(2 * np.pi * (18 + side) * t)) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 9))
    if name == "river":
        for side, w in enumerate(wide(lambda: pink(n, rng))):
            water = bandpass(w, 120, 2200)
            water /= np.std(water)
            mix[side] += 0.35 * water * (0.85 + 0.15 * np.sin(2 * np.pi * t / (5.1 + 0.7 * side)))
    if name == "temple":
        # a deep hush and a low, wide drone in stone, on the temple theme's
        # D: D3 and A3 on the left, A2 and A3 on the right
        mix *= 0.5
        for side, notes in enumerate(([50, 57], [45, 57])):
            mix[side] += fit(pad([hz(m) for m in notes], seconds + 3, rng, attack=4, release=4) * 0.35, n)
    return to_integrated(seamless_stereo(mix, 3), LOOP_LUFS[f"ambience-{name}"])


# Music
# -----
# Four short pieces in an A A' B A form that end on the tonic and ring out:
# the menu, and one play theme per ambience family. The melody follows the
# chords (chord tones on strong beats, pentatonic steps between), phrases
# end on long notes, and each family has its own key, tempo and voices.

PIECES = {
    # name: tonic, scale (pentatonic), tempo, lead, chords for A and B as
    # (root offset, quality) per bar
    "menu": dict(tonic=60, scale=[0, 2, 4, 7, 9], bpm=84, lead="kalimba", lead_lo=67, seed=31,
                 a=[(0, "M"), (9, "m"), (5, "M"), (7, "M")], b=[(5, "M"), (7, "M"), (4, "m"), (9, "m")]),
    "forest": dict(tonic=60, scale=[0, 2, 4, 7, 9], bpm=76, lead="marimba", lead_lo=67, seed=32,
                   a=[(0, "M"), (5, "M"), (9, "m"), (7, "M")], b=[(5, "M"), (0, "M"), (2, "m"), (7, "M")]),
    "river": dict(tonic=67, scale=[0, 2, 4, 7, 9], bpm=80, lead="kalimba", lead_lo=69, seed=33, arpeggio=True,
                  a=[(0, "M"), (7, "M"), (9, "m"), (5, "M")], b=[(9, "m"), (5, "M"), (0, "M"), (7, "M")]),
    "temple": dict(tonic=62, scale=[0, 3, 5, 7, 10], bpm=66, lead="bell", lead_lo=65, seed=34,
                   a=[(0, "m"), (10, "M"), (8, "M"), (10, "M")], b=[(8, "M"), (10, "M"), (0, "m"), (7, "m")]),
}
QUALITY = {"M": (0, 4, 7), "m": (0, 3, 7)}


def chord_notes(tonic, root, quality, low=48):
    """The triad on `root` (semitones above the tonic), voiced upward from
    near `low`: the bass note and the pad's three notes."""
    base = tonic + root
    while base - 12 >= low:
        base -= 12
    while base < low:
        base += 12
    return [base + q for q in QUALITY[quality]]


# melodic shapes for a phrase's first bar: (beat, move in scale steps)
CONTOURS = [
    [(0, 0), (1, 1), (1.5, 1), (2, 1), (3, -1)],      # a rise and a turn
    [(0, 0), (0.5, 1), (1, -1), (2, -1), (3, 2)],     # a little wave, then a lift
    [(0, 0), (1, 2), (2, -1), (2.5, -1), (3, -1)],    # a leap, stepping back down
    [(0, 0), (1.5, -1), (2, -1), (3, 2)],             # a dip and a reach
    [(0, 0), (1, 1), (2, 2), (3, -1)],                # climbing
]


def melody(spec, bars, rng):
    """(beat, length, midi) notes in phrases of two bars: a shaped first bar,
    then two long notes that settle. Strong beats (1 and 3) take a chord
    tone; the steps between stay in the pentatonic scale, so nothing clashes.
    Every 8-bar section ends on its last chord's root where the scale has
    it, and the piece on the tonic. The A sections share their shapes, the
    B section has its own, a step higher."""
    tonic, scale, lo = spec["tonic"], spec["scale"], spec["lead_lo"]
    pool = [m for m in range(lo, lo + 22) if (m - tonic) % 12 in scale]
    top = len(pool) - 1

    def tones(bar):
        root, quality = bars[bar]
        return {(tonic + root + q) % 12 for q in QUALITY[quality]}

    def snap(i, bar, direction, avoid=None):
        """The chord tone nearest scale step i, leaning toward `direction`,
        never the pitch `avoid`."""
        best = None
        for d in sorted(range(-3, 4), key=lambda d: (abs(d), -d * direction)):
            k = min(top, max(0, i + d))
            if pool[k] % 12 in tones(bar) and pool[k] != avoid:
                best = k
                break
        return best if best is not None else min(top, max(0, i))

    def walk(i, step):
        k = i + step
        return k if 0 <= k <= top else i - step  # turn back at the edges

    sections = {}  # the shapes of the A and B tunes
    notes = []
    i = len(pool) // 2 - 1
    for bar in range(len(bars)):
        if bar == len(bars) - 1:
            # the ring-out: the tonic, near where the tune is
            home = min((k for k in range(top + 1) if pool[k] % 12 == tonic % 12), key=lambda k: abs(k - i))
            notes.append((bar * 4, 4, pool[home]))
            break
        inside = bar % 8
        b_part = 16 <= bar < 24
        if not sections:
            pick = rng.permutation(len(CONTOURS))
            sections["A"] = [CONTOURS[pick[0]], CONTOURS[pick[1]]]
            sections["B"] = [CONTOURS[pick[2]], CONTOURS[pick[3]]]
        if inside % 2 == 0:
            # the phrase's shaped bar: phrases 1 and 3 share a shape, 2 and 4
            # the other; each phrase starts where the section's tune does
            shape = sections["B" if b_part else "A"][(inside // 2) % 2]
            start = len(pool) // 2 + (1 if b_part else -1) + (inside // 4)
            for k, (beat, step) in enumerate(shape):
                if k == 0:
                    i = snap(start, bar, 1)
                elif beat in (0, 2):
                    i = snap(walk(i, step), bar, step, avoid=pool[i])
                else:
                    i = walk(i, step)
                nxt = shape[k + 1][0] if k + 1 < len(shape) else 4
                notes.append((bar * 4 + beat, nxt - beat, pool[i]))
        else:
            # the phrase settles: down a step to a chord tone, then (at the
            # end of a section) to the root, else to another chord tone
            i = snap(walk(i, -1), bar, -1, avoid=pool[i])
            notes.append((bar * 4, 2, pool[i]))
            root = (tonic + bars[bar][0]) % 12
            if inside == 7:
                cands = [k for k in range(top + 1) if pool[k] % 12 == root]
                i = min(cands, key=lambda k: abs(k - i)) if cands else snap(i, bar, -1, avoid=pool[i])
            else:
                i = snap(walk(i, -1 if inside == 3 else 1), bar, -1 if inside == 3 else 1, avoid=pool[i])
            notes.append((bar * 4 + 2, 2, pool[i]))
    return notes


def voice(lead, f, dur, rng):
    if lead == "kalimba":
        return kalimba(f, dur, rng)
    if lead == "bell":
        return bell(f, dur, 1.6) * 0.8
    return marimba(f, dur, 0.7, rng)


def music(name):
    spec = PIECES[name]
    rng = np.random.default_rng(spec["seed"])
    beat = 60 / spec["bpm"]
    a, b = spec["a"], spec["b"]
    # A A' B A, then one bar of the tonic to ring out on
    bars = a + a + a + a + b + b + a + a + [(0, a[0][1])]
    total = len(bars) * 4 * beat
    n = int(SR * (total + 4))
    out = np.zeros((2, n))
    at = lambda beats: int(SR * beats * beat)  # noqa: E731
    for k, (root, quality) in enumerate(bars):
        notes = chord_notes(spec["tonic"], root, quality)
        last = k == len(bars) - 1
        length = 4 * beat + (3.0 if last else 1.2)
        # a soft pad, spread wide by two slightly different takes
        for side, p in ((0, -0.6), (1, 0.6)):
            pd = pad([hz(m) for m in notes], length, rng, attack=0.8, release=1.2 if not last else 3.0) * 0.16
            place(out, pd, at(k * 4), p)
        # the bass: a log drum on the root, beat 1 (and 3 in the B section)
        bass = notes[0] - 12
        place(out, log_drum(hz(bass), 0.7) * 0.32, at(k * 4), 0.0)
        if 16 <= k < 24 and not last:
            place(out, log_drum(hz(bass), 0.5) * 0.2, at(k * 4 + 2), 0.0)
        if spec.get("arpeggio") and not last:
            # river: flowing eighth-note arpeggios, left and right in turn
            arp = notes + [notes[0] + 12]
            for e in range(8):
                m = arp[e % len(arp)] + 12
                place(out, kalimba(hz(m), 0.9, rng) * 0.12, at(k * 4 + e * 0.5), -0.45 if e % 2 else 0.45)
    for start, length, m in melody(spec, bars, rng):
        dur = min(2.4, length * beat + 0.8)
        gain = 0.42 if spec["lead"] != "bell" else 0.5
        place(out, voice(spec["lead"], hz(m), dur, rng) * gain, at(start), 0.12)
        if spec["lead"] == "bell" and length >= 2:
            # temple: a low marimba answers long bell notes
            place(out, marimba(hz(m - 24), 1.2, 0.5, rng) * 0.25, at(start + 1), -0.2)
    if name in ("menu", "forest"):
        for bt in range(len(bars) * 4 - 4):
            if bt % 2 == 1:
                place(out, shaker(0.15, rng) * 0.035, at(bt), 0.35 if bt % 4 == 1 else -0.35)
    out = stereo_reverb(out, 2.4, 0.3, rng)[:, :n]
    return to_integrated(out, LOOP_LUFS[f"music-{name}"])


def main():
    """Makes every sound, or only the kinds named: effects, critters,
    ambience, music (numpy's rounding differs a little between machines, so
    remaking a kind you did not change only churns its files)."""
    kinds = sys.argv[1:] or ["effects", "critters", "ambience", "music"]
    os.makedirs(OUT, exist_ok=True)
    made = []
    shorts = {}
    if "effects" in kinds:
        shorts.update(effects())
    if "critters" in kinds:
        shorts.update(critters())
    for name, x in shorts.items():
        path = os.path.join(OUT, f"{name}.wav")
        write_wav(path, x)
        made.append(path)
    for name in ("forest", "river", "temple") if "ambience" in kinds else ():
        path = os.path.join(OUT, f"ambience-{name}.ogg")
        write_ogg(path, ambience(name), 1)
        made.append(path)
    for name in PIECES if "music" in kinds else ():
        path = os.path.join(OUT, f"music-{name}.ogg")
        write_ogg(path, music(name), 2)
        made.append(path)
    for p in made:
        print(os.path.relpath(p), os.path.getsize(p))


if __name__ == "__main__":
    sys.exit(main())
