import 'package:flutter/material.dart';

import '../../core/widgets/feature_placeholder.dart';

/// FR-3 — Học theo chương / bài học.
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.menu_book,
      title: 'Học theo chương',
      frTag: 'FR-3',
      description:
          'Danh sách chương → chọn chương → danh sách từ của chương.\n'
          'Cần file PDF thứ 2 định nghĩa chương (Giai đoạn 2).',
    );
  }
}
