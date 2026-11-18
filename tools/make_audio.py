#!/usr/bin/env python3
"""Generates all music and sound effects for Tales of a Mercenary.

Everything is synthesized (square/saw/noise, SNES-ish chiptune flavour) so the
repo has no third-party audio. Run from the repo root:

    python3 tools/make_audio.py

Writes 16-bit mono WAV files into audio/.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
rng = np.random.default_rng(1986)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def t_arr(dur):
    return np.arange(int(SR * dur)) / SR


def square(freq, dur, duty=0.5):
    t = t_arr(dur)
    if np.ndim(freq):
        phase = np.cumsum(freq) / SR
    else:
        phase = freq * t
    return np.where((phase % 1.0) < duty, 1.0, -1.0)


def saw(freq, dur):
    t = t_arr(dur)
    phase = freq * t
    return 2.0 * (phase % 1.0) - 1.0


def tri(freq, dur):
    t = t_arr(dur)
    phase = freq * t
    return 2.0 * np.abs(2.0 * (phase % 1.0) - 1.0) - 1.0


def noise(dur, step=1):
    n = int(SR * dur)
    base = rng.uniform(-1, 1, n // step + 1)
    return np.repeat(base, step)[:n]


def env(n, attack=0.002, decay=None, curve=2.0):
    """Linear attack, then power-curve decay to zero over the rest."""
    a = max(1, int(SR * attack))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    rest = n - a
    if rest > 0:
        e[a:] = np.linspace(1, 0, rest) ** curve
    return e


def lowpass(x, k):
    if k <= 1:
        return x
    kernel = np.ones(k) / k
    return np.convolve(x, kernel, mode="same")


def crush(x, levels=24):
    """Small bit-crush for that sample-chip grit."""
    return np.round(x * levels) / levels


def write(name, x, vol=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * vol
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", path, f"{len(x) / SR:.2f}s")


# ---------------------------------------------------------------- SFX

def sweep(f0, f1, dur, shape="square", duty=0.5):
    n = int(SR * dur)
    f = np.geomspace(f0, f1, n)
    phase = np.cumsum(f) / SR
    if shape == "square":
        return np.where((phase % 1.0) < duty, 1.0, -1.0)
    if shape == "tri":
        return 2.0 * np.abs(2.0 * (phase % 1.0) - 1.0) - 1.0
    return 2.0 * (phase % 1.0) - 1.0


def sfx():
    # Pistol: snappy noise crack + falling square
    d = 0.12
    x = noise(d, 2) * env(int(SR * d), 0.001, curve=3) * 0.8
    x += sweep(900, 180, d, "square", 0.3) * env(int(SR * d), 0.001, curve=2) * 0.5
    write("shoot", crush(x), 0.55)

    # Uzi: shorter, brighter
    d = 0.07
    x = noise(d, 1) * env(int(SR * d), 0.001, curve=3)
    x += sweep(1400, 400, d, "square", 0.25) * env(int(SR * d), 0.001, curve=2) * 0.4
    write("uzi", crush(x), 0.4)

    # Shotgun: big low boom
    d = 0.32
    x = lowpass(noise(d, 3), 3) * env(int(SR * d), 0.001, curve=2.5)
    x += sweep(220, 50, d, "square", 0.5) * env(int(SR * d), 0.001, curve=2) * 0.6
    write("shotgun", crush(x), 0.7)

    # Enemy hit: tiny tick
    d = 0.05
    x = noise(d, 4) * env(int(SR * d), 0.001, curve=2)
    x += sweep(600, 300, d, "square") * env(int(SR * d), 0.001) * 0.3
    write("hit", crush(x), 0.35)

    # Enemy dies: crunchy falling pop
    d = 0.18
    x = noise(d, 6) * env(int(SR * d), 0.001, curve=2) * 0.7
    x += sweep(500, 80, d, "square", 0.4) * env(int(SR * d), 0.001, curve=1.5) * 0.6
    write("die", crush(x, 12), 0.45)

    # XP pickup: rising blip
    d = 0.08
    x = sweep(1200, 2400, d, "square", 0.25) * env(int(SR * d), 0.001, curve=1.5)
    write("gem", x, 0.25)

    # Item pickup (pizza / magnet / case)
    notes = [72, 76, 79, 84]
    parts = []
    for n in notes:
        dd = 0.06
        parts.append(square(midi(n), dd, 0.25) * env(int(SR * dd), 0.001, curve=1))
    write("pickup", np.concatenate(parts), 0.4)

    # Level up fanfare
    seq = [(69, 0.08), (73, 0.08), (76, 0.08), (81, 0.08), (76, 0.08), (81, 0.30)]
    parts = []
    for n, dd in seq:
        a = square(midi(n), dd, 0.5) * 0.5 + square(midi(n + 12), dd, 0.125) * 0.3
        parts.append(a * env(int(SR * dd), 0.002, curve=0.7))
    write("levelup", np.concatenate(parts), 0.5)

    # Explosion
    d = 0.7
    x = lowpass(noise(d, 8), 4) * env(int(SR * d), 0.002, curve=2.2)
    x += sweep(120, 30, d, "square") * env(int(SR * d), 0.002, curve=3) * 0.5
    write("explode", crush(x, 16), 0.8)

    # Player hurt
    d = 0.2
    x = sweep(300, 90, d, "square", 0.5) * env(int(SR * d), 0.001, curve=1)
    x += noise(d, 10) * env(int(SR * d), 0.001, curve=3) * 0.4
    write("hurt", crush(x), 0.5)

    # Menu select
    d = 0.06
    x = square(midi(84), d, 0.25) * env(int(SR * d), 0.001, curve=1)
    write("select", x, 0.3)

    # Confirm
    parts = [square(midi(n), 0.05, 0.25) * env(int(SR * 0.05), 0.001, curve=1) for n in (79, 91)]
    write("confirm", np.concatenate(parts), 0.35)

    # Throw (grenade)
    d = 0.15
    x = sweep(300, 900, d, "tri") * env(int(SR * d), 0.01, curve=1)
    write("throw", x, 0.35)

    # Boss warning siren
    d = 1.2
    t = t_arr(d)
    f = 500 + 250 * np.sin(2 * np.pi * 2.5 * t)
    phase = np.cumsum(f) / SR
    x = np.where((phase % 1.0) < 0.5, 1.0, -1.0) * env(len(t), 0.02, curve=0.5)
    write("siren", x, 0.4)

    # Game over jingle (sad descending)
    seq = [(64, 0.18), (63, 0.18), (62, 0.18), (61, 0.6)]
    parts = []
    for n, dd in seq:
        a = square(midi(n), dd, 0.5) * 0.5 + tri(midi(n - 12), dd) * 0.5
        parts.append(a * env(int(SR * dd), 0.003, curve=1))
    write("gameover", np.concatenate(parts), 0.5)


# ---------------------------------------------------------------- MUSIC

BPM = 120
BEAT = 60.0 / BPM
BAR = BEAT * 4


def place(buf, start_s, sig):
    i = int(start_s * SR)
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


def music():
    # Am - F - C - G, synthwave style, 8 bars (16 s), loops cleanly.
    chords = [
        (45, [69, 72, 76]),  # Am
        (41, [65, 69, 72]),  # F
        (48, [67, 72, 76]),  # C
        (43, [67, 71, 74]),  # G
    ]
    bars = 8
    total = bars * BAR
    buf = np.zeros(int(total * SR) + SR)

    eighth = BEAT / 2
    six = BEAT / 4

    for b in range(bars):
        root, arp = chords[b % 4]
        bar_t = b * BAR
        # Bass: driving eighths, root / octave pattern, sawtooth with a lowpass
        for k in range(8):
            n = root if k % 2 == 0 else root + 12
            if k == 7 and b % 4 == 3:
                n = root + 7
            s = saw(midi(n), eighth * 0.95) * 0.55 + square(midi(n), eighth * 0.95, 0.5) * 0.25
            s = lowpass(s, 6) * env(len(s), 0.003, curve=0.6)
            place(buf, bar_t + k * eighth, s * 0.55)
        # Arpeggio: 16th note pulse-wave arp, up the chord
        pattern = [0, 1, 2, 1, 0, 1, 2, 3] * 2
        for k in range(16):
            idx = pattern[k]
            n = arp[idx] if idx < 3 else arp[0] + 12
            s = square(midi(n), six * 0.8, 0.25) * env(int(SR * six * 0.8), 0.001, curve=1.5)
            place(buf, bar_t + k * six, s * (0.16 if b < 4 else 0.12))
        # Drums
        for beat in range(4):
            bt = bar_t + beat * BEAT
            # kick on every beat
            d = 0.18
            kick = sweep(150, 40, d, "tri") * env(int(SR * d), 0.001, curve=2)
            place(buf, bt, kick * 0.9)
            # snare on 2 & 4
            if beat % 2 == 1:
                d = 0.16
                sn = noise(d, 2) * env(int(SR * d), 0.001, curve=2.5) * 0.45
                sn += sweep(260, 160, d, "tri") * env(int(SR * d), 0.001, curve=3) * 0.3
                place(buf, bt, sn)
            # closed hats on off-beats
            d = 0.035
            hat = noise(d, 1) * env(int(SR * d), 0.0005, curve=3) * 0.12
            place(buf, bt + eighth, hat)
        # fill on last bar
        if b == bars - 1:
            for k in range(4):
                d = 0.1
                sn = noise(d, 2) * env(int(SR * d), 0.001, curve=2.5) * 0.35
                place(buf, bar_t + 3 * BEAT + k * six, sn)

    # Lead melody over the second half
    lead = [
        [76, None, 74, 72, None, 71, 72, None],
        [69, None, None, 72, None, None, 77, 76],
        [76, None, 74, 72, None, 67, None, 72],
        [74, None, None, None, 71, None, 67, None],
    ]
    for li, bar_notes in enumerate(lead):
        bar_t = (4 + li) * BAR
        k = 0
        while k < 8:
            n = bar_notes[k]
            if n is None:
                k += 1
                continue
            length = 1
            while k + length < 8 and bar_notes[k + length] is None:
                length += 1
            dur = eighth * length * 0.95
            t = t_arr(dur)
            vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.15, 0, 1)
            f = midi(n) * vib
            s = square(f, dur, 0.5) * 0.6 + square(f * 2.003, dur, 0.25) * 0.15
            e = env(len(s), 0.01, curve=0.4)
            place(buf, bar_t + k * eighth, s * e * 0.22)
            # simple echo
            place(buf, bar_t + k * eighth + BEAT * 0.75, s * e * 0.07)
            k += length

    buf = buf[: int(total * SR)]
    # soft clip
    buf = np.tanh(buf * 1.2)
    write("music", buf, 0.6)


if __name__ == "__main__":
    sfx()
    music()
