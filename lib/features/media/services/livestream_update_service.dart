// File: lib/features/home/livestream_update_service.dart
import 'package:graphql_flutter/graphql_flutter.dart';

class LivestreamUpdateService {
  final GraphQLClient _gql;
  LivestreamUpdateService(this._gql);

  /// Returns true if an update was triggered.
  Future<bool> maybeTriggerUpdate() async {
    final nowUtc = DateTime.now().toUtc();

    // 1) Read current last_run_at
    const qMeta = r'''
      query GetLivestreamCacheMeta {
        livestream_cache_meta_by_pk(id: "singleton") {
          last_run_at
        }
      }
    ''';

    DateTime? lastRun;
    try {
      final res = await _gql.query(
        QueryOptions(document: gql(qMeta), fetchPolicy: FetchPolicy.networkOnly),
      );
      if (res.hasException) throw res.exception!;
      final iso = res.data?['livestream_cache_meta_by_pk']?['last_run_at'] as String?;
      if (iso != null) {
        lastRun = DateTime.tryParse(iso);
      }
    } catch (e) {
      // If the row/table is missing, we'll still attempt the refresh & upsert.
    }

    final needsUpdate = lastRun == null || nowUtc.difference(lastRun) > const Duration(hours: 1);
    if (!needsUpdate) return false;

    // 2) Trigger your cache refresh (Hasura Action or Remote Schema)
    // Create an Action named `refresh_livestream_cache` that returns { ok: Boolean, message: String }
    const mRefresh = r'''
      mutation RefreshLivestream {
        refresh_livestream_cache {
          ok
          message
        }
      }
    ''';

    final refreshRes = await _gql.mutate(MutationOptions(document: gql(mRefresh)));
    if (refreshRes.hasException) {
      // Don’t update the timestamp if the refresh failed
      throw Exception('Refresh failed: ${refreshRes.exception}');
    }

    final ok = refreshRes.data?['refresh_livestream_cache']?['ok'] == true;
    if (!ok) {
      final msg = refreshRes.data?['refresh_livestream_cache']?['message'] as String?;
      throw Exception('Refresh not OK${msg != null ? ': $msg' : ''}');
    }

    // 3) Upsert new last_run_at
    const mUpsert = r'''
      mutation UpsertMeta($ts: timestamptz!) {
        insert_livestream_cache_meta_one(
          object: { id: "singleton", last_run_at: $ts },
          on_conflict: {
            constraint: livestream_cache_meta_pkey,
            update_columns: [last_run_at]
          }
        ) { id }
      }
    ''';

    final upsertRes = await _gql.mutate(
      MutationOptions(document: gql(mUpsert), variables: {'ts': nowUtc.toIso8601String()}),
    );
    if (upsertRes.hasException) {
      throw Exception('Failed to update last_run_at: ${upsertRes.exception}');
    }

    return true;
  }
}
