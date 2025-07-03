// File: lib/features/groups/chat_storage_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class ChatStorageService {
  final _client = Supabase.instance.client;

  Future<String> uploadFile(File file, String groupId) async {
    try {
      final filename = 'group/$groupId/${Uuid().v4()}_${p.basename(file.path)}';
      final fileBytes = await file.readAsBytes();

      // 1. Request presigned URL from Supabase Edge Function
      final response = await _client.functions.invoke('generate-presigned-url', body: {
        'filename': filename,
        'contentType': 'application/octet-stream', // or detect
      });

      debugPrint('📥 Edge Function raw response: ${response.data}');

      final data = response.data;
      final uploadUrl = data['uploadUrl'];
      final finalUrl = data['finalUrl'];

      if (uploadUrl == null || finalUrl == null) {
        throw Exception('Invalid presigned URL response');
      }

      // 2. Upload to AWS S3 using presigned URL
      final uploadRes = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/octet-stream',
        },
        body: fileBytes,
      );

      if (uploadRes.statusCode != 200) {
        debugPrint('❌ Failed to upload to S3: ${uploadRes.body}');
        throw Exception('S3 upload failed with status: ${uploadRes.statusCode}');
      }

      debugPrint('✅ File uploaded to S3: $finalUrl');
      return finalUrl;
    } catch (e, stack) {
      debugPrint('❌ Upload error: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }
}
