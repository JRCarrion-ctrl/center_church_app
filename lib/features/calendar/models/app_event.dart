// File: lib/features/calendar/models/app_event.dart
class AppEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime eventDate;
  final DateTime? eventEnd;
  final String? imageUrl;
  final String? location;

  AppEvent({
    required this.id,
    required this.title,
    this.description,
    required this.eventDate,
    this.eventEnd,
    this.imageUrl,
    this.location,
  });

  // If you ever decode JSON responses, include location here too.
  factory AppEvent.fromJson(Map<String, dynamic> json) => AppEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        eventDate: DateTime.parse(json['event_date'] as String).toUtc(),
        imageUrl: json['image_url'] as String?,
        location: json['location'] as String?,
      );

  factory AppEvent.fromMap(Map<String, dynamic> map) => AppEvent(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        eventDate: DateTime.parse(map['event_date'] as String).toUtc(),
        eventEnd: map['event_end'] != null 
            ? DateTime.parse(map['event_end'] as String).toUtc() 
            : null,
        imageUrl: map['image_url'] as String?,
        location: map['location'] as String?,          // ensure typed as String?
      );

  /// Use this for inserts/updates so `image_url` is never forgotten.
  Map<String, dynamic> toUpsertMap() => {
        'title': title,
        'description': description,
        'event_date': eventDate.toUtc().toIso8601String(),
        'event_end': eventEnd?.toUtc().toIso8601String(),
        'image_url': imageUrl,
        'location': location,
      };

  AppEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? eventDate,
    String? imageUrl,
    String? location,
  }) {
    return AppEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: eventDate ?? this.eventDate,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
    );
  }
}
