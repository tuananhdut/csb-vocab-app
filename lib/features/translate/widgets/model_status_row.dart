import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/translation_providers.dart';
import '../../../domain/entities/translation_direction.dart';

/// Hàng trạng thái nhỏ, cố định — cho user đang online biết vẫn có thể
/// tải model on-device của [direction] để dùng khi mất mạng sau này.
/// [ModelDownloadPrompt] (chặn cả màn) chỉ hiện khi offline VÀ chưa tải
/// (xem `translate_screen.dart`) nên khi online mà chưa tải, đây là chỗ
/// duy nhất còn cho user thấy nút "Tải" — trước đây bị ẩn hoàn toàn.
class ModelStatusRow extends ConsumerStatefulWidget {
  const ModelStatusRow({super.key, required this.direction});

  final TranslationDirection direction;

  @override
  ConsumerState<ModelStatusRow> createState() => _ModelStatusRowState();
}

class _ModelStatusRowState extends ConsumerState<ModelStatusRow> {
  CancelToken? _cancelToken;

  void _startDownload() {
    _cancelToken = CancelToken();
    downloadTranslationModel(ref, widget.direction, cancelToken: _cancelToken);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(modelDownloadStateProvider(widget.direction));

    return switch (state) {
      ModelNotDownloaded() => _StatusLine(
          icon: Icons.cloud_download_outlined,
          iconColor: scheme.outline,
          text: 'Chưa tải model offline cho ${widget.direction.label}',
          action: TextButton(onPressed: _startDownload, child: const Text('Tải')),
        ),
      ModelDownloading(:final progress) => _StatusLine(
          icon: Icons.downloading,
          iconColor: scheme.primary,
          text: progress <= 0
              ? 'Đang chuẩn bị tải model offline…'
              : 'Đang tải model offline… ${(progress * 100).round()}%',
          action: TextButton(
            onPressed: () => _cancelToken?.cancel(),
            child: const Text('Huỷ'),
          ),
        ),
      ModelDownloadFailed() => _StatusLine(
          icon: Icons.error_outline,
          iconColor: scheme.error,
          text: 'Tải model offline thất bại',
          action: TextButton(onPressed: _startDownload, child: const Text('Thử lại')),
        ),
      ModelReady() => _StatusLine(
          icon: Icons.check_circle_outline,
          iconColor: scheme.tertiary,
          text: 'Đã có model offline cho ${widget.direction.label}',
          action: null,
        ),
    };
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
