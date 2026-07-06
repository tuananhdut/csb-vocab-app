import 'package:flutter/material.dart';

import '../../core/widgets/feature_placeholder.dart';

/// FR-2 — Tra cứu từ vựng (offline, phạm vi từ trong PDF).
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.search,
      title: 'Tra cứu từ vựng',
      frTag: 'FR-2',
      description:
          'Ô tìm kiếm + kết quả: từ, nghĩa, phiên âm, loại từ, ví dụ, ảnh.\n'
          'Sẽ hoàn thiện ở Giai đoạn 1 sau khi có vocab.db từ PDF.',
    );
  }
}
