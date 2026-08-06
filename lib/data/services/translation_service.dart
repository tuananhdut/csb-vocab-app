import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/translation_direction.dart';
import 'model_download_service.dart';

/// Marian/opus-mt dùng bảng `vocab.json` riêng (piece -> id), KHÁC id nội
/// bộ trong file `.spm` gốc — xác nhận qua POC (xem
/// `tools/onnx-model-conversion/README.md` mục "Ghi chú quan trọng").
/// Dùng thư viện SentencePiece thuần chỉ để segment câu thành piece,
/// tự map piece<->id qua bảng này.
class _MarianVocab {
  _MarianVocab(this._pieceToId) : _idToPiece = _pieceToId.map((k, v) => MapEntry(v, k));

  final Map<String, int> _pieceToId;
  final Map<int, String> _idToPiece;

  static const _unkId = 1; // '<unk>' trong vocab.json

  static Future<_MarianVocab> loadFromFile(File file) async {
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return _MarianVocab(raw.map((k, v) => MapEntry(k, v as int)));
  }

  List<int> piecesToIds(List<String> pieces) =>
      pieces.map((piece) => _pieceToId[piece] ?? _unkId).toList();

  String idsToText(List<int> ids) {
    final pieces = ids.map((id) => _idToPiece[id] ?? '').where((p) => p.isNotEmpty);
    return pieces.join('').replaceAll('▁', ' ').trim();
  }
}

class _MarianConfig {
  const _MarianConfig({
    required this.decoderStartTokenId,
    required this.eosTokenId,
    required this.decoderLayers,
  });

  final int decoderStartTokenId;
  final int eosTokenId;
  final int decoderLayers;

  static Future<_MarianConfig> loadFromFile(File file) async {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return _MarianConfig(
      decoderStartTokenId: json['decoder_start_token_id'] as int,
      eosTokenId: json['eos_token_id'] as int,
      decoderLayers: json['decoder_layers'] as int,
    );
  }
}

class _DirectionSessions {
  _DirectionSessions({
    required this.encoder,
    required this.decoder,
    required this.decoderWithPast,
    required this.sourceTokenizer,
    required this.vocab,
    required this.config,
  });

  final OrtSession encoder;
  final OrtSession decoder;
  final OrtSession decoderWithPast;
  final SentencePieceTokenizer sourceTokenizer;
  final _MarianVocab vocab;
  final _MarianConfig config;
}

/// Chưa tải model cho chiều đang dịch — gọi
/// `downloadTranslationModel(ref, direction)` trước (xem
/// `translation_providers.dart`).
class ModelNotLoadedException implements Exception {
  ModelNotLoadedException(this.direction);
  final TranslationDirection direction;

  @override
  String toString() => 'Model chưa tải cho chiều ${direction.label}';
}

