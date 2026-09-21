import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:llamadart/llamadart.dart';

import '../../domain/entities/translation_direction.dart';
import 'llm_model_download_service.dart';

// System prompt gọn (chỉ nêu vai trò + quy tắc chung); phần dạy cụ thể
// cách xử lý câu giả định/phủ định và thuật ngữ kỹ thuật đưa qua
// few-shot examples bên dưới ([_fewShotExamples]) — model chat-tuned
// thường theo ví dụ cụ thể tốt hơn là mô tả quy tắc trừu tượng trong
// system prompt (đã thấy rõ qua 2 lỗi thực tế: "debounce" dịch bừa
// thành "đỡ lỗi", và câu giả định phủ định "Had it not been for..."
// bị dịch đảo ngược nhân quả).
const _systemPrompt =
    'You are a professional English-Vietnamese translator specialized in '
    'maritime and military terminology (Vietnam Coast Guard domain). '
    'Translate the given text to the target language, preserving the exact '
    'logical meaning (especially negation, conditionals, and counterfactuals '
    '- do not reverse cause and effect). '
    'If a technical/programming term has no standard Vietnamese translation, '
    'keep the original term and add a short Vietnamese gloss in parentheses '
    'instead of inventing an unrelated word. '
    'Reply with ONLY the translation, no explanation, no quotes, no notes.';

/// Ví dụ mẫu (few-shot) — dạy đúng 2 loại lỗi đã quan sát thực tế khi
/// test app (xem hội thoại dẫn tới thay đổi này), tách khỏi
/// [_systemPrompt] vì model theo ví dụ cụ thể tốt hơn mô tả quy tắc.
const _fewShotExamples = [
  (
    en: 'Had it not been for your timely intervention, the situation could '
        'have escalated far beyond our control.',
    vi: 'Nếu không nhờ bạn can thiệp kịp thời, tình hình có thể đã leo thang '
        'vượt xa tầm kiểm soát của chúng tôi.',
  ),
  (en: 'debounce', vi: 'debounce (kỹ thuật trì hoãn xử lý sự kiện lặp lại)'),
];

/// Model chưa tải xong — gọi `downloadLlmModel(ref)` trước (xem
/// `translation_providers.dart`).
class LlmModelNotLoadedException implements Exception {
  @override
  String toString() => 'Model AI cục bộ chưa tải xong';
}

/// Output lẫn ký tự Trung/Nhật thay vì tiếng Việt — hành vi code-switch
/// đã quan sát thực tế ở benchmark (`tools/translation-eval/results/
/// SUMMARY.md`, mục "Bug đáng lo"), retry 1 lần không sửa được. Caller
/// nên rơi về nguồn dịch khác (MyMemory/opus-mt) thay vì hiện thẳng kết
/// quả lỗi cho user.
class LlmDegenerateOutputException implements Exception {
  LlmDegenerateOutputException(this.output);
  final String output;

  @override
  String toString() => 'Model AI cục bộ trả về output lẫn ngôn ngữ khác: $output';
}

/// CJK Unicode ranges phổ biến nhất (Hán, Hiragana/Katakana) — đủ để
/// bắt lỗi quan sát được ở benchmark, không cần đầy đủ mọi block CJK.
final _cjkPattern = RegExp(
  r'[一-鿿぀-ヿ]',
);

/// Suy luận dịch bằng Qwen2.5-3B-Instruct cục bộ qua llama.cpp
/// (`llamadart`) — CHỈ dùng làm lựa chọn bổ sung cho fallback offline
/// trên desktop, độc lập với [TranslationService] (opus-mt, vẫn là
/// fallback mặc định). Model dùng chung cho cả 2 chiều dịch (khác
/// opus-mt cần model riêng/chiều) vì đây là 1 LLM đa ngôn ngữ, chỉ đổi
/// prompt theo chiều.
///
/// Xem `tools/translation-eval/results/SUMMARY.md` cho số liệu benchmark
/// đã dẫn tới quyết định tích hợp này.
class LlmTranslationService {
  LlmTranslationService._();
  static final LlmTranslationService instance = LlmTranslationService._();

  LlamaEngine? _engine;

  // llama.cpp chỉ cho 1 generation chạy tại 1 thời điểm trên cùng
  // context — gọi `engine.create()` chồng lên nhau (debounce dịch vẫn
  // có thể bắn nhiều request nếu user gõ nhanh, mỗi request là 1
  // provider instance riêng) ném thẳng `LlamaException: Bad state:
  // llama.cpp generation is already in progress` lên UI (đã gặp thực
  // tế khi test). Chuỗi mọi lệnh dịch qua 1 hàng đợi tuần tự thay vì
  // để `LlamaEngine` tự chối — request sau chờ request trước xong,
  // không request nào bị lỗi.
  Future<void> _queue = Future<void>.value();

  // Số thứ tự request mới nhất — request cũ hơn (còn xếp hàng chờ hoặc
  // đang chạy dở) bị "vượt mặt" khi user gõ tiếp thì không còn ai chờ
  // kết quả nữa (UI chỉ watch provider của text hiện tại), nên huỷ luôn
  // thay vì tốn CPU/GPU chạy hết cho 1 kết quả không dùng tới.
  int _requestSeq = 0;

