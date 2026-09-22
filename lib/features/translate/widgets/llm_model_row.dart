import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/translation_providers.dart';

/// Hàng nhỏ cho phép tải model AI cục bộ (Qwen2.5-3B-Instruct, ~2.1GB)
/// làm fallback offline chất lượng cao hơn opus-mt hiện tại (xem
/// `tools/translation-eval/results/SUMMARY.md`) — CHỈ hiện trên Windows
/// desktop ([isLlmTranslationSupportedPlatform]), hoàn toàn độc lập với
/// [ModelStatusRow]/[ModelDownloadPrompt] (per-direction, opus-mt):
/// không sửa logic `canTranslate` hiện có, tránh ảnh hưởng luồng dịch
/// mặc định của mobile/màn hình khác nếu user không chủ động bật tính
/// năng này.
class LlmModelRow extends ConsumerStatefulWidget {
  const LlmModelRow({super.key});

  @override
  ConsumerState<LlmModelRow> createState() => _LlmModelRowState();
}

class _LlmModelRowState extends ConsumerState<LlmModelRow> {
  CancelToken? _cancelToken;

  void _startDownload() {
    _cancelToken = CancelToken();
    downloadLlmModel(ref, cancelToken: _cancelToken);
  }

  void _delete() => deleteLlmModel(ref);

  @override
  Widget build(BuildContext context) {
    if (!isLlmTranslationSupportedPlatform) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    // Seed 1 lần từ đĩa — cùng pattern với `translate_screen.dart`
    // (modelExistsOnDiskProvider) cho opus-mt, giữ hành vi nhất quán:
    // đã tải từ phiên trước thì không bắt tải lại.
    final existsOnDisk = ref.watch(llmModelExistsOnDiskProvider);
    existsOnDisk.whenData((exists) {
      if (!exists) return;
      final current = ref.read(llmModelDownloadStateProvider);
      if (current is ModelNotDownloaded) {
        Future.microtask(() {
          if (!mounted) return;
          ref.read(llmModelDownloadStateProvider.notifier).state = const ModelReady();
        });
      }
    });

    final state = ref.watch(llmModelDownloadStateProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.memory, size: 16, color: scheme.outline),
          const SizedBox(width: 8),
          Expanded(child: _statusText(context, state)),
          _action(state),
        ],
      ),
    );
  }

  Widget _statusText(BuildContext context, ModelDownloadState state) {
    final text = switch (state) {
      ModelNotDownloaded() =>
        'AI cục bộ (Qwen2.5-3B, ~2.1GB) — dịch offline chính xác hơn khi mất mạng',
      ModelDownloading(:final progress) => progress <= 0
          ? 'Đang chuẩn bị tải AI cục bộ…'
          : 'Đang tải AI cục bộ… ${(progress * 100).round()}%',
      ModelDownloadFailed() => 'Tải AI cục bộ thất bại',
      ModelReady() => 'Đã sẵn sàng AI cục bộ (Qwen2.5-3B) — ưu tiên dùng khi offline',
    };
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
    );
  }

  Widget _action(ModelDownloadState state) => switch (state) {
    ModelNotDownloaded() => TextButton(onPressed: _startDownload, child: const Text('Tải')),
    ModelDownloading() => TextButton(
      onPressed: () => _cancelToken?.cancel(),
      child: const Text('Huỷ'),
    ),
    ModelDownloadFailed() => TextButton(onPressed: _startDownload, child: const Text('Thử lại')),
    ModelReady() => TextButton(onPressed: _delete, child: const Text('Xoá')),
  };
}
