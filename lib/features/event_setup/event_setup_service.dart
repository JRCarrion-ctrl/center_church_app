// File: lib/features/event_setup/event_setup_service.dart
//
// Hasura access for Event Setup. The server enforces all authorization:
// row permissions (backend/event_setup/hasura_permissions.md) scope rows to
// staff (owner/supervisor/approvers) or the ministries a leader leads, and Postgres triggers validate each department sign-off
// against event_setup_approval_permissions. The client-side checks in the UI
// only decide which controls to show.
//
// Department notifications on submit are sent server-side by the Hasura event
// trigger `event_setup_request_created` (backend/event_setup/notifications_webhook.md),
// so nothing here calls OneSignal directly.

import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:uuid/uuid.dart';

import '../calendar/church_event_attachment_upload_service.dart';
import '../calendar/event_photo_storage_service.dart';
import 'models/event_setup_models.dart';

class _Q {
  static const requestFields = r'''
    id title group_id room event_date event_end estimated_attendance notes status
    description add_to_calendar announce_lead created_by target_audiences
    image_url location_other rsvp_enabled signup_slots attachments
    group { name }
    creator { display_name }
    signoffs(order_by: { approved_at: asc }) {
      id department approved_by approved_at
      approver { display_name }
    }
  ''';

  static const fetchRequests =
      '''
    query FetchEventSetupRequests(\$since: timestamptz!) {
      event_setup_requests(
        where: { event_end: { _gte: \$since } }
        order_by: [{ status: desc }, { event_date: asc }]
      ) { $requestFields }
    }
  ''';

  static const insertRequest = r'''
    mutation InsertEventSetupRequest($object: event_setup_requests_insert_input!) {
      insert_event_setup_requests_one(object: $object) { id }
    }
  ''';

  static const updateRequest = r'''
    mutation UpdateEventSetupRequest($id: uuid!, $set: event_setup_requests_set_input!) {
      update_event_setup_requests_by_pk(pk_columns: { id: $id }, _set: $set) { id }
    }
  ''';

  static const fetchNotifications = r'''
    query MyEventSetupNotifications($uid: String!) {
      event_setup_notifications(
        where: { user_id: { _eq: $uid }, read_at: { _is_null: true } }
        order_by: { created_at: desc }
        limit: 30
      ) {
        id request_id title changes created_at
        actor { display_name }
      }
    }
  ''';

  static const markNotificationsRead = r'''
    mutation MarkEventSetupNotificationsRead($ids: [uuid!]!, $now: timestamptz!) {
      update_event_setup_notifications(where: { id: { _in: $ids } }, _set: { read_at: $now }) {
        affected_rows
      }
    }
  ''';

  static const insertSignoff = r'''
    mutation SignOffEventSetup($requestId: uuid!, $department: String!) {
      insert_event_setup_signoffs_one(
        object: { request_id: $requestId, department: $department }
      ) { id }
    }
  ''';

  static const deleteSignoff = r'''
    mutation RevokeEventSetupSignoff($requestId: uuid!, $department: String!) {
      delete_event_setup_signoffs(
        where: { request_id: { _eq: $requestId }, department: { _eq: $department } }
      ) { affected_rows }
    }
  ''';

  static const permissionFields = r'''
    id user_id department group_id
    profile { display_name email }
    group { name }
  ''';

  static const fetchMyPermissions =
      '''
    query MyEventSetupPermissions(\$uid: String!) {
      event_setup_approval_permissions(where: { user_id: { _eq: \$uid } }) {
        $permissionFields
      }
    }
  ''';

  static const fetchAllPermissions =
      '''
    query AllEventSetupPermissions {
      event_setup_approval_permissions(order_by: { created_at: asc }) {
        $permissionFields
      }
    }
  ''';

  static const insertPermissions = r'''
    mutation InsertEventSetupPermissions($objects: [event_setup_approval_permissions_insert_input!]!) {
      insert_event_setup_approval_permissions(objects: $objects) { affected_rows }
    }
  ''';

