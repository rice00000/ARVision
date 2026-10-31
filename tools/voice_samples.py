"""Bakes one line in several Kokoro voices, to choose Onion's voice.
Run from the project folder:  python3 tools/voice_samples.py
Writes voice_samples/<voice>.wav next to the project (not inside it)."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))
from speech_backend import kokoro_synthesizer

LINE = "Oh. You can see me? Good. I've been making rather a lot of noise."
VOICES = ["af_heart", "af_bella", "af_nicole", "af_sky", "bf_emma", "bf_isabella", "am_michael", "bm_george"]
OUT = Path(__file__).resolve().parents[2] / "voice_samples"
OUT.mkdir(exist_ok=True)
for name in VOICES:
    kokoro_synthesizer({"voice": name})(LINE, OUT / (name + ".wav"))
    print("made", OUT / (name + ".wav"))
