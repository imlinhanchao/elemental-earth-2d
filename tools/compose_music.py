#!/usr/bin/env python3
"""程序化合成《元素纪元 2D》原创配乐（主菜单 + 6 个时代 + 2 段过场短乐句）。

全部音色由 numpy 合成（拨弦 Karplus-Strong、加法钢琴、FM 电钢 / 钟、波表弦乐与垫音、
手鼓与沙锤、卷积混响），不使用任何外部采样，没有版权问题。

循环曲目按小节数精确计算长度，超出结尾的音符尾音与混响回卷到开头，循环点无缝。
各时代共用同一个主动机（MOTIF），换调式、配器与速度做变奏。

用法: python3 tools/compose_music.py [曲目名 ...]    （需要 numpy 与 oggenc / vorbis-tools）
输出: assets/audio/bgm/<name>.ogg
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "bgm")
OGG_QUALITY = "2"  # 约 96 kbps

# 调式（半音）
AEOLIAN = [0, 2, 3, 5, 7, 8, 10]
DORIAN = [0, 2, 3, 5, 7, 9, 10]
IONIAN = [0, 2, 4, 5, 7, 9, 11]
LYDIAN = [0, 2, 4, 6, 7, 9, 11]
MINOR_PENTA = [0, 3, 5, 7, 10]

# 主动机：(调式音级, 拍数)，None 为休止。两小节
MOTIF = [(4, 1.5), (3, 0.5), (2, 1.0), (4, 1.0), (1, 1.0), (2, 0.5), (0, 0.5), (0, 2.0)]


def midi_hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def _t(n):
    return np.arange(n) / SR


def _fade(sig, attack=0.003, release=0.01):
    n = len(sig)
    a = min(n, max(1, int(attack * SR)))
    r = min(n, max(1, int(release * SR)))
    sig[:a] *= np.linspace(0.0, 1.0, a)
    sig[n - r:] *= np.linspace(1.0, 0.0, r)
    return sig


def _note_off(t, dur, rate):
    """音符结束后的指数衰减"""
    return np.where(t < dur, 1.0, np.exp(-(t - dur) * rate))


def _lowpass(sig, k):
    if k <= 1:
        return sig
    return np.convolve(sig, np.ones(k) / k, mode="same")


# ---------------------------------------------------------------- 波表

_TABLE_N = 4096


def _wavetable(harmonics):
    ph = np.arange(_TABLE_N) / _TABLE_N * 2 * np.pi
    tab = np.zeros(_TABLE_N)
    for k, amp in harmonics:
        tab += amp * np.sin(k * ph)
    return tab / np.max(np.abs(tab))


TAB_STRINGS = _wavetable([(k, (1.0 / k) * np.exp(-k * 0.18)) for k in range(1, 14)])
TAB_PAD = _wavetable([(k, (1.0 / k) * np.exp(-k * 0.45)) for k in range(1, 10)])
TAB_CELLO = _wavetable([(k, (1.0 / k ** 0.8) * np.exp(-k * 0.15)) for k in range(1, 14)])
TAB_FLUTE = _wavetable([(1, 1.0), (2, 0.22), (3, 0.09), (4, 0.03)])
TAB_RECORDER = _wavetable([(1, 1.0), (2, 0.12), (3, 0.22), (4, 0.04), (5, 0.05)])
TAB_HUM = _wavetable([(1, 1.0), (2, 0.5), (3, 0.28), (4, 0.12), (5, 0.06)])


def _osc(table, freq_curve):
    phase = np.cumsum(freq_curve) / SR
    idx = ((phase % 1.0) * _TABLE_N).astype(np.int64) % _TABLE_N
    return table[idx]


def _sustained(table, freq, dur, vel, attack, release, voices=(0.0,), vib_rate=0.0, vib_depth=0.0, rng=None):
    n = int((dur + release) * SR)
    t = _t(n)
    vib = 1.0 + vib_depth * np.sin(2 * np.pi * vib_rate * t) * np.clip((t - 0.35) / 0.6, 0.0, 1.0)
    out = np.zeros(n)
    for cents in voices:
        f = freq * 2 ** (cents / 1200.0)
        shift = (rng.random() if rng is not None else 0.0) * SR / f
        out += np.roll(_osc(table, f * vib), int(shift))
    out /= len(voices)
    env = np.clip(t / attack, 0.0, 1.0) * np.where(t < dur, 1.0, np.clip(1.0 - (t - dur) / release, 0.0, 1.0)) ** 2
    return _fade(out * env * vel, 0.002, 0.02)


# ---------------------------------------------------------------- 乐器
# 签名: inst(freq, dur, vel, rng) -> 单声道数组（可长于 dur，包含尾音）


def strings(f, dur, vel, rng):
    return _sustained(TAB_STRINGS, f, dur, vel, 0.45, 1.2, voices=(-7.0, 0.0, 6.0), vib_rate=5.1, vib_depth=0.003, rng=rng)


def warm_pad(f, dur, vel, rng):
    return _sustained(TAB_PAD, f, dur, vel, 1.4, 2.0, voices=(-9.0, 0.0, 8.0), rng=rng)


def cello(f, dur, vel, rng):
    return _sustained(TAB_CELLO, f, dur, vel, 0.12, 0.6, voices=(-3.0, 3.0), vib_rate=4.8, vib_depth=0.0025, rng=rng)


def hum(f, dur, vel, rng):
    return _sustained(TAB_HUM, f, dur, vel, 0.9, 1.5, voices=(-5.0, 4.0), vib_rate=4.0, vib_depth=0.002, rng=rng)


def _breath(n, rng, amount):
    noise = _lowpass(rng.uniform(-1, 1, n), 6) - _lowpass(rng.uniform(-1, 1, n), 40) * 0.5
    return noise * amount


def flute(f, dur, vel, rng):
    s = _sustained(TAB_FLUTE, f, dur, vel, 0.07, 0.18, vib_rate=5.0, vib_depth=0.004, rng=rng)
    t = _t(len(s))
    chiff = np.exp(-t * 30.0) * 0.6 + 0.12
    s += _breath(len(s), rng, 0.08 * vel) * chiff * np.clip(t / 0.03, 0, 1) * _note_off(t, dur, 20)
    return s


def recorder(f, dur, vel, rng):
    s = _sustained(TAB_RECORDER, f, dur, vel, 0.04, 0.12, vib_rate=5.6, vib_depth=0.0025, rng=rng)
    t = _t(len(s))
    s += _breath(len(s), rng, 0.05 * vel) * (np.exp(-t * 40.0) + 0.08) * _note_off(t, dur, 25)
    return s


def _partials(f, dur, vel, parts, tail, attack=0.002, off_rate=8.0, rng=None):
    n = int((dur + tail) * SR)
    t = _t(n)
    out = np.zeros(n)
    for ratio, amp, decay in parts:
        if f * ratio > SR * 0.45:
            continue
        ph = rng.random() * 2 * np.pi if rng is not None else 0.0
        out += amp * np.sin(2 * np.pi * f * ratio * t + ph) * np.exp(-t * decay)
    out *= _note_off(t, dur, off_rate)
    return _fade(out * vel, attack, 0.02)


def piano(f, dur, vel, rng):
    parts = []
    scale = (f / 261.6) ** 0.45
    for k in range(1, 11):
        ratio = k * np.sqrt(1 + 0.00035 * k * k)
        amp = (1.0 / k ** 1.15) * np.exp(-k * (0.55 - 0.3 * vel))
        parts.append((ratio, amp, (0.7 + 0.45 * k) * scale))
        parts.append((ratio * 1.0006, amp * 0.5, (0.9 + 0.5 * k) * scale))
    s = _partials(f, dur, vel, parts, 1.0, 0.002, 9.0, rng)
    t = _t(len(s))
    s[: int(0.02 * SR)] += _lowpass(rng.uniform(-1, 1, int(0.02 * SR)), 4) * np.exp(-t[: int(0.02 * SR)] * 300) * 0.05 * vel
    return s


def marimba(f, dur, vel, rng):
    return _partials(f, max(dur, 1.2), vel, [(1, 1.0, 3.8), (3.93, 0.32, 11.0), (9.2, 0.06, 26.0)], 0.3, 0.001, 4.0, rng)


def kalimba(f, dur, vel, rng):
    return _partials(f, max(dur, 1.5), vel, [(1, 1.0, 2.4), (5.4, 0.18, 9.0), (8.9, 0.06, 18.0)], 0.4, 0.001, 3.0, rng)


def glock(f, dur, vel, rng):
    return _partials(f, max(dur, 2.0), vel, [(1, 1.0, 1.3), (2.76, 0.35, 3.0), (5.4, 0.16, 6.5), (8.93, 0.07, 11.0)], 0.8, 0.001, 2.0, rng)


def celesta(f, dur, vel, rng):
    return _partials(f, max(dur, 1.6), vel, [(1, 1.0, 2.2), (2.0, 0.25, 4.0), (3.0, 0.08, 7.0), (4.2, 0.05, 10.0)], 0.6, 0.001, 3.0, rng)


def _fm(f, dur, vel, ratio, index, idx_decay, amp_decay, tail, off_rate):
    n = int((dur + tail) * SR)
    t = _t(n)
    mod = index * np.exp(-t * idx_decay) * np.sin(2 * np.pi * f * ratio * t)
    out = np.sin(2 * np.pi * f * t + mod) * np.exp(-t * amp_decay) * _note_off(t, dur, off_rate)
    return _fade(out * vel, 0.002, 0.02)


def e_piano(f, dur, vel, rng):
    s = _fm(f, dur, vel, 1.0, 1.4 * vel + 0.3, 2.5, 1.1, 1.0, 6.0)
    # 音叉金属泛音：高比率 FM，迅速衰减
    tine = _fm(f, min(dur, 0.3), vel * 0.12, 14.0, 0.8, 30.0, 18.0, 0.2, 20.0)
    k = min(len(s), len(tine))
    s[:k] += tine[:k]
    return s


def bell(f, dur, vel, rng):
    return _fm(f, max(dur, 3.0), vel, 3.5, 2.2, 1.6, 0.9, 1.5, 1.5)


def soft_bell(f, dur, vel, rng):
    return _fm(f, max(dur, 2.5), vel, 2.0, 1.0, 2.0, 1.0, 1.0, 2.0)


def pluck(f, dur, vel, rng, decay=0.996, bright=3):
    """Karplus-Strong 拨弦，按实际基频重采样以消除整数延迟带来的音高偏差"""
    total = int((max(dur, 0.6) + 1.2) * SR)
    N = int(np.ceil(SR / f))
    f0 = SR / (N + 0.5)
    n_raw = int(total * f / f0) + N + 2
    out = np.zeros(n_raw)
    out[1:N + 1] = _lowpass(rng.uniform(-1, 1, N), bright)
    start = N + 1
    while start < n_raw:
        end = min(start + N, n_raw)
        out[start:end] = decay * 0.5 * (out[start - N:end - N] + out[start - N - 1:end - N - 1])
        start = end
    pos = np.arange(total) * (f / f0)
    sig = np.interp(pos, np.arange(n_raw), out)
    t = _t(total)
    sig *= _note_off(t, max(dur, 0.6), 6.0)
    sig -= np.mean(sig)
    return _fade(sig * vel / (np.max(np.abs(sig)) + 1e-9), 0.001, 0.03)


def lute(f, dur, vel, rng):
    return pluck(f, dur, vel, rng, 0.995, 4)


def harp(f, dur, vel, rng):
    return pluck(f, max(dur, 1.5), vel, rng, 0.998, 6)


def pizz(f, dur, vel, rng):
    return pluck(f, 0.5, vel, rng, 0.990, 8)


def synth_pluck(f, dur, vel, rng):
    n = int((max(dur, 0.4) + 0.6) * SR)
    t = _t(n)
    out = np.zeros(n)
    for k in range(1, 12):
        if f * k > 12000:
            break
        out += (1.0 / k) * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (2.5 + 2.2 * k))
    return _fade(out * vel, 0.002, 0.03)


def sub_bass(f, dur, vel, rng):
    n = int((dur + 0.3) * SR)
    t = _t(n)
    out = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t)
    env = np.clip(t / 0.015, 0, 1) * (0.55 + 0.45 * np.exp(-t * 4.0)) * _note_off(t, dur, 14.0)
    return _fade(out * env * vel, 0.002, 0.03)


# ---------------------------------------------------------------- 打击乐


def frame_drum(vel, rng):
    n = int(0.9 * SR)
    t = _t(n)
    f = 52 + 60 * np.exp(-t * 22)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6.5)
    skin = _lowpass(rng.uniform(-1, 1, n), 10) * np.exp(-t * 35) * 0.35
    return _fade((body + skin) * vel, 0.001, 0.02)


def kick_soft(vel, rng):
    n = int(0.6 * SR)
    t = _t(n)
    f = 42 + 80 * np.exp(-t * 32)
    return _fade(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8.0) * vel, 0.001, 0.02)


def shaker(vel, rng):
    n = int(0.14 * SR)
    t = _t(n)
    noise = np.diff(rng.uniform(-1, 1, n + 1))
    env = np.clip(t / 0.012, 0, 1) * np.exp(-t * 38)
    return _fade(noise * env * vel * 0.5, 0.001, 0.01)


def hat(vel, rng):
    n = int(0.08 * SR)
    t = _t(n)
    noise = np.diff(np.diff(rng.uniform(-1, 1, n + 2)))
    return _fade(noise * np.exp(-t * 85) * vel * 0.25, 0.0005, 0.01)


def woodblock(vel, rng):
    return _partials(820, 0.08, vel, [(1, 1.0, 40), (2.7, 0.4, 70)], 0.1, 0.0005, 30.0, rng)


PERC = {"frame": frame_drum, "kick": kick_soft, "shaker": shaker, "hat": hat, "wood": woodblock}


# ---------------------------------------------------------------- 轨道与混音


class Track:
    def __init__(self, n_samples, loop):
        self.n = n_samples
        self.loop = loop
        self.buf = np.zeros((2, n_samples))

    def add(self, t, sig, pan=0.0, gain=1.0):
        gl = np.cos((pan + 1) * np.pi / 4) * gain
        gr = np.sin((pan + 1) * np.pi / 4) * gain
        start = int(round(t * SR))
        if not self.loop:
            end = min(self.buf.shape[1], start + len(sig))
            if end > start:
                self.buf[0, start:end] += sig[: end - start] * gl
                self.buf[1, start:end] += sig[: end - start] * gr
            return
        pos = start % self.n
        i = 0
        while i < len(sig):
            take = min(len(sig) - i, self.n - pos)
            self.buf[0, pos:pos + take] += sig[i:i + take] * gl
            self.buf[1, pos:pos + take] += sig[i:i + take] * gr
            i += take
            pos = 0


def reverb(buf, seconds, wet, rng, brightness=3500.0):
    """卷积混响（循环卷积：循环曲目的混响尾音自然回卷到开头）"""
    length = buf.shape[1]
    ir_n = int(seconds * SR)
    t = _t(ir_n)
    freqs = np.fft.rfftfreq(length, 1 / SR)
    tilt = 1.0 / np.sqrt(1.0 + (freqs / brightness) ** 2)
    out = np.empty_like(buf)
    pre = int(0.022 * SR)
    for ch in range(2):
        ir = np.zeros(length)
        tail = rng.normal(0, 1, ir_n) * np.exp(-6.9 * t / seconds) * np.clip(t / 0.03, 0, 1)
        ir[pre:pre + ir_n] = tail[: length - pre]
        ir /= np.sqrt(np.sum(ir ** 2))
        spec = np.fft.rfft(buf[ch]) * np.fft.rfft(ir) * tilt
        out[ch] = buf[ch] + wet * np.fft.irfft(spec, length)
    return out


def master(buf, target_db=-19.0):
    buf = buf - buf.mean(axis=1, keepdims=True)
    rms = np.sqrt(np.mean(buf ** 2))
    buf = buf * (10 ** (target_db / 20.0) / (rms + 1e-12))
    # 软限幅：峰值不超过 -1 dBFS
    ceiling = 0.89
    return np.tanh(buf / ceiling) * ceiling


def write_ogg(buf, name):
    os.makedirs(OUT_DIR, exist_ok=True)
    pcm = (np.clip(buf, -1, 1).T * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, name + ".wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        out_path = os.path.join(OUT_DIR, name + ".ogg")
        subprocess.run(["oggenc", "-Q", "-q", OGG_QUALITY, "-o", out_path, wav_path], check=True)
    print("  %-14s %6.1f s  %6.0f KB" % (name, buf.shape[1] / SR, os.path.getsize(out_path) / 1024))


# ---------------------------------------------------------------- 作曲


class Composer:
    def __init__(self, spec):
        self.s = spec
        self.rng = np.random.default_rng(spec["seed"])
        self.beat = 60.0 / spec["bpm"]
        self.bars = spec.get("bars", 32)
        self.bar_len = 4 * self.beat
        n = int(round(self.bars * 4 * self.beat * SR))
        self.track = Track(n, loop=True)
        self.scale = spec["scale"]

    # 音级 → MIDI
    def midi(self, d, octave=0):
        n = len(self.scale)
        o, i = divmod(int(d), n)
        return self.s["root"] + 12 * (o + octave) + self.scale[i]

    def chord(self, bar):
        r = self.s["prog"][bar % len(self.s["prog"])]
        tones = [r, r + 2, r + 4]
        if self.s.get("sevenths"):
            tones.append(r + 6)
        return tones

    def _human(self, t, amount=0.008):
        return max(0.0, t + self.rng.normal(0, amount))

    def note(self, inst, t, midi, dur, vel, pan=0.0, gain=1.0):
        vel = float(np.clip(vel * (1 + self.rng.normal(0, 0.07)), 0.05, 1.0))
        self.track.add(self._human(t), inst(midi_hz(midi), dur, vel, self.rng), pan, gain)

    def hit(self, kind, t, vel, pan=0.0, gain=1.0):
        vel = float(np.clip(vel * (1 + self.rng.normal(0, 0.1)), 0.05, 1.0))
        self.track.add(self._human(t, 0.004), PERC[kind](vel, self.rng), pan, gain)

    # ---- 旋律
    def _nearest_chord_tone(self, d, chord):
        n = len(self.scale)
        pcs = {c % n for c in chord}
        for off in (0, -1, 1, -2, 2, -3, 3):
            if (d + off) % n in pcs:
                return d + off
        return d

    def gen_phrase(self, start_d, first_bar, n_bars, end_tonic, lo, hi):
        rhythms = [[1, 1, 1, 1], [1.5, 0.5, 1, 1], [2, 1, 1], [0.5, 0.5, 1, 2], [1, 0.5, 0.5, 2], [3, 1], [2, 2], [1, 1, 2]]
        steps = [-2, -1, -1, -1, 1, 1, 1, 2, 0, 3, -3]
        events = []
        d = start_d
        for b in range(n_bars):
            chord = self.chord(first_bar + b)
            last = b == n_bars - 1
            rhythm = [[2, 2], [1, 3], [1, 1, 2], [4]][self.rng.integers(4)] if last else rhythms[self.rng.integers(len(rhythms))]
            for j, r in enumerate(rhythm):
                if j > 0:
                    d += steps[self.rng.integers(len(steps))]
                if j == 0 or r >= 2:
                    d = self._nearest_chord_tone(d, chord)
                if d < lo:
                    d += 2
                if d > hi:
                    d -= 2
                if last and j == len(rhythm) - 1:
                    n = len(self.scale)
                    target = 0 if end_tonic else self.chord(first_bar + b)[0]
                    d = min(range(lo, hi + 1), key=lambda x: (x % n != target % n, abs(x - d)))
                rest = j > 0 and not last and self.rng.random() < 0.07
                events.append((None if rest else d, r))
        return events

    def motif(self, shift=0, ornament=False):
        out = []
        for d, r in MOTIF:
            if ornament and r >= 1.0 and d is not None and self.rng.random() < 0.4:
                out.append((d + shift + 1, 0.25))
                out.append((d + shift, r - 0.25))
            else:
                out.append((None if d is None else d + shift, r))
        return out

    def melody_plan(self):
        n = len(self.scale)
        lo, hi = -1, n + 5
        top = n  # 主动机的落点
        plan = []  # (起始小节, 事件)
        plan.append((4, self.motif() + self.gen_phrase(2, 6, 2, False, lo, hi)))
        plan.append((8, self.motif(2) + self.gen_phrase(4, 10, 2, True, lo, hi)))
        plan.append((16, self.gen_phrase(top, 16, 4, False, lo + 2, hi + 1)))
        plan.append((20, self.gen_phrase(top - 1, 20, 4, False, lo + 1, hi + 1)))
        plan.append((24, self.motif(0, True) + self.gen_phrase(2, 26, 2, True, lo, hi)))
        return plan

    def render_melody(self, inst, octave, gain, pan, legato=0.95, vel=0.75):
        for bar, events in self.melody_plan():
            t = bar * self.bar_len
            for d, r in events:
                if d is not None:
                    v = vel * (1.08 if abs((t / self.beat) % 4) < 0.01 else 1.0)
                    self.note(inst, t, self.midi(d, octave), r * self.beat * legato, v, pan, gain)
                t += r * self.beat

    # ---- 伴奏
    def render_pad(self, inst, octave, gain, bars, vel=0.5, spread=0.5):
        b = bars[0]
        while b <= bars[1]:
            chord = self.chord(b)
            span = 1
            while b + span <= bars[1] and self.chord(b + span) == chord and span < 4:
                span += 1
            for i, d in enumerate(chord):
                pan = (i / max(1, len(chord) - 1) - 0.5) * 2 * spread
                self.note(inst, b * self.bar_len, self.midi(d, octave), span * self.bar_len, vel, pan, gain)
            b += span

    def render_arp(self, inst, octave, gain, bars, pattern, step, vel=0.5, pan_swing=0.35, accent=1.25):
        for b in range(bars[0], bars[1] + 1):
            chord = self.chord(b)
            tones = chord + [c + len(self.scale) for c in chord]
            steps = int(round(4 / step))
            for i in range(steps):
                idx = pattern[i % len(pattern)]
                if idx is None:
                    continue
                t = b * self.bar_len + i * step * self.beat
                v = vel * (accent if i == 0 else 1.0)
                pan = np.sin(i * 0.9) * pan_swing
                self.note(inst, t, self.midi(tones[idx % len(tones)], octave), step * self.beat * 1.6, v, pan, gain)

    def render_bass(self, inst, octave, gain, bars, pattern, vel=0.6):
        """pattern: [(拍, 和弦音序 0=根 2=五, 拍长)]"""
        for b in range(bars[0], bars[1] + 1):
            chord = self.chord(b)
            for beat_pos, ci, length in pattern:
                d = chord[0] if ci == 0 else chord[min(ci, len(chord) - 1)]
                self.note(inst, b * self.bar_len + beat_pos * self.beat, self.midi(d, octave), length * self.beat, vel, 0.0, gain)

    def render_perc(self, kind, bars, positions, vel, gain, pan=0.0):
        for b in range(bars[0], bars[1] + 1):
            for p in positions:
                v = vel * (1.2 if p == 0 else 1.0)
                self.hit(kind, b * self.bar_len + p * self.beat, v, pan, gain)

    def render_wind(self, gain, center=420.0):
        n = self.track.n
        spec = np.fft.rfft(self.rng.normal(0, 1, n))
        f = np.fft.rfftfreq(n, 1 / SR)
        band = np.exp(-0.5 * (np.log2(np.maximum(f, 1) / center) / 0.9) ** 2)
        noise = np.fft.irfft(spec * band, n)
        noise /= np.max(np.abs(noise))
        t = _t(n)
        lfo = 0.55 + 0.45 * np.sin(2 * np.pi * t * 3 / (n / SR)) * np.sin(2 * np.pi * t * 5 / (n / SR) + 1.3)
        self.track.add(0, noise * lfo, -0.3, gain)
        self.track.add(0, np.roll(noise, n // 3) * lfo[::-1], 0.3, gain)

    def finish(self, name, rt=3.0, wet=0.32):
        buf = reverb(self.track.buf, rt, wet, self.rng, self.s.get("brightness", 3500.0))
        write_ogg(master(buf, self.s.get("loudness", -19.0)), name)


# ---------------------------------------------------------------- 曲目

ALL = (0, 31)
BODY = (4, 27)


def track_menu():
    c = Composer({"seed": 11, "bpm": 66, "root": 50, "scale": AEOLIAN, "prog": [0, 5, 2, 6, 0, 5, 3, 4], "sevenths": True})
    c.render_pad(strings, 0, 0.22, ALL, 0.5)
    c.render_bass(cello, -1, 0.30, (2, 29), [(0, 0, 3.8)])
    c.render_arp(celesta, 1, 0.13, (4, 15), [0, 2, 1, 3, 2, 4, 3, 1], 0.5, 0.45)
    c.render_arp(harp, 0, 0.16, (16, 27), [0, 1, 2, 3, 4, 3, 2, 1], 0.5, 0.45)
    c.render_melody(piano, 1, 0.42, 0.1, vel=0.7)
    c.finish("menu", 3.6, 0.38)


def track_stone():
    c = Composer({"seed": 21, "bpm": 62, "root": 45, "scale": MINOR_PENTA, "prog": [0, 0, 3, 2, 0, 3, 1, 0], "brightness": 2800.0})
    c.render_wind(0.05)
    c.render_pad(hum, 0, 0.16, ALL, 0.45, 0.3)
    c.render_bass(warm_pad, -1, 0.22, ALL, [(0, 0, 4.0)], 0.6)
    c.render_arp(kalimba, 1, 0.16, (4, 27), [0, None, 2, None, 1, None, 3, None], 0.5, 0.5, 0.4)
    c.render_arp(marimba, 0, 0.12, (16, 23), [0, 2, 1, 2], 1.0, 0.45)
    c.render_perc("frame", (8, 27), [0, 2.5], 0.6, 0.28)
    c.render_perc("shaker", (12, 27), [1, 3], 0.4, 0.12, 0.3)
    c.render_melody(flute, 1, 0.34, -0.1, vel=0.7)
    c.finish("era_stone", 3.2, 0.34)


def track_alchemy():
    c = Composer({"seed": 31, "bpm": 72, "root": 50, "scale": DORIAN, "prog": [0, 6, 0, 3, 0, 6, 4, 0]})
    c.render_bass(cello, -2, 0.18, ALL, [(0, 0, 4.0)], 0.5)  # 主音持续低音
    c.render_bass(cello, -1, 0.12, ALL, [(0, 2, 4.0)], 0.4)  # 五度
    c.render_arp(lute, 0, 0.22, (2, 29), [0, 1, 2, 3, 2, 1, 2, 1], 0.5, 0.55)
    c.render_perc("frame", (8, 27), [0, 1.5, 2], 0.5, 0.22)
    c.render_perc("wood", (16, 23), [3.5], 0.35, 0.08, 0.4)
    c.render_melody(recorder, 1, 0.30, 0.15, vel=0.72)
    c.render_pad(strings, 0, 0.08, (16, 27), 0.4)
    c.finish("era_alchemy", 3.0, 0.36)


def track_modern():
    c = Composer({"seed": 41, "bpm": 76, "root": 53, "scale": IONIAN, "prog": [0, 5, 3, 4, 0, 5, 1, 4]})
    c.render_pad(strings, 0, 0.16, ALL, 0.45)
    c.render_bass(pizz, -1, 0.30, (2, 29), [(0, 0, 1), (2, 2, 1)], 0.6)
    c.render_arp(piano, 0, 0.17, (4, 27), [0, 2, 1, 2, 0, 2, 1, 2], 0.5, 0.45, 0.25)
    c.render_bass(cello, -1, 0.16, (16, 27), [(0, 0, 4.0)], 0.5)
    c.render_melody(piano, 1, 0.40, 0.12, vel=0.72)
    c.finish("era_modern", 2.8, 0.33)


def track_electro():
    c = Composer({"seed": 51, "bpm": 84, "root": 52, "scale": AEOLIAN, "prog": [0, 5, 2, 6, 0, 5, 3, 4], "sevenths": True})
    c.render_pad(warm_pad, 0, 0.17, ALL, 0.5)
    c.render_bass(sub_bass, -1, 0.30, (2, 29), [(0, 0, 0.45), (1, 0, 0.45), (2, 0, 0.45), (2.5, 0, 0.3), (3, 2, 0.45)], 0.55)
    c.render_arp(synth_pluck, 1, 0.13, (4, 27), [0, 2, 3, 1, 4, 2, 3, 1], 0.5, 0.5)
    c.render_perc("kick", (8, 27), [0, 2], 0.55, 0.30)
    c.render_perc("shaker", (8, 27), [0.5, 1.5, 2.5, 3.5], 0.5, 0.10, 0.25)
    c.render_melody(e_piano, 1, 0.36, -0.1, vel=0.72)
    c.finish("era_electro", 2.6, 0.30)


def track_rare_earth():
    c = Composer({"seed": 61, "bpm": 78, "root": 48, "scale": LYDIAN, "prog": [0, 1, 5, 4, 0, 1, 3, 4], "brightness": 5000.0})
    c.render_pad(warm_pad, 1, 0.15, ALL, 0.45, 0.7)
    c.render_bass(warm_pad, -1, 0.20, ALL, [(0, 0, 4.0)], 0.55)
    c.render_arp(e_piano, 1, 0.10, (4, 27), [0, 2, 4, 3, 5, 3, 4, 2, 0, 2, 4, 3, 5, 4, 3, 1], 0.25, 0.4, 0.6)
    c.render_perc("hat", (8, 27), [0.5, 1.5, 2.5, 3.5], 0.5, 0.10, 0.3)
    c.render_perc("kick", (12, 27), [0], 0.5, 0.22)
    c.render_melody(glock, 2, 0.24, 0.2, vel=0.7)
    c.render_arp(celesta, 2, 0.06, (16, 27), [None, None, 4, None, None, 5, None, None], 0.5, 0.4, 0.7)
    c.finish("era_rare_earth", 3.8, 0.40)


def track_atomic():
    c = Composer({"seed": 71, "bpm": 90, "root": 42, "scale": AEOLIAN, "prog": [0, 5, 6, 4, 0, 5, 3, 6], "brightness": 4200.0})
    c.render_pad(warm_pad, 1, 0.17, ALL, 0.5, 0.7)
    c.render_bass(sub_bass, -1, 0.34, (2, 29), [(b * 0.5, 0, 0.3) for b in range(8)], 0.5)
    c.render_arp(synth_pluck, 1, 0.11, (4, 27), [0, 3, 1, 4, 2, 5, 1, 3, 0, 4, 2, 5, 1, 3, 2, 4], 0.25, 0.45, 0.65)
    c.render_perc("kick", (8, 27), [0, 2], 0.6, 0.30)
    c.render_perc("hat", (8, 27), [i * 0.5 + 0.25 for i in range(8)], 0.45, 0.08, -0.3)
    c.render_melody(bell, 2, 0.22, 0.1, legato=1.0, vel=0.65)
    c.finish("era_atomic", 3.4, 0.36)


def _stinger(name, notes, pad_notes, seconds, rt):
    """notes: [(时刻, 乐器, midi, 时长, 力度, 声像, 增益)]"""
    rng = np.random.default_rng(sum(map(ord, name)))
    tr = Track(int(seconds * SR), loop=False)
    for t, inst, m, dur, vel, pan, gain in notes:
        tr.add(t, inst(midi_hz(m), dur, vel, rng), pan, gain)
    for t, inst, m, dur, vel, pan, gain in pad_notes:
        tr.add(t, inst(midi_hz(m), dur, vel, rng), pan, gain)
    buf = reverb(tr.buf, rt, 0.42, rng, 4500.0)
    buf = master(buf, -17.0)
    n = buf.shape[1]
    fade = int(1.5 * SR)
    buf[:, n - fade:] *= np.linspace(1, 0, fade) ** 2
    write_ogg(buf, name)


def track_stingers():
    # 时代跃迁：D 大调分解和弦上行两个八度，弦乐与钟落在主和弦上
    up = [62, 66, 69, 74, 78, 81, 86]
    notes = [(i * 0.13, celesta, m, 0.5, 0.65 + i * 0.04, -0.4 + i * 0.13, 0.32) for i, m in enumerate(up)]
    notes += [(i * 0.13, harp, m - 12, 0.6, 0.6, 0.3 - i * 0.1, 0.25) for i, m in enumerate(up[:5])]
    notes += [(0.95, bell, 86, 3.0, 0.7, 0.0, 0.2), (0.95, piano, 50, 3.0, 0.7, 0.0, 0.35), (0.95, piano, 57, 3.0, 0.6, 0.0, 0.3)]
    pads = [(0.9, strings, m, 3.2, 0.55, p, 0.2) for m, p in ((62, -0.5), (66, 0.0), (69, 0.5), (74, 0.2))]
    pads += [(0.9, cello, 38, 3.2, 0.6, 0.0, 0.28)]
    _stinger("stinger_era", notes, pads, 7.5, 3.5)

    # 元素发现：钟琴三和弦上行，最后一声高钟
    notes = [(i * 0.11, glock, m, 1.5, 0.6 + i * 0.06, -0.3 + i * 0.2, 0.3) for i, m in enumerate([76, 79, 83, 88])]
    notes += [(0.5, soft_bell, 95, 2.5, 0.5, 0.2, 0.18)]
    pads = [(0.3, warm_pad, m, 2.2, 0.5, p, 0.16) for m, p in ((64, -0.4), (71, 0.4), (76, 0.0))]
    _stinger("stinger_discovery", notes, pads, 5.0, 3.0)


TRACKS = {
    "menu": track_menu,
    "era_stone": track_stone,
    "era_alchemy": track_alchemy,
    "era_modern": track_modern,
    "era_electro": track_electro,
    "era_rare_earth": track_rare_earth,
    "era_atomic": track_atomic,
    "stingers": track_stingers,
}

if __name__ == "__main__":
    names = sys.argv[1:] or list(TRACKS)
    for nm in names:
        TRACKS[nm]()
