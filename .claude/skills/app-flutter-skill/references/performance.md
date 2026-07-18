
# Flutter Performance

Measure first: DevTools Performance view (frame chart — find the >16ms frames), rebuild counts (Widget Rebuild Stats / `debugRepaintRainbowEnabled` for repaints), Memory view, `flutter run --profile` on a **real low-end device** — debug-mode and emulator numbers lie. Name the bucket before fixing.

## 1. Rebuild elimination (jank while interacting)

- `const` constructors everywhere possible — const widgets short-circuit rebuilds. Lint `prefer_const_constructors` should be an error.
- Narrow what listens: `context.select` over `watch`, `Consumer` with its `child:` parameter for stable subtrees, split big widgets so state changes rebuild leaves not screens.
- Extract widget **classes**, not helper methods — `Widget _buildHeader()` rebuilds with the parent and can't be const; `class _Header extends StatelessWidget` can.
- Don't create objects in `build` that break `==` downstream: closures passed to const-hungry children, new `TextStyle`/`EdgeInsets` (make them static const), new controller instances (state/initState).
- Animations: `AnimatedBuilder`/`ListenableBuilder` with `child:` so only the animated part rebuilds; prefer implicit animations (`AnimatedContainer`) or `transform` properties over rebuilding layouts per tick.

## 2. Lists (scroll jank)

- `ListView.builder`/`SliverList` always — never `ListView(children: [...])` or `Column` in `SingleChildScrollView` for long/unbounded lists (builds everything up front).
- `itemExtent` or `prototypeItem` when rows are uniform — skips speculative layout.
- Keep item builds cheap: no per-item network calls or heavy compute in `itemBuilder`; precompute in the provider.
- Images in lists: `cacheWidth`/`cacheHeight` (or `ResizeImage`) sized to display size — decoding a 4000px photo for an 80px thumbnail is the classic list-jank cause. `cached_network_image` for network thumbs.
- `RepaintBoundary` around items with heavy paint (charts, shadows) — verify with the repaint rainbow, don't sprinkle blindly (each boundary costs memory).
- Avoid `shrinkWrap: true` + `NeverScrollableScrollPhysics` nesting where slivers (`CustomScrollView`) do it properly.

## 3. Heavy work off the UI thread

- The UI isolate owns 16ms per frame. JSON parsing of big payloads, image processing, crypto → `compute()`/`Isolate.run`:
  ```dart
  final orders = await Isolate.run(() => parseOrders(jsonString));
  ```

  Threshold rule: anything that could exceed ~4ms on the weakest target device.
- Debounce user-input-driven work (search filtering) with a `Timer` or stream debounce in the provider.
- `Future.delayed(Duration.zero)` hacks and `scheduleMicrotask` chains in reviews = smell; find the actual ordering problem.

## 4. Startup time

- Defer everything deferrable: don't initialize analytics/remote-config/heavy plugins before `runApp`; kick off after first frame (`WidgetsBinding.instance.addPostFrameCallback`) or lazily.
- Show a native splash (`flutter_native_splash`) into a lightweight first frame; fetch data after, with skeletons.
- Profile with `flutter run --trace-startup --profile`; on Android check for slow plugin `onAttachedToEngine` work.
- Deferred loading (`deferred as`) for rarely-used heavy routes on Android (AABs support it); iOS doesn't split — keep heavy deps honest on both.

## 5. Memory

- Dispose everything with a `dispose()`: controllers (Text/Scroll/Animation/Tab), focus nodes, stream subscriptions, timers, `ChangeNotifier`s you own. Review flag: any `late final XController` without a matching dispose.
- Image cache blowups: huge images without `cacheWidth`; clear or bound `PaintingBinding.instance.imageCache` for gallery-style apps.
- Leaked providers: screen-scoped state provided globally accumulates; verify screens' state dies on pop (DevTools memory snapshot diff after 3× navigate in/out).
- Listeners added (`addListener`, platform streams) and never removed — pair every add with a remove in dispose.

## 6. Build size & shaders

- `flutter build appbundle` / IPA with `--split-debug-info` and `--obfuscate`; audit size with `--analyze-size`.
- Asset bloat: compress PNGs or use WebP, don't bundle 3x assets nobody requests, tree-shake icons (default on) — no `--no-tree-shake-icons` in release.
- Shader jank (first-run animation stutter, mostly iOS pre-Impeller): Impeller is default on iOS and Android in current stable — if targeting old Flutter, mention SkSL warmup; otherwise verify Impeller isn't disabled.

## Quick perf review checklist

- [ ] const everywhere constable; extracted widget classes not helper methods
- [ ] `select`/`Consumer(child:)` narrowing rebuilds; no whole-screen watch for one field
- [ ] Lists: `.builder`, sized image decoding, cheap item builds
- [ ] Big JSON/compute in isolates; input-driven work debounced
- [ ] Everything owning resources has a matching dispose
- [ ] Startup: no heavy sync init before first frame
- [ ] Profiled in --profile mode on a real device before and after
