import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/tts_service.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/word.dart';
import '../review/multiple_choice_card.dart';
import '../review/review_providers.dart';
import '../vocab/word_widgets.dart';

/// Phiên "Học từ mới": học theo từng CẶP 2 từ — xem overview (ảnh/tên/
/// phiên âm tự phát âm/nghĩa/ví dụ), rồi làm ngay trắc nghiệm củng cố
/// cho đúng 2 từ vừa xem, trước khi sang cặp tiếp theo. Học chủ động
/// (active recall) ngay trong lúc học thay vì chỉ đọc thụ động rồi mới
/// ôn tập ở phiên sau — dễ nhớ hơn hẳn so với chỉ xem overview đơn
/// thuần. Xem hết tất cả các cặp mới đánh dấu "đã học" cả lô và đưa vào
/// hàng đợi ôn tập SM-2.
class LearnNewWordsScreen extends ConsumerStatefulWidget {
  const LearnNewWordsScreen({super.key, required this.dictionaryId, required this.words});

  final int dictionaryId;
  final List<VocabWord> words;

  @override
  ConsumerState<LearnNewWordsScreen> createState() => _LearnNewWordsScreenState();
}

enum _Stage { overview, quiz }

class _LearnNewWordsScreenState extends ConsumerState<LearnNewWordsScreen> {
  static const _pairSize = 2;

  late final List<List<VocabWord>> _pairs = [
    for (var i = 0; i < widget.words.length; i += _pairSize)
      widget.words.sublist(i, (i + _pairSize).clamp(0, widget.words.length)),
  ];

  int _pairIndex = 0;
  int _overviewIndexInPair = 0;
  _Stage _stage = _Stage.overview;
  List<ReviewQuestion>? _quizQuestions;
  int _quizIndex = 0;

  List<VocabWord> get _currentPair => _pairs[_pairIndex];

  Future<void> _nextOverview() async {
    if (_overviewIndexInPair + 1 < _currentPair.length) {
      setState(() => _overviewIndexInPair += 1);
      return;
    }
    final questions = await buildQuickQuiz(ref, _currentPair);
    if (!mounted) return;
    setState(() {
      _stage = _Stage.quiz;
      _quizQuestions = questions;
      _quizIndex = 0;
    });
  }

  Future<void> _onQuizAnswered(bool isCorrect) async {
    if (_quizIndex + 1 < _quizQuestions!.length) {
      setState(() => _quizIndex += 1);
      return;
    }

    if (_pairIndex + 1 < _pairs.length) {
      setState(() {
        _pairIndex += 1;
        _overviewIndexInPair = 0;
        _stage = _Stage.overview;
        _quizQuestions = null;
      });
      return;
    }

    await markWordsLearnedBatch(ref, widget.words.map((w) => w.id).toList());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => _LearnNewWordsResultScreen(count: widget.words.length)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = widget.words.length * 2; // moi tu: 1 overview + 1 cau quiz
    final doneSteps = _pairIndex * _pairSize * 2 +
        (_stage == _Stage.overview ? _overviewIndexInPair : _currentPair.length + _quizIndex);

    return Scaffold(
      appBar: AppBar(title: const Text('Học từ mới')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(value: doneSteps / totalSteps),
            const SizedBox(height: 12),
            _StageBadge(stage: _stage),
            const SizedBox(height: 8),
            Expanded(
              child: _stage == _Stage.overview
                  ? _WordIntroCard(
                      key: ValueKey('overview_${_currentPair[_overviewIndexInPair].id}'),
                      word: _currentPair[_overviewIndexInPair],
                    )
                  : KeyedSubtree(
                      key: ValueKey('quiz_${_quizQuestions![_quizIndex].word.id}'),
                      child: MultipleChoiceCard(
                        question: _quizQuestions![_quizIndex],
                        onAnswered: _onQuizAnswered,
                      ),
                    ),
            ),
            if (_stage == _Stage.overview)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _nextOverview,
                  child: Text(
                    _overviewIndexInPair + 1 < _currentPair.length ? 'Từ tiếp theo' : 'Kiểm tra nhanh',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.stage});
  final _Stage stage;

  @override
  Widget build(BuildContext context) {
    final isOverview = stage == _Stage.overview;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.panel2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isOverview ? Icons.menu_book_outlined : Icons.check_circle_outline, size: 14),
            const SizedBox(width: 6),
            Text(
              isOverview ? 'Học từ mới' : 'Kiểm tra nhanh',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _WordIntroCard extends StatefulWidget {
  const _WordIntroCard({super.key, required this.word});
  final VocabWord word;

  @override
  State<_WordIntroCard> createState() => _WordIntroCardState();
}

class _WordIntroCardState extends State<_WordIntroCard> {
  @override
  void initState() {
    super.initState();
    TtsService.instance.speak(widget.word.word);
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  word.imagePath ?? AppConstants.defaultWordImage,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Image.asset(
                    AppConstants.defaultWordImage,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(word.word, style: textTheme.headlineMedium)),
                  if (word.partOfSpeech.isNotEmpty) PosTag(word.partOfSpeech),
                ],
              ),
              if (word.phonetic.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      word.phonetic,
                      style: textTheme.bodyMedium?.copyWith(fontFamily: AppFonts.mono, color: AppColors.brand),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => TtsService.instance.speak(word.word),
                      icon: const Icon(Icons.volume_up_outlined, size: 20),
                      color: AppColors.brand,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Phát âm lại',
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.panel2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(word.meaningVi, style: textTheme.bodyLarge?.copyWith(height: 1.4)),
              ),
              if (word.examples.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('VÍ DỤ', style: textTheme.labelMedium?.copyWith(color: scheme.outline)),
                const SizedBox(height: 8),
                for (final ex in word.examples)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.panel2,
                      border: Border(left: BorderSide(color: AppColors.brand, width: 3)),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ex.en.isNotEmpty) Text(ex.en, style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                        if (ex.vi.isNotEmpty) Text(ex.vi, style: textTheme.bodySmall?.copyWith(color: scheme.outline)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LearnNewWordsResultScreen extends StatelessWidget {
  const _LearnNewWordsResultScreen({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Học từ mới')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.celebration_outlined, size: 72, color: scheme.primary),
              const SizedBox(height: 16),
              Text('Đã thêm $count từ vào hàng đợi ôn tập', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
