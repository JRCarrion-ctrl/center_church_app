// File: lib/routes/group_routes.dart
import 'package:go_router/go_router.dart';
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
    builder: (context, state) {
      final groupId = state.pathParameters['id']!;
      return GroupPage(groupId: groupId);
    },
  ),
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
      GoRoute(
        path: 'members', 
        builder: (context, state) {
          final groupId = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?; 
          final isAdmin = extra?['isAdmin'] as bool? ?? false;
          
          return ManageMembersPage(groupId: groupId, isAdmin: isAdmin);
        },
      ),
    ]
  ),
  GoRoute(
    path: '/groups/:id/info/members',
    builder: (context, state) {
      final groupId = state.pathParameters['id']!;
      final extra = state.extra as Map<String, dynamic>?; 
      final isAdmin = extra?['isAdmin'] as bool? ?? false;
      
      return ManageMembersPage(groupId: groupId, isAdmin: isAdmin);
    },
  ),
  GoRoute(
    path: '/group-event/:id',
    builder: (context, state) {
      final eventId = state.pathParameters['id']!;
      final extraEvent = state.extra as GroupEvent?; 

      return GroupEventDeepLinkWrapper(eventId: eventId, preloadedEvent: extraEvent);
    },
  ),
  GoRoute(
    path: '/groups/:id/info/announcements',
    builder: (context, state) { 
      final groupId = state.pathParameters['id']!;
      return ManageAnnouncementsPage(groupId: groupId);
    },
  ),
  GoRoute(
    path: '/groups/:id/info/events',
    builder: (context, state) {
      final groupId = state.pathParameters['id']!;
      return GroupEventListPage(groupId: groupId);
    },
  ),
  GoRoute(
    path: '/groups/:id/info/media',
    builder: (context, state) { 
      final groupId = state.pathParameters['id']!;
      return GroupMediaPage(groupId: groupId);
    },
  ),
];