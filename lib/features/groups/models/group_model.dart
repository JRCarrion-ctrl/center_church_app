import 'group.dart' show decodeSubgroupDescription;

class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? parentGroupId;
  final String? photoUrl;
  final String visibility;
  final bool archived;
  final bool temporary;
  final int unreadCount; // <-- NEW FIELD
  final bool isMuted;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.parentGroupId,
    this.photoUrl,
    this.visibility = 'public',
    this.archived = false,
    this.temporary = false,
    this.unreadCount = 0, // <-- Set default
    this.isMuted = false,
  });

  factory GroupModel.fromMap(Map<String, dynamic> m) {
    final bool muted = (m['is_muted'] as bool?) ?? false;
    final (parentGroupId, description) = decodeSubgroupDescription(m['description'] as String?);

     return GroupModel(
        id: m['id'] as String,
        name: m['name'] as String,
        description: description,
        parentGroupId: parentGroupId,
        photoUrl: m['photo_url'] as String?,
        visibility: (m['visibility'] as String?) ?? 'public',
        archived: (m['archived'] as bool?) ?? false,
        temporary: (m['temporary'] as bool?) ?? false,
        unreadCount: (m['unreadCount'] as int?) ?? 0,
        isMuted: muted,
      );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'photo_url': photoUrl,
        'visibility': visibility,
        'archived': archived,
        'temporary': temporary,
        'is_muted': isMuted,
      };
}
