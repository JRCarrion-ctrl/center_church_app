// File: lib/features/home/quick_links_footer.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class QuickLinksFooter extends StatelessWidget {
  const QuickLinksFooter({super.key});

  final List<LinkData> links = const [
    LinkData('Give', 'https://www.givingfire.com/ccf'),
    LinkData('Instagram', 'https://www.instagram.com/centrocristianofrederick/'),
    LinkData('Facebook', 'https://www.facebook.com/centrocristianofrederick/'),
    LinkData('YouTube', 'https://www.youtube.com/@centerchurch8898'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Links',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.orange[100],
          child: ListTile(
            title: const Text('Give'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl(context, links[0].url),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: links
              .skip(1)
              .map((link) => OutlinedButton.icon(
                    icon: const Icon(Icons.link),
                    label: Text(link.label),
                    onPressed: () => _launchUrl(context, link.url),
                  ))
              .toList(),
        ),
      ],
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
