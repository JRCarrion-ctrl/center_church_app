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
  final String type;
  final DateTime? attachmentUploadedAt;
  final DateTime? attachmentExpiresAt;
  final DateTime? updatedAt;


  GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    this.senderName,
    required this.content,
    this.fileUrl,
    required this.createdAt,
    required this.deleted,
    required this.type,
    this.attachmentUploadedAt,
    this.attachmentExpiresAt,
    this.updatedAt,
  });

  factory GroupMessage.fromMap(Map<String, dynamic> map) {
    // Correctly parse the nested 'sender' object from the GraphQL response
    final sender = map['sender'] as Map<String, dynamic>?;

    return GroupMessage(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      senderId: map['sender_id'] as String,
      senderName: sender?['display_name'] as String?,
      content: map['content'] as String,
      fileUrl: map['file_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      deleted: map['deleted'] as bool? ?? false,
      type: map['type'] as String,
      attachmentUploadedAt: map['attachment_uploaded_at'] != null ? DateTime.parse(map['attachment_uploaded_at'] as String).toUtc() : null,
      attachmentExpiresAt: map['attachment_expires_at'] != null ? DateTime.parse(map['attachment_expires_at'] as String).toUtc() : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String).toUtc() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'sender_id': senderId,
      'sender_name': senderName, // This field is for local caching
      'content': content,
      'file_url': fileUrl,
      'created_at': createdAt.toIso8601String(),
      'deleted': deleted,
      'type': type,
      'attachment_uploaded_at': attachmentUploadedAt?.toIso8601String(),
      'attachment_expires_at': attachmentExpiresAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}