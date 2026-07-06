// Smoke test: app khởi động vào splash screen mà không lỗi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:csb_vocab_app/app.dart';

void main() {
  testWidgets('App khởi động và hiển thị splash', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CsbVocabApp()));
    await tester.pump();

    // Splash hiển thị tiêu đề chủ đề Cảnh sát biển.
    expect(find.text('Cảnh Sát Biển\nViệt Nam'), findsOneWidget);
    expect(find.byIcon(Icons.anchor), findsWidgets);
  });
}
