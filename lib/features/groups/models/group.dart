// file: lib/features/groups/models/group.dart

// Sub-groups have no dedicated parent/child column in the `groups` table, so the
// link is encoded as a hidden tag prefix in the `description` column and decoded
// here on read. `GroupService.encodeSubgroupDescription` is the sole writer.
final RegExp _subgroupTagPattern = RegExp(r'^\[\[subgroup_of:([0-9a-fA-F-]+)\]\]\n?');

/// Splits a raw `description` column value into (parentGroupId, visibleText).
(String?, String?) decodeSubgroupDescription(String? rawDescription) {
  if (rawDescription == null) return (null, null);
  final match = _subgroupTagPattern.firstMatch(rawDescription);
  if (match == null) return (null, rawDescription);
  final parentId = match.group(1);
  final visible = rawDescription.substring(match.end);
  return (parentId, visible.isEmpty ? null : visible);
}

class Group {
  final String id;
  final String name;
  final String? description;
  final String? parentGroupId;
  final String? photoUrl;
  final String visibility;
  final DateTime createdAt;
  final bool onlyAdminsMessage;
  final List<String> languages;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.parentGroupId,
    this.photoUrl,
    required this.visibility,
    required this.createdAt,
    this.onlyAdminsMessage = false,
    this.languages = const ['spanish'],
  });

  factory Group.fromMap(Map<String, dynamic> map) {
    final (parentGroupId, description) = decodeSubgroupDescription(map['description'] as String?);
    return Group(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: description,
      parentGroupId: parentGroupId,
      photoUrl: map['photo_url'] as String?,
      visibility: map['visibility'] as String? ?? 'public',
      createdAt: _parseDate(map['created_at']),
      onlyAdminsMessage: map['only_admins_message'] as bool? ?? false,
      languages: (map['target_audiences'] as List?)?.cast<String>().toList() ?? const ['spanish'],
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
