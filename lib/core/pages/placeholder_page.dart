import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    // ⚡️ JUST return the content, NOT a new Scaffold
    return Center(
      child: Text("key_003".tr(args: [title])),
    );
  }
}
