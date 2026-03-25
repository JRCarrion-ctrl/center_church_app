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
            backgroundColor: colorScheme.surface,
            elevation: 0,
            scrolledUnderElevation: 4.0,
            leadingWidth: 0,
            centerTitle: false,
            title: Row(
              children: [
                Image.asset(
                  'assets/logo_light.png',
                  height: 32,
                  fit: BoxFit.contain,
                  color: colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                
                // THE CLEAN DROPDOWN
                MenuAnchor(
                  // 1. STYLE THE DROPDOWN MENU (The Glass Pane)
                  style: MenuStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      colorScheme.surface.withValues(alpha: 0.85), // Translucent background
                    ),
                    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent), // Removes M3 purple tint
                    elevation: const WidgetStatePropertyAll(8), // Soft floating shadow
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16), // Match your app's rounded cards
                        side: BorderSide(
                          color: colorScheme.onSurface.withValues(alpha: 0.1), // Subtle glass edge
                          width: 1,
                        ),
                      ),
                    ),
                    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
                  ),
                  builder: (BuildContext context, MenuController controller, Widget? child) {
                    // 2. STYLE THE MASTER BUTTON (The Sleek Pill)
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.4), // Very subtle frosted fill
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorScheme.onSurface.withValues(alpha: 0.15), // Glass rim outline
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getServiceLabel(appState.selectedService),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600, 
                                  fontSize: 14,
                                  color: colorScheme.onSurface, // Crisp text
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                controller.isOpen 
                                    ? Icons.keyboard_arrow_up_rounded 
                                    : Icons.keyboard_arrow_down_rounded, 
                                size: 18,
                                color: colorScheme.onSurface.withValues(alpha: 0.7), // Slightly faded icon
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  menuChildren: _getSortedServices(appState.selectedService).map((service) {
                    final isSelected = service == appState.selectedService;
                    return MenuItemButton(
                      style: MenuItemButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        backgroundColor: Colors.transparent, // Let the glass background show through
                      ),
                      leadingIcon: isSelected 
                          ? Icon(Icons.check_rounded, size: 18, color: colorScheme.primary) 
                          : const SizedBox(width: 18), 
                      child: Text(
                        _getServiceLabel(service),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                        ),
                      ),
                      onPressed: () {
                        appState.updateServiceFilter(service);
                      },
                    );
                  }).toList(),
                )
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.account_circle_outlined, color: colorScheme.onSurface),
                onPressed: () => context.push('/more/profile'),
              ),
              const SizedBox(width: 8),
            ],
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

String _getServiceLabel(ChurchService service) {
  return switch (service) {
    ChurchService.english => 'TCCF',
    ChurchService.spanish => 'Centro',
    ChurchService.both => 'TCCF & Centro',
  };
}
List<ChurchService> _getSortedServices(ChurchService selected) {
  // Get the options that are NOT currently selected
  final List<ChurchService> others = ChurchService.values
      .where((e) => e != selected)
      .toList();
      
  // If "Both" is in the unselected list, move it to the very end
  if (others.contains(ChurchService.both)) {
    others.remove(ChurchService.both);
    others.add(ChurchService.both);
  }
  
  // Return the selected item first, followed by the sorted others
  return [selected, ...others];
}