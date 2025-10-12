import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../app_state.dart';

class MainApp extends StatelessWidget {
  final Widget child;

  // store keys, not translated strings
  static const tabs = [
    _TabItem(path: '/groups', icon: Icons.group, labelKey: 'main_1'),
    _TabItem(path: '/calendar', icon: Icons.calendar_today, labelKey: 'main_2'),
    _TabItem(path: '/', icon: Icons.home, labelKey: 'main_3'),
    _TabItem(path: '/prayer', icon: Icons.book, labelKey: 'main_4'),
    _TabItem(path: '/more', icon: Icons.more_horiz, labelKey: 'main_5'),
  ];

  const MainApp({super.key, required this.child});

  int _resolveTabIndex(String location) {
    final index = tabs.indexWhere(
      (t) => location == t.path || location.startsWith('${t.path}/'),
    );
    return index == -1 ? 2 : index; // default to Home
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final currentLocation = GoRouterState.of(context).uri.toString();
        final selectedIndex = _resolveTabIndex(currentLocation);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            leadingWidth: 120,
            leading: Padding(
              padding: const EdgeInsets.only(left: 1.0),
              child: Center(
                child: Text(
                  'CCF',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            title: Image.asset(
              'assets/logo_light.png',
              height: 40,
              fit: BoxFit.contain,
              color: isDark ? Colors.white : Colors.black,
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.notifications, color: textColor),
                onPressed: () => context.push('/notifications'),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Container(color: theme.dividerColor, height: 1),
            ),
          ),

          body: child,

          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            currentIndex: selectedIndex,
            onTap: (index) {
              if (index != selectedIndex) {
                appState.updateTabIndex(index);
                context.go(tabs[index].path);
              }
            },
            selectedItemColor: theme.colorScheme.primary,
            unselectedItemColor: theme.unselectedWidgetColor,
            items: tabs
                .map((t) => BottomNavigationBarItem(
                      icon: Icon(t.icon),
                      label: t.labelKey.tr(), // translate at build time
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class _TabItem {
  final String path;
  final IconData icon;
  final String labelKey;

  const _TabItem({
    required this.path,
    required this.icon,
    required this.labelKey,
  });
}
