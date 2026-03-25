// file: lib/features/policy/policy_screen.dart

import 'dart:ui'; // Required for the glassmorphic blur
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

import '../../app_state.dart';

// --- Helper function to open URLs ---
Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.inAppWebView);
  } else {
    debugPrint('Could not launch $url');
  }
}

// --- Modernized Clickable Card ---
class PolicyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String url;

  const PolicyCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _launchUrl(url),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded, color: colorScheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Main Policy Acceptance Screen ---
class PolicyAcceptanceScreen extends StatelessWidget {
  final String privacyPolicyUrl;
  final String termsAndConditionsUrl;

  const PolicyAcceptanceScreen({
    super.key,
    required this.privacyPolicyUrl,
    required this.termsAndConditionsUrl,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {},
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon Header
                Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),
                
                const Text(
                  'Before you begin',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                Text(
                  'Please review our privacy policy and terms of service to continue using the app.',
                  style: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Policy Cards
                PolicyCard(
                  title: 'Privacy Policy',
                  subtitle: 'How we protect your data',
                  icon: Icons.lock_outline_rounded,
                  url: privacyPolicyUrl,
                ),
                const SizedBox(height: 16),
                PolicyCard(
                  title: 'Terms & Conditions',
                  subtitle: 'Rules and guidelines',
                  icon: Icons.description_outlined,
                  url: termsAndConditionsUrl,
                ),
                
                const Spacer(),

                // Modern Pill Button
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    // Trigger the Service Selector Modal
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      barrierColor: Colors.black.withValues(alpha: 0.5),
                      isDismissible: false,
                      enableDrag: false,
                      builder: (_) => const _ServiceSelectorModal(),
                    );
                  },
                  child: const Text(
                    'I Agree & Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- The Glassmorphic Service Selector Modal ---
class _ServiceSelectorModal extends StatelessWidget {
  const _ServiceSelectorModal();

  void _handleSelection(BuildContext context, ChurchService service) async {
    final appState = Provider.of<AppState>(context, listen: false);
    
    // 1. Save the language preference to the Database
    await appState.updateServiceFilter(service);
    
    // 2. Accept terms to boot up the GoRouter (hides the policy screen)
    await appState.acceptTerms();
    
    // 3. Close the modal smoothly so the Home Screen appears behind the popups
    if (context.mounted) {
      Navigator.pop(context);
    }

    // 4. Trigger the Permission Prompts in sequence
    final isMobileDevice = !kIsWeb && 
        (defaultTargetPlatform == TargetPlatform.iOS || 
         defaultTargetPlatform == TargetPlatform.android);

    if (isMobileDevice) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        TrackingStatus status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          await Future.delayed(const Duration(milliseconds: 500)); 
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      }

      await OneSignal.Notifications.requestPermission(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65), // Dark frosted glass
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                "Which service do you primarily attend?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),
              
              _buildServiceTile(context, ChurchService.english, '9:30am (English)'),
              _buildServiceTile(context, ChurchService.spanish, '11:30am (Español)'),
              _buildServiceTile(context, ChurchService.both, '9:30am & 11:30am (Both)'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTile(BuildContext context, ChurchService value, String label) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
        onTap: () => _handleSelection(context, value),
      ),
    );
  }
}