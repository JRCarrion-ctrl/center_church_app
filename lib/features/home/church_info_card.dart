// File: lib/features/home/church_info_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChurchInfoCard extends StatelessWidget {
  const ChurchInfoCard({super.key});

  static const _churchUrl = 'https://www.centrocristianofrederick.com/';

  Future<void> _launchChurchSite() async {
    final uri = Uri.parse(_churchUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $_churchUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/landing_background.png',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Container(
                height: 180,
                width: double.infinity,
                color: Colors.black.withAlpha((0.3 * 255).toInt()),
              ),
              ElevatedButton(
                onPressed: _launchChurchSite,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Theme.of(context).colorScheme.surface.withAlpha((0.9 * 255).toInt()),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 4,
                ),
                child: const Text(
                  'Learn More About Our Church',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
