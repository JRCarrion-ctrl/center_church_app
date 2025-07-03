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
      id: map['id'],
      groupId: map['group_id'],
      title: map['title'],
      body: map['body'],
      imageUrl: map['image_url'],
      publishedAt: DateTime.parse(map['published_at']),
    );
  }
}
