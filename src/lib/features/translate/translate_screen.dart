import 'package:flutter/material.dart';

import '../../core/widgets/feature_placeholder.dart';

/// FR-4 — Dịch Anh↔Việt (offline, tra từ/cụm từ trong DB rồi ghép).
class TranslateScreen extends StatelessWidget {
  const TranslateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.translate,
      title: 'Dịch Anh ↔ Việt',
      frTag: 'FR-4',
      description:
          'Giao diện kiểu Google Translate, dịch offline bằng tra từ/cụm từ.\n'
          'Sẽ hoàn thiện ở Giai đoạn 3.',
    );
  }
}
