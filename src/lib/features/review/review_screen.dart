import 'package:flutter/material.dart';

import '../../core/widgets/feature_placeholder.dart';

/// FR-5 — Ôn tập từ vựng (SM-2) + thông báo nhắc học.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.repeat,
      title: 'Ôn tập',
      frTag: 'FR-5',
      description:
          'Đánh dấu đã học, hàng đợi "ôn hôm nay" theo thuật toán SM-2.\n'
          'Sẽ hoàn thiện ở Giai đoạn 2.',
    );
  }
}
