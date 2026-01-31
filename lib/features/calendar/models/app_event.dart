// File: lib/features/calendar/models/app_event.dart

class AppEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime eventDate;
  final DateTime? eventEnd;
  final String? imageUrl;
  final String? location;
  final List<AppEventSlot> slots;

  AppEvent({
    required this.id,
    required this.title,
    this.description,
    required this.eventDate,
    this.eventEnd,
    this.imageUrl,
    this.location,
    this.slots = const [],
  });

  factory AppEvent.fromMap(Map<String, dynamic> map) => AppEvent(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        eventDate: DateTime.parse(map['event_date'] as String).toUtc(),
        eventEnd: map['event_end'] != null 
            ? DateTime.parse(map['event_end'] as String).toUtc() 
            : null,
        imageUrl: map['image_url'] as String?,
        location: map['location'] as String?,
        // Parse nested slots if they exist in the query
        slots: (map['event_slots'] as List?)
                ?.map((s) => AppEventSlot.fromMap(s))
                .toList() ?? [],
      );
}

class AppEventSlot {
  final String? id;
  final String title;
  final int maxSlots;
  final int currentCount; // <--- NEW: Tracks how many are taken

  AppEventSlot({
    this.id, 
    required this.title, 
    required this.maxSlots,
    this.currentCount = 0, // Default to 0
  });

  factory AppEventSlot.fromMap(Map<String, dynamic> map) {
    // Logic to parse Hasura Aggregate
    int count = 0;
    if (map['slot_assignments_aggregate'] != null) {
      final sum = map['slot_assignments_aggregate']?['aggregate']?['sum'];
      if (sum != null && sum['quantity'] != null) {
        count = (sum['quantity'] as num).toInt();
      }
    }

    return AppEventSlot(
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