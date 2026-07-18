
# REST Networking — dio + JWT backend (ASP.NET Core style)

## Client setup

One configured `Dio` instance, injected everywhere (never `Dio()` per call):

```dart
Dio buildDio(TokenStore tokens) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,          // per-flavor, never hardcoded
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
  ));
  dio.interceptors.addAll([
    AuthInterceptor(tokens, dio),
    if (kDebugMode) LogInterceptor(responseBody: true), // never in release: logs tokens/PII
  ]);
  return dio;
}
```

## JWT auth with refresh (the flow everyone gets wrong)

Requirements: access token attached to every request; on `401`, refresh once and retry; concurrent 401s must share one refresh (not N parallel refreshes — rotation-enabled backends will revoke the family); refresh failure logs the user out.

```dart
class AuthInterceptor extends QueuedInterceptor { // Queued = serializes, solving the concurrency problem
  AuthInterceptor(this._tokens, this._dio);
  final TokenStore _tokens;
  final Dio _dio;

  @override
  void onRequest(options, handler) async {
    final access = await _tokens.accessToken;
    if (access != null) options.headers['Authorization'] = 'Bearer $access';
    handler.next(options);
  }

  @override
  void onError(err, handler) async {
    if (err.response?.statusCode == 401 && !err.requestOptions.path.contains('/auth/')) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retry = await _dio.fetch(err.requestOptions
          ..headers['Authorization'] = 'Bearer ${await _tokens.accessToken}');
        return handler.resolve(retry);
      }
      _tokens.clearAndLogout(); // navigate to login via auth state, not from here
    }
    handler.next(err);
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _tokens.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await Dio(BaseOptions(baseUrl: _dio.options.baseUrl)) // bare dio: no interceptor recursion
          .post('/api/v1/auth/refresh', data: {'refreshToken': refresh});
      await _tokens.save(res.data['accessToken'], res.data['refreshToken']);
      return true;
    } catch (_) { return false; }
  }
}
```

Token storage: `flutter_secure_storage` (Keychain/Keystore) — never SharedPreferences.

## Error mapping — one place, user-ready messages

Map transport + backend errors (ASP.NET ProblemDetails / ValidationProblemDetails) into a small sealed hierarchy so providers/UI never see `DioException`:

```dart
sealed class ApiException implements Exception { String get userMessage; }
class NetworkException extends ApiException { ... }     // timeouts, no connectivity → "Check your connection"
class ValidationException extends ApiException {         // 400 with errors map
  final Map<String, List<String>> fieldErrors;            // parse problemDetails['errors']
  ...
}
class UnauthorizedException extends ApiException { ... } // post-refresh-failure 401/403
class ConflictException extends ApiException { ... }     // 409 (concurrency, duplicates)
class ServerException extends ApiException { ... }       // 5xx → generic message + logged detail
```

Do the mapping in the repository/api-service layer (or an error interceptor). Show `ValidationException.fieldErrors` on the matching form fields — the backend already validated; reuse it.

## Models & JSON

- `json_serializable` (or freezed with it) over hand-written `fromJson` for anything nontrivial — hand-rolled parsers rot.
- Tolerate backend evolution: unknown JSON fields must be ignored (default behavior — don't enable strictness that crashes on new fields); enums with `unknownEnumValue:` fallback — the API will add members before the app updates.
- DateTimes: backend sends UTC ISO-8601; parse with `DateTime.parse` (keeps UTC), convert with `.toLocal()` only for display.
- Money: parse to `Decimal`/int cents, never double arithmetic for currency display math.

## Lists & pagination

Match the backend contract (keyset/cursor for infinite scroll):

```dart
Future<PageResult<Order>> getOrders({String? cursor, int pageSize = 20});
```

Provider keeps `items`, `nextCursor`, `isLoadingMore`; trigger load-more from the scroll controller at ~80% extent; guard against duplicate concurrent load-more calls; pull-to-refresh resets cursor and replaces the list.

## Resilience habits

- **Idempotency keys on risky POSTs** (checkout, payment): generate a UUID per user action (not per attempt), send as `Idempotency-Key`, reuse it on retry — pairs with a backend that supports it.
- Retries: only for idempotent GETs and network-level failures (`dio_smart_retry` or manual, exponential backoff + jitter, max 2–3). Never blanket-retry POSTs without idempotency keys.
- Cancellation: pass a `CancelToken` per screen, cancel in provider dispose — abandoned screens shouldn't complete requests into dead state.
- Connectivity: `connectivity_plus` for proactive banners, but treat it as a hint — the real source of truth is the request failing; always handle `NetworkException` regardless.
- Simple offline cache when needed: repository returns cached data (drift/hive) immediately, refreshes from network, provider emits twice (cache-then-network). Only build full offline sync when the product actually requires it.

## Uploads/downloads

- Uploads: `FormData` + `MultipartFile.fromFile`, send `onSendProgress` to the UI, compress images client-side first (`flutter_image_compress`) — mobile users on cellular will thank you.
- Downloads: `dio.download` with progress; save under `path_provider` directories, never hardcoded paths.
