// lib/routes/misc_routes.dart
import 'package:ccf_app/features/more/pages/public_profile.dart';
import 'package:go_router/go_router.dart';
import '../transitions/transitions.dart';
import '../features/features.dart';
import '../features/giving/give_page.dart';
import 'package:ccf_app/features/calendar/pages/app_event_details_page.dart';
import '../features/calendar/models/app_event.dart';
import '../features/more/pages/group_deletion_requests_page.dart';

final List<GoRoute> miscRoutes = [
  GoRoute(
    path: '/give',
    pageBuilder: (_, _) => buildSlidePage(
      const GivePage(),
      direction: SlideDirection.right,
    ),
  ),
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
  GoRoute(
    path: '/app-event/:id',
    pageBuilder: (context, state) {
      final event = state.extra as AppEvent;
      return buildSlidePage(
        AppEventDetailsPage(event: event),
        direction: SlideDirection.right,
      );
    },
  ),
  GoRoute(
    path: '/profile/:id',
    builder: (context, state) => PublicProfile(userId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/admin/group-deletion-requests',
    builder: (context, state) => const GroupDeletionRequestsPage(),
  ),
];
