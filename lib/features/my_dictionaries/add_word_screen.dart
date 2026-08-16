import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/vocab_providers.dart';
import '../../domain/entities/word.dart';
import '../review/review_providers.dart';

/// Nhãn đầy đủ cho dropdown "Loại từ" — mã số khớp `part_of_speech` (xem
/// `docs/db/schema.sql` và `VocabRepository._posLabels`).
const _partOfSpeechOptions = {
  0: 'Danh từ (dt)',
  1: 'Động từ (đt)',
  2: 'Tính từ (tt)',
  3: 'Trạng từ (trt)',
  4: 'Giới từ (gt)',
};

/// Chiều ngược lại của `VocabRepository._posLabels` (viết tắt hiển thị
/// trên [VocabWord.partOfSpeech] -> mã số) — dùng để chọn sẵn mục đúng
/// trong dropdown khi mở form ở chế độ sửa.
const _posCodeByAbbreviation = {'dt': 0, 'đt': 1, 'tt': 2, 'trt': 3, 'gt': 4};

/// SCR-07b — Tự thêm/sửa từ: nhập tay 1 từ không có trong giáo trình,
/// kèm ảnh minh hoạ tuỳ chọn. Bộ từ điển đích không hỏi lại — màn này
/// luôn mở từ card của đúng bộ đó (SCR-07), nên [dictionaryId] cố định.
/// Chỉ 2 trường bắt buộc (từ + nghĩa); phiên âm/loại từ/ảnh tuỳ chọn vì
/// người dùng không phải chuyên gia ngôn ngữ. Xem
/// docs/artifact-design/screens/screen-07b-tu-them-tu-moi.html.
///
/// Truyền [existingWord] để chuyển sang chế độ sửa (SCR-07c, mở từ
/// [DictionaryDetailScreen]) — form dùng lại nguyên vẹn, chỉ đổi tiêu
/// đề/nút và gọi [editWord] thay vì [addManualWord] lúc lưu.
class AddWordScreen extends ConsumerStatefulWidget {
  const AddWordScreen({
    super.key,
    required this.dictionaryId,
    required this.dictionaryName,
    this.existingWord,
  });

  final int dictionaryId;
  final String dictionaryName;
  final VocabWord? existingWord;

  bool get isEditing => existingWord != null;

