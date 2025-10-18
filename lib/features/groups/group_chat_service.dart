// File: lib/features/groups/group_chat_service.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:logger/logger.dart';

import 'models/group_message.dart';
import '../auth/oidc_auth.dart';

/// Chat service backed by Hasura (GraphQL).
class GroupChatService {
  final _logger = Logger();
  final GraphQLClient client;
  final String? Function()? getCurrentUserId;

  GroupChatService(this.client, {this.getCurrentUserId});

  // ===== GraphQL Fragments =====
  static const _groupMessageFragment = r'''
    fragment GroupMessageFields on group_messages {
      id
      group_id
      sender_id
      content
      file_url
      created_at
      deleted
      type
      profile {
        display_name
        photo_url
      }
    }
  ''';

  static const _memberMetadataFragment = r'''
    fragment MemberMetadataFields on group_member_metadata {
      user_id
      group_id
      last_seen
      last_typed
      updated_at
      profile {
        display_name
        photo_url
      }
    }
  ''';

  // ======= Queries =======

  /// ✅ FIX: Added optional `upTo` parameter to prevent race condition.
  Future<List<GroupMessage>> getMessagesPaginated({
    required String groupId,
    required int limit,
    required int offset,
    DateTime? upTo,
  }) async {
    // ✅ FIX: Use a static query string for better performance and caching.
    // The 'where' clause is now handled by a single variable, '$where'.
    const q = r'''
      query MessagesPaginated($where: group_messages_bool_exp!, $limit: Int!, $offset: Int!) {
        group_messages(
          where: $where
          order_by: { created_at: desc }
          limit: $limit
          offset: $offset
        ) {
          ...GroupMessageFields
        }
      }
    ''' +
        _groupMessageFragment;

    // ✅ FIX: Build a dynamic 'where' object for the variables map.
    // This is safer and more maintainable than building a string.
    final Map<String, dynamic> where = {
      'group_id': {'_eq': groupId},
      'deleted': {'_eq': false},
    };

    if (upTo != null) {
      where['created_at'] = {'_lte': upTo.toIso8601String()};
    }

    final res = await client.query(QueryOptions(
      document: gql(q),
      variables: {
        'where': where,
        'limit': limit,
        'offset': offset,
      },
    ));

    if (res.hasException) {
      _logger.e('GraphQL query failed', error: res.exception);
      throw res.exception!;
    }

    final rows = (res.data?['group_messages'] as List<dynamic>? ?? []);
    final List<GroupMessage> messages = [];
    for (final row in rows) {
      try {
        if (row is Map<String, dynamic>) {
          messages.add(GroupMessage.fromMap(row));
        }
      } catch (e, st) {
        _logger.e(
          'Failed to parse a message object',
          error: 'Error: $e, Data: $row',
          stackTrace: st,
        );
      }
    }
    _logger.i('Successfully parsed ${messages.length} of ${rows.length} messages.');
    return messages;
  }

  // ======= Subscriptions =======

  Stream<List<GroupMessage>> streamNewMessages({
    required String groupId,
    required DateTime since,
  }) {
    final sinceTs = since.toIso8601String();
    dev.log('[STREAM] Subscribing to new messages for group $groupId since: $sinceTs');

    // This subscription fetches any messages created after the 'since' timestamp.
    const s = r'''
      subscription OnNewMessage($gid: uuid!, $since: timestamptz!) {
        group_messages(
          where: {
            group_id: { _eq: $gid },
            created_at: { _gt: $since },
            deleted: { _eq: false }
          },
          # ✅ FIX: Order descending to match paginated query and simplify client logic.
          order_by: { created_at: desc }
        ) {
          ...GroupMessageFields
        }
      }
    ''' +
        _groupMessageFragment;

    final stream = client.subscribe(SubscriptionOptions(
      document: gql(s),
      variables: {'gid': groupId, 'since': sinceTs},
    ));

    return stream.map((result) {
      if (result.hasException) {
        dev.log('[STREAM] Subscription GraphQL error', error: result.exception);
        return <GroupMessage>[];
      }

      final rows = (result.data?['group_messages'] as List<dynamic>? ?? []);
      if (rows.isEmpty) return <GroupMessage>[];

      final List<GroupMessage> messages = [];
      for (final row in rows) {
        try {
          if (row is Map<String, dynamic>) {
            messages.add(GroupMessage.fromMap(row));
          }
        } catch (e, st) {
          dev.log('[STREAM] Failed to parse message from stream', error: e, stackTrace: st);
        }
      }
      return messages;
    });
  }

