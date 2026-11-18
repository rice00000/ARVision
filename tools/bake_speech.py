"""Bake the guide's speech on Windows/macOS; --watch keeps the Godot editor nonblocking."""
from pathlib import Path
from contextlib import contextmanager
import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import time
from speech_backend import synthesizer

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "content/voice/speech.tts"
OUT = ROOT / "content/voice/generated"
INDEX = OUT / "index.json"
STRING = r'"(?:\\.|[^"\\])*"'
LITERAL = re.compile(r'#[^\n]*|' + STRING)
# Everything that reaches the voice: say / instruct, Onion.line and the hub's spoken labels (Megan, Nov 18: every
# written line baked).
SAY = re.compile(r'(?<!func )\b(?:say|instruct|Onion\.line)\(')
# A script's own helper that speaks its text (the hub's _label, Turn to fit's _say): its calls count too.
HELPERS = ("_say", "_label")
SPEAKS = r'(?m)^func {}\(.*:\n(?:(?:\t.*)?\n)*?\t.*\b(?:Onion\.line|Events\.say|say)\('
LOCAL = re.compile(r'(?<![\w.&"])([a-z_][a-z0-9_]*)\b')
# A constant a say(...) call names (say(WELCOME), Onion.line(WorkshopController.LEFT_EARLY), TOUR_LINES[step]):
# the texts in its declaration, wherever it is declared.
CONST = re.compile(r'(?m)^\s*const\s+([A-Z][A-Z0-9_]*)\b')
NAME = re.compile(r'\b(?:[A-Z][A-Za-z0-9]*\.)?([A-Z][A-Z0-9_]+)\b')
FIELDS = re.compile(r'(?m)^\s*(?:@export\s+var\s+)?(intro|greeting|farewell|title|turn_to|arrive)\s*(?::=|=)\s*(' + STRING + ')')


