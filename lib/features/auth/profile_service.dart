import 'package:flutter/widgets.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/graph_provider.dart';
import 'profile.dart';

class ProfileService {
  static const _qByPk = r'''
    query Me($id: text!) {
      profiles_by_pk(id:$id) { id display_name role }
    }
  ''';

  static const _mUpdateName = r'''
    mutation UpdName($id:text!, $name:text!) {
      update_profiles_by_pk(pk_columns:{id:$id}, _set:{display_name:$name}) {
        id display_name role
      }
    }
  ''';

  Future<Profile> getProfile(BuildContext context, String id) async {
    final c = GraphProvider.of(context);
    final r = await c.query(QueryOptions(document: gql(_qByPk), variables: {'id': id}));
    if (r.hasException || r.data?['profiles_by_pk'] == null) {
      throw Exception(r.exception.toString());
    }
    final m = r.data!['profiles_by_pk'] as Map<String, dynamic>;
    return Profile(id: m['id'], displayName: m['display_name'] ?? 'Member', role: m['role'] ?? 'member');
    }

  Future<Profile> updateDisplayName(BuildContext context, String id, String name) async {
    final c = GraphProvider.of(context);
    final r = await c.mutate(MutationOptions(document: gql(_mUpdateName), variables: {'id': id, 'name': name}));
    if (r.hasException || r.data?['update_profiles_by_pk'] == null) {
      throw Exception(r.exception.toString());
    }
    final m = r.data!['update_profiles_by_pk'] as Map<String, dynamic>;
    return Profile(id: m['id'], displayName: m['display_name'], role: m['role']);
  }
}
