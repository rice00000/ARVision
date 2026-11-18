"""Small sound-design toolkit: cut, varispeed, layer, EQ, reverb, match loudness, export OGG.

Signals are float64 arrays shaped (n, 2) at SR.
"""
import os, subprocess, numpy as np, soundfile as sf, pyloudnorm as pyln
from scipy.signal import resample_poly
from pedalboard import (Pedalboard, HighpassFilter, LowpassFilter, LowShelfFilter, HighShelfFilter,
                        PeakFilter, Reverb, Compressor, Limiter, Delay, Chorus)

SR = 48000
LIB = 'E:/SFXs/'


def load(path, start=0.0, end=None):
    """Load a file (any format) as stereo SR float64, optionally cut [start, end] seconds."""
    if not os.path.isabs(path) and not os.path.exists(path):
        path = LIB + path
    try:
        y, r = sf.read(path, always_2d=True)
        y = y.astype(np.float64)
        if r != SR:
            from math import gcd
            g = gcd(SR, r)
            y = resample_poly(y, SR // g, r // g, axis=0)
    except Exception:
        raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'],
                             capture_output=True).stdout
        y = np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)
    if y.shape[1] == 1:
        y = np.repeat(y, 2, axis=1)
    elif y.shape[1] > 2:
        y = y[:, :2]
    a = int(start * SR)
    b = len(y) if end is None else int(end * SR)
    return y[a:b].copy()


def silence(seconds):
    return np.zeros((int(seconds * SR), 2))


def onset(y, threshold_db=-30.0):
    """Seconds to the first sample above threshold relative to the peak."""
    m = np.abs(y).max(1)
    thr = m.max() * 10 ** (threshold_db / 20)
    return int(np.argmax(m > thr)) / SR


def trim(y, threshold_db=-50.0, pre=0.002):
    """Cut leading silence (keeps [pre] seconds) and trailing silence."""
    m = np.abs(y).max(1)
    thr = m.max() * 10 ** (threshold_db / 20)
    idx = np.nonzero(m > thr)[0]
    a = max(0, idx[0] - int(pre * SR))
    b = idx[-1] + 1
    return y[a:b].copy()


def cut(y, start, end=None):
    return y[int(start * SR): None if end is None else int(end * SR)].copy()


def fade(y, fin=0.0, fout=0.0, shape='cos'):
    y = y.copy()
    if fin > 0:
        n = min(len(y), int(fin * SR))
        t = np.linspace(0, 1, n)
        y[:n] *= (np.sin(t * np.pi / 2) if shape == 'cos' else t)[:, None]
    if fout > 0:
        n = min(len(y), int(fout * SR))
        t = np.linspace(1, 0, n)
        y[-n:] *= (np.sin(t * np.pi / 2) ** 2 if shape == 'cos' else t)[:, None]
    return y


def length(y, seconds, fout=0.05):
    """Cut to [seconds] with a fade-out at the end."""
    return fade(y[:int(seconds * SR)], fout=fout)


