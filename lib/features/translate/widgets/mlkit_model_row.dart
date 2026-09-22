import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/translation_providers.dart';
import '../../../data/services/connectivity_service.dart';

/// Hàng nhỏ cho phép tải gói ngôn ngữ ML Kit Translation (Google,
/// on-device, ~30-150MB/ngôn ngữ) làm fallback offline cho mobile — CHỈ
/// hiện trên Android/iOS ([isMlKitTranslationSupportedPlatform]), cùng
/// vai trò với [LlmModelRow] bên desktop nhưng khác SDK (ML Kit chuyên
/// dịch, nhỏ gọn, phù hợp RAM/pin di động hơn LLM). Độc lập với
/// [ModelStatusRow]/[ModelDownloadPrompt] (per-direction, opus-mt).
class MlKitModelRow extends ConsumerStatefulWidget {
  const MlKitModelRow({super.key});

  @override
  ConsumerState<MlKitModelRow> createState() => _MlKitModelRowState();
}

class _MlKitModelRowState extends ConsumerState<MlKitModelRow> {
  void _startDownload() => downloadMlKitModel(ref);
  void _delete() => deleteMlKitModel(ref);

  @override
  Widget build(BuildContext context) {
    if (!isMlKitTranslationSupportedPlatform) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    // Seed 1 lần từ đĩa — cùng pattern với `LlmModelRow`/opus-mt.
    final existsOnDisk = ref.watch(mlkitModelExistsOnDiskProvider);
    existsOnDisk.whenData((exists) {
      if (!exists) return;
      final current = ref.read(mlkitModelDownloadStateProvider);
      if (current is ModelNotDownloaded) {
        Future.microtask(() {
          if (!mounted) return;
          ref.read(mlkitModelDownloadStateProvider.notifier).state = const ModelReady();
        });
      }
    });

    final state = ref.watch(mlkitModelDownloadStateProvider);
    // Cùng pattern với ModelStatusRow (opus-mt): tự ẩn khi đã sẵn sàng,
    // không cần chiếm chỗ nhắc lại điều user đã biết.
    if (state is ModelReady) return const SizedBox.shrink();
    // Tải cần mạng (ML Kit tự tải từ server Google) - chặn từ UI thay vì
    // để user bấm rồi kẹt spinner vô thời hạn (đã gặp thực tế: offline
    // + bấm Tải -> cuộc gọi native ML Kit không timeout, đứng mãi).
    final isOnline = ref.watch(connectivityProvider).value ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.translate, size: 16, color: scheme.outline),
          const SizedBox(width: 8),
          Expanded(child: _statusText(context, state, isOnline)),
          _action(state, isOnline),
        ],
      ),
    );
  }

  Widget _statusText(BuildContext context, ModelDownloadState state, bool isOnline) {
    final text = switch (state) {
      ModelNotDownloaded() => isOnline
          ? 'Dịch offline ML Kit (Google, ~30-150MB) — chính xác hơn khi mất mạng'
          : 'Dịch offline ML Kit — cần có mạng để tải lần đầu',
      ModelDownloading() => 'Đang tải gói ngôn ngữ ML Kit…',
      // Hiện message thật (e.toString() từ downloadMlKitModel) thay vì
      // chỉ báo chung chung — cần để biết lý do thật trên máy lỗi (thiếu
      // Google Play Services, timeout, mất mạng...) khi tester báo lại.
      ModelDownloadFailed(:final message) => 'Tải ML Kit thất bại: $message',
      ModelReady() => 'Đã sẵn sàng dịch offline ML Kit — ưu tiên dùng khi mất mạng',
    };
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
    );
  }

  Widget _action(ModelDownloadState state, bool isOnline) => switch (state) {
    ModelNotDownloaded() => TextButton(
      onPressed: isOnline ? _startDownload : null,
      child: const Text('Tải'),
    ),
    // ML Kit khong bao tien do/khong ho tro huy giua chung (khac
    // opus-mt/LLM co CancelToken) - chi hien spinner, khong co nut Huy.
    ModelDownloading() => const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    ModelDownloadFailed() => TextButton(
      onPressed: isOnline ? _startDownload : null,
      child: const Text('Thử lại'),
    ),
    ModelReady() => TextButton(onPressed: _delete, child: const Text('Xoá')),
  };
}
