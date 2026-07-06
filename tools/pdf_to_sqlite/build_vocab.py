"""Sinh vocab.db từ giáo trình TA_chuyen_nganh_2.pdf (self-contained).

Pipeline:
  PDF --> parse (màu/font/size) --> entries --> SQLite (chapters, words, examples)
       --> trích ảnh minh họa --> assets/images/words/ + gắn image_path

Cấu trúc nhận diện: xem README trong thư mục này.
Cross-reference ("xem X") không có từ tiếng Anh -> bỏ (đúng, không phải lỗi).

Chạy:
  python build_vocab.py <pdf> <out_db> <images_dir> [--no-images]
"""
import os
import re
import sqlite3
import sys
import unicodedata
from collections import Counter, OrderedDict

import fitz

FIRST_CONTENT_PAGE = 6
IMG_MIN_SIDE = 55  # px: lọc icon nhỏ (♣, 🔑) khỏi ảnh minh họa thật

POS_SET = {"dt", "đt", "tt", "pt", "gt", "lt", "st", "tht", "đdt",
           "pre", "prep", "n", "v", "adj", "adv"}
POS_RE = re.compile(r"^\(\s*([^)]{1,10}?)\s*\)[:：]?$")
IPA_RE = re.compile(r"^/.+")


# ---------- helpers phân loại span ----------
def rgb(c):
    return (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF


def is_blue(c):
    r, g, b = rgb(c)
    return b >= 150 and r < 130 and g < 130


def is_red(c):
    r, g, b = rgb(c)
    return r >= 150 and g < 100 and b < 100


def is_bold(s):
    return bool(s["flags"] & 16)


def is_italic(s):
    return bool(s["flags"] & 2)


def pos_token(txt):
    m = POS_RE.match(txt)
    if not m:
        return None
    inner = m.group(1).strip().rstrip(".").lower()
    return m.group(1).strip().rstrip(".") if inner in POS_SET else None


def classify(s):
    txt = s["text"].strip()
    if not txt:
        return None, txt
    color, size, font = s["color"], s["size"], s["font"]
    if font.startswith("Symbol") or font.startswith("Segoe UI Emoji"):
        return "SKIP", txt
    if is_red(color) and is_bold(s):
        return "SPECIALTY", txt
    if is_blue(color):
        if size >= 30:
            return "ALPHA", txt          # chữ cái phân mục A–Z (48)
        if size >= 16:
            return "SKIP", txt           # catchword lặp ở chân trang (20)
        if size >= 12.5:                 # 13–14: đầu mục / từ tiếng Anh
            return ("HEADWORD" if is_bold(s) else "EQUIV"), txt
        return "SUBENTRY", txt           # 12: cụm từ con
    p = pos_token(txt)
    if p is not None:
        return "POS", p
    if IPA_RE.match(txt) and not is_italic(s):
        return "IPA", txt
    if is_italic(s):
        return "ITALIC", txt
    return "BLACK", txt


def page_specialty(page):
    for b in page.get_text("dict")["blocks"]:
        if b.get("type") != 0:
            continue
        for l in b["lines"]:
            for s in l["spans"]:
                if is_red(s["color"]) and is_bold(s) and s["text"].strip():
                    return s["text"].strip()
    return None


def clean(t):
    return re.sub(r"\s+([.,;:])", r"\1", t).strip()


# ---------- parse ----------
class Entry:
    def __init__(self, chapter, page):
        self.chapter, self.page = chapter, page
        self.headword_vi = ""
        self.alias = ""          # dạng thay thế trong ngoặc: X (alias)
        self.pos = ""
        self.equivalents = []   # [{word, phonetic}]
        self.vi_example = ""
        self.en_example = ""
        self.subentries = []    # [{phrase_vi, pos, word_en, phonetic}]
        self.is_ref = False      # cross-ref "xem Y" -> không có từ EN

    def is_empty(self):
        return not (self.pos or self.equivalents or self.alias or self.is_ref)

    def is_valid(self):
        return bool(self.headword_vi.strip() and self.equivalents)


def parse(pdf_path):
    doc = fitz.open(pdf_path)
    entries, dropped_ref, dropped_other = [], 0, []
    current = None
    chapter = None
    pend_eq = pend_sub = None
    paren = 0   # độ sâu ngoặc trong "vùng đầu mục" (trước khi có equivalent)

    def flush():
        nonlocal current, dropped_ref
        if current is None:
            return
        if current.is_valid():
            entries.append(current)
        elif current.is_ref or not current.headword_vi.strip():
            dropped_ref += 1
        else:
            dropped_other.append((current.page, current.headword_vi))
        current = None

    for pno in range(FIRST_CONTENT_PAGE, doc.page_count):
        page = doc[pno]
        sp = page_specialty(page)
        if sp:
            chapter = sp
        paren = 0   # ngoặc không bắc cầu qua trang -> reset, tránh kẹt/cascade
        for b in page.get_text("dict")["blocks"]:
            if b.get("type") != 0:
                continue
            for l in b["lines"]:
                for s in l["spans"]:
                    role, txt = classify(s)
                    if role in (None, "SKIP", "ALPHA", "SPECIALTY"):
                        continue

                    # Vùng đầu mục: span XANH chứa '(' ')' hoặc 'xem' = alias/cross-ref
                    # (ngoặc đôi khi cũng là màu xanh, nên xử lý ở đây thay vì chỉ đếm span đen)
                    in_header = (current is not None and not current.equivalents
                                 and pend_sub is None)
                    if in_header and role in ("HEADWORD", "EQUIV", "SUBENTRY"):
                        has_xem = "xem" in txt.lower()
                        if has_xem:
                            current.is_ref = True
                        if paren > 0 or "(" in txt or ")" in txt or has_xem:
                            core = txt.strip("() ").strip()
                            if core and not has_xem and core.lower() != "xem":
                                current.alias += (" " if current.alias else "") + core
                            paren = max(0, paren + txt.count("(") - txt.count(")"))
                            pend_eq = pend_sub = None
                            continue

                    if role == "HEADWORD":
                        if current and current.is_empty() and current.headword_vi:
                            current.headword_vi += " " + txt   # headword nhiều span
                        else:
                            flush()
                            current = Entry(chapter, pno)
                            current.headword_vi = txt
                            paren = 0
                        pend_eq = pend_sub = None
                        continue
                    if current is None:
                        continue
                    if role == "EQUIV":
                        pend_sub = None
                        pend_eq = {"word": txt, "phonetic": ""}
                        current.equivalents.append(pend_eq)
                    elif role == "SUBENTRY":
                        phrase = txt.strip().lstrip("~").strip().rstrip(":：").strip()
                        pend_sub = {"phrase_vi": phrase, "pos": "",
                                    "word_en": "", "phonetic": ""}
                        current.subentries.append(pend_sub)
                        pend_eq = None
                    elif role == "POS":
                        if pend_sub is not None:
                            if not pend_sub["pos"]:
                                pend_sub["pos"] = txt
                        elif not current.equivalents:
                            current.pos = txt
                    elif role == "IPA":
                        tgt = pend_sub or pend_eq
                        if tgt is not None:
                            tgt["phonetic"] += (" " if tgt["phonetic"] else "") + txt
                    elif role == "ITALIC":
                        if pend_sub is not None:
                            if not pend_sub["phonetic"]:   # chưa có IPA -> là từ EN
                                pend_sub["word_en"] += (" " if pend_sub["word_en"] else "") + txt
                        else:
                            current.en_example += (" " if current.en_example else "") + txt
                    elif role == "BLACK":
                        if pend_sub is not None:
                            pass
                        elif current.equivalents:
                            current.vi_example += (" " if current.vi_example else "") + txt
                        else:
                            # vùng đầu mục: theo dõi ngoặc + phát hiện cross-ref "xem"
                            paren = max(0, paren + txt.count("(") - txt.count(")"))
                            if "xem" in txt.lower():
                                current.is_ref = True
    flush()
    return entries, dropped_ref, dropped_other


# ---------- trích ảnh ----------
def slugify(text):
    t = unicodedata.normalize("NFKD", text)
    t = "".join(c for c in t if not unicodedata.combining(c))
    t = re.sub(r"[^a-zA-Z0-9]+", "_", t).strip("_").lower()
    return t[:60] or "img"


def extract_images(pdf_path, images_dir):
    """Render vùng ảnh minh họa lớn -> PNG, lấy caption (italic dưới ảnh).
    Trả về dict: caption_normalized -> relative_path."""
    os.makedirs(images_dir, exist_ok=True)
    doc = fitz.open(pdf_path)
    caption_map = {}
    count = 0
    for pno in range(FIRST_CONTENT_PAGE, doc.page_count):
        page = doc[pno]
        d = page.get_text("dict")
        img_blocks = [b for b in d["blocks"] if b.get("type") == 1]
        text_lines = [(l, s) for b in d["blocks"] if b.get("type") == 0
                      for l in b["lines"] for s in l["spans"] if s["text"].strip()]
        for b in img_blocks:
            x0, y0, x1, y1 = b["bbox"]
            if (x1 - x0) < IMG_MIN_SIDE or (y1 - y0) < IMG_MIN_SIDE:
                continue
            # caption = italic span ngay dưới ảnh (y gần đáy ảnh)
            caption = None
            best_dy = 40
            for l, s in text_lines:
                sx0, sy0, sx1, sy1 = s["bbox"]
                if is_italic(s) and sy0 >= y1 - 4 and (sy0 - y1) < best_dy \
                        and sx0 < x1 and sx1 > x0:
                    caption = s["text"].strip()
                    best_dy = sy0 - y1
            rect = fitz.Rect(x0, y0, x1, y1)
            pix = page.get_pixmap(clip=rect, matrix=fitz.Matrix(2, 2))
            name = f"p{pno}_{slugify(caption) if caption else count}.png"
            pix.save(os.path.join(images_dir, name))
            count += 1
            if caption:
                caption_map[normalize_vi(caption)] = f"assets/images/words/{name}"
    return caption_map, count


def normalize_vi(text):
    return re.sub(r"\s+", " ", text.strip().lower())


# ---------- build sqlite ----------
SCHEMA = """
PRAGMA journal_mode=WAL;
CREATE TABLE chapters (
  id INTEGER PRIMARY KEY,
  chapter_no INTEGER,
  title TEXT
);
CREATE TABLE words (
  id INTEGER PRIMARY KEY,
  chapter_id INTEGER REFERENCES chapters(id),
  word TEXT,                 -- từ tiếng Anh (hiển thị)
  word_lower TEXT,           -- để tìm kiếm
  phonetic TEXT,
  part_of_speech TEXT,
  meaning_vi TEXT,           -- nghĩa/khái niệm tiếng Việt
  image_path TEXT,
  is_subentry INTEGER DEFAULT 0
);
CREATE INDEX idx_words_lower ON words(word_lower);
CREATE INDEX idx_words_chapter ON words(chapter_id);
CREATE TABLE examples (
  id INTEGER PRIMARY KEY,
  word_id INTEGER REFERENCES words(id),
  example_en TEXT,
  example_vi TEXT
);
"""


def build_db(entries, caption_map, out_db):
    if os.path.exists(out_db):
        os.remove(out_db)
    for ext in ("-wal", "-shm"):
        if os.path.exists(out_db + ext):
            os.remove(out_db + ext)
    os.makedirs(os.path.dirname(out_db), exist_ok=True)
    con = sqlite3.connect(out_db)
    con.executescript(SCHEMA)
    cur = con.cursor()

    # chapters theo thứ tự xuất hiện
    chapters = OrderedDict()
    for e in entries:
        if e.chapter and e.chapter not in chapters:
            chapters[e.chapter] = len(chapters) + 1
    chap_id = {}
    for title, no in chapters.items():
        cur.execute("INSERT INTO chapters(chapter_no,title) VALUES(?,?)", (no, title))
        chap_id[title] = cur.lastrowid

    n_words = n_ex = n_img = 0
    for e in entries:
        cid = chap_id.get(e.chapter)
        img = caption_map.get(normalize_vi(e.headword_vi))
        if img:
            n_img += 1
        meaning_hw = e.headword_vi.strip()
        if e.alias:
            meaning_hw += f" ({e.alias.strip()})"
        # mỗi từ tiếng Anh (equivalent) = 1 word row, dùng chung nghĩa + ví dụ
        for eq in e.equivalents:
            w = eq["word"].strip()
            if not w:
                continue
            cur.execute(
                """INSERT INTO words(chapter_id,word,word_lower,phonetic,
                   part_of_speech,meaning_vi,image_path,is_subentry)
                   VALUES(?,?,?,?,?,?,?,0)""",
                (cid, w, w.lower(), eq["phonetic"].strip(), e.pos,
                 meaning_hw, img))
            wid = cur.lastrowid
            n_words += 1
            if e.en_example or e.vi_example:
                cur.execute(
                    "INSERT INTO examples(word_id,example_en,example_vi) VALUES(?,?,?)",
                    (wid, clean(e.en_example), clean(e.vi_example)))
                n_ex += 1
        # sub-entries: từ tiếng Anh của cụm, nghĩa = headword + cụm
        for sub in e.subentries:
            w = sub["word_en"].strip()
            if not w:
                continue
            meaning = f"{e.headword_vi.strip()} — {sub['phrase_vi']}".strip(" —")
            cur.execute(
                """INSERT INTO words(chapter_id,word,word_lower,phonetic,
                   part_of_speech,meaning_vi,image_path,is_subentry)
                   VALUES(?,?,?,?,?,?,?,1)""",
                (cid, w, w.lower(), sub["phonetic"].strip(),
                 sub["pos"] or e.pos, meaning, None))
            n_words += 1

    con.commit()
    con.close()
    return len(chapters), n_words, n_ex, n_img


def main():
    pdf = sys.argv[1]
    out_db = sys.argv[2]
    images_dir = sys.argv[3]
    do_images = "--no-images" not in sys.argv

    entries, dropped_ref, dropped_other = parse(pdf)
    print(f"Entry hợp lệ: {len(entries)}")
    print(f"Bỏ (cross-ref 'xem' — hợp lệ): {dropped_ref}")
    print(f"Bỏ (cần xem lại): {len(dropped_other)}")
    for pg, hw in dropped_other[:20]:
        print(f"    trang {pg}: {hw}")
    log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "parse_warnings.log")
    with open(log_path, "w", encoding="utf-8") as f:
        f.write("Các mục bị bỏ (không có từ tiếng Anh rõ ràng) — rà soát tay:\n")
        for pg, hw in dropped_other:
            f.write(f"trang {pg}: {hw}\n")

    caption_map, n_img_files = ({}, 0)
    if do_images:
        caption_map, n_img_files = extract_images(pdf, images_dir)
        print(f"Ảnh minh họa trích được: {n_img_files} (có caption: {len(caption_map)})")

    n_ch, n_w, n_ex, n_img_linked = build_db(entries, caption_map, out_db)
    print(f"\n=== vocab.db ===")
    print(f"chapters: {n_ch}")
    print(f"words   : {n_w}")
    print(f"examples: {n_ex}")
    print(f"words có ảnh: {n_img_linked}")
    print(f"DB: {out_db}")
    for k, v in Counter(e.chapter for e in entries).items():
        print(f"  {k}: {v} entry")


if __name__ == "__main__":
    main()
