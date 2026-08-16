import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/vocab_providers.dart';
import '../../domain/entities/word.dart';
import '../review/review_providers.dart';
import '../vocab/word_widgets.dart';
import 'add_word_screen.dart';

/// SCR-07c — Chi tiết bộ từ điển: toàn bộ từ thuộc [dictionaryId], mở
/// từ nút "Xem" trên card (SCR-07). Tái dùng [chapterWordsProvider] —
/// `word_dictionaries.dictionary_id` là cùng cột dùng cho cả bộ giáo
/// trình lẫn bộ cá nhân, nên logic lấy từ theo bộ giống hệt lấy từ
/// theo chương.
///
/// Bố cục theo đúng quy ước ở `search_screen.dart`: Windows/desktop
/// (`width >= AppConstants.desktopBreakpoint`) dùng layout 2 cột — danh
/// sách bên trái, chi tiết từ inline bên phải; mobile giữ bottom sheet
/// ([WordDetailSheet]) vì màn hẹp không đủ chỗ cho pane thứ 2.
///
/// Sửa/xoá quyết định theo TỪNG TỪ ([VocabWord.isEditable], tính từ
/// `source`) — không phải theo bộ đang xem: từ giáo trình gốc
/// (`source=0` SEED) luôn khoá dù nằm trong bộ nào (kể cả bộ user tự
/// tạo, nếu lỡ có mặt); từ tự thêm (`source=2`) hoặc lưu qua Tra Online
/// (`source=1`) luôn sửa/xoá được, kể cả khi đã thêm vào 1 bộ mặc định
/// — bộ mặc định chỉ khoá XOÁ CẢ BỘ, không khoá riêng từ user tự thêm
/// vào đó.
class DictionaryDetailScreen extends ConsumerStatefulWidget {
  const DictionaryDetailScreen({
    super.key,
    required this.dictionaryId,
    required this.dictionaryName,
  });

  final int dictionaryId;
  final String dictionaryName;

  @override
  ConsumerState<DictionaryDetailScreen> createState() =>
      _DictionaryDetailScreenState();
}

class _DictionaryDetailScreenState
    extends ConsumerState<DictionaryDetailScreen> {
  VocabWord? _selected;

  Future<void> _addWord() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddWordScreen(
          dictionaryId: widget.dictionaryId,
          dictionaryName: widget.dictionaryName,
        ),
      ),
    );
  }

  Future<void> _editWord(VocabWord word) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddWordScreen(
          dictionaryId: widget.dictionaryId,
          dictionaryName: widget.dictionaryName,
          existingWord: word,
        ),
      ),
    );
    // Bộ đã sửa xong -> danh sách nạp lại từ mới; bỏ chọn để tránh giữ
    // dữ liệu cũ trên pane phải (desktop) sau khi provider invalidate.
    if (mounted) setState(() => _selected = null);
  }

  Future<void> _deleteWord(VocabWord word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá từ này?'),
        content: Text(
          '"${word.word}" sẽ bị xoá khỏi ${widget.dictionaryName}. Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.signalRed),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await deleteWord(ref, wordId: word.id, dictionaryId: widget.dictionaryId);
    if (!mounted) return;
    if (_selected?.id == word.id) setState(() => _selected = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã xoá "${word.word}".')));
  }

  @override
  Widget build(BuildContext context) {
    final words = ref.watch(chapterWordsProvider(widget.dictionaryId));
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dictionaryName),
        actions: [
          IconButton(
            onPressed: _addWord,
            icon: const Icon(Icons.add),
            tooltip: 'Thêm từ mới',
          ),
        ],
      ),
      body: words.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) {
          if (list.isEmpty) {
            return _EmptyState(onAddWord: _addWord);
          }
          return isDesktop ? _buildTwoPane(list) : _buildSingleColumn(list);
        },
      ),
    );
  }

  /// Mobile: danh sách đầy màn hình, bấm 1 dòng mở [WordDetailSheet]
  /// bottom sheet (hành vi mặc định của [WordTile.onTap]).
  Widget _buildSingleColumn(List<VocabWord> list) {
    return Column(
      children: [
        _CountHeader(count: list.length),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => _buildTile(list[i]),
          ),
        ),
      ],
    );
  }

  /// Windows: bố cục 2 cột như `search_screen.dart._buildTwoPane` — cột
  /// trái là danh sách trong 1 card trắng, cột phải hiển thị chi tiết
  /// từ đang chọn inline (không mở bottom sheet trên màn rộng).
  Widget _buildTwoPane(List<VocabWord> list) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 356,
            child: _Card(
              child: Column(
                children: [
                  _CountHeader(count: list.length),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final word = list[i];
                        return _buildTile(
                          word,
                          selected: _selected?.id == word.id,
                          onTap: () => setState(() => _selected = word),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _Card(
              child: _selected == null
                  ? const _PaneDetailEmpty()
                  : _DesktopWordDetail(
                      key: ValueKey(_selected!.id),
                      word: _selected!,
                      onEdit: () => _editWord(_selected!),
                      onDelete: () => _deleteWord(_selected!),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    VocabWord word, {
    bool selected = false,
    VoidCallback? onTap,
  }) {
    if (!word.isEditable) {
      return WordTile(word: word, selected: selected, onTap: onTap);
    }
    return _ManagedWordTile(
      word: word,
      selected: selected,
      onTap: onTap,
      onEdit: () => _editWord(word),
      onDelete: () => _deleteWord(word),
    );
  }
}

/// Card trắng bo góc dùng chung cho cột trái/phải của layout 2 cột —
/// khớp `_Card` trong `search_screen.dart` (không export nên khai báo
/// lại, cùng style).
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Thanh nhỏ hiển thị tổng số từ ngay đầu danh sách — giúp bộ nhiều từ
/// dễ hình dung quy mô trước khi cuộn.
class _CountHeader extends StatelessWidget {
  const _CountHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.panel,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Text(
        '$count từ',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

/// Trạng thái chưa chọn từ nào ở pane chi tiết (desktop) — khớp
/// `_PaneDetailEmpty` trong `search_screen.dart`.
class _PaneDetailEmpty extends StatelessWidget {
  const _PaneDetailEmpty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 40,
              color: scheme.outline.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Chọn một từ để xem chi tiết',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: scheme.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bấm vào một dòng trong danh sách bên trái.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trạng thái rỗng — thân thiện hơn 1 dòng text đơn giản, kèm lối tắt
/// thêm từ ngay tại chỗ thay vì phải quay lại card rồi bấm nút "+".
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddWord});
  final VoidCallback onAddWord;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: scheme.outline.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Bộ từ điển này chưa có từ nào',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Thêm từ đầu tiên để bắt đầu học.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddWord,
              icon: const Icon(Icons.add),
              label: const Text('Thêm từ mới'),
            ),
          ],
        ),
      ),
    );
  }
}

