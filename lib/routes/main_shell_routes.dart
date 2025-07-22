import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/navigation/main_app.dart';
import '../features/features.dart';
import '../features/home/manage_app_announcements_page.dart';
import '../transitions/slide.dart';
import '../app_state.dart';

final ShellRoute mainShellRoute = ShellRoute(
  builder: (context, state, child) => MainApp(child: child),
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      pageBuilder: (context, state) {
        final appState = Provider.of<AppState>(context, listen: false);
        final direction = appState.currentTabIndex > appState.previousTabIndex
            ? SlideDirection.right
            : SlideDirection.left;

        return buildSlidePage(const HomePage(), direction: direction);
      },
    ),
    GoRoute(
      path: '/groups',
      name: 'groups',
      pageBuilder: (context, state) {
        final appState = Provider.of<AppState>(context, listen: false);
        final direction = appState.currentTabIndex > appState.previousTabIndex
            ? SlideDirection.right
            : SlideDirection.left;

        return buildSlidePage(const GroupsPage(), direction: direction);
      },
    ),
    GoRoute(
      path: '/calendar',
      name: 'calendar',
      pageBuilder: (context, state) {
        final appState = Provider.of<AppState>(context, listen: false);
        final direction = appState.currentTabIndex > appState.previousTabIndex
            ? SlideDirection.right
            : SlideDirection.left;

        return buildSlidePage(const CalendarPage(), direction: direction);
      },
    ),
    GoRoute(
      path: '/prayer',
      name: 'prayer',
      pageBuilder: (context, state) {
        final appState = Provider.of<AppState>(context, listen: false);
        final direction = appState.currentTabIndex > appState.previousTabIndex
            ? SlideDirection.right
            : SlideDirection.left;

        return buildSlidePage(const PrayerPage(), direction: direction);
      },
    ),
    GoRoute(
      path: '/more',
      name: 'more',
      pageBuilder: (context, state) {
        final appState = Provider.of<AppState>(context, listen: false);
        final direction = appState.currentTabIndex > appState.previousTabIndex
            ? SlideDirection.right
            : SlideDirection.left;

        return buildSlidePage(const MorePage(), direction: direction);
      },
    ),
    GoRoute(
      path: '/manage-app-announcements',
      builder: (context, state) => const ManageAppAnnouncementsPage(),
    ),
  ],
);
