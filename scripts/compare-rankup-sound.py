"""
Prints a per-10ms RMS + detected-pitch timeline for one or two WAV files
(pure Python stdlib only, uses the Goertzel algorithm - no numpy/scipy).

Used while tuning sound/rank-up-promotion.wav / .ogg against a reference
clip's envelope and pitch, without ever needing to redistribute the
reference audio itself.

Note: input files must be WAV (PCM). To analyze an mp3/ogg, first decode it,
e.g. via VLC:
  vlc -I dummy input.mp3 --sout "#transcode{acodec=s16l,channels=1,samplerate=22050}:std{access=file,mux=wav,dst=output.wav}" vlc://quit

Usage:
  python compare-rankup-sound.py <file.wav> [reference.wav]
"""
import math
import struct
import sys
import wave

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi_to_name(m):
    return f"{NOTE_NAMES[m % 12]}{m // 12 - 1}"


def midi_to_freq(m):
    return 440.0 * (2.0 ** ((m - 69) / 12.0))


def goertzel_power(samples, sr, freq):
    n = len(samples)
    k = int(0.5 + (n * freq) / sr)
    w = (2.0 * math.pi / n) * k
    coeff = 2.0 * math.cos(w)
    s_prev = s_prev2 = 0.0
    for x in samples:
        s = x + coeff * s_prev - s_prev2
        s_prev2 = s_prev
        s_prev = s
    return s_prev2 ** 2 + s_prev ** 2 - coeff * s_prev * s_prev2


def load_mono(path):
    with wave.open(path, "rb") as wf:
        sr = wf.getframerate()
        nch = wf.getnchannels()
        raw = wf.readframes(wf.getnframes())
    samples = struct.unpack("<%dh" % (len(raw) // 2), raw)
    if nch == 2:
        mono = [(samples[i] + samples[i + 1]) / 2 / 32768.0 for i in range(0, len(samples), 2)]
    else:
        mono = [s / 32768.0 for s in samples]
    return sr, mono


def analyze(path, label, max_seconds=1.0, note_range=range(48, 97)):
    sr, mono = load_mono(path)
    win_n = int(sr * 0.03)
    hop_n = int(sr * 0.01)
    candidates = [(m, midi_to_freq(m)) for m in note_range]

    print(f"=== {label} ({path}) ===")
    i = 0
    prev_note = None
    while i + win_n <= len(mono) and i / sr <= max_seconds:
        window = mono[i:i + win_n]
        rms = math.sqrt(sum(s * s for s in window) / len(window))
        n = len(window)
        windowed = [window[j] * (0.5 - 0.5 * math.cos(2 * math.pi * j / (n - 1))) for j in range(n)]

        best_m, best_power = None, -1.0
        for m, f in candidates:
            p = goertzel_power(windowed, sr, f)
            if p > best_power:
                best_power = p
                best_m = m

        note = midi_to_name(best_m) if rms > 0.02 else "-"
        marker = ">>" if note != prev_note and note != "-" else "  "
        print(f"t={i / sr:5.3f}s  rms={rms:5.3f}  {marker} {note}")
        prev_note = note
        i += hop_n
    print()


def main():
    if len(sys.argv) not in (2, 3):
        print("Usage: python compare-rankup-sound.py <file.wav> [reference.wav]")
        sys.exit(1)

    analyze(sys.argv[1], "FILE")
    if len(sys.argv) == 3:
        analyze(sys.argv[2], "REFERENCE")


if __name__ == "__main__":
    main()
