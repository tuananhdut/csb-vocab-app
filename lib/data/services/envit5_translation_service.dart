import 'dart:typed_data';

import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/translation_direction.dart';
import 'envit5_model_download_service.dart';

/// Chưa tải model envit5 — gọi `downloadEnvit5Model(ref)` trước (xem
/// `translation_providers.dart`).
class Envit5ModelNotLoadedException implements Exception {
  @override
  String toString() => 'Model envit5 chưa tải';
}

/// Suy luận dịch on-device bằng envit5 (VietAI, T5-base, quantize INT8) -
/// thay thế Qwen2.5-3B làm offline fallback chính trên desktop (xem
/// benchmark `tools/translation-eval/results/`). Khác
/// [TranslationService] (opus-mt, per-direction): CHỈ 1 bộ session dùng
/// chung cho cả 2 chiều, chọn chiều qua prefix văn bản "en: "/"vi: "
/// (T5 text-to-text) thay vì model riêng/chiều.
///
/// Lưu ý khác opus-mt: đồ thị ONNX của bản quantize này (xem
/// `tools/translation-eval/sources/envit5.py`) khai báo
/// `encoder_hidden_states` là input bắt buộc ở CẢ decoder không-past lẫn
/// decoder-with-past (dù past_key_values.*.encoder.* đã đủ thông tin) -
/// thiếu sẽ báo lỗi thiếu input, đã xác nhận qua `session.get_inputs()`.
class Envit5TranslationService {
  Envit5TranslationService._();
  static final Envit5TranslationService instance = Envit5TranslationService._();

  static const _maxDecodeSteps = 128;
  static const _decoderStartTokenId = 0; // = pad_token_id, chuẩn T5
  static const _eosTokenId = 1;
  static const _numDecoderLayers = 12;

  OrtSession? _encoder;
  OrtSession? _decoder;
  OrtSession? _decoderWithPast;
  SentencePieceTokenizer? _tokenizer;

  bool get isLoaded => _encoder != null;

  Future<void> load() async {
    if (isLoaded) return;

    final dir = await Envit5ModelDownloadService.instance.modelDir;
    if (!await Envit5ModelDownloadService.instance.isDownloaded()) {
      throw Envit5ModelNotLoadedException();
    }

    final ort = OnnxRuntime();
    _encoder = await ort.createSession(p.join(dir.path, 'encoder_model_quantized.onnx'));
    _decoder = await ort.createSession(p.join(dir.path, 'decoder_model_quantized.onnx'));
    _decoderWithPast =
        await ort.createSession(p.join(dir.path, 'decoder_with_past_model_quantized.onnx'));
    _tokenizer = await SentencePieceTokenizer.fromModelFile(
      p.join(dir.path, 'spiece.model'),
      config: const SentencePieceConfig(addEosToken: false),
    );
  }

  Future<void> unload() async {
    await _encoder?.close();
    await _decoder?.close();
    await _decoderWithPast?.close();
    _encoder = null;
    _decoder = null;
    _decoderWithPast = null;
    _tokenizer = null;
  }

  Future<String> translate(TranslationDirection direction, String text) async {
    final encoder = _encoder;
    final decoder = _decoder;
    final decoderWithPast = _decoderWithPast;
    final tokenizer = _tokenizer;
    if (encoder == null || decoder == null || decoderWithPast == null || tokenizer == null) {
      throw Envit5ModelNotLoadedException();
    }
    if (text.trim().isEmpty) return '';

    final isEnToVi = direction == TranslationDirection.enToVi;
    final prefixed = '${isEnToVi ? 'en' : 'vi'}: $text';

    final inputIds = tokenizer.encode(prefixed).ids.toList()..add(_eosTokenId);
    final seqLen = inputIds.length;

    final inputIdsValue = await OrtValue.fromList(Int64List.fromList(inputIds), [1, seqLen]);
    final attentionMaskValue =
        await OrtValue.fromList(Int64List.fromList(List.filled(seqLen, 1)), [1, seqLen]);

    final encoderOutputs = await encoder.run({
      'input_ids': inputIdsValue,
      'attention_mask': attentionMaskValue,
    });
    final encoderHiddenStates = encoderOutputs['last_hidden_state']!;

    var currentToken = _decoderStartTokenId;
    final generatedIds = <int>[];
    Map<String, OrtValue>? pastKv;

    for (var step = 0; step < _maxDecodeSteps; step++) {
      final decoderInputIds = await OrtValue.fromList(Int64List.fromList([currentToken]), [1, 1]);

      final Map<String, OrtValue> outputs;
      if (step == 0) {
        outputs = await decoder.run({
          'input_ids': decoderInputIds,
          'encoder_hidden_states': encoderHiddenStates,
          'encoder_attention_mask': attentionMaskValue,
        });
      } else {
        outputs = await decoderWithPast.run({
          'input_ids': decoderInputIds,
          'encoder_hidden_states': encoderHiddenStates,
          'encoder_attention_mask': attentionMaskValue,
          ...pastKv!,
        });
      }

      final logits = await outputs['logits']!.asList();
      currentToken = _argmax(logits);

      if (currentToken == _eosTokenId) break;
      generatedIds.add(currentToken);

      final nextPastKv = <String, OrtValue>{};
      for (var l = 0; l < _numDecoderLayers; l++) {
        nextPastKv['past_key_values.$l.decoder.key'] = outputs['present.$l.decoder.key']!;
        nextPastKv['past_key_values.$l.decoder.value'] = outputs['present.$l.decoder.value']!;
        if (step == 0) {
          nextPastKv['past_key_values.$l.encoder.key'] = outputs['present.$l.encoder.key']!;
          nextPastKv['past_key_values.$l.encoder.value'] = outputs['present.$l.encoder.value']!;
        } else {
          nextPastKv['past_key_values.$l.encoder.key'] = pastKv!['past_key_values.$l.encoder.key']!;
          nextPastKv['past_key_values.$l.encoder.value'] =
              pastKv['past_key_values.$l.encoder.value']!;
        }
      }
      pastKv = nextPastKv;
    }

    return _stripLanguagePrefix(tokenizer.decode(generatedIds));
  }

  /// Model sinh cả prefix ngôn ngữ đích ("vi: "/"en: ") ngay đầu bản dịch
  /// (đúng cách VietAI demo trong model card) - đã xác nhận qua benchmark
  /// Python (`tools/translation-eval/sources/envit5.py`), API này chỉ
  /// cần nội dung dịch, không cần lặp lại prefix.
  String _stripLanguagePrefix(String decoded) {
    for (final prefix in ['vi:', 'en:']) {
      if (decoded.toLowerCase().startsWith(prefix)) {
        return decoded.substring(prefix.length).trim();
      }
    }
    return decoded;
  }

  int _argmax(dynamic nested) {
    var bestIdx = 0;
    var bestVal = double.negativeInfinity;
    var i = 0;
    void walk(dynamic v) {
      if (v is List) {
        for (final e in v) {
          walk(e);
        }
      } else if (v is num) {
        if (v > bestVal) {
          bestVal = v.toDouble();
          bestIdx = i;
        }
        i++;
      }
    }

    walk(nested);
    return bestIdx;
  }
}
