// File: lib/features/home/models/group_announcement.dart
class GroupAnnouncement {
  final String id;
  final String groupId;
  final String title;
  final String? body;
  final String? imageUrl;
  final DateTime publishedAt;

  GroupAnnouncement({
    required this.id,
    required this.groupId,
    required this.title,
    this.body,
    this.imageUrl,
    required this.publishedAt,
  });

  factory GroupAnnouncement.fromMap(Map<String, dynamic> map) {
    return GroupAnnouncement(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      title: map['title'] as String,
      body: map['body'] as String?,
      imageUrl: map['image_url'] as String?,
      publishedAt: DateTime.parse(map['published_at'] as String),
    );
  }
}
