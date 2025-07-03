import 'package:ccf_app/features/media/services/youtube_services.dart';

class MediaService {
  Future<Map<String, String>> getLatestLivestream() async {
    final data = await YouTubeService.fetchLatestLivestream();

    if (data == null) {
      return {
        'url': '',
        'thumbnail': '',
      };
    }

    return {
      'url': data['url'] ?? '',
      'thumbnail': data['thumbnail'] ?? '',
    };
  }
}
