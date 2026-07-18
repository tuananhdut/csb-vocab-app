import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/review.dart';
import 'review_providers.dart';

/// Phiên ôn tập kiểu flashcard: hiện từ → lật xem nghĩa → đánh giá
/// Quên/Khó/Tốt/Dễ → chuyển sang từ tiếp theo (FR-5.2).
class ReviewSessionScreen extends ConsumerStatefulWidget {
  const ReviewSessionScreen({super.key, required this.items});
  final List<DueReviewItem> items;

  @override
  ConsumerState<ReviewSessionScreen> createState() =>
      _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends ConsumerState<ReviewSessionScreen> {
  int _index = 0;
  bool _revealed = false;

  Future<void> _rate(ReviewRating rating) async {
    final word = widget.items[_index].word;
    await submitWordReview(ref, word.id, rating);
    if (!mounted) return;

    if (_index + 1 >= widget.items.length) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã hoàn thành lượt ôn tập hôm nay!')),
      );
      return;
    }
    setState(() {
      _index += 1;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final word = widget.items[_index].word;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ôn tập (${_index + 1}/${widget.items.length})'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_index) / widget.items.length,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _revealed = true),
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(word.word,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          if (word.phonetic.isNotEmpty)
                            Text(word.phonetic,
                                style: TextStyle(
                                    color: scheme.primary, fontSize: 16)),
                          const SizedBox(height: 20),
                          if (!_revealed)
                            Text('Chạm để xem nghĩa',
                                style: TextStyle(color: scheme.outline))
                          else ...[
                            if (word.partOfSpeech.isNotEmpty)
                              Chip(
                                label: Text(word.partOfSpeech),
                                visualDensity: VisualDensity.compact,
                              ),
                            const SizedBox(height: 8),
                            Text(word.meaningVi,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_revealed)
              Row(
                children: [
                  for (final rating in ReviewRating.values) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rate(rating),
                        child: Text(rating.label),
                      ),
                    ),
                    if (rating != ReviewRating.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              )
            else
              FilledButton(
                onPressed: () => setState(() => _revealed = true),
                child: const Text('Hiện nghĩa'),
              ),
          ],
        ),
      ),
    );
  }
}
