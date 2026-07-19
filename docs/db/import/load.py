"""Nap words_import.final.csv (da AI review) vao 1 DB thu nghiem SQLite.

Xem docs/csb-vocab-analysis/tasks/03-import-tu-dien-hai-quan/03-plan.md
(LOAD-01/LOAD-02) va Data Contract trong cung file de biet boi canh day
du. Day la buoc LOAD cuoi cung cua pipeline Extract -> Review -> Load.

QUAN TRONG - dung theo Data Contract da dieu chinh (xem lich su hoi
thoai task, khac ban dau trong 03-plan.md):
- Script CHI doc words_import.final.csv (ban da AI review), KHONG bao
  gio doc words_import.csv (ban tho chua review).
- Dong reviewed=0 bi SKIP (khong insert vao words), KHONG lam dung ca
  batch - script in ra danh sach dong bi skip de minh bach, roi tiep
  tuc insert binh thuong cac dong reviewed=1. Quyet dinh nay thay cho
  "all-or-nothing" ban dau, vi 7 dong reviewed=0 con lai sau AI review
  deu la manh vo trung lap VO HAI (word rong, nghia da co day du o dong
  khac trong file - xem ghi chu trong meaning_vi).
- Script CHI nap vao 1 file .sqlite THU NGHIEM (mac dinh
  docs/db/import/review.sqlite), KHONG DUNG CHAM vao user.db/vocab.db
  that cua app - vi schema moi (91_DB-design-new-model.md) chua duoc
  implement that trong app, va LOAD-03 (chien luoc dedup voi nguon
  .docx cu) chua co quyet dinh.
- DB thu nghiem duoc dung lai tu dau (xoa file cu neu co) moi lan chay,
  roi chi ap dung schema.sql (KHONG con seed.sql).
- Bang `dictionaries` KHONG con doc tu docs/db/seed.sql (hardcode 7
  ten co dinh) - thay vao do SUY RA DONG tu cot dictionary_name trong
  chinh words_import.final.csv: 1 dong "Chua phan loai" co dinh
  (sort_order=0, is_deletable=0, giu dung nguyen tac #2 trong
  91_DB-design-new-model.md - noi chua tu mo coi) + N dong ten chuyen
  nganh distinct tim thay trong CSV, sap xep theo source_page NHO NHAT
  tang dan (chuyen nganh xuat hien som nhat trong tai lieu goc se co
  sort_order nho hon, tu nhien khop thu tu muc luc PDF). Neu sau nay
  CSV co them chuyen nganh moi, dictionaries se tu dong co them ma
  khong can sua file seed rieng.

Cach dung:
    python docs/db/import/load.py
"""

from __future__ import annotations

import csv
import io
import os
import sqlite3
import sys
import time

CSV_PATH = "docs/db/import/words_import.final.csv"
SCHEMA_PATH = "docs/db/schema.sql"
DB_PATH = "docs/db/import/review.sqlite"

# Windows console mac dinh dung cp1252, khong encode duoc tieng Viet co
# dau - bat buoc ep stdout/stderr sang UTF-8 truoc khi print bat ky
# noi dung tieng Viet nao (word/meaning_vi trong du lieu tu dien).
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")


