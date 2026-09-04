"""Gop Tu_dien.csv (trang 764-1344, than tu dien A-Z) + tudien_abbr_full.csv
(trang 1363-1739, muc viet tat) thanh 1 CSV duy nhat dai dien cho TOAN BO
noi dung da trich xuat cua Tu_dien.pdf. Chi gop co hoc theo thu tu
source_page - KHONG doi dinh dang TRUE/FALSE, KHONG dedup voi vocab.db
(nhung buoc do la quyet dinh rieng, chua lam o day).
"""

from __future__ import annotations

import csv
from pathlib import Path

FIELDNAMES = [
    "source_page", "dictionary_name", "word", "phonetic",
    "part_of_speech_raw", "part_of_speech_code", "meaning_vi",
    "is_subentry", "example_en", "example_vi", "image_path", "reviewed",
]

TU_DIEN_CSV = Path("docs/source-materials/Tu_dien.csv")
ABBR_FULL_CSV = Path("docs/db/import/tudien_abbr_full.csv")
OUT_PATH = Path("docs/source-materials/Tu_dien_full.csv")


def load(path: Path) -> list[dict]:
    with open(path, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        assert reader.fieldnames == FIELDNAMES, f"{path}: header mismatch: {reader.fieldnames}"
        return list(reader)


def main() -> None:
    a = load(TU_DIEN_CSV)
    b = load(ABBR_FULL_CSV)

    pages_a = sorted({int(r["source_page"]) for r in a})
    pages_b = sorted({int(r["source_page"]) for r in b})
    overlap = set(pages_a) & set(pages_b)
    if overlap:
        raise SystemExit(f"UNEXPECTED page overlap between the two sources: {sorted(overlap)}")

    all_rows = a + b
    all_rows.sort(key=lambda r: int(r["source_page"]))

    with open(OUT_PATH, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(all_rows)

    print(f"{TU_DIEN_CSV}: {len(a)} rows, pages {pages_a[0]}-{pages_a[-1]}")
    print(f"{ABBR_FULL_CSV}: {len(b)} rows, pages {pages_b[0]}-{pages_b[-1]}")
    print(f"-> {OUT_PATH}: {len(all_rows)} rows total, pages {pages_a[0]}-{pages_b[-1]}")


if __name__ == "__main__":
    main()
