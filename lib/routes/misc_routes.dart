// lib/routes/misc_routes.dart
import 'package:go_router/go_router.dart';
import '../transitions/transitions.dart';
import '../features/features.dart';

final List<GoRoute> miscRoutes = [
  GoRoute(
    path: '/landing',
    builder: (_, _) => const LandingPage(),
  ),
  GoRoute(
    path: '/more/profile',
    pageBuilder: (_, _) => buildSlidePage(
      const ProfilePage(),
      direction: SlideDirection.right,
    ),
  ),
  GoRoute(
    path: '/more/settings',
    pageBuilder: (_, _) => buildSlidePage(
      const SettingsPage(),
      direction: SlideDirection.right,
    ),
  ),
  GoRoute(
    path: '/more/directory',
    pageBuilder: (_, _) => buildSlidePage(
      const DirectoryPage(),
      direction: SlideDirection.right,
    ),
  ),
  GoRoute(
    path: '/event/:id',
    builder: (context, state) => EventPage(eventId: state.pathParameters['id']!),
  ),
];
