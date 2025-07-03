// file: lib/features/groups/models/group_invitation.dart

import 'group.dart';

class GroupInvitation {
  final String id;
  final String groupId;
  final String userId;
  final String? note;
  final String status;
  final DateTime createdAt;

  /// Optional: populate with embedded group if available
  final Group? group;

  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.userId,
    this.note,
    required this.status,
    required this.createdAt,
    this.group,
  });

  factory GroupInvitation.fromMap(Map<String, dynamic> map) {
    return GroupInvitation(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      userId: map['user_id'] as String,
      note: map['note'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at']),
      group: map['groups'] != null ? Group.fromMap(map['groups']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'note': note,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
