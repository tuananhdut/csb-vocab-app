import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:csb_vocab_app/data/services/dictionary_api_service.dart';
import 'package:csb_vocab_app/domain/entities/word.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// MyMemory answers immediately; the dictionary API never answers until
/// cancelled, like the real one does when it is down.
class _FakeAdapter implements HttpClientAdapter {
  int myMemoryCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.host.contains('mymemory')) {
      myMemoryCalls++;
      return ResponseBody.fromString(
        jsonEncode({
          'responseStatus': 200,
          'responseData': {'translatedText': 'thủy thủ'},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    await cancelFuture;
    throw DioException.requestCancelled(requestOptions: options, reason: 'x');
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('shows the translation without waiting for a hanging phonetics API', () async {
    final adapter = _FakeAdapter();
    final service = DictionaryApiService(
      dio: Dio()..httpClientAdapter = adapter,
      detailsTimeout: const Duration(milliseconds: 200),
    );

    final partials = <OnlineLookupResult>[];
    final stopwatch = Stopwatch()..start();
    final result = await service.lookup(
      'sailor',
      direction: SearchDirection.enToVi,
      onTranslated: partials.add,
    );

    expect(partials, hasLength(1));
    expect(partials.single.meaningVi, 'thủy thủ');
    expect(partials.single.phonetic, isEmpty);
    expect(result?.meaningVi, 'thủy thủ');
    expect(result?.phonetic, isEmpty);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('caches the translation for repeated queries', () async {
    final adapter = _FakeAdapter();
    final service = DictionaryApiService(
      dio: Dio()..httpClientAdapter = adapter,
      detailsTimeout: const Duration(milliseconds: 50),
    );

    await service.lookup('sailor', direction: SearchDirection.enToVi);
    await service.lookup('Sailor', direction: SearchDirection.enToVi);

    expect(adapter.myMemoryCalls, 1);
  });

  test('a cancelled lookup resolves to null without throwing', () async {
    final service = DictionaryApiService(
      dio: Dio()..httpClientAdapter = _FakeAdapter(),
      detailsTimeout: const Duration(milliseconds: 50),
    );
    final token = CancelToken()..cancel();

    final result = await service.lookup(
      'sailor',
      direction: SearchDirection.enToVi,
      cancelToken: token,
    );

    expect(result, isNull);
  });
}
