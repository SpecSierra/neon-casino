#!/usr/bin/env python3
"""Synthesize the short UI sounds (16-bit mono WAV). Run from the repo root.

Voiced warm rather than bright: triangle/sine bodies an octave lower than a typical UI beep,
a sine sub-octave under every tone, soft attacks, and every sound goes through a gentle
low-pass (2 poles, ~3.4 kHz) plus a low-shelf lift, so phone speakers get body, not fizz.
"""
import math, struct, wave, random
RATE = 44100
LP_HZ = 3400

def lowpass(x, hz=LP_HZ, poles=2):
    a = 1 - math.exp(-2 * math.pi * hz / RATE)
    for _ in range(poles):
        y, acc = [], 0.0
        for s in x:
            acc += (s - acc) * a
            y.append(acc)
        x = y
    return x

def warm(x):
    """Low-pass, add a low-shelf (the signal's own <200 Hz band, +6 dB), normalise to -1 dBFS."""
    x = lowpass(x)
    low = lowpass(x, 200, 1)
    x = [s + l for s, l in zip(x, low)]
    peak = max(1e-9, max(abs(s) for s in x))
    g = min(1.0, 0.89 / peak) if peak > 0.89 else 1.0
    return [s * g for s in x]

def write(name, samples, level=1.0):
    s = warm(samples)
    with wave.open("qml/sounds/%s.wav" % name, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * level)) * 30000)) for v in s))

def osc(shape, ph):
    if shape == "sine": return math.sin(2 * math.pi * ph)
    if shape == "tri": return 4 * abs((ph % 1.0) - 0.5) - 1
    if shape == "soft":     # rounded square: tanh-clipped sine, fewer harsh partials than a square
        return math.tanh(2.2 * math.sin(2 * math.pi * ph)) / math.tanh(2.2)
    return 1.0 if (ph % 1.0) < 0.5 else -1.0

def tone(freq, dur, vol=0.5, shape="tri", decay=8.0, sweep=0.0, sub=0.5, attack=0.004):
    """One note: body + a sine one octave down (sub), exponential decay, short fade-in."""
    out, ph, phs = [], 0.0, 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        f = freq * (1 + sweep * t)
        ph += f / RATE; phs += f / 2 / RATE
        v = osc(shape, ph) + sub * math.sin(2 * math.pi * phs)
        env = math.exp(-decay * t) * min(1.0, t / attack)
        out.append(v * vol * env)
    rel = int(RATE * 0.006)                      # tiny release: no click at the end
    for i in range(min(rel, len(out))):
        out[-1 - i] *= i / rel
    return out

def thump(freq, dur, vol, decay, noise=0.0, drop=0.6):
    """A pitched knock: a sine that falls in pitch (kick-like) with an optional dull noise layer."""
    out, ph, acc = [], 0.0, 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        f = freq * (1 - drop * min(1.0, t / dur))
        ph += f / RATE
        acc += (random.uniform(-1, 1) - acc) * 0.08          # pre-filtered noise
        out.append((math.sin(2 * math.pi * ph) + noise * acc * 4) * vol * math.exp(-decay * t) * min(1.0, t / 0.002))
    return out

def mix(*parts):
    n = max(len(p) for p in parts); return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]
def seq(*parts): return [s for p in parts for s in p]
random.seed(3)

write("click", thump(520, 0.05, 0.6, 70, noise=0.15))
write("card", thump(420, 0.08, 0.45, 40, noise=0.7, drop=0.3))
write("tick", thump(380, 0.035, 0.55, 90, noise=0.1))
write("reel", tone(262, 0.11, 0.45, "soft", 26, sweep=-1.0, sub=0.5))
write("win", seq(tone(330, 0.09, 0.4), tone(440, 0.09, 0.4), tone(660, 0.26, 0.42, decay=6)))
write("bigwin", seq(*[tone(f, 0.075, 0.4, decay=4) for f in (262, 330, 392, 523, 392, 523, 659)], tone(784, 0.6, 0.45, decay=3, sub=0.7)))
write("lose", tone(247, 0.4, 0.5, "soft", 5, sweep=-0.8, sub=0.5))
write("perk", mix(tone(220, 0.65, 0.3, "sine", 3, sweep=1.5, sub=0.6), tone(330, 0.65, 0.25, "tri", 3, sweep=1.5, sub=0.3)))
write("bust", seq(tone(294, 0.22, 0.45, "soft", 3, sub=0.6), tone(247, 0.22, 0.45, "soft", 3, sub=0.6), tone(196, 0.7, 0.5, "soft", 2.5, sub=0.7)))

# roulette: a seamless 1 s rolling loop, a fret clack and the final drop into a pocket
def ballroll():
    n = RATE
    noise = [random.uniform(-1, 1) for _ in range(n)]
    out, acc = [], 0.0
    for i in range(n):
        acc += (noise[i] - acc) * 0.03                  # darker rumble than before
        wob = 0.7 + 0.3 * math.sin(2 * math.pi * 9 * i / n)
        out.append(acc * 4.5 * wob)
    f = 1200                                             # crossfade the ends: no seam
    for i in range(f):
        a = i / f
        out[i] = out[i] * a + out[n - f + i] * (1 - a)
    return out[:n - f]
write("ballroll", ballroll())
write("clack", thump(700, 0.035, 0.6, 180, noise=0.4, drop=0.2))
write("pocket", seq(thump(300, 0.07, 0.7, 70, noise=0.4), thump(420, 0.06, 0.4, 100, noise=0.3)))