def decode(token):
    return json.loads(token.replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t"))


def said(source, constants=None):
    """Every string literal inside a say(...) call, format strings included, and every constant line it names."""
    own = {match[1] for match in CONST.finditer(source)}

    def resolve(name):   # this script's own constant first (two scripts may use one name for different things)
        return declared(source, name) if name in own else (constants or {}).get(name, [])

    calls = list(SAY.finditer(source))
    for helper in HELPERS:
        if re.search(SPEAKS.format(helper), source):
            calls += list(re.finditer(r'(?<!func )(?<![\w.])' + helper + r'\(', source))
    for call in calls:
        depth, at, words = 1, call.end(), []
        while depth and at < len(source):
            literal = LITERAL.match(source, at)
            if literal:
                if literal[0].startswith('"'):
                    yield decode(literal[0])
                at = literal.end()
                continue
            depth += {"(": 1, ")": -1}.get(source[at], 0)
            words.append(source[at])
            at += 1
        arguments = "".join(words)
        for name in NAME.findall(arguments) if constants else []:
            yield from resolve(name)
        # A local that holds the line (var other_line := {&"butterflies": BUTTERFLIES_BACK, ...}): its texts too.
        for local in set(LOCAL.findall(arguments)) if constants else []:
            match = re.search(rf'(?m)^\s*var\s+{local}\b.*$', source)
            if match:
                for name in NAME.findall(match[0]):
                    yield from resolve(name)


def word_list(entry):
    """The string literals in the declaration of NAME in a script: file.gd:NAME."""
    path, name = entry.split(":")
    return declared((ROOT / path).read_text(encoding="utf-8"), name)


def declared(source, name):
    """The string literals in the declaration of [name] in [source], over as many lines as its brackets take. In a
    dictionary, only the values (not its keys)."""
    found = re.search(rf'(?m)^.*\b(?:const|var)\s+{name}\b[^=\n]*=', source)   # after the type (Array[String])
    if found is None:
        return []
    start = found.end()
    depth, at, seen = 0, start, False
    while at < len(source):
        literal = LITERAL.match(source, at)
        if literal:
            at = literal.end()
            continue
        char = source[at]
        if char in "([{":
            depth, seen = depth + 1, True
        elif char in ")]}":
            depth -= 1
        elif char == "\n" and depth <= 0:
            break
        at += 1
        if seen and depth == 0:
            break
    declaration = re.sub(r'&?' + STRING + r'\s*:', ':', source[start:at])   # drop dictionary keys
    return [decode(token) for token in re.findall(STRING, declaration)]


def collect(config):
    phrases = {}

    def add(text):
        for part in re.split(r'%[-+0-9.]*[sdf]', text):
            key = " ".join(re.sub(r"(?:[^\w']|_)+", " ", part.lower()).split())
            if key:
                phrases.setdefault(key, part.strip())

    for text in config["lines"] + config["names"]:
        add(text)
    for entry in config["word_lists"]:
        for text in word_list(entry):
            add(text)
    sources = [path for directory in config["say_sources"] for path in sorted((ROOT / directory).rglob("*.gd"))]
    constants = {}   # NAME -> every text a constant of that name holds (two scripts may share a name)
    for path in sources:
        source = path.read_text(encoding="utf-8")
        for match in CONST.finditer(source):
            constants.setdefault(match[1], []).extend(declared(source, match[1]))
    for path in sources:
        source = path.read_text(encoding="utf-8")
        for text in said(source, constants):
            add(text)
        for match in FIELDS.finditer(source):
            add(decode(match[2]))
    for directory in config["resource_roots"]:
        for path in sorted((ROOT / directory).rglob("*.tres")):
            for match in FIELDS.finditer(path.read_text(encoding="utf-8")):
                add(decode(match[2]))
    return dict(sorted(phrases.items()))


def digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


@contextmanager
def bake_lock():
    """Serialize an editor bake and a simultaneous CLI build."""
    path = ROOT / ".godot/speech-bake.lock"
    path.parent.mkdir(exist_ok=True)
    with path.open("a+b") as lock:
        if lock.tell() == 0:
            lock.write(b"0")
            lock.flush()
        lock.seek(0)
        if sys.platform == "win32":
            import msvcrt
            msvcrt.locking(lock.fileno(), msvcrt.LK_LOCK, 1)
        else:
            import fcntl
            fcntl.flock(lock, fcntl.LOCK_EX)
        yield # Closing the file releases the lock on both OSes.


def bake(check, report):
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    phrases = collect(config)
    # Shared cache keys deliberately exclude the host OS. Checking out teammates'
    # files never regenerates them merely because their computer has another voice.
    settings = {"format": "ogg-vorbis-mono-q0-v1", "voices": config["voices"]}
    clips = {key: "res://content/voice/generated/" + digest([settings, text])[:24] + ".ogg"
             for key, text in phrases.items()}
    pending = [key for key, path in clips.items() if not (ROOT / path[6:]).exists()]
    fingerprint = digest([settings, phrases])
    previous = json.loads(INDEX.read_text(encoding="utf-8")) if INDEX.exists() else {}
    fresh = not pending and previous.get("fingerprint") == fingerprint
    if check:
        if not fresh:
            raise RuntimeError("Speech is stale. Run python3 tools/bake_speech.py (Windows: python).")
        return
    OUT.mkdir(parents=True, exist_ok=True)
    if pending:
        import soundfile as sf
        speak = synthesizer(config["voices"])
        for done, key in enumerate(pending, 1):
            report(state="generating", done=done, total=len(pending))
            descriptor, name = tempfile.mkstemp(prefix=".speech-", suffix=".tmp", dir=OUT)
            os.close(descriptor)
            temporary = Path(name)
            encoded = temporary.with_suffix(".ogg.tmp")
            try:
                speak(phrases[key], temporary)
                audio, rate = sf.read(temporary, dtype="float32", always_2d=True)
                if len(audio) == 0:
                    raise RuntimeError("Empty speech audio: " + phrases[key])
                # Maximum Vorbis compression; WAV is only a synthesis intermediate.
                sf.write(encoded, audio.mean(axis=1), rate, format="OGG", subtype="VORBIS", compression_level=1.0)
                encoded.replace(ROOT / clips[key][6:])
            finally:
                temporary.unlink(missing_ok=True)
                encoded.unlink(missing_ok=True)
    if not fresh:
        write_json(INDEX, {"fingerprint": fingerprint, "clips": clips})
        active = {Path(path).name for path in clips.values()}
        for path in OUT.iterdir():
            if path.suffix in (".wav", ".ogg") and path.name not in active:
                path.unlink()
                path.with_suffix(path.suffix + ".import").unlink(missing_ok=True)
    report(state="ready", generated=len(pending), total=len(clips))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--status", type=Path)
    args = parser.parse_args()

    def report(**value):
        if args.status:
            write_json(args.status, value)

    def run():
        try:
            with bake_lock():
                bake(args.check, report)
            return 0
        except Exception as error:
            message = getattr(error, "stderr", None) or str(error)
            report(state="error", message=message)
            print("SPEECH_ERROR:", message, file=sys.stderr, flush=True)
            return 1

    if not args.watch:
        return run()
    # Only this worker scans source files. Godot reads a tiny status file.
    seen, due = None, 0.0
    while True:
        config = json.loads(CONFIG.read_text(encoding="utf-8"))
        sources = [CONFIG, *(p for d in config["say_sources"] for p in (ROOT / d).rglob("*.gd")),
                   *(p for d in config["resource_roots"] for p in (ROOT / d).rglob("*.tres"))]
        stamp = [(str(p), p.stat().st_mtime_ns) for p in sorted(sources)]
        if stamp != seen:
            seen, due = stamp, time.monotonic() + 0.8
            report(state="waiting")
        if due and time.monotonic() >= due:
            run()
            due = 0.0
        time.sleep(0.25)


if __name__ == "__main__":
    sys.exit(main())
