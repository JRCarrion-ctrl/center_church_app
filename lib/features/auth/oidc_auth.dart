// file: lib/features/auth/oidc_auth.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:openid_client/openid_client.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

// Import the provider, which handles the platform switching automatically.
import 'web_auth_provider.dart';

class OidcAuth {
  static const _storage = FlutterSecureStorage();

  static const issuerUrl = 'https://auth.ccfapp.com';
  static const issuer = issuerUrl; // Alias for backward compatibility
  static const clientId  = '335963766606790668';

  // Delegate this to the platform-specific getter from the provider
  static String get redirectUri => platformRedirectUri;

  static const scopes = ['openid', 'profile', 'email', 'offline_access'];

  static const _kAccess  = 'zitadel_access_token';
  static const _kRefresh = 'zitadel_refresh_token';
  static const _kIdToken = 'zitadel_id_token';
  static const _kExpiry  = 'zitadel_expiry'; // epoch seconds

  static Future<void>? _activeRefreshFuture;

  static Future<Client> _getClient() async {
    final uri = Uri.parse(issuerUrl);
    final issuer = await Issuer.discover(uri);
    return Client(issuer, clientId);
  }

  // ─────────────────────────────────────────────
  // Public auth flows
  // ─────────────────────────────────────────────

  static Future<void> signIn() async {
    final tokenResponse = await _runAuthFlow();
    if (tokenResponse.accessToken == null) throw Exception('Sign-in failed');

    await _saveTokens(
      access:     tokenResponse.accessToken!,
      id:         tokenResponse.idToken.toCompactSerialization(),
      refresh:    tokenResponse.refreshToken,
      expiryDate: tokenResponse.expiresAt,
    );
  }

  /// Forces a fresh login prompt — use before sensitive actions like
  /// changing a password to re-verify the user's identity.
  static Future<void> reauthenticate() async {
    final tokenResponse = await _runAuthFlow(forcePrompt: true);
    if (tokenResponse.accessToken == null) throw Exception('Re-authentication failed');

    await _saveTokens(
      access:     tokenResponse.accessToken!,
      id:         tokenResponse.idToken.toCompactSerialization(),
      refresh:    tokenResponse.refreshToken,
      expiryDate: tokenResponse.expiresAt,
    );
  }

  // Pure username/password login — no browser redirect needed.
  static Future<void> login(String username, String password) async {
    final url = Uri.parse('$issuerUrl/oauth/v2/token');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'password',
        'client_id':  clientId,
        'scope':      scopes.join(' '),
        'username':   username,
        'password':   password,
      },
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error_description'] ?? 'Authentication failed.');
    }

    final result    = jsonDecode(response.body);
    final expiresIn = result['expires_in'] as int;

    await _saveTokens(
      access:     result['access_token'] as String,
      id:         result['id_token']     as String,
      refresh:    result['refresh_token'] as String?,
      expiryDate: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  static Future<void> signOut() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kIdToken);
    await _storage.delete(key: _kExpiry);
  }

  // ─────────────────────────────────────────────
  // Token refresh
  // ─────────────────────────────────────────────

  /// Concurrency-safe refresh: if a refresh is already in flight, awaits
  /// that one instead of firing a second network request.
  static Future<void> refreshIfNeeded() async {
    if (_activeRefreshFuture != null) {
      return await _activeRefreshFuture;
    }
    _activeRefreshFuture = _performTokenRefresh();
    try {
      await _activeRefreshFuture;
    } finally {
      _activeRefreshFuture = null;
    }
  }

  static Future<void> _performTokenRefresh() async {
    final expStr  = await _storage.read(key: _kExpiry);
    final refresh = await _storage.read(key: _kRefresh);
    final access  = await _storage.read(key: _kAccess);

    // A refresh token is required; the access token is best-effort.
    if (expStr == null || refresh == null) return;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = int.tryParse(expStr) ?? 0;
    if (now < exp - 60) return; // Still valid with >1 min to spare.

    final client = await _getClient();
    final credential = client.createCredential(
      accessToken:  access,
      refreshToken: refresh,
    );

    // Passing `true` forces openid_client to use the refresh token.
    final tokenResponse = await credential.getTokenResponse(true);
    if (tokenResponse.accessToken == null) return;

    // Preserve the stored id token if the server doesn't return a new one.
    final newIdToken = tokenResponse.idToken.toCompactSerialization();

    await _saveTokens(
      access:     tokenResponse.accessToken!,
      id:         newIdToken,
      refresh:    tokenResponse.refreshToken,
      expiryDate: tokenResponse.expiresAt,
    );
  }

  // ─────────────────────────────────────────────
  // Token / user reads
  // ─────────────────────────────────────────────

  static Future<String?> readAccessToken() => _storage.read(key: _kAccess);
  static Future<String?> readIdToken()     => _storage.read(key: _kIdToken);

  static Future<String?> readUserLoginId() async {
    final idToken = await _storage.read(key: _kIdToken);
    if (idToken == null) return null;
    final payload = JwtDecoder.decode(idToken);
    return payload['email'] as String?
        ?? payload['preferred_username'] as String?;
  }

  // ─────────────────────────────────────────────
  // Password management
  // ─────────────────────────────────────────────

  static Future<void> changePassword(
      String currentPassword, String newPassword) async {
    final accessToken = await _storage.read(key: _kAccess);
    if (accessToken == null) throw Exception('User is not authenticated.');

    final url = Uri.parse('$issuerUrl/auth/v1/users/me/password');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({
        'oldPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 204) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to change password.');
    }
  }

  // ─────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────

  /// Shared PKCE browser flow used by both [signIn] and [reauthenticate].
  static Future<TokenResponse> _runAuthFlow(
      {bool forcePrompt = false}) async {
    final client = await _getClient();

    final authenticator = Flow.authorizationCodeWithPKCE(client)
      ..scopes.addAll(scopes)
      ..redirectUri = Uri.parse(redirectUri);

    var authUri = authenticator.authenticationUri;

    if (forcePrompt) {
      // Merge `prompt=login` into the generated URI's query parameters.
      authUri = authUri.replace(queryParameters: {
        ...authUri.queryParameters,
        'prompt': 'login',
      });
    }

    // On web: use dart:html BroadcastChannel directly — flutter_web_auth_2
    // validates event.source, which is null on synthetic cross-tab messages
    // and causes the Future to hang indefinitely.
    // On mobile: flutter_web_auth_2 handles Custom Tabs / ASWebAuthentication.
    final String resultUrl;
    if (kIsWeb) {
      resultUrl = await webAuthenticate(authUri.toString());
    } else {
      resultUrl = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: 'ccfapp',
      );
    }

    // callback() expects the query parameters as a Map, not a raw Uri.
    final resultUri     = Uri.parse(resultUrl);
    final credential    = await authenticator.callback(resultUri.queryParameters);
    return credential.getTokenResponse();
  }

  static Future<void> _saveTokens({
    required String  access,
    required String  id,
    String?          refresh,
    DateTime?        expiryDate,
  }) async {
    await _storage.write(key: _kAccess,  value: access);
    await _storage.write(key: _kIdToken, value: id);
    if (refresh != null) {
      await _storage.write(key: _kRefresh, value: refresh);
    }
    if (expiryDate != null) {
      await _storage.write(
        key:   _kExpiry,
        value: (expiryDate.millisecondsSinceEpoch ~/ 1000).toString(),
      );
    }
  }
}