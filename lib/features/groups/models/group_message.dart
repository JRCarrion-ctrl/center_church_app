// File: lib/features/groups/models/group_message.dart

class GroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String? senderName;
  final String content;
  final String? fileUrl;
  final DateTime createdAt;
  final bool deleted;
  final List<String> reportedBy;

  GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    this.senderName,
    required this.content,
    this.fileUrl,
    required this.createdAt,
    required this.deleted,
    required this.reportedBy,
  });

  factory GroupMessage.fromMap(Map<String, dynamic> map) {
    return GroupMessage(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      senderId: map['sender_id'] as String,
      senderName: map['sender_name'] ?? 'Unknown',
      content: map['content'] as String,
      fileUrl: map['file_url'] as String?,
      createdAt: DateTime.parse(map['created_at']),
      deleted: map['deleted'] ?? false,
      reportedBy: (map['reported_by'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'file_url': fileUrl,
      'created_at': createdAt.toIso8601String(),
      'deleted': deleted,
      'reported_by': reportedBy,
    };
  }
}
