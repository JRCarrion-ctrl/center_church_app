import 'package:supabase_flutter/supabase_flutter.dart';

class MediaService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, String>> getLatestLivestream() async {
    try {
      final cached = await _supabase
          .from('livestream_cache')
          .select()
          .order('fetched_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (cached == null) {
        return {'url': '', 'thumbnail': ''};
      }

      return {
        'url': cached['url'] ?? '',
        'thumbnail': cached['thumbnail'] ?? '',
      };
    } catch (e) {
      // Optionally log this or handle error reporting
      return {'url': '', 'thumbnail': ''};
    }
  }
}
