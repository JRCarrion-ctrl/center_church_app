import 'package:supabase_flutter/supabase_flutter.dart';

class MediaService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, String>> getLatestLivestream() async {
    final now = DateTime.now().toUtc();
    final tenMinutesAgo = now.subtract(const Duration(minutes: 10)).toIso8601String();

    try {
      final cached = await _supabase
          .from('livestream_cache')
          .select()
          .gte('fetched_at', tenMinutesAgo)
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
