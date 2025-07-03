import 'package:supabase_flutter/supabase_flutter.dart';

class DeletionRequestService {
  final supabase = Supabase.instance.client;

  /// Submit a deletion request (if one doesn’t already exist)
  Future<void> requestDeletion({
    required String groupId,
    required String userId,
    required String reason,
  }) async {
    final existing = await supabase
        .from('group_deletion_requests')
        .select()
        .eq('group_id', groupId)
        .eq('status', 'pending')
        .maybeSingle();

    if (existing != null) {
      throw Exception('A deletion request is already pending.');
    }

    await supabase.from('group_deletion_requests').insert({
      'group_id': groupId,
      'user_id': userId,
      'reason': reason,
    });
  }
}