  Stream<List<Map<String, dynamic>>> streamMemberMetadata({required String groupId}) {
    const s = r'''
      subscription MemberStatuses($gid: uuid!) {
        group_member_metadata(
          where: { group_id: { _eq: $gid } }
          # Order by update time to get the most recent activity first
          order_by: { updated_at: desc } 
        ) {
          ...MemberMetadataFields
        }
      }
    ''' +
        _memberMetadataFragment;

    final stream = client.subscribe(SubscriptionOptions(
      document: gql(s),
      variables: {'gid': groupId},
    ));

    return stream.map((result) {
      if (result.hasException) {
        dev.log('[STREAM] Member metadata subscription error', error: result.exception);
        return <Map<String, dynamic>>[];
      }
      final rows = (result.data?['group_member_metadata'] as List<dynamic>? ?? []);
      
      // We return the raw map data here; mapping to a dedicated model is optional
      return rows.cast<Map<String, dynamic>>();
    });
  }

  // ======= Mutations =======

  /// Sends a message and returns the created message object for optimistic UI updates.
  Future<GroupMessage?> sendMessage(
    String groupId,
    String content, {
    String? fileUrl,
    String type = 'text',
  }) async {
    await OidcAuth.refreshIfNeeded();

    const m = r'''
      mutation SendMessage($gid: uuid!, $sid: String!, $content: String!, $type: String!, $fileUrl: String) {
        insert_group_messages_one(object: {
          group_id: $gid,
          sender_id: $sid,
          content: $content,
          type: $type,
          file_url: $fileUrl
        }) {
          ...GroupMessageFields
        }
      }
    ''' +
        _groupMessageFragment;

    final sid = getCurrentUserId?.call();
    if (sid == null || sid.isEmpty) throw Exception('User not authenticated');

    final res = await client.mutate(MutationOptions(
      document: gql(m),
      variables: {'gid': groupId, 'sid': sid, 'content': content, 'type': type, 'fileUrl': fileUrl},
    ));

    if (res.hasException) {
      _logger.e('Failed to send message', error: res.exception);
      throw res.exception!;
    }

    final data = res.data?['insert_group_messages_one'];
    if (data == null) return null;

    return GroupMessage.fromMap(data as Map<String, dynamic>);
  }

  Future<void> updateLastSeen(String groupId) async {
    final sid = getCurrentUserId?.call();
    if (sid == null || sid.isEmpty) return;

    // Use Hasura's built-in "now()" for the timestamp.
    const m = r'''
      mutation UpsertLastSeen($gid: uuid!, $uid: String!) {
        insert_group_member_metadata_one(
          object: {
            group_id: $gid,
            user_id: $uid,
            last_seen: "now()"
          },
          on_conflict: {
            constraint: group_member_metadata_pkey,
            update_columns: [last_seen]
          }
        ) { user_id }
      }
    ''';
    
    // We don't need to refresh OIDC for this frequent, non-critical mutation.
    final res = await client.mutate(MutationOptions(
      document: gql(m),
      variables: {'gid': groupId, 'uid': sid},
    ));
    if (res.hasException) {
      _logger.w('Failed to update last_seen for $sid in $groupId: ${res.exception}');
      // Do not throw, as this is a background status update.
    }
  }

