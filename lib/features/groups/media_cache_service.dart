// File: lib/features/groups/media_cache_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  /// Gets the file for a given S3 media URL.
  /// If cached locally, returns the local file.
  /// Otherwise downloads it, caches it, and returns the file.
  Future<File> getMediaFile(String mediaUrl) async {
    final uri = Uri.parse(mediaUrl);
    final s3Key = uri.path; // includes leading slash
    final dir = await getApplicationDocumentsDirectory();
    final mediaPath = p.join(dir.path, 'group_media', s3Key);

    final mediaDir = Directory(p.dirname(mediaPath));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final file = File(mediaPath);

    if (await file.exists()) {
      return file;
    }

    // Download and cache the file
    final response = await http.get(Uri.parse(mediaUrl));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } else {
      throw Exception('Failed to download media: ${response.statusCode}');
    }
  }

  /// Clears all cached media
  Future<void> clearCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(dir.path, 'group_media'));
    if (await mediaDir.exists()) {
      await mediaDir.delete(recursive: true);
    }
  }
}
