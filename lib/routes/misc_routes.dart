// lib/routes/misc_routes.dart
import 'package:ccf_app/features/home/models/group_announcements_page.dart';
import 'package:ccf_app/features/more/models/contact_support.dart';
import 'package:ccf_app/features/more/models/data_delete_account.dart';
import 'package:ccf_app/features/more/models/media_settings.dart';
import 'package:ccf_app/features/more/models/notification_settings_page.dart';
import 'package:ccf_app/features/more/pages/add_child_profile.dart';
import 'package:ccf_app/features/more/pages/bible_studies_page.dart';
import 'package:ccf_app/features/more/pages/bible_study_requests_page.dart';
import 'package:ccf_app/features/more/pages/child_profile_page.dart';
import 'package:ccf_app/features/more/pages/edit_bible_study_page.dart';
import 'package:ccf_app/features/more/pages/edit_child_profile.dart';
import 'package:ccf_app/features/more/pages/faq_page.dart';
import 'package:ccf_app/features/more/pages/how_to_use_page.dart';
import 'package:ccf_app/features/more/pages/notes_viewer_page.dart';
import 'package:ccf_app/features/more/pages/view_child_profile.dart';
import 'package:ccf_app/features/more/pages/public_profile.dart';
import 'package:go_router/go_router.dart';
import '../features/features.dart';
import '../features/giving/give_page.dart';
import 'package:ccf_app/features/calendar/pages/app_event_details_page.dart';
import '../features/calendar/models/app_event.dart';
import '../features/more/pages/family_page.dart';
import '../features/more/pages/qr_checkin_scanner.dart';
import '../features/more/pages/nursery_staff_page.dart';
import '../features/more/pages/child_staff_profile.dart';
import 'package:ccf_app/features/more/pages/role_management_page.dart';

final List<GoRoute> miscRoutes = [
  GoRoute(
    path: '/more/role-management',
    builder: (_, state) => const RoleManagementPage(),
  ),
  GoRoute(
    path: '/give',
    builder: (_, state) => const GivePage(),
  ),
  GoRoute(
    path: '/landing',
    builder: (_, _) => const LandingPage(),
  ),
  GoRoute(
    path: '/more/profile',
    builder: (_, state) => const ProfilePage(),
  ),
  GoRoute(
    path: '/more/settings',
    builder: (_, state) => const SettingsPage(),
  ),
  GoRoute(
    path: '/more/faq',
    builder: (_, state) => FAQPage(),
  ),
  GoRoute(
    path: '/more/how_to',
    builder: (_, state) => HowToUsePage(),
  ),
  GoRoute(
    path: '/more/directory',
    builder: (_, state) => const DirectoryPage(),
  ),
  GoRoute(
    path: '/calendar/app-event/:id',
    builder: (context, state) {
      final eventId = state.pathParameters['id']!;
      final extraEvent = state.extra as AppEvent?; 

      return AppEventDeepLinkWrapper(
        eventId: eventId,
        preloadedEvent: extraEvent,
      );
    },
  ),
  GoRoute(
    path: '/profile/:id',
    builder: (context, state) => PublicProfile(userId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/more/family',
    builder: (context, state) {
      final familyId = (state.extra as Map<String, dynamic>?)?['familyId'] as String?;
      return FamilyPage(familyId: familyId);
    },
  ),
  GoRoute(
    path: '/more/family/add_child',
    name: 'add_child_profile',
    builder: (context, state) {
      final familyId = state.extra;
      if (familyId is! String) {
        throw Exception('Missing or invalid family ID');
      }
      return AddChildProfilePage(familyId: familyId);
    },
  ),
  GoRoute(
    path: '/more/family/edit_child',
    name: 'edit_child_profile',
    builder: (context, state) {
      final child = state.extra;
      if (child is! Map<String, dynamic>) {
        throw Exception('Missing or invalid child data for edit');
      }
      return EditChildProfilePage(child: child);
    },
  ),
  GoRoute(
    path: '/more/family/view_child',
    name: 'view_child_profile',
    builder: (context, state) {
      final childId = state.extra;
      if (childId is! String) {
        throw Exception('Missing or invalid child ID for view');
      }
      return ViewChildProfilePage(childId: childId);
    },
  ),
  GoRoute(
    path: '/more/nursery',
    builder: (_, state) => const NurseryStaffPage(),
  ),
  GoRoute(
    path: '/more/nursery/qr_checkin',
    builder: (_, state) => const QRCheckinScannerPage(),
  ),
  GoRoute(
    path: '/more/study',
    builder: (_, state) => const BibleStudiesPage(),
  ),
  GoRoute(
    path: '/more/study/requests',
    builder: (_, state) => const BibleStudyRequestsPage(),
  ),
  GoRoute(
    path: '/more/study/edit',
    name: 'edit_bible_study',
    builder: (context, state) {
      final study = state.extra as Map<String, dynamic>?;
      return EditBibleStudyPage(study: study);
    },
  ),
  GoRoute(
    path: '/more/study/notes_viewer',
    builder: (context, state) {
      final url = state.extra as String;
      return NotesViewerPage(url: url);
    },
  ),
  GoRoute(
    path: '/nursery/child-profile',
    builder: (context, state) => ChildProfilePage(
      child: state.extra as Map<String, dynamic>
    ),
  ),
  GoRoute(
    path: '/more/nursery/child-staff/:childId',
    name: 'child-staff',
    builder: (context, state) {
      final childId = state.pathParameters['childId']!;
      return ChildStaffProfilePage(childId: childId);
    },
  ),
  GoRoute(
    path: '/more/settings/data-and-delete',
    builder: (context, state) => const DataAndDeleteAccountPage(),
  ),
  GoRoute(
    path: '/more/settings/contact-support',
    builder: (context, state) => const ContactSupportPage(),
  ),
  GoRoute(
    path: '/more/settings/notifications',
    builder: (context, state) => const NotificationSettingsPage(),
  ),
  GoRoute(
    path: '/more/settings/media-settings',
    builder: (context, state) => const MediaSettingsPage(),
  ),
  GoRoute(
    path: '/group-announcements',
    builder: (context, state) => const GroupAnnouncementsPage(),
  )
];