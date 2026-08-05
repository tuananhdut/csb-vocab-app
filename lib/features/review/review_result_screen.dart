import 'package:flutter/material.dart';

/// Màn kết quả cuối phiên ôn tập khách quan — chỉ tổng số câu đúng/sai
/// (đã chốt ở `docs/csb-vocab-analysis/tasks/02-review-multi-mode/
/// 03-plan.md`, không liệt kê lại từng từ sai).
class ReviewResultScreen extends StatelessWidget {
  const ReviewResultScreen({super.key, required this.correctCount, required this.totalCount});

  final int correctCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả ôn tập')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.task_alt, size: 72, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                'Đúng $correctCount/$totalCount',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Đã hoàn thành lượt ôn tập hôm nay!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.outline),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
