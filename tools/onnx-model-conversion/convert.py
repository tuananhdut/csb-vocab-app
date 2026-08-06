"""Quantize INT8 bộ ONNX opus-mt (encoder/decoder/decoder_with_past) đã
export bằng optimum-cli, copy kèm tokenizer/config sang thư mục output.

Dùng quantize_dynamic trực tiếp (không dùng optimum.onnxruntime.
ORTQuantizer.quantize() -- API đó lỗi "Unable to find data type for
weight_name=..." trên graph MarianMT). Cũng KHÔNG gọi
onnxruntime.quantization.shape_inference.quant_pre_process trước --
graph MarianMT (nhiều nhánh past-key-value) khiến symbolic shape
inference lỗi "Incomplete symbolic shape inference". Workaround đã
verify hoạt động ổn định: quantize_dynamic + extra_options
DefaultTensorType=1 (FLOAT), bỏ qua bước pre-process.

Usage:
    python convert.py --input-dir out\\opus-mt-en-vi-onnx --output-dir out\\opus-mt-en-vi-onnx-quantized
"""

import argparse
import shutil
import sys
from pathlib import Path

# Console Windows mặc định dùng cp1252, không encode được tiếng Việt có
# dấu trong các message dưới đây -- ép UTF-8 để tránh UnicodeEncodeError.
if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

from onnxruntime.quantization import QuantType, quantize_dynamic

GRAPH_FILES = ["encoder_model.onnx", "decoder_model.onnx", "decoder_with_past_model.onnx"]
COPY_FILES = [
    "source.spm",
    "target.spm",
    "vocab.json",
    "config.json",
    "generation_config.json",
]


def quantize_graph(src: Path, dst: Path) -> tuple[float, float]:
    quantize_dynamic(
        model_input=str(src),
        model_output=str(dst),
        weight_type=QuantType.QInt8,
        extra_options={"DefaultTensorType": 1},
    )
    return src.stat().st_size / 1e6, dst.stat().st_size / 1e6


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()

    input_dir: Path = args.input_dir
    output_dir: Path = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    for name in GRAPH_FILES:
        src = input_dir / name
        if not src.exists():
            raise FileNotFoundError(
                f"Không tìm thấy {src}. Kiểm tra lại bộ file mà optimum-cli"
                f" thực tế đã xuất ra (xem README) -- có thể version optimum"
                f" khác dùng tên file khác (vd decoder_model_merged.onnx)."
            )
        dst = output_dir / name.replace(".onnx", "_quantized.onnx")
        before_mb, after_mb = quantize_graph(src, dst)
        print(f"{name}: {before_mb:.1f}MB -> {after_mb:.1f}MB")

    for name in COPY_FILES:
        src = input_dir / name
        if not src.exists():
            print(f"CẢNH BÁO: thiếu {src}, bỏ qua (kiểm tra lại nếu app cần file này lúc runtime).")
            continue
        shutil.copy2(src, output_dir / name)
        print(f"copied {name}")

    print(f"Xong. Output tại: {output_dir}")


if __name__ == "__main__":
    main()
