
// file: lib/features/auth/oidc_auth.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OidcAuth {
  static const _auth = FlutterAppAuth();
  static const _storage = FlutterSecureStorage();

  static const issuer      = 'https://auth.ccfapp.com';
  static const clientId    = '335963766606790668';
  static const redirectUri = 'ccfapp://login-callback';
  static const scopes      = ['openid','profile','email','offline_access'];

  static const _kAccess  = 'zitadel_access_token';
  static const _kRefresh = 'zitadel_refresh_token';
  static const _kIdToken = 'zitadel_id_token';
  static const _kExpiry  = 'zitadel_expiry'; // epoch seconds

  // --- ADDED: The lock to track an active refresh request ---
  static Future<void>? _activeRefreshFuture;

  static Future<void> signIn() async {
    final result = await _auth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        redirectUri,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: '$issuer/oauth/v2/authorize',
          tokenEndpoint:        '$issuer/oauth/v2/token',
        ),
        scopes: scopes,
      ),
    );
    if (result.accessToken == null) throw Exception('Sign-in failed');
    await _storage.write(key: _kAccess,  value: result.accessToken);
    await _storage.write(key: _kIdToken, value: result.idToken);
    if (result.refreshToken != null) {
      await _storage.write(key: _kRefresh, value: result.refreshToken);
    }
    if (result.accessTokenExpirationDateTime != null) {
      await _storage.write(
        key: _kExpiry,
        value: (result.accessTokenExpirationDateTime!.millisecondsSinceEpoch ~/ 1000).toString(),
      );
    }
    final t = await OidcAuth.readAccessToken();
    if (kDebugMode) {
      print(JwtDecoder.decode(t!));
    }
  }

  // --- UPDATED: The public method now acts as a concurrency manager ---
  static Future<void> refreshIfNeeded() async {
    // 1. If a refresh is already in progress, await it and return.
    if (_activeRefreshFuture != null) {
      return await _activeRefreshFuture;
    }

    // 2. Start the refresh and assign it to our tracker.
    _activeRefreshFuture = _performTokenRefresh();

    try {
      // 3. Wait for the actual network/storage work to finish.
      await _activeRefreshFuture;
    } finally {
      // 4. Always clear the tracker so future calls can execute properly.
      _activeRefreshFuture = null;
    }
  }

  // --- ADDED: The private method that actually does the work ---
  static Future<void> _performTokenRefresh() async {
    final expStr = await _storage.read(key: _kExpiry);
    final refresh = await _storage.read(key: _kRefresh);
    if (expStr == null || refresh == null) return;
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = int.tryParse(expStr) ?? 0;
    if (now < exp - 60) return; // refresh ~1min early

    final t = await _auth.token(TokenRequest(
      clientId,
      redirectUri,
      serviceConfiguration: const AuthorizationServiceConfiguration(
        authorizationEndpoint: '$issuer/oauth/v2/authorize',
        tokenEndpoint:        '$issuer/oauth/v2/token',
      ),
      refreshToken: refresh,
      scopes: scopes,
    ));
    
    // Safety check added here in case 't' is null
    if (t.accessToken == null) return;
    
    await _storage.write(key: _kAccess, value: t.accessToken);
    if (t.refreshToken != null) {
      await _storage.write(key: _kRefresh, value: t.refreshToken);
    }
    if (t.accessTokenExpirationDateTime != null) {
      await _storage.write(
        key: _kExpiry,
        value: (t.accessTokenExpirationDateTime!.millisecondsSinceEpoch ~/ 1000).toString(),
      );
    }
  }

  static Future<String?> readUserLoginId() async {
    final idToken = await _storage.read(key: _kIdToken);
    if (idToken == null) return null;
    
    final payload = JwtDecoder.decode(idToken);
    return payload['email'] as String? ?? payload['preferred_username'] as String?;
  }

  static Future<void> login(String username, String password) async {
    final url = Uri.parse('$issuer/oauth/v2/token');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'password',
        'client_id': clientId,
        'scope': scopes.join(' '),
        'username': username,
        'password': password,
      },
    );

    if (response.statusCode != 200) {
      final responseBody = jsonDecode(response.body);
      final errorDescription = responseBody['error_description'] ?? 'Authentication failed.';
      throw Exception(errorDescription);
    }
    
    final result = jsonDecode(response.body);
    
    await _storage.write(key: _kAccess,  value: result['access_token']);
    await _storage.write(key: _kIdToken, value: result['id_token']);

    if (result['refresh_token'] != null) {
      await _storage.write(key: _kRefresh, value: result['refresh_token']);
    }
    
    final expiresIn = result['expires_in'] as int;
    final expiryTime = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expiresIn;
    await _storage.write(key: _kExpiry, value: expiryTime.toString());
  }

  static Future<void> reauthenticate() async {
    final result = await _auth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        redirectUri,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: '$issuer/oauth/v2/authorize',
          tokenEndpoint:        '$issuer/oauth/v2/token',
        ),
        scopes: scopes,
        additionalParameters: {'prompt': 'login'},
      ),
    );
    
    if (result.accessToken == null) throw Exception('Re-authentication failed');

    await _storage.write(key: _kAccess,  value: result.accessToken);
    await _storage.write(key: _kIdToken, value: result.idToken);
    if (result.refreshToken != null) {
      await _storage.write(key: _kRefresh, value: result.refreshToken);
    }
    if (result.accessTokenExpirationDateTime != null) {
      await _storage.write(
        key: _kExpiry,
        value: (result.accessTokenExpirationDateTime!.millisecondsSinceEpoch ~/ 1000).toString(),
      );
    }
  }

  static Future<void> signOut() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kIdToken);
    await _storage.delete(key: _kExpiry);
  }

  static Future<String?> readAccessToken() => _storage.read(key: _kAccess);
  static Future<String?> readIdToken()     => _storage.read(key: _kIdToken);

  static Future<void> changePassword(String currentPassword, String newPassword) async {
    final accessToken = await _storage.read(key: _kAccess);
    if (accessToken == null) {
      throw Exception("User is not authenticated.");
    }
    
    final url = Uri.parse('$issuer/auth/v1/users/me/password');
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'oldPassword': currentPassword,
      'newPassword': newPassword,
    });
    
    final response = await http.put(url, headers: headers, body: body);
    
    if (response.statusCode != 204) {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['message'] ?? 'Failed to change password.';
      throw Exception(errorMessage);
    }
  }
}