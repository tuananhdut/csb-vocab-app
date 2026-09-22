"""Cham lai term_accuracy tu cac file *-detail.jsonl da co san (khong
goi lai API/model) - dung sau khi sua logic term_hit() trong
run_benchmark.py (vd bo stopword) de khong phai chay lai benchmark ton
kem.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from run_benchmark import term_hit

_RESULTS_DIR = Path(__file__).resolve().parent / "results"


def rescore(detail_path: Path) -> None:
    rows = [json.loads(line) for line in detail_path.open(encoding="utf-8")]
    by_source: dict[str, list[dict]] = {}
    for r in rows:
        by_source.setdefault(r["source"], []).append(r)

    for source, source_rows in by_source.items():
        terms = [r for r in source_rows if r["type"] == "term"]
        hits = sum(1 for r in terms if term_hit(r["translation"], r["vi_ref"]))
        pct = (hits / len(terms) * 100) if terms else 0.0
        print(f"{source}: term accuracy = {hits}/{len(terms)} = {pct:.1f}%")


if __name__ == "__main__":
    for path_str in sys.argv[1:]:
        p = Path(path_str)
        print(f"=== {p.name} ===")
        rescore(p)
