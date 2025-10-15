// file: lib/features/groups/group_service.dart

import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:logger/logger.dart';

import 'models/group.dart';
import 'models/group_model.dart';

final log = Logger();

class GroupArchivedException implements Exception {
  final String groupId;
  const GroupArchivedException(this.groupId);
  @override
  String toString() => 'Group $groupId is archived';
}

class GroupInfoData {
  final Group group;
  final List<Map<String, dynamic>> memberships;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> announcements;
  final List<Map<String, dynamic>> media;
  final Map<String, dynamic>? pinnedMessage;
  // Add other data points as needed

  GroupInfoData({
    required this.group,
    required this.memberships,
    required this.events,
    required this.announcements,
    required this.media,
    this.pinnedMessage,
  });
}

class GroupService {
  final GraphQLClient client;
  GroupService(this.client);

  // ---------- Helpers ----------

  Future<void> _assertGroupActive(String groupId) async {
    const q = r'''
      query IsActive($id: uuid!) {
        groups_by_pk(id: $id) { id archived }
      }
    ''';
    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'id': groupId}),
    );
    if (res.hasException) {
      throw res.exception!;
    }
    final row = res.data?['groups_by_pk'] as Map<String, dynamic>?;
    if (row == null) throw Exception('Group not found');
    if (row['archived'] == true) throw GroupArchivedException(groupId);
  }

  // ---------- Reads ----------

  Future<GroupInfoData> getGroupInfoData(String groupId) async {
    const consolidatedQuery = r'''
      query GetGroupInfoData($groupId: uuid!) {
        groups_by_pk(id: $groupId) {
          id
          name
          description
          photo_url
          visibility
          created_at
          pinned_message_id
          archived
          group_memberships(limit: 5, order_by: {profile: {display_name: asc}}) {
            user_id
            role
            profile {
              display_name
            }
          }
          group_events(limit: 3, order_by: {event_date: asc}) {
            title
            event_date
          }
          group_announcements(limit: 2, order_by: {published_at: desc}) {
            title
            body
            image_url
            published_at
          }
          group_messages(
            where: {file_url: {_is_null: false}},
            order_by: {created_at: desc},
            limit: 6
          ) {
            id
            file_url
            created_at
          }
        }
      }
    ''';
    
    final result = await client.query(QueryOptions(
      document: gql(consolidatedQuery),
      variables: {'groupId': groupId},
      fetchPolicy: FetchPolicy.networkOnly, // Ensures you get fresh data
    ));

    if (result.hasException) {
      throw result.exception!;
    }
    
    final groupData = result.data?['groups_by_pk'];
    if (groupData == null) {
      throw Exception('Group not found');
    }

    // Parse the single, nested response into your new data model
    return GroupInfoData(
      group: Group.fromMap(groupData),
      memberships: List<Map<String, dynamic>>.from(groupData['group_memberships'] ?? []),
      events: List<Map<String, dynamic>>.from(groupData['group_events'] ?? []),
      announcements: List<Map<String, dynamic>>.from(groupData['group_announcements'] ?? []),
      media: List<Map<String, dynamic>>.from(groupData['group_messages'] ?? []),
      pinnedMessage: groupData['pinned_message'],
    );
  }

  Future<Group?> getGroupById(String groupId) async {
    const q = r'''
      query GroupById($id: uuid!) {
        groups_by_pk(id: $id) {
          id
          name
          description
          photo_url
          visibility
          temporary
          archived
          pinned_message_id
          created_at
        }
      }
    ''';
    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'id': groupId}),
    );
    if (res.hasException) {
      debugPrint('getGroupById error: ${res.exception}');
      return null;
    }
    final data = res.data?['groups_by_pk'] as Map<String, dynamic>?;
    return data == null ? null : Group.fromMap(data);
  }

  Future<bool> isUserGroupAdmin(String groupId, String userId) async {
    const q = r'''
      query Role($gid: uuid!, $uid: String!) {
        group_memberships(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid }, status: { _eq: "approved" } }
          limit: 1
        ) { role }
      }
    ''';
    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'gid': groupId, 'uid': userId}),
    );
    if (res.hasException) throw res.exception!;
    final items = (res.data?['group_memberships'] as List<dynamic>? ?? []);
    final role = items.isEmpty ? null : (items.first['role'] as String?);
    return const {'admin', 'leader', 'supervisor', 'owner'}.contains(role);
  }

  Future<bool> isUserGroupOwner(String groupId, String userId) async {
    const q = r'''
      query Role($gid: uuid!, $uid: String!) {
        group_memberships(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid }, status: { _eq: "approved" } }
          limit: 1
        ) { role }
      }
    ''';
    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'gid': groupId, 'uid': userId}),
    );
    if (res.hasException) throw res.exception!;
    final items = (res.data?['group_memberships'] as List<dynamic>? ?? []);
    final role = items.isEmpty ? null : (items.first['role'] as String?);
    return role == 'owner';
  }

  Future<List<GroupModel>> getUserGroups(String userId) async {
    const q = r'''
      query MyGroups($uid: String!) {
        group_memberships(
          where: {
            user_id: { _eq: $uid}
            status: { _eq: "approved" }
            group: { archived: { _eq: false } }
          }
        ) {
          group {
            id
            name
            description
            photo_url
            visibility
            temporary
            archived
            pinned_message_id
            created_at
          }
        }
      }
    ''';
    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'uid': userId}),
    );
    if (res.hasException) throw res.exception!;
    final rows = (res.data?['group_memberships'] as List<dynamic>? ?? []);
    return rows
        .map((e) => e['group']) // Change from 'groups' to 'group'
        .where((g) => g != null)
        .map<GroupModel>((g) => GroupModel.fromMap(Map<String, dynamic>.from(g)))
        .toList();
  }

  Future<List<GroupModel>> getJoinableGroups() async {
    const q = r'''
      query Joinable {
        groups(
          where: {
            archived: { _eq: false }
            visibility: { _in: ["public", "request"] }
          }
        ) {
          id
          name
          description
          photo_url
          visibility
          temporary
          archived
          created_at
        }
      }
    ''';
    final res = await client.query(QueryOptions(document: gql(q)));
    if (res.hasException) throw res.exception!;
    final rows = (res.data?['groups'] as List<dynamic>? ?? []);
    return rows.map((e) => GroupModel.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<GroupModel>> getAdminGroups(String userId) async {
    const q = r'''
      query AdminGroups($uid: String!) {
        group_memberships(
          where: {
            user_id: { _eq: $uid }
            status: { _eq: "approved" }
            role: { _in: ["admin","leader","supervisor","owner"] }
            }
        ) { group_id }
      }
    ''';
    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'uid': userId}),
    );
    if (res.hasException) throw res.exception!;
    final rows = (res.data?['group_memberships'] as List<dynamic>? ?? []);
    return rows
        .map((e) => e['groups'])
        .where((g) => g != null)
        .map<GroupModel>((g) => GroupModel.fromMap(Map<String, dynamic>.from(g)))
        .toList();
  }

  Future<List<GroupModel>> getGroupInvitations(String userId) async {
    const q = r'''
      query Invitations($uid: String!) {
        group_invitations(
          where: {
            user_id: { _eq: $uid }
            status: { _eq: "pending" }
            }
        ) { group_id }
      }
    ''';
    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'uid': userId}),
    );
    if (res.hasException) throw res.exception!;
    final rows = (res.data?['group_invitations'] as List<dynamic>? ?? []);
    return rows
        .map((e) => e['groups'])
        .where((g) => g != null)
        .map<GroupModel>((g) => GroupModel.fromMap(Map<String, dynamic>.from(g)))
        .toList();
  }

  Future<Map<String, dynamic>?> getPinnedMessage(String groupId) async {
    // Get pinned id
    const qGroup = r'''
      query Pinned($id: uuid!) {
        groups_by_pk(id: $id) { pinned_message_id archived }
      }
    ''';
    final g = await client.query(
      QueryOptions(document: gql(qGroup), variables: {'id': groupId}),
    );
    if (g.hasException) throw g.exception!;
    final grp = g.data?['groups_by_pk'];
    if (grp == null) return null;
    final pinnedId = grp['pinned_message_id'];
    if (pinnedId == null) return null;

    const qMsg = r'''
      query PinnedMsg($id: uuid!) {
        group_messages_by_pk(id: $id) {
          content
          sender_id
          created_at
          sender: profiles { display_name }
        }
      }
    ''';
    final m = await client.query(
      QueryOptions(document: gql(qMsg), variables: {'id': pinnedId}),
    );
    if (m.hasException) throw m.exception!;
    final msg = m.data?['group_messages_by_pk'];
    if (msg == null) return null;

    return {
      'content': msg['content'],
      'sender': (msg['sender']?['display_name'] as String?) ?? 'Someone',
      'created_at': msg['created_at'],
    };
  }

  Future<List<Map<String, dynamic>>> getGroupEvents(String groupId) async {
    await _assertGroupActive(groupId);
    const q = r'''
      query Events($gid: uuid!, $now: timestamptz!) {
        events(
          where: { group_id: { _eq: $gid }, event_date: { _gte: $now } }
          order_by: { event_date: asc }
          limit: 3
        ) {
          id
          title
          event_date
          location
          image_url
        }
      }
    ''';
    final res = await client.query(
      QueryOptions(
        document: gql(q),
        variables: {'gid': groupId, 'now': DateTime.now().toUtc().toIso8601String()},
      ),
    );
    if (res.hasException) throw res.exception!;
    return List<Map<String, dynamic>>.from(
      (res.data?['events'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<List<Map<String, dynamic>>> getGroupAnnouncements(String groupId) async {
    await _assertGroupActive(groupId);
    const q = r'''
      query Ann($gid: uuid!, $now: timestamptz!) {
        announcements(
          where: { group_id: { _eq: $gid }, published_at: { _lte: $now } }
          order_by: { published_at: desc }
          limit: 3
        ) { id title body image_url published_at created_at }
      }
    ''';
    final res = await client.query(
      QueryOptions(
        document: gql(q),
        variables: {'gid': groupId, 'now': DateTime.now().toUtc().toIso8601String()},
      ),
    );
    if (res.hasException) throw res.exception!;
    return List<Map<String, dynamic>>.from(
      (res.data?['announcements'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<List<Map<String, dynamic>>> getRecentGroupMedia(
    String groupId, {
    int limit = 6,
  }) async {
    await _assertGroupActive(groupId);
    const q = r'''
      query Media($gid: uuid!, $now: timestamptz!, $limit: Int!) {
        group_messages(
          where: {
            group_id: { _eq: $gid },
            file_url: { _is_null: false },
            attachment_expires_at: { _gt: $now }
          }
          order_by: { created_at: desc }
          limit: $limit
        ) { id file_url created_at }
      }
    ''';
    final res = await client.query(
      QueryOptions(
        document: gql(q),
        variables: {'gid': groupId, 'now': DateTime.now().toUtc().toIso8601String(), 'limit': limit},
      ),
    );
    if (res.hasException) throw res.exception!;
    final rows = (res.data?['group_messages'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    const imageExts = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'};
    return rows.where((msg) {
      final url = (msg['file_url'] as String?)?.toLowerCase();
      if (url == null) return false;
      final path = url.split('?').first;
      final ext = path.split('.').last;
      return imageExts.contains(ext);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    const q = r'''
      query Members($gid: uuid!) {
        group_memberships_summary(
          where: { group_id: { _eq: $gid } },
          order_by: { display_name: asc }
        ) {
          user_id
          role
          display_name
          photo_url
        }
      }
    ''';
    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'gid': groupId}),
    );
    if (res.hasException) throw res.exception!;
    return List<Map<String, dynamic>>.from(
      (res.data?['group_memberships_summary'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    );
  }

  // ---------- Mutations ----------

  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? photoUrl,
  }) async {
    await _assertGroupActive(groupId);
    const m = r'''
      mutation UpdateGroup($id: uuid!, $name: String, $desc: String, $photo: String) {
        update_groups_by_pk(
          pk_columns: { id: $id },
          _set: { name: $name, description: $desc, photo_url: $photo }
        ) { id }
      }
    ''';
    final res = await client.mutate(
      MutationOptions(
        document: gql(m),
        variables: {'id': groupId, 'name': name, 'desc': description, 'photo': photoUrl},
      ),
    );
    if (res.hasException) throw res.exception!;
  }

  Future<void> joinGroup({required String groupId, required String userId}) async {
    await _assertGroupActive(groupId);

    // Fetch group visibility
    const q = r'''
      query GroupLite($id: uuid!) { groups_by_pk(id: $id) { id visibility } }
    ''';
    final g = await client.query(
      QueryOptions(document: gql(q), variables: {'id': groupId}),
    );
    if (g.hasException) throw g.exception!;
    final group = g.data?['groups_by_pk'];
    if (group == null) throw Exception('Group not found');

    final vis = (group['visibility'] as String?) ?? 'invite';

    if (vis == 'public') {
      const m = r'''
        mutation Join($gid: uuid!, $uid: String!) {
          insert_group_memberships_one(object: {
            group_id: $gid,
            user_id: $uid,
            role: "member",
            status: "approved"
          }) { group_id }
        }
      ''';
      final res = await client.mutate(
        MutationOptions(document: gql(m), variables: {'gid': groupId, 'uid': userId}),
      );
      if (res.hasException) throw res.exception!;
    } else if (vis == 'request') {
      // Ensure no duplicate request
      const qReq = r'''
        query Existing($gid: uuid!, $uid: String!) {
          group_requests(where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } }, limit: 1) { user_id }
        }
      ''';
      final ex = await client.query(
        QueryOptions(document: gql(qReq), variables: {'gid': groupId, 'uid': userId}),
      );
      if (ex.hasException) throw ex.exception!;
      final exists = (ex.data?['group_requests'] as List<dynamic>? ?? []).isNotEmpty;
      if (exists) throw Exception('You already requested to join this group.');

      const mReq = r'''
        mutation Request($gid: uuid!, $uid: String!) {
          insert_group_requests_one(object: { group_id: $gid, user_id: $uid }) { group_id }
        }
      ''';
      final ins = await client.mutate(
        MutationOptions(document: gql(mReq), variables: {'gid': groupId, 'uid': userId}),
      );
      if (ins.hasException) throw ins.exception!;
    } else {
      throw Exception('This group is invite only.');
    }
  }

  Future<void> leaveGroup({required String groupId, required String? userId}) async {
    const m = r'''
      mutation Leave($gid: uuid!, $uid: String!) {
        delete_group_memberships(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } }
        ) { affected_rows }
      }
    ''';
    final res = await client.mutate(
      MutationOptions(document: gql(m), variables: {'gid': groupId, 'uid': userId}),
    );
    if (res.hasException) throw res.exception!;
  }

  /// Archive the group (safer than hard delete; server should enforce perms).
  Future<void> deleteGroup(String groupId) async {
    const m = r'''
      mutation Archive($id: uuid!) {
        update_groups_by_pk(pk_columns: { id: $id }, _set: { archived: true }) { id }
      }
    ''';
    final res = await client.mutate(
      MutationOptions(document: gql(m), variables: {'id': groupId}),
    );
    if (res.hasException) throw res.exception!;
  }

  Future<String> getMyGroupRole({required String groupId, required String? userId}) async {
    const q = r'''
      query Role($gid: uuid!, $uid: String!) {
        group_memberships(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } }
          limit: 1
        ) { role }
      }
    ''';
    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'gid': groupId, 'uid': userId}),
    );
    if (res.hasException) throw res.exception!;
    final rows = (res.data?['group_memberships'] as List<dynamic>? ?? []);
    return rows.isEmpty ? 'none' : (rows.first['role'] as String? ?? 'none');
  }

  Future<void> removeMember(String groupId, String userId) async {
    await _assertGroupActive(groupId);
    const m = r'''
      mutation Remove($gid: uuid!, $uid: String!) {
        delete_group_memberships(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } }
        ) { affected_rows }
      }
    ''';
    final res = await client.mutate(
      MutationOptions(document: gql(m), variables: {'gid': groupId, 'uid': userId}),
    );
    if (res.hasException) throw res.exception!;
  }

  Future<void> setMemberRole(String groupId, String userId, String newRole) async {
    await _assertGroupActive(groupId);
    const m = r'''
      mutation Promote($gid: uuid!, $uid: String!, $role: String!) {
        update_group_memberships(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } },
          _set: { role: $role }
        ) { affected_rows }
      }
    ''';
    final res = await client.mutate(
      MutationOptions(
        document: gql(m),
        variables: {'gid': groupId, 'uid': userId, 'role': newRole},
      ),
    );
    if (res.hasException) throw res.exception!;
    log.i('Role updated to "$newRole" for $userId in $groupId');
  }

  Future<List<Map<String, dynamic>>> getPendingMembers(String groupId) async {
    const q = r'''
      query Pending($gid: uuid!) {
        group_memberships(
          where: { group_id: { _eq: $gid }, status: { _eq: "pending" } }
          order_by: { joined_at: asc }
        ) {
          user_id
          role
          status
          profiles { display_name email }
        }
      }
    ''';
    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'gid': groupId}),
    );
    if (res.hasException) throw res.exception!;
    final rows = (res.data?['group_memberships'] as List<dynamic>? ?? []);
    return rows
        .map((e) => {
              'user_id': e['user_id'],
              'role': e['role'],
              'status': e['status'],
              'display_name': e['profiles']?['display_name'],
              'email': e['profiles']?['email'],
            })
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getGroupJoinRequests(String groupId) async {
    const q = r'''
      query Requests($gid: uuid!) {
        group_requests(
          where: { group_id: { _eq: $gid } }
          order_by: { created_at: asc }
        ) {
          user_id
          created_at
          profiles { display_name email photo_url }
        }
      }
    ''';
    final res = await client.query(
      QueryOptions(document: gql(q), variables: {'gid': groupId}),
    );
    if (res.hasException) throw res.exception!;
    final rows = (res.data?['group_requests'] as List<dynamic>? ?? []);
    return rows
        .map((e) => {
              'user_id': e['user_id'],
              'display_name': e['profiles']?['display_name'],
              'photo_url': e['profiles']?['photo_url'],
              'email': e['profiles']?['email'],
              'created_at': e['created_at'],
            })
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> approveMemberRequest(String groupId, String userId) async {
    await _assertGroupActive(groupId);

    // Try to update membership if it exists…
    const mUpdate = r'''
      mutation ApproveUpdate($gid: uuid!, $uid: String!) {
        update_group_memberships(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } },
          _set: { status: "approved", role: "member" }
        ) { affected_rows }
      }
    ''';
    final up = await client.mutate(
      MutationOptions(document: gql(mUpdate), variables: {'gid': groupId, 'uid': userId}),
    );
    if (up.hasException) throw up.exception!;
    final updated = (up.data?['update_group_memberships']?['affected_rows'] as int?) ?? 0;

    if (updated == 0) {
      // …otherwise insert new approved membership.
      const mInsert = r'''
        mutation ApproveInsert($gid: uuid!, $uid: String!) {
          insert_group_memberships_one(object: {
            group_id: $gid, user_id: $uid, role: "member", status: "approved"
          }) { group_id }
        }
      ''';
      final ins = await client.mutate(
        MutationOptions(document: gql(mInsert), variables: {'gid': groupId, 'uid': userId}),
      );
      if (ins.hasException) throw ins.exception!;
    }

    // Remove pending request
    const mDelReq = r'''
      mutation DelReq($gid: uuid!, $uid: String!) {
        delete_group_requests(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } }
        ) { affected_rows }
      }
    ''';
    final del = await client.mutate(
      MutationOptions(document: gql(mDelReq), variables: {'gid': groupId, 'uid': userId}),
    );
    if (del.hasException) throw del.exception!;
  }

  Future<void> denyMemberRequest(String groupId, String userId) async {
    await _assertGroupActive(groupId);
    const m = r'''
      mutation Deny($gid: uuid!, $uid: String!) {
        delete_group_requests(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } }
        ) { affected_rows }
      }
    ''';
    final res = await client.mutate(
      MutationOptions(document: gql(m), variables: {'gid': groupId, 'uid': userId}),
    );
    if (res.hasException) throw res.exception!;
  }
}
