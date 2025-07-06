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
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/landing_background.png', // <- Make sure this file exists and is in pubspec.yaml
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        ElevatedButton(
          onPressed: _launchChurchSite,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(255, 255, 255, 1.0).withValues(alpha: 0.9 * 255),
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
          child: const Text('Learn More About Our Church'),
        ),
      ],
    );
  }
}
