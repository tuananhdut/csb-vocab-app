"""Trich xuat tu vung tu TA_chuyen_nganh_2.pdf sang CSV trung gian.

Xem docs/csb-vocab-analysis/tasks/03-import-tu-dien-hai-quan/03-plan.md
(EXT-01/EXT-02/EXT-03) va 02-brainstorm.md (Option 2 da chon) de biet
boi canh day du. Day la script TRICH XUAT THO - bat buoc phai review
thu cong 100% dong CSV output truoc khi cho phep load.py chay (xem
Data Contract trong 03-plan.md).

Quy tac font/mau xac dinh qua khao sat EXT-01 (quet toan bo 211 trang,
xem color_distribution trong lich su hoi thoai task):

- Heading chuyen nganh: size~18, Bold, do (255,0,0)
- Dau muc tieng Viet: size~14, Bold=True, xanh duong (BLUE_COLORS)
- Thuat ngu tieng Anh: size~14, Bold=False, xanh duong (BLUE_COLORS)
- Loai tu (dt./dt/...): size~12, Bold=True, den, trong ngoac ()
- Phien am: size~12, Bold=False, den, dang /.../
- Tu phai sinh (~...): size~12, Bold=False, xanh duong, ket thuc bang ':'
  (luu y: khong phai luon co ky tu '~' o dau - vd "dao luc dia:" o trang 20)
- Cau vi du VN: size~12, den, tu dich in Bold
- Cau vi du EN: size~12, den, Italic (tu dich BoldItalic)
- Bullet phan cach nhieu nghia Anh: font Symbol, mau tim (112,48,160)

QUAN TRONG: mot muc tu co the vat qua ranh gioi trang (xem EXT-01,
trang 85 va 180) - script noi toan bo span cua ca tai lieu thanh 1
dong chay lien tuc truoc khi tim ranh gioi muc tu, khong cat theo trang.

ANH MINH HOA (mo rong scope so voi 03-plan.md ban dau - xem ghi chu tai
day va lich su hoi thoai task): moi trang co nhieu anh icon nho (42-47px,
bieu tuong moc khoa lap lai dau moi muc tu - khao sat toan bo 211 trang
cho thay ~967 lan xuat hien) LAN VOI vai anh minh hoa that kich thuoc
lon hon han (>=225px trong du lieu khao sat). Dung nguong
IMAGE_MIN_SIZE_PX de loc icon, roi gan moi anh minh hoa cho headword
GAN NHAT PHIA TREN no tren cung 1 trang (dung toa do Y) - khop mo ta
chinh thuc trong PDF (trang 4, "HUONG DAN SU DUNG": "Hinh anh duoc chen
ngay sau vi du, hoac sau tu goc").
"""

from __future__ import annotations

import csv
import os
import re
import sys
from dataclasses import dataclass, field

import fitz  # PyMuPDF

PDF_PATH = "docs/source-materials/TA_chuyen_nganh_2.pdf"
OUTPUT_CSV = "docs/db/import/words_import.csv"
# Luu thang vao thu muc asset that cua app (da khai bao trong pubspec.yaml)
# - khong con qua thu muc trung gian docs/db/import/data/ nua, tranh phai
# copy tay + doi image_path trong CSV sau khi extract xong.
IMAGE_DIR = "assets/images/words"
IMAGE_PATH_PREFIX = "assets/images/words"

# Pham vi trang theo muc luc (PDF page index = trang in - 1).
# Bo Phu luc 1 (khau lenh, tr.192) va Phu luc 2 (hinh anh, tr.202) - Out
# of Scope theo 03-plan.md.
FIRST_PAGE_IDX = 5   # trang in 6 (dau QUAN SU CHUNG)
LAST_PAGE_IDX = 190  # trang in 191 (cuoi CANH SAT BIEN, truoc tr.192)

# Nguong loc icon vs anh minh hoa that (px, canh lon nhat). Xac dinh qua
# khao sat toan bo 211 trang: icon lap lai o 42-47px (~967 lan), anh
# minh hoa that tu 225px tro len - chon 150 lam nguong an toan, cach xa
# ca 2 nhom.
IMAGE_MIN_SIZE_PX = 150

