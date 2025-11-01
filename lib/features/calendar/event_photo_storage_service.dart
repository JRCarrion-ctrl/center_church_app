import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';

class EventPhotoStorageService {
  final GraphQLClient _client;

  EventPhotoStorageService(this._client);

  static const _mPresign = r'''
    mutation PresignUpload($filename: String!, $contentType: String!) {
      get_presigned_upload(filename: $filename, contentType: $contentType) {
        uploadUrl
        finalUrl
      }
    }
  ''';

  Future<String?> uploadEventPhoto({
    required File file,
    required String keyPrefix,
    required String logicalId,
  }) async {
    try {
      if (keyPrefix.isEmpty || logicalId.isEmpty) {
        throw ArgumentError('keyPrefix and logicalId cannot be empty.');
      }
      
      final filename = '$keyPrefix/$logicalId/${const Uuid().v4()}_${p.basename(file.path)}';
      final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';

      // 1. Get Pre-signed URL from Hasura
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

      // 2. Upload the file to S3
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

    } catch (e, st) {
      debugPrint('❌ EventPhotoStorageService.uploadEventPhoto error: $e');
      debugPrint(st.toString());
      // Re-throw the error so the caller can handle the failed upload
      rethrow; 
    }
  }
}
