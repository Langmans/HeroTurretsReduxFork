"""
Generates sound/rank-up-promotion.wav: a short original "tu-tu-tuuu" trumpet
fanfare used for the turret rank-up notification sound.

This does NOT use any copyrighted game audio - it renders a General MIDI
trumpet patch from a hand-built MIDI file, then brightens/normalizes/gates
the result in pure Python (stdlib only, no numpy/scipy).

Requirements (not bundled with the mod, install locally to re-run this):
  - VLC (with its built-in FluidSynth MIDI decoder)
  - A General MIDI soundfont (.sf2), e.g. "GeneralUser GS" - freely
    redistributable, see https://schristiancollins.com/generaluser

Usage:
  python generate-rankup-sound.py <path-to-soundfont.sf2>

This writes sound/rank-up-promotion.wav (relative to the mod root).
"""
import math
import os
import shutil
import struct
import subprocess
import sys
import wave

SR = 44100
MOD_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MID_PATH = os.path.join(MOD_ROOT, "scripts", "_rankup_tmp.mid")
WAV_TMP_PATH = os.path.join(MOD_ROOT, "scripts", "_rankup_tmp.wav")
OUT_PATH = os.path.join(MOD_ROOT, "sound", "rank-up-promotion.ogg")

VLC_CANDIDATES = [
    r"C:\Program Files\VideoLAN\VLC\vlc.exe",
    r"C:\Program Files (x86)\VideoLAN\VLC\vlc.exe",
    "/usr/bin/vlc",
    "/usr/local/bin/vlc",
    "/snap/bin/vlc",
]


def vlq(n):
    """Encode an integer as a MIDI variable-length quantity."""
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    return bytes(reversed(out))


def write_midi(path):
    ppq = 1000  # ticks per quarter note
    tempo = 1_000_000  # microseconds per quarter note -> 1 tick == 1 ms

    events = bytearray()

    def add(delta_ticks, data):
        events.extend(vlq(delta_ticks))
        events.extend(data)

    add(0, bytes([0xFF, 0x51, 0x03]) + tempo.to_bytes(3, "big"))
    add(0, bytes([0xC0, 56]))  # program change, channel 0, GM Trumpet

    C5, G5 = 72, 79

    # "tu" (80ms) - "tu" (80ms, 10ms gap) - "tuuu" (450ms, higher, 20ms gap)
    add(0, bytes([0x90, C5, 127]))
    add(80, bytes([0x80, C5, 0]))
    add(10, bytes([0x90, C5, 127]))
    add(80, bytes([0x80, C5, 0]))
    add(20, bytes([0x90, G5, 127]))
    add(450, bytes([0x80, G5, 0]))

    add(100, bytes([0xFF, 0x2F, 0x00]))  # end of track

    track = b"MTrk" + struct.pack(">I", len(events)) + bytes(events)
    header = b"MThd" + struct.pack(">IHHH", 6, 0, 1, ppq)

    with open(path, "wb") as f:
        f.write(header)
        f.write(track)


def find_vlc():
    on_path = shutil.which("vlc") or shutil.which("cvlc")
    if on_path:
        return on_path
    for c in VLC_CANDIDATES:
        if os.path.isfile(c):
            return c
    raise FileNotFoundError("VLC not found - install it or edit VLC_CANDIDATES")


def render_midi_to_wav(vlc_path, sf2_path, mid_path, wav_path):
    if os.path.exists(wav_path):
        os.remove(wav_path)
    sout = (
        "#transcode{acodec=s16l,channels=2,samplerate=%d}:"
        "std{access=file,mux=wav,dst=%s}" % (SR, wav_path)
    )
    subprocess.run(
        [vlc_path, "-I", "dummy", "--soundfont", sf2_path, mid_path,
         "--sout", sout, "vlc://quit"],
        check=True,
    )


def transcode_wav_to_ogg(vlc_path, wav_path, ogg_path):
    if os.path.exists(ogg_path):
        os.remove(ogg_path)
    sout = (
        "#transcode{acodec=vorb,ab=160,channels=2,samplerate=%d}:"
        "std{access=file,mux=ogg,dst=%s}" % (SR, ogg_path)
    )
    subprocess.run(
        [vlc_path, "-I", "dummy", wav_path, "--sout", sout, "vlc://quit"],
        check=True,
    )


def onepole_lowpass(signal, cutoff_hz):
    rc = 1.0 / (2 * math.pi * cutoff_hz)
    dt = 1.0 / SR
    alpha = dt / (rc + dt)
    out = [0.0] * len(signal)
    prev = 0.0
    for i, x in enumerate(signal):
        prev = prev + alpha * (x - prev)
        out[i] = prev
    return out


def gate(samples, nch, start_ms, end_ms, fade_ms=6):
    """Force near-silence in [start_ms, end_ms), with short fades to avoid clicks."""
    start = int(SR * start_ms / 1000) * nch
    end = int(SR * end_ms / 1000) * nch
    fade = int(SR * fade_ms / 1000) * nch
    for i in range(start, min(end, len(samples))):
        if i < start + fade:
            g = 1.0 - (i - start) / fade
        elif i > end - fade:
            g = (end - i) / fade
        else:
            g = 0.0
        samples[i] = int(samples[i] * max(0.0, min(1.0, g)))
    return samples


def post_process(wav_path):
    with wave.open(wav_path, "rb") as wf:
        params = wf.getparams()
        raw = wf.readframes(wf.getnframes())
    nch = params.nchannels
    samples = list(struct.unpack("<%dh" % (len(raw) // 2), raw))

    # brightness: add back a high-shelf (signal - lowpass) for more "cartoony" clarity
    floats = [s / 32768.0 for s in samples]
    lp = onepole_lowpass(floats, 2800)
    brightened = [floats[i] + 0.9 * (floats[i] - lp[i]) for i in range(len(floats))]

    # normalize to near full scale
    peak = max(abs(x) for x in brightened) or 1.0
    gain = 0.92 / peak
    samples = [max(-32767, min(32767, int(x * gain * 32767))) for x in brightened]

    # gate silence into the "tu - tu - tuuu" pauses (matched against the reference clip's envelope)
    samples = gate(samples, nch, 68, 98)
    samples = gate(samples, nch, 172, 228)

    with wave.open(wav_path, "wb") as wf:
        wf.setparams(params)
        wf.writeframes(struct.pack("<%dh" % len(samples), *samples))


def main():
    if len(sys.argv) != 2:
        print("Usage: python generate-rankup-sound.py <path-to-soundfont.sf2>")
        sys.exit(1)
    sf2_path = sys.argv[1]

    write_midi(MID_PATH)
    vlc_path = find_vlc()
    try:
        render_midi_to_wav(vlc_path, sf2_path, MID_PATH, WAV_TMP_PATH)
        post_process(WAV_TMP_PATH)
        transcode_wav_to_ogg(vlc_path, WAV_TMP_PATH, OUT_PATH)
    finally:
        for tmp in (MID_PATH, WAV_TMP_PATH):
            if os.path.exists(tmp):
                os.remove(tmp)

    print("done:", OUT_PATH)


if __name__ == "__main__":
    main()
