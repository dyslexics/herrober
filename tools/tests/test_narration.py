"""Austauschvertrag und echter Audioimport, ohne einen Sprachdienst aufzurufen."""
import copy
import json
from pathlib import Path
import shutil
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import narration as n


@pytest.fixture(scope="module")
def manifest():
    return n.make_manifest()


@pytest.fixture
def delivery(tmp_path, manifest):
    root = tmp_path / "repo"
    (root / "Content/Audio").mkdir(parents=True)
    for source in n.SOURCES:
        shutil.copy2(n.ROOT / source, root / source)
    for name in ["index.json", "tafel-37.json", "tafel-37.m4a"]:
        shutil.copy2(n.ROOT / "Content/Audio" / name, root / "Content/Audio" / name)
    incoming = tmp_path / "incoming"
    incoming.mkdir()
    shutil.copy2(n.ROOT / "Content/Audio/tafel-37.m4a", incoming / "audio.m4a")
    job = next(j for j in manifest["jobs"] if j["id"] == "tafel-37")
    old = n.read_json(n.ROOT / "Content/Audio/tafel-37.json")
    data = {"schema_version": 1, "manifest_sha256": manifest["sha256"],
            "producer": {"provider": "existing-bundle-fixture", "model": "no-synthesis", "voice": old["voice"],
                         "usage_rights": "Existing app recording reused only for import validation"},
            "recordings": [{"job_id": job["id"], "job_sha256": job["sha256"], "audio": "audio.m4a",
                            "words": [{"token_id": t["id"], "start_ms": w["t"], "end_ms": w["t"] + w["d"]}
                                      for t, w in zip(job["tokens"], old["words"])]}]}
    mpath, dpath = tmp_path / "manifest.json", incoming / "delivery.json"
    n.write_json(mpath, manifest)
    n.write_json(dpath, data)
    return root, mpath, dpath, data


def test_export_covers_sources_and_existing_players(manifest):
    assert manifest == n.make_manifest()
    assert len({j["id"] for j in manifest["jobs"]}) == len(manifest["jobs"])
    legacy = [j for j in manifest["jobs"] if j["target"]["kind"] != "supplement"]
    assert len(legacy) == 87
    for job in legacy:
        meta = n.read_json(n.ROOT / "Content/Audio" / (job["id"] + ".json"))
        assert job["segments"] == meta["segments"]
    categories = {j["category"] for j in manifest["jobs"]}
    assert {"fibel", "ueber", "vorsatz", "tabellen", "fragen", "bildaufgaben", "menufuehrer"} <= categories
    assert {j["language"] for j in manifest["jobs"]} == {"de-AT", "fr-FR", "en-US"}
    for job in manifest["jobs"]:
        assert job["tokens"]
        covered = {(t["segment"], i) for t in job["tokens"] for i in range(t["a"], t["e"])}
        for si, segment in enumerate(job["segments"]):
            assert all((si, i) in covered for i, c in enumerate(segment["text"]) if c.isalnum())


def test_french_original_and_german_pronunciation():
    seg = [{"seite": 0, "block": 0, "item": -1, "text": "Dîner etc.", "nr": ""}]
    de = n.make_job("x", "x", "x", "de-AT", seg, {})
    fr = n.make_job("x", "x", "x", "fr-FR", seg, {})
    assert de["spoken_text"] == "Dinee et cetera"
    assert fr["spoken_text"] == "Dîner etc."
    assert n.text_key("Dîner", "de-AT") != n.text_key("Dîner", "fr-FR")


def test_unknown_source_field_requires_explicit_rule(tmp_path):
    (tmp_path / "Content").mkdir()
    for source in n.SOURCES:
        shutil.copy2(n.ROOT / source, tmp_path / source)
    path = tmp_path / n.SOURCES[1]
    data = n.read_json(path); data["neuer_lesetext"] = "Darf nicht fehlen"
    n.write_json(path, data)
    with pytest.raises(ValueError, match="Nicht klassifiziert"):
        n.make_manifest(tmp_path)


def test_validate_import_and_repeat_are_safe(delivery):
    root, mpath, dpath, _ = delivery
    before = n.tree_hash(root / "Content/Audio")
    n.process(root, mpath, dpath, partial=True, apply=False)
    assert n.tree_hash(root / "Content/Audio") == before
    report = n.process(root, mpath, dpath, partial=True, apply=True)
    assert n.tree_hash(Path(report["backup"])) == before
    after = n.tree_hash(root / "Content/Audio")
    index = n.read_json(root / "Content/Audio/narration-index.json")
    key = n.text_key("Armleuchter.", "de-AT")
    assert index["entries"][key]["segment"] == 1
    assert index["entries"][key]["stem"] == "tafel-37"
    n.process(root, mpath, dpath, partial=True, apply=True)
    assert n.tree_hash(root / "Content/Audio") == after
    assert len(list((root / "build/narration-backups").iterdir())) == 1


