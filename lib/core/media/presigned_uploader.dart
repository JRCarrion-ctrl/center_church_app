// lib/core/media/presigned_uploader.dart
import 'dart:convert';
import 'dart:io'; // Import dart:io for HttpHeaders
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart'; // Needed for debugPrint

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
        'contentType': contentType
      }),
    ).timeout(const Duration(seconds: 15));
    
    if (presignRes.statusCode != 200) {
      throw Exception('Presign request failed: ${presignRes.statusCode} ${presignRes.body}');
    }

    final body = jsonDecode(presignRes.body) as Map<String, dynamic>;
    final uploadUrl = body['uploadUrl'] as String;
    final finalUrl = body['finalUrl'] as String;
    debugPrint('🎯 Presigned URL received: $uploadUrl'); // Added debug print

    // 4. PUT the file to the presigned URL using the successful stream method
    final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));

    // Set headers: Content-Type and Content-Length are CRITICAL for S3-compatible storage.
    request.headers[HttpHeaders.contentTypeHeader] = contentType;
    request.headers[HttpHeaders.contentLengthHeader] = (await file.length()).toString();

    // Pipe the file stream to the request sink
    await file.openRead().pipe(request.sink);

    // Send the request and wait for the response.
    final response = await request.send();

    if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        debugPrint('❌ Storage upload failed: ${response.statusCode} $responseBody');
        throw Exception('Storage upload failed (${response.statusCode})');
    }

    debugPrint('✅ Uploaded to $finalUrl'); // Added debug print
    // Return the final URL
    return finalUrl;
  }
}