// File: lib/routes/group_routes.dart
import 'package:go_router/go_router.dart';
import '../features/calendar/models/group_event.dart';
import '../features/groups/pages/manage_members_page.dart';
import '../features/groups/pages/manage_announcements_page.dart';
import '../features/groups/pages/group_media_page.dart';
import '../features/groups/pages/group_event_list_page.dart';
import '../features/calendar/widgets/group_event_form_modal.dart';
import '../features/groups/pages/manage_events_page.dart';
import '../features/groups/pages/group_portal_page.dart';
import '../features/groups/pages/group_settings_page.dart'; // Ensure this is imported

final List<GoRoute> groupRoutes = [
  // Main Group Landing Page
  GoRoute(
    path: '/groups/:id',
    name: 'group',
    builder: (context, state) {
      final groupId = state.pathParameters['id']!;
      final extra = state.extra as Map<String, dynamic>?; 
      return GroupPortalPage(
        groupId: groupId, 
        isAdmin: extra?['isAdmin'] as bool? ?? false, 
        isOwner: extra?['isOwner'] as bool? ?? false,
      );
    },
    routes: [
      // --- ALL PREVIOUS INFO ROUTES MOVED HERE ---
      
      GoRoute(
        path: 'info/settings', 
        builder: (context, state) => GroupSettingsPage(
          group: (state.extra as Map<String, dynamic>?)?['group'],
        ),
      ),
      GoRoute(
        path: 'info/members', 
        builder: (context, state) => ManageMembersPage(
          groupId: state.pathParameters['id']!, 
          isAdmin: (state.extra as Map<String, dynamic>?)?['isAdmin'] ?? false,
        ),
      ),
      GoRoute(
        path: 'info/announcements',
        builder: (context, state) => ManageAnnouncementsPage(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: 'info/events',
        builder: (context, state) => GroupEventListPage(groupId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => GroupEventFormModal(groupId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'edit',
            builder: (context, state) => GroupEventFormModal(
              groupId: state.pathParameters['id']!, 
              existing: state.extra as GroupEvent?,
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'info/media',
        builder: (context, state) => GroupMediaPage(groupId: state.pathParameters['id']!),
      ),
    ],
  ),

  // Deep Link for VIEWING a Group Event
  GoRoute(
    path: '/group-event/:id',
    builder: (context, state) => GroupEventDeepLinkWrapper(
      eventId: state.pathParameters['id']!, 
      preloadedEvent: state.extra as GroupEvent?,
    ),
  ),
];