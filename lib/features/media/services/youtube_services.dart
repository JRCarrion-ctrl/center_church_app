// File: lib/features/media/services/youtube_services.dart
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

class YouTubeService {
  static const String _apiKey = 'AIzaSyA5-sCz0BroyDwVKfSprmZpjHTKqPHL6Bc';
  static const String _channelId = 'UC7hrHYmMinZHf_BkA-sfoVw';

  static Future<Map<String, String>?> fetchLatestLivestream() async {
    for (final eventType in ['live', 'upcoming', 'completed']) {
      final url = Uri.https(
        'www.googleapis.com',
        '/youtube/v3/search',
        {
          'part': 'snippet',
          'channelId': _channelId,
          'eventType': eventType,
          'type': 'video',
          'order': 'date',
          'maxResults': '1',
          'key': _apiKey,
        },
      );

      try {
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = data['items'];

          if (items != null && items.isNotEmpty) {
            final video = items[0];
            final videoId = video['id']['videoId'];
            final thumbnail = video['snippet']['thumbnails']['high']['url'];

            return {
              'url': 'https://www.youtube.com/watch?v=$videoId',
              'thumbnail': thumbnail,
            };
          } else {
            log('No $eventType videos found.');
          }
        } else {
          log('YouTube API failed with status: ${response.statusCode}');
        }
      } catch (e, stack) {
        log('Error loading $eventType livestream', error: e, stackTrace: stack);
      }
    }

    return null;
  }

}
