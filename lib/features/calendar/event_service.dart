// File: lib/features/calendar/event_service.dart
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'models/group_event.dart';
import 'models/app_event.dart';

class _EventQueries {
  // ... [Keep existing App Event Queries: appEvents, insertAppEvent, etc.] ...
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
        event_end
        location
      }
    }
  ''';
  
  static const insertAppEvent = r'''
    mutation InsertAppEvent($title: String!, $description: String, $image_url: String, $event_date: timestamptz!, $event_end: timestamptz, $location: String) {
      insert_app_events_one(object: {
        title: $title,
        description: $description,
        image_url: $image_url,
        event_date: $event_date,
        event_end: $event_end,
        location: $location
      }) { id }
    }
  ''';

  static const updateAppEvent = r'''
    mutation UpdateAppEvent($id: uuid!, $title: String!, $description: String, $image_url: String, $event_date: timestamptz!, $event_end: timestamptz, $location: String) {
      update_app_events_by_pk(pk_columns: {id: $id}, _set: {
        title: $title,
        description: $description,
        image_url: $image_url,
        event_date: $event_date,
        event_end: $event_end,
        location: $location
      }) { id }
    }
  ''';

  static const deleteAppEvent = r'''
    mutation DeleteAppEvent($id: uuid!) {
      delete_app_events_by_pk(id: $id) { id }
    }
  ''';

  // ... [Keep Slot Fetch Queries] ...
  static const fetchAppEventSlots = r'''
    query FetchAppEventSlots($eventId: uuid!) {
      event_slots(where: {app_event_id: {_eq: $eventId}}, order_by: {title: asc}) {
        id
        title
        max_slots
        slot_assignments_aggregate {
          aggregate {
            sum { quantity }
          }
        }
      }
    }
  ''';

  static const fetchGroupEventSlots = r'''
    query FetchGroupEventSlots($eventId: uuid!) {
      event_slots(where: {group_event_id: {_eq: $eventId}}, order_by: {title: asc}) {
        id
        title
        max_slots
        slot_assignments_aggregate {
          aggregate {
            sum { quantity }
          }
        }
      }
    }
  ''';

  // --- NEW: Delete Slots Mutation ---
  static const deleteEventSlots = r'''
    mutation DeleteEventSlots($ids: [uuid!]!) {
      delete_event_slots(where: {id: {_in: $ids}}) {
        affected_rows
      }
    }
  ''';

  static const upsertEventSlots = r'''
    mutation UpsertEventSlots($objects: [event_slots_insert_input!]!) {
      insert_event_slots(
        objects: $objects,
        on_conflict: {
          constraint: event_slots_pkey,
          update_columns: [title, max_slots]
        }
      ) {
        affected_rows
      }
    }
  ''';

  // ... [Keep the rest of the queries: insertWithSlots, group queries, RSVP, etc.] ...
  static const insertAppEventWithSlots = r'''
    mutation InsertAppEventWithSlots($object: app_events_insert_input!) {
      insert_app_events_one(object: $object) { id }
    }
  ''';

  static const insertGroupEventWithSlots = r'''
    mutation InsertGroupEventWithSlots($object: group_events_insert_input!) {
      insert_group_events_one(object: $object) { id }
    }
  ''';
  
  // [Insert other existing queries here: checkGroupMemberRole, fetchMyUpcomingGroupEvents, etc.]
  // (Assuming you have the previous file's content, I am abbreviating purely to save space, 
  // ensure you keep all other queries from the previous step)
  static const checkGroupMemberRole = r'''
    query MemberRole($gid: uuid!, $uid: String!) {
      group_memberships(
        where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } }
        limit: 1
      ) { role }
    }
  ''';
  // ... etc ...
  static const fetchUserAssignments = r'''
    query FetchUserAssignments($slotIds: [uuid!]!, $userId: String!) {
      slot_assignments(where: {
        user_id: {_eq: $userId},
        slot_id: {_in: $slotIds}
      }) {
        slot_id
        quantity
      }
    }
  ''';
  
  static const unclaimSlot = r'''
    mutation UnclaimSlot($slotId: uuid!, $userId: String!) {
      delete_slot_assignments(where: {
        slot_id: {_eq: $slotId},
        user_id: {_eq: $userId}
      }) {
        affected_rows
      }
    }
  ''';
  static const claimSlot = r'''
    mutation ClaimSlot($slotId: uuid!, $userId: String!, $quantity: Int!) {
      insert_slot_assignments_one(
        object: { slot_id: $slotId, user_id: $userId, quantity: $quantity }
        on_conflict: {
          constraint: unique_slot_assignment,
          update_columns: [quantity]
        }
      ) { id }
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
        event_end
        location
        group { name }
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
        event_end
        location
        group { name }
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
        event_end
        location
        group { name }
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
      $event_end: timestamptz,
      $location: String
    ) {
      insert_group_events_one(object: {
        group_id: $group_id,
        title: $title,
        description: $description,
        image_url: $image_url,
        event_date: $event_date,
        event_end: $event_end,
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
      $event_end: timestamptz,
      $location: String
    ) {
      update_group_events_by_pk(pk_columns: {id: $id}, _set: {
        title: $title,
        description: $description,
        image_url: $image_url,
        event_date: $event_date,
        event_end: $event_end,
        location: $location
      }) { id }
    }
  ''';
  static const deleteGroupEvent = r'''
    mutation DeleteGroupEvent($id: uuid!) {
      delete_group_events_by_pk(id: $id) { id }
    }
  ''';
  static const fetchGroupEventRSVPs = r'''
    query FetchGroupRSVPs($eventId: uuid!) {
      event_attendance(where: {event_id: {_eq: $eventId}}) {
        user_id
        attending_count
        profiles {
          display_name
          email
          photo_url
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
          photo_url
        }
      }
    }
  ''';
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
  static const removeGroupEventRSVP = r'''
    mutation RemoveRSVP($eid: uuid!, $uid: String!) {
      delete_event_attendance(
        where: { event_id: { _eq: $eid }, user_id: { _eq: $uid } }
      ) { affected_rows }
    }
  ''';
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
          photo_url
        }
      }
    }
  ''';
  static const removeAppEventRSVP = r'''
    mutation RemoveAppRSVP($app_event_id: uuid!, $user_id: String!) {
      delete_app_event_attendance(
        where: { app_event_id: { _eq: $app_event_id }, user_id: { _eq: $user_id } }
      ) {
        affected_rows
      }
    }
  ''';
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
        event_end
        location
        group { name }
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

  // ... [Keep helpers] ...
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

  Future<void> _saveEvent(
    String insertDoc,
    String updateDoc,
    Map<String, dynamic> vars,
    bool isNew,
  ) async {
    final doc = gql(isNew ? insertDoc : updateDoc);
    final effectiveVars = Map<String, dynamic>.from(vars);
    if (isNew) effectiveVars.remove('id');
  
    final res = await _gql.mutate(MutationOptions(
      document: doc, 
      variables: effectiveVars,
      fetchPolicy: FetchPolicy.noCache,
    ));
  
    if (res.hasException) {
      debugPrint('GraphQL Error Details: ${res.exception.toString()}');
      throw Exception('Error saving event: ${res.exception}');
    }
  }

  Future<void> _upsertSlots(List<Map<String, dynamic>> slotsData) async {
    if (slotsData.isEmpty) return;
    final res = await _gql.mutate(MutationOptions(
      document: gql(_EventQueries.upsertEventSlots),
      variables: {'objects': slotsData},
      fetchPolicy: FetchPolicy.noCache,
    ));
    if (res.hasException) throw Exception('Error upserting slots: ${res.exception}');
  }

  // --- NEW: Delete Helper ---
  Future<void> _deleteSlots(List<String> idsToDelete) async {
    if (idsToDelete.isEmpty) return;
    final res = await _gql.mutate(MutationOptions(
      document: gql(_EventQueries.deleteEventSlots),
      variables: {'ids': idsToDelete},
      fetchPolicy: FetchPolicy.noCache,
    ));
    if (res.hasException) throw Exception('Error deleting slots: ${res.exception}');
  }

  // ... [Keep App Event Methods] ...
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
      'event_end': event.eventEnd?.toUtc().toIso8601String(),
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
      MutationOptions(
        document: gql(_EventQueries.deleteAppEvent),
        variables: {'id': eventId},
      ),
    );
    if (res.hasException) throw Exception('Error deleting event: ${res.exception}');
  }

  // >>> UPDATED LOGIC for APP EVENTS <<<
  Future<void> saveAppEventWithSlots(AppEvent event, List<AppEventSlot> slots) async {
    final isNew = event.id.isEmpty;
    if (isNew) {
      // Create New logic (Nested Insert) - untouched
      final vars = {
        'object': {
          'title': event.title,
          'description': event.description,
          'image_url': event.imageUrl,
          'event_date': event.eventDate.toUtc().toIso8601String(),
          'event_end': event.eventEnd?.toUtc().toIso8601String(),
          'location': event.location,
          'event_slots': {
            'data': slots.map((s) => s.toUpsertMap()).toList()
          }
        }
      };
      final res = await _gql.mutate(MutationOptions(
        document: gql(_EventQueries.insertAppEventWithSlots),
        variables: vars,
        fetchPolicy: FetchPolicy.noCache,
      ));
      if (res.hasException) throw Exception('Error saving event: ${res.exception}');
    } else {
      // 1. Update the Event details
      await saveAppEvent(event);
      
      // 2. Fetch existing slots from DB
      final existingSlots = await fetchAppEventSlots(event.id);
      final dbIds = existingSlots.map((s) => s.id).whereType<String>().toSet();
      
      // 3. Identify UI IDs
      final uiIds = slots.map((s) => s.id).whereType<String>().toSet();
      
      // 4. Determine deletions (In DB but not in UI)
      final idsToDelete = dbIds.difference(uiIds).toList();
      if (idsToDelete.isNotEmpty) {
        await _deleteSlots(idsToDelete);
      }

      // 5. Upsert remaining (Updates + Inserts)
      if (slots.isNotEmpty) {
        final slotsPayload = slots.map((s) {
          final map = s.toUpsertMap();
          map['app_event_id'] = event.id;
          // IMPORTANT: If id exists, include it to force Update. If null, exclude it to force Insert.
          if (s.id != null) {
            map['id'] = s.id;
          } else {
            map.remove('id');
          }
          return map;
        }).toList();
        await _upsertSlots(slotsPayload);
      }
    }
  }

  // ... [Keep Group Helpers] ...
  Future<bool> isUserAdminInGroup({required String groupId, required String userId}) async {
    // [Same as before]
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
      if (res.hasException) return false;
      String? role;
      final rows = (res.data?['group_memberships'] as List?) ?? const [];
      if (rows.isNotEmpty) role = rows.first['role'] as String?;
      const adminRoles = {'admin', 'leader', 'supervisor', 'owner'};
      return adminRoles.contains(role);
    } catch (_) {
      return false;
    }
  }

  Future<String> checkGroupMemberRole({required String groupId, required String userId}) async {
    final res = await _gql.query(QueryOptions(
      document: gql(_EventQueries.checkGroupMemberRole),
      fetchPolicy: FetchPolicy.noCache,
      variables: {'gid': groupId, 'uid': userId},
    ));
    if (res.hasException) throw res.exception!;
    final rows = (res.data?['group_memberships'] as List?) ?? const [];
    return rows.isEmpty ? 'member' : (rows.first['role'] as String? ?? 'member');
  }

  Future<List<GroupEvent>> fetchUpcomingGroupEvents() async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not logged in');
    return _fetchEvents(
      _EventQueries.fetchMyUpcomingGroupEvents,
      'group_events',
      GroupEvent.fromMap,
      {'uid': userId, 'from': _startOfTodayUtc.toIso8601String()},
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
    final isNew = event.id.isEmpty;
    final vars = {
      'id': event.id,
      'group_id': event.groupId,
      'title': event.title,
      'description': event.description,
      'image_url': event.imageUrl,
      'event_date': event.eventDate.toUtc().toIso8601String(),
      'event_end': event.eventEnd?.toUtc().toIso8601String(),
      'location': event.location,
    };
    if (!isNew) vars.remove('group_id');
    await _saveEvent(
      _EventQueries.insertGroupEvent,
      _EventQueries.updateGroupEvent,
      vars,
      isNew,
    );
  }

  // >>> UPDATED LOGIC for GROUP EVENTS <<<
  Future<void> saveGroupEventWithSlots(GroupEvent event, List<GroupEventSlot> slots) async {
    final isNew = event.id.isEmpty;
    if (isNew) {
      final vars = {
        'object': {
          'group_id': event.groupId,
          'title': event.title,
          'description': event.description,
          'image_url': event.imageUrl,
          'event_date': event.eventDate.toUtc().toIso8601String(),
          'event_end': event.eventEnd?.toUtc().toIso8601String(),
          'location': event.location,
          'event_slots': {
            'data': slots.map((s) => s.toUpsertMap()).toList()
          }
        }
      };
      final res = await _gql.mutate(MutationOptions(
        document: gql(_EventQueries.insertGroupEventWithSlots),
        variables: vars,
        fetchPolicy: FetchPolicy.noCache,
      ));
      if (res.hasException) throw Exception('Error saving group event with slots: ${res.exception}');
    } else {
      // 1. Update Event
      await saveEvent(event);

      // 2. Fetch existing slots
      final existingSlots = await fetchGroupEventSlots(event.id);
      final dbIds = existingSlots.map((s) => s.id).whereType<String>().toSet();

      // 3. Identify UI IDs
      final uiIds = slots.map((s) => s.id).whereType<String>().toSet();

      // 4. Delete removed
      final idsToDelete = dbIds.difference(uiIds).toList();
      if (idsToDelete.isNotEmpty) {
        await _deleteSlots(idsToDelete);
      }

      // 5. Upsert remaining
      if (slots.isNotEmpty) {
        final slotsPayload = slots.map((s) {
          final map = s.toUpsertMap();
          map['group_event_id'] = event.id;
          if (s.id != null) {
            map['id'] = s.id;
          } else {
            map.remove('id');
          }
          return map;
        }).toList();
        await _upsertSlots(slotsPayload);
      }
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final res = await _gql.mutate(
      MutationOptions(document: gql(_EventQueries.deleteGroupEvent), variables: {'id': eventId}),
    );
    if (res.hasException) throw Exception('Error deleting event: ${res.exception}');
  }

  // ... [Keep Slot/RSVP methods] ...
  Future<List<AppEventSlot>> fetchAppEventSlots(String eventId) async {
    final res = await _gql.query(
      QueryOptions(
        document: gql(_EventQueries.fetchAppEventSlots),
        variables: {'eventId': eventId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (res.hasException) throw res.exception!;
    return (res.data?['event_slots'] as List? ?? [])
        .map((s) => AppEventSlot.fromMap(s))
        .toList();
  }

  Future<List<GroupEventSlot>> fetchGroupEventSlots(String eventId) async {
    final res = await _gql.query(
      QueryOptions(
        document: gql(_EventQueries.fetchGroupEventSlots),
        variables: {'eventId': eventId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (res.hasException) throw res.exception!;
    return (res.data?['event_slots'] as List? ?? [])
        .map((s) => GroupEventSlot.fromMap(s))
        .toList();
  }

  Future<void> claimSlot({required String slotId, int quantity = 1}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not logged in');
    final res = await _gql.mutate(MutationOptions(
      document: gql(_EventQueries.claimSlot),
      variables: {
        'slotId': slotId,
        'userId': userId,
        'quantity': quantity,
      },
    ));
    if (res.hasException) throw Exception('Could not sign up for slot: ${res.exception}');
  }
  
  Future<void> unclaimSlot({required String slotId}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not logged in');
    final res = await _gql.mutate(MutationOptions(
      document: gql(_EventQueries.unclaimSlot),
      variables: {
        'slotId': slotId,
        'userId': userId,
      },
    ));
    if (res.hasException) throw Exception('Could not remove slot: ${res.exception}');
  }

  Future<Map<String, int>> fetchUserAssignments(List<String> slotIds) async {
    final userId = _currentUserId;
    if (userId == null || slotIds.isEmpty) return {};

    final res = await _gql.query(QueryOptions(
      document: gql(_EventQueries.fetchUserAssignments),
      variables: {
        'slotIds': slotIds,
        'userId': userId
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (res.hasException) {
      debugPrint("Error fetching user assignments: ${res.exception}");
      return {};
    }

    final List data = res.data?['slot_assignments'] ?? [];
    final Map<String, int> result = {};
    for (var row in data) {
      result[row['slot_id']] = row['quantity'] as int;
    }
    return result;
  }

  Future<void> rsvpGroupEvent({required String eventId, required int count}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not logged in');
    final res = await _gql.mutate(MutationOptions(
      document: gql(_EventQueries.upsertGroupRSVP),
      variables: {'eid': eventId, 'uid': userId, 'count': count},
    ));
    if (res.hasException) throw Exception('Error saving Group RSVP: ${res.exception}');
  }

  Future<void> removeGroupEventRSVP(String eventId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');
    final res = await _gql.mutate(MutationOptions(
      document: gql(_EventQueries.removeGroupEventRSVP),
      variables: {'eid': eventId, 'uid': userId},
    ));
    if (res.hasException) throw Exception('Error deleting Group RSVP: ${res.exception}');
  }

  Future<List<Map<String, dynamic>>> fetchGroupEventRSVPs(String eventId) async {
    final res = await _gql.query(QueryOptions(
      document: gql(_EventQueries.fetchGroupEventRSVPs),
      variables: {'eventId': eventId},
      fetchPolicy: FetchPolicy.networkOnly
    ));
    if (res.hasException) throw res.exception!;
    return (res.data?['event_attendance'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchGroupEventRSVPsLite(String eventId) async {
    final res = await _gql.query(QueryOptions(
      document: gql(_EventQueries.fetchGroupEventRSVPsLite),
      variables: {'eventId': eventId},
      fetchPolicy: FetchPolicy.networkOnly
    ));
    if (res.hasException) throw res.exception!;
    return (res.data?['event_attendance'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> rsvpAppEvent({required String appEventId, required int count}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not logged in');
    final res = await _gql.mutate(MutationOptions(
      document: gql(_EventQueries.upsertAppRSVP),
      variables: {'app_event_id': appEventId, 'user_id': userId, 'attending_count': count},
    ));
    if (res.hasException) throw Exception('Error saving RSVP: ${res.exception}');
  }

  Future<List<Map<String, dynamic>>> fetchAppEventRSVPs(String appEventId) async {
    final res = await _gql.query(QueryOptions(
      document: gql(_EventQueries.fetchAppEventRSVPs),
      variables: {'appEventId': appEventId},
      fetchPolicy: FetchPolicy.networkOnly
    ));
    if (res.hasException) throw res.exception!;
    return (res.data?['app_event_attendance'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> removeAppEventRSVP(String appEventId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');
    final res = await _gql.mutate(MutationOptions(
      document: gql(_EventQueries.removeAppEventRSVP),
      variables: {
        'app_event_id': appEventId, 
        'user_id': userId
      },
    ));
    if (res.hasException) throw Exception('Error deleting RSVP: ${res.exception}');
  }
}