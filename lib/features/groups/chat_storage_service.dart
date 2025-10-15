// File: lib/features/groups/chat_storage_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';

class ChatStorageService {
  final GraphQLClient _client;
  ChatStorageService(this._client);

  // It's good practice to define constants outside the method
  // to avoid recreating them on every call.
  static const _mPresign = r'''
    mutation PresignUpload($filename: String!, $contentType: String!) {
      get_presigned_upload(filename: $filename, contentType: $contentType) {
        uploadUrl
        finalUrl
      }
    }
  ''';

  Future<String> uploadFile(File file, String groupId) async {
    try {
      final filename = 'group_media/$groupId/${const Uuid().v4()}_${p.basename(file.path)}';
      final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';

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

      // Set headers. Content-Length is crucial for S3-compatible services.
      request.headers[HttpHeaders.contentTypeHeader] = contentType;
      request.headers[HttpHeaders.contentLengthHeader] = (await file.length()).toString();

      // ✨ REFINED PART ✨
      // Start piping the file stream to the request sink. `send()` will consume this stream.
      // The `pipe()` method will automatically close the sink when the file stream ends.
      // The outer try/catch will handle any errors from the stream or the request.
      file.openRead().pipe(request.sink);

      // Send the request and wait for the response.
      final response = await request.send();

      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        debugPrint('❌ S3 upload failed: ${response.statusCode} $responseBody');
        throw Exception('S3 upload failed (${response.statusCode})');
      }

      debugPrint('✅ Uploaded to $finalUrl');
      return finalUrl;
    } catch (e, st) {
      debugPrint('❌ ChatStorageService.uploadFile error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }
}