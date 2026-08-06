"""Migrate assets/db/vocab.db (schema cu) sang schema moi docs/db/schema.sql.

Xem docs/csb-vocab-analysis/91_DB-design-new-model.md va
docs/csb-vocab-analysis/tasks/04-seed-noi-dung-bai-doc/ - day la buoc
dua schema moi (dictionaries N-N, sections/chapters bai doc) vao CHINH
DB THAT cua app (khac han LOAD-01/LOAD-02 truoc chi ghi vao
review.sqlite thu nghiem).

Nguyen tac migrate (KHONG mat du lieu that dang co):
- Bang `chapters` CU (6 dong: chapter_no/title, dung nhu "bo chuyen
  nganh") duoc doi ten y nghia thanh `dictionaries` moi (is_default=1,
  is_deletable=1, sort_order=chapter_no) + them 1 dong "Chua phan loai"
  cu dinh (id nho nhat, is_deletable=0) - dung nguyen tac #2 trong
  91_DB-design-new-model.md.
- `words.chapter_id` (1-N cu) duoc chuyen thanh 1 dong `word_dictionaries`
  (N-N moi) tuong ung cho moi word - khong word nao bi mat lien ket.
- `words.part_of_speech` TEXT cu ('dt'/'dt'/'tt'/'prep') duoc map sang
  ma so INTEGER 0-4 theo dung enum da chot (xem POS_MAP duoi).
- `words.source = 0` (SEED) + `created_at` = thoi diem chay migrate cho
  toan bo 2456 dong cu - dung dinh nghia SEED "dong goi san luc build".
- `examples` giu nguyen cau truc (chi doi word_id namespace, khong doi
  gia tri vi words.id giu nguyen qua migrate).
- Sections/chapters (bai doc) duoc INSERT THEM tu
  docs/db/import/chapters_import.csv (da review o task 04) - khong lien
  quan gi den words/dictionaries.

QUAN TRONG: script ghi ra 1 file MOI (OUTPUT_PATH), khong sua truc tiep
INPUT_PATH - chay xong, tu kiem tra ket qua roi moi thay the
assets/db/vocab.db (backup file cu truoc khi thay, xem huong dan cuoi
file khi chay script).

Cach dung:
    python docs/db/import/migrate_vocab_db.py
"""

from __future__ import annotations

import csv
import io
import os
import shutil
import sqlite3
import sys
import time

INPUT_PATH = "assets/db/vocab.db"
OUTPUT_PATH = "docs/db/import/vocab.migrated.db"
SCHEMA_PATH = "docs/db/schema.sql"
CHAPTERS_CSV_PATH = "docs/db/import/chapters_import.csv"

SECTION_SORT_ORDER = {
    "General Military English": 1,
    "Specialized English for the Vietnam Coast Guard": 2,
}

POS_MAP = {
    "dt": 0,   # danh tu
    "đt": 1,   # dong tu
    "tt": 2,   # tinh tu
    "trt": 3,  # trang tu
    "prep": 4, # gioi tu
    "cụm gt": 4,
}

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")


def build_fresh_db(db_path: str, schema_path: str) -> sqlite3.Connection:
    if os.path.exists(db_path):
        os.remove(db_path)
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")
    with open(schema_path, encoding="utf-8") as f:
        conn.executescript(f.read())
    conn.commit()
    return conn


def migrate_words_and_dictionaries(old: sqlite3.Connection, new: sqlite3.Connection, now: int) -> None:
    """Doi chapters cu -> dictionaries moi, words.chapter_id -> word_dictionaries."""
    old_cur = old.cursor()
    new_cur = new.cursor()

    new_cur.execute(
        "INSERT INTO dictionaries (name, is_default, is_deletable, sort_order, created_at) VALUES (?, 1, 0, 0, ?)",
        ("Chưa phân loại", now),
    )
    unclassified_id = new_cur.lastrowid

    dictionary_id_map: dict[int, int] = {}
    old_chapters = old_cur.execute("SELECT id, chapter_no, title FROM chapters ORDER BY chapter_no").fetchall()
    for old_id, chapter_no, title in old_chapters:
        new_cur.execute(
            "INSERT INTO dictionaries (name, is_default, is_deletable, sort_order, created_at) VALUES (?, 1, 1, ?, ?)",
            (title, chapter_no, now),
        )
        dictionary_id_map[old_id] = new_cur.lastrowid

    print(f"Migrated {len(old_chapters)} chapters -> dictionaries (+1 'Chưa phân loại')")

    unmapped_pos = set()
    inserted_words = 0
    old_words = old_cur.execute(
        "SELECT id, chapter_id, word, word_lower, phonetic, part_of_speech, meaning_vi, image_path, is_subentry FROM words"
    ).fetchall()
    for (old_word_id, chapter_id, word, word_lower, phonetic, pos_raw, meaning_vi, image_path, is_subentry) in old_words:
        pos_key = (pos_raw or "").strip()
        part_of_speech = POS_MAP.get(pos_key)
        if pos_key and part_of_speech is None:
            unmapped_pos.add(pos_key)

        new_cur.execute(
            """
            INSERT INTO words (id, word, word_lower, phonetic, meaning_vi,
                                part_of_speech, is_subentry, image_path,
                                source, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
            """,
            (old_word_id, word, word_lower, phonetic or None, meaning_vi,
             part_of_speech, is_subentry, image_path, now),
        )
        inserted_words += 1

        dictionary_id = dictionary_id_map.get(chapter_id, unclassified_id)
        new_cur.execute(
            "INSERT INTO word_dictionaries (word_id, dictionary_id, added_at) VALUES (?, ?, ?)",
            (old_word_id, dictionary_id, now),
        )

    if unmapped_pos:
        print(f"CANH BAO: {len(unmapped_pos)} gia tri part_of_speech khong map duoc, de NULL: {sorted(unmapped_pos)}")
    print(f"Migrated {inserted_words} words + word_dictionaries")

    inserted_examples = 0
    for (ex_id, word_id, example_en, example_vi) in old_cur.execute(
        "SELECT id, word_id, example_en, example_vi FROM examples"
    ).fetchall():
        new_cur.execute(
            "INSERT INTO examples (id, word_id, example_en, example_vi) VALUES (?, ?, ?, ?)",
            (ex_id, word_id, example_en, example_vi),
        )
        inserted_examples += 1
    print(f"Migrated {inserted_examples} examples")


