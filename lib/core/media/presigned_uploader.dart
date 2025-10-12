// lib/core/media/presigned_uploader.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class PresignedUploader {
  // Expose one place to change later if you move routes/flavors
  static const _presignEndpoint = 'https://uploads.ccfapp.com/storage/presign';
  static const _storage = FlutterSecureStorage();

  static String _inferMime(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'image/jpeg';
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.heic')) return 'image/heic';
    return 'application/octet-stream';
  }

  /// Returns the final, public/authorized URL you should store in DB (or an object_key you pass to Hasura).
  static Future<String> upload({
    required File file,
    required String keyPrefix, // e.g. "group_media/123"
    required String logicalId, // e.g. message id or child id
  }) async {
    // 🔐 get Zitadel JWT (issued by auth.ccfapp.com)
    final token = await _storage.read(key: 'zitadel_access_token');
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Please sign in before uploading.');
    }

    final ext = file.path.split('.').last.toLowerCase();
    final filename =
        '$keyPrefix/$logicalId-${DateTime.now().millisecondsSinceEpoch}.$ext';
    final contentType = _inferMime(file.path);
    final bytes = await file.readAsBytes();

    // 1) Ask our signer to make a presigned PUT URL for OCI Object Storage.
    final presignRes = await http.post(
      Uri.parse(_presignEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Zitadel JWT (server verifies)
      },
      body: jsonEncode({
        'filename': filename,      // object key to create
        'contentType': contentType // helps set correct metadata
      }),
    );

    if (presignRes.statusCode == 401 || presignRes.statusCode == 403) {
      throw Exception('Unauthorized from presign endpoint (check JWT/roles).');
    }
    if (presignRes.statusCode != 200) {
      throw Exception(
        'Presign failed: ${presignRes.statusCode} ${presignRes.body}',
      );
    }

    final body = jsonDecode(presignRes.body) as Map<String, dynamic>;
    final uploadUrl = body['uploadUrl'] as String; // OCI signed PUT URL
    final finalUrl  = body['finalUrl']  as String; // CDN/GET URL or object_key

    // 2) PUT the bytes directly to OCI (Cloudflare is not in this path).
    final put = await http.put(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Type': contentType,
        // Some presigned URLs require these—only add if your signer includes them:
        // 'x-amz-acl': 'private',
      },
      body: bytes,
    );

    if (put.statusCode != 200 && put.statusCode != 201) {
      throw Exception('Upload failed: ${put.statusCode} ${put.body}');
    }

    return finalUrl; // store this (or store `filename` + serve via signed GET)
  }
}
