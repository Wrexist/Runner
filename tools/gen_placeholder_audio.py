#!/usr/bin/env python3
"""Generate gentle placeholder audio (WAV, pure stdlib) for every theme.

These are PLACEHOLDERS: soft synthesized chimes so the game has sound before
real CC0 .ogg files are sourced (docs/ASSET_MANIFEST.md). AudioManager prefers
the .ogg path from theme.json and falls back to the same path with a .wav
extension, so dropping real .ogg files in later needs zero theme.json edits.

Design constraints (Kids Category): soft attack, low peak level, no harsh or
buzzer-like tones. The "miss" sound is a quiet, sympathetic two-note "aw".

Usage:  python3 tools/gen_placeholder_audio.py   (writes themes/*/audio/*.wav)
"""
import math
import struct
import wave
from pathlib import Path

SR = 22050          # plenty for soft chimes; keeps files small
PEAK = 0.45         # global ceiling (~ -7 dBFS) — gentle on small ears

ROOT = Path(__file__).resolve().parent.parent


def note(freq, dur, gain=1.0, attack=0.01, release=0.08, harmonics=((1, 1.0), (2, 0.25)),
         detune=0.0, vibrato=0.0):
    """One soft tone as a list of floats. Envelope: linear attack, exp-ish decay."""
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        # Envelope: attack ramp, then decay toward release at the tail.
        env = min(1.0, t / attack) if attack > 0 else 1.0
        env *= math.exp(-2.2 * t / dur)
        tail = dur - t
        if tail < release:
            env *= tail / release
        f = freq * (1.0 + vibrato * math.sin(2 * math.pi * 5.0 * t))
        s = 0.0
        for mult, amp in harmonics:
            s += amp * math.sin(2 * math.pi * f * mult * t)
            if detune:
                s += amp * 0.6 * math.sin(2 * math.pi * f * mult * (1 + detune) * t)
        out.append(s * env * gain)
    return out


def mix(buf, src, at):
    """Mix src into buf starting at second `at` (extends buf as needed)."""
    start = int(at * SR)
    end = start + len(src)
    if end > len(buf):
        buf.extend([0.0] * (end - len(buf)))
    for i, v in enumerate(src):
        buf[start + i] += v


def write_wav(path, buf):
    peak = max(1e-9, max(abs(v) for v in buf))
    scale = PEAK / peak
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * scale)) * 32767))
                          for v in buf)
        w.writeframes(frames)
    print(f"  wrote {path.relative_to(ROOT)}  ({len(buf)/SR:.2f}s)")


def semitone(base, n):
    return base * (2 ** (n / 12.0))


# Per-theme character: a transpose + timbre tweak so each world sounds distinct.
THEMES = {
    "forest": dict(transpose=0,  detune=0.0,   vibrato=0.0),
    "space":  dict(transpose=-2, detune=0.006, vibrato=0.0),
    "ocean":  dict(transpose=1,  detune=0.0,   vibrato=0.012),
}

C5 = 523.25


def gen_sfx(theme_dir, p):
    tr, det, vib = p["transpose"], p["detune"], p["vibrato"]
    f = lambda n: semitone(C5, n + tr)

    # gem: one bright-but-soft ping (G5) with a quiet sparkle a fifth up.
    buf = []
    mix(buf, note(f(7), 0.18, 1.0, detune=det, vibrato=vib), 0.0)
    mix(buf, note(f(14), 0.12, 0.25, detune=det), 0.02)
    write_wav(theme_dir / "gem.wav", buf)

    # rescue: a happy little ascending arpeggio C-E-G.
    buf = []
    for i, (st, at) in enumerate([(0, 0.0), (4, 0.09), (7, 0.18)]):
        mix(buf, note(f(st), 0.22, 1.0 - i * 0.15, detune=det, vibrato=vib), at)
    write_wav(theme_dir / "rescue.wav", buf)

    # miss: a quiet, sympathetic falling minor third (E4 -> C#4). Never harsh.
    buf = []
    mix(buf, note(f(-8), 0.22, 0.6, attack=0.03, detune=det), 0.0)
    mix(buf, note(f(-11), 0.30, 0.5, attack=0.03, detune=det), 0.16)
    write_wav(theme_dir / "miss.wav", buf)


def gen_music(theme_dir, p):
    """A gentle 16s pentatonic arpeggio loop over I-vi-IV-V. Every voice has its
    own attack/release inside the grid, so the loop point is click-free."""
    tr, det, vib = p["transpose"], p["detune"], p["vibrato"]
    f = lambda n: semitone(C5, n + tr)
    chords = [           # (chord tones in semitones from C, bass offset)
        ([0, 4, 7], -24),    # C
        ([-3, 0, 4], -27),   # Am
        ([-7, -3, 0], -31),  # F
        ([-5, -1, 2], -29),  # G
    ]
    buf = []
    beat = 0.5           # 120 bpm, eighth-note arpeggio = 0.25s steps
    chord_len = 4.0      # 2 bars per chord -> 16s total
    for ci, (tones, bass) in enumerate(chords):
        base = ci * chord_len
        # Soft pad: root + fifth, enveloped per chord (no loop-edge click).
        mix(buf, note(f(tones[0]), chord_len, 0.16, attack=0.6, release=0.8,
                      harmonics=((1, 1.0),), detune=det), base)
        mix(buf, note(f(tones[0] + 7), chord_len, 0.10, attack=0.8, release=0.8,
                      harmonics=((1, 1.0),), detune=det), base)
        mix(buf, note(f(bass + 12), chord_len, 0.12, attack=0.5, release=0.8,
                      harmonics=((1, 1.0),), detune=det), base)
        # Arpeggio: eighth notes cycling chord tones up an octave, gentle taper.
        pattern = [tones[0], tones[1], tones[2], tones[1] + 12,
                   tones[2], tones[1], tones[2] + 12, tones[1]]
        for step in range(16):
            st = pattern[step % len(pattern)] + (12 if step % 8 >= 4 else 0)
            mix(buf, note(f(st), 0.22, 0.30, attack=0.012, release=0.06,
                          detune=det, vibrato=vib), base + step * 0.25 * (beat / 0.25))
    # Trim/pad to exactly 16s so AudioManager's loop_end lands on the grid.
    want = int(16.0 * SR)
    buf = (buf + [0.0] * want)[:want]
    write_wav(theme_dir / "music.wav", buf)


def main():
    for theme, p in THEMES.items():
        d = ROOT / "themes" / theme / "audio"
        print(f"{theme}:")
        gen_sfx(d, p)
        gen_music(d, p)


if __name__ == "__main__":
    main()
