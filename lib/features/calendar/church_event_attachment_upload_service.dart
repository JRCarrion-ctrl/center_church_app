// filename: lib/features/calendar/church_event_attachment_upload_service.dart
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;

/// Handles uploading files attached to a calendar/church event, using the
/// same presigned-URL flow as [BibleStudyUploadService].
class ChurchEventAttachmentUploadService {
  final GraphQLClient _client;
  ChurchEventAttachmentUploadService(this._client);

  static const _mPresign = r'''
    mutation PresignEventAttachmentUpload($filename: String!, $contentType: String!) {
      get_presigned_upload(filename: $filename, contentType: $contentType) {
        uploadUrl
        finalUrl
      }
    }
  ''';

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

  /// Uploads a file for a given event and returns the final public URL.
  /// [eventId] scopes storage so attachments for different events don't collide.
  /// [originalFileName] e.g. "sign-up-sheet.pdf" (used to derive the extension
  /// and preserved as the display name by the caller).
  Future<String> uploadEventAttachment({
    required String eventId,
    required Uint8List bytes,
    required String originalFileName,
    required String contentType,
  }) async {
    try {
      // Namespace by event id, and disambiguate with a timestamp so repeated
      // uploads of same-named files don't overwrite each other in storage.
      final safeName = originalFileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageFilename = 'event_attachments/$eventId/${timestamp}_$safeName';

      return await _executeUpload(
        bytes: bytes,
        filename: storageFilename,
        contentType: contentType,
      );
    } catch (e, st) {
      debugPrint('❌ ChurchEventAttachmentUploadService.uploadEventAttachment error: $e\n$st');
      rethrow;
    }
  }
}