# Ten heading trong PDF -> ten dictionary da seed trong docs/db/seed.sql
DICTIONARY_MAP = {
    "QUÂN SỰ CHUNG": "Quân sự chung",
    "HÀNG HẢI": "Hàng hải",
    "THÔNG TIN RA ĐA": "Thông tin ra đa",
    "VŨ KHÍ": "Vũ khí",
    "CƠ ĐIỆN": "Cơ điện",
    "CẢNH SÁT BIỂN": "Cảnh sát biển",
}

# Mapping da chot o 03-plan.md (Scope): dt.->0, dt.->1 (dong tu), tt.->2,
# trt.->3, cum gt.->4. Dung regex vi PDF khong nhat quan dau cham/khoang
# trang (vd "(dt.)" vs "(dt)").
POS_PATTERNS = [
    (re.compile(r"^đt\.?$", re.IGNORECASE), 1),  # dong tu - kiem tra TRUOC dt
    (re.compile(r"^dt\.?$", re.IGNORECASE), 0),  # danh tu
    (re.compile(r"^tt\.?$", re.IGNORECASE), 2),  # tinh tu
    (re.compile(r"^trt\.?$", re.IGNORECASE), 3),  # trang tu
    (re.compile(r"^cụm gt\.?$", re.IGNORECASE), 4),  # cum gioi tu
]

# Mau xanh duong dung cho dau muc VN + thuat ngu EN (khao sat EXT-01:
# quet toan bo 211 trang, 2 bien the xuat hien voi tan suat lon).
BLUE_COLORS = {(0, 0, 255), (51, 51, 255)}
RED_COLOR = (255, 0, 0)
PURPLE_COLOR = (112, 48, 160)


def rgb(color_int: int) -> tuple[int, int, int]:
    return ((color_int >> 16) & 255, (color_int >> 8) & 255, color_int & 255)


def join_text_parts(parts: list[str]) -> str:
    """Noi cac doan text lai, chen khoang trang giua 2 doan neu ca 2 deu
    khong co san dau cach/dau cau o ranh gioi - tranh dinh chu kieu
    'systemthat' khi tu dich Bold nam giua cau khong co dem cach trong
    PDF goc. Khong chen thua neu 1 trong 2 phia da co dau cach/dau cau."""
    if not parts:
        return ""
    result = parts[0]
    for part in parts[1:]:
        if not part:
            continue
        needs_space = (
            result
            and part
            and not result[-1].isspace()
            and result[-1] not in ".,;:!?()"
            and not part[0].isspace()
            and part[0] not in ".,;:!?()"
        )
        result += (" " if needs_space else "") + part
    return result


@dataclass
class Span:
    text: str
    size: float
    bold: bool
    italic: bool
    color: tuple[int, int, int]
    font: str
    page_idx: int  # 0-based PDF page index, de suy ra source_page
    y0: float = 0.0  # toa do Y dinh span tren trang, dung de gan anh minh hoa
    in_parens: bool = False  # span nam trong cum ngoac (...) - xem mark_parens_depth()


def load_spans(pdf_path: str, first: int, last: int) -> list[Span]:
    """Doc toan bo span cua pham vi trang, noi lien tuc xuyen trang."""
    doc = fitz.open(pdf_path)
    spans: list[Span] = []
    for page_idx in range(first, last + 1):
        page = doc[page_idx]
        d = page.get_text("dict")
        for block in d["blocks"]:
            if "lines" not in block:
                continue
            for line in block["lines"]:
                for s in line["spans"]:
                    text = s["text"]
                    if not text.strip():
                        continue  # bo qua span chi chua khoang trang
                    font = s["font"]
                    spans.append(
                        Span(
                            text=text,
                            size=s["size"],
                            bold="Bold" in font,
                            italic="Italic" in font,
                            color=rgb(s["color"]),
                            font=font,
                            page_idx=page_idx,
                            y0=s["bbox"][1],
                        )
                    )
    mark_parens_depth(spans)
    return spans


