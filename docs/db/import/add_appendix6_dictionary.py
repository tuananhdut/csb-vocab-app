"""Add the dictionary "Từ vựng giáo trình" from Appendix 6 of
assets/pdf/TA CHUYÊN NGÀNH Them.docx to assets/db/vocab.db.

Idempotent: re-running drops and rebuilds the dictionary's links. Words
already in the DB with a matching meaning are linked, not duplicated;
the rest are inserted as SEED rows with the textbook's own meaning.
"""
import sqlite3
import sys
import time

import docx

DOCX = "assets/pdf/TA CHUYÊN NGÀNH Them.docx"
DB = "assets/db/vocab.db"
DICT_NAME = "Từ vựng giáo trình"
POS = {"n": 0, "v": 1, "a": 2, "adj": 2, "adv": 3, "prep": 4}
# Typos in the source table.
WORD_FIX = {"amry corp": "army corps", "coordin ation": "coordination"}


def load_rows():
    rows = []
    for t in docx.Document(DOCX).tables:
        for r in t.rows:
            cells = []
            for c in r.cells:
                if not cells or c._tc is not cells[-1]._tc:  # skip merged cells
                    cells.append(c)
            cs = [" ".join(c.text.split()) for c in cells]
            if len(cs) == 5 and cs[0].isdigit():
                rows.append(cs)
    # Appendix 5 (irregular verbs) shares the 5-column shape; Appendix 6
    # starts at the first row whose third column is a phonetic.
    start = next(i for i, r in enumerate(rows) if r[2].startswith("/"))
    return rows[start:]


def main():
    entries = {}
    for _, word, phonetic, typ, meaning in load_rows():
        word = WORD_FIX.get(word.lower(), word).strip()
        if not word or not meaning:
            continue
        entries.setdefault((word.lower(), meaning.lower()), (word, phonetic or None, typ, meaning))

    db = sqlite3.connect(DB)
    now = int(time.time())
    row = db.execute("SELECT id FROM dictionaries WHERE name = ?", (DICT_NAME,)).fetchone()
    if row:
        dict_id = row[0]
        db.execute("DELETE FROM word_dictionaries WHERE dictionary_id = ?", (dict_id,))
    else:
        order = db.execute("SELECT COALESCE(MAX(sort_order), 0) + 1 FROM dictionaries").fetchone()[0]
        dict_id = db.execute(
            "INSERT INTO dictionaries (name, is_default, sort_order, created_at) VALUES (?, 1, ?, ?)",
            (DICT_NAME, order, now),
        ).lastrowid

    linked = inserted = 0
    for (lower, meaning_lower), (word, phonetic, typ, meaning) in entries.items():
        existing = [
            r for r in db.execute("SELECT id, meaning_vi FROM words WHERE word_lower = ?", (lower,))
            if meaning_lower in r[1].lower() or r[1].lower() in meaning_lower
        ]
        if existing:
            word_id = existing[0][0]
            linked += 1
        else:
            word_id = db.execute(
                "INSERT INTO words (word, word_lower, phonetic, meaning_vi, meaning_lower,"
                " part_of_speech, is_subentry, source, created_at)"
                " VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?)",
                (word, lower, phonetic, meaning, meaning.lower(), POS.get(typ.lower()), now),
            ).lastrowid
            inserted += 1
        db.execute(
            "INSERT OR IGNORE INTO word_dictionaries (word_id, dictionary_id, added_at) VALUES (?, ?, ?)",
            (word_id, dict_id, now),
        )
    db.commit()
    db.execute("VACUUM")
    db.close()
    print(f"dictionary {dict_id}: {linked} linked, {inserted} inserted")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
