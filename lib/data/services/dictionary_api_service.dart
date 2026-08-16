import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/word.dart';

/// Tra từ/cụm từ ngắn qua MyMemory Translation API khi không có trong
/// `vocab.db` local (SCR-02 "Chế độ Online", xem `02_Search.md`). Khi
/// query là tiếng Anh, gọi thêm song song Free Dictionary API
/// (`api.dictionaryapi.dev`) để bổ sung phiên âm IPA + loại từ — hai
/// API độc lập, không phụ thuộc nhau, lỗi 1 bên không chặn bên còn lại.
///
/// Đã khảo sát LABAN.vn thay thế nhưng không dùng: không có API JSON
/// công khai (chỉ có widget nhúng), endpoint AJAX nội bộ trả HTML thô
/// phải tự parse (giòn, dễ gãy khi họ đổi giao diện), và có rủi ro bản
/// quyền — LABAN thuộc VNG, dữ liệu được cho là cấp phép lại từ Viện
/// Ngôn ngữ học nên VNG có thể cũng không có quyền cho bên thứ 3 dùng
/// lại. MyMemory + Free Dictionary API đều có ToS công khai cho phép
/// dùng miễn phí, không vướng rủi ro này.
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
  static const _dictionaryApiBaseUrl =
      'https://api.dictionaryapi.dev/api/v2/entries/en';

  /// `partOfSpeech` tiếng Anh (Free Dictionary API) -> viết tắt tiếng
  /// Việt đã dùng trong toàn app (xem `VocabRepository._posLabels`,
  /// `PosTag` widget) — chỉ map các loại từ enum hiện có hỗ trợ
  /// (`docs/db/schema.sql`), loại khác (interjection, pronoun...) bỏ
  /// qua vì UI không có nhãn cho chúng.
  static const _posLabelByEnglishName = {
    'noun': 'dt',
    'verb': 'đt',
    'adjective': 'tt',
    'adverb': 'trt',
    'preposition': 'gt',
  };

  /// Email liên hệ của dự án, gửi kèm mọi request để MyMemory nâng
  /// quota từ 5.000 lên 50.000 ký tự/ngày/IP — không phải email user,
  /// không thu thập gì từ người dùng, chỉ để MyMemory biết ai đứng sau
  /// lượng traffic gọi tới (yêu cầu của chính MyMemory, xem
  /// https://mymemory.translated.net/doc/spec.php).
  static const _contactEmail = 'tuanhaoggg@gmail.com';

  /// Tra [text] qua MyMemory (dịch nghĩa) theo đúng [direction] user đã
  /// chọn ở dropdown [SearchScreen] (bắt buộc, không có mặc định đoán
  /// tự động). Free Dictionary API (không hỗ trợ tiếng Việt — đã xác
  /// nhận trực tiếp gọi thử `entries/vi/...` trả lỗi 502, không phải
  /// 404 "không tìm thấy") luôn được gọi thêm cho TỪ TIẾNG ANH để lấy
  /// phiên âm/loại từ, nhưng thời điểm khác nhau theo hướng:
  /// - [SearchDirection.enToVi]: [text] đã là tiếng Anh -> gọi SONG
  ///   SONG với MyMemory ngay từ đầu.
  /// - [SearchDirection.viToEn]: [text] là tiếng Việt, chưa biết từ
  ///   tiếng Anh tương ứng cho tới khi MyMemory dịch xong -> gọi Free
  ///   Dictionary API SAU, dùng kết quả dịch làm từ khoá tra.
  /// Trả `null` nếu MyMemory lỗi/timeout/không có kết quả — coi là
  /// nguồn chính, Free Dictionary API chỉ làm giàu thêm (optional), lỗi
  /// chỉ ghi log ([debugPrint]), không throw ra ngoài để không chặn UI
  /// bằng lỗi đỏ (đã chốt Q-CSB-06: fallback êm về kết quả offline khi
  /// mạng chập chờn).
  Future<OnlineLookupResult?> lookup(
    String text, {
    required SearchDirection direction,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final isVietnamese = direction == SearchDirection.viToEn;
    final from = isVietnamese ? 'vi' : 'en';
    final to = isVietnamese ? 'en' : 'vi';

    String? translated;
    _EnglishDetails? details;
    if (isVietnamese) {
      // Chưa biết từ tiếng Anh là gì cho tới khi có bản dịch -> tuần tự.
      translated = await _translate(trimmed, from: from, to: to);
      if (translated != null) details = await _lookupEnglishDetails(translated);
    } else {
      // [text] đã là tiếng Anh -> bắt đầu cả 2 request trước khi await
      // cái nào, chạy song song thật (không phải tuần tự).
      final translateFuture = _translate(trimmed, from: from, to: to);
      final detailsFuture = _lookupEnglishDetails(trimmed);
      translated = await translateFuture;
      details = await detailsFuture;
    }
    if (translated == null) return null;

    return OnlineLookupResult(
      queryText: trimmed,
      translatedText: translated,
      // Kết quả hiển thị luôn theo thứ tự (Anh, Việt) khớp WordTile/
      // WordDetailContent hiện có — đảo lại nếu query gốc là tiếng Việt.
      word: isVietnamese ? translated : trimmed,
      meaningVi: isVietnamese ? trimmed : translated,
      phonetic: details?.phonetic ?? '',
      partOfSpeech: details?.partOfSpeech ?? '',
    );
  }

  /// Gọi Free Dictionary API lấy phiên âm IPA + loại từ đầu tiên cho 1
  /// từ tiếng Anh — trả `null` nếu không tìm thấy/lỗi mạng (404 khi từ
  /// không có trong từ điển, xác nhận trực tiếp khác 502 của trường
  /// hợp ngôn ngữ không hỗ trợ). 1 từ có thể có nhiều `partOfSpeech`
  /// (vd "chair" vừa là danh từ vừa là động từ) — chỉ lấy loại đầu
  /// tiên, đủ dùng cho 1 dòng [PosTag] hiện có, không cần hiện đủ.
  Future<_EnglishDetails?> _lookupEnglishDetails(String word) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '$_dictionaryApiBaseUrl/$word',
      );
      final entry = response.data?.firstOrNull as Map<String, dynamic>?;
      if (entry == null) return null;

      // Field `phonetic` gốc không phải lúc nào cũng có (vd "table" —
      // xác nhận trực tiếp) — fallback tìm phần tử đầu tiên trong
      // `phonetics[]` thực sự có `text` (1 số phần tử chỉ có `audio`,
      // không có `text`).
      var phonetic = entry['phonetic'] as String? ?? '';
      if (phonetic.isEmpty) {
        final phoneticsList = entry['phonetics'] as List<dynamic>?;
        for (final item in phoneticsList ?? const []) {
          final text = (item as Map<String, dynamic>?)?['text'] as String?;
          if (text != null && text.isNotEmpty) {
            phonetic = text;
            break;
          }
        }
      }
      final meanings = entry['meanings'] as List<dynamic>?;
      final firstMeaning = meanings?.firstOrNull as Map<String, dynamic>?;
      final posRaw = firstMeaning?['partOfSpeech'] as String?;
      final posLabel = _posLabelByEnglishName[posRaw] ?? '';

      if (phonetic.isEmpty && posLabel.isEmpty) return null;
      return _EnglishDetails(phonetic: phonetic, partOfSpeech: posLabel);
    } on DioException catch (e) {
      // 404 (từ không có trong từ điển) là kết quả bình thường, không
      // phải lỗi — chỉ log các lỗi khác (mạng/timeout) để tránh log rác.
      if (e.response?.statusCode != 404) {
        debugPrint('DictionaryApiService: Free Dictionary API lỗi — $e');
      }
      return null;
    } catch (e) {
      debugPrint(
        'DictionaryApiService: lỗi không xác định khi tra chi tiết "$word" — $e',
      );
      return null;
    }
  }

  Future<String?> _translate(
    String text, {
    required String from,
    required String to,
  }) async {
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
      debugPrint(
        'DictionaryApiService: lỗi không xác định khi tra "$text" — $e',
      );
      return null;
    }
  }
}

