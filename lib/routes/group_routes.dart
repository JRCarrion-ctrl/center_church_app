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
      );
    },
    // Add the /members route as a sub-route of /info (if you want to ensure
    // that isAdmin/isOwner is available for the next hop)
    routes: [
      GoRoute(
        // The path should be relative to its parent route: /groups/:id/info/members
        path: 'members', 
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['id']!;
          // FIX: Extract the isAdmin flag passed from GroupInfoPage via the extra parameter.
          // NOTE: If GroupInfoPage is navigating here, it must pass the data via 'extra'.
          final extra = state.extra as Map<String, dynamic>?; 
          final isAdmin = extra?['isAdmin'] as bool? ?? false;
          
          return buildSlidePage(
            // Pass the isAdmin flag to the ManageMembersPage
            ManageMembersPage(groupId: groupId, isAdmin: isAdmin),
            direction: SlideDirection.right,
          );
        },
      ),
    ]
  ),
  // The original /groups/:id/members route must be updated or removed
  // I will update it, assuming the call site remains context.push('/groups/:id/members')
  // but note that nesting it under /info is a cleaner architectural approach.
  GoRoute(
    path: '/groups/:id/info/members',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['id']!;
      final extra = state.extra as Map<String, dynamic>?; 
      final isAdmin = extra?['isAdmin'] as bool? ?? false;
      
      return buildSlidePage(
        ManageMembersPage(groupId: groupId, isAdmin: isAdmin),
        direction: SlideDirection.right,
      );
    },
  ),
  GoRoute(
    path: '/group-event/:id',
    pageBuilder: (context, state) {
      final event = state.extra as GroupEvent;
      return buildSlidePage(
        GroupEventDetailsPage(event: event),
        direction: SlideDirection.right,
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
      );
    },
  ),
];