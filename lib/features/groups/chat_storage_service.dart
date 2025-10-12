// File: lib/features/groups/chat_storage_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class ChatStorageService {
  final GraphQLClient _client;
  ChatStorageService(this._client);

  Future<String> uploadFile(File file, String groupId) async {
    try {
      // Build storage path (namespaced by group)
      final filename = 'group/$groupId/${const Uuid().v4()}_${p.basename(file.path)}';
      final bytes = await file.readAsBytes();
      final contentType = _detectContentType(file.path);

      // 1) Ask Hasura Action to presign an S3 upload (replace with your action name/shape if needed)
      // TODO: Get presigned upload hasura action
      const mPresign = r'''
        mutation PresignUpload($path: String!, $contentType: String!) {
          get_presigned_upload(path: $path, contentType: $contentType) {
            uploadUrl
            finalUrl
          }
        }
      ''';

      final presignRes = await _client.mutate(
        MutationOptions(
          document: gql(mPresign),
          variables: {'path': filename, 'contentType': contentType},
          fetchPolicy: FetchPolicy.noCache,
        ),
      );
      if (presignRes.hasException) {
        throw Exception('Presign failed: ${presignRes.exception}');
      }

      final payload = presignRes.data?['get_presigned_upload'] as Map<String, dynamic>?;
      final uploadUrl = payload?['uploadUrl'] as String?;
      final finalUrl  = payload?['finalUrl']  as String?;
      if (uploadUrl == null || finalUrl == null) {
        throw Exception('Invalid presign response');
      }

      // 2) Upload to S3 with the presigned URL
      final put = await http.put(
        Uri.parse(uploadUrl),
        headers: {HttpHeaders.contentTypeHeader: contentType},
        body: bytes,
      );
      if (put.statusCode != 200 && put.statusCode != 204) {
        debugPrint('❌ S3 upload failed: ${put.statusCode} ${put.body}');
        throw Exception('S3 upload failed (${put.statusCode})');
      }

      debugPrint('✅ Uploaded to $finalUrl');
      return finalUrl;
    } catch (e, st) {
      debugPrint('❌ ChatStorageService.uploadFile error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  String _detectContentType(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