def mark_parens_depth(spans: list[Span]) -> None:
    """Danh dau in_parens=True cho moi span nam trong 1 cum ngoac (...)
    CHUA DONG, bat ke mau/style ben trong. Sua tai cho trong ham, khong
    tra ve gia tri moi.

    Ly do can buoc nay: mot so cum tham chieu cheo "(xem X)" co dau
    ngoac MAU DEN nhung noi dung "X" ben trong lai la 1 cum XANH BOLD
    giong het style headword that (vd trang 9: "bia" + " (" [den] +
    "xem" [den] + "muc tieu" [XANH BOLD] + ") " [den]). Dem ky tu '('
    ')' xuyen suot moi span, khong quan tam mau, la cach tong quat xu
    ly dung bien the nay.

    QUAN TRONG: mot span co the TU CAN BANG ngoac rieng no (vd "(dt.)"
    hay headword "khoá nòng (súng/pháo) " co san "(súng/pháo)" nam
    GIUA - day KHONG phai mo dau 1 vung note keo dai, chi la 1 chu
    thich ngan gon nam gon trong chinh headword do. Vi vay chi tinh
    in_parens=True cho TOAN BO span khi ngoac VAN CON DO DANG luc ket
    thuc span (tuc anh huong toi cac span TIEP THEO) - neu 1 span tu
    mo roi tu dong ngay trong no (depth quay ve <= muc truoc do), KHONG
    danh dau in_parens cho span do (giu nguyen la headword/text binh
    thuong), chi propagate in_parens neu depth con duong luc ket thuc
    span (bao gom ca truong hop mo dau tien o chinh span nay)."""
    depth = 0
    for s in spans:
        depth_before = depth
        opens = s.text.count("(")
        closes = s.text.count(")")
        depth_after = max(0, depth_before + opens - closes)
        # in_parens neu: (a) da o trong ngoac tu truoc (depth_before>0),
        # HOAC (b) span nay mo ngoac va van CON DO DANG sau khi tru het
        # closes trong chinh no (depth_after>0 - nghia la khong tu dong
        # het, se anh huong span sau).
        if depth_before > 0 or depth_after > 0:
            s.in_parens = True
        depth = depth_after


def is_vi_headword(s: Span) -> bool:
    return 13 <= s.size <= 15 and s.bold and s.color in BLUE_COLORS and not s.in_parens


def is_en_term(s: Span) -> bool:
    return 13 <= s.size <= 15 and not s.bold and not s.italic and s.color in BLUE_COLORS


def is_pos_tag(s: Span) -> bool:
    return 11 <= s.size <= 13 and s.bold and s.color == (0, 0, 0)


def is_phonetic(s: Span) -> bool:
    return 11 <= s.size <= 13 and not s.bold and not s.italic and s.color == (0, 0, 0) and "/" in s.text


def is_subentry_marker(s: Span) -> bool:
    return 11 <= s.size <= 13 and not s.bold and not s.italic and s.color in BLUE_COLORS


def is_heading(s: Span) -> bool:
    return s.size >= 17 and s.bold and s.color == RED_COLOR


def is_plain_black_text(s: Span) -> bool:
    """Text den thuong, khong Bold/Italic - vd cum '(xem X)' tham chieu
    cheo, hoac dau ngoac le loi. Dung de "nuot" an toan cac doan khong
    khop pattern nao khac, tranh lam lech con tro parse."""
    return not s.bold and not s.italic and s.color == (0, 0, 0)


def is_example_vi_span(s: Span) -> bool:
    """Cau vi du tieng Viet: den, size~12, KHONG Italic, KHONG phai
    phien am (khong chua '/'). Tu dich trong cau co the Bold hoac
    khong - khong phan biet o day, gop chung vao 1 cau."""
    return (
        11 <= s.size <= 13
        and not s.italic
        and s.color == (0, 0, 0)
        and "/" not in s.text
    )


