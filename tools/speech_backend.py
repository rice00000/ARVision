"""Native desktop speech -> PCM WAV. No Godot or cache logic lives here."""
import subprocess
import sys


def synthesizer(voices, platform=sys.platform):
    if "kokoro" in voices:
        return kokoro_synthesizer(voices["kokoro"])
    if platform not in ("darwin", "win32"):
        raise RuntimeError("Speech authoring supports Windows and macOS. Cached audio plays everywhere.")
    settings = voices[platform]
    if platform == "darwin":
        def write(text, path):
            subprocess.run(["/usr/bin/say", "-v", settings["name"], "-r", str(settings["rate"]),
                            "--file-format=WAVE", "--data-format=LEI16@22050", "-o", str(path), "-f", "-"],
                           input=text, text=True, check=True, capture_output=True)
        return write
    try:
        from win32com.client import Dispatch
    except ImportError:
        raise RuntimeError("Install the Windows adapter: python -m pip install -r tools/requirements.txt") from None
    voice = Dispatch("SAPI.SpVoice")
    tokens = list(voice.GetVoices())
    matches = [token for token in tokens if token.GetDescription().startswith(settings["name"])]
    if not matches:
        raise RuntimeError("Voice not installed. Available: " + ", ".join(t.GetDescription() for t in tokens))
    voice.Voice = matches[0]
    voice.Rate = settings["rate"]
    voice.AllowAudioOutputFormatChangesOnNextSet = False

    def write(text, path):
        stream = Dispatch("SAPI.SpFileStream")
        stream.Format.Type = 22 # SAFT22kHz16BitMono
        stream.Open(str(path), 3) # SSFMCreateForWrite
        try:
            voice.AudioOutputStream = stream
            voice.Speak(text, 16) # SVSFIsNotXML: authored text is always literal.
        finally:
            stream.Close()
    return write


def kokoro_synthesizer(settings):
    """Kokoro-82M (open weights, Apache 2.0; https://huggingface.co/hexgrad/Kokoro-82M).
    Same voice on every computer. Needs: python3 -m pip install kokoro soundfile, and espeak-ng.
    settings: {"voice": "af_heart", "speed": 1.0}; the voice's first letter picks the accent
    (a = American, b = British English)."""
    try:
        import numpy
        import soundfile
        from kokoro import KPipeline
    except ImportError:
        raise RuntimeError("Install Kokoro: python3 -m pip install kokoro soundfile (and brew install espeak-ng)") from None
    voice = settings["voice"]
    pipeline = KPipeline(lang_code=voice[0], repo_id="hexgrad/Kokoro-82M")

    def write(text, path):
        parts = [audio for _, _, audio in pipeline(text, voice=voice, speed=settings.get("speed", 1.0))]
        if not parts:
            raise RuntimeError("Kokoro made no audio for: " + text)
        soundfile.write(str(path), numpy.concatenate([numpy.asarray(part) for part in parts]), 24000, format="WAV")
    return write
