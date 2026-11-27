// File: lib/features/event_setup/models/event_setup_models.dart

/// The three departments that must sign off before an event is scheduled.
/// [dbValue] matches the check constraint in backend/event_setup/001_event_setup.sql.
enum SetupDepartment {
  administrator('administrator', 'event_setup_dept_admin', 'event_setup_dept_admin_desc'),
  security('security', 'event_setup_dept_security', 'event_setup_dept_security_desc'),
  cleaning('cleaning', 'event_setup_dept_cleaning', 'event_setup_dept_cleaning_desc');

  const SetupDepartment(this.dbValue, this.labelKey, this.descriptionKey);

  final String dbValue;
  final String labelKey;
  final String descriptionKey;

  static SetupDepartment? fromDb(String? value) {
    for (final d in values) {
      if (d.dbValue == value) return d;
    }
    return null;
  }
}

/// Rooms / facilities that can be reserved.
enum SetupRoom {
  mainSanctuary('main_sanctuary', 'event_setup_room_main_sanctuary'),
  fellowshipHall('fellowship_hall', 'event_setup_room_fellowship_hall'),
  youthRoom('youth_room', 'event_setup_room_youth_room'),
  classroom('classroom', 'event_setup_room_classroom'),
  other('other', 'event_setup_room_other');

  const SetupRoom(this.dbValue, this.labelKey);

  final String dbValue;
  final String labelKey;

  static SetupRoom fromDb(String? value) {
    for (final r in values) {
      if (r.dbValue == value) return r;
    }
    return SetupRoom.other;
  }
}

/// How long before the event its announcement is posted. Posting never happens
/// before all three departments sign off; if the lead time has already passed
/// at approval, it posts right away. [dbValue] matches 002_announcements_and_visibility.sql.
enum AnnounceLead {
  asap('asap', 'event_setup_lead_asap', Duration.zero),
  oneDay('1_day', 'event_setup_lead_1_day', Duration(days: 1)),
  threeDays('3_days', 'event_setup_lead_3_days', Duration(days: 3)),
  oneWeek('1_week', 'event_setup_lead_1_week', Duration(days: 7)),
  twoWeeks('2_weeks', 'event_setup_lead_2_weeks', Duration(days: 14));

  const AnnounceLead(this.dbValue, this.labelKey, this.lead);

  final String dbValue;
  final String labelKey;
  final Duration lead;

  static AnnounceLead? fromDb(String? value) {
    for (final l in values) {
      if (l.dbValue == value) return l;
    }
    return null;
  }
}

/// A sign-up slot people can claim once the event is on the calendar
/// ("Bring a dessert", 10 spots). Copied to unified_event_slots at approval.
class SetupSlot {
  final String title;
  final int maxSlots;

  const SetupSlot({required this.title, required this.maxSlots});

