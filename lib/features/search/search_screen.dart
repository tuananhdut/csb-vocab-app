import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              ? const _Hint()
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

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.travel_explore, size: 64, color: scheme.primary),
          const SizedBox(height: 12),
          const Text('Tra cứu từ vựng chuyên ngành'),
          const SizedBox(height: 4),
          Text('Gõ từ tiếng Anh hoặc tiếng Việt để tìm',
              style: TextStyle(color: scheme.outline)),
        ],
      ),
    );
  }
}