/// Suy luận dịch on-device bằng model opus-mt đã quantize (FR-4,
/// [IMPL-017]) — singleton quản lý ONNX session theo từng chiều, nạp
/// khi lần đầu dịch (không nạp sẵn lúc khởi động app, tránh tốn RAM cho
/// tính năng chưa dùng tới). Vòng lặp decode dùng logic đã kiểm chứng ở
/// POC (`docs`/lịch sử triển khai FR-4): dịch khớp 100% với inference
/// bằng `transformers`/PyTorch gốc cho câu test.
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static const _maxDecodeSteps = 128;

  final _sessions = <TranslationDirection, _DirectionSessions>{};

  bool isLoaded(TranslationDirection direction) => _sessions.containsKey(direction);

  Future<void> loadDirection(TranslationDirection direction) async {
    if (_sessions.containsKey(direction)) return;

    final dir = await ModelDownloadService.instance.directoryFor(direction);
    if (!await ModelDownloadService.instance.isDirectionDownloaded(direction)) {
      throw ModelNotLoadedException(direction);
    }

    final ort = OnnxRuntime();
    final encoder = await ort.createSession(p.join(dir.path, 'encoder_model_quantized.onnx'));
    final decoder = await ort.createSession(p.join(dir.path, 'decoder_model_quantized.onnx'));
    final decoderWithPast =
        await ort.createSession(p.join(dir.path, 'decoder_with_past_model_quantized.onnx'));
    final sourceTokenizer = await SentencePieceTokenizer.fromModelFile(
      p.join(dir.path, 'source.spm'),
      config: const SentencePieceConfig(addEosToken: false),
    );
    final vocab = await _MarianVocab.loadFromFile(File(p.join(dir.path, 'vocab.json')));
    final config = await _MarianConfig.loadFromFile(File(p.join(dir.path, 'config.json')));

    _sessions[direction] = _DirectionSessions(
      encoder: encoder,
      decoder: decoder,
      decoderWithPast: decoderWithPast,
      sourceTokenizer: sourceTokenizer,
      vocab: vocab,
      config: config,
    );
  }

  Future<void> unloadDirection(TranslationDirection direction) async {
    final s = _sessions.remove(direction);
    await s?.encoder.close();
    await s?.decoder.close();
    await s?.decoderWithPast.close();
  }

  Future<String> translate(TranslationDirection direction, String text) async {
    final s = _sessions[direction];
    if (s == null) throw ModelNotLoadedException(direction);
    if (text.trim().isEmpty) return '';

    final pieces = s.sourceTokenizer.encode(text).tokens;
    final inputIds = s.vocab.piecesToIds(pieces)..add(s.config.eosTokenId);
    final seqLen = inputIds.length;

    final inputIdsValue =
        await OrtValue.fromList(Int64List.fromList(inputIds), [1, seqLen]);
    final attentionMaskValue =
        await OrtValue.fromList(Int64List.fromList(List.filled(seqLen, 1)), [1, seqLen]);

    final encoderOutputs = await s.encoder.run({
      'input_ids': inputIdsValue,
      'attention_mask': attentionMaskValue,
    });
    final encoderHiddenStates = encoderOutputs['last_hidden_state']!;

    var currentToken = s.config.decoderStartTokenId;
    final generatedIds = <int>[];
    Map<String, OrtValue>? pastKv;

    for (var step = 0; step < _maxDecodeSteps; step++) {
      final decoderInputIds =
          await OrtValue.fromList(Int64List.fromList([currentToken]), [1, 1]);

      final Map<String, OrtValue> outputs;
      if (step == 0) {
        outputs = await s.decoder.run({
          'input_ids': decoderInputIds,
          'encoder_hidden_states': encoderHiddenStates,
          'encoder_attention_mask': attentionMaskValue,
        });
      } else {
        outputs = await s.decoderWithPast.run({
          'input_ids': decoderInputIds,
          'encoder_attention_mask': attentionMaskValue,
          ...pastKv!,
        });
      }

      final logits = await outputs['logits']!.asList();
      currentToken = _argmax(logits);

      if (currentToken == s.config.eosTokenId) break;
      generatedIds.add(currentToken);

      final nextPastKv = <String, OrtValue>{};
      for (var l = 0; l < s.config.decoderLayers; l++) {
        nextPastKv['past_key_values.$l.decoder.key'] = outputs['present.$l.decoder.key']!;
        nextPastKv['past_key_values.$l.decoder.value'] = outputs['present.$l.decoder.value']!;
        if (step == 0) {
          nextPastKv['past_key_values.$l.encoder.key'] = outputs['present.$l.encoder.key']!;
          nextPastKv['past_key_values.$l.encoder.value'] = outputs['present.$l.encoder.value']!;
        } else {
          nextPastKv['past_key_values.$l.encoder.key'] = pastKv!['past_key_values.$l.encoder.key']!;
          nextPastKv['past_key_values.$l.encoder.value'] = pastKv['past_key_values.$l.encoder.value']!;
        }
      }
      pastKv = nextPastKv;
    }

    return s.vocab.idsToText(generatedIds);
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
