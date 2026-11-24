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


def _impulse_response(rate, length=16384):
    """The two K-weighting stages' impulse response, by running the causal
    biquads over an impulse (once per rate; it decays well within 16384)."""
    h = np.zeros(length)
    h[0] = 1.0
    for (b0, b1, b2), (_, a1, a2) in _kweight_coefficients(rate):
        y = np.zeros(length)
        x1 = x2 = y1 = y2 = 0.0
        for i in range(length):
            xi = h[i]
            yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, xi, y1, yi
            y[i] = yi
        h = y
    return h


_IR = {}


def kweight(x, rate=44100):
    """The causal K-weighting filter, as BS.1770 specifies it, applied by
    fast convolution with its impulse response (numpy only, no scipy)."""
    if rate not in _IR:
        _IR[rate] = _impulse_response(rate)
    h = _IR[rate]
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    size = 1 << (n + len(h) - 2).bit_length()
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(h, size), size)[:n]


def _channels(x):
    """One array per channel: a mono array, or a list of channel arrays."""
    if isinstance(x, (list, tuple)):
        return [np.asarray(c, dtype=np.float64) for c in x]
    return [np.asarray(x, dtype=np.float64)]


def _block_loudness(chans, rate, block, hop):
    # BS.1770: the K-weighted mean square of each channel, summed (front
    # channels weigh 1), per block
    n = int(rate * block)
    h = int(rate * hop)
    total = None
    for y in chans:
        if len(y) < n:
            y = np.concatenate([y, np.zeros(n - len(y))])
        starts = range(0, len(y) - n + 1, h)
        ms = np.array([np.mean(y[s:s + n] ** 2) for s in starts])
        total = ms if total is None else total[:len(ms)] + ms[:len(total)]
    return -0.691 + 10 * np.log10(np.maximum(total, 1e-12))


def momentary_max(x, rate=44100):
    chans = [kweight(c, rate) for c in _channels(x)]
    return float(np.max(_block_loudness(chans, rate, 0.4, 0.1)))


def integrated(x, rate=44100):
    chans = [kweight(c, rate) for c in _channels(x)]
    blocks = _block_loudness(chans, rate, 0.4, 0.1)
    blocks = blocks[blocks > -70]
    if len(blocks) == 0:
        return -70.0
    rel = 10 * np.log10(np.mean(10 ** ((blocks + 0.691) / 10))) - 0.691 - 10
    gated = blocks[blocks > rel]
    return float(10 * np.log10(np.mean(10 ** ((gated + 0.691) / 10))) - 0.691)


def true_peak(x):
    """The highest peak of any channel after 4x oversampling, in dBTP."""
    peak = 0.0
    for c in _channels(x):
        n = len(c)
        spectrum = np.fft.rfft(c)
        if n % 2 == 0:
            # the Nyquist bin stands for two halves once the spectrum grows
            spectrum[-1] *= 0.5
        up = np.fft.irfft(spectrum, 4 * n) * 4
        peak = max(peak, float(np.max(np.abs(up))))
    return float(20 * np.log10(max(peak, 1e-12)))