  static SetupSlot? fromMap(dynamic map) {
    if (map is! Map) return null;
    final title = (map['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) return null;
    return SetupSlot(title: title, maxSlots: (map['max_slots'] as num?)?.toInt() ?? 1);
  }

  Map<String, dynamic> toMap() => {'title': title, 'max_slots': maxSlots};
}

/// A file uploaded with the request. Copied to event_attachments at approval.
class SetupAttachment {
  final String fileName;
  final String fileUrl;
  final String contentType;
  final int? fileSizeBytes;

  const SetupAttachment({
    required this.fileName,
    required this.fileUrl,
    required this.contentType,
    this.fileSizeBytes,
  });

  static SetupAttachment? fromMap(dynamic map) {
    if (map is! Map) return null;
    final name = map['file_name'] as String?;
    final url = map['file_url'] as String?;
    if (name == null || url == null) return null;
    return SetupAttachment(
      fileName: name,
      fileUrl: url,
      contentType: map['content_type'] as String? ?? 'application/octet-stream',
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'file_name': fileName,
    'file_url': fileUrl,
    'content_type': contentType,
    'file_size_bytes': fileSizeBytes,
  };
}

class EventSetupSignoff {
  final String id;
  final SetupDepartment department;
  final String approvedBy;
  final String? approverName;
  final DateTime approvedAt;

  const EventSetupSignoff({
    required this.id,
    required this.department,
    required this.approvedBy,
    required this.approvedAt,
    this.approverName,
  });

  static EventSetupSignoff? fromMap(Map<String, dynamic> map) {
    final dept = SetupDepartment.fromDb(map['department'] as String?);
    if (dept == null) return null;
    return EventSetupSignoff(
      id: map['id'] as String,
      department: dept,
      approvedBy: map['approved_by'] as String,
      approverName: map['approver']?['display_name'] as String?,
      approvedAt: DateTime.parse(map['approved_at'] as String).toLocal(),
    );
  }
}

class EventSetupRequest {
  final String id;
  final String title;
  final String? groupId;
  final String? groupName;
  final SetupRoom room;
  final DateTime start;
  final DateTime end;
  final int? estimatedAttendance;
  final String? notes;
  final String? description;
  final bool addToCalendar;
  final AnnounceLead? announceLead;
  final String status;
  final String? createdBy;
  final String? creatorName;
  final List<EventSetupSignoff> signoffs;
  final List<String> targetAudiences;
  final String? imageUrl;

  /// Typed-in location, used when [room] is [SetupRoom.other].
  final String? locationOther;
  final bool rsvpEnabled;
  final List<SetupSlot> signupSlots;
  final List<SetupAttachment> attachments;

  const EventSetupRequest({
    required this.id,
    required this.title,
    required this.room,
    required this.start,
    required this.end,
    required this.status,
    this.groupId,
    this.groupName,
    this.estimatedAttendance,
    this.notes,
    this.description,
    this.addToCalendar = true,
    this.announceLead,
    this.createdBy,
    this.creatorName,
    this.signoffs = const [],
    this.targetAudiences = const ['english', 'spanish'],
    this.imageUrl,
    this.locationOther,
    this.rsvpEnabled = false,
    this.signupSlots = const [],
    this.attachments = const [],
  });

  /// True when the room is Other and a place was typed in.
  bool get hasCustomLocation => room == SetupRoom.other && (locationOther?.trim().isNotEmpty ?? false);

  /// The typed-in place for Other, else null (show [room]'s label instead).
  String? get customLocation => hasCustomLocation ? locationOther!.trim() : null;

  bool get isApproved => status == 'approved';
  int get approvedCount => signoffs.map((s) => s.department).toSet().length;

  EventSetupSignoff? signoffFor(SetupDepartment dept) {
    for (final s in signoffs) {
      if (s.department == dept) return s;
    }
    return null;
  }

  factory EventSetupRequest.fromMap(Map<String, dynamic> map) {
    return EventSetupRequest(
      id: map['id'] as String,
      title: map['title'] as String,
      groupId: map['group_id'] as String?,
      groupName: map['group']?['name'] as String?,
      room: SetupRoom.fromDb(map['room'] as String?),
      start: DateTime.parse(map['event_date'] as String).toLocal(),
      end: DateTime.parse(map['event_end'] as String).toLocal(),
      estimatedAttendance: (map['estimated_attendance'] as num?)?.toInt(),
      notes: map['notes'] as String?,
      description: map['description'] as String?,
      addToCalendar: map['add_to_calendar'] as bool? ?? true,
      announceLead: AnnounceLead.fromDb(map['announce_lead'] as String?),
      status: map['status'] as String? ?? 'pending',
      createdBy: map['created_by'] as String?,
      creatorName: map['creator']?['display_name'] as String?,
      signoffs: (map['signoffs'] as List? ?? const [])
          .map((s) => EventSetupSignoff.fromMap(s as Map<String, dynamic>))
          .whereType<EventSetupSignoff>()
          .toList(),
      targetAudiences: (map['target_audiences'] as List?)?.map((e) => e.toString()).toList() ??
          const ['english', 'spanish'],
      imageUrl: map['image_url'] as String?,
      locationOther: map['location_other'] as String?,
      rsvpEnabled: map['rsvp_enabled'] as bool? ?? false,
      signupSlots: (map['signup_slots'] as List? ?? const [])
          .map(SetupSlot.fromMap)
          .whereType<SetupSlot>()
          .toList(),
      attachments: (map['attachments'] as List? ?? const [])
          .map(SetupAttachment.fromMap)
          .whereType<SetupAttachment>()
          .toList(),
    );
  }
}

/// "Someone edited an event": sent to Cleaning, Security and owners by the
/// event_setup_after_edit trigger (backend/event_setup/003_edits_and_notifications.sql).
class EventSetupNotification {
  final String id;
  final String? requestId;
  final String title;
  final List<String> changes;
  final String? actorName;
  final DateTime createdAt;

  const EventSetupNotification({
    required this.id,
    required this.requestId,
    required this.title,
    required this.changes,
    required this.actorName,
    required this.createdAt,
  });

  factory EventSetupNotification.fromMap(Map<String, dynamic> map) {
    return EventSetupNotification(
      id: map['id'] as String,
      requestId: map['request_id'] as String?,
      title: map['title'] as String? ?? '',
      changes: (map['changes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      actorName: map['actor']?['display_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}

/// One owner-managed rule: [userId] may approve [department] for events in
/// [groupId], or for every ministry when [groupId] is null.
class ApprovalPermission {
  final String id;
  final String userId;
  final String? userName;
  final String? userEmail;
  final SetupDepartment department;
  final String? groupId;
  final String? groupName;

  const ApprovalPermission({
    required this.id,
    required this.userId,
    required this.department,
    this.userName,
    this.userEmail,
    this.groupId,
    this.groupName,
  });

  bool get isAllMinistries => groupId == null;

  bool covers(SetupDepartment dept, String? eventGroupId) =>
      department == dept && (groupId == null || groupId == eventGroupId);

  static ApprovalPermission? fromMap(Map<String, dynamic> map) {
    final dept = SetupDepartment.fromDb(map['department'] as String?);
    if (dept == null) return null;
    return ApprovalPermission(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userName: map['profile']?['display_name'] as String?,
      userEmail: map['profile']?['email'] as String?,
      department: dept,
      groupId: map['group_id'] as String?,
      groupName: map['group']?['name'] as String?,
    );
  }
}

/// An announcement made from Event Setup: standalone, or generated from an
/// approved event ([requestId] set). [groupId] null = church-wide.
class HubAnnouncement {
  final String id;
  final String? requestId;
  final String? groupId;
  final String? groupName;
  final String title;
  final String? body;
  final String? imageUrl;
  final DateTime publishAt;
  final String createdBy;
  final String? creatorName;

  const HubAnnouncement({
    required this.id,
    required this.title,
    required this.publishAt,
    required this.createdBy,
    this.requestId,
    this.groupId,
    this.groupName,
    this.body,
    this.imageUrl,
    this.creatorName,
  });

  bool get isScheduled => publishAt.isAfter(DateTime.now());
  bool get isFromEvent => requestId != null;

  factory HubAnnouncement.fromMap(Map<String, dynamic> map) {
    return HubAnnouncement(
      id: map['id'] as String,
      requestId: map['request_id'] as String?,
      groupId: map['group_id'] as String?,
      groupName: map['group']?['name'] as String?,
      title: map['title'] as String,
      body: map['body'] as String?,
      imageUrl: map['image_url'] as String?,
      publishAt: DateTime.parse(map['publish_at'] as String).toLocal(),
      createdBy: map['created_by'] as String,
      creatorName: map['creator']?['display_name'] as String?,
    );
  }
}

/// Lightweight ministry / group option for selectors.
class MinistryOption {
  final String id;
  final String name;
  const MinistryOption(this.id, this.name);
}

/// Lightweight member option for the permission picker.
class MemberOption {
  final String id;
  final String displayName;
  final String? email;
  const MemberOption(this.id, this.displayName, this.email);
}
