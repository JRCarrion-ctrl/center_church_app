// File: lib/features/home/church_info_card.dart
import 'dart:ui'; // Required for ImageFilter (Glass effect)
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

class ChurchInfoCard extends StatelessWidget {
  const ChurchInfoCard({super.key});

  static const _spanishUrl = 'https://www.centrocristianofrederick.com/';
  static const _englishUrl = 'https://www.tccf.church/';

  Future<void> _launchChurchSite(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ClipRRect(
          // ✨ UPGRADE: Increased radius to 28 to match our new standard
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/DSC06378.jpg',
                height: 220, // Slightly taller to give buttons breathing room
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Container(
                height: 220,
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.4), // Darker overlay for better text pop
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "key_178a".tr().toUpperCase(), // Uppercase for modern branding
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Glass Buttons Stacking
                    _GlassLinkButton(
                      label: 'centrocristianofrederick.com',
                      onTap: () => _launchChurchSite(_spanishUrl),
                    ),
                    const SizedBox(height: 12),
                    _GlassLinkButton(
                      label: 'tccf.church',
                      onTap: () => _launchChurchSite(_englishUrl),
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

// Reusable Glass Button for Image Backgrounds
class _GlassLinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GlassLinkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}