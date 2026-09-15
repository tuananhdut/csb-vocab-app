"""Dung 1 file .sqlite MOI, gop du lieu CU (copy nguyen tu assets/db/vocab.db
that cua app) + du lieu MOI (Tu_dien_full.csv, 31,997 dong tu Tu_dien.pdf)
thanh 1 DB xem thu/kiem tra - CHUA ghi de len assets/db/vocab.db that.

Quy tac ap dung (mac dinh, CHUA duoc nguoi dung xac nhan rieng - xem bao
cao cuoi script de doi chieu, co the doi lai neu can):
- Dictionary moi "Military Dictionary" duoc tao rieng cho toan bo du lieu
  Tu_dien.csv, gan sort_order sau cung (sau 6 chuyen nganh cu).
- Dedup CHI so voi tu CU (word_lower trung voi 1 tu da co trong DB cu) ->
  BO QUA dong Tu_dien do, giu nguyen ban cu (coi giao trinh da review la
  nguon dang tin hon). KHONG dedup theo word_lower giua cac dong Tu_dien
  voi nhau (1 tu co nhieu nghia/viet tat trung headword la binh thuong
  trong tu dien, vd "RA" vua la "rear admiral" vua la "Regular Army").
  CHI loai dong TRUNG Y HET (word + meaning_vi giong 100% 1 dong Tu_dien
  khac) - la loi lap trong nguyen ban, khong phai da nghia hop le.
- reviewed: BO QUA co reviewed=0/1/TRUE/FALSE trong CSV, chap nhan het -
  vi toan bo du lieu Tu_dien da duoc doi chieu truc tiep voi anh trang
  goc (khong OCR) va spot-check nhieu trang khop ~100%, coi la dat chuan
  chat luong de dua vao DB xem thu (khac quy uoc REV-01 that cua repo -
  soat tay tung dong - vi 32K dong khong kha thi lam tay).
- image_path: BO TRONG cho toan bo du lieu Tu_dien - cot nay dang tro toi
  file anh KHONG TON TAI (img_<page>.jpg chua tung duoc trich that), neu
  giu se lam vo Image.asset() trong app.
- learned_words (trang thai SRS cua user) KHONG duoc copy - day la du
  lieu tien do hoc tap runtime, khong phai noi dung tu dien, khong lien
  quan den viec gop du lieu nay.
"""

from __future__ import annotations

import csv
import io
import sqlite3
import sys
import time
from pathlib import Path

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

OLD_DB_PATH = Path("assets/db/vocab.db")
SCHEMA_PATH = Path("docs/db/schema.sql")
TU_DIEN_CSV = Path("docs/source-materials/Tu_dien_full.csv")
OUT_DB_PATH = Path("docs/db/import/vocab_combined.sqlite")

NEW_DICTIONARY_NAME = "Military Dictionary"


def build_fresh_db(db_path: Path, schema_path: Path) -> sqlite3.Connection:
    if db_path.exists():
        db_path.unlink()
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA foreign_keys = ON")
    with open(schema_path, encoding="utf-8") as f:
        conn.executescript(f.read())
    conn.commit()
    return conn


