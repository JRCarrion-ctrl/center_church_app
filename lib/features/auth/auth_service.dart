import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/app_state.dart';

class AuthService {
  final SupabaseClient _client;
  final AppState appState;

  AuthService(this.appState) : _client = Supabase.instance.client;

  /// Sign In
  Future<AuthResponse> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );

    appState.updateOneSignalUser();
    return response;
  }

  /// Sign Up
  Future<AuthResponse> signUp(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password.trim(),
    );

    appState.updateOneSignalUser();
    return response;
  }

  /// Sign Out
  Future<void> signOut() async {
    await _client.auth.signOut();
    appState.updateOneSignalUser();
  }

  /// Get Current User Email
  String? getCurrentUserEmail() {
    return _client.auth.currentUser?.email;
  }
}
