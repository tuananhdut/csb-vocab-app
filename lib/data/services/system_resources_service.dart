import 'package:system_info3/system_info3.dart';

/// Kiểm tra RAM máy trước khi dùng AI cục bộ (Qwen2.5-3B, desktop) —
/// peak RAM đo thực tế ~3.36GB (xem `tools/translation-eval/results/
/// SUMMARY.md`). Máy RAM quá thấp cố load model này dễ bị treo máy/OOM
/// thay vì lỗi có kiểm soát; kiểm tra trước để tự rơi về opus-mt (vẫn
/// giữ làm lưới an toàn cuối, KHÔNG bỏ) thay vì cố load rồi mới biết lỗi.
///
/// QUAN TRỌNG: `system_info3` đọc RAM trên Windows bằng `Process.runSync`
/// gọi `wmic` — ĐỒNG BỘ, chặn hẳn isolate đang gọi (thường là UI isolate)
/// trong lúc chờ tiến trình con (~100-500ms/lần, đo thực tế qua
/// code-review). Gọi trực tiếp không cache sẽ giật UI rõ rệt ở 2 chỗ đã
/// gặp thực tế: `LlmModelRow` rebuild liên tục theo tiến độ tải (mỗi lần
/// `onReceiveProgress` của Dio), và `translateProvider` chạy lại mỗi lần
/// dịch. Cache kết quả để chỉ thực sự spawn `wmic` khi cần.
class SystemResourcesService {
  SystemResourcesService._();

  // Duoi ~2GB duoi muc RAM da benchmark (8GB) - coi la may cau hinh thap,
  // khong nen thu LLM du chua chac chan se that bai.
  static const _minTotalRamBytes = 6 * 1024 * 1024 * 1024; // 6GB

  // Peak do thuc te ~3.36GB - can it nhat ngan nay RAM RANH truoc khi
  // load, chua tinh RAM app Flutter + OS dang dung.
  static const _minFreeRamBytes = 2500 * 1024 * 1024; // ~2.5GB

  // RAM TONG khong doi trong vong doi tien trinh app - do 1 lan roi nho
  // mai mai, khong bao gio can spawn lai `wmic` cho gia tri nay.
  static bool? _cachedHasEnoughTotal;

  // RAM RANH bien dong theo thoi gian nhung khong can chinh xac tung
  // giay cho muc dich "kiem tra an toan truoc khi load model nang" - cache
  // ngan (throttle) de khong spawn `wmic` lien tuc khi bi goi don dap
  // (dich nhieu cau lien tuc, hoac nhieu widget cung watch 1 luc).
  static bool? _cachedHasEnoughFree;
  static DateTime? _cachedFreeAt;
  static const _freeCacheTtl = Duration(seconds: 5);

  /// `true` nếu RAM TỔNG của máy đủ để cân nhắc dùng AI cục bộ — dùng để
  /// quyết định CÓ HIỆN tuỳ chọn tải hay không ([LlmModelRow]), trước khi
  /// user tốn 2.1GB băng thông/dung lượng tải model không dùng được. Ổn
  /// định hơn [hasEnoughRamForLlm] (không phụ thuộc RAM rảnh biến động
  /// lúc kiểm tra) — đúng bản chất câu hỏi "máy này CÓ THUỘC LOẠI đủ cấu
  /// hình không", không phải "RAM đang rảnh bao nhiêu ngay lúc này". Kết
  /// quả cache vĩnh viễn (xem doc-comment class).
  ///
  /// Fail-safe: xem [hasEnoughRamForLlm].
  static bool hasEnoughTotalRamForLlm() {
    final cached = _cachedHasEnoughTotal;
    if (cached != null) return cached;
    try {
      final result = SysInfo.getTotalPhysicalMemory() >= _minTotalRamBytes;
      _cachedHasEnoughTotal = result;
      return result;
    } catch (_) {
      // Khong cache ket qua fail-safe: loi co the tam thoi, lan sau van
      // nen thu do lai thay vi ket luan vinh vien.
      return true;
    }
  }

  /// `true` nếu máy đủ RAM để dùng AI cục bộ AN TOÀN NGAY LÚC NÀY — dùng
  /// ở `translateProvider`, kiểm tra lại mỗi lần dịch (khác
  /// [hasEnoughTotalRamForLlm] chỉ cần đúng 1 lần khi hiện UI): máy đủ
  /// cấu hình (RAM tổng) nhưng đang chạy nhiều app khác lúc dịch vẫn nên
  /// rơi về opus-mt thay vì cố load model nặng gây treo máy. Kết quả
  /// cache trong [_freeCacheTtl] (xem doc-comment class) - "an toàn ngay
  /// lúc này" không cần chính xác tới từng giây.
  ///
  /// Fail-safe: không xác định được RAM (lỗi API, platform không hỗ trợ,
  /// hoặc `wmic` bị gỡ khỏi Windows tương lai — package dùng `wmic` để
  /// đọc RAM trên Windows, công cụ Microsoft đã đánh dấu deprecated) thì
  /// coi như ĐỦ RAM, giữ đúng hành vi hiện tại thay vì chặn nhầm user chỉ
  /// vì không đo được.
  static bool hasEnoughRamForLlm() {
    if (!hasEnoughTotalRamForLlm()) return false;

    final cachedAt = _cachedFreeAt;
    final cached = _cachedHasEnoughFree;
    if (cached != null && cachedAt != null && DateTime.now().difference(cachedAt) < _freeCacheTtl) {
      return cached;
    }

    try {
      final result = SysInfo.getFreePhysicalMemory() >= _minFreeRamBytes;
      _cachedHasEnoughFree = result;
      _cachedFreeAt = DateTime.now();
      return result;
    } catch (_) {
      return true;
    }
  }
}
