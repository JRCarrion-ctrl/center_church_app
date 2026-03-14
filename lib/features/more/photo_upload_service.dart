// File: lib/features/more/photo_upload_service.dart
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

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

  /// Core upload logic. Accepts raw [bytes] instead of a File so it works
  /// on all platforms including web.
  Future<String> _executeUpload({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final presignResult = await _client.mutate(
      MutationOptions(
        document: gql(_mPresign),
        variables: {'filename': filename, 'contentType': contentType},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );
    if (presignResult.hasException) {
      throw Exception('Presign failed: ${presignResult.exception}');
    }

    final payload   = presignResult.data?['get_presigned_upload'] as Map<String, dynamic>?;
    final uploadUrl = payload?['uploadUrl'] as String?;
    final finalUrl  = payload?['finalUrl']  as String?;
    if (uploadUrl == null || finalUrl == null) {
      throw Exception('Invalid presign response');
    }
    debugPrint('🎯 Using Pre-signed URL: $uploadUrl');

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

  /// Uploads a child profile photo. [extension] should include the dot (e.g. ".jpg").
  Future<String> uploadProfilePhoto(
      Uint8List bytes, String familyId, String extension, String contentType) async {
    try {
      final filename =
          'child_media/$familyId/${const Uuid().v4()}$extension';
      return await _executeUpload(
          bytes: bytes, filename: filename, contentType: contentType);
    } catch (e, st) {
      debugPrint('❌ PhotoUploadService.uploadProfilePhoto error: $e\n$st');
      rethrow;
    }
  }

  /// Uploads the authenticated user's profile photo.
  Future<String> uploadUserProfilePhoto(
      Uint8List bytes, String userId, String extension, String contentType) async {
    try {
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final ext      = extension.isNotEmpty ? extension : '.jpg';
      final filename = 'profile_photos/$userId-$uniqueId$ext';
      return await _executeUpload(
          bytes: bytes, filename: filename, contentType: contentType);
    } catch (e, st) {
      debugPrint('❌ PhotoUploadService.uploadUserProfilePhoto error: $e\n$st');
      rethrow;
    }
  }

  /// Uploads a child QR code PNG.
  Future<String> uploadQrCode(
      Uint8List bytes, String familyId, String childId) async {
    try {
      final filename = 'child_media/$familyId/qrcodes/$childId.png';
      return await _executeUpload(
          bytes: bytes, filename: filename, contentType: 'image/png');
    } catch (e, st) {
      debugPrint('❌ PhotoUploadService.uploadQrCode error: $e\n$st');
      rethrow;
    }
  }
}