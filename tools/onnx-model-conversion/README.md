# Convert opus-mt sang ONNX (dịch offline En⇄Vi)

Quy trình một lần, chạy ngoài runtime của app Flutter, để tạo ra bộ file
ONNX + tokenizer dùng cho tính năng dịch on-device (FR-4). Xem
`docs/spec_history.md` [IMPL-017] và `docs/csb-vocab-analysis/04_Translate.md`
cho bối cảnh quyết định.

**Không commit file `.onnx`/`.spm`/`.zip` output vào git** — quá nặng
(150-215MB/chiều sau quantize). Output được upload lên GitHub Releases
của repo này, app tải về lúc runtime (xem Phase 2-3 của kế hoạch).

## Yêu cầu

- Python 3.12 (khuyến nghị venv riêng, không cài vào Python hệ thống — các
  gói này khá nặng, ~800MB-1GB do kéo theo `torch`).
- Windows: bật "Long Path support" hoặc dùng venv ở đường dẫn ngắn (vd
  `C:\pyenv\...`) để tránh lỗi `MAX_PATH` khi cài `onnxruntime`.

## Cài đặt

```powershell
python -m venv C:\pyenv\onnxconv
C:\pyenv\onnxconv\Scripts\python.exe -m pip install --upgrade pip
C:\pyenv\onnxconv\Scripts\python.exe -m pip install -r requirements.txt
```

## Bước 1 — Export ONNX từ checkpoint gốc Helsinki-NLP

```powershell
C:\pyenv\onnxconv\Scripts\optimum-cli.exe export onnx `
  --model Helsinki-NLP/opus-mt-en-vi `
  --task text2text-generation-with-past `
  --optimize O2 `
  out\opus-mt-en-vi-onnx\

C:\pyenv\onnxconv\Scripts\optimum-cli.exe export onnx `
  --model Helsinki-NLP/opus-mt-vi-en `
  --task text2text-generation-with-past `
  --optimize O2 `
  out\opus-mt-vi-en-onnx\
```

Với `optimum==2.1.0`/`optimum-onnx==0.1.0` (version đã verify), lệnh này
xuất ra 3 file ONNX riêng biệt — **không** gộp thành 1 file
`decoder_model_merged.onnx`:

- `encoder_model.onnx` (~187MB float32)
- `decoder_model.onnx` (~322MB float32) — dùng cho bước decode đầu tiên
  (không có KV-cache)
- `decoder_with_past_model.onnx` (~310MB float32) — dùng cho các bước
  decode sau, nhận `past_key_values.*` và trả `present.*`
- `source.spm`, `target.spm` — tokenizer SentencePiece
- `vocab.json` — **bắt buộc phải giữ lại**, xem ghi chú tokenizer bên dưới
- `config.json` — chứa `pad_token_id`/`decoder_start_token_id`/`eos_token_id`

Nếu convert bằng version `optimum` khác, kiểm tra lại danh sách file thực
tế xuất ra (có thể có `decoder_model_merged.onnx` gộp `use_cache_branch`
thay vì 2 file riêng) và điều chỉnh `convert.ps1`/logic app tương ứng —
đừng giả định danh sách file trên là cố định.

## Bước 2 — Quantize INT8 (giảm dung lượng ~75%)

Dùng thẳng `onnxruntime.quantization` (không dùng `optimum.onnxruntime. ORTQuantizer.quantize()` — API wrapper đó lỗi
`RuntimeError: Unable to find data type for weight_name=...` trên các
graph MarianMT do `optimum` xuất ra, vì thiếu shape inference đầy đủ
trước khi quantize; `onnxruntime.quantization.quantize_dynamic` gọi trực
tiếp + `extra_options={'DefaultTensorType': 1}` (1 = FLOAT) chạy ổn định
và cho kết quả đúng — đã verify bằng cách chạy lại POC dịch trên Windows
với model quantize và so khớp với bản float32 gốc).

```powershell
C:\pyenv\onnxconv\Scripts\python.exe convert.py `
  --input-dir out\opus-mt-en-vi-onnx `
  --output-dir out\opus-mt-en-vi-onnx-quantized
C:\pyenv\onnxconv\Scripts\python.exe convert.py `
  --input-dir out\opus-mt-vi-en-onnx `
  --output-dir out\opus-mt-vi-en-onnx-quantized
```

