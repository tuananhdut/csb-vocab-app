import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/translation_providers.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../domain/entities/translation_direction.dart';

/// Prompt tải/tiến độ/lỗi cho 1 chiều dịch — gộp 3 trạng thái
/// [ModelNotDownloaded]/[ModelDownloading]/[ModelDownloadFailed] của
/// [modelDownloadStateProvider] thành 1 widget, hiện khi chiều đang chọn
/// chưa sẵn sàng ([ModelReady]) (xem `translate_screen.dart`).
class ModelDownloadPrompt extends ConsumerStatefulWidget {
  const ModelDownloadPrompt({super.key, required this.direction});

  final TranslationDirection direction;

  @override
  ConsumerState<ModelDownloadPrompt> createState() => _ModelDownloadPromptState();
}

class _ModelDownloadPromptState extends ConsumerState<ModelDownloadPrompt> {
  CancelToken? _cancelToken;

  void _startDownload() {
    _cancelToken = CancelToken();
    downloadTranslationModel(ref, widget.direction, cancelToken: _cancelToken);
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(modelDownloadStateProvider(widget.direction));
    final isOnline = ref.watch(connectivityProvider).value ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: switch (state) {
          ModelNotDownloaded() => _NotDownloadedView(
              direction: widget.direction,
              isOnline: isOnline,
              onDownload: _startDownload,
            ),
          ModelDownloading(:final progress, :final receivedBytes, :final totalBytes) =>
            _DownloadingView(
              progress: progress,
              receivedBytes: receivedBytes,
              totalBytes: totalBytes,
              onCancel: _cancelDownload,
            ),
          ModelDownloadFailed(:final message) => _FailedView(
              message: message,
              onRetry: _startDownload,
            ),
          ModelReady() => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _NotDownloadedView extends StatelessWidget {
  const _NotDownloadedView({
    required this.direction,
    required this.isOnline,
    required this.onDownload,
  });

  final TranslationDirection direction;
  final bool isOnline;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_download_outlined, size: 48, color: scheme.outline),
        const SizedBox(height: 16),
        Text(
          'Cần tải model dịch ${direction.label}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Dịch bằng mô hình AI offline (Helsinki-NLP/OPUS-MT), khoảng 130-140MB. '
          'Tải một lần, sau đó dùng được hoàn toàn không cần mạng.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: isOnline ? onDownload : null,
          icon: const Icon(Icons.download),
          label: const Text('Tải model'),
        ),
        if (!isOnline) ...[
          const SizedBox(height: 8),
          Text(
            'Cần có kết nối mạng để tải lần đầu.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

class _DownloadingView extends StatelessWidget {
  const _DownloadingView({
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
    required this.onCancel,
  });

  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final VoidCallback onCancel;

  String _formatMb(int bytes) => '${(bytes / 1e6).toStringAsFixed(1)}MB';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final indeterminate = totalBytes <= 0;
    final percentLabel = indeterminate ? '' : '${(progress * 100).round()}%';

    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: indeterminate ? null : progress,
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                if (!indeterminate)
                  Text(
                    percentLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  )
                else
                  Icon(Icons.download_rounded, size: 22, color: scheme.primary),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Đang tải model dịch…',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            indeterminate
                ? 'Đang chuẩn bị tải…'
                : '${_formatMb(receivedBytes)} / ${_formatMb(totalBytes)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onCancel,
              child: const Text('Huỷ'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 48, color: scheme.error),
        const SizedBox(height: 16),
        Text('Tải model thất bại', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
        ),
      ],
    );
  }
}
