# Baked speech

The guide's voice is baked ahead of time (same pipeline as XRVision). The game only plays files: no runtime TTS on Quest or PC.

- **What gets baked:** every `say(...)` literal, content `intro` / `greeting` / `level_done` / `completion` / `farewell` / `title` / `turn_to` / `arrive`, and lists in `content/voice/speech.tts`. Format strings split at `%s`: `"Find the %s!"` plays "find the" + "cup".
- **Bake:** `python tools/bake_speech.py` (macOS: `python3`). Install once: `python -m pip install -r tools/requirements.txt`. Windows uses SAPI, macOS `say`; voices are set in `speech.tts`.
- **Editor:** the `speech_baker` plugin rebakes on save; wait for **Speech: ready** before running or exporting.
- **Check:** `--check` fails when stale; `python tools/test.py` runs it, and `tests/speech_test.gd` checks every line resolves.
- Commit `content/voice/generated/` (OGGs + `index.json`). An unbaked line logs `[Speech] Unbaked text` and stays silent.
- New spoken text outside a `say(...)` literal or the lists above → add it to `lines` in `speech.tts`.