  @override
  ConsumerState<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends ConsumerState<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _wordController = TextEditingController(text: widget.existingWord?.word);
  late final _meaningController = TextEditingController(text: widget.existingWord?.meaningVi);
  late final _phoneticController = TextEditingController(text: widget.existingWord?.phonetic);
  final _exampleEnController = TextEditingController();
  final _exampleViController = TextEditingController();
  int? _partOfSpeechCode;
  File? _pickedImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingWord;
    if (existing != null) {
      _partOfSpeechCode = _posCodeByAbbreviation[existing.partOfSpeech];
      final imagePath = existing.imagePath;
      if (imagePath != null && imagePath.isNotEmpty && p.isAbsolute(imagePath)) {
        _pickedImage = File(imagePath);
      }
      _loadExistingExample(existing.id);
    }
  }

  /// Nạp ví dụ đã lưu khi mở form ở chế độ sửa — [VocabWord] từ
  /// [chapterWordsProvider]/[DictionaryDetailScreen] không kèm sẵn
  /// `examples` (chỉ được gán ở luồng "Học từ mới"), nên đọc riêng qua
  /// [wordExamplesProvider]. Form chỉ hỗ trợ đúng 1 cặp ví dụ nên chỉ
  /// lấy dòng đầu tiên nếu có nhiều.
  Future<void> _loadExistingExample(int wordId) async {
    final examples = await ref.read(wordExamplesProvider(wordId).future);
    if (!mounted || examples.isEmpty) return;
    setState(() {
      _exampleEnController.text = examples.first.en;
      _exampleViController.text = examples.first.vi;
    });
  }

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    _phoneticController.dispose();
    _exampleEnController.dispose();
    _exampleViController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    const typeGroup = XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    setState(() => _pickedImage = File(file.path));
  }

  void _removeImage() => setState(() => _pickedImage = null);

  /// Copy ảnh đã chọn vào thư mục lưu trữ riêng của app (bền vững qua
  /// các lần chạy, không phụ thuộc đường dẫn gốc user có thể xoá/di
  /// chuyển) — trả về đường dẫn tuyệt đối để lưu vào `words.image_path`.
  /// Nếu ảnh đang chọn đã nằm sẵn trong thư mục này (ảnh cũ của
  /// [widget.existingWord] khi sửa, người dùng không đổi) thì giữ
  /// nguyên đường dẫn, khỏi copy trùng thêm 1 bản.
  Future<String?> _persistPickedImage() async {
    if (_pickedImage == null) return null;
    final wordsDir = Directory(p.join((await getApplicationSupportDirectory()).path, 'word_images'));
    if (p.equals(p.dirname(_pickedImage!.path), wordsDir.path)) return _pickedImage!.path;
    await wordsDir.create(recursive: true);
    final fileName = '${DateTime.now().microsecondsSinceEpoch}${p.extension(_pickedImage!.path)}';
    final savedFile = await _pickedImage!.copy(p.join(wordsDir.path, fileName));
    return savedFile.path;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final imagePath = await _persistPickedImage();
    final word = _wordController.text.trim();
    if (widget.isEditing) {
      await editWord(
        ref,
        wordId: widget.existingWord!.id,
        dictionaryId: widget.dictionaryId,
        word: word,
        meaningVi: _meaningController.text.trim(),
        phonetic: _phoneticController.text,
        partOfSpeechCode: _partOfSpeechCode,
        imagePath: imagePath,
        exampleEn: _exampleEnController.text,
        exampleVi: _exampleViController.text,
      );
    } else {
      await addManualWord(
        ref,
        word: word,
        meaningVi: _meaningController.text.trim(),
        dictionaryId: widget.dictionaryId,
        phonetic: _phoneticController.text,
        partOfSpeechCode: _partOfSpeechCode,
        imagePath: imagePath,
        exampleEn: _exampleEnController.text,
        exampleVi: _exampleViController.text,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? 'Đã lưu thay đổi cho "$word".'
              : 'Đã thêm "$word" vào ${widget.dictionaryName}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Sửa từ' : 'Tự thêm từ mới')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.panel2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.collections_bookmark_outlined, size: 14, color: AppColors.brand),
                          const SizedBox(width: 6),
                          Text(
                            widget.dictionaryName,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.brand),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ImagePickerField(image: _pickedImage, onPick: _pickImage, onRemove: _removeImage),
                    const SizedBox(height: 24),
                    _SectionLabel('TỪ TIẾNG ANH', required: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _wordController,
                      style: Theme.of(context).textTheme.titleMedium,
                      decoration: const InputDecoration(hintText: 'Nhập từ hoặc cụm từ'),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Bắt buộc' : null,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel('PHIÊN ÂM'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _phoneticController,
                                style: TextStyle(fontFamily: AppFonts.mono, color: AppColors.brand),
                                decoration: const InputDecoration(hintText: '/tʃɒk/'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel('LOẠI TỪ'),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int?>(
                                initialValue: _partOfSpeechCode,
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Chưa xác định', overflow: TextOverflow.ellipsis),
                                  ),
                                  for (final entry in _partOfSpeechOptions.entries)
                                    DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                                    ),
                                ],
                                onChanged: (value) => setState(() => _partOfSpeechCode = value),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel('NGHĨA TIẾNG VIỆT', required: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _meaningController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: 'Nhập nghĩa của từ'),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Bắt buộc' : null,
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel('VÍ DỤ THỰC TẾ'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _exampleEnController,
                      decoration: const InputDecoration(hintText: 'Câu ví dụ (tiếng Anh)'),
                      validator: (value) =>
                          (value != null &&
                                  value.trim().isNotEmpty &&
                                  _exampleViController.text.trim().isEmpty)
                              ? 'Cần điền cả bản dịch bên dưới'
                              : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _exampleViController,
                      decoration: const InputDecoration(hintText: 'Dịch nghĩa câu ví dụ'),
                      validator: (value) =>
                          (value != null &&
                                  value.trim().isNotEmpty &&
                                  _exampleEnController.text.trim().isEmpty)
                              ? 'Cần điền cả câu tiếng Anh bên trên'
                              : null,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                              )
                            : const Icon(Icons.check),
                        label: Text(widget.isEditing ? 'Lưu thay đổi' : 'Lưu từ mới'),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: scheme.outline),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Từ tự thêm chỉ hiển thị trong bộ từ điển cá nhân — không xuất hiện khi Tra cứu trong giáo trình gốc.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.required = false});
  final String text;

  /// `true` cho ô bắt buộc — hiện thêm dấu `*` màu đỏ để phân biệt với
  /// ô tuỳ chọn ngay từ khi mở form, không phải chờ bấm Lưu mới biết.
  final bool required;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.inkSoft);
    if (!required) return Text(text, style: style);
    return Text.rich(
      TextSpan(
        text: text,
        style: style,
        children: const [TextSpan(text: ' *', style: TextStyle(color: AppColors.signalRed))],
      ),
    );
  }
}

/// Ô chọn/preview ảnh minh hoạ — bấm để mở hộp thoại chọn file
/// ([file_selector], hỗ trợ Windows desktop); có ảnh thì hiện preview +
/// nút đổi/xoá, chưa có thì hiện khung placeholder mời chọn.
class _ImagePickerField extends StatelessWidget {
  const _ImagePickerField({required this.image, required this.onPick, required this.onRemove});

  final File? image;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (image == null) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 30, color: scheme.outline),
              const SizedBox(height: 8),
              Text(
                'Thêm ảnh minh hoạ (tuỳ chọn)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Image.file(image!, height: 140, width: double.infinity, fit: BoxFit.cover),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                _ImageActionButton(icon: Icons.edit_outlined, tooltip: 'Đổi ảnh', onTap: onPick),
                const SizedBox(width: 6),
                _ImageActionButton(icon: Icons.close, tooltip: 'Xoá ảnh', onTap: onRemove),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Tooltip(message: tooltip, child: Icon(icon, size: 16, color: AppColors.white)),
        ),
      ),
    );
  }
}
