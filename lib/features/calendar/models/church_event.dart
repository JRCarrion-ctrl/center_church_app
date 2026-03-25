// File: lib/features/calendar/models/church_event.dart

class ChurchEvent {
  // --- Core Fields ---
  final String id;
  final String title;
  final String? description;
  final DateTime eventDate;
  final DateTime? eventEnd;
  final String? imageUrl;
  final String? location; 
  final String? rrule;

  // --- Unified Relationship Fields ---
  final String? groupId;
  final String? groupName; 
  final List<ChurchEventSlot> slots;
  final List<String> targetAudiences;
  final int? attendingCount;

  // --- The State Machine Fields ---
  final String visibility;
  final String status;

  // --- Helpful UI Getters ---
  bool get isBilingual => targetAudiences.contains('english') && targetAudiences.contains('spanish');
  bool get isPublicApp => visibility == 'public_app';
  bool get isGroupOnly => visibility == 'group_only';
  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending_approval';

  ChurchEvent({
    required this.id,
    required this.title,
    this.description,
    required this.eventDate,
    this.eventEnd,
    this.imageUrl,
    this.location,
    this.rrule,
    this.groupId,
    this.groupName,
    this.slots = const [],
    this.targetAudiences = const [], 
    this.attendingCount,
    this.visibility = 'public_app',
    this.status = 'approved',
  });

  factory ChurchEvent.fromMap(Map<String, dynamic> map) {
    // Safely parse the RSVP Aggregate (Brought over from GroupEvent)
    int? count;
    final aggregate = map['rsvps_aggregate']?['aggregate']?['sum'];
    if (aggregate != null && aggregate['attending_count'] != null) {
      count = (aggregate['attending_count'] as num).toInt();
    }

    return ChurchEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      eventDate: DateTime.parse(map['event_date'] as String).toUtc(),
      eventEnd: map['event_end'] != null 
          ? DateTime.parse(map['event_end'] as String).toUtc() 
          : null,
      imageUrl: map['image_url'] as String?,
      location: map['location'] as String?,
      rrule: map['rrule'] as String?,
      
      // Handle nested group relationship
      groupId: map['group_id'] as String?,
      groupName: map['group']?['name'] as String?,
      
      // The new State Machine columns with safe defaults
      visibility: map['visibility'] as String? ?? 'public_app',
      status: map['status'] as String? ?? 'approved',
      
      // Safely parse arrays and slots
      targetAudiences: (map['target_audiences'] as List?)
              ?.cast<String>()
              .toList() ?? [],
      slots: (map['event_slots'] as List?)
              ?.map((s) => ChurchEventSlot.fromMap(s))
              .toList() ?? [],
      attendingCount: count,
    );
  }
}

class ChurchEventSlot {
  final String? id;
  final String title;
  final int maxSlots;
  final int currentCount; 

  ChurchEventSlot({
    this.id, 
    required this.title, 
    required this.maxSlots,
    this.currentCount = 0, 
  });

  factory ChurchEventSlot.fromMap(Map<String, dynamic> map) {
    // Parse Hasura Aggregate for current assignments
    int count = 0;
    if (map['slot_assignments_aggregate'] != null) {
      final sum = map['slot_assignments_aggregate']?['aggregate']?['sum'];
      if (sum != null && sum['quantity'] != null) {
        count = (sum['quantity'] as num).toInt();
      }
    }

    return ChurchEventSlot(
      id: map['id'],
      title: map['title'],
      maxSlots: map['max_slots'] as int,
      currentCount: count,
    );
  }

  Map<String, dynamic> toUpsertMap() => {
        'title': title,
        'max_slots': maxSlots,
      };
}