def is_example_en_span(s: Span) -> bool:
    """Cau vi du tieng Anh: den, size~12, Italic=True (tu dich la
    BoldItalic, van co italic=True nen khong can phan biet rieng)."""
    return 11 <= s.size <= 13 and s.italic and s.color == (0, 0, 0)


def parse_pos(raw: str) -> tuple[str, int | None]:
    """Tra ve (chuoi goc da lam sach, ma so enum hoac None)."""
    cleaned = raw.strip().strip("()").strip()
    for pattern, code in POS_PATTERNS:
        if pattern.match(cleaned):
            return cleaned, code
    return cleaned, None


@dataclass
class WordRow:
    source_page: int
    dictionary_name: str
    word: str
    phonetic: str
    part_of_speech_raw: str
    part_of_speech_code: int | None
    meaning_vi: str
    is_subentry: int
    example_en: str = ""
    example_vi: str = ""
    reviewed: int = 0
    image_path: str = ""
    _page_idx: int = -1  # noi bo, dung de gan anh - khong ghi ra CSV
    _y0: float = 0.0  # noi bo, dung de gan anh - khong ghi ra CSV


def extract(spans: list[Span]) -> list[WordRow]:
    rows: list[WordRow] = []
    current_dict = None
    i = 0
    n = len(spans)

    while i < n:
        s = spans[i]

        if is_heading(s):
            name = s.text.strip()
            if name in DICTIONARY_MAP:
                current_dict = DICTIONARY_MAP[name]
            i += 1
            continue

        if s.in_parens and current_dict and rows:
            # Toan bo cum nam trong ngoac (...) - bat ke mau/style ben
            # trong (xanh Bold giong headword that, hoac den thuong) -
            # la ghi chu tham chieu cheo kieu "(xem X)", KHONG phai
            # headword moi (xem mark_parens_depth() - xu ly dung ca 2
            # bien the da phat hien: ca cum xanh, hoac ngoac den boc
            # thuat ngu xanh Bold ben trong). Gom cho toi khi het
            # in_parens, noi vao ghi chu cua dong gan nhat.
            note_parts = [s.text]
            j = i + 1
            while j < n and spans[j].in_parens:
                note_parts.append(spans[j].text)
                j += 1
            note = join_text_parts(note_parts).strip()
            rows[-1].meaning_vi = f"{rows[-1].meaning_vi} {note}".strip()
            i = j
            continue

        if s.in_parens:
            # in_parens nhung chua co current_dict/rows (hiem, vd dau
            # tai lieu) - bo qua an toan, khong lam gay state.
            i += 1
            continue

        if is_vi_headword(s) and current_dict:
            # Gom cac span dau muc VN lien tiep (co the bi PDF tach nhieu
            # span cung thuoc tinh, vd tieu de dai qua 1 dong). is_vi_
            # headword() da tu loai tru span in_parens=True nen o day
            # KHONG can tu xu ly ngoac nua - chi don gian dung khi gap
            # span khong con la headword (kha nang la in_parens, marker
            # khac, hoac ket thuc doan).
            meaning_vi_parts = [s.text]
            j = i + 1
            while j < n and is_vi_headword(spans[j]):
                meaning_vi_parts.append(spans[j].text)
                j += 1
            meaning_vi = join_text_parts(meaning_vi_parts).strip()
            source_page = s.page_idx + 1

            # Tim the loai tu ngay sau (co the co hoac khong).
            pos_raw, pos_code = "", None
            if j < n and is_pos_tag(spans[j]):
                pos_raw, pos_code = parse_pos(spans[j].text)
                j += 1

            # Tu vi tri j: co the co 1..N thuat ngu Anh, phan cach boi
            # bullet (font Symbol mau tim). Voi moi thuat ngu Anh, tao
            # 1 WordRow rieng (theo Scope da chot o 03-plan.md).
            found_any_term = False
            new_rows_start = len(rows)
            while j < n:
                # Bo qua bullet/separator
                while j < n and spans[j].color == PURPLE_COLOR:
                    j += 1
                if j >= n or not is_en_term(spans[j]):
                    break
                word_parts = [spans[j].text]
                j += 1
                while j < n and is_en_term(spans[j]):
                    word_parts.append(spans[j].text)
                    j += 1
                word = "".join(word_parts).strip()

                phonetic = ""
                if j < n and is_phonetic(spans[j]):
                    phonetic = spans[j].text.strip()
                    j += 1

                rows.append(
                    WordRow(
                        source_page=source_page,
                        dictionary_name=current_dict,
                        word=word,
                        phonetic=phonetic,
                        part_of_speech_raw=pos_raw,
                        part_of_speech_code=pos_code,
                        meaning_vi=meaning_vi,
                        is_subentry=0,
                        _page_idx=s.page_idx,
                        _y0=s.y0,
                    )
                )
                found_any_term = True

            if found_any_term:
                # Tu vi tri j: co the co cau vi du VN roi EN ngay sau
                # (den, size~12 - VN khong Italic, EN co Italic). Gom cho
                # toi khi gap span khac loai (headword moi, marker '~',
                # bullet...). Gan chung 1 cau vi du cho TAT CA cac dong
                # vua tao trong muc tu nay (1..N thuat ngu Anh dong nghia
                # deu minh hoa boi cung 1 cau vi du trong PDF goc).
                example_vi_parts: list[str] = []
                while j < n and is_example_vi_span(spans[j]):
                    example_vi_parts.append(spans[j].text)
                    j += 1
                example_en_parts: list[str] = []
                while j < n and is_example_en_span(spans[j]):
                    example_en_parts.append(spans[j].text)
                    j += 1
                example_vi = join_text_parts(example_vi_parts).strip()
                example_en = join_text_parts(example_en_parts).strip()
                if example_vi or example_en:
                    for r in rows[new_rows_start:]:
                        r.example_vi = example_vi
                        r.example_en = example_en

            if not found_any_term:
                # Muc tu khong co thuat ngu Anh ngay sau (vd chi co ghi
                # chu tham chieu cheo "(xem X)"). Gom TOAN BO span
                # in_parens=True lien tiep (bat ke mau/style ben trong -
                # vd "bia (xem mục tiêu)" co "mục tiêu" xanh Bold trong
                # ngoac den, xem mark_parens_depth()) vao 1 ghi chu rieng,
                # DAM BAO con tro j luon tien len - tranh de sot span
                # khien muc tu ke tiep bi lech/nuot nham (loi da phat
                # hien khi chay thu chuong Vu khi: cum "(xem thao)" lam
                # gay state).
                note_parts: list[str] = []
                while j < n and (spans[j].in_parens or (is_plain_black_text(spans[j]) and not is_vi_headword(spans[j]))):
                    note_parts.append(spans[j].text)
                    j += 1
                note = join_text_parts(note_parts).strip()
                rows.append(
                    WordRow(
                        source_page=source_page,
                        dictionary_name=current_dict,
                        word="",
                        phonetic="",
                        part_of_speech_raw=pos_raw,
                        part_of_speech_code=pos_code,
                        meaning_vi=f"{meaning_vi} {note}".strip() if note else meaning_vi,
                        is_subentry=0,
                    )
                )
                if j == i:
                    # An toan: neu van khong tien len duoc (khong con
                    # truong hop nao khac), buoc phai nhay 1 buoc de
                    # tranh vong lap vo han.
                    j += 1

            i = j
            continue

        if is_subentry_marker(s) and current_dict and rows:
            # Gom cum span mau xanh size 12 lien tiep cho toi khi gap ':'
            # (khong dua vao ky tu '~' vi khong phai luon co - xem EXT-01).
            parts = [s.text]
            j = i + 1
            while j < n and is_subentry_marker(spans[j]) and ":" not in "".join(parts):
                parts.append(spans[j].text)
                j += 1
            sub_text = "".join(parts)
            if ":" not in sub_text:
                # Khong ket thuc bang ':' trong pham vi gom - khong phai
                # sub-entry hop le, coi nhu text thuong, bo qua an toan.
                i += 1
                continue
            sub_label = sub_text.split(":", 1)[0].strip().lstrip("~").strip()
            parent_meaning = rows[-1].meaning_vi if rows else ""
            combined_meaning = f"{parent_meaning} {sub_label}".strip()
            source_page = s.page_idx + 1

            pos_raw, pos_code = "", None
            if j < n and is_pos_tag(spans[j]):
                pos_raw, pos_code = parse_pos(spans[j].text)
                j += 1

            if j < n and spans[j].italic and not spans[j].bold:
                word = spans[j].text.strip()
                j += 1
                phonetic = ""
                if j < n and is_phonetic(spans[j]):
                    phonetic = spans[j].text.strip()
                    j += 1
                rows.append(
                    WordRow(
                        source_page=source_page,
                        dictionary_name=current_dict,
                        word=word,
                        phonetic=phonetic,
                        part_of_speech_raw=pos_raw,
                        part_of_speech_code=pos_code,
                        meaning_vi=combined_meaning,
                        is_subentry=1,
                    )
                )
            i = j
            continue

        i += 1

    return rows


