import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/vocab_providers.dart';
import '../../domain/entities/vocab.dart';
import '../vocab/word_widgets.dart';

/// FR-2 — Tra cứu từ vựng (offline, 2 chiều Anh↔Việt trong phạm vi giáo trình).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  VocabWord? _selected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      if (value.trim().isEmpty) _selected = null;
    });
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Nhập từ tiếng Anh hoặc tiếng Việt…',
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    _setQuery('');
                  },
                ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        ),
        onChanged: _setQuery,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchProvider(_query));
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;

    if (isDesktop) return _buildTwoPane(results);

    return Column(
      children: [
        _buildSearchField(),
        Expanded(
          child: _query.trim().isEmpty
              ? const _SearchEmptyCarousel()
              : results.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Lỗi: $e')),
                  data: (words) {
                    if (words.isEmpty) {
                      return Center(
                        child: Text('Không tìm thấy "$_query"',
                            style: Theme.of(context).textTheme.bodyLarge),
                      );
                    }
                    return _buildSingleColumn(words);
                  },
                ),
        ),
      ],
    );
  }

  /// Mobile: danh sách kết quả, bấm 1 dòng mở `WordDetailSheet` bottom sheet.
  Widget _buildSingleColumn(List<VocabWord> words) {
    return ListView.separated(
      itemCount: words.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => WordTile(word: words[i], showChapter: true),
    );
  }

  /// Windows: bố cục 2 cột — cột trái gồm ô tìm kiếm + danh sách kết quả
  /// (`pane-list`), cột phải hiển thị chi tiết từ đang chọn
  /// (`pane-detail`), khớp mockup
  /// `docs/artifact-design-windows/screens/screen-02-tra-cuu.html`.
  Widget _buildTwoPane(AsyncValue<List<VocabWord>> results) {
    return Row(
      children: [
        SizedBox(
          width: 340,
          child: Column(
            children: [
              _buildSearchField(),
              Expanded(
                child: _query.trim().isEmpty
                    ? const _SearchEmptyCarousel()
                    : results.when(
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Lỗi: $e')),
                        data: (words) {
                          if (words.isEmpty) {
                            return Center(
                              child: Text('Không tìm thấy "$_query"',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium),
                            );
                          }
                          return ListView.separated(
                            itemCount: words.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final word = words[i];
                              return WordTile(
                                word: word,
                                showChapter: true,
                                selected: _selected?.id == word.id,
                                onTap: () =>
                                    setState(() => _selected = word),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: ColoredBox(
            color: AppColors.pageBg,
            child: _selected == null
                ? const _PaneDetailEmpty()
                : WordDetailContent(
                    key: ValueKey(_selected!.id),
                    word: _selected!,
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Trạng thái chưa chọn từ nào ở pane chi tiết (desktop) — khớp
/// `.pane-detail-empty` trong mockup Windows.
class _PaneDetailEmpty extends StatelessWidget {
  const _PaneDetailEmpty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined,
              size: 36, color: scheme.outline.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          Text('Chọn 1 từ để xem chi tiết',
              style: TextStyle(color: scheme.outline, fontSize: 13.5)),
        ],
      ),
    );
  }
}

/// Trạng thái "chưa tìm kiếm" — slide ảnh Cảnh sát biển tự động lướt qua
/// lại, thay cho gợi ý chữ đơn giản trước đây (xem mockup `screen-02c-
/// tra-cuu-trong.html`, `docs/spec_history.md` [IMPL-009]).
class _SearchEmptyCarousel extends StatelessWidget {
  const _SearchEmptyCarousel();

  static const _images = [
    'assets/images/coast_guard/csb-slide-01.jpg',
    'assets/images/coast_guard/csb-slide-02.jpg',
    'assets/images/coast_guard/csb-slide-03.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Thích ứng theo chiều rộng thực tế của widget (không phải toàn màn
        // hình) — widget này có thể nằm trong cột hẹp (pane-list desktop)
        // hoặc full-width (mobile/pane rỗng).
        final isWide = constraints.maxWidth >= 500;
        final horizontalPadding = isWide ? 48.0 : 16.0;
        final carouselHeight = isWide ? 320.0 : 220.0;

        return SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Tra cứu từ vựng chuyên ngành',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Gõ từ tiếng Anh hoặc tiếng Việt để tìm',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.outline),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CarouselSlider(
                    options: CarouselOptions(
                      height: carouselHeight,
                      viewportFraction: 1,
                      autoPlay: true,
                      autoPlayInterval: const Duration(seconds: 4),
                      autoPlayAnimationDuration:
                          const Duration(milliseconds: 600),
                    ),
                    items: _images
                        .map(
                          (path) => Image.asset(
                            path,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(Icons.image_not_supported_outlined,
                                  color: scheme.outline),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
