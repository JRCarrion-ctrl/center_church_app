import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  /// Gets the cached local file for a given media URL (mobile only).
  /// Callers must guard with [kIsWeb] before calling this.
  Future<File> getMediaFile(String mediaUrl) async {
    if (kIsWeb) throw UnsupportedError('MediaCacheService is not supported on web.');

    final uri     = Uri.parse(mediaUrl);
    final s3Key   = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    final dir     = await getApplicationDocumentsDirectory();
    final mediaPath = p.join(dir.path, 'group_media', s3Key);

    final mediaDir = Directory(p.dirname(mediaPath));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final file = File(mediaPath);
    if (await file.exists()) return file;

    final prefs              = await SharedPreferences.getInstance();
    final wifiOnly           = prefs.getBool('mediaWifiOnly') ?? true;
    final autoDownloadImages = prefs.getBool('autoDownloadImages') ?? true;
    final autoDownloadVideos = prefs.getBool('autoDownloadVideos') ?? false;

    final extension = p.extension(s3Key).toLowerCase();
    final isImage   = ['.jpg', '.jpeg', '.png', '.webp', '.heic'].contains(extension);
    final isVideo   = ['.mp4', '.mov', '.webm'].contains(extension);

    if ((isImage && !autoDownloadImages) || (isVideo && !autoDownloadVideos)) {
      throw Exception('Auto-download disabled for this media type.');
    }

    if (wifiOnly) {
      final result = await Connectivity().checkConnectivity();
      if (!result.contains(ConnectivityResult.wifi)) {
        throw Exception('Not on Wi-Fi');
      }
    }

    final response = await http.get(Uri.parse(mediaUrl));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } else {
      throw Exception('Failed to download media: ${response.statusCode}');
    }
  }

  /// Clears all cached media files (mobile only).
  Future<void> clearCache() async {
    if (kIsWeb) return; // No-op on web

    final dir      = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(dir.path, 'group_media'));
    if (await mediaDir.exists()) {
      await mediaDir.delete(recursive: true);
    }
  }
}