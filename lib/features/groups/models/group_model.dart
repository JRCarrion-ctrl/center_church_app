class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? parentGroupId;
  final String? photoUrl;
  final String visibility;
  final bool archived;
  final bool temporary;
  final int unreadCount;
  final bool isMuted;

  // Newest message, for the chat-list preview (only set by getUserGroups).
  final String? lastMessageText;
  final String? lastMessageType;
  final String? lastMessageSenderId;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.parentGroupId,
    this.photoUrl,
    this.visibility = 'public',
    this.archived = false,
    this.temporary = false,
    this.unreadCount = 0,
    this.isMuted = false,
    this.lastMessageText,
    this.lastMessageType,
    this.lastMessageSenderId,
    this.lastMessageSender,
    this.lastMessageAt,
  });

  factory GroupModel.fromMap(Map<String, dynamic> m) {
    final bool muted = (m['is_muted'] as bool?) ?? false;

    return GroupModel(
      id: m['id'] as String,
      name: m['name'] as String,
      // Read directly from the map, just like the standard Group model
      description: m['description'] as String?,
      parentGroupId: m['parent_group_id'] as String?,
      photoUrl: m['photo_url'] as String?,
      visibility: (m['visibility'] as String?) ?? 'public',
      archived: (m['archived'] as bool?) ?? false,
      temporary: (m['temporary'] as bool?) ?? false,
      unreadCount: (m['unreadCount'] as int?) ?? 0,
      isMuted: muted,
      lastMessageText: m['last_message_text'] as String?,
      lastMessageType: m['last_message_type'] as String?,
      lastMessageSenderId: m['last_message_sender_id'] as String?,
      lastMessageSender: m['last_message_sender'] as String?,
      lastMessageAt: DateTime.tryParse(m['last_message_at'] as String? ?? '')?.toLocal(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'parent_group_id': parentGroupId, // Added to map for consistency
        'photo_url': photoUrl,
        'visibility': visibility,
        'archived': archived,
        'temporary': temporary,
        'is_muted': isMuted,
      };
}