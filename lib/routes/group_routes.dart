// File: lib/routes/group_routes.dart
import 'package:go_router/go_router.dart';
import '../transitions/slide.dart'; 
import '../features/groups/group_page.dart';
import '../features/calendar/models/group_event.dart';
import '../features/groups/pages/group_info_page.dart';
import '../features/groups/pages/manage_members_page.dart';
import '../features/groups/pages/manage_events_page.dart';
import '../features/groups/pages/manage_announcements_page.dart';
import '../features/groups/pages/group_media_page.dart';
import 'package:ccf_app/features/groups/pages/group_event_list_page.dart';

final List<GoRoute> groupRoutes = [
  GoRoute(
    path: '/groups/:id',
    name: 'group',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['id']!;
      return buildSlidePage(
        GroupPage(groupId: groupId),
        direction: SlideDirection.right,
        key: state.pageKey, // <--- Added key
      );
    },
  ),
  GoRoute(
    path: '/groups/:id/info',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['id']!;
      final extra = state.extra as Map<String, dynamic>?; 
      final isAdmin = extra?['isAdmin'] as bool? ?? false;
      final isOwner = extra?['isOwner'] as bool? ?? false;
      return buildSlidePage(
        GroupInfoPage(groupId: groupId, isAdmin: isAdmin, isOwner: isOwner),
        direction: SlideDirection.right,
        key: state.pageKey, // <--- Added key
      );
    },
    // Add the /members route as a sub-route of /info
    routes: [
      GoRoute(
        path: 'members', 
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?; 
          final isAdmin = extra?['isAdmin'] as bool? ?? false;
          
          return buildSlidePage(
            ManageMembersPage(groupId: groupId, isAdmin: isAdmin),
            direction: SlideDirection.right,
            key: state.pageKey, // <--- Added key
          );
        },
      ),
    ]
  ),
  // The original /groups/:id/members route
  GoRoute(
    path: '/groups/:id/info/members',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['id']!;
      final extra = state.extra as Map<String, dynamic>?; 
      final isAdmin = extra?['isAdmin'] as bool? ?? false;
      
      return buildSlidePage(
        ManageMembersPage(groupId: groupId, isAdmin: isAdmin),
        direction: SlideDirection.right,
        key: state.pageKey, // <--- Added key
      );
    },
  ),
  GoRoute(
    path: '/group-event/:id',
    pageBuilder: (context, state) {
      final eventId = state.pathParameters['id']!;
      final extraEvent = state.extra as GroupEvent?; // Allow nullable

      // Use a wrapper that handles fetching if the object is missing
      return buildSlidePage(
        GroupEventDeepLinkWrapper(eventId: eventId, preloadedEvent: extraEvent),
        direction: SlideDirection.right,
        key: state.pageKey,
      );
    },
  ),
  GoRoute(
    path: '/groups/:id/info/announcements',
    pageBuilder: (context, state) { 
      final groupId = state.pathParameters['id']!;
      return buildSlidePage(
        ManageAnnouncementsPage(groupId: groupId),
        direction: SlideDirection.right,
        key: state.pageKey, // <--- Added key
      );
    },
  ),
  GoRoute(
    path: '/groups/:id/info/events',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['id']!;
      return buildSlidePage(
        GroupEventListPage(groupId: groupId),
        direction: SlideDirection.right,
        key: state.pageKey, // <--- Added key
      );
    },
  ),
  GoRoute(
    path: '/groups/:id/info/media',
    pageBuilder: (context, state) { 
      final groupId = state.pathParameters['id']!;
      return buildSlidePage(
        GroupMediaPage(groupId: groupId),
        direction: SlideDirection.right,
        key: state.pageKey, // <--- Added key
      );
    },
  ),
];