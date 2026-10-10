"""Add and backfill `words.meaning_lower` in assets/db/vocab.db.

SQLite's lower() only folds ASCII, so "Đô đốc" never matched a lowercase
"đô đốc" query. This column holds the Unicode-lowercased meaning, like
`word_lower` does for the English headword. Idempotent; run it last in
the import pipeline, after any script that inserts into `words`.
"""
import sqlite3
import sys

DB = "assets/db/vocab.db"


def main():
    db = sqlite3.connect(DB)
    cols = [r[1] for r in db.execute("PRAGMA table_info(words)")]
    if "meaning_lower" not in cols:
        db.execute("ALTER TABLE words ADD COLUMN meaning_lower TEXT NOT NULL DEFAULT ''")
    rows = db.execute("SELECT id, meaning_vi FROM words").fetchall()
    db.executemany(
        "UPDATE words SET meaning_lower = ? WHERE id = ?",
        [(meaning.lower(), word_id) for word_id, meaning in rows],
    )
    db.commit()
    db.execute("VACUUM")
    db.close()
    print(f"meaning_lower set on {len(rows)} words")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
