import datetime as dt
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import build_polls as b


def poll(pid="p", total=100, end="2026-11-02", notice="https://exemple.test/n"):
    return {"id": pid, "institute": "Institut fictif", "fieldStart": "2026-11-01", "fieldEnd": end,
            "sampleSize": 1000, "noticeURL": notice,
            "hypotheses": [{"id": "h", "round": 1, "scores": [{"candidateID": "x", "name": "X", "percent": total}]}]}


class Silence(unittest.TestCase):
    def test_bornes(self):
        at = lambda *a: dt.datetime(*a, tzinfo=b.PARIS)
        self.assertFalse(b.is_silent(at(2027, 4, 16, 23, 59)))
        self.assertTrue(b.is_silent(at(2027, 4, 17, 0, 0)))
        self.assertFalse(b.is_silent(at(2027, 4, 18, 20, 0)))
        self.assertTrue(b.is_silent(at(2027, 5, 2, 19, 59)))
        self.assertFalse(b.is_silent(at(2027, 5, 2, 20, 0)))


class Merge(unittest.TestCase):
    def test_archive_conservee_et_tri(self):
        merged = b.merge([poll("ancien", end="2026-11-02")], [poll("nouveau", end="2026-11-03")])
        self.assertEqual([p["id"] for p in merged], ["nouveau", "ancien"])

    def test_doublon_remplace(self):
        self.assertEqual(len(b.merge([poll()], [poll()])), 1)

    def test_total_invalide(self):
        with self.assertRaises(b.ValidationError):
            b.merge([], [poll(total=80)])

    def test_notice_obligatoire(self):
        with self.assertRaises(b.ValidationError):
            b.merge([], [poll(notice=None)])

    def test_cle(self):
        self.assertEqual(b.poll_key({"institute": "Ifop-Fiducial", "fieldStart": "2026-11-01", "fieldEnd": "2026-11-02", "sponsor": "Média é"}),
                         "ifop-fiducial-2026-11-01-2026-11-02-media-e")


class Adaptateur(unittest.TestCase):
    def test_sondage_format_2027etmoi(self):
        raw = {"institut": "Institut fictif", "commanditaire": "Média fictif", "terrain_debut": "2026-10-01",
               "terrain_fin": "2026-10-02", "echantillon": 1000,
               "source": {"titre": "Notice", "url": "https://exemple.test/n", "date": "2026-10-03"},
               "hypotheses": [{"label": "Hypothèse", "scores": {"a": 60, "z": 40}}]}
        poll = b.adapt_poll(raw, {"a": "Nom A"})
        b.validate_poll(poll)
        self.assertEqual(poll["id"], "institut-fictif-2026-10-01-2026-10-02-media-fictif")
        self.assertEqual(poll["hypotheses"][0]["scores"][0], {"candidateID": "a", "name": "Nom A", "percent": 60})
        self.assertEqual(poll["hypotheses"][0]["scores"][1]["name"], "z")

    def test_statuts(self):
        base = {"id": "a", "nom": "A", "statut": "declare"}
        self.assertEqual(b.adapt_candidate(base)["status"], "declaree")
        self.assertEqual(b.adapt_candidate(base | {"statut": "renonce"})["status"], "renoncement")
        self.assertEqual(b.adapt_candidate(base | {"statut": "nouveau"})["status"], "inconnu")
        self.assertNotIn("propositions", b.adapt_candidate(base | {"propositions": ["x"]}))


if __name__ == "__main__":
    unittest.main()