def load_chapters_content(new: sqlite3.Connection) -> None:
    """Insert sections/chapters (bai doc) tu chapters_import.csv da review
    o task 04 - xem docs/csb-vocab-analysis/tasks/04-seed-noi-dung-bai-doc/
    04-plan.md (LOAD-01/LOAD-02)."""
    with open(CHAPTERS_CSV_PATH, encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))

    unreviewed = [r for r in rows if r["reviewed"] != "1"]
    rows_to_load = [r for r in rows if r["reviewed"] == "1"]
    if unreviewed:
        print(f"SKIPPING {len(unreviewed)} chapter rows with reviewed=0")

    section_names = sorted(
        {r["section_name"].strip() for r in rows_to_load if r["section_name"].strip()},
        key=lambda n: SECTION_SORT_ORDER.get(n, 999),
    )

    cur = new.cursor()
    section_map: dict[str, int] = {}
    for name in section_names:
        cur.execute(
            "INSERT INTO sections (name, sort_order) VALUES (?, ?)",
            (name, SECTION_SORT_ORDER.get(name, 999)),
        )
        section_map[name] = cur.lastrowid

    inserted_chapters = 0
    for r in rows_to_load:
        section_id = section_map.get(r["section_name"].strip())
        if section_id is None:
            continue
        cur.execute(
            "INSERT INTO chapters (section_id, title, sort_order, content) VALUES (?, ?, ?, ?)",
            (section_id, r["chapter_title"], int(r["sort_order"]), r["content_md"]),
        )
        inserted_chapters += 1

    print(f"Loaded {len(section_map)} sections + {inserted_chapters} chapters (bai doc)")


def main() -> None:
    now = int(time.time())

    old = sqlite3.connect(INPUT_PATH)
    new = build_fresh_db(OUTPUT_PATH, SCHEMA_PATH)

    try:
        migrate_words_and_dictionaries(old, new, now)
        load_chapters_content(new)
        new.commit()
    except Exception:
        new.rollback()
        raise
    finally:
        old.close()
        new.close()

    # Sanity check doi chieu so dong
    old_check = sqlite3.connect(INPUT_PATH)
    new_check = sqlite3.connect(OUTPUT_PATH)
    old_words_count = old_check.execute("SELECT COUNT(*) FROM words").fetchone()[0]
    old_examples_count = old_check.execute("SELECT COUNT(*) FROM examples").fetchone()[0]
    new_words_count = new_check.execute("SELECT COUNT(*) FROM words").fetchone()[0]
    new_examples_count = new_check.execute("SELECT COUNT(*) FROM examples").fetchone()[0]
    new_word_dicts_count = new_check.execute("SELECT COUNT(*) FROM word_dictionaries").fetchone()[0]
    new_sections_count = new_check.execute("SELECT COUNT(*) FROM sections").fetchone()[0]
    new_chapters_count = new_check.execute("SELECT COUNT(*) FROM chapters").fetchone()[0]
    old_check.close()
    new_check.close()

    print()
    print(f"words:            old={old_words_count}  new={new_words_count}  {'OK' if old_words_count == new_words_count else 'MISMATCH'}")
    print(f"examples:         old={old_examples_count}  new={new_examples_count}  {'OK' if old_examples_count == new_examples_count else 'MISMATCH'}")
    print(f"word_dictionaries: {new_word_dicts_count} (phai == words.new = {new_words_count})")
    print(f"sections:          {new_sections_count}")
    print(f"chapters (bai doc): {new_chapters_count}")
    print()
    print(f"Done -> {OUTPUT_PATH}")
    print("Kiem tra ky ket qua truoc khi thay the assets/db/vocab.db (xem sanity check tren).")


if __name__ == "__main__":
    main()
