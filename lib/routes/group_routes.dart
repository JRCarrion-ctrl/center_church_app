// File: lib/routes/group_routes.dart
import 'package:go_router/go_router.dart';
import '../features/groups/group_page.dart';
import '../features/groups/models/group.dart';
import '../features/groups/pages/edit_group_info_page.dart';
import '../features/groups/pages/manage_members_page.dart';
import '../features/groups/pages/manage_events_page.dart';
import '../features/groups/pages/manage_announcements_page.dart';

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
    path: '/groups/:id/events',
    builder: (context, state) {
      final groupId = state.pathParameters['id']!;
      return ManageGroupEventsPage(groupId: groupId);
    },
  ),
  GoRoute(
    path: '/groups/:id/announcements',
    builder: (context, state) {
      final groupId = state.pathParameters['id']!;
      return ManageAnnouncementsPage(groupId: groupId);
    },
  ),
];
