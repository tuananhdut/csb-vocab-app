"""Trich noi dung 14 UNIT tu TA_chuyen_nganh.docx thanh chapters_import.csv.

Xem docs/csb-vocab-analysis/tasks/04-seed-noi-dung-bai-doc/04-plan.md
(EXT-01..EXT-04) va Data Contract trong cung file de biet boi canh day
du. Day la buoc EXTRACT dau tien cua pipeline Extract -> Review -> Load.

Cau truc nguon (da khao sat truc tiep qua zipfile + regex tren
word/document.xml, khong phai gia dinh):
- word/document.xml chua muc luc (TOC) LAP LAI toan bo tieu de CHAPTER/
  UNIT truoc khi vao noi dung thuc - pattern `UNIT\\s*\\d+` xuat hien 28
  lan tong: 14 lan dau la muc luc, 14 lan sau la noi dung UNIT thuc su.
  Script bo qua 14 match dau tien (dua vao thu tu xuat hien, khong dua
  vao vi tri ky tu tuyet doi - vi tri co the lech nho theo cach trich
  text, xem 04-analysis.md).
- 2 CHAPTER cha (tim bang regex `CHAPTER\\s+[IVX]+`, cung co ban muc luc
  lap lai o dau - lay match THUC su gan voi tung UNIT thuc, khong phai
  2 match dau tien):
    CHAPTER I  -> "General Military English"       -> Unit 1-3
    CHAPTER II -> "Specialized English for the Vietnam Coast Guard" -> Unit 1-11
  (danh so UNIT lap lai doc lap theo tung CHAPTER - da chot o 04-analysis.md)
- content moi UNIT = toan bo van ban tu chinh dong "UNIT n: ..." cho den
  ngay truoc UNIT tiep theo (hoac truoc APPENDIX cho UNIT 11 - UNIT cuoi
  cung), gop nguyen khoi (I. INTRODUCTION + II. TEXT + III. GRAMMAR +
  IV. VOCABULARY + Exercise) - da chot dung Option 1 Minimal Safe, KHONG
  parse tung heading con. Unit 9 cua Chapter II lech heading con (dung
  "A. FOREIGN RELATIONS..." thay vi "I. INTRODUCTION") nhung khong anh
  huong ranh gioi UNIT ngoai cung nen khong can xu ly rieng.
- title UNIT tach bang cach cat truoc heading con dau tien ("I.
  INTRODUCTION" hoac "A. FOREIGN RELATIONS" cho truong hop lech) - vi
  UNIT title va heading con dinh lien khong co dau phan cach ro trong
  text da flatten.

Cach dung:
    python docs/db/import/extract_ta_chuyen_nganh_docx.py
"""

from __future__ import annotations

import csv
import io
import re
import sys
import zipfile
from xml.sax.saxutils import unescape

DOCX_PATH = "docs/source-materials/TA_chuyen_nganh.docx"
CSV_PATH = "docs/db/import/chapters_import.csv"

SECTION_NAMES = {
    "I": "General Military English",
    "II": "Specialized English for the Vietnam Coast Guard",
}

# Windows console mac dinh dung cp1252, khong encode duoc mot so ky tu
# Unicode (vd U+2019 '’' trong "PEOPLE’S ARMY") - bat buoc ep stdout
# sang UTF-8 truoc khi print bat ky noi dung trich tu docx.
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")


def load_full_text(docx_path: str) -> str:
    """Doc word/document.xml, tra ve text thuan (da unescape XML entities).

    QUAN TRONG: regex phai la `<w:t(?:\\s[^>]*)?>` (khong phai
    `<w:t[^>]*>`) - vi `<w:t[^>]*>` cung khop nham voi tag `<w:tab/>`
    (vi "tab" bat dau bang "t"), lam text bi chen rac XML attribute cua
    tab stop. Da phat hien loi nay khi doi chieu vi tri UNIT/APPENDIX
    voi so lieu khao sat truoc o 04-analysis.md - vi tri lech han cho
    toi khi sua dung regex.
    """
    with zipfile.ZipFile(docx_path) as z:
        xml = z.read("word/document.xml").decode("utf-8")
    texts = re.findall(r"<w:t(?:\s[^>]*)?>(.*?)</w:t>", xml, flags=re.S)
    return unescape("".join(texts))


