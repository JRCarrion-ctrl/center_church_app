// File: lib/features/groups/group_pin_service.dart
import 'package:graphql_flutter/graphql_flutter.dart';

class GroupPinService {
  GroupPinService(this.client);

  final GraphQLClient client;

  Future<void> pinMessage(String groupId, String messageId) async {
    if (groupId.isEmpty || messageId.isEmpty) {
      throw ArgumentError('groupId and messageId cannot be empty');
    }

    // Try with id as String!, then fallback to uuid!
    final tries = <MutationOptions>[
      MutationOptions(
        document: gql(_mPin),
        variables: {'gid': groupId, 'mid': messageId},
      ),
    ];

    await _runFirstSuccessful(tries);
  }

  Future<void> unpinMessage(String groupId) async {
    if (groupId.isEmpty) {
      throw ArgumentError('groupId cannot be empty');
    }

    final tries = <MutationOptions>[
      MutationOptions(
        document: gql(_mUnpin),
        variables: {'gid': groupId},
      ),
    ];

    await _runFirstSuccessful(tries);
  }

  Future<void> _runFirstSuccessful(List<MutationOptions> attempts) async {
    OperationException? last;
    for (final opts in attempts) {
      final res = await client.mutate(opts);
      if (!res.hasException) return;
      last = res.exception;
    }
    throw last ?? Exception('Mutation failed');
  }
}

// ----- GraphQL documents -----
const _mPin= r'''
mutation PinMessageUuid($gid: uuid!, $mid: uuid!) {
  update_groups_by_pk(
    pk_columns: { id: $gid }
    _set: { pinned_message_id: $mid }
  ) { id }
}
''';

const _mUnpin = r'''
mutation UnpinMessageUuid($gid: uuid!) {
  update_groups_by_pk(
    pk_columns: { id: $gid }
    _set: { pinned_message_id: null }
  ) { id }
}
''';
