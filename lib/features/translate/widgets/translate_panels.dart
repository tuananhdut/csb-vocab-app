import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dismiss_keyboard_on_tap.dart';
import '../../../data/repositories/translation_providers.dart';
import '../../../data/repositories/vocab_providers.dart';
import '../../../domain/entities/translation_direction.dart';

/// Khung nguồn/kết quả khi model [direction] đã sẵn sàng ([ModelReady]) —
/// debounce input 800ms trước khi gọi [translateProvider] vì suy luận
/// ONNX/LLM không rẻ như tra DB, không được chạy lại mỗi keystroke (xem
/// ghi chú tại `translation_providers.dart`). Giảm từ 1200ms theo yêu
/// cầu (phản hồi sớm hơn sau khi ngừng gõ) - vẫn đủ để không bắn request
/// mỗi keystroke, dù người gõ chậm có thể bắn nhiều request dở dang hơn
/// mốc 1200ms trước đó.
class TranslatePanels extends ConsumerStatefulWidget {
  const TranslatePanels({super.key, required this.direction});

  final TranslationDirection direction;

  @override
  ConsumerState<TranslatePanels> createState() => _TranslatePanelsState();
}

class _TranslatePanelsState extends ConsumerState<TranslatePanels> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _debouncedText = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      setState(() => _debouncedText = value);
    });
  }

  @override
  void didUpdateWidget(covariant TranslatePanels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.direction != widget.direction) {
      // Đảo chiều dịch — câu nguồn cũ không còn đúng ngôn ngữ, xoá sạch.
      _controller.clear();
      setState(() => _debouncedText = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = _debouncedText.trim().isNotEmpty;
    // Dictionary first: an exact hit skips the machine translator
    // entirely, so no online request is fired while the lookup is pending.
    final dictMatch = hasText
        ? ref.watch(exactTranslateLookupProvider((widget.direction, _debouncedText)))
        : null;
    final dictWord = dictMatch?.value;
    final result = !hasText || dictMatch!.isLoading || dictWord != null
        ? null
        : ref.watch(translateProvider((widget.direction, _debouncedText)));

    return DismissKeyboardOnTap(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.direction.sourceLangLabel} → ${widget.direction.targetLangLabel}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: 12),
            _Panel(
              child: TextField(
                controller: _controller,
                maxLines: 5,
                minLines: 3,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Nhập ${widget.direction.sourceLangLabel.toLowerCase()}…',
                  border: InputBorder.none,
                ),
                onChanged: _onChanged,
              ),
            ),
            const SizedBox(height: 12),
            _Panel(
              child: dictWord != null
                  ? _DictionaryResult(
                      text: widget.direction == TranslationDirection.enToVi
                          ? dictWord.meaningVi
                          : dictWord.word,
                    )
                  : result == null
                  ? Text(
                      'Bản dịch sẽ hiện ở đây',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.outline),
                    )
                  : result.when(
                      loading: () => Row(
                        children: [
                          SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.outline,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Đang dịch…',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: scheme.outline),
                          ),
                        ],
                      ),
                      error: (e, _) => SelectableText(
                        'Lỗi dịch: $e',
                        style: TextStyle(color: scheme.error),
                      ),
                      data: (text) => SelectableText(
                        text,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DictionaryResult extends StatelessWidget {
  const _DictionaryResult({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified_outlined, size: 14, color: AppColors.brand),
            const SizedBox(width: 4),
            Text(
              'Có trong từ điển',
              style: textTheme.labelSmall?.copyWith(color: AppColors.brand),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(text, style: textTheme.bodyMedium),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
