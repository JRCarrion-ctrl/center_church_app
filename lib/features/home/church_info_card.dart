// File: lib/features/home/church_info_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

class ChurchInfoCard extends StatelessWidget {
  const ChurchInfoCard({super.key});

  // Define separate URLs for the two buttons
  static const _spanishUrl = 'https://www.centrocristianofrederick.com/'; // Placeholder Spanish URL
  static const _englishUrl = 'https://www.tccf.church/'; // Placeholder English URL

  Future<void> _launchChurchSite(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine a theme-appropriate color for the text header background

    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ClipRRect(
          // ✨ CHANGE: Increased the outer border radius for a more curved look.
          borderRadius: BorderRadius.circular(20),
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
                // Keeps the dark overlay for contrast
                color: Colors.black.withAlpha((0.3 * 255).toInt()),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Text header at the top
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        "key_178a".tr(), //Learn more about our church
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          // Use the overlayColor or White for better contrast against the dark background
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Column for vertical stacking of buttons
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center, 
                      children: [
                        // Spanish Button
                        ElevatedButton(
                          onPressed: () => _launchChurchSite(_spanishUrl),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20), 
                            ),
                          ),
                          child: const Text('centrocristianofrederick.com'),
                        ),
                        const SizedBox(height: 12), // Added vertical spacing
                        // English Button
                        ElevatedButton(
                          onPressed: () => _launchChurchSite(_englishUrl),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20), 
                            ),
                          ),
                          child: const Text('tccf.church'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}