-- ============================================================================
-- CSB Vocab App — Seed dữ liệu khởi tạo bắt buộc cho `dictionaries`
-- ============================================================================
-- Chạy SAU schema.sql. Đây là dữ liệu bắt buộc phải có ngay khi tạo DB mới
-- (không phụ thuộc migration dữ liệu từ vocab.db/user.db cũ) — theo
-- docs/csb-vocab-analysis/91_DB-design-new-model.md § "Bảng dictionaries":
--   "1 dòng 'Chưa phân loại' (is_default=1, is_deletable=0) + 6 dòng
--    giáo trình gốc (is_default=1, is_deletable=1)"
--
-- Tên 6 bộ giáo trình gốc lấy từ docs/source-materials/README.md:
--   "Quân sự chung, Hàng hải, Thông tin ra đa, Vũ khí, Cơ điện, Cảnh sát biển"
-- created_at dùng epoch 0 làm placeholder — thay bằng thời điểm build DB
-- thật khi implement.
-- ============================================================================

INSERT INTO dictionaries (id, name, is_default, is_deletable, sort_order, created_at) VALUES
  (1, 'Chưa phân loại',      1, 0, 0, 0),
  (2, 'Quân sự chung',       1, 1, 1, 0),
  (3, 'Hàng hải',            1, 1, 2, 0),
  (4, 'Thông tin ra đa',     1, 1, 3, 0),
  (5, 'Vũ khí',              1, 1, 4, 0),
  (6, 'Cơ điện',             1, 1, 5, 0),
  (7, 'Cảnh sát biển',       1, 1, 6, 0);
