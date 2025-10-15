// File: lib/features/calendar/event_service.dart
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'models/group_event.dart';
import 'models/app_event.dart';

// Centralize GraphQL queries in a single class for better organization
class _EventQueries {
  // ... (App Event Queries)
  static const appEvents = r'''
    query FetchAppEvents($from: timestamptz!) {
      app_events(
        where: { event_date: { _gte: $from } }
        order_by: { event_date: asc }
      ) {
        id
        title
        description
        image_url
        event_date
        location
      }
    }
  ''';

  static const insertAppEvent = r'''
    mutation InsertAppEvent($title: String!, $description: String, $image_url: String, $event_date: timestamptz!, $location: String) {
      insert_app_events_one(object: {
        title: $title,
        description: $description,
        image_url: $image_url,
        event_date: $event_date,
        location: $location
      }) { id }
    }
  ''';

  static const updateAppEvent = r'''
    mutation UpdateAppEvent($id: uuid!, $title: String!, $description: String, $image_url: String, $event_date: timestamptz!, $location: String) {
      update_app_events_by_pk(pk_columns: {id: $id}, _set: {
        title: $title,
        description: $description,
        image_url: $image_url,
        event_date: $event_date,
        location: $location
      }) { id }
    }
  ''';

  static const deleteAppEvent = r'''
    mutation DeleteAppEvent($id: uuid!) {
      delete_app_events_by_pk(id: $id) { id }
    }
  ''';

  // ... (Group Membership and Event Queries)
  
  // NEW: Query to check a member's role in a specific group
  static const checkGroupMemberRole = r'''
    query MemberRole($gid: uuid!, $uid: String!) {
      group_memberships(
        where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } }
        limit: 1
      ) { role }
    }
  ''' ;

  static const fetchMyUpcomingGroupEvents = r'''
    query FetchMyUpcomingGroupEvents($uid: String!, $from: timestamptz!) {
      group_events(
        where: {
          event_date: { _gte: $from },
          group: {
            group_memberships: {
              user_id: { _eq: $uid },
              status: { _eq: "approved" }
            }
          }
        },
        order_by: { event_date: asc }
      ) {
        id
        group_id
        title
        description
        image_url
        event_date
        location
      }
    }
  ''';


  static const fetchGroupEvents = r'''
    query FetchGroupEvents($groupId: uuid!, $from: timestamptz!) {
      group_events(where: {group_id: {_eq: $groupId}, event_date: {_gte: $from}}, order_by: {event_date: asc}) {
        id
        group_id
        title
        description
        image_url
        event_date
        location
        rsvps_aggregate {
          aggregate {
            sum {
              attending_count
            }
          }
        }
      }
    }
  ''';

  static const fetchAllGroupEvents = r'''
    query FetchAllGroupEvents($groupId: uuid!) {
      group_events(
        where: { group_id: { _eq: $groupId } }
        order_by: { event_date: desc }
      ) {
        id
        group_id
        title
        description
        image_url
        event_date
        location
      }
    }
  ''';

  static const getEventById = r'''
    query GetGroupEventByPk($id: uuid!) {
      group_events_by_pk(id: $id) {
        id
        group_id
        title
        description
        image_url
        event_date
        location
      }
    }
  ''';

  static const insertGroupEvent = r'''
    mutation InsertGroupEvent(
      $group_id: uuid!,
      $title: String!,
      $description: String,
      $image_url: String,
      $event_date: timestamptz!,
      $location: String
    ) {
      insert_group_events_one(object: {
        group_id: $group_id,
        title: $title,
        description: $description,
        image_url: $image_url,
        event_date: $event_date,
        location: $location
      }) { id }
    }
  ''';

  static const updateGroupEvent = r'''
    mutation UpdateGroupEvent(
      $id: uuid!,
      $title: String!,
      $description: String,
      $image_url: String,
      $event_date: timestamptz!,
      $location: String
    ) {
      update_group_events_by_pk(pk_columns: {id: $id}, _set: {
        title: $title,
        description: $description,
        image_url: $image_url,
        event_date: $event_date,
        location: $location
      }) { id }
    }
  ''';

