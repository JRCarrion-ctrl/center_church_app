// File: lib/features/home/announcement_service.dart
import 'package:graphql_flutter/graphql_flutter.dart';
import 'models/group_announcement.dart';

class AnnouncementService {
  final GraphQLClient _gql;
  final String? _currentUserId;

  AnnouncementService(this._gql, {String? currentUserId})
      : _currentUserId = currentUserId;

  /// Fetch announcements for groups the user is in.
  /// [onlyPublished] filters out announcements scheduled for the future.
  Future<List<GroupAnnouncement>> fetchGroupAnnouncements({bool onlyPublished = false}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    // 1) Get approved group memberships → group_ids
    const qMemberships = r'''
      query MyApprovedMemberships($uid: String!) {
        group_memberships(where: {user_id: {_eq: $uid}, status: {_eq: "approved"}}) {
          group_id
        }
      }
    ''';

    final res1 = await _gql.query(
      QueryOptions(
        document: gql(qMemberships),
        variables: {'uid': userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (res1.hasException) throw res1.exception!;
    final groupIds = (res1.data?['group_memberships'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>) // Cast to Map
        .where((e) => e.containsKey('group_id') && e['group_id'] is String) // Filter for valid keys and types
        .map((e) => e['group_id'] as String) // Safely map to String
        .toSet();
    if (groupIds.isEmpty) return [];

    // 2) Fetch announcements for those groups (optionally only published)
    final qAnnouncements = onlyPublished ? _qAnnouncementsPublished : _qAnnouncementsAll;

    final vars = {
      'groupIds': groupIds.toList(),
      if (onlyPublished) 'now': DateTime.now().toUtc().toIso8601String(),
    };

    final res2 = await _gql.query(
      QueryOptions(
        document: gql(qAnnouncements),
        variables: vars,
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (res2.hasException) throw res2.exception!;

    final rows = (res2.data?['announcements'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return rows.map(GroupAnnouncement.fromMap).toList();
  }

  // Query: all announcements for given groupIds
  static const _qAnnouncementsAll = r'''
    query AnnouncementsAll($groupIds: [uuid!]!) {
      announcements(
        where: { group_id: { _in: $groupIds } }
        order_by: { published_at: desc }
      ) {
        id
        group_id
        title
        body
        image_url
        published_at
      }
    }
  ''';

  // Query: only announcements with published_at <= now
  static const _qAnnouncementsPublished = r'''
    query AnnouncementsPublished($groupIds: [uuid!]!, $now: timestamptz!) {
      announcements(
        where: { 
          group_id: { _in: $groupIds },
          published_at: { _lte: $now }
        }
        order_by: { published_at: desc }
      ) {
        id
        group_id
        title
        body
        image_url
        published_at
      }
    }
  ''';
}
