"""Chay Qwen2.5-3B-Instruct (GGUF, quantize Q4_K_M) cuc bo qua
llama-cpp-python - ung vien moi dang danh gia (xem task-brainstorm/
task-plan hoi thoai truoc). Chi dung cho benchmark ngoai app, KHONG
phai runtime cua app Flutter.
"""

from __future__ import annotations

import time
from pathlib import Path

import requests

_REPO = "Qwen/Qwen2.5-3B-Instruct-GGUF"
_FILENAME = "qwen2.5-3b-instruct-q4_k_m.gguf"
_HF_URL = f"https://huggingface.co/{_REPO}/resolve/main/{_FILENAME}"
_MODELS_DIR = Path(__file__).resolve().parent.parent / "models"

_SYSTEM_PROMPT = (
    "You are a professional English-to-Vietnamese translator specialized in "
    "maritime and military terminology (Vietnam Coast Guard domain). "
    "Translate the given English text to Vietnamese. "
    "Reply with ONLY the Vietnamese translation, no explanation, no quotes."
)


class QwenTranslator:
    def __init__(self, n_ctx: int = 2048, n_threads: int | None = None) -> None:
        from llama_cpp import Llama  # import cuc bo - dependency nang, chi can khi thuc su chay

        model_path = self._ensure_downloaded()
        self.peak_load_start = time.time()
        self._llm = Llama(
            model_path=str(model_path),
            n_ctx=n_ctx,
            n_threads=n_threads,
            verbose=False,
        )
        self.load_seconds = time.time() - self.peak_load_start

    def _ensure_downloaded(self) -> Path:
        _MODELS_DIR.mkdir(parents=True, exist_ok=True)
        dest = _MODELS_DIR / _FILENAME
        if dest.exists():
            return dest
        print(f"[qwen_llm] downloading {_FILENAME} (~2.1GB, one-time)...")
        with requests.get(_HF_URL, stream=True, timeout=600) as resp:
            resp.raise_for_status()
            tmp = dest.with_suffix(".part")
            with tmp.open("wb") as f:
                for chunk in resp.iter_content(chunk_size=1024 * 1024):
                    f.write(chunk)
            tmp.rename(dest)
        print("[qwen_llm] download done")
        return dest

    def translate(self, text: str, max_tokens: int = 256) -> str:
        messages = [
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": text},
        ]
        result = self._llm.create_chat_completion(
            messages=messages,
            max_tokens=max_tokens,
            temperature=0.1,
        )
        return result["choices"][0]["message"]["content"].strip()


_singleton: QwenTranslator | None = None


def translate(text: str) -> str | None:
    global _singleton
    try:
        if _singleton is None:
            _singleton = QwenTranslator()
        return _singleton.translate(text)
    except Exception as e:  # noqa: BLE001
        print(f"[qwen_llm] failed for {text!r}: {e}")
        return None
