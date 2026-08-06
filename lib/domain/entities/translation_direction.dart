// Chiều dịch cho FR-4 (SCR-04) — máy dịch neural on-device (opus-mt,
// xem docs/spec_history.md [IMPL-017] và tools/onnx-model-conversion/).

/// Một chiều dịch (En->Vi hoặc Vi->En) — mỗi chiều có model ONNX riêng,
/// tải độc lập (xem [IMPL-017] điểm chốt "tải riêng từng chiều").
enum TranslationDirection {
  enToVi(
    label: 'Anh → Việt',
    modelName: 'en-vi-v1',
    sourceLangLabel: 'Tiếng Anh',
    targetLangLabel: 'Tiếng Việt',
  ),
  viToEn(
    label: 'Việt → Anh',
    modelName: 'vi-en-v1',
    sourceLangLabel: 'Tiếng Việt',
    targetLangLabel: 'Tiếng Anh',
  );

  const TranslationDirection({
    required this.label,
    required this.modelName,
    required this.sourceLangLabel,
    required this.targetLangLabel,
  });

  final String label;

  /// Trùng tên file zip/manifest trên GitHub Release (vd `en-vi-v1.zip`).
  final String modelName;
  final String sourceLangLabel;
  final String targetLangLabel;

  TranslationDirection get reversed =>
      this == TranslationDirection.enToVi ? TranslationDirection.viToEn : TranslationDirection.enToVi;
}
