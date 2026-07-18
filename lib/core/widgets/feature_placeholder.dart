import 'package:flutter/material.dart';

/// Khung tạm cho các màn hình chức năng chưa hoàn thiện (Giai đoạn 0).
/// Mỗi màn sẽ được thay bằng nội dung thật ở các giai đoạn sau.
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.frTag,
  });

  final IconData icon;
  final String title;
  final String description;

  /// Mã yêu cầu chức năng (vd "FR-2") để dễ đối chiếu với plan.
  final String? frTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (frTag != null) ...[
              const SizedBox(height: 4),
              Chip(
                label: Text(frTag!),
                visualDensity: VisualDensity.compact,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
