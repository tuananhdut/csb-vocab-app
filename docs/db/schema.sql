-- ============================================================================
-- CSB Vocab App — Schema DB định hướng mới (1 database duy nhất)
-- ============================================================================
-- Sinh ra để XEM/ĐỐI CHIẾU trực quan cho thiết kế đã chốt tại:
--   docs/csb-vocab-analysis/91_DB-design-new-model.md
-- Không phải code chạy thật — implement thật sẽ dùng Drift (đã chốt D3,
-- xem docs/spec_history.md [IMPL-007]), file .sql này chỉ để bạn có thể
-- `sqlite3 review.db < schema.sql` chạy thử/xem ERD bằng công cụ ngoài.
--
-- Quyết định nền tảng (không lặp lại toàn bộ lý do — xem file .md gốc):
--   [IMPL-014] 1 database duy nhất, bỏ ranh giới vocab.db/user.db.
--   [IMPL-014] Mọi từ luôn thuộc >=1 bộ từ điển (bộ "Chưa phân loại" cố định).
--   [IMPL-015] Ôn tập khách quan (trắc nghiệm + gõ chữ), không đổi SM-2.
--
-- Áp dụng "PRAGMA foreign_keys = ON;" khi mở kết nối thật nếu muốn ràng
-- buộc FK được enforce (SQLite mặc định tắt).
--
-- KHÔNG bao gồm ở đây: `chapter_words` (liên kết Chapter <-> từ xuất hiện
-- trong bài) — dời sang phase sau, chờ bước xử lý .docx riêng (Q-CSB-07)
-- sinh dữ liệu bài đọc thật. Khung `sections`/`chapters` vẫn tạo ở đây vì
-- không phụ thuộc dữ liệu đó (91_DB-design-new-model.md dòng 14-16).
--
-- KHÔNG có bảng `review_logs`: bỏ hẳn (không phải dời sang phase sau) —
-- chưa có bất kỳ màn hình nào đọc lại bảng này (chỉ có INSERT, không có
-- SELECT ở review_repository.dart), giữ 1 bảng chỉ-ghi-không-ai-đọc là
-- dữ liệu chết. Khác `learned_words` (lưu trạng thái hiện tại, được đọc
-- liên tục để tính hàng đợi ôn tập) — review_logs từng dự tính làm audit
-- trail nhưng chưa có nhu cầu thống kê thật, nên bỏ theo cùng nguyên tắc
-- đã áp dụng cho cột `question_mode`.
--
-- KHÔNG có bảng `search_history`: cùng lý do — code hiện tại không hề
-- đọc/ghi bảng này (xác nhận ở docs/csb-vocab-analysis/02_Search.md,
-- ghi nhận là gap "chưa được đọc/ghi ở bất kỳ đâu"), không mockup nào
-- (kể cả screen-02-tra-cuu.html) thiết kế UI "lịch sử tra cứu". Nếu sau
-- này thực sự làm tính năng này, tạo lại bảng bằng 1 migration đơn giản.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 1. words — bảng từ vựng hợp nhất (thay cho words + custom_words cũ)
--    Xem 91_DB-design-new-model.md § "Bảng words"
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS words (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  word            TEXT    NOT NULL,
  word_lower      TEXT    NOT NULL,                 -- cột kỹ thuật, hỗ trợ search không phân biệt hoa/thường
  phonetic        TEXT,                              -- NULL nếu nguồn không cung cấp (vd tự nhập tay)
  meaning_vi      TEXT    NOT NULL,
  part_of_speech  INTEGER,                           -- NULL = chưa xác định; xem bảng enum bên dưới
  is_subentry     INTEGER NOT NULL DEFAULT 0,        -- 0/1 (bool) — cụm từ/biến thể liên quan 1 từ gốc
  image_path      TEXT,                              -- NULL nếu chưa có ảnh minh hoạ
  source          INTEGER NOT NULL,                  -- 0=SEED / 1=ONLINE_LOOKUP / 2=MANUAL — xem enum bên dưới
  created_at      INTEGER NOT NULL,                  -- unix timestamp

  CHECK (part_of_speech IS NULL OR part_of_speech BETWEEN 0 AND 4),
  CHECK (is_subentry IN (0, 1)),
  CHECK (source BETWEEN 0 AND 2)
);

CREATE INDEX IF NOT EXISTS idx_words_word_lower ON words(word_lower);