/// Kết quả tra 1 từ/cụm từ qua API ngoài — [word]/[meaningVi] đã được
/// sắp đúng thứ tự (Anh, Việt) để hiển thị nhất quán với [VocabWord]
/// dù query gốc của user là tiếng Anh hay tiếng Việt. [phonetic]/
/// [partOfSpeech] chỉ có giá trị khi query là tiếng Anh và Free
/// Dictionary API tìm thấy từ đó (xem `DictionaryApiService._lookupEnglishDetails`) —
/// rỗng ở các trường hợp còn lại (query tiếng Việt, hoặc API phụ lỗi).
class OnlineLookupResult {
  const OnlineLookupResult({
    required this.queryText,
    required this.translatedText,
    required this.word,
    required this.meaningVi,
    this.phonetic = '',
    this.partOfSpeech = '',
  });

  final String queryText;
  final String translatedText;
  final String word;
  final String meaningVi;
  final String phonetic;
  final String partOfSpeech;
}

/// Kết quả tạm từ Free Dictionary API — chỉ dùng nội bộ trong
/// [DictionaryApiService], gộp vào [OnlineLookupResult] ở [DictionaryApiService.lookup].
class _EnglishDetails {
  const _EnglishDetails({required this.phonetic, required this.partOfSpeech});
  final String phonetic;
  final String partOfSpeech;
}
