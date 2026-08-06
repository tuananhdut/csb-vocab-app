import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/review.dart';
import 'multiple_choice_card.dart';
import 'review_providers.dart';
import 'review_result_screen.dart';

/// Phiên ôn tập khách quan (FR-5.2, đã bỏ hẳn lật thẻ tự chấm chủ quan
/// — xem `docs/csb-vocab-analysis/tasks/02-review-multi-mode/
/// 03-plan.md`): mỗi từ hiện dưới dạng trắc nghiệm hoặc gõ chữ (đã
/// chuẩn bị sẵn qua [buildReviewSession]), hệ thống tự chấm đúng/sai và
/// gọi `submitReview` — không cần người dùng tự đánh giá cảm nhận.
class ReviewSessionScreen extends ConsumerStatefulWidget {
  const ReviewSessionScreen({super.key, required this.questions, this.dictionaryId});
  final List<ReviewQuestion> questions;

  /// Bộ từ điển đang ôn (SCR-07 "Ôn tập" theo từng bộ) — `null` khi mở
  /// từ hàng đợi due chung (chưa có lối vào nào khác ngoài per-bộ, giữ
  /// tham số optional để không phải sửa signature nếu sau này có thêm).
  final int? dictionaryId;

  @override
  ConsumerState<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends ConsumerState<ReviewSessionScreen> {
  int _index = 0;
  int _correctCount = 0;

  Future<void> _onAnswered(bool isCorrect) async {
    final word = widget.questions[_index].word;
    await submitWordReview(
      ref,
      word.id,
      isCorrect ? ReviewRating.good : ReviewRating.forgot,
      dictionaryId: widget.dictionaryId,
    );
    if (!mounted) return;

    final correctCount = _correctCount + (isCorrect ? 1 : 0);
    if (_index + 1 >= widget.questions.length) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewResultScreen(
            correctCount: correctCount,
            totalCount: widget.questions.length,
          ),
        ),
      );
      return;
    }
    setState(() {
      _index += 1;
      _correctCount = correctCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text('Ôn tập (${_index + 1}/${widget.questions.length})'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(value: _index / widget.questions.length),
            const SizedBox(height: 12),
            _KindBadge(mode: question.mode),
            const SizedBox(height: 8),
            Expanded(
              // key theo id+index buoc Flutter tao lai State cua card con
              // khi chuyen sang cau hoi tiep theo - tranh giu lai trang
              // thai "da submit" (mau vien, disable) cua cau truoc.
              child: KeyedSubtree(
                key: ValueKey('${question.word.id}_$_index'),
                child: question.mode == QuestionMode.multipleChoice
                    ? MultipleChoiceCard(question: question, onAnswered: _onAnswered)
                    : _TypingCard(question: question, onAnswered: _onAnswered),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.mode});
  final QuestionMode mode;

  @override
  Widget build(BuildContext context) {
    final isMultipleChoice = mode == QuestionMode.multipleChoice;
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
            Icon(isMultipleChoice ? Icons.check_circle_outline : Icons.keyboard_outlined, size: 14),
            const SizedBox(width: 6),
            Text(
              isMultipleChoice ? 'Trắc nghiệm' : 'Gõ chữ',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Câu hỏi gõ chữ: hiện nghĩa tiếng Việt, gõ lại từ tiếng Anh, so khớp
/// tuyệt đối sau chuẩn hoá (khớp mockup
/// screen-07e-phien-on-tap-cau-go-chu.html). Trạng thái "đã submit" tự
/// thiết kế (mockup thiếu ảnh minh hoạ, đã chốt ở 03-plan.md): đổi viền
/// input theo đúng/sai, nếu sai hiện thêm dòng đáp án đúng dưới input.
class _TypingCard extends StatefulWidget {
  const _TypingCard({required this.question, required this.onAnswered});
  final ReviewQuestion question;
  final Future<void> Function(bool isCorrect) onAnswered;

  @override
  State<_TypingCard> createState() => _TypingCardState();
}

class _TypingCardState extends State<_TypingCard> {
  final _controller = TextEditingController();
  bool? _isCorrect;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isCorrect != null) return;
    final word = widget.question.word;
    final isCorrect = _controller.text.trim().toLowerCase() == word.word.trim().toLowerCase();
    setState(() => _isCorrect = isCorrect);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    await widget.onAnswered(isCorrect);
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.question.word;
    final scheme = Theme.of(context).colorScheme;
    final borderColor = switch (_isCorrect) {
      true => AppColors.teal,
      false => scheme.error,
      null => AppColors.border,
    };

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (word.partOfSpeech.isNotEmpty)
                  Chip(label: Text(word.partOfSpeech), visualDensity: VisualDensity.compact),
                const SizedBox(height: 8),
                Text(word.meaningVi, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Từ tiếng Anh là gì?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: _isCorrect == null,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Nhập từ tiếng Anh…',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isCorrect == null ? _submit : null,
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
        if (_isCorrect == false) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Đáp án đúng: ${word.word}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.error),
            ),
          ),
        ],
      ],
    );
  }
}
