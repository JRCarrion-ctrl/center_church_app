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

  // CHANGE ME
  static const issuer      = 'https://auth.ccfapp.com';
  static const clientId    = '335963766606790668';
  static const redirectUri = 'ccfapp://login-callback';
  static const scopes      = ['openid','profile','email','offline_access'];

  static const _kAccess  = 'zitadel_access_token';
  static const _kRefresh = 'zitadel_refresh_token';
  static const _kIdToken = 'zitadel_id_token';
  static const _kExpiry  = 'zitadel_expiry'; // epoch seconds

  static Future<void> signIn() async {
    final result = await _auth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        redirectUri,
        // You may use discoveryUrl instead of serviceConfiguration
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

  static Future<void> refreshIfNeeded() async {
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

  static Future<void> signOut() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kIdToken);
    await _storage.delete(key: _kExpiry);
  }

  static Future<String?> readAccessToken() => _storage.read(key: _kAccess);
  static Future<String?> readIdToken()     => _storage.read(key: _kIdToken);

  /// Changes the user's password by making a direct API call to Zitadel's Auth API.
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