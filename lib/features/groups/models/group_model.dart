class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final List<String> memberIds;
  final bool isJoinable;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    this.memberIds = const [],
    this.isJoinable = false,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      photoUrl: map['photo_url'],
      memberIds: List<String>.from(map['member_ids'] ?? []),
      isJoinable: map['is_joinable'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'photo_url': photoUrl,
      'member_ids': memberIds,
      'is_joinable': isJoinable,
    };
  }
}
