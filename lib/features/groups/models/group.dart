// file: lib/features/groups/models/group.dart

class Group {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final String visibility;
  final DateTime createdAt;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    required this.visibility,
    required this.createdAt,
  });

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      photoUrl: map['photo_url'] as String?,
      visibility: map['visibility'] as String? ?? 'public',
      createdAt: _parseDate(map['created_at']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    try {
      if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now(); // fallback
    } catch (_) {
      return DateTime.now();
    }
  }
}
