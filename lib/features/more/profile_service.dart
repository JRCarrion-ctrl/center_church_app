// File: lib/services/profile_service.dart

import 'dart:io'; // Required for File in the upload method
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:logger/logger.dart';
// Assuming the path to your PhotoUploadService
import 'photo_upload_service.dart';

final _logger = Logger();

// --- GraphQL Query Definitions (Unchanged) ---
// Fetches the entire profile bundle in one go (like the original _loadAllData)
const String qProfileBundle = r'''
  query ProfileBundle($uid: String!) {
    profiles_by_pk(id: $uid) {
      display_name
      email
      bio
      photo_url
      visible_in_directory
      phone
    }
    group_memberships(where: { user_id: { _eq: $uid } }) {
      id
      role
      group {
        id
        name
      }
    }
    my_family: family_members(
      where: { user_id: { _eq: $uid }, status: { _eq: "accepted" } }
      limit: 1
    ) {
      id
      family_id
    }
    prayer_requests(where: { user_id: { _eq: $uid } }, order_by: { created_at: desc }) {
      id
      request
      created_at
      expires_at
      status
    }
    event_attendance(where: { user_id: { _eq: $uid } }, order_by: { created_at: desc }) {
      id
      attending_count
      created_at
      events {
        title
        event_date
      }
    }
    app_event_attendance(where: { user_id: { _eq: $uid } }, order_by: { created_at: desc }) {
      id
      attending_count
      created_at
      app_events {
        title
        event_date
      }
    }
  }
''';

// Fetches detailed family members based on family ID
const String qFamilyMembers = r'''
  query Family($fid: uuid!) {
    family_members(
      where: { family_id: { _eq: $fid }, status: { _eq: "accepted" } }
    ) {
      id
      relationship
      status
      user_id
      is_child
      child: child_profile { display_name qr_code_url }
      user: profile { id display_name photo_url }
    }
  }
''';

// Mutation to update a single profile field (replaces _updateProfileField, _toggleVisibility)
const String mUpdateProfileField = r'''
  mutation UpdateField($id: String!, $_set: profiles_set_input!) {
    update_profiles_by_pk(
      pk_columns: { id: $id },
      _set: $_set
    ) { id }
  }
''';

// Mutation to update the user's photo URL (replaces SetPhoto mutation)
const String mSetPhoto = r'''
  mutation SetPhoto($id: String!, $url: String!) {
    update_profiles_by_pk(pk_columns: { id: $id }, _set: { photo_url: $url }) { id }
  }
''';

// Mutation to delete a prayer request (replaces DeletePrayer mutation)
const String mDeletePrayer = r'''
  mutation DeletePrayer($id: uuid!) {
    delete_prayer_requests_by_pk(id: $id) { id }
  }
''';

// Mutation to delete a user account (replaces DeleteAccount mutation)
const String mDeleteAccount = r'''
  mutation DeleteAccount($id: String!) {
    delete_profiles_by_pk(id: $id) {
      id
    }
  }
''';

// --- Service Class ---

class ProfileBundle {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> prayerRequests;
  final List<Map<String, dynamic>> eventRsvps;
  final String? familyId;

  ProfileBundle({
    this.profile,
    required this.groups,
    required this.prayerRequests,
    required this.eventRsvps,
    this.familyId,
  });
}

class ProfileService {
  final GraphQLClient client;
  // DEPENDENCY INJECTION: Inject the PhotoUploadService
  final PhotoUploadService photoUploadService; 

  ProfileService(this.client, this.photoUploadService);

