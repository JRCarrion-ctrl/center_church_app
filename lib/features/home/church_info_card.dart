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
    final overlayColor = Theme.of(context).colorScheme.surface.withAlpha((0.9 * 255).toInt());
    
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
                      decoration: BoxDecoration(
                        color: overlayColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "key_178a".tr(), 
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Column for vertical stacking of buttons
                    // FIX: Changed crossAxisAlignment to center to prevent horizontal stretching
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center, 
                      children: [
                        // Spanish Button
                        ElevatedButton(
                          onPressed: () => _launchChurchSite(_spanishUrl),
                          style: ElevatedButton.styleFrom(
                            // Setting padding explicitly for tight wrapping
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                            // INCREASED circular border radius
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20), 
                            ),
                            // REMOVED minimumSize and .copyWith(padding) as padding is now explicit
                          ),
                          child: const Text('centrocristianofrederick.com'),
                        ),
                        const SizedBox(height: 12), // Added vertical spacing
                        // English Button
                        ElevatedButton(
                          onPressed: () => _launchChurchSite(_englishUrl),
                          style: ElevatedButton.styleFrom(
                            // Setting padding explicitly for tight wrapping
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                            // INCREASED circular border radius
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20), 
                            ),
                            // REMOVED minimumSize and .copyWith(padding) as padding is now explicit
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