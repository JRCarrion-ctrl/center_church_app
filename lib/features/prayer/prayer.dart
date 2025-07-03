import 'package:flutter/material.dart';

class PrayerPage extends StatelessWidget {
  const PrayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> dummyPrayerRequests = [
      {
        'name': 'John Doe',
        'request': 'Please pray for my job interview next week.'
      },
      {
        'name': 'Anonymous',
        'request': 'Pray for healing for my family member.'
      },
      {
        'name': 'Jane Smith',
        'request': 'I need strength during this difficult season.'
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Requests'),
      ),
      body: ListView.builder(
        itemCount: dummyPrayerRequests.length,
        itemBuilder: (context, index) {
          final prayer = dummyPrayerRequests[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(prayer['request'] ?? ''),
              subtitle: prayer['name'] != 'Anonymous'
                  ? Text('From: ${prayer['name']}')
                  : null,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // This will stay empty for Phase 1
        },
        tooltip: 'Submit Prayer Request',
        child: const Icon(Icons.add),
      ),
    );
  }
}
