import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/review.dart';
import '../vocab/word_widgets.dart';

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

  void _selectByIndex(int index, List<String> choices) {
    if (index < choices.length) _select(choices[index]);
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.question.word;
    final choices = widget.question.choices ?? const [];
    final scheme = Theme.of(context).colorScheme;

    // So 1-4 chon dap an bang ban phim (Windows/desktop).
    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < 4; i++)
          SingleActivator(_digitKeys[i]): () => _selectByIndex(i, choices),
      },
      child: Focus(
        autofocus: true,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: WordImage(imagePath: word.imagePath, height: 96),
                          ),
                          const SizedBox(height: 14),
                          Text(word.word, style: Theme.of(context).textTheme.headlineMedium),
                          if (word.phonetic.isNotEmpty)
                            Text(
                              word.phonetic,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.primary),
                            ),
                          const SizedBox(height: 6),
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
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var col = 0; col < 2; col++) ...[
                              if (col > 0) const SizedBox(width: 12),
                              Expanded(
                                child: _ChoiceCell(
                                  index: row * 2 + col,
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
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _digitKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
];

class _ChoiceCell extends StatelessWidget {
  const _ChoiceCell({
    required this.index,
    required this.choice,
    required this.selected,
    required this.correctAnswer,
    required this.onTap,
  });

  final int index;
  final String choice;
  final String? selected;
  final String correctAnswer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCorrectChoice = choice == correctAnswer;
    final isPicked = choice == selected;

    Color borderColor = AppColors.border;
    Color fillColor = AppColors.panel;
    Color badgeColor = scheme.outline;
    Widget? statusIcon;
    var isHighlighted = false;

    if (selected != null) {
      if (isCorrectChoice) {
        isHighlighted = true;
        borderColor = AppColors.teal;
        fillColor = AppColors.teal.withValues(alpha: 0.1);
        badgeColor = AppColors.teal;
        statusIcon = const Icon(Icons.check_circle, color: AppColors.teal, size: 20);
      } else if (isPicked) {
        isHighlighted = true;
        borderColor = scheme.error;
        fillColor = scheme.error.withValues(alpha: 0.1);
        badgeColor = scheme.error;
        statusIcon = Icon(Icons.cancel, color: scheme.error, size: 20);
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor, width: isHighlighted ? 1.5 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: selected == null ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    choice,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (statusIcon != null) ...[
                  const SizedBox(width: 6),
                  statusIcon,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
