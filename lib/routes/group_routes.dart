// File: lib/routes/group_routes.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/groups/pages/manage_members_page.dart';
import '../features/groups/pages/manage_announcements_page.dart';
import '../features/groups/pages/group_media_page.dart';
import '../features/groups/pages/group_event_list_page.dart';
import '../features/groups/pages/group_portal_page.dart';
import '../features/groups/pages/group_settings_page.dart';
import '../features/calendar/models/church_event.dart';
import '../features/calendar/widgets/church_event_form_modal.dart';
import '../features/calendar/pages/church_event_details_page.dart';
import '../features/groups/pages/join_group_preview_screen.dart';

final List<GoRoute> groupRoutes = [
  GoRoute(
    path: '/groups/:id',
    name: 'group',
    builder: (context, state) {
      return GroupPortalPage(groupId: state.pathParameters['id']!);
    },
    routes: [
      GoRoute(
        path: 'info/settings', 
        builder: (context, state) => GroupSettingsWrapper(groupId: state.pathParameters['id']!)
      ),
      GoRoute(
        path: 'info/members', 
        builder: (context, state) => ManageMembersPage(
          groupId: state.pathParameters['id']!, 
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
            builder: (context, state) => ChurchEventFormWrapper(
              prefilledGroupId: state.pathParameters['id']!
            ),
          ),
          GoRoute(
            path: 'edit',
            builder: (context, state) => ChurchEventFormWrapper(
              prefilledGroupId: state.pathParameters['id']!, 
              eventId: state.uri.queryParameters['eventId'], 
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

  // ✨ UPDATED: Deep Link for VIEWING a Group Event points to Unified Wrapper
  GoRoute(
    path: '/group-event/:id',
    builder: (context, state) => ChurchEventDeepLinkWrapper(
      eventId: state.pathParameters['id']!, 
      preloadedEvent: state.extra as ChurchEvent?,
    ),
  ),

  GoRoute(
    path: '/invite/:groupId',
    builder: (context, state) {
      final groupId = state.pathParameters['groupId']!;
      final token = state.uri.queryParameters['token'];
      
      return GroupInviteProcessorScreen(
        groupId: groupId,
        token: token,
      );
    },
  ),

  GoRoute(
    path: '/join/:token',
    builder: (context, state) {
      final token = state.pathParameters['token'];
      
      if (token == null || token.isEmpty) {
        return const Scaffold(
          body: Center(child: Text("Invalid invite link format.")),
        );
      }
      
      return JoinGroupPreviewScreen(token: token);
    },
  ),
];