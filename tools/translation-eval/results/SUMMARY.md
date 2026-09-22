# Kết luận benchmark: MyMemory vs opus-mt (hiện tại) vs Qwen2.5-3B-Instruct

Test set: 60 câu (40 "term" chuyên ngành từ Military Dictionary + 20 "sentence"
tự nhiên từ bảng `examples`, xem `testset.jsonl`). Chạy trên máy dev (Windows),
đo RAM thực bằng RSS của tiến trình Python khi model đang load + inference.

| Nguồn | chrF++ (sentence, cao hơn=tốt hơn) | Term accuracy (term, đã lọc stopword) | Tốc độ TB/câu | Peak RAM |
|---|---|---|---|---|
| **MyMemory (online, đang dùng)** | **76.4** | **75.0%** | 1.4s | 42MB |
| opus-mt (on-device, đang dùng làm fallback) | 45.5 | 20.0% | 0.3s | 317MB |
| Qwen2.5-3B-Instruct (ứng viên) | 51.7 | 50.0% | 2.0s | 3.36GB |

## Kết luận chính

1. **Qwen2.5-3B KHÔNG vượt MyMemory** ở cả 2 tiêu chí trên test set này — MyMemory
   (nguồn online đang ưu tiên dùng) vẫn chính xác hơn rõ rệt (75% vs 50% term,
   76.4 vs 51.7 chrF). Không có lý do để thay MyMemory bằng Qwen2.5-3B khi có mạng.

2. **Qwen2.5-3B vượt trội hơn hẳn opus-mt** — nguồn đang dùng làm fallback offline
   hiện tại: term accuracy 50% vs 20% (gấp 2.5 lần), chrF 51.7 vs 45.5. opus-mt
   còn có vấn đề nghiêm trọng hơn: **lặp vô hạn ra rác** (`[[degenerate-repeat]]`)
   khi input là 1 từ/cụm ngắn đứng riêng — đúng kiểu input phổ biến khi user tra
   nhanh 1 thuật ngữ. => Nếu muốn nâng chất lượng **fallback offline**, Qwen2.5-3B
   là lựa chọn hợp lý hơn hẳn model hiện tại.

3. **RAM khả thi trên máy 8GB**: peak 3.36GB, đúng như ước tính ở brainstorm
   trước (2.5-3.5GB) — còn dư ~4.6GB cho OS + app khác, nhưng đây là số đo trên
   máy dev, KHÔNG phải máy 8GB thật của bạn — vẫn cần test lại trên đúng máy đích.

4. **Bug đáng lo: Qwen2.5-3B occasionally lặp ra tiếng Trung/Nhật** thay vì tiếng
   Việt (vd `term-008`: `'ph遗余'`, `term-028`: `'重建预备队'`, `sent-005`:
   `'LC 滤波指的是...'` toàn tiếng Trung). Đây là hành vi code-switching thường gặp
   ở model đa ngôn ngữ nhỏ, KHÔNG chấp nhận được nếu ship thẳng cho user — cần xử
   lý (system prompt mạnh hơn, hoặc lọc/validate output, hoặc thử model khác)
   trước khi tích hợp vào app.

5. **Tốc độ 2.0s/câu (CPU, greedy)** chấp nhận được cho use case offline fallback
   (không kỳ vọng nhanh như online), nhưng chậm hơn opus-mt hiện tại (0.3s) và
   MyMemory (1.4s) — cần cân nhắc UX (loading indicator rõ ràng hơn).

## Đã tự verify (self-check trước khi kết luận)

- Phát hiện và sửa 1 lỗi thật trong cách chấm điểm: `term_hit()` ban đầu tính
  nhầm các từ đệm tiếng Việt phổ biến ("những", "trong"...) là "khớp đúng nghĩa"
  — khiến vài bản dịch **hoàn toàn là rác** của opus-mt (vd `"Những bao
  [[degenerate-repeat]]"`) vẫn được tính điểm đúng. Đã thêm stopword filter
  (`_VI_STOPWORDS` trong `run_benchmark.py`) và chấm lại từ `*-detail.jsonl` đã
  lưu sẵn (không cần gọi lại model) — opus-mt giảm từ 22.5% xuống đúng 20.0%,
  MyMemory/Qwen không đổi.
- Đối chiếu thủ công 15 mẫu (5/nguồn) để xác nhận logic decode Python port khớp
  hành vi thật, không phải bug: test riêng opus-mt với câu đầy đủ ra kết quả hợp
  lý, xác nhận việc lặp vô hạn chỉ xảy ra với input ngắn đứng riêng — là hạn chế
  thật của model, không phải lỗi code.

## Khuyến nghị tiếp theo (KHÔNG tự làm, chờ bạn quyết định)

- Nếu muốn dùng Qwen2.5-3B: chỉ nên thay cho **opus-mt (fallback offline)**, giữ
  nguyên MyMemory làm nguồn chính khi online — khớp đúng kiến trúc hiện tại của
  app (`translation_providers.dart`), không cần đổi gì phía online.
- Bắt buộc xử lý bug lặp tiếng Trung/Nhật trước khi tích hợp — chưa an toàn để
  ship.
- Test set 60 câu là quy mô nhỏ, tín hiệu ban đầu rõ nhưng nên mở rộng nếu quyết
  định đầu tư tích hợp thật vào Flutter (out of scope của bước này).
- Việc tích hợp Qwen2.5-3B vào app Flutter (FFI/llama.cpp, tải model ~2.1GB,
  UI) **chưa được làm** — đây vẫn là quyết định cần bạn xác nhận riêng, vì chi
  phí engineering lớn hơn nhiều so với benchmark này.
