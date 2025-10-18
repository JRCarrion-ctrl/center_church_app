// File: lib/main_app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../app_state.dart';

class MainApp extends StatelessWidget {
  final Widget child;

  // Icons updated to use outlined versions for a cleaner, modern look
  // NOTE: 'labelKey' is already used instead of hard-coded text.
  static const tabs = [
    _TabItem(path: '/groups', icon: Icons.group_outlined, labelKey: 'main_1'),
    _TabItem(path: '/calendar', icon: Icons.calendar_today_outlined, labelKey: 'main_2'),
    _TabItem(path: '/', icon: Icons.home_outlined, labelKey: 'main_3'),
    _TabItem(path: '/prayer', icon: Icons.menu_book_outlined, labelKey: 'main_4'),
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
    final colorScheme = theme.colorScheme;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final currentLocation = GoRouterState.of(context).uri.toString();
        final selectedIndex = _resolveTabIndex(currentLocation);

        return Scaffold(
          // ====================================================================
          // MODERN TOP BANNER (AppBar)
          // ====================================================================
          appBar: AppBar(
            // Use M3 surface and rely on shadow for separation
            backgroundColor: colorScheme.surface, 
            elevation: 0,
            scrolledUnderElevation: 4.0, // Shows subtle shadow when content scrolls under
            
            // Layout is now asymmetric (branding to the left)
            leadingWidth: 0,
            centerTitle: false, 

            title: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Image.asset(
                'assets/logo_light.png', 
                height: 36,
                fit: BoxFit.contain,
                color: colorScheme.onSurface, // Use M3 color for tinting
              ),
            ),
            
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: colorScheme.onSurface),
                onPressed: () => context.push('/notifications'),
              ),
              // Added profile icon for better user navigation structure
              IconButton(
                icon: Icon(Icons.account_circle_outlined, color: colorScheme.onSurface),
                onPressed: () => context.push('/more/profile'), 
              ),
              const SizedBox(width: 8),
            ],
            // Removed the explicit bottom divider line (PreferredSize)
          ),

          body: child,

          // ====================================================================
          // MODERN BOTTOM BANNER (NavigationBar - M3)
          // ====================================================================
          bottomNavigationBar: NavigationBar(
            backgroundColor: colorScheme.surfaceContainer, // Soft M3 surface
            elevation: 2, // Subtle lift/shadow
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              if (index != selectedIndex) {
                appState.updateTabIndex(index);
                context.go(tabs[index].path);
              }
            },
            // Map _TabItem data to NavigationDestination widgets
            destinations: tabs
                .map((t) => NavigationDestination(
                        // NavigationDestination handles M3 styling (rounded indicator)
                        icon: Icon(t.icon),
                        selectedIcon: Icon(t.icon), 
                        label: t.labelKey.tr(), // Uses localization key for translation
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