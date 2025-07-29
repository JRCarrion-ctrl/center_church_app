import 'package:supabase_flutter/supabase_flutter.dart';

class GroupPinService {
  final _client = Supabase.instance.client;

  Future<void> pinMessage(String groupId, String messageId) async {
    if (groupId.isEmpty || messageId.isEmpty) {
      throw ArgumentError('groupId and messageId cannot be empty');
    }

    await _client.rpc('pin_message', params: {
      'group_id': groupId,
      'message_id': messageId,
    });
  }

  Future<void> unpinMessage(String groupId) async {
    if (groupId.isEmpty) {
      throw ArgumentError('groupId cannot be empty');
    }

    await _client.rpc('pin_message', params: {
      'group_id': groupId,
      'message_id': null,
    });
  }
}