-- Enum part_of_speech (mã số cố định — mapping nhãn giữ ở tầng Dart):
--   0 = Danh từ   (n)
--   1 = Động từ   (v)
--   2 = Tính từ   (a, gộp cả "adj")
--   3 = Trạng từ  (adv)
--   4 = Giới từ   (prep)
--   NULL = chưa xác định

-- Enum source (mã số cố định — không nullable):
--   0 = SEED            (giáo trình gốc, đóng gói sẵn lúc build)
--   1 = ONLINE_LOOKUP    (tra Online rồi bấm "Thêm vào bộ")
--   2 = MANUAL           (user tự nhập tay)

-- ----------------------------------------------------------------------------
-- 2. dictionaries — bộ từ điển (mặc định + cá nhân, thay cho `chapters` cũ)
--    Xem 91_DB-design-new-model.md § "Bảng dictionaries"
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dictionaries (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT    NOT NULL,
  is_default    INTEGER NOT NULL DEFAULT 0,   -- 1 = đóng gói sẵn/hệ thống tạo, 0 = user tự tạo
  is_deletable  INTEGER NOT NULL DEFAULT 1,   -- 0 riêng cho "Chưa phân loại" (không cho xoá)
  sort_order    INTEGER NOT NULL DEFAULT 0,
  created_at    INTEGER NOT NULL,

  CHECK (is_default IN (0, 1)),
  CHECK (is_deletable IN (0, 1))
);

-- ----------------------------------------------------------------------------
-- 3. word_dictionaries — N-N words <-> dictionaries (thay cho words.chapter_id đơn)
--    Ràng buộc nghiệp vụ (enforce ở tầng Repository, KHÔNG enforce được bằng
--    SQL thuần): mọi word_id luôn phải có >=1 dòng trong bảng này.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS word_dictionaries (
  word_id        INTEGER NOT NULL,
  dictionary_id  INTEGER NOT NULL,
  added_at       INTEGER NOT NULL,

  PRIMARY KEY (word_id, dictionary_id),
  FOREIGN KEY (word_id)       REFERENCES words(id)       ON DELETE CASCADE,
  FOREIGN KEY (dictionary_id) REFERENCES dictionaries(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_word_dictionaries_dictionary ON word_dictionaries(dictionary_id);

-- ----------------------------------------------------------------------------
-- 4. sections / chapters — khung nội dung bài học (Chapter dạng bài báo)
--    Chỉ tạo khung bảng ở đây — `content` là placeholder tối thiểu, cấu
--    trúc chi tiết + highlight từ vựng chốt ở bước xử lý .docx riêng
--    (Q-CSB-07). Bảng liên kết `chapter_words` dời sang phase sau vì phụ
--    thuộc dữ liệu bài đọc thật (chưa có).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sections (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS chapters (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  section_id  INTEGER NOT NULL,
  title       TEXT    NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  content     TEXT,                          -- văn bản có cấu trúc (Markdown/HTML rút gọn); placeholder tối thiểu

  FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 5. examples — ví dụ câu cho từng từ (giữ nguyên như thiết kế cũ)
--    Baseline suy từ lib/data/repositories/vocab_repository.dart (examplesFor())
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS examples (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  word_id     INTEGER NOT NULL,
  example_en  TEXT    NOT NULL,
  example_vi  TEXT    NOT NULL,

  FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_examples_word ON examples(word_id);

-- ----------------------------------------------------------------------------
-- 6. learned_words — trạng thái SM-2 (giữ nguyên schema cốt lõi, không đổi)
--    Baseline: lib/data/local/user_database.dart — chỉ đổi namespace word_id
--    trỏ sang bảng `words` hợp nhất mới.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS learned_words (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  word_id        INTEGER NOT NULL UNIQUE,
  is_learned     INTEGER NOT NULL DEFAULT 1,
  ease_factor    REAL    NOT NULL DEFAULT 2.5,   -- SM-2, sàn cứng 1.3 (enforce ở tầng SrsScheduler)
  interval_days  INTEGER NOT NULL DEFAULT 0,
  repetitions    INTEGER NOT NULL DEFAULT 0,
  due_date       INTEGER,
  last_reviewed  INTEGER,

  FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_learned_words_due ON learned_words(due_date);

-- Nhãn "từ khó" — KHÔNG phải cột, tính động tại tầng ứng dụng:
--   is_difficult = (learned_words.ease_factor <= 1.5)
-- Chỉ dùng để hiển thị/thống kê, KHÔNG ảnh hưởng ORDER BY của hàng đợi ôn tập.
