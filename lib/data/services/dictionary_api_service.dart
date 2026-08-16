import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Tra từ/cụm từ ngắn qua MyMemory Translation API khi không có trong
/// `vocab.db` local (SCR-02 "Chế độ Online", xem `02_Search.md`).
///
/// Thay cho LibreTranslate đã chốt trước đó ở [IMPL-013] — public
/// instance của LibreTranslate đã đổi chính sách, giờ bắt buộc API key
/// (xác nhận trực tiếp: gọi thử trả về lỗi yêu cầu đăng ký key), không
/// còn dùng ẩn danh miễn phí được nữa. MyMemory không cần key, gọi
/// thẳng từ client, quota 5.000 ký tự/ngày/IP (ẩn danh) hoặc 50.000
/// ký tự/ngày/IP nếu kèm tham số `de` (email liên hệ, xem
/// [_contactEmail]) — quota tính theo IP gọi API, không phải theo
/// user trong app (app không có backend/tài khoản để phân biệt).
class DictionaryApiService {
  DictionaryApiService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _baseUrl = 'https://api.mymemory.translated.net/get';

  /// Email liên hệ của dự án, gửi kèm mọi request để MyMemory nâng
  /// quota từ 5.000 lên 50.000 ký tự/ngày/IP — không phải email user,
  /// không thu thập gì từ người dùng, chỉ để MyMemory biết ai đứng sau
  /// lượng traffic gọi tới (yêu cầu của chính MyMemory, xem
  /// https://mymemory.translated.net/doc/spec.php).
  static const _contactEmail = 'tuanhaoggg@gmail.com';

  /// Regex ký tự riêng của tiếng Việt (nguyên âm có dấu mũ/móc + `đ`) —
  /// đủ để đoán hướng dịch cho từ đơn/cụm ngắn mà không cần thư viện
  /// detect ngôn ngữ riêng: query có ký tự này -> chắc chắn là tiếng
  /// Việt (tiếng Anh không có các ký tự này); ngược lại coi là tiếng
  /// Anh. Từ mượn/tên riêng không dấu tiếng Việt vẫn có thể đoán sai
  /// (hiếm, chấp nhận được vì đây chỉ là nguồn bổ sung, không phải
  /// chính).
  static final _vietnameseCharsPattern =
      RegExp(r'[ăâđêôơưÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ]', caseSensitive: false);

  bool _looksVietnamese(String text) => _vietnameseCharsPattern.hasMatch(text);

  /// Tra [text] qua MyMemory, tự đoán hướng dịch (Việt->Anh nếu có dấu
  /// tiếng Việt, ngược lại Anh->Việt) — trả `null` nếu API lỗi/timeout/
  /// không có kết quả. Lỗi chỉ ghi log ([debugPrint]), không throw ra
  /// ngoài để không chặn UI bằng lỗi đỏ (đã chốt Q-CSB-06: fallback êm
  /// về kết quả offline khi mạng chập chờn).
  Future<OnlineLookupResult?> lookup(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final isVietnamese = _looksVietnamese(trimmed);
    final from = isVietnamese ? 'vi' : 'en';
    final to = isVietnamese ? 'en' : 'vi';

    final translated = await _translate(trimmed, from: from, to: to);
    if (translated == null) return null;

    return OnlineLookupResult(
      queryText: trimmed,
      translatedText: translated,
      // Kết quả hiển thị luôn theo thứ tự (Anh, Việt) khớp WordTile/
      // WordDetailContent hiện có — đảo lại nếu query gốc là tiếng Việt.
      word: isVietnamese ? translated : trimmed,
      meaningVi: isVietnamese ? trimmed : translated,
    );
  }

  Future<String?> _translate(String text, {required String from, required String to}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _baseUrl,
        queryParameters: {
          'q': text,
          'langpair': '$from|$to',
          'de': _contactEmail,
        },
      );

      final data = response.data;
      final translated = data?['responseData']?['translatedText'] as String?;
      if (translated == null || translated.isEmpty) return null;

      // MyMemory trả nguyên câu báo lỗi dạng text khi không tìm được
      // bản dịch (không phải HTTP error code) — lọc bằng responseStatus.
      final status = data?['responseStatus'];
      final statusCode = status is int ? status : int.tryParse('$status');
      if (statusCode != null && statusCode != 200) return null;

      return translated;
    } on DioException catch (e) {
      debugPrint('DictionaryApiService: MyMemory request thất bại — $e');
      return null;
    } catch (e) {
      debugPrint('DictionaryApiService: lỗi không xác định khi tra "$text" — $e');
      return null;
    }
  }
}

/// Kết quả tra 1 từ/cụm từ qua API ngoài — [word]/[meaningVi] đã được
/// sắp đúng thứ tự (Anh, Việt) để hiển thị nhất quán với [VocabWord]
/// dù query gốc của user là tiếng Anh hay tiếng Việt.
class OnlineLookupResult {
  const OnlineLookupResult({
    required this.queryText,
    required this.translatedText,
    required this.word,
    required this.meaningVi,
  });

  final String queryText;
  final String translatedText;
  final String word;
  final String meaningVi;
}
