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
        backgroundColor: Color(0xFFFAF4EF),
        side: const BorderSide(color: Color(0xFF5C4033), width: 1.5),
        foregroundColor: Color(0xFF3B2C25),
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 2),
        textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: onTap,
      child: Text(title),
    );
  }
}
