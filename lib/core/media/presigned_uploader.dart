// lib/core/media/presigned_uploader.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class PresignedUploader {
  static const _presignEndpoint = 'https://uploads.ccfapp.com/storage/presign';
  static const _storage = FlutterSecureStorage();

  static Future<String> upload({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    // 1. Get the authentication token.
    final token = await _storage.read(key: 'zitadel_access_token');
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Please sign in before uploading.');
    }

    // 2. Request the presigned URL from the backend.
    final presignRes = await http.post(
      Uri.parse(_presignEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'filename': filename,
        'contentType': contentType,
      }),
    ).timeout(const Duration(seconds: 15));

    if (presignRes.statusCode != 200) {
      throw Exception(
          'Presign request failed: ${presignRes.statusCode} ${presignRes.body}');
    }

    final body = jsonDecode(presignRes.body) as Map<String, dynamic>;
    final uploadUrl = body['uploadUrl'] as String;
    final finalUrl  = body['finalUrl']  as String;
    debugPrint('🎯 Presigned URL received: $uploadUrl');

    // 3. PUT the bytes to the presigned URL.
    // Plain string headers replace dart:io's HttpHeaders constants.
    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {
        'content-type':   contentType,
        'content-length': bytes.length.toString(),
      },
      body: bytes,
    );

    if (response.statusCode != 200) {
      debugPrint('❌ S3 upload failed: ${response.statusCode} ${response.body}');
      throw Exception('S3 upload failed (${response.statusCode})');
    }

    debugPrint('✅ Uploaded to $finalUrl');
    return finalUrl;
  }
}