/// [WordTile] kèm menu sửa/xoá — chỉ dùng cho từ tự thêm
/// ([VocabWord.isManual]). Bọc [WordTile] thay vì sửa trực tiếp để
/// không ảnh hưởng các nơi khác đang dùng [WordTile] cho từ giáo
/// trình (Tra cứu, danh sách theo chương...).
class _ManagedWordTile extends StatelessWidget {
  const _ManagedWordTile({
    required this.word,
    required this.onEdit,
    required this.onDelete,
    this.selected = false,
    this.onTap,
  });

  final VocabWord word;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return WordTile(
      word: word,
      selected: selected,
      onTap: onTap,
      trailing: _WordActionsMenu(onEdit: onEdit, onDelete: onDelete),
    );
  }
}

/// Menu "⋮" dùng cho các dòng trong danh sách (mobile/cột trái
/// desktop, xem [_ManagedWordTile]) — chỉ 2 lựa chọn Sửa/Xoá. Pane chi
/// tiết desktop ([_DesktopWordDetail]) đủ rộng nên hiện thẳng 2 nút,
/// không dùng widget này.
///
/// Tự dựng bằng [showMenu] + toạ độ [RenderBox] thật của nút (cùng
/// pattern `_SearchDirectionDropdown` ở `search_screen.dart`) thay vì
/// [PopupMenuButton] mặc định — neo menu chính xác ngay dưới nút, cùng
/// style item (khoảng cách gọn, font theo theme) thay vì [ListTile] mặc
/// định cỡ lớn.
class _WordActionsMenu extends StatefulWidget {
  const _WordActionsMenu({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_WordActionsMenu> createState() => _WordActionsMenuState();
}

class _WordActionsMenuState extends State<_WordActionsMenu> {
  final _buttonKey = GlobalKey();

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

    final selected = await showMenu<_WordAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonTopLeft.dx,
        buttonTopLeft.dy + buttonSize.height + 4,
        overlayBox.size.width - buttonTopLeft.dx - buttonSize.width,
        0,
      ),
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 200),
      items: [
        PopupMenuItem(
          value: _WordAction.edit,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 16, color: AppColors.ink),
              const SizedBox(width: 8),
              Text('Sửa', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        PopupMenuItem(
          value: _WordAction.delete,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline,
                size: 16,
                color: AppColors.signalRed,
              ),
              const SizedBox(width: 8),
              Text(
                'Xoá',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.signalRed),
              ),
            ],
          ),
        ),
      ],
    );

    switch (selected) {
      case _WordAction.edit:
        widget.onEdit();
      case _WordAction.delete:
        widget.onDelete();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _buttonKey,
      width: 32,
      height: 32,
      child: IconButton(
        onPressed: _openMenu,
        padding: EdgeInsets.zero,
        tooltip: 'Tuỳ chọn',
        icon: Icon(
          Icons.more_vert,
          size: 20,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

enum _WordAction { edit, delete }

/// Chi tiết từ inline cho pane phải (desktop) — tái dùng
/// [WordDetailContent] (giống mockup Windows) và chèn thêm 2 nút
/// sửa/xoá hiện sẵn (không ẩn sau menu "⋮" như ở danh sách, vì pane
/// chi tiết đủ rộng để hiện luôn) khi [VocabWord.isEditable] (theo
/// TỪNG TỪ, xem [DictionaryDetailScreen]); từ giáo trình gốc chỉ hiển
/// thị, không có 2 nút này.
class _DesktopWordDetail extends StatelessWidget {
  const _DesktopWordDetail({
    super.key,
    required this.word,
    required this.onEdit,
    required this.onDelete,
  });

  final VocabWord word;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return WordDetailContent(
      word: word,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      leadingAction: word.isEditable
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Sửa'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: AppColors.signalRed,
                  ),
                  label: const Text(
                    'Xoá',
                    style: TextStyle(color: AppColors.signalRed),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.signalRed),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
