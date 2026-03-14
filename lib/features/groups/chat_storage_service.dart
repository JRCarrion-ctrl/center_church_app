// File: lib/features/groups/chat_storage_service.dart

import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ChatStorageService {
  final GraphQLClient _client;
  ChatStorageService(this._client);

  static const _mPresign = r'''
    mutation PresignUpload($filename: String!, $contentType: String!) {
      get_presigned_upload(filename: $filename, contentType: $contentType) {
        uploadUrl
        finalUrl
      }
    }
  ''';

  Future<String> uploadFile(Uint8List bytes, String filename, String groupId) async {
    try {
      final ext         = filename.contains('.') ? filename.split('.').last : 'jpg';
      final contentType = _contentTypeFromExt(ext);
      final s3Filename  = 'group_media/$groupId/${const Uuid().v4()}_$filename';
      debugPrint('📤 uploadFile started: $filename ext=$ext contentType=$contentType bytes=${bytes.length}');

      final presignResult = await _client.mutate(
        MutationOptions(
          document: gql(_mPresign),
          variables: {'filename': s3Filename, 'contentType': contentType},
          fetchPolicy: FetchPolicy.noCache,
        ),
      );
      debugPrint('📋 Presign complete. hasException=${presignResult.hasException}');
      if (presignResult.hasException) {
        throw Exception('Presign failed: ${presignResult.exception}');
      }

      final payload   = presignResult.data?['get_presigned_upload'] as Map<String, dynamic>?;
      final uploadUrl = payload?['uploadUrl'] as String?;
      final finalUrl  = payload?['finalUrl']  as String?;
      debugPrint('🔗 uploadUrl=$uploadUrl');
      debugPrint('🔗 finalUrl=$finalUrl');

      if (uploadUrl == null || finalUrl == null) {
        throw Exception('Invalid presign response');
      }

      debugPrint('🚀 Starting PUT request...');

      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'content-type':   contentType,
          'content-length': bytes.length.toString(),
        },
        body: bytes,
      );

      debugPrint('📡 Response received: statusCode=${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('❌ S3 upload failed: ${response.statusCode} ${response.body}');
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

  String _contentTypeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':  return 'image/png';
      case 'gif':  return 'image/gif';
      case 'webp': return 'image/webp';
      case 'heic': return 'image/heic';
      case 'jpeg': return 'image/jpeg';
      case 'pdf':  return 'application/pdf';
      case 'mp4':  return 'video/mp4';
      case 'mov':  return 'video/quicktime';
      case 'webm': return 'video/webm';
      case 'doc':  return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:     return 'image/jpeg';
    }
  }
}