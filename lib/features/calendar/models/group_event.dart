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
  });

  factory GroupEvent.fromMap(Map<String, dynamic> map) {
    // ✅ 2. UPDATE PARSING LOGIC: Safely extract the nested sum.
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
      'location': location,
      // Note: attendingCount is not typically needed in toMap for inserts/updates
    };
  }
}