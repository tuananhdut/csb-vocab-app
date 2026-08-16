import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/vocab_providers.dart';
import '../../domain/entities/dictionary.dart';
import '../review/review_providers.dart';

/// Modal "Thêm vào bộ từ điển" (SCR-02 "Chế độ Online", mockup
/// `screen-04b-them-vao-bo-tu-dien.html`) — mở khi bấm "Thêm vào bộ"
/// trên 1 kết quả tra Online ([VocabWord.isOnline]) ở màn Search. Chọn
/// 1 hoặc nhiều bộ (checkbox) đã có, hoặc tạo bộ mới ngay tại chỗ, rồi
/// lưu từ vào tất cả bộ đã chọn qua [addOnlineWord].
///
/// Liệt kê mọi bộ (kể cả giáo trình gốc `is_default=1`) — bộ mặc định
/// không xoá/sửa được nhưng vẫn nhận từ mới bình thường, chỉ loại
/// riêng "Chưa phân loại" (id cố định = 1, nơi chứa từ mồ côi tự động,
/// không phải lựa chọn user chủ động).
Future<void> showAddToDictionarySheet(
  BuildContext context, {
  required String word,
  required String meaningVi,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AddToDictionarySheet(word: word, meaningVi: meaningVi),
  );
}

class AddToDictionarySheet extends ConsumerStatefulWidget {
  const AddToDictionarySheet({
    super.key,
    required this.word,
    required this.meaningVi,
  });

  final String word;
  final String meaningVi;

  @override
  ConsumerState<AddToDictionarySheet> createState() =>
      _AddToDictionarySheetState();
}

class _AddToDictionarySheetState extends ConsumerState<AddToDictionarySheet> {
  final _selectedIds = <int>{};

  /// Bộ đã chứa từ này TỪ TRƯỚC (nạp ở [_loadExistingSelection]) — tích
  /// sẵn VÀ khoá checkbox (không cho bỏ tích), vì modal này chỉ dùng để
  /// *thêm* vào bộ, không phải để gỡ từ khỏi bộ (việc đó làm ở
  /// `DictionaryDetailScreen`, chỉ áp dụng cho từ tự thêm).
  Set<int> _alreadyInIds = const {};
  bool _saving = false;
  bool _loadedExisting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingSelection();
  }

  /// Tích sẵn + khoá checkbox các bộ đã chứa từ này — user mở lại modal
  /// cho cùng 1 kết quả tra (đã từng bấm "Thêm" trước đó) sẽ thấy đúng
  /// trạng thái hiện tại, không phải luôn bắt đầu trắng trơn.
  Future<void> _loadExistingSelection() async {
    final ids = await ref.read(
      onlineWordDictionaryIdsProvider(widget.word).future,
    );
    if (!mounted) return;
    setState(() {
      _alreadyInIds = ids.toSet();
      _selectedIds.addAll(ids);
      _loadedExisting = true;
    });
  }

  Future<void> _createDictionary() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tạo bộ từ điển mới'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên bộ từ điển'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty) return;
    if (!mounted) return;
    await createDictionary(ref, trimmedName);
    // Bộ vừa tạo chưa có id để tự tick sẵn (createDictionary không trả
    // về) — user tick lại thủ công trong danh sách vừa làm mới, chấp
    // nhận được vì đây là thao tác hiếm (không phải mỗi lần thêm từ).
  }

  Future<void> _save() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn ít nhất 1 bộ từ điển.')),
      );
      return;
    }
    setState(() => _saving = true);
    await addOnlineWord(
      ref,
      word: widget.word,
      meaningVi: widget.meaningVi,
      dictionaryIds: _selectedIds.toList(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã thêm "${widget.word}" vào ${_selectedIds.length} bộ.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dictionaries = ref.watch(myDictionariesProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thêm vào bộ từ điển',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.word} — ${widget.meaningVi}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.4,
              ),
              // Chờ nạp xong trạng thái checkbox đã chọn trước đó
              // ([_loadExistingSelection]) rồi mới hiện danh sách — tránh
              // hiệu ứng checkbox trắng rồi đột ngột tự tích lại.
              child: !_loadedExisting
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : dictionaries.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Lỗi: $e'),
                      ),
                      data: (list) {
                        // Cho chọn cả bộ giáo trình gốc (is_default=1) — bộ mặc
                        // định không xoá/sửa được nhưng vẫn nhận từ mới bình
                        // thường (đã chốt ở tính năng "Tự thêm từ mới"). Chỉ
                        // loại riêng "Chưa phân loại" (id cố định = 1) vì đó là
                        // nơi chứa từ mồ côi tự động, không phải lựa chọn user
                        // chủ động chọn (cùng quy tắc `VocabRepository.chapters()`).
                        final options = list.where((d) => d.id != 1).toList();
                        if (options.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'Chưa có bộ từ điển nào — tạo bộ mới bên dưới.',
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (_, i) {
                            final alreadyIn = _alreadyInIds.contains(
                              options[i].id,
                            );
                            return _DictionaryCheckboxTile(
                              dictionary: options[i],
                              checked: _selectedIds.contains(options[i].id),
                              enabled: !alreadyIn,
                              onChanged: (checked) => setState(() {
                                if (checked) {
                                  _selectedIds.add(options[i].id);
                                } else {
                                  _selectedIds.remove(options[i].id);
                                }
                              }),
                            );
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _createDictionary,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Tạo bộ mới'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Thêm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DictionaryCheckboxTile extends StatelessWidget {
  const _DictionaryCheckboxTile({
    required this.dictionary,
    required this.checked,
    required this.onChanged,
    this.enabled = true,
  });

  final Dictionary dictionary;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: checked,
      // `enabled: false` vẫn cần onChanged non-null để CheckboxListTile
      // không tự đổi màu disabled-nhưng-vẫn-bấm-được — Flutter chỉ thực
      // sự khoá tương tác khi onChanged là null.
      onChanged: enabled ? (value) => onChanged(value ?? false) : null,
      enabled: enabled,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(dictionary.name),
      subtitle: Text(
        enabled
            ? '${dictionary.wordCount} từ'
            : '${dictionary.wordCount} từ · đã có từ này',
      ),
    );
  }
}
