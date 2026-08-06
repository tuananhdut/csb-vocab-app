import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/translation_providers.dart';
import '../../../domain/entities/translation_direction.dart';

/// Khung nguồn/kết quả khi model [direction] đã sẵn sàng ([ModelReady]) —
/// debounce input 500ms trước khi gọi [translateProvider] vì suy luận
/// ONNX không rẻ như tra DB, không được chạy lại mỗi keystroke (xem
/// ghi chú tại `translation_providers.dart`).
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
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
    final result = _debouncedText.trim().isEmpty
        ? null
        : ref.watch(translateProvider((widget.direction, _debouncedText)));

    return Padding(
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
            child: result == null
                ? Text(
                    'Bản dịch sẽ hiện ở đây',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.outline),
                  )
                : result.when(
                    loading: () => const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (e, _) => Text(
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
