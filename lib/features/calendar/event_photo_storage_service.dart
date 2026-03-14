
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

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
    required Uint8List bytes,
    required String? extension,
    required String keyPrefix,
    required String logicalId,
  }) async {
    try {
      if (keyPrefix.isEmpty || logicalId.isEmpty) {
        throw ArgumentError('keyPrefix and logicalId cannot be empty.');
      }

      final ext         = (extension != null && extension.isNotEmpty) ? extension : '.jpg';
      final contentType = ext == '.png' ? 'image/png' : 'image/jpeg';
      final filename    = '$keyPrefix/$logicalId/${const Uuid().v4()}$ext';

      // 1. Get pre-signed URL from Hasura
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

      // 2. Upload bytes to S3
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

    } catch (e, st) {
      debugPrint('❌ EventPhotoStorageService.uploadEventPhoto error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }
}