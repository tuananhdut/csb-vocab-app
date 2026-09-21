"""Chay model opus-mt on-device (ONNX, quantized) tu Python - mirror
chinh xac logic decode trong lib/data/services/translation_service.dart
(cung mot bo model da publish o GitHub Release `mt-models-v1`), de so
sanh cong bang voi nhanh fallback offline hien tai cua app.

Tai model tu GitHub Release ve tools/translation-eval/models/en-vi-v1/
(cache lai, khong tai lai neu da co). Khong dung torch/optimum (nang,
~800MB-1GB) - chi can onnxruntime + sentencepiece (nhe).
"""

from __future__ import annotations

import io
import json
import zipfile
from pathlib import Path

import numpy as np
import onnxruntime as ort
import requests
import sentencepiece as spm

_RELEASE_BASE = (
    "https://github.com/tuananhdut/csb-vocab-app/releases/download/mt-models-v1"
)
_MODEL_NAME = "en-vi-v1"
_MODELS_DIR = Path(__file__).resolve().parent.parent / "models"
_MAX_DECODE_STEPS = 128


class OpusMtTranslator:
    def __init__(self) -> None:
        self._dir = _MODELS_DIR / _MODEL_NAME
        self._ensure_downloaded()

        self._encoder = ort.InferenceSession(str(self._dir / "encoder_model_quantized.onnx"))
        self._decoder = ort.InferenceSession(str(self._dir / "decoder_model_quantized.onnx"))
        self._decoder_with_past = ort.InferenceSession(
            str(self._dir / "decoder_with_past_model_quantized.onnx")
        )
        self._sp = spm.SentencePieceProcessor(model_file=str(self._dir / "source.spm"))

        vocab = json.loads((self._dir / "vocab.json").read_text(encoding="utf-8"))
        self._piece_to_id: dict[str, int] = vocab
        self._id_to_piece: dict[int, str] = {v: k for k, v in vocab.items()}
        self._unk_id = 1

        config = json.loads((self._dir / "config.json").read_text(encoding="utf-8"))
        self._decoder_start_token_id = config["decoder_start_token_id"]
        self._eos_token_id = config["eos_token_id"]
        self._decoder_layers = config["decoder_layers"]

    def _ensure_downloaded(self) -> None:
        marker = self._dir / ".ready"
        if marker.exists():
            return
        self._dir.mkdir(parents=True, exist_ok=True)
        print(f"[opus_mt] downloading {_MODEL_NAME}.zip (~137MB, one-time)...")
        resp = requests.get(f"{_RELEASE_BASE}/{_MODEL_NAME}.zip", timeout=120)
        resp.raise_for_status()
        with zipfile.ZipFile(io.BytesIO(resp.content)) as zf:
            zf.extractall(self._dir)
        marker.write_text("ok", encoding="utf-8")
        print("[opus_mt] download + extract done")

    def _pieces_to_ids(self, pieces: list[str]) -> list[int]:
        return [self._piece_to_id.get(p, self._unk_id) for p in pieces]

    def _ids_to_text(self, ids: list[int]) -> str:
        pieces = [self._id_to_piece.get(i, "") for i in ids]
        text = "".join(p for p in pieces if p)
        return text.replace("▁", " ").strip()

    def translate(self, text: str) -> str:
        if not text.strip():
            return ""

        pieces = self._sp.encode(text, out_type=str)
        input_ids = self._pieces_to_ids(pieces) + [self._eos_token_id]
        seq_len = len(input_ids)

        input_ids_arr = np.array([input_ids], dtype=np.int64)
        attention_mask_arr = np.ones((1, seq_len), dtype=np.int64)

        encoder_out = self._encoder.run(
            None, {"input_ids": input_ids_arr, "attention_mask": attention_mask_arr}
        )
        encoder_output_names = [o.name for o in self._encoder.get_outputs()]
        encoder_hidden_states = encoder_out[encoder_output_names.index("last_hidden_state")]

        current_token = self._decoder_start_token_id
        generated_ids: list[int] = []
        past_kv: dict[str, np.ndarray] | None = None

        for step in range(_MAX_DECODE_STEPS):
            decoder_input_ids = np.array([[current_token]], dtype=np.int64)

            if step == 0:
                inputs = {
                    "input_ids": decoder_input_ids,
                    "encoder_hidden_states": encoder_hidden_states,
                    "encoder_attention_mask": attention_mask_arr,
                }
                outputs = self._decoder.run(None, inputs)
                output_names = [o.name for o in self._decoder.get_outputs()]
            else:
                inputs = {
                    "input_ids": decoder_input_ids,
                    "encoder_attention_mask": attention_mask_arr,
                    **past_kv,
                }
                outputs = self._decoder_with_past.run(None, inputs)
                output_names = [o.name for o in self._decoder_with_past.get_outputs()]

            out = dict(zip(output_names, outputs))
            logits = out["logits"]
            current_token = int(np.argmax(logits[0, -1, :]))

            if current_token == self._eos_token_id:
                break
            generated_ids.append(current_token)

            # Model nho (opus-mt) de roi vao vong lap sinh cung 1 token
            # lien tuc khi input la 1 tu/cum ngan dung rieng khong co
            # ngu canh cau (quan sat thuc te tren testset "term") -
            # KHONG phai loi decode loop (da doi chieu voi cau day du,
            # ra ket qua dung). Dung som thay vi chay het 128 buoc sinh
            # toan token lap, danh dau ro trong ban dich de report khong
            # bi nhieu boi 1 chuoi rac dai.
            if len(generated_ids) >= 6 and len(set(generated_ids[-6:])) == 1:
                return self._ids_to_text(generated_ids[:-5]) + " [[degenerate-repeat]]"

            next_past_kv: dict[str, np.ndarray] = {}
            for l in range(self._decoder_layers):
                next_past_kv[f"past_key_values.{l}.decoder.key"] = out[f"present.{l}.decoder.key"]
                next_past_kv[f"past_key_values.{l}.decoder.value"] = out[
                    f"present.{l}.decoder.value"
                ]
                if step == 0:
                    next_past_kv[f"past_key_values.{l}.encoder.key"] = out[
                        f"present.{l}.encoder.key"
                    ]
                    next_past_kv[f"past_key_values.{l}.encoder.value"] = out[
                        f"present.{l}.encoder.value"
                    ]
                else:
                    next_past_kv[f"past_key_values.{l}.encoder.key"] = past_kv[
                        f"past_key_values.{l}.encoder.key"
                    ]
                    next_past_kv[f"past_key_values.{l}.encoder.value"] = past_kv[
                        f"past_key_values.{l}.encoder.value"
                    ]
            past_kv = next_past_kv

        return self._ids_to_text(generated_ids)


_singleton: OpusMtTranslator | None = None


def translate(text: str) -> str | None:
    global _singleton
    try:
        if _singleton is None:
            _singleton = OpusMtTranslator()
        return _singleton.translate(text)
    except Exception as e:  # noqa: BLE001
        print(f"[opus_mt] failed for {text!r}: {e}")
        return None
