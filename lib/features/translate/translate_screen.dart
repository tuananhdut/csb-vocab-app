import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/translation_providers.dart';
import '../../domain/entities/translation_direction.dart';
import 'widgets/model_download_prompt.dart';
import 'widgets/translate_panels.dart';

/// FR-4 — Dịch Anh↔Việt bằng máy dịch neural on-device (opus-mt, tải
/// theo yêu cầu — xem `docs/spec_history.md` [IMPL-017], thay cho thiết
/// kế cũ "tra ghép từ/cụm" đã ghi ở `04_Translate.md`).
class TranslateScreen extends ConsumerStatefulWidget {
  const TranslateScreen({super.key});

  @override
  ConsumerState<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends ConsumerState<TranslateScreen> {
  TranslationDirection _direction = TranslationDirection.enToVi;

  void _swapDirection() {
    setState(() => _direction = _direction.reversed);
  }

  @override
  Widget build(BuildContext context) {
    // Seed trạng thái tải từ đĩa 1 lần khi provider khởi tạo — cho biết
    // model đã tải từ phiên trước hay chưa (StateProvider luôn khởi tạo
    // ModelNotDownloaded, cần đồng bộ thủ công vì Riverpod 3 không có
    // sẵn cách "seed StateProvider từ FutureProvider" trong convention
    // functional-provider-only của repo).
    final existsOnDisk = ref.watch(modelExistsOnDiskProvider(_direction));
    existsOnDisk.whenData((exists) {
      if (!exists) return;
      final current = ref.read(modelDownloadStateProvider(_direction));
      if (current is ModelNotDownloaded) {
        Future.microtask(() {
          if (!mounted) return;
          ref.read(modelDownloadStateProvider(_direction).notifier).state = const ModelReady();
        });
      }
    });

    final downloadState = ref.watch(modelDownloadStateProvider(_direction));

    return Column(
      children: [
        _DirectionSwitch(direction: _direction, onSwap: _swapDirection),
        const Divider(height: 1),
        Expanded(
          child: downloadState is ModelReady
              ? TranslatePanels(key: ValueKey(_direction), direction: _direction)
              : ModelDownloadPrompt(key: ValueKey(_direction), direction: _direction),
        ),
      ],
    );
  }
}

class _DirectionSwitch extends StatelessWidget {
  const _DirectionSwitch({required this.direction, required this.onSwap});

  final TranslationDirection direction;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(direction.sourceLangLabel, style: Theme.of(context).textTheme.labelLarge),
          IconButton(
            icon: Icon(Icons.swap_horiz, color: scheme.primary),
            onPressed: onSwap,
            tooltip: 'Đảo chiều dịch',
          ),
          Text(direction.targetLangLabel, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