  static const deleteGroupEvent = r'''
    mutation DeleteGroupEvent($id: uuid!) {
      delete_group_events_by_pk(id: $id) { id }
    }
  ''';

  // ... (Group Event RSVP Queries)
  
  static const fetchGroupEventRSVPs = r'''
    query FetchGroupRSVPs($eventId: uuid!) {
      event_attendance(where: {event_id: {_eq: $eventId}}) {
        user_id
        attending_count
        profiles {
          display_name
          email
        }
      }
    }
  ''';

  static const fetchGroupEventRSVPsLite = r'''
    query FetchGroupRSVPsLite($eventId: uuid!) {
      event_attendance(where: {event_id: {_eq: $eventId}}) {
        attending_count
        profiles {
          display_name
          email
        }
      }
    }
  ''';
  
  // NEW: Mutation for Group Event RSVP (Upsert)
  static const upsertGroupRSVP = r'''
    mutation UpsertRSVP($eid: uuid!, $uid: String!, $count: Int!) {
      insert_event_attendance_one(
        object: { event_id: $eid, user_id: $uid, attending_count: $count }
        on_conflict: {
          constraint: unique_event_rsvp
          update_columns: [attending_count]
        }
      ) { event_id }
    }
  ''';
  
  // NEW: Mutation for Group Event RSVP Removal
  static const removeGroupEventRSVP = r'''
    mutation RemoveRSVP($eid: uuid!, $uid: String!) {
      delete_event_attendance(
        where: { event_id: { _eq: $eid }, user_id: { _eq: $uid } }
      ) { affected_rows }
    }
  ''';

  // ... (App Event RSVP Methods)

  static const upsertAppRSVP = r'''
    mutation UpsertAppRSVP($app_event_id: uuid!, $user_id: String!, $attending_count: Int!) { 
      insert_app_event_attendance_one(
        object: { app_event_id: $app_event_id, user_id: $user_id, attending_count: $attending_count }
        on_conflict: {
          constraint: unique_app_rsvp
          update_columns: [attending_count]
        }
      ) { app_event_id }
    }
  ''';

  static const fetchAppEventRSVPs = r'''
    query FetchAppRSVPs($appEventId: uuid!) {
      app_event_attendance(where: {app_event_id: {_eq: $appEventId}}) {
        user_id
        attending_count
        profile {
          display_name
          email
        }
      }
    }
  ''';

  static const removeAppEventRSVP = r'''
    mutation RemoveAppRSVP($appEventId: uuid!, $userId: String!) {
      delete_app_event_attendance(
        where: { app_event_id: { _eq: $appEventId }, user_id: { _eq: $userId } }
      ) {
        affected_rows
      }
    }
  ''';
}

class EventService {
  final GraphQLClient _gql;
  final String? _currentUserId;

  EventService(this._gql, {String? currentUserId}) : _currentUserId = currentUserId;

