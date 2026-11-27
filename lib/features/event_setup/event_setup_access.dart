// File: lib/features/event_setup/event_setup_access.dart
//
// Client-side visibility rules for Event Setup. These only decide what to
// render and where the router lets people go. The real authorization is
// server-side (Hasura permissions + Postgres triggers in backend/event_setup/).
//
// Who can do what:
//   * Staff: owners, supervisors, and anyone with an approval permission
//     (administrator / security / cleaning). They see every ministry's events
//     and announcements.
//   * Ministry leaders: see and create only for ministries they lead.
//   * Creating: owners/supervisors (any ministry or church-wide) and ministry
//     leaders (their own ministries only). Approvers who are neither can view
//     and sign off but not create.

import '../../shared/user_roles.dart';

class EventSetupAccess {
  /// Bottom-nav tab.
  static const String route = '/event-setup';
  static const String permissionsRoute = '/event-setup/permissions';

  /// Old location (More → Event Setup). Redirects to [route].
  static const String legacyRoute = '/more/event-setup';

  static bool isAdmin(UserRole role) => role == UserRole.supervisor || role == UserRole.owner;

  /// Only owners manage who may approve.
  static bool canManagePermissions(UserRole role) => role == UserRole.owner;
}
