import '../../app_state.dart';

class AuthService {
  final AppState app;
  AuthService(this.app);

  Future<void> signInWithZitadel() => app.signInWithZitadel();

  Future<void> signOut() => app.signOut();
}