  static const deletePermission = r'''
    mutation DeleteEventSetupPermission($id: uuid!) {
      delete_event_setup_approval_permissions_by_pk(id: $id) { id }
    }
  ''';

  static const fetchMinistries = r'''
    query EventSetupMinistries {
      groups(where: { archived: { _eq: false } }, order_by: { name: asc }) { id name }
    }
  ''';

  static const announcementFields = r'''
    id request_id group_id title body image_url publish_at created_by
    group { name }
    creator { display_name }
  ''';

  static const fetchAnnouncements =
      '''
    query FetchEventSetupAnnouncements(\$since: timestamptz!) {
      event_setup_announcements(
        where: { publish_at: { _gte: \$since } }
        order_by: { publish_at: desc }
      ) { $announcementFields }
    }
  ''';

  static const insertAnnouncement = r'''
    mutation InsertEventSetupAnnouncement($object: event_setup_announcements_insert_input!) {
      insert_event_setup_announcements_one(object: $object) { id }
    }
  ''';

  static const deleteAnnouncement = r'''
    mutation DeleteEventSetupAnnouncement($id: uuid!) {
      delete_event_setup_announcements_by_pk(id: $id) { id }
    }
  ''';

  static const fetchLedMinistries = r'''
    query EventSetupLedMinistries($uid: String!) {
      group_memberships(
        where: {
          user_id: { _eq: $uid }
          status: { _eq: "approved" }
          role: { _in: ["admin", "leader", "supervisor", "owner"] }
          group: { archived: { _eq: false } }
        }
        order_by: { group: { name: asc } }
      ) { group { id name } }
    }
  ''';

  static const fetchMembers = r'''
    query EventSetupMembers {
      profiles(order_by: { display_name: asc }) { id display_name email }
    }
  ''';
}

class EventSetupService {
  EventSetupService(this._client);

  final GraphQLClient _client;

  late final EventPhotoStorageService _photos = EventPhotoStorageService(_client);
  late final ChurchEventAttachmentUploadService _files = ChurchEventAttachmentUploadService(_client);

  /// Groups a request's uploads in storage before it has an id.
  final String _draftId = const Uuid().v4();

