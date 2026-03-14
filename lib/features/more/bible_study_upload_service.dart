// File: lib/features/more/bible_study_upload_service.dart
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;

class BibleStudyUploadService {
  final GraphQLClient _client;
  BibleStudyUploadService(this._client);

  static const _mPresign = r'''
    mutation PresignUpload($filename: String!, $contentType: String!) {
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

  /// [logicalIdWithExtension] e.g. "my-study-title.pdf"
  /// [contentType] e.g. "application/pdf"
  Future<String> uploadStudyNotes(
      Uint8List bytes, String logicalIdWithExtension, String contentType) async {
    try {
      final filename = 'bible_studies/$logicalIdWithExtension';
      return await _executeUpload(
          bytes: bytes, filename: filename, contentType: contentType);
    } catch (e, st) {
      debugPrint('❌ BibleStudyUploadService.uploadStudyNotes error: $e\n$st');
      rethrow;
    }
  }
}