def extract_units(full_text: str) -> list[dict]:
    """Tra ve list 14 dict {chapter_roman, unit_no, title, content_md}."""
    unit_positions = [m.start() for m in re.finditer(r"UNIT\s*\d+", full_text)]
    if len(unit_positions) != 28:
        raise ValueError(
            f"Ky vong 28 lan match 'UNIT n' (14 muc luc + 14 noi dung thuc), "
            f"thuc te tim thay {len(unit_positions)} - cau truc docx co the "
            f"da doi, can khao sat lai truoc khi tin ket qua script nay."
        )
    real_positions = unit_positions[14:]  # bo 14 match dau (muc luc)

    chapter_positions = {
        m.group(1): m.start()
        for m in re.finditer(r"CHAPTER\s+([IVX]+)", full_text)
        # lay match THUC (nam sau vi tri UNIT dau tien - loai bo ban muc luc)
        if m.start() > real_positions[0] - 10000
    }
    if set(chapter_positions) != {"I", "II"}:
        raise ValueError(
            f"Ky vong tim dung 2 CHAPTER thuc (I, II), thuc te: "
            f"{sorted(chapter_positions)} - can khao sat lai."
        )

    appendix_match = re.search(r"APPENDIX", full_text[real_positions[-1] :])
    end_of_last_unit = (
        real_positions[-1] + appendix_match.start() if appendix_match else len(full_text)
    )

    units = []
    for i, pos in enumerate(real_positions):
        end = real_positions[i + 1] if i + 1 < len(real_positions) else end_of_last_unit
        block = full_text[pos:end]

        # Giua Exercise cuoi cua 1 UNIT va "UNIT n" tiep theo co the xen
        # 1 dong tieu de "CHAPTER II:..." (dung khi UNIT ke la UNIT 1
        # cua CHAPTER moi) - can cat truoc doan nay, khong duoc coi la
        # thuoc content cua UNIT hien tai. Da phat hien thuc te o ranh
        # gioi cuoi Unit 3 Chapter I -> dau Unit 1 Chapter II.
        chapter_heading_match = re.search(r"CHAPTER\s+[IVX]+:?", block)
        if chapter_heading_match:
            block = block[: chapter_heading_match.start()]

        block = block.strip()

        chapter_roman = "I" if pos < chapter_positions["II"] else "II"

        m = re.match(r"^UNIT\s*(\d+)\s*:?\s*", block)
        unit_no = int(m.group(1))
        rest = block[m.end() :]

        heading_match = re.search(r"(I\.\s*INTRODUCTION|A\.\s*FOREIGN)", rest)
        if not heading_match:
            raise ValueError(
                f"Khong tim thay heading con dau tien (I. INTRODUCTION / "
                f"A. FOREIGN) trong UNIT {unit_no} (Chapter {chapter_roman}) "
                f"- can kiem tra thu cong block nay."
            )
        title = rest[: heading_match.start()].strip()

        units.append(
            {
                "chapter_roman": chapter_roman,
                "unit_no": unit_no,
                "title": title,
                "content_md": block,
            }
        )

    return units


def to_rows(units: list[dict]) -> list[dict]:
    rows = []
    for u in units:
        rows.append(
            {
                "section_name": SECTION_NAMES[u["chapter_roman"]],
                "chapter_title": u["title"],
                "sort_order": u["unit_no"],
                "content_md": u["content_md"],
                "reviewed": 0,
            }
        )
    return rows


def main() -> None:
    full_text = load_full_text(DOCX_PATH)
    units = extract_units(full_text)
    print(f"Extracted {len(units)} units from {DOCX_PATH}")

    rows = to_rows(units)
    with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=["section_name", "chapter_title", "sort_order", "content_md", "reviewed"]
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nWrote {len(rows)} rows -> {CSV_PATH}")
    for r in rows:
        print(f"  [{r['section_name'][:12]:12s}] #{r['sort_order']:>2d}  {r['chapter_title']}")


if __name__ == "__main__":
    main()
