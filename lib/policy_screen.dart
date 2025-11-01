// file: lib/features/policy/policy_screen.dart

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher

// --- Helper function to open URLs ---
Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.inAppWebView);
  } else {
    // Handle the error (e.g., show a Snackbar)
    debugPrint('Could not launch $url');
    // You might want to throw an exception or show a user-friendly error
  }
}

// --- Custom Widget for Clickable Link ---
class PolicyLink extends StatelessWidget {
  final String label;
  final String url;
  
  const PolicyLink({
    super.key,
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary, // Make it look clickable
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}


// --- Main Policy Acceptance Screen ---
class PolicyAcceptanceScreen extends StatelessWidget {
  // 1. Required URLs must now be passed into the constructor
  final String privacyPolicyUrl;
  final String termsAndConditionsUrl;

  const PolicyAcceptanceScreen({
    super.key,
    required this.privacyPolicyUrl,
    required this.termsAndConditionsUrl,
  });

  @override
  Widget build(BuildContext context) {
    // PopScope prevents the user from navigating back using the system back button
    return PopScope(
      canPop: false, // Explicitly prevent back navigation
      onPopInvokedWithResult: (bool didPop, Object? result) {}, // Handle the invocation (or leave empty)
      child: Scaffold(
        backgroundColor: kWhite,
        appBar: AppBar(
          backgroundColor: kWhite,
          automaticallyImplyLeading: false,
          title: const Text('Policies & Terms'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Important Notice', 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Before using this application, please review our Privacy Policy and Terms & Conditions. This is required to proceed.',
                      ),
                      const SizedBox(height: 24),

                      // 2. Use the PolicyLink widget for clickable links
                      const Text(
                        'Privacy Policy:', 
                        style: TextStyle(fontWeight: FontWeight.bold)
                      ),
                      PolicyLink(
                        label: 'View Full Privacy Policy',
                        url: privacyPolicyUrl,
                      ),
                      
                      const SizedBox(height: 16),

                      const Text(
                        'Terms & Conditions:', 
                        style: TextStyle(fontWeight: FontWeight.bold)
                      ),
                      PolicyLink(
                        label: 'View Full Terms & Conditions',
                        url: termsAndConditionsUrl,
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              // Acceptance Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Call the acceptTerms method from AppState
                    Provider.of<AppState>(context, listen: false).acceptTerms();
                  },
                  child: const Text('I Agree and Continue'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}