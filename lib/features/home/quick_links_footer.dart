// File: lib/features/home/quick_links_footer.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class QuickLinksFooter extends StatelessWidget {
  const QuickLinksFooter({super.key});

  final List<LinkData> links = const [
    LinkData('Facebook', 'https://www.facebook.com/profile.php?id=100089863186477'),
    LinkData('Instagram', 'https://www.instagram.com/centrocristiano_frederick/'),
    LinkData('YouTube', 'https://www.youtube.com/@centerchurch8898/streams'),
    LinkData('Cafe', 'https://center-cafe.square.site'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Quick Links',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              color: colorScheme.surfaceContainerHighest,
              child: ListTile(
                title: const Text('Give'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/give'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: links
                  .map(
                    (link) => OutlinedButton.icon(
                      icon: const Icon(Icons.link),
                      label: Text(link.label),
                      onPressed: () => _launchUrl(context, link.url),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final messenger = ScaffoldMessenger.of(context);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
}

class LinkData {
  final String label;
  final String url;

  const LinkData(this.label, this.url);
}
