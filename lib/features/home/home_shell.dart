import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/notification_service.dart';
import '../lessons/lessons_screen.dart';
import '../my_dictionaries/my_dictionaries_screen.dart';
import '../review/review_providers.dart';
import '../search/search_screen.dart';
import '../translate/translate_screen.dart';

const _myDictionariesDestinationIndex = 3;

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
    _Destination('Từ điển của tôi', Icons.collections_bookmark_outlined, MyDictionariesScreen()),
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

    final body = Stack(
      children: [
        const Positioned.fill(child: _ContentWatermark()),
        IndexedStack(
          index: _index,
          children: [for (final d in _destinations) d.screen],
        ),
      ],
    );

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(_destinations[_index].label),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: _ConnectivityAppBarBadge(),
                ),
              ],
            ),
      body: isDesktop
          ? Row(
              children: [
                Container(
                  width: 220,
                  color: AppColors.brandDeep,
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
                      const _NavRailConnectivityFooter(),
                    ],
                  ),
                ),
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
          : _BottomNavBar(
              selectedIndex: _index,
              onSelect: _onSelect,
              destinations: _destinations,
              iconBuilder: _destinationIcon,
              dueCount: dueCount,
            ),
    );
  }

  Widget _destinationIcon(IconData icon, int index, int dueCount) {
    if (index != _myDictionariesDestinationIndex || dueCount <= 0) {
      return Icon(icon);
    }
    return Badge(
      label: Text(dueCount > 99 ? '99+' : '$dueCount'),
      backgroundColor: AppColors.signalRed,
      offset: const Offset(10, -8),
      child: Icon(icon),
    );
  }

  void _onSelect(int i) => setState(() => _index = i);
}

class _Destination {
  const _Destination(this.label, this.icon, this.screen);
  final String label;
  final IconData icon;
  final Widget screen;
}

/// Bottom nav mobile tự dựng thay cho [NavigationBar] mặc định — mỗi tab là
/// 1 khối icon+label gộp chung, đổ nền navy full-khối khi active (khác
/// `NavigationBar` M3 mặc định chỉ tô pill quanh icon).
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.selectedIndex,
    required this.onSelect,
    required this.destinations,
    required this.iconBuilder,
    required this.dueCount,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<_Destination> destinations;
  final Widget Function(IconData icon, int index, int dueCount) iconBuilder;
  final int dueCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            for (final (i, d) in destinations.indexed)
              Expanded(
                child: _BottomNavItem(
                  label: d.label,
                  icon: iconBuilder(d.icon, i, dueCount),
                  selected: i == selectedIndex,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
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
    final fg = selected ? AppColors.brand : AppColors.inkSoft;

    return Material(
      color: selected
          ? AppColors.brand.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(color: fg, size: 22),
                child: icon,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo Cảnh sát biển in mờ phía sau nội dung mỗi tab chính — hiệu ứng
/// "giấy tờ chính thức có dấu mờ". Không chặn tương tác của nội dung phía
/// trên ([IgnorePointer]).
class _ContentWatermark extends StatelessWidget {
  const _ContentWatermark();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: 0.05,
          child: Image.asset(
            'assets/images/logo/csb-logo.png',
            width: 420,
            height: 420,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
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
    final inactiveFg = AppColors.white.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppColors.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.white.withValues(alpha: 0.06),
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
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected ? AppColors.white : inactiveFg,
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
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

/// Chỉ báo trạng thái mạng Offline/Online dạng chấm màu + nhãn, đặt cuối
/// nav-rail (khớp thiết kế Google Stitch được duyệt). Mobile dùng
/// [_ConnectivityAppBarBadge] dạng bo tròn trong `AppBar.actions`.
class _NavRailConnectivityFooter extends ConsumerWidget {
  const _NavRailConnectivityFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider).value ?? false;
    final dotColor = isOnline ? AppColors.teal : AppColors.inkSoft;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              isOnline ? 'Trực tuyến' : 'Ngoại tuyến',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chỉ báo trạng thái mạng cho `AppBar.actions` (Mobile) — bo tròn dạng
/// pill, khớp `.net-badge` trong mockup mobile
/// (`docs/artifact-design/styles.css`).
class _ConnectivityAppBarBadge extends ConsumerWidget {
  const _ConnectivityAppBarBadge();

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
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Khối logo/tên app phía trên [NavigationRail] (chỉ Windows/desktop) —
/// logo dạng app-icon lớn, tên + phụ đề bên dưới (khớp thiết kế Google
/// Stitch được duyệt).
class _NavRailBrand extends StatelessWidget {
  const _NavRailBrand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Image.asset(
            'assets/images/logo/csb-logo.png',
            width: 128,
            height: 128,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.anchor, size: 40, color: AppColors.brand),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: AppFonts.serif,
                  color: AppColors.white,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            'Cảnh sát biển VN',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
}
