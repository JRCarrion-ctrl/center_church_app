import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_001".tr())),
      body: Center(
        child: Text("key_002".tr()),
      ),
    );
  }
}
