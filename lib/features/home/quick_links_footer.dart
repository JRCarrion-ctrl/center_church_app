// File: lib/features/home/quick_links_footer.dart
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

class QuickLinksFooter extends StatelessWidget {
  const QuickLinksFooter({super.key});

  // URL for the donation link
  static const String _donateUrl = 'https://tccf.givingfire.com';
  // URL for the quick links
  final List<LinkData> links = const [
    LinkData('Facebook', 'https://www.facebook.com/profile.php?id=100089863186477'),
    LinkData('Instagram', 'https://www.instagram.com/centrocristiano_frederick/'),
    LinkData('YouTube', 'https://www.youtube.com/@centerchurch8898/streams'),
    LinkData('Cafe', 'https://center-cafe.square.site'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "key_187a".tr(), // Title: Quick Links
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // -----------------------------------------------------------
              // 🎁 MODIFIED DONATE BUTTON (Prominent FilledButton)
              // -----------------------------------------------------------
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _launchUrl(context, _donateUrl),
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "key_188".tr(), // Donate button text
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 4, // Add elevation for a professional, button-like appearance
                  ),
                ),
              ),
              // -----------------------------------------------------------
              
              const SizedBox(height: 24),
              
              // -----------------------------------------------------------
              // Quick Links (Social Media and Cafe)
              // -----------------------------------------------------------
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
                        style: OutlinedButton.styleFrom(
                          // Use rounded corners for consistency
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          // Use tertiary/secondary color for link visual appeal
                          foregroundColor: colorScheme.secondary,
                          side: BorderSide(color: colorScheme.outlineVariant),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16), // Padding at the very bottom
            ],
          ),
        ),
      ),
    );
  }

  void _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final messenger = ScaffoldMessenger.of(context);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        SnackBar(content: Text("key_189".tr(args: [url]))),
      );
    }
  }
}

class LinkData {
  final String label;
  final String url;

  const LinkData(this.label, this.url);
}