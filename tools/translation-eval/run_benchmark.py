"""Chay benchmark dich qua 3 nguon (MyMemory online, opus-mt on-device
hien tai, Qwen2.5-3B-Instruct ung vien) tren testset.jsonl, cham diem
chrF++ (do troi chay) + ty le thuat ngu dung (do chinh xac domain), va
xuat report. Xem tools/translation-eval/README.md.

Vi du chay:
    python run_benchmark.py --sources mymemory,opus_mt,qwen2.5-3b
    python run_benchmark.py --sources mymemory --limit 5   # test nhanh
"""

from __future__ import annotations

import argparse
import json
import time
from datetime import datetime
from pathlib import Path

import psutil
from sacrebleu.metrics import CHRF

_HERE = Path(__file__).resolve().parent
_TESTSET_PATH = _HERE / "testset.jsonl"
_RESULTS_DIR = _HERE / "results"

# Import tung module theo yeu cau (khong import het o dau file) - moi
# nguon keo theo dependency nang khac nhau (onnxruntime cho opus_mt,
# llama-cpp-python cho qwen2.5-3b); chi mymemory la nhe (chi can
# requests). Tranh bat nguoi dung phai cai het moi thu chi de chay 1
# nguon nhe khi test nhanh.
_SOURCE_MODULES = {
    "mymemory": "sources.mymemory",
    "opus_mt": "sources.opus_mt",
    "qwen2.5-3b": "sources.qwen_llm",
}


def _load_source_fn(name: str):
    import importlib

    module = importlib.import_module(_SOURCE_MODULES[name])
    return module.translate


def load_testset(limit: int | None = None) -> list[dict]:
    items = []
    with _TESTSET_PATH.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                items.append(json.loads(line))
    return items[:limit] if limit else items


_VI_STOPWORDS = {
    "những", "các", "trong", "của", "và", "là", "có", "được", "cho", "khi",
    "này", "đó", "với", "một", "để", "bị", "đã", "sẽ", "hay", "hoặc", "như",
    "từ", "về", "trên", "dưới", "theo", "tại", "còn", "vào", "ra", "lên",
    "xuống", "cũng", "rất", "nên", "phải", "bằng", "qua", "sau", "trước",
}


def term_hit(translation: str | None, vi_ref: str) -> bool:
    """Danh gia 'dung thuat ngu' theo kieu long: vi_ref co the co nhieu
    nghia phan cach boi ';' (dac diem du lieu tu dien nguon, xem
    build_testset.py) - tinh la dung neu ban dich chua BAT KY tu khoa
    nao trung voi 1 trong cac nghia (so sanh substring, khong phan biet
    hoa/thuong) - dung cho danh gia nhanh, KHONG thay the review thu
    cong (xem ghi chu trong README.md).
    """
    if not translation:
        return False
    t = translation.lower()
    for sense in vi_ref.split(";"):
        sense = sense.strip().lower()
        if not sense:
            continue
        # Lay tu/cum quan trong nhat: bo tu qua ngan VA bo stopword tieng
        # Viet (tu de/gioi tu/lien tu pho bien) - neu khong, cac tu nhu
        # "nhung", "trong" se khop nham voi bat ky ban dich nao co dung
        # cau truc cau, du dich sai hoan toan noi dung (da phat hien
        # thuc te qua self-verify tren mau opus_mt "packer"/"padding").
        keywords = [
            w
            for w in sense.replace(",", " ").split()
            if len(w) >= 3 and w.lower() not in _VI_STOPWORDS
        ]
        if keywords and any(kw in t for kw in keywords):
            return True
    return False


