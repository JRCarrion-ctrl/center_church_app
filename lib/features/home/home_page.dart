// File: lib/features/home/home_page.dart
import 'package:material_ui/material_ui.dart';
import 'package:ccf_app/app_state.dart';
import 'package:provider/provider.dart';
import 'package:ccf_app/features/home/welcome_header.dart';
import 'package:ccf_app/features/home/announcements_section.dart';
import 'package:ccf_app/features/home/livestream_preview.dart';
import 'package:ccf_app/features/home/church_info_card.dart';
import 'package:ccf_app/features/home/quick_links_footer.dart';
import 'package:ccf_app/features/home/incident_report_button.dart';
import 'package:ccf_app/features/home/latest_blog_quick_link.dart';
import 'package:ccf_app/shared/widgets/app_surface.dart';

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
    final bool isAuthenticated = context.watch<AppState>().isAuthenticated;

    return Scaffold(
      // We use a Stack to layer the background asset under the content
      body: Stack(
        children: [
          // Same softly tinted page as the group chat.
          Positioned.fill(child: ColoredBox(color: appBackgroundColor(context))),
          // 3. Your Main App Content
          SafeArea(
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

                // --- LATEST BLOG PREVIEW ---
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverToBoxAdapter(
                    child: _buildConstrainedChild(const LatestBlogQuickLink()), // Navigate to BlogListPage on tap
                  ),
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

                // --- CONDITIONAL INCIDENT REPORT BUTTON ---
                if (isAuthenticated)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                    sliver: SliverToBoxAdapter(
                      child: _buildConstrainedChild(const IncidentReportButton()),
                    ),
                  ),
                
                const SliverToBoxAdapter(child: SizedBox(height: verticalPadding)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}