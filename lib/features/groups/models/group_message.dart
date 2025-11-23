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

  /// A private helper to safely parse nullable UTC date strings.
  static DateTime? _parseUtcDateTime(String? dateString) {
    if (dateString == null) return null;
    return DateTime.parse(dateString).toUtc();
  }

  factory GroupMessage.fromMap(Map<String, dynamic> map) {
    // Handles both the nested 'sender' object from the server
    // and the flat 'sender_name' that might exist in older cached data.
    final senderData = (map['sender'] ?? map['profile']) as Map<String, dynamic>?;
    final senderName = senderData?['display_name'] as String? ?? map['sender_name'] as String?;

    return GroupMessage(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      senderId: map['sender_id'] as String,
      senderName: senderName,
      content: map['content'] as String,
      fileUrl: map['file_url'] as String?,
      createdAt: _parseUtcDateTime(map['created_at'] as String)!,
      deleted: map['deleted'] as bool? ?? false,
      type: map['type'] as String,
      attachmentUploadedAt: _parseUtcDateTime(map['attachment_uploaded_at'] as String?),
      attachmentExpiresAt: _parseUtcDateTime(map['attachment_expires_at'] as String?),
      updatedAt: _parseUtcDateTime(map['updated_at'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'sender_id': senderId,
      // Creates a nested sender object for consistency with the server response.
      'sender': {
        'display_name': senderName,
      },
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

  /// Creates a copy of this message but with the given fields replaced with the new values.
  GroupMessage copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? senderName,
    String? content,
    String? fileUrl,
    DateTime? createdAt,
    bool? deleted,
    String? type,
    DateTime? attachmentUploadedAt,
    DateTime? attachmentExpiresAt,
    DateTime? updatedAt,
  }) {
    return GroupMessage(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      fileUrl: fileUrl ?? this.fileUrl,
      createdAt: createdAt ?? this.createdAt,
      deleted: deleted ?? this.deleted,
      type: type ?? this.type,
      attachmentUploadedAt: attachmentUploadedAt ?? this.attachmentUploadedAt,
      attachmentExpiresAt: attachmentExpiresAt ?? this.attachmentExpiresAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'GroupMessage(id: $id, senderId: $senderId, content: "$content")';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}