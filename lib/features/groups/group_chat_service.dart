// File: lib/features/groups/group_chat_service.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'models/group_message.dart';
import 'package:logger/logger.dart';
import '../auth/oidc_auth.dart';    

/// Chat service backed by Hasura (GraphQL).
class GroupChatService {
  final _logger = Logger();
  GroupChatService(
    this.client, {
    this.getCurrentUserId,
  });

  final GraphQLClient client;
  final String? Function()? getCurrentUserId;

  // ===== GraphQL Fragments =====
  static const _groupMessageFragment = r'''
    fragment GroupMessageFields on group_messages_with_senders {
      id
      group_id
      sender_id
      content
      file_url
      created_at
      deleted
      sender_name
      sender_avatar_url
    }
  ''';

  // ======= Queries =======

  Future<List<GroupMessage>> getMessages(String groupId) async {
    _logger.i('top of getmessages');
    const q = r'''
      query Messages($gid: uuid!) {
        group_messages_with_senders(
          where: { group_id: { _eq: $gid }, deleted: { _eq: false } }
          order_by: { created_at: asc }
        ) {
          ...GroupMessageFields
        }
      }
    ''' + _groupMessageFragment;

    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'gid': groupId}),
    );
    if (res.hasException) throw res.exception!;

    final rows = (res.data?['group_messages_with_senders'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return rows.map(GroupMessage.fromMap).toList();
  }

  Future<List<GroupMessage>> getMessagesPaginated(
  String groupId, {
  required int limit,
  required int offset,
}) async {
  _logger.i('top of getmessagespaginated');
  const q = r'''
    query MessagesPaginated($gid: uuid!, $limit: Int!, $offset: Int!) {
      group_messages_with_senders(
        where: { group_id: { _eq: $gid }, deleted: { _eq: false } }
        order_by: { created_at: asc, id: asc }
        limit: $limit
        offset: $offset
      ) {
        ...GroupMessageFields
      }
    }
  ''' + _groupMessageFragment;
  _logger.i('before final res =');

  final res = await client.query(
    QueryOptions(
      document: gql(q),
      variables: {'gid': groupId, 'limit': limit, 'offset': offset},
    ),
  );
  _logger.i('after final res =');

  dev.log(
    'GraphQL response for getMessagesPaginated: ${res.data}',
    name: 'GQL',
  );
  if (res.hasException) {
    dev.log(
      'GraphQL exception for getMessagesPaginated: ${res.exception}',
      name: 'GQL',
      error: res.exception,
    );
    throw res.exception!;
  }

  final rows = (res.data?['group_messages_with_senders'] as List<dynamic>? ?? [])
      .cast<Map<String, dynamic>>();
  return rows.map(GroupMessage.fromMap).toList();
}

  // ======= Subscriptions =======

  Stream<GroupMessage> streamNewMessages(String groupId, {DateTime? since}) {
    final sinceTs = (since ?? DateTime.now().toUtc()).toIso8601String();
    _logger.i('top of streamnewmessages');

    const s = r'''
      subscription OnMessagesStream($gid: uuid!, $since: timestamptz!, $batch: Int!, $minId: uuid!) {
        group_messages_with_senders_stream(
          batch_size: $batch,
          cursor: { initial_value: { created_at: $since, id: $minId } },
          where: { group_id: { _eq: $gid }, deleted: { _eq: false } },
          order_by: [{ created_at: asc }, { id: asc }]
        ) {
          ...GroupMessageFields
        }
      }
    ''' + _groupMessageFragment;

    _logger.i('before final stream =');

    final stream = client.subscribe(SubscriptionOptions(
      document: gql(s),
      variables: {
        'gid': groupId,
        'since': sinceTs,
        'batch': 50,
        'minId': '00000000-0000-0000-0000-000000000000', // safe floor
      },
    ));

    _logger.i('before stream.expand');

    return stream.expand((result) {
      try {
        if (result.hasException) {
          dev.log('GraphQL subscription exception: ${result.exception}', name: 'GQL');
          return const <GroupMessage>[];
        }

        // Log the raw payload so we can inspect keys/shape
        dev.log('Subscription payload: ${result.data}', name: 'GQL');

        final rows = (result.data?['group_messages_with_senders_stream'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

        dev.log('Received ${rows.length} rows from subscription', name: 'GQL');

        // Defensive mapping: map inside try/catch and log any bad rows
        final mapped = <GroupMessage>[];
        for (final r in rows) {
          try {
            mapped.add(GroupMessage.fromMap(r));
          } catch (e, st) {
           dev.log('Failed to map message row: $r — error: $e', name: 'GQL', stackTrace: st);
          }
        }

        return mapped;
      } catch (e, st) {
        dev.log('Unexpected error in subscription expand: $e', name: 'GQL', stackTrace: st);
        return const <GroupMessage>[];
      }
    });
  }

  // ======= Mutations =======

  Future<void> sendMessage(
    String groupId,
    String content, {
    String? fileUrl,
    String type = 'text',
    DateTime? attachmentUploadedAt,
    DateTime? attachmentExpiresAt,
  }) async {
    dev.log('[GroupChatService] sendMessage start type=$type fileUrl=$fileUrl', name: 'GQL');

    await OidcAuth.refreshIfNeeded();
    final tok = await OidcAuth.readAccessToken();
    dev.log('[GroupChatService] tokenPresent=${tok != null && tok.isNotEmpty}', name: 'GQL');

    const m = r'''
      mutation SendMessage(
        $gid: uuid!,
        $sid: String!,
        $content: String!,
        $type: String!,
        $fileUrl: String,
        $uploadedAt: timestamptz,
        $expiresAt: timestamptz
      ) {
        insert_group_messages_one(object:{
          group_id: $gid,
          sender_id: $sid,
          content: $content,
          type: $type,
          file_url: $fileUrl,
          deleted: false,
          attachment_uploaded_at: $uploadedAt,
          attachment_expires_at: $expiresAt
        }) { id }
      }
    ''';

    final uploadedAtIso = (attachmentUploadedAt ??
            (fileUrl != null ? DateTime.now().toUtc() : null))
        ?.toIso8601String();
    final expiresAtIso = (attachmentExpiresAt ??
            (fileUrl != null ? DateTime.now().toUtc().add(const Duration(days: 30)) : null))
        ?.toIso8601String();

    final sid = getCurrentUserId?.call();
    if (sid == null || sid.isEmpty) {
      throw Exception('User not authenticated');
    }

    final res = await client.mutate(MutationOptions(
      operationName: 'SendMessage',
      document: gql(m),
      variables: {
        'gid': groupId,
        'sid': sid,
        'content': content,
        'type': type,
        'fileUrl': fileUrl,
        'uploadedAt': uploadedAtIso,
        'expiresAt': expiresAtIso,
      },
    ));

    if (res.hasException) throw res.exception!;
    dev.log('[GroupChatService] sendMessage ok id=${res.data?['insert_group_messages_one']?['id']}', name: 'GQL');
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
        group_messages_with_senders_by_pk(id: $id) {
          ...GroupMessageFields
        }
      }
    ''' + _groupMessageFragment;
    final res = await client.query(QueryOptions(
      document: gql(q),
      variables: {'id': id},
    ));
    if (res.hasException) throw res.exception!;
    final row = res.data?['group_messages_with_senders_by_pk'];
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