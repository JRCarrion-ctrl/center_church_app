import 'package:jwt_decoder/jwt_decoder.dart';

class HasuraRoles {
  static bool hasRole(String token, String role) {
    final c = JwtDecoder.decode(token);
    final claims = c['https://hasura.io/jwt/claims'] as Map<String, dynamic>? ?? {};
    final allowed = (claims['x-hasura-allowed-roles'] as List?)?.cast<String>() ?? const [];
    return allowed.contains(role);
  }

  static String? defaultRole(String token) {
    final c = JwtDecoder.decode(token);
    final claims = c['https://hasura.io/jwt/claims'] as Map<String, dynamic>? ?? {};
    return claims['x-hasura-default-role'] as String?;
  }
}
