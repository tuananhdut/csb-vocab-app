"""Tao testset.jsonl cho benchmark dich (xem tools/translation-eval/README.md).

Nguon du lieu: assets/db/vocab.db - da duoc xac nhan/bien tap san (khong
phai AI tu bia), gom 2 loai:
  - "term": cum tu chuyen nganh + nghia tieng Viet, lay tu bo
    "Military Dictionary" (dictionary_id=8, ~31.7K muc).
  - "sentence": cau day du EN/VI, lay tu bang `examples` (da co san cho
    tinh nang xem vi du trong app, KHONG lien quan rieng den quan
    su/hang hai nhung dung de danh gia do troi chay/ngu phap cau dai).

Chay 1 lan, khong chay trong runtime app. Khong sua DB.
"""

import json
import random
import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parents[2] / "assets" / "db" / "vocab.db"
OUT_PATH = Path(__file__).resolve().parent / "testset.jsonl"

MILITARY_DICT_ID = 8
N_TERMS = 40
N_SENTENCES = 20
SEED = 42


def pick_terms(con: sqlite3.Connection) -> list[dict]:
    rows = con.execute(
        """
        SELECT w.word, w.meaning_vi
        FROM words w
        JOIN word_dictionaries wd ON wd.word_id = w.id
        WHERE wd.dictionary_id = ?
          AND w.is_subentry = 0
          AND length(w.word) >= 3
          AND w.meaning_vi IS NOT NULL
          AND length(trim(w.meaning_vi)) > 0
        """,
        (MILITARY_DICT_ID,),
    ).fetchall()

    # Phan tang theo do dai cum tu (so tu) de test set khong toan tu don
    # gian - can ca cum ngan (1-2 tu) lan cum dai (4+ tu, thuong la cho
    # thuat ngu chuyen nganh phuc tap hon, kho dich dung hon).
    buckets: dict[int, list[tuple[str, str]]] = {1: [], 2: [], 3: [], 4: []}
    for word, meaning in rows:
        n = len(word.split())
        bucket = min(n, 4)
        buckets[bucket].append((word, meaning))

    random.seed(SEED)
    for bucket in buckets.values():
        random.shuffle(bucket)

    per_bucket = N_TERMS // 4
    picked: list[tuple[str, str]] = []
    for bucket in buckets.values():
        picked.extend(bucket[:per_bucket])
    picked = picked[:N_TERMS]

    return [
        {
            "id": f"term-{i:03d}",
            "type": "term",
            "en": word,
            "vi_ref": meaning,
            "domain_terms": [word],
        }
        for i, (word, meaning) in enumerate(picked)
    ]


def pick_sentences(con: sqlite3.Connection) -> list[dict]:
    rows = con.execute(
        """
        SELECT DISTINCT example_en, example_vi
        FROM examples
        WHERE example_en IS NOT NULL AND length(trim(example_en)) > 0
          AND example_vi IS NOT NULL AND length(trim(example_vi)) > 0
        """
    ).fetchall()

    # Loai cau qua ngan (khong du ngu canh) hoac qua dai (kho so sanh
    # chrF ro rang, uu tien cau 6-30 tu).
    candidates = [
        (en, vi) for en, vi in rows if 6 <= len(en.split()) <= 30
    ]

    random.seed(SEED)
    random.shuffle(candidates)
    picked = candidates[:N_SENTENCES]

    return [
        {
            "id": f"sent-{i:03d}",
            "type": "sentence",
            "en": en,
            "vi_ref": vi,
            "domain_terms": [],
        }
        for i, (en, vi) in enumerate(picked)
    ]


def main() -> None:
    con = sqlite3.connect(DB_PATH)
    terms = pick_terms(con)
    sentences = pick_sentences(con)
    con.close()

    items = terms + sentences
    with OUT_PATH.open("w", encoding="utf-8") as f:
        for item in items:
            f.write(json.dumps(item, ensure_ascii=False) + "\n")

    print(f"Wrote {len(items)} items ({len(terms)} term, {len(sentences)} sentence) to {OUT_PATH}")


if __name__ == "__main__":
    main()
