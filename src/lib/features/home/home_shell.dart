import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/services/notification_service.dart';
import '../lessons/lessons_screen.dart';
import '../review/review_providers.dart';
import '../review/review_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
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
    _Destination('Tra cứu', Icons.search, SearchScreen()),
    _Destination('Học', Icons.menu_book, LessonsScreen()),
    _Destination('Dịch', Icons.translate, TranslateScreen()),
    _Destination('Ôn tập', Icons.repeat, ReviewScreen()),
    _Destination('Cài đặt', Icons.settings, SettingsScreen()),
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
      appBar: AppBar(title: Text(_destinations[_index].label)),
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _onSelect,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final (i, d) in _destinations.indexed)
                      NavigationRailDestination(
                        icon: _destinationIcon(d.icon, i, dueCount),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
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
