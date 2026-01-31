// File: lib/routes/group_routes.dart
import 'package:go_router/go_router.dart';
import '../features/groups/group_page.dart';
import '../features/calendar/models/group_event.dart';
import '../features/groups/pages/group_info_page.dart';
import '../features/groups/pages/manage_members_page.dart';
import '../features/groups/pages/manage_announcements_page.dart';
import '../features/groups/pages/group_media_page.dart';
import 'package:ccf_app/features/groups/pages/group_event_list_page.dart';
import '../features/calendar/widgets/group_event_form_modal.dart';
import '../features/groups/pages/manage_events_page.dart'; // Ensure this import exists

final List<GoRoute> groupRoutes = [
  // 1. Main Group Landing Page
  GoRoute(
    path: '/groups/:id',
    name: 'group',
    builder: (context, state) {
      final groupId = state.pathParameters['id']!;
      return GroupPage(groupId: groupId);
    },
  ),

  // 2. Group Info/Settings Page
  GoRoute(
    path: '/groups/:id/info',
    builder: (context, state) {
      final groupId = state.pathParameters['id']!;
      final extra = state.extra as Map<String, dynamic>?; 
      final isAdmin = extra?['isAdmin'] as bool? ?? false;
      final isOwner = extra?['isOwner'] as bool? ?? false;
      
      return GroupInfoPage(groupId: groupId, isAdmin: isAdmin, isOwner: isOwner);
    },
    routes: [
      // 2a. Manage Members (Nested)
      GoRoute(
        path: 'members', 
        builder: (context, state) {
          final groupId = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?; 
          final isAdmin = extra?['isAdmin'] as bool? ?? false;
          
          return ManageMembersPage(groupId: groupId, isAdmin: isAdmin);
        },
      ),
      
      // 2b. Manage Announcements (Nested)
      GoRoute(
        path: 'announcements',
        builder: (context, state) { 
          final groupId = state.pathParameters['id']!;
          return ManageAnnouncementsPage(groupId: groupId);
        },
      ),

      // 2c. Manage Events List (Nested)
      GoRoute(
        path: 'events',
        builder: (context, state) {
          final groupId = state.pathParameters['id']!;
          return GroupEventListPage(groupId: groupId);
        },
        routes: [
          // Create NEW group event: /groups/:id/info/events/new
          GoRoute(
            path: 'new',
            builder: (context, state) {
              final groupId = state.pathParameters['id']!;
              return GroupEventFormModal(groupId: groupId);
            },
          ),
          // Edit EXISTING group event: /groups/:id/info/events/edit
          GoRoute(
            path: 'edit',
            builder: (context, state) {
              final groupId = state.pathParameters['id']!;
              final event = state.extra as GroupEvent?;
              return GroupEventFormModal(groupId: groupId, existing: event);
            },
          ),
        ],
      ),

      // 2d. Group Media (Nested)
      GoRoute(
        path: 'media',
        builder: (context, state) { 
          final groupId = state.pathParameters['id']!;
          return GroupMediaPage(groupId: groupId);
        },
      ),
    ]
  ),

  // 3. Deep Link for VIEWING a Group Event
  // Kept top-level for cleaner sharing URLs: domain.com/group-event/123
  GoRoute(
    path: '/group-event/:id',
    builder: (context, state) {
      final eventId = state.pathParameters['id']!;
      final extraEvent = state.extra as GroupEvent?; 

      return GroupEventDeepLinkWrapper(
        eventId: eventId, 
        preloadedEvent: extraEvent
      );
    },
  ),
];