  bool get isLoaded => _engine != null;

  Future<void> load() async {
    if (_engine != null) return;
    if (!await LlmModelDownloadService.instance.isDownloaded()) {
      throw LlmModelNotLoadedException();
    }
    final modelFile = await LlmModelDownloadService.instance.modelFile();
    final engine = LlamaEngine(LlamaBackend());
    await engine.loadModel(
      modelFile.path,
      modelParams: const ModelParams(contextSize: 2048),
    );
    _engine = engine;
  }

  Future<void> unload() async {
    final engine = _engine;
    _engine = null;
    await engine?.dispose();
  }

  /// Dịch [text] theo [direction]. Ném [LlmDegenerateOutputException]
  /// nếu output lẫn CJK sau 1 lần retry (2 lần generate tổng cộng) —
  /// caller nên fallback sang nguồn khác thay vì hiện lỗi cho user. Các
  /// lệnh gọi đồng thời được xếp hàng tuần tự qua [_queue]; nếu 1 request
  /// mới hơn tới trong lúc request cũ còn đang xếp hàng/chạy dở, request
  /// cũ bị huỷ ngay (xem [_requestSeq]) — không đợi nó chạy xong.
  Future<String> translate(TranslationDirection direction, String text) {
    final mySeq = ++_requestSeq;
    // Huỷ generation đang chạy (nếu có) ngay lập tức: đó chắc chắn là
    // của 1 request cũ hơn (mySeq vừa tăng), không ai còn chờ kết quả
    // của nó nữa.
    _engine?.cancelGeneration();

    final result = _queue.then((_) => _translateLocked(mySeq, direction, text));
    // Luôn advance hàng đợi kể cả khi request này lỗi, để request tiếp
    // theo không bị kẹt chờ mãi 1 Future đã fail.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<String> _translateLocked(int mySeq, TranslationDirection direction, String text) async {
    // Đã bị 1 request mới hơn ghi đè trong lúc xếp hàng chờ tới lượt -
    // bỏ qua, không tốn thời gian generate cho kết quả không ai chờ.
    if (mySeq != _requestSeq) return '';

    final engine = _engine;
    if (engine == null) throw LlmModelNotLoadedException();
    if (text.trim().isEmpty) return '';

    final targetLabel = direction.targetLangLabel;
    final sourceLabel = direction.sourceLangLabel;

    final first = await _runOnce(engine, mySeq, direction, sourceLabel, targetLabel, text);
    debugPrint('[LLM translate] "$text" -> "$first" (attempt 0)');
    if (!_cjkPattern.hasMatch(first)) return first;
    if (mySeq != _requestSeq) return '';

    final retry = await _runOnce(engine, mySeq, direction, sourceLabel, targetLabel, text);
    debugPrint('[LLM translate] "$text" -> "$retry" (attempt 1)');
    if (_cjkPattern.hasMatch(retry)) throw LlmDegenerateOutputException(retry);
    return retry;
  }

  Future<String> _runOnce(
    LlamaEngine engine,
    int mySeq,
    TranslationDirection direction,
    String sourceLabel,
    String targetLabel,
    String text,
  ) async {
    // Few-shot chỉ soạn cho chiều Anh->Việt (2 lỗi thực tế đều xảy ra ở
    // chiều này) - đảo ví dụ sang Việt->Anh cần cặp câu riêng đã kiểm
    // chứng, chưa có, nên bỏ qua thay vì đoán mò.
    final fewShot = direction == TranslationDirection.enToVi
        ? _fewShotExamples.expand(
            (e) => [
              LlamaChatMessage.fromText(
                role: LlamaChatRole.user,
                text: 'Translate from $sourceLabel to $targetLabel:\n\n${e.en}',
              ),
              LlamaChatMessage.fromText(role: LlamaChatRole.assistant, text: e.vi),
            ],
          )
        : const Iterable<LlamaChatMessage>.empty();

    final messages = [
      const LlamaChatMessage.fromText(role: LlamaChatRole.system, text: _systemPrompt),
      ...fewShot,
      LlamaChatMessage.fromText(
        role: LlamaChatRole.user,
        text: 'Translate from $sourceLabel to $targetLabel:\n\n$text',
      ),
    ];

    final buffer = StringBuffer();
    try {
      await for (final chunk in engine.create(
        messages,
        params: const GenerationParams(maxTokens: 256, temp: 0.1),
      )) {
        // Bị 1 request mới hơn ghi đè giữa chừng (translate() đã gọi
        // cancelGeneration()) - dừng đọc stream ngay, không cần đợi hết.
        if (mySeq != _requestSeq) break;
        final delta = chunk.choices.first.delta.content;
        if (delta != null) buffer.write(delta);
      }
    } on LlamaException {
      // cancelGeneration() có thể làm stream throw thay vì kết thúc êm
      // tuỳ backend - coi như bị huỷ, trả những gì đã có (caller ở
      // _translateLocked sẽ tự bỏ qua nếu mySeq đã lỗi thời).
      if (mySeq == _requestSeq) rethrow;
    }
    return buffer.toString().trim();
  }
}
