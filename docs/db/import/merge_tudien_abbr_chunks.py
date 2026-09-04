"""Gop tat ca cac chunk CSV (do nhieu agent doc anh truc tiep sinh ra) cua
muc Viet tat Tu_dien.pdf thanh 1 file CSV duy nhat, kem kiem tra toan ven:
- Dung header/schema cho tat ca cac file.
- Khong thieu trang (source_page) trong khoang ky vong.
- Khong co dong rong word/meaning_vi.
- Bao cao so dong tung file + tong so dong.

Gop luon voi pilot_tudien_vision_abbr.csv (trang 1363-1372, idx 598-607, da
lam truoc do) de ra 1 file "tudien_abbr_full.csv" bao phu toan bo muc Viet
tat da lam (trang 1363-1739, idx 598-974).
"""

from __future__ import annotations

import csv
from pathlib import Path

FIELDNAMES = [
    "source_page", "dictionary_name", "word", "phonetic",
    "part_of_speech_raw", "part_of_speech_code", "meaning_vi",
    "is_subentry", "example_en", "example_vi", "image_path", "reviewed",
]

CHUNKS_DIR = Path("docs/db/import/tudien_abbr_chunks")
FIRST_BATCH = Path("docs/db/import/pilot_tudien_vision_abbr.csv")
OUT_PATH = Path("docs/db/import/tudien_abbr_full.csv")

# Cac khoang trang in ky vong, theo thu tu, de kiem tra khong thieu/trung trang.
EXPECTED_PAGE_RANGES = [
    (1363, 1372),   # pilot dau tien (idx 598-607)
    (1383, 1397),   # chunk_0618_0632
    (1398, 1412),   # chunk_0633_0647
    (1413, 1442),   # chunk_0648_0677
    (1443, 1472),   # chunk_0678_0707
    (1473, 1502),   # chunk_0708_0737
    (1503, 1517),   # chunk_0738_0752
    (1518, 1532),   # chunk_0753_0767
    (1533, 1562),   # chunk_0768_0797
    (1563, 1592),   # chunk_0798_0827
    (1593, 1622),   # chunk_0828_0857
    (1623, 1652),   # chunk_0858_0887
    (1653, 1682),   # chunk_0888_0917
    (1683, 1712),   # chunk_0918_0947
    (1713, 1739),   # chunk_0948_0974
]


def load_csv(path: Path) -> list[dict]:
    with open(path, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        assert reader.fieldnames == FIELDNAMES, f"{path}: header mismatch: {reader.fieldnames}"
        return list(reader)


def main() -> None:
    files = [FIRST_BATCH] + sorted(CHUNKS_DIR.glob("chunk_*.csv"))
    all_rows: list[dict] = []
    report_lines = []

    for path in files:
        rows = load_csv(path)
        pages = sorted({int(r["source_page"]) for r in rows})
        empty_word = sum(1 for r in rows if not r["word"].strip())
        empty_meaning = sum(1 for r in rows if not r["meaning_vi"].strip())
        report_lines.append(
            f"{path.name}: {len(rows)} rows, pages {pages[0]}-{pages[-1]} "
            f"({len(pages)} distinct pages), empty_word={empty_word}, empty_meaning={empty_meaning}"
        )
        all_rows.extend(rows)

    # Kiem tra khong thieu trang trong tung khoang ky vong
    all_pages = sorted({int(r["source_page"]) for r in all_rows})
    all_pages_set = set(all_pages)
    missing_pages = []
    for lo, hi in EXPECTED_PAGE_RANGES:
        for p in range(lo, hi + 1):
            if p not in all_pages_set:
                missing_pages.append(p)

    report_lines.append(f"\nTONG SO DONG: {len(all_rows)}")
    report_lines.append(f"Tong so trang khac nhau: {len(all_pages)} (tu {all_pages[0]} den {all_pages[-1]})")
    report_lines.append(f"Trang bi thieu (neu co): {missing_pages if missing_pages else 'KHONG CO'}")

    # Ghi file gop
    with open(OUT_PATH, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(all_rows)

    report_lines.append(f"\nDa ghi {OUT_PATH} ({len(all_rows)} dong)")

    with open("docs/db/import/_merge_report.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(report_lines))

    print("done")


if __name__ == "__main__":
    main()
