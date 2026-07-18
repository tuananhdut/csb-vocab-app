
# Platform & Native — Android / iOS

## Platform channels (when no plugin exists)

- `MethodChannel` for request/response, `EventChannel` for native→Dart streams. Name channels reverse-DNS (`com.yourapp/battery`).
- Dart side: wrap in a service class, map `PlatformException` codes to your `ApiException`-style hierarchy — widgets never see raw platform exceptions.
- Native side runs on the platform main thread — dispatch heavy work to background (Kotlin coroutines / GCD) and post results back on main.
- Type discipline: channel payloads are dynamic maps; validate and convert at the boundary, define the contract in one shared doc/comment on both sides.
- Prefer Pigeon for nontrivial channel APIs — generated type-safe bindings beat stringly-typed method names.
- Before writing any channel: search pub.dev; check maintenance (last release, issue tray) before adopting.

## Permissions (the #1 store-rejection and 1-star-review source)

- `permission_handler`; request **in context** (camera permission when user taps the camera button, not at launch) with a pre-prompt explaining why — iOS gives you one system prompt; burn it and you're sending users to Settings.
- Handle all outcomes: granted, denied (offer retry with rationale), permanentlyDenied (deep-link to app settings via `openAppSettings()`), restricted (parental controls — degrade gracefully).
- iOS: every used permission needs a `Info.plist` usage string (`NSCameraUsageDescription` etc.) — missing one = instant review rejection or runtime crash.
- Android 13+: notification permission is runtime (`POST_NOTIFICATIONS`) — request before relying on push; photo/media permissions split by type.

## Push notifications (FCM both platforms)

- `firebase_messaging`: FCM delivers to Android directly and to iOS via APNs (upload the APNs key in Firebase console; enable Push Notifications + Background Modes/remote-notifications capabilities in Xcode).
- Token lifecycle: send token to backend on login **and** on `onTokenRefresh`; delete server-side on logout. Backend stores per user+device (matches the .NET mobile-api pattern).
- Three handling paths, all needed: foreground (`onMessage` — show in-app banner/local notification, OS shows nothing), background tap (`onMessageOpenedApp` — navigate via deep link from `data` payload), terminated launch (`getInitialMessage` — check once after startup, route accordingly).
- Background data handler must be a **top-level function** with `@pragma('vm:entry-point')`; it runs in its own isolate — no Provider/context access, keep it minimal.
- Payload discipline: IDs + route in `data`, fetch details via API; never sensitive content in the notification.
- Android: create notification channels (importance, sound) at startup; iOS: request permission via `FirebaseMessaging.instance.requestPermission()` in context.

## Deep links

- go_router handles routing; configure App Links (Android: `assetlinks.json` + verified intent filter) and Universal Links (iOS: `apple-app-site-association` + Associated Domains capability). Custom schemes only as fallback — they're hijackable.
- Every push notification should carry a deep link route; test cold-start deep links explicitly (most common breakage).

## Background work

- Rule one: mobile OSes will kill you. Design servers-side-heavy; the app syncs opportunistically.
- Periodic/deferred tasks: `workmanager` (WorkManager / BGTaskScheduler). iOS gives no timing guarantees — anything user-critical must not depend on background execution.
- Foreground-service-style continuous work (tracking, playback) is platform-specific and store-policy-sensitive — implement natively with proper notifications/entitlements and flag the policy review.
- Persist queued offline mutations (drift/hive) and flush on connectivity/app-resume — pairs with a backend batch/idempotency contract.

## Secure storage & app security

- Tokens/secrets: `flutter_secure_storage`. Nothing sensitive in SharedPreferences or unencrypted files.
- No API keys in Dart code for privileged services (Dart decompiles trivially) — privileged operations go through your backend.
- Certificate pinning (dio `badCertificateCallback`/`SecurityContext`) only if threat model justifies it — pin rotation bricks old app versions; prefer short-lived infra certs + monitoring.
- Jailbreak/root detection, screenshot blocking (`FLAG_SECURE`) only when compliance requires — they degrade UX.

## Flavors, config & release

- Three flavors minimum (dev/staging/prod): Android `productFlavors` + iOS schemes/xcconfigs; separate bundle IDs so all can coexist on one device; `--dart-define-from-file` for per-env API URLs — never `if (kDebugMode) baseUrl = ...`.
- **Android release**: AAB, Play App Signing, keep upload keystore + `key.properties` out of git; set `targetSdkVersion` to Play's current requirement; ProGuard/R8 keep-rules for plugins that need them; test the release build — debug builds hide obfuscation crashes.
- **iOS release**: real device testing mandatory (simulators skip push, camera, performance truth); Xcode-managed signing unless CI needs manual profiles; privacy manifest + App Privacy questionnaire answers must match SDK reality (Apple cross-checks); TestFlight before production.
- Both stores: crash reporting from day one (Crashlytics/Sentry with `--split-debug-info` symbols uploaded), versioning discipline (`version: 1.4.2+37` — name+build number monotonic per store), staged rollout (Play staged %, iOS phased release) with a halt criterion.
- CI: build both platforms per PR; a change that builds on Android and breaks iOS signing/pods is routine — catch it before release week.

## Platform-adaptive UX seniors don't skip

- Back handling: Android predictive back / `PopScope` for unsaved-changes guards; iOS swipe-back must not be broken by custom gesture handlers.
- Keyboard: `SafeArea` + scrollable forms + `textInputAction` (next/done) wiring; test with keyboard open on a small phone.
- Text scaling & accessibility: test at 1.3× text scale, label icon buttons (`Semantics`/`tooltip`), respect reduced motion.
- Date/number formatting via `intl` with the device locale — never hand-formatted strings.
