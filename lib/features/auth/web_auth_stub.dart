// file: lib/features/auth/web_auth_stub.dart
Future<String> webAuthenticate(String url) {
  throw UnsupportedError('webAuthenticate() is only available on web.');
}

String get platformRedirectUri => 'ccfapp://login-callback';