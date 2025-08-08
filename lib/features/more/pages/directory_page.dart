// File: lib/features/more/pages/directory_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';

class DirectoryPage extends StatefulWidget {
  const DirectoryPage({super.key});

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchDirectoryUsers() async {
    final data = await supabase
        .from('public_profiles')
        .select('id, display_name, photo_url') // <-- Add photo_url here
        .order('display_name', ascending: true);

    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("key_257".tr()),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
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
              final photoUrl = user['photo_url'];

              return ListTile(
                leading: photoUrl != null && photoUrl.toString().isNotEmpty
                  ? CircleAvatar(
                      radius: 22,
                      backgroundImage: CachedNetworkImageProvider(photoUrl),
                      backgroundColor: Colors.transparent,
                    )
                    : const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user['display_name'] ?? 'Unnamed User'),
                onTap: () {
                  context.push('/profile/${user['id']}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