def load_rows(csv_path: str) -> list[dict]:
    with open(csv_path, encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def build_fresh_db(db_path: str, schema_path: str) -> sqlite3.Connection:
    """Xoa DB thu nghiem cu (neu co) va dung lai tu schema.sql (KHONG con
    seed.sql - xem seed_dictionaries_from_csv()), dam bao moi lan chay
    load.py deu bat dau tu trang thai sach - tranh du lieu cu chong len
    khi chay lai nhieu lan de sua loi."""
    if os.path.exists(db_path):
        os.remove(db_path)
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")
    with open(schema_path, encoding="utf-8") as f:
        conn.executescript(f.read())
    conn.commit()
    return conn


def seed_dictionaries_from_csv(conn: sqlite3.Connection, rows: list[dict], now: int) -> dict[str, int]:
    """Suy ra danh sach dictionaries TU CHINH du lieu CSV, thay vi doc
    tu docs/db/seed.sql hardcode. Tra ve dict {dictionary_name: id} de
    dung tiep khi insert word_dictionaries.

    Quy tac (da chot qua AskUserQuestion):
    - 1 dong "Chua phan loai" co dinh, id=1, sort_order=0, is_deletable=0
      (khong bao gio xoa - noi chua tu mo coi, dung nguyen tac #2 trong
      91_DB-design-new-model.md). Khong co tu nao trong CSV hien dang
      thuoc bo nay (moi dong CSV deu co dictionary_name ro rang), nhung
      van tao san de dung dung thiet ke.
    - Cac ten chuyen nganh DISTINCT tim thay trong cot dictionary_name
      cua CSV, sap xep theo source_page NHO NHAT cua tung ten (tang dan)
      - chuyen nganh xuat hien som nhat trong tai lieu goc duoc
      sort_order nho hon, tu nhien khop thu tu muc luc PDF goc (Quan su
      chung, Hang hai, Thong tin ra da, Vu khi, Co dien, Canh sat bien).
    """
    first_page_by_name: dict[str, int] = {}
    for r in rows:
        name = r["dictionary_name"].strip()
        if not name:
            continue
        page = int(r["source_page"])
        if name not in first_page_by_name or page < first_page_by_name[name]:
            first_page_by_name[name] = page

    ordered_names = sorted(first_page_by_name, key=lambda n: first_page_by_name[n])

    cur = conn.cursor()
    cur.execute(
        "INSERT INTO dictionaries (name, is_default, is_deletable, sort_order, created_at) VALUES (?, 1, 0, 0, ?)",
        ("Chưa phân loại", now),
    )
    dict_map = {"Chưa phân loại": cur.lastrowid}

    for i, name in enumerate(ordered_names, start=1):
        cur.execute(
            "INSERT INTO dictionaries (name, is_default, is_deletable, sort_order, created_at) VALUES (?, 1, 1, ?, ?)",
            (name, i, now),
        )
        dict_map[name] = cur.lastrowid

    conn.commit()
    return dict_map


def main() -> None:
    rows = load_rows(CSV_PATH)
    print(f"Read {len(rows)} rows from {CSV_PATH}")

    # Dong reviewed=0 bi SKIP (khong insert), khong lam dung ca batch -
    # quyet dinh nay khac ban dau "all-or-nothing" trong 03-plan.md
    # (Data Contract), doi lai vi 7 dong reviewed=0 con lai sau khi AI
    # review deu la manh vo trung lap VO HAI (word rong, nghia da co
    # day du o dong khac trong cung file - xem ghi chu trong
    # meaning_vi cua tung dong) - khong co gia tri de insert vao words.
    unreviewed = [r for r in rows if r["reviewed"] != "1"]
    rows_to_load = [r for r in rows if r["reviewed"] == "1"]
    if unreviewed:
        print(f"\nSKIPPING {len(unreviewed)} rows with reviewed=0 (not inserted):")
        for r in unreviewed:
            print(f"  page={r['source_page']:>4s}  word={r['word']!r:20s}  meaning_vi={r['meaning_vi']!r}")

    print(f"\nLoading {len(rows_to_load)} rows (reviewed=1)")

    now = int(time.time())
    conn = build_fresh_db(DB_PATH, SCHEMA_PATH)
    dict_map = seed_dictionaries_from_csv(conn, rows_to_load, now)
    print(f"\nSeeded {len(dict_map)} dictionaries from CSV:")
    for name, id_ in sorted(dict_map.items(), key=lambda kv: kv[1]):
        print(f"  id={id_}  {name!r}")

    inserted_words = 0
    inserted_word_dicts = 0
    inserted_examples = 0
    skipped_no_dictionary = []

    try:
        cur = conn.cursor()
        for r in rows_to_load:
            dict_name = r["dictionary_name"].strip()
            dictionary_id = dict_map.get(dict_name)
            if dictionary_id is None:
                # Khong nen xay ra vi dict_map da suy tu chinh danh sach
                # rows_to_load (seed_dictionaries_from_csv dung cung
                # bien rows_to_load) - giu lai nhu 1 an toan phong thu,
                # skip dong nay thay vi dung ca batch neu co gi bat
                # thuong (vd dictionary_name rong sau khi strip).
                skipped_no_dictionary.append(r)
                continue

            part_of_speech = int(r["part_of_speech_code"]) if r["part_of_speech_code"] else None
            is_subentry = int(r["is_subentry"]) if r["is_subentry"] else 0

            cur.execute(
                """
                INSERT INTO words (word, word_lower, phonetic, meaning_vi,
                                    part_of_speech, is_subentry, image_path,
                                    source, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)
                """,
                (
                    r["word"],
                    r["word"].lower(),
                    r["phonetic"] or None,
                    r["meaning_vi"],
                    part_of_speech,
                    is_subentry,
                    r["image_path"] or None,
                    now,
                ),
            )
            word_id = cur.lastrowid
            inserted_words += 1

            cur.execute(
                "INSERT INTO word_dictionaries (word_id, dictionary_id, added_at) VALUES (?, ?, ?)",
                (word_id, dictionary_id, now),
            )
            inserted_word_dicts += 1

            if r["example_en"] or r["example_vi"]:
                cur.execute(
                    "INSERT INTO examples (word_id, example_en, example_vi) VALUES (?, ?, ?)",
                    (word_id, r["example_en"], r["example_vi"]),
                )
                inserted_examples += 1

        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    print(f"\nInserted: words={inserted_words}  word_dictionaries={inserted_word_dicts}  examples={inserted_examples}")
    if skipped_no_dictionary:
        print(f"\nSKIPPED {len(skipped_no_dictionary)} rows (dictionary_name khong khop):")
        for r in skipped_no_dictionary:
            print(f"  page={r['source_page']:>4s}  dictionary_name={r['dictionary_name']!r}  word={r['word']!r}")
    print(f"\nDone -> {DB_PATH}")


if __name__ == "__main__":
    main()
