import 'package:ccf_app/features/media/services/youtube_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, String>> getLatestLivestream() async {
    // 1. Try to get cached livestream if recent (e.g. within last 10 minutes)
    final now = DateTime.now().toUtc();
    final tenMinutesAgo = now.subtract(const Duration(minutes: 10)).toIso8601String();

    final cached = await _supabase
        .from('livestream_cache')
        .select()
        .gte('fetched_at', tenMinutesAgo)
        .order('fetched_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (cached != null && cached['url'] != null && cached['url'].toString().isNotEmpty) {
      return {
        'url': cached['url'],
        'thumbnail': cached['thumbnail'],
      };
    }

    // 2. If no recent cache, call YouTube API
    final data = await YouTubeService.fetchLatestLivestream();

    if (data == null) {
      return {
        'url': '',
        'thumbnail': '',
      };
    }

    // 3. Cache the result in Supabase
    await _supabase.from('livestream_cache').insert({
      'url': data['url'],
      'thumbnail': data['thumbnail'],
      'fetched_at': now.toIso8601String(),
    });

    return data;
  }
}