def slugify(word: str) -> str:
    """vd 'life jacket' -> 'life_jacket'. Chi dung ky tu an toan cho ten
    file - loai dau cau, thay khoang trang/gach ngang lien tiep bang '_'."""
    s = re.sub(r"[^\w\s-]", "", word.strip().lower())
    s = re.sub(r"[\s-]+", "_", s)
    return s or "unnamed"


def extract_images_and_assign(
    pdf_path: str, rows: list[WordRow], first: int, last: int, image_dir: str
) -> None:
    """Trich anh minh hoa (loc icon qua IMAGE_MIN_SIZE_PX), gan cho
    TOAN BO cac dong cung 1 muc tu (cung meaning_vi + source_page) co
    headword GAN NHAT PHIA TREN anh tren cung 1 trang. Luu vao image_dir
    theo ten tu TIENG ANH DAU TIEN cua muc tu do (khong phai theo dong
    gan anh nhat ve khoang cach) - vd "life vest"/"life jacket" cung 1
    muc "ao phao" deu duoc gan chung 1 anh life_vest.png."""
    os.makedirs(image_dir, exist_ok=True)
    doc = fitz.open(pdf_path)

    # Gom headword theo trang de tim "gan nhat phia tren" hieu qua.
    headwords_by_page: dict[int, list[WordRow]] = {}
    for r in rows:
        if r.word and r._page_idx >= 0:
            headwords_by_page.setdefault(r._page_idx, []).append(r)
    for page_rows in headwords_by_page.values():
        page_rows.sort(key=lambda r: r._y0)

    assigned_count = 0
    for page_idx in range(first, last + 1):
        page_rows = headwords_by_page.get(page_idx)
        if not page_rows:
            continue
        page = doc[page_idx]
        seen_xref: set[int] = set()
        for img in page.get_images(full=True):
            xref, width, height = img[0], img[2], img[3]
            if xref in seen_xref:
                continue
            seen_xref.add(xref)
            if max(width, height) < IMAGE_MIN_SIZE_PX:
                continue  # icon, khong phai anh minh hoa that
            rects = page.get_image_rects(xref)
            if not rects:
                continue
            img_y0 = rects[0].y0

            # Tim headword gan nhat PHIA TREN anh (y0 nho hon, lon nhat
            # trong so cac headword thoa dieu kien).
            candidate = None
            for r in page_rows:
                if r._y0 <= img_y0:
                    candidate = r
                else:
                    break
            if candidate is None:
                continue  # anh nam truoc headword dau tien tren trang - bo qua

            # Gom TOAN BO cac dong cung 1 muc tu (cung meaning_vi +
            # source_page) - vd "life vest"/"life jacket" deu la cac dong
            # rieng cua chung 1 muc "ao phao". Dat ten file theo dong
            # DAU TIEN xuat hien trong rows (thu tu doc PDF), khong phai
            # candidate (co the la dong thu 2, 3...).
            group = [
                r
                for r in rows
                if r.meaning_vi == candidate.meaning_vi
                and r.source_page == candidate.source_page
                and r.is_subentry == candidate.is_subentry
            ]
            first_word = group[0].word if group else candidate.word

            # Them source_page vao ten file de tranh trung: cung 1 tu
            # tieng Anh co the xuat hien o 2 chuyen nganh khac nhau voi
            # nghia/anh minh hoa khac nhau (vd "filter", "bearing",
            # "indicator" deu co o ca Co dien lan Thong tin ra da - da
            # phat hien khi kiem tra sau lan chay full dau tien, xem lich
            # su hoi thoai task) - neu chi dung ten tu se bi ghi de nham.
            # Luu JPEG thay vi PNG: anh minh hoa that trong PDF von da
            # nen DCTDecode (JPEG) tu dau (xem khao sat get_images() -
            # Image269 tr.7 la DCTDecode) - decode ra roi ep ve PNG
            # khong nen lam phinh dung luong khong can thiet (~33MB cho
            # 261 anh o muc PNG mac dinh). JPEG quality=85 giu chat
            # luong gan nhu khong doi, giam dung luong dang ke.
            filename = f"{slugify(first_word)}_p{candidate.source_page}.jpg"
            out_path = os.path.join(image_dir, filename)
            pix = fitz.Pixmap(doc, xref)
            if pix.alpha:  # JPEG khong ho tro kenh alpha, phai bo truoc
                pix = fitz.Pixmap(pix, 0)
            if pix.n - pix.alpha >= 4:  # CMYK -> chuyen ve RGB truoc khi luu
                pix = fitz.Pixmap(fitz.csRGB, pix)
            pix.save(out_path, jpg_quality=85)
            for r in group:
                r.image_path = f"{IMAGE_PATH_PREFIX}/{filename}"
            assigned_count += 1

    print(f"Extracted {assigned_count} illustration images -> {image_dir}/")


