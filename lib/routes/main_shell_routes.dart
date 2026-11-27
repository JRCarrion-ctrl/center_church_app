// File: lib/routes/main_shell_route.dart

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../features/navigation/main_app.dart';
import '../features/features.dart';
import '../features/home/manage_app_announcements_page.dart';
import '../transitions/slide.dart';
import '../app_state.dart';
import '../features/home/blog/blog_list_page.dart';
import '../features/home/blog/blog_details_page.dart';
import '../features/event_setup/event_setup_access.dart';
import '../features/event_setup/pages/event_setup_page.dart';

final ShellRoute mainShellRoute = ShellRoute(
  builder: (context, state, child) => MainApp(child: child),
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      pageBuilder: (context, state) {
        final appState = context.read<AppState>();
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
        final appState = context.read<AppState>();
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
        final appState = context.read<AppState>();
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
        final appState = context.read<AppState>();
        final direction = appState.currentTabIndex > appState.previousTabIndex
            ? SlideDirection.right
            : SlideDirection.left;

        return buildSlidePage(const PrayerPage(), direction: direction);
      },
    ),
    // Staff / ministry-leader tab; role guard lives in app_router.dart redirect.
    GoRoute(
      path: EventSetupAccess.route,
      name: 'event_setup',
      pageBuilder: (context, state) {
        final appState = context.read<AppState>();
        final direction = appState.currentTabIndex > appState.previousTabIndex
            ? SlideDirection.right
            : SlideDirection.left;

        return buildSlidePage(const EventSetupPage(), direction: direction);
      },
    ),
    GoRoute(
      path: '/more',
      name: 'more',
      pageBuilder: (context, state) {
        final appState = context.read<AppState>();
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
    GoRoute(
      path: '/blogs',
      name: 'blogs',
      builder: (context, state) => const BlogListPage(),
    ),
    GoRoute(
      path: '/blog/:id',
      name: 'blog_detail',
      builder: (context, state) {
        final blogId = state.pathParameters['id']!;
        return BlogDetailPage(blogId: blogId); // Only pass the ID
      },
    ),
  ],
);