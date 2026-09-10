#!/usr/bin/env python3
"""Anbieterneutraler Text-/Audioaustausch. Erzeugt selbst keine Sprache.

export → externe Vertonung → validate → import. Siehe docs/VERTONUNG.md.
"""
import argparse
from collections import Counter
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

from audio_text import TOKEN, gesprochen_tokens, segmente_kapitel, teile
from fraktur import frakturisieren

ROOT = Path(__file__).resolve().parents[1]
VERSION = 1
SOURCES = ("Content/content.json", "Content/lernen.json")
SPOKEN = {"titel", "untertitel", "autoren", "ort_jahr", "neu", "de_neu", "fr",
          "ort_datum", "einleitung", "hinweis", "erklaerung", "text", "anwendung",
          "zitat", "frage", "antworten", "beschreibung", "formen", "dauer", "nummer"}
EXCLUDED = {
    "alt": "zweite Schriftansicht desselben Texts", "de_alt": "zweite Schriftansicht desselben Texts",
    "falsch": "absichtlich falsche Fibel-Antwort, kein Aussprachevorbild",
    "gross": "Alphabet wird als eigene Sprecheinheit exportiert",
    "klein": "Alphabet wird als eigene Sprecheinheit exportiert",
    "unsicher": "interne Transkriptionsnotiz; Quelle vor Korrektur prüfen",
    "slug": "Kennung", "id": "Kennung", "kapitel": "Kennung", "menu": "Bildkennung",
    "art": "Darstellungsart", "typ": "Darstellungsart", "stufe": "Übungsstufe",
    "sprache": "Sprachkennung", "nr": "Referenznummer", "seite": "Seitenreferenz",
    "bild": "Bilddatei", "bild_alt": "Bildmetadatum", "einband": "Bilddatei",
    "titelblatt": "Bilddatei", "url": "Linkziel",
}
LANGS = {"de": "de-AT", "fr": "fr-FR", "en": "en-US"}
# Vollständiges Unicode-Alphabet einschließlich ſ, ž, ꝛ und Bruchzeichen.
NARRATION_TOKEN = re.compile(TOKEN.pattern.split("|[A-Za-z", 1)[0] +
                             r"|ꝛc\.|[^\W\d_]+(?:['’][^\W\d_]+)*|\d+|\s+|.", re.S)


