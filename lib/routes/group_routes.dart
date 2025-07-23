// File: lib/routes/group_routes.dart
import 'package:go_router/go_router.dart';
import '../transitions/slide.dart';
import '../features/groups/group_page.dart';
import '../features/calendar/models/group_event.dart';
import '../features/groups/models/group.dart';
import '../features/groups/pages/edit_group_info_page.dart';
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
    path: '/groups/:id/edit',
    builder: (context, state) {
      final group = state.extra as Group;
      return EditGroupInfoPage(group: group);
    },
  ),
  GoRoute(
    path: '/groups/:id/members',
    builder: (context, state) {
      final groupId = state.pathParameters['id']!;
      return ManageMembersPage(groupId: groupId);
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
    path: '/groups/:id/announcements',
    builder: (context, state) {
      final groupId = state.pathParameters['id']!;
      return ManageAnnouncementsPage(groupId: groupId);
    },
  ),
  GoRoute(
    path: '/groups/:id/events',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['id']!;
      return buildSlidePage(
        GroupEventListPage(groupId: groupId),
        direction: SlideDirection.right,
      );
    },
  ),
  GoRoute(
    path: '/groups/:id/media',
    builder: (context, state) {
      final groupId = state.pathParameters['id']!;
      return GroupMediaPage(groupId: groupId);
    },
  ),
];
