
# State with Provider — Senior Patterns

## Scoping: the rule that prevents most Provider pain

Provide state at the narrowest scope that covers its consumers:

- **App root (`MultiProvider` in `main`)**: auth session, user profile, settings/theme, connectivity — things genuinely alive for the whole app.
- **Route/screen level**: feature state. Wrap the screen in its provider so the state is created on entry and disposed on exit:
  ```dart
  GoRoute(
    path: '/orders',
    builder: (context, state) => ChangeNotifierProvider(
      create: (ctx) => OrdersProvider(ctx.read<OrdersRepository>())..load(),
      child: const OrdersScreen(),
    ),
  ),
  ```
- **Widget subtree**: rarely — per-item state in complex lists (`ChangeNotifierProvider.value` for existing instances; never `create:` inside `itemBuilder` with `.value` semantics confused — `create` makes new instances, `.value` reuses).

Global-everything is the junior smell: it leaks memory, keeps stale state between visits, and hides dependencies.

## A well-shaped ChangeNotifier

```dart
class OrdersProvider extends ChangeNotifier {
  OrdersProvider(this._repo);
  final OrdersRepository _repo;

  OrdersState _state = OrdersLoading();
  OrdersState get state => _state;

  bool _disposed = false;

  Future<void> load() async {
    _set(OrdersLoading());
    try {
      final orders = await _repo.getOrders();
      _set(OrdersLoaded(orders));
    } on ApiException catch (e) {
      _set(OrdersError(e.userMessage));
    }
  }

  void _set(OrdersState s) {
    if (_disposed) return;
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() { _disposed = true; super.dispose(); }
}
```

Rules encoded there: state exposed as a single sealed-class getter (widgets pattern-match, no boolean flag soup like `isLoading && !hasError`); private setter guards against notify-after-dispose (async completions outlive screens); repository injected (testable); errors mapped to user-facing state, never rethrown to the widget.

## Consuming without over-rebuilding

- `context.watch<T>()` in `build` only; `context.read<T>()` in callbacks/initState. `watch` in a callback is a bug; `read` in build is a stale-UI bug.
- `context.select` for one field — the biggest rebuild win:
  ```dart
  final count = context.select<CartProvider, int>((c) => c.items.length);
  ```

  Selected values need working `==` (another reason for immutable models).
- `Consumer<T>` to shrink the rebuilt subtree inside a big build method; its `child` parameter passes through non-rebuilding subtrees — use it.
- Pattern-match sealed state at the top of build:
  ```dart
  return switch (provider.state) {
    OrdersLoading() => const LoadingView(),
    OrdersError(:final message) => ErrorView(message: message, onRetry: provider.load),
    OrdersLoaded(:final orders) when orders.isEmpty => const EmptyOrdersView(),
    OrdersLoaded(:final orders) => OrderListView(orders: orders),
  };
  ```

  Exhaustive by compiler — adding a state variant breaks every screen that forgot to handle it. That's a feature.

## Wiring dependencies

- Plain `Provider<T>` for services/repositories (no notifications needed):
  ```dart
  MultiProvider(providers: [
    Provider(create: (_) => DioClient()),
    Provider(create: (ctx) => OrdersRepository(ctx.read<DioClient>())),
    ChangeNotifierProvider(create: (ctx) => AuthProvider(ctx.read<AuthRepository>())),
  ])
  ```
- `ChangeNotifierProxyProvider` when a notifier must react to another (e.g., cart resets when auth changes) — but prefer explicit method calls from the depending side; proxy chains get unreadable past two links.
- Cross-feature communication: shared parent provider at the closest common scope, or listen in the provider layer (one notifier subscribes to another via `addListener`, removing in dispose) — not widgets ferrying data between providers.

## When Provider stops being enough — say so

Signals it's time to recommend Riverpod (usually) or Bloc: provider dependency chains 3+ deep, needing providers outside the widget tree (background handlers, isolates), heavy async orchestration with cancellation/debounce/race concerns, or families of parameterized state (per-item detail providers). Don't contort Provider with global keys and service locators to fake these — name the growth path honestly, estimate the migration as incremental (Riverpod can coexist), and let the user decide.

## Testing providers

- Pure unit tests: instantiate with a mocked repository, call methods, assert state transitions — no widgets needed. This is where the value is.
- Widget tests: pump the widget wrapped in `ChangeNotifierProvider.value` with a fake provider; assert on rendered outcomes per state variant.
- Common test bug: forgetting `notifyListeners` is synchronous — after `await tester.pump()`, assert; no arbitrary `pumpAndSettle` for infinite animations (spinners) — pump fixed durations.
