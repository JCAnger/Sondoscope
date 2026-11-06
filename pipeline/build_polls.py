#!/usr/bin/env python3
"""Construit public/polls.json à partir des fichiers 2027etmoi de pipeline/raw."""
from __future__ import annotations

import datetime as dt
import json
import pathlib
import re
import sys
import unicodedata
from zoneinfo import ZoneInfo

ROOT = pathlib.Path(__file__).resolve().parent
RAW = ROOT / "raw"
ARCHIVE = ROOT / "archive" / "polls.json"
PUBLIC = ROOT.parent / "public" / "polls.json"
PARIS = ZoneInfo("Europe/Paris")

SOURCES = [
    {"name": "2027etmoi (sondages)", "licence": "Licence Ouverte 2.0",
     "url": "https://www.data.gouv.fr/datasets/sondages-dintentions-de-vote-au-premier-tour-presidentielle-2027-notices-officielles"},
    {"name": "2027etmoi (candidatures)", "licence": "Licence Ouverte 2.0",
     "url": "https://www.data.gouv.fr/datasets/candidatures-a-lelection-presidentielle-2027-statuts-sources"},
]

SILENCE = [
    (dt.datetime(2027, 4, 17, 0, 0, tzinfo=PARIS), dt.datetime(2027, 4, 18, 20, 0, tzinfo=PARIS)),
    (dt.datetime(2027, 5, 1, 0, 0, tzinfo=PARIS), dt.datetime(2027, 5, 2, 20, 0, tzinfo=PARIS)),
]


class ValidationError(ValueError):
    pass


def is_silent(moment: dt.datetime) -> bool:
    return any(start <= moment < end for start, end in SILENCE)


def slug(text: str) -> str:
    plain = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", plain).strip("-")


def poll_key(poll: dict) -> str:
    """Clé de déduplication : institut + dates de terrain + commanditaire."""
    return slug("-".join([poll["institute"], poll["fieldStart"], poll["fieldEnd"], poll.get("sponsor") or ""]))


def validate_poll(poll: dict) -> None:
    for field in ("institute", "fieldStart", "fieldEnd", "sampleSize", "hypotheses"):
        if not poll.get(field):
            raise ValidationError(f"{field} manquant : {poll.get('id')}")
    start, end = dt.date.fromisoformat(poll["fieldStart"]), dt.date.fromisoformat(poll["fieldEnd"])
    if start > end:
        raise ValidationError(f"dates inversées : {poll['id']}")
    if not poll.get("noticeURL"):
        raise ValidationError(f"notice manquante : {poll['id']}")
    for hypothesis in poll["hypotheses"]:
        total = sum(score["percent"] for score in hypothesis["scores"])
        if not 97 <= total <= 103:
            raise ValidationError(f"total {total} loin de 100 : {poll['id']}/{hypothesis['id']}")


def merge(archive: list[dict], fresh: list[dict]) -> list[dict]:
    """Fusionne sans jamais effacer : la version la plus récente d'un sondage remplace l'ancienne."""
    merged = {poll["id"]: poll for poll in archive}
    for poll in fresh:
        validate_poll(poll)
        merged[poll["id"]] = poll
    return sorted(merged.values(), key=lambda p: (p["fieldEnd"], p["id"]), reverse=True)


STATUS = {
    "declare": "declaree",
    "pressenti": "pressentie",
    "renonce": "renoncement",
    "primaire": "primaire",
    "empeche": "empechee",
    "valide": "validee",
}


def adapt_candidate(raw: dict) -> dict:
    """Ne garde que le nécessaire : les programmes et les liens de campagne restent hors de l'app."""
    source = raw.get("source") or {}
    return {
        "id": raw["id"],
        "name": raw["nom"],
        "party": raw.get("parti"),
        "status": STATUS.get(raw.get("statut"), "inconnu"),
        "detail": raw.get("statut_detail"),
        "sourceURL": source.get("url"),
        "checkedOn": raw.get("verifie_le"),
    }


def adapt_poll(raw: dict, names: dict[str, str]) -> dict:
    source = raw.get("source") or {}
    poll = {
        "institute": raw["institut"],
        "sponsor": raw.get("commanditaire"),
        "fieldStart": raw["terrain_debut"],
        "fieldEnd": raw["terrain_fin"],
        "sampleSize": raw["echantillon"],
        "noticeURL": source.get("url"),
        "source": source.get("titre"),
        "hypotheses": [
            {
                "id": f"h{index}",
                "label": hypothesis.get("label"),
                "round": 1,  # le fichier source ne couvre que le premier tour
                "scores": [
                    {"candidateID": key, "name": names.get(key, key), "percent": value}
                    for key, value in hypothesis["scores"].items()
                ],
            }
            for index, hypothesis in enumerate(raw["hypotheses"], start=1)
        ],
    }
    poll["id"] = poll_key(poll)
    return poll


def load_raw() -> tuple[list[dict], list[dict], str]:
    """Renvoie (candidats, sondages, date de mise à jour des sources)."""
    missing = [name for name in ("sondages.json", "candidatures.json") if not (RAW / name).exists()]
    if missing:
        raise SystemExit(f"Fichiers absents de pipeline/raw : {', '.join(missing)}")
    polls_file = json.loads((RAW / "sondages.json").read_text(encoding="utf-8"))
    candidates_file = json.loads((RAW / "candidatures.json").read_text(encoding="utf-8"))
    candidates = [adapt_candidate(item) for item in candidates_file["candidats"]]
    names = {item["id"]: item["name"] for item in candidates} | polls_file.get("noms_hors_liste", {})
    polls = [adapt_poll(item, names) for item in polls_file["sondages"]]
    updated = max(polls_file["mise_a_jour"], candidates_file["mise_a_jour"])
    return candidates, polls, updated


def main() -> int:
    now = dt.datetime.now(PARIS)
    if is_silent(now):
        print("Silence électoral : aucune publication.")
        return 0
    candidates, fresh, updated = load_raw()
    archive = json.loads(ARCHIVE.read_text()) if ARCHIVE.exists() else []
    polls = merge(archive, fresh)
    ARCHIVE.parent.mkdir(parents=True, exist_ok=True)
    ARCHIVE.write_text(json.dumps(polls, ensure_ascii=False, indent=1))
    PUBLIC.parent.mkdir(parents=True, exist_ok=True)
    PUBLIC.write_text(json.dumps({
        "schemaVersion": 1,
        "generatedAt": updated,
        "sources": SOURCES,
        "silencePeriods": [],
        "candidates": candidates,
        "polls": polls,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