def write_csv(rows: list[WordRow], path: str) -> None:
    fieldnames = [
        "source_page",
        "dictionary_name",
        "word",
        "phonetic",
        "part_of_speech_raw",
        "part_of_speech_code",
        "meaning_vi",
        "is_subentry",
        "example_en",
        "example_vi",
        "image_path",
        "reviewed",
    ]
    with open(path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for r in rows:
            writer.writerow(
                {
                    "source_page": r.source_page,
                    "dictionary_name": r.dictionary_name,
                    "word": r.word,
                    "phonetic": r.phonetic,
                    "part_of_speech_raw": r.part_of_speech_raw,
                    "part_of_speech_code": r.part_of_speech_code
                    if r.part_of_speech_code is not None
                    else "",
                    "meaning_vi": r.meaning_vi,
                    "is_subentry": r.is_subentry,
                    "example_en": r.example_en,
                    "example_vi": r.example_vi,
                    "image_path": r.image_path,
                    "reviewed": r.reviewed,
                }
            )


def main() -> None:
    first, last = FIRST_PAGE_IDX, LAST_PAGE_IDX
    if len(sys.argv) >= 3:
        first, last = int(sys.argv[1]), int(sys.argv[2])

    spans = load_spans(PDF_PATH, first, last)
    rows = extract(spans)
    extract_images_and_assign(PDF_PATH, rows, first, last, IMAGE_DIR)
    write_csv(rows, OUTPUT_CSV)
    print(f"Extracted {len(rows)} rows from pages {first + 1}-{last + 1} -> {OUTPUT_CSV}")

    no_word = sum(1 for r in rows if not r.word)
    no_pos = sum(1 for r in rows if r.part_of_speech_code is None and r.part_of_speech_raw)
    print(f"Rows with empty word (needs manual review): {no_word}")
    print(f"Rows with unmapped part_of_speech (needs manual review): {no_pos}")


if __name__ == "__main__":
    main()
