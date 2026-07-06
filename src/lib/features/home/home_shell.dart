import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../lessons/lessons_screen.dart';
import '../review/review_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../translate/translate_screen.dart';

/// Khung chính sau splash. Điều hướng adaptive:
/// - Desktop (cửa sổ rộng, Windows): [NavigationRail] bên trái.
/// - Mobile (Android/iOS): [BottomNavigationBar] dưới đáy.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

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
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
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
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    label: d.label,
                  ),
              ],
            ),
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
