import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/notification_service.dart';
import '../lessons/lessons_screen.dart';
import '../review/review_providers.dart';
import '../review/review_screen.dart';
import '../search/search_screen.dart';
import '../translate/translate_screen.dart';

const _reviewDestinationIndex = 3;

/// Khung chính sau splash. Điều hướng adaptive:
/// - Desktop (cửa sổ rộng, Windows): [NavigationRail] bên trái.
/// - Mobile (Android/iOS): [BottomNavigationBar] dưới đáy.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool _dueNotified = false;

  static const _destinations = <_Destination>[
    _Destination('Tra cứu', Icons.explore_outlined, SearchScreen()),
    _Destination('Học', Icons.menu_book_outlined, LessonsScreen()),
    _Destination('Dịch', Icons.waves_outlined, TranslateScreen()),
    _Destination('Ôn tập', Icons.radar, ReviewScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;
    final dueCount = ref.watch(dueReviewCountProvider).value ?? 0;

    // Nhắc 1 lần khi mở app nếu có từ đến hạn ôn (FR-5.3, Windows: in-app +
    // system notification khi app đang mở).
    ref.listen(dueReviewCountProvider, (prev, next) {
      final count = next.value ?? 0;
      if (!_dueNotified && count > 0) {
        _dueNotified = true;
        NotificationService.instance.showDueReminder(count);
      }
    });

    final body = IndexedStack(
      index: _index,
      children: [for (final d in _destinations) d.screen],
    );

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(_destinations[_index].label),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: _ConnectivityBadge(),
                ),
              ],
            ),
      body: isDesktop
          ? Row(
              children: [
                SizedBox(
                  width: 220,
                  child: Column(
                    children: [
                      const _NavRailBrand(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          children: [
                            for (final (i, d) in _destinations.indexed)
                              _NavRailItem(
                                label: d.label,
                                icon: _destinationIcon(d.icon, i, dueCount),
                                selected: i == _index,
                                onTap: () => _onSelect(i),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      _PageHeader(title: _destinations[_index].label),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            )
          : body,
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _onSelect,
              destinations: [
                for (final (i, d) in _destinations.indexed)
                  NavigationDestination(
                    icon: _destinationIcon(d.icon, i, dueCount),
                    label: d.label,
                  ),
              ],
            ),
    );
  }

  Widget _destinationIcon(IconData icon, int index, int dueCount) {
    if (index != _reviewDestinationIndex || dueCount <= 0) {
      return Icon(icon);
    }
    return Badge(label: Text('$dueCount'), child: Icon(icon));
  }

  void _onSelect(int i) => setState(() => _index = i);
}

class _Destination {
  const _Destination(this.label, this.icon, this.screen);
  final String label;
  final IconData icon;
  final Widget screen;
}

/// 1 mục trong nav-rail Windows — nền phủ full-width khi được chọn (khớp
/// `.nav-item`/`.nav-item.active` trong mockup), khác `NavigationRail` mặc
/// định của Material (chỉ khoanh vùng quanh icon).
class _NavRailItem extends StatelessWidget {
  const _NavRailItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveFg = Theme.of(context).colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppColors.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
            child: Row(
              children: [
                IconTheme(
                  data: IconThemeData(
                    color: selected ? AppColors.white : inactiveFg,
                    size: 20,
                  ),
                  child: icon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.white : inactiveFg,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề trang trong nội dung (chỉ Windows/desktop) — thay cho
/// `Scaffold.appBar` để khớp `.page-header` trong mockup Windows (tiêu đề
/// nằm trong `page-body`, tách khỏi title bar cửa sổ). Mobile vẫn dùng
/// `AppBar` thông thường, không đổi.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const Spacer(),
          const _ConnectivityBadge(),
        ],
      ),
    );
  }
}

/// Chỉ báo trạng thái mạng Offline/Online — khớp `.net-badge` trong
/// mockup (cả Windows lẫn Mobile đều có, xem
/// `docs/artifact-design-windows/styles.css` và
/// `docs/artifact-design/styles.css`). Dùng chung cho [_PageHeader]
/// (desktop) và `AppBar.actions` (mobile).
class _ConnectivityBadge extends ConsumerWidget {
  const _ConnectivityBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider).value ?? false;
    final color = isOnline ? Colors.green.shade700 : Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOnline ? Icons.wifi : Icons.wifi_off, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Khối logo/tên app phía trên [NavigationRail] (chỉ Windows/desktop) —
/// khớp `.nav-rail-brand` trong mockup Windows
/// (`docs/artifact-design-windows/styles.css`).
class _NavRailBrand extends StatelessWidget {
  const _NavRailBrand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.anchor,
                    size: 16, color: AppColors.snap),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontFamily: AppFonts.serif,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    Text(
                      'Cảnh sát biển VN',
                      style: TextStyle(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
