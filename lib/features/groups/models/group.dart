// file: lib/features/groups/models/group.dart

class Group {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final String visibility; // public, request, invite_only
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    required this.visibility,
    required this.createdAt,
  });

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      photoUrl: map['photo_url'] as String?,
      visibility: map['visibility'] as String,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'photo_url': photoUrl,
      'visibility': visibility,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
