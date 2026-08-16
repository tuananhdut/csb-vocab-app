import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/vocab_providers.dart';
import '../../data/services/connectivity_service.dart';
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
  late final _wordController = TextEditingController(
    text: widget.existingWord?.word,
  );
  late final _meaningController = TextEditingController(
    text: widget.existingWord?.meaningVi,
  );
  late final _phoneticController = TextEditingController(
    text: widget.existingWord?.phonetic,
  );
  final _exampleEnController = TextEditingController();
  final _exampleViController = TextEditingController();
  int? _partOfSpeechCode;
  File? _pickedImage;
  bool _saving = false;
  bool _autofilling = false;

  /// `id` từ tự điền vừa khớp trúng 1 bản ghi ĐÃ CÓ SẴN trong local —
  /// khi khác `null` lúc bấm Lưu, [_save] liên kết thẳng bản ghi đó vào
  /// [AddWordScreen.dictionaryId] thay vì tạo từ MANUAL mới trùng lặp
  /// (xem [linkExistingWord]). Reset về `null` ngay khi user tự sửa
  /// tay "Từ tiếng Anh"/"Nghĩa tiếng Việt" — lúc đó nội dung không còn
  /// chắc khớp với bản ghi gốc nữa.
  int? _linkedWordId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingWord;
    if (existing != null) {
      _partOfSpeechCode = _posCodeByAbbreviation[existing.partOfSpeech];
      final imagePath = existing.imagePath;
      if (imagePath != null &&
          imagePath.isNotEmpty &&
          p.isAbsolute(imagePath)) {
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

  /// Tự điền Nghĩa tiếng Việt/Từ tiếng Anh/Phiên âm/Loại từ còn trống từ
  /// dữ liệu đã có — ưu tiên ô "Từ tiếng Anh" nếu có chữ (tra hướng
  /// enToVi), ngược lại dùng "Nghĩa tiếng Việt" (tra hướng viToEn).
  /// Tra local (`vocab.db`, khớp CHÍNH XÁC — xem
  /// [VocabRepository.findExactMatch]) trước; nếu không có và đang có
  /// mạng, tra thêm Online (cùng cơ chế `DictionaryApiService` đã dùng
  /// ở màn Tra cứu). Không tự động chạy khi gõ — chỉ chạy khi user chủ
  /// động bấm nút, tránh tốn quota API/DB mỗi ký tự gõ vào.
  Future<void> _autofill() async {
    final word = _wordController.text.trim();
    final meaning = _meaningController.text.trim();
    if (word.isEmpty && meaning.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhập từ tiếng Anh hoặc nghĩa tiếng Việt trước.'),
        ),
      );
      return;
    }

    final direction = word.isNotEmpty
        ? SearchDirection.enToVi
        : SearchDirection.viToEn;
    final query = word.isNotEmpty ? word : meaning;

    setState(() {
      _autofilling = true;
      _linkedWordId = null;
    });
    try {
      final vocabRepo = await ref.read(vocabRepositoryProvider.future);
      final localMatch = vocabRepo.findExactMatch(query, direction: direction);

      if (localMatch != null) {
        _applyAutofill(
          word: localMatch.word,
          meaningVi: localMatch.meaningVi,
          phonetic: localMatch.phonetic,
          partOfSpeechAbbreviation: localMatch.partOfSpeech,
        );
        // Chỉ ghi nhớ id để [_save] liên kết (thay vì tạo từ MANUAL mới)
        // nếu CẢ 5 trường (từ/nghĩa/phiên âm/loại từ/ví dụ) trong form
        // SAU KHI autofill khớp y hệt bản ghi gốc — nếu user đã tự gõ
        // trước 1 trong các ô đó khác với dữ liệu gốc, [_applyAutofill]
        // giữ nguyên giá trị đó (không ghi đè ô đã có chữ), nên form và
        // bản ghi gốc có thể lệch nhau dù vẫn "khớp" ở bước tìm kiếm
        // ban đầu. Ví dụ user gõ mà không lưu được khi link (form chỉ
        // hỗ trợ 1-1, `linkExistingWord` không đụng bảng `examples`)
        // là mất dữ liệu — an toàn hơn là bắt tạo mới trong trường hợp đó.
        final existingExamples = vocabRepo.examplesFor(localMatch.id);
        if (_formMatchesRecord(localMatch, existingExamples)) {
          setState(() => _linkedWordId = localMatch.id);
        }
        return;
      }

      final isOnline = ref.read(connectivityProvider).value ?? false;
      if (!isOnline) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy — cần có mạng để tra thêm Online.'),
          ),
        );
        return;
      }

      final apiService = ref.read(dictionaryApiServiceProvider);
      final onlineResult = await apiService.lookup(query, direction: direction);
      if (!mounted) return;
      if (onlineResult == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy dữ liệu cho từ này.')),
        );
        return;
      }
      _applyAutofill(
        word: onlineResult.word,
        meaningVi: onlineResult.meaningVi,
        phonetic: onlineResult.phonetic,
        partOfSpeechAbbreviation: onlineResult.partOfSpeech,
      );
    } finally {
      if (mounted) setState(() => _autofilling = false);
    }
  }

  /// Điền các ô còn lại — không ghi đè ô user đã tự gõ (`word`/`meaningVi`
  /// chỉ set nếu ô tương ứng đang trống, vì 1 trong 2 luôn đã có sẵn là
  /// nguồn tra ở trên); phiên âm/loại từ luôn điền nếu tra được, vì 2 ô
  /// này thường trống lúc gọi tự điền.
  void _applyAutofill({
    required String word,
    required String meaningVi,
    required String phonetic,
    required String partOfSpeechAbbreviation,
  }) {
    setState(() {
      if (_wordController.text.trim().isEmpty) _wordController.text = word;
      if (_meaningController.text.trim().isEmpty) {
        _meaningController.text = meaningVi;
      }
      if (phonetic.isNotEmpty) _phoneticController.text = phonetic;
      final code = _posCodeByAbbreviation[partOfSpeechAbbreviation];
      if (code != null) _partOfSpeechCode = code;
    });
  }

  /// So khớp CẢ 5 trường (từ, nghĩa, phiên âm, loại từ, ví dụ) đang hiển
  /// thị trong form với [record]/[existingExamples] — chỉ khi khớp y hệt
  /// mới an toàn để liên kết ([_linkedWordId]) thay vì tạo bản ghi mới;
  /// nếu user đã tự gõ trước 1 trong các ô đó khác với dữ liệu gốc (giữ
  /// nguyên vì [_applyAutofill] không ghi đè ô đang có chữ), form và
  /// bản ghi gốc lệch nhau — phải tạo mới, không được link. Ví dụ so
  /// khớp với ví dụ ĐẦU TIÊN của [record] vì form chỉ hỗ trợ 1 ví dụ dù
  /// DB cho phép nhiều (`examples.word_id` không UNIQUE) — `_save` chỉ
  /// link, không đụng bảng `examples`, nên ví dụ user gõ khác bản ghi
  /// gốc mà vẫn link sẽ mất, phải bắt tạo bản ghi MANUAL mới thay vào đó.
  bool _formMatchesRecord(VocabWord record, List<WordExample> existingExamples) {
    final wordMatches =
        _wordController.text.trim().toLowerCase() ==
        record.word.trim().toLowerCase();
    final meaningMatches =
        _meaningController.text.trim().toLowerCase() ==
        record.meaningVi.trim().toLowerCase();
    final phoneticMatches =
        _phoneticController.text.trim() == record.phonetic.trim();
    final posMatches =
        _partOfSpeechCode == _posCodeByAbbreviation[record.partOfSpeech];
    final existingExample = existingExamples.isEmpty
        ? null
        : existingExamples.first;
    final exampleEnMatches =
        _exampleEnController.text.trim() == (existingExample?.en.trim() ?? '');
    final exampleViMatches =
        _exampleViController.text.trim() == (existingExample?.vi.trim() ?? '');
    return wordMatches &&
        meaningMatches &&
        phoneticMatches &&
        posMatches &&
        exampleEnMatches &&
        exampleViMatches;
  }

  /// `onChanged` của ô "Từ tiếng Anh"/"Nghĩa tiếng Việt" cũng bị kích
  /// hoạt khi [_applyAutofill] set `.text` bằng code (không chỉ khi
  /// user gõ tay) — bỏ qua reset trong lúc đang tự điền
  /// ([_autofilling]), chỉ coi là "user tự sửa" (mất liên kết đã khớp)
  /// khi sửa SAU khi tự điền đã xong.
  void _clearLinkedWordIfUserEdited() {
    if (_autofilling || _linkedWordId == null) return;
    setState(() => _linkedWordId = null);
  }

  Future<void> _pickImage() async {
    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
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
    final wordsDir = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'word_images'),
    );
    if (p.equals(p.dirname(_pickedImage!.path), wordsDir.path)) {
      return _pickedImage!.path;
    }
    await wordsDir.create(recursive: true);
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}${p.extension(_pickedImage!.path)}';
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
    } else if (_linkedWordId != null) {
      // Tự điền vừa khớp trúng 1 bản ghi có sẵn (chưa bị user sửa tay
      // sau đó, xem [_clearLinkedWordIfUserEdited]) — liên kết thay vì
      // tạo bản ghi MANUAL mới trùng nội dung.
      await linkExistingWord(
        ref,
        wordId: _linkedWordId!,
        dictionaryId: widget.dictionaryId,
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
    final wasLinked = !widget.isEditing && _linkedWordId != null;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? 'Đã lưu thay đổi cho "$word".'
              : wasLinked
              ? 'Đã thêm "$word" (từ có sẵn) vào ${widget.dictionaryName}.'
              : 'Đã thêm "$word" vào ${widget.dictionaryName}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Sửa từ' : 'Tự thêm từ mới'),
      ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.panel2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.collections_bookmark_outlined,
                            size: 14,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.dictionaryName,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppColors.brand),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ImagePickerField(
                      image: _pickedImage,
                      onPick: _pickImage,
                      onRemove: _removeImage,
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel('TỪ TIẾNG ANH', required: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _wordController,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Nhập từ hoặc cụm từ',
                      ),
                      onChanged: (_) => _clearLinkedWordIfUserEdited(),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Bắt buộc'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _autofilling ? null : _autofill,
                        icon: _autofilling
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Tự điền từ dữ liệu'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel('NGHĨA TIẾNG VIỆT', required: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _meaningController,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Nhập nghĩa của từ',
                      ),
                      onChanged: (_) => _clearLinkedWordIfUserEdited(),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Bắt buộc'
                          : null,
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
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontFamily: AppFonts.mono,
                                      color: AppColors.brand,
                                    ),
                                decoration: const InputDecoration(
                                  hintText: '/tʃɒk/',
                                ),
                                onChanged: (_) =>
                                    _clearLinkedWordIfUserEdited(),
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
                              _PartOfSpeechDropdown(
                                value: _partOfSpeechCode,
                                onChanged: (value) => setState(() {
                                  _partOfSpeechCode = value;
                                  if (!_autofilling) _linkedWordId = null;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel('VÍ DỤ THỰC TẾ'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _exampleEnController,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Câu ví dụ (tiếng Anh)',
                      ),
                      onChanged: (_) => _clearLinkedWordIfUserEdited(),
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
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Dịch nghĩa câu ví dụ',
                      ),
                      onChanged: (_) => _clearLinkedWordIfUserEdited(),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          widget.isEditing ? 'Lưu thay đổi' : 'Lưu từ mới',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: scheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Từ tự thêm chỉ hiển thị trong bộ từ điển cá nhân — không xuất hiện khi Tra cứu trong giáo trình gốc.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.outline),
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

/// Dropdown chọn loại từ — tự dựng bằng [showMenu] + toạ độ [RenderBox]
/// thật của nút (cùng pattern `_SearchDirectionDropdown` ở
/// `search_screen.dart`) thay vì [DropdownButtonFormField] mặc định, để
/// neo menu chính xác ngay dưới nút, cùng style checkmark/khoảng cách
/// gọn.
class _PartOfSpeechDropdown extends StatefulWidget {
  const _PartOfSpeechDropdown({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_PartOfSpeechDropdown> createState() => _PartOfSpeechDropdownState();
}

class _PartOfSpeechDropdownState extends State<_PartOfSpeechDropdown> {
  final _buttonKey = GlobalKey();

  String get _currentLabel => widget.value == null
      ? 'Chưa xác định'
      : _partOfSpeechOptions[widget.value]!;

  Future<void> _openMenu() async {
    final buttonBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final buttonSize = buttonBox.size;

    final options = <int?, String>{
      null: 'Chưa xác định',
      ..._partOfSpeechOptions,
    };

    // showMenu trả `null` cả khi user đóng menu KHÔNG chọn gì lẫn khi
    // chọn mục "Chưa xác định" (value cũng là null) — bọc trong
    // _PosSelection để phân biệt "không chọn" (result == null) với
    // "đã chọn null" (result là _PosSelection(null)).
    final result = await showMenu<_PosSelection>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonTopLeft.dx,
        buttonTopLeft.dy + buttonSize.height + 4,
        overlayBox.size.width - buttonTopLeft.dx - buttonSize.width,
        0,
      ),
      constraints: BoxConstraints(
        minWidth: buttonSize.width,
        maxWidth: buttonSize.width * 1.6,
      ),
      items: [
        for (final entry in options.entries)
          PopupMenuItem<_PosSelection>(
            value: _PosSelection(entry.key),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  child: entry.key == widget.value
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: AppColors.brand,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.value,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: entry.key == widget.value
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: entry.key == widget.value
                          ? AppColors.brand
                          : AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (result != null) widget.onChanged(result.code);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: _buttonKey,
      borderRadius: BorderRadius.circular(8),
      onTap: _openMenu,
      child: InputDecorator(
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                _currentLabel,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Bọc `int? code` để phân biệt "user đóng menu không chọn gì" (giá trị
/// `showMenu` trả về là `null`) với "user chọn mục 'Chưa xác định'"
/// (giá trị hợp lệ, `code` bên trong là `null`) — xem
/// [_PartOfSpeechDropdownState._openMenu].
class _PosSelection {
  const _PosSelection(this.code);
  final int? code;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.required = false});
  final String text;

  /// `true` cho ô bắt buộc — hiện thêm dấu `*` màu đỏ để phân biệt với
  /// ô tuỳ chọn ngay từ khi mở form, không phải chờ bấm Lưu mới biết.
  final bool required;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: AppColors.inkSoft);
    if (!required) return Text(text, style: style);
    return Text.rich(
      TextSpan(
        text: text,
        style: style,
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: AppColors.signalRed),
          ),
        ],
      ),
    );
  }
}

/// Ô chọn/preview ảnh minh hoạ — bấm để mở hộp thoại chọn file
/// ([file_selector], hỗ trợ Windows desktop); có ảnh thì hiện preview +
/// nút đổi/xoá, chưa có thì hiện khung placeholder mời chọn.
class _ImagePickerField extends StatelessWidget {
  const _ImagePickerField({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

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
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 30,
                color: scheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                'Thêm ảnh minh hoạ (tuỳ chọn)',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: scheme.outline),
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
          Image.file(
            image!,
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                _ImageActionButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Đổi ảnh',
                  onTap: onPick,
                ),
                const SizedBox(width: 6),
                _ImageActionButton(
                  icon: Icons.close,
                  tooltip: 'Xoá ảnh',
                  onTap: onRemove,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

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
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, size: 16, color: AppColors.white),
          ),
        ),
      ),
    );
  }
}
