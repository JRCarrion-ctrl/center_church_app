import 'package:flutter/material.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  final List<FAQItem> faqs = const [
    FAQItem(
      question: 'How do I join a group?',
      answer:
          'Navigate to the Groups page. You will see a list of open groups you can join or request access to. Tap on the group you want, and follow the prompt.',
    ),
    FAQItem(
      question: 'What is the difference between main announcements and group announcements?',
      answer:
          'Main announcements appear on the Home screen for everyone, while group announcements are specific to the groups you’ve joined. You’ll see those in their respective group chats.',
    ),
    FAQItem(
      question: 'Can I watch past livestreams?',
      answer:
          'Yes! Tap "More Livestreams" on the Home page to view past services and Bible studies. Bible studies may require access approval if you’re not in A/V ministry.',
    ),
    FAQItem(
      question: 'How do I submit a prayer request?',
      answer:
          'On the Prayer page, tap the "+" button to submit a prayer request. You can include your name or remain anonymous. Requests expire after 7 days.',
    ),
    FAQItem(
      question: 'How do I change the app’s language or theme?',
      answer:
          'Go to Settings from the More tab. From there, you can select a preferred language and choose between Light, Dark, or System theme modes.',
    ),
    FAQItem(
      question: 'What are roles and permissions?',
      answer:
          'Roles like Member, Group Admin, Leader, or Owner determine what features you can access. You can view your role in your Profile, and any extra permissions in the Permissions page.',
    ),
    FAQItem(
      question: 'Is my data secure?',
      answer:
          'Yes. We use Supabase for secure authentication, encrypted storage, and role-based access. Only verified users with the right permissions can see sensitive information.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return _FAQCard(faq: faq);
        },
      ),
    );
  }
}

class _FAQCard extends StatefulWidget {
  final FAQItem faq;

  const _FAQCard({required this.faq});

  @override
  State<_FAQCard> createState() => _FAQCardState();
}

class _FAQCardState extends State<_FAQCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(widget.faq.question, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        initiallyExpanded: _expanded,
        onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
        children: [
          Text(widget.faq.answer, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  const FAQItem({required this.question, required this.answer});
}
