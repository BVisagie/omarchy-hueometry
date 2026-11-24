"""Loudness as EBU R128 / ITU-R BS.1770 measures it, in numpy, shared by
the synthesiser (to set levels) and tools/check/audio.py (to check them).

- momentary_max: the loudest 400 ms window, K-weighted, in LUFS. Effects
  are shorter than integrated loudness's gating suits, so their level is
  their loudest moment.
- integrated: gated integrated loudness, for the music and ambience.
- true_peak: the sample peak after 4x oversampling, in dBTP.
"""
import numpy as np


def _kweight_coefficients(rate):
    # the two BS.1770 stages, designed for any rate (as pyloudnorm does)
    f0, gain, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = np.tan(np.pi * f0 / rate)
    vh = 10 ** (gain / 20)
    vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    shelf = ((vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0), \
            (1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0)
    f0, q = 38.13547087602444, 0.5003270373238773
    k = np.tan(np.pi * f0 / rate)
    a0 = 1 + k / q + k * k
    high = (1.0, -2.0, 1.0), (1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0)
    return shelf, high


def _response(b, a, w):
    z = np.exp(-1j * w)
    return (b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z)


def kweight(x, rate=44100):
    """K-weighting applied by its magnitude in the frequency domain: fast in
    numpy, and loudness depends only on the magnitude."""
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    size = 1 << (n - 1).bit_length()
    w = 2 * np.pi * np.fft.rfftfreq(size, 1 / rate) / rate
    h = np.ones_like(w, dtype=np.complex128)
    for b, a in _kweight_coefficients(rate):
        h *= _response(b, a, w)
    return np.fft.irfft(np.fft.rfft(x, size) * np.abs(h), size)[:n]


def _block_loudness(y, rate, block, hop):
    n = int(rate * block)
    h = int(rate * hop)
    if len(y) < n:
        y = np.concatenate([y, np.zeros(n - len(y))])
    starts = range(0, len(y) - n + 1, h)
    ms = np.array([np.mean(y[s:s + n] ** 2) for s in starts])
    return -0.691 + 10 * np.log10(np.maximum(ms, 1e-12))


def momentary_max(x, rate=44100):
    return float(np.max(_block_loudness(kweight(x, rate), rate, 0.4, 0.1)))


def integrated(x, rate=44100):
    blocks = _block_loudness(kweight(x, rate), rate, 0.4, 0.1)
    blocks = blocks[blocks > -70]
    if len(blocks) == 0:
        return -70.0
    rel = 10 * np.log10(np.mean(10 ** ((blocks + 0.691) / 10))) - 0.691 - 10
    gated = blocks[blocks > rel]
    return float(10 * np.log10(np.mean(10 ** ((gated + 0.691) / 10))) - 0.691)


def true_peak(x):
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    spectrum = np.fft.rfft(x)
    up = np.fft.irfft(spectrum, 4 * n) * 4
    return float(20 * np.log10(max(np.max(np.abs(up)), 1e-12)))
