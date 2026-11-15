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

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final fileName = '${locale.languageCode}.json';
    
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
          return response.data;
        } else if (response.data is String) {
          return json.decode(response.data);
        }
      }
    } catch (e) {
      logger.e('⚠️ [EasyLocalization] Remote fetch failed for $fileName: $e');
    }

    // Fallback to local bundled files
    try {
      final localJson = await rootBundle.loadString('$localFallbackPath/$fileName');
      logger.i('📁 [EasyLocalization] Loaded local fallback for $fileName');
      return json.decode(localJson);
    } catch (e) {
      logger.e('❌ [EasyLocalization] Failed to load local fallback for $fileName: $e');
      return {};
    }
  }
}