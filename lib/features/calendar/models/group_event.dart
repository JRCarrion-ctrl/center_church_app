// File: lib/features/calendar/models/group_event.dart

class GroupEvent {
  final String id;
  final String groupId;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime eventDate;
  final DateTime? eventEnd;
  final String? location;
  final int? attendingCount;
  final String? groupName;
  final List<GroupEventSlot> slots;

  GroupEvent({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    this.imageUrl,
    required this.eventDate,
    this.eventEnd,
    this.location,
    this.attendingCount,
    this.groupName,
    this.slots = const [],
  });

  factory GroupEvent.fromMap(Map<String, dynamic> map) {
    int? count;
    final aggregate = map['rsvps_aggregate']?['aggregate']?['sum'];
    if (aggregate != null && aggregate['attending_count'] != null) {
      count = (aggregate['attending_count'] as num).toInt();
    }

    return GroupEvent(
      id: map['id'],
      groupId: map['group_id'],
      title: map['title'],
      description: map['description'],
      imageUrl: map['image_url'] as String?,
      eventDate: DateTime.parse(map['event_date']).toUtc(),
      eventEnd: map['event_end'] != null 
          ? DateTime.parse(map['event_end']).toUtc() 
          : null,
      location: map['location'],
      attendingCount: count,
      groupName: map['group']?['name'] as String?,
      slots: (map['event_slots'] as List?)
          ?.map((s) => GroupEventSlot.fromMap(s))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'event_date': eventDate.toUtc().toIso8601String(),
      'event_end': eventEnd?.toUtc().toIso8601String(),
      'location': location,
    };
  }
}

class GroupEventSlot {
  final String? id;
  final String title;
  final int maxSlots;
  final int currentCount; // <--- NEW: Tracks how many are taken

  GroupEventSlot({
    this.id, 
    required this.title, 
    required this.maxSlots,
    this.currentCount = 0, // Default to 0
  });

  factory GroupEventSlot.fromMap(Map<String, dynamic> map) {
    // Logic to parse Hasura Aggregate
    int count = 0;
    if (map['slot_assignments_aggregate'] != null) {
      final sum = map['slot_assignments_aggregate']?['aggregate']?['sum'];
      if (sum != null && sum['quantity'] != null) {
        count = (sum['quantity'] as num).toInt();
      }
    }

    return GroupEventSlot(
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