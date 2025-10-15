// File: lib/features/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:ccf_app/features/home/welcome_header.dart';
import 'package:ccf_app/features/home/announcements_section.dart';
import 'package:ccf_app/features/home/livestream_preview.dart';
import 'package:ccf_app/features/home/church_info_card.dart';
import 'package:ccf_app/features/home/quick_links_footer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    WelcomeHeader(),
                    SizedBox(height: 24),
                     ChurchInfoCard(),
                    SizedBox(height: 24),
                    AnnouncementsSection(),
                    SizedBox(height: 24),
                    LivestreamPreview(),
                    SizedBox(height: 24),
                    QuickLinksFooter()
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
