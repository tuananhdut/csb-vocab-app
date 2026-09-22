"""Chay model VietAI/envit5-translation (T5, ONNX cong dong tu
phatjk/envit5-translation-onnx - VietAI khong tu publish ban ONNX) de
so sanh voi opus-mt/Qwen2.5-3B/MyMemory tren cung testset.

Khac opus-mt: 1 model dung chung ca 2 chieu qua prefix "en: "/"vi: "
(T5 text-to-text), khong can vocab.json rieng - sentencepiece decode
thang ra id model dung (spiece.model dung lam vocab, khong nhu Marian
opus-mt can remap qua vocab.json rieng).

Tai FP32 (~2GB, chua quantize) tu HuggingFace ve
tools/translation-eval/models/envit5-onnx/ (cache lai, khong tai lai
neu da co). Day la BUOC BENCHMARK - neu so lieu tot se quantize INT8
rieng truoc khi host/tich hop vao app (xem TODO ke hoach), khong lam
quantize o day de giu script don gian cho muc dich do chat luong truoc.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import onnxruntime as ort
import requests
import sentencepiece as spm

_HF_BASE = "https://huggingface.co/phatjk/envit5-translation-onnx/resolve/main"
_FILES = [
    "encoder_model.onnx",
    "decoder_model.onnx",
    "decoder_with_past_model.onnx",
    "spiece.model",
]
_MODELS_DIR = Path(__file__).resolve().parent.parent / "models"
_MODEL_NAME = "envit5-onnx"
_MAX_DECODE_STEPS = 128
_DECODER_START_TOKEN_ID = 0  # = pad_token_id, chuan T5
_EOS_TOKEN_ID = 1
_NUM_DECODER_LAYERS = 12


class Envit5Translator:
    def __init__(self) -> None:
        self._dir = _MODELS_DIR / _MODEL_NAME
        self._ensure_downloaded()

        self._encoder = ort.InferenceSession(str(self._dir / "encoder_model.onnx"))
        self._decoder = ort.InferenceSession(str(self._dir / "decoder_model.onnx"))
        self._decoder_with_past = ort.InferenceSession(
            str(self._dir / "decoder_with_past_model.onnx")
        )
        self._sp = spm.SentencePieceProcessor(model_file=str(self._dir / "spiece.model"))

    def _ensure_downloaded(self) -> None:
        marker = self._dir / ".ready"
        if marker.exists():
            return
        self._dir.mkdir(parents=True, exist_ok=True)
        for name in _FILES:
            dest = self._dir / name
            print(f"[envit5] downloading {name} (one-time)...")
            resp = requests.get(f"{_HF_BASE}/{name}", timeout=300)
            resp.raise_for_status()
            dest.write_bytes(resp.content)
        marker.write_text("ok", encoding="utf-8")
        print("[envit5] download done")

    def translate(self, text: str, *, source_lang: str = "en") -> str:
        if not text.strip():
            return ""

        prefixed = f"{source_lang}: {text}"
        input_ids = self._sp.encode(prefixed, out_type=int) + [_EOS_TOKEN_ID]
        seq_len = len(input_ids)

        input_ids_arr = np.array([input_ids], dtype=np.int64)
        attention_mask_arr = np.ones((1, seq_len), dtype=np.int64)

        encoder_out = self._encoder.run(
            None, {"input_ids": input_ids_arr, "attention_mask": attention_mask_arr}
        )
        encoder_output_names = [o.name for o in self._encoder.get_outputs()]
        encoder_hidden_states = encoder_out[encoder_output_names.index("last_hidden_state")]

        current_token = _DECODER_START_TOKEN_ID
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
                # Khac opus-mt: graph ONNX cua envit5 (cong dong export)
                # khai bao encoder_hidden_states la input bat buoc ca o
                # decoder_with_past (du past_key_values.*.encoder.* da
                # mang du thong tin) - thieu se bao loi "Required inputs
                # missing" (da xac nhan qua session.get_inputs()).
                inputs = {
                    "input_ids": decoder_input_ids,
                    "encoder_hidden_states": encoder_hidden_states,
                    "encoder_attention_mask": attention_mask_arr,
                    **past_kv,
                }
                outputs = self._decoder_with_past.run(None, inputs)
                output_names = [o.name for o in self._decoder_with_past.get_outputs()]

            out = dict(zip(output_names, outputs))
            logits = out["logits"]
            current_token = int(np.argmax(logits[0, -1, :]))

            if current_token == _EOS_TOKEN_ID:
                break
            generated_ids.append(current_token)

            # Cung guard nhu opus_mt.py - phong truong hop model nho lap
            # vo han khi input ngan dung rieng, danh dau ro trong ban
            # dich thay vi chay het 128 buoc sinh toan token lap.
            if len(generated_ids) >= 6 and len(set(generated_ids[-6:])) == 1:
                return self._sp.decode(generated_ids[:-5]) + " [[degenerate-repeat]]"

            next_past_kv: dict[str, np.ndarray] = {}
            for l in range(_NUM_DECODER_LAYERS):
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

        decoded = self._sp.decode(generated_ids)
        # Model sinh ca prefix ngon ngu dich ("vi: "/"en: ") ngay dau ban
        # dich - dung voi cach VietAI demo trong model card, nhung API
        # nay chi can noi dung dich, khong can prefix lap lai.
        for prefix in ("vi:", "en:"):
            if decoded.lower().startswith(prefix):
                decoded = decoded[len(prefix):].strip()
                break
        return decoded


_singleton: Envit5Translator | None = None


def translate(text: str) -> str | None:
    global _singleton
    try:
        if _singleton is None:
            _singleton = Envit5Translator()
        return _singleton.translate(text, source_lang="en")
    except Exception as e:  # noqa: BLE001
        print(f"[envit5] failed for {text!r}: {e}")
        return None
