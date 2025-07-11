import 'package:flutter/material.dart';

class HowToUsePage extends StatelessWidget {
  const HowToUsePage({super.key});

  final List<HowToSection> sections = const [
    HowToSection(
      title: 'Home Tab',
      content:
          'The Home tab shows a welcome message, countdown to the next service, announcements, the latest livestream, church info, and quick links (Giving, YouTube, etc.). Tap "More Livestreams" to browse past services or Bible studies.',
    ),
    HowToSection(
      title: 'Groups Tab',
      content:
          'Join or request to join open groups. Tap a group to enter its chat, view the calendar, media, and announcements. Group admins can manage members and post announcements.',
    ),
    HowToSection(
      title: 'Calendar Tab',
      content:
          'Shows events from your groups. Tap the calendar icon in the top right to choose which group calendars sync to your view. Tap an event to see details or mark attendance.',
    ),
    HowToSection(
      title: 'Prayer Tab',
      content:
          'View and submit prayer requests. You can choose to submit anonymously or with your name. Requests expire after 7 days. You can view and remove your own requests from your profile.',
    ),
    HowToSection(
      title: 'Bible Study Access',
      content:
          'Bible studies are restricted. When you tap one, you can request access and leave a note. Supervisors in the A/V ministry can approve or deny requests.',
    ),
    HowToSection(
      title: 'Nursery & Check-In',
      content:
          'If you have children added under your Family profile, you can check them in by showing their QR code. Nursery staff scan it and can message you while your child is checked in.',
    ),
    HowToSection(
      title: 'Roles & Permissions',
      content:
          'Your role (User, Member, Admin, Leader, Supervisor, Owner) determines what you can access. You can view your role on your Profile page and any special permissions in the More tab.',
    ),
    HowToSection(
      title: 'Settings & Customization',
      content:
          'Go to the Settings page from the More tab to change your theme, notification preferences, language, accessibility options, and more.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Use'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return _HowToCard(section: section);
        },
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  final HowToSection section;

  const _HowToCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(section.title, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: [
          Text(section.content, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class HowToSection {
  final String title;
  final String content;

  const HowToSection({required this.title, required this.content});
}
