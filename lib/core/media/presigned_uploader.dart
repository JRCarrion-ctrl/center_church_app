// lib/core/media/presigned_uploader.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class PresignedUploader {
  static const _presignEndpoint = 'https://uploads.ccfapp.com/storage/presign';
  static const _storage = FlutterSecureStorage();

  static Future<String> upload({
    required File file,
    required String keyPrefix, // e.g. "avatars" or "group_media/123"
    required String logicalId, // e.g. a user ID or message ID
  }) async {
    // 1. Get the authentication token
    final token = await _storage.read(key: 'zitadel_access_token');
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Please sign in before uploading.');
    }

    // 2. Determine MIME type and file name
    final ext = file.path.split('.').last.toLowerCase();
    // Use the lookupMimeType result, but fallback to a known type if possible
    final contentType = lookupMimeType(file.path) 
        ?? (ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 
           (ext == 'png' ? 'image/png' : 'application/octet-stream'));

    final filename =
        '$keyPrefix/$logicalId-${DateTime.now().millisecondsSinceEpoch}.$ext';

    // 3. Request the presigned URL from your backend
    final presignRes = await http.post(
      Uri.parse(_presignEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'filename': filename, 
        'contentType': contentType // Backend needs this to generate the correct PAR headers
      }),
    ).timeout(const Duration(seconds: 15));
    
    if (presignRes.statusCode != 200) {
      throw Exception('Presign request failed: ${presignRes.statusCode} ${presignRes.body}');
    }

    final body = jsonDecode(presignRes.body) as Map<String, dynamic>;
    final uploadUrl = body['uploadUrl'] as String;
    final finalUrl = body['finalUrl'] as String;

    // 4. PUT the file to the presigned URL with explicit Content-Type header
    // Use a direct put with the file bytes. This is simpler than the stream send 
    // and often more reliable for smaller files like images.
    final bytes = await file.readAsBytes();
    
    final response = await http.put(
        Uri.parse(uploadUrl),
        // CRITICAL: Ensure Content-Type is set here for the storage system
        headers: { 'Content-Type': contentType }, 
        body: bytes,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Direct upload to storage failed: ${response.statusCode} ${response.body}');
    }

    // Return the final URL
    return finalUrl;
  }
}