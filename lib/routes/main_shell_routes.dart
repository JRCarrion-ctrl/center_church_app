// File: lib/routes/main_shell_routes.dart
import 'package:go_router/go_router.dart';
import '../features/navigation/main_app.dart';
import '../features/features.dart';
import '../features/home/manage_app_announcements_page.dart';

final ShellRoute mainShellRoute = ShellRoute(
  builder: (context, state, child) => MainApp(child: child),
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (_, _) => const HomePage(),
    ),
    GoRoute(
      path: '/groups',
      name: 'groups',
      builder: (_, _) => const GroupsPage(),
    ),
    GoRoute(
      path: '/calendar',
      name: 'calendar',
      builder: (_, _) => const CalendarPage(),
    ),
    GoRoute(
      path: '/prayer',
      name: 'prayer',
      builder: (_, _) => const PrayerPage(),
    ),
    GoRoute(
      path: '/more',
      name: 'more',
      builder: (_, _) => const MorePage(),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (_, _) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/manage-app-announcements',
      builder: (context, state) => const ManageAppAnnouncementsPage(),
    ),
  ],
);
