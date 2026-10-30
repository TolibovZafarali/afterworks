#!/usr/bin/env python3
"""Rebuild the bundled, original interface tones using a deterministic synthesizer."""
import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "Afterworks" / "Resources"
OUTPUT.mkdir(parents=True, exist_ok=True)
SAMPLE_RATE = 44100


def render(name, duration, voices):
    frames = bytearray()
    for index in range(int(SAMPLE_RATE * duration)):
        time = index / SAMPLE_RATE
        value = 0.0
        for start, frequency, length, gain in voices:
            elapsed = time - start
            if 0 <= elapsed <= length:
                attack = min(1, elapsed / 0.008)
                release = min(1, (length - elapsed) / 0.08)
                envelope = attack * release * math.exp(-elapsed * 7 / length)
                fundamental = math.sin(2 * math.pi * frequency * elapsed)
                overtone = 0.18 * math.sin(2 * math.pi * frequency * 2.01 * elapsed)
                value += gain * envelope * (fundamental + overtone)
        sample = int(max(-0.9, min(0.9, value)) * 32767)
        frames.extend(struct.pack("<h", sample))
    with wave.open(str(OUTPUT / name), "wb") as sound:
        sound.setnchannels(1)
        sound.setsampwidth(2)
        sound.setframerate(SAMPLE_RATE)
        sound.writeframes(frames)


render("placement.wav", 0.16, [(0, 392.0, 0.15, 0.18), (0.006, 587.33, 0.13, 0.08)])
render("delivery.wav", 0.5, [(0, 523.25, 0.24, 0.12), (0.12, 659.25, 0.32, 0.12)])
render("era.wav", 1.4, [(0, 261.63, 1.1, 0.12), (0.16, 392.0, 1.1, 0.11), (0.35, 523.25, 1.0, 0.10), (0.55, 659.25, 0.8, 0.07)])
print(OUTPUT)
