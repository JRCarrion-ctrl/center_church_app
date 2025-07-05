// File: lib/features/calendar/models/app_event.dart

class AppEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime eventDate;
  final String? imageUrl;

  AppEvent({
    required this.id,
    required this.title,
    this.description,
    required this.eventDate,
    this.imageUrl,
  });

  factory AppEvent.fromJson(Map<String, dynamic> json) => AppEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        eventDate: DateTime.parse(json['event_date'] as String),
        imageUrl: json['image_url'] as String?,
      );
  
  factory AppEvent.fromMap(Map<String, dynamic> map) {
    return AppEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      eventDate: DateTime.parse(map['event_date'] as String),
    );
  }
}