def encoded(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def digest(value):
    return hashlib.sha256(encoded(value)).hexdigest()


def text_key(text, language):
    return hashlib.sha256((language + "\n" + text).encode()).hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def object_fields(value, required, optional=(), name="Objekt"):
    if not isinstance(value, dict) or not set(required) <= value.keys() or not value.keys() <= set(required) | set(optional):
        raise ValueError(f"{name}: fehlende oder unbekannte Felder")


def delivery_shape(value):
    object_fields(value, ["schema_version", "manifest_sha256", "producer", "recordings"], name="Lieferung")
    if type(value["schema_version"]) is not int:
        raise ValueError("schema_version muss eine ganze Zahl sein")
    object_fields(value["producer"], ["provider", "model", "voice", "usage_rights"], name="producer")
    if not isinstance(value["recordings"], list):
        raise ValueError("recordings muss eine Liste sein")
    for row in value["recordings"]:
        object_fields(row, ["job_id", "job_sha256", "audio", "words"], ["voice"], "Aufnahme")
        if not isinstance(row["job_id"], str) or not isinstance(row["words"], list):
            raise ValueError("job_id muss Text sein, words eine Liste")
        for word in row["words"]:
            object_fields(word, ["token_id", "start_ms", "end_ms"], name="Wortzeit")


def language(code):
    result = LANGS.get(code, code)
    if result not in LANGS.values():
        raise ValueError(f"Unbekannte Sprache: {code}")
    return result


def make_job(job_id, category, title, lang, segments, target):
    tokens = []
    spoken = []
    for si, seg in enumerate(segments):
        pieces = []
        for match in NARRATION_TOKEN.finditer(seg["text"]):
            a, e = match.span()
            display = match.group()
            normalized = display.replace("ſ", "s").replace("ꝛc.", "etc.")
            pronunciation = "".join(t[2] for t in gesprochen_tokens(normalized))
            pronunciation = {"½": "ein halb", "¼": "ein Viertel", "¾": "drei Viertel"}.get(display, pronunciation)
            is_word = any(c.isalnum() for c in display)
            # Französische Wörter erhalten keine deutschen Lautumschreibungen.
            reading = pronunciation if lang == "de-AT" else seg["text"][a:e]
            pieces.append(reading)
            if is_word:
                tokens.append({"id": len(tokens), "segment": si, "a": a, "e": e,
                               "display": seg["text"][a:e], "spoken": reading})
        spoken.append("".join(pieces))
    job = {"id": job_id, "category": category, "title": title, "language": lang,
           "target": target, "segments": segments, "spoken_text": "\n\n".join(spoken),
           "tokens": tokens}
    job["sha256"] = digest(job)
    return job


def make_manifest(root=ROOT):
    content, learning = [read_json(root / s) for s in SOURCES]
    jobs = []
    for chapter in content["kapitel"]:
        for part, segs in enumerate(teile(segmente_kapitel(chapter)), 1):
            stem = f"{chapter['slug']}-{part}"
            segments = [{"seite": si, "block": bi, "item": ii, "text": text, "nr": nr}
                        for si, bi, ii, text, nr in segs]
            jobs.append(make_job(stem, "kapitel", chapter["titel"], "de-AT", segments,
                                 {"kind": "kapitel", "key": chapter["slug"], "stem": stem,
                                  "pages": [segs[0][4], segs[-1][4]]}))
    for group in content["tafeln"]:
        for plate in group["tafeln"]:
            segments = [{"seite": 0, "block": -1, "item": -1,
                         "text": f"Tafel {plate['nr']}. {plate['titel']}", "nr": plate["seite"]}]
            segments += [{"seite": 0, "block": i, "item": -1, "text": label["de_neu"],
                          "nr": plate["seite"]} for i, label in enumerate(plate["beschriftungen"])
                         if label.get("de_neu")]
            stem = f"tafel-{plate['nr']}"
            jobs.append(make_job(stem, "tafeln", plate["titel"], "de-AT", segments,
                                 {"kind": "tafeln", "key": plate["nr"], "stem": stem}))
    for group in content["menus"]:
        for card in group["karten"]:
            segments = [{"seite": 0, "block": i, "item": -1, "text": line["neu"], "nr": ""}
                        for i, line in enumerate(card["zeilen"])]
            if not segments:
                continue
            stem = "menu-" + Path(card["bild"]).stem
            jobs.append(make_job(stem, "menus", card["titel"], language(card.get("sprache", "de")),
                                 segments, {"kind": "menus", "key": card["bild"], "stem": stem}))

    # Ein exakt gleicher Text in derselben Sprache braucht nur eine Aufnahme.
    lookup = {}
    for job in jobs:
        for si, seg in enumerate(job["segments"]):
            lookup.setdefault(text_key(seg["text"], job["language"]), (job, si))
    covered, excluded = [], []

    def add(text, lang, source, category):
        if not text.strip() or not any(c.isalnum() for c in text):
            excluded.append({"source": source, "reason": "leer oder nur Satzzeichen"})
            return
        key = text_key(text, lang)
        if key not in lookup:
            stem = "narr-" + key
            seg = {"seite": 0, "block": 0, "item": -1, "text": text, "nr": ""}
            job = make_job(stem, category, text.splitlines()[0][:100], lang, [seg],
                           {"kind": "supplement", "key": key, "stem": stem})
            jobs.append(job)
            lookup[key] = (job, 0)
        job, si = lookup[key]
        covered.append({"source": source, "job_id": job["id"], "segment": si})

    def walk(value, path, source, lang="de-AT", field="", category="buch"):
        if isinstance(value, dict):
            own_lang = language(value.get("sprache", lang))
            for k, v in value.items():
                # Menükommentare deutsch, die zitierten Zeilen in ihrer Quellsprache.
                child_lang = own_lang
                if source.endswith("lernen.json") and "sprache" in value and k != "zitat":
                    child_lang = "de-AT"
                if k == "fr":
                    child_lang = "fr-FR"
                walk(v, path + "/" + k, source, child_lang, k, category)
        elif isinstance(value, list):
            for i, v in enumerate(value):
                walk(v, path + "/" + str(i), source, lang, field, category)
        elif isinstance(value, str):
            ref = source + "#" + path
            if field in SPOKEN or field == "zeilen":
                # Zweisprachige Gang-Tabelle: zweite Spalte Französisch.
                if category == "kapitel" and "/zeilen/" in path and path.endswith("/1"):
                    parts = path.split("/")
                    if content["kapitel"][int(parts[2])]["slug"] == "capitel-03":
                        lang = "fr-FR"
                add(value, lang, ref, "tabellen" if "/zeilen/" in path and field == "zeilen" else category)
            elif field in EXCLUDED:
                excluded.append({"source": ref, "reason": EXCLUDED[field]})
            else:
                raise ValueError(f"Nicht klassifiziertes Textfeld {ref}: Exportregeln ergänzen")

    for source, data in zip(SOURCES, [content, learning]):
        for key, value in data.items():
            walk(value, "/" + key, source, category=key)
    for i, letter in enumerate(content.get("fibel", {}).get("alphabet", [])):
        text = "langes s" if letter["klein"] == "ſ" else letter["gross"] or letter["klein"]
        add(text, "de-AT", f"Content/content.json#/fibel/alphabet/{i}:spoken", "fibel")

    manifest = {"schema_version": VERSION,
                "sources": {s: hashlib.sha256((root / s).read_bytes()).hexdigest() for s in SOURCES},
                "jobs": jobs, "coverage": {"included": covered, "excluded": excluded}}
    manifest["sha256"] = digest(manifest)
    return manifest


def export(root, output):
    manifest = make_manifest(root)
    output.mkdir(parents=True, exist_ok=True)
    write_json(output / "manifest.json", manifest)
    with (output / "texts.jsonl").open("w", encoding="utf-8") as f:
        for job in manifest["jobs"]:
            f.write(json.dumps({k: job[k] for k in ["id", "sha256", "category", "language", "title", "spoken_text"]}, ensure_ascii=False) + "\n")
    sections = ["# Herr Ober! – vollständiger Sprechtext\n",
                "Generiert mit `python tools/narration.py export`. Maßgeblich: manifest.json.\n"]
    for job in manifest["jobs"]:
        sections.append(f"## {job['id']}\n\n{job['category']} · {job['language']}\n\n{job['spoken_text']}\n")
    (output / "TEXTS.md").write_text("\n".join(sections), encoding="utf-8")
    write_json(output / "delivery-template.json", {
        "schema_version": VERSION, "manifest_sha256": manifest["sha256"],
        "producer": {"provider": "REQUIRED", "model": "REQUIRED", "voice": "REQUIRED",
                     "usage_rights": "REQUIRED"}, "recordings": []})
    print(json.dumps({"jobs": len(manifest["jobs"]), "categories": dict(Counter(j["category"] for j in manifest["jobs"])),
                      "manifest_sha256": manifest["sha256"], "output": str(output)}, ensure_ascii=False))


def bundle(root, output):
    export(root, root / "narration")
    names = [*SOURCES, "Content/Audio/index.json", "LICENSE", "docs/VERTONUNG.md", "docs/VERTONUNG_PROMPT.md",
             "docs/VERTONUNG_PRUEFUNG.md", "docs/images/narration-import-playback.png",
             "tools/narration.py", "tools/audio_text.py", "tools/fraktur.py", "tools/fraktur_ausnahmen.json",
             "tools/hyph-de-1901.dic", "tools/requirements-narration.txt"]
    names += ["narration/" + name for name in ["README.md", "manifest.json", "texts.jsonl", "TEXTS.md",
                                               "delivery-template.json", "delivery.schema.json"]]
    note = ("# Herr Ober! – Übergabepaket für die Vertonung\n\n"
            "Beginne mit docs/VERTONUNG_PROMPT.md. Hier liegen die Sprechtexte, Quellen und Prüfwerkzeuge.\n"
            "Das Paket enthält keine App und keine neu erzeugten Aufnahmen. Python-Abhängigkeit: "
            "tools/requirements-narration.txt; zusätzlich ffmpeg/ffprobe.\n\n"
            "Du kannst deine Lieferung hier mit tools/narration.py validate prüfen. Zum Einbau verwende "
            "tools/narration.py import im vollständigen App-Repository https://github.com/dyslexics/herrober. "
            "Ein Import in diese Paketkopie allein aktualisiert keine iOS-App.\n")
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in sorted(names):
            entry = zipfile.ZipInfo("HerrOber-Vertonung/" + name)
            entry.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(entry, (root / name).read_bytes())
        entry = zipfile.ZipInfo("HerrOber-Vertonung/START.md")
        entry.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(entry, note.encode())
    print(f"Übergabepaket: {output} ({output.stat().st_size} Bytes)")


def safe_file(folder, name):
    if not isinstance(name, str) or not name or Path(name).is_absolute() or ".." in Path(name).parts:
        raise ValueError(f"Unzulässiger Lieferpfad: {name!r}")
    candidate = folder / name
    resolved = candidate.resolve(strict=True)
    if not resolved.is_relative_to(folder.resolve()) or candidate.is_symlink() or not resolved.is_file():
        raise ValueError(f"Datei außerhalb der Lieferung: {name}")
    return resolved


def probe(audio):
    result = subprocess.run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(audio)],
                            check=True, capture_output=True, text=True)
    info = json.loads(result.stdout)
    if sum(s["codec_type"] == "audio" for s in info["streams"]) != 1:
        raise ValueError(f"Genau eine Audiospur erforderlich: {audio.name}")
    if any(s["codec_type"] == "video" for s in info["streams"]):
        raise ValueError(f"Video in Audiodatei: {audio.name}")
    duration = float(info["format"]["duration"])
    if not math.isfinite(duration) or duration <= 0:
        raise ValueError(f"Ungültige Audiodauer: {audio.name}")
    # Tatsächliche Dekodierung, nicht nur den Containerkopf prüfen.
    subprocess.run(["ffmpeg", "-v", "error", "-xerror", "-i", str(audio), "-f", "null", "-"],
                   check=True, capture_output=True)
    return round(duration * 1000)


def timings(job, recording, duration):
    supplied = recording.get("words")
    if not isinstance(supplied, list) or len(supplied) != len(job["tokens"]):
        raise ValueError(f"{job['id']}: Wortzeiten unvollständig")
    words, previous_end = [], 0
    maps = [frakturisieren(s["text"]).map for s in job["segments"]]
    for token, timing in zip(job["tokens"], supplied):
        start, end = timing.get("start_ms"), timing.get("end_ms")
        if type(timing.get("token_id")) is not int or timing["token_id"] != token["id"]:
            raise ValueError(f"{job['id']}: falsche Token-Reihenfolge")
        if type(start) is not int or type(end) is not int or not (previous_end <= start < end <= duration):
            raise ValueError(f"{job['id']}: ungültige/überlappende Wortzeit bei Token {token['id']}")
        si, a, e = token["segment"], token["a"], token["e"]
        rest = job["segments"][si]["text"][e:].lstrip('“"»«)')
        words.append({"s": si, "a": a, "e": e, "aa": maps[si][a], "ae": maps[si][e],
                      "t": start, "d": end - start, "p": bool(rest) and rest[0] in ".!?"})
        previous_end = end
    return words


def prepare(root, manifest_path, delivery_path, staging, partial=False):
    expected = make_manifest(root)
    manifest = read_json(manifest_path)
    if manifest != expected:
        raise ValueError("Export passt nicht zum aktuellen Textstand; neu exportieren")
    delivery = read_json(delivery_path)
    delivery_shape(delivery)
    if delivery.get("schema_version") != VERSION or delivery.get("manifest_sha256") != manifest["sha256"]:
        raise ValueError("Lieferung gehört zu einem anderen Export/Schema")
    producer = delivery.get("producer", {})
    if any(not isinstance(producer.get(k), str) or not producer[k].strip() or producer[k] == "REQUIRED"
           for k in ["provider", "model", "voice", "usage_rights"]):
        raise ValueError("Anbieter, Modell, Stimme und Nutzungsangabe fehlen")
    jobs = {j["id"]: j for j in manifest["jobs"]}
    recordings = delivery.get("recordings", [])
    ids = [r.get("job_id") for r in recordings]
    if not ids or len(ids) != len(set(ids)) or not set(ids) <= jobs.keys():
        raise ValueError("Leere Lieferung, doppelte oder unbekannte Job-IDs")
    if not partial and set(ids) != jobs.keys():
        raise ValueError(f"{len(jobs) - len(ids)} Aufnahmen fehlen; Teilpaket nur mit --partial")
    index = read_json(root / "Content/Audio/index.json")
    narration_path = root / "Content/Audio/narration-index.json"
    narration = read_json(narration_path) if narration_path.exists() else {"schema_version": VERSION, "entries": {}}
    valid_keys = {text_key(s["text"], j["language"]) for j in manifest["jobs"] for s in j["segments"]}
    narration["entries"] = {k: v for k, v in narration["entries"].items() if k in valid_keys}
    receipts = []
    for number, recording in enumerate(recordings, 1):
        job = jobs[recording["job_id"]]
        if number == 1 or number % 25 == 0 or number == len(recordings):
            print(f"Prüfe Aufnahme {number}/{len(recordings)}: {job['id']}", file=sys.stderr, flush=True)
        if recording.get("job_sha256") != job["sha256"]:
            raise ValueError(f"{job['id']}: Text-Hash stimmt nicht")
        audio = safe_file(delivery_path.parent, recording.get("audio"))
        duration = probe(audio)
        words = timings(job, recording, duration)
        target = staging / (job["target"]["stem"] + ".m4a")
        subprocess.run(["ffmpeg", "-v", "error", "-xerror", "-i", str(audio), "-map", "0:a:0",
                        "-map_metadata", "-1", "-c:a", "aac", "-b:a", "96k", "-ar", "44100", "-ac", "1",
                        "-movflags", "+faststart", str(target)], check=True, capture_output=True)
        converted_duration = probe(target)
        # Keine geschätzten Wortzeiten; Konvertierung darf die Zeitbasis nicht verschieben.
        if abs(converted_duration - duration) > 100 or words[-1]["t"] + words[-1]["d"] > converted_duration:
            raise ValueError(f"{job['id']}: Zeitbasis nach Konvertierung verändert")
        voice = recording.get("voice", producer["voice"])
        if not isinstance(voice, str) or not voice.strip():
            raise ValueError("Leere Stimme")
        meta = {"voice": voice, "duration": converted_duration, "segments": job["segments"], "words": words,
                "narration_job_sha256": job["sha256"], "producer": producer}
        write_json(target.with_suffix(".json"), meta)
        t = job["target"]
        if t["kind"] == "kapitel":
            part = next(p for p in index["kapitel"][t["key"]] if p["stem"] == t["stem"])
            part["duration"] = converted_duration
        elif t["kind"] in ["tafeln", "menus"]:
            index[t["kind"]][t["key"]] = t["stem"]
        for si, segment in enumerate(job["segments"]):
            key = text_key(segment["text"], job["language"])
            narration["entries"][key] = {"stem": t["stem"], "segment": si, "text": segment["text"],
                                         "language": job["language"], "category": job["category"],
                                         "supplement": t["kind"] == "supplement"}
        receipts.append({"job_id": job["id"], "input_sha256": hashlib.sha256(audio.read_bytes()).hexdigest(),
                         "output_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                         "job_sha256": job["sha256"], "duration_ms": converted_duration})
    write_json(staging / "index.json", index)
    write_json(staging / "narration-index.json", narration)
    report = {"schema_version": VERSION, "manifest_sha256": manifest["sha256"], "producer": producer,
              "recordings": receipts, "missing": sorted(jobs.keys() - set(ids)), "partial": partial}
    write_json(staging / "narration-receipt.json", report)
    return report


def tree_hash(path):
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in path.rglob("*") if p.is_file()}


@contextmanager
def import_lock(root):
    path = root / "build/narration-import.lock"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as f:
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield


def process(root, manifest_path, delivery_path, partial, apply):
    with import_lock(root), tempfile.TemporaryDirectory(prefix="narration-", dir=root / "build") as tmp:
        staging = Path(tmp)
        audio_dir = root / "Content/Audio"
        before = tree_hash(audio_dir)
        report = prepare(root, manifest_path, delivery_path, staging, partial)
        unchanged = all((audio_dir / f.name).is_file() and f.read_bytes() == (audio_dir / f.name).read_bytes()
                        for f in staging.iterdir())
        if apply and not unchanged:
            # Erst nach vollständiger Prüfung eine komplette Austauschkopie vorbereiten.
            replacement = Path(tempfile.mkdtemp(prefix=".narration-audio-stage-", dir=root))
            try:
                shutil.copytree(audio_dir, replacement, dirs_exist_ok=True)
                for file in staging.iterdir():
                    shutil.copy2(file, replacement / file.name)
                if before != tree_hash(audio_dir) or read_json(manifest_path) != make_manifest(root):
                    raise ValueError("Inhalte während des Imports geändert; nichts übernommen")
                # Auf demselben Dateisystem sichern; kein Archiv wird gelöscht.
                backups = root / "build/narration-backups"
                backups.mkdir(exist_ok=True)
                stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
                backup = backups / stamp
                os.replace(audio_dir, backup)
                try:
                    os.replace(replacement, audio_dir)
                except BaseException:
                    os.replace(backup, audio_dir)
                    raise
                report["backup"] = str(backup)
            finally:
                if replacement.exists():
                    shutil.rmtree(replacement)
        print(json.dumps({"status": ("unchanged" if unchanged else "imported") if apply else "validated", "recordings": len(report["recordings"]),
                          "missing": len(report["missing"]), "backup": report.get("backup")}, ensure_ascii=False))
        return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    subs = parser.add_subparsers(dest="command", required=True)
    exp = subs.add_parser("export", help="Texte exportieren, keine Sprache erzeugen")
    exp.add_argument("--out", type=Path, default=Path("narration"))
    pack = subs.add_parser("bundle", help="Übergabepaket mit Texten, Prompt und Prüfwerkzeugen")
    pack.add_argument("--out", type=Path, default=Path("narration/HerrOber-Vertonung.zip"))
    for command in ["validate", "import"]:
        p = subs.add_parser(command)
        p.add_argument("--manifest", type=Path, default=Path("narration/manifest.json"))
        p.add_argument("--delivery", type=Path, required=True)
        p.add_argument("--partial", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "export":
            export(args.root.resolve(), args.out.resolve())
        elif args.command == "bundle":
            bundle(args.root.resolve(), args.out.resolve())
        else:
            process(args.root.resolve(), args.manifest.resolve(), args.delivery.resolve(), args.partial, args.command == "import")
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Vertonung: {error}\n")


if __name__ == "__main__":
    main()
