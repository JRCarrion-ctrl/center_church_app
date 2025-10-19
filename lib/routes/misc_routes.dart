// File: lib/routes/misc_routes.dart
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
import '../transitions/transitions.dart';
import '../features/features.dart';
import '../features/giving/give_page.dart';
import 'package:ccf_app/features/calendar/pages/app_event_details_page.dart';
import '../features/calendar/models/app_event.dart';
import '../features/more/pages/family_page.dart';
import '../features/more/pages/qr_checkin_scanner.dart';
import '../features/more/pages/nursery_staff_page.dart';

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
    path: '/more/faq',
    pageBuilder: (_, _) => buildSlidePage(
      FAQPage(),
      direction: SlideDirection.right,
    ),
  ),
  GoRoute(
    path: '/more/how_to',
    pageBuilder: (_, _) => buildSlidePage(
      HowToUsePage(),
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
    pageBuilder: (context, state) => buildSlidePage(
      PublicProfile(userId: state.pathParameters['id']!),
      direction: SlideDirection.right,
    ),
  ),
  GoRoute(
    path: '/more/family',
    pageBuilder: (context, state) {
      final familyId = (state.extra as Map<String, dynamic>?)?['familyId'] as String?;
      return buildSlidePage(
        FamilyPage(familyId: familyId),
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
  GoRoute(
    path: '/nursery',
    pageBuilder: (_, _) => buildSlidePage(const NurseryStaffPage(), direction: SlideDirection.right),
  ),
  GoRoute(
    path: '/nursery/qr_checkin',
    pageBuilder: (_, _) => buildSlidePage(const QRCheckinScannerPage(), direction: SlideDirection.right),
  ),
  GoRoute(
    path: '/more/study',
    pageBuilder: (_, _) => buildSlidePage(
      const BibleStudiesPage(),
      direction: SlideDirection.right,
    ),
  ),
  GoRoute(
    path: '/more/study/requests',
    pageBuilder: (_, _) => buildSlidePage(
      const BibleStudyRequestsPage(),
      direction: SlideDirection.right,
    ),
  ),
  GoRoute(
    path: '/more/study/edit',
    name: 'edit_bible_study',
    pageBuilder: (context, state) {
      final study = state.extra as Map<String, dynamic>?;
      return buildSlidePage(
        EditBibleStudyPage(study: study),
        direction: SlideDirection.right,
      );
    },
  ),
  GoRoute(
    path: '/notes_viewer',
    pageBuilder: (context, state) {
      final url = state.extra as String;
      return buildSlidePage(
        NotesViewerPage(url: url),
        direction: SlideDirection.right,
      );
    },
  ),
  GoRoute(
    path: '/nursery/child-profile',
    pageBuilder: (context, state) => buildSlidePage(
      ChildProfilePage(child: state.extra as Map<String, dynamic>),
      direction: SlideDirection.right,
    ),
  ),
  GoRoute(
    path: '/data-and-delete',
    pageBuilder: (context, state) => buildSlidePage(
      const DataAndDeleteAccountPage(),
      direction: SlideDirection.right,
    ),
  ),
  GoRoute(
    path: '/contact-support',
    pageBuilder: (context, state) => buildSlidePage(
      const ContactSupportPage(),
      direction: SlideDirection.right,
    ),
  ),
  GoRoute(
    path: '/settings/notifications',
    pageBuilder: (context, state) => buildSlidePage(
      const NotificationSettingsPage(),
      direction: SlideDirection.right,
    ),
  ),
  GoRoute(
    path: '/media-settings',
    pageBuilder: (context, state) => buildSlidePage(
      const MediaSettingsPage(),
      direction: SlideDirection.right,
    ),
  ),
  GoRoute(
    path: '/group-announcements',
    pageBuilder: (context, state) => buildSlidePage(
      const GroupAnnouncementsPage(),
      direction: SlideDirection.right,
    ),
  )
];