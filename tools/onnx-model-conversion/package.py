"""Đóng gói thư mục model đã quantize thành 1 file zip + MANIFEST.json
(size + SHA-256) để upload lên GitHub Releases.

Usage:
    python package.py --input-dir out\\opus-mt-en-vi-onnx-quantized --name en-vi-v1 --output-dir out
"""

import argparse
import hashlib
import json
import sys
import zipfile
from pathlib import Path

if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", required=True, type=Path, help="Thư mục chứa model đã quantize")
    parser.add_argument("--name", required=True, help="Tên gói, vd en-vi-v1 -> en-vi-v1.zip")
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()

    input_dir: Path = args.input_dir
    output_dir: Path = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    zip_path = output_dir / f"{args.name}.zip"
    manifest_path = output_dir / f"{args.name}.manifest.json"

    files = sorted(p for p in input_dir.iterdir() if p.is_file())
    if not files:
        raise FileNotFoundError(f"Không có file nào trong {input_dir}")

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in files:
            zf.write(f, arcname=f.name)
            print(f"zipped {f.name} ({f.stat().st_size / 1e6:.1f}MB)")

    manifest = {
        "name": args.name,
        "file": zip_path.name,
        "sizeBytes": zip_path.stat().st_size,
        "sha256": sha256_of(zip_path),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(f"Zip: {zip_path} ({manifest['sizeBytes'] / 1e6:.1f}MB)")
    print(f"Manifest: {manifest_path}")
    print(f"SHA-256: {manifest['sha256']}")


if __name__ == "__main__":
    main()
