// File: lib/features/home/home_page.dart (Final clean version)
import 'package:flutter/material.dart';
import 'package:ccf_app/features/home/welcome_header.dart';
import 'package:ccf_app/features/home/announcements_section.dart';
import 'package:ccf_app/features/home/livestream_preview.dart';
import 'package:ccf_app/features/home/church_info_card.dart';
import 'package:ccf_app/features/home/quick_links_footer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const double horizontalPadding = 16.0;
  static const double verticalPadding = 24.0;
  static const double maxWidth = 600.0;
  static const double spacing = 24.0;

  Widget _buildConstrainedChild(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: verticalPadding)),

            // --- WELCOME HEADER ---
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: SliverToBoxAdapter(child: _buildConstrainedChild(const WelcomeHeader())),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: spacing)),

            // --- CHURCH INFO CARD ---
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: SliverToBoxAdapter(child: _buildConstrainedChild(const ChurchInfoCard())),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: spacing)),

            // --- ANNOUNCEMENTS SECTION ---
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: SliverToBoxAdapter(child: _buildConstrainedChild(const AnnouncementsSection())),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: spacing)),

            // --- LIVESTREAM PREVIEW ---
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: SliverToBoxAdapter(child: _buildConstrainedChild(const LivestreamPreview())),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: spacing)),

            // --- QUICK LINKS FOOTER ---
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: SliverToBoxAdapter(child: _buildConstrainedChild(const QuickLinksFooter())),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: verticalPadding)),
          ],
        ),
      ),
    );
  }
}