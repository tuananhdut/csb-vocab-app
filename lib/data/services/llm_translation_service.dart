import 'package:llamadart/llamadart.dart';

import '../../domain/entities/translation_direction.dart';
import 'llm_model_download_service.dart';

const _systemPrompt =
    'You are a professional English-Vietnamese translator specialized in '
    'maritime and military terminology (Vietnam Coast Guard domain). '
    'Translate the given text to the target language. '
    'Reply with ONLY the translation, no explanation, no quotes, no notes.';

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
  /// nếu output lẫn CJK sau 1 lần retry — caller nên fallback sang
  /// nguồn khác thay vì hiện lỗi cho user.
  Future<String> translate(TranslationDirection direction, String text) async {
    final engine = _engine;
    if (engine == null) throw LlmModelNotLoadedException();
    if (text.trim().isEmpty) return '';

    final targetLabel = direction.targetLangLabel;
    final sourceLabel = direction.sourceLangLabel;

    for (var attempt = 0; attempt < 2; attempt++) {
      final result = await _runOnce(engine, sourceLabel, targetLabel, text);
      if (!_cjkPattern.hasMatch(result)) return result;
    }

    final last = await _runOnce(engine, sourceLabel, targetLabel, text);
    if (_cjkPattern.hasMatch(last)) throw LlmDegenerateOutputException(last);
    return last;
  }

  Future<String> _runOnce(
    LlamaEngine engine,
    String sourceLabel,
    String targetLabel,
    String text,
  ) async {
    final messages = [
      const LlamaChatMessage.fromText(role: LlamaChatRole.system, text: _systemPrompt),
      LlamaChatMessage.fromText(
        role: LlamaChatRole.user,
        text: 'Translate from $sourceLabel to $targetLabel:\n\n$text',
      ),
    ];

    final buffer = StringBuffer();
    await for (final chunk in engine.create(
      messages,
      params: const GenerationParams(maxTokens: 256, temp: 0.1),
    )) {
      final delta = chunk.choices.first.delta.content;
      if (delta != null) buffer.write(delta);
    }
    return buffer.toString().trim();
  }
}
