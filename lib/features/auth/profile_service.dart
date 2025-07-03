import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'profile.dart';

class ProfileService {
  final SupabaseClient _client;
  final Logger _logger = Logger();

  ProfileService() : _client = Supabase.instance.client;

  /// Get the user profile by user ID
  Future<Profile?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
          
      if (response == null) {
        _logger.w('No profile found for userId=$userId');
        return null;
      }

      return Profile.fromMap(response);
    } catch (e) {
      _logger.e('Error getting profile for userId=$userId', error: e);
      return null;
    }
  }

  /// Create a new user profile
  Future<void> createProfile({
    required String userId,
    required String displayName,
    required String email,
    String role = 'member',
  }) async {
    try {
      await _client.from('profiles').insert({
        'id': userId,
        'display_name': displayName,
        'email': email,
        'role': role,
      });
    } catch (e) {
      _logger.e('Error creating profile for userId=$userId', error: e);
      rethrow;
    }
  }

  /// Update an existing user profile
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? email,
    String? role,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (email != null) data['email'] = email;
    if (role != null) data['role'] = role;

    if (data.isNotEmpty) {
      try {
        await _client.from('profiles').update(data).eq('id', userId);
      } catch (e) {
        _logger.e('Error updating profile for userId=$userId', error: e);
        rethrow;
      }
    }
  }

  /// Delete a user profile
  Future<void> deleteProfile(String userId) async {
    try {
      await _client.from('profiles').delete().eq('id', userId);
    } catch (e) {
      _logger.e('Error deleting profile for userId=$userId', error: e);
      rethrow;
    }
  }
}
