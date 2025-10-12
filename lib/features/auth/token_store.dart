import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  static const _s = FlutterSecureStorage();
  static const _k = 'zitadel_access_token';
  static Future<void> save(String token) => _s.write(key: _k, value: token);
  static Future<String?> read() => _s.read(key: _k);
  static Future<void> clear() => _s.delete(key: _k);
}
