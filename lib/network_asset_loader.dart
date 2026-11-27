import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class NetworkAssetLoader extends AssetLoader {
  final String remoteBaseUrl;
  final String localFallbackPath;

  const NetworkAssetLoader({
    required this.remoteBaseUrl,
    this.localFallbackPath = 'assets/translations',
  });

  /// Bundled translations are the base; remote values override them. Keys
  /// that only exist in the app bundle (e.g. a feature shipped before the
  /// remote files were updated) still resolve instead of showing raw keys.
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final fileName = '${locale.languageCode}.json';
    final results = await Future.wait([_loadLocal(fileName), _loadRemote(fileName)]);
    return {...results[0], ...results[1]};
  }

  Future<Map<String, dynamic>> _loadRemote(String fileName) async {
    // Safely combine the URL to prevent double slashes
    final cleanBaseUrl = remoteBaseUrl.endsWith('/')
        ? remoteBaseUrl.substring(0, remoteBaseUrl.length - 1)
        : remoteBaseUrl;
    final url = '$cleanBaseUrl/$fileName';

    try {
      logger.i('🌐 [EasyLocalization] Attempting to fetch remote file: $url');

      final response = await Dio().get(
        url,
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 5),
          // Explicitly tell the server we want a JSON file
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        logger.i('✅ [EasyLocalization] Successfully fetched remote file: $url');
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        } else if (response.data is String) {
          return json.decode(response.data as String) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      logger.e('⚠️ [EasyLocalization] Remote fetch failed for $fileName: $e');
    }
    return const {};
  }

  Future<Map<String, dynamic>> _loadLocal(String fileName) async {
    try {
      final localJson = await rootBundle.loadString('$localFallbackPath/$fileName');
      logger.i('📁 [EasyLocalization] Loaded bundled translations for $fileName');
      return json.decode(localJson) as Map<String, dynamic>;
    } catch (e) {
      logger.e('❌ [EasyLocalization] Failed to load bundled translations for $fileName: $e');
      return const {};
    }
  }
}