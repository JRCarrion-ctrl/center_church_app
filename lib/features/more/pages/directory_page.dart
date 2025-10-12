// File: lib/features/more/pages/directory_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class DirectoryPage extends StatefulWidget {
  const DirectoryPage({super.key});

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  Future<List<Map<String, dynamic>>> _fetchDirectoryUsers() async {
    final client = GraphQLProvider.of(context).value;

    const q = r'''
      query DirectoryUsers {
        public_profiles(order_by: {display_name: asc}) {
          id
          display_name
          photo_url
        }
      }
    ''';

    final res = await client.query(
      QueryOptions(
        document: gql(q),
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (res.hasException) throw res.exception!;
    final rows = (res.data?['public_profiles'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("key_257".tr()),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchDirectoryUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return Center(child: Text("key_259".tr()));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final user = users[index];
              final photoUrl = user['photo_url'] as String?;
              final name = (user['display_name'] as String?) ?? 'Unnamed User';

              return ListTile(
                leading: (photoUrl != null && photoUrl.isNotEmpty)
                    ? CircleAvatar(
                        radius: 22,
                        backgroundImage: CachedNetworkImageProvider(photoUrl),
                        backgroundColor: Colors.transparent,
                      )
                    : const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                onTap: () => context.push('/profile/${user['id']}'),
              );
            },
          );
        },
      ),
    );
  }
}