  /// Executes the main profile bundle query and maps the results.
  Future<ProfileBundle> fetchProfileBundle(String userId) async {
    _logger.i('[ProfileBundleService] Fetching data for user: $userId');
    
    final res = await client.query(
      QueryOptions(
        document: gql(qProfileBundle),
        variables: {'uid': userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (res.hasException) {
      if (res.exception?.linkException is CacheMissException) {
         _logger.w('[ProfileBundleService] CacheMissException. Will attempt to proceed.');
      } else {
        _logger.e('[ProfileBundleService] Error fetching bundle', error: res.exception);
        throw res.exception!;
      }
    }

    final data = res.data ?? {};
    final profile = data['profiles_by_pk'] as Map<String, dynamic>?;
    final groups = (data['group_memberships'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final prayers = (data['prayer_requests'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    
    final myFamilyList = (data['my_family'] as List<dynamic>? ?? []);
    final familyId = myFamilyList.isNotEmpty ? (myFamilyList.first['family_id'] as String?) : null;
    
    final groupRSVPs = (data['event_attendance'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final appRSVPs = (data['app_event_attendance'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final eventRsvps = [
      ...groupRSVPs.map((r) => {...r, 'source': 'group'}),
      ...appRSVPs.map((r) => {...r, 'source': 'app'}),
    ];

    return ProfileBundle(
      profile: profile,
      groups: groups,
      prayerRequests: prayers,
      eventRsvps: eventRsvps,
      familyId: familyId,
    );
  }

  /// Fetches the list of family members for a given family ID.
  Future<List<Map<String, dynamic>>> fetchFamilyMembers(String familyId) async {
    _logger.d('[FamilyService] Fetching members for family: $familyId');
    final res = await client.query(
      QueryOptions(
        document: gql(qFamilyMembers),
        variables: {'fid': familyId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (res.hasException) {
      _logger.e('[FamilyService] Query failed', error: res.exception);
      throw res.exception!;
    }
    
    return (res.data?['family_members'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  /// Updates a single field in the user's profile.
  Future<void> updateProfileField(String userId, String key, dynamic value) async {
    _logger.d('[ProfileService] Updating $key for $userId to $value');
    
    final Map<String, dynamic> setVariables = { key: value };

    final res = await client.mutate(
      MutationOptions(
        document: gql(mUpdateProfileField),
        variables: {
          'id': userId,
          '_set': setVariables,
        },
      ),
    );
    if (res.hasException) throw res.exception!;
  }
  
  Future<String> uploadAndSetProfilePhoto(String userId, File file) async {
    _logger.d('[ProfileService] Starting photo upload and update for user $userId');

    // 1. Upload the file using the specialized service
    final uploadedUrl = await photoUploadService.uploadUserProfilePhoto(file, userId);

    // 2. Create a cache-busting URL
    final cacheBustedUrl = '$uploadedUrl?ts=${DateTime.now().millisecondsSinceEpoch}';

    // 3. Update the GraphQL database with the new URL
    final res = await client.mutate(
      MutationOptions(
        document: gql(mSetPhoto),
        variables: {'id': userId, 'url': cacheBustedUrl},
      ),
    );
    if (res.hasException) {
      _logger.e('[ProfileService] Failed to set photo URL in DB', error: res.exception);
      throw res.exception!;
    }
    
    return cacheBustedUrl;
  }

  // NOTE: The previous, simple updateProfilePhotoUrl is removed as it is now encapsulated 
  // within uploadAndSetProfilePhoto, which handles both parts of the operation.
  // The old stub remains:
  // Future<void> updateProfilePhotoUrl(String userId, String url) { ... }

  /// Deletes a prayer request by ID.
  Future<void> deletePrayerRequest(String id) async {
    _logger.d('[ProfileService] Deleting prayer request $id');
    final res = await client.mutate(
      MutationOptions(
        document: gql(mDeletePrayer),
        variables: {'id': id},
      ),
    );
    if (res.hasException) throw res.exception!;
  }

  /// Toggles the user's visibility in the directory.
  Future<void> toggleVisibility(String userId, bool visible) async {
    _logger.d('[ProfileService] Toggling visibility for $userId to $visible');
    await updateProfileField(userId, 'visible_in_directory', visible);
  }

  /// Initiates the deletion of the user's account.
  Future<void> deleteUserAccount(String userId) async {
    _logger.w('[ProfileService] Initiating account deletion for $userId');
    final res = await client.mutate(
      MutationOptions(
        document: gql(mDeleteAccount),
        variables: {'id': userId},
      ),
    );
    if (res.hasException) throw res.exception!;
  }
}