Kích thước sau quantize (đo thực tế, model en-vi):

| File                         | Trước | Sau   | Giảm |
| ---------------------------- | ------- | ----- | ----- |
| encoder_model.onnx           | 186.7MB | ~47MB | ~75%  |
| decoder_model.onnx           | 322.2MB | ~81MB | ~75%  |
| decoder_with_past_model.onnx | 309.6MB | ~78MB | ~75%  |

Tổng ~206MB/chiều (khớp ước tính ban đầu ~150-215MB).

## Ghi chú quan trọng: tokenizer Marian dùng `vocab.json`, KHÔNG dùng ID thô của `.spm`

Marian/opus-mt có 1 tầng ánh xạ `piece → id` riêng qua `vocab.json`,
**khác hoàn toàn** thứ tự ID nội bộ trong file `source.spm`/`target.spm`.
Đã verify thực tế: dùng ID thô từ thư viện SentencePiece thuần (không đi
qua `vocab.json`) làm encoder nhận input sai hoàn toàn, decode ra rác dù
model và decode loop đều đúng.

**Bắt buộc đóng gói `vocab.json` cùng bộ model** khi phân phối — cách
dùng đúng ở phía app (Dart):

1. Dùng thư viện SentencePiece thuần (`dart_sentencepiece_tokenizer`) chỉ
   để **segment câu thành piece** (`encode(text).tokens`), không dùng
   `.ids` của thư viện này.
2. Tự map `piece → id` (encode) và `id → piece` (decode) qua
   `vocab.json`, token không có trong vocab → dùng id của `<unk>`.
3. Khi ghép piece lại thành câu: nối trực tiếp rồi thay `▁` (U+2581)
   bằng khoảng trắng.

Xem `lib/data/services/translation_service.dart` (app Flutter) cho cách
implement cụ thể — logic này đã được POC xác nhận cho ra bản dịch khớp
100% với inference bằng `transformers`/PyTorch gốc.

## Bước 3 — Đóng gói & upload

Dùng `package.py` (không dùng `Compress-Archive` thuần — script này tự
tính SHA-256 và ghi kèm `*.manifest.json` để app verify integrity lúc
tải về):

```powershell
C:\pyenv\onnxconv\Scripts\python.exe package.py `
  --input-dir out\opus-mt-en-vi-onnx-quantized --name en-vi-v1 --output-dir out\release
C:\pyenv\onnxconv\Scripts\python.exe package.py `
  --input-dir out\opus-mt-vi-en-onnx-quantized --name vi-en-v1 --output-dir out\release
```

Output: `en-vi-v1.zip` + `en-vi-v1.manifest.json`, `vi-en-v1.zip` +
`vi-en-v1.manifest.json`. Kích thước zip thực tế (ONNX nén được thêm
~35% qua DEFLATE, tốt hơn ước tính ban đầu):

| Gói | Size thư mục quantize | Size zip |
|---|---|---|
| en-vi-v1 | 209.5MB | 136.7MB |
| vi-en-v1 | 208.1MB | 133.3MB |

Upload cả 4 file lên GitHub Release:

```powershell
gh release create mt-models-v1 out\release\en-vi-v1.zip out\release\en-vi-v1.manifest.json `
  out\release\vi-en-v1.zip out\release\vi-en-v1.manifest.json `
  --title "MT models v1 (opus-mt en<->vi, ONNX INT8 quantized)" `
  --notes "On-device translation models for FR-4. Apache-2.0 licensed (inherited from Helsinki-NLP source models)."
```

Release đã publish tại:
<https://github.com/tuananhdut/csb-vocab-app/releases/tag/mt-models-v1>

App tải file zip trực tiếp qua URL dạng:
`https://github.com/tuananhdut/csb-vocab-app/releases/download/mt-models-v1/en-vi-v1.zip`
(và tương tự cho `vi-en-v1.zip`, `*.manifest.json`) — xem thiết kế
`ModelDownloadService` trong kế hoạch triển khai FR-4 (Phase 3).