def speed(y, semitones):
    """Varispeed (tape-style): pitch and duration change together. Positive is higher and shorter."""
    if semitones == 0:
        return y.copy()
    ratio = 2 ** (semitones / 12)
    up, down = 1000, int(round(1000 * ratio))
    from math import gcd
    g = gcd(up, down)
    return resample_poly(y, up // g, down // g, axis=0)


def stretch_pitch(y, semitones):
    """Pitch shift keeping the duration (phase vocoder, use small amounts)."""
    import librosa
    return np.stack([librosa.effects.pitch_shift(y[:, c].astype(np.float32), sr=SR, n_steps=semitones)
                     for c in range(2)], 1).astype(np.float64)


def gain(y, db):
    return y * 10 ** (db / 20)


def mono(y):
    m = y.mean(1, keepdims=True)
    return np.repeat(m, 2, axis=1)


def pan(y, p):
    """Constant-power pan, p in [-1, 1], on a mono-summed signal."""
    m = y.mean(1)
    a = (p + 1) * np.pi / 4
    return np.stack([m * np.cos(a), m * np.sin(a)], 1) * np.sqrt(2)


def width(y, w):
    """Stereo width: 0 mono, 1 unchanged, >1 wider."""
    mid = (y[:, 0] + y[:, 1]) / 2
    side = (y[:, 0] - y[:, 1]) / 2 * w
    return np.stack([mid + side, mid - side], 1)


def mix(*layers):
    """layers: (signal, offset_seconds, gain_db). Returns the sum."""
    end = max(int(off * SR) + len(sig) for sig, off, _ in layers)
    out = np.zeros((end, 2))
    for sig, off, db in layers:
        a = int(off * SR)
        out[a:a + len(sig)] += gain(sig, db)
    return out


def fx(y, *plugins):
    board = Pedalboard(list(plugins))
    out = board(y.T.astype(np.float32), SR).T.astype(np.float64)
    return out


def tail(y, seconds):
    """Append silence so effects can ring out."""
    return np.concatenate([y, silence(seconds)])


def hp(y, hz, q=0.707):
    return fx(y, HighpassFilter(cutoff_frequency_hz=hz))


def lp(y, hz):
    return fx(y, LowpassFilter(cutoff_frequency_hz=hz))


def eq(y, low=None, high=None, peaks=()):
    """low/high: (hz, db) shelves; peaks: (hz, db, q)."""
    plugins = []
    if low:
        plugins.append(LowShelfFilter(cutoff_frequency_hz=low[0], gain_db=low[1]))
    if high:
        plugins.append(HighShelfFilter(cutoff_frequency_hz=high[0], gain_db=high[1]))
    for hz, db, q in peaks:
        plugins.append(PeakFilter(cutoff_frequency_hz=hz, gain_db=db, q=q))
    return fx(y, *plugins)


def verb(y, size=0.4, wet=0.18, damp=0.5, width_=1.0, ring=1.0):
    """Reverb with an appended tail of [ring] seconds."""
    y = tail(y, ring)
    return fx(y, Reverb(room_size=size, wet_level=wet, dry_level=1.0 - wet * 0.5, damping=damp, width=width_))


def comp(y, threshold=-18, ratio=3, attack=5, release=80):
    return fx(y, Compressor(threshold_db=threshold, ratio=ratio, attack_ms=attack, release_ms=release))


def lufs(y):
    meter = pyln.Meter(SR, block_size=min(0.4, max(0.05, len(y) / SR * 0.5)))
    return meter.integrated_loudness(y)


def peak_db(y):
    return 20 * np.log10(np.abs(y).max() + 1e-12)


def short_max(y, window=0.1):
    """Loudest 100 ms RMS (dBFS), a fair loudness for short one-shots."""
    m = y.mean(1)
    w = int(window * SR)
    if len(m) <= w:
        return 20 * np.log10(np.sqrt((m ** 2).mean()) + 1e-12)
    r = np.sqrt(np.convolve(m ** 2, np.ones(w) / w, 'valid'))
    return 20 * np.log10(r.max() + 1e-12)


def level(y, target_db, ceiling=-1.0):
    """Set the loudest 100 ms RMS to [target_db] dBFS, limited to a [ceiling] peak."""
    y = gain(y, target_db - short_max(y))
    p = peak_db(y)
    if p > ceiling:
        y = fx(y, Limiter(threshold_db=ceiling, release_ms=50))
        y = np.clip(y, -10 ** (ceiling / 20), 10 ** (ceiling / 20))
    return y


def export(y, path, channels=2, quality=6, fade_end=0.01):
    """Write OGG Vorbis (mono for sounds placed in 3D). A tiny end fade avoids clicks."""
    y = fade(y, fout=fade_end) if fade_end else y
    data = y.mean(1) if channels == 1 else y
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + '.tmp.wav'
    sf.write(tmp, data.astype(np.float32), SR, subtype='FLOAT')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp, '-c:a', 'libvorbis', '-q:a', str(quality), path],
                   check=True)
    os.remove(tmp)
    return path


def wav(y, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, y.astype(np.float32), SR, subtype='FLOAT')
    return path


# ---- tuned synthesis, for tiny accents where a recording would be too long -------------------

def note_hz(name):
    import librosa
    return float(librosa.note_to_hz(name))