def run_source(name: str, items: list[dict]) -> dict:
    fn = _load_source_fn(name)
    rows = []
    process = psutil.Process()
    rss_before = process.memory_info().rss

    peak_rss = rss_before
    total_time = 0.0
    for item in items:
        start = time.time()
        translation = fn(item["en"])
        elapsed = time.time() - start
        total_time += elapsed
        peak_rss = max(peak_rss, process.memory_info().rss)
        rows.append(
            {
                "id": item["id"],
                "type": item["type"],
                "en": item["en"],
                "vi_ref": item["vi_ref"],
                "translation": translation,
                "seconds": round(elapsed, 2),
            }
        )
        print(f"  [{name}] {item['id']} ({elapsed:.1f}s): {translation!r}")

    # chrF chi tinh tren "sentence" - "term" co vi_ref la nhieu nghia
    # noi boi ';' (vd "sự chiếm đóng; sự giữ; ..."), so ky tu voi 1 ban
    # dich ngan se cho diem thap gia tao du dung nghia (xem term_hit()
    # cho do do chinh xac thuc su cua nhom "term"). Tach rieng tranh
    # hieu lam diem chrF thap = dich sai.
    chrf = CHRF()

    def chrf_for(rows_subset: list[dict]) -> float:
        scored = [r for r in rows_subset if r["translation"]]
        if not scored:
            return 0.0
        return round(
            chrf.corpus_score(
                [r["translation"] for r in scored], [[r["vi_ref"] for r in scored]]
            ).score,
            2,
        )

    sentence_rows = [r for r in rows if r["type"] == "sentence"]
    chrf_score = chrf_for(sentence_rows)

    term_items = [r for r in rows if r["type"] == "term"]
    term_hits = sum(1 for r in term_items if term_hit(r["translation"], r["vi_ref"]))
    term_accuracy = (term_hits / len(term_items) * 100) if term_items else None

    failures = sum(1 for r in rows if not r["translation"])

    return {
        "name": name,
        "rows": rows,
        "chrf": round(chrf_score, 2),
        "term_accuracy_pct": round(term_accuracy, 1) if term_accuracy is not None else None,
        "avg_seconds": round(total_time / len(items), 2) if items else 0.0,
        "peak_rss_mb": round(peak_rss / (1024 * 1024), 1),
        "failures": failures,
        "n_items": len(items),
    }


def write_report(source_results: list[dict], testset_size: int) -> Path:
    _RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    report_path = _RESULTS_DIR / f"{ts}-report.md"
    detail_path = _RESULTS_DIR / f"{ts}-detail.jsonl"

    lines = [
        f"# Translation benchmark report ({ts})",
        "",
        f"Test set: {testset_size} items (`testset.jsonl`)",
        "",
        "| Source | chrF++ (sentence) | Term accuracy (term) | Avg sec/item | Peak RSS (MB) | Failures |",
        "|---|---|---|---|---|---|",
    ]
    for r in source_results:
        term_acc = f"{r['term_accuracy_pct']}%" if r["term_accuracy_pct"] is not None else "n/a"
        lines.append(
            f"| {r['name']} | {r['chrf']} | {term_acc} | {r['avg_seconds']}s "
            f"| {r['peak_rss_mb']} | {r['failures']}/{r['n_items']} |"
        )
    lines.append("")
    lines.append(
        "chrF++ chi tinh tren nhom 'sentence' (cao hon = troi chay hon). "
        "Term accuracy chi tinh tren nhom 'term' = ty le cum tu chuyen nganh "
        "dich trung 1 trong cac nghia tham chieu (so sanh keyword long, can "
        "review thu cong mau de xac nhan, khong phai chuan tuyet doi)."
    )
    report_path.write_text("\n".join(lines), encoding="utf-8")

    with detail_path.open("w", encoding="utf-8") as f:
        for r in source_results:
            for row in r["rows"]:
                f.write(json.dumps({"source": r["name"], **row}, ensure_ascii=False) + "\n")

    return report_path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", default="mymemory,opus_mt,qwen2.5-3b")
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    source_names = [s.strip() for s in args.sources.split(",") if s.strip()]
    for s in source_names:
        if s not in _SOURCE_MODULES:
            raise SystemExit(f"Unknown source {s!r}, choices: {list(_SOURCE_MODULES)}")

    items = load_testset(limit=args.limit)
    print(f"Loaded {len(items)} test items")

    source_results = []
    for name in source_names:
        print(f"\n=== Running source: {name} ===")
        source_results.append(run_source(name, items))

    report_path = write_report(source_results, len(items))
    print(f"\nReport written to {report_path}")


if __name__ == "__main__":
    main()
