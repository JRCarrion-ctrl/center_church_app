// lib/features/groups/models/group_model.dart
class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final String visibility;      // 'public' | 'request' | 'invite_only'
  final bool archived;          // <- new
  final bool temporary;         // <- optional but useful for nursery DMs

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    this.visibility = 'public',
    this.archived = false,
    this.temporary = false,
  });

  factory GroupModel.fromMap(Map<String, dynamic> m) => GroupModel(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        photoUrl: m['photo_url'] as String?,
        visibility: (m['visibility'] as String?) ?? 'public',
        archived: (m['archived'] as bool?) ?? false,
        temporary: (m['temporary'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'photo_url': photoUrl,
        'visibility': visibility,
        'archived': archived,
        'temporary': temporary,
      };
}