def bell(freq, seconds=1.2, bright=1.0, decay=1.0, seed=0):
    """A soft struck bell / celesta tone: inharmonic partials with their own decays."""
    rng = np.random.default_rng(seed)
    t = np.arange(int(seconds * SR)) / SR
    partials = [(1.0, 1.0, 1.0), (2.0, 0.35 * bright, 1.6), (3.01, 0.12 * bright, 2.4),
                (4.17, 0.08 * bright, 3.2), (5.43, 0.04 * bright, 4.0)]
    out = np.zeros_like(t)
    for ratio, amp, dk in partials:
        ph = rng.uniform(0, 2 * np.pi)
        out += amp * np.sin(2 * np.pi * freq * ratio * t + ph) * np.exp(-t * dk * 2.2 / decay)
    attack = np.minimum(1, t / 0.002)
    out *= attack
    out /= np.abs(out).max()
    return np.stack([out, out], 1)


def _modal(freq, seconds, partials, noise_amp=0.0, noise_hz=3000, seed=0, detune=0.0):
    """Sum of decaying partials (ratio, amp, decay_per_s) plus a short mallet noise click; stereo with a tiny detune."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    chans = []
    for c, dt in enumerate((-detune, detune)):
        out = np.zeros(n)
        for ratio, amp, dk in partials:
            f = freq * ratio * (1 + dt * 1e-3)
            if f >= SR / 2 * 0.95:
                continue
            out += amp * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi)) * np.exp(-t * dk)
        chans.append(out)
    y = np.stack(chans, 1)
    y *= np.minimum(1, t / 0.0015)[:, None]
    end = min(n, int(0.04 * SR))
    y[-end:] *= np.cos(np.linspace(0, np.pi / 2, end))[:, None] ** 2   # never cut a ringing note
    if noise_amp:
        from scipy.signal import butter, sosfilt
        k = int(0.006 * SR)
        nz = rng.standard_normal(k) * np.exp(-np.arange(k) / (0.0012 * SR))
        sos = butter(2, [noise_hz * 0.5, min(noise_hz * 2, SR / 2 * 0.9)], 'bandpass', fs=SR, output='sos')
        nz = sosfilt(sos, nz)
        y[:k] += (nz / (np.abs(nz).max() + 1e-9) * noise_amp)[:, None]
    return y / (np.abs(y).max() + 1e-12)


def marimba(note, seconds=1.0, seed=0):
    f = note_hz(note) if isinstance(note, str) else note
    return _modal(f, seconds, [(1.0, 1.0, 4.5), (3.93, 0.22, 14.0), (9.2, 0.05, 30.0), (2.0, 0.04, 9.0)],
                  noise_amp=0.25, noise_hz=2500, seed=seed)


def celesta(note, seconds=1.4, seed=0):
    f = note_hz(note) if isinstance(note, str) else note
    return _modal(f, seconds, [(1.0, 1.0, 3.0), (2.0, 0.30, 5.0), (3.0, 0.10, 8.0), (4.16, 0.10, 12.0),
                               (5.43, 0.05, 16.0), (8.9, 0.02, 25.0)],
                  noise_amp=0.12, noise_hz=6000, seed=seed)


def glass(note, seconds=1.6, seed=0):
    """A soft struck glass / bowl ping: few partials, long and pure."""
    f = note_hz(note) if isinstance(note, str) else note
    return _modal(f, seconds, [(1.0, 1.0, 2.2), (2.32, 0.18, 4.0), (4.25, 0.06, 7.0)],
                  noise_amp=0.05, noise_hz=8000, seed=seed)


def hits(y, threshold_db=-24.0, gap=0.08):
    """Onsets of separate hits in [y]: list of (seconds, peak dBFS of the next 100 ms), loudest first."""
    import librosa
    m = y.mean(1).astype(np.float32)
    on = librosa.onset.onset_detect(y=m, sr=SR, units='time', backtrack=True, wait=int(gap * SR / 512))
    top = peak_db(y)
    out = []
    for t in on:
        p = peak_db(y[int(t * SR):int((t + 0.1) * SR)])
        if p >= top + threshold_db:
            out.append((round(float(t), 3), round(p, 1)))
    return sorted(out, key=lambda h: -h[1])
