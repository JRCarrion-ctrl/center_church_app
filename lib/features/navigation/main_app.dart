// File: lib/main_app.dart
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../app_state.dart';
import '../event_setup/event_setup_access.dart';
import '../../shared/page_refresh.dart';

class MainApp extends StatelessWidget {
  final Widget child;

  // Icons updated to use outlined versions for a cleaner, modern look
  // NOTE: 'labelKey' is already used instead of hard-coded text.
  // Outlined icon normally, filled when the tab is selected.
  static const _groupsTab = _TabItem(
      path: '/groups', icon: Icons.forum_outlined, selectedIcon: Icons.forum_rounded, labelKey: 'main_1');
  static const _calendarTab = _TabItem(
      path: '/calendar', icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month_rounded, labelKey: 'main_2');
  static const _homeTab = _TabItem(
      path: '/', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, labelKey: 'main_3');
  static const _prayerTab = _TabItem(
      path: '/prayer', icon: Icons.volunteer_activism_outlined, selectedIcon: Icons.volunteer_activism, labelKey: 'main_4');
  static const _eventsTab = _TabItem(
      path: EventSetupAccess.route, icon: Icons.campaign_outlined, selectedIcon: Icons.campaign_rounded, labelKey: 'main_events');
  static const _moreTab = _TabItem(
      path: '/more', icon: Icons.menu_rounded, selectedIcon: Icons.menu_open_rounded, labelKey: 'main_5');

  /// Event Setup only appears for staff and ministry leaders. It sits after
  /// Home, so Home keeps index 2 either way.
  static List<_TabItem> _tabsFor(AppState appState) => [
    _groupsTab,
    _calendarTab,
    _homeTab,
    _prayerTab,
    if (appState.canOpenEventSetup) _eventsTab,
    _moreTab,
  ];

  const MainApp({super.key, required this.child});

  int _resolveTabIndex(List<_TabItem> tabs, String location) {
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
        final tabs = _tabsFor(appState);
        final selectedIndex = _resolveTabIndex(tabs, GoRouterState.of(context).uri.path);

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
          // BOTTOM BAR: a floating rounded bar, centered on wide screens.
          // Tapping the tab you're already on refreshes that page.
          // ====================================================================
          bottomNavigationBar: _BottomBar(
            tabs: tabs,
            selectedIndex: selectedIndex,
            onSelected: (index) {
              if (index == selectedIndex) {
                PageRefresh.instance.ping();
                return;
              }
              appState.updateTabIndex(index);
              context.go(tabs[index].path);
            },
          ),
        );
      },
    );
  }
}

class _TabItem {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;

  const _TabItem({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
  });
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.tabs, required this.selectedIndex, required this.onSelected});

  final List<_TabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(30);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: DecoratedBox(
              decoration: BoxDecoration(
                // A clean card like the chat's message field: white with a
                // hairline edge and a soft shadow (raised surface in dark mode).
                color: Theme.of(context).brightness == Brightness.dark
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.surfaceContainerLowest,
                borderRadius: radius,
                border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.09)),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                      );
                    }),
                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return IconThemeData(
                        size: 24,
                        color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                      );
                    }),
                  ),
                  child: NavigationBar(
                    height: 68,
                    backgroundColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0),
                    surfaceTintColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0),
                    elevation: 0,
                    // Same charcoal pill as the chat's Chat / Home switch.
                    indicatorColor: colorScheme.primary,
                    indicatorShape: const StadiumBorder(),
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onSelected,
                    destinations: [
                      for (final t in tabs)
                        NavigationDestination(
                          icon: Icon(t.icon),
                          selectedIcon: Icon(t.selectedIcon),
                          label: t.labelKey.tr(),
                          tooltip: '',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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