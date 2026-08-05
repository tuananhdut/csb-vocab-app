import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/review.dart';

/// Câu hỏi trắc nghiệm: hiện từ tiếng Anh, chọn 1/4 nghĩa tiếng Việt
/// (khớp mockup screen-07f-phien-on-tap-cau-trac-nghiem.html) — dùng
/// chung cho phiên ôn tập (`ReviewSessionScreen`) và phiên "Học từ mới"
/// (`LearnNewWordsScreen`, củng cố ngay sau khi xem overview).
class MultipleChoiceCard extends StatefulWidget {
  const MultipleChoiceCard({super.key, required this.question, required this.onAnswered});
  final ReviewQuestion question;
  final Future<void> Function(bool isCorrect) onAnswered;

  @override
  State<MultipleChoiceCard> createState() => _MultipleChoiceCardState();
}

class _MultipleChoiceCardState extends State<MultipleChoiceCard> {
  String? _selected;

  Future<void> _select(String choice) async {
    if (_selected != null) return;
    setState(() => _selected = choice);
    final isCorrect = choice == widget.question.word.meaningVi;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    await widget.onAnswered(isCorrect);
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.question.word;
    final choices = widget.question.choices ?? const [];
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        word.imagePath ?? AppConstants.defaultWordImage,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Image.asset(
                          AppConstants.defaultWordImage,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(word.word, style: Theme.of(context).textTheme.headlineMedium),
                    if (word.phonetic.isNotEmpty)
                      Text(
                        word.phonetic,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.primary),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Chọn nghĩa tiếng Việt đúng',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ),
            ),
            // Luoi 2x2 thay vi liet ke doc 4 lua chon - tan dung chieu
            // rong tren desktop, giu dung 4 lua chon co dinh tu
            // ReviewQuestion.choices (khong tong quat hoa cho so luong
            // khac vi khong co yeu cau nao ngoai 4).
            for (var row = 0; row < 2; row++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    for (var col = 0; col < 2; col++) ...[
                      if (col > 0) const SizedBox(width: 12),
                      Expanded(
                        child: _ChoiceCell(
                          choice: choices[row * 2 + col],
                          selected: _selected,
                          correctAnswer: word.meaningVi,
                          onTap: () => _select(choices[row * 2 + col]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCell extends StatelessWidget {
  const _ChoiceCell({required this.choice, required this.selected, required this.correctAnswer, required this.onTap});

  final String choice;
  final String? selected;
  final String correctAnswer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color? borderColor;
    Color? fillColor;

    if (selected != null) {
      if (choice == correctAnswer) {
        borderColor = AppColors.teal;
        fillColor = AppColors.teal.withValues(alpha: 0.1);
      } else if (choice == selected) {
        borderColor = scheme.error;
        fillColor = scheme.error.withValues(alpha: 0.1);
      }
    }

    return Material(
      color: fillColor ?? AppColors.panel,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: selected == null ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor ?? AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            choice,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
