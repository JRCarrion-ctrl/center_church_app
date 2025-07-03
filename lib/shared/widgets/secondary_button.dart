// lib/widgets/secondary_button.dart
import 'package:flutter/material.dart';

class SecondaryButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final double fontSize;
  final double padding;

  const SecondaryButton({
    super.key,
    required this.title,
    required this.onTap,
    required this.fontSize,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: padding / 2, horizontal: padding),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: const BorderSide(color: Colors.white, width: 1.5),
        foregroundColor: Colors.white,
        textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
      onPressed: onTap,
      child: Text(title),
    );
  }
}
