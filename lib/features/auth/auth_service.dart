import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ccf_app/app_state.dart';

class AuthService {
  final SupabaseClient _client;
  final AppState appState;

  AuthService(this.appState) : _client = Supabase.instance.client;

  Future<AuthResponse> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );
    await appState.updateOneSignalUser();
    return response;
  }

  Future<AuthResponse> signUp(String email, String password) async {
    // Send a confirmation email that also logs the user in after verification
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password.trim(),
      emailRedirectTo: 'ccf_app://login-callback', // deep link handled in main.dart
    );

    // We don't call updateOneSignalUser() yet because user may not be confirmed/logged in
    // Instead, OneSignal will be updated in main.dart once the deep link is opened

    return response;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    await appState.updateOneSignalUser();
  }

  /// Get Current User Email
  String? getCurrentUserEmail() {
    return _client.auth.currentUser?.email;
  }
}
