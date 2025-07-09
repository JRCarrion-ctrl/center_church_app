// lib/routes/misc_routes.dart
import 'package:ccf_app/features/more/pages/add_child_profile.dart';
import 'package:ccf_app/features/more/pages/edit_child_profile.dart';
import 'package:ccf_app/features/more/pages/view_child_profile.dart';
import 'package:ccf_app/features/more/pages/public_profile.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../transitions/transitions.dart';
import '../features/features.dart';
import '../features/giving/give_page.dart';
import 'package:ccf_app/features/calendar/pages/app_event_details_page.dart';
import '../features/calendar/models/app_event.dart';
import '../features/more/pages/family_page.dart';

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
    path: '/more/family',
    pageBuilder: (context, state) {
      final familyId = state.extra as String?;
      final user = Supabase.instance.client.auth.currentUser;
      if (familyId == null || user == null) {
        throw Exception('Missing required family ID or user not logged in');
      }
      return buildSlidePage(
        FamilyPage(familyId: familyId, currentUserId: user.id),
        direction: SlideDirection.right,
      );
    },
  ),
  GoRoute(
    path: '/more/family/add_child',
    name: 'add_child_profile',
    pageBuilder: (context, state) {
      final familyId = state.extra;
      if (familyId is! String) {
        throw Exception('Missing or invalid family ID');
      }
      return buildSlidePage(
        AddChildProfilePage(familyId: familyId),
        direction: SlideDirection.right,
      );
    },
  ),
  GoRoute(
    path: '/more/family/edit_child',
    name: 'edit_child_profile',
    pageBuilder: (context, state) {
      final child = state.extra;
      if (child is! Map<String, dynamic>) {
        throw Exception('Missing or invalid child data for edit');
      }
      return buildSlidePage(
        EditChildProfilePage(child: child),
        direction: SlideDirection.right,
      );
    },
  ),
  GoRoute(
    path: '/more/family/view_child',
    name: 'view_child_profile',
    pageBuilder: (context, state) {
      final childId = state.extra;
      if (childId is! String) {
        throw Exception('Missing or invalid child ID for view');
      }
      return buildSlidePage(
        ViewChildProfilePage(childId: childId),
        direction: SlideDirection.right,
      );
    },
  ),
];