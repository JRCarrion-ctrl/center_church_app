import 'package:supabase_flutter/supabase_flutter.dart';

class MediaService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, String>> getLatestLivestream() async {
    final now = DateTime.now().toUtc();
    final tenMinutesAgo = now.subtract(const Duration(minutes: 10)).toIso8601String();

    final cached = await _supabase
        .from('livestream_cache')
        .select()
        .gte('fetched_at', tenMinutesAgo)
        .order('fetched_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return {
      'url': cached?['url'] ?? '',
      'thumbnail': cached?['thumbnail'] ?? '',
    };
  }
}