  Future<void> updateLastTyped(String groupId, {required bool isTyping}) async {
    final sid = getCurrentUserId?.call();
    if (sid == null || sid.isEmpty) return;
    
    // 1. Prepare the value for last_typed (timestamp or null)
    final String? typedValue = isTyping 
        ? DateTime.now().toUtc().toIso8601String() 
        : null;
    
    // 2. Use a single upsert mutation. We rely on the JSON variable to handle the null value.
    const m = r'''
      mutation UpsertLastTyped($gid: uuid!, $uid: String!, $typed: timestamptz) {
        insert_group_member_metadata_one(
          object: {
            group_id: $gid,
            user_id: $uid,
            last_seen: "now()",
            last_typed: $typed # Use the variable, which handles null
          },
          on_conflict: {
            constraint: group_member_metadata_pkey,
            update_columns: [last_seen, last_typed] 
          }
        ) { user_id }
      }
    ''';
    
    final res = await client.mutate(MutationOptions(
      document: gql(m),
      variables: {
        'gid': groupId, 
        'uid': sid,
        'typed': typedValue, // Passed as String (timestamp) or null
      },
    ));
    if (res.hasException) {
      _logger.w('Failed to update last_typed for $sid in $groupId: ${res.exception}');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    const m = r'''
      mutation SoftDelete($id: uuid!) {
        update_group_messages_by_pk(
          pk_columns: { id: $id },
          _set: { deleted: true }
        ) { id }
      }
    ''';
    final res = await client.mutate(
      MutationOptions(document: gql(m), variables: {'id': messageId}),
    );
    if (res.hasException) throw res.exception!;
  }

  Future<void> reportMessage(String messageId) async {
    final uid = getCurrentUserId?.call();
    if (uid == null || uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    const mFn = r'''
      mutation Report($msgId: uuid!, $uid: String!) {
        report_group_message(args: { msg_id: $msgId, uid: $uid })
      }
    ''';

    final res = await client.mutate(
      MutationOptions(document: gql(mFn), variables: {'msgId': messageId, 'uid': uid}),
    );

    if (res.hasException) throw res.exception!;
  }

  Future<void> addReaction(String messageId, String emoji) async {
    final uid = getCurrentUserId?.call();
    if (uid == null || uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    const m = r'''
      mutation React($mid: uuid!, $uid: String!, $emoji: String!) {
        delete_message_reactions(
          where: { message_id: { _eq: $mid }, user_id: { _eq: $uid } }
        ) { affected_rows }
        insert_message_reactions_one(
          object: { message_id: $mid, user_id: $uid, emoji: $emoji }
        ) { message_id }
      }
    ''';

    final res = await client.mutate(MutationOptions(
      document: gql(m),
      variables: {'mid': messageId, 'uid': uid, 'emoji': emoji},
    ));
    if (res.hasException) throw res.exception!;
  }

  Future<GroupMessage?> getMessageById(String id) async {
    const q = r'''
      query One($id: uuid!) {
        group_messages_by_pk(id: $id) {
          ...GroupMessageFields
        }
      }
    ''' +
        _groupMessageFragment;
    final res = await client.query(QueryOptions(
      document: gql(q),
      variables: {'id': id},
    ));
    if (res.hasException) throw res.exception!;
    final row = res.data?['group_messages_by_pk'];
    return row == null ? null : GroupMessage.fromMap(row as Map<String, dynamic>);
  }

  Future<Map<String, List<String>>> getReactions(String groupId) async {
    const q = r'''
      query Reactions($gid: uuid!) {
        message_reactions(
          where: { message: { group_id: { _eq: $gid } } }
        ) {
          message_id
          emoji
        }
      }
    ''';

    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'gid': groupId}),
    );
    if (res.hasException) throw res.exception!;

    final map = <String, List<String>>{};
    final rows =
        (res.data?['message_reactions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    for (final r in rows) {
      final mid = r['message_id'] as String;
      final emoji = r['emoji'] as String;
      (map[mid] ??= []).add(emoji);
    }
    return map;
  }
}