def test_supplement_import_registers_exact_text(delivery, manifest):
    root, mpath, dpath, data = delivery
    job = next(j for j in manifest["jobs"] if j["target"]["kind"] == "supplement"
               and j["segments"][0]["text"] == "Armleuchter" and j["language"] == "de-AT")
    # Ein echtes bereits vorhandenes Wort ausschneiden; keine Synthese und keine geratenen Zeiten.
    sample = dpath.parent / "word.wav"
    n.subprocess.run(["ffmpeg", "-v", "error", "-i", str(dpath.parent / "audio.m4a"),
                      "-ss", "3.125", "-t", "0.625", "-c:a", "pcm_s16le", str(sample)], check=True)
    duration = n.probe(sample)
    data["recordings"] = [{"job_id": job["id"], "job_sha256": job["sha256"], "audio": "word.wav",
                           "words": [{"token_id": 0, "start_ms": 0, "end_ms": duration}]}]
    n.write_json(dpath, data)
    n.process(root, mpath, dpath, partial=True, apply=True)
    index = n.read_json(root / "Content/Audio/narration-index.json")
    entry = index["entries"][n.text_key("Armleuchter", "de-AT")]
    assert entry["supplement"] is True
    assert entry["stem"] == job["target"]["stem"]
    assert (root / "Content/Audio" / (entry["stem"] + ".m4a")).is_file()


@pytest.mark.parametrize("failure", ["stale", "duplicate", "unknown", "hash", "order", "missing_word", "negative", "float", "outside", "overlap", "path", "corrupt"])
def test_bad_delivery_does_not_touch_audio(delivery, failure):
    root, mpath, dpath, data = delivery
    before = n.tree_hash(root / "Content/Audio")
    r = data["recordings"][0]
    if failure == "stale": data["manifest_sha256"] = "old"
    if failure == "duplicate": data["recordings"].append(copy.deepcopy(r))
    if failure == "unknown": r["job_id"] = "unknown"
    if failure == "hash": r["job_sha256"] = "old"
    if failure == "order": r["words"][0]["token_id"] = 1
    if failure == "missing_word": r["words"].pop()
    if failure == "negative": r["words"][0]["start_ms"] = -1
    if failure == "float": r["words"][0]["start_ms"] = 0.5
    if failure == "outside": r["words"][-1]["end_ms"] = 99999999
    if failure == "overlap": r["words"][1]["start_ms"] = 200
    if failure == "path": r["audio"] = "../escape.m4a"
    if failure == "corrupt": (dpath.parent / "audio.m4a").write_bytes(b"not audio")
    n.write_json(dpath, data)
    with pytest.raises((ValueError, n.subprocess.CalledProcessError)):
        n.process(root, mpath, dpath, partial=True, apply=True)
    assert n.tree_hash(root / "Content/Audio") == before
    assert not (root / "build/narration-backups").exists()


def test_full_import_rejects_incomplete_delivery(delivery):
    root, mpath, dpath, _ = delivery
    with pytest.raises(ValueError, match="Aufnahmen fehlen"):
        n.process(root, mpath, dpath, partial=False, apply=True)


def test_changed_source_rejected(delivery):
    root, mpath, dpath, _ = delivery
    path = root / n.SOURCES[1]
    data = n.read_json(path); data["begriffe"][0]["text"] += " Neuer Satz."
    n.write_json(path, data)
    with pytest.raises(ValueError, match="Textstand"):
        n.process(root, mpath, dpath, partial=True, apply=True)


def test_fraktur_abbreviation_mapping():
    seg = [{"seite": 0, "block": 0, "item": -1, "text": "Teller etc.", "nr": ""}]
    j = n.make_job("x", "x", "x", "de-AT", seg, {})
    words = n.timings(j, {"words": [{"token_id": 0, "start_ms": 0, "end_ms": 300},
                                   {"token_id": 1, "start_ms": 400, "end_ms": 900}]}, 1000)
    assert words[1]["ae"] < words[1]["e"]  # etc. → ꝛc.


def test_symlink_outside_delivery_rejected(tmp_path):
    folder = tmp_path / "delivery"; folder.mkdir()
    target = tmp_path / "audio.m4a"; target.write_bytes(b"private")
    (folder / "audio.m4a").symlink_to(target)
    with pytest.raises(ValueError): n.safe_file(folder, "audio.m4a")


@pytest.mark.parametrize("bad", [None, [], {"schema_version": True}, {"recordings": None}])
def test_malformed_delivery_rejected_cleanly(bad):
    with pytest.raises(ValueError): n.delivery_shape(bad)


def test_schema_rejects_unknown_fields(delivery):
    _, _, _, data = delivery
    data["recordings"][0]["words"][0]["guessed"] = True
    with pytest.raises(ValueError, match="unbekannte Felder"): n.delivery_shape(data)
