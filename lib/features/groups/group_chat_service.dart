// File: lib/features/groups/group_chat_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/group_message.dart';

class GroupChatService {
  final _client = Supabase.instance.client;
  final _table = 'group_messages';

  /// Get latest messages
  Future<List<GroupMessage>> getMessages(String groupId) async {
    final data = await _client
        .from(_table)
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: true);

    return (data as List)
        .map((msg) => GroupMessage.fromMap(msg as Map<String, dynamic>))
        .toList();
  }

  /// Send a message
  Future<void> sendMessage(String groupId, String content, {String? fileUrl}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from(_table).insert({
      'group_id': groupId,
      'sender_id': userId,
      'content': content,
      'file_url': fileUrl,
    });
  }

  /// Soft delete message
  Future<void> deleteMessage(String messageId) async {
    await _client.from(_table).update({
      'deleted': true,
    }).eq('id', messageId);
  }

  /// Report message
  Future<void> reportMessage(String messageId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.rpc('report_group_message', params: {
      'msg_id': messageId,
      'uid': userId,
    });
  }

  /// Real-time message stream
  Stream<List<GroupMessage>> streamMessages(String groupId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at')
        .map((data) => data.map(GroupMessage.fromMap).toList());
  }

  Future<void> addReaction(String messageId, String emoji) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client
      .from('message_reactions')
      .upsert({'message_id': messageId, 'user_id': userId, 'emoji': emoji});
  }

  Future<Map<String, List<String>>> getReactions(String groupId) async {
    final data = await Supabase.instance.client
      .from('message_reactions')
      .select('message_id, emoji');

    final Map<String, List<String>> result = {};
    for (final row in data) {
      result.putIfAbsent(row['message_id'], () => []).add(row['emoji']);
    }
    return result;
  }
}
