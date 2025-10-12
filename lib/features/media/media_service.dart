// File: lib/features/media/media_service.dart
import 'package:graphql_flutter/graphql_flutter.dart';

class MediaService {
  final GraphQLClient _gql;
  MediaService(this._gql);

  /// Returns { 'url': String, 'thumbnail': String } or empty strings if none.
  Future<Map<String, String>> getLatestLivestream() async {
    const q = r'''
      query LatestLivestream {
        livestream_cache(order_by: { fetched_at: desc }, limit: 1) {
          url
          thumbnail
        }
      }
    ''';

    try {
      final res = await _gql.query(
        QueryOptions(document: gql(q), fetchPolicy: FetchPolicy.networkOnly),
      );
      if (res.hasException) {
        // Mirror original behavior: fail soft with empty strings
        return {'url': '', 'thumbnail': ''};
      }

      final rows = (res.data?['livestream_cache'] as List<dynamic>? ?? []);
      if (rows.isEmpty) return {'url': '', 'thumbnail': ''};

      final row = rows.first as Map<String, dynamic>;
      return {
        'url': (row['url'] ?? '') as String,
        'thumbnail': (row['thumbnail'] ?? '') as String,
      };
    } catch (_) {
      // Mirror original behavior: fail soft
      return {'url': '', 'thumbnail': ''};
    }
  }
}