def copy_old_data(old_conn: sqlite3.Connection, new_conn: sqlite3.Connection) -> dict:
    """Copy dictionaries/words/word_dictionaries/examples/sections/chapters
    tu DB cu sang DB moi, remap id (AUTOINCREMENT se cap id khac). Tra ve
    context (word_lower da co, dictionary id map, so luong da copy) de
    dung tiep cho buoc gop Tu_dien."""
    new_cur = new_conn.cursor()

    dict_id_map: dict[int, int] = {}
    for row in old_conn.execute("SELECT id, name, is_default, sort_order, created_at FROM dictionaries ORDER BY id"):
        old_id, name, is_default, sort_order, created_at = row
        new_cur.execute(
            "INSERT INTO dictionaries (name, is_default, sort_order, created_at) VALUES (?, ?, ?, ?)",
            (name, is_default, sort_order, created_at),
        )
        dict_id_map[old_id] = new_cur.lastrowid

    word_id_map: dict[int, int] = {}
    existing_word_lower: set[str] = set()
    for row in old_conn.execute(
        "SELECT id, word, word_lower, phonetic, meaning_vi, part_of_speech, is_subentry, image_path, source, created_at FROM words ORDER BY id"
    ):
        old_id, word, word_lower, phonetic, meaning_vi, pos, is_subentry, image_path, source, created_at = row
        new_cur.execute(
            """INSERT INTO words (word, word_lower, phonetic, meaning_vi, part_of_speech,
                                   is_subentry, image_path, source, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (word, word_lower, phonetic, meaning_vi, pos, is_subentry, image_path, source, created_at),
        )
        word_id_map[old_id] = new_cur.lastrowid
        existing_word_lower.add(word_lower)

    for row in old_conn.execute("SELECT word_id, dictionary_id, added_at FROM word_dictionaries"):
        old_word_id, old_dict_id, added_at = row
        new_cur.execute(
            "INSERT INTO word_dictionaries (word_id, dictionary_id, added_at) VALUES (?, ?, ?)",
            (word_id_map[old_word_id], dict_id_map[old_dict_id], added_at),
        )

    for row in old_conn.execute("SELECT word_id, example_en, example_vi FROM examples"):
        old_word_id, example_en, example_vi = row
        new_cur.execute(
            "INSERT INTO examples (word_id, example_en, example_vi) VALUES (?, ?, ?)",
            (word_id_map[old_word_id], example_en, example_vi),
        )

    section_id_map: dict[int, int] = {}
    for row in old_conn.execute("SELECT id, name, sort_order FROM sections ORDER BY id"):
        old_id, name, sort_order = row
        new_cur.execute("INSERT INTO sections (name, sort_order) VALUES (?, ?)", (name, sort_order))
        section_id_map[old_id] = new_cur.lastrowid

    for row in old_conn.execute("SELECT id, section_id, title, sort_order, pdf_path FROM chapters ORDER BY id"):
        _old_id, old_section_id, title, sort_order, pdf_path = row
        new_cur.execute(
            "INSERT INTO chapters (section_id, title, sort_order, pdf_path) VALUES (?, ?, ?, ?)",
            (section_id_map[old_section_id], title, sort_order, pdf_path),
        )

    new_conn.commit()

    return {
        "dict_id_map": dict_id_map,
        "existing_word_lower": existing_word_lower,
        "words_copied": len(word_id_map),
        "dictionaries_copied": len(dict_id_map),
        "next_dict_sort_order": max(
            (row[0] for row in old_conn.execute("SELECT sort_order FROM dictionaries")), default=0
        )
        + 1,
    }


def load_tudien_rows(csv_path: Path) -> list[dict]:
    with open(csv_path, encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def truthy(value: str) -> bool:
    return value.strip().upper() in ("1", "TRUE")


def merge_tudien(new_conn: sqlite3.Connection, rows: list[dict], ctx: dict, now: int) -> dict:
    cur = new_conn.cursor()

    cur.execute(
        "INSERT INTO dictionaries (name, is_default, sort_order, created_at) VALUES (?, 1, ?, ?)",
        (NEW_DICTIONARY_NAME, ctx["next_dict_sort_order"], now),
    )
    new_dict_id = cur.lastrowid

    existing_word_lower: set[str] = ctx["existing_word_lower"]
    seen_exact: set[tuple[str, str]] = set()

    inserted = 0
    skipped_dup_old = 0
    skipped_dup_internal = 0

    for r in rows:
        word = r["word"].strip()
        meaning_vi = r["meaning_vi"].strip()
        word_lower = word.lower()

        if word_lower in existing_word_lower:
            skipped_dup_old += 1
            continue

        exact_key = (word_lower, meaning_vi)
        if exact_key in seen_exact:
            skipped_dup_internal += 1
            continue
        seen_exact.add(exact_key)

        is_subentry = 1 if truthy(r["is_subentry"]) else 0

        cur.execute(
            """INSERT INTO words (word, word_lower, phonetic, meaning_vi, part_of_speech,
                                   is_subentry, image_path, source, created_at)
               VALUES (?, ?, NULL, ?, NULL, ?, NULL, 0, ?)""",
            (word, word_lower, meaning_vi, is_subentry, now),
        )
        word_id = cur.lastrowid
        inserted += 1

        cur.execute(
            "INSERT INTO word_dictionaries (word_id, dictionary_id, added_at) VALUES (?, ?, ?)",
            (word_id, new_dict_id, now),
        )

    new_conn.commit()

    return {
        "inserted": inserted,
        "skipped_dup_old": skipped_dup_old,
        "skipped_dup_internal": skipped_dup_internal,
    }


def main() -> None:
    old_conn = sqlite3.connect(str(OLD_DB_PATH))
    new_conn = build_fresh_db(OUT_DB_PATH, SCHEMA_PATH)

    ctx = copy_old_data(old_conn, new_conn)
    old_conn.close()

    print(f"Copied old data: {ctx['words_copied']} words, {ctx['dictionaries_copied']} dictionaries")

    rows = load_tudien_rows(TU_DIEN_CSV)
    print(f"Read {len(rows)} rows from {TU_DIEN_CSV}")

    now = int(time.time())
    stats = merge_tudien(new_conn, rows, ctx, now)

    total_words = new_conn.execute("SELECT count(*) FROM words").fetchone()[0]
    total_dicts = new_conn.execute("SELECT count(*) FROM dictionaries").fetchone()[0]
    new_conn.close()

    print(f"\nMerged '{NEW_DICTIONARY_NAME}':")
    print(f"  inserted:            {stats['inserted']}")
    print(f"  skipped (dup vs old):{stats['skipped_dup_old']}")
    print(f"  skipped (dup within Tu_dien):{stats['skipped_dup_internal']}")
    print(f"\nFinal DB: {total_words} words total, {total_dicts} dictionaries -> {OUT_DB_PATH}")


if __name__ == "__main__":
    main()
