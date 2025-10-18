// File: lib/features/more/photo_upload_service.dart (Refactored)
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';

class PhotoUploadService {
  final GraphQLClient _client;
  PhotoUploadService(this._client);

  static const _mPresign = r'''
    mutation PresignUpload($filename: String!, $contentType: String!) {
      get_presigned_upload(filename: $filename, contentType: $contentType) {
        uploadUrl
        finalUrl
      }
    }
  ''';

  // Core upload logic helper (extracted from uploadProfilePhoto)
  Future<String> _executeUpload({
    required File file, 
    required String filename, 
    required String contentType
  }) async {
    final presignResult = await _client.mutate(
      MutationOptions(
        document: gql(_mPresign),
        variables: {'filename': filename, 'contentType': contentType},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );
    if (presignResult.hasException) {
      // NOTE: Logging the backend error here is crucial for debugging
      throw Exception('Presign failed: ${presignResult.exception}'); 
    }

    final payload = presignResult.data?['get_presigned_upload'] as Map<String, dynamic>?;
    final uploadUrl = payload?['uploadUrl'] as String?;
    final finalUrl  = payload?['finalUrl']  as String?;
    if (uploadUrl == null || finalUrl == null) {
      throw Exception('Invalid presign response');
    }
    debugPrint('🎯 Using Pre-signed URL: $uploadUrl');

    final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
    request.headers[HttpHeaders.contentTypeHeader] = contentType;
    request.headers[HttpHeaders.contentLengthHeader] = (await file.length()).toString();

    file.openRead().pipe(request.sink);

    final response = await request.send();

    if (response.statusCode != 200) {
      final responseBody = await response.stream.bytesToString();
      debugPrint('❌ S3 upload failed: ${response.statusCode} $responseBody');
      throw Exception('S3 upload failed (${response.statusCode})');
    }

    debugPrint('✅ Uploaded to $finalUrl');
    return finalUrl;
  }
  
  // Method for child profile photos (scoped by familyId, using 'child_media' prefix)
  Future<String> uploadProfilePhoto(File file, String familyId) async {
    try {
      // Used for Child Profile Photos
      final filename = 'child_media/$familyId/${const Uuid().v4()}_${p.basename(file.path)}';
      final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';

      return await _executeUpload(file: file, filename: filename, contentType: contentType);
    } catch (e, st) {
      debugPrint('❌ PhotoUploadService.uploadProfilePhoto (child) error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  // NEW METHOD: For the authenticated user's profile photo (scoped by userId)
  Future<String> uploadUserProfilePhoto(File file, String userId) async {
    try {
      const prefix = 'profile_photos';
      // Use a timestamp to ensure uniqueness and cache busting.
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final extension = p.extension(file.path).isNotEmpty ? p.extension(file.path) : '.jpg';
      final filename = '$prefix/$userId-$uniqueId$extension';
      final contentType = lookupMimeType(file.path) ?? 'image/jpeg';
      
      return await _executeUpload(file: file, filename: filename, contentType: contentType);
    } catch (e, st) {
      debugPrint('❌ PhotoUploadService.uploadUserProfilePhoto (user) error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  Future<String> uploadQrCode(File file, String familyId, String childId) async {
    try {
      // Used for Child QR Codes
      final filename = 'child_media/$familyId/qrcodes/$childId.png';
      const contentType = 'image/png'; 

      return await _executeUpload(file: file, filename: filename, contentType: contentType);
    } catch (e, st) {
      debugPrint('❌ PhotoUploadService.uploadQrCode error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }
}