"""Original deterministic pentatonic music and effects; no external sound samples."""
import array
import math
import random
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets/audio"
OUT.mkdir(parents=True, exist_ok=True)


def save(name, samples):
    peak = max(1.0, max(abs(x) for x in samples))
    pcm = array.array("h", (int(max(-1, min(1, x / peak)) * 26000) for x in samples))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())


def note(buffer, start, duration, midi, gain=0.2, soft=False):
    freq = 440 * 2 ** ((midi - 69) / 12)
    for n in range(int(duration * RATE)):
        t = n / RATE
        env = min(1, t / 0.015) * math.exp(-t * (2.4 if soft else 4.2))
        env *= min(1, (duration - t) / 0.08)
        tone = math.sin(2 * math.pi * freq * t)
        tone += (0.08 if soft else 0.19) * math.sin(2 * math.pi * freq * 2 * t)
        buffer[(int(start * RATE) + n) % len(buffer)] += tone * env * gain


# 16 bars, 96 BPM. Notes wrap into the start for a seamless reverb-free loop.
beat = 60 / 96
music = [0.0] * int(beat * 64 * RATE)
melody = [76, 79, 81, 79, 76, 74, 72, 74, 76, 79, 84, 81, 79, 76, 74, 72,
          74, 76, 79, 76, 74, 72, 69, 72, 74, 76, 79, 81, 79, 74, 72, 72]
chords = [(48, 55, 60), (45, 52, 57), (41, 48, 53), (43, 50, 55)]
for bar in range(16):
    chord = chords[(bar // 2) % 4]
    for j in range(4):
        note(music, (bar * 4 + j) * beat, 1.8, chord[j % 3] + 12, 0.11, True)
    note(music, bar * 4 * beat, 2.1, chord[0], 0.10, True)
for i, pitch in enumerate(melody):
    note(music, i * 2 * beat, 1.1, pitch, 0.22)
save("music", music)

for name, tones in {"fish": [84, 88], "win": [72, 76, 79, 84], "tap": [79], "land": [60]}.items():
    samples = [0.0] * int((len(tones) * 0.12 + 0.4) * RATE)
    for i, tone in enumerate(tones):
        note(samples, i * 0.12, 0.35, tone, 0.36 if name != "land" else 0.16, True)
    save(name, samples)

jump = []
for i in range(int(RATE * 0.24)):
    t = i / RATE
    jump.append(math.sin(2 * math.pi * (300 * t + 800 * t * t)) * math.sin(math.pi * t / 0.24) * 0.34)
save("jump", jump)
rng = random.Random(731)
splash = []
smoothed = 0.0
for i in range(int(RATE * 0.6)):
    t = i / RATE
    smoothed = smoothed * 0.75 + rng.uniform(-1, 1) * 0.25
    splash.append((smoothed * 0.5 + math.sin(2 * math.pi * (140 * t - 75 * t * t)) * 0.15) * math.exp(-t * 8) * min(1, t / 0.015))
save("splash", splash)
print("Created original music loop and six effects.")
