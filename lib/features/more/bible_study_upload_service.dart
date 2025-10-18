// File: lib/features/more/bible_study_upload_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

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
  
  // Reusable core upload logic
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
      debugPrint('❌ Storage upload failed: ${response.statusCode} $responseBody');
      throw Exception('Storage upload failed (${response.statusCode})');
    }

    debugPrint('✅ Uploaded to $finalUrl');
    return finalUrl;
  }

  Future<String> uploadStudyNotes(File file, String logicalIdWithExtension) async {
    try {
      // Filename construction: prefix/logical_id.ext
      final filename = 'bible_studies/$logicalIdWithExtension';
      final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';

      return await _executeUpload(file: file, filename: filename, contentType: contentType);
    } catch (e, st) {
      debugPrint('❌ BibleStudyUploadService.uploadStudyNotes error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }
}