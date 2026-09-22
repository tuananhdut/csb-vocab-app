"""One-off script: quantize INT8 (dynamic) 3 file ONNX cua envit5 da tai
ve luc benchmark (models/envit5-onnx/), ghi ra models/envit5-onnx-quantized/
cung spiece.model + config.json toi thieu de app doc. Khong phai code app -
chi chay 1 lan de chuan bi asset truoc khi tao GitHub Release.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from onnxruntime.quantization import QuantType, quantize_dynamic

_SRC = Path(__file__).resolve().parent / "models" / "envit5-onnx"
_DST = Path(__file__).resolve().parent / "models" / "envit5-onnx-quantized"

_FILES = ["encoder_model.onnx", "decoder_model.onnx", "decoder_with_past_model.onnx"]


def main() -> None:
    _DST.mkdir(parents=True, exist_ok=True)

    for name in _FILES:
        src = _SRC / name
        dst = _DST / name.replace(".onnx", "_quantized.onnx")
        print(f"[quantize] {name} -> {dst.name} ...")
        quantize_dynamic(
            model_input=str(src),
            model_output=str(dst),
            weight_type=QuantType.QInt8,
        )
        before = src.stat().st_size / (1024 * 1024)
        after = dst.stat().st_size / (1024 * 1024)
        print(f"  {before:.1f}MB -> {after:.1f}MB")

    # spiece.model khong quantize duoc (khong phai ONNX) - copy nguyen.
    spiece_src = _SRC / "spiece.model"
    spiece_dst = _DST / "spiece.model"
    spiece_dst.write_bytes(spiece_src.read_bytes())

    config = {
        "decoder_start_token_id": 0,
        "eos_token_id": 1,
        "num_decoder_layers": 12,
        "source": "VietAI/envit5-translation (T5-base), ONNX export cong dong "
        "phatjk/envit5-translation-onnx, quantized INT8 dynamic tu du an nay",
    }
    (_DST / "config.json").write_text(json.dumps(config, indent=2), encoding="utf-8")

    print("\n[quantize] SHA-256 cua tung file (dung de dien vao ModelDownloadService):")
    for f in sorted(_DST.iterdir()):
        digest = hashlib.sha256(f.read_bytes()).hexdigest()
        size_mb = f.stat().st_size / (1024 * 1024)
        print(f"  {f.name}: {digest}  ({size_mb:.1f}MB)")


if __name__ == "__main__":
    main()
