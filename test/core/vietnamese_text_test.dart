import 'package:csb_vocab_app/core/utils/vietnamese_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds the other tone placement for uy/oa/oe', () {
    expect(toneStyleVariants('thuỷ thủ có bằng'), contains('thủy thủ có bằng'));
    expect(toneStyleVariants('thủy thủ'), contains('thuỷ thủ'));
    expect(toneStyleVariants('hoà bình'), contains('hòa bình'));
  });

  test('keeps the original first and does not duplicate', () {
    expect(toneStyleVariants('tàu'), ['tàu']);
    expect(toneStyleVariants('thuỷ').first, 'thuỷ');
  });
}
