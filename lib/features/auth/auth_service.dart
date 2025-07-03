import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService() : _client = Supabase.instance.client;

  /// Sign In
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Sign Up
  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Sign Out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get Current User Email
  String? getCurrentUserEmail() {
    return _client.auth.currentUser?.email;
  }
}
