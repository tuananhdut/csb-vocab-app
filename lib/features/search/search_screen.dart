import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/repositories/vocab_providers.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchProvider(_query));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Nhập từ tiếng Anh hoặc tiếng Việt…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
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
                    return ListView.separated(
                      itemCount: words.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) =>
                          WordTile(word: words[i], showChapter: true),
                    );
                  },
                ),
        ),
      ],
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
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Tra cứu từ vựng chuyên ngành',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: scheme.primary),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Gõ từ tiếng Anh hoặc tiếng Việt để tìm',
            style: TextStyle(color: scheme.outline),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CarouselSlider(
              options: CarouselOptions(
                height: isDesktop ? 320 : 220,
                viewportFraction: 1,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 4),
                autoPlayAnimationDuration: const Duration(milliseconds: 600),
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
      ],
    );
  }
}
