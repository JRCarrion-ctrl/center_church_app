// File: lib/features/calendar/models/group_event.dart
class GroupEvent {
  final String id;
  final String groupId;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime eventDate;
  final String? location;

  GroupEvent({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    this.imageUrl,
    required this.eventDate,
    this.location,
  });

  factory GroupEvent.fromMap(Map<String, dynamic> map) {
    return GroupEvent(
      id: map['id'],
      groupId: map['group_id'],
      title: map['title'],
      description: map['description'],
      imageUrl: map['image_url'] as String?,
      eventDate: DateTime.parse(map['event_date']).toUtc(),
      location: map['location'],
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
    };
  }
}
