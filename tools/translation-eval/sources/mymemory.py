"""Goi MyMemory Translation API - cung nguon dung trong app
(lib/data/services/dictionary_api_service.dart, translate()), mien phi,
khong can key.
"""

from __future__ import annotations

import time

import requests

_ENDPOINT = "https://api.mymemory.translated.net/get"


def translate(text: str, timeout: float = 10.0, retries: int = 2) -> str | None:
    """Tra ve ban dich hoac None neu loi/timeout sau khi retry."""
    params = {"q": text, "langpair": "en|vi"}
    last_err: Exception | None = None
    for attempt in range(retries + 1):
        try:
            resp = requests.get(_ENDPOINT, params=params, timeout=timeout)
            resp.raise_for_status()
            data = resp.json()
            translated = data.get("responseData", {}).get("translatedText")
            if translated:
                return translated
            last_err = RuntimeError(f"empty responseData: {data}")
        except Exception as e:  # noqa: BLE001 - ghi lai loi de report, khong chan batch
            last_err = e
            time.sleep(1.0)
    print(f"[mymemory] failed for {text!r}: {last_err}")
    return None
