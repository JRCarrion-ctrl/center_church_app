// File: lib/features/groups/models/group_announcement.dart
class GroupAnnouncement {
  final String id;
  final String groupId;
  final String title;
  final String? body;
  final String? createdByName;
  final String? imageUrl;
  final DateTime? publishedAt;
  final DateTime? createdAt;

  GroupAnnouncement({
    required this.id,
    required this.groupId,
    required this.title,
    this.body,
    this.imageUrl,
    this.publishedAt,
    this.createdAt,
    this.createdByName
  });

  factory GroupAnnouncement.fromMap(Map<String, dynamic> map) {
    return GroupAnnouncement(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      title: map['title'] ?? '',
      body: map['body'],
      imageUrl: map['image_url'],
      publishedAt: map['published_at'] != null
          ? DateTime.parse(map['published_at'])
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      createdByName: map['profiles']?['display_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'published_at': publishedAt?.toUtc().toIso8601String(),
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }
}
