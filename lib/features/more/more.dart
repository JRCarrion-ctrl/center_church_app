import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> moreItems = [
      {'title': 'Profile', 'route': '/more/profile'},
      {'title': 'Family', 'route': null},
      {'title': 'Directory', 'route': '/more/directory'},
      {'title': 'Nursery Staff', 'route': null},
      {'title': 'Bible Studies', 'route': null},
      {'title': 'Settings', 'route': '/more/settings'},
      {'title': 'Permissions', 'route': null},
      {'title': 'How To', 'route': null},
      {'title': 'FAQ', 'route': null},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView.builder(
        itemCount: moreItems.length,
        itemBuilder: (context, index) {
          final item = moreItems[index];
          return ListTile(
            title: Text(item['title']),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              if (item['route'] != null) {
                context.push(item['route']);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item['title']} page not available yet')),
                );
              }
            },
          );
        },
      ),
    );
  }
}