  static const Map<String, String> _contentTypes = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'heic': 'image/heic',
    'txt': 'text/plain',
    'csv': 'text/csv',
  };

  /// Uploads a picture for an event or announcement; returns its public URL.
  Future<String> uploadImage(Uint8List bytes, String? extension) async {
    final ext = (extension == null || extension.isEmpty) ? 'jpg' : extension.replaceFirst('.', '');
    final url = await _photos.uploadEventPhoto(
      bytes: bytes,
      extension: '.$ext',
      keyPrefix: 'event_setup',
      logicalId: _draftId,
    );
    if (url == null) throw Exception('Image upload failed');
    return url;
  }

  /// Uploads a file for an event. It's attached to the calendar entry when
  /// the event is approved.
  Future<SetupAttachment> uploadAttachment(Uint8List bytes, String fileName) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final contentType = _contentTypes[ext] ?? 'application/octet-stream';
    final url = await _files.uploadEventAttachment(
      eventId: 'setup_$_draftId',
      bytes: bytes,
      originalFileName: fileName,
      contentType: contentType,
    );
    return SetupAttachment(fileName: fileName, fileUrl: url, contentType: contentType, fileSizeBytes: bytes.length);
  }

  Future<Map<String, dynamic>> _query(String doc, [Map<String, dynamic> vars = const {}]) async {
    final res = await _client.query(
      QueryOptions(document: gql(doc), variables: vars, fetchPolicy: FetchPolicy.networkOnly),
    );
    if (res.hasException) throw res.exception!;
    return res.data ?? const {};
  }

  Future<Map<String, dynamic>> _mutate(String doc, Map<String, dynamic> vars) async {
    final res = await _client.mutate(MutationOptions(document: gql(doc), variables: vars));
    if (res.hasException) throw res.exception!;
    return res.data ?? const {};
  }

  /// Pending requests plus recently approved ones whose event hasn't ended yet.
  Future<List<EventSetupRequest>> fetchRequests() async {
    final since = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final data = await _query(_Q.fetchRequests, {'since': since.toIso8601String()});
    return (data['event_setup_requests'] as List? ?? const [])
        .map((m) => EventSetupRequest.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<String> submitRequest({
    required String title,
    required String? groupId,
    required SetupRoom room,
    required DateTime start,
    required DateTime end,
    required int? estimatedAttendance,
    required String? notes,
    required String? description,
    required bool addToCalendar,
    required AnnounceLead? announceLead,
    required List<String> targetAudiences,
    String? imageUrl,
    String? locationOther,
    bool rsvpEnabled = false,
    List<SetupSlot> signupSlots = const [],
    List<SetupAttachment> attachments = const [],
  }) async {
    final data = await _mutate(_Q.insertRequest, {
      'object': {
        'title': title,
        'group_id': groupId,
        'room': room.dbValue,
        ..._mediaFields(
          room: room,
          imageUrl: imageUrl,
          locationOther: locationOther,
          rsvpEnabled: rsvpEnabled,
          signupSlots: signupSlots,
          attachments: attachments,
        ),
        'event_date': start.toUtc().toIso8601String(),
        'event_end': end.toUtc().toIso8601String(),
        'estimated_attendance': estimatedAttendance,
        'notes': (notes == null || notes.isEmpty) ? null : notes,
        'description': (description == null || description.isEmpty) ? null : description,
        'add_to_calendar': addToCalendar,
        'announce_lead': announceLead?.dbValue,
        'target_audiences': targetAudiences,
      },
    });
    return data['insert_event_setup_requests_one']['id'] as String;
  }

  /// Saves an edit to a submitted event. Sign-offs stay as they are; the
  /// server updates the calendar entry / announcement and notifies Cleaning,
  /// Security and owners.
  Future<void> updateRequest({
    required String id,
    required String title,
    required SetupRoom room,
    required DateTime start,
    required DateTime end,
    required int? estimatedAttendance,
    required String? notes,
    required String? description,
    required List<String> targetAudiences,
    String? imageUrl,
    String? locationOther,
    bool rsvpEnabled = false,
    List<SetupSlot>? signupSlots,
    List<SetupAttachment>? attachments,
  }) => _mutate(_Q.updateRequest, {
    'id': id,
    'set': {
      'title': title,
      'room': room.dbValue,
      ..._mediaFields(
        room: room,
        imageUrl: imageUrl,
        locationOther: locationOther,
        rsvpEnabled: rsvpEnabled,
        signupSlots: signupSlots,
        attachments: attachments,
      ),
      'event_date': start.toUtc().toIso8601String(),
      'event_end': end.toUtc().toIso8601String(),
      'estimated_attendance': estimatedAttendance,
      'notes': (notes == null || notes.isEmpty) ? null : notes,
      'description': (description == null || description.isEmpty) ? null : description,
      'target_audiences': targetAudiences,
    },
  });

  /// [signupSlots] / [attachments] null = leave unchanged (approved events
  /// manage those on the calendar page).
  Map<String, dynamic> _mediaFields({
    required SetupRoom room,
    required String? imageUrl,
    required String? locationOther,
    required bool rsvpEnabled,
    required List<SetupSlot>? signupSlots,
    required List<SetupAttachment>? attachments,
  }) {
    final place = locationOther?.trim() ?? '';
    return {
      'image_url': (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
      'location_other': (room == SetupRoom.other && place.isNotEmpty) ? place : null,
      'rsvp_enabled': rsvpEnabled,
      if (signupSlots != null) 'signup_slots': signupSlots.map((s) => s.toMap()).toList(),
      if (attachments != null) 'attachments': attachments.map((a) => a.toMap()).toList(),
    };
  }

  /// Unread "event was edited" notices for [userId].
  Future<List<EventSetupNotification>> fetchNotifications(String userId) async {
    final data = await _query(_Q.fetchNotifications, {'uid': userId});
    return (data['event_setup_notifications'] as List? ?? const [])
        .map((m) => EventSetupNotification.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> markNotificationsRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _mutate(_Q.markNotificationsRead, {
      'ids': ids,
      'now': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> signOff(String requestId, SetupDepartment dept) =>
      _mutate(_Q.insertSignoff, {'requestId': requestId, 'department': dept.dbValue});

  Future<void> revokeSignoff(String requestId, SetupDepartment dept) =>
      _mutate(_Q.deleteSignoff, {'requestId': requestId, 'department': dept.dbValue});

  Future<List<ApprovalPermission>> fetchMyPermissions(String userId) async {
    final data = await _query(_Q.fetchMyPermissions, {'uid': userId});
    return _parsePermissions(data);
  }

  Future<List<ApprovalPermission>> fetchAllPermissions() async {
    final data = await _query(_Q.fetchAllPermissions);
    return _parsePermissions(data);
  }

  /// Creates one rule per department for [userId] scoped to [groupId]
  /// (null = All Ministries).
  Future<void> addPermissions({
    required String userId,
    required String? groupId,
    required Iterable<SetupDepartment> departments,
  }) async {
    final objects = departments.map((d) => {'user_id': userId, 'department': d.dbValue, 'group_id': groupId}).toList();
    if (objects.isEmpty) return;
    await _mutate(_Q.insertPermissions, {'objects': objects});
  }

  Future<void> deletePermission(String id) => _mutate(_Q.deletePermission, {'id': id});

  Future<List<MinistryOption>> fetchMinistries() async {
    final data = await _query(_Q.fetchMinistries);
    return (data['groups'] as List? ?? const [])
        .map((g) => MinistryOption(g['id'] as String, g['name'] as String))
        .toList();
  }

  /// Ministries [userId] leads (group admin/leader). Used to scope what a
  /// ministry leader may create.
  Future<List<MinistryOption>> fetchLedMinistries(String userId) async {
    final data = await _query(_Q.fetchLedMinistries, {'uid': userId});
    return (data['group_memberships'] as List? ?? const [])
        .map((m) => m['group'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map((g) => MinistryOption(g['id'] as String, g['name'] as String))
        .toList();
  }

  /// Scheduled announcements plus those posted in the last 30 days.
  Future<List<HubAnnouncement>> fetchAnnouncements() async {
    final since = DateTime.now().toUtc().subtract(const Duration(days: 30));
    final data = await _query(_Q.fetchAnnouncements, {'since': since.toIso8601String()});
    return (data['event_setup_announcements'] as List? ?? const [])
        .map((m) => HubAnnouncement.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// Standalone announcement. [groupId] null = church-wide. The server copies
  /// it to the ministry's (or church-wide) announcements at [publishAt].
  Future<void> createAnnouncement({
    required String title,
    required String? body,
    required String? groupId,
    required List<String> targetAudiences,
    required DateTime publishAt,
    String? imageUrl,
  }) => _mutate(_Q.insertAnnouncement, {
    'object': {
      'title': title,
      'body': (body == null || body.isEmpty) ? null : body,
      'image_url': (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
      'group_id': groupId,
      'target_audiences': targetAudiences,
      'publish_at': publishAt.toUtc().toIso8601String(),
    },
  });

  Future<void> deleteAnnouncement(String id) => _mutate(_Q.deleteAnnouncement, {'id': id});

  Future<List<MemberOption>> fetchMembers() async {
    final data = await _query(_Q.fetchMembers);
    return (data['profiles'] as List? ?? const [])
        .map((p) => MemberOption(p['id'] as String, (p['display_name'] as String?) ?? '', p['email'] as String?))
        .toList();
  }

  List<ApprovalPermission> _parsePermissions(Map<String, dynamic> data) =>
      (data['event_setup_approval_permissions'] as List? ?? const [])
          .map((m) => ApprovalPermission.fromMap(m as Map<String, dynamic>))
          .whereType<ApprovalPermission>()
          .toList();
}