  DateTime get _startOfTodayUtc {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  Future<bool> isUserAdminInGroup({
    required String groupId,
    required String userId,
  }) async {
    const qRole = r'''
      query MyGroupRole($gid: uuid!, $uid: String!) {
        group_memberships(
          where: {
            group_id: { _eq: $gid },
            user_id: { _eq: $uid },
            status: { _eq: "approved" }
          }
          limit: 1
        ) { role }
      }
    ''';

    try {
      final res = await _gql.query(QueryOptions(
        document: gql(qRole),
        variables: {'gid': groupId, 'uid': userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (res.hasException) {
        return false;
      }

      String? role;
      final rows = (res.data?['group_memberships'] as List?) ?? const [];
      if (rows.isNotEmpty) {
        role = rows.first['role'] as String?;
      }

      const adminRoles = {'admin', 'leader', 'supervisor', 'owner'};
      return adminRoles.contains(role);

    } catch (_) {
      return false;
    }
  }

  // Helper method to handle query boilerplate
  Future<List<T>> _fetchEvents<T>(
    String document,
    String dataKey,
    T Function(Map<String, dynamic>) fromMap,
    Map<String, dynamic> variables,
  ) async {
    try {
      final res = await _gql.query(
        QueryOptions(
          document: gql(document),
          variables: variables,
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (res.hasException) throw res.exception!;
      final list = (res.data?[dataKey] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(fromMap)
          .toList();
      return list;
    } catch (e) {
      debugPrint('Error fetching events: $e');
      rethrow;
    }
  }

  // Helper method to handle mutation boilerplate
  Future<void> _saveEvent(
    String insertDoc,
    String updateDoc,
    Map<String, dynamic> vars,
    bool isNew,
  ) async {
    final doc = gql(isNew ? insertDoc : updateDoc);
    final effectiveVars = isNew ? (Map.of(vars)..remove('id')) : vars;
    
    final res = await _gql.mutate(MutationOptions(document: doc, variables: effectiveVars));
    if (res.hasException) {
      throw Exception('Error saving event: ${res.exception}');
    }
  }

  // ----------------------
  // App-Wide Events
  // ----------------------

  Future<List<AppEvent>> fetchAppEvents() async {
    return _fetchEvents(
      _EventQueries.appEvents,
      'app_events',
      AppEvent.fromMap,
      {'from': _startOfTodayUtc.toIso8601String()},
    );
  }

  Future<void> saveAppEvent(AppEvent event) async {
    final vars = {
      'id': event.id,
      'title': event.title,
      'description': event.description,
      'image_url': event.imageUrl,
      'event_date': event.eventDate.toUtc().toIso8601String(),
      'location': event.location,
    };
    await _saveEvent(
      _EventQueries.insertAppEvent,
      _EventQueries.updateAppEvent,
      vars,
      event.id.isEmpty,
    );
  }

  Future<void> deleteAppEvent(String eventId) async {
    final res = await _gql.mutate(
      MutationOptions(document: gql(_EventQueries.deleteAppEvent), variables: {'id': eventId}),
    );
    if (res.hasException) {
      throw Exception('Error deleting event: ${res.exception}');
    }
  }

  // ----------------------
  // Group Events
  // ----------------------

  // NEW: Method to check group member role
  Future<String> checkGroupMemberRole({
    required String groupId, 
    required String userId,
  }) async {
    final res = await _gql.query(QueryOptions(
      document: gql(_EventQueries.checkGroupMemberRole),
      fetchPolicy: FetchPolicy.noCache,
      variables: {'gid': groupId, 'uid': userId},
    ));
    if (res.hasException) throw res.exception!;
    
    final rows = (res.data?['group_memberships'] as List?) ?? const [];
    // Default role is 'member' if no membership is found
    return rows.isEmpty ? 'member' : (rows.first['role'] as String? ?? 'member');
  }

  Future<List<GroupEvent>> fetchUpcomingGroupEvents() async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not logged in');

    // ✅ Now makes only ONE network call
    return _fetchEvents(
      _EventQueries.fetchMyUpcomingGroupEvents,
      'group_events',
      GroupEvent.fromMap,
      {
        'uid': userId,
        'from': _startOfTodayUtc.toIso8601String(),
      },
    );
  }

  Future<List<GroupEvent>> fetchGroupEvents(String groupId) async {
    return _fetchEvents(
      _EventQueries.fetchGroupEvents,
      'group_events',
      GroupEvent.fromMap,
      {'groupId': groupId, 'from': _startOfTodayUtc.toIso8601String()},
    );
  }

  Future<List<GroupEvent>> fetchAllGroupEvents(String groupId) async {
    return _fetchEvents(
      _EventQueries.fetchAllGroupEvents,
      'group_events',
      GroupEvent.fromMap,
      {'groupId': groupId},
    );
  }

  Future<GroupEvent?> getEventById(String eventId) async {
    final res = await _gql.query(
      QueryOptions(document: gql(_EventQueries.getEventById), variables: {'id': eventId}, fetchPolicy: FetchPolicy.networkOnly),
    );
    if (res.hasException) throw res.exception!;
    final json = res.data?['group_events_by_pk'] as Map<String, dynamic>?;
    return json == null ? null : GroupEvent.fromMap(json);
  }

  Future<void> saveEvent(GroupEvent event) async {
    final vars = {
      'id': event.id,
      'group_id': event.groupId,
      'title': event.title,
      'description': event.description,
      'image_url': event.imageUrl,
      'event_date': event.eventDate.toUtc().toIso8601String(),
      'location': event.location,
    };
    await _saveEvent(
      _EventQueries.insertGroupEvent,
      _EventQueries.updateGroupEvent,
      vars,
      event.id.isEmpty,
    );
  }

  Future<void> deleteEvent(String eventId) async {
    final res = await _gql.mutate(
      MutationOptions(document: gql(_EventQueries.deleteGroupEvent), variables: {'id': eventId}),
    );
    if (res.hasException) {
      throw Exception('Error deleting event: ${res.exception}');
    }
  }

  // ----------------------
  // RSVP Methods
  // ----------------------

  // NEW: Method to handle Group Event RSVP (Upsert)
  Future<void> rsvpGroupEvent({required String eventId, required int count}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not logged in');

    try {
      final res = await _gql.mutate(
        MutationOptions(
          document: gql(_EventQueries.upsertGroupRSVP),
          variables: {
            'eid': eventId,
            'uid': userId,
            'count': count,
          },
        ),
      );
      if (res.hasException) {
        debugPrint('GraphQL Exception on Group RSVP: ${res.exception.toString()}');
        throw Exception('Error saving Group RSVP: ${res.exception}');
      }
    } catch (e) {
      debugPrint('Network/Execution Error on Group RSVP: $e');
      rethrow;
    }
  }

  // NEW: Method to handle Group Event RSVP Removal
  Future<void> removeGroupEventRSVP(String eventId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final res = await _gql.mutate(
      MutationOptions(
        document: gql(_EventQueries.removeGroupEventRSVP),
        variables: {'eid': eventId, 'uid': userId},
      ),
    );
    if (res.hasException) {
      throw Exception('Error deleting Group RSVP: ${res.exception}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchGroupEventRSVPs(String eventId) async {
    final res = await _gql.query(
      QueryOptions(document: gql(_EventQueries.fetchGroupEventRSVPs), variables: {'eventId': eventId}, fetchPolicy: FetchPolicy.networkOnly),
    );
    if (res.hasException) throw res.exception!;
    return (res.data?['event_attendance'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchGroupEventRSVPsLite(String eventId) async {
    final res = await _gql.query(
      QueryOptions(document: gql(_EventQueries.fetchGroupEventRSVPsLite), variables: {'eventId': eventId}, fetchPolicy: FetchPolicy.networkOnly),
    );
    if (res.hasException) throw res.exception!;
    return (res.data?['event_attendance'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }
  
  // ... (App Event RSVP Methods)

  Future<void> rsvpAppEvent({required String appEventId, required int count}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not logged in');

    try {
      final res = await _gql.mutate(
        MutationOptions(
          document: gql(_EventQueries.upsertAppRSVP),
          variables: {
            'app_event_id': appEventId,
            'user_id': userId,
            'attending_count': count,
          },
        ),
      );
      if (res.hasException) {
        // MODIFIED: Print the specific exception details
        debugPrint('GraphQL Exception on RSVP: ${res.exception.toString()}');
        throw Exception('Error saving RSVP: ${res.exception}');
      }
    } catch (e) {
      // MODIFIED: Catch and re-throw, printing the full error object
      debugPrint('Network/Execution Error on RSVP: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAppEventRSVPs(String appEventId) async {
    final res = await _gql.query(
      QueryOptions(
        document: gql(_EventQueries.fetchAppEventRSVPs),
        variables: {'appEventId': appEventId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (res.hasException) throw res.exception!;
    return (res.data?['app_event_attendance'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> removeAppEventRSVP(String appEventId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final res = await _gql.mutate(
      MutationOptions(
        document: gql(_EventQueries.removeAppEventRSVP),
        variables: {'appEventId': appEventId, 'userId': userId},
      ),
    );
    if (res.hasException) {
      throw Exception('Error deleting RSVP: ${res.exception}');
    }
  }
}