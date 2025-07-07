import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class LivestreamUpdateService {
  static final _supabase = Supabase.instance.client;

  static Future<void> maybeTriggerUpdate() async {
    final res = await _supabase
        .from('livestream_cache_meta')
        .select('last_run_at')
        .eq('id', 'singleton')
        .maybeSingle();

    final lastRun = DateTime.tryParse(res?['last_run_at'] ?? '');
    final now = DateTime.now().toUtc();

    if (lastRun == null || now.difference(lastRun) > const Duration(hours: 1)) {
      final url = Uri.parse(
        'https://vhzcbqgehlpemdkvmzvy.functions.supabase.co/update-livestream-cache',
      );

      final result = await http.post(url);

      if (result.statusCode == 200) {
        await _supabase
            .from('livestream_cache_meta')
            .update({'last_run_at': now.toIso8601String()})
            .eq('id', 'singleton');
      }
    }
  }
}
