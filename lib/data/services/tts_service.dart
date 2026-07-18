import 'package:flutter_tts/flutter_tts.dart';

/// Phát âm từ vựng tiếng Anh (nút loa cạnh IPA ở màn Tra cứu, FR-2).
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    _initialized = true;
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    await _tts.stop();
    await _tts.speak(text);
  }
}
