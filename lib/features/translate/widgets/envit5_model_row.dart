import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/translation_providers.dart';

/// Hàng nhỏ cho phép tải model envit5 (VietAI, T5-base, ~450MB đã
/// quantize INT8) làm fallback offline CHÍNH trên desktop — thay thế vai
/// trò [LlmModelRow] (Qwen2.5-3B): benchmark cho thấy chất lượng gần
/// bằng online (chrF 73.66 vs 76.39 MyMemory) và tốt hơn hẳn Qwen (51.7)
/// với RAM/tốc độ đều tốt hơn (xem `tools/translation-eval/results/`).
/// [LlmModelRow] CỐ Ý không xoá (giữ để dùng lại sau) nhưng không còn
/// hiện trên `TranslateScreen`.
class Envit5ModelRow extends ConsumerStatefulWidget {
  const Envit5ModelRow({super.key});

  @override
  ConsumerState<Envit5ModelRow> createState() => _Envit5ModelRowState();
}

class _Envit5ModelRowState extends ConsumerState<Envit5ModelRow> {
  CancelToken? _cancelToken;

  void _startDownload() {
    _cancelToken = CancelToken();
    downloadEnvit5Model(ref, cancelToken: _cancelToken);
  }

  void _delete() => deleteEnvit5Model(ref);

  @override
  Widget build(BuildContext context) {
    if (!isEnvit5TranslationSupportedPlatform) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    // Seed 1 lần từ đĩa — cùng pattern với LlmModelRow/MlKitModelRow.
    final existsOnDisk = ref.watch(envit5ModelExistsOnDiskProvider);
    existsOnDisk.whenData((exists) {
      if (!exists) return;
      final current = ref.read(envit5ModelDownloadStateProvider);
      if (current is ModelNotDownloaded) {
        Future.microtask(() {
          if (!mounted) return;
          ref.read(envit5ModelDownloadStateProvider.notifier).state = const ModelReady();
        });
      }
    });

    final state = ref.watch(envit5ModelDownloadStateProvider);
    // Tự ẩn khi đã sẵn sàng — cùng pattern ModelStatusRow/MlKitModelRow,
    // không chiếm chỗ nhắc lại điều user đã biết.
    if (state is ModelReady) return const SizedBox.shrink();

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
        'Dịch offline envit5 (~450MB) — chính xác gần bằng online khi mất mạng',
      ModelDownloading(:final progress) => progress <= 0
          ? 'Đang chuẩn bị tải envit5…'
          : 'Đang tải envit5… ${(progress * 100).round()}%',
      ModelDownloadFailed(:final message) => 'Tải envit5 thất bại: $message',
      ModelReady() => 'Đã sẵn sàng dịch offline envit5 — ưu tiên dùng khi mất